import Foundation

// Wire contract for Face Scan Pro: docs/face-scan-skin-1.0/PRO-SPEC.md §3 (`/api/face-scan`).
//
// Decoding is deliberately tolerant. These shapes come from a vision LLM behind a server that
// validates them, but a stored scan outlives the server version that wrote it, so:
//   - unknown keys are ignored (Codable does that by default; nothing here opts out),
//   - unknown zones and unknown metric keys are dropped, never fatal,
//   - a malformed region is dropped, the rest of its zone is kept,
//   - every field except a zone's `zone` is optional or defaulted (ios/Skintel/CLAUDE.md rule 3),
//   - scores are rounded and clamped to 0...100 on the way in, whatever the server sent.
//
// Every public name carries the `Face` prefix on purpose: bare `Region`, `Report` or `Quality`
// would shadow framework types (ios/Skintel/CLAUDE.md rule 1).

// MARK: - Zones and metrics

/// The five zones the on-device slicer crops. Raw values are the wire keys.
public enum FaceZone: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case forehead
    case nose
    case leftCheek = "left_cheek"
    case rightCheek = "right_cheek"
    case chin

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .forehead: "Forehead"
        case .nose: "Nose & T-zone"
        case .leftCheek: "Left cheek"
        case .rightCheek: "Right cheek"
        case .chin: "Chin"
        }
    }
}

/// The five 0-100 scores every zone carries. Higher means more of the thing. Raw values are the
/// wire keys. Wording stays cosmetic (PRO-SPEC §6).
public enum FaceMetric: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case redness
    case shine
    case raisedBlemishes = "raised_blemishes"
    case flatMarks = "flat_marks"
    case texture

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .redness: "Redness"
        case .shine: "Shine"
        case .raisedBlemishes: "Raised blemishes"
        case .flatMarks: "Flat marks"
        case .texture: "Texture"
        }
    }
}

/// Which read a request asks for. Raw values are the wire values of the request's `stage`.
public enum FaceScanStage: String, Codable, Sendable, Hashable, CaseIterable {
    /// Day 1 sweep.
    case baseline
    /// Days 2-6 single front photo.
    case daily
    /// Day 7 sweep.
    case final
    /// Day 7 synthesis (adds `report` and `routine`).
    case report
}

// MARK: - Quality

/// Whether the photo could be read. `issues` holds wire codes such as `too_dark`, `face_turned`,
/// `filter`, `blurry`, `multiple_faces`; they stay strings so a new server-side code is not fatal.
public struct FaceQuality: Codable, Sendable, Hashable {
    public var ok: Bool
    public var issues: [String]

    public init(ok: Bool, issues: [String] = []) {
        self.ok = ok
        self.issues = issues
    }

    enum CodingKeys: String, CodingKey { case ok, issues }

    /// A missing `ok` decodes as `false`: a read nobody vouched for is never counted.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.lenient(Bool.self, forKey: .ok) ?? false
        issues = c.lossyArray(String.self, forKey: .issues)
    }
}

// MARK: - Regions

/// An approximate highlight inside a zone crop (baseline and final reads only). `box` is
/// normalised `[x, y, w, h]` in the crop, each value clamped to 0...1. A vision model's boxes are
/// approximate: draw soft highlights and counts, never precise outlines (PRO-SPEC §3).
public struct FaceRegion: Codable, Sendable, Hashable {
    /// What a highlight marks, in cosmetic words (PRO-SPEC §6). Anything the server adds later
    /// reads as `.unknown`; the original string stays in `FaceRegion.kind`.
    public enum Kind: String, Codable, Sendable, Hashable, CaseIterable {
        case raisedBlemish = "raised_blemish"
        case cloggedPore = "clogged_pore"
        case redMark = "red_mark"
        case brownMark = "brown_mark"
        case unevenTexture = "uneven_texture"
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try? decoder.singleValueContainer().decode(String.self)
            self = raw.flatMap { Self(rawValue: $0.lowercased()) } ?? .unknown
        }

