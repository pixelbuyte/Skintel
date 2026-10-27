import Foundation
import Testing
@testable import SkintelCore

// Face Scan Pro wire contract (PRO-SPEC §3): tolerant decoding and clamping.

private func decodeFace<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONCoding.decode(T.self, from: Data(json.utf8))
}

/// The §3 example, with its comments removed.
private let specExample = """
{
  "quality": { "ok": true, "issues": [] },
  "zones": [
    { "zone": "chin",
      "scores": { "redness": 34, "shine": 12, "raised_blemishes": 41, "flat_marks": 22, "texture": 18 },
      "regions": [ { "kind": "raised_blemish", "box": [0.42, 0.61, 0.08, 0.07] } ],
      "note": "A few raised blemishes along the jawline." }
  ],
  "summary": "Mostly calm. Shine on the T-zone, a few blemishes on the chin.",
  "disclaimer": "A cosmetic read of a photo, not a diagnosis."
}
"""

@Test func faceScanDecodesTheSpecExample() throws {
    let r = try decodeFace(FaceScanResult.self, specExample)
    #expect(r.quality == FaceQuality(ok: true, issues: []))
    #expect(r.zones.count == 1)
    let chin = try #require(r.zone(.chin))
    #expect(chin.scores == [.redness: 34, .shine: 12, .raisedBlemishes: 41, .flatMarks: 22, .texture: 18])
    #expect(chin.note == "A few raised blemishes along the jawline.")
    #expect(chin.regions.count == 1)
    #expect(chin.regions[0].kind == "raised_blemish")
    #expect(chin.regions[0].box == [0.42, 0.61, 0.08, 0.07])
    #expect(chin.regions[0].x == 0.42 && chin.regions[0].height == 0.07)
    #expect(r.summary == "Mostly calm. Shine on the T-zone, a few blemishes on the chin.")
    #expect(r.disclaimer == "A cosmetic read of a photo, not a diagnosis.")
    #expect(r.report == nil)
    #expect(r.routine == nil)
    #expect(r.score(.shine, in: .chin) == 12)
    #expect(r.score(.shine, in: .forehead) == nil)
}

@Test func faceScanDecodesTheReportStageExample() throws {
    let json = """
    { "quality": { "ok": true, "issues": [] }, "zones": [], "summary": "Week done.", "disclaimer": "d",
      "report": { "oil_pattern": "combination", "redness": "steady", "barrier": "less_steady", "marks": "fading",
                  "suggested_active": { "name": "Azelaic acid", "why": "Evens red marks.", "nights_per_week": 3 } },
      "routine": { "am": [ { "step": "Gentle cleanser", "product": "CeraVe Hydrating", "note": "30 seconds" },
                           { "step": "SPF 30" } ],
                   "pm": [ { "step": "Cleanser", "product": "", "note": "" },
                           { "step": "Azelaic acid", "product": "The Ordinary Azelaic 10%", "note": "3 nights a week" } ],
                   "conflicts": ["Retinol and AHA on the same night"] } }
    """
    let r = try decodeFace(FaceScanResult.self, json)
    let report = try #require(r.report)
    #expect(report.oilPattern == .combination)
    #expect(report.redness == .steady)
    #expect(report.barrier == .lessSteady)
    #expect(report.marks == .fading)
    #expect(report.suggestedActive == FaceReport.SuggestedActive(name: "Azelaic acid", why: "Evens red marks.", nightsPerWeek: 3))
    let routine = try #require(r.routine)
    #expect(routine.am == [FaceRoutine.Step(step: "Gentle cleanser", product: "CeraVe Hydrating", note: "30 seconds"),
                           FaceRoutine.Step(step: "SPF 30")])
    // An empty product is nil, a missing note is "".
    #expect(routine.pm[0] == FaceRoutine.Step(step: "Cleanser"))
    #expect(routine.pm[0].product == nil && routine.pm[0].note == "")
    #expect(routine.pm[1].product == "The Ordinary Azelaic 10%")
    #expect(routine.conflicts == ["Retinol and AHA on the same night"])

    // `suggested_active: null` is a valid report.
    let none = try decodeFace(FaceReport.self, #"{"oil_pattern":"oily","suggested_active":null}"#)
    #expect(none.suggestedActive == nil)
    #expect(none.oilPattern == .oily)
}

