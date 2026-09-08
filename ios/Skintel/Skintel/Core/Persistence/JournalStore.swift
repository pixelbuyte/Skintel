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