        public var label: String {
            switch self {
            case .raisedBlemish: "Raised blemish"
            case .cloggedPore: "Clogged pore"
            case .redMark: "Red mark"
            case .brownMark: "Brown mark"
            case .unevenTexture: "Uneven texture"
            case .unknown: "Area"
            }
        }
    }

    /// Wire kind such as `raised_blemish`, kept as the string the server sent so a new kind
    /// survives storage. Read it as an enum with `kindValue`.
    public let kind: String
    /// Exactly four numbers, each within 0...1.
    public let box: [Double]

    /// Nil when `box` is not exactly four finite numbers. Out-of-range values are clamped, not rejected.
    public init?(kind: String, box: [Double]) {
        guard box.count == 4, box.allSatisfy(\.isFinite) else { return nil }
        self.kind = kind
        self.box = box.map { min(max($0, 0), 1) }
    }

    public init?(kind: Kind, box: [Double]) {
        self.init(kind: kind.rawValue, box: box)
    }

    /// `kind` as an enum; `.unknown` for a kind this build does not know.
    public var kindValue: Kind { Kind(rawValue: kind.lowercased()) ?? .unknown }

    public var x: Double { box[0] }
    public var y: Double { box[1] }
    public var width: Double { box[2] }
    public var height: Double { box[3] }

    enum CodingKeys: String, CodingKey { case kind, box }

    /// Throws when `box` is missing or malformed; `FaceZoneResult` drops such regions and keeps the rest.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = c.lenient(String.self, forKey: .kind) ?? ""
        let box = try c.decode([Double].self, forKey: .box)
        guard let region = FaceRegion(kind: kind, box: box) else {
            throw DecodingError.dataCorruptedError(
                forKey: .box, in: c, debugDescription: "box must be exactly four finite numbers")
        }
        self = region
    }
}

// MARK: - Zone result

public struct FaceZoneResult: Codable, Sendable, Hashable, Identifiable {
    public let zone: FaceZone
    /// 0...100 per metric. A metric the server did not send is absent, never zero.
    public let scores: [FaceMetric: Int]
    public let regions: [FaceRegion]
    public let note: String?

    public var id: FaceZone { zone }

    /// Scores are clamped here too, so no `FaceZoneResult` can hold a value outside 0...100, and a
    /// blank `note` (empty or only whitespace) becomes nil so a screen never shows an empty line.
    public init(zone: FaceZone, scores: [FaceMetric: Int] = [:], regions: [FaceRegion] = [], note: String? = nil) {
        self.zone = zone
        self.scores = scores.mapValues { min(max($0, 0), 100) }
        self.regions = regions
        self.note = note.flatMap { $0.allSatisfy(\.isWhitespace) ? nil : $0 }
    }

    /// Rounds to the nearest integer (halves away from zero) and clamps to 0...100.
    /// Clamps before converting, so a huge value cannot trap `Int(_:)`.
    public static func clampScore(_ raw: Double) -> Int {
        guard raw.isFinite else { return raw > 0 ? 100 : 0 }
        return Int(min(max(raw.rounded(), 0), 100))
    }

    enum CodingKeys: String, CodingKey { case zone, scores, regions, note }

    /// Throws only when `zone` is missing or not one of the five known zones;
    /// `FaceScanResult` drops such zones and keeps the rest.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let zone = try c.decode(FaceZone.self, forKey: .zone)
        var scores: [FaceMetric: Int] = [:]
        // `[FaceMetric: Int]` would not decode from a JSON object (Swift only does that for
        // String/Int keys), so read string keys and map them. Unknown keys and non-numbers are dropped.
        let raw = (try? c.decode([String: Lossy<Double>].self, forKey: .scores)) ?? [:]
        for (key, box) in raw {
            guard let metric = FaceMetric(rawValue: key), let value = box.value, value.isFinite else { continue }
            scores[metric] = Self.clampScore(value)
        }
        self.init(zone: zone, scores: scores,
                  regions: c.lossyArray(FaceRegion.self, forKey: .regions),
                  note: c.lenient(String.self, forKey: .note))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(zone, forKey: .zone)
        var wire: [String: Int] = [:]
        for (metric, value) in scores { wire[metric.rawValue] = value }
        try c.encode(wire, forKey: .scores)
        try c.encode(regions, forKey: .regions)
        try c.encodeIfPresent(note, forKey: .note)
    }
}

// MARK: - Day 7 report and routine

/// The Day 7 synthesis (`stage: "report"`). Every word field falls back to `.unknown`; a report
/// from a newer server never fails to decode.
public struct FaceReport: Codable, Sendable, Hashable {
    /// Where shine sits. The wire values are `dry | normal | combination | oily`, and
    /// `FaceCalibration`'s Day 3 read returns this same type, so both screens share one vocabulary.
    /// "balanced" also decodes, as `.normal`.
    public enum OilPattern: String, Codable, Sendable, Hashable, CaseIterable {
        case oily, dry, combination, normal, unknown

        public init(from decoder: Decoder) throws {
            let raw = (try? decoder.singleValueContainer().decode(String.self))?.lowercased()
            self = raw.map { $0 == "balanced" ? "normal" : $0 }.flatMap { Self(rawValue: $0) } ?? .unknown
        }

