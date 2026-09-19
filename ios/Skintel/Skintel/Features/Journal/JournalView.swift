import SwiftUI
import SkintelCore

/// The Journal is the only screen in Skintel that takes and never gives, so this version
/// inverts it: every tap answers back immediately with a sentence computed on this phone
/// from data that is already there, free tier included.
///
/// Tapping a face *is* the log. A five-week calendar replaces the seven-dot strip, so she
/// can see the record filling up and tap any missed day to fill it in. "What you used
/// today" is individually tickable and writes to `env.journalUsage`, a local record of
/// what was actually applied — which is what `JournalInsight` reads.
///
/// The legacy `"Used: …"` notes line is still written (it is the only cross-device carrier
/// and the Pro reader's input) but is **never** fed to the local engine: it records the
/// whole saved routine rather than what was applied, so it is over-inclusive on historical
/// days and has zero variance for a static routine. Here it is display-only, stripped out
/// of her own words and rendered as chips.
struct JournalView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

    /// The face she just tapped, held through the round trip so the selection never
    /// flickers and never silently reverts on failure.
    @State private var optimistic: JournalCondition?
    @State private var notes = ""
    @State private var noteOpen = false
    @State private var ticked: Set<String> = []
    @State private var saving = false
    @State private var error: String?
    @State private var primed = false
    @State private var selectedDay: String?
    @State private var showPicker = false
    @State private var pendingDelete: JournalEntry?
    @State private var path: [AppDestination] = []
    @FocusState private var notesFocused: Bool

    private var todayKey: String { ISO8601.dayString(Date()) }

    /// Constant, and deliberately plain: it is the only place the thresholds are
    /// explained, and a reader who checks it against the calendar must find it true.
    private static let howText = """
        A good day is one you marked Clear or Mild. A rough day is Moderate or Broke out. \
        Skintel counts the days you ticked a product and compares them with the days you \
        didn't. It only says something when there are at least four days on each side and \
        a clear gap between them. Skin often lags by days, so treat this as a lead, not proof.
        """

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    header
                    todayCard
                    insightsSection
                    calendarSection
                    goDeeperSection
                    recentNotesSection
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
                // `skPetRefresh` scopes `.tint(.clear)` to kill the system wheel; put the
                // real tint back on the page content so nothing else inherits clear.
                .tint(SKColor.primary)
            }
            .scrollDismissesKeyboard(.interactively)
            .skPetRefresh { await env.journal.load() }
            .skPageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .keyboard) { HStack { Spacer(); Button("Done") { notesFocused = false }.font(SKFont.bodyMedium) } }
            }
            .navigationDestination(for: AppDestination.self) { d in
                if case .culprits = d { CulpritsView() }
            }
        }
        .tint(SKColor.primary)
        .task {
            await env.journal.load()
            prime()
        }
        .onChange(of: env.journal.state.value?.count) { _, _ in prime() }
        .sheet(isPresented: $showPicker) {
            ShelfPickerSheet(exclude: Set(routineProductIDs + extraTickedIDs)) { id in
                ticked.insert(id)
                commitUsage()
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let e = pendingDelete else { return }
                Task {
                    try? await env.journal.delete(e)
                    // The local usage record for that day is deliberately kept: without a
                    // condition it stops being an analysis day anyway, and dropping it
                    // would lose her ticks if she re-logs the day.
                    if e.entryDate == todayKey { optimistic = nil; notes = ""; noteOpen = false }
                    Haptics.success()
                }
            }
        }
    }

    /// Runs until today's entry has actually arrived, so it survives the load finishing
    /// after the first pass. The tick seed is guarded on `ticked.isEmpty` rather than on
    /// `primed`, so a repeat pass can never clobber a tick she made in between.
    private func prime() {
        if ticked.isEmpty {
            if let stored = env.journalUsage.log.days[todayKey] {
                ticked = Set(stored)
            } else {
                // No local record yet — the routine's "done today" ticks are the best
                // honest guess, and she can correct any of them in one tap.
                ticked = Set(routineProductIDs.filter { env.routine.isDone($0) })
            }
        }
        guard !primed, let t = env.journal.today else { return }
        primed = true
        notes = JournalInsight.strippingUsageLine(t.notes)
        noteOpen = !notes.isEmpty
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: SKSpace.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Journal").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                Spacer()
                if env.journal.streak > 0 {
                    SKChip("🔥 \(env.journal.streak)-day streak", tone: .caution)
                }
            }
            Text(progressLine).font(SKFont.secondary).foregroundStyle(SKColor.muted)
        }
        .padding(.top, SKSpace.md)
    }

    private var progressLine: String {
        let p = JournalInsight.progress(entries: env.journal.entries, today: todayKey)
        guard p.loggedDays > 0 else { return "Nothing logged yet — start with today." }
        var line = "\(p.loggedDays) day\(p.loggedDays == 1 ? "" : "s") logged"
        if p.loggedStreak >= 2 { line += " · \(p.loggedStreak) in a row" }
        if p.bestGoodRun >= 3 { line += " · best good run: \(p.bestGoodRun) days" }
        return line
    }

    // MARK: - Today

    private var displayedCondition: JournalCondition? {
        optimistic ?? env.journal.today?.condition
    }

    private var todayCard: some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                Text(displayedCondition == nil ? "How's your skin today?" : "Today")
                    .font(SKFont.sans(19, weight: .semibold, relativeTo: .title3)).foregroundStyle(SKColor.ink)

                conditionButtons(selected: displayedCondition) { c in Task { await log(c) } }

                Text(todaySubline).font(SKFont.caption).foregroundStyle(SKColor.muted)

                // Fixed copy on purpose: the one thing she needs to know is that the tap
                // did not land and that tapping again is the whole retry.
                if error != nil { SKInlineError(message: "Didn't save — tap a face to try again.") }

                usageBlock
                noteBlock
            }
        }
    }

    private var todaySubline: String {
        if saving { return "Saving…" }
        guard displayedCondition != nil else { return "One tap. You can add more after." }
        return JournalInsight.payback(entries: env.journal.entries, today: todayKey)
    }

    /// The four faces. Shared verbatim by the Today card and the calendar's backfill
    /// panel so a filled-in day is logged with exactly the same affordance.
    private func conditionButtons(selected: JournalCondition?,
                                  action: @escaping (JournalCondition) -> Void) -> some View {
        HStack(spacing: SKSpace.sm) {
            ForEach(JournalCondition.allCases, id: \.self) { c in
                Button {
                    action(c)
                } label: {
                    VStack(spacing: 6) {
                        Text(c.emoji).font(.system(size: 24))
                        Text(c.label).font(SKFont.sans(13, weight: .semibold, relativeTo: .caption)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selected == c ? c.tone.fg : SKColor.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .background(selected == c ? c.tone.bg : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                        .stroke(selected == c ? c.tone.fg : SKColor.line, lineWidth: selected == c ? 1.5 : 1))
                }
                .buttonStyle(SKPressStyle())
                .accessibilityLabel(c.label)
                .accessibilityAddTraits(selected == c ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    // MARK: - What you used today

    /// AM then PM, de-duplicated, order preserved — that is the order she reads them in
    /// on the Routine screen and the order they are written into the `"Used: …"` line.
    private var routineProductIDs: [String] {
        var seen = Set<String>()
        return (env.routine.ids(.am) + env.routine.ids(.pm)).filter { seen.insert($0).inserted }
    }

    /// Ticked ids she picked off the shelf rather than out of her routine. Ordered by the
    /// stored record first so the chips do not reshuffle between launches.
    private var extraTickedIDs: [String] {
        let inRoutine = Set(routineProductIDs)
        let stored = env.journalUsage.productIDs(on: todayKey).filter { !inRoutine.contains($0) && ticked.contains($0) }
        let known = Set(stored)
        let fresh = ticked.filter { !inRoutine.contains($0) && !known.contains($0) }.sorted()
        return stored + fresh
    }

    private var orderedTickedIDs: [String] {
        routineProductIDs.filter { ticked.contains($0) } + extraTickedIDs
    }

    private var usedNames: [String] {
        orderedTickedIDs.compactMap { env.products.product(id: $0)?.product.productName }
    }

    @ViewBuilder
    private var usageBlock: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            SKFieldLabel("What you used today")
            if routineProductIDs.isEmpty, extraTickedIDs.isEmpty {
                Text("Add products to your routine and Skintel can start matching them to your days.")
                    .font(SKFont.secondary).foregroundStyle(SKColor.muted)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(routineProductIDs, id: \.self) { id in usageChip(id) }
                    ForEach(extraTickedIDs, id: \.self) { id in usageChip(id) }
                }
                SKDashedButton(title: "+ Something else") { showPicker = true }
                Text("Stays on your phone. Skintel uses it to spot what your skin agrees with.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
        }
    }

    private func usageChip(_ id: String) -> some View {
        SKSelectChip(title: shortName(name(of: id)), selected: ticked.contains(id)) { toggle(id) }
    }

    private func name(of id: String) -> String {
        env.products.product(id: id)?.product.productName ?? "Product"
    }

    private func shortName(_ s: String) -> String {
        let w = s.split(separator: " ")
        return w.count > 2 ? w.prefix(2).joined(separator: " ") : s
    }

    private func toggle(_ id: String) {
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
        Haptics.selection()
        commitUsage()
    }

    /// Local, free, and immediate — a tick is never a network call and never waits on one.
    private func commitUsage() {
        env.journalUsage.set(orderedTickedIDs, on: todayKey)
    }

    // MARK: - Note

    @ViewBuilder
    private var noteBlock: some View {
        if noteOpen {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                SKTextEditor(placeholder: "Skin felt calm all day. New toner didn't sting…", text: $notes, minHeight: 96)
                    .focused($notesFocused)
                SKButton(title: "Save note", kind: .secondary, isLoading: saving) { Task { await saveNote() } }
                    .disabled(displayedCondition == nil)
            }
        } else {
            SKLinkButton(title: "+ Add a note", chevron: false) { noteOpen = true }
        }
    }

    // MARK: - Writing

    private func log(_ c: JournalCondition) async {
        guard !saving else { return }
        optimistic = c
        Haptics.selection()
        await commit(c, day: todayKey)
    }

    private func saveNote() async {
        guard let c = displayedCondition else { return }
        await commit(c, day: todayKey)
    }

    /// The single write path, used by the Today faces, the note button and the calendar
    /// backfill. The notes text is stripped then rebuilt every time, usage line last:
    /// the old `if !text.contains("Used:")` guard meant the line went stale on every
    /// update and that anyone who typed "Used:" lost routine logging forever.
    private func commit(_ c: JournalCondition, day: String) async {
        guard !saving else { return }
        saving = true
        error = nil
        defer { saving = false }

        let isToday = day == todayKey
        // Whatever is ticked right now becomes this day's record, including a set that
        // was only ever seeded from the routine and never touched.
        if isToday { commitUsage() }

        let existing = env.journal.entry(on: day)?.notes
        let words = isToday ? notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            : JournalInsight.strippingUsageLine(existing)
        // A backfilled day keeps whatever names its own entry already carried; today's
        // line is rebuilt from the ticks. Capped at six names because
        // `api/_journal-analyze.ts` slices each entry's notes to 200 characters.
        let names = isToday ? usedNames : JournalInsight.usageNames(existing)

        var text = words
        if let line = JournalInsight.usageNote(productNames: names) {
            text += (text.isEmpty ? "" : "\n") + line
        }

        do {
            try await env.journal.save(day: day, condition: c, notes: text.isEmpty ? nil : String(text.prefix(2000)))
            env.analytics.track(.journalSaved)
            Haptics.success()
            notesFocused = false
            if isToday { notes = words }
        } catch {
            // The face stays exactly where she put it; tapping again overwrites.
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - What Skintel noticed

    private var insightsSection: some View {
        let list = JournalInsight.findings(entries: env.journal.entries,
                                           usage: env.journalUsage.dayUsage,
                                           products: env.products.products,
                                           shelfFlagged: Set(env.products.culprits.byNormalized.keys),
                                           today: todayKey)
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            SKSectionHeader(title: "What Skintel noticed")
            ForEach(list) { f in findingCard(f) }
            Text("These are patterns in your own log, not medical advice. Skin changes for lots of reasons — hormones, weather, stress.")
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
        }
    }

    private func tone(for mood: JournalInsight.Finding.Mood) -> SKTone? {
        switch mood {
        case .good: return .good
        case .caution: return .caution
        case .neutral: return nil
        }
    }

    private func findingCard(_ f: JournalInsight.Finding) -> some View {
        SKCard(tint: tone(for: f.mood)) {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text(f.headline).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                Text(f.detail).font(SKFont.secondary).foregroundStyle(SKColor.ink)
                if let p = f.progress {
                    SKProgressBar(fraction: p, tone: .neutral, height: 6)
                }
                if f.sharedIngredientRaw != nil {
                    SKLinkButton(title: "See what your shelf shares") { path.append(.culprits) }
                }
                DisclosureGroup("How Skintel worked this out") {
                    Text(Self.howText)
                        .font(SKFont.caption)
                        .foregroundStyle(SKColor.muted)
                        .padding(.top, SKSpace.xs)
                }
                .font(SKFont.secondary)
                .foregroundStyle(SKColor.muted)
            }
        }
    }

    // MARK: - Your last 5 weeks

    private var calendarSection: some View {
        let g = JournalInsight.grid(entries: env.journal.entries, today: todayKey)
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            SKSectionHeader(title: "Your last 5 weeks")
            SKCard(padding: SKSpace.lg) {
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    weekdayRow
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 10) {
                        // id: \.offset, not the cell's own Identifiable id — the engine's
                        // documented (unreachable in this app) malformed-today fallback
                        // yields 35 cells sharing one id, which would collide here.
                        ForEach(Array(g.cells.enumerated()), id: \.offset) { _, cell in dayCell(cell) }
                    }
                    Text(countsLine(g)).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    if let day = selectedDay {
                        Divider().background(SKColor.line)
                        dayPanel(day)
                    }
                }
            }
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                Text(d).font(SKFont.mono(11)).foregroundStyle(SKColor.muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func countsLine(_ g: JournalInsight.Grid) -> String {
        if g.goodDays == 0, g.roughDays == 0 { return "Nothing logged in the last 5 weeks." }
        var parts = ["\(g.goodDays) good", "\(g.roughDays) rough"]
        if g.missedDays > 0 { parts.append("\(g.missedDays) not logged") }
        return parts.joined(separator: " · ")
    }

    private func dayCell(_ cell: JournalInsight.Cell) -> some View {
        Button {
            selectedDay = cell.day
            Haptics.selection()
        } label: {
            dayMark(cell)
                .frame(width: 26, height: 26)
                .overlay {
                    if cell.isToday {
                        Circle().stroke(SKColor.primary, lineWidth: 2).frame(width: 22, height: 22)
                    } else if selectedDay == cell.day {
                        Circle().stroke(SKColor.ink.opacity(0.3), lineWidth: 1.5).frame(width: 22, height: 22)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(SKPressStyle())
        .disabled(cell.isFuture)
        .accessibilityLabel("\(JournalInsight.dayLabel(cell.day)): \(cell.condition?.label ?? "not logged")")
    }

    @ViewBuilder
    private func dayMark(_ cell: JournalInsight.Cell) -> some View {
        if let c = cell.condition {
            SKDot(tone: c.tone, size: 14)
        } else {
            Circle()
                .strokeBorder(SKColor.line, lineWidth: 1.5)
                .frame(width: 14, height: 14)
                .opacity(cell.isFuture ? 0.35 : 1)
        }
    }

    @ViewBuilder
    private func dayPanel(_ day: String) -> some View {
        if day == todayKey {
            Text("That's today — log it up top.")
                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
        } else if let e = env.journal.entry(on: day) {
            loggedDayPanel(e)
        } else {
            backfillPanel(day)
        }
    }

    private func loggedDayPanel(_ e: JournalEntry) -> some View {
        let words = JournalInsight.strippingUsageLine(e.notes)
        let used = JournalInsight.usageNames(e.notes)
        return VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack(spacing: SKSpace.sm) {
                Text(e.condition.emoji).font(.system(size: 22))
                Text(JournalInsight.dayLabel(e.entryDate)).font(SKFont.bodyMedium).foregroundStyle(SKColor.ink)
                SKChip(e.condition.label, tone: e.condition.tone)
                Spacer(minLength: 0)
            }
            if !words.isEmpty {
                Text(words).font(SKFont.secondary).foregroundStyle(SKColor.muted)
            }
            if !used.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(used.enumerated()), id: \.offset) { _, n in SKChip(shortName(n)) }
                }
            }
            SKLinkButton(title: "Delete this entry", chevron: false) { pendingDelete = e }
        }
    }

    private func backfillPanel(_ day: String) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("Nothing logged for \(JournalInsight.dayLabel(day)).")
                .font(SKFont.bodyMedium).foregroundStyle(SKColor.ink)
            conditionButtons(selected: nil) { c in Task { await commit(c, day: day) } }
            Text("You can fill in any day you missed.")
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
        }
    }

    // MARK: - Go deeper

    @ViewBuilder
    private var goDeeperSection: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            switch env.journal.analysis {
            case .idle:
                SKCard {
                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        Text("Go deeper").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        Text("Day counts only see so much. Skintel can read every entry and every product you own, end to end.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        SKButton(title: "Read my 90 days", kind: .secondary) { Task { await analyze() } }
                            .disabled(env.journal.entries.count < 3)
                    }
                }
            case .loading:
                SKCard { HStack(spacing: SKSpace.md) { ProgressView().tint(SKColor.primary); Text("Reading \(env.journal.entries.count) entries…").font(SKFont.secondary).foregroundStyle(SKColor.muted) } }
            case .failed(let e):
                SKCard { VStack(alignment: .leading, spacing: SKSpace.md) { SKInlineError(message: e.userMessage); SKButton(title: "Try again", kind: .secondary) { Task { await analyze() } } } }
            case .loaded(let a):
                SKCard(tint: a.suspects.isEmpty ? .good : .caution) {
                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        Text(a.suspects.isEmpty ? "Nothing stands out yet" : "\(a.suspects.count) thing\(a.suspects.count == 1 ? "" : "s") worth a look")
                            .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        if let s = a.summary, !s.isEmpty { Text(s).font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                        SKLinkButton(title: "See what your shelf shares") { path.append(.culprits) }
                    }
                }
            }
        }
    }

    private func analyze() async {
        guard env.subscription.entitlement.isPro else { openPaywall(.journalAnalysis); return }
        await env.journal.analyze()
        if case .failed(let e) = env.journal.analysis, e.requiresPaywall { openPaywall(.journalAnalysis) }
    }

    // MARK: - Recent notes

    /// Only entries that still say something once the machine-written usage line is
    /// stripped. Everything else is already fully represented by the calendar above —
    /// that is the whole dedupe rule.
    private var recentNoted: [JournalEntry] {
        Array(env.journal.entries
            .filter { $0.entryDate != todayKey && !JournalInsight.strippingUsageLine($0.notes).isEmpty }
            .prefix(5))
    }

    @ViewBuilder
    private var recentNotesSection: some View {
        if case .failed(let e) = env.journal.state {
            SKErrorState(error: e) { Task { await env.journal.load() } }
        } else if !recentNoted.isEmpty {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                SKSectionHeader(title: "Recent notes")
                ForEach(recentNoted) { e in
                    noteRow(e)
                        .contextMenu { Button(role: .destructive) { pendingDelete = e } label: { Label("Delete", systemImage: "trash") } }
                }
            }
        }
    }

    private func noteRow(_ e: JournalEntry) -> some View {
        SKCard(padding: SKSpace.md) {
            HStack(alignment: .top, spacing: SKSpace.md) {
                Text(e.condition.emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(JournalInsight.dayLabel(e.entryDate))
                            .font(SKFont.bodyMedium).foregroundStyle(SKColor.ink)
                        SKChip(e.condition.label, tone: e.condition.tone)
                    }
                    Text(JournalInsight.strippingUsageLine(e.notes))
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(3)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
