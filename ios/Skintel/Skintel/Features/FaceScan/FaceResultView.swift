import SkintelCore
import SwiftUI

/// The face map with the 7-day check (canvas screen 5), in the light chemist look: a porcelain
/// hero with one map, the person's own Day 1 photo with the canonical mesh fitted over it, the
/// zone glow and the AI's marked spots, or the turnable 3D model ("Photo · 3D"), both mirrored
/// like a selfie; day buttons; rings; the insight; zones that open to their five readings; what
/// Skinstel suggests; the person's goals with Ask; tonight's routine; the report; the history.
/// Levels are words and glyphs, never raw scores or percentages (PRO-SPEC §6).
///
/// With `onUnlock` (no Skintel+, e.g. the free scan's real Day 1 map), the week is locked: the
/// rings card becomes the locked 7-day check, and the routine, the scan actions and Ask stay
/// hidden. Without it, the same cycle shows unlocked.
struct FaceResultView: View {
    let calibration: FaceCalibration
    let routine: FaceRoutine?
    /// The scan action to offer today ("Take today's photo", "Final sweep"), or nil.
    let nextAction: String?
    let onNext: () -> Void
    /// Opens Ask with this question in the composer: a goal's question, or the general one.
    let onAsk: ((String) -> Void)?
    let onClose: () -> Void
    /// Not Skintel+ only: opens the Skintel+ wall from the locked 7-day check.
    var onUnlock: (() -> Void)? = nil
    /// The Day 1 front photo (JPEG, on this phone only). With it the hero opens on the photo. It
    /// is deleted with the Day 1 crops when the report is written, so the report map opens on 3D.
    var photo: Data? = nil
    /// The questionnaire's answers: the goals and "Anything you want to know?" picks.
    var answers: FaceAnswers? = nil

    @State private var selected: Int?
    /// The hero toggle; nil until the person picks, so it follows whether a photo exists.
    @State private var show3D: Bool?
    /// Zone rows opened to their five readings.
    @State private var openZones: Set<FaceZone> = []

    private var showsPhoto: Bool { photo != nil && !(show3D ?? false) }

    private var isFree: Bool { onUnlock != nil }

    /// Ask is offered where it was before: not on the free (locked) map, and only with a handler.
    private var askable: Bool { !isFree && onAsk != nil }

    private var scans: [FaceScanEntry] { calibration.scans }
    private var index: Int {
        guard !scans.isEmpty else { return 0 }
        return min(selected ?? scans.count - 1, scans.count - 1)
    }
    private var entry: FaceScanEntry? { scans.isEmpty ? nil : scans[index] }

    private var goals: [FaceGoal] { FaceGoal.goals(in: answers) }
    private var knows: [FaceKnow] { FaceQuestions.know(in: answers) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(spacing: 14) {
                    if let onUnlock { lockedWeekCard(unlock: onUnlock) } else { ringsCard }
                    insightCard
                    zonesCard
                    if let tips = suggestions { tipsCard(tips) }
                    if showsGoalsCard { goalsCard }
                    if let report = calibration.latestReport?.report { reportCard(report) }
                    if !isFree, let routine, !(routine.pm.isEmpty && routine.am.isEmpty) { routineCard(routine) }
                    if !isFree, let nextAction { SKButton(title: nextAction, systemImage: "faceid") { onNext() } }
                    if !isFree, let onAsk {
                        SKButton(title: "Ask Skinstel about this scan", kind: nextAction == nil ? .primary : .secondary) {
                            onAsk(FaceGoal.askPrompt(for: goals))
                        }
                    }
                    historyCard
                    Text("\(FaceScanResult.defaultDisclaimer) Photos are read, then deleted.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
                }
                .skPagePadding()
                .padding(.top, SKSpace.lg)
                .padding(.bottom, 30)
            }
        }
        .skPageBackground()
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Hero

    private var levels: FaceZoneLevels { FaceZoneLevels(result: entry?.result) }

