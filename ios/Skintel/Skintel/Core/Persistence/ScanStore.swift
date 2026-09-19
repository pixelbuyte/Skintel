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
        /// How the scan got here ("lookup", "paste", "url", "search", "photo", "shelf").
        /// Optional so scans persisted before this field existed still decode — `load()`
        /// drops the whole file on any decode error, and losing history is worse than a
        /// missing label.
        var source: String?
        var result: ScanResult
        var scannedAt: Date
    }

    private(set) var scans: [String: StoredScan] = [:]
    private struct StoredImage: Codable {
        var remoteURL: String?
        var filename: String?
    }
    private var images: [String: StoredImage] = [:]
    /// A late optional photo lookup may finish just after the user saves the scan.
    /// Keep that in-flight write attached to the product rather than an orphan scan ID.
    private var attachedScanIDs: [String: String] = [:]
    private let fileURL: URL
    private let imagesURL: URL
    private let photosDirectory: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Skintel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("scans.v1.json")
        imagesURL = dir.appendingPathComponent("product-images.v1.json")
        photosDirectory = dir.appendingPathComponent("ProductPhotos", isDirectory: true)
        load()
        if let data = try? Data(contentsOf: imagesURL),
           let stored = try? JSONDecoder().decode([String: StoredImage].self, from: data) { images = stored }
    }

    func result(for productID: String) -> ScanResult? { scans[productID]?.result }
    func score(for productID: String) -> Int? { scans[productID]?.result.score }

    /// Same key before and after saving a scan. Photos also work for manually added
    /// products with no paid analysis; no database schema or fake verdict is required.
    func imageURL(for id: String) -> URL? {
        guard let image = images[id] else { return nil }
        if let filename = image.filename, filename == URL(fileURLWithPath: filename).lastPathComponent {
            let url = photosDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return ProductImageURL.remote(image.remoteURL)
    }

    /// Reuses the on-device photo reference when saving; image files stay in the app's
    /// protected Application Support directory, outside the JSON scan history.
    func setImage(for id: String, imageURL: URL? = nil, photoData: Data? = nil) {
        let id = attachedScanIDs[id] ?? id
        var reference = images[id] ?? StoredImage()
        if let photoData {
            let filename = UUID().uuidString + ".jpg"
            do {
                try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
                try photoData.write(to: photosDirectory.appendingPathComponent(filename), options: [.atomic, .completeFileProtection])
                let previous = reference.filename
                reference.filename = filename
                images[id] = reference
                removeUnusedPhoto(previous)
            } catch { return }
        } else if let imageURL {
            if imageURL.isFileURL, imageURL.deletingLastPathComponent().standardizedFileURL == photosDirectory.standardizedFileURL {
                reference.filename = imageURL.lastPathComponent
            } else if let remote = ProductImageURL.remote(imageURL.absoluteString) {
                reference.remoteURL = remote.absoluteString
            } else { return }
        } else { return }
        images[id] = reference
        persistImages()
    }

    var recent: [StoredScan] {
        scans.values.sorted { $0.scannedAt > $1.scannedAt }
    }

    @discardableResult
    func record(productID: String?, brand: String?, productName: String?, inci: String,
                source: String?, result: ScanResult, imageURL: URL? = nil, photoData: Data? = nil) -> StoredScan {
        let id = productID ?? UUID().uuidString
        let s = StoredScan(id: id, productID: productID, brand: brand, productName: productName,
                           inci: inci, source: source, result: result, scannedAt: Date())
        scans[id] = s
        setImage(for: id, imageURL: imageURL, photoData: photoData)
        persist()
        return s
    }

    /// When an unsaved scan becomes a product, re-key it so the product shows its score.
    func attach(scanID: String, to productID: String) {
        guard var s = scans.removeValue(forKey: scanID) else { return }
        s.id = productID
        s.productID = productID
        scans[productID] = s
        attachedScanIDs[scanID] = productID
        if let image = images.removeValue(forKey: scanID) {
            let previous = images[productID]?.filename
            images[productID] = image
            removeUnusedPhoto(previous)
            persistImages()
        }
        persist()
    }

    func remove(productID: String) {
        scans.removeValue(forKey: productID)
        let image = images.removeValue(forKey: productID)
        removeUnusedPhoto(image?.filename)
        persistImages()
        attachedScanIDs = attachedScanIDs.filter { $0.value != productID }
        persist()
    }

    func reset() {
        scans = [:]
        try? FileManager.default.removeItem(at: fileURL)
        let filenames = images.values.compactMap(\.filename)
        images = [:]
        attachedScanIDs = [:]
        for filename in filenames { removeUnusedPhoto(filename) }
        try? FileManager.default.removeItem(at: imagesURL)
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

    private func persistImages() {
        guard let data = try? JSONEncoder().encode(images) else { return }
        try? data.write(to: imagesURL, options: [.atomic, .completeFileProtection])
    }

    private func removeUnusedPhoto(_ filename: String?) {
        guard let filename, filename == URL(fileURLWithPath: filename).lastPathComponent,
              !images.values.contains(where: { $0.filename == filename }) else { return }
        try? FileManager.default.removeItem(at: photosDirectory.appendingPathComponent(filename))
    }
}
