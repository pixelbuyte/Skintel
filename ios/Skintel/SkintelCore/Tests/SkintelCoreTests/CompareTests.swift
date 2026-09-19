import Foundation
import Testing
@testable import SkintelCore

// MARK: - Fixtures
//
// `product(_:_:_:_:)` mirrors the helper in LogicTests.swift. Both are file-private, so
// they are deliberately duplicated rather than shared.

private func product(_ id: String, _ name: String, _ outcome: Outcome, _ inci: String) -> ProductWithIngredients {
    let p = Product(id: id, userID: "u", brand: nil, productName: name, category: nil, outcome: outcome,
                    notes: nil, createdAt: "2026-01-01T00:00:00+00:00", updatedAt: "2026-01-01T00:00:00+00:00")
    let ings = INCI.parse(inci).map {
        ProductIngredient(id: "\(id)-\($0.position)", productID: id, userID: "u", position: $0.position,
                          inciRaw: $0.raw, inciNormalized: $0.normalized)
    }
    return ProductWithIngredients(product: p, ingredients: ings)
}

/// A shelf row whose stored `inci_normalized` column is written by hand, so a test can
/// reproduce a web-written product that keyed its ingredients differently.
private func storedProduct(_ id: String, _ outcome: Outcome, _ rows: [(raw: String, normalized: String)]) -> ProductWithIngredients {
    let p = Product(id: id, userID: "u", brand: nil, productName: id, category: nil, outcome: outcome,
                    notes: nil, createdAt: "2026-01-01T00:00:00+00:00", updatedAt: "2026-01-01T00:00:00+00:00")
    let ings = rows.enumerated().map { i, r in
        ProductIngredient(id: "\(id)-\(i)", productID: id, userID: "u", position: i,
                          inciRaw: r.raw, inciNormalized: r.normalized)
    }
    return ProductWithIngredients(product: p, ingredients: ings)
}

private func history(_ shelf: [ProductWithIngredients]) -> CompareLocal.History {
    CompareLocal.History(shelf: shelf, culprits: Correlate.run(shelf))
}

private let emptyHistory = CompareLocal.History(shelf: [], culprits: Correlate.run([]))

private func side(_ name: String, _ inci: String) -> CompareLocal.Side {
    CompareLocal.Side(name: name, parsed: INCI.parse(inci))
}

/// `n` ingredients the curated table has never heard of, so they classify as nothing.
private func unknowns(_ n: Int, _ prefix: String = "Qed") -> [String] {
    (0..<n).map { "\(prefix) \($0)" }
}

private func list(_ names: [String]) -> String { names.joined(separator: ", ") }

private func candidate(_ id: String,
                       name: String,
                       category: String? = nil,
                       outcome: Outcome? = nil,
                       normalized: [String] = [],
                       score: Int? = nil,
                       date: Date? = nil,
                       saved: Bool = true) -> CompareSuggest.Candidate {
    CompareSuggest.Candidate(id: id, productID: saved ? id : nil, name: name, category: category,
                             outcome: outcome, normalized: normalized,
                             inci: normalized.joined(separator: ", "), score: score, date: date)
}

private let coreCategories = ["Cleanser", "Moisturizer", "Sunscreen"]

// MARK: - CompareLocal.History

@Test func historyCountsProductsNotRows() {
    let shelf = [
        product("g1", "Cream", .good, "Glycerin, Glycerin"),
        product("b1", "Lotion", .bad, "Parfum, Alcohol Denat"),
        product("b2", "Toner", .bad, "Parfum, Sodium Lauryl Sulfate"),
        product("u1", "Mask", .unsure, "Parfum, Glycerin"),
    ]
    let h = history(shelf)

    // Two rows of the same ingredient in one product is still one product.
    #expect(h.goodCounts["glycerin"] == 1)
    #expect(h.badCounts["parfum"] == 2)
    // `.unsure` feeds neither dictionary.
    #expect(h.badCounts["glycerin"] == nil)
    #expect(h.goodCounts["parfum"] == nil)
    #expect(h.goodProductCount == 1)
    #expect(h.badProductCount == 2)
    #expect(h.culpritsByNormalized["parfum"]?.badCount == 2)
    #expect(h.culpritsByNormalized["alcohol denat"] == nil)
}

// MARK: - CompareLocal.run — classification

@Test func classifiesReactedEchoHelperFragrance() {
    let shelf = [
        product("b1", "Lotion", .bad, "Parfum, Alcohol Denat"),
        product("b2", "Toner", .bad, "Parfum, Sodium Lauryl Sulfate"),
        product("b3", "Balm", .bad, "Coconut Oil"),
        product("g1", "Cream", .good, "Glycerin"),
    ]
    let r = CompareLocal.run(sides: [side("Serum", "Water, Parfum, Coconut Oil, Niacinamide, Glycerin")],
                             history: history(shelf), profile: SkinProfile())
    let s = r.sides[0]

    #expect(s.reacted.map(\.name) == ["Parfum"])
    #expect(s.echo.map(\.name) == ["Coconut Oil"])
    #expect(s.helpers.map(\.name) == ["Niacinamide", "Glycerin"])
    // Parfum was consumed as `.reacted` — first match wins, so there is no fragrance row.
    #expect(s.fragrance == nil)
    #expect(s.familiarCount == 1)
    #expect(s.ingredientCount == 5)
    #expect(s.headline == "1 ingredient you've reacted to before.")
}