        public var label: String {
            switch self {
            case .oily: "Oily"
            case .dry: "Dry"
            case .combination: "Combination"
            case .normal: "Balanced"
            case .unknown: "Not clear"
            }
        }
    }

    public enum Redness: String, Codable, Sendable, Hashable, CaseIterable {
        case steady, variable, unknown

        public init(from decoder: Decoder) throws {
            let raw = try? decoder.singleValueContainer().decode(String.self)
            self = raw.flatMap { Self(rawValue: $0.lowercased()) } ?? .unknown
        }

        public var label: String {
            switch self {
            case .steady: "Steady"
            case .variable: "Variable"
            case .unknown: "Not clear"
            }
        }
    }

    public enum Barrier: String, Codable, Sendable, Hashable, CaseIterable {
        case steady
        case lessSteady = "less_steady"
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try? decoder.singleValueContainer().decode(String.self)
            self = raw.flatMap { Self(rawValue: $0.lowercased()) } ?? .unknown
        }

        public var label: String {
            switch self {
            case .steady: "Looks steady"
            case .lessSteady: "Less steady"
            case .unknown: "Not clear"
            }
        }
    }

    public enum Marks: String, Codable, Sendable, Hashable, CaseIterable {
        case fading, steady, more, unknown

        public init(from decoder: Decoder) throws {
            let raw = try? decoder.singleValueContainer().decode(String.self)
            self = raw.flatMap { Self(rawValue: $0.lowercased()) } ?? .unknown
        }

        public var label: String {
            switch self {
            case .fading: "Fading"
            case .steady: "Steady"
            case .more: "More"
            case .unknown: "Not clear"
            }
        }
    }

    /// One over-the-counter cosmetic active from the server's allow-list, never prescription-only.
    public struct SuggestedActive: Codable, Sendable, Hashable {
        public var name: String
        public var why: String
        /// 1...7 when present.
        public var nightsPerWeek: Int?

        public init(name: String, why: String = "", nightsPerWeek: Int? = nil) {
            self.name = name
            self.why = why
            self.nightsPerWeek = nightsPerWeek.map { min(max($0, 1), 7) }
        }

        enum CodingKeys: String, CodingKey {
            case name, why
            case nightsPerWeek = "nights_per_week"
        }

        /// Throws when `name` is missing; `FaceReport` then treats the suggestion as absent.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let name = try c.decode(String.self, forKey: .name)
            let nights = c.lenient(Double.self, forKey: .nightsPerWeek)
                .flatMap { $0.isFinite ? Int(min(max($0.rounded(), 1), 7)) : nil }
            self.init(name: name, why: c.lenient(String.self, forKey: .why) ?? "", nightsPerWeek: nights)
        }
    }

    public var oilPattern: OilPattern
    public var redness: Redness
    public var barrier: Barrier
    public var marks: Marks
    public var suggestedActive: SuggestedActive?

    public init(oilPattern: OilPattern = .unknown, redness: Redness = .unknown, barrier: Barrier = .unknown,
                marks: Marks = .unknown, suggestedActive: SuggestedActive? = nil) {
        self.oilPattern = oilPattern
        self.redness = redness
        self.barrier = barrier
        self.marks = marks
        self.suggestedActive = suggestedActive
    }

    enum CodingKeys: String, CodingKey {
        case redness, barrier, marks
        case oilPattern = "oil_pattern"
        case suggestedActive = "suggested_active"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(oilPattern: c.lenient(OilPattern.self, forKey: .oilPattern) ?? .unknown,
                  redness: c.lenient(Redness.self, forKey: .redness) ?? .unknown,
                  barrier: c.lenient(Barrier.self, forKey: .barrier) ?? .unknown,
                  marks: c.lenient(Marks.self, forKey: .marks) ?? .unknown,
                  suggestedActive: c.lenient(SuggestedActive.self, forKey: .suggestedActive))
    }
}

/// The conflict-checked routine that comes with the Day 7 report. `conflicts` lists pairs the
/// server removed or spaced out, as plain sentences.
public struct FaceRoutine: Codable, Sendable, Hashable {
    /// One routine step on the wire: `{ "step": "Cleanser", "product": "…", "note": "…" }`.
    /// A plain string ("Cleanser") decodes too, as a step with no product and no note.
    public struct Step: Codable, Sendable, Hashable {
        public var step: String
        /// A product from the person's shelf; nil when the step is generic. Never empty.
        public var product: String?
        public var note: String

