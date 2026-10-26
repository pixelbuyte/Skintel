import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SkintelCore

// Face Scan Pro request side (PRO-SPEC §3): encoding, limits, validation.

private func encoded<T: Encodable>(_ value: T) throws -> String {
    String(decoding: try JSONCoding.encoder.encode(value), as: UTF8.self)
}

private func b64(_ count: Int) -> String { String(repeating: "A", count: count) }

private func views(_ n: Int, size: Int = 1_000) -> [FaceScanImage] {
    let roles: [FaceScanImage.Role] = [.front, .left45, .right45]
    return (0..<n).map { FaceScanImage(role: roles[$0 % 3], base64: b64(size)) }
}

private func zones(_ n: Int, from: String? = nil, size: Int = 1_000) -> [FaceScanImage] {
    (0..<n).map { FaceScanImage(role: .zone, zone: FaceZone.allCases[$0 % 5], from: from, base64: b64(size)) }
}

// MARK: - Encoding

@Test func faceScanRequestEncodesTheWireShape() throws {
    let req = FaceScanRequest(stage: .daily, cycleId: "c1", day: 3,
                              images: [FaceScanImage(role: .front, base64: "AAAA")], answers: FaceAnswers())
    #expect(try encoded(req) ==
        #"{"answers":{"locks":[]},"cycleId":"c1","day":3,"images":[{"base64":"AAAA","mimeType":"image\/jpeg","role":"front"}],"stage":"daily"}"#)
}

@Test func faceAnswersAlwaysEncodeLocksEvenWhenThereAreNone() throws {
    #expect(try encoded(FaceAnswers()) == #"{"locks":[]}"#)
    #expect(try encoded(FaceAnswers(locks: [.pregnantOrTrying, .breastfeeding, .skinMedicine]))
            == #"{"locks":["pregnant_or_trying","breastfeeding","skin_medicine"]}"#)
    let full = FaceAnswers(locks: [.skinMedicine], chips: ["q3": ["retinol", "vitamin_c"]], notes: ["q3": "twice a week"])
    #expect(try encoded(full) == #"{"chips":{"q3":["retinol","vitamin_c"]},"locks":["skin_medicine"],"notes":{"q3":"twice a week"}}"#)
    // Without answers the key is simply absent; with them, locks is always inside.
    let noAnswers = try encoded(FaceScanRequest(stage: .report, cycleId: "c", day: 7))
    #expect(!noAnswers.contains("answers"))
}

@Test func faceScanImageEncodesZoneAndFromOnlyWhenSet() throws {
    let crop = FaceScanImage(role: .zone, zone: .leftCheek, from: FaceScanImage.day1, base64: "QQ==", mimeType: "image/png")
    #expect(try encoded(crop) == #"{"base64":"QQ==","from":"day1","mimeType":"image\/png","role":"zone","zone":"left_cheek"}"#)
    let view = FaceScanImage(role: .right45, base64: "QQ==")
    let text = try encoded(view)
    #expect(text == #"{"base64":"QQ==","mimeType":"image\/jpeg","role":"right45"}"#)
    #expect(FaceScanImage.Role.allCases.map(\.rawValue) == ["front", "left45", "right45", "zone"])
}

@Test func faceScanRequestCarriesTheLooselyTypedExtras() throws {
    let req = FaceScanRequest(stage: .report, cycleId: "c9", day: 7,
                              history: [.object(["day": .number(1), "redness": .number(30)])],
                              profile: ["skinType": .string("combination")],
                              shelf: [.string("CeraVe Foaming Cleanser")],
                              triggers: [.string("fragrance")])
    let text = try encoded(req)
    #expect(text.contains(#""history":[{"day":1,"redness":30}]"#))
    #expect(text.contains(#""profile":{"skinType":"combination"}"#))
    #expect(text.contains(#""shelf":["CeraVe Foaming Cleanser"]"#))
    #expect(text.contains(#""triggers":["fragrance"]"#))
    #expect(text.contains(#""images":[]"#))
    #expect(text.contains(#""stage":"report""#))
    #expect(try JSONCoding.decode(FaceScanRequest.self, from: JSONCoding.encoder.encode(req)) == req)
}

@Test func faceAnswersDecodeTolerantlyAndDropLocksThisBuildDoesNotKnow() throws {
    func decodeAnswers(_ json: String) throws -> FaceAnswers { try JSONCoding.decode(FaceAnswers.self, from: Data(json.utf8)) }
    #expect(try decodeAnswers("{}") == FaceAnswers())
    #expect(try decodeAnswers(#"{"locks":["breastfeeding","from_the_future","skin_medicine"]}"#).locks == [.breastfeeding, .skinMedicine])
    #expect(try decodeAnswers(#"{"locks":"nope","chips":[1],"notes":7}"#) == FaceAnswers())
    let full = FaceAnswers(locks: [.pregnantOrTrying], chips: ["q1": ["tight"]], notes: ["q19": "dry in winter"])
    #expect(try decodeAnswers(encoded(full)) == full)
}

// MARK: - Limits and validation