@Test func fragranceRowOnlyWhenNotAlreadyReacted() {
    let r = CompareLocal.run(sides: [side("Serum", "Water, Parfum, Coconut Oil, Niacinamide, Glycerin, Limonene")],
                             history: emptyHistory, profile: SkinProfile())
    let s = r.sides[0]

    #expect(s.reacted.isEmpty)
    #expect(s.echo.isEmpty)
    #expect(s.fragrance?.name == "Parfum")
    #expect(s.fragrance?.detail == "Fragrance — a common trigger for sensitive skin")
    // Only the first fragrance is kept; Limonene is not promoted anywhere.
    #expect(!s.helpers.contains(where: { $0.name == "Limonene" }))
    #expect(!s.reacted.contains(where: { $0.name == "Limonene" }))
    #expect(!s.echo.contains(where: { $0.name == "Limonene" }))
    #expect(s.headline == "Nothing here you've reacted to.")
}

@Test func reactedDetailNamesBadCountAndPosition() {
    let shelf = [
        product("b1", "A", .bad, "Parfum, Alcohol Denat"),
        product("b2", "B", .bad, "Parfum, Sodium Lauryl Sulfate"),
        product("b3", "C", .bad, "Parfum, Cocamidopropyl Betaine"),
    ]
    let h = history(shelf)
    #expect(h.culpritsByNormalized["parfum"]?.badCount == 3)

    let high = CompareLocal.run(sides: [side("Near the top", list(unknowns(2)) + ", Parfum")],
                                history: h, profile: SkinProfile())
    #expect(high.sides[0].reacted.first?.detail == "In 3 products that broke you out · high up the list")

    let low = CompareLocal.run(sides: [side("Far down", list(unknowns(12)) + ", Parfum")],
                               history: h, profile: SkinProfile())
    #expect(low.sides[0].reacted.first?.detail == "In 3 products that broke you out")
}

/// The silent-failure guard. `IngredientKnowledge.normalizeKey` strips the slash;
/// `INCI.normalize` keeps it, and the `inci_normalized` column holds the latter.
@Test func usesInciNormalizeNotKnowledgeKey() {
    let raw = "Caprylic/Capric Triglyceride"
    #expect(INCI.normalize(raw) == "caprylic/capric triglyceride")
    #expect(IngredientKnowledge.normalizeKey(raw) == "caprylic capric triglyceride")
    #expect(INCI.normalize(raw) != IngredientKnowledge.normalizeKey(raw))

    let inciKeyed = history([
        storedProduct("b1", .bad, [(raw, "caprylic/capric triglyceride")]),
        storedProduct("b2", .bad, [(raw, "caprylic/capric triglyceride")]),
    ])
    let matched = CompareLocal.run(sides: [side("Balm", raw)], history: inciKeyed, profile: SkinProfile())
    #expect(matched.sides[0].reacted.map(\.name) == [raw])

    let knowledgeKeyed = history([
        storedProduct("b1", .bad, [(raw, "caprylic capric triglyceride")]),
        storedProduct("b2", .bad, [(raw, "caprylic capric triglyceride")]),
    ])
    let missed = CompareLocal.run(sides: [side("Balm", raw)], history: knowledgeKeyed, profile: SkinProfile())
    #expect(missed.sides[0].reacted.isEmpty)
    #expect(missed.sides[0].echo.isEmpty)
}

// MARK: - CompareLocal.run — fit

@Test func fitIsClampedAndDeterministic() {
    // Same inputs, same report. Twice.
    let shelf = [
        product("b1", "A", .bad, "Parfum, Alcohol Denat"),
        product("g1", "B", .good, "Glycerin, Niacinamide"),
    ]
    let h = history(shelf)
    let sides = [side("Left", "Glycerin, Parfum, Niacinamide"), side("Right", "Water, Panthenol")]
    let profile = SkinProfile(skinType: .dry, concerns: [.breakouts])
    #expect(CompareLocal.run(sides: sides, history: h, profile: profile)
            == CompareLocal.run(sides: sides, history: h, profile: profile))

    // Floor: eight high-risk repeat offenders, all at the top of the list. The reacted
    // penalty saturates at its cap, so the fit bottoms out and never goes negative.
    let eight = list(unknowns(8, "Bad"))
    let worstHistory = history([
        product("b1", "A", .bad, eight),
        product("b2", "B", .bad, eight),
    ])
    let worst = CompareLocal.run(sides: [side("All triggers", eight)],
                                 history: worstHistory, profile: SkinProfile()).sides[0]
    #expect(worst.reacted.count == 8)
    #expect(worst.fit >= 0)
    #expect(worst.fit == 27)   // 72 base − 45 (reacted cap)

    // Ceiling: every bonus at once overshoots 100 and is clamped back to it.
    let allBonuses = "Niacinamide, Glycerin, Centella Asiatica Extract, Palmitoyl Tripeptide-1, Hyaluronic Acid, Panthenol, Allantoin, Bisabolol, Tocopherol, Ferulic Acid"
    let bestHistory = history([product("g1", "Loved", .good, allBonuses)])
    let best = CompareLocal.run(sides: [side("Everything", allBonuses)],
                                history: bestHistory,
                                profile: SkinProfile(concerns: [.breakouts, .redness, .fineLines])).sides[0]
    #expect(best.helpers.count == 10)
    #expect(best.familiarCount == 10)
    #expect(best.fit == 100)   // 72 + 16 + 8 + 6 = 102, clamped
}