        /// A blank `product` (empty or only whitespace) becomes nil.
        public init(step: String, product: String? = nil, note: String = "") {
            self.step = step
            self.product = product.flatMap { $0.allSatisfy(\.isWhitespace) ? nil : $0 }
            self.note = note
        }

        enum CodingKeys: String, CodingKey { case step, product, note }

        /// Throws when there is no usable step text (a missing, non-string or blank `step`);
        /// `FaceRoutine` drops such steps and keeps the rest.
        public init(from decoder: Decoder) throws {
            let text: String
            var product: String?
            var note = ""
            if let plain = try? decoder.singleValueContainer().decode(String.self) {
                text = plain
            } else {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                text = try c.decode(String.self, forKey: .step)
                product = c.lenient(String.self, forKey: .product)
                note = c.lenient(String.self, forKey: .note) ?? ""
            }
            guard !text.allSatisfy(\.isWhitespace) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "a routine step needs text"))
            }
            self.init(step: text, product: product, note: note)
        }
    }

    public var am: [Step]
    public var pm: [Step]
    public var conflicts: [String]

    public init(am: [Step] = [], pm: [Step] = [], conflicts: [String] = []) {
        self.am = am
        self.pm = pm
        self.conflicts = conflicts
    }

    enum CodingKeys: String, CodingKey { case am, pm, conflicts }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(am: c.lossyArray(Step.self, forKey: .am),
                  pm: c.lossyArray(Step.self, forKey: .pm),
                  conflicts: c.lossyArray(String.self, forKey: .conflicts))
    }
}

// MARK: - Scan result

/// One decoded `/api/face-scan` response. Safe to persist: every field is defaulted, and what it
/// encodes decodes back to an equal value.
public struct FaceScanResult: Codable, Sendable, Hashable {
    /// Shown whenever the server sends none; a read is never presented without it.
    public static let defaultDisclaimer = "A cosmetic read of a photo, not a diagnosis."

    /// A read that never happened: not ok, no zones. What a damaged stored entry decodes to.
    public static let unreadable = FaceScanResult(quality: FaceQuality(ok: false))

    public var quality: FaceQuality
    public var zones: [FaceZoneResult]
    public var summary: String
    public var disclaimer: String
    public var report: FaceReport?
    public var routine: FaceRoutine?
    /// True for the one free scan a non-Pro account gets: `zones` lists only the areas with findings,
    /// with no scores or notes. The app shows the locked map and the paywall.
    public var locked: Bool

    public init(quality: FaceQuality, zones: [FaceZoneResult] = [], summary: String = "",
                disclaimer: String = FaceScanResult.defaultDisclaimer,
                report: FaceReport? = nil, routine: FaceRoutine? = nil, locked: Bool = false) {
        self.quality = quality
        self.zones = zones
        self.summary = summary
        self.disclaimer = disclaimer
        self.report = report
        self.routine = routine
        self.locked = locked
    }

    enum CodingKeys: String, CodingKey { case quality, zones, summary, disclaimer, report, routine, locked }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let disclaimer = c.lenient(String.self, forKey: .disclaimer)
        self.init(quality: c.lenient(FaceQuality.self, forKey: .quality) ?? FaceQuality(ok: false),
                  zones: c.lossyArray(FaceZoneResult.self, forKey: .zones),
                  summary: c.lenient(String.self, forKey: .summary) ?? "",
                  disclaimer: (disclaimer?.isEmpty == false ? disclaimer : nil) ?? Self.defaultDisclaimer,
                  report: c.lenient(FaceReport.self, forKey: .report),
                  routine: c.lenient(FaceRoutine.self, forKey: .routine),
                  locked: c.lenient(Bool.self, forKey: .locked) ?? false)
    }

    /// The first result for `zone`, or nil when the server did not send it.
    public func zone(_ zone: FaceZone) -> FaceZoneResult? {
        zones.first { $0.zone == zone }
    }

    /// One score, or nil when the zone or metric is absent.
    public func score(_ metric: FaceMetric, in zone: FaceZone) -> Int? {
        self.zone(zone)?.scores[metric]
    }
}

// MARK: - Tolerant decoding helpers

/// Decodes `T` or quietly holds nil. Because its `init(from:)` never throws, the unkeyed or keyed
/// container moves past a bad element instead of failing the whole collection.
private struct Lossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    /// The array under `key` with undecodable elements dropped; `[]` when absent or not an array.
    func lossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        guard let boxes = try? decode([Lossy<T>].self, forKey: key) else { return [] }
        return boxes.compactMap(\.value)
    }

    /// The value under `key`, or nil when absent, null or of the wrong type.
    func lenient<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }
}
