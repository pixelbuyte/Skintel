import Foundation
import Observation
import SkintelCore

/// Journal entries (`/api/journal`, last 90 days) and the most recent AI analysis, shared
/// by the Journal and Culprits screens.
@MainActor
@Observable
final class JournalStore {
    private(set) var state: Loadable<[JournalEntry]> = .idle
    private(set) var analysis: Loadable<JournalAnalysis> = .idle
    private let api: SkintelAPI

    init(api: SkintelAPI) {
        self.api = api
    }

    var entries: [JournalEntry] { state.value ?? [] }

    func entry(on day: String) -> JournalEntry? { entries.first { $0.entryDate == day } }
    var today: JournalEntry? { entry(on: ISO8601.dayString(Date())) }

    func load() async {
        if state.value == nil { state = .loading }
        do { state = .loaded(try await api.journalEntries().sorted { $0.entryDate > $1.entryDate }) }
        catch let e as APIError { if state.value == nil { state = .failed(e) } }
        catch { if state.value == nil { state = .failed(.network(error.localizedDescription)) } }
    }

    func save(day: String, condition: JournalCondition, notes: String?) async throws {
        let saved = try await api.saveJournalEntry(entryDate: day, condition: condition, notes: notes, photoURL: nil)
        var list = entries.filter { $0.entryDate != day }
        list.append(saved)
        state = .loaded(list.sorted { $0.entryDate > $1.entryDate })
    }

    func delete(_ entry: JournalEntry) async throws {
        try await api.deleteJournalEntry(id: entry.id)
        state = .loaded(entries.filter { $0.id != entry.id })
    }

    func analyze() async {
        analysis = .loading
        do { analysis = .loaded(try await api.analyzeJournal()) }
        catch let e as APIError { analysis = .failed(e) }
        catch { analysis = .failed(.network(error.localizedDescription)) }
    }

    /// Consecutive logged days ending today or yesterday.
    var streak: Int {
        let days = Set(entries.map(\.entryDate))
        var count = 0
        var cursor = Date()
        let cal = Calendar.current
        if !days.contains(ISO8601.dayString(cursor)) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
            if !days.contains(ISO8601.dayString(cursor)) { return 0 }
        }
        while days.contains(ISO8601.dayString(cursor)) {
            count += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    /// The last seven days, oldest first, with whatever was logged.
    var week: [(date: Date, entry: JournalEntry?)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            return (d, entry(on: ISO8601.dayString(d)))
        }
    }

    func reset() {
        state = .idle
        analysis = .idle
    }
}

/// What she ticked as *actually used*, per UTC day key, on this phone only.
///
/// `/api/journal` has no usage field and this release adds no column, so the server
/// cannot carry this. The legacy `"Used: …"` notes line still travels cross-device and
/// still feeds the Pro reader, but it is display-only: it records the whole saved
/// routine rather than what was applied, which makes it over-inclusive on historical
/// days and gives it zero variance for a static routine — exactly the shape that makes
/// a correlation engine invent a guilty product. `JournalInsight` reads this file
/// instead.
///
/// A separate file from `routine.v1.json` on purpose: a decode failure in a map that
/// grows every day must not be able to destroy her routine.
@MainActor
@Observable
final class JournalUsageStore {
    /// Every field defaulted, so a payload written by an older or newer build still
    /// decodes into a usable value instead of dropping the whole store.
    struct Log: Codable, Sendable, Equatable {
        var days: [String: [String]] = [:]
    }

    /// Roughly four months. The engine never looks further back than 30 days, so this is
    /// generous; it exists to stop the file growing without bound.
    private static let maxDays = 120

    private(set) var log = Log()
    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Skintel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("journal-usage.v1.json")
        load()
    }

    /// `[]` both for "she ticked nothing" and for "there is no record". Callers that need
    /// to tell those apart read `log.days[day]` directly — priming the Today card does.
    func productIDs(on day: String) -> [String] { log.days[day] ?? [] }

    func set(_ productIDs: [String], on day: String) {
        var seen = Set<String>()
        log.days[day] = productIDs.filter { seen.insert($0).inserted }
        prune()
        persist()
    }

    /// The engine's input. Days with no ticks are dropped here rather than in the view,
    /// so an empty record never counts as an analysis day.
    var dayUsage: [JournalInsight.DayUsage] {
        log.days
            .filter { !$0.value.isEmpty }
            .map { JournalInsight.DayUsage(day: $0.key, productIDs: $0.value) }
            .sorted { $0.day < $1.day }
    }

    func reset() {
        log = Log()
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// ISO day keys sort chronologically, so "keep the newest 120" is a plain descending
    /// sort on the keys.
    private func prune() {
        guard log.days.count > Self.maxDays else { return }
        let keep = Set(log.days.keys.sorted(by: >).prefix(Self.maxDays))
        log.days = log.days.filter { keep.contains($0.key) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let l = try? JSONDecoder().decode(Log.self, from: data) else { return }
        log = l
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(log) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
