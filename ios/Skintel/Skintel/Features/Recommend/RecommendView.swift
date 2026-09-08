import SwiftUI
import SkintelCore

/// Recommend.tsx: goal + budget → `/api/recommend`, which builds avoid/prefer lists from
/// the shelf server-side. Options are the web's six goals and three budget presets.
struct RecommendView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

    private struct Goal: Identifiable { let id: String; let label: String; let icon: String }
    private let goals: [Goal] = [
        .init(id: "cleanser", label: "Cleanser", icon: "drop"),
        .init(id: "moisturizer", label: "Moisturizer", icon: "square.stack"),
        .init(id: "serum", label: "Serum", icon: "flask"),
        .init(id: "sunscreen", label: "Sunscreen", icon: "sun.max"),
        .init(id: "toner", label: "Toner", icon: "wind"),
        .init(id: "exfoliant", label: "Exfoliant", icon: "flame"),
    ]
    private struct Budget: Identifiable { let id: String; let label: String; let max: Int; let hint: String }
    private let budgets: [Budget] = [
        .init(id: "drugstore", label: "Everyday", max: 20, hint: "≤ $20"),
        .init(id: "mid", label: "Mid", max: 50, hint: "≤ $50"),
        .init(id: "luxury", label: "Luxury", max: 100, hint: "≤ $100"),
    ]

    @State private var goal = "moisturizer"
    @State private var budget = "mid"
    @State private var notes = ""
    @State private var result: Loadable<RecommendResult> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.xl) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Find a product").font(SKFont.pageTitle).foregroundStyle(SKColor.ink).padding(.leading, 44)
                    Text("Picks that avoid what broke you out and lean on what worked.")
                        .font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                }
                .padding(.top, SKSpace.md)

                VStack(alignment: .leading, spacing: SKSpace.md) {
                    SKFieldLabel("I'm looking for a")
                    let cols = [GridItem(.flexible(), spacing: SKSpace.sm), GridItem(.flexible(), spacing: SKSpace.sm), GridItem(.flexible(), spacing: SKSpace.sm)]
                    LazyVGrid(columns: cols, spacing: SKSpace.sm) {
                        ForEach(goals) { g in
                            Button { goal = g.id; Haptics.selection() } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: g.icon).font(.system(size: 18, weight: .medium))
                                    Text(g.label).font(SKFont.sans(13, weight: .semibold, relativeTo: .caption))
                                }
                                .foregroundStyle(goal == g.id ? SKColor.primary : SKColor.ink)
                                .frame(maxWidth: .infinity).frame(height: 72)
                                .background(goal == g.id ? SKColor.blush : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(goal == g.id ? SKColor.primary : SKColor.line, lineWidth: goal == g.id ? 1.5 : 1))
                            }
                            .buttonStyle(SKPressStyle())
                            .accessibilityAddTraits(goal == g.id ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: SKSpace.md) {
                    SKFieldLabel("Budget")
                    HStack(spacing: SKSpace.sm) {
                        ForEach(budgets) { b in
                            Button { budget = b.id; Haptics.selection() } label: {
                                VStack(spacing: 4) {
                                    Text(b.label).font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                                    Text(b.hint).font(SKFont.dataSmall)
                                }
                                .foregroundStyle(budget == b.id ? SKColor.primary : SKColor.ink)
                                .frame(maxWidth: .infinity).frame(height: 64)
                                .background(budget == b.id ? SKColor.blush : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(budget == b.id ? SKColor.primary : SKColor.line, lineWidth: budget == b.id ? 1.5 : 1))
                            }
                            .buttonStyle(SKPressStyle())
                            .accessibilityAddTraits(budget == b.id ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    SKFieldLabel("Anything else")
                    SKTextEditor(placeholder: "Fragrance-free, no silicones, for under makeup…", text: $notes, minHeight: 80)
                }

                if case .failed(let e) = result { SKInlineError(message: e.userMessage) }
                SKButton(title: "Find products", systemImage: "wand.and.stars", isLoading: result.isLoading) { Task { await run() } }

                if case .loaded(let r) = result {
                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        Text("Picks for you").font(SKFont.section).foregroundStyle(SKColor.ink)
                        if r.recommendations.isEmpty {
                            Text("Nothing fit those constraints. Try a wider budget.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        }
                        ForEach(r.recommendations) { rec in
                            SKCard {
                                VStack(alignment: .leading, spacing: SKSpace.sm) {
                                    HStack(alignment: .top, spacing: SKSpace.md) {
                                        SKProductMark(name: rec.productName, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            if let b = rec.brand { Text(b).skLabelStyle() }
                                            Text(rec.productName).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                                        }
                                        Spacer()
                                        if let p = rec.priceRange { Text(p).font(SKFont.dataSmall).foregroundStyle(SKColor.muted) }
                                    }
                                    if let k = rec.keyIngredients?.values, !k.isEmpty {
                                        FlowLayout(spacing: 6) { ForEach(k.prefix(6), id: \.self) { SKChip($0, tone: .good) } }
                                    }
                                    if let why = rec.whyItFits, !why.isEmpty { Text(why).font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                                    if let w = rec.watchOuts, !w.isEmpty, w.lowercased() != "none" {
                                        Text("Watch: \(w)").font(SKFont.secondary).foregroundStyle(SKColor.cautionFg)
                                    }
                                }
                            }
                        }
                        Text("Suggestions are generated from your shelf's history. Check the ingredient list on the real packaging before buying.")
                            .font(SKFont.caption).foregroundStyle(SKColor.muted)
                    }
                }
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { BackButton().padding(.top, 2) }
    }

    private func run() async {
        guard env.subscription.entitlement.isPro else { openPaywall(.recommend); return }
        result = .loading
        let b = budgets.first { $0.id == budget }
        do {
            result = .loaded(try await env.api.recommend(RecommendRequest(goal: goal, budget: budget, maxPrice: b?.max, count: 5,
                                                                          notes: notes.isEmpty ? nil : String(notes.prefix(500)))))
            Haptics.success()
        } catch let e as APIError {
            if e.requiresPaywall { openPaywall(.recommend); result = .idle } else { result = .failed(e) }
        } catch { result = .failed(.network(error.localizedDescription)) }
    }
}
