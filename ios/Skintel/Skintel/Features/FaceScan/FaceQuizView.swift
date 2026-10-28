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
    /// A line above the options ("From your shelf: …"), or nil.
    var pre: String? = nil
    var rows: [Row]
}

enum FaceQuestions {
    static let lockOptions: [String: FaceLock] = [
        "Pregnant or trying": .pregnantOrTrying,
        "Breastfeeding": .breastfeeding,
        "Prescription skin medicine": .skinMedicine,
    ]

    /// The goals question's key: its picks go to the read (tips start with them) and to Ask.
    static let goalsKey = "goals"
    /// "Anything you want to know?": the "You asked" rows on the map.
    static let knowKey = "know"
    /// The skin type row at the top of every question ("From your profile").
    static let skinKey = "skin"
    /// The question that collects the locks. Skippable, but the report re-asks it first when it was
    /// never answered (`FaceScanFlowView.readReport`), so the report never fails open.
    static let locksID = "q5"
    static let goalOptions = ["Less shine", "Fewer breakouts", "Fade marks", "Calmer redness", "Smoother texture",
                              "Smaller-looking pores", "More glow", "A simpler routine", "Just curious"]
    static let skinTypes = ["Oily", "Dry", "Combination", "Balanced", "Sensitive"]

    /// The seven core questions. Under-18s don't see the pregnancy options (PRO-SPEC §7.2, the safe default).
    static func core(under18: Bool, shelfLine: String?) -> [FaceQuestion] {
        let locks = under18 ? ["Prescription skin medicine", "None of these"]
                            : ["Pregnant or trying", "Breastfeeding", "Prescription skin medicine", "None of these"]
        return [
            FaceQuestion(id: goalsKey, title: "What do you want to improve?",
                         hint: "Pick all that apply. Skinstel suggests what to try for each one.",
                         rows: [.init(key: goalsKey, options: goalOptions, multi: true, exclusive: ["Just curious"])]),
            FaceQuestion(id: knowKey, title: "Anything you want to know?", hint: "Your results answer these first.",
                         rows: [.init(key: knowKey, options: ["Is my routine working?", "What should I add?", "What should I stop?"], multi: true)]),
            FaceQuestion(id: "q2", title: "Do products sting or burn when you put them on?",
                         rows: [.init(key: "q2", options: ["Never", "Sometimes", "Often", "Only certain ones"])]),
            FaceQuestion(id: "q3", title: "Which actives are you using right now?",
                         hint: shelfLine == nil ? "Pick all that apply." : "Picked from your shelf. Change anything that is wrong.",
                         pre: shelfLine,
                         rows: [.init(key: "q3", options: ["Retinoid", "AHA or BHA", "Vitamin C", "Benzoyl peroxide", "Niacinamide", "None"],
                                      multi: true, exclusive: ["None"])]),
            FaceQuestion(id: "q4", title: "When a blemish heals, the mark it leaves is usually…",
                         rows: [.init(key: "q4", options: ["Pink or red", "Brown", "No mark"])]),
            FaceQuestion(id: locksID, title: "Anything we should be careful with?",
                         hint: "Skinstel leaves out ingredients that are not a good fit. Check with your doctor too.",
                         rows: [.init(key: locksID, options: locks, multi: true, exclusive: ["None of these"])]),
            FaceQuestion(id: "q7", title: "How many steps will you really do?",
                         rows: [.init(key: "q7_steps", options: ["3", "4 to 5", "6 or more"])]),
        ]
    }

