import Foundation
import SkintelCore

// The face shape drawn by `FaceMeshView`.
//
// `Resources/face_mesh.json` is the MediaPipe Face Mesh canonical face model (468 vertices,
// 898 triangles) from google-ai-edge/mediapipe
// (mediapipe/modules/face_geometry/data/canonical_face_model.obj),
// Copyright The MediaPipe Authors, licensed under the Apache License, Version 2.0
// (https://www.apache.org/licenses/LICENSE-2.0). Modified: vertices recentred and scaled so the
// face is 2 units tall, UVs and normals dropped, stored as flat `v` (x, y, z) and `f` (a, b, c).
//
// The mesh is a generic face, not the person's. It never leaves the device. On the "You" photo
// its front view is laid over the person's own Day 1 photo with a 2D fit to Vision's landmarks
// (`FaceMeshFit`), on the phone only, for the picture; nothing about the fit is kept or sent
// (PRO-SPEC §2).
//
// Sides: the model puts the person's RIGHT at negative x (MediaPipe names landmarks from the
// person's point of view: 33/133 are the corners of their right eye, at x = -0.50 and -0.21;
// 263/362 their left eye, at +x). Seen from the front without mirroring, that is the image's
// left, the same as the unmirrored photos the sweep takes. Screens mirror it (selfie view).

/// The canonical mesh plus the per-zone heat weights the renderer blends in.
struct FaceMeshData: Sendable {
    /// Flat x, y, z per vertex. y is up, z points out of the face.
    let positions: [Float]
    /// Flat vertex indices, three per triangle.
    let faces: [Int]
    let vertexCount: Int
    /// For each zone, a 0...1 weight per vertex: a Gaussian falloff around the zone's landmarks.
    let weights: [FaceZone: [Float]]
    /// The wireframe of the front view (x right, y up, depth ignored): each edge of a triangle
    /// that faces the viewer, once, as flat pairs `a, b`.
    let frontEdges: [Int]

    /// The landmark each zone's glow and label leader sit on.
    static let anchors: [FaceZone: Int] = [
        .forehead: 151, .nose: 4, .leftCheek: 280, .rightCheek: 50, .chin: 199,
    ]

    // Landmark groups (MediaPipe Face Mesh indices) the photo fit matches to Vision's landmarks.

