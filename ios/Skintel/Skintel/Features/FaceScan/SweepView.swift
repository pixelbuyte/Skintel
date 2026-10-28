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
        // Behind the retake card the camera stays off until Retake.
        if !holding { camera.start() }
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
        camera?.start()
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

/// The sweep (Face Scan Pro v2 "Sweep"): the person sees their own face, mirrored, inside a
/// stadium-shaped portal with a cream ring-light halo and the clay progress ring; Front / Left /
/// Right chips and live checks say where they are and what to fix. An angle locks once every check holds for `SweepCamera.framesToLock` analysed frames
/// (about 0.6 s), or with the shutter. With `retakeIssues`, it opens on the "Let's retake that" card instead.
struct SweepView: View {
    let fullSweep: Bool
    let retakeIssues: [String]?
    /// The Day 1 privacy caption, on the baseline sweep only.
    let showsPrivacyNote: Bool
    let onClose: () -> Void
    let onDone: (SweepImages) -> Void

    @State private var model: SweepModel
    @State private var showRetake: Bool
    @State private var light = SweepScreenLight()
    /// Whether this view turned the idle timer off, so leaving never clears the flow's own.
    @State private var ownsIdleTimer = false
    @Environment(\.scenePhase) private var scenePhase

    init(fullSweep: Bool, retakeIssues: [String]? = nil, showsPrivacyNote: Bool = false,
         onClose: @escaping () -> Void, onDone: @escaping (SweepImages) -> Void) {
        self.fullSweep = fullSweep
        self.retakeIssues = retakeIssues
        self.showsPrivacyNote = showsPrivacyNote
        self.onClose = onClose
        self.onDone = onDone
        _model = State(initialValue: SweepModel(fullSweep: fullSweep, holding: retakeIssues != nil))
        _showRetake = State(initialValue: retakeIssues != nil)
    }

    private let names: [FaceScanImage.Role: String] = [.front: "Front", .left45: "Left", .right45: "Right"]

    private var live: Bool { model.phase == .scanning || model.phase == .done }
    /// The ring light is on while an angle is being looked for.
    private var lightOn: Bool { model.phase == .scanning && !model.holding }

