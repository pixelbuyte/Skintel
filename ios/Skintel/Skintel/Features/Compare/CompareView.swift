import SwiftUI
import SkintelCore

/// Compare, rebuilt around the read the phone can already do.
///
/// Everything above the fold is computed locally from data that is already on the device
/// — the shelf's outcomes, `Correlate`'s repeat offenders, the curated ingredient table
/// and the saved skin profile — so the screen answers "which of these two is better for
/// me" instantly, offline, at zero marginal cost. The server round trip survives as one
/// optional "go deeper" button below the local answer, never in front of it.
///
/// Two engines in `SkintelCore` do the thinking: `CompareLocal` reads a filled pair, and
/// `CompareSuggest` proposes which two are worth comparing in the first place. Both are
/// pure, so everything here is layout and copy.
struct CompareView: View {

    /// Founder switch. true = the on-device read is free and Pro gates only the server
    /// deepening. Flip to false to put the whole local read back behind the paywall;
    /// nothing else changes.
    private static let localReadIsFree = true

    /// The only categories `CompareSuggest.gaps` is ever allowed to name. `ProductCategory`
    /// lives in the app target, so the list is threaded in rather than imported.
    private static let coreCategories = [
        ProductCategory.cleanser.rawValue,
        ProductCategory.moisturizer.rawValue,
        ProductCategory.sunscreen.rawValue,
    ]

    @Environment(AppEnvironment.self) private var env
    @Environment(\.openPaywall) private var openPaywall

    enum SideKey: String, Identifiable, Hashable {
        case left, right
        var id: String { rawValue }
    }

    struct Pick: Hashable {
        var productID: String?
        var name: String
        var inci: String
    }

    @State private var left: Pick?
    @State private var right: Pick?
    @State private var picking: SideKey?
    @State private var pasting: SideKey?
    @State private var server: Loadable<CompareResult> = .idle
    @State private var path: [AppDestination] = []

    // MARK: - Per-render model
    //
    // `ProductStore.culprits` re-runs `Correlate.run` on every access and
    // `Correlate.Result.byNormalized` rebuilds its dictionary on every access, so the
    // whole model is built exactly once per body pass and handed down. Nothing below
    // recomputes it, and nothing recomputes inside a `ForEach`.

    private struct Model {
        var shelf: [ProductWithIngredients]
        var badProductCount: Int
        var report: CompareLocal.Report?
        var pairs: [CompareSuggest.Pair]
        var gaps: [CompareSuggest.Gap]
    }

    private func buildModel() -> Model {
        let shelf = env.products.products
        let history = CompareLocal.History(shelf: shelf, culprits: env.products.culprits)
        // Built once, unfiltered: `gaps` needs the ingredient-less rows that `pairs` drops.
        let all = candidates()
        return Model(shelf: shelf,
                     badProductCount: history.badProductCount,
                     report: localReport(history),
                     pairs: CompareSuggest.pairs(all),
                     gaps: CompareSuggest.gaps(all, coreCategories: Self.coreCategories))
    }

