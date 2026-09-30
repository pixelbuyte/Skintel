import SwiftUI
import UIKit
import SkintelCore
import SkinstelMascot

// MARK: - Paste a link

/// "Paste a product link": the server fetches the page and pulls out the ingredient list
/// (`/api/lookup?mode=url`, Skintel+), then the list goes through the same analysis as a
/// barcode and the hub pushes the verdict. The clipboard is only checked for a link (which
/// iOS allows without asking) and read when the person taps, so iOS shows its paste prompt.
struct LinkImportView: View {
    let model: ScanFlowModel
    let startImport: (String) -> Void
    let retryAnalysis: (ScanCandidate) -> Void
    let cancel: () -> Void
    let typeItIn: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var link = ""
    @State private var clipboardHasLink = false
    @State private var clipboardNote: String?
    @FocusState private var fieldFocused: Bool

    private var target: URL? { ProductLink.url(from: link) }
    private var busy: Bool { model.isBusy }

    private var hostLine: String {
        guard let url = target, let host = ProductLink.host(url) else { return "Opening the product page" }
        return "Opening \(host)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    Text("Paste a product link")
                        .font(SKFont.section)
                        .foregroundStyle(SKColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Use the product's page on the brand's site or a shop. Skintel reads the ingredient list there and checks it the same way as a barcode scan.")
                        .font(SKFont.secondary)
                        .foregroundStyle(SKColor.muted)
                }

                if clipboardHasLink && link.isEmpty && !busy {
                    clipboardOffer
                }

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    HStack {
                        SKFieldLabel("Product page")
                        Spacer()
                        ClipboardPasteButton { text in use(text, importNow: false) }
                            .disabled(busy)
                    }
                    SKTextField(placeholder: "https://…", text: $link, keyboard: .URL, contentType: .URL,
                                autocapitalization: .never, submitLabel: .go) { start() }
                        .focused($fieldFocused)
                        .disabled(busy)
                    if let clipboardNote {
                        Text(clipboardNote).font(SKFont.caption).foregroundStyle(SKColor.muted)
                    }
                }

                SKButton(title: "Import", systemImage: "arrow.down.to.line") { start() }
                    .disabled(target == nil || busy)

                status
            }
            .skPagePadding()
            .padding(.vertical, SKSpace.lg)
            .padding(.bottom, SKSpace.xxl)
            .animation(reduceMotion ? nil : SKAnimation.ios(0.3), value: model.phase)
        }
        .scrollDismissesKeyboard(.interactively)
        .skPageBackground()
        .skNavigationTitle("Paste a link")
        .onAppear {
            if !busy { model.reset() }
            refreshClipboard()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshClipboard() }
        }
        .onChange(of: model.phase) { _, phase in
            // 402 from the import or the analysis: the same gate as the scanner.
            if case .failed(let e, _) = phase, e.requiresPaywall {
                model.reset()
                openPaywall(.scanner)
            }
        }
        .onDisappear { if busy { cancel() } }
    }

    // MARK: Clipboard

    private var clipboardOffer: some View {
        Button { pasteFromClipboard() } label: {
            HStack(spacing: SKSpace.md) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SKColor.primary)
                    .frame(width: 44, height: 44)
                    .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paste from clipboard").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Text("There's a link on your clipboard. Skintel only reads it if you tap.")
                        .font(SKFont.secondary)
                        .foregroundStyle(SKColor.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(SKSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.primary.opacity(0.25)))
            .contentShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// `hasURLs` doesn't read the clipboard, so iOS shows no prompt for it.
    private func refreshClipboard() {
        clipboardHasLink = UIPasteboard.general.hasURLs
    }

    /// Reads the clipboard only on this tap, then imports straight away.
    private func pasteFromClipboard() {
        let board = UIPasteboard.general
        clipboardHasLink = false
        guard let text = board.url?.absoluteString ?? board.string else {
            clipboardNote = "Nothing could be read from the clipboard."
            Haptics.warning()
            return
        }
        use(text, importNow: true)
    }

    private func use(_ text: String, importNow: Bool) {
        guard let found = ProductLink.url(from: text) else {
            clipboardNote = "There's no web link on the clipboard."
            Haptics.warning()
            return
        }
        clipboardNote = nil
        link = found.absoluteString
        if importNow { start() }
    }

    // MARK: Import

    private func start() {
        guard let url = target, !busy else { return }
        fieldFocused = false
        clipboardNote = nil
        guard env.subscription.entitlement.canUseScanner else { openPaywall(.scanner); return }
        startImport(url.absoluteString)
    }

    private func tryAnotherLink() {
        model.reset()
        link = ""
        fieldFocused = true
    }

    @ViewBuilder
    private var status: some View {
        switch model.phase {
        case .lookingUp:
            ImportProgressCard(title: "Fetching the page…",
                               detail: hostLine,
                               onCancel: cancel)
        case .analyzing(let c):
            ImportProgressCard(title: "Reading \(c.parsed.count) ingredients…",
                               detail: "\(c.displayName) · \(ImportCopy.checkLine(triggers: env.products.culprits.all.count))",
                               onCancel: cancel)
        case .failed(let e, let retry):
            failure(e, retry: retry)
        case .scanning, .found, .notFound, .result:
            EmptyView()
        }
    }

    @ViewBuilder
    private func failure(_ e: APIError, retry: ScanCandidate?) -> some View {
        if e.requiresPaywall {
            // The paywall is opening (see onChange); nothing to show here.
            EmptyView()
        } else if let retry {
            ImportFailureCard(title: "The page was read, but the check didn't finish.", message: e.userMessage) {
                if e.isRetryable {
                    SKButton(title: "Try again") { retryAnalysis(retry) }
                }
                SKButton(title: "Try another link", kind: .secondary) { tryAnotherLink() }
            }
        } else if ProductLink.pageUnreadable(e) {
            ImportFailureCard(title: "Couldn't read that page.",
                              message: "Paste the ingredient list instead. Some shops stop apps reading their pages; the brand's own page often works.") {
                SKButton(title: "Type it in", systemImage: "keyboard") { typeItIn() }
                SKButton(title: "Try another link", kind: .secondary) { tryAnotherLink() }
            }
        } else {
            ImportFailureCard(title: e == .offline ? "You're offline." : "That didn't work.", message: e.userMessage) {
                SKButton(title: "Try again") { start() }
                SKButton(title: "Type it in instead", kind: .secondary) { typeItIn() }
            }
        }
    }
}

