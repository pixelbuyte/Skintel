import Foundation
import Observation
import SkintelCore

/// AM/PM routine as ordered product ids, persisted on device exactly like the web's
/// `localStorage['skintel:routine:v1']` (`{am, pm, name, savedAt}`). Conflicts come from
/// `POST /api/analyze-routine`; nothing is inferred locally.
@MainActor
@Observable
final class RoutineStore {
    struct Routine: Codable, Sendable, Equatable {
        var am: [String] = []
        var pm: [String] = []
        var name: String? = nil
        var savedAt: Date? = nil
        /// Product ids ticked off today, reset when the day changes.
        var doneToday: [String] = []
        var doneDay: String? = nil
        /// Day (`YYYY-MM-DD`, UTC like `doneDay`) → slots whose every step was ticked that day.
        /// Optional so routines saved before this field existed still decode.
        var completed: [String: [String]]? = nil
    }

    enum Slot: String, CaseIterable, Identifiable, Sendable {
        case am = "AM", pm = "PM"
        var id: String { rawValue }
    }

    private(set) var routine = Routine()
    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Skintel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("routine.v1.json")
        load()
        rollDayIfNeeded()
    }

    func ids(_ slot: Slot) -> [String] { slot == .am ? routine.am : routine.pm }

    func set(_ ids: [String], for slot: Slot) {
        if slot == .am { routine.am = ids } else { routine.pm = ids }
        routine.savedAt = Date()
        persist()
    }

    func add(_ productID: String, to slot: Slot) {
        var list = ids(slot)
        guard !list.contains(productID) else { return }
        list.append(productID)
        set(list, for: slot)
    }

    func remove(_ productID: String, from slot: Slot) {
        set(ids(slot).filter { $0 != productID }, for: slot)
    }

    func move(from source: IndexSet, to destination: Int, in slot: Slot) {
        var list = ids(slot)
        list.move(fromOffsets: source, toOffset: destination)
        set(list, for: slot)
    }

    func isDone(_ productID: String) -> Bool { routine.doneToday.contains(productID) }

    /// Pass `slot` when the tick belongs to a specific routine, so the day is recorded as
    /// completed (or un-completed) for that slot.
    func toggleDone(_ productID: String, in slot: Slot? = nil) {
        rollDayIfNeeded()
        if let i = routine.doneToday.firstIndex(of: productID) { routine.doneToday.remove(at: i) }
        else { routine.doneToday.append(productID) }
        persist()
        if let slot { recordCompletion(slot) }
    }

    func markAllDone(_ slot: Slot) {
        rollDayIfNeeded()
        for id in ids(slot) where !routine.doneToday.contains(id) { routine.doneToday.append(id) }
        persist()
        recordCompletion(slot)
    }

    /// Days out of the last `days` (today included) on which every step of `slot` was ticked.
    func daysCompleted(_ slot: Slot, lastDays days: Int = 7) -> Int {
        let log = routine.completed ?? [:]
        var count = 0
        for offset in 0..<days {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            if (log[ISO8601.dayString(day)] ?? []).contains(slot.rawValue) { count += 1 }
        }
        return count
    }

    /// Progress for the Home card ("2/5") for the slot that is current right now.
    func progress(for slot: Slot) -> (done: Int, total: Int) {
        let list = ids(slot)
        return (list.filter(isDone).count, list.count)
    }

    static func currentSlot(now: Date = Date()) -> Slot {
        Calendar.current.component(.hour, from: now) < 15 ? .am : .pm
    }

    func reset() {
        routine = Routine()
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func recordCompletion(_ slot: Slot) {
        let today = ISO8601.dayString(Date())
        let list = ids(slot)
        var log = routine.completed ?? [:]
        var slots = Set(log[today] ?? [])
        if !list.isEmpty && list.allSatisfy(isDone) { slots.insert(slot.rawValue) } else { slots.remove(slot.rawValue) }
        log[today] = slots.isEmpty ? nil : slots.sorted()
        // Keep about four months; day strings sort lexicographically.
        if let cutoff = Calendar.current.date(byAdding: .day, value: -120, to: Date()) {
            let oldest = ISO8601.dayString(cutoff)
            log = log.filter { $0.key >= oldest }
        }
        routine.completed = log
        persist()
    }

    private func rollDayIfNeeded() {
        let today = ISO8601.dayString(Date())
        if routine.doneDay != today {
            routine.doneDay = today
            routine.doneToday = []
            persist()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let r = try? JSONDecoder().decode(Routine.self, from: data) else { return }
        routine = r
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(routine) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
