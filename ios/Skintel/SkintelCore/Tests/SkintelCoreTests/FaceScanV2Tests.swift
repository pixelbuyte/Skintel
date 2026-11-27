import Foundation
import Testing
@testable import SkintelCore

/// Tips on a result, goals on a request, and the face/goals keys of an Ask request.

@Test func tipsDecodeTolerantlyAndRoundTrip() throws {
    let json = """
    {"quality":{"ok":true,"issues":[]},"zones":[],"summary":"Mostly clear.",
     "tips":[{"title":"Gel moisturiser","why":"Some shine on the nose.","zone":"nose","metric":"shine"},
             {"title":"","why":"no title"},
             {"title":"SPF daily","zone":"ear","metric":"glow"},
             {"title":"Third"},{"title":"Fourth"}]}
    """
    let result = try JSONDecoder().decode(FaceScanResult.self, from: Data(json.utf8))
    #expect(result.tips.count == 3)
    #expect(result.tips[0] == FaceTip(title: "Gel moisturiser", why: "Some shine on the nose.", zone: .nose, metric: .shine))
    #expect(result.tips[1] == FaceTip(title: "SPF daily"))
    #expect(result.tips[2].title == "Third")
    let again = try JSONDecoder().decode(FaceScanResult.self, from: JSONEncoder().encode(result))
    #expect(again == result)
}

@Test func resultsStoredBeforeTipsStillDecode() throws {
    let old = #"{"quality":{"ok":true,"issues":[]},"zones":[],"summary":"Old"}"#
    let result = try JSONDecoder().decode(FaceScanResult.self, from: Data(old.utf8))
    #expect(result.tips.isEmpty)
    #expect(result.summary == "Old")
}

@Test func goalsAreSentOnlyWhenSet() throws {
    let plain = FaceScanRequest(stage: .baseline, cycleId: "c1", day: 1)
    let plainJSON = String(decoding: try JSONEncoder().encode(plain), as: UTF8.self)
    #expect(!plainJSON.contains("goals"))
    let withGoals = FaceScanRequest(stage: .baseline, cycleId: "c1", day: 1, goals: ["Less shine"])
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(withGoals)) as? [String: Any]
    #expect(object?["goals"] as? [String] == ["Less shine"])
}

@Test func askBodyOmitsFaceAndGoalsUnlessUsed() throws {
    let routine = SkintelAPI.AssistantBody.Routine(am: [], pm: [])
    let turns = [SkintelAPI.AssistantTurn(role: "user", content: "Hi")]
    let plain = SkintelAPI.AssistantBody(messages: turns, routine: routine, model: "luna", tagged: [], face: nil, goals: nil)
    let plainObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(plain)) as? [String: Any]
    #expect(plainObject?["face"] == nil)
    #expect(plainObject?["goals"] == nil)
    let tagged = SkintelAPI.AssistantBody(messages: turns, routine: routine, model: "luna", tagged: [], face: true, goals: ["Less shine"])
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(tagged)) as? [String: Any]
    #expect(object?["face"] as? Bool == true)
    #expect(object?["goals"] as? [String] == ["Less shine"])
}
