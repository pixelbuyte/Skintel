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
// The mesh is a generic face, not the person's. It never leaves the device and nothing about the
// person is fitted to it (PRO-SPEC §2).

/// The canonical mesh plus the per-zone heat weights the renderer blends in.
struct FaceMeshData: Sendable {
    /// Flat x, y, z per vertex. y is up, z points out of the face.
    let positions: [Float]
    /// Flat vertex indices, three per triangle.
    let faces: [Int]
    let vertexCount: Int
    /// For each zone, a 0...1 weight per vertex: a Gaussian falloff around the zone's landmarks.
    let weights: [FaceZone: [Float]]

    /// The landmark each zone's glow and label leader sit on.
    static let anchors: [FaceZone: Int] = [
        .forehead: 151, .nose: 4, .leftCheek: 280, .rightCheek: 50, .chin: 199,
    ]

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
