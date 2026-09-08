import SwiftUI
import SkintelCore

/// Design §09: the barcode hit slides up and analysis starts immediately — no confirm
/// step. Also hosts the not-found / failed / needs-INCI states of the same flow.
struct FoundSheet: View {
    @Bindable var model: ScanFlowModel
    @Environment(AppEnvironment.self) private var env
    @State private var pastedINCI = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            switch model.phase {
            case .lookingUp(let upc):
                header(name: upc.isEmpty ? "Reading…" : "Looking up \(upc)", sub: upc.isEmpty ? "" : "\(spaced(upc)) · searching")
                progressCard(title: "Checking product databases…", subtitle: "Cache, Open Beauty Facts, then AI search")
            case .found(let c):
                header(name: c.displayName, sub: c.upc.map { "\(spaced($0)) · matched ✓" } ?? "matched ✓")
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    Text("Found the product but not its ingredient list.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    SKTextEditor(placeholder: "Paste the INCI list from the packaging", text: $pastedINCI, minHeight: 90, mono: true)
                    SKButton(title: "Analyze") {
                        Task { await model.usePasted(brand: c.brand, name: c.productName, inci: pastedINCI) }
                    }
                    .disabled(INCI.parse(pastedINCI).isEmpty)
                }
            case .analyzing(let c):
                header(name: c.displayName, sub: c.upc.map { "\(spaced($0)) · matched ✓" } ?? "\(c.source) · ready")
                progressCard(title: "Reading \(c.parsed.count) ingredients…",
                             subtitle: profileLine)
                HStack {
                    Text("Auto-confirmed — no extra taps").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    Spacer()
                    Button("Wrong product?") { model.reset() }
                        .font(SKFont.sans(15, weight: .semibold)).foregroundStyle(SKColor.primary)
                }
            case .notFound(let upc):
                header(name: "Not in our databases yet", sub: spaced(upc))
                Text("Paste the ingredient list from the packaging and Skintel will analyze it — this barcode gets remembered for everyone next time.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                SKTextEditor(placeholder: "Aqua, Glycerin, …", text: $pastedINCI, minHeight: 90, mono: true)
                HStack(spacing: SKSpace.md) {
                    SKButton(title: "Scan again", kind: .secondary) { model.reset() }
                    SKButton(title: "Analyze") { Task { await model.usePasted(brand: nil, name: nil, inci: pastedINCI) } }
                        .disabled(INCI.parse(pastedINCI).isEmpty)
                }
            case .failed(let e, let retry):
                header(name: e == .proRequired ? "Skintel Pro needed" : "That didn't work", sub: "")
                Text(e.userMessage).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                HStack(spacing: SKSpace.md) {
                    SKButton(title: "Back to camera", kind: .secondary) { model.reset() }
                    if let retry, e.isRetryable { SKButton(title: "Try again") { Task { await model.analyze(retry) } } }
                }
            case .scanning, .result:
                EmptyView()
            }
        }
        .skPagePadding()
        .padding(.top, SKSpace.xl)
        .padding(.bottom, SKSpace.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(SKAnimation.ios(0.3), value: model.phase)
        .interactiveDismissDisabled(model.isBusy)
    }

    private var profileLine: String {
        let p = env.session.user?.skinProfile.summary ?? ""
        let culprits = env.products.culprits.all.count
        if !p.isEmpty { return "Matching against \(p)" }
        return culprits > 0 ? "Matching against \(culprits) known trigger\(culprits == 1 ? "" : "s")" : "Matching against your shelf"
    }

    private func header(name: String, sub: String) -> some View {
        HStack(alignment: .top, spacing: SKSpace.lg) {
            SKProductMark(name: name, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(SKFont.sans(22, weight: .semibold, relativeTo: .title2)).foregroundStyle(SKColor.ink).lineLimit(2)
                if !sub.isEmpty { Text(sub).font(SKFont.dataSmall).foregroundStyle(SKColor.muted) }
            }
        }
    }

    private func progressCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            HStack(spacing: SKSpace.md) {
                ProgressView().tint(SKColor.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Text(subtitle).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
            }
            .padding(SKSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SKColor.cautionBg.opacity(0.6), in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.cautionFg.opacity(0.2)))
            IndeterminateBar()
        }
    }

    private func spaced(_ upc: String) -> String {
        // "3606000537400" → "3 606000 537400", the EAN grouping on the packaging
        guard upc.count == 13 else { return upc }
        let s = Array(upc)
        return "\(s[0]) \(String(s[1...6])) \(String(s[7...12]))"
    }
}

/// Progress that fills to ~90% while the request is in flight — honest about not
/// knowing the exact progress, but not a frozen bar either.
private struct IndeterminateBar: View {
    @State private var fraction = 0.0
    var body: some View {
        SKProgressBar(fraction: fraction, height: 6)
            .onAppear { withAnimation(.easeOut(duration: 6)) { fraction = 0.9 } }
    }
}