    /// The opt-in deep dive. Q16 (supplements) is left out for under-18s.
    static func deep(under18: Bool) -> [FaceQuestion] {
        var list: [FaceQuestion] = [
            FaceQuestion(id: "q8", title: "Do you get tiny, same-size bumps that itch, on your forehead or chest?",
                         hint: "Helps Skinstel pick products that suit this pattern.",
                         rows: [.init(key: "q8", options: ["Often", "Sometimes", "Never"])]),
            FaceQuestion(id: "q9", title: "Your breakouts are mostly…",
                         rows: [.init(key: "q9", options: ["Deep, sore bumps", "Small clogged pores", "Both"])]),
            FaceQuestion(id: "q10", title: "Do breakouts around your jaw follow a monthly cycle?",
                         rows: [.init(key: "q10", options: ["Yes", "Sometimes", "No"])]),
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
            FaceQuestion(id: "q6", title: "Ingredients that have bothered you before", hint: "Pick all that apply.",
                         rows: [.init(key: "q6", options: ["Fragrance", "Essential oils", "Drying alcohol", "Coconut oil", "None"],
                                      multi: true, exclusive: ["None"])]),
        ]
        if under18 { list.removeAll { $0.id == "q16" } }
        return list
    }

    /// What the app already knows, so the person confirms instead of re-answering (PRO-SPEC §4.2).
    static func prefill(profile: SkinProfile, triggerNames: [String], shelfActives: [String]) -> [String: Set<String>] {
        var out: [String: Set<String>] = [:]
        switch profile.skinType {
        case .oily?: out[skinKey] = ["Oily"]
        case .dry?: out[skinKey] = ["Dry"]
        case .combination?: out[skinKey] = ["Combination"]
        case .normal?: out[skinKey] = ["Balanced"]
        case .sensitive?: out[skinKey] = ["Sensitive"]; out["q2"] = ["Sometimes"]
        case nil: break
        }
        var goals: Set<String> = []
        if profile.concerns.contains(.breakouts) { goals.insert("Fewer breakouts") }
        if profile.concerns.contains(.redness) { goals.insert("Calmer redness") }
        if profile.concerns.contains(.oiliness) { goals.insert("Less shine") }
        if profile.concerns.contains(.darkSpots) { goals.insert("Fade marks") }
        if !goals.isEmpty { out[goalsKey] = goals }
        if !shelfActives.isEmpty { out["q3"] = Set(shelfActives) }
        let picked = triggerPicks(triggerNames)
        if !picked.isEmpty { out["q6"] = Set(picked) }
        return out
    }

