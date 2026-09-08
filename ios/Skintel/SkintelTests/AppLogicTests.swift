import Foundation
import Testing
import SkintelCore
@testable import Skintel

// App-layer logic that does not need a device: routing, on-device stores, templates.

private func tempDir() -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent("skintel-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

private func user(onboarded: Bool) -> AuthUser {
    AuthUser(id: "u", email: "a@b.c", userMetadata: ["onboarding_complete": .bool(onboarded)])
}

private func session(onboarded: Bool) -> Session {
    Session(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(3600), user: user(onboarded: onboarded))
}

@Test func routerNeverShowsSignInWhileRestoring() {
    #expect(AppRoute.resolve(.restoring, onboardingSkippedLocally: false) == .launching)
    #expect(AppRoute.resolve(.signedOut, onboardingSkippedLocally: true) == .signedOut)
    #expect(AppRoute.resolve(.signedIn(session(onboarded: false)), onboardingSkippedLocally: false) == .onboarding)
    #expect(AppRoute.resolve(.signedIn(session(onboarded: false)), onboardingSkippedLocally: true) == .main)
    #expect(AppRoute.resolve(.signedIn(session(onboarded: true)), onboardingSkippedLocally: false) == .main)
}

@MainActor
@Test func routineStorePersistsOrderAndRollsDoneStateDaily() {
    let dir = tempDir()
    let store = RoutineStore(directory: dir)
    store.add("a", to: .pm); store.add("b", to: .pm); store.add("a", to: .pm)   // duplicate ignored
    #expect(store.ids(.pm) == ["a", "b"])
    store.move(from: IndexSet(integer: 1), to: 0, in: .pm)
    #expect(store.ids(.pm) == ["b", "a"])
    store.toggleDone("a")
    #expect(store.isDone("a"))
    #expect(store.progress(for: .pm).done == 1 && store.progress(for: .pm).total == 2)

    let reloaded = RoutineStore(directory: dir)
    #expect(reloaded.ids(.pm) == ["b", "a"])
    #expect(reloaded.isDone("a"))   // same day → still done
    reloaded.remove("b", from: .pm)
    #expect(reloaded.ids(.pm) == ["a"])
}

@MainActor
@Test func scanStoreReKeysUnsavedScanOntoProduct() {
    let store = ScanStore(directory: tempDir())
    let result = ScanResult(verdict: .clean, score: 82, summary: "ok", flags: [], notes: nil)
    let s = store.record(productID: nil, brand: "CeraVe", productName: "Cleanser", inci: "Aqua, Glycerin", source: "paste", result: result)
    #expect(store.score(for: "p1") == nil)
    store.attach(scanID: s.id, to: "p1")
    #expect(store.score(for: "p1") == 82)
    #expect(store.scans[s.id] == nil)
    store.remove(productID: "p1")
    #expect(store.recent.isEmpty)
}

@Test func routineTemplateFillsByCategoryWithoutReusingAProduct() {
    func p(_ id: String, _ name: String, _ cat: String?) -> ProductWithIngredients {
        ProductWithIngredients(product: Product(id: id, userID: "u", brand: nil, productName: name, category: cat, outcome: .good,
                                                notes: nil, createdAt: "", updatedAt: ""), ingredients: [])
    }
    let shelf = [p("1", "Gel Cleanser", "Cleanser"), p("2", "Daily Moisturizer", "Moisturizer"), p("3", "Retinol Serum", "Serum")]
    let t = RoutineTemplate.all.first { $0.id == "antiaging" }!
    // am: cleanser, serum, moisturizer, sunscreen → sunscreen has no match and is skipped
    #expect(t.fill(t.am, from: shelf) == ["1", "3", "2"])
    // pm: cleanser, toner, serum, moisturizer → toner skipped
    #expect(t.fill(t.pm, from: shelf) == ["1", "3", "2"])
}

@Test func relativeDatesReadNaturally() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(DateFormatting.relative(now, now: now) == "today")
    #expect(DateFormatting.relative(now.addingTimeInterval(-86_400), now: now) == "yesterday")
    #expect(DateFormatting.relative(now.addingTimeInterval(-3 * 86_400), now: now).count == 3)   // weekday
    #expect(DateFormatting.relative(now.addingTimeInterval(-30 * 86_400), now: now).contains(" "))  // "Mon d"
}

@Test func scoreToneThresholdsMatchDesign() {
    #expect(SKScore.tone(82) == .good)
    #expect(SKScore.tone(75) == .good)
    #expect(SKScore.tone(64) == .caution)
    #expect(SKScore.tone(50) == .caution)
    #expect(SKScore.tone(31) == .bad)
}
