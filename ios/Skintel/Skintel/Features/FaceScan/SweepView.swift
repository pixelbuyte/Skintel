import Observation
import SwiftUI
import SkintelCore

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
    private var camera: SweepCamera?

    init(fullSweep: Bool) {
        roles = fullSweep ? [.front, .left45, .right45] : [.front]
    }

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

    private func aim() {
        if let role = currentRole {
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

/// The dark scanner (canvas screen 3): the face mesh with a scan line, an oval progress ring,
/// angle chips and corner brackets. The camera runs behind it; the person sees the mesh, not
/// their photo.
struct SweepView: View {
    let fullSweep: Bool
    let onClose: () -> Void
    let onDone: (SweepImages) -> Void

    @State private var model: SweepModel

    init(fullSweep: Bool, onClose: @escaping () -> Void, onDone: @escaping (SweepImages) -> Void) {
        self.fullSweep = fullSweep
        self.onClose = onClose
        self.onDone = onDone
        _model = State(initialValue: SweepModel(fullSweep: fullSweep))
    }

    private let names: [FaceScanImage.Role: String] = [.front: "Centre", .left45: "Left 45°", .right45: "Right 45°"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(kicker).font(SKFont.mono(12)).tracking(1.5)
                Spacer()
                Button { model.restart() } label: {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SKColor.bg.opacity(0.7)).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Start the sweep again")
            }
            .padding(.top, SKSpace.md)
            .padding(.horizontal, SKSpace.sm)

            Text(title).font(SKFont.serif(34, relativeTo: .largeTitle)).multilineTextAlignment(.center)
                .padding(.horizontal, 30).padding(.top, 14)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(SKFont.sans(15, relativeTo: .subheadline)).foregroundStyle(SKColor.bg.opacity(0.72))
                .multilineTextAlignment(.center).padding(.top, SKSpace.sm).padding(.horizontal, SKSpace.xl)

            ZStack {
                FaceMeshView(mode: .scan, zoom: 0.4, targetYaw: targetYaw)
                Ellipse().stroke(SKColor.bg.opacity(0.12), lineWidth: 6).padding(14)
                Ellipse().trim(from: 0, to: progress)
                    .stroke(SKColor.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(14)
                    .animation(SKAnimation.ios(0.4), value: progress)
                brackets
            }
            .frame(width: 300, height: 380)
            .padding(.top, SKSpace.xl)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Scan progress")
            .accessibilityValue("\(min(model.step, model.roles.count)) of \(model.roles.count) angles")

            HStack(spacing: SKSpace.sm) {
                ForEach(Array(model.roles.enumerated()), id: \.offset) { index, role in
                    chip(index: index, role: role)
                }
            }
            .padding(.top, 24)

            checks.padding(.top, 20)
            Spacer(minLength: SKSpace.lg)
            Text("The 3D face is a model, not a scan of you. Day 1 close-ups stay on this phone until Day 7, then are deleted.")
                .font(SKFont.caption).foregroundStyle(SKColor.bg.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 40).padding(.bottom, 30)
        }
        .foregroundStyle(SKColor.bg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SKColor.scannerBg.ignoresSafeArea())
        .task { await model.start() }
        .onDisappear { model.stop() }
        .onChange(of: model.phase) { _, phase in
            if phase == .done { onDone(model.images) }
        }
    }

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
        return n == 1 ? "TODAY'S PHOTO" : "ANGLE \(model.step + 1) OF \(n)"
    }

    private var title: String {
        switch model.phase {
        case .denied: return "Camera is off"
        case .unavailable: return "No front camera"
        case .done: return "Got it. Reading your skin"
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
        case .denied: return "Allow the camera for Skintel in Settings to scan your face."
        case .unavailable: return "Face scan needs a front camera."
        case .done: return "Usually under a minute"
        default: break
        }
        switch model.currentRole {
        case .left45: return "Keep your phone where it is"
        case .right45: return "Almost there"
        default: return "Phone at eye level, about 35 cm away"
        }
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
        .foregroundStyle(done || active ? SKColor.cream : SKColor.bg.opacity(0.72))
        .padding(.horizontal, SKSpace.md).padding(.vertical, SKSpace.sm)
        .background(done ? SKColor.primary : active ? SKColor.primary.opacity(0.25) : Color.clear, in: Capsule())
        .overlay(Capsule().stroke(done || active ? SKColor.primary : SKColor.bg.opacity(0.3), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : active ? "Now" : "Waiting")
    }

    private var checks: some View {
        HStack(spacing: SKSpace.lg) {
            check("Even light", model.reading.evenLight)
            check("35 cm away", model.reading.goodDistance)
            check("One face", model.reading.oneFace)
        }
        .font(SKFont.sans(13, relativeTo: .footnote))
        .foregroundStyle(SKColor.bg.opacity(0.8))
    }

    private func check(_ text: String, _ ok: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark" : "circle.dotted").font(.system(size: 11, weight: .bold))
                .foregroundStyle(ok ? SKColor.goodBg : SKColor.bg.opacity(0.5))
            Text(text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(ok ? "OK" : "Not yet")
    }

    private var brackets: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, len: CGFloat = 26
            Path { p in
                p.move(to: CGPoint(x: -6, y: -6 + len)); p.addLine(to: CGPoint(x: -6, y: -6)); p.addLine(to: CGPoint(x: -6 + len, y: -6))
                p.move(to: CGPoint(x: w + 6 - len, y: -6)); p.addLine(to: CGPoint(x: w + 6, y: -6)); p.addLine(to: CGPoint(x: w + 6, y: -6 + len))
                p.move(to: CGPoint(x: -6, y: h + 6 - len)); p.addLine(to: CGPoint(x: -6, y: h + 6)); p.addLine(to: CGPoint(x: -6 + len, y: h + 6))
                p.move(to: CGPoint(x: w + 6 - len, y: h + 6)); p.addLine(to: CGPoint(x: w + 6, y: h + 6)); p.addLine(to: CGPoint(x: w + 6, y: h + 6 - len))
            }
            .stroke(SKColor.bg.opacity(0.6), lineWidth: 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
