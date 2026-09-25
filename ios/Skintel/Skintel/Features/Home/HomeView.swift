import SwiftUI
import SkintelCore
import SkinstelMascot

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
    /// Set only when the person's own tick finishes a routine; cleared after a short moment.
    @State private var celebratingSlot: RoutineStore.Slot?
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
            .skHint(.today, when: !env.products.products.isEmpty && !showCheckIn && !showAssistant)
        }
        .tint(SKColor.primary)
        .sheet(isPresented: $showCheckIn) { CheckInSheet() }
        .skAskSheet(isPresented: $showAssistant)
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
                todayCard
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
                     mascot: .wave,
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
                    if allDone { routineDoneRow(stepCount: steps.count) }
                    SKButton(title: allDone ? "\(slot.rawValue) routine done" : "Mark all done",
                             kind: allDone ? .done : .primary,
                             systemImage: allDone ? "checkmark" : nil) {
                        if !allDone {
                            env.routine.markAllDone(slot)
                            Haptics.success()
                            celebratingSlot = slot
                        }
                    }
                }
            }
        }
    }

    /// The mascot celebrates only right after the person's own tick completes the routine,
    /// then settles; opening Today on an already-finished routine just shows it resting.
    private func routineDoneRow(stepCount: Int) -> some View {
        HStack(spacing: SKSpace.md) {
            // One drop per screen: once the whole day is done, the Today card has it.
            if !TodayLoop(env: env).isComplete { SKMascot(action: celebratingSlot == slot ? .celebrate : .idle, height: 76) }
            Text("All \(stepCount) step\(stepCount == 1 ? "" : "s") done \(slot == .am ? "this morning" : "tonight").")
                .font(SKFont.secondary)
                .foregroundStyle(SKColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: celebratingSlot) {
            guard celebratingSlot != nil else { return }
            try? await Task.sleep(for: .seconds(2.4))
            if !Task.isCancelled { celebratingSlot = nil }
        }
        .onDisappear { celebratingSlot = nil }
    }

    private func celebrateIfRoutineComplete() {
        let steps = env.routine.ids(slot).compactMap { env.products.product(id: $0) }
        guard !steps.isEmpty, steps.allSatisfy({ env.routine.isDone($0.id) }) else { return }
        celebratingSlot = slot
    }

    private func stepRow(index: Int, product p: ProductWithIngredients) -> some View {
        let done = env.routine.isDone(p.id)
        return HStack(spacing: SKSpace.sm) {
            Button {
                env.routine.toggleDone(p.id, in: slot)
                if done {
                    Haptics.selection()
                } else {
                    Haptics.success()
                    celebrateIfRoutineComplete()
                }
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

    // MARK: Today loop

    /// Rows jump to where the work happens: the routine card below, switched to that slot
    /// (or the routine builder when the slot has no steps), or the check-in sheet.
    private var todayCard: some View {
        TodayLoopCard(loop: TodayLoop(env: env), isCovered: showCheckIn || showAssistant) { item in
            switch item.kind {
            case .morning, .night:
                if item.isSetUp {
                    withAnimation(SKAnimation.ios(0.3)) { slot = item.kind == .morning ? .am : .pm }
                } else {
                    path.append(.routine)
                }
            case .checkIn:
                showCheckIn = true
            }
        }
    }

    // MARK: Skin check-in

    /// True after "Edit" on a saved log, until the next tap saves.
    @State private var editingLog = false

    /// A calm daily log rather than a quiz: one line that fits the time of day, four compact
    /// chips, and once saved a single "Saved for today · Edit" row. Detail is one tap away.
    private var checkInCard: some View {
        let today = env.journal.today
        let loaded = env.journal.state.value != nil
        return SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(alignment: .center, spacing: SKSpace.sm) {
                    Text("Skin log").skLabelStyle()
                    Spacer(minLength: 0)
                    if loaded { streakMark(env.journal.streaks()) }
                }
                if loaded {
                    if let today, !editingLog {
                        savedLog(today)
                    } else {
                        Text(SkinLogPrompt.line())
                            .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        FlowLayout(spacing: SKSpace.sm) {
                            ForEach(JournalCondition.allCases, id: \.self) { c in
                                MoodChoiceButton(condition: c, selected: today?.condition == c) { quickSave(c) }
                            }
                        }
                        HStack(spacing: SKSpace.sm) {
                            Text(today == nil ? "One tap logs today." : "Tap one to change today's log.")
                                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                            Spacer(minLength: 0)
                            addDetailButton
                        }
                    }
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

    /// "Day 4" once today is logged; the run so far while today is still open.
    @ViewBuilder
    private func streakMark(_ s: Streaks) -> some View {
        if s.loggedToday && s.current > 0 {
            Text("Day \(s.current)")
                .font(SKFont.sans(13, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(SKColor.goodFg)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(SKColor.goodBg, in: Capsule())
                .accessibilityLabel("Day \(s.current) of your check-in streak")
        } else if s.current > 0 {
            Text("\(s.current)-day streak")
                .font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
        }
    }

    private func savedLog(_ entry: JournalEntry) -> some View {
        let symptoms = CheckInSheet.lineValues(entry.notes, prefix: CheckInSheet.symptomPrefix)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: SKSpace.sm) {
                Circle().fill(entry.condition.logTint.dot).frame(width: 10, height: 10)
                Text(entry.condition.checkInLabel)
                    .font(SKFont.cardTitle).foregroundStyle(SKColor.ink).lineLimit(1)
                Text("· Saved for today")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(1)
                Spacer(minLength: 0)
                Button("Edit") { withAnimation(SKAnimation.ios(0.3)) { editingLog = true } }
                    .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(SKColor.primary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Edit today's skin log")
            }
            .accessibilityElement(children: .contain)
            if !symptoms.isEmpty {
                Text(symptoms.joined(separator: " · "))
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
            }
            addDetailButton
        }
    }

    private var addDetailButton: some View {
        Button("Add detail") { showCheckIn = true }
            .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
            .foregroundStyle(SKColor.primary)
            .frame(minHeight: 44)
    }

    /// One tap saves. Existing notes are kept, so changing the mood never erases detail.
    private func quickSave(_ c: JournalCondition) {
        guard env.journal.state.value != nil else { return }
        moodError = nil
        Haptics.selection()
        withAnimation(SKAnimation.ios(0.3)) { editingLog = false }
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
        case .culprits: TriggersView()
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

/// Skin-log tints, built from the brand tokens: sage for clear, clay for the middle two,
/// terracotta for a breakout. No yellow.
struct SkinLogTint {
    /// Text and mark on the chosen chip.
    let fg: Color
    /// Fill of the chosen chip.
    let bg: Color
    /// Border of the chosen chip.
    let stroke: Color
    /// The small mark on an unchosen chip and in the saved row.
    let dot: Color
}

extension JournalCondition {
    var logTint: SkinLogTint {
        switch self {
        case .clear:
            SkinLogTint(fg: SKColor.goodFg, bg: SKColor.goodBg, stroke: SKColor.goodFg.opacity(0.45), dot: SKColor.goodFg)
        case .mild:
            SkinLogTint(fg: SKColor.primaryPressed, bg: SKColor.primary.opacity(0.08),
                        stroke: SKColor.primary.opacity(0.35), dot: SKColor.primary.opacity(0.4))
        case .moderate:
            SkinLogTint(fg: SKColor.primaryPressed, bg: SKColor.primary.opacity(0.16),
                        stroke: SKColor.primary.opacity(0.5), dot: SKColor.primary.opacity(0.7))
        case .breakout:
            SkinLogTint(fg: SKColor.cream, bg: SKColor.primary, stroke: SKColor.primary, dot: SKColor.primary)
        }
    }
}

/// The skin log's one-line prompt, by time of day.
enum SkinLogPrompt {
    static func line(_ date: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<11: "How did your skin wake up?"
        case 11..<17: "How's your skin holding up?"
        case 17..<22: "How did your skin do today?"
        default: "Before bed: how's your skin?"
        }
    }
}

/// One choice in the skin log: a compact chip, tinted once chosen.
struct MoodChoiceButton: View {
    let condition: JournalCondition
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let tint = condition.logTint
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().fill(selected ? tint.fg : tint.dot).frame(width: 8, height: 8)
                Text(condition.checkInLabel)
                    .font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? tint.fg : SKColor.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(selected ? tint.bg : SKColor.cream, in: Capsule())
            .overlay(Capsule().stroke(selected ? tint.stroke : SKColor.line, lineWidth: selected ? 1.5 : 1))
            .contentShape(Capsule())
        }
        .buttonStyle(SKPressStyle())
        .animation(SKAnimation.ios(0.25), value: selected)
        .accessibilityLabel(condition.checkInLabel)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Today loop

/// Today's three actions — morning routine, skin check-in, night routine — read from the
/// routine's completion log and today's journal entry. Nothing is estimated.
@MainActor
struct TodayLoop {
    enum Kind: Hashable, Sendable { case morning, checkIn, night }

    struct Item: Identifiable {
        let kind: Kind
        let title: String
        /// "Done", "2 of 4", "Tonight", "Set up", the logged condition…
        let detail: String
        /// Something to do today: the routine has steps (the check-in always counts).
        let isSetUp: Bool
        let isDone: Bool
        var id: Kind { kind }
    }

    let items: [Item]
    /// Check-ins have loaded, so the check-in row is known rather than assumed.
    let ready: Bool

    var total: Int { items.filter(\.isSetUp).count }
    var done: Int { items.filter { $0.isSetUp && $0.isDone }.count }
    /// All three set up and done today.
    var isComplete: Bool { ready && items.allSatisfy { $0.isSetUp && $0.isDone } }

    init(env: AppEnvironment, now: Date = Date()) {
        let day = ISO8601.dayString(now)
        let isReady = env.journal.state.value != nil
        let beforeNight = RoutineStore.currentSlot(now: now) == .am

        func routineItem(_ slot: RoutineStore.Slot, kind: Kind, title: String) -> Item {
            let steps = env.routine.ids(slot).filter { env.products.product(id: $0) != nil }
            let complete = !steps.isEmpty && env.routine.isComplete(slot, on: day)
            let ticked = steps.filter { env.routine.isDone($0) }.count
            let detail: String
            if steps.isEmpty { detail = "Set up" }
            else if complete { detail = "Done" }
            else if slot == .pm && beforeNight && ticked == 0 { detail = "Tonight" }
            else if ticked > 0 { detail = "\(ticked) of \(steps.count)" }
            else { detail = steps.count == 1 ? "1 step" : "\(steps.count) steps" }
            return Item(kind: kind, title: title, detail: detail, isSetUp: !steps.isEmpty, isDone: complete)
        }

        let entry = env.journal.entry(on: day)
        let checkIn = Item(kind: .checkIn, title: "Skin check-in",
                           detail: entry?.condition.checkInLabel ?? (isReady ? "Log it" : "…"),
                           isSetUp: true, isDone: entry != nil)
        ready = isReady
        items = [routineItem(.am, kind: .morning, title: "Morning routine"),
                 checkIn,
                 routineItem(.pm, kind: .night, title: "Night routine")]
    }
}

/// Home's daily loop: three rows and "2 of 3 done". Finishing the third while Today is open
/// gets one celebration that day; opening Today on a finished day just shows the drop resting.
private struct TodayLoopCard: View {
    let loop: TodayLoop
    /// A sheet is over Today: hold the celebration until it's gone, so it isn't missed.
    let isCovered: Bool
    let open: (TodayLoop.Item) -> Void

    @AppStorage("today.loop.celebratedDay") private var celebratedDay = ""
    @State private var celebrating = false
    @State private var pending = false
    @State private var visible = false

    private struct Signature: Equatable {
        let ready: Bool
        let complete: Bool
    }

    var body: some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                if loop.isComplete {
                    completeRow
                } else {
                    header
                    rows
                }
            }
        }
        .onChange(of: Signature(ready: loop.ready, complete: loop.isComplete)) { old, new in
            // Only a change seen with check-ins already loaded: loading them must not "finish" a day.
            guard old.ready, new.ready, !old.complete, new.complete else { return }
            if visible && !isCovered { celebrate() } else { pending = true }
        }
        .onChange(of: isCovered) { _, covered in
            if !covered && pending && visible { celebrate() }
        }
        .onAppear {
            visible = true
            if pending && !isCovered { celebrate() }
        }
        .onDisappear { visible = false }
        .task(id: celebrating) {
            guard celebrating else { return }
            try? await Task.sleep(for: .seconds(2.6))
            celebrating = false
        }
    }

    /// Once a day, and only while the day is still complete.
    private func celebrate() {
        pending = false
        let today = ISO8601.dayString(Date())
        guard loop.isComplete, celebratedDay != today else { return }
        celebratedDay = today
        celebrating = true
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(SKFont.section).foregroundStyle(SKColor.ink)
                Spacer()
                Text("\(loop.done) of \(loop.total) done")
                    .font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
            }
            HStack(spacing: 6) {
                ForEach(loop.items) { item in
                    Capsule()
                        .fill(item.isSetUp && item.isDone ? SKColor.primary : SKColor.line)
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(loop.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Rectangle().fill(SKColor.line).frame(height: 1).padding(.leading, 36) }
                Button { open(item) } label: { row(item) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.title): \(item.isSetUp && item.isDone ? "done" : item.detail)")
                    .accessibilityHint(hint(for: item))
            }
        }
    }

    private func row(_ item: TodayLoop.Item) -> some View {
        let done = item.isSetUp && item.isDone
        return HStack(spacing: SKSpace.md) {
            ZStack {
                Circle().fill(done ? SKColor.primary : SKColor.cream)
                Circle().stroke(done ? SKColor.primary : SKColor.line, lineWidth: 1.5)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(SKColor.cream)
                }
            }
            .frame(width: 24, height: 24)
            Text(item.title)
                .font(SKFont.bodyMedium)
                .foregroundStyle(done ? SKColor.muted : SKColor.ink)
                .lineLimit(1)
            Spacer(minLength: SKSpace.sm)
            Text(item.detail)
                .font(SKFont.secondary)
                .foregroundStyle(detailColor(item))
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SKColor.muted.opacity(0.6))
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func detailColor(_ item: TodayLoop.Item) -> Color {
        if item.isSetUp && item.isDone { return SKColor.goodFg }
        if !item.isSetUp || (item.kind == .checkIn && loop.ready) { return SKColor.primary }
        return SKColor.muted
    }

    private func hint(for item: TodayLoop.Item) -> String {
        switch item.kind {
        case .morning, .night: item.isSetUp ? "Shows these steps below" : "Opens the routine builder"
        case .checkIn: "Opens the check-in"
        }
    }

    private var completeRow: some View {
        HStack(spacing: SKSpace.md) {
            SKMascot(action: celebrating ? .celebrate : .idle, height: 72)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today's done").font(SKFont.section).foregroundStyle(SKColor.ink)
                    Spacer(minLength: SKSpace.sm)
                    Text("3 of 3").font(SKFont.dataSmall).foregroundStyle(SKColor.goodFg)
                }
                Text("Morning routine, check-in and night routine all ticked. See you tomorrow.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
