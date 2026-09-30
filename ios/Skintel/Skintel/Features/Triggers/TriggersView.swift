import SwiftUI
import SkintelCore

/// Triggers (the screen was called "Culprits"; the web app renamed it, and the
/// `AppDestination.culprits` / `PaywallReason.culprits` case names stay for compatibility).
/// Two real signals: the local co-occurrence engine (an ingredient shared by ≥2 products
/// marked "broke out", `Correlate`) and, for Skintel+, the journal AI's suspects.
/// Before the threshold it shows real progress toward it and a way to the shelf, so the
/// screen is never a dead end.
struct TriggersView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @State private var expanded: Set<String> = []
    @State private var demo: PaywallReason?
    @State private var showShelf = false

    /// `Correlate.run` needs an ingredient in at least this many "broke out" products.
    private static let threshold = 2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Triggers").font(SKFont.pageTitle).foregroundStyle(SKColor.ink).padding(.leading, 44)
                        .accessibilityAddTraits(.isHeader)
                    Text("Ingredients your breakouts share").font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                }
                .padding(.top, SKSpace.sm)

                shelfSection
                journalSection
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.xxl)
        }
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackButton() }
        .onAppear { env.analytics.track(.culpritViewed) }
        .sheet(isPresented: $showShelf) { ShelfTab() }
        .sheet(item: $demo) { reason in
            FeatureDemoSheet(reason: reason,
                             title: reason == .culprits ? "What you'll see" : "What your journal will show",
                             message: reason == .culprits
                                ? "Once two products are marked “broke out”, Skintel compares their ingredient lists and names what they share."
                                : "After a few check-ins, Skintel lines them up with when each product joined your shelf and names what keeps showing up before a bad day.")
        }
    }

    // MARK: Shelf co-occurrence

    @ViewBuilder
    private var shelfSection: some View {
        if env.products.isLoaded {
            let r = env.products.culprits
            let bad = env.products.badProductCount
            if bad < Self.threshold {
                progressCard(bad: bad)
            } else if r.all.isEmpty {
                nothingSharedCard(bad: bad)
            } else {
                foundHeader(count: r.all.count)
                ForEach(r.high) { triggerCard($0, label: "Top suspect", tone: .bad) }
                ForEach(r.medium) { triggerCard($0, label: "Watching", tone: .caution) }
            }
        } else if let e = env.products.state.error {
            SKErrorState(error: e) { Task { await env.products.load() } }
        } else {
            SKSkeleton(height: 220)
        }
    }

    /// "Broke out" products saved without an ingredient list count toward the two, but
    /// `Correlate` has nothing of theirs to compare.
    private var badWithoutIngredients: Int {
        env.products.products.filter { $0.product.outcome == .bad && $0.ingredients.isEmpty }.count
    }

    /// Before the threshold: honest progress, how to get there, and the way to the shelf.
    private func progressCard(bad: Int) -> some View {
        let missing = badWithoutIngredients
        let missingLine: String = missing == 1
            ? "1 of your “broke out” products has no ingredient list yet."
            : "\(missing) of your “broke out” products have no ingredient list yet."
        return SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(spacing: SKSpace.md) {
                    SKDrop("DropInsights", size: 88)
                    Text("Find your triggers").font(SKFont.section).foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Mark \(Self.threshold) products as “broke out” to find shared ingredients — \(bad) of \(Self.threshold) so far.")
                    .font(SKFont.body).foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                SKProgressBar(fraction: Double(bad) / Double(Self.threshold), height: 6)
                Text("On your shelf, open a product, tap Edit and choose Broke out. It needs its ingredient list to count.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if missing > 0 {
                    Text(missingLine)
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                SKButton(title: "Go to your shelf", systemImage: "tray.full") { showShelf = true }
                SKLinkButton(title: "See an example") { demo = .culprits }
            }
        }
    }

    private func nothingSharedCard(bad: Int) -> some View {
        let missing = badWithoutIngredients
        let detail: String
        if missing == 0 {
            detail = "Keep marking products as they break you out and Skintel checks again each time."
        } else if missing == 1 {
            detail = "1 of them has no ingredient list, so it can't be compared yet. Add the list on your shelf."
        } else {
            detail = "\(missing) of them have no ingredient list, so they can't be compared yet. Add the lists on your shelf."
        }
        return SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(spacing: SKSpace.md) {
                    SKDrop("DropInsights", size: 88)
                    Text("Nothing shared yet").font(SKFont.section).foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Your \(bad) “broke out” products don't have an ingredient in common.")
                    .font(SKFont.body).foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SKButton(title: "Go to your shelf", kind: .secondary, systemImage: "tray.full") { showShelf = true }
            }
        }
    }

    private func foundHeader(count: Int) -> some View {
        HStack(spacing: SKSpace.md) {
            SKDrop("DropWarning", size: 88)
            VStack(alignment: .leading, spacing: 4) {
                Text(count == 1 ? "1 possible trigger" : "\(count) possible triggers")
                    .font(SKFont.section).foregroundStyle(SKColor.ink)
                Text("Each is in 2 or more products that broke you out. A pattern to test, not proof.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func triggerCard(_ c: Culprit, label: String, tone: SKTone) -> some View {
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
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SKColor.primary)
                        .accessibilityHidden(true)
                    Text(whyItMatters(c))
                        .font(SKFont.secondary).foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
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
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// One line on what the co-occurrence means for the person. It is a pattern across
    /// their own "broke out" products, never proof of cause.
    private func whyItMatters(_ c: Culprit) -> String {
        c.goodCount > 0
            ? "Why it matters: it could be the amount or the mix, so test it before cutting it out."
            : "Why it matters: it's the likeliest link between your breakouts. Check labels for it; scans flag it too."
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
                            SKLinkButton(title: "See an example") { demo = .journalAnalysis }
                        }
                    }
                }
            case .loading:
                SKCard { HStack(spacing: SKSpace.md) { ProgressView().tint(SKColor.primary); Text("Reading your journal…").font(SKFont.secondary).foregroundStyle(SKColor.muted) } }
            case .failed(let e):
                SKCard { VStack(alignment: .leading, spacing: SKSpace.md) { SKInlineError(message: e.userMessage); SKButton(title: "Try again", kind: .secondary) { Task { await analyze() } } } }
            case .loaded(let a):
                if a.suspects.isEmpty {
                    // An SF symbol, not a drop: the shelf section above already has this screen's one drop.
                    SKCard(tint: .good) {
                        HStack(spacing: SKSpace.md) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(SKColor.goodFg)
                                .frame(width: 48, height: 48)
                                .background(SKColor.goodBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("No clear suspect yet").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                                Text(a.summary ?? "Keep logging — every entry sharpens detection.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                            }
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
