import SwiftUI
import SkintelCore

/// One question of the face scan quiz (PRO-SPEC §4). Wording is cosmetic only (§6).
struct FaceQuestion: Identifiable, Sendable {
    struct Row: Sendable {
        var key: String
        var label: String?
        var options: [String]
        var multi = false
        /// Options that clear the others when picked ("None", "Not sure").
        var exclusive: Set<String> = []
    }

    var id: String
    var title: String
    var hint: String?
    var rows: [Row]
    /// Q19 is a note only; it never blocks.
    var noteOnly = false
}

enum FaceQuestions {
    static let lockOptions: [String: FaceLock] = [
        "Pregnant or trying": .pregnantOrTrying,
        "Breastfeeding": .breastfeeding,
        "Prescription skin medicine": .skinMedicine,
    ]

    /// Q1–Q7. Under-18s don't see the pregnancy options (PRO-SPEC §7.2, the safe default).
    static func core(under18: Bool, triggerHint: String?) -> [FaceQuestion] {
        let locks = under18 ? ["Prescription skin medicine", "None of these"]
                            : ["Pregnant or trying", "Breastfeeding", "Prescription skin medicine", "None of these"]
        return [
            FaceQuestion(id: "q1", title: "30 minutes after washing, with nothing on, your skin feels…",
                         rows: [.init(key: "q1", options: ["Tight", "Comfortable", "Shiny on the T-zone", "Shiny all over"])]),
            FaceQuestion(id: "q2", title: "Do products sting or burn when you put them on?",
                         rows: [.init(key: "q2", options: ["Never", "Sometimes", "Often", "Only certain ones"])]),
            FaceQuestion(id: "q3", title: "Which actives are you using right now?", hint: "Pick all that apply.",
                         rows: [.init(key: "q3", options: ["Retinoid", "AHA or BHA", "Vitamin C", "Benzoyl peroxide", "Niacinamide", "None"],
                                      multi: true, exclusive: ["None"])]),
            FaceQuestion(id: "q4", title: "When a blemish heals, the mark it leaves is usually…",
                         rows: [.init(key: "q4", options: ["Pink or red", "Brown", "No mark", "Not sure"])]),
            FaceQuestion(id: "q5", title: "Anything we should be careful with?",
                         hint: "We leave out ingredients that are not a good fit. Check with your doctor too.",
                         rows: [.init(key: "q5", options: locks, multi: true, exclusive: ["None of these"])]),
            FaceQuestion(id: "q6", title: "Ingredients that have bothered you before", hint: triggerHint,
                         rows: [.init(key: "q6", options: ["Fragrance", "Essential oils", "Drying alcohol", "Coconut oil", "Not sure"],
                                      multi: true, exclusive: ["Not sure"])]),
            FaceQuestion(id: "q7", title: "Your main goal, and how many steps you will really do",
                         rows: [.init(key: "q7_goal", label: "Goal", options: ["Fewer breakouts", "Calmer redness", "Less shine", "More even tone"]),
                                .init(key: "q7_steps", label: "Steps", options: ["3", "4 to 5", "6 or more"])]),
        ]
    }

