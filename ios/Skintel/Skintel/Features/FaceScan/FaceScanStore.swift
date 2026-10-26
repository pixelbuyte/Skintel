import Foundation
import Observation
import SkintelCore

/// Face scans kept on this device, in the shape of `ScanStore`: one JSON file in Application
/// Support, written atomically with complete file protection. Every persisted field decodes with
/// a default, so an older or damaged file never takes the history with it
/// (ios/Skintel/CLAUDE.md rule 3).
///
/// Day 1 zone crops live beside it in `FaceScanDay1/`, protected with `.complete` and excluded
/// from backup. They are sent again with the Day 7 crops and deleted when the cycle ends, the
/// scan is deleted, or `reset()` runs (PRO-SPEC §2).
@MainActor
@Observable
final class FaceScanStore {
    static let shared = FaceScanStore()

    struct Persisted: Codable, Sendable {
        var entries: [FaceScanEntry] = []
        var cycleId: String = ""
        /// `YYYY-MM-DD` of the cycle's first scan.
        var cycleStart: String = ""
        var answers: FaceAnswers?

        init() {}

        enum CodingKeys: String, CodingKey { case entries, cycleId, cycleStart, answers }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            entries = (try? c.decodeIfPresent([FaceScanEntry].self, forKey: .entries)) ?? []
            cycleId = (try? c.decodeIfPresent(String.self, forKey: .cycleId)) ?? ""
            cycleStart = (try? c.decodeIfPresent(String.self, forKey: .cycleStart)) ?? ""
            answers = try? c.decodeIfPresent(FaceAnswers.self, forKey: .answers)
        }
    }

    private(set) var data = Persisted()
    private let directory: URL
    private let fileURL: URL
    private let cropsURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Skintel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.directory = dir
        fileURL = dir.appendingPathComponent("facescan.v1.json")
        cropsURL = dir.appendingPathComponent("FaceScanDay1", isDirectory: true)
        load()
    }

    // MARK: Reading

    var entries: [FaceScanEntry] { data.entries }
    var cycleId: String { data.cycleId }
    var answers: FaceAnswers? { data.answers }
    var hasCycle: Bool { !data.cycleId.isEmpty }

    var calibration: FaceCalibration {
        FaceCalibration(entries: data.entries, cycleId: data.cycleId)
    }

    /// Day of the cycle (1-based) for `now`, from the cycle's first scan; 1 before any scan.
    func cycleDay(now: Date, timeZone: TimeZone = .autoupdatingCurrent) -> Int {
        let today = Streaks.dayKey(now, timeZone: timeZone)
        guard let start = Self.dayNumber(data.cycleStart), let current = Self.dayNumber(today) else { return 1 }
        return max(1, current - start + 1)
    }

    /// Days since 1970 for a `YYYY-MM-DD` key, read in UTC so the count is calendar-exact.
    static func dayNumber(_ key: String) -> Int? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        guard let date = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// The most recent counted scan that carries a routine.
    var latestRoutine: FaceRoutine? {
        if let r = calibration.latestReport?.routine { return r }
        return calibration.scans.reversed().first { $0.result.routine != nil }?.result.routine
    }

    // MARK: Writing

    /// Starts a new cycle, dropping the old cycle's Day 1 crops.
    func startCycle(now: Date, timeZone: TimeZone = .autoupdatingCurrent) {
        deleteDay1Crops()
        data.cycleId = UUID().uuidString.lowercased()
        data.cycleStart = Streaks.dayKey(now, timeZone: timeZone)
        persist()
    }

    func saveAnswers(_ answers: FaceAnswers) {
        data.answers = answers
        persist()
    }

    func record(stage: FaceScanStage, result: FaceScanResult, now: Date, timeZone: TimeZone = .autoupdatingCurrent) {
        let entry = FaceScanEntry(day: Streaks.dayKey(now, timeZone: timeZone), stage: stage, result: result,
                                  cycleId: data.cycleId)
        data.entries.append(entry)
        persist()
        if stage == .report && result.quality.ok { deleteDay1Crops() }
    }

    /// Deletes every scan, the answers and the Day 1 crops.
    func reset() {
        data = Persisted()
        try? FileManager.default.removeItem(at: fileURL)
        deleteDay1Crops()
    }

    // MARK: Day 1 crops

    func saveDay1Crops(_ crops: [FaceZone: Data]) {
        let fm = FileManager.default
        try? fm.createDirectory(at: cropsURL, withIntermediateDirectories: true,
                                attributes: [.protectionKey: FileProtectionType.complete])
        excludeFromBackup(cropsURL)
        for (zone, jpeg) in crops {
            let url = cropsURL.appendingPathComponent("\(zone.rawValue).jpg")
            try? jpeg.write(to: url, options: [.atomic, .completeFileProtection])
            excludeFromBackup(url)
        }
    }

    func day1Crops() -> [FaceZone: Data] {
        var out: [FaceZone: Data] = [:]
        for zone in FaceZone.allCases {
            let url = cropsURL.appendingPathComponent("\(zone.rawValue).jpg")
            if let d = try? Data(contentsOf: url) { out[zone] = d }
        }
        return out
    }

    func deleteDay1Crops() {
        try? FileManager.default.removeItem(at: cropsURL)
    }

    private func excludeFromBackup(_ url: URL) {
        var u = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? u.setResourceValues(values)
    }

    // MARK: File

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Persisted.self, from: raw) else { return }
        data = decoded
    }

    private func persist() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