// MARK: - Photograph the label

/// "Photograph the label": the hub opens the camera and starts the read; this page shows what
/// is happening, then the hub pushes the verdict. Retakes come back here.
struct PhotoImportView: View {
    let model: ScanFlowModel
    let takePhoto: () -> Void
    let retryAnalysis: (ScanCandidate) -> Void
    let cancel: () -> Void
    let typeItIn: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var permission: CameraPermission.Status = CameraPermission.status

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    Text("Photograph the label")
                        .font(SKFont.section)
                        .foregroundStyle(SKColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Fit the whole ingredient list in the frame, flat and in focus. Skintel reads it and checks it the same way as a barcode scan.")
                        .font(SKFont.secondary)
                        .foregroundStyle(SKColor.muted)
                }

                switch model.phase {
                case .lookingUp:
                    ImportProgressCard(title: "Reading the label…",
                                       detail: "Looking for the ingredient list in your photo",
                                       onCancel: cancel)
                case .analyzing(let c):
                    ImportProgressCard(title: "Reading \(c.parsed.count) ingredients…",
                                       detail: "\(c.displayName) · \(ImportCopy.checkLine(triggers: env.products.culprits.all.count))",
                                       onCancel: cancel)
                case .failed(let e, let retry):
                    failure(e, retry: retry)
                case .scanning, .found, .notFound, .result:
                    idle
                }
            }
            .skPagePadding()
            .padding(.vertical, SKSpace.lg)
            .padding(.bottom, SKSpace.xxl)
            .animation(reduceMotion ? nil : SKAnimation.ios(0.3), value: model.phase)
        }
        .skPageBackground()
        .skNavigationTitle("Label photo")
        .onAppear { permission = CameraPermission.status }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { permission = CameraPermission.status }
        }
        .onChange(of: model.phase) { _, phase in
            if case .failed(let e, _) = phase, e.requiresPaywall {
                model.reset()
                openPaywall(.scanner)
            }
        }
        .onDisappear { if model.isBusy { cancel() } }
    }

    @ViewBuilder
    private var idle: some View {
        switch permission {
        case .denied:
            ImportFailureCard(title: "Camera is off for Skintel",
                              message: "Turn it on in Settings to photograph labels, or type the product in.") {
                SKButton(title: "Open Settings") { CameraPermission.openSettings() }
                SKButton(title: "Type it in instead", kind: .secondary) { typeItIn() }
            }
        case .restricted:
            ImportFailureCard(title: "Camera access is restricted",
                              message: "This device doesn't allow Skintel to use the camera. You can type the product in instead.") {
                SKButton(title: "Type it in instead", kind: .secondary) { typeItIn() }
            }
        case .authorized, .notDetermined:
            SKButton(title: "Take a photo", systemImage: "camera") { takePhoto() }
            SKButton(title: "Type it in instead", kind: .secondary) { typeItIn() }
        }
    }

    @ViewBuilder
    private func failure(_ e: APIError, retry: ScanCandidate?) -> some View {
        if e.requiresPaywall {
            EmptyView()
        } else if let retry {
            ImportFailureCard(title: "The label was read, but the check didn't finish.", message: e.userMessage) {
                if e.isRetryable {
                    SKButton(title: "Try again") { retryAnalysis(retry) }
                }
                SKButton(title: "Retake photo", kind: .secondary) { takePhoto() }
            }
        } else {
            ImportFailureCard(title: e == .offline ? "You're offline." : "Couldn't read that label.", message: e.userMessage) {
                SKButton(title: "Retake photo", systemImage: "camera") { takePhoto() }
                SKButton(title: "Type it in instead", kind: .secondary) { typeItIn() }
            }
        }
    }
}

