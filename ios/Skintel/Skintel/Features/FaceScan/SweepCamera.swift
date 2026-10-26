import AVFoundation
import CoreImage
import Foundation
import ImageIO
import os
import SkintelCore
import Vision

/// What one analysed camera frame says about the face. Sendable, so it hops to the main actor.
struct SweepReading: Sendable, Equatable {
    var faceCount = 0
    /// Head turn in radians from Vision; the sign depends on the image orientation, so the sweep
    /// only relies on its size and on the two turns having opposite signs.
    var yaw: Double = 0
    var evenLight = false
    var goodDistance = false
    var sharp = false

    var oneFace: Bool { faceCount == 1 }
    var ready: Bool { oneFace && evenLight && goodDistance && sharp }
}

/// The encoded images of one locked angle.
struct SweepCapture: Sendable {
    var role: FaceScanImage.Role
    var view: Data
    /// Zone crops, cut from the centre view only.
    var crops: [FaceZone: Data]
}

/// Front camera plus Vision checks for the 3-angle sweep. Runs on its own queue; the session,
/// Vision and Core Image work never touch the main actor. Readings and captures are delivered
/// through the `@MainActor` handlers given at init.
final class SweepCamera: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Target: Sendable, Equatable {
        case none
        /// Lock the next ready frame as this role (front also cuts the zone crops). For the second
        /// turn, `oppositeOf` is the first turn's yaw, so it must go the other way.
        case capture(FaceScanImage.Role, oppositeOf: Double)
    }

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.skintel.facescan.camera")
    private let ciContext = CIContext()
    private let target = OSAllocatedUnfairLock<Target>(initialState: .none)
    private let onReading: @MainActor @Sendable (SweepReading) -> Void
    private let onCapture: @MainActor @Sendable (SweepCapture, Double) -> Void
    private var frameIndex = 0
    private var configured = false

    /// Image orientation for the front camera held upright, unmirrored (the person's right cheek
    /// is on the image's left, as another person would see them).
    private let orientation: CGImagePropertyOrientation = .right

    init(onReading: @escaping @MainActor @Sendable (SweepReading) -> Void,
         onCapture: @escaping @MainActor @Sendable (SweepCapture, Double) -> Void) {
        self.onReading = onReading
        self.onCapture = onCapture
        super.init()
    }

    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    func setTarget(_ value: Target) {
        target.withLock { $0 = value }
    }

    func start() {
        queue.async { [self] in
            if !configured { configure() }
            if configured && !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        guard session.canAddInput(input) else { session.commitConfiguration(); return }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return }
        session.addOutput(output)
        session.commitConfiguration()
        configured = true
    }

    // MARK: Frames

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameIndex += 1
        guard frameIndex % 3 == 0, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let rects = VNDetectFaceRectanglesRequest()
        rects.revision = VNDetectFaceRectanglesRequestRevision3
        let quality = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try? handler.perform([rects, quality])

        let faces = rects.results ?? []
        var reading = SweepReading()
        reading.faceCount = faces.count
        reading.evenLight = Self.meanLuma(pixelBuffer).map { $0 > 0.22 && $0 < 0.9 } ?? false
        let face = faces.first
        if let face {
            reading.yaw = face.yaw?.doubleValue ?? 0
            let w = face.boundingBox.width
            reading.goodDistance = w > 0.28 && w < 0.8
        }
        let captureQuality = quality.results?.first?.faceCaptureQuality ?? 0
        reading.sharp = captureQuality >= 0.3

        let handlerReading = onReading
        Task { @MainActor in handlerReading(reading) }

        guard reading.ready, let face else { return }
        let current = target.withLock { $0 }
        guard case .capture(let role, let first) = current,
              Self.matches(role: role, yaw: reading.yaw, oppositeOf: first) else { return }
        target.withLock { $0 = .none }

        guard let capture = encode(pixelBuffer: pixelBuffer, face: face.boundingBox, role: role) else {
            target.withLock { $0 = current }
            return
        }
        let handlerCapture = onCapture
        let yaw = reading.yaw
        Task { @MainActor in handlerCapture(capture, yaw) }
    }

    /// Centre wants the head straight; the turns want about 30° or more (the person aims for 45°).
    static func matches(role: FaceScanImage.Role, yaw: Double, oppositeOf first: Double) -> Bool {
        switch role {
        case .front: abs(yaw) < 0.2
        case .left45, .right45: abs(yaw) >= 0.52 && (first == 0 || (yaw > 0) != (first > 0))
        case .zone: false
        }
    }

    /// Mean of a sample of the luma plane, 0...1.
    private static func meanLuma(_ buffer: CVPixelBuffer) -> Double? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard CVPixelBufferGetPlaneCount(buffer) > 0,
              let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var total = 0, count = 0
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                total += Int(bytes[y * stride + x])
                count += 1
                x += 16
            }
            y += 16
        }
        return count > 0 ? Double(total) / Double(count) / 255 : nil
    }

    // MARK: Encoding (PRO-SPEC §3: views 1024 px, crops 512 px, JPEG 0.8 stepping to 0.6)

    /// Zone rectangles in the face box's unit space (origin bottom-left, as Vision and Core Image
    /// use). The image is unmirrored, so the person's right cheek is on the image's left.
    private static let zoneRects: [FaceZone: CGRect] = [
        .forehead: CGRect(x: 0.2, y: 0.82, width: 0.6, height: 0.3),
        .nose: CGRect(x: 0.34, y: 0.32, width: 0.32, height: 0.4),
        .rightCheek: CGRect(x: 0.04, y: 0.22, width: 0.34, height: 0.38),
        .leftCheek: CGRect(x: 0.62, y: 0.22, width: 0.34, height: 0.38),
        .chin: CGRect(x: 0.3, y: -0.06, width: 0.4, height: 0.26),
    ]

    private func encode(pixelBuffer: CVPixelBuffer, face: CGRect, role: FaceScanImage.Role) -> SweepCapture? {
        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let image = oriented.transformed(by: CGAffineTransform(translationX: -oriented.extent.origin.x,
                                                               y: -oriented.extent.origin.y))
        let extent = image.extent
        guard let view = jpeg(image, longSide: 1024, limit: FaceScanLimits.maxViewBase64) else { return nil }
        var crops: [FaceZone: Data] = [:]
        if role == .front {
            let faceRect = VNImageRectForNormalizedRect(face, Int(extent.width), Int(extent.height))
            for (zone, unit) in Self.zoneRects {
                let rect = CGRect(x: faceRect.minX + unit.minX * faceRect.width,
                                  y: faceRect.minY + unit.minY * faceRect.height,
                                  width: unit.width * faceRect.width,
                                  height: unit.height * faceRect.height).intersection(extent)
                guard !rect.isNull, rect.width > 8, rect.height > 8 else { continue }
                let cropped = image.cropped(to: rect)
                    .transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
                if let data = jpeg(cropped, longSide: 512, limit: FaceScanLimits.maxZoneBase64) {
                    crops[zone] = data
                }
            }
        }
        return SweepCapture(role: role, view: view, crops: crops)
    }

    /// Scales so the long side is at most `longSide`, then encodes at 0.8, 0.7, 0.6 until the
    /// base64 size fits `limit`; a last try at three quarters of the size.
    private func jpeg(_ image: CIImage, longSide: CGFloat, limit: Int) -> Data? {
        let long = max(image.extent.width, image.extent.height)
        guard long > 0 else { return nil }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        for factor in [1.0, 0.75] as [CGFloat] {
            let s = min(1, longSide / long) * factor
            let scaled = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
            for q in [0.8, 0.7, 0.6] {
                let key = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
                guard let data = ciContext.jpegRepresentation(of: scaled, colorSpace: colorSpace, options: [key: q]) else { continue }
                if Self.base64Length(data.count) <= limit { return data }
            }
        }
        return nil
    }

    static func base64Length(_ bytes: Int) -> Int { ((bytes + 2) / 3) * 4 }
}