    var body: some View {
        ZStack {
            // A cream screen at full brightness is the ring light; the camera shows in the oval.
            SKColor.bg.ignoresSafeArea()
            content
            if showRetake {
                SKColor.scannerOverlay.ignoresSafeArea()
                retakeCard
                    .skPagePadding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(SKColor.ink)
        .task { await model.start() }
        .onAppear { updateLight() }
        .onDisappear {
            model.stop()
            light.restore()
            if ownsIdleTimer { UIApplication.shared.isIdleTimerDisabled = false }
            ownsIdleTimer = false
        }
        .onChange(of: lightOn) { updateLight() }
        .onChange(of: scenePhase) { updateLight() }
        .onChange(of: model.phase) { _, phase in
            if phase == .done { onDone(model.images) }
        }
    }

    /// The ring light and the idle timer follow the sweep: on while an angle is being looked for
    /// in the foreground, off behind the retake card, after the sweep and in the background.
    private func updateLight() {
        let on = lightOn && scenePhase == .active
        if on { light.raise() } else { light.restore() }
        UIApplication.shared.isIdleTimerDisabled = on
        ownsIdleTimer = on
    }

    private func close() {
        light.restore()
        onClose()
    }

    // MARK: Layout

    private var content: some View {
        GeometryReader { geo in
            // The portal is 300 × 392 on a full-size phone and shrinks on a short one.
            let scale = min(1, max(0.68, (geo.size.height - 400) / 420))
            VStack(spacing: 0) {
                HStack {
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                    Text(kicker).font(SKFont.mono(12)).tracking(1.5).foregroundStyle(SKColor.primary)
                    Spacer()
                    Button { model.restart() } label: {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(SKColor.muted).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Start the sweep again")
                    .disabled(model.holding)
                }
                .padding(.top, SKSpace.md)
                .padding(.leading, SKSpace.sm).padding(.trailing, SKSpace.md)

                Text(title).font(SKFont.serif(34, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    .accessibilityAddTraits(.isHeader)
                    .animation(SKAnimation.ios(0.3), value: title)
                Text(subtitle).font(SKFont.sans(15, weight: hint == nil ? .regular : .semibold, relativeTo: .subheadline))
                    .foregroundStyle(hint == nil ? SKColor.muted : SKColor.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 6)

                Spacer(minLength: SKSpace.md)
                portal(scale: scale)
                Spacer(minLength: SKSpace.md)

                if model.roles.count > 1 {
                    HStack(spacing: SKSpace.sm) {
                        ForEach(Array(model.roles.enumerated()), id: \.offset) { index, role in
                            chip(index: index, role: role)
                        }
                    }
                }
                if model.phase == .scanning {
                    checks.padding(.top, SKSpace.lg)
                    shutter.padding(.top, SKSpace.md)
                }
                Text(showsPrivacyNote ? "Your 3D face shape stays on this phone. Only the photos are read, then deleted. Your Day 1 photo stays on this phone for your week."
                                      : "Your 3D face shape stays on this phone. Only the photos are read, then deleted.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                    .padding(.top, SKSpace.md)
                    .padding(.bottom, SKSpace.lg)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The stadium portal: the camera (or the 3D face before it starts) inside, a cream halo
    /// around it that the full-brightness screen turns into a ring light, and the progress ring.
    private func portal(scale: CGFloat) -> some View {
        let w = 300 * scale, h = 392 * scale
        return ZStack {
            RoundedRectangle(cornerRadius: (h + 52) / 2, style: .continuous)
                .fill(SKColor.cream)
                .frame(width: w + 52, height: h + 52)
                .shadow(color: SKColor.cream.opacity(lightOn ? 0.95 : 0.6), radius: 30)
                .shadow(color: SKColor.ink.opacity(0.08), radius: 22, y: 22)
            RoundedRectangle(cornerRadius: (h + 24) / 2, style: .continuous)
                .stroke(SKColor.line, lineWidth: 1)
                .frame(width: w + 24, height: h + 24)
            Group {
                if live, let session = model.session {
                    SweepPreview(session: session)
                } else {
                    FaceMeshView(mode: .scan, zoom: 0.42, targetYaw: targetYaw, palette: .light)
                        .background(SKColor.clayTileBg)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: w / 2, style: .continuous))
            .accessibilityHidden(true)
            RoundedRectangle(cornerRadius: (h + 24) / 2, style: .continuous)
                .trim(from: 0, to: progress)
                .stroke(SKColor.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: w + 24, height: h + 24)
                .animation(SKAnimation.ios(0.4), value: progress)
            if model.phase == .scanning && model.reading.ready && !model.holding {
                RoundedRectangle(cornerRadius: w / 2, style: .continuous)
                    .stroke(SKColor.goodFg.opacity(0.7), lineWidth: 2)
                    .frame(width: w - 8, height: h - 8)
            }
            Text("CAMERA · MIRRORED")
                .font(SKFont.label).tracking(1).foregroundStyle(SKColor.clayTileFg)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(SKColor.cream.opacity(0.88), in: Capsule())
                .frame(width: w, height: h, alignment: .top)
                .padding(.top, 28)
                .accessibilityHidden(true)
        }
        .frame(width: w + 52, height: h + 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scan progress")
        .accessibilityValue("\(min(model.step, model.roles.count)) of \(model.roles.count) angles")
    }

    private var shutter: some View {
        Button {
            Haptics.tap()
            model.shutter()
        } label: {
            ZStack {
                Circle().stroke(SKColor.primary, lineWidth: 3).frame(width: 66, height: 66)
                Circle().fill(SKColor.primary).frame(width: 54, height: 54)
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
        case .done: return model.roles.count == 1 ? "Got it" : "Got it. Reading your skin"
        default: break
        }
        switch model.currentRole {
        case .left45: return "Slowly turn to your left"
        case .right45: return "Now slowly to your right"
        default: return "Look straight ahead"
        }
    }

    private var subtitle: String {
        switch model.phase {
        case .denied: return "Allow the camera for Skinstel in Settings to scan your face."
        case .unavailable: return "Face scan needs a front camera."
        case .done: return model.roles.count == 1 ? "Reading today's photo" : "Questions next, while it reads"
        case .starting: return "Starting the camera"
        default: break
        }
        if model.holding { return "Phone at eye level, about 35 cm away" }
        if let hint { return hint }
        if model.reading.ready { return "Hold it there" }
        switch model.currentRole {
        case .left45: return "Keep your phone where it is"
        case .right45: return "Almost there"
        default: return "Phone at eye level, about 35 cm away"
        }
    }

    /// What's stopping the angle from locking, live, in the order to fix it. Nil once the camera
    /// sees nothing wrong, so the turn instruction shows.
    private var hint: String? {
        guard model.phase == .scanning else { return nil }
        let r = model.reading
        if r.faceCount == 0 { return "Fit your face in the frame" }
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
            if done {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
            } else if active {
                Circle().fill(SKColor.primary).frame(width: 9, height: 9)
            } else {
                Circle().stroke(SKColor.muted, lineWidth: 1.5).frame(width: 9, height: 9)
            }
            Text(active ? "\(name) · now" : name)
        }
        .font(SKFont.sans(13, weight: .semibold, relativeTo: .footnote))
        .foregroundStyle(done ? SKColor.goodFg : active ? SKColor.ink : SKColor.muted)
        .padding(.leading, 9).padding(.trailing, 12)
        .frame(height: 36)
        .background(done ? SKColor.goodBg : active ? SKColor.cream : .clear, in: Capsule())
        .overlay(Capsule().stroke(done ? SKColor.goodBg : active ? SKColor.primary : SKColor.line, lineWidth: active ? 1.5 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : active ? "Now" : "Waiting")
    }

    // MARK: Checks

    private var checks: some View {
        let r = model.reading
        let distanceFix = r.tooClose ? "Move back" : "Move closer"
        return HStack(spacing: 14) {
            check(ok: r.evenLight, okText: "Even light", fix: "Find light")
            check(ok: r.goodDistance, okText: "35 cm away", fix: distanceFix)
            check(ok: r.oneFace, okText: "One face", fix: r.faceCount == 0 ? "No face yet" : "Only you")
        }
        .padding(.horizontal, SKSpace.lg)
    }

    private func check(ok: Bool, okText: String, fix: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ok ? SKColor.goodFg : SKColor.cautionFg)
                .accessibilityHidden(true)
            Text(ok ? okText : fix).lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(SKColor.ink)
        }
        .font(SKFont.sans(13, relativeTo: .footnote))
        .animation(SKAnimation.ios(0.25), value: ok)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ok ? okText : fix)
        .accessibilityValue(ok ? "OK" : "Needs a fix")
    }
}
