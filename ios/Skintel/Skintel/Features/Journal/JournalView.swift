import SwiftUI
import SkintelCore

/// Design §14 with the product's real four states. "Used today" chips come from the
/// routine and are written into the entry's notes ("Used: …") so the journal AI sees
/// what was applied — the journal API has no separate usage field.
struct JournalView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

    @State private var condition: JournalCondition?
    @State private var notes = ""
    @State private var includeRoutine = true
    @State private var saving = false
    @State private var error: String?
    @State private var primed = false
    @State private var pendingDelete: JournalEntry?
    @State private var path: [AppDestination] = []
    @FocusState private var notesFocused: Bool

    private var todayKey: String { ISO8601.dayString(Date()) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Journal").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                        Spacer()
                        if env.journal.streak > 0 {
                            SKChip("🔥 \(env.journal.streak)-day streak", tone: .caution)
                        }
                    }
                    .padding(.top, SKSpace.md)

                    entryCard
                    weekStrip
                    analysisSection
                    history
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await env.journal.load() }
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
        .confirmationDialog("Delete this entry?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let e = pendingDelete else { return }
                Task { try? await env.journal.delete(e); Haptics.success() }
            }
        }
    }

    private func prime() {
        guard !primed, let t = env.journal.today else { return }
        primed = true
        condition = t.condition
        notes = t.notes ?? ""
        includeRoutine = false
    }

    // MARK: Today

    private var entryCard: some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                Text(env.journal.today == nil ? "How's your skin today?" : "Today's entry")
                    .font(SKFont.sans(19, weight: .semibold, relativeTo: .title3)).foregroundStyle(SKColor.ink)

                HStack(spacing: SKSpace.sm) {
                    ForEach(JournalCondition.allCases, id: \.self) { c in
                        Button {
                            condition = c; Haptics.selection()
                        } label: {
                            VStack(spacing: 6) {
                                Text(c.emoji).font(.system(size: 24))
                                Text(c.label).font(SKFont.sans(13, weight: .semibold, relativeTo: .caption)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(condition == c ? c.tone.fg : SKColor.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 84)
                            .background(condition == c ? c.tone.bg : SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                                .stroke(condition == c ? c.tone.fg : SKColor.line, lineWidth: condition == c ? 1.5 : 1))
                        }
                        .buttonStyle(SKPressStyle())
                        .accessibilityLabel(c.label)
                        .accessibilityAddTraits(condition == c ? [.isButton, .isSelected] : .isButton)
                    }
                }

                SKTextEditor(placeholder: "Skin felt calm all day. New toner didn't sting…", text: $notes, minHeight: 96)
                    .focused($notesFocused)

                routineChips

                if let error { SKInlineError(message: error) }

                SKButton(title: env.journal.today == nil ? "Save today's entry" : "Update today's entry", isLoading: saving) { Task { await save() } }
                    .disabled(condition == nil)
            }
        }
    }

    @ViewBuilder
    private var routineChips: some View {
        let slot = RoutineStore.currentSlot()
        let names = (env.routine.ids(.am) + env.routine.ids(.pm)).compactMap { env.products.product(id: $0)?.product.productName }
        if !names.isEmpty {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                HStack {
                    SKFieldLabel("Used today")
                    Spacer()
                    Toggle("Include routine", isOn: $includeRoutine).labelsHidden().tint(SKColor.goodFg)
                        .accessibilityLabel("Log today's routine in this entry")
                }
                FlowLayout(spacing: 6) {
                    ForEach(Array(names.prefix(5).enumerated()), id: \.offset) { _, n in SKChip(shortName(n)) }
                    if names.count > 5 { SKChip("+\(names.count - 5) from \(slot.rawValue)") }
                }
                .opacity(includeRoutine ? 1 : 0.45)
            }
        }
    }

    private func shortName(_ s: String) -> String {
        let w = s.split(separator: " ")
        return w.count > 2 ? w.prefix(2).joined(separator: " ") : s
    }

    private func save() async {
        guard let condition else { return }
        saving = true; error = nil
        defer { saving = false }
        var text = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let used = (env.routine.ids(.am) + env.routine.ids(.pm)).compactMap { env.products.product(id: $0)?.product.productName }
        if includeRoutine, !used.isEmpty, !text.contains("Used:") {
            text += (text.isEmpty ? "" : "\n") + "Used: " + used.joined(separator: ", ")
        }
        do {
            try await env.journal.save(day: todayKey, condition: condition, notes: text.isEmpty ? nil : String(text.prefix(2000)))
            env.analytics.track(.journalSaved)
            Haptics.success()
            notesFocused = false
            includeRoutine = false
            notes = text
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: Week

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("This week").font(SKFont.section).foregroundStyle(SKColor.ink)
            SKCard(padding: SKSpace.lg) {
                HStack {
                    ForEach(Array(env.journal.week.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 10) {
                            Text(DateFormatting.weekdayShort(day.date)).font(SKFont.mono(11)).textCase(.uppercase).foregroundStyle(SKColor.muted)
                            SKDot(tone: day.entry?.condition.tone ?? .neutral, size: 16)
                                .overlay {
                                    if Calendar.current.isDateInToday(day.date) { Circle().stroke(SKColor.primary, lineWidth: 2).frame(width: 22, height: 22) }
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(DateFormatting.weekdayShort(day.date)): \(day.entry?.condition.label ?? "not logged")")
                    }
                }
            }
        }
    }

    // MARK: Analysis

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            switch env.journal.analysis {
            case .idle:
                SKCard {
                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        Text("Find the pattern").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        Text(env.journal.entries.count < 5
                             ? "Log five or more days and Skintel can line your entries up against your shelf. \(env.journal.entries.count)/5 so far."
                             : "Skintel reads your last 90 days against your shelf and names what keeps showing up before a bad day.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        SKButton(title: "Analyze my journal", kind: .secondary, systemImage: "sparkles") { Task { await analyze() } }
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
                        Text(a.suspects.isEmpty ? "No clear suspect yet" : "\(a.suspects.count) suspect\(a.suspects.count == 1 ? "" : "s") in your journal")
                            .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        if let s = a.summary, !s.isEmpty { Text(s).font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                        SKLinkButton(title: "See culprits") { path.append(.culprits) }
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

    // MARK: History

    @ViewBuilder
    private var history: some View {
        let past = env.journal.entries.filter { $0.entryDate != todayKey }
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text("Earlier").font(SKFont.section).foregroundStyle(SKColor.ink)
                ForEach(past.prefix(30)) { e in
                    SKCard(padding: SKSpace.md) {
                        HStack(alignment: .top, spacing: SKSpace.md) {
                            Text(e.condition.emoji).font(.system(size: 22))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(ISO8601.date(e.entryDate).map(DateFormatting.short) ?? e.entryDate)
                                        .font(SKFont.bodyMedium).foregroundStyle(SKColor.ink)
                                    SKChip(e.condition.label, tone: e.condition.tone)
                                }
                                if let n = e.notes, !n.isEmpty {
                                    Text(n).font(SKFont.secondary).foregroundStyle(SKColor.muted).lineLimit(3)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .contextMenu { Button(role: .destructive) { pendingDelete = e } label: { Label("Delete", systemImage: "trash") } }
                }
            }
        } else if case .failed(let e) = env.journal.state {
            SKErrorState(error: e) { Task { await env.journal.load() } }
        }
    }
}

// MARK: - Check-in detail sheet

/// The check-in with a little more detail: how the skin is, what specifically, and an
/// optional note. The mood is saved as the server's condition; symptoms ride along in the
/// note as a "Symptoms:" line, which the journal analysis already reads.
struct CheckInSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var condition: JournalCondition?
    @State private var symptoms: Set<String> = []
    @State private var note = ""
    @State private var primed = false
    @State private var saving = false
    @State private var error: String?

    private static let symptomOptions = ["Redness", "Stinging", "Dryness", "Flaking", "Bumps", "Oily T-zone", "Itching"]
    private static let symptomPrefix = "Symptoms: "

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How's your skin today?").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                        Text("One tap is enough. The rest is optional.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: SKSpace.sm), GridItem(.flexible(), spacing: SKSpace.sm)], spacing: SKSpace.sm) {
                        ForEach(JournalCondition.allCases, id: \.self) { c in
                            MoodChoiceButton(condition: c, selected: condition == c) {
                                condition = c
                                Haptics.selection()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        SKFieldLabel("Anything specific? · optional")
                        FlowLayout(spacing: SKSpace.sm) {
                            ForEach(Self.symptomOptions, id: \.self) { s in
                                SKSelectChip(title: s, selected: symptoms.contains(s)) {
                                    if symptoms.contains(s) { symptoms.remove(s) } else { symptoms.insert(s) }
                                    Haptics.selection()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        SKFieldLabel("Note · optional")
                        SKTextEditor(placeholder: "Anything else worth remembering…", text: $note, minHeight: 90)
                    }

                    if let error { SKInlineError(message: error) }

                    SKButton(title: "Save for today", isLoading: saving) { Task { await save() } }
                        .disabled(condition == nil)
                }
                .skPagePadding()
                .padding(.top, SKSpace.md)
                .padding(.bottom, SKSpace.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .skPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.font(SKFont.bodyMedium) } }
        }
        .tint(SKColor.primary)
        .task {
            await env.journal.load()
            prime()
        }
    }

    /// Start from today's saved entry, splitting the "Symptoms:" line back out of the note.
    private func prime() {
        guard !primed, env.journal.state.value != nil else { return }
        primed = true
        guard let t = env.journal.today else { return }
        condition = t.condition
        var rest: [String] = []
        for line in (t.notes ?? "").components(separatedBy: "\n") {
            if line.hasPrefix(Self.symptomPrefix) {
                let names = line.dropFirst(Self.symptomPrefix.count).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                symptoms = Set(names)
            } else {
                rest.append(line)
            }
        }
        note = rest.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        guard let condition else { return }
        saving = true
        error = nil
        defer { saving = false }
        var lines: [String] = []
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { lines.append(trimmed) }
        let chosen = Self.symptomOptions.filter { symptoms.contains($0) }
        if !chosen.isEmpty { lines.append(Self.symptomPrefix + chosen.joined(separator: ", ")) }
        let text = lines.joined(separator: "\n")
        do {
            try await env.journal.save(day: ISO8601.dayString(Date()), condition: condition, notes: text.isEmpty ? nil : String(text.prefix(2000)))
            env.analytics.track(.journalSaved)
            Haptics.success()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
            Haptics.error()
        }
    }
}

// MARK: - Insights tab

/// The weekly picture, built only from what the person has actually done: routine ticks,
/// skin check-ins and their shelf. Nothing here is estimated; when there isn't enough data
/// it says so.
struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var path: [AppDestination] = []
    @State private var showJournal = false
    @State private var showCheckIn = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Insights").font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                        Text("Your last seven days").font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                    }
                    .padding(.top, SKSpace.md)

                    consistencyCard
                    skinDaysCard
                    suspectsCard
                    patternRow
                    historyRow
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
            }
            .refreshable {
                await env.journal.load()
                await env.products.load()
            }
            .skPageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppDestination.self) { d in
                switch d {
                case .culprits: CulpritsView()
                case .routine: RoutineView()
                default: EmptyView()
                }
            }
        }
        .tint(SKColor.primary)
        .sheet(isPresented: $showJournal) { JournalView() }
        .sheet(isPresented: $showCheckIn) { CheckInSheet() }
        .task { await env.journal.load() }
    }

    // MARK: Routine kept

    private var consistencyCard: some View {
        let hasRoutine = !env.routine.ids(.am).isEmpty || !env.routine.ids(.pm).isEmpty
        return SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text("Routine kept").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                if hasRoutine {
                    ForEach(RoutineStore.Slot.allCases) { slot in
                        if !env.routine.ids(slot).isEmpty { consistencyRow(slot) }
                    }
                    Text("A day counts when every step in that routine is ticked on Today.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                } else {
                    Text("Build your routine and tick it off on Today to see how consistent you are.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    SKButton(title: "Build your routine", kind: .secondary) { path.append(.routine) }
                }
            }
        }
    }

    private func consistencyRow(_ slot: RoutineStore.Slot) -> some View {
        let n = env.routine.daysCompleted(slot)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(slot == .am ? "Morning" : "Night").font(SKFont.sans(15, weight: .medium, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                Spacer()
                Text("\(n) of 7").font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
            }
            SKProgressBar(fraction: Double(n) / 7, tone: n >= 5 ? .good : .neutral, height: 6)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Skin days

    private var skinDaysCard: some View {
        let week = env.journal.week
        let logged = week.filter { $0.entry != nil }.count
        let clear = week.filter { $0.entry?.condition == .clear }.count
        return SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(logged == 0 ? "No check-ins yet this week" : "\(clear) clear \(clear == 1 ? "day" : "days") this week")
                        .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Spacer()
                    if env.journal.state.value != nil && env.journal.today == nil {
                        Button("Check in") { showCheckIn = true }
                            .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                            .foregroundStyle(SKColor.primary)
                    }
                }
                HStack {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 10) {
                            Text(DateFormatting.weekdayShort(day.date)).font(SKFont.mono(11)).textCase(.uppercase).foregroundStyle(SKColor.muted)
                            SKDot(tone: day.entry?.condition.tone ?? .neutral, size: 16)
                                .overlay {
                                    if Calendar.current.isDateInToday(day.date) { Circle().stroke(SKColor.primary, lineWidth: 2).frame(width: 22, height: 22) }
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(DateFormatting.weekdayShort(day.date)): \(day.entry?.condition.checkInLabel ?? "not logged")")
                    }
                }
                if logged < 3 {
                    Text("Insights get sharper after about a week of check-ins.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                }
            }
        }
    }

    // MARK: Suspects and patterns

    @ViewBuilder
    private var suspectsCard: some View {
        let culprits = env.products.culprits
        let bad = env.products.badProductCount
        Button { path.append(.culprits) } label: {
            SKCard(tint: culprits.all.isEmpty ? nil : SKTone.bad) {
                HStack(spacing: SKSpace.lg) {
                    Image(systemName: culprits.all.isEmpty ? "magnifyingglass" : "exclamationmark.triangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(culprits.all.isEmpty ? SKColor.primary : SKColor.badFg)
                        .frame(width: 48, height: 48)
                        .background(culprits.all.isEmpty ? SKColor.blush : SKColor.badBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        if let top = culprits.all.first {
                            Text("Suspect: \(top.name)").font(SKFont.cardTitle).foregroundStyle(SKColor.ink).lineLimit(2)
                            Text("In \(top.badCount) products that broke you out").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        } else {
                            Text("Culprit detection").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            Text(bad < 2 ? "Mark two products as “Broke out” and Skintel finds what they share."
                                 : "No shared ingredient yet. Add ingredient lists to widen the net.")
                                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                }
            }
        }
        .buttonStyle(SKPressStyle())
    }

    private var patternRow: some View {
        Button { path.append(.culprits) } label: {
            SKCard {
                HStack(spacing: SKSpace.lg) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.primary)
                        .frame(width: 48, height: 48)
                        .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: SKSpace.sm) {
                            Text("Journal patterns").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                            if !env.subscription.entitlement.isPro { SKChip("Pro") }
                        }
                        Text("Lines up your check-ins with when each product joined your shelf.")
                            .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                }
            }
        }
        .buttonStyle(SKPressStyle())
    }

    private var historyRow: some View {
        Button { showJournal = true } label: {
            SKCard {
                HStack(spacing: SKSpace.lg) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.ink)
                        .frame(width: 48, height: 48)
                        .background(SKColor.neutralChip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Check-in history").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        Text("Every day you've logged, with your notes.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(SKColor.muted)
                }
            }
        }
        .buttonStyle(SKPressStyle())
    }
}