// MARK: - Shared pieces

enum ImportCopy {
    /// What the analysis compares against — only claims what `/api/scan-ai` is sent.
    static func checkLine(triggers: Int) -> String {
        triggers > 0 ? "checking against \(triggers) known trigger\(triggers == 1 ? "" : "s")" : "checking each ingredient"
    }
}

/// The in-flight card: the mascot scanning beside the step that is actually running, and a
/// way out. Only shown while a request is open.
struct ImportProgressCard: View {
    let title: String
    let detail: String
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.xs) {
            HStack(spacing: SKSpace.md) {
                SKMascot(action: .scan, height: 72)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Text(detail).font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(2)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
            }
            Button("Cancel", action: onCancel)
                .font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(SKColor.primary)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, SKSpace.lg)
        .padding(.top, SKSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKColor.blush, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.primary.opacity(0.15)))
    }
}

/// What went wrong, in plain words, with the next useful step underneath.
struct ImportFailureCard<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            HStack(alignment: .top, spacing: SKSpace.sm) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SKColor.badFg)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Text(message).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
            }
            .accessibilityElement(children: .combine)
            actions()
        }
        .padding(SKSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
    }
}

/// "Paste" that reads the clipboard only when tapped, so iOS can show its own paste prompt
/// and nothing is read behind the person's back.
struct ClipboardPasteButton: View {
    var title = "Paste"
    let onPaste: (String) -> Void

    var body: some View {
        Button {
            let board = UIPasteboard.general
            guard let text = board.string ?? board.url?.absoluteString,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Haptics.warning()
                return
            }
            Haptics.selection()
            onPaste(text)
        } label: {
            Label(title, systemImage: "doc.on.clipboard")
                .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(SKColor.primary)
                .padding(.horizontal, SKSpace.md)
                .frame(minHeight: 32)
                .background(SKColor.blush, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) from clipboard")
    }
}

/// Turning pasted text into the product page to import.
enum ProductLink {
    /// The http(s) page in `text`: a whole pasted address ("sephora.com/…" gets https://), or
    /// the first web link inside a longer paste ("Look at this: https://…").
    static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains(where: \.isWhitespace), let direct = web(trimmed) { return direct }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let matches = detector.matches(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed))
        for match in matches {
            guard let found = match.url, let scheme = found.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else { continue }
            if let url = web(found.absoluteString) { return url }
        }
        return nil
    }

    private static func web(_ s: String) -> URL? {
        let lower = s.lowercased()
        let full = (lower.hasPrefix("http://") || lower.hasPrefix("https://")) ? s : "https://" + s
        guard let parts = URLComponents(string: full),
              let scheme = parts.scheme?.lowercased(), scheme == "http" || scheme == "https",
              parts.user == nil,
              let host = parts.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix("."),
              let url = parts.url else { return nil }
        return url
    }

    /// "sephora.com" for the progress line.
    static func host(_ url: URL) -> String? {
        guard let h = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host, !h.isEmpty else { return nil }
        return h.lowercased().hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    /// The page itself couldn't be read (blocked, no list on it, not a product page, or the
    /// fetch failed): pasting the list is the way forward, not retrying.
    static func pageUnreadable(_ e: APIError) -> Bool {
        switch e {
        case .notFound, .unprocessable, .badRequest, .decoding: true
        case .server(let status, _): status == 502
        default: false
        }
    }
}
