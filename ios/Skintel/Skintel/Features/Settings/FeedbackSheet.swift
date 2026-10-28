import MessageUI
import StoreKit
import SwiftUI
import UIKit

/// Feedback from the You page's top-left button: what it's about, their words, then Mail with
/// the app and iOS version filled in. Without Mail it falls back to a mailto link, then to
/// copying the address.
struct FeedbackSheet: View {
    static let address = "skinstelreview@gmail.com"

    private enum Kind: String, CaseIterable {
        case idea = "An idea"
        case broken = "Something's broken"
        case faceScan = "Face scan"
        case other = "Something else"
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var kind: Kind = .idea
    @State private var message = ""
    @State private var showMail = false
    @State private var copied = false
    @FocusState private var focused: Bool

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FEEDBACK").font(SKFont.label).tracking(1.6).foregroundStyle(SKColor.primary)
                    Text("Tell us what you think").font(SKFont.serif(34, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Every message is read by the people who make Skinstel.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    Text("IT'S ABOUT").font(SKFont.label).tracking(1.4).foregroundStyle(SKColor.muted)
                    ChipFlow(spacing: SKSpace.sm) {
                        ForEach(Kind.allCases, id: \.self) { option in
                            let on = kind == option
                            Button { kind = option; Haptics.selection() } label: {
                                Text(option.rawValue)
                                    .font(SKFont.sans(15, weight: .medium, relativeTo: .body))
                                    .foregroundStyle(on ? SKColor.cream : SKColor.ink)
                                    .padding(.horizontal, 15)
                                    .frame(minHeight: 44)
                                    .background(on ? SKColor.primary : SKColor.cream, in: Capsule())
                                    .overlay(Capsule().stroke(on ? SKColor.primary : SKColor.line))
                            }
                            .buttonStyle(SKPressStyle())
                            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your message").font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                    TextField(placeholder, text: $message, axis: .vertical)
                        .lineLimit(5...10)
                        .font(SKFont.sans(16, relativeTo: .body))
                        .foregroundStyle(SKColor.ink)
                        .focused($focused)
                        .padding(SKSpace.md)
                        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous).stroke(SKColor.line))
                }

                SKButton(title: "Send feedback", systemImage: "paperplane") { send() }
                    .disabled(trimmed.isEmpty)

                Button {
                    requestReview()
                } label: {
                    Label("Enjoying Skinstel? Rate it on the App Store", systemImage: "star")
                        .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(SKColor.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)

                Text(copied ? "Address copied: \(Self.address)" : "Or email us at \(Self.address).")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.xl)
            .padding(.bottom, SKSpace.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SKColor.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SKColor.bg)
        .sheet(isPresented: $showMail) {
            FeedbackMailView(subject: subject, body: mailBody) { sent in
                showMail = false
                if sent { Haptics.success(); dismiss() }
            }
            .ignoresSafeArea()
        }
    }

    private var placeholder: String {
        switch kind {
        case .idea: "What would make Skinstel better for you?"
        case .broken: "What happened, and what did you expect?"
        case .faceScan: "How was your face scan? Anything confusing or wrong?"
        case .other: "Anything on your mind"
        }
    }

    private var subject: String { "Skinstel feedback: \(kind.rawValue)" }

    private var mailBody: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(trimmed)\n\n—\nSkinstel \(version) (\(build)) · iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)"
    }

    private func send() {
        guard !trimmed.isEmpty else { return }
        focused = false
        if MFMailComposeViewController.canSendMail() {
            showMail = true
            return
        }
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = Self.address
        parts.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: mailBody)]
        guard let url = parts.url else { copyAddress(); return }
        openURL(url) { accepted in
            if !accepted { copyAddress() }
        }
    }

    private func copyAddress() {
        UIPasteboard.general.string = Self.address
        copied = true
    }
}

/// The system Mail composer, addressed to Skinstel.
private struct FeedbackMailView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let onFinish: @MainActor (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([FeedbackSheet.address])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: @MainActor (Bool) -> Void
        init(onFinish: @escaping @MainActor (Bool) -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            let sent = result == .sent
            Task { @MainActor in onFinish(sent) }
        }
    }
}