@Test func faceScanIgnoresUnknownKeysAtEveryLevel() throws {
    let json = """
    { "quality": { "ok": true, "issues": ["blurry"], "lux": 120 },
      "zones": [ { "zone": "nose", "scores": { "shine": 70 }, "regions": [ { "kind": "k", "box": [0, 0, 1, 1], "conf": 0.9 } ],
                   "note": "n", "confidence": 0.5 } ],
      "summary": "s", "disclaimer": "d", "model": "google/gemini-4-argon", "cycleId": "c1",
      "report": { "oil_pattern": "dry", "future_field": [1, 2] },
      "routine": { "am": [], "pm": [], "conflicts": [], "extra": true } }
    """
    let r = try decodeFace(FaceScanResult.self, json)
    #expect(r.quality == FaceQuality(ok: true, issues: ["blurry"]))
    #expect(r.score(.shine, in: .nose) == 70)
    #expect(r.zone(.nose)?.regions.count == 1)
    #expect(r.report?.oilPattern == .dry)
    #expect(r.routine != nil)
}

@Test func faceScanDropsUnknownZonesAndMetricsWithoutFailing() throws {
    let json = """
    { "quality": { "ok": true },
      "zones": [ { "zone": "neck", "scores": { "shine": 50 } },
                 { "scores": { "shine": 50 } },
                 "not an object",
                 { "zone": "left_cheek", "scores": { "shine": 40, "glow": 99, "texture": "rough", "redness": null, "flat_marks": 8 } } ],
      "summary": "s", "disclaimer": "d" }
    """
    let r = try decodeFace(FaceScanResult.self, json)
    #expect(r.zones.map(\.zone) == [.leftCheek])
    // Unknown metric `glow`, a string and a null are dropped; the valid two stay.
    #expect(r.zones[0].scores == [.shine: 40, .flatMarks: 8])
}

@Test func faceScanClampsAndRoundsScores() throws {
    let json = """
    { "quality": { "ok": true }, "summary": "", "disclaimer": "d",
      "zones": [ { "zone": "forehead",
                   "scores": { "redness": -5, "shine": 140, "texture": 34.5, "flat_marks": 12.4, "raised_blemishes": 1e30 } } ] }
    """
    let r = try decodeFace(FaceScanResult.self, json)
    let s = try #require(r.zone(.forehead)).scores
    #expect(s[.redness] == 0)
    #expect(s[.shine] == 100)
    #expect(s[.texture] == 35)           // halves round away from zero
    #expect(s[.flatMarks] == 12)
    #expect(s[.raisedBlemishes] == 100)  // clamped before converting, so no Int overflow
    #expect(FaceZoneResult.clampScore(-0.4) == 0)
    #expect(FaceZoneResult.clampScore(99.6) == 100)
    #expect(FaceZoneResult.clampScore(-1e30) == 0)
    // The initializer holds the same invariant for callers building results by hand.
    let built = FaceZoneResult(zone: .chin, scores: [.shine: -5, .redness: 140, .texture: 50])
    #expect(built.scores == [.shine: 0, .redness: 100, .texture: 50])
}

