import SwiftUI
import SkintelCore

/// Design §07. Answers "what should I do next?": the four shelf counts, the top
/// suspect, tonight's routine progress, and recent products with their scores.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var path: [AppDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    header
                    content
                }
                .skPagePadding()
                .padding(.top, SKSpace.sm)
                .padding(.bottom, SKSpace.xxl)
            }
            .refreshable { await env.products.load(); await env.subscription.load() }
            .skPageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppDestination.self) { destination(for: $0) }
        }
        .tint(SKColor.primary)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                Text(DateFormatting.header()).skLabelStyle()
                Text("\(DateFormatting.greeting()), \(env.session.user?.firstName ?? "there")")
                    .font(SKFont.greeting)
                    .foregroundStyle(SKColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            Button { path.append(.settings) } label: {
                SKAvatar(name: env.session.user?.displayName ?? env.session.user?.email)
            }
            .buttonStyle(SKPressStyle(scale: 0.92))
            .accessibilityLabel("Settings")
        }
        .padding(.top, SKSpace.md)
    }

    // MARK: Body

    @ViewBuilder
    private var content: some View {
        switch env.products.state {
        case .idle, .loading:
            VStack(spacing: SKSpace.md) {
                HStack(spacing: SKSpace.md) { ForEach(0..<4, id: \.self) { _ in SKSkeleton(height: 92) } }
                SKSkeleton(height: 110)
                SKSkeleton(height: 170)
            }
        case .failed(let e):
            SKErrorState(error: e) { Task { await env.products.load() } }
        case .loaded(let products):
            if products.isEmpty {
                emptyShelf
            } else {
                stats
                suspectCard
                routineCard
                recentScans(products)
                recommendRow
            }
        }
    }

    private var emptyShelf: some View {
        VStack(spacing: SKSpace.lg) {
            SKEmptyState(icon: "sparkles",
                         title: "Your shelf is empty",
                         message: "Scan a product or paste its ingredient list, then tell Skintel how your skin reacted. Patterns start with the second product.",
                         actionTitle: "Add your first product") {
                path.append(.productForm(.add(prefill: nil)))
            }
            recommendRow
        }
    }

    private var stats: some View {
        let c = env.products.counts
        return HStack(spacing: SKSpace.md) {
            statTile(c.total, "Logged", SKColor.ink)
            statTile(c.good, "Worked", SKColor.goodFg)
            statTile(c.unsure, "Unsure", SKColor.cautionFg)
            statTile(c.bad, "Broke out", SKColor.badFg)
        }
    }

    private func statTile(_ n: Int, _ label: String, _ color: Color) -> some View {
        Button { path.append(.products) } label: {
            VStack(spacing: 6) {
                Text("\(n)").font(SKFont.stat).foregroundStyle(color)
                Text(label).font(SKFont.sans(13, relativeTo: .caption)).foregroundStyle(SKColor.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SKSpace.lg)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
            .skCardShadow()
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel("\(n) \(label)")
    }

    @ViewBuilder
    private var suspectCard: some View {
        let culprits = env.products.culprits
        if let top = culprits.all.first {
            Button { path.append(.culprits) } label: {
                SKCard(tint: .bad) {
                    HStack(spacing: SKSpace.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(SKColor.badFg)
                            .frame(width: 48, height: 48)
                            .background(SKColor.badBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(culprits.all.count == 1 ? "1 suspect found" : "\(culprits.all.count) suspects found")
                                .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            Text("\(top.name) is in \(top.badCount) products that broke you out")
                                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Text("Review ›").font(SKFont.sans(15, weight: .semibold)).foregroundStyle(SKColor.badFg)
                    }
                }
            }
            .buttonStyle(SKPressStyle())
        } else if env.products.badProductCount < 2 {
            SKCard {
                HStack(spacing: SKSpace.lg) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.primary)
                        .frame(width: 48, height: 48)
                        .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No suspects yet").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        Text("Mark two products as “Broke out” and Skintel finds what they share.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }
                }
            }
        }
    }

    private var routineCard: some View {
        let slot = RoutineStore.currentSlot()
        let ids = env.routine.ids(slot)
        let progress = env.routine.progress(for: slot)
        return Button { path.append(.routine) } label: {
            SKCard {
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    HStack {
                        Text(slot == .pm ? "Tonight's routine" : "This morning's routine")
                            .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        Spacer()
                        Text(slot.rawValue).font(SKFont.sans(13, weight: .semibold)).foregroundStyle(SKColor.muted)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(SKColor.neutralChip, in: Capsule())
                    }
                    if ids.isEmpty {
                        Text("No steps yet — build it from your shelf.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    } else {
                        HStack(spacing: SKSpace.md) {
                            SKProgressBar(fraction: Double(progress.done) / Double(max(1, progress.total)))
                            Text("\(progress.done)/\(progress.total)").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        }
                        FlowLayout(spacing: SKSpace.sm) {
                            ForEach(ids.prefix(4), id: \.self) { id in
                                let done = env.routine.isDone(id)
                                let name = env.products.product(id: id)?.product.productName ?? "Product"
                                SKChip(done ? "✓ \(shortName(name))" : shortName(name), tone: done ? .good : .neutral)
                            }
                            if ids.count > 4 { SKChip("+\(ids.count - 4)") }
                        }
                    }
                }
            }
        }
        .buttonStyle(SKPressStyle())
    }

    private func shortName(_ s: String) -> String {
        let words = s.split(separator: " ")
        return words.count > 2 ? words.prefix(2).joined(separator: " ") + "…" : s
    }

    private func recentScans(_ products: [ProductWithIngredients]) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            SKSectionHeader(title: "Recent scans", linkTitle: "Shelf") { path.append(.products) }
            ForEach(products.prefix(3)) { p in
                Button { path.append(.productDetail(id: p.id)) } label: {
                    ProductRow(product: p, score: env.scans.score(for: p.id))
                }
                .buttonStyle(SKPressStyle())
            }
        }
    }

    private var recommendRow: some View {
        Button { path.append(.recommend) } label: {
            SKCard {
                HStack(spacing: SKSpace.lg) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.primary)
                        .frame(width: 48, height: 48)
                        .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Find a product that fits").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        Text("Picks built around what your shelf says works and what doesn't.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                }
            }
        }
        .buttonStyle(SKPressStyle())
    }

    // MARK: Destinations

    @ViewBuilder
    func destination(for d: AppDestination) -> some View {
        switch d {
        case .products: ProductsListView()
        case .productDetail(let id): ProductDetailView(productID: id)
        case .productForm(let mode): ProductFormView(mode: mode)
        case .verdict(let scanID): VerdictView(scanID: scanID)
        case .culprits: CulpritsView()
        case .routine: RoutineView()
        case .recommend: RecommendView()
        case .settings: SettingsView()
        }
    }
}

/// Product row used on Home and the shelf list: mark, name, meta, score or outcome.
struct ProductRow: View {
    let product: ProductWithIngredients
    var score: Int?

    var body: some View {
        SKCard(padding: SKSpace.md) {
            HStack(spacing: SKSpace.md) {
                SKProductMark(name: product.product.productName)
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.product.productName)
                        .font(SKFont.cardTitle).foregroundStyle(SKColor.ink).lineLimit(1)
                    Text(meta).font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(1)
                }
                Spacer(minLength: SKSpace.sm)
                if let score { SKScoreBadge(score: score) }
                else { SKChip(product.product.outcome.label, tone: product.product.outcome.tone) }
            }
        }
    }

    private var meta: String {
        var parts: [String] = []
        if let d = ISO8601.date(product.product.createdAt) { parts.append("Added \(DateFormatting.relative(d))") }
        if let c = product.product.category, !c.isEmpty { parts.append(c) }
        else if let b = product.product.brand, !b.isEmpty { parts.append(b) }
        return parts.joined(separator: " · ")
    }
}
