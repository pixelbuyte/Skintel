import SwiftUI
import SkintelCore
import SkinstelMascot

/// Today: what to do right now. The current AM or PM routine as a tickable checklist, a
/// one-tap skin check-in, and only the alerts that need attention. Everything shown comes
/// from what the person has actually done: ticks, check-ins and their shelf.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var path: [AppDestination] = []
    @State private var slot: RoutineStore.Slot = RoutineStore.currentSlot()
    @State private var showCheckIn = false
    @State private var showAssistant = false
    @State private var showJournal = false
    @AppStorage(AssistantPlacement.key) private var assistantPlacement = AssistantPlacement.tab
    @State private var moodError: String?
    /// Set only when the person's own tick finishes a routine; cleared after a short moment.
    @State private var celebratingSlot: RoutineStore.Slot?
    @AppStorage(CheckInPrompt.enabledKey) private var autoPrompt = true
    @AppStorage(CheckInPrompt.lastKey) private var lastPrompt = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
        .sheet(isPresented: $showJournal) { JournalView() }
        .task(id: celebratingSlot) {
            guard celebratingSlot != nil else { return }
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            celebratingSlot = nil
        }
        .onChange(of: slot) { _, _ in celebratingSlot = nil }
        .task {
            env.routine.rollDayIfNeeded()
            await env.journal.load()
            promptCheckInIfDue()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            env.routine.rollDayIfNeeded()
            Task {
                await env.journal.load()
                promptCheckInIfDue()
            }
        }
    }

    /// Morning: ask when nothing is logged yet today. Evening: ask when tonight's part isn't
    /// answered. At most once per part of the day, and never over another sheet.
    private func promptCheckInIfDue() {
        guard autoPrompt, !showCheckIn, !showAssistant, !showJournal, env.journal.state.value != nil,
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
        return HStack(alignment: .top, spacing: SKSpace.md) {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                Text("TODAY · \(DateFormatting.header())").skLabelStyle()
                Text("\(DateFormatting.greeting()), \(env.session.user?.firstName ?? "there")")
                    .font(SKFont.greeting)
                    .foregroundStyle(SKColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("A little care, every day.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
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
            weekCard
            if products.isEmpty {
                newUserCard
            } else {
                companionHero
                companionActions
                routineCard
                checkInCard
                askCard
                suspectCard
                recommendRow
            }
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack {
                Text("Your skin this week").font(SKFont.bodyMedium)
                Spacer()
                Button("Journal") { showJournal = true }
                    .font(SKFont.secondary).foregroundStyle(SKColor.primary)
                    .frame(minHeight: 44)
            }
            if env.journal.state.value != nil {
                TodayCheckInWeek(days: env.journal.week)
            } else if env.journal.state.error != nil {
                Button("Couldn't load your week. Try again") {
                    Task { await env.journal.load() }
                }
                .font(SKFont.secondary).foregroundStyle(SKColor.primary)
                .frame(minHeight: 44)
            } else {
                ProgressView("Loading your week…").font(SKFont.secondary)
            }
        }
        .foregroundStyle(SKColor.ink)
    }

    private var companionHero: some View {
        let steps = env.routine.ids(slot).compactMap { env.products.product(id: $0) }
        let done = steps.filter { env.routine.isDone($0.id) }.count
        return VStack(spacing: SKSpace.md) {
            SKSegmented(options: [(RoutineStore.Slot.am, "Morning"), (.pm, "Evening")], selection: $slot)
            TodayCompanionHero(done: done, total: steps.count, evening: slot == .pm,
                               celebrating: celebratingSlot == slot)
            if steps.isEmpty {
                SKButton(title: "Build your \(slot.rawValue) routine", kind: .secondary) { path.append(.routine) }
            }
        }
        .padding(SKSpace.lg)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [SKColor.cream, SKColor.goodBg.opacity(0.65)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(SKColor.line))
    }

    private var companionActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: SKSpace.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: SKSpace.md))
        return layout {
            TodayFeatureTile(art: "DropCheckIn", title: "Skin check-in",
                             subtitle: env.journal.today == nil ? "How are you feeling?" : "Update today's entry",
                             tint: SKColor.cream) { showCheckIn = true }
            TodayFeatureTile(art: slot == .am ? "DropSunscreen" : "DropNight",
                             title: slot == .am ? "Morning care" : "Evening care",
                             subtitle: "Plan your routine", tint: SKColor.goodBg) { path.append(.routine) }
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
                Button("Edit routine") { path.append(.routine) }
                    .font(SKFont.secondary).foregroundStyle(SKColor.primary).frame(minHeight: 44)
                if steps.isEmpty {
                    Text("No \(slot.rawValue) steps yet. Add products from your shelf and Skintel keeps them in order.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    SKButton(title: "Build your \(slot.rawValue) routine", kind: .secondary) { path.append(.routine) }
                } else {
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

    /// Completion text complements the hero; the hero owns the only animated character.
    private func routineDoneRow(stepCount: Int) -> some View {
        Text("All \(stepCount) step\(stepCount == 1 ? "" : "s") done \(slot == .am ? "this morning" : "tonight").")
            .font(SKFont.secondary).foregroundStyle(SKColor.goodFg)
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
                    celebratingSlot = nil
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
                SKDrop("DropAsk", size: 60)
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
            Button { path.append(.culprits) } label: {
                SKCard {
                    HStack(spacing: SKSpace.lg) {
                        SKDrop("DropIngredients", size: 58)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Worth a closer look")
                                .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            Text("\(top.name) is in \(top.badCount) products that broke you out")
                                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Text("Review ›").font(SKFont.sans(15, weight: .semibold)).foregroundStyle(SKColor.primary)
                    }
                }
            }
            .buttonStyle(SKPressStyle())
        }
    }

    private var recommendRow: some View {
        Button { path.append(.recommend) } label: {
            SKCard {
                HStack(spacing: SKSpace.lg) {
                    SKDrop("DropCompare", size: 58)
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
        case .routine: RoutineView(initialSlot: slot)
        case .recommend: RecommendView()
        case .settings: SettingsView()
        }
    }
}

/// Progress is checklist completion, never a skin-health score. The interactive mascot
/// owns its short wave locally so tapping it does not re-render the whole dashboard.
private struct TodayCompanionHero: View {
    let done: Int
    let total: Int
    let evening: Bool
    let celebrating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var waveID = 0
    @State private var waving = false

    private var fraction: Double { total > 0 ? min(1, max(0, Double(done) / Double(total))) : 0 }
    private var action: SkinstelMascotAction {
        if celebrating { return .celebrate }
        if waving { return .wave }
        return evening ? .sleep : .idle
    }
    private var message: String {
        if total == 0 { return "Your routine starts here." }
        if done >= total { return "A little care. All done." }
        let remaining = total - done
        return "\(remaining) little step\(remaining == 1 ? "" : "s") left."
    }

    var body: some View {
        VStack(spacing: SKSpace.sm) {
            Text(evening ? "YOUR EVENING RITUAL" : "YOUR MORNING RITUAL")
                .skLabelStyle().padding(.top, SKSpace.sm)
            ZStack {
                Circle().stroke(SKColor.primary.opacity(0.1), lineWidth: 12)
                Circle().trim(from: 0, to: fraction)
                    .stroke(SKColor.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: fraction)
                VStack(spacing: 0) {
                    Button {
                        Haptics.selection()
                        waveID += 1
                        waving = true
                    } label: {
                        SkinstelMascot(action: action, playbackID: waveID)
                            .frame(width: 110, height: 124)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skinstel companion")
                    .accessibilityHint("Double tap to say hello")
                    .task(id: waveID) {
                        guard waveID > 0 else { return }
                        try? await Task.sleep(for: .seconds(1.8))
                        guard !Task.isCancelled else { return }
                        waving = false
                    }
                    if !dynamicTypeSize.isAccessibilitySize { progressLabel }
                }
            }
            .frame(width: 228, height: 228)
            .padding(.vertical, SKSpace.md)
            if dynamicTypeSize.isAccessibilitySize { progressLabel }
            Text(message).font(SKFont.section).foregroundStyle(SKColor.ink)
                .multilineTextAlignment(.center)
            Text(total == 0 ? "Add the products you want to use." : "\(done) of \(total) steps complete · \(evening ? "PM" : "AM") routine")
                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, SKSpace.sm)
        .onDisappear { waving = false }
    }

    private var progressLabel: some View {
        VStack(spacing: 0) {
            Text(total == 0 ? "Let's begin" : "\(Int((fraction * 100).rounded()))%")
                .font(SKFont.serif(total == 0 ? 24 : 36, relativeTo: .title))
                .foregroundStyle(SKColor.ink)
            Text("routine complete").font(SKFont.caption).foregroundStyle(SKColor.muted)
                .opacity(total == 0 ? 0 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(total == 0 ? "No routine steps yet" : "\(done) of \(total) routine steps complete")
    }
}

/// A sticker marks a real logged day. Missing days remain empty and never imply a mood.
private struct TodayCheckInWeek: View {
    let days: [(date: Date, entry: JournalEntry?)]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) { strip }
        } else {
            strip
        }
    }

    private var strip: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(days.map { Day(date: $0.date, condition: $0.entry?.condition) }) { day in
                TodayCheckInDay(date: day.date, condition: day.condition,
                                today: Calendar.current.isDateInToday(day.date))
                    .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 76 : 0, maxWidth: .infinity)
            }
        }
        .padding(.vertical, SKSpace.sm)
    }

    private struct Day: Identifiable {
        let date: Date
        let condition: JournalCondition?
        // JournalStore.week rebuilds Date values; the persisted day key is stable.
        var id: String { ISO8601.dayString(date) }
    }
}