@Test func faceScanLimitsArePinned() {
    #expect(FaceScanLimits.maxViewBase64 == 540_000)
    #expect(FaceScanLimits.maxZoneBase64 == 180_000)
    #expect(FaceScanLimits.maxTotalBase64 == 3_500_000)
    #expect(FaceScanStage.allCases.map(FaceScanLimits.maxImages(for:)) == [8, 1, 13, 0])   // baseline, daily, final, report
    #expect(FaceScanLimits.maxBase64(for: .front) == 540_000 && FaceScanLimits.maxBase64(for: .zone) == 180_000)
}

@Test func validRequestsPassForEveryStage() {
    #expect(FaceScanRequest(stage: .daily, cycleId: "c", day: 3, images: views(1)).validate() == nil)
    #expect(FaceScanRequest(stage: .baseline, cycleId: "c", day: 1, images: views(3) + zones(5)).validate() == nil)
    let final = FaceScanRequest(stage: .final, cycleId: "c", day: 7,
                                images: views(3) + zones(5) + zones(5, from: FaceScanImage.day1))
    #expect(final.images.count == 13)
    #expect(final.validate() == nil)
    #expect(FaceScanRequest(stage: .report, cycleId: "c", day: 7).validate() == nil)
    // Days 1 and 31 are the edges.
    #expect(FaceScanRequest(stage: .report, cycleId: "c", day: 1).validate() == nil)
    #expect(FaceScanRequest(stage: .report, cycleId: "c", day: 31).validate() == nil)
}

@Test func validateCatchesTooManyImagesForTheStage() throws {
    let daily = try #require(FaceScanRequest(stage: .daily, cycleId: "c", day: 2, images: views(2)).validate())
    #expect(daily.contains("at most 1") && daily.contains("daily"))
    #expect(FaceScanRequest(stage: .baseline, cycleId: "c", day: 1, images: views(3) + zones(6)).validate()?.contains("at most 8") == true)
    #expect(FaceScanRequest(stage: .final, cycleId: "c", day: 7, images: views(3) + zones(11)).validate()?.contains("at most 13") == true)
    #expect(FaceScanRequest(stage: .report, cycleId: "c", day: 7, images: views(1)).validate()?.contains("at most 0") == true)
}

@Test func validateCatchesATotalOverTheLimit() throws {
    // Eight front views: the count is allowed and each is under the per-view limit, but together
    // they are 4,000,000 characters against a 3,500,000 limit.
    let big = (0..<8).map { _ in FaceScanImage(role: .front, base64: b64(500_000)) }
    let req = FaceScanRequest(stage: .baseline, cycleId: "c", day: 1, images: big)
    let reason = try #require(req.validate())
    #expect(reason.contains("total") && reason.contains("3500000"))
    // Just under it passes: seven of the same.
    #expect(FaceScanRequest(stage: .baseline, cycleId: "c", day: 1, images: Array(big.prefix(7))).validate() == nil)
}

@Test func validateCatchesAnImageOverItsOwnLimit() throws {
    #expect(FaceScanRequest(stage: .daily, cycleId: "c", day: 2, images: [FaceScanImage(role: .front, base64: b64(540_000))]).validate() == nil)
    let view = try #require(FaceScanRequest(stage: .daily, cycleId: "c", day: 2,
                                            images: [FaceScanImage(role: .front, base64: b64(540_001))]).validate())
    #expect(view.contains("front") && view.contains("540000"))
    let crop = FaceScanImage(role: .zone, zone: .chin, base64: b64(180_000))
    #expect(FaceScanRequest(stage: .baseline, cycleId: "c", day: 1, images: [crop]).validate() == nil)
    let tooBig = FaceScanImage(role: .zone, zone: .chin, base64: b64(180_001))
    #expect(FaceScanRequest(stage: .baseline, cycleId: "c", day: 1, images: [tooBig]).validate()?.contains("180000") == true)
}

@Test func validateCatchesFromOnANonFinalStageAndBadFromValues() throws {
    let day1Crop = zones(1, from: FaceScanImage.day1)
    for stage in [FaceScanStage.baseline, .daily] {
        let reason = try #require(FaceScanRequest(stage: stage, cycleId: "c", day: 2, images: day1Crop).validate())
        #expect(reason.contains("final"), "\(stage)")
    }
    #expect(FaceScanRequest(stage: .final, cycleId: "c", day: 7, images: day1Crop).validate() == nil)
    let wrong = zones(1, from: "day2")
    #expect(FaceScanRequest(stage: .final, cycleId: "c", day: 7, images: wrong).validate()?.contains("day1") == true)
}

@Test func validateCatchesAZoneCropWithoutAZoneAndABadDay() {
    let noZone = FaceScanImage(role: .zone, base64: b64(100))
    #expect(FaceScanRequest(stage: .baseline, cycleId: "c", day: 1, images: [noZone]).validate()?.contains("no zone") == true)
    #expect(FaceScanRequest(stage: .daily, cycleId: "c", day: 0, images: views(1)).validate()?.contains("1 to 31") == true)
    #expect(FaceScanRequest(stage: .daily, cycleId: "c", day: 32, images: views(1)).validate() != nil)
    #expect(FaceScanRequest(stage: .daily, cycleId: "c", day: -4, images: views(1)).validate() != nil)
}
