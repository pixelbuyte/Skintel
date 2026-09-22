import Foundation
import Observation
import SkintelCore
import UIKit

/// One state machine for every way a product can enter the app: barcode, typed barcode,
/// pasted INCI, label photo, product link, or catalogue search. Each resolves to a
/// `ScanCandidate`; analysis runs `/api/scan-ai` with the shelf's culprits and records
/// the result in `ScanStore` so the verdict can be shown, saved, or discarded.
@MainActor
@Observable
final class ScanFlowModel {
    enum Phase: Equatable {
        case scanning
        case lookingUp(upc: String)
        case found(ScanCandidate)
        case analyzing(ScanCandidate)
        case result(scanID: String)
        case notFound(upc: String)
        case failed(APIError, retry: ScanCandidate?)
    }

    private(set) var phase: Phase = .scanning
    var torchOn = false

    private let env: AppEnvironment
    private var lastCode: (String, Date)?
    private var operationID = UUID()
    private var imageTask: Task<Void, Never>?
    private var resolvedImageURL: URL?

    init(env: AppEnvironment) {
        self.env = env
    }

    var isBusy: Bool {
        switch phase {
        case .lookingUp, .analyzing: true
        default: false
        }
    }

    func reset() {
        beginOperation()
        phase = .scanning
        lastCode = nil
    }

    // MARK: Entry points

    func handleBarcode(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        guard (8...13).contains(digits.count) else { return }
        // The camera fires the same code many times a second; one lookup per code per 4s.
        if let (code, at) = lastCode, code == digits, Date().timeIntervalSince(at) < 4 { return }
        guard case .scanning = phase else { return }
        lastCode = (digits, Date())
        // Close the gate synchronously before starting the task so a second camera
        // callback cannot queue a duplicate paid lookup on the same run loop turn.
        phase = .lookingUp(upc: digits)
        Haptics.medium()
        Task { await lookup(upc: digits) }
    }

    func lookup(upc: String) async {
        let operation = beginOperation()
        phase = .lookingUp(upc: upc)
        env.analytics.track(.scanStarted(mode: "barcode"))
        do {
            let hit = try await env.api.lookupBarcode(upc)
            guard operation == operationID, !Task.isCancelled else { return }
            let c = ScanCandidate(brand: hit.brand, productName: hit.productName, inci: hit.ingredients, upc: upc, source: hit.source ?? "lookup", imageURL: ProductImageURL.remote(hit.imageUrl))
            enrichImage(for: c, operation: operation)
            if c.parsed.isEmpty { phase = .found(c) }   // matched but no INCI: user can paste it
            else { await analyze(c, operation: operation) }
        } catch let e as APIError {
            guard operation == operationID, e != .cancelled else { return }
            if case .notFound = e { phase = .notFound(upc: upc); Haptics.warning() }
            else { phase = .failed(e, retry: nil); Haptics.error() }
        } catch {
            guard operation == operationID, !Task.isCancelled else { return }
            phase = .failed(.network(error.localizedDescription), retry: nil)
        }
    }

    func usePasted(brand: String?, name: String?, inci: String, imageURL: URL? = nil, photoData: Data? = nil) async {
        let c = ScanCandidate(brand: blank(brand), productName: blank(name), inci: inci, upc: nil, source: "paste", imageURL: imageURL, photoData: photoData)
        env.analytics.track(.scanStarted(mode: "paste"))
        await analyze(c)
    }

    func importURL(_ url: String) async {
        let operation = beginOperation()
        phase = .lookingUp(upc: "")
        env.analytics.track(.scanStarted(mode: "url"))
        do {
            let r = try await env.api.importURL(url)
            guard operation == operationID, !Task.isCancelled else { return }
            await analyze(ScanCandidate(brand: r.brand, productName: r.productName, inci: r.ingredients, upc: nil, source: "url", imageURL: ProductImageURL.remote(r.imageUrl)), operation: operation)
        } catch let e as APIError { if operation == operationID, e != .cancelled { phase = .failed(e, retry: nil) } }
        catch { if operation == operationID, !Task.isCancelled { phase = .failed(.network(error.localizedDescription), retry: nil) } }
    }

