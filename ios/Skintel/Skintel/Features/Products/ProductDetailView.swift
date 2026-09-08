import SwiftUI
import SkintelCore

/// Design §11: INCI list with a category chip and a personal verdict dot per row, and
/// the AI insight (the stored `/api/scan-ai` result) on the second tab.
struct ProductDetailView: View {
    let productID: String
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @Environment(\.dismiss) private var dismiss

    private enum Tab: Hashable { case ingredients, insight }
    @State private var tab: Tab = .ingredients
    @State private var showAll = false
    @State private var analyzing = false
    @State private var analyzeError: String?
    @State private var confirmDelete = false
    @State private var routineSlot: RoutineStore.Slot?

    var body: some View {
        if let p = env.products.product(id: productID) {
            content(p)
        } else {
            SKEmptyState(icon: "questionmark.circle", title: "Product not found", message: "It may have been deleted on another device.")
                .skPageBackground()
        }
    }

    private func content(_ p: ProductWithIngredients) -> some View {
        let scan = env.scans.result(for: p.id)
        let culprits = env.products.culprits.byNormalized
        return ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                HStack(alignment: .top, spacing: SKSpace.lg) {
                    SKProductMark(name: p.product.productName, size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        if let b = p.product.brand, !b.isEmpty { Text(b).skLabelStyle() }
                        Text(p.product.productName).font(SKFont.serif(26, relativeTo: .title2)).foregroundStyle(SKColor.ink)
                        HStack(spacing: SKSpace.sm) {
                            if let scan {
                                SKChip("\(scan.score) · \(scan.verdict.label)", tone: scan.verdict.tone)
                            } else {
                                SKChip(p.product.outcome.label, tone: p.product.outcome.tone)
                            }
                            if let c = p.product.category, !c.isEmpty { SKChip(c) }
                        }
                    }
                }

                SKSegmented(options: [(Tab.ingredients, "Ingredients · \(p.ingredients.count)"), (Tab.insight, "AI insight")], selection: $tab)

                switch tab {
                case .ingredients: ingredientList(p, culprits: culprits)
                case .insight: insight(p, scan: scan)
                }

                if let n = p.product.notes, !n.isEmpty {
                    VStack(alignment: .leading, spacing: SKSpace.sm) {
                        SKFieldLabel("Notes")
                        Text(n).font(SKFont.body).foregroundStyle(SKColor.ink)
                    }
                }
            }
            .skPagePadding()
            .padding(.vertical, SKSpace.md)
            .padding(.bottom, SKSpace.xxl)
        }
        .skPageBackground()
        .skNavigationTitle("Product")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink(value: AppDestination.productForm(.edit(productID: p.id))) { Label("Edit", systemImage: "pencil") }
                    Button { routineSlot = .am } label: { Label("Add to AM routine", systemImage: "sun.max") }
                    Button { routineSlot = .pm } label: { Label("Add to PM routine", systemImage: "moon") }
                    Divider()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("More")
            }
        }
        .navigationDestination(for: AppDestination.self) { d in
            if case .productForm(let mode) = d { ProductFormView(mode: mode) }
        }
        .confirmationDialog("Delete \(p.product.productName)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await env.products.delete(id: p.id)
                        env.scans.remove(productID: p.id)
                        env.routine.remove(p.id, from: .am); env.routine.remove(p.id, from: .pm)
                        Haptics.success(); dismiss()
                    } catch { analyzeError = (error as? APIError)?.userMessage ?? error.localizedDescription }
                }
            }
        }
        .onChange(of: routineSlot) { _, slot in
            guard let slot else { return }
            env.routine.add(p.id, to: slot)
            Haptics.success()
            routineSlot = nil
        }
        .alert("Something went wrong", isPresented: Binding(get: { analyzeError != nil }, set: { if !$0 { analyzeError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(analyzeError ?? "") }
    }

    // MARK: Ingredients

    private func ingredientList(_ p: ProductWithIngredients, culprits: [String: Culprit]) -> some View {
        let rows = p.ingredients
        let visible = showAll ? rows : Array(rows.prefix(6))
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            if rows.isEmpty {
                SKEmptyState(icon: "list.bullet", title: "No ingredients yet",
                             message: "Edit this product and paste the INCI list from the packaging.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { i, ing in
                        let row = classify(ing, culprits: culprits)
                        SKRow(showDivider: i < visible.count - 1) {
                            HStack(spacing: SKSpace.md) {
                                SKDot(tone: row.tone)
                                Text(ing.inciRaw).font(SKFont.data).foregroundStyle(SKColor.ink).lineLimit(1)
                            }
                        } trailing: {
                            SKChip(row.chip, tone: row.tone)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(ing.inciRaw), \(row.chip)")
                    }
                }
                .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
                .skCardShadow()

                if rows.count > 6 {
                    Button { withAnimation(SKAnimation.ios(0.3)) { showAll.toggle() } } label: {
                        Text(showAll ? "Show fewer ▴" : "Show all \(rows.count) ingredients ▾")
                            .font(SKFont.sans(15, weight: .semibold)).foregroundStyle(SKColor.primary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func classify(_ ing: ProductIngredient, culprits: [String: Culprit]) -> (tone: SKTone, chip: String) {
        if culprits[ing.inciNormalized] != nil { return (.bad, "Trigger") }
        if IngredientKnowledge.isFragrance(ing.inciRaw) { return (.caution, "Fragrance") }
        if let info = IngredientKnowledge.lookup(ing.inciRaw) {
            let positive = IngredientKnowledge.positiveCategories.contains(info.category)
            return (positive ? .good : .neutral, info.category.label)
        }
        return (.neutral, "Other")
    }

    // MARK: AI insight

    @ViewBuilder
    private func insight(_ p: ProductWithIngredients, scan: ScanResult?) -> some View {
        if let scan {
            VerdictCard(result: scan, goodCount: goodCount(p))
            FlagList(result: scan)
        } else if p.ingredients.isEmpty {
            SKEmptyState(icon: "sparkles", title: "Nothing to analyze", message: "Add the ingredient list first.")
        } else {
            SKCard {
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    Text("No AI verdict yet").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Text("Skintel scores every ingredient against your shelf's culprits and returns a plain-English verdict.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    if let analyzeError { SKInlineError(message: analyzeError) }
                    SKButton(title: "Analyze with AI", systemImage: "sparkles", isLoading: analyzing) { Task { await analyze(p) } }
                }
            }
        }
    }

    private func goodCount(_ p: ProductWithIngredients) -> Int {
        let parsed = p.ingredients.map { INCI.ParsedIngredient(raw: $0.inciRaw, normalized: $0.inciNormalized, position: $0.position) }
        return IngredientKnowledge.categorize(parsed, culpritsByNormalized: env.products.culprits.byNormalized).good.count
    }

    private func analyze(_ p: ProductWithIngredients) async {
        guard env.subscription.entitlement.canUseScanner else { openPaywall(.scanner); return }
        analyzing = true; analyzeError = nil
        defer { analyzing = false }
        let inci = p.ingredients.map(\.inciRaw).joined(separator: ", ")
        let matches = env.products.culprits.all.map(ScanAIRequest.Match.init)
        do {
            let result = try await env.api.scan(ScanAIRequest(inci: inci, matches: matches))
            env.scans.record(productID: p.id, brand: p.product.brand, productName: p.product.productName, inci: inci, source: "shelf", result: result)
            env.analytics.track(.scanCompleted(verdict: result.verdict.rawValue))
            Haptics.success()
        } catch let e as APIError where e.requiresPaywall {
            openPaywall(.scanner)
        } catch {
            analyzeError = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }
}