@Test func emptySideScoresZeroWithHonestHeadline() {
    let r = CompareLocal.run(sides: [CompareLocal.Side(name: "Nothing", parsed: [])],
                             history: emptyHistory, profile: SkinProfile())
    #expect(r.sides[0].fit == 0)
    #expect(r.sides[0].headline == "No ingredients to read.")
    #expect(r.sides[0].ingredientCount == 0)
    #expect(r.sides[0].reacted.isEmpty)
}

@Test func positionWeightsReactedIngredients() {
    let h = history([
        product("b1", "A", .bad, "Parfum, Alcohol Denat"),
        product("b2", "B", .bad, "Parfum, Sodium Lauryl Sulfate"),
    ])
    let top = CompareLocal.run(sides: [side("Top", "Parfum")], history: h, profile: SkinProfile()).sides[0]
    let deep = CompareLocal.run(sides: [side("Deep", list(unknowns(20)) + ", Parfum")],
                                history: h, profile: SkinProfile()).sides[0]
    #expect(top.reacted.count == 1)
    #expect(deep.reacted.count == 1)
    #expect(top.fit < deep.fit)
}

@Test func fragrancePenaltyDoublesForSensitiveSkin() {
    // Glycerin is a hydrator, not a soothing agent, so no profile bonus muddies this.
    let s = [side("Scented", "Water, Parfum, Glycerin")]
    let neutral = CompareLocal.run(sides: s, history: emptyHistory, profile: SkinProfile()).sides[0].fit
    let sensitive = CompareLocal.run(sides: s, history: emptyHistory,
                                     profile: SkinProfile(skinType: .sensitive)).sides[0].fit
    let redness = CompareLocal.run(sides: s, history: emptyHistory,
                                   profile: SkinProfile(concerns: [.redness])).sides[0].fit

    #expect(sensitive == redness)
    #expect(sensitive < neutral)
    #expect(neutral - sensitive == 7)   // 12 instead of 5
}

@Test func profileBonusCapsAtSix() {
    // An `.active`, a `.soothing`, a `.peptide` and a `.hydrator`, and no fragrance —
    // so the only thing that moves between the two runs is the profile bonus.
    let s = [side("Everything", "Niacinamide, Centella Asiatica Extract, Palmitoyl Tripeptide-1, Glycerin")]
    let plain = CompareLocal.run(sides: s, history: emptyHistory, profile: SkinProfile()).sides[0].fit
    let loaded = CompareLocal.run(sides: s, history: emptyHistory,
                                  profile: SkinProfile(concerns: SkinConcern.allCases)).sides[0].fit
    // Four rules fire, worth 12, capped at 6.
    #expect(loaded - plain == 6)
}

@Test func helperAndFamiliarBonusesCap() {
    let twenty = "Glycerin, Hyaluronic Acid, Sodium Hyaluronate, Sodium PCA, Panthenol, Propanediol, Betaine, Urea, Trehalose, Glycereth-26, Ceramide NP, Ceramide AP, Ceramide EOP, Ceramide NS, Cholesterol, Phytosphingosine, Cetyl Alcohol, Cetearyl Alcohol, Stearyl Alcohol, Behenyl Alcohol"
    let four = "Glycerin, Hyaluronic Acid, Sodium Hyaluronate, Sodium PCA"
    let many = CompareLocal.run(sides: [side("Many", twenty)], history: emptyHistory, profile: SkinProfile()).sides[0]
    let few = CompareLocal.run(sides: [side("Few", four)], history: emptyHistory, profile: SkinProfile()).sides[0]
    #expect(many.helpers.count == 20)
    #expect(many.fit == few.fit)   // both saturate the 16-point helper cap
    #expect(many.fit == 88)

    let known = unknowns(20, "Familiar")
    let h = history([product("g1", "Loved", .good, list(known))])
    func fit(_ n: Int) -> Int {
        CompareLocal.run(sides: [side("Side", list(Array(known.prefix(n))))],
                         history: h, profile: SkinProfile()).sides[0].fit
    }
    #expect(fit(20) == fit(8))     // both saturate the 8-point familiar cap
    #expect(fit(20) == 80)
    #expect(fit(4) == 76)
}