    func useSearchResult(_ r: ProductSearchResult) async {
        let operation = beginOperation()
        let c = ScanCandidate(brand: r.brand, productName: r.productName, inci: r.ingredients ?? "", upc: r.code, source: "search", imageURL: ProductImageURL.remote(r.imageUrl))
        enrichImage(for: c, operation: operation)
        env.analytics.track(.scanStarted(mode: "search"))
        if c.parsed.isEmpty { phase = .found(c) } else { await analyze(c, operation: operation) }
    }

    func scanPhoto(_ image: UIImage) async {
        let operation = beginOperation()
        guard let data = ImageResizer.jpegData(image) else { phase = .failed(.unprocessable("That photo couldn't be read."), retry: nil); return }
        phase = .lookingUp(upc: "")
        env.analytics.track(.scanStarted(mode: "photo"))
        do {
            let r = try await env.api.scanPhoto(imageBase64: data.base64EncodedString(), mimeType: "image/jpeg")
            guard operation == operationID, !Task.isCancelled else { return }
            let c = ScanCandidate(brand: r.brand, productName: r.productName, inci: r.ingredients, upc: nil, source: "photo", photoData: ImageResizer.jpegData(image, maxDimension: 512, quality: 0.8))
            if c.parsed.isEmpty { phase = .found(c) }
            else { await analyze(c, operation: operation) }
        } catch let e as APIError { if operation == operationID, e != .cancelled { phase = .failed(e, retry: nil) } }
        catch { if operation == operationID, !Task.isCancelled { phase = .failed(.network(error.localizedDescription), retry: nil) } }
    }

    // MARK: Analysis

    func analyze(_ c: ScanCandidate) async {
        let operation = beginOperation()
        enrichImage(for: c, operation: operation)
        await analyze(c, operation: operation)
    }

    private func analyze(_ c: ScanCandidate, operation: UUID) async {
        phase = .analyzing(c)
        let matches = env.products.culprits.all.map(ScanAIRequest.Match.init)
        do {
            let result = try await env.api.scan(ScanAIRequest(inci: c.inci, matches: matches))
            guard operation == operationID, !Task.isCancelled else { return }
            let stored = env.scans.record(productID: nil, brand: c.brand, productName: c.productName, inci: c.inci, source: c.source, result: result,
                                          imageURL: resolvedImageURL ?? c.imageURL, photoData: c.photoData)
            env.analytics.track(.scanCompleted(verdict: result.verdict.rawValue))
            Haptics.success()
            phase = .result(scanID: stored.id)
        } catch let e as APIError {
            guard operation == operationID, e != .cancelled else { return }
            phase = .failed(e, retry: c)
            Haptics.error()
        } catch {
            guard operation == operationID, !Task.isCancelled else { return }
            phase = .failed(.network(error.localizedDescription), retry: c)
        }
    }

    @discardableResult
    private func beginOperation() -> UUID {
        imageTask?.cancel()
        imageTask = nil
        resolvedImageURL = nil
        operationID = UUID()
        return operationID
    }

    private func enrichImage(for candidate: ScanCandidate, operation: UUID) {
        resolvedImageURL = candidate.imageURL
        guard candidate.imageURL == nil, candidate.photoData == nil, let barcode = candidate.upc else { return }
        imageTask = Task {
            guard let url = await env.api.lookupProductImage(barcode: barcode),
                  operation == operationID, !Task.isCancelled else { return }
            resolvedImageURL = url
            switch phase {
            case .found(var current):
                current.imageURL = url; phase = .found(current)
            case .analyzing(var current):
                current.imageURL = url; phase = .analyzing(current)
            case .result(let scanID):
                env.scans.setImage(for: scanID, imageURL: url)
            default: break
            }
        }
    }

    private func blank(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return t
    }
}
