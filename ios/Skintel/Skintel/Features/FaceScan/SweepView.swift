import AVFoundation
import Observation
import SkintelCore
import SwiftUI
import UIKit

/// The sweep's result: the three views (or one, for a daily photo) and the centre's zone crops.
struct SweepImages: Sendable {
    var views: [FaceScanImage.Role: Data] = [:]
    var crops: [FaceZone: Data] = [:]
}

@MainActor
@Observable
final class SweepModel {
    enum Phase: Equatable { case starting, denied, unavailable, scanning, done }

    /// The angles to lock, in order. A daily photo is the centre only.
    let roles: [FaceScanImage.Role]
    private(set) var phase: Phase = .starting
    private(set) var step = 0
    private(set) var reading = SweepReading()
    private(set) var images = SweepImages()
    /// True while the retake card is up: the camera runs (the person sees themselves) but no
    /// angle locks until they tap Retake.
    private(set) var holding: Bool
    private var camera: SweepCamera?

    init(fullSweep: Bool, holding: Bool = false) {
        roles = fullSweep ? [.front, .left45, .right45] : [.front]
        self.holding = holding
    }

    /// The running session for the live preview, once the camera exists.
    var session: AVCaptureSession? { camera?.captureSession }

    var currentRole: FaceScanImage.Role? { step < roles.count ? roles[step] : nil }

    func start() async {
        guard SweepCamera.isAvailable else { phase = .unavailable; return }
        guard await SweepCamera.requestAccess() else { phase = .denied; return }
        let camera = SweepCamera(
            onReading: { [weak self] reading in self?.reading = reading },
            onCapture: { [weak self] capture, yaw in self?.locked(capture, yaw: yaw) }
        )
        self.camera = camera
        phase = .scanning
        camera.start()
        aim()
    }

    func stop() { camera?.stop() }

    func restart() {
        step = 0
        images = SweepImages()
        if phase == .done { phase = .scanning; camera?.start() }
        aim()
    }

    /// Retake: drop the hold and start the sweep from the first angle.
    func resume() {
        holding = false
        restart()
    }

    /// The manual shutter: lock the current angle on the next frame with a face.
    func shutter() {
        guard phase == .scanning, !holding, let role = currentRole else { return }
        camera?.setTarget(.forced(role))
    }

    private func aim() {
        if holding {
            camera?.setTarget(.none)
        } else if let role = currentRole {
            camera?.setTarget(.capture(role))
        } else {
            camera?.setTarget(.none)
        }
    }

    private func locked(_ capture: SweepCapture, yaw: Double) {
        guard capture.role == currentRole else { return }
        images.views[capture.role] = capture.view
        if capture.role == .front { images.crops = capture.crops }
        Haptics.tap()
        step += 1
        if step >= roles.count {
            phase = .done
            Haptics.success()
            camera?.stop()
        }
        aim()
    }
}

/// Raises the screen to full brightness while the sweep runs, so the screen lights the face,
/// and puts the person's own brightness back after. Main actor only (UIScreen).
@MainActor
final class SweepScreenLight {
    private var saved: CGFloat?
    private weak var raisedScreen: UIScreen?

    private var currentScreen: UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.screen
    }

    func raise() {
        guard let screen = currentScreen else { return }
        if saved == nil {
            saved = screen.brightness
            raisedScreen = screen
        }
        screen.brightness = 1
    }

    func restore() {
        guard let saved else { return }
        (raisedScreen ?? currentScreen)?.brightness = saved
        self.saved = nil
        raisedScreen = nil
    }
}

/// The live front camera on the sweep's own session. The layer is the view's backing layer,
/// so it always fills the view; the front camera's preview is mirrored by default.
struct SweepPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session { uiView.previewLayer.session = session }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// What the server's quality codes mean in plain words, and what to do about them.
enum SweepRetakeAdvice {
    struct Line: Hashable {
        var problem: String
        var tip: String
    }

    static let defaultTips = ["Face a window", "Hold the phone at eye level", "Wipe the camera lens"]