    /// Actives found on the shelf: the Q3 options they match, and "From your shelf: …" naming the
    /// products, or nil when nothing on the shelf has one.
    static func shelfActives(_ products: [(name: String, ingredients: [String])]) -> (picks: [String], line: String?) {
        let patterns: [(option: String, words: [String])] = [
            ("Retinoid", ["retinol", "retinal", "retinyl", "adapalene", "tretinoin"]),
            ("AHA or BHA", ["glycolic", "lactic acid", "mandelic", "salicylic"]),
            ("Vitamin C", ["ascorbic", "ascorbyl"]),
            ("Benzoyl peroxide", ["benzoyl peroxide"]),
            ("Niacinamide", ["niacinamide"]),
        ]
        var picks: [String] = []
        var names: [String] = []
        for (option, words) in patterns {
            let hits = products.filter { p in p.ingredients.contains { inci in words.contains { inci.lowercased().contains($0) } } }
            guard !hits.isEmpty else { continue }
            picks.append(option)
            for hit in hits where !names.contains(hit.name) { names.append(hit.name) }
        }
        guard !names.isEmpty else { return ([], nil) }
        return (picks, "From your shelf: " + names.prefix(3).joined(separator: ", "))
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

/// The photo read running behind the questions, for the status pill.
enum FaceReadStatus: Sendable, Equatable { case hidden, reading, read }

/// The seven core questions, the checkpoint, and the opt-in deep dive (Face Scan Pro v2 "Quiz").
/// The skin type from the profile sits on top of every question with Edit; every question has
/// Skip and Not sure, which leave it unanswered and show soft on the progress bar.
struct FaceQuizView: View {
    let under18: Bool
    let prefill: [String: Set<String>]
    /// "From your shelf: …" on the actives question, or nil.
    let shelfLine: String?
    var readStatus: FaceReadStatus = .hidden
    let onClose: () -> Void
    /// Called once, when the goals question is left: the read starts then, during the rest.
    var onGoals: ([String]) -> Void = { _ in }
    let onFinish: (FaceAnswers) -> Void

    private enum Stage: Equatable { case core(Int), checkpoint, deep(Int) }

    @State private var stage: Stage = .core(0)
    @State private var picks: [String: Set<String>] = [:]
    @State private var notes: [String: String] = [:]
    @State private var noteOpen = false
    @State private var editSkin = false
    @State private var skipped: Set<String> = []
    @State private var unsure: Set<String> = []
    @State private var didPrefill = false
    @State private var sentGoals = false

    private var core: [FaceQuestion] { FaceQuestions.core(under18: under18, shelfLine: shelfLine) }
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
        VStack(spacing: 10) {
            HStack {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(SKColor.ink).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                Spacer()
                Text(kicker).font(SKFont.mono(12)).tracking(1.5).foregroundStyle(SKColor.ink)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.leading, SKSpace.sm).padding(.trailing, SKSpace.lg)
            if readStatus != .hidden { statusPill }
            HStack(spacing: SKSpace.xs) {
                ForEach(0..<segmentCount, id: \.self) { i in
                    Capsule().fill(segmentColor(i)).frame(height: 4)
                }
            }
            .skPagePadding()
            .accessibilityHidden(true)
        }
        .padding(.top, SKSpace.md)
    }

    private var statusPill: some View {
        let done = readStatus == .read
        return HStack(spacing: SKSpace.sm) {
            if done {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(SKColor.goodFg)
                    .frame(width: 18, height: 18)
                    .background(SKColor.goodBg, in: Circle())
            } else {
                ProgressView().controlSize(.mini).tint(SKColor.primary).frame(width: 18, height: 18)
            }
            Text(done ? "Photos read · your map is ready" : "Reading your photos while you answer…")
                .font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.ink)
        }
        .padding(.leading, 10).padding(.trailing, 14)
        .frame(height: 32)
        .background(SKColor.cream, in: Capsule())
        .overlay(Capsule().stroke(SKColor.line))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var kicker: String {
        switch stage {
        case .core(let i): "QUESTION \(i + 1) OF \(core.count)"
        case .checkpoint: "CORE PROFILE · DONE"
        case .deep(let i): "DEEP DIVE · \(i + 1 + core.count) OF \(core.count + deep.count)"
        }
    }

    private var segmentCount: Int {
        if case .deep = stage { return deep.count }
        return core.count
    }

    /// Done questions are clay (soft when skipped or "Not sure"), the current one clay, the rest a hairline.
    private func segmentColor(_ i: Int) -> Color {
        switch stage {
        case .core(let current):
            if i < current { return isSoft(core[i].id) ? SKColor.primary.opacity(0.35) : SKColor.primary }
            return i == current ? SKColor.primary : SKColor.line
        case .checkpoint:
            return isSoft(core[i].id) ? SKColor.primary.opacity(0.35) : SKColor.primary
        case .deep(let current):
            if i < current { return isSoft(deep[i].id) ? SKColor.primary.opacity(0.35) : SKColor.primary }
            return i == current ? SKColor.primary : SKColor.line
        }
    }

    private func isSoft(_ id: String) -> Bool { skipped.contains(id) || unsure.contains(id) }

    // MARK: Question

    private func questionPage(_ q: FaceQuestion, isDeep: Bool, isLast: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                skinRow
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    Text(q.title).font(SKFont.serif(32, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let hint = q.hint {
                        Text(hint).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let pre = q.pre {
                        Label(pre, systemImage: "tray")
                            .font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.clayTileFg)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(SKColor.clayTileBg, in: Capsule())
                    }
                }
                ForEach(q.rows, id: \.key) { row in
                    VStack(alignment: .leading, spacing: 10) {
                        if let label = row.label { Text(label.uppercased()).font(SKFont.label).foregroundStyle(SKColor.muted) }
                        ChipFlow(spacing: SKSpace.sm) {
                            ForEach(row.options, id: \.self) { option in
                                optionChip(option, row: row, questionID: q.id)
                            }
                        }
                    }
                }
                noteArea(q)
            }
            .skPagePadding()
            .padding(.top, 14)
            .padding(.bottom, SKSpace.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: SKSpace.sm) {
                HStack(spacing: SKSpace.sm) {
                    leaveButton("Skip") { leave(q, unsure: false) }
                    leaveButton("Not sure") { leave(q, unsure: true) }
                }
                if isDeep && isLast {
                    SKButton(title: "See my results") { finish() }
                } else {
                    SKButton(title: "Next") { next() }.disabled(!answered(q))
                    if isDeep {
                        SKButton(title: "See my results now", kind: .ghost) { finish() }
                    }
                }
            }
            .skPagePadding()
            .padding(.top, SKSpace.sm)
            .padding(.bottom, SKSpace.lg)
            .background(SKColor.bg)
        }
    }

