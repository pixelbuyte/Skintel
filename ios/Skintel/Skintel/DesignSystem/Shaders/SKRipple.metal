#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// Skinstel 3.0 water ripple, used by `.skRipple(trigger:origin:)`.
///
/// A ring travels out from `origin` at `speed` points per second. Each pixel samples the
/// layer pushed along the ring's direction by a decaying sine, and a faint highlight rides
/// the crest so the ripple still reads on a flat colour.
[[ stitchable ]] half4 skRipple(float2 position, SwiftUI::Layer layer, float2 origin, float time,
                               float amplitude, float frequency, float decay, float speed) {
    float2 delta = position - origin;
    float dist = length(delta);
    float t = max(0.0, time - dist / speed);
    float wave = amplitude * sin(frequency * t) * exp(-decay * t);
    float2 dir = dist > 0.0001 ? delta / dist : float2(0.0);
    half4 color = layer.sample(position + wave * dir);
    float glow = clamp(wave / max(amplitude, 0.0001), -1.0, 1.0);
    color.rgb += half3(half(0.22 * glow)) * color.a;
    return color;
}