    static func lines(_ issues: [String]) -> [Line] {
        let map: [String: Line] = [
            "too_dark": Line(problem: "It was too dim", tip: "Face a window or a lamp"),
            "face_turned": Line(problem: "Your face was turned away", tip: "Hold the phone at eye level"),
            "filter": Line(problem: "The photo looked filtered", tip: "Turn off any beauty filter"),
            "blurry": Line(problem: "The photo was blurry", tip: "Wipe the camera lens and hold still"),
            "multiple_faces": Line(problem: "More than one face was in view", tip: "Make sure only you are in view"),
        ]
        var seen = Set<String>()
        return issues.compactMap { map[$0] }.filter { seen.insert($0.problem).inserted }
    }
}

/// The scanner (canvas screen 3), over the live front camera: the person sees their own face,
/// mirrored, inside an oval guide with the angle progress ring. A small 3D face in the corner
/// turns to the angle wanted; live checks say what to fix; the screen glows cream as a ring
/// light. An angle locks once every check holds for `SweepCamera.holdSeconds`, or with the
/// shutter. With `retakeIssues`, it opens on the "Let's retake that" card instead.
struct SweepView: View {
    let fullSweep: Bool
    let retakeIssues: [String]?
    let onClose: () -> Void
    let onDone: (SweepImages) -> Void

    @State private var model: SweepModel
    @State private var showRetake: Bool
    @State private var light = SweepScreenLight()
    @Environment(\.scenePhase) private var scenePhase

    init(fullSweep: Bool, retakeIssues: [String]? = nil, onClose: @escaping () -> Void,
         onDone: @escaping (SweepImages) -> Void) {
        self.fullSweep = fullSweep
        self.retakeIssues = retakeIssues
        self.onClose = onClose
        self.onDone = onDone
        _model = State(initialValue: SweepModel(fullSweep: fullSweep, holding: retakeIssues != nil))
        _showRetake = State(initialValue: retakeIssues != nil)
    }

    private let names: [FaceScanImage.Role: String] = [.front: "Centre", .left45: "Left 45°", .right45: "Right 45°"]

    private var live: Bool { model.phase == .scanning || model.phase == .done }
    /// The ring light is on while an angle is being looked for.
    private var lightOn: Bool { model.phase == .scanning && !model.holding }