    private func leaveButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SKFont.sans(15, weight: .semibold, relativeTo: .body))
                .foregroundStyle(SKColor.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .overlay(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(SKColor.line))
                .contentShape(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
        }
        .buttonStyle(SKPressStyle())
    }

    /// "From your profile: Combination skin" with Edit, on every question.
    private var skinRow: some View {
        let skin = picks[FaceQuestions.skinKey]?.first
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "drop")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SKColor.primary)
                    .frame(width: 28, height: 28)
                    .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                (Text("From your profile: ").foregroundStyle(SKColor.muted)
                 + Text(skin.map { "\($0) skin" } ?? "Not set").fontWeight(.semibold).foregroundStyle(SKColor.ink))
                    .font(SKFont.sans(14, relativeTo: .subheadline))
                Spacer(minLength: 0)
                Button(editSkin ? "Done" : "Edit") {
                    withAnimation(SKAnimation.ios(0.25)) { editSkin.toggle() }
                }
                .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(SKColor.primary)
                .frame(minWidth: 56, minHeight: 44)
                .accessibilityLabel(editSkin ? "Done" : "Edit skin type")
            }
            .padding(.leading, SKSpace.md).padding(.trailing, SKSpace.xs)
            .frame(minHeight: 48)
            if editSkin {
                ChipFlow(spacing: 6) {
                    ForEach(FaceQuestions.skinTypes, id: \.self) { type in
                        let on = skin == type
                        Button {
                            Haptics.selection()
                            picks[FaceQuestions.skinKey] = [type]
                            withAnimation(SKAnimation.ios(0.25)) { editSkin = false }
                        } label: {
                            Text(type)
                                .font(SKFont.sans(14, weight: .medium, relativeTo: .subheadline))
                                .foregroundStyle(on ? SKColor.cream : SKColor.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(on ? SKColor.primary : SKColor.cream, in: Capsule())
                                .overlay(Capsule().stroke(on ? SKColor.primary : SKColor.line))
                        }
                        .buttonStyle(SKPressStyle())
                        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.horizontal, SKSpace.md).padding(.bottom, SKSpace.md)
            }
        }
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(SKColor.line))
    }

    private func optionChip(_ option: String, row: FaceQuestion.Row, questionID: String) -> some View {
        let on = picks[row.key, default: []].contains(option)
        return Button { toggle(option, row: row, questionID: questionID) } label: {
            HStack(spacing: 6) {
                if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)) }
                Text(option)
            }
            .font(SKFont.sans(15, weight: .medium, relativeTo: .body))
            .foregroundStyle(on ? SKColor.cream : SKColor.ink)
            .padding(.horizontal, 15)
            .frame(minHeight: 44)
            .background(on ? SKColor.primary : SKColor.cream, in: Capsule())
            .overlay(Capsule().stroke(on ? SKColor.primary : SKColor.line, lineWidth: 1))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func noteArea(_ q: FaceQuestion) -> some View {
        Button { noteOpen.toggle() } label: {
            Text("+ Add a detail or product name (optional)")
                .font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                .foregroundStyle(SKColor.primary)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        if noteOpen {
            VStack(alignment: .leading, spacing: 6) {
                Text("Detail or product name").font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                TextField("e.g. The Ordinary retinol, since August", text: noteBinding(q.id), axis: .vertical)
                    .lineLimit(2...6)
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

    private var forkNote: String {
        var parts: [String] = []
        if !skipped.isEmpty { parts.append(skipped.count == 1 ? "skipped 1 question" : "skipped \(skipped.count) questions") }
        if !unsure.isEmpty { parts.append("weren't sure on \(unsure.count)") }
        if parts.isEmpty {
            return "That's enough for your face map and a starter routine. You can stop here, or answer \(deep.count) more to sharpen it."
        }
        return "You \(parts.joined(separator: " and ")). That's fine: Skinstel works with what you gave it and never guesses the rest."
    }

    private var pickedGoals: [String] {
        FaceQuestions.goalOptions.filter { (picks[FaceQuestions.goalsKey] ?? []).contains($0) }
    }

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
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(forkNote).font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("YOU WANT TO IMPROVE").font(SKFont.label).tracking(1.4).foregroundStyle(SKColor.muted)
                Text(pickedGoals.isEmpty ? "Nothing picked yet" : pickedGoals.joined(separator: " · "))
                    .font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Skinstel suggests what to try for each one with your map.")
                    .font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
            }
            .padding(.horizontal, 14).padding(.vertical, SKSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(SKColor.line))
            .accessibilityElement(children: .combine)
            Spacer()
            SKButton(title: "See my results now") { finish() }
            Button { noteOpen = false; stage = .deep(0) } label: {
                VStack(alignment: .leading, spacing: SKSpace.xs) {
                    Text("Go deeper · \(deep.count) more questions, about 90 s").font(SKFont.sans(16, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(SKColor.ink)
                    Text("Sharper on breakout timing, flushing, shine during the day, sleep and diet triggers. Skip any of them.")
                        .font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.muted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .padding(.horizontal, SKSpace.lg).padding(.vertical, SKSpace.md)
                .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SKRadius.button, style: .continuous).stroke(SKColor.line, lineWidth: 1))
            }
            .buttonStyle(SKPressStyle())
        }
        .skPagePadding()
        .padding(.top, 34)
        .padding(.bottom, 26)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Logic

    private func answered(_ q: FaceQuestion) -> Bool {
        q.rows.allSatisfy { !(picks[$0.key] ?? []).isEmpty }
    }

    private func toggle(_ option: String, row: FaceQuestion.Row, questionID: String) {
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
        skipped.remove(questionID)
        unsure.remove(questionID)
    }

    /// Skip or Not sure: clears the question's picks, marks it soft, and moves on.
    private func leave(_ q: FaceQuestion, unsure isUnsure: Bool) {
        Haptics.selection()
        for row in q.rows { picks[row.key] = nil }
        skipped.remove(q.id)
        unsure.remove(q.id)
        if isUnsure { unsure.insert(q.id) } else { skipped.insert(q.id) }
        if case .deep(let i) = stage, i == deep.count - 1 { finish(); return }
        next()
    }

    private func next() {
        noteOpen = false
        sendGoalsIfLeaving()
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

    /// Leaving the goals question (Next, Skip or Not sure) starts the read with whatever was picked.
    private func sendGoalsIfLeaving() {
        guard !sentGoals, case .core(let i) = stage, core[i].id == FaceQuestions.goalsKey else { return }
        sentGoals = true
        onGoals(pickedGoals.filter { $0 != "Just curious" })
    }

    private func finish() {
        sendGoalsIfLeaving()
        let chosen = picks[FaceQuestions.locksID] ?? []
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
