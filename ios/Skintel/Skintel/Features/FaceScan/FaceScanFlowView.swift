import SkintelCore
import SwiftUI
import UIKit

/// Face Scan Pro, start to finish (PRO-SPEC §4–5): consent, the sweep, the questions, the read,
/// and the 7-day map. The one entry point lane F wires in:
///
///     FaceScanFlowView()                                  // present full screen
///     FaceScanFlowView(onAsk: { question in ... })        // also offer Ask; `question` goes in its composer
///
/// It needs `AppEnvironment` in the environment, closes itself with `dismiss`, and keeps its
/// scans in `FaceScanStore.shared` (call `FaceScanStore.shared.reset()` on sign-out and account
/// deletion). Entitlement is the server's: a 402 shows the Skintel+ message.
///
/// Without Skintel+, the one free baseline is kept exactly like a paid one (an entry in a real
/// cycle, the Day 1 crops, the answers) and shown as a real Day 1 map with the week locked.
/// Once the account is Pro, the same cycle goes on from Day 2.
///
/// The baseline read starts the moment the sweep ends, while the person answers the questions
/// (the server reads no answers before the report stage): the map shows as soon as both are done.
/// A failed read or a retake asked by the quality check shows after the questions, as before.
struct FaceScanFlowView: View {
    let onAsk: ((String) -> Void)?

    init(onAsk: ((String) -> Void)? = nil) {
        self.onAsk = onAsk
        // A returning person opens straight on their map: no blank first frame before `begin()`,
        // which still runs every gate on appear (age, Skintel+, consent) and moves on if one applies.
        let store = FaceScanStore.shared
        let opensOnMap = store.hasCycle && store.calibration.hasBaselineScan
            && UserDefaults.standard.bool(forKey: Self.consentKey)
        _screen = State(initialValue: opensOnMap ? .result : .start)
    }

    private static let consentKey = "faceScan.aiConsent"

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
    /// The quiz was opened from the map ("For your goals · Edit"): it starts from the saved
    /// answers and goes back to the map, with no read.
    @State private var editingAnswers = false
    @State private var store = FaceScanStore.shared
    @State private var screen: Screen
    /// `begin()` ran its gates once for this presentation.
    @State private var begun = false
    @State private var showConsent = false
    @State private var pendingImages: SweepImages?
    /// A read that didn't go through: shown in the flow over the reading screen, never an alert.
    @State private var errorText: String?
    /// What "Try again" re-sends (the same images and answers); nil when retrying can't help.
    @State private var lastAttempt: Attempt?
    /// The server couldn't read the photos: the sweep reopens on the "Let's retake that" card.
    @State private var retakeIssues: [String]?
    /// When the current read was sent, for the timed steps on the reading screen.
    @State private var readingStarted = Date()
    /// The baseline read running while the person answers, and what it came to.
    @State private var earlyRead: EarlyRead?
    /// Which early read is current, so a stale reply is never applied.
    @State private var earlyToken = 0
    /// The questions are done and the reading screen waits for the early read.
    @State private var waitingForEarlyRead = false

    private enum Attempt {
        case baseline(FaceAnswers)
        case scan(FaceScanStage, SweepImages)
        case report
    }

    private enum Screen: Equatable {
        case start
        case ageGate
        case sweep(FaceScanStage)
        case quiz
        case reading
        case result
    }

    /// The early read: in flight, recorded (the map waits for the questions), a quality miss to
    /// retake, or a failure to show on the reading screen. Failures wait for the questions.
    private enum EarlyRead: Equatable {
        case reading
        case ready
        case retake([String])
        case failed(String, retryable: Bool)
    }

    /// How one request ended.
    private enum ReadOutcome {
        case result(FaceScanResult)
        case proRequired
        case failed(String, retryable: Bool)
    }