@Test func faceRegionDropsMalformedBoxesAndKeepsTheRest() throws {
    let json = """
    { "zone": "chin", "scores": { "shine": 10 },
      "regions": [ { "kind": "raised_blemish", "box": [0.1, 0.2, 0.3] },
                   { "kind": "raised_blemish", "box": [0.1, 0.2, 0.3, 0.4, 0.5] },
                   { "kind": "raised_blemish", "box": [0.1, "x", 0.3, 0.4] },
                   { "kind": "raised_blemish" },
                   { "kind": "raised_blemish", "box": "0.1,0.2,0.3,0.4" },
                   { "kind": "red_mark", "box": [-0.2, 0.5, 1.4, 0.25] },
                   { "box": [0, 0, 0.5, 0.5] } ] }
    """
    let z = try decodeFace(FaceZoneResult.self, json)
    #expect(z.regions.count == 2)
    // Out-of-range numbers are clamped to 0...1, not rejected.
    #expect(z.regions[0] == FaceRegion(kind: "red_mark", box: [0, 0.5, 1, 0.25]))
    #expect(z.regions[0] == FaceRegion(kind: .redMark, box: [0, 0.5, 1, 0.25]))
    #expect(z.regions[0].kindValue == .redMark)
    // A region with no kind is still a usable highlight.
    #expect(z.regions[1].kind == "")
    #expect(z.regions[1].kindValue == .unknown)
    #expect(z.regions[1].box == [0, 0, 0.5, 0.5])
    #expect(z.scores == [.shine: 10])

    #expect(FaceRegion(kind: "k", box: [0.1, 0.2, 0.3]) == nil)
    #expect(FaceRegion(kind: "k", box: [0.1, 0.2, 0.3, .nan]) == nil)
    #expect(FaceRegion(kind: "k", box: [2, -1, 0.5, 0.5])?.box == [1, 0, 0.5, 0.5])
    #expect(throws: (any Error).self) { try decodeFace(FaceRegion.self, #"{"kind":"k","box":[1,2]}"#) }
}

@Test func faceScanDecodesWithEveryFieldMissing() throws {
    let r = try decodeFace(FaceScanResult.self, "{}")
    // Nobody vouched for the read, so it is not ok and would not count toward an unlock.
    #expect(r.quality == FaceQuality(ok: false, issues: []))
    #expect(r.zones.isEmpty)
    #expect(r.summary == "")
    #expect(r.disclaimer == FaceScanResult.defaultDisclaimer)
    #expect(r.report == nil && r.routine == nil)

    let wrongTypes = try decodeFace(FaceScanResult.self, """
    { "quality": "fine", "zones": {"a": 1}, "summary": 7, "disclaimer": "", "report": [], "routine": 3 }
    """)
    #expect(wrongTypes.quality.ok == false)
    #expect(wrongTypes.zones.isEmpty)
    #expect(wrongTypes.summary == "")
    #expect(wrongTypes.disclaimer == FaceScanResult.defaultDisclaimer)   // an empty disclaimer is never shown as empty
    #expect(wrongTypes.report == nil && wrongTypes.routine == nil)
}

@Test func faceReportFallsBackToUnknownAndClampsNights() throws {
    let r = try decodeFace(FaceReport.self, """
    { "oil_pattern": "greasy", "redness": 5, "barrier": "wobbly", "marks": null,
      "suggested_active": { "name": "Niacinamide", "nights_per_week": 12 } }
    """)
    #expect(r.oilPattern == .unknown && r.redness == .unknown && r.barrier == .unknown && r.marks == .unknown)
    #expect(r.suggestedActive == FaceReport.SuggestedActive(name: "Niacinamide", why: "", nightsPerWeek: 7))
    #expect(try decodeFace(FaceReport.self, #"{"suggested_active":{"name":"X","nights_per_week":0}}"#)
        .suggestedActive?.nightsPerWeek == 1)
    #expect(try decodeFace(FaceReport.self, #"{"suggested_active":{"name":"X","nights_per_week":2.6}}"#)
        .suggestedActive?.nightsPerWeek == 3)
    // A suggestion with no name is not a suggestion.
    #expect(try decodeFace(FaceReport.self, #"{"suggested_active":{"why":"no name"}}"#).suggestedActive == nil)
    // Case differences do not matter; an empty report is all unknown.
    #expect(try decodeFace(FaceReport.self, #"{"marks":"MORE"}"#).marks == .more)
    #expect(try decodeFace(FaceReport.self, "{}") == FaceReport())
}