// MARK: - CompareLocal.run — winner, tiebreak, copy

private let twoTriggerShelf = [
    product("b1", "A", .bad, "Linalool, Parfum"),
    product("b2", "B", .bad, "Linalool, Parfum"),
]

@Test func confidentWinnerWhenFitsDifferByAtLeastSix() {
    let r = CompareLocal.run(sides: [side("Marula Cleanser", "Glycerin"),
                                     side("Scented Cleanser", "Linalool, Parfum")],
                             history: history(twoTriggerShelf), profile: SkinProfile())
    #expect(r.winnerIndex == 0)
    #expect(r.isConfident)
    #expect(r.sides[0].fit > r.sides[1].fit)
    #expect(r.headline == "Marula Cleanser is the better match for you.")
}

@Test func tiebreakPrefersFewerReactedThenFragranceThenHelpers() {
    // 1. Fewer ingredients she has reacted to. A medium-risk offender deep in the list
    //    costs 4 points — inside the 6-point confidence band.
    let mediumShelf = history([
        product("b1", "A", .bad, "Water, Alcohol Denat"),
        product("b2", "B", .bad, "Water, Sodium Lauryl Sulfate"),
        product("g1", "C", .good, "Water, Glycerin"),
    ])
    let byReacted = CompareLocal.run(sides: [side("With water", list(unknowns(12)) + ", Water"),
                                             side("Without water", list(unknowns(12)) + ", Panthenol")],
                                     history: mediumShelf, profile: SkinProfile())
    #expect(abs(byReacted.sides[0].fit - byReacted.sides[1].fit) < 6)
    #expect(byReacted.sides[0].reacted.count == 1)
    #expect(byReacted.sides[1].reacted.isEmpty)
    #expect(byReacted.winnerIndex == 1)
    #expect(!byReacted.isConfident)
    #expect(byReacted.headline.hasSuffix(", by a hair."))

    // 2. Fragrance-free wins when the reacted counts match.
    let byFragrance = CompareLocal.run(sides: [side("Scented", "Water, Parfum"),
                                               side("Plain", "Water, Xanthan Gum")],
                                       history: emptyHistory, profile: SkinProfile())
    #expect(abs(byFragrance.sides[0].fit - byFragrance.sides[1].fit) < 6)
    #expect(byFragrance.sides[0].reacted.count == byFragrance.sides[1].reacted.count)
    #expect(byFragrance.winnerIndex == 1)
    #expect(!byFragrance.isConfident)
    #expect(byFragrance.headline == "Plain, by a hair.")

    // 3. More ingredients known to help, when everything above it ties.
    let byHelpers = CompareLocal.run(sides: [side("Helpful", list(unknowns(10)) + ", Glycerin"),
                                             side("Inert", list(unknowns(11)))],
                                     history: emptyHistory, profile: SkinProfile())
    #expect(abs(byHelpers.sides[0].fit - byHelpers.sides[1].fit) < 6)
    #expect(byHelpers.sides[0].helpers.count == 1)
    #expect(byHelpers.sides[1].helpers.isEmpty)
    #expect(byHelpers.winnerIndex == 0)
    #expect(!byHelpers.isConfident)
    #expect(byHelpers.headline == "Helpful, by a hair.")
}

@Test func exactTieReportsTooCloseToCall() {
    let inci = "Water, Glycerin, Niacinamide"
    let forward = CompareLocal.run(sides: [side("Alpha", inci), side("Beta", inci)],
                                   history: emptyHistory, profile: SkinProfile())
    #expect(forward.winnerIndex == nil)
    #expect(!forward.isConfident)
    #expect(forward.headline == "Too close to call.")
    #expect(forward.reason == "Nothing in your history separates these two.")

    // Swapping the sides must not flip a coin on name order.
    let backward = CompareLocal.run(sides: [side("Beta", inci), side("Alpha", inci)],
                                    history: emptyHistory, profile: SkinProfile())
    #expect(backward.winnerIndex == nil)
    #expect(backward.headline == "Too close to call.")
}