    /// The selected scan's marked spots, per zone (baseline and final reads carry them).
    private var regions: [FaceZone: [FaceRegion]] {
        var out: [FaceZone: [FaceRegion]] = [:]
        for zone in entry?.result.zones ?? [] where !zone.regions.isEmpty {
            out[zone.zone, default: []] += zone.regions
        }
        return out
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Back")
                Spacer()
                Text("FACE SCAN").font(SKFont.mono(12)).tracking(1.5).foregroundStyle(SKColor.clayTileFg)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, SKSpace.sm)
            VStack(alignment: .leading, spacing: SKSpace.xs) {
                Text("YOUR SKIN MAP · DAY \(index + 1) OF 7").font(SKFont.label).tracking(1.5).foregroundStyle(SKColor.primary)
                Text(insight.title).font(SKFont.pageTitle).foregroundStyle(SKColor.ink).accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, 14)

            if photo != nil {
                heroToggle
                    .padding(.horizontal, SKSpace.xl)
                    .padding(.top, SKSpace.md)
            }

            Group {
                if showsPhoto, let photo {
                    FacePhotoMap(photo: photo, levels: levels, labels: labels, regions: regions)
                        .clipShape(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line, lineWidth: 1))
                        .padding(.horizontal, SKSpace.md)
                        .padding(.vertical, SKSpace.sm)
                } else {
                    FaceMeshView(mode: .result, levels: levels, labels: labels, zoom: 0.31)
                }
            }
            .frame(height: 330)
            .frame(maxWidth: SKLayout.readableWidth)
            .frame(maxWidth: .infinity)

            Text("Mirrored, like a selfie")
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, SKSpace.md)

            VStack(spacing: 10) {
                ZStack {
                    Rectangle().fill(SKColor.ink.opacity(0.12)).frame(height: 2).padding(.horizontal, 18)
                    HStack {
                        ForEach(1...7, id: \.self) { n in
                            dayButton(n)
                            if n < 7 { Spacer(minLength: 0) }
                        }
                    }
                }
                HStack {
                    Text(showsPhoto ? "Tap a day" : "Tap a day · drag the face to turn it")
                    Spacer()
                    Text("◆ = unlock day").font(SKFont.label).foregroundStyle(SKColor.clayTileFg)
                }
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 54)
        .padding(.bottom, 22)
        .foregroundStyle(SKColor.ink)
        .background { heroBackground }
    }

    /// Porcelain with a soft clay wash, a rose blush at the foot and a hairline edge.
    private var heroBackground: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: SKRadius.sheet, bottomTrailingRadius: SKRadius.sheet)
        return ZStack {
            shape.fill(SKColor.cream)
            shape.fill(LinearGradient(colors: [SKColor.blush, .clear, SKColor.rose.opacity(0.35)],
                                      startPoint: .top, endPoint: .bottom))
            shape.stroke(SKColor.line, lineWidth: 1)
        }
    }

    /// "Photo · 3D": their own Day 1 photo with the mesh and glow, or the turnable 3D model.
    private var heroToggle: some View {
        HStack(spacing: 0) {
            toggleButton("Photo", on: showsPhoto) { show3D = false }
            toggleButton("3D", on: !showsPhoto) { show3D = true }
        }
        .padding(3)
        .background(SKColor.neutralChip, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map view")
    }

    private func toggleButton(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(SKAnimation.ios(0.3)) { action() }
            Haptics.selection()
        } label: {
            Text(title)
                .font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(on ? SKColor.ink : SKColor.muted)
                .frame(minWidth: 64, minHeight: 32)
                .background(on ? SKColor.cream : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func dayButton(_ n: Int) -> some View {
        let unlock = [1, 3, 5, 7].contains(n)
        let has = n <= scans.count
        let on = has && n - 1 == index
        let past = has && !on
        return Button { selected = n - 1; Haptics.selection() } label: {
            Text(unlock ? "\(n)◆" : "\(n)")
                .font(SKFont.mono(13))
                .foregroundStyle(on || past ? SKColor.cream : SKColor.muted)
                .frame(width: 44, height: 44)
                .background(on ? SKColor.ink : past ? SKColor.primary : SKColor.cream, in: Circle())
                .overlay(Circle().stroke(on ? SKColor.ink : unlock ? SKColor.primary : SKColor.line,
                                         lineWidth: on ? 2 : unlock ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!has)
        .accessibilityLabel("Day \(n)")
        .accessibilityValue(has ? (on ? "Showing" : "Scanned") : "Not scanned yet")
    }

    // MARK: Zones

    /// Display order and label sides, mirrored like a selfie: the person's left cheek is on the
    /// screen's left, their right cheek on the screen's right.
    private static let zoneOrder: [(zone: FaceZone, side: FaceMeshLabel.Side, y: CGFloat)] = [
        (.forehead, .leading, 0.17), (.nose, .trailing, 0.36), (.leftCheek, .leading, 0.56),
        (.rightCheek, .trailing, 0.66), (.chin, .leading, 0.86),
    ]

    /// What a zone shows: clear (every reading under "Some"), its strongest finding, or nothing read.
    private enum Finding: Equatable {
        case clear
        case finding(FaceMetric, FaceCalibration.Band)
        case notRead
    }

    /// Uses the zone's own top finding (ties go away from shine, which moves most with light), so
    /// a calm zone reads "Clear" instead of whichever metric happened to be largest.
    private func finding(_ zone: FaceZone, in result: FaceScanResult?) -> Finding {
        guard let z = result?.zone(zone) else { return .notRead }
        if z.isClear { return .clear }
        guard let top = z.topFinding else { return .notRead }
        return .finding(top.metric, FaceCalibration.band(top.score))
    }

    private var labels: [FaceMeshLabel] {
        Self.zoneOrder.compactMap { item -> FaceMeshLabel? in
            let value: String
            let hot: Bool
            switch finding(item.zone, in: entry?.result) {
            case .notRead: return nil
            case .clear:
                value = "CLEAR"
                hot = false
            case .finding(let metric, let band):
                value = "\(metric.label) · \(band.label)".uppercased()
                hot = band == .noticeable
            }
            return FaceMeshLabel(zone: item.zone, title: item.zone.label.uppercased(), value: value,
                                 side: item.side, y: item.y, hot: hot)
        }
    }

    private var zonesCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.zoneOrder.enumerated()), id: \.offset) { i, item in
                zoneRow(item.zone)
                if i < Self.zoneOrder.count - 1 { Divider().overlay(SKColor.line) }
            }
        }
        .padding(.horizontal, SKSpace.lg).padding(.vertical, SKSpace.xs)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line, lineWidth: 1))
        .skCardShadow()
    }

    /// The zone, its finding (glyph + words), and the AI's note for it (or the trend against
    /// Day 1 when there is no note). A tap opens the five readings.
    private func zoneRow(_ zone: FaceZone) -> some View {
        let result = entry?.result
        let zoneResult = result?.zone(zone)
        let found = finding(zone, in: result)
        let trend = trendText(zone, metric: zoneResult?.topFinding?.metric)
        let note = zoneResult?.note
        let open = openZones.contains(zone)
        let tag = findingTag(found)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(SKAnimation.ios(0.3)) {
                    if open { openZones.remove(zone) } else { openZones.insert(zone) }
                }
                Haptics.selection()
            } label: {
                VStack(alignment: .leading, spacing: SKSpace.xs) {
                    HStack {
                        Text(zone.label).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                        Spacer()
                        if zoneResult != nil {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SKColor.muted)
                                .rotationEffect(.degrees(open ? 180 : 0))
                                .accessibilityHidden(true)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: tag.glyph).font(.system(size: 12, weight: .semibold)).accessibilityHidden(true)
                        Text(tag.text).font(SKFont.sans(13, weight: .medium, relativeTo: .footnote))
                    }
                    .foregroundStyle(tag.color)
                    Text(note ?? trend.text)
                        .font(SKFont.sans(13, relativeTo: .footnote))
                        .foregroundStyle(note == nil && trend.calmer ? SKColor.goodFg : SKColor.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, SKSpace.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(zoneResult == nil)
            .accessibilityElement(children: .combine)
            .accessibilityValue(zoneResult == nil ? "" : open ? "Open" : "Closed")
            .accessibilityHint(zoneResult == nil ? "" : "Shows each reading for this zone")

            if open, let zoneResult {
                readings(zoneResult, trend: note == nil ? nil : trend.text)
                    .transition(.opacity)
            }
        }
    }

    /// Five small bars, one per reading, each with a glyph and a word. Never a number.
    private func readings(_ zone: FaceZoneResult, trend: String?) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            ForEach(FaceMetric.allCases) { metric in
                let band = zone.scores[metric].map { FaceCalibration.band($0) }
                let word = bandWord(band)
                HStack(spacing: SKSpace.md) {
                    Text(metric.label).font(SKFont.sans(14, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    levelBar(band)
                    HStack(spacing: 5) {
                        Image(systemName: word.glyph).font(.system(size: 11, weight: .semibold))
                        Text(word.text).font(SKFont.sans(13, weight: .medium, relativeTo: .footnote))
                    }
                    .foregroundStyle(word.color)
                    .frame(minWidth: 104, alignment: .leading)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(metric.label)
                .accessibilityValue(word.text)
            }
            if let trend {
                Text(trend).font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
        }
        .padding(.bottom, SKSpace.md)
    }

    /// Two segments: none lit for None, one for Some, both for Noticeable.
    private func levelBar(_ band: FaceCalibration.Band?) -> some View {
        let level = band.map { FaceZoneLevels.level(for: $0) } ?? 0
        return HStack(spacing: 3) {
            Capsule().fill(level >= 1 ? SKColor.primary : SKColor.line).frame(width: 16, height: 6)
            Capsule().fill(level >= 2 ? SKColor.primary : SKColor.line).frame(width: 16, height: 6)
        }
        .accessibilityHidden(true)
    }

    private struct Word {
        let glyph: String
        let text: String
        let color: Color
    }

    /// None / Some / Noticeable as colour, glyph and word.
    private func bandWord(_ band: FaceCalibration.Band?) -> Word {
        switch band {
        case .clear?: Word(glyph: "circle", text: "None", color: SKColor.goodFg)
        case .mild?: Word(glyph: "circle.lefthalf.filled", text: "Some", color: SKColor.primary)
        case .noticeable?: Word(glyph: "circle.fill", text: "Noticeable", color: SKColor.cautionFg)
        case nil: Word(glyph: "minus", text: "Not read", color: SKColor.muted)
        }
    }

    /// The zone's headline: "Clear", or "Flat marks · Some".
    private func findingTag(_ found: Finding) -> Word {
        switch found {
        case .clear: return Word(glyph: "checkmark.circle", text: "Clear", color: SKColor.goodFg)
        case .notRead: return Word(glyph: "minus", text: "Not read", color: SKColor.muted)
        case .finding(let metric, let band):
            let word = bandWord(band)
            return Word(glyph: word.glyph, text: "\(metric.label) · \(word.text)", color: word.color)
        }
    }

    /// The selected scan against Day 1, by band so it never implies more precision than it has.
    private func trendText(_ zone: FaceZone, metric: FaceMetric?) -> (text: String, calmer: Bool) {
        guard index > 0, let metric, let first = scans.first?.result.score(metric, in: zone),
              let now = entry?.result.score(metric, in: zone) else { return ("Day 1 baseline", false) }
        let a = FaceZoneLevels.level(for: FaceCalibration.band(first))
        let b = FaceZoneLevels.level(for: FaceCalibration.band(now))
        if b < a { return ("Calmer than Day 1", true) }
        if b > a { return ("More than Day 1", false) }
        return ("Same as Day 1", false)
    }

    // MARK: Suggestions

    /// The tips of the newest scan that has any; nil (no card) when none does.
    private var suggestions: [FaceTip]? {
        guard let tips = scans.last(where: { !$0.result.tips.isEmpty })?.result.tips, !tips.isEmpty else { return nil }
        return tips
    }

    private func tipsCard(_ tips: [FaceTip]) -> some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text("WHAT SKINSTEL SUGGESTS").font(SKFont.label).tracking(1).foregroundStyle(SKColor.primary)
                ForEach(Array(tips.enumerated()), id: \.offset) { i, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(SKFont.sans(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(SKColor.clayTileFg)
                            .frame(width: 24, height: 24)
                            .background(SKColor.clayTileBg, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tip.title).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if !tip.why.isEmpty {
                                Text(tip.why).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let about = Self.tipSubject(tip) {
                                Text(about.uppercased()).font(SKFont.label).tracking(1).foregroundStyle(SKColor.clayTileFg)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// "Nose & T-zone · Shine", from what the tip links to.
    private static func tipSubject(_ tip: FaceTip) -> String? {
        let parts = [tip.zone?.label, tip.metric?.label].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Goals

    private var showsGoalsCard: Bool { !goals.isEmpty || (askable && !knows.isEmpty) }

    private var goalsCard: some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text(goals.isEmpty ? "YOUR QUESTIONS" : "FOR YOUR GOALS").font(SKFont.label).tracking(1)
                    .foregroundStyle(SKColor.primary)
                ForEach(goals) { goal in
                    HStack(alignment: .center, spacing: SKSpace.md) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.label).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                            if let line = mapLine(for: goal) {
                                Text(line).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        if askable {
                            askChip("Ask Skinstel", label: "Ask Skinstel about \(goal.label.lowercased())") {
                                onAsk?(goal.askPrompt)
                            }
                        }
                    }
                }
                if askable && !knows.isEmpty {
                    if !goals.isEmpty { Divider().overlay(SKColor.line) }
                    ChipFlow(spacing: SKSpace.sm) {
                        ForEach(knows, id: \.label) { item in
                            askChip(item.label, label: "Ask Skinstel: \(item.label)") { onAsk?(item.prompt) }
                        }
                    }
                }
            }
        }
    }

    private func askChip(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "bubble.left").font(.system(size: 11, weight: .semibold))
                Text(title).font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(SKColor.primary)
            .padding(.horizontal, SKSpace.md)
            .padding(.vertical, 7)
            .background(SKColor.blush, in: Capsule())
            .overlay(Capsule().stroke(SKColor.primary.opacity(0.3), lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel(label)
    }

    /// What the map shows for a goal's reading, in words: "Shine: Some on your nose". Nil when the
    /// goal is not about one reading, or the selected scan did not read it.
    private func mapLine(for goal: FaceGoal) -> String? {
        guard let metric = goal.metric, let result = entry?.result else { return nil }
        var read = false
        var showing: [(zone: FaceZone, score: Int)] = []
        for item in Self.zoneOrder {
            guard let score = result.score(metric, in: item.zone) else { continue }
            read = true
            if score >= FaceCalibration.someFrom { showing.append((item.zone, score)) }
        }
        guard read else { return nil }
        guard let top = showing.max(by: { $0.score < $1.score }) else { return "\(metric.label): none showing on your map" }
        let band = FaceCalibration.band(top.score)
        let places = showing
            .filter { FaceCalibration.band($0.score) == band }
            .sorted { $0.score > $1.score }
            .prefix(2)
            .map { Self.place($0.zone) }
        return "\(metric.label): \(band.label) on \(places.joined(separator: " and "))"
    }

    private static func place(_ zone: FaceZone) -> String {
        switch zone {
        case .forehead: "your forehead"
        case .nose: "your nose"
        case .leftCheek: "your left cheek"
        case .rightCheek: "your right cheek"
        case .chin: "your chin"
        }
    }

    // MARK: Rings

    private struct Ring { let milestone: FaceCalibration.Milestone; let color: Color; let radius: CGFloat }

    private var rings: [Ring] {
        [Ring(milestone: .faceMap, color: SKColor.ink, radius: 58),
         Ring(milestone: .oilPattern, color: SKColor.primary, radius: 46),
         Ring(milestone: .rednessBaseline, color: FaceScanColor.ringThree, radius: 34),
         Ring(milestone: .fullReport, color: SKColor.goodFg, radius: 22)]
    }

    private func ringStatus(_ m: FaceCalibration.Milestone) -> String {
        if calibration.isUnlocked(m) { return "READY ✓" }
        let left = calibration.scansToGo(for: m)
        if left == 0 { return m.requiresFinalScan ? "FINAL SWEEP" : "FIRST SWEEP" }
        return left == 1 ? "1 SCAN" : "\(left) SCANS"
    }

    private var ringsCard: some View {
        HStack(spacing: SKSpace.lg) {
            ZStack {
                ForEach(rings, id: \.radius) { ring in
                    Circle().stroke(SKColor.ink.opacity(0.07), lineWidth: 10)
                        .frame(width: ring.radius * 2, height: ring.radius * 2)
                    Circle().trim(from: 0, to: CGFloat(calibration.isUnlocked(ring.milestone) ? 1 : min(calibration.progress(for: ring.milestone), 0.999)))
                        .stroke(ring.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: ring.radius * 2, height: ring.radius * 2)
                }
            }
            .frame(width: 132, height: 132)
            .accessibilityElement()
            .accessibilityLabel(rings.map { "\($0.milestone.label) \(ringStatus($0.milestone).lowercased())" }.joined(separator: ", "))
            VStack(alignment: .leading, spacing: 9) {
                ForEach(rings, id: \.radius) { ring in
                    HStack(spacing: SKSpace.sm) {
                        RoundedRectangle(cornerRadius: 3).fill(ring.color).frame(width: 10, height: 10)
                        Text(ring.milestone.label).font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                        Spacer(minLength: 0)
                        Text(ringStatus(ring.milestone)).font(SKFont.label)
                            .foregroundStyle(calibration.isUnlocked(ring.milestone) ? SKColor.goodFg : SKColor.muted)
                    }
                }
            }
            .accessibilityHidden(true)
        }
        .padding(SKSpace.lg)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line, lineWidth: 1))
        .skCardShadow()
    }

    // MARK: Locked week (free scan)

    /// The free scan's stand-in for the rings: the four rings drawn empty around a lock, the
    /// question the week answers, and the way into Skintel+.
    private func lockedWeekCard(unlock: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            HStack(spacing: SKSpace.lg) {
                ZStack {
                    ForEach(rings, id: \.radius) { ring in
                        Circle().stroke(SKColor.ink.opacity(0.07), lineWidth: 10)
                            .frame(width: ring.radius * 2, height: ring.radius * 2)
                    }
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.primary)
                }
                .frame(width: 132, height: 132)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("7-DAY CHECK").font(SKFont.label).tracking(1).foregroundStyle(SKColor.primary)
                    Text("Is your skin getting calmer?")
                        .font(SKFont.sans(17, weight: .semibold, relativeTo: .headline)).foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Follow it for 7 days with Skintel+")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            SKButton(title: "Get Skintel+", action: unlock)
        }
        .padding(SKSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line, lineWidth: 1))
        .skCardShadow()
    }

    // MARK: Insight

    private var insight: (kicker: String, title: String, body: String) {
        let count = index + 1
        let summary = entry?.result.summary ?? ""
        if count >= 7, calibration.isUnlocked(.fullReport), let report = calibration.latestReport {
            return ("DAY 7 · FULL REPORT", "Your week, zone by zone.", report.summary.isEmpty ? summary : report.summary)
        }
        if count >= 5, calibration.isUnlocked(.rednessBaseline), let redness = calibration.rednessBaseline {
            var body = "Across five scans your redness was \(redness.label.lowercased())."
            if let steady = calibration.barrierSteady {
                body += steady ? " Your cheeks barely changed, so your barrier looks steady." : " Your cheeks changed from day to day, so your barrier looks less steady."
            }
            return ("DAY 5 · REDNESS BASELINE", redness == .steady ? "Your redness stays steady." : "Your redness comes and goes.", body)
        }
        if count >= 3, calibration.isUnlocked(.oilPattern), let oil = calibration.oilPattern {
            let title: String = switch oil {
            case .combination: "Shine sits on your T-zone."
            case .oily: "Shine shows all over."
            case .dry: "Your skin stays matte."
            case .normal, .unknown: "Your shine is balanced."
            }
            return ("DAY 3 · OIL PATTERN", title, "Across three scans your pattern reads as \(oil.label.lowercased()). \(summary)")
        }
        if count == 1 { return ("DAY 1 · FACE MAP", "Your first map is ready.", summary) }
        return ("DAY \(count) · DAILY READ", "Day \(count) of your week.", summary)
    }

    private var insightCard: some View {
        SKCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(insight.kicker).font(SKFont.label).tracking(1).foregroundStyle(SKColor.primary)
                Text(insight.body.isEmpty ? "No read for this day." : insight.body)
                    .font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Report

    private func reportCard(_ report: FaceReport) -> some View {
        SKCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR SKIN REPORT").font(SKFont.label).foregroundStyle(SKColor.muted)
                reportRow("Oil pattern", report.oilPattern.label)
                reportRow("Redness", report.redness.label)
                reportRow("Barrier", report.barrier.label)
                reportRow("Marks", report.marks.label)
                if let active = report.suggestedActive {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested active: \(active.name)").font(SKFont.sans(15, weight: .semibold, relativeTo: .body))
                        if let nights = active.nightsPerWeek { Text("\(nights) nights a week").font(SKFont.secondary).foregroundStyle(SKColor.muted) }
                        if !active.why.isEmpty { Text(active.why).font(SKFont.secondary).foregroundStyle(SKColor.muted) }
                    }
                    .foregroundStyle(SKColor.ink)
                }
            }
        }
    }

    private func reportRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(SKFont.sans(15, relativeTo: .body)).foregroundStyle(SKColor.ink)
            Spacer()
            Text(value).font(SKFont.sans(15, weight: .medium, relativeTo: .body)).foregroundStyle(SKColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Routine

    private func routineCard(_ routine: FaceRoutine) -> some View {
        let steps = routine.pm.isEmpty ? routine.am : routine.pm
        return SKCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(routine.pm.isEmpty ? "THIS MORNING" : "TONIGHT, FROM YOUR SHELF").font(SKFont.label).foregroundStyle(SKColor.muted)
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(SKFont.sans(12, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(SKColor.clayTileFg)
                            .frame(width: 24, height: 24)
                            .background(SKColor.clayTileBg, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.product.map { "\(step.step): \($0)" } ?? step.step)
                                .font(SKFont.sans(14, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                            if !step.note.isEmpty { Text(step.note).font(SKFont.caption).foregroundStyle(SKColor.muted) }
                        }
                    }
                }
                ForEach(routine.conflicts, id: \.self) { conflict in
                    Text(conflict).font(SKFont.sans(13, relativeTo: .footnote)).foregroundStyle(SKColor.cautionFg)
                        .padding(.horizontal, SKSpace.md).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SKColor.cautionBg, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                }
            }
        }
    }

    // MARK: History

    private var historyCard: some View {
        SKCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("THIS WEEK'S SCANS").font(SKFont.label).foregroundStyle(SKColor.muted)
                if scans.isEmpty {
                    Text("No scans yet.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
                ForEach(Array(scans.enumerated()), id: \.offset) { i, scan in
                    Button { selected = i } label: {
                        HStack {
                            Text("Day \(i + 1)").font(SKFont.sans(15, weight: .semibold, relativeTo: .body))
                            Text(Self.stageLabel(scan.stage)).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                            Spacer()
                            Text(scan.day).font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                        }
                        .foregroundStyle(SKColor.ink)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(i == index ? .isSelected : [])
                }
            }
        }
    }

    static func stageLabel(_ stage: FaceScanStage) -> String {
        switch stage {
        case .baseline: "First sweep"
        case .daily: "Daily photo"
        case .final: "Final sweep"
        case .report: "Report"
        }
    }
}
