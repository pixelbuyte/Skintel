import SwiftUI
import SkintelCore

/// Design §14 with the product's real four states. "Used today" chips come from the
/// routine and are written into the entry's notes ("Used: …") so the journal AI sees
/// what was applied — the journal API has no separate usage field.
struct JournalView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @Environment(\.dismiss) private var dismiss

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
                            SKChip("\(env.journal.streak)-day streak", tone: .good)
                        }
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(SKColor.ink).frame(width: 36, height: 36)
                                .background(SKColor.neutralChip, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
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
                if case .culprits = d { TriggersView() }
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
                        HStack(spacing: SKSpace.md) {
                            if a.suspects.isEmpty { SKDrop("DropCheckIn", size: 56) }
                            Text(a.suspects.isEmpty ? "No clear suspect yet" : "\(a.suspects.count) suspect\(a.suspects.count == 1 ? "" : "s") in your journal")
                                .font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                        }
                        if let s = a.summary, !s.isEmpty { Text(s).font(SKFont.secondary).foregroundStyle(SKColor.ink) }
                        SKLinkButton(title: "See triggers") {
                            if env.subscription.entitlement.isPro { path.append(.culprits) } else { openPaywall(.culprits) }
                        }
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

// MARK: - Guided check-in

/// One question per screen, three at most, then a short recap and a way into Ask Skintel.
/// Mornings ask about waking skin and yesterday; nights ask how the day went. Everything is
/// today's journal entry: the mood as the condition, the rest as "Symptoms:", "Yesterday:"
/// and "Today:" lines in the note, which the journal analysis and Ask Skintel both read.
struct CheckInSheet: View {
    enum Part: Sendable {
        case morning, night
        static func now(_ date: Date = Date()) -> Part {
            (4..<15).contains(Calendar.current.component(.hour, from: date)) ? .morning : .night
        }
    }

    var part: Part = .now()

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var condition: JournalCondition?
    @State private var symptoms: Set<String> = []
    @State private var factors: Set<String> = []
    @State private var note = ""
    @State private var carried: [String] = []
    @State private var primed = false
    @State private var saving = false
    @State private var error: String?
    @State private var showAsk = false

    static let symptomOptions = ["Redness", "Stinging", "Dryness", "Flaking", "Bumps", "Oily T-zone", "Itching"]
    static let symptomPrefix = "Symptoms: "
    static let yesterdayPrefix = "Yesterday: "
    static let todayPrefix = "Today: "
    private static let morningFactors = ["New product", "Late night", "Stress", "Workout", "Lots of sun", "Heavy makeup"]
    private static let nightFactors = ["Sun", "Sweat", "Makeup", "Stress", "Picked at it", "Tried something new"]

    private var factorOptions: [String] { part == .morning ? Self.morningFactors : Self.nightFactors }
    private var factorPrefix: String { part == .morning ? Self.yesterdayPrefix : Self.todayPrefix }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                if step < 3 { question } else { done }
            }
            .skPagePadding()
            .padding(.top, SKSpace.sm)
            .padding(.bottom, SKSpace.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                if part == .night {
                    RadialGradient(colors: [Color(hex: 0xD6D2E8).opacity(0.6), .clear], center: .topTrailing, startRadius: 0, endRadius: 440)
                        .ignoresSafeArea()
                }
            }
            .skPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == 1 || step == 2 ? "Back" : "Close") { back() }.font(SKFont.bodyMedium)
                }
                ToolbarItem(placement: .principal) { progress }
            }
        }
        .tint(SKColor.primary)
        .skAskSheet(isPresented: $showAsk, initialQuestion: askPrompt)
        .task {
            await env.journal.load()
            prime()
        }
    }

    // MARK: Questions

    @ViewBuilder
    private var question: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kicker).font(SKFont.label).tracking(1.2).foregroundStyle(SKColor.muted)
            Text(title).font(SKFont.hero).foregroundStyle(SKColor.ink).fixedSize(horizontal: false, vertical: true)
            Text(hint).font(SKFont.secondary).foregroundStyle(SKColor.muted)
        }
        .padding(.top, SKSpace.md)
        .id(step)
        switch step {
        case 0:
            conditionChoices
        case 1:
            chips(Self.symptomOptions, selection: $symptoms)
        default:
            chips(factorOptions, selection: $factors)
            if part == .night {
                SKTextEditor(placeholder: "Anything else about today? (optional)", text: $note, minHeight: 84)
            }
        }
        if let error { SKInlineError(message: error) }
        Spacer(minLength: 0)
        HStack(spacing: SKSpace.sm) {
            if step > 0 && currentSelectionEmpty {
                SKButton(title: "Skip", kind: .secondary) { advance() }
            }
            SKButton(title: step == 2 ? "Save" : "Next", isLoading: saving) { advance() }
                .disabled(condition == nil)
        }
    }

    private var conditionChoices: some View {
        VStack(spacing: SKSpace.sm) {
            ForEach(JournalCondition.allCases, id: \.self) { c in
                Button {
                    condition = c
                    Haptics.selection()
                    Task {
                        try? await Task.sleep(for: .milliseconds(220))
                        if step == 0 { go(to: 1) }
                    }
                } label: {
                    HStack(spacing: SKSpace.md) {
                        Circle().fill(c.logTint.dot).frame(width: 12, height: 12)   // same tints as Today's log
                        Text(c.checkInLabel).font(SKFont.sans(18, weight: .semibold, relativeTo: .title3)).foregroundStyle(SKColor.ink)
                        Spacer()
                        if condition == c {
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(SKColor.primary)
                        }
                    }
                    .padding(.horizontal, SKSpace.lg)
                    .frame(height: 60)
                    .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(condition == c ? SKColor.primary : SKColor.line, lineWidth: condition == c ? 2 : 1))
                }
                .buttonStyle(SKPressStyle())
                .accessibilityLabel(c.checkInLabel)
                .accessibilityAddTraits(condition == c ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func chips(_ options: [String], selection: Binding<Set<String>>) -> some View {
        FlowLayout(spacing: SKSpace.sm) {
            ForEach(options, id: \.self) { o in
                SKSelectChip(title: o, selected: selection.wrappedValue.contains(o)) {
                    if selection.wrappedValue.contains(o) { selection.wrappedValue.remove(o) } else { selection.wrappedValue.insert(o) }
                    Haptics.selection()
                }
            }
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? SKColor.primary : SKColor.ink.opacity(0.15))
                    .frame(width: i == min(step, 2) && step < 3 ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step < 3 ? "Question \(step + 1) of 3" : "Done")
    }

    private var kicker: String {
        let label = part == .morning ? "MORNING CHECK-IN" : "NIGHT CHECK-IN"
        return step == 0 ? "\(label) · 1 OF 3" : "\(step + 1) OF 3"
    }

    private var title: String {
        switch (step, part) {
        case (0, .morning):
            if let name = env.session.user?.firstName { return "Morning, \(name). How's your skin?" }
            return "Morning. How's your skin?"
        case (0, .night): return "How did your skin hold up today?"
        case (1, .morning): return "Anything you notice?"
        case (1, .night): return "Anything you noticed today?"
        case (_, .morning): return "Anything different yesterday?"
        case (_, .night): return "What was today like?"
        }
    }

    private var hint: String {
        switch step {
        case 0: return part == .night && env.journal.today != nil ? "Updates today's entry." : "One tap is enough."
        case 1: return "Pick any, or skip."
        default: return part == .morning ? "Skintel lines these up with how your skin reacts." : "Last one. A note is optional."
        }
    }

    private var currentSelectionEmpty: Bool {
        step == 1 ? symptoms.isEmpty : factors.isEmpty && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Done

    @ViewBuilder
    private var done: some View {
        VStack(spacing: SKSpace.md) {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(SKColor.cream)
                .frame(width: 72, height: 72)
                .background(SKColor.primary, in: Circle())
                .skPrimaryGlow()
            Text(env.journal.streak > 1 ? "Logged. \(env.journal.streak)-day streak." : "Logged for today.")
                .font(SKFont.hero).foregroundStyle(SKColor.ink).multilineTextAlignment(.center)
            Text(recap).font(SKFont.sans(16, relativeTo: .body)).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SKSpace.xl)

        VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack(spacing: SKSpace.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SKColor.cream)
                    .frame(width: 32, height: 32)
                    .background(SKColor.primary, in: Circle())
                Text("Go deeper with Ask Skintel").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
            }
            Text("It already knows today's answers, your shelf and your routine.")
                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
            Button { showAsk = true } label: {
                HStack(spacing: SKSpace.sm) {
                    Text(askPrompt).font(SKFont.sans(15, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                        .multilineTextAlignment(.leading).lineLimit(2)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SKColor.cream)
                        .frame(width: 32, height: 32)
                        .background(SKColor.primary, in: Circle())
                }
                .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6)
                .background(SKColor.bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(SKPressStyle())
        }
        .padding(SKSpace.lg)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(SKColor.line))

        Spacer(minLength: 0)
        SKButton(title: "Done", kind: .secondary) { dismiss() }
    }

    /// Only what the journal actually shows: vs yesterday, a repeating symptom, a new product.
    private var recap: String {
        guard let condition else { return "" }
        var lines: [String] = []
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        if let y = env.journal.entry(on: ISO8601.dayString(yesterday)) {
            let d = Self.rank(condition) - Self.rank(y.condition)
            lines.append(d < 0 ? "Calmer than yesterday." : d > 0 ? "Rougher than yesterday." : "Same as yesterday.")
        }
        var counts: [String: Int] = [:]
        for day in env.journal.week {
            for s in Self.lineValues(day.entry?.notes, prefix: Self.symptomPrefix) { counts[s, default: 0] += 1 }
        }
        if let top = counts.max(by: { $0.value < $1.value }), top.value >= 2 {
            lines.append("\(top.key) showed up \(top.value) times this week.")
        }
        if factors.contains("New product") || factors.contains("Tried something new") {
            lines.append("Skintel will line this up with what you added.")
        }
        return lines.isEmpty ? "Every check-in makes the patterns sharper." : lines.joined(separator: " ")
    }

    private var askPrompt: String {
        let symptom = Self.symptomOptions.first { symptoms.contains($0) }?.lowercased()
        if condition == .clear {
            return part == .morning ? "What should I keep doing to stay clear?" : "Anything I should add to keep my skin this calm?"
        }
        if part == .night {
            return symptom.map { "My skin had \($0) today. What should I skip tonight?" } ?? "What should I skip tonight after today?"
        }
        return symptom.map { "Why is my skin showing \($0) this morning?" } ?? "What should I change this morning?"
    }

    // MARK: Flow

    private func advance() {
        if step < 2 { go(to: step + 1) } else { Task { await save() } }
    }

    private func go(to s: Int) {
        withAnimation(reduceMotion ? nil : SKAnimation.ios(0.35)) { step = s }
    }

    private func back() {
        if step == 1 || step == 2 { go(to: step - 1) } else { dismiss() }
    }

    /// Start from today's entry: its mood and symptoms, this part's factors, the free note,
    /// and the other part's factor line kept as-is.
    private func prime() {
        guard !primed, env.journal.state.value != nil else { return }
        primed = true
        guard let t = env.journal.today else { return }
        condition = t.condition
        var rest: [String] = []
        for line in (t.notes ?? "").components(separatedBy: "\n") {
            if line.hasPrefix(Self.symptomPrefix) {
                symptoms = Set(Self.lineValues(line, prefix: Self.symptomPrefix))
            } else if line.hasPrefix(factorPrefix) {
                factors = Set(Self.lineValues(line, prefix: factorPrefix))
            } else if line.hasPrefix(Self.yesterdayPrefix) || line.hasPrefix(Self.todayPrefix) {
                carried.append(line)
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
        let chosenSymptoms = Self.symptomOptions.filter { symptoms.contains($0) }
        if !chosenSymptoms.isEmpty { lines.append(Self.symptomPrefix + chosenSymptoms.joined(separator: ", ")) }
        lines.append(contentsOf: carried)
        let chosenFactors = factorOptions.filter { factors.contains($0) }
        if !chosenFactors.isEmpty {
            lines.append(factorPrefix + chosenFactors.joined(separator: ", "))
        } else if part == .night {
            // Marks the night check-in as done even when nothing stood out.
            lines.append(factorPrefix + "Nothing notable")
        }
        let text = lines.joined(separator: "\n")
        do {
            try await env.journal.save(day: ISO8601.dayString(Date()), condition: condition, notes: text.isEmpty ? nil : String(text.prefix(2000)))
            env.analytics.track(.journalSaved)
            Haptics.success()
            go(to: 3)
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: Helpers

    static func lineValues(_ notes: String?, prefix: String) -> [String] {
        guard let line = (notes ?? "").components(separatedBy: "\n").first(where: { $0.hasPrefix(prefix) }) else { return [] }
        return line.dropFirst(prefix.count).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func hasLine(_ notes: String?, prefix: String) -> Bool {
        (notes ?? "").components(separatedBy: "\n").contains { $0.hasPrefix(prefix) }
    }

    private static func rank(_ c: JournalCondition) -> Int {
        switch c {
        case .clear: 0
        case .mild: 1
        case .moderate: 2
        case .breakout: 3
        }
    }
}

/// Opens the check-in by itself once each morning and evening while that part of the day
/// hasn't been answered yet. Can be turned off in You › Personalization.
enum CheckInPrompt {
    static let enabledKey = "checkin.autoPrompt"
    static let lastKey = "checkin.lastPrompt"

    /// The part of the day to ask about right now, if now is a prompting window.
    static func window(_ date: Date = Date()) -> CheckInSheet.Part? {
        let hour = Calendar.current.component(.hour, from: date)
        if (5..<12).contains(hour) { return .morning }
        if (18..<24).contains(hour) { return .night }
        return nil
    }
}

// MARK: - Insights tab

/// The weekly picture, built only from what the person has actually done: routine ticks,
/// skin check-ins and their shelf. Nothing here is estimated; when there isn't enough data
/// it says so.
struct InsightsView: View {
    /// Where "back" goes from the Free-plan wall.
    var leave: (() -> Void)? = nil
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall
    @State private var path: [AppDestination] = []
    @State private var showJournal = false
    @State private var showCheckIn = false

    var body: some View {
        if env.subscription.entitlement.isPro {
            insights
        } else {
            ProLockedView(feature: .insights, leave: leave)
        }
    }

    private var insights: some View {
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
            .skHint(.insights)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppDestination.self) { d in
                switch d {
                case .culprits: TriggersView()
                case .routine: RoutineView()
                default: EmptyView()
                }
            }
        }
        .tint(SKColor.primary)
        .sheet(isPresented: $showJournal) { JournalView().skProGates() }
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
        Button {
            if env.subscription.entitlement.isPro { path.append(.culprits) } else { openPaywall(.culprits) }
        } label: {
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
                            Text("Triggers").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
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
        Button {
            if env.subscription.entitlement.isPro { path.append(.culprits) } else { openPaywall(.journalAnalysis) }
        } label: {
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
                            if !env.subscription.entitlement.isPro { SKChip("Skintel+") }
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
