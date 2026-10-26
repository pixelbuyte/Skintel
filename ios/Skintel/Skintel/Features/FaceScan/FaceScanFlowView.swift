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
struct FaceScanFlowView: View {
    let onAsk: (() -> Void)?

    init(onAsk: (() -> Void)? = nil) {
        self.onAsk = onAsk
    }

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openPaywall) private var openPaywall
    @AppStorage("faceScan.aiConsent") private var aiConsent = false
    /// The 13+ answer (COPPA), asked only when onboarding gave no age or "Under 18".
    @AppStorage("faceScan.age13Confirmed") private var age13Confirmed: Bool?
    @State private var lockedResult: FaceScanResult?
    @State private var store = FaceScanStore.shared
    @State private var screen: Screen = .start
    @State private var showConsent = false
    @State private var pendingImages: SweepImages?
    @State private var errorText: String?

    private enum Screen: Equatable {
        case start
        case ageGate
        case locked
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
            case .locked:
                if let lockedResult {
                    FaceLockedView(result: lockedResult, onUnlock: showPaywall, onClose: close)
                }
            case .sweep(let stage):
                SweepView(fullSweep: stage != .daily, onClose: close) { images in
                    swept(images, stage: stage)
                }
            case .quiz:
                FaceQuizView(under18: profile.ageRange == .under18, prefill: FaceQuestions.prefill(profile: profile, triggerNames: triggerNames),
                             triggerHint: triggerHint, onClose: close) { answers in
                    store.saveAnswers(answers)
                    Task { await readBaseline(answers: answers) }
                }
            case .reading:
                reading
            case .result:
                FaceResultView(calibration: store.calibration, routine: store.latestRoutine,
                               nextAction: nextAction, onNext: beginNext, onAsk: onAsk, onClose: close)
            }
        }
        .onAppear(perform: begin)
        .alert("Read your skin with AI?", isPresented: $showConsent) {
            Button("Allow") { aiConsent = true; begin() }
            Button("Not now", role: .cancel) { close() }
        } message: {
            Text("To read your skin, Skinstel sends your face photos (three angles and five close crops), your answers, your skin profile and your Triggers to third-party AI providers through OpenRouter (Google and Anthropic), with zero data retention. Photos are read, then deleted; your 3D face shape stays on this phone. A cosmetic read, not a diagnosis. Details are in our Privacy Policy.")
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

    private func begin() {
        guard screen == .start else { return }
        if needsAgeCheck && age13Confirmed != true { screen = .ageGate; return }
        guard aiConsent else { showConsent = true; return }
        screen = hasBaseline ? .result : .sweep(.baseline)
    }

    private func beginNext() {
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

    private func showPaywall() {
        openPaywall(.faceScan)
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
        await send(stage: .report, images: [], answers: store.answers ?? FaceAnswers(locks: []), history: history) {}
    }

    private func send(stage: FaceScanStage, images: [FaceScanImage], answers: FaceAnswers?,
                      history: [JSONValue]? = nil, onSuccess: () -> Void) async {
        screen = .reading
        let day = min(max(store.cycleDay(now: Date()), FaceScanLimits.cycleDays.lowerBound), FaceScanLimits.cycleDays.upperBound)
        let request = FaceScanRequest(stage: stage, cycleId: store.cycleId, day: day, images: images, answers: answers,
                                      history: history, profile: profileJSON, triggers: triggersJSON)
        do {
            let result = try await env.api.faceScan(request)
            if result.locked {
                // The free scan: zones found, details behind Skintel+. Not stored as a scan.
                Haptics.success()
                lockedResult = result
                screen = .locked
                return
            }
            guard result.quality.ok else {
                errorText = Self.qualityMessage(result.quality.issues)
                return
            }
            store.record(stage: stage, result: result, now: Date())
            onSuccess()
            Haptics.success()
            screen = .result
        } catch APIError.proRequired {
            // The free scan is used up: straight to the wall.
            showPaywall()
            close()
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