    /// The person's right eye outline (lower then upper lid), at negative x.
    static let rightEyeRing = [33, 7, 163, 144, 145, 153, 154, 155, 133, 246, 161, 160, 159, 158, 157, 173]
    /// The person's left eye outline, at positive x.
    static let leftEyeRing = [263, 249, 390, 373, 374, 380, 381, 382, 362, 466, 388, 387, 386, 385, 384, 398]
    /// The outer lip line, upper then lower.
    static let outerLips = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291, 146, 91, 181, 84, 17, 314, 405, 321, 375]
    /// The tip of the nose.
    static let noseTip = [1, 4]
    /// The bottom of the chin.
    static let chinTip = [152]
    /// The face outline, in order around the face: the photo clips the wireframe and glow to it.
    static let silhouette = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377,
                             152, 148, 176, 149, 150, 136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]

    /// The centre of a landmark group in the front view (x, y; depth ignored).
    func frontCentroid(_ indices: [Int]) -> SIMD2<Double>? {
        let valid = indices.filter { $0 >= 0 && $0 < vertexCount }
        guard !valid.isEmpty else { return nil }
        var sum = SIMD2<Double>.zero
        for i in valid { sum += SIMD2<Double>(Double(positions[i * 3]), Double(positions[i * 3 + 1])) }
        return sum / Double(valid.count)
    }

    /// Landmark indices and radii of each zone's heat, as in the approved canvas
    /// (`FaceMesh.dc.html`). Landmarks 280/425 are the person's left cheek, 50/205 their right.
    static let centres: [FaceZone: [(index: Int, radius: Float)]] = [
        .forehead: [(151, 0.42), (108, 0.3), (337, 0.3)],
        .nose: [(195, 0.2), (4, 0.2)],
        .leftCheek: [(280, 0.3), (425, 0.26)],
        .rightCheek: [(50, 0.3), (205, 0.26)],
        .chin: [(199, 0.26), (175, 0.22)],
    ]

    /// Loaded once from the app bundle; nil only if the resource is missing or damaged.
    static let shared: FaceMeshData? = load()

    private struct File: Decodable {
        let v: [Float]
        let f: [Int]
    }

    private static func load() -> FaceMeshData? {
        guard let url = Bundle.main.url(forResource: "face_mesh", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        return FaceMeshData(positions: file.v, faces: file.f)
    }

    init?(positions: [Float], faces: [Int]) {
        let n = positions.count / 3
        guard n > 0, positions.count == n * 3, faces.count % 3 == 0,
              faces.allSatisfy({ $0 >= 0 && $0 < n }),
              Self.anchors.values.allSatisfy({ $0 < n }) else { return nil }
        self.positions = positions
        self.faces = faces
        self.vertexCount = n
        var weights: [FaceZone: [Float]] = [:]
        for (zone, centres) in Self.centres {
            var w = [Float](repeating: 0, count: n)
            for i in 0..<n {
                var best: Float = 0
                for c in centres where c.index < n {
                    let dx = positions[i * 3] - positions[c.index * 3]
                    let dy = positions[i * 3 + 1] - positions[c.index * 3 + 1]
                    let dz = positions[i * 3 + 2] - positions[c.index * 3 + 2]
                    let d2 = dx * dx + dy * dy + dz * dz
                    let value = Float(exp(Double(-(d2 / (c.radius * c.radius)) * 1.6)))
                    if value > best { best = value }
                }
                w[i] = best
            }
            weights[zone] = w
        }
        self.weights = weights

        // Front-facing in the front view: counter-clockwise with x right and y up (888 of the
        // model's 898 triangles; the rest sit edge-on at the sides).
        var edges: [Int] = []
        var seen = Set<Int>()
        var k = 0
        while k + 2 < faces.count {
            let a = faces[k], b = faces[k + 1], c = faces[k + 2]
            let ax = positions[a * 3], ay = positions[a * 3 + 1]
            let cross = (positions[b * 3] - ax) * (positions[c * 3 + 1] - ay)
                - (positions[b * 3 + 1] - ay) * (positions[c * 3] - ax)
            if cross > 0 {
                for (p, q) in [(a, b), (b, c), (c, a)] {
                    let lo = min(p, q), hi = max(p, q)
                    if seen.insert(lo * n + hi).inserted {
                        edges.append(lo)
                        edges.append(hi)
                    }
                }
            }
            k += 3
        }
        self.frontEdges = edges
    }
}

/// How strongly each zone glows on the map: 0 none, 1 some, 2 noticeable. Built from a scan's
/// scores through `FaceCalibration.band(_:)`, so the map never shows a raw number.
struct FaceZoneLevels: Sendable, Hashable {
    var levels: [FaceZone: Int] = [:]

    func level(_ zone: FaceZone) -> Int { levels[zone] ?? 0 }

    static func level(for band: FaceCalibration.Band) -> Int {
        switch band {
        case .clear: 0
        case .mild: 1
        case .noticeable: 2
        }
    }

    /// The highest band across a zone's metrics.
    init(result: FaceScanResult?) {
        guard let result else { return }
        for zone in result.zones {
            let top = zone.scores.values.max() ?? 0
            levels[zone.zone] = Self.level(for: FaceCalibration.band(top))
        }
    }

    init(levels: [FaceZone: Int]) { self.levels = levels }
}

/// A label drawn beside the map with a leader line to its zone.
struct FaceMeshLabel: Sendable, Hashable {
    enum Side: Sendable, Hashable { case leading, trailing }
    var zone: FaceZone
    var title: String
    var value: String
    var side: Side
    /// Vertical position, 0 top to 1 bottom of the view.
    var y: CGFloat
    var hot: Bool
}
