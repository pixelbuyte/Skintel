import SwiftUI
import SkintelCore

/// Face Scan Pro, start to finish (PRO-SPEC §4–5): consent, the sweep, the questions, the read,
/// and the 7-day map. The one entry point lane F wires in:
///
///     FaceScanFlowView()                       // present full screen
///     FaceScanFlowView(onAsk: { ... })         // also offer "Ask Skinstel about this scan"
///
/// It needs `AppEnvironment` in the environment, closes itself with `dismiss`, and keeps its
/// scans in `FaceScanStore.shared` (call `FaceScanStore.shared.reset()` on sign-out and account
/// deletion). Entitlement is the server's: a 402 shows the Skintel+ message.
///
/// Without Skintel+, the one free baseline is kept exactly like a paid one (an entry in a real
/// cycle, the Day 1 crops, the answers) and shown as a real Day 1 map with the week locked.
/// Once the account is Pro, the same cycle goes on from Day 2.
struct FaceScanFlowView: View {
    let onAsk: (() -> Void)?

    init(onAsk: (() -> Void)? = nil) {
        self.onAsk = onAsk
    }

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @AppStorage("faceScan.aiConsent") private var aiConsent = false
    /// The 13+ answer (COPPA), asked only when onboarding gave no age or "Under 18".
    @AppStorage("faceScan.age13Confirmed") private var age13Confirmed: Bool?
    @AppStorage("faceScan.freeUsed") private var freeUsed = false
    /// The 402 path: the wall over a blank flow, which closes when the wall does.
    @State private var wallThenClose = false
    /// The wall opened from the locked 7-day check on the map (no Skintel+).
    @State private var wallFromLocked = false
    /// The quiz was opened to collect Q5's locks before the report.
    @State private var quizThenReport = false
    @State private var store = FaceScanStore.shared
    @State private var screen: Screen = .start
    @State private var showConsent = false
    @State private var pendingImages: SweepImages?
    @State private var errorText: String?

    private enum Screen: Equatable {
        case start
        case ageGate
        case sweep(FaceScanStage)
        case quiz
        case reading
        case result
    }

