import Foundation
import Observation
import SkintelCore

/// AI verdicts persisted on this device, mirroring the web's `localStorage['skintel:scans:v1']`.
/// The `products` table has no score column, so the "82" next to a product lives here,
/// keyed by product id once saved. Stored in Application Support as JSON (no PII beyond
/// the ingredient text the user already entered).
@MainActor
@Observable
final class ScanStore {
    struct StoredScan: Codable, Sendable, Identifiable, Hashable {
        var id: String                 // product id when saved, otherwise a UUID
        var productID: String?
        var brand: String?
        var productName: String?
        var inci: String
        var result: ScanResult
        var scannedAt: Date
    }

    private(set) var scans: [String: StoredScan] = [:]
    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Skintel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("scans.v1.json")
        load()
    }

    func result(for productID: String) -> ScanResult? { scans[productID]?.result }
    func score(for productID: String) -> Int? { scans[productID]?.result.score }

    var recent: [StoredScan] {
        scans.values.sorted { $0.scannedAt > $1.scannedAt }
    }

    @discardableResult
    func record(productID: String?, brand: String?, productName: String?, inci: String, result: ScanResult) -> StoredScan {
        let id = productID ?? UUID().uuidString
        let s = StoredScan(id: id, productID: productID, brand: brand, productName: productName,
                           inci: inci, result: result, scannedAt: Date())
        scans[id] = s
        persist()
        return s
    }

    /// When an unsaved scan becomes a product, re-key it so the product shows its score.
    func attach(scanID: String, to productID: String) {
        guard var s = scans.removeValue(forKey: scanID) else { return }
        s.id = productID
        s.productID = productID
        scans[productID] = s
        persist()
    }

    func remove(productID: String) {
        scans.removeValue(forKey: productID)
        persist()
    }

    func reset() {
        scans = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: StoredScan].self, from: data) else { return }
        scans = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(scans) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
