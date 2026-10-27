import Foundation

// Request side of the Face Scan Pro wire contract: docs/face-scan-skin-1.0/PRO-SPEC.md §3,
// `POST /api/face-scan`. The response side (`FaceScanResult`) lives in Models/FaceScan.swift.
//
// These types pin the request shape and its size limits on the device, so a request the server
// would refuse (too many images, too many bytes, a Day 1 crop on the wrong stage) is caught
// before a megabyte of base64 goes over the network.

// MARK: - Answers

/// A hard lock from Q5. The server removes ingredients from the suggestion list before the model
/// sees it (PRO-SPEC §3): retinoids and strong salicylic acid for the first two, a gentle routine
/// plus "check with your doctor" for the third.
public enum FaceLock: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case pregnantOrTrying = "pregnant_or_trying"
    case breastfeeding
    case skinMedicine = "skin_medicine"

    public var id: String { rawValue }
}

/// The questionnaire answers a request carries. `locks` is always sent, as `[]` when there are
/// none, so the server can tell "no locks" from "locks not collected". `chips` and `notes` are
/// keyed by question id (`q1` … `q19`) and left out when nil.
///
/// Decoding is tolerant (this is stored with the cycle): everything is defaulted, and a lock
/// value this build does not know is dropped, since this build could not honour it anyway.
public struct FaceAnswers: Codable, Sendable, Hashable {
    public var locks: [FaceLock]
    public var chips: [String: [String]]?
    public var notes: [String: String]?

    public init(locks: [FaceLock] = [], chips: [String: [String]]? = nil, notes: [String: String]? = nil) {
        self.locks = locks
        self.chips = chips
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey { case locks, chips, notes }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = (try? c.decode([String].self, forKey: .locks)) ?? []
        self.init(locks: raw.compactMap(FaceLock.init(rawValue:)),
                  chips: try? c.decodeIfPresent([String: [String]].self, forKey: .chips),
                  notes: try? c.decodeIfPresent([String: String].self, forKey: .notes))
    }
}

/// What the person wants from their skin, asked in the questions (multi-select). Stored in
/// `FaceAnswers.chips[FaceGoal.chipKey]` as the chip labels, like every other chip answer, so the
/// report model reads plain words.
public enum FaceGoal: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case lessShine = "less_shine"
    case fewerBreakouts = "fewer_breakouts"
    case fadeMarks = "fade_marks"
    case calmerRedness = "calmer_redness"
    case smootherTexture = "smoother_texture"
    case smallerPores = "smaller_pores"
    case moreGlow = "more_glow"
    case simplerRoutine = "simpler_routine"
    case justCurious = "just_curious"

    public static let chipKey = "goals"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .lessShine: "Less shine"
        case .fewerBreakouts: "Fewer breakouts"
        case .fadeMarks: "Fade marks"
        case .calmerRedness: "Calmer redness"
        case .smootherTexture: "Smoother texture"
        case .smallerPores: "Smaller-looking pores"
        case .moreGlow: "More glow"
        case .simplerRoutine: "A simpler routine"
        case .justCurious: "Just curious"
        }
    }

    /// The question put in Ask's composer for this goal.
    public var askPrompt: String {
        switch self {
        case .lessShine: "How do I get less shine, going by my face scan?"
        case .fewerBreakouts: "What would help with breakouts, going by my face scan?"
        case .fadeMarks: "How can I help my marks fade, going by my face scan?"
        case .calmerRedness: "How do I calm the redness my face scan shows?"
        case .smootherTexture: "How do I get smoother texture, going by my face scan?"
        case .smallerPores: "How can my pores look smaller, going by my face scan?"
        case .moreGlow: "How do I get more glow, going by my face scan?"
        case .simplerRoutine: "What is the simplest routine for the skin my face scan shows?"
        case .justCurious: Self.defaultAskPrompt
        }
    }

    /// The metric a goal is about, so a screen can point at the zone that matters; nil for goals
    /// that are not about one metric.
    public var metric: FaceMetric? {
        switch self {
        case .lessShine, .smallerPores: .shine
        case .fewerBreakouts: .raisedBlemishes
        case .fadeMarks: .flatMarks
        case .calmerRedness: .redness
        case .smootherTexture: .texture
        case .moreGlow, .simplerRoutine, .justCurious: nil
        }
    }

    public static let defaultAskPrompt = "What stands out in my face scan, and what should I do about it?"

    /// The goals in `answers`, in the order picked. Reads labels and raw values alike.
    public static func goals(in answers: FaceAnswers?) -> [FaceGoal] {
        let picked = answers?.chips?[chipKey] ?? []
        var out: [FaceGoal] = []
        for value in picked {
            guard let goal = allCases.first(where: { $0.label == value || $0.rawValue == value }),
                  !out.contains(goal) else { continue }
            out.append(goal)
        }
        return out
    }

    /// What Ask opens with after a face scan: the first goal's question, or the general one.
    public static func askPrompt(for goals: [FaceGoal]) -> String {
        goals.first?.askPrompt ?? defaultAskPrompt
    }
}

// MARK: - Images

