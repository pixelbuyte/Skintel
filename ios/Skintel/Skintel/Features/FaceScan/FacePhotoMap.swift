import ImageIO
import SkintelCore
import SwiftUI
import UIKit
import Vision

/// Where the face, its zone centres and the fitted mesh sit in the Day 1 photo, in Vision's
/// normalised image space (0...1, origin bottom-left). The photo is stored unmirrored, as the
/// sweep took it (the person's right cheek on the image's left); only the screen flips it.
struct FacePhotoLayout: Sendable, Equatable {
    var face: CGRect
    var centres: [FaceZone: CGPoint]
    /// The canonical mesh's front view fitted to this face, one point per vertex; nil when Vision
    /// found too few landmarks for a fit (the photo then shows without the wireframe).
    var mesh: [CGPoint]?

    /// Frames the photo until Vision has looked at it: about where the sweep's oval puts a face.
    static let typicalFace = CGRect(x: 0.25, y: 0.3, width: 0.5, height: 0.4)

    /// Zone centres in the face box's unit space when Vision finds no landmarks: the centres of
    /// the crop rectangles the sweep cuts (`SweepCamera.zoneRects`). The photo is unmirrored, so
    /// the person's right cheek is on the image's left.
    static let fallbackCentres: [FaceZone: CGPoint] = [
        .forehead: CGPoint(x: 0.5, y: 0.97), .nose: CGPoint(x: 0.5, y: 0.52),
        .rightCheek: CGPoint(x: 0.21, y: 0.41), .leftCheek: CGPoint(x: 0.79, y: 0.41),
        .chin: CGPoint(x: 0.5, y: 0.07),
    ]

    /// Runs face landmarks once on the photo and fits the mesh to them. Off the main actor; nil
    /// when no face is found.
    static func locate(_ jpeg: Data) -> FacePhotoLayout? {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let face = (request.results ?? []).max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return nil }
        let box = face.boundingBox
        var centres: [FaceZone: CGPoint] = [:]
        for (zone, p) in unitCentres(face.landmarks) {
            centres[zone] = CGPoint(x: box.minX + p.x * box.width, y: box.minY + p.y * box.height)
        }
        var layout = FacePhotoLayout(face: box, centres: centres, mesh: nil)
        let width = Double(image.width), height = Double(image.height)
        guard width > 0, height > 0, let mesh = FaceMeshData.shared,
              let fit = FaceMeshFit.fit(mesh: mesh, landmarks: face.landmarks, box: box,
                                        imageWidth: width, imageHeight: height) else { return layout }
        var points: [CGPoint] = []
        points.reserveCapacity(mesh.vertexCount)
        for i in 0..<mesh.vertexCount {
            let p = fit.apply(SIMD2<Double>(Double(mesh.positions[i * 3]), Double(mesh.positions[i * 3 + 1])))
            points.append(CGPoint(x: p.x / width, y: p.y / height))
        }
        layout.mesh = points
        // With a fit, the glow and the tags sit on the same landmarks as on the 3D map.
        for (zone, index) in FaceMeshData.anchors where index < points.count {
            layout.centres[zone] = points[index]
        }
        return layout
    }

    /// Where one of the AI's marked spots sits. Its `box` is a fraction of the zone's crop with
    /// the origin at the crop's top left; the crop is the sweep's rectangle for that zone
    /// (`SweepCamera.zoneRects`) around the face box, cut to the image. Approximate, as the boxes
    /// are: drawn as small rings, never outlines.
    func spot(_ region: FaceRegion, in zone: FaceZone) -> CGRect? {
        guard let unit = SweepCamera.zoneRects[zone] else { return nil }
        let crop = CGRect(x: face.minX + unit.minX * face.width, y: face.minY + unit.minY * face.height,
                          width: unit.width * face.width, height: unit.height * face.height)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !crop.isNull, crop.width > 0, crop.height > 0 else { return nil }
        let x = CGFloat(region.x), y = CGFloat(region.y), w = CGFloat(region.width), h = CGFloat(region.height)
        return CGRect(x: crop.minX + x * crop.width, y: crop.maxY - (y + h) * crop.height,
                      width: w * crop.width, height: h * crop.height)
    }

    /// Zone centres in face-box unit space from the landmarks, falling back per zone.
    private static func unitCentres(_ landmarks: VNFaceLandmarks2D?) -> [FaceZone: CGPoint] {
        var out = fallbackCentres
        guard let landmarks else { return out }
        func centroid(_ region: VNFaceLandmarkRegion2D?) -> CGPoint? {
            guard let points = region?.normalizedPoints, !points.isEmpty else { return nil }
            let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
        }
        let eyes = [centroid(landmarks.leftEye), centroid(landmarks.rightEye)].compactMap { $0 }.sorted { $0.x < $1.x }
        let brows = [centroid(landmarks.leftEyebrow), centroid(landmarks.rightEyebrow)].compactMap { $0 }
        let nose = centroid(landmarks.nose)
        let mouth = centroid(landmarks.outerLips)
        if let nose { out[.nose] = nose }
        if eyes.count == 2 {
            let midX = (eyes[0].x + eyes[1].x) / 2
            let eyeY = (eyes[0].y + eyes[1].y) / 2
            let browY = brows.isEmpty ? eyeY + 0.1 : brows.map(\.y).reduce(0, +) / CGFloat(brows.count)
            out[.forehead] = CGPoint(x: midX, y: min(browY + 0.16, 1.05))
            let cheekY = nose.map { $0.y - 0.04 } ?? eyeY - 0.2
            // Image-left is the person's right cheek (unmirrored photo).
            out[.rightCheek] = CGPoint(x: eyes[0].x - 0.03, y: cheekY)
            out[.leftCheek] = CGPoint(x: eyes[1].x + 0.03, y: cheekY)
        }
        if let mouth { out[.chin] = CGPoint(x: mouth.x, y: max(mouth.y - 0.16, -0.04)) }
        return out
    }
}