    var body: some View {
        Group {
            switch screen {
            case .start:
                FaceScanBackdrop().ignoresSafeArea()
            case .ageGate:
                FaceAgeGateView(tooYoung: age13Confirmed == false, onAnswer: { yes in
                    age13Confirmed = yes
                    if yes { screen = .start; begin() }
                }, onClose: close)
            case .sweep(let stage):
                SweepView(fullSweep: stage != .daily, retakeIssues: retakeIssues,
                          showsPrivacyNote: stage == .baseline, onClose: {
                    // "Not now" on a retake goes back to the map when there is one.
                    if retakeIssues != nil && hasBaseline { retakeIssues = nil; screen = .result } else { close() }
                }) { images in
                    swept(images, stage: stage)
                }
            case .quiz:
                FaceQuizView(under18: treatAsUnder18,
                             prefill: FaceQuestions.prefill(profile: profile, triggerNames: triggerNames,
                                                            shelfActives: shelfActives.picks),
                             triggerHint: triggerHint,
                             profileLine: FaceQuestions.profileLine(profile: profile),
                             readStatus: editingAnswers ? nil : quizReadStatus,
                             saved: editingAnswers ? store.answers : nil,
                             shelfHint: shelfActives.hint,
                             onClose: {
                                 if editingAnswers { editingAnswers = false; screen = .result } else { close() }
                             }) { answers in
                    store.saveAnswers(answers)
                    if editingAnswers {
                        editingAnswers = false
                        screen = .result
                    } else if quizThenReport {
                        quizThenReport = false
                        Task { await readReport() }
                    } else if earlyRead != nil {
                        showEarlyRead()
                    } else {
                        Task { await readBaseline(answers: answers) }
                    }
                }
            case .reading:
                reading
            case .result:
                FaceResultView(calibration: store.calibration, routine: store.latestRoutine,
                               nextAction: nextAction, onNext: beginNext, onAsk: onAsk, onClose: close,
                               onUnlock: unlockWeek, photo: store.day1Front, answers: store.answers,
                               onEditGoals: editGoals)
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
        .sheet(isPresented: $showConsent, onDismiss: afterConsent) {
            FaceConsentSheet(privacyURL: env.config.privacyURL,
                             onAllow: { aiConsent = true; showConsent = false },
                             onNotNow: { showConsent = false })
        }
        // A read in flight keeps the screen awake: it can take up to a minute, and a locked phone
        // drops the request. The sweep sets its own (SweepView); a failure card lets it sleep.
        .onChange(of: screen, initial: true) { updateIdleTimer() }
        .onChange(of: errorText) { updateIdleTimer() }
        .onChange(of: earlyRead) { updateIdleTimer() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func updateIdleTimer() {
        if screen == .reading {
            UIApplication.shared.isIdleTimerDisabled = errorText == nil
        } else if case .sweep = screen {
            // SweepView owns it while it is on screen.
        } else if screen == .quiz && earlyRead == .reading {
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    /// The consent sheet closed: Allow goes on, anything else (Not now, a swipe) closes the flow.
    private func afterConsent() {
        if aiConsent { begin() } else { close() }
    }

    // MARK: Screens

    private var reading: some View {
        ZStack {
            VStack(spacing: SKSpace.lg) {
                FaceMeshView(mode: .scan, zoom: 0.4).frame(width: 240, height: 290)
                Text("Reading your skin").font(SKFont.serif(34, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("This can take up to a minute").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                if errorText == nil {
                    TimelineView(.periodic(from: readingStarted, by: 1)) { context in
                        readingSteps(elapsed: context.date.timeIntervalSince(readingStarted))
                    }
                    .padding(.top, SKSpace.sm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            if let errorText {
                SKColor.ink.opacity(0.2).ignoresSafeArea()
                failureCard(errorText)
                    .skPagePadding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(FaceScanBackdrop().ignoresSafeArea())
    }

    /// Three steps on timers. The last one stays in progress until the answer arrives: the
    /// screen never claims the read is done before it is.
    private func readingSteps(elapsed: TimeInterval) -> some View {
        let steps = ["Sending your photos", "Reading each area", "Writing your map"]
        let current = elapsed < 6 ? 0 : elapsed < 22 ? 1 : 2
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(spacing: SKSpace.md) {
                    ZStack {
                        if i < current {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(SKColor.goodFg)
                        } else if i == current {
                            ProgressView().controlSize(.small).tint(SKColor.primary)
                        } else {
                            Circle().stroke(SKColor.ink.opacity(0.25), lineWidth: 1.5).frame(width: 12, height: 12)
                        }
                    }
                    .frame(width: 20, height: 20)
                    Text(step).font(SKFont.secondary)
                        .foregroundStyle(i <= current ? SKColor.ink : SKColor.muted)
                }
            }
        }
        .animation(SKAnimation.ios(0.3), value: current)
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("That didn't go through").font(SKFont.section).foregroundStyle(SKColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text(message).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            if lastAttempt != nil {
                Text("Your photos are still here, so there's nothing to retake.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted)
                SKButton(title: "Try again", systemImage: "arrow.clockwise") { retry() }
                    .padding(.top, SKSpace.xs)
            }
            SKButton(title: "Not now", kind: lastAttempt == nil ? .primary : .ghost) { notNow() }
        }
        .padding(SKSpace.xl)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.sheet, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.sheet, style: .continuous).stroke(SKColor.line, lineWidth: 1))
        .skCardShadow()
    }

    // MARK: Context

    private var profile: SkinProfile { env.session.user?.skinProfile ?? SkinProfile() }

    private var triggerNames: [String] { env.products.culprits.all.map(\.name) }

    /// Actives found on the shelf, for Q3.
    private var shelfActives: (picks: [String], hint: String?) {
        FaceQuestions.shelfActives(env.products.products.map { item in
            (name: item.product.productName, ingredients: item.ingredients.map(\.inciRaw))
        })
    }

    private var triggerHint: String? {
        let picks = FaceQuestions.triggerPicks(triggerNames)
        guard !picks.isEmpty else { return nil }
        let list = picks.joined(separator: ", ")
        return picks.count == 1 ? "\(list) is already in your Triggers, so it is picked."
                                : "\(list) are already in your Triggers, so they are picked."
    }

    /// "For your goals · Edit": the questions again from the saved answers, once there are some.
    private var editGoals: (() -> Void)? {
        guard store.answers != nil else { return nil }
        return { editingAnswers = true; screen = .quiz }
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

    /// The pill on the questions while the early read runs; hidden once it failed (that shows after).
    private var quizReadStatus: FaceQuizView.ReadStatus? {
        switch earlyRead {
        case .reading?: .reading
        case .ready?: .ready
        default: nil
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

    /// Once on appear (also when the flow already opened on the map), and again from the age gate
    /// and the consent sheet, which both leave the screen on `.start`.
    private func begin() {
        guard screen == .start || !begun else { return }
        begun = true
        store.expireDay1Crops(now: Date())
        if needsAgeCheck && age13Confirmed != true { screen = .ageGate; return }
        // The free scan is used and there is no map left to show (deleted): straight to the wall.
        // With its cycle still here, it reopens below as the Day 1 map with the week locked.
        if !isPro && freeUsed && !hasBaseline { screen = .start; wallThenClose = true; return }
        guard aiConsent else { screen = .start; showConsent = true; return }
        screen = hasBaseline ? .result : .sweep(.baseline)
    }

    private func beginNext() {
        if freeWeekTooLate || (store.hasCycle && store.calibration.latestReport != nil) {
            // A new week: the read starts a new cycle id as soon as the sweep is done.
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
        for key in [consentKey, "faceScan.age13Confirmed", "faceScan.freeUsed"] {
            defaults.removeObject(forKey: key)
        }
    }

    /// "Not now" on the failure card, the only way a failed read leaves: back to the map when
    /// there is one, otherwise the flow closes. Nothing closes on its own.
    private func notNow() {
        errorText = nil
        lastAttempt = nil
        if hasBaseline { screen = .result } else { close() }
    }

    /// Re-sends exactly what failed: the same photos and answers, no new sweep.
    private func retry() {
        // A double tap: the first one already cleared the card and re-sent.
        guard errorText != nil, let attempt = lastAttempt else { return }
        errorText = nil
        switch attempt {
        case .baseline(let answers): Task { await readBaseline(answers: answers, newCycle: false) }
        case .scan(let stage, let images): Task { await read(stage: stage, images: images) }
        case .report: Task { await readReport() }
        }
    }

    private func swept(_ images: SweepImages, stage: FaceScanStage) {
        switch stage {
        case .baseline:
            pendingImages = images
            // A retake after a quality miss keeps this attempt's cycle and answers: no second quiz.
            if retakeIssues != nil, let answers = store.answers {
                retakeIssues = nil
                Task { await readBaseline(answers: answers, newCycle: false) }
            } else {
                retakeIssues = nil
                startEarlyRead(images)
                editingAnswers = false
                screen = .quiz
            }
        case .daily, .final:
            retakeIssues = nil
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

    /// The cycle day a request carries, clamped to the wire's range.
    private var requestDay: Int {
        min(max(store.cycleDay(now: Date()), FaceScanLimits.cycleDays.lowerBound), FaceScanLimits.cycleDays.upperBound)
    }

    // MARK: Early read (baseline, while the questions are answered)

    /// Starts the baseline read as the sweep ends. The cycle starts now (the request carries its
    /// id); no answers go with it, since the server reads none before the report stage.
    private func startEarlyRead(_ images: SweepImages) {
        store.startCycle(now: Date())
        lastAttempt = nil
        errorText = nil
        waitingForEarlyRead = false
        readingStarted = Date()
        earlyRead = .reading
        earlyToken += 1
        let token = earlyToken
        let day = requestDay
        let request = FaceScanRequest(stage: .baseline, cycleId: store.cycleId, day: day, images: sweepImages(images),
                                      answers: nil, profile: profileJSON, triggers: triggersJSON)
        Task {
            let outcome = await perform(request, stage: .baseline, day: day)
            earlyLanded(outcome, images: images, token: token)
        }
    }

    /// The early read came back. A good read is recorded at once (the server counted it, so it is
    /// kept even if the person closes the questions); everything else waits for the questions.
    private func earlyLanded(_ outcome: ReadOutcome, images: SweepImages, token: Int) {
        guard token == earlyToken, earlyRead == .reading else { return }
        switch outcome {
        case .proRequired:
            // The free scan is used up: the wall now, rather than after answering for nothing.
            earlyRead = nil
            waitingForEarlyRead = false
            freeUsed = true
            screen = .start
            wallThenClose = true
            return
        case .result(let result):
            if result.quality.ok {
                if result.locked { freeUsed = true }
                store.record(stage: .baseline, result: result, now: Date())
                store.saveDay1Crops(images.crops, front: images.views[.front])
                pendingImages = nil
                earlyRead = .ready
            } else {
                earlyRead = .retake(result.quality.issues)
            }
        case .failed(let message, let retryable):
            earlyRead = .failed(message, retryable: retryable)
        }
        if waitingForEarlyRead { showEarlyRead() }
    }

    /// The questions are done (answers saved): show what the early read came to, or wait for it
    /// on the reading screen.
    private func showEarlyRead() {
        guard let early = earlyRead else { return }
        switch early {
        case .reading:
            waitingForEarlyRead = true
            errorText = nil
            screen = .reading
            return
        case .ready:
            lastAttempt = nil
            Haptics.success()
            screen = .result
        case .retake(let issues):
            // Retake inside the flow, over the live camera; the stored answers are reused.
            retakeIssues = issues
            screen = .sweep(.baseline)
        case .failed(let message, let retryable):
            lastAttempt = retryable ? store.answers.map { Attempt.baseline($0) } : nil
            errorText = message
            screen = .reading
        }
        earlyRead = nil
        waitingForEarlyRead = false
    }

    // MARK: Reads

    /// `newCycle` is false for a retry or a retake, so the read the server may have kept stays
    /// in the same cycle (and recoverable).
    private func readBaseline(answers: FaceAnswers, newCycle: Bool = true) async {
        guard let images = pendingImages else { screen = .sweep(.baseline); return }
        if newCycle || !store.hasCycle { store.startCycle(now: Date()) }
        lastAttempt = .baseline(answers)
        await send(stage: .baseline, images: sweepImages(images), answers: answers) {
            store.saveDay1Crops(images.crops, front: images.views[.front])
            pendingImages = nil
        }
    }

    private func read(stage: FaceScanStage, images: SweepImages) async {
        let day1 = stage == .final ? store.day1Crops() : [:]
        let list = stage == .daily
            ? images.views[.front].map { [FaceScanImage(role: .front, base64: $0.base64EncodedString())] } ?? []
            : sweepImages(images, day1: day1)
        lastAttempt = .scan(stage, images)
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
            editingAnswers = false
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
        lastAttempt = .report
        await send(stage: .report, images: [], answers: answers, history: history, shelf: shelf.isEmpty ? nil : shelf) {}
    }

    /// A read on the reading screen: sends, then shows the result, the retake or the failure card.
    private func send(stage: FaceScanStage, images: [FaceScanImage], answers: FaceAnswers?,
                      history: [JSONValue]? = nil, shelf: [JSONValue]? = nil, onSuccess: () -> Void) async {
        errorText = nil
        readingStarted = Date()
        screen = .reading
        let day = requestDay
        let request = FaceScanRequest(stage: stage, cycleId: store.cycleId, day: day, images: images, answers: answers,
                                      history: history, profile: profileJSON, shelf: shelf, triggers: triggersJSON)
        switch await perform(request, stage: stage, day: day) {
        case .result(let result):
            accept(result, stage: stage, onSuccess: onSuccess)
        case .proRequired:
            // The free scan is used up: straight to the wall; the flow closes with it.
            freeUsed = true
            screen = .start
            wallThenClose = true
        case .failed(let message, let retryable):
            if !retryable { lastAttempt = nil }
            errorText = message
        }
    }

    /// One request, with the lost-reply recovery. Never touches the screen.
    private func perform(_ request: FaceScanRequest, stage: FaceScanStage, day: Int) async -> ReadOutcome {
        do {
            return .result(try await env.api.faceScan(request))
        } catch APIError.proRequired {
            return .proRequired
        } catch APIError.rateLimited {
            return .failed("That's today's limit for face scans. Try again tomorrow.", retryable: false)
        } catch let error as APIError {
            // The server keeps every readable answer. If only the reply was lost, fetch it
            // rather than closing the flow and throwing away a finished (and counted) read.
            if Self.mayHaveFinished(error), let kept = await recover(stage: stage, day: day) {
                return .result(kept)
            }
            return .failed(error.userMessage, retryable: true)
        } catch {
            return .failed("Something went wrong. Please try again.", retryable: true)
        }
    }

    private func accept(_ result: FaceScanResult, stage: FaceScanStage, onSuccess: () -> Void) {
        guard result.quality.ok else {
            // Retake inside the flow, over the live camera; a report has no photos to retake.
            if stage == .report {
                errorText = Self.qualityMessage(result.quality.issues)
            } else {
                retakeIssues = result.quality.issues
                screen = .sweep(stage)
            }
            return
        }
        // The free scan is a real baseline: recorded in this cycle with its Day 1 crops like
        // a paid one, so after Skintel+ the week goes on at Day 2 instead of a new sweep.
        if result.locked { freeUsed = true }
        store.record(stage: stage, result: result, now: Date())
        onSuccess()
        lastAttempt = nil
        Haptics.success()
        screen = .result
    }

    /// Failures where the read may still have finished on the server: the reply never arrived
    /// (timeout, dropped or lost connection), arrived garbled, or the gateway gave up waiting.
    static func mayHaveFinished(_ error: APIError) -> Bool {
        switch error {
        case .network, .offline, .decoding: true
        case .server(let status, _): status == 504
        default: false
        }
    }

    /// Asks for the kept read a few times: a connection that dropped early can come back before
    /// the server is done (its whole budget is under a minute). Stays on the reading screen.
    private func recover(stage: FaceScanStage, day: Int) async -> FaceScanResult? {
        for attempt in 0..<6 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 8_000_000_000) }
            if let kept = try? await env.api.latestFaceScan(cycleId: store.cycleId, stage: stage, day: day) {
                return kept
            }
        }
        return nil
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

/// The short AI consent (replaces the long alert). The full list of what is sent stays one tap
/// away in "What's sent", and in the privacy policy. Stored in the same `faceScan.aiConsent` flag.
private struct FaceConsentSheet: View {
    let privacyURL: URL
    let onAllow: () -> Void
    let onNotNow: () -> Void

    @State private var showSent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                Text("Read your skin with AI?").font(SKFont.section).foregroundStyle(SKColor.ink)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: SKSpace.md) {
                    bullet("Your photos, answers, skin profile, shelf and Triggers go to AI providers (Google and Anthropic, through OpenRouter), with zero data retention.")
                    bullet("Your Day 1 photo stays on this phone until your week ends")
                    bullet("A cosmetic read, not a diagnosis")
                }
                DisclosureGroup(isExpanded: $showSent) {
                    Text("Your face photos (three angles and five close crops), your answers, your skin profile, your shelf and your Triggers go to AI providers through OpenRouter (Google and Anthropic), with zero data retention. Photos are read, then deleted. Day 1 photos stay on this phone for your 7-day check, then are deleted (after 14 days if the week isn't finished). The 3D face is a model, not a scan of you.")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, SKSpace.sm)
                } label: {
                    Text("What's sent").font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline))
                        .foregroundStyle(SKColor.ink)
                }
                .tint(SKColor.muted)
                Link("Privacy details", destination: privacyURL)
                    .font(SKFont.secondary).foregroundStyle(SKColor.primary)
                VStack(spacing: SKSpace.xs) {
                    SKButton(title: "Allow") { onAllow() }
                    SKButton(title: "Not now", kind: .ghost) { onNotNow() }
                }
                .padding(.top, SKSpace.xs)
            }
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.xxl)
            .padding(.bottom, SKSpace.lg)
        }
        .presentationDetents([.height(500), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SKColor.cream)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SKSpace.sm) {
            Circle().fill(SKColor.primary).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(text).font(SKFont.body).foregroundStyle(SKColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
