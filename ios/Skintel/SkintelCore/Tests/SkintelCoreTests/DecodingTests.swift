import Foundation
import Testing
@testable import SkintelCore

private func decode<T: Decodable>(_ t: T.Type, _ json: String) throws -> T {
    try JSONCoding.decode(T.self, from: Data(json.utf8))
}

@Test func decodesPostgRESTProductWithNestedIngredientsSorted() throws {
    let json = """
    [{"id":"p1","user_id":"u","brand":"CeraVe","product_name":"Foaming Cleanser","category":"Cleanser",
      "outcome":"good","notes":null,"created_at":"2026-08-01T10:00:00.000000+00:00","updated_at":"2026-08-01T10:00:00.000000+00:00",
      "product_ingredients":[
        {"id":"i2","product_id":"p1","user_id":"u","position":1,"inci_raw":"Glycerin","inci_normalized":"glycerin"},
        {"id":"i1","product_id":"p1","user_id":"u","position":0,"inci_raw":"Aqua","inci_normalized":"aqua"}]}]
    """
    let rows = try decode([ProductWithIngredients].self, json)
    #expect(rows.count == 1)
    #expect(rows[0].product.productName == "Foaming Cleanser")
    #expect(rows[0].product.outcome == .good)
    #expect(rows[0].ingredients.map(\.inciRaw) == ["Aqua", "Glycerin"])
    #expect(rows[0].id == "p1")

    // Round-trips through Encodable with the same wire keys.
    let data = try JSONCoding.encoder.encode(rows)
    let again = try JSONCoding.decode([ProductWithIngredients].self, from: data)
    #expect(again == rows)
}

@Test func decodesProductWithoutIngredientsKey() throws {
    let json = """
    [{"id":"p1","user_id":"u","brand":null,"product_name":"X","category":null,"outcome":"unsure","notes":null,
      "created_at":"2026-08-01T10:00:00+00:00","updated_at":"2026-08-01T10:00:00+00:00"}]
    """
    let rows = try decode([ProductWithIngredients].self, json)
    #expect(rows[0].ingredients.isEmpty)
}

@Test func decodesSubscriptionAndJournal() throws {
    let s = try decode([Subscription].self, """
    [{"user_id":"u","tier":"founding","stripe_customer_id":null,"stripe_subscription_id":null,"status":"active",
      "current_period_end":null,"founding_seat_number":42,"created_at":"2026-08-01T10:00:00+00:00","updated_at":"2026-08-01T10:00:00+00:00"}]
    """)
    #expect(s.first?.tier == .founding)
    #expect(s.first?.foundingSeatNumber == 42)
    #expect(Entitlement(s.first).isPro)

    let j = try decode(JournalEntriesResponse.self, """
    {"entries":[{"id":"j1","user_id":"u","entry_date":"2026-08-17","condition":"breakout","notes":"ugh","photo_url":null,"created_at":"2026-08-17T20:00:00+00:00"}]}
    """)
    #expect(j.entries.first?.condition == .breakout)
    #expect(j.entries.first?.entryDate == "2026-08-17")
}