private struct TodayCheckInDay: View {
    let date: Date
    let condition: JournalCondition?
    let today: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(date, format: .dateTime.weekday(.narrow))
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
            ZStack {
                Circle().fill(today ? SKColor.blush : SKColor.cream.opacity(0.7))
                if condition != nil {
                    SKDrop("DropCheckIn", size: 34)
                } else {
                    Circle().stroke(SKColor.muted.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .padding(9)
                }
            }
            .frame(width: 38, height: 38)
            .overlay(Circle().stroke(today ? SKColor.primary : .clear, lineWidth: 1.5))
            Text(date, format: .dateTime.day())
                .font(SKFont.dataSmall).foregroundStyle(today ? SKColor.primary : SKColor.muted)
            Text(condition?.checkInLabel ?? "Not logged")
                .font(SKFont.sans(9, relativeTo: .caption2))
                .foregroundStyle(condition?.tone.fg ?? SKColor.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)): \(condition?.checkInLabel ?? "No check-in")\(today ? ", today" : "")")
    }
}

private struct TodayFeatureTile: View {
    let art: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                HStack(alignment: .top) {
                    SKDrop(art, size: 74)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SKColor.primary).padding(.top, 6)
                        .accessibilityHidden(true)
                }
                Text(title).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                Text(subtitle).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(SKSpace.md)
            .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SKColor.line))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityElement(children: .combine)
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