@Test func reasonPicksTheFirstTrueClause() {
    let triggers = history(twoTriggerShelf)

    // 1. The winner skips things she has reacted to.
    let skips = CompareLocal.run(sides: [side("Marula Cleanser", "Glycerin"),
                                         side("Scented", "Linalool, Parfum")],
                                 history: triggers, profile: SkinProfile())
    #expect(skips.reason == "It skips Linalool and Parfum, which are in products that broke you out.")

    // 2. Fewer, but not none.
    let fewer = CompareLocal.run(sides: [side("One trigger", "Linalool, Glycerin"),
                                         side("Two triggers", "Linalool, Parfum")],
                                 history: triggers, profile: SkinProfile())
    #expect(fewer.winnerIndex == 0)
    #expect(fewer.reason == "It has 1 ingredients you've reacted to instead of 2.")

    // 3. Fragrance.
    let fragrance = CompareLocal.run(sides: [side("Clean", "Glycerin, Niacinamide"),
                                             side("Scented", "Glycerin, Niacinamide, Parfum")],
                                     history: emptyHistory, profile: SkinProfile())
    #expect(fragrance.winnerIndex == 0)
    #expect(fragrance.reason == "It's fragrance-free; Scented isn't.")

    // 4. More ingredients known to help.
    let helpful = CompareLocal.run(sides: [side("Rich", "Glycerin, Niacinamide, Panthenol"),
                                           side("Plain", "Water, Xanthan Gum, Carbomer")],
                                   history: emptyHistory, profile: SkinProfile())
    #expect(helpful.winnerIndex == 0)
    #expect(helpful.reason == "It has 3 ingredients known to help, against 0.")

    // 5. Familiar from products that worked.
    let known = unknowns(8, "Familiar")
    let familiarHistory = history([product("g1", "Loved", .good, list(known))])
    let familiar = CompareLocal.run(sides: [side("Familiar", list(known)),
                                            side("Strange", list(unknowns(8, "Strange")))],
                                    history: familiarHistory, profile: SkinProfile())
    #expect(familiar.winnerIndex == 0)
    #expect(familiar.reason == "8 of its ingredients are already in products that worked for you.")

    // 6. Fallback — the winner is ahead only because the loser echoes a single bad product.
    let echoed = unknowns(4, "Echo")
    let echoHistory = history([product("b1", "Broke out", .bad, list(echoed))])
    let fallback = CompareLocal.run(sides: [side("Neutral", list(unknowns(2, "Inert"))),
                                            side("Echoey", list(echoed))],
                                    history: echoHistory, profile: SkinProfile())
    #expect(fallback.winnerIndex == 0)
    #expect(fallback.sides[1].echo.count == 4)
    #expect(fallback.reason == "It comes out ahead against your history.")
}

@Test func singleSideReportHasNoWinnerAndNoDiff() {
    let r = CompareLocal.run(sides: [side("Only one", "Water, Glycerin")],
                             history: emptyHistory, profile: SkinProfile())
    #expect(r.sides.count == 1)
    #expect(r.winnerIndex == nil)
    #expect(!r.isConfident)
    #expect(r.diff == nil)
    #expect(r.headline == r.sides[0].headline)
    #expect(r.reason == "Scored \(r.sides[0].fit) out of 100 against your history.")
}

// MARK: - CompareLocal — diff

@Test func diffCountsSharedAndUniqueIngredients() throws {
    let r = CompareLocal.run(sides: [side("Left", "Glycerin, Niacinamide, Water, Xanthan Gum"),
                                     side("Right", "Water, Xanthan Gum, Panthenol, Allantoin")],
                             history: emptyHistory, profile: SkinProfile())
    let d = try #require(r.diff)
    #expect(d.sharedCount == 2)
    #expect(d.totalCount == 6)
    #expect(abs(d.overlap - 2.0 / 6.0) < 0.0001)
    #expect(!d.isNearIdentical)
    #expect(d.onlyLeft.map(\.name) == ["Glycerin", "Niacinamide"])
    #expect(d.onlyRight.map(\.name) == ["Panthenol", "Allantoin"])
    #expect(d.headline == "They share 2 of 6 ingredients.")

    // Only meaningful kinds survive the filter, and each column is capped at four.
    let capped = CompareLocal.run(sides: [side("Left", "Glycerin, Niacinamide, Panthenol, Allantoin, Bisabolol, Tocopherol"),
                                          side("Right", "Water, Xanthan Gum")],
                                  history: emptyHistory, profile: SkinProfile())
    let cd = try #require(capped.diff)
    #expect(cd.onlyLeft.count == 4)
    #expect(cd.onlyLeft.allSatisfy({ $0.kind == .helper }))
    // Water and Xanthan Gum are fillers, so the right column has nothing worth naming.
    #expect(cd.onlyRight.isEmpty)
}

@Test func nearIdenticalSuppressesDetailAndSetsHeadline() throws {
    let shared = list(unknowns(9, "Shared"))
    let r = CompareLocal.run(sides: [side("Left", shared + ", Glycerin"),
                                     side("Right", shared + ", Panthenol")],
                             history: emptyHistory, profile: SkinProfile())
    let d = try #require(r.diff)
    #expect(d.sharedCount == 9)
    #expect(d.totalCount == 11)
    #expect(d.overlap >= 0.8)
    #expect(d.isNearIdentical)
    #expect(d.headline == "Nearly the same formula. Pick on price.")
}