/// A 2D similarity (scale, turn and shift, no stretch) from the canonical mesh's front view to the
/// photo in pixels, fitted by weighted least squares to matching landmarks.
///
/// Sides, checked on both: the MediaPipe model has the person's right at negative x (33/133, its
/// right eye corners, are at x = -0.50/-0.21), and the photo is unmirrored, so the person's right
/// eye is the one on the image's left. Vision labels `leftEye`/`rightEye` from the person's side,
/// but the fit does not lean on that: it sorts Vision's two eyes by x and pairs the image-left
/// one with the model's right eye. Both spaces have x to the right and y up, so no reflection.
struct FaceMeshFit: Sendable, Equatable {
    /// x' = a·x − b·y + tx, y' = b·x + a·y + ty.
    var a: Double
    var b: Double
    var tx: Double
    var ty: Double

    struct Pair: Sendable {
        var mesh: SIMD2<Double>
        var photo: SIMD2<Double>
        var weight: Double
    }

    var scale: Double { (a * a + b * b).squareRoot() }
    var rotation: Double { atan2(b, a) }

    func apply(_ p: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2<Double>(a * p.x - b * p.y + tx, b * p.x + a * p.y + ty)
    }

    /// Closed-form least squares (the 2D Procrustes fit without reflection) over three or more pairs.
    static func solve(_ pairs: [Pair]) -> FaceMeshFit? {
        guard pairs.count >= 3 else { return nil }
        let total = pairs.reduce(0.0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var meshMean = SIMD2<Double>.zero, photoMean = SIMD2<Double>.zero
        for p in pairs {
            meshMean += p.mesh * p.weight
            photoMean += p.photo * p.weight
        }
        meshMean /= total
        photoMean /= total
        var dot = 0.0, cross = 0.0, norm = 0.0
        for p in pairs {
            let u = p.mesh - meshMean, v = p.photo - photoMean
            dot += p.weight * (u.x * v.x + u.y * v.y)
            cross += p.weight * (u.x * v.y - u.y * v.x)
            norm += p.weight * (u.x * u.x + u.y * u.y)
        }
        guard norm > 1e-9 else { return nil }
        let a = dot / norm, b = cross / norm
        return FaceMeshFit(a: a, b: b,
                           tx: photoMean.x - (a * meshMean.x - b * meshMean.y),
                           ty: photoMean.y - (b * meshMean.x + a * meshMean.y))
    }

    /// Eye centres (always), the mouth centre, the nose tip and the chin. Nil without both eyes
    /// and at least one more point, or when the fit comes out implausibly small, large or turned.
    static func fit(mesh: FaceMeshData, landmarks: VNFaceLandmarks2D?, box: CGRect,
                    imageWidth: Double, imageHeight: Double) -> FaceMeshFit? {
        guard let landmarks else { return nil }
        // Landmark points are normalised to the face box; take them to pixels, y up.
        func points(_ region: VNFaceLandmarkRegion2D?) -> [SIMD2<Double>] {
            (region?.normalizedPoints ?? []).map { p in
                SIMD2<Double>(Double(box.minX + p.x * box.width) * imageWidth,
                              Double(box.minY + p.y * box.height) * imageHeight)
            }
        }
        func centre(_ list: [SIMD2<Double>]) -> SIMD2<Double>? {
            list.isEmpty ? nil : list.reduce(SIMD2<Double>.zero, +) / Double(list.count)
        }
        let eyes = [centre(points(landmarks.leftEye)), centre(points(landmarks.rightEye))]
            .compactMap { $0 }
            .sorted { $0.x < $1.x }
        guard eyes.count == 2,
              let meshRightEye = mesh.frontCentroid(FaceMeshData.rightEyeRing),
              let meshLeftEye = mesh.frontCentroid(FaceMeshData.leftEyeRing) else { return nil }
        var pairs = [Pair(mesh: meshRightEye, photo: eyes[0], weight: 1),
                     Pair(mesh: meshLeftEye, photo: eyes[1], weight: 1)]
        if let mouth = centre(points(landmarks.outerLips)), let lips = mesh.frontCentroid(FaceMeshData.outerLips) {
            pairs.append(Pair(mesh: lips, photo: mouth, weight: 1))
        }
        // The lowest point of the nose's crest is its tip; the lowest of the contour, the chin.
        if let tip = points(landmarks.noseCrest).min(by: { $0.y < $1.y }), let nose = mesh.frontCentroid(FaceMeshData.noseTip) {
            pairs.append(Pair(mesh: nose, photo: tip, weight: 0.5))
        }
        if let bottom = points(landmarks.faceContour).min(by: { $0.y < $1.y }), let chin = mesh.frontCentroid(FaceMeshData.chinTip) {
            pairs.append(Pair(mesh: chin, photo: bottom, weight: 0.5))
        }
        guard let fit = solve(pairs) else { return nil }
        // The model is 2 units from forehead to chin; Vision's box runs from about the brows.
        let boxHeight = Double(box.height) * imageHeight
        guard boxHeight > 0, (0.6...3.0).contains(2 * fit.scale / boxHeight), abs(fit.rotation) < 0.7 else { return nil }
        return fit
    }
}

/// How the photo fills the view: aspect fill, zoomed so the face takes a bit over half the height,
/// kept centred on the face, and mirrored like a selfie (the person's right cheek on the screen's
/// right). The photo and everything drawn over it map through the same frame.
struct FacePhotoFrame: Equatable {
    let size: CGSize
    let imageSize: CGSize
    let scale: CGFloat
    /// Top left of the drawn image before the mirror.
    let origin: CGPoint

