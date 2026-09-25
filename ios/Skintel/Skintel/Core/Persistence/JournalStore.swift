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

    /// Optimistic: the entry shows immediately and the network catches up. A failure puts
    /// the previous list back; only the newest of several quick taps may write the result.
    func save(day: String, condition: JournalCondition, notes: String?) async throws {
        let previous = state
        let old = entry(on: day)
        let draft = JournalEntry(id: old?.id ?? "pending-\(day)", userID: old?.userID ?? "", entryDate: day,
                                 condition: condition, notes: notes, photoURL: old?.photoURL,
                                 createdAt: old?.createdAt ?? ISO8601DateFormatter().string(from: Date()))
        replace(day: day, with: draft)
        saveGeneration += 1
        let generation = saveGeneration
        do {
            let saved = try await api.saveJournalEntry(entryDate: day, condition: condition, notes: notes, photoURL: nil)
            if generation == saveGeneration { replace(day: day, with: saved) }
        } catch {
            if generation == saveGeneration { state = previous }
            throw error
        }
    }

    private var saveGeneration = 0

    private func replace(day: String, with entry: JournalEntry) {
        var list = entries.filter { $0.entryDate != day }
        list.append(entry)
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

    /// Current and best check-in streak from the loaded entries (see `Streaks`). The API
    /// returns the latest `entryLimit` entries, so older history can't count toward `best`.
    func streaks(now: Date = Date()) -> Streaks {
        Streaks(days: entries.map(\.entryDate), now: now)
    }

    /// `/api/journal` returns at most this many entries (newest first).
    static let entryLimit = 90

    /// True when the list may be cut off by `entryLimit`, so totals should read "90+".
    var mayHaveOlderEntries: Bool { entries.count >= Self.entryLimit }

    /// Consecutive logged days ending today or yesterday.
    var streak: Int { streaks().current }

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