@Test func faceRoutineDecodesWithMissingArraysAndBadElements() throws {
    let r = try decodeFace(FaceRoutine.self, #"{"am":["SPF", 3, null, "Moisturiser"]}"#)
    #expect(r.am == [FaceRoutine.Step(step: "SPF"), FaceRoutine.Step(step: "Moisturiser")])
    #expect(r.pm.isEmpty && r.conflicts.isEmpty)
    #expect(try decodeFace(FaceRoutine.self, "{}") == FaceRoutine())
}

@Test func faceRoutineStepsDecodeFromStringsOrObjectsAndDropTheUnusable() throws {
    let r = try decodeFace(FaceRoutine.self, """
    { "pm": [ "Cleanser",
              { "step": "Niacinamide", "product": "  ", "note": "after cleansing", "extra": 1 },
              { "step": "Moisturiser", "product": "CeraVe PM" },
              { "product": "no step text" },
              { "step": "   " },
              "",
              { "step": 7 },
              [] ] }
    """)
    #expect(r.pm.map(\.step) == ["Cleanser", "Niacinamide", "Moisturiser"])
    #expect(r.pm[0] == FaceRoutine.Step(step: "Cleanser", product: nil, note: ""))
    #expect(r.pm[1].product == nil)            // whitespace-only product is nil
    #expect(r.pm[1].note == "after cleansing")
    #expect(r.pm[2].product == "CeraVe PM" && r.pm[2].note == "")
    #expect(FaceRoutine.Step(step: "X", product: "").product == nil)

    // Steps encode as objects and read back equal.
    let data = try JSONCoding.encoder.encode(r)
    #expect(try JSONCoding.decode(FaceRoutine.self, from: data) == r)
    #expect(String(decoding: data, as: UTF8.self).contains(#""step":"Cleanser""#))
}

@Test func faceZoneNoteIsNilWhenBlank() throws {
    #expect(try decodeFace(FaceZoneResult.self, #"{"zone":"chin","note":""}"#).note == nil)
    #expect(try decodeFace(FaceZoneResult.self, #"{"zone":"chin","note":"  \n "}"#).note == nil)
    #expect(try decodeFace(FaceZoneResult.self, #"{"zone":"chin","note":"A few."}"#).note == "A few.")
    #expect(try decodeFace(FaceZoneResult.self, #"{"zone":"chin"}"#).note == nil)
    #expect(FaceZoneResult(zone: .chin, note: "").note == nil)
}

@Test func faceRegionKindsReadAsCosmeticWords() throws {
    #expect(FaceRegion.Kind.allCases.map(\.rawValue)
            == ["raised_blemish", "clogged_pore", "red_mark", "brown_mark", "uneven_texture", "unknown"])
    #expect(FaceRegion.Kind.allCases.map(\.label)
            == ["Raised blemish", "Clogged pore", "Red mark", "Brown mark", "Uneven texture", "Area"])
    // A kind this build does not know keeps its string for storage and reads as unknown.
    let region = try #require(FaceRegion(kind: "future_kind", box: [0, 0, 1, 1]))
    #expect(region.kind == "future_kind")
    #expect(region.kindValue == .unknown)
    #expect(FaceRegion(kind: "Brown_Mark", box: [0, 0, 1, 1])?.kindValue == .brownMark)
    let decoded = try decodeFace(FaceRegion.Kind.self, #""clogged_pore""#)
    #expect(decoded == .cloggedPore)
    #expect(try decodeFace(FaceRegion.Kind.self, "5") == .unknown)
}

@Test func oilPatternUsesOneVocabularyIncludingBalanced() throws {
    #expect(FaceReport.OilPattern.allCases.map(\.rawValue) == ["oily", "dry", "combination", "normal", "unknown"])
    #expect(FaceReport.OilPattern.normal.label == "Balanced")
    let cases: [(wire: String, expected: FaceReport.OilPattern)] = [
        ("dry", .dry), ("normal", .normal), ("combination", .combination), ("oily", .oily),
        ("balanced", .normal), ("Balanced", .normal), ("greasy", .unknown),
    ]
    for (wire, expected) in cases {
        #expect(try decodeFace(FaceReport.self, #"{"oil_pattern":"\#(wire)"}"#).oilPattern == expected, "\(wire)")
    }
}