    init(size: CGSize, imageSize: CGSize, face: CGRect) {
        self.size = size
        self.imageSize = imageSize
        let w = size.width, h = size.height
        let iw = max(imageSize.width, 1), ih = max(imageSize.height, 1)
        let fill = max(w / iw, h / ih)
        let s = max(fill, min(0.56 * h / max(face.height * ih, 1), fill * 3))
        let cx = face.midX * iw, cy = (1 - face.midY) * ih
        scale = s
        origin = CGPoint(x: min(0, max(w - iw * s, w / 2 - cx * s)),
                         y: min(0, max(h - ih * s, h * 0.5 - cy * s)))
    }

    /// The drawn image, before the mirror.
    var imageRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: imageSize.width * scale, height: imageSize.height * scale)
    }

    /// A normalised image point (origin bottom-left) on screen, mirrored.
    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: size.width - (origin.x + p.x * imageSize.width * scale),
                y: origin.y + (1 - p.y) * imageSize.height * scale)
    }
}

/// The person's own Day 1 photo as one map: the canonical mesh's wireframe fitted over the face
/// (thin ink, clipped to the face), the zone glow, small rings where the AI marked spots, and the
/// zone tags. Mirrored like a selfie; the stored photo is never changed and never leaves the phone.
///
/// The photo shows as soon as it is decoded, over a light placeholder (never black). Vision runs
/// once, off the main actor; when it lands the photo glides to frame the face and the overlay
/// fades in.
struct FacePhotoMap: View {
    let photo: Data
    var levels = FaceZoneLevels(levels: [:])
    var labels: [FaceMeshLabel] = []
    /// The AI's marked spots per zone (baseline and final reads only).
    var regions: [FaceZone: [FaceRegion]] = [:]

    @State private var image: UIImage?
    @State private var layout: FacePhotoLayout?
    /// Vision has finished (found a face or not): the overlay can show.
    @State private var located = false

