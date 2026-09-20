import SwiftUI
import SkintelCore

/// The first sixty seconds, not a census of the shelf.
///
/// She opens this mid-morning, one hand, part-way through a routine. So the routine is the
/// hero and its steps tick off *here* — walking to another screen to tap a checkbox was the
/// old design's real cost. Under it sits exactly one thing to do next (`HomeFocus`) and one
/// thing Skintel noticed, drawn from the same `JournalInsight` engine Journal uses so the
/// app speaks with one voice instead of three.
///
/// The four shelf counters are gone on purpose: they were four taps to the same list,
/// dressed up as information. Everything that survived goes somewhere different.
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
                // `skPetRefresh` scopes `.tint(.clear)` to kill the system wheel; put the
                // real tint back on the page content so nothing else inherits clear.
                .tint(SKColor.primary)
            }
            .skPetRefresh { await env.products.load(); await env.subscription.load() }
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
            // Shaped like what actually arrives, so the load-in settles instead of snapping.
            VStack(spacing: SKSpace.lg) {
                SKSkeleton(height: 210)
                SKSkeleton(height: 96)
                SKSkeleton(height: 120)
            }
        case .failed(let e):
            VStack(spacing: SKSpace.lg) {
                SKErrorState(error: e) { Task { await env.products.load() } }
                savedOnThisPhone
            }
        case .loaded(let products):
            if products.isEmpty {
                emptyShelf
            } else {
                routineCard
                nudgeCard
                noticedCard
                recentScans(products)
                recommendRow
            }
        }
    }

    /// The offline rescue block: when the shelf can't load, hand back her own data
    /// instead of a dead end. Both sources are already in memory, off disk, so this
    /// works with no network — `VerdictView` reads `env.scans.scans[scanID]` the same way.
    @ViewBuilder
    private var savedOnThisPhone: some View {
        let recent = Array(env.scans.recent.prefix(3))
        let progress = env.routine.progress(for: RoutineStore.currentSlot())
        if !recent.isEmpty || progress.total > 0 {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                SKSectionHeader(title: "Saved on this phone")

                if progress.total > 0 {
                    SKCard(padding: SKSpace.md) {
                        HStack(spacing: SKSpace.md) {
                            SKProgressBar(fraction: Double(progress.done) / Double(max(1, progress.total)))
                            Text("\(progress.done)/\(progress.total)")
                                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        }
                    }
                }

                ForEach(recent) { s in
                    Button { path.append(.verdict(scanID: s.id)) } label: {
                        SKCard(padding: SKSpace.md) {
                            HStack(spacing: SKSpace.md) {
                                SKProductMark(name: s.productName ?? "Product", size: 40, imageURL: s.imageURL)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.productName ?? "Scanned product")
                                        .font(SKFont.cardTitle).foregroundStyle(SKColor.ink).lineLimit(1)
                                    Text(DateFormatting.relative(s.scannedAt))
                                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                                }
                                Spacer(minLength: SKSpace.sm)
                                SKScoreBadge(score: s.result.score)
                            }
                        }
                    }
                    .buttonStyle(SKPressStyle())
                }
            }
        }
    }

    private var emptyShelf: some View {
        VStack(spacing: SKSpace.lg) {
            SKEmptyState(icon: "sparkles",
                         title: "Start with one product",
                         message: "Add what you used this morning and tell Skintel how your skin took it. The second product is where patterns start.",
                         actionTitle: "Add your first product") {
                path.append(.productForm(.add(prefill: nil)))
            }
            recommendRow
        }
    }

    /// One thing to do next, and it goes somewhere she can act — never to the same list
    /// the row below already links to.
    @ViewBuilder
    private var nudgeCard: some View {
        let unsure = env.products.products
            .filter { $0.product.outcome == .unsure }
            .sorted { $0.product.createdAt < $1.product.createdAt }
        let counts = env.products.counts
        let nudge = HomeFocus.nudge(productCount: counts.total,
                                    unsureProductIDs: unsure.map(\.id),
                                    decidedCount: counts.good + counts.bad,
                                    routineTotal: env.routine.ids(RoutineStore.currentSlot()).count)

        if nudge.kind != .allSet {
            Button { follow(nudge) } label: {
                SKCard {
                    HStack(spacing: SKSpace.lg) {
                        Image(systemName: nudgeIcon(nudge.kind))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(SKColor.primary)
                            .frame(width: 48, height: 48)
                            .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(nudge.headline).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            Text(nudge.detail)
                                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                    }
                }
            }
            .buttonStyle(SKPressStyle())
        }
    }

    private func nudgeIcon(_ kind: HomeFocus.Nudge.Kind) -> String {
        switch kind {
        case .firstProduct, .secondProduct: "plus.circle"
        case .markOutcomes: "questionmark.circle"
        case .buildRoutine: "list.bullet"
        case .allSet: "checkmark.circle"
        }
    }

    private func follow(_ nudge: HomeFocus.Nudge) {
        switch nudge.kind {
        case .firstProduct, .secondProduct: path.append(.productForm(.add(prefill: nil)))
        case .markOutcomes:
            if let id = nudge.productID { path.append(.productDetail(id: id)) } else { path.append(.products) }
        case .buildRoutine: path.append(.routine)
        case .allSet: break
        }
    }

    /// The top `JournalInsight` finding — the same engine, wording and caution thresholds
    /// Journal uses, so Home never claims something Journal would phrase more carefully.
    /// No red triangle: this is a pattern in her own log, not an alarm.
    @ViewBuilder
    private var noticedCard: some View {
        let findings = JournalInsight.findings(entries: env.journal.entries,
                                               usage: env.journalUsage.dayUsage,
                                               products: env.products.products,
                                               shelfFlagged: Set(env.products.culprits.byNormalized.keys),
                                               today: ISO8601.dayString(Date()))
        if let top = findings.first(where: { $0.kind != .gathering }) {
            let tint: SKTone? = switch top.mood {
            case .good: .good
            case .caution: .caution
            case .neutral: nil
            }
            Button { path.append(.culprits) } label: {
                SKCard(tint: tint) {
                    VStack(alignment: .leading, spacing: SKSpace.sm) {
                        Text("Skintel noticed").skLabelStyle()
                        Text(top.headline)
                            .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(top.detail)
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("See what your shelf shares ›")
                            .font(SKFont.sans(14, weight: .semibold)).foregroundStyle(SKColor.primary)
                            .padding(.top, 2)
                    }
                }
            }
            .buttonStyle(SKPressStyle())
        }
    }

    /// The hero. Steps tick off here rather than one screen away, because the whole point
    /// of this screen is the thirty seconds she is standing at the sink.
    @ViewBuilder
    private var routineCard: some View {
        let slot = RoutineStore.currentSlot()
        let ids = env.routine.ids(slot)
        let progress = env.routine.progress(for: slot)
        let left = max(0, progress.total - progress.done)

        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack {
                    Text(slot == .pm ? "Tonight" : "This morning")
                        .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Spacer()
                    Text(slot.rawValue).font(SKFont.sans(13, weight: .semibold)).foregroundStyle(SKColor.muted)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(SKColor.neutralChip, in: Capsule())
                }

                if ids.isEmpty {
                    Text("No steps yet. Build one from your shelf and Skintel can track what you actually use.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { path.append(.routine) } label: {
                        Text("Build your routine ›")
                            .font(SKFont.sans(14, weight: .semibold)).foregroundStyle(SKColor.primary)
                    }
                    .buttonStyle(SKPressStyle())
                } else {
                    HStack(spacing: SKSpace.md) {
                        SKProgressBar(fraction: Double(progress.done) / Double(max(1, progress.total)))
                        Text(left == 0 ? "All done" : "\(left) left")
                            .font(SKFont.secondary).foregroundStyle(left == 0 ? SKColor.goodFg : SKColor.muted)
                    }

                    VStack(spacing: SKSpace.sm) {
                        ForEach(ids.prefix(4), id: \.self) { id in homeStep(id) }
                    }

                    Button { path.append(.routine) } label: {
                        Text(ids.count > 4 ? "All \(ids.count) steps ›" : "Edit routine ›")
                            .font(SKFont.sans(14, weight: .semibold)).foregroundStyle(SKColor.primary)
                    }
                    .buttonStyle(SKPressStyle())
                }
            }
        }
    }

    /// A tick target, not a link: tapping marks the step done without leaving Home.
    private func homeStep(_ id: String) -> some View {
        let done = env.routine.isDone(id)
        let name = env.products.product(id: id)?.product.productName ?? "Removed product"
        return Button {
            env.routine.toggleDone(id)
            Haptics.selection()
        } label: {
            HStack(spacing: SKSpace.md) {
                ZStack {
                    Circle()
                        .fill(done ? SKColor.goodBg : SKColor.neutralChip)
                        .frame(width: 28, height: 28)
                    if done {
                        Text("✓").font(SKFont.sans(14, weight: .semibold)).foregroundStyle(SKColor.goodFg)
                    }
                }
                Text(name)
                    .font(SKFont.body).foregroundStyle(done ? SKColor.muted : SKColor.ink)
                    .strikethrough(done, color: SKColor.muted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel("\(name), \(done ? "done" : "not done")")
        .accessibilityHint("Double-tap to mark \(done ? "not done" : "done")")
    }

    private func recentScans(_ products: [ProductWithIngredients]) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            SKSectionHeader(title: "Recent scans", linkTitle: "Shelf") { path.append(.products) }
            ForEach(products.prefix(3)) { p in
                Button { path.append(.productDetail(id: p.id)) } label: {
                    ProductRow(product: p, score: env.scans.score(for: p.id), imageURL: env.scans.imageURL(for: p.id))
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
    /// Injected like `score` rather than read from the environment, so the row stays a
    /// pure view. Nil is the normal case — most products have no photo anywhere.
    var imageURL: String? = nil

    var body: some View {
        SKCard(padding: SKSpace.md) {
            HStack(spacing: SKSpace.md) {
                SKProductMark(name: product.product.productName, imageURL: imageURL)
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
