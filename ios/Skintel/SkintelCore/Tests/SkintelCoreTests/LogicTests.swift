import Foundation
import Testing
@testable import SkintelCore

// MARK: - INCI (must match src/lib/inci.ts byte-for-byte)

@Test func normalizeStripsParensMarkersAndWhitespace() {
    #expect(INCI.normalize("Aqua (Water)*") == "aqua")
    #expect(INCI.normalize("  Glycerin  ") == "glycerin")
    #expect(INCI.normalize("Tocopherol†") == "tocopherol")
    #expect(INCI.normalize("Caprylic/Capric  Triglyceride") == "caprylic/capric triglyceride")
    #expect(INCI.normalize("Ceramide NP (Ceramide 3) ‡") == "ceramide np")
}

@Test func parseSplitsStripsMarkersAndDedupes() {
    let parsed = INCI.parse("1. Water, Glycerin; - Niacinamide\n• water\n2 Parfum, , Glycerin")
    #expect(parsed.map(\.normalized) == ["water", "glycerin", "niacinamide", "parfum"])
    #expect(parsed.map(\.raw) == ["Water", "Glycerin", "Niacinamide", "Parfum"])
    #expect(parsed.map(\.position) == [0, 1, 2, 3])
    #expect(INCI.parse("").isEmpty)
    #expect(INCI.parse(" , ; ").isEmpty)
}

// MARK: - Ingredient knowledge (src/lib/ingredient-knowledge.ts)

@Test func knowledgeNormaliserDiffersFromInciNormaliser() {
    #expect(IngredientKnowledge.normalizeKey("Caprylic/Capric Triglyceride") == "caprylic capric triglyceride")
    #expect(IngredientKnowledge.lookup("AQUA")?.category == .filler)
    #expect(IngredientKnowledge.lookup("Sodium Hyaluronate")?.category == .hydrator)
    #expect(IngredientKnowledge.lookup("Glycolic Acid")?.category == .active)
    #expect(IngredientKnowledge.lookup("Unobtainium") == nil)
    #expect(IngredientKnowledge.isFragrance("Parfum"))
    #expect(IngredientKnowledge.isFragrance("LIMONENE"))
    #expect(!IngredientKnowledge.isFragrance("Glycerin"))
    #expect(IngredientKnowledge.raw.count == 91)
}

@Test func categorizeAndLocalVerdict() {
    let parsed = INCI.parse("Water, Glycerin, Parfum, Niacinamide, Xanthan Gum")
    let culprit = Culprit(name: "Parfum", normalized: "parfum", badCount: 2, goodCount: 0,
                          badProducts: ["A", "B"], goodProducts: [], risk: .high)
    let b = IngredientKnowledge.categorize(parsed, culpritsByNormalized: ["parfum": culprit])
    #expect(b.watchOut.map(\.raw) == ["Parfum"])
    #expect(b.good.map(\.raw) == ["Glycerin", "Niacinamide"])
    #expect(b.rest.map(\.raw) == ["Water", "Xanthan Gum"])
    #expect(b.rest.first?.info?.category == .filler)

    let caution = IngredientKnowledge.verdict(b)
    #expect(caution.tone == .caution)
    #expect(caution.headline == "⚠ Caution. 1 of your triggers")

    let clean = IngredientKnowledge.verdict(IngredientKnowledge.categorize(parsed, culpritsByNormalized: [:]))
    #expect(clean.tone == .good)
    #expect(clean.body == "No personal triggers found. Contains 2 ingredients known to help.")

    let two = Culprit(name: "Water", normalized: "water", badCount: 3, goodCount: 1, badProducts: [], goodProducts: [], risk: .medium)
    let bad = IngredientKnowledge.verdict(IngredientKnowledge.categorize(parsed, culpritsByNormalized: ["parfum": culprit, "water": two]))
    #expect(bad.tone == .bad)
    #expect(bad.headline == "✗ 2 of your triggers found")
}

// MARK: - Culprit correlation (src/lib/correlate.ts)

private func product(_ id: String, _ name: String, _ outcome: Outcome, _ inci: String) -> ProductWithIngredients {
    let p = Product(id: id, userID: "u", brand: nil, productName: name, category: nil, outcome: outcome,
                    notes: nil, createdAt: "2026-01-01T00:00:00+00:00", updatedAt: "2026-01-01T00:00:00+00:00")
    let ings = INCI.parse(inci).map {
        ProductIngredient(id: "\(id)-\($0.position)", productID: id, userID: "u", position: $0.position,
                          inciRaw: $0.raw, inciNormalized: $0.normalized)
    }
    return ProductWithIngredients(product: p, ingredients: ings)
}