    var body: some View {
        // Read in the body, not only inside the Canvas renderer. The old map read `image` only
        // inside the renderer, so its body never depended on it: when the photo landed nothing
        // redrew, and "You" stayed blank (black) until something else forced a redraw.
        let image = self.image
        let layout = self.layout
        let located = self.located
        let levels = self.levels
        let labels = self.labels
        let regions = self.regions
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [SKColor.cream, SKColor.rose.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                if let image {
                    let frame = FacePhotoFrame(size: geo.size, imageSize: image.size,
                                               face: layout?.face ?? FacePhotoLayout.typicalFace)
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: frame.imageRect.width, height: frame.imageRect.height)
                        .scaleEffect(x: -1, y: 1)
                        .position(x: geo.size.width - frame.imageRect.midX, y: frame.imageRect.midY)
                        .animation(SKAnimation.ios(0.5), value: layout?.face)
                    Canvas { context, _ in
                        Self.drawOverlay(in: &context, frame: frame, layout: layout, levels: levels,
                                         labels: labels, regions: regions)
                    }
                    .opacity(located ? 1 : 0)
                    .animation(SKAnimation.ios(0.35).delay(0.3), value: located)
                }
            }
        }
        .clipped()
        .task(id: photo) {
            located = false
            layout = nil
            image = UIImage(data: photo)
            let data = photo
            let found = await Task.detached(priority: .userInitiated) { FacePhotoLayout.locate(data) }.value
            guard !Task.isCancelled else { return }
            layout = found
            located = true
        }
        .accessibilityElement()
        .accessibilityLabel("Your Day 1 photo, mirrored like a selfie, with zones highlighted")
        .accessibilityAddTraits(.isImage)
    }

    private static func drawOverlay(in context: inout GraphicsContext, frame: FacePhotoFrame, layout: FacePhotoLayout?,
                                    levels: FaceZoneLevels, labels: [FaceMeshLabel], regions: [FaceZone: [FaceRegion]]) {
        let face = layout?.face ?? FacePhotoLayout.typicalFace
        let centres = layout?.centres ?? FacePhotoLayout.fallbackCentres.mapValues {
            CGPoint(x: face.minX + $0.x * face.width, y: face.minY + $0.y * face.height)
        }
        let faceWidth = face.width * frame.imageSize.width * frame.scale

        // On the skin only: with a fit, the wireframe and the glow are clipped to the face outline.
        var skin = context
        if let mesh = layout?.mesh, let data = FaceMeshData.shared {
            var outline = Path()
            for (n, i) in FaceMeshData.silhouette.enumerated() where i < mesh.count {
                let p = frame.point(mesh[i])
                if n == 0 { outline.move(to: p) } else { outline.addLine(to: p) }
            }
            outline.closeSubpath()
            skin.clip(to: outline)
            var lines = Path()
            let edges = data.frontEdges
            var k = 0
            while k + 1 < edges.count {
                let a = edges[k], b = edges[k + 1]
                if a < mesh.count, b < mesh.count {
                    lines.move(to: frame.point(mesh[a]))
                    lines.addLine(to: frame.point(mesh[b]))
                }
                k += 2
            }
            skin.stroke(lines, with: .color(SKColor.ink.opacity(0.15)), lineWidth: 0.5)
        }

        for zone in FaceZone.allCases {
            let l = Double(levels.level(zone)) / 2
            guard l > 0, let c = centres[zone] else { continue }
            let centre = frame.point(c)
            let rad = faceWidth * (zone == .forehead ? 0.42 : 0.27)
            let gradient = Gradient(colors: [SKColor.primary.opacity(0.42 * l), SKColor.primary.opacity(0)])
            skin.fill(Path(ellipseIn: CGRect(x: centre.x - rad, y: centre.y - rad, width: rad * 2, height: rad * 2)),
                      with: .radialGradient(gradient, center: centre, startRadius: 0, endRadius: rad))
        }

        // Marked spots: hollow rings, a cream halo under clay so they read on any skin.
        if let layout {
            for zone in FaceZone.allCases {
                for region in regions[zone] ?? [] {
                    guard let rect = layout.spot(region, in: zone) else { continue }
                    let c = frame.point(CGPoint(x: rect.midX, y: rect.midY))
                    let extent = max(rect.width * frame.imageSize.width, rect.height * frame.imageSize.height) * frame.scale
                    let r = min(max(extent / 2, 5), 12)
                    let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                    context.stroke(ring, with: .color(SKColor.cream.opacity(0.9)), lineWidth: 3)
                    context.stroke(ring, with: .color(SKColor.primary), lineWidth: 1.5)
                }
            }
        }

        for label in labels {
            guard let c = centres[label.zone] else { continue }
            FaceMapLabels.draw(label, at: frame.point(c), in: &context, size: frame.size)
        }
    }
}