    var body: some View {
        ZStack {
            SKColor.scannerBg.ignoresSafeArea()
            if live, let session = model.session {
                SweepPreview(session: session)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
            scrims
            if lightOn { ringLight }
            content
            if showRetake {
                SKColor.scannerOverlay.ignoresSafeArea()
                retakeCard
                    .skPagePadding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(SKColor.bg)
        .task { await model.start() }
        .onDisappear {
            model.stop()
            light.restore()
        }
        .onChange(of: lightOn) { updateLight() }
        .onChange(of: scenePhase) { updateLight() }
        .onChange(of: model.phase) { _, phase in
            if phase == .done { onDone(model.images) }
        }
    }

    private func updateLight() {
        if lightOn && scenePhase == .active { light.raise() } else { light.restore() }
    }

    private func close() {
        light.restore()
        onClose()
    }

    // MARK: Layout

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(kicker).font(SKFont.mono(12)).tracking(1.5)
                Spacer()
                Button { model.restart() } label: {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SKColor.bg.opacity(0.8)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Start the sweep again")
                .disabled(model.holding)
            }
            .padding(.top, SKSpace.md)
            .padding(.horizontal, SKSpace.lg)

            HStack(alignment: .top, spacing: SKSpace.md) {
                VStack(alignment: .leading, spacing: SKSpace.xs) {
                    Text(title).font(SKFont.serif(32, relativeTo: .largeTitle))
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle).font(SKFont.sans(15, relativeTo: .subheadline)).foregroundStyle(SKColor.bg.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(SKAnimation.ios(0.3), value: title)
                if live { meshGuide }
            }
            .shadow(color: SKColor.scannerBg.opacity(0.5), radius: 6)
            .padding(.horizontal, SKSpace.xl)
            .padding(.top, SKSpace.sm)

            Spacer(minLength: SKSpace.md)
            ovalGuide
            Spacer(minLength: SKSpace.md)

            if model.roles.count > 1 {
                HStack(spacing: SKSpace.sm) {
                    ForEach(Array(model.roles.enumerated()), id: \.offset) { index, role in
                        chip(index: index, role: role)
                    }
                }
                .padding(.bottom, SKSpace.md)
            }
            if model.phase == .scanning { checks.padding(.horizontal, SKSpace.lg) }
            if model.phase == .scanning { shutter.padding(.top, SKSpace.lg) }
            Text("Your Day 1 photo and close-ups stay on this phone until your week ends, then are deleted.")
                .font(SKFont.caption).foregroundStyle(SKColor.bg.opacity(0.7))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
                .padding(.top, SKSpace.md).padding(.bottom, SKSpace.lg)
        }
    }

    /// Dark gradients at the top and bottom so the words read over any background.
    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [SKColor.scannerBg.opacity(0.75), SKColor.scannerBg.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 220)
            Spacer(minLength: 0)
            LinearGradient(colors: [SKColor.scannerBg.opacity(0), SKColor.scannerBg.opacity(0.8)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 300)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A soft cream border: with the screen at full brightness it lights the face.
    private var ringLight: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SKRadius.sheet, style: .continuous)
                .strokeBorder(SKColor.cream, lineWidth: 34)
                .blur(radius: 14)
            RoundedRectangle(cornerRadius: SKRadius.sheet, style: .continuous)
                .strokeBorder(SKColor.cream, lineWidth: 14)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var ovalGuide: some View {
        ZStack {
            Ellipse().stroke(SKColor.bg.opacity(0.35), lineWidth: 5)
            Ellipse().trim(from: 0, to: progress)
                .stroke(SKColor.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(SKAnimation.ios(0.4), value: progress)
            if model.phase == .scanning && model.reading.ready && !model.holding {
                Ellipse().stroke(SKColor.goodBg.opacity(0.9), lineWidth: 2).padding(8)
            }
        }
        .frame(width: 250, height: 330)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scan progress")
        .accessibilityValue("\(min(model.step, model.roles.count)) of \(model.roles.count) angles")
    }

    /// The "you are here" guide: the 3D face turned to the angle wanted now.
    private var meshGuide: some View {
        FaceMeshView(mode: .scan, zoom: 0.4, targetYaw: targetYaw)
            .frame(width: 96, height: 96)
            .background(SKColor.scannerBg.opacity(0.72), in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.bg.opacity(0.25), lineWidth: 1))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var shutter: some View {
        Button {
            Haptics.tap()
            model.shutter()
        } label: {
            ZStack {
                Circle().stroke(SKColor.bg, lineWidth: 3).frame(width: 66, height: 66)
                Circle().fill(SKColor.bg).frame(width: 54, height: 54)
            }
            .frame(width: 70, height: 70)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(model.holding || model.reading.faceCount == 0)
        .opacity(model.holding || model.reading.faceCount == 0 ? 0.45 : 1)
        .accessibilityLabel("Take this angle now")
        .accessibilityHint("Takes the photo without waiting for every check")
    }

    // MARK: Retake

    private var retakeCard: some View {
        let lines = SweepRetakeAdvice.lines(retakeIssues ?? [])
        let tips = lines.isEmpty ? SweepRetakeAdvice.defaultTips : lines.map(\.tip)
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            Text("Let's retake that").font(SKFont.section).foregroundStyle(SKColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text(lines.isEmpty ? "We couldn't read that photo clearly."
                               : lines.map(\.problem).joined(separator: ". ") + ".")
                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .firstTextBaseline, spacing: SKSpace.sm) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(SKColor.goodFg)
                            .accessibilityHidden(true)
                        Text(tip).font(SKFont.body).foregroundStyle(SKColor.ink)
                    }
                }
            }
            SKButton(title: "Retake", systemImage: "arrow.counterclockwise") {
                withAnimation(SKAnimation.ios(0.35)) { showRetake = false }
                model.resume()
            }
            .padding(.top, SKSpace.xs)
            SKButton(title: "Not now", kind: .ghost) { close() }
        }
        .padding(SKSpace.xl)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.sheet, style: .continuous))
        .skCardShadow()
    }

    // MARK: Words

    private var progress: CGFloat {
        CGFloat(min(model.step, model.roles.count)) / CGFloat(max(model.roles.count, 1))
    }

    private var targetYaw: Double {
        switch model.currentRole {
        case .left45: 0.62
        case .right45: -0.62
        default: 0
        }
    }

    private var kicker: String {
        let n = model.roles.count
        if model.phase == .done { return n == 1 ? "PHOTO TAKEN" : "ALL \(n) ANGLES" }
        return n == 1 ? "TODAY'S PHOTO" : "ANGLE \(min(model.step + 1, n)) OF \(n)"
    }

    private var title: String {
        switch model.phase {
        case .denied: return "Camera is off"
        case .unavailable: return "No front camera"
        case .done: return "Got it"
        default: break
        }
        switch model.currentRole {
        case .left45: return "Slowly turn left"
        case .right45: return "Now right"
        default: return "Look straight ahead"
        }
    }

    private var subtitle: String {
        switch model.phase {
        case .denied: return "Allow the camera for Skinstel in Settings to scan your face."
        case .unavailable: return "Face scan needs a front camera."
        case .done: return "Reading your skin next"
        case .starting: return "Starting the camera"
        default: break
        }
        if model.holding { return "Phone at eye level, face in the oval" }
        if let hint { return hint }
        if model.reading.ready { return "Hold it there" }
        switch model.currentRole {
        case .left45, .right45: return "Keep your phone where it is"
        default: return "Phone at eye level, face in the oval"
        }
    }

    /// What's stopping the angle from locking, live, in the order to fix it. Nil once the camera
    /// sees nothing wrong, so the turn instruction shows.
    private var hint: String? {
        guard model.phase == .scanning else { return nil }
        let r = model.reading
        if r.faceCount == 0 { return "Fit your face in the oval" }
        if r.faceCount > 1 { return "Only one face in view, please" }
        if !r.evenLight { return "Too dark. Face a window or a bright light" }
        if r.tooFar { return "Move a little closer" }
        if r.tooClose { return "Move the phone back a little" }
        if !r.sharp || !r.steady { return "Hold still" }
        return nil
    }

    private func chip(index: Int, role: FaceScanImage.Role) -> some View {
        let done = index < model.step
        let active = index == model.step && model.phase == .scanning
        let name = names[role] ?? ""
        return HStack(spacing: 6) {
            if done { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
            Text(active ? "\(name) · now" : name)
        }
        .font(SKFont.sans(13, relativeTo: .footnote))
        .foregroundStyle(done || active ? SKColor.cream : SKColor.bg.opacity(0.85))
        .padding(.horizontal, SKSpace.md).padding(.vertical, SKSpace.sm)
        .background(done ? SKColor.primary : active ? SKColor.primary.opacity(0.45) : SKColor.scannerBg.opacity(0.5), in: Capsule())
        .overlay(Capsule().stroke(done || active ? SKColor.primary : SKColor.bg.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : active ? "Now" : "Waiting")
    }

    // MARK: Checks

    private var checks: some View {
        let r = model.reading
        let faceFix = r.faceCount == 0 ? "Fit your face in the oval" : "Only you in view"
        let distanceFix = r.tooClose ? "Move back a little" : "Move a little closer"
        return VStack(spacing: SKSpace.sm) {
            HStack(spacing: SKSpace.sm) {
                check(ok: r.evenLight, okText: "Good light", fix: "Face a window or a lamp")
                check(ok: r.goodDistance, okText: "Good distance", fix: distanceFix)
            }
            HStack(spacing: SKSpace.sm) {
                check(ok: r.sharp && r.steady, okText: "Steady", fix: "Hold still")
                check(ok: r.oneFace, okText: "One face", fix: faceFix)
            }
        }
    }

    private func check(ok: Bool, okText: String, fix: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark" : "exclamationmark")
                .font(.system(size: 11, weight: .bold))
                .accessibilityHidden(true)
            Text(ok ? okText : fix).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(SKFont.sans(13, weight: .medium, relativeTo: .footnote))
        .foregroundStyle(ok ? SKColor.goodFg : SKColor.cream)
        .padding(.horizontal, SKSpace.md).padding(.vertical, SKSpace.sm)
        .frame(maxWidth: .infinity)
        .background(ok ? SKColor.goodBg : SKColor.scannerBg.opacity(0.6), in: Capsule())
        .overlay(Capsule().stroke(ok ? SKColor.goodBg : SKColor.bg.opacity(0.35), lineWidth: 1))
        .animation(SKAnimation.ios(0.25), value: ok)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ok ? okText : fix)
        .accessibilityValue(ok ? "OK" : "Needs a fix")
    }
}
