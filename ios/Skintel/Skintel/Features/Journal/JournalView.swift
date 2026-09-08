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
