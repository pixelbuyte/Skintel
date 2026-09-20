import SwiftUI
import SkintelCore

/// A daily starting point: the next routine, a scan action, and the user's real shelf.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openScanner) private var openScanner
    @State private var path: [AppDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                header
                content
            }
            .skPagePadding()
            .padding(.top, SKSpace.sm)
            .padding(.bottom, SKSpace.xxl)
            .skMascotRefreshable { await env.products.load(); await env.subscription.load() }
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
                    .font(SKFont.editorial(30, relativeTo: .largeTitle))
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
                routineCard
                quickActions
                stats
                recentScans(products)
                suspectCard
                recommendRow
            }
        }
    }

    private var emptyShelf: some View {
        VStack(spacing: SKSpace.lg) {
            SKCard {
                VStack(spacing: SKSpace.lg) {
                    SKMascot(size: 112)
                    Text("Start with one product.")
                        .font(SKFont.editorial(28, relativeTo: .title))
                        .foregroundStyle(SKColor.ink)
                        .multilineTextAlignment(.center)
                    Text("Check its ingredients, save it to your shelf, and keep track of how your skin feels.")
                        .font(SKFont.body).foregroundStyle(SKColor.muted)
                        .multilineTextAlignment(.center)
                    SKButton(title: "Scan your first product", systemImage: "barcode.viewfinder") { openScanner() }
                    SKLinkButton(title: "Add ingredients by hand", chevron: false) {
                        path.append(.productForm(.add(prefill: nil)))
                    }
                }
                .padding(.vertical, SKSpace.md)
            }
            routineCard
        }
    }

    private var quickActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SKSpace.md) {
                SKButton(title: "Scan a product", systemImage: "barcode.viewfinder") { openScanner() }
                SKButton(title: "My shelf", kind: .secondary, fullWidth: false) { path.append(.products) }
            }
            VStack(spacing: SKSpace.md) {
                SKButton(title: "Scan a product", systemImage: "barcode.viewfinder") { openScanner() }
                SKButton(title: "My shelf", kind: .secondary) { path.append(.products) }
            }
        }
    }

    private var stats: some View {
        let c = env.products.counts
        return SKCard(padding: SKSpace.md) {
            HStack(spacing: SKSpace.sm) {
                statTile(c.total, "Saved", SKColor.ink)
                statTile(c.good, "Worked", SKColor.goodFg)
                statTile(c.unsure, "Unsure", SKColor.cautionFg)
                statTile(c.bad, "Broke out", SKColor.badFg)
            }
        }
    }

    private func statTile(_ n: Int, _ label: String, _ color: Color) -> some View {
        Button { path.append(.products) } label: {
            VStack(spacing: 6) {
                Text("\(n)").font(SKFont.sans(24, weight: .semibold, relativeTo: .title2)).foregroundStyle(color)
                Text(label).font(SKFont.sans(13, relativeTo: .caption)).foregroundStyle(SKColor.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SKSpace.sm)
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel("\(n) \(label)")
    }

    @ViewBuilder
    private var suspectCard: some View {
        let culprits = env.products.culprits
        if let top = culprits.all.first {
            Button { path.append(.culprits) } label: {
                SKCard {
                    HStack(spacing: SKSpace.lg) {
                        SKMascot(size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("A pattern worth a look")
                                .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            Text("\(top.name) appears in \(top.badCount) products you marked “Broke out”.")
                                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(SKColor.primary)
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
                        Text("Your skin has a story").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        Text("Log how products feel on your skin to start spotting shared ingredients.")
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
                    Text("YOUR DAILY CARE").skLabelStyle()
                    HStack {
                        Image(systemName: slot == .pm ? "moon.stars" : "sun.max")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(SKColor.primary)
                        Text(slot == .pm ? "Tonight's routine" : "This morning's routine")
                            .font(SKFont.editorial(24, relativeTo: .title2)).foregroundStyle(SKColor.ink)
                        Spacer()
                        Text(slot.rawValue).font(SKFont.sans(13, weight: .semibold)).foregroundStyle(SKColor.muted)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(SKColor.neutralChip, in: Capsule())
                    }
                    if ids.isEmpty {
                        Text("A simple routine starts with the products you already have.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        Label("Build your routine", systemImage: "arrow.right")
                            .font(SKFont.bodyMedium).foregroundStyle(SKColor.primary)
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
                        HStack {
                            Text(progress.done == progress.total ? "All done. A little care, every day." : "Pick up where you left off")
                                .font(SKFont.secondary).foregroundStyle(SKColor.primary)
                            Spacer()
                            Image(systemName: "arrow.right").foregroundStyle(SKColor.primary)
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
            SKSectionHeader(title: "On your shelf", linkTitle: "See all") { path.append(.products) }
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
                        Text("Explore options based on your skin profile and past reactions.")
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
    @Environment(AppEnvironment.self) private var env
    let product: ProductWithIngredients
    var score: Int?

    var body: some View {
        SKCard(padding: SKSpace.md) {
            HStack(spacing: SKSpace.md) {
                SKProductMark(name: product.product.productName, imageURL: env.scans.imageURL(for: product.id))
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