    var body: some View {
        Group {
            switch screen {
            case .start:
                SKColor.scannerBg.ignoresSafeArea()
            case .ageGate:
                FaceAgeGateView(tooYoung: age13Confirmed == false, onAnswer: { yes in
                    age13Confirmed = yes
                    if yes { screen = .start; begin() }
                }, onClose: close)
            case .sweep(let stage):
                SweepView(fullSweep: stage != .daily, onClose: close) { images in
                    swept(images, stage: stage)
                }
            case .quiz:
                FaceQuizView(under18: treatAsUnder18, prefill: FaceQuestions.prefill(profile: profile, triggerNames: triggerNames),
                             triggerHint: triggerHint, onClose: close) { answers in
                    store.saveAnswers(answers)
                    if quizThenReport {
                        quizThenReport = false
                        Task { await readReport() }
                    } else {
                        Task { await readBaseline(answers: answers) }
                    }
                }
            case .reading:
                reading
            case .result:
                FaceResultView(calibration: store.calibration, routine: store.latestRoutine,
                               nextAction: nextAction, onNext: beginNext, onAsk: onAsk, onClose: close,
                               onUnlock: unlockWeek)
                    .sheet(isPresented: $wallFromLocked) {
                        PaywallView(reason: .faceScan, faceMapReady: true)
                    }
            }
        }
        .onAppear(perform: begin)
        .task { await env.subscription.confirmIfUnsure() }
        .sheet(isPresented: $wallThenClose, onDismiss: close) {
            PaywallView(reason: .faceScan)
        }
        .alert("Read your skin with AI?", isPresented: $showConsent) {
            Button("Allow") { aiConsent = true; begin() }
            Button("Not now", role: .cancel) { close() }
        } message: {
            Text("To read your skin, Skinstel sends your face photos (three angles and five close crops), your answers, your skin profile, your shelf and your Triggers to third-party AI providers through OpenRouter (Google and Anthropic), with zero data retention. Photos are read, then deleted. The 3D face is a model, not a scan of you. Day 1 close-ups stay on this phone for your 7-day check, then are deleted (after 14 days if the week isn't finished). A cosmetic read, not a diagnosis. Details are in our Privacy Policy.")
        }
        .alert("Face scan", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) { afterError() }
        } message: {
            Text(errorText ?? "")
        }
    }

    // MARK: Screens

    private var reading: some View {
        VStack(spacing: SKSpace.lg) {
            FaceMeshView(mode: .scan, zoom: 0.4).frame(width: 260, height: 320)
            Text("Reading your skin").font(SKFont.serif(34, relativeTo: .largeTitle)).foregroundStyle(SKColor.bg)
            Text("About 10 seconds").font(SKFont.secondary).foregroundStyle(SKColor.bg.opacity(0.72))
            ProgressView().tint(SKColor.bg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SKColor.scannerBg.ignoresSafeArea())
        .accessibilityElement(children: .combine)
    }

    // MARK: Context

    private var profile: SkinProfile { env.session.user?.skinProfile ?? SkinProfile() }

    private var triggerNames: [String] { env.products.culprits.all.map(\.name) }

    private var triggerHint: String? {
        let picks = FaceQuestions.triggerPicks(triggerNames)
        guard !picks.isEmpty else { return nil }
        let list = picks.joined(separator: ", ")
        return picks.count == 1 ? "\(list) is already in your Triggers, so it is picked."
                                : "\(list) are already in your Triggers, so they are picked."
    }

    private var hasBaseline: Bool { store.hasCycle && store.calibration.hasBaselineScan }

    /// The scan today calls for: none once today is counted or the report exists.
    private var nextStage: FaceScanStage? {
        let cal = store.calibration
        guard hasBaseline, !cal.hasFinalScan else { return nil }
        if cal.scannedToday(now: Date()) { return nil }
        return cal.scanCount >= FaceCalibration.Milestone.fullReport.scansNeeded - 1 ? .final : .daily
    }

    private var nextAction: String? {
        if freeWeekTooLate { return "Start a new week" }
        if store.hasCycle && store.calibration.latestReport != nil { return "Start a new week" }
        if store.hasCycle && store.calibration.hasFinalScan && store.calibration.latestReport == nil {
            return "Write my skin report"
        }
        switch nextStage {
        case .final?: return "Final sweep"
        case .daily?: return "Take today's photo"
        default: return nil
        }
    }

    // MARK: Flow

    private var isPro: Bool { env.subscription.entitlement.isPro }

    /// Without Skintel+ the map shows with the week locked, and this opens the wall. Nil for Pro,
    /// so the moment a purchase lands the same cycle shows unlocked with today's scan action.
    /// Locked only for a confirmed Free row: while the membership is loading or its fetch failed,
    /// a Pro member never sees the week locked (a scan call would 402 to the wall anyway).
    private var unlockWeek: (() -> Void)? {
        let sub = env.subscription
        guard sub.loaded, sub.lastError == nil, !sub.entitlement.isPro else { return nil }
        return { wallFromLocked = true }
    }

    /// The cycle holds only the free baseline and the six scans left can no longer finish inside
    /// the 14 days the Day 1 crops are kept: a late upgrade starts a new week instead.
    private var freeWeekTooLate: Bool {
        let cal = store.calibration
        guard store.hasCycle, cal.scanCount == 1, let only = cal.scans.first,
              only.stage == .baseline, only.result.locked else { return false }
        let scansLeft = cal.scansToGo(for: .fullReport)
        return store.cycleDay(now: Date()) + scansLeft - 1 > 14
    }

    private func begin() {
        guard screen == .start else { return }
        store.expireDay1Crops(now: Date())
        if needsAgeCheck && age13Confirmed != true { screen = .ageGate; return }
        // The free scan is used and there is no map left to show (deleted): straight to the wall.
        // With its cycle still here, it reopens below as the Day 1 map with the week locked.
        if !isPro && freeUsed && !hasBaseline { wallThenClose = true; return }
        guard aiConsent else { showConsent = true; return }
        screen = hasBaseline ? .result : .sweep(.baseline)
    }

    private func beginNext() {
        if freeWeekTooLate || (store.hasCycle && store.calibration.latestReport != nil) {
            // A new week: readBaseline starts a new cycle id once the sweep and quiz are done.
            screen = .sweep(.baseline)
            return
        }
        if store.calibration.hasFinalScan && store.calibration.latestReport == nil {
            Task { await readReport() }
            return
        }
        guard let stage = nextStage else { return }
        screen = .sweep(stage)
    }

    private func close() { dismiss() }

    /// Onboarding gave no age, or "Under 18": ask the 13+ question.
    private var needsAgeCheck: Bool { profile.ageRange == nil || profile.ageRange == .under18 }

    /// Under 18, or an unknown age that only passed the 13+ gate: no pregnancy chips, no Q16.
    private var treatAsUnder18: Bool { profile.ageRange == nil || profile.ageRange == .under18 }

    /// The `@AppStorage` keys this flow keeps, cleared on sign-out (`AppEnvironment.resetAfterSignOut`).
    static func resetPreferences(_ defaults: UserDefaults = .standard) {
        for key in ["faceScan.aiConsent", "faceScan.age13Confirmed", "faceScan.freeUsed"] {
            defaults.removeObject(forKey: key)
        }
    }

    private func afterError() {
        screen = hasBaseline ? .result : .start
        if screen == .start { close() }
    }

    private func swept(_ images: SweepImages, stage: FaceScanStage) {
        switch stage {
        case .baseline:
            pendingImages = images
            screen = .quiz
        case .daily, .final:
            Task { await read(stage: stage, images: images) }
        case .report:
            break
        }
    }

    private func sweepImages(_ images: SweepImages, day1: [FaceZone: Data] = [:]) -> [FaceScanImage] {
        var out: [FaceScanImage] = []
        for role in [FaceScanImage.Role.front, .left45, .right45] {
            if let d = images.views[role] { out.append(FaceScanImage(role: role, base64: d.base64EncodedString())) }
        }
        for zone in FaceZone.allCases {
            if let d = images.crops[zone] { out.append(FaceScanImage(role: .zone, zone: zone, base64: d.base64EncodedString())) }
        }
        for zone in FaceZone.allCases {
            if let d = day1[zone] {
                out.append(FaceScanImage(role: .zone, zone: zone, from: FaceScanImage.day1, base64: d.base64EncodedString()))
            }
        }
        return out
    }

    private var profileJSON: [String: JSONValue] {
        var p: [String: JSONValue] = [:]
        if let t = profile.skinType { p["skinType"] = .string(t.rawValue) }
        p["concerns"] = .array(profile.concerns.map { .string($0.rawValue) })
        if let a = profile.ageRange { p["ageRange"] = .string(a.rawValue) }
        return p
    }

    private var triggersJSON: [JSONValue]? {
        let names = triggerNames
        return names.isEmpty ? nil : names.map { .string($0) }
    }

    private func readBaseline(answers: FaceAnswers) async {
        guard let images = pendingImages else { screen = .sweep(.baseline); return }
        store.startCycle(now: Date())
        await send(stage: .baseline, images: sweepImages(images), answers: answers) {
            store.saveDay1Crops(images.crops)
        }
        pendingImages = nil
    }

    private func read(stage: FaceScanStage, images: SweepImages) async {
        let day1 = stage == .final ? store.day1Crops() : [:]
        let list = stage == .daily
            ? images.views[.front].map { [FaceScanImage(role: .front, base64: $0.base64EncodedString())] } ?? []
            : sweepImages(images, day1: day1)
        await send(stage: stage, images: list, answers: store.answers) {}
        if stage == .final, store.calibration.hasFinalScan { await readReport() }
    }

    private func readReport() async {
        let history: [JSONValue] = store.calibration.scans.compactMap { entry in
            guard let data = try? JSONEncoder().encode(entry) else { return nil }
            return try? JSONDecoder().decode(JSONValue.self, from: data)
        }
        // Locks never fail open: no stored answers means the quiz (Q5) runs first.
        guard let answers = store.answers else {
            quizThenReport = true
            screen = .quiz
            return
        }
        let shelf: [JSONValue] = env.products.products.map { item in
            var o: [String: JSONValue] = ["name": .string(item.product.productName)]
            if let brand = item.product.brand { o["brand"] = .string(brand) }
            if let category = item.product.category { o["category"] = .string(category) }
            let key = item.ingredients.sorted { $0.position < $1.position }.prefix(15).map { JSONValue.string($0.inciRaw) }
            if !key.isEmpty { o["ingredients"] = .array(Array(key)) }
            return .object(o)
        }
        await send(stage: .report, images: [], answers: answers, history: history, shelf: shelf.isEmpty ? nil : shelf) {}
    }

    private func send(stage: FaceScanStage, images: [FaceScanImage], answers: FaceAnswers?,
                      history: [JSONValue]? = nil, shelf: [JSONValue]? = nil, onSuccess: () -> Void) async {
        screen = .reading
        let day = min(max(store.cycleDay(now: Date()), FaceScanLimits.cycleDays.lowerBound), FaceScanLimits.cycleDays.upperBound)
        let request = FaceScanRequest(stage: stage, cycleId: store.cycleId, day: day, images: images, answers: answers,
                                      history: history, profile: profileJSON, shelf: shelf, triggers: triggersJSON)
        do {
            let result = try await env.api.faceScan(request)
            guard result.quality.ok else {
                errorText = Self.qualityMessage(result.quality.issues)
                return
            }
            // The free scan is a real baseline: recorded in this cycle with its Day 1 crops like
            // a paid one, so after Skintel+ the week goes on at Day 2 instead of a new sweep.
            if result.locked { freeUsed = true }
            store.record(stage: stage, result: result, now: Date())
            onSuccess()
            Haptics.success()
            screen = .result
        } catch APIError.proRequired {
            // The free scan is used up: straight to the wall; the flow closes with it.
            freeUsed = true
            screen = .start
            wallThenClose = true
        } catch let error as APIError {
            errorText = error.userMessage
        } catch {
            errorText = "Something went wrong. Please try again."
        }
    }

    static func qualityMessage(_ issues: [String]) -> String {
        let reasons: [String: String] = [
            "too_dark": "the light was too dim",
            "face_turned": "your face was turned away",
            "filter": "the photo looked filtered",
            "blurry": "the photo was blurry",
            "multiple_faces": "more than one face was in view",
        ]
        let words = issues.compactMap { reasons[$0] }
        guard !words.isEmpty else { return "We couldn't read that photo. Please try again in even light." }
        return "We couldn't read that photo: \(words.joined(separator: ", ")). Please try again."
    }
}