    var body: some View {
        let m = buildModel()
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.lg) {
                    header(m)

                    if Self.localReadIsFree {
                        readSections(m)
                    } else {
                        lockedCard
                    }

                    if bothFilled {
                        deepenSection
                    }

                    suggestionSections(m)
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
            }
            .skPageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AppDestination.self) { destination($0) }
        }
        .tint(SKColor.primary)
        .sheet(item: $picking) { key in
            ShelfPickerSheet(exclude: Set([left?.productID, right?.productID].compactMap { $0 })) { id in
                if let p = env.products.product(id: id) {
                    set(key, Pick(productID: id,
                                  name: p.product.productName,
                                  inci: p.ingredients.map(\.inciRaw).joined(separator: ", ")))
                }
            }
        }
        .sheet(item: $pasting) { key in
            CustomProductSheet(name: slot(key)?.name ?? "",
                               inci: slot(key)?.productID == nil ? (slot(key)?.inci ?? "") : "") { name, inci in
                set(key, Pick(productID: nil, name: name, inci: inci))
            }
        }
    }

    @ViewBuilder
    private func destination(_ d: AppDestination) -> some View {
        switch d {
        case .recommend: RecommendView()
        case .productDetail(let id): ProductDetailView(productID: id)
        default: EmptyView()
        }
    }

    // MARK: - 1. Header

    private func header(_ m: Model) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Compare")
                .font(SKFont.pageTitle)
                .foregroundStyle(SKColor.ink)
            Text(subtitle(m))
                .font(SKFont.sans(17, relativeTo: .body))
                .foregroundStyle(SKColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, SKSpace.md)
    }

    /// First match wins.
    private func subtitle(_ m: Model) -> String {
        if bothFilled, let r = m.report { return r.headline }
        if anyFilled { return "Pick a second one to see them side by side." }
        if !m.pairs.isEmpty {
            return "\(m.pairs.count) pair\(m.pairs.count == 1 ? "" : "s") worth comparing."
        }
        if !m.shelf.isEmpty { return "Pick two from your shelf, or paste a list." }
        return "Paste any ingredient list for an instant read."
    }

    // MARK: - 2/3. The local read

    @ViewBuilder
    private func readSections(_ m: Model) -> some View {
        if let r = m.report {
            if bothFilled { banner(r) }
            sideGrid(r)
            gridFootnotes(m)
            if let d = r.diff, bothFilled { diffCard(d) }
        }
    }

    // 2a. Banner — both sides filled only. Replaces the old trophy card.
    private func banner(_ r: CompareLocal.Report) -> some View {
        let bannerTone: SKTone = r.winnerIndex == nil ? .neutral : .good
        return SKCard(tint: bannerTone) {
            HStack(alignment: .top, spacing: SKSpace.md) {
                Image(systemName: r.winnerIndex == nil ? "equal.circle" : "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(bannerTone.fg)
                    .frame(width: 44, height: 44)
                    .background(bannerTone.bg, in: Circle())
                (Text(r.headline).font(SKFont.sans(16, weight: .semibold))
                    + Text(" " + r.reason).font(SKFont.body))
                    .foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(r.headline) \(r.reason)")
    }

    // 2b/2c. Two columns, always exactly two.
    private func sideGrid(_ r: CompareLocal.Report) -> some View {
        let cols = [GridItem(.flexible(), spacing: SKSpace.md),
                    GridItem(.flexible(), spacing: SKSpace.md)]
        return LazyVGrid(columns: cols, spacing: SKSpace.md) {
            column(.left, r)
            column(.right, r)
        }
    }

    @ViewBuilder
    private func column(_ key: SideKey, _ r: CompareLocal.Report) -> some View {
        if let pick = slot(key), let i = reportIndex(for: key), r.sides.indices.contains(i) {
            filledCard(key, pick: pick, side: r.sides[i], isWinner: bothFilled && r.winnerIndex == i)
        } else {
            emptyTile(key)
        }
    }

    private func filledCard(_ key: SideKey,
                            pick: Pick,
                            side: CompareLocal.SideReport,
                            isWinner: Bool) -> some View {
        let rows = visibleRows(side)
        let overflow = allRows(side).count - rows.count
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                SKProductMark(name: pick.name, size: 56)
                Text(pick.name)
                    .font(SKFont.cardTitle)
                    .foregroundStyle(SKColor.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                SKScoreRing(score: side.fit, size: 96, lineWidth: 9, caption: "your fit")
                    .frame(maxWidth: .infinity)
                Text(side.headline)
                    .font(SKFont.secondary)
                    .foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SKSpace.lg)

            if !rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        ingredientRow(row, showDivider: i < rows.count - 1)
                    }
                }
            }

            VStack(alignment: .leading, spacing: SKSpace.sm) {
                if overflow > 0 {
                    Text("+\(overflow) more")
                        .font(SKFont.caption)
                        .foregroundStyle(SKColor.muted)
                }
                if side.fragrance == nil {
                    SKChip("Fragrance-free", tone: .good)
                }
                if side.familiarCount > 0 {
                    Text("\(side.familiarCount) of these are in products that worked for you.")
                        .font(SKFont.caption)
                        .foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The scan score is a fact about the formula; the ring is a fact about her
                // history. Small mono text, never a second ring and never a badge.
                if let s = storedScan(pick) {
                    Text("Scanned \(s.result.score) · \(DateFormatting.relative(s.scannedAt))")
                        .font(SKFont.dataSmall)
                        .foregroundStyle(SKColor.muted)
                }
                HStack {
                    Button("Change") { openPicker(key, pasted: pick.productID == nil) }
                    Spacer()
                    Button("Clear") { set(key, nil) }
                }
                .font(SKFont.sans(13, weight: .semibold))
                .foregroundStyle(SKColor.primary)
            }
            .padding(.horizontal, SKSpace.lg)
        }
        .padding(.vertical, SKSpace.lg)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                .stroke(isWinner ? SKColor.goodFg : SKColor.line, lineWidth: isWinner ? 1.5 : 1)
        )
        .skCardShadow()
    }

    private func ingredientRow(_ row: CompareLocal.Row, showDivider: Bool) -> some View {
        let t = tone(for: row.kind)
        return SKRow(showDivider: showDivider) {
            HStack(spacing: SKSpace.md) {
                SKDot(tone: t)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(SKFont.bodyMedium)
                        .foregroundStyle(SKColor.ink)
                        .lineLimit(1)
                    Text(row.detail)
                        .font(SKFont.caption)
                        .foregroundStyle(SKColor.muted)
                        .lineLimit(2)
                }
            }
        } trailing: {
            // A two-column grid on a 393pt phone leaves a narrow trailing slot, so the
            // chip truncates rather than wrapping into a three-line capsule.
            SKChip(chipText(row), tone: t)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.name), \(chipText(row)). \(row.detail)")
    }

    // 2c. Compact "add the other one" tile.
    private func emptyTile(_ key: SideKey) -> some View {
        VStack(spacing: SKSpace.sm) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SKColor.primary)
                .frame(width: 44, height: 44)
                .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Add the other one")
                .font(SKFont.secondary)
                .foregroundStyle(SKColor.muted)
                .multilineTextAlignment(.center)
            SKButton(title: "From shelf", kind: .secondary) { picking = key }
            SKButton(title: "Paste a list", kind: .ghost) { pasting = key }
        }
        .padding(SKSpace.lg)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                .stroke(SKColor.line, lineWidth: 1)
        )
        .skCardShadow()
    }

    // 2d. The two notes that only make sense directly under the grid. Nothing is emitted
    // when neither applies, so the page never carries an invisible spacer's worth of gap.
    @ViewBuilder
    private func gridFootnotes(_ m: Model) -> some View {
        let explainsScan = storedScan(left) != nil || storedScan(right) != nil
        // Fewer than two products marked as breakouts means `Correlate` has no pattern to
        // find yet. Say so, rather than implying nothing was there to find.
        let invitesMoreData = m.badProductCount < 2
        if explainsScan || invitesMoreData {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                if explainsScan {
                    Text("Fit is about your history. The scan score is about the formula.")
                        .font(SKFont.caption)
                        .foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if invitesMoreData {
                    Text("Mark a few more products and this gets sharper.")
                        .font(SKFont.caption)
                        .foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - 3. What's different

    /// The card's chrome is `SKCard`'s, hand-built so the ingredient rows can run to the
    /// card edge and keep `SKRow`'s own 16pt gutter and inset divider, instead of sitting
    /// 32pt in behind a second layer of padding.
    private func diffCard(_ d: CompareLocal.Diff) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text(d.headline)
                .font(SKFont.cardTitle)
                .foregroundStyle(SKColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SKSpace.lg)
            // When the two formulas are all but identical the headline *is* the answer;
            // listing the one different preservative would only add noise.
            if !d.isNearIdentical {
                onlyIn(left?.name ?? "this one", rows: d.onlyLeft)
                onlyIn(right?.name ?? "the other", rows: d.onlyRight)
            }
        }
        .padding(.vertical, SKSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                .stroke(SKColor.line, lineWidth: 1)
        )
        .skCardShadow()
    }

    @ViewBuilder
    private func onlyIn(_ name: String, rows: [CompareLocal.Row]) -> some View {
        if !rows.isEmpty {
            let shown = Array(rows.prefix(4))
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                Text("ONLY IN \(name.uppercased())")
                    .skLabelStyle()
                    .padding(.horizontal, SKSpace.lg)
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, row in
                        ingredientRow(row, showDivider: i < shown.count - 1)
                    }
                }
            }
        }
    }

    // MARK: - 4. The deepening

    private var deepenSection: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            if case .failed(let e) = server { SKInlineError(message: e.userMessage) }

            SKButton(title: "Get the full ingredient read",
                     kind: .secondary,
                     isLoading: server.isLoading) { Task { await deepen() } }

            Text("Every ingredient checked, not just the ones your history already knows about.")
                .font(SKFont.caption)
                .foregroundStyle(SKColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            if case .loaded(let r) = server { fullRead(r) }
        }
    }

    /// Appended below the local read, never in place of it. No ring lives here — exactly
    /// one ring per side, and it always means "your fit".
    private func fullRead(_ r: CompareResult) -> some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text("FULL READ").skLabelStyle()
                ForEach(Array(r.items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.name) — \(item.scoreInt)/100")
                            .font(SKFont.bodyMedium)
                            .foregroundStyle(SKColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(item.keyWins?.values.prefix(3) ?? [], id: \.self) {
                            Text("✓ \($0)")
                                .font(SKFont.sans(13, weight: .semibold))
                                .foregroundStyle(SKColor.goodFg)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(item.keyConcerns?.values.prefix(3) ?? [], id: \.self) {
                            Text("✗ \($0)")
                                .font(SKFont.sans(13, weight: .semibold))
                                .foregroundStyle(SKColor.badFg)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let reason = r.winner?.reason, !reason.isEmpty {
                    Text(reason)
                        .font(SKFont.secondary)
                        .foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - 5/6/7/8. Choosing what to compare

    @ViewBuilder
    private func suggestionSections(_ m: Model) -> some View {
        if m.shelf.isEmpty && !anyFilled {
            SKEmptyState(
                icon: "arrow.left.arrow.right",
                title: "Nothing to compare yet",
                message: "Paste any ingredient list and Skintel reads it against your skin straight away. Save a few products and it starts finding pairs worth comparing.",
                actionTitle: "Paste a list"
            ) { pasting = .left }
        } else {
            if !bothFilled && !m.pairs.isEmpty {
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    SKSectionHeader(title: "Compare these two")
                    ForEach(m.pairs) { pairCard($0) }
                }
            }

            if !anyFilled {
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    Text("PICK YOUR OWN").skLabelStyle()
                    HStack(spacing: SKSpace.sm) {
                        SKButton(title: "From shelf", kind: .secondary, fullWidth: false) { picking = .left }
                        SKButton(title: "Paste a list", kind: .ghost, fullWidth: false) { pasting = .left }
                        Spacer()
                    }
                }
            }

            if !m.gaps.isEmpty { gapsSection(m.gaps) }
        }
    }

    private func pairCard(_ pair: CompareSuggest.Pair) -> some View {
        let chip = reasonChip(pair.reason)
        return Button { fill(pair) } label: {
            SKCard(padding: SKSpace.md) {
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    HStack(spacing: SKSpace.sm) {
                        SKProductMark(name: pair.left.name, size: 40)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SKColor.muted)
                        SKProductMark(name: pair.right.name, size: 40)
                        Spacer(minLength: SKSpace.sm)
                        SKChip(chip.label, tone: chip.tone).fixedSize()
                    }
                    Text(pair.line)
                        .font(SKFont.secondary)
                        .foregroundStyle(SKColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(SKPressStyle())
        .accessibilityLabel("\(pair.left.name) against \(pair.right.name). \(pair.line)")
    }

    private func gapsSection(_ gaps: [CompareSuggest.Gap]) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            SKSectionHeader(title: "Where the gaps are")
            VStack(spacing: 0) {
                ForEach(Array(gaps.enumerated()), id: \.element.id) { i, gap in
                    SKRow(showDivider: i < gaps.count - 1) {
                        Text(gap.line)
                            .font(SKFont.secondary)
                            .foregroundStyle(SKColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } trailing: {
                        SKLinkButton(title: gap.actionTitle) { route(gap) }
                    }
                }
            }
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                    .stroke(SKColor.line, lineWidth: 1)
            )
            .skCardShadow()
        }
    }

    /// Only reachable when the founder switch at the top of this file is flipped off.
    private var lockedCard: some View {
        SKCard {
            VStack(alignment: .leading, spacing: SKSpace.md) {
                Text("See how two products stack up against your own history.")
                    .font(SKFont.body)
                    .foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                SKButton(title: "Unlock Compare") { openPaywall(.compare) }
            }
        }
    }

    // MARK: - Local engine plumbing

    private var anyFilled: Bool { left != nil || right != nil }
    private var bothFilled: Bool { left != nil && right != nil }

    private var profile: SkinProfile { env.session.user?.skinProfile ?? SkinProfile() }

    private func slot(_ key: SideKey) -> Pick? {
        switch key {
        case .left: return left
        case .right: return right
        }
    }

    /// Where this side's report landed in `Report.sides`, which only ever holds the sides
    /// that were actually filled, in left-then-right order.
    private func reportIndex(for key: SideKey) -> Int? {
        switch key {
        case .left: return left == nil ? nil : 0
        case .right: return right == nil ? nil : (left == nil ? 0 : 1)
        }
    }

    private func localReport(_ history: CompareLocal.History) -> CompareLocal.Report? {
        var sides: [CompareLocal.Side] = []
        if let l = left { sides.append(CompareLocal.Side(name: l.name, parsed: parsed(l))) }
        if let r = right { sides.append(CompareLocal.Side(name: r.name, parsed: parsed(r))) }
        guard !sides.isEmpty else { return nil }
        return CompareLocal.run(sides: sides, history: history, profile: profile)
    }

    /// A shelf product supplies the stored `inci_normalized` column the web wrote, so
    /// culprit keys line up exactly. A pasted list is normalised here instead.
    private func parsed(_ pick: Pick) -> [INCI.ParsedIngredient] {
        if let id = pick.productID, let p = env.products.product(id: id) {
            return p.ingredients.map {
                INCI.ParsedIngredient(raw: $0.inciRaw, normalized: $0.inciNormalized, position: $0.position)
            }
        }
        return INCI.parse(pick.inci)
    }

    /// One unfiltered array for both engines: `pairs` drops the ingredient-less rows,
    /// `gaps` needs them.
    private func candidates() -> [CompareSuggest.Candidate] {
        var out: [CompareSuggest.Candidate] = []
        for p in env.products.products {
            out.append(CompareSuggest.Candidate(
                id: p.id,
                productID: p.id,
                name: p.product.productName,
                category: p.product.category,
                outcome: p.product.outcome,
                normalized: p.ingredients.map(\.inciNormalized),
                inci: p.ingredients.map(\.inciRaw).joined(separator: ", "),
                score: env.scans.score(for: p.id),
                date: ISO8601.date(p.product.createdAt)))
        }
        for s in env.scans.recent.prefix(20) where s.productID == nil {
            let rows = INCI.parse(s.inci)
            guard !rows.isEmpty else { continue }
            out.append(CompareSuggest.Candidate(
                id: "scan:" + s.id,
                productID: nil,
                name: s.productName ?? s.brand ?? "Scanned product",
                category: nil,
                outcome: nil,
                normalized: rows.map(\.normalized),
                inci: s.inci,
                score: s.result.score,
                date: s.scannedAt))
        }
        return out
    }

    private func storedScan(_ pick: Pick?) -> ScanStore.StoredScan? {
        guard let id = pick?.productID else { return nil }
        return env.scans.scans[id]
    }

    // MARK: Rows

    /// Classification order on screen: what she has reacted to, then what echoes a single
    /// breakout, then the fragrance flag, then what earns its place.
    private func allRows(_ side: CompareLocal.SideReport) -> [CompareLocal.Row] {
        var out = side.reacted + side.echo
        if let f = side.fragrance { out.append(f) }
        return out + side.helpers
    }

    private func visibleRows(_ side: CompareLocal.SideReport) -> [CompareLocal.Row] {
        Array(allRows(side).prefix(5))
    }

    private func tone(for kind: CompareLocal.RowKind) -> SKTone {
        switch kind {
        case .reacted: return .bad
        case .echo: return .caution
        case .helper: return .good
        case .fragrance: return isFragranceSensitive ? .bad : .caution
        case .topOfList: return .neutral
        }
    }

    private var isFragranceSensitive: Bool {
        let p = profile
        return p.skinType == .sensitive || p.concerns.contains(.redness)
    }

    private func chipText(_ row: CompareLocal.Row) -> String {
        switch row.kind {
        case .reacted: return "Reacted before"
        case .echo: return "Seen in a breakout"
        case .helper: return IngredientKnowledge.lookup(row.name)?.category.label ?? "Helps"
        case .fragrance: return "Fragrance"
        case .topOfList: return "Near the top"
        }
    }

    private func reasonChip(_ reason: CompareSuggest.Reason) -> (label: String, tone: SKTone) {
        switch reason {
        case .sameJobDifferentResult: return ("Opposite results", .caution)
        case .nearDuplicate: return ("Almost the same", .neutral)
        case .beforeYouBuy: return ("Before you buy", .neutral)
        case .stillUnsure: return ("Both unsure", .caution)
        case .bothBrokeOut: return ("Both broke you out", .bad)
        }
    }

    // MARK: Actions

    private func set(_ key: SideKey, _ pick: Pick?) {
        switch key {
        case .left: left = pick
        case .right: right = pick
        }
        server = .idle
    }

    private func openPicker(_ key: SideKey, pasted: Bool) {
        if pasted { pasting = key } else { picking = key }
    }

    /// Filling both sides *is* the action — the read appears on the same frame.
    private func fill(_ pair: CompareSuggest.Pair) {
        left = Pick(productID: pair.left.productID, name: pair.left.name, inci: pair.left.inci)
        right = Pick(productID: pair.right.productID, name: pair.right.name, inci: pair.right.inci)
        server = .idle
        Haptics.tap()
    }

    private func route(_ gap: CompareSuggest.Gap) {
        if gap.kind == .noIngredients, let id = gap.productID {
            path.append(.productDetail(id: id))
        } else {
            path.append(.recommend)
        }
    }

    /// The old `compare()`, unchanged except that it sends exactly the two filled sides and
    /// is no longer the way onto the screen. `compareRun` stays on this path only — local
    /// reads deliberately do not fire it, so expect its volume to fall after launch.
    private func deepen() async {
        guard env.subscription.entitlement.isPro else { openPaywall(.compare); return }
        let items = [left, right].compactMap { $0 }.map {
            CompareRequest.Item(name: $0.name, inci: String($0.inci.prefix(8000)))
        }
        guard items.count == 2 else { return }
        server = .loading
        do {
            server = .loaded(try await env.api.compare(CompareRequest(products: items)))
            env.analytics.track(.compareRun)
            Haptics.success()
        } catch let e as APIError {
            if e.requiresPaywall { openPaywall(.compare); server = .idle } else { server = .failed(e) }
        } catch {
            server = .failed(.network(error.localizedDescription))
        }
    }
}

struct CustomProductSheet: View {
    @State var name: String
    @State var inci: String
    let onDone: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    SKFieldLabel("Product name")
                    SKTextField(placeholder: "e.g. Fenty Hydra Vizor", text: $name, autocapitalization: .words)
                    SKFieldLabel("Ingredients (INCI)")
                    SKTextEditor(placeholder: "Aqua, Glycerin, …", text: $inci, minHeight: 180, mono: true)
                    SKButton(title: "Use this product") { onDone(name.trimmingCharacters(in: .whitespaces), inci); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || INCI.parse(inci).isEmpty)
                }
                .skPagePadding().padding(.vertical, SKSpace.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .skPageBackground()
            .skNavigationTitle("Not on your shelf")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.font(SKFont.bodyMedium) } }
        }
        .tint(SKColor.primary)
    }
}
