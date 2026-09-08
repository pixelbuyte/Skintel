import UIKit

enum ImageResizer {
    /// Downscales to `maxDimension` on the long edge and encodes JPEG. Label photos are
    /// text; 1600px is plenty for OCR and keeps uploads well under the API's 6 MB cap.
    static func jpegData(_ image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
