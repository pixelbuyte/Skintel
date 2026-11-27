import SwiftUI
import SkintelCore

/// Face scan is 13 and over (COPPA). Asked when onboarding gave no age or "Under 18".
struct FaceAgeGateView: View {
    let tooYoung: Bool
    let onAnswer: (Bool) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.ink).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }
            if tooYoung {
                Text("Face scan is for people 13 and over.").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Everything else in Skintel is still here for you.")
                    .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.muted)
                Spacer()
                SKButton(title: "Close", action: onClose)
            } else {
                Text("Are you 13 or older?").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Face scan reads photos of your face, so it is for people 13 and over.")
                    .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.muted)
                Spacer()
                SKButton(title: "Yes") { onAnswer(true) }
                SKButton(title: "No", kind: .secondary) { onAnswer(false) }
            }
        }
        .skPagePadding()
        .padding(.vertical, SKSpace.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .skPageBackground()
    }
}