@Test func faceScanRoundTripsThroughTheSharedEncoder() throws {
    let original = try decodeFace(FaceScanResult.self, """
    { "quality": { "ok": true, "issues": ["filter"] },
      "zones": [ { "zone": "right_cheek", "scores": { "redness": 61, "flat_marks": 9 },
                   "regions": [ { "kind": "raised_blemish", "box": [0.1, 0.2, 0.3, 0.4] } ], "note": "n" },
                 { "zone": "chin", "scores": { "shine": 5 } } ],
      "summary": "s", "disclaimer": "d",
      "report": { "oil_pattern": "combination", "redness": "variable", "barrier": "less_steady", "marks": "more",
                  "suggested_active": { "name": "Azelaic acid", "why": "w", "nights_per_week": 2 } },
      "routine": { "am": [ { "step": "Cleanser", "product": "CeraVe", "note": "n" } ], "pm": ["p"], "conflicts": ["c"] } }
    """)
    let data = try JSONCoding.encoder.encode(original)
    #expect(try JSONCoding.decode(FaceScanResult.self, from: data) == original)
    // Scores go out as a JSON object with the wire keys.
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains(#""flat_marks":9"#))
    #expect(text.contains(#""zone":"right_cheek""#))
    #expect(text.contains(#""nights_per_week":2"#))
}

@Test func faceScanEntryDecodesDamagedStoredEntries() throws {
    let ok = try decodeFace(FaceScanEntry.self, """
    {"day":"2026-10-26","stage":"final","result":{"quality":{"ok":true},"summary":"s"}}
    """)
    #expect(ok.day == "2026-10-26" && ok.stage == .final && ok.result.quality.ok)
    #expect(ok.cycleId == "")                  // entries stored before cycles existed

    // Missing/unknown stage reads as daily; a missing or unreadable result is `unreadable`.
    let odd = try decodeFace(FaceScanEntry.self, #"{"day":"2026-10-27","stage":"weekly","result":"oops"}"#)
    #expect(odd.stage == .daily)
    #expect(odd.result == .unreadable)
    let empty = try decodeFace(FaceScanEntry.self, "{}")
    #expect(empty.day == "" && empty.stage == .daily && empty.result == .unreadable && empty.cycleId == "")

    // The cycle id round-trips, and a wrong-typed one reads as "".
    let cycle = FaceScanEntry(day: "2026-10-26", stage: .baseline, result: .unreadable, cycleId: "c-1")
    let data = try JSONCoding.encoder.encode(cycle)
    #expect(try JSONCoding.decode(FaceScanEntry.self, from: data) == cycle)
    #expect(try decodeFace(FaceScanEntry.self, #"{"cycleId":42}"#).cycleId == "")
}

@Test func faceNamesCarryWireKeysAndUserFacingLabels() {
    #expect(FaceZone.allCases.map(\.rawValue) == ["forehead", "nose", "left_cheek", "right_cheek", "chin"])
    #expect(FaceZone.allCases.map(\.label) == ["Forehead", "Nose & T-zone", "Left cheek", "Right cheek", "Chin"])
    #expect(FaceMetric.allCases.map(\.rawValue) == ["redness", "shine", "raised_blemishes", "flat_marks", "texture"])
    #expect(FaceMetric.allCases.map(\.label) == ["Redness", "Shine", "Raised blemishes", "Flat marks", "Texture"])
    #expect(FaceScanStage.allCases.map(\.rawValue) == ["baseline", "daily", "final", "report"])
    #expect(FaceReport.Barrier.lessSteady.rawValue == "less_steady")
}

@Test func faceScanLockedDefaultsToFalseAndDecodesTheFreeScan() throws {
    let old = try decodeFace(FaceScanResult.self, specExample)
    #expect(old.locked == false)
    let free = try decodeFace(FaceScanResult.self, """
    { "quality": { "ok": true, "issues": [] }, "locked": true, "summary": "Your face map is ready.",
      "zones": [ { "zone": "chin", "scores": {}, "regions": [], "note": null } ] }
    """)
    #expect(free.locked)
    #expect(free.zones.map(\.zone) == [.chin])
    #expect(free.zones.first?.scores.isEmpty == true)
    let round = try JSONCoding.decode(FaceScanResult.self, from: JSONCoding.encoder.encode(free))
    #expect(round.locked)
}