    /// Q8–Q19, opt-in. Q16 (supplements) is left out for under-18s.
    static func deep(under18: Bool) -> [FaceQuestion] {
        var list: [FaceQuestion] = [
            FaceQuestion(id: "q8", title: "Do you get tiny, same-size bumps that itch, on your forehead or chest?",
                         hint: "Helps us pick products that suit this pattern.",
                         rows: [.init(key: "q8", options: ["Often", "Sometimes", "Never", "Not sure"])]),
            FaceQuestion(id: "q9", title: "Your breakouts are mostly…",
                         rows: [.init(key: "q9", options: ["Deep, sore bumps", "Small clogged pores", "Both", "Not sure"])]),
            FaceQuestion(id: "q10", title: "Do breakouts around your jaw follow a monthly cycle?",
                         rows: [.init(key: "q10", options: ["Yes", "Sometimes", "No", "Not sure"])]),
            FaceQuestion(id: "q11", title: "Does your face flush with any of these?", hint: "Pick all that apply.",
                         rows: [.init(key: "q11", options: ["Heat", "Spicy food", "Alcohol", "None"], multi: true, exclusive: ["None"])]),
            FaceQuestion(id: "q12", title: "By early afternoon, does shine come through your SPF?",
                         rows: [.init(key: "q12", options: ["Most days", "Sometimes", "No", "I don't wear SPF"])]),
            FaceQuestion(id: "q13", title: "How hot are your showers?",
                         rows: [.init(key: "q13", options: ["Hot", "Warm", "Cool"])]),
            FaceQuestion(id: "q14", title: "Which of these are part of your week?", hint: "Pick all that apply.",
                         rows: [.init(key: "q14", options: ["A lot of sweat", "A helmet", "A face mask", "Pillowcase changed weekly", "None"],
                                      multi: true, exclusive: ["None"])]),
            FaceQuestion(id: "q15", title: "What is the air like where you spend your day?", hint: "Pick all that apply.",
                         rows: [.init(key: "q15", options: ["Humid", "Dry", "Air conditioning", "Heating"], multi: true)]),
            FaceQuestion(id: "q16", title: "Do you take any of these?", hint: "Pick all that apply.",
                         rows: [.init(key: "q16", options: ["Whey protein", "Dairy most days", "B12", "Biotin", "None"],
                                      multi: true, exclusive: ["None"])]),
            FaceQuestion(id: "q17", title: "How often do you wear SPF?",
                         rows: [.init(key: "q17", options: ["Every day", "Most days", "Rarely", "Never"])]),
            FaceQuestion(id: "q18", title: "Your sleep and stress lately",
                         rows: [.init(key: "q18_sleep", label: "Sleep", options: ["Under 6 h", "6 to 8 h", "Over 8 h"]),
                                .init(key: "q18_stress", label: "Stress", options: ["Low", "Some", "High"])]),
            FaceQuestion(id: "q19", title: "Anything else about your skin?",
                         hint: "Optional. A routine, a product, a pattern you've noticed.", rows: [], noteOnly: true),
        ]
        if under18 { list.removeAll { $0.id == "q16" } }
        return list
    }

    /// What the app already knows, so the person confirms instead of re-answering (PRO-SPEC §4.2).
    static func prefill(profile: SkinProfile, triggerNames: [String]) -> [String: Set<String>] {
        var out: [String: Set<String>] = [:]
        switch profile.skinType {
        case .oily?: out["q1"] = ["Shiny all over"]
        case .dry?: out["q1"] = ["Tight"]
        case .combination?: out["q1"] = ["Shiny on the T-zone"]
        case .normal?: out["q1"] = ["Comfortable"]
        case .sensitive?, nil: break
        }
        if profile.skinType == .sensitive { out["q2"] = ["Sometimes"] }
        let goal: String? = profile.concerns.contains(.breakouts) ? "Fewer breakouts"
            : profile.concerns.contains(.redness) ? "Calmer redness"
            : profile.concerns.contains(.oiliness) ? "Less shine"
            : profile.concerns.contains(.darkSpots) ? "More even tone" : nil
        if let goal { out["q7_goal"] = [goal] }
        let picked = triggerPicks(triggerNames)
        if !picked.isEmpty { out["q6"] = Set(picked) }
        return out
    }

    /// Q6 options that match an ingredient in Triggers.
    static func triggerPicks(_ names: [String]) -> [String] {
        let lower = names.map { $0.lowercased() }
        var picks: [String] = []
        if lower.contains(where: { $0.contains("fragrance") || $0.contains("parfum") }) { picks.append("Fragrance") }
        if lower.contains(where: { $0.contains(" oil") && !$0.contains("coconut") && ($0.contains("lavender") || $0.contains("peppermint") || $0.contains("tea tree") || $0.contains("citrus") || $0.contains("lemon")) }) {
            picks.append("Essential oils")
        }
        if lower.contains(where: { $0.contains("alcohol denat") || $0 == "alcohol" || $0.contains("sd alcohol") }) { picks.append("Drying alcohol") }
        if lower.contains(where: { $0.contains("coconut") || $0.contains("cocos nucifera") }) { picks.append("Coconut oil") }
        return picks
    }
}

