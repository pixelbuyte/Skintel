import SwiftUI

/// A small "NEW" pill for a freshly shipped feature: clay fill, cream mono caps.
/// Pair it with `@AppStorage("seen.faceScan")` (or similar) to hide it after first open.
struct SKNewBadge: View {
    var body: some View {
        Text("NEW")
            .font(SKFont.mono(11, bold: true, relativeTo: .caption2))
            .tracking(1)
            .foregroundStyle(SKColor.cream)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(SKColor.primary, in: Capsule())
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("New feature")
    }
}
