import SwiftUI
import SkintelCore

/// Design §15 with the product's two real signals: the local co-occurrence engine
/// (an ingredient shared by ≥2 "broke out" products) and, for Pro, the journal AI's
/// suspects with confidence and evidence dates.
struct CulpritsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @State private var expanded: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Culprits").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                    Text("Shelf × journal correlation").font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                }
                .padding(.top, SKSpace.sm)

                let r = env.products.culprits
                if env.products.badProductCount < 2 {
                    gate
                } else if r.all.isEmpty {
                    SKCard {
                        VStack(alignment: .leading, spacing: SKSpace.sm) {
                            Text("Nothing shared yet").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            Text("Your \(env.products.badProductCount) “broke out” products don't have an ingredient in common. Add ingredient lists to more products to widen the net.")
                                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        }
                    }
                } else {
                    ForEach(r.high) { culpritCard($0, label: "Top suspect", tone: .bad) }
                    ForEach(r.medium) { culpritCard($0, label: "Watching", tone: .caution) }
                }

                journalSection
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.xxl)
        }
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackButton() }
        .onAppear { env.analytics.track(.culpritViewed) }
    }

    private var gate: some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text("Two “broke out” products unlock this").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                Text("Skintel compares the ingredient lists of everything that broke you out and surfaces what they share. You have \(env.products.badProductCount) so far.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                SKProgressBar(fraction: Double(env.products.badProductCount) / 2, tone: .bad, height: 6)
            }
        }
    }

    private func culpritCard(_ c: Culprit, label: String, tone: SKTone) -> some View {
        SKCard(tint: tone) {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack {
                    SKChip(label.uppercased(), tone: tone)
                    Spacer()
                    Text("in \(c.badCount) of \(env.products.badProductCount) breakouts").font(SKFont.dataSmall).foregroundStyle(tone.fg)
                }
                HStack(alignment: .top, spacing: SKSpace.md) {
                    SKProductMark(name: c.name, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.name).font(SKFont.sans(20, weight: .semibold, relativeTo: .title3)).foregroundStyle(SKColor.ink)
                        Text(c.goodCount > 0
                             ? "Also in \(c.goodCount) product\(c.goodCount == 1 ? "" : "s") that worked — could be a purge or a dose thing."
                             : "Never in anything that worked for you.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }
                }
                usageBars(c)
                if expanded.contains(c.id) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Broke out").skLabelStyle()
                        ForEach(c.badProducts, id: \.self) { Text("• \($0)").font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                        if !c.goodProducts.isEmpty {
                            Text("Worked").skLabelStyle().padding(.top, 4)
                            ForEach(c.goodProducts, id: \.self) { Text("• \($0)").font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                        }
                    }
                }
                Button {
                    withAnimation(SKAnimation.ios(0.3)) { if expanded.contains(c.id) { expanded.remove(c.id) } else { expanded.insert(c.id) } }
                } label: {
                    Text(expanded.contains(c.id) ? "Hide products ▴" : "Which products ▾")
                        .font(SKFont.sans(15, weight: .semibold)).foregroundStyle(tone.fg)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Bar per "broke out" product: tall red when it contains the ingredient, short grey when not.
    private func usageBars(_ c: Culprit) -> some View {
        let bad = env.products.products.filter { $0.product.outcome == .bad }
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(bad) { p in
                let hit = p.ingredients.contains { $0.inciNormalized == c.normalized }
                RoundedRectangle(cornerRadius: 4)
                    .fill(hit ? SKColor.badFg : SKColor.line)
                    .frame(height: hit ? 40 : 14)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("\(p.product.productName): \(hit ? "contains" : "does not contain") \(c.name)")
            }
        }
        .frame(height: 40)
    }

    // MARK: Journal AI

    @ViewBuilder
    private var journalSection: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("From your journal").font(SKFont.section).foregroundStyle(SKColor.ink).padding(.top, SKSpace.sm)
            switch env.journal.analysis {
            case .idle:
                SKCard {
                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        Text("Journal × timeline").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        Text("Breakouts usually show up 3–14 days after the trigger. Skintel lines up your last 90 days of entries with when each product joined your shelf.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        SKButton(title: "Analyze my journal", kind: .secondary, systemImage: "sparkles") { Task { await analyze() } }
                            .disabled(env.journal.entries.count < 3)
                        if env.journal.entries.count < 3 {
                            Text("Needs at least 3 journal entries.").font(SKFont.caption).foregroundStyle(SKColor.muted)
                        }
                    }
                }
            case .loading:
                SKCard { HStack(spacing: SKSpace.md) { ProgressView().tint(SKColor.primary); Text("Reading your journal…").font(SKFont.secondary).foregroundStyle(SKColor.muted) } }
            case .failed(let e):
                SKCard { VStack(alignment: .leading, spacing: SKSpace.md) { SKInlineError(message: e.userMessage); SKButton(title: "Try again", kind: .secondary) { Task { await analyze() } } } }
            case .loaded(let a):
                if a.suspects.isEmpty {
                    SKCard(tint: .good) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No clear suspect yet").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            Text(a.summary ?? "Keep logging — every entry sharpens detection.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        }
                    }
                }
                ForEach(a.suspects) { s in
                    let pct = s.confidencePercent ?? 0
                    SKCard(tint: pct >= 70 ? .bad : .caution) {
                        VStack(alignment: .leading, spacing: SKSpace.sm) {
                            HStack {
                                SKChip(pct >= 70 ? "SUSPECT" : "WATCHING", tone: pct >= 70 ? .bad : .caution)
                                Spacer()
                                if s.confidencePercent != nil { Text("\(pct)% confidence").font(SKFont.dataSmall).foregroundStyle(pct >= 70 ? SKColor.badFg : SKColor.cautionFg) }
                            }
                            Text(s.productOrIngredient).font(SKFont.sans(20, weight: .semibold, relativeTo: .title3)).foregroundStyle(SKColor.ink)
                            if let r = s.reasoning, !r.isEmpty { Text(r).font(SKFont.secondary).foregroundStyle(SKColor.muted) }
                            if let dates = s.evidenceDates?.values, !dates.isEmpty {
                                Text(dates.joined(separator: " · ")).font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                            }
                        }
                    }
                }
                if let recs = a.recommendations?.values, !recs.isEmpty {
                    SKCard {
                        VStack(alignment: .leading, spacing: SKSpace.sm) {
                            Text("What to try").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            ForEach(recs, id: \.self) { Text("• \($0)").font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                        }
                    }
                }
                SKButton(title: "Re-run analysis", kind: .ghost) { Task { await analyze() } }
            }
        }
    }

    private func analyze() async {
        guard env.subscription.entitlement.isPro else { openPaywall(.culprits); return }
        await env.journal.analyze()
        if case .failed(let e) = env.journal.analysis, e.requiresPaywall { openPaywall(.culprits) }
    }
}

/// Floating back chevron for screens that hide the system bar to show a serif title.
struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SKColor.ink).frame(width: 44, height: 44)
                .background(SKColor.cream.opacity(0.85), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.leading, SKSpace.md)
        .accessibilityLabel("Back")
    }
}