@Test func diffFallsBackToTopOfListWhenNothingIsRecognised() throws {
    let left = unknowns(10, "Lhs")
    let right = unknowns(10, "Rhs")
    let r = CompareLocal.run(sides: [side("Left", list(left)), side("Right", list(right))],
                             history: emptyHistory, profile: SkinProfile())
    let d = try #require(r.diff)
    #expect(d.sharedCount == 0)
    #expect(!d.onlyLeft.isEmpty)
    #expect(!d.onlyRight.isEmpty)
    #expect(d.onlyLeft.allSatisfy({ $0.kind == .topOfList }))
    #expect(d.onlyRight.allSatisfy({ $0.kind == .topOfList }))
    #expect(d.onlyLeft.count <= 3)
    #expect(d.onlyRight.count <= 3)
    // Ordered by position, and never past the eighth ingredient.
    #expect(d.onlyLeft.map(\.name) == Array(left.prefix(3)))
    #expect(d.onlyRight.map(\.name) == Array(right.prefix(3)))
    #expect(d.onlyLeft[0].detail == "One of the first ingredients — there's a lot of it in here.")
}

@Test func diffHandlesEmptySideWithoutDividingByZero() throws {
    let oneSided = CompareLocal.run(sides: [CompareLocal.Side(name: "Empty", parsed: []),
                                            side("Full", "Water, Glycerin")],
                                    history: emptyHistory, profile: SkinProfile())
    let d = try #require(oneSided.diff)
    #expect(d.sharedCount == 0)
    #expect(d.totalCount == 2)
    #expect(d.overlap == 0)
    #expect(!d.isNearIdentical)

    let bothEmpty = CompareLocal.run(sides: [CompareLocal.Side(name: "A", parsed: []),
                                             CompareLocal.Side(name: "B", parsed: [])],
                                     history: emptyHistory, profile: SkinProfile())
    let e = try #require(bothEmpty.diff)
    #expect(e.totalCount == 0)
    #expect(e.overlap == 0)
    #expect(!e.isNearIdentical)
}

// MARK: - CompareSuggest.pairs

/// Ten candidates that satisfy all five rules at once, on disjoint products.
private let fiveRuleShelf: [CompareSuggest.Candidate] = [
    candidate("g1", name: "Gentle Wash", category: "Cleanser", outcome: .good,
              normalized: ["a1", "a2", "a3"], score: 10),
    candidate("b1", name: "Harsh Wash", category: "Cleanser", outcome: .bad,
              normalized: ["b1x", "b2x", "b3x"], score: 20),
    candidate("n1", name: "Tonic One", category: "Toner", outcome: .unsure,
              normalized: ["x1", "x2", "x3", "x4", "x5"], score: 30),
    candidate("n2", name: "Tonic Two", category: "Toner", outcome: .unsure,
              normalized: ["x1", "x2", "x3", "x4", "y1"], score: 31),
    candidate("g2", name: "Good Toner", category: "Toner", outcome: .good,
              normalized: ["q1", "q2", "q3"], score: 90),
    candidate("scan:s1", name: "Dew Drops", category: nil, outcome: nil,
              normalized: ["z1", "z2"], score: 70, saved: false),
    candidate("u1", name: "Mask One", category: "Mask", outcome: .unsure,
              normalized: ["m1", "m2"], score: 40),
    candidate("u2", name: "Mask Two", category: "Mask", outcome: .unsure,
              normalized: ["m3", "m4"], score: 41),
    candidate("x1", name: "Serum One", category: "Serum", outcome: .bad,
              normalized: ["s1a", "s2a"], score: 50),
    candidate("x2", name: "Serum Two", category: "Serum", outcome: .bad,
              normalized: ["s3a", "s4a"], score: 51),
]

@Test func skipsCandidatesWithNoIngredients() {
    let cs = [
        candidate("ghost", name: "Sweet Almond Balm", category: "Cleanser", outcome: .good, normalized: []),
        candidate("foam", name: "Foaming Wash", category: "Cleanser", outcome: .bad, normalized: ["a", "b"]),
        candidate("gel", name: "Gel Wash", category: "Cleanser", outcome: .good, normalized: ["a", "c"]),
    ]
    let ps = CompareSuggest.pairs(cs)
    #expect(!ps.isEmpty)
    #expect(!ps.contains(where: { $0.left.id == "ghost" || $0.right.id == "ghost" }))
    #expect(ps[0].left.id == "gel")
    #expect(ps[0].right.id == "foam")
}

@Test func rulePriorityOrder() {
    let all = CompareSuggest.pairs(fiveRuleShelf, limit: 5)
    #expect(all.map(\.reason) == [.sameJobDifferentResult, .nearDuplicate, .beforeYouBuy,
                                  .stillUnsure, .bothBrokeOut])
    #expect(all.map(\.id) == ["g1|b1", "n1|n2", "scan:s1|g2", "u1|u2", "x1|x2"])

    // The near-duplicate rule consumes the two Toners, so the "both unsure" rule has to
    // fall through to a pair whose candidates are still free.
    #expect(all[3].left.id == "u1")

    let top = CompareSuggest.pairs(fiveRuleShelf)
    #expect(top.map(\.reason) == [.sameJobDifferentResult, .nearDuplicate, .beforeYouBuy])
}