/// Q1–Q7, the checkpoint, and the opt-in deep dive (canvas screen 4).
struct FaceQuizView: View {
    let under18: Bool
    let prefill: [String: Set<String>]
    let triggerHint: String?
    let onClose: () -> Void
    let onFinish: (FaceAnswers) -> Void

    private enum Stage: Equatable { case core(Int), checkpoint, deep(Int) }

    @State private var stage: Stage = .core(0)
    @State private var picks: [String: Set<String>] = [:]
    @State private var notes: [String: String] = [:]
    @State private var noteOpen = false
    @State private var didPrefill = false

    private var core: [FaceQuestion] { FaceQuestions.core(under18: under18, triggerHint: triggerHint) }
    private var deep: [FaceQuestion] { FaceQuestions.deep(under18: under18) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            switch stage {
            case .core(let i): questionPage(core[i], isDeep: false, isLast: false)
            case .deep(let i): questionPage(deep[i], isDeep: true, isLast: i == deep.count - 1)
            case .checkpoint: checkpoint
            }
        }
        .skPageBackground()
        .onAppear {
            guard !didPrefill else { return }
            didPrefill = true
            picks = prefill
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: SKSpace.sm) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.ink).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                Spacer()
                Text(kicker).font(SKFont.mono(12)).tracking(1.5).foregroundStyle(SKColor.ink)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, SKSpace.sm)
            HStack(spacing: SKSpace.xs) {
                ForEach(0..<segmentCount, id: \.self) { i in
                    Capsule().fill(i <= litSegment ? SKColor.primary : SKColor.line).frame(height: 4)
                }
            }
            .skPagePadding()
            .accessibilityHidden(true)
        }
        .padding(.top, SKSpace.md)
    }

    private var kicker: String {
        switch stage {
        case .core(let i): "QUESTION \(i + 1) OF 7"
        case .checkpoint: "CORE PROFILE · 7 OF 7"
        case .deep(let i): "DEEP DIVE · \(i + 8) OF \(7 + deep.count)"
        }
    }

    private var segmentCount: Int {
        if case .deep = stage { return deep.count }
        return core.count
    }

    private var litSegment: Int {
        switch stage {
        case .core(let i): i
        case .checkpoint: core.count
        case .deep(let i): i
        }
    }

    // MARK: Question

    private func questionPage(_ q: FaceQuestion, isDeep: Bool, isLast: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(q.title).font(SKFont.pageTitle).foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let hint = q.hint {
                    Text(hint).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
                ForEach(q.rows, id: \.key) { row in
                    VStack(alignment: .leading, spacing: 10) {
                        if let label = row.label { Text(label.uppercased()).font(SKFont.label).foregroundStyle(SKColor.muted) }
                        ChipFlow(spacing: SKSpace.sm) {
                            ForEach(row.options, id: \.self) { option in
                                optionChip(option, row: row)
                            }
                        }
                    }
                }
                noteArea(q)
            }
            .skPagePadding()
            .padding(.top, 30)
            .padding(.bottom, SKSpace.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: SKSpace.sm) {
                if isDeep {
                    if isLast {
                        SKButton(title: "See my results") { finish() }
                    } else {
                        SKButton(title: "Next") { next() }.disabled(!answered(q))
                        SKButton(title: "See my results now", kind: .ghost) { finish() }
                    }
                } else {
                    SKButton(title: "Next") { next() }.disabled(!answered(q))
                }
            }
            .skPagePadding()
            .padding(.vertical, SKSpace.md)
            .background(SKColor.bg)
        }
    }

    private func optionChip(_ option: String, row: FaceQuestion.Row) -> some View {
        let on = picks[row.key, default: []].contains(option)
        return Button { toggle(option, row: row) } label: {
            Text(option)
                .font(SKFont.sans(15, weight: .medium, relativeTo: .body))
                .foregroundStyle(on ? SKColor.cream : SKColor.ink)
                .padding(.horizontal, SKSpace.lg)
                .frame(minHeight: 44)
                .background(on ? SKColor.primary : SKColor.cream, in: Capsule())
                .overlay(Capsule().stroke(on ? SKColor.primary : SKColor.line, lineWidth: 1))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func noteArea(_ q: FaceQuestion) -> some View {
        if !q.noteOnly {
            Button { noteOpen.toggle() } label: {
                Text("+ Add a detail or product name (optional)")
                    .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(SKColor.primary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        if noteOpen || q.noteOnly {
            VStack(alignment: .leading, spacing: 6) {
                Text("Detail or product name").font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                TextField("e.g. The Ordinary retinol 0.5%, since August", text: noteBinding(q.id), axis: .vertical)
                    .lineLimit(3...6)
                    .font(SKFont.sans(15, relativeTo: .body))
                    .foregroundStyle(SKColor.ink)
                    .padding(SKSpace.md)
                    .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous).stroke(SKColor.line, lineWidth: 1))
            }
        }
    }

    private func noteBinding(_ id: String) -> Binding<String> {
        Binding(get: { notes[id] ?? "" }, set: { notes[id] = String($0.prefix(500)) })
    }

    // MARK: Checkpoint

    private var checkpoint: some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            ZStack {
                Circle().stroke(SKColor.primary, lineWidth: 7).frame(width: 68, height: 68)
                Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundStyle(SKColor.primary)
            }
            .frame(width: 84, height: 84)
            .accessibilityElement()
            .accessibilityLabel("Core profile complete")
            Text("Your core profile is done.").font(SKFont.serif(38, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text("That's enough for your face map and a starter routine. You can stop here, or answer 12 more questions to sharpen it.")
                .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.muted)
            Spacer()
            SKButton(title: "See my results now") { finish() }
            Button { noteOpen = false; stage = .deep(0) } label: {
                VStack(alignment: .leading, spacing: SKSpace.xs) {
                    Text("Go deeper · \(deep.count) more questions, about 90 s").font(SKFont.sans(16, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(SKColor.ink)
                    Text("Sharper on breakout timing, flushing, shine during the day, sleep and diet triggers.")
                        .font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .padding(.horizontal, SKSpace.lg).padding(.vertical, SKSpace.md)
                .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(SKColor.line, lineWidth: 1))
            }
            .buttonStyle(SKPressStyle())
        }
        .skPagePadding()
        .padding(.top, 40)
        .padding(.bottom, 30)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Logic

    private func answered(_ q: FaceQuestion) -> Bool {
        q.noteOnly || q.rows.allSatisfy { !(picks[$0.key] ?? []).isEmpty }
    }

    private func toggle(_ option: String, row: FaceQuestion.Row) {
        Haptics.selection()
        var current = picks[row.key] ?? []
        if !row.multi {
            current = [option]
        } else if current.contains(option) {
            current.remove(option)
        } else if row.exclusive.contains(option) {
            current = [option]
        } else {
            current.subtract(row.exclusive)
            current.insert(option)
        }
        picks[row.key] = current
    }

    private func next() {
        noteOpen = false
        switch stage {
        case .core(let i): stage = i + 1 < core.count ? .core(i + 1) : .checkpoint
        case .deep(let i): if i + 1 < deep.count { stage = .deep(i + 1) } else { finish() }
        case .checkpoint: stage = .deep(0)
        }
    }

    private func back() {
        noteOpen = false
        switch stage {
        case .core(let i): if i == 0 { onClose() } else { stage = .core(i - 1) }
        case .checkpoint: stage = .core(core.count - 1)
        case .deep(let i): stage = i == 0 ? .checkpoint : .deep(i - 1)
        }
    }

    private func finish() {
        let chosen = picks[ "q5"] ?? []
        let locks = FaceLock.allCases.filter { lock in
            chosen.contains { FaceQuestions.lockOptions[$0] == lock }
        }
        var chips: [String: [String]] = [:]
        for (key, value) in picks where !value.isEmpty { chips[key] = value.sorted() }
        let cleanNotes = notes.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        onFinish(FaceAnswers(locks: locks, chips: chips, notes: cleanNotes.isEmpty ? nil : cleanNotes))
    }
}

/// Wrapping row of chips.
struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
