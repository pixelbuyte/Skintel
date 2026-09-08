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
        Haptics.medium()
        Task { await lookup(upc: digits) }
    }

    func lookup(upc: String) async {
        phase = .lookingUp(upc: upc)
        env.analytics.track(.scanStarted(mode: "barcode"))
        do {
            let hit = try await env.api.lookupBarcode(upc)
            let c = ScanCandidate(brand: hit.brand, productName: hit.productName, inci: hit.ingredients, upc: upc, source: hit.source ?? "lookup")
            if c.parsed.isEmpty { phase = .found(c) }   // matched but no INCI: user can paste it
            else { await analyze(c) }
        } catch let e as APIError {
            if case .notFound = e { phase = .notFound(upc: upc); Haptics.warning() }
            else { phase = .failed(e, retry: nil); Haptics.error() }
        } catch {
            phase = .failed(.network(error.localizedDescription), retry: nil)
        }
    }

    func usePasted(brand: String?, name: String?, inci: String) async {
        let c = ScanCandidate(brand: blank(brand), productName: blank(name), inci: inci, upc: nil, source: "paste")
        env.analytics.track(.scanStarted(mode: "paste"))
        await analyze(c)
    }

    func importURL(_ url: String) async {
        phase = .lookingUp(upc: "")
        env.analytics.track(.scanStarted(mode: "url"))
        do {
            let r = try await env.api.importURL(url)
            await analyze(ScanCandidate(brand: r.brand, productName: r.productName, inci: r.ingredients, upc: nil, source: "url"))
        } catch let e as APIError { phase = .failed(e, retry: nil) }
        catch { phase = .failed(.network(error.localizedDescription), retry: nil) }
    }

    func useSearchResult(_ r: ProductSearchResult) async {
        let c = ScanCandidate(brand: r.brand, productName: r.productName, inci: r.ingredients ?? "", upc: r.code, source: "search")
        env.analytics.track(.scanStarted(mode: "search"))
        if c.parsed.isEmpty { phase = .found(c) } else { await analyze(c) }
    }

    func scanPhoto(_ image: UIImage) async {
        guard let data = ImageResizer.jpegData(image) else { phase = .failed(.unprocessable("That photo couldn't be read."), retry: nil); return }
        phase = .lookingUp(upc: "")
        env.analytics.track(.scanStarted(mode: "photo"))
        do {
            let r = try await env.api.scanPhoto(imageBase64: data.base64EncodedString(), mimeType: "image/jpeg")
            let c = ScanCandidate(brand: r.brand, productName: r.productName, inci: r.ingredients, upc: nil, source: "photo")
            if c.parsed.isEmpty { phase = .failed(.unprocessable("No ingredient list was found in that photo. Try a sharper shot of the INCI block."), retry: nil) }
            else { await analyze(c) }
        } catch let e as APIError { phase = .failed(e, retry: nil) }
        catch { phase = .failed(.network(error.localizedDescription), retry: nil) }
    }

    // MARK: Analysis

    func analyze(_ c: ScanCandidate) async {
        phase = .analyzing(c)
        let matches = env.products.culprits.all.map(ScanAIRequest.Match.init)
        do {
            let result = try await env.api.scan(ScanAIRequest(inci: c.inci, matches: matches))
            let stored = env.scans.record(productID: nil, brand: c.brand, productName: c.productName, inci: c.inci, source: c.source, result: result)
            env.analytics.track(.scanCompleted(verdict: result.verdict.rawValue))
            Haptics.success()
            phase = .result(scanID: stored.id)
        } catch let e as APIError {
            phase = .failed(e, retry: c)
            Haptics.error()
        } catch {
            phase = .failed(.network(error.localizedDescription), retry: c)
        }
    }

    private func blank(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return t
    }
}