@Test func eachCandidateAppearsInAtMostOnePair() {
    let cs = [
        candidate("p1", name: "One", category: "Cleanser", outcome: .good, normalized: ["a"]),
        candidate("p2", name: "Two", category: "Cleanser", outcome: .bad, normalized: ["b"]),
        candidate("p3", name: "Three", category: "Cleanser", outcome: .bad, normalized: ["c"]),
        candidate("p4", name: "Four", category: "Cleanser", outcome: .good, normalized: ["d"]),
    ]
    let ps = CompareSuggest.pairs(cs)
    #expect(ps.count == 2)
    let ids = ps.flatMap { [$0.left.id, $0.right.id] }
    #expect(Set(ids).count == ids.count)
}

@Test func orderingIsDeterministic() {
    let expected = CompareSuggest.pairs(fiveRuleShelf, limit: 5).map(\.id)
    #expect(CompareSuggest.pairs(fiveRuleShelf, limit: 5).map(\.id) == expected)
    #expect(CompareSuggest.pairs(Array(fiveRuleShelf.reversed()), limit: 5).map(\.id) == expected)
    #expect(CompareSuggest.pairs(fiveRuleShelf.shuffled(), limit: 5).map(\.id) == expected)
}

@Test func categoryMatchIsCaseInsensitiveAndNilNeverMatchesNil() {
    let mixedCase = [
        candidate("a", name: "Lower", category: "cleanser", outcome: .good, normalized: ["a"]),
        candidate("b", name: "Upper", category: "  Cleanser ", outcome: .bad, normalized: ["b"]),
    ]
    let matched = CompareSuggest.pairs(mixedCase)
    #expect(matched.count == 1)
    #expect(matched[0].reason == .sameJobDifferentResult)

    let uncategorised = [
        candidate("c", name: "Mystery One", category: nil, outcome: .good, normalized: ["a"]),
        candidate("d", name: "Mystery Two", category: nil, outcome: .bad, normalized: ["b"]),
    ]
    #expect(CompareSuggest.pairs(uncategorised).isEmpty)
}

@Test func linesAreTheAgreedStrings() {
    let opposite = CompareSuggest.pairs([
        candidate("g", name: "CeraVe PM", category: "Moisturizer", outcome: .good, normalized: ["a"]),
        candidate("b", name: "Nivea Soft", category: "Moisturizer", outcome: .bad, normalized: ["b"]),
    ])
    #expect(opposite[0].line == "Both are moisturizer. CeraVe PM worked, Nivea Soft broke you out.")

    // 17 shared of 25 total is exactly 0.68 — the rounding case.
    let shared = (0..<17).map { "shared\($0)" }
    let duplicates = CompareSuggest.pairs([
        candidate("dupA", name: "Alpha", category: nil, outcome: .unsure,
                  normalized: shared + ["au1", "au2", "au3", "au4"]),
        candidate("dupB", name: "Beta", category: nil, outcome: .unsure,
                  normalized: shared + ["bu1", "bu2", "bu3", "bu4"]),
    ])
    #expect(duplicates[0].reason == .nearDuplicate)
    #expect(duplicates[0].line == "These two are 68% the same formula. You may only need one.")

    let sameJobScan = CompareSuggest.pairs([
        candidate("scan:1", name: "Dew Drops", category: "Serum", outcome: nil,
                  normalized: ["z1"], saved: false),
        candidate("g", name: "Ordinary Serum", category: "Serum", outcome: .good, normalized: ["a"]),
    ])
    #expect(sameJobScan[0].reason == .beforeYouBuy)
    #expect(sameJobScan[0].line == "You scanned Dew Drops and didn't save it. Put it next to the serum that works for you.")

    let looseScan = CompareSuggest.pairs([
        candidate("scan:1", name: "Dew Drops", category: nil, outcome: nil,
                  normalized: ["z1"], saved: false),
        candidate("g", name: "Alpha Hydrate", category: "Moisturizer", outcome: .good, normalized: ["a"]),
    ])
    #expect(looseScan[0].reason == .beforeYouBuy)
    #expect(looseScan[0].line == "You scanned Dew Drops and didn't save it. Put it next to Alpha Hydrate, which works for you.")

    let unsure = CompareSuggest.pairs([
        candidate("u1", name: "One", category: "Mask", outcome: .unsure, normalized: ["a"]),
        candidate("u2", name: "Two", category: "Mask", outcome: .unsure, normalized: ["b"]),
    ])
    #expect(unsure[0].line == "You're unsure about both of these. One of them is probably fine.")

    let broke = CompareSuggest.pairs([
        candidate("x1", name: "One", category: "Serum", outcome: .bad, normalized: ["a"]),
        candidate("x2", name: "Two", category: "Serum", outcome: .bad, normalized: ["b"]),
    ])
    #expect(broke[0].line == "Both of these broke you out. See what they share.")
}

@Test func respectsLimit() {
    #expect(CompareSuggest.pairs(fiveRuleShelf, limit: 1).count == 1)
    #expect(CompareSuggest.pairs(fiveRuleShelf, limit: 3).count == 3)
    #expect(CompareSuggest.pairs(fiveRuleShelf, limit: 0).isEmpty)
    #expect(CompareSuggest.pairs([]).isEmpty)
}

// MARK: - CompareSuggest.gaps