@Test func scanResultToleratesLLMShapedFields() throws {
    let r = try decode(ScanAIResponse.self, """
    {"result":{"verdict":"Clean","score":"82","summary":"Gentle gel cleanser.","flags":[
      {"ingredient":"Cocamidopropyl hydroxysultaine","level":"MEDIUM","reason":"rare sensitivity trigger"}],"notes":null},"model":"x"}
    """).result
    #expect(r.verdict == .clean)
    #expect(r.score == 82)
    #expect(r.flags.first?.level == .medium)
    #expect(r.mediumCount == 1 && r.highCount == 0)

    let clamped = try decode(ScanAIResponse.self, #"{"result":{"verdict":"avoid","score":140,"summary":"","flags":[]}}"#).result
    #expect(clamped.score == 100)
    #expect(clamped.verdict == .avoid)

    let bogus = try decode(ScanAIResponse.self, #"{"result":{"verdict":"meh","score":"n/a","summary":"x","flags":"none"}}"#).result
    #expect(bogus.verdict == .caution)
    #expect(bogus.score == 0)
    #expect(bogus.flags.isEmpty)
}

@Test func journalAnalysisConfidenceNormalises() throws {
    let a = try decode(JournalAnalysisResponse.self, """
    {"result":{"summary":"s","suspects":[
      {"productOrIngredient":"Fragrance-heavy lotion","confidence":0.87,"reasoning":"r","evidenceDates":["2026-07-01","2026-07-09"]},
      {"productOrIngredient":"Retinol","confidence":"54%","reasoning":"purge?","evidenceDates":"2026-07-03"}],
      "patterns":["p"],"recommendations":null}}
    """).result
    #expect(a.suspects[0].confidencePercent == 87)
    #expect(a.suspects[0].evidenceDates?.values.count == 2)
    #expect(a.suspects[1].confidencePercent == 54)
    #expect(a.suspects[1].evidenceDates?.values == ["2026-07-03"])
    #expect(a.recommendations?.values.isEmpty ?? true)
}

@Test func routineAndCompareDecodeWithMissingArrays() throws {
    let r = try decode(RoutineAnalysisResponse.self, """
    {"result":{"amVerdict":"fine","pmVerdict":"careful","conflicts":[{"products":["Retinol 0.5%","2% BHA"],"issue":"same night","severity":"high","fix":"alternate"}]}}
    """).result
    #expect(r.conflicts.first?.isHigh == true)
    #expect(r.conflicts.first?.products?.values == ["Retinol 0.5%", "2% BHA"])
    #expect(r.suggestions == nil)

    let c = try decode(CompareResult.self, """
    {"items":[{"name":"A","verdict":"clean","score":88,"short":"good","keyConcerns":[],"keyWins":["ceramides"]},
              {"name":"B","verdict":"caution","score":"61","short":"meh"}],"winner":{"index":0,"reason":"fewer flags"}}
    """)
    #expect(c.items.map(\.scoreInt) == [88, 61])
    #expect(c.winner?.index == 0)
}

@Test func recommendDecodes() throws {
    let r = try decode(RecommendResponse.self, """
    {"result":{"recommendations":[{"brand":"CeraVe","productName":"PM Lotion","category":"Moisturizer","priceRange":"$","keyIngredients":["niacinamide","ceramides"],"whyItFits":"w","watchOuts":"none"}]},"meta":{"avoidCount":3,"preferCount":5}}
    """).result
    #expect(r.recommendations.first?.keyIngredients?.values == ["niacinamide", "ceramides"])
}

// MARK: - Error mapping

@Test func errorMappingCoversPaywallAndAuth() {
    #expect(mapError(status: 402, data: Data(#"{"error":"Pro required"}"#.utf8)) == .proRequired)
    #expect(mapError(status: 401, data: Data()) == .unauthenticated)
    #expect(mapError(status: 400, data: Data(#"{"code":"P0001","message":"FREE_PLAN_LIMIT","details":null,"hint":null}"#.utf8)) == .freePlanLimit)
    #expect(mapError(status: 409, data: Data(#"{"error":"Founding offer is sold out"}"#.utf8)) == .conflict("Founding offer is sold out"))
    #expect(mapError(status: 404, data: Data(#"{"error":"Not found in databases","upc":"123"}"#.utf8)) == .notFound("Not found in databases"))
    #expect(mapError(status: 400, data: Data(#"{"error":"invalid_grant","error_description":"Invalid login credentials"}"#.utf8)) == .badRequest("Invalid login credentials"))
    #expect(mapError(status: 503, data: Data()) == .server(status: 503, message: nil))
    #expect(APIError.proRequired.requiresPaywall && APIError.freePlanLimit.requiresPaywall)
    #expect(APIError.offline.isRetryable && !APIError.proRequired.isRetryable)
}

@Test func productPatchEncodesOnlySetFields() {
    let p = PostgRESTClient.ProductPatch(brand: .set(nil), productName: .set("New"), notes: .keep)
    let j = p.json
    #expect(j["brand"] == .null)
    #expect(j["product_name"] == .string("New"))
    #expect(j["notes"] == nil)
    #expect(j["category"] == nil)
}