@Test func correlateFindsSharedBadIngredientsAndDowngradesOnesAlsoInGood() {
    let r = Correlate.run([
        product("1", "Lotion", .bad, "Water, Parfum, Sodium Lauryl Sulfate, Coconut Oil"),
        product("2", "Toner", .bad, "Water, Parfum, Sodium Lauryl Sulfate"),
        product("3", "Cleanser", .good, "Water, Glycerin"),
        product("4", "Serum", .unsure, "Parfum, Sodium Lauryl Sulfate"),
        product("5", "Balm", .bad, "Coconut Oil"),
    ])
    // water: in 2 bad + 1 good → medium; parfum + sls: 2 bad, 0 good → high; coconut oil: 2 bad → high
    #expect(r.medium.map(\.normalized) == ["water"])
    #expect(r.medium.first?.goodProducts == ["Cleanser"])
    #expect(r.high.map(\.normalized) == ["coconut oil", "parfum", "sodium lauryl sulfate"])
    #expect(r.high.allSatisfy { $0.badCount == 2 })
    #expect(r.byNormalized["parfum"]?.badProducts == ["Lotion", "Toner"])
}

@Test func correlateIgnoresIngredientsInOnlyOneBadProduct() {
    let r = Correlate.run([
        product("1", "A", .bad, "Parfum, Retinol"),
        product("2", "B", .bad, "Parfum"),
    ])
    #expect(r.all.map(\.normalized) == ["parfum"])
    #expect(r.high.first?.name == "Parfum")
}

@Test func correlateSortsByBadCountThenName() {
    let r = Correlate.run([
        product("1", "A", .bad, "Zinc Oxide, Parfum"),
        product("2", "B", .bad, "Zinc Oxide, Parfum"),
        product("3", "C", .bad, "Zinc Oxide"),
    ])
    #expect(r.high.map(\.normalized) == ["zinc oxide", "parfum"])
    #expect(r.high.map(\.badCount) == [3, 2])
}

// MARK: - Entitlement (server rule, not the web hook's tier-only rule)

private func sub(_ tier: Tier, _ status: String?) -> Subscription {
    Subscription(userID: "u", tier: tier, status: status, createdAt: "", updatedAt: "")
}

@Test func entitlementFollowsServerRule() {
    #expect(!Entitlement(nil).isPro)
    #expect(Entitlement(nil).productLimit == 5)
    #expect(Entitlement(sub(.pro, "active")).isPro)
    #expect(Entitlement(sub(.pro, "trialing")).isPro)
    #expect(Entitlement(sub(.founding, "active")).isPro)
    #expect(!Entitlement(sub(.pro, "canceled")).isPro)          // web would say paid; API says 402
    #expect(Entitlement(sub(.pro, "canceled")).isPaidTier)
    #expect(!Entitlement(sub(.free, "active")).isPro)
    #expect(Entitlement(sub(.pro, "active")).productLimit == nil)
    #expect(Entitlement(nil).canAddProduct(currentCount: 4))
    #expect(!Entitlement(nil).canAddProduct(currentCount: 5))
    #expect(Entitlement(sub(.founding, "active")).tierLabel == "Founding member")
}

// MARK: - Session / metadata

@Test func sessionExpiryAndMetadataAccessors() {
    let user = AuthUser(id: "u", email: "a@b.c", userMetadata: [
        "skin_type": .string("combination"),
        "concerns": .array([.string("breakouts"), .string("dark_spots"), .string("bogus")]),
        "onboarding_complete": .bool(true),
        "full_name": .string("Riya Patel"),
    ])
    #expect(user.skinProfile.skinType == .combination)
    #expect(user.skinProfile.concerns == [.breakouts, .darkSpots])
    #expect(user.skinProfile.summary == "combination · breakout-prone")
    #expect(user.onboardingComplete)
    #expect(user.displayName == "Riya Patel")
    #expect(user.firstName == "Riya")

    let s = Session(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(30), user: user)
    #expect(s.isExpiring())
    #expect(!Session(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(600), user: user).isExpiring())

    let patch = AuthUser.metadataPatch(profile: SkinProfile(skinType: .oily, concerns: [.redness]), displayName: "R", onboardingComplete: true)
    #expect(patch["skin_type"] == .string("oily"))
    #expect(patch["concerns"] == .array([.string("redness")]))
    #expect(patch["onboarding_complete"] == .bool(true))
    #expect(patch["display_name"] == .string("R"))
}

@Test func tokenResponseComputesExpiryFromExpiresIn() throws {
    let json = #"{"access_token":"at","token_type":"bearer","expires_in":3600,"refresh_token":"rt","user":{"id":"u1","email":"x@y.z","user_metadata":{}}}"#
    let tok = try JSONDecoder().decode(GoTrueClient.TokenResponse.self, from: Data(json.utf8))
    let now = Date(timeIntervalSince1970: 1_000_000)
    let s = try tok.session(now: now)
    #expect(s.expiresAt == now.addingTimeInterval(3600))
    #expect(s.user.id == "u1")
}

// MARK: - Dates

@Test func iso8601ParsesPostgresAndDayStrings() {
    #expect(ISO8601.date("2026-08-17T23:05:06.123456+00:00") != nil)
    #expect(ISO8601.date("2026-08-17T23:05:06+00:00") != nil)
    #expect(ISO8601.date("2026-08-17T23:05:06Z") != nil)
    #expect(ISO8601.date("2026-08-17") != nil)
    #expect(ISO8601.date(nil) == nil)
    #expect(ISO8601.date("") == nil)
    #expect(ISO8601.dayString(Date(timeIntervalSince1970: 0)) == "1970-01-01")
}
