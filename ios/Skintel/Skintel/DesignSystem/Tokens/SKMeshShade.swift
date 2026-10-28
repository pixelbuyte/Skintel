import Foundation

/// Shading ramps for the face scan's 3D mesh (`FaceMeshView`), from the approved canvas renderer
/// (`FaceMesh.dc.html`). Lighting for a 3D surface, not UI colours: the dark end sits on
/// `SKColor.scannerBg`, the warm end is `SKColor.primary` lit, scan light is `SKColor.bg`.
/// Colour components are sRGB 0...255; `light` is the light direction.
enum SKMeshShade {
    static let darkLow: SIMD3<Double> = [24, 22, 19]
    static let darkHigh: SIMD3<Double> = [92, 84, 74]
    static let warmLow: SIMD3<Double> = [120, 60, 48]
    static let warmHigh: SIMD3<Double> = [222, 132, 110]
    static let scanLight: SIMD3<Double> = [244, 237, 224]
    /// The light palette (cream screens): a pale clay-sand face, lit to cream.
    static let lightLow: SIMD3<Double> = [206, 186, 168]
    static let lightHigh: SIMD3<Double> = [250, 244, 234]
    static let light: SIMD3<Double> = [-0.35, 0.45, 0.82]
}