/// One photo in a request. `base64` is the JPEG bytes without a data-URL prefix.
public struct FaceScanImage: Codable, Sendable, Hashable {
    public enum Role: String, Codable, Sendable, Hashable, CaseIterable {
        /// Centre view, 0°.
        case front
        /// Left 45° view.
        case left45
        /// Right 45° view.
        case right45
        /// One of the five zone crops; `zone` says which.
        case zone
    }

    /// The only `from` value: a Day 1 crop re-sent with the Day 7 final read, so the server can
    /// compare the two. Valid on `.final` requests only.
    public static let day1 = "day1"

    public var role: Role
    /// Set when `role == .zone`.
    public var zone: FaceZone?
    /// Nil for a fresh photo, `FaceScanImage.day1` for a stored Day 1 crop.
    public var from: String?
    public var base64: String
    public var mimeType: String

    public init(role: Role, zone: FaceZone? = nil, from: String? = nil, base64: String, mimeType: String = "image/jpeg") {
        self.role = role
        self.zone = zone
        self.from = from
        self.base64 = base64
        self.mimeType = mimeType
    }

    /// Size of the encoded image as sent. Base64 is ASCII, so characters are bytes.
    var encodedSize: Int { base64.utf8.count }
}

/// The size and count limits a request must stay inside. The totals are base64 characters, which
/// are bytes on the wire.
public enum FaceScanLimits {
    /// A front, left 45° or right 45° view.
    public static let maxViewBase64 = 540_000
    /// A zone crop, fresh or from Day 1.
    public static let maxZoneBase64 = 180_000
    /// Every image in the request together.
    public static let maxTotalBase64 = 3_500_000
    /// Valid `FaceScanRequest.day` values.
    public static let cycleDays = 1...31

    /// Daily: one front photo. Baseline: three views and five zone crops. Final: those eight plus
    /// the five Day 1 crops. Report: no images, the server works from history.
    public static func maxImages(for stage: FaceScanStage) -> Int {
        switch stage {
        case .daily: 1
        case .baseline: 8
        case .final: 13
        case .report: 0
        }
    }

    /// The per-image limit for a role.
    public static func maxBase64(for role: FaceScanImage.Role) -> Int {
        role == .zone ? maxZoneBase64 : maxViewBase64
    }
}

// MARK: - Request

/// The body of `POST /api/face-scan`. Keys are camelCase on the wire, as the contract has them.
/// `history`, `profile`, `shelf` and `triggers` are loosely typed on purpose: the server owns
/// their shape, and they are left out when nil.
public struct FaceScanRequest: Codable, Sendable, Hashable {
    public var stage: FaceScanStage
    public var cycleId: String
    /// Day of the cycle, 1 to 31.
    public var day: Int
    public var images: [FaceScanImage]
    public var answers: FaceAnswers?
    /// Earlier daily results, for the report stage.
    public var history: [JSONValue]?
    public var profile: [String: JSONValue]?
    public var shelf: [JSONValue]?
    public var triggers: [JSONValue]?

    public init(stage: FaceScanStage, cycleId: String, day: Int, images: [FaceScanImage] = [],
                answers: FaceAnswers? = nil, history: [JSONValue]? = nil, profile: [String: JSONValue]? = nil,
                shelf: [JSONValue]? = nil, triggers: [JSONValue]? = nil) {
        self.stage = stage
        self.cycleId = cycleId
        self.day = day
        self.images = images
        self.answers = answers
        self.history = history
        self.profile = profile
        self.shelf = shelf
        self.triggers = triggers
    }

    /// Why the server would refuse this request, or nil when it fits the contract. The first
    /// problem found, in plain words. Checks the day, the image count for the stage, each image
    /// (zone crops need a zone; `from` is only `"day1"` and only on a final read; size), and the
    /// total size.
    public func validate() -> String? {
        if !FaceScanLimits.cycleDays.contains(day) {
            return "The cycle day must be from 1 to 31 (got \(day))."
        }
        let maxImages = FaceScanLimits.maxImages(for: stage)
        if images.count > maxImages {
            return "A \(stage.rawValue) scan takes at most \(maxImages) images (got \(images.count))."
        }
        var total = 0
        for (offset, image) in images.enumerated() {
            let n = offset + 1
            if image.role == .zone && image.zone == nil {
                return "Image \(n) is a zone crop with no zone."
            }
            if let from = image.from {
                if stage != .final {
                    return "Image \(n) has \"from\", which only a final scan may use (this is a \(stage.rawValue) scan)."
                }
                if from != FaceScanImage.day1 {
                    return "Image \(n) has from \"\(from)\"; the only value is \"\(FaceScanImage.day1)\"."
                }
            }
            let limit = FaceScanLimits.maxBase64(for: image.role)
            if image.encodedSize > limit {
                return "Image \(n) (\(image.role.rawValue)) is \(image.encodedSize) characters of base64; the limit is \(limit)."
            }
            total += image.encodedSize
        }
        if total > FaceScanLimits.maxTotalBase64 {
            return "The images total \(total) characters of base64; the limit is \(FaceScanLimits.maxTotalBase64)."
        }
        return nil
    }
}
