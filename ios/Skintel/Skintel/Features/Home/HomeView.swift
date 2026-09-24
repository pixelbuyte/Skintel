import SwiftUI
import SkintelCore

/// Today: what to do right now. The current AM or PM routine as a tickable checklist, a
/// one-tap skin check-in, and only the alerts that need attention. Everything shown comes
/// from what the person has actually done: ticks, check-ins and their shelf.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @State private var path: [AppDestination] = []
    @State private var slot: RoutineStore.Slot = RoutineStore.currentSlot()
    @State private var showCheckIn = false
    @State private var showAssistant = false
    @AppStorage(AssistantPlacement.key) private var assistantPlacement = AssistantPlacement.tab
    @State private var moodError: String?
    @AppStorage(CheckInPrompt.enabledKey) private var autoPrompt = true
    @AppStorage(CheckInPrompt.lastKey) private var lastPrompt = ""
    @Environment(\.scenePhase) private var scenePhase

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
            .refreshable {
                await env.products.load()
                await env.subscription.load()
                await env.journal.load()
            }
            .skPageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppDestination.self) { destination(for: $0) }
        }
        .tint(SKColor.primary)
        .sheet(isPresented: $showCheckIn) { CheckInSheet() }
        .sheet(isPresented: $showAssistant) { AssistantView() }
        .task {
            await env.journal.load()
            promptCheckInIfDue()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await env.journal.load()
                promptCheckInIfDue()
            }
        }
    }

    /// Morning: ask when nothing is logged yet today. Evening: ask when tonight's part isn't
    /// answered. At most once per part of the day, and never over another sheet.
    private func promptCheckInIfDue() {
        guard autoPrompt, !showCheckIn, !showAssistant, env.journal.state.value != nil,
              !env.products.products.isEmpty, let part = CheckInPrompt.window() else { return }
        let key = "\(ISO8601.dayString(Date()))-\(part == .morning ? "am" : "pm")"
        guard lastPrompt != key else { return }
        let today = env.journal.today
        switch part {
        case .morning:
            guard today == nil else { return }
        case .night:
            guard !CheckInSheet.hasLine(today?.notes, prefix: CheckInSheet.todayPrefix) else { return }
        }
        lastPrompt = key
        showCheckIn = true
    }

    // MARK: Header

    private var header: some View {
        let amSteps = env.routine.ids(.am)
        let pmSteps = env.routine.ids(.pm)
        return HStack(alignment: .top, spacing: SKSpace.md) {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                Text(DateFormatting.header()).skLabelStyle()
                Text("\(DateFormatting.greeting()), \(env.session.user?.firstName ?? "there")")
                    .font(SKFont.greeting)
                    .foregroundStyle(SKColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if !amSteps.isEmpty || !pmSteps.isEmpty {
                    HStack(spacing: SKSpace.sm) {
                        if !amSteps.isEmpty {
                            let n = env.routine.daysCompleted(.am)
                            SKChip("AM \(n) of 7", tone: n >= 5 ? .good : .neutral)
                        }
                        if !pmSteps.isEmpty {
                            let n = env.routine.daysCompleted(.pm)
                            SKChip("PM \(n) of 7", tone: n >= 5 ? .good : .neutral)
                        }
                        Text("this week").font(SKFont.caption).foregroundStyle(SKColor.muted)
                    }
                }
            }
            if assistantPlacement == AssistantPlacement.corner {
                Spacer(minLength: 0)
                Button { showAssistant = true } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(SKColor.cream)
                        .frame(width: 50, height: 50)
                        .background(SKColor.primary, in: Circle())
                        .skPrimaryGlow(strength: 0.3)
                }
                .buttonStyle(SKPressStyle(scale: 0.92))
                .accessibilityLabel("Ask Skintel")
            }
        }
        .padding(.top, SKSpace.md)
    }

    // MARK: Body

    @ViewBuilder
    private var content: some View {
        switch env.products.state {
        case .idle, .loading:
            VStack(spacing: SKSpace.md) {
                SKSkeleton(height: 300)
                SKSkeleton(height: 150)
            }
        case .failed(let e):
            SKErrorState(error: e) { Task { await env.products.load() } }
        case .loaded(let products):
            if products.isEmpty {
                newUserCard
            } else {
                routineCard
                checkInCard
                askCard
                suspectCard
                recommendRow
            }
        }
    }

    private var newUserCard: some View {
        SKEmptyState(icon: "sparkles",
                     title: "Let's build your routine",
                     message: "Add what's on your bathroom shelf. Skintel puts it in order and flags anything that shouldn't be mixed.",
                     actionTitle: "Add your first product") {
            path.append(.productForm(.add(prefill: nil)))
        }
    }

    // MARK: Routine

    private var routineCard: some View {
        let steps = env.routine.ids(slot).compactMap { env.products.product(id: $0) }
        let done = steps.filter { env.routine.isDone($0.id) }.count
        let allDone = !steps.isEmpty && done == steps.count
        return SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(slot == .am ? "This morning" : "Tonight").font(SKFont.section).foregroundStyle(SKColor.ink)
                    Spacer()
                    if !steps.isEmpty {
                        Text("\(done) of \(steps.count)").font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                    }
                }
                SKSegmented(options: [(RoutineStore.Slot.am, "AM"), (.pm, "PM")], selection: $slot)
                if steps.isEmpty {
                    Text("No \(slot.rawValue) steps yet. Add products from your shelf and Skintel keeps them in order.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    SKButton(title: "Build your \(slot.rawValue) routine", kind: .secondary) { path.append(.routine) }
                } else {
                    SKProgressBar(fraction: Double(done) / Double(steps.count), height: 6)
                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, p in
                            if index > 0 { Rectangle().fill(SKColor.line).frame(height: 1) }
                            stepRow(index: index, product: p)
                        }
                    }
                    SKButton(title: allDone ? "\(slot.rawValue) routine done" : "Mark all done",
                             kind: allDone ? .done : .primary,
                             systemImage: allDone ? "checkmark" : nil) {
                        if !allDone {
                            env.routine.markAllDone(slot)
                            Haptics.success()
                        }
                    }
                }
            }
        }
    }

    private func stepRow(index: Int, product p: ProductWithIngredients) -> some View {
        let done = env.routine.isDone(p.id)
        return HStack(spacing: SKSpace.sm) {
            Button {
                env.routine.toggleDone(p.id, in: slot)
                if done { Haptics.selection() } else { Haptics.success() }
            } label: {
                ZStack {
                    Circle().fill(done ? SKColor.primary : SKColor.cream)
                    Circle().stroke(done ? SKColor.primary : SKColor.line, lineWidth: 1.5)
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SKColor.cream)
                    }
                }
                .frame(width: 28, height: 28)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Undo \(p.product.productName)" : "Mark \(p.product.productName) done")

            Button { path.append(.productDetail(id: p.id)) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(index + 1) · \((p.product.category ?? "Step").uppercased())")
                        .font(SKFont.mono(10.5)).tracking(1).foregroundStyle(SKColor.muted)
                    Text(p.product.productName)
                        .font(SKFont.sans(16, weight: .medium, relativeTo: .body))
                        .foregroundStyle(done ? SKColor.muted : SKColor.ink)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Skin check-in

    private var checkInCard: some View {
        let today = env.journal.today
        return SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(today == nil ? "How's your skin today?" : "Skin today").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Spacer()
                    Button("Add detail") { showCheckIn = true }
                        .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(SKColor.primary)
                }
                if env.journal.state.value != nil {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: SKSpace.sm), GridItem(.flexible(), spacing: SKSpace.sm)], spacing: SKSpace.sm) {
                        ForEach(JournalCondition.allCases, id: \.self) { c in
                            MoodChoiceButton(condition: c, selected: today?.condition == c) { quickSave(c) }
                        }
                    }
                    Text(today == nil ? "One tap is enough. Details are optional." : "Saved for today. Tap another to change it.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                } else if let e = env.journal.state.error {
                    SKInlineError(message: e.userMessage)
                    SKButton(title: "Try again", kind: .secondary) { Task { await env.journal.load() } }
                } else {
                    HStack(spacing: SKSpace.sm) {
                        ProgressView().tint(SKColor.primary)
                        Text("Loading your check-ins…").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }
                }
                if let moodError { SKInlineError(message: moodError) }
            }
        }
    }

    /// One tap saves. Existing notes are kept, so changing the mood never erases detail.
    private func quickSave(_ c: JournalCondition) {
        guard env.journal.state.value != nil else { return }
        moodError = nil
        Haptics.selection()
        Task {
            do {
                try await env.journal.save(day: ISO8601.dayString(Date()), condition: c, notes: env.journal.today?.notes)
                env.analytics.track(.journalSaved)
            } catch {
                moodError = (error as? APIError)?.userMessage ?? error.localizedDescription
                Haptics.error()
            }
        }
    }

    // MARK: Ask Skintel

    /// A chat-style prompt bar that opens the assistant preview.
    private var askCard: some View {
        Button { showAssistant = true } label: {
            HStack(spacing: SKSpace.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SKColor.cream)
                    .frame(width: 36, height: 36)
                    .background(SKColor.primary, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Skintel").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Text("What order should I use my products in?")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SKColor.cream)
                    .frame(width: 32, height: 32)
                    .background(SKColor.primary, in: Circle())
                    .skPrimaryGlow(strength: 0.3)
            }
            .padding(.vertical, SKSpace.md)
            .padding(.horizontal, SKSpace.md)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(SKColor.line))
            .skCardShadow()
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel("Ask Skintel")
    }

    // MARK: Alerts

    @ViewBuilder
    private var suspectCard: some View {
        let culprits = env.products.culprits
        if let top = culprits.all.first {
            Button { open(.culprits, else: .culprits) } label: {
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
        }
    }

    /// Free members go straight to the feature's demo instead of an empty Pro screen.
    private func open(_ destination: AppDestination, else reason: PaywallReason) {
        if env.subscription.entitlement.isPro { path.append(destination) } else { openPaywall(reason) }
    }

    private var recommendRow: some View {
        Button { open(.recommend, else: .recommend) } label: {
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
                SKProductMark(name: product.product.productName, category: product.product.category)
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

extension JournalCondition {
    /// Wording for the one-tap check-in. The stored values stay the server's four.
    var checkInLabel: String {
        switch self {
        case .clear: "Clear"
        case .mild: "A bit off"
        case .moderate: "Irritated"
        case .breakout: "Breaking out"
        }
    }
}

/// One choice in the skin check-in (Today card and the detail sheet).
struct MoodChoiceButton: View {
    let condition: JournalCondition
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                SKDot(tone: condition.tone, size: 10)
                Text(condition.checkInLabel).font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
            }
            .foregroundStyle(selected ? condition.tone.fg : SKColor.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(selected ? condition.tone.bg : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous)
                .stroke(selected ? condition.tone.fg : SKColor.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel(condition.checkInLabel)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