/// Fires all four gap kinds at once: an ingredient-less product, a cleanser category
/// where nothing has worked, no sunscreen at all, and one lone moisturiser that works.
private let fourGapShelf: [CompareSuggest.Candidate] = [
    candidate("balm", name: "Sweet Almond Balm", category: "Body", outcome: .unsure, normalized: []),
    candidate("c1", name: "Foaming Wash", category: "Cleanser", outcome: .bad, normalized: ["a"]),
    candidate("c2", name: "Clay Wash", category: "Cleanser", outcome: .bad, normalized: ["b"]),
    candidate("m1", name: "Alpha Hydrate", category: "Moisturizer", outcome: .good, normalized: ["c"]),
    candidate("m2", name: "Beta Cream", category: "Moisturizer", outcome: .unsure, normalized: ["d"]),
]

@Test func emptyShelfReturnsNoGaps() {
    #expect(CompareSuggest.gaps([], coreCategories: coreCategories).isEmpty)
}

@Test func gapPriorityAndLimit() {
    let capped = CompareSuggest.gaps(fourGapShelf, coreCategories: coreCategories)
    #expect(capped.map(\.kind) == [.noIngredients, .nothingWorks])

    let all = CompareSuggest.gaps(fourGapShelf, coreCategories: coreCategories, limit: 4)
    #expect(all.map(\.kind) == [.noIngredients, .nothingWorks, .missingCategory, .onlyOneThatWorks])
}

@Test func gapLinesAreTheAgreedStrings() {
    let all = CompareSuggest.gaps(fourGapShelf, coreCategories: coreCategories, limit: 4)

    #expect(all[0].line == "Sweet Almond Balm has no ingredient list yet. Add one and it can join comparisons.")
    #expect(all[0].actionTitle == "Add it")
    #expect(all[0].productID == "balm")

    // Capitalised inside this sentence, because it names the category as a heading.
    #expect(all[1].line == "Nothing in Cleanser has worked yet — 2 of 2 broke you out.")
    #expect(all[1].actionTitle == "Find a replacement")

    // Lowercased inside this one, because it reads as a noun mid-sentence.
    #expect(all[2].line == "No sunscreen on your shelf yet.")
    #expect(all[2].actionTitle == "Find one")

    #expect(all[3].line == "Alpha Hydrate is your only moisturizer that works. Worth a backup?")
    #expect(all[3].actionTitle == "Find a backup")

    #expect(Set(all.map(\.id)).count == 4)
}

@Test func noIngredientsGapNeedsTwoProducts() {
    let lonely = [candidate("balm", name: "Sweet Almond Balm", category: "Body",
                            outcome: .unsure, normalized: [])]
    let gs = CompareSuggest.gaps(lonely, coreCategories: coreCategories, limit: 4)
    #expect(!gs.contains(where: { $0.kind == .noIngredients }))
    // The shelf is still missing all three core categories, so it does not go silent.
    #expect(gs.allSatisfy({ $0.kind == .missingCategory }))
}

// MARK: - Determinism guard

/// Neither engine takes a `now:`/`today:` parameter, and `Candidate.date` is only ever a
/// sort key — so repeated calls on identical input must be byte-identical, and a fixture
/// with no dates at all must still come back in a stable order.
///
/// Enforced in review with:
/// `grep -nE 'Date\(\)|\.now|isDateInToday|isDateInYesterday' CompareLocal.swift CompareSuggest.swift`
@Test func noWallClockInsideTheEngines() {
    let shelf = [
        product("b1", "A", .bad, "Linalool, Parfum"),
        product("b2", "B", .bad, "Linalool, Parfum"),
        product("g1", "C", .good, "Glycerin, Niacinamide"),
    ]
    let h = history(shelf)
    let sides = [side("Left", "Glycerin, Linalool, Panthenol"), side("Right", "Water, Parfum, Niacinamide")]
    let profile = SkinProfile(skinType: .sensitive, concerns: [.breakouts, .redness])

    let first = CompareLocal.run(sides: sides, history: h, profile: profile)
    let second = CompareLocal.run(sides: sides, history: h, profile: profile)
    #expect(first == second)

    let dated = fiveRuleShelf
    let undated = fiveRuleShelf.map {
        CompareSuggest.Candidate(id: $0.id, productID: $0.productID, name: $0.name,
                                 category: $0.category, outcome: $0.outcome,
                                 normalized: $0.normalized, inci: $0.inci, score: $0.score, date: nil)
    }
    #expect(CompareSuggest.pairs(dated, limit: 5).map(\.id) == CompareSuggest.pairs(dated, limit: 5).map(\.id))
    #expect(CompareSuggest.pairs(undated, limit: 5).map(\.id) == CompareSuggest.pairs(Array(undated.reversed()), limit: 5).map(\.id))
    #expect(CompareSuggest.gaps(fourGapShelf, coreCategories: coreCategories, limit: 4)
            == CompareSuggest.gaps(fourGapShelf, coreCategories: coreCategories, limit: 4))
}
