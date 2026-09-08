import SwiftUI
import SkintelCore

/// Signed-in but not yet profiled: skin profile (§04) then camera permission (§05).
/// Step 1 of the design's three is the welcome screen shown before sign-in.
struct OnboardingFlow: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: OnboardingViewModel?
    @State private var step = 2

    var body: some View {
        Group {
            if let model {
                switch step {
                case 2:
                    ProfileStepView(model: model, next: { withAnimation(SKAnimation.ios()) { step = 3 } })
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                default:
                    CameraStepView(model: model, back: { withAnimation(SKAnimation.ios()) { step = 2 } })
                        .transition(.move(edge: .trailing))
                }
            } else {
                SplashView()
            }
        }
        .skPageBackground()
        .onAppear {
            if model == nil { model = OnboardingViewModel(session: env.session, analytics: env.analytics) }
        }
    }
}

private struct StepHeader: View {
    let step: Int
    var back: (() -> Void)?

    var body: some View {
        HStack {
            if let back {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SKColor.ink).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { i in
                    Capsule().fill(i <= step ? SKColor.primary : SKColor.line).frame(width: 36, height: 4)
                }
            }
            .accessibilityHidden(true)
            Spacer()
            Text("\(step)/3").font(SKFont.secondary).foregroundStyle(SKColor.muted).frame(width: 44)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step) of 3")
    }
}

struct ProfileStepView: View {
    @Bindable var model: OnboardingViewModel
    let next: () -> Void

    private let columns = [GridItem(.flexible(), spacing: SKSpace.md), GridItem(.flexible(), spacing: SKSpace.md)]

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: 2).skPagePadding().padding(.top, SKSpace.sm)
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.xl) {
                    VStack(alignment: .leading, spacing: SKSpace.sm) {
                        Text("Tell us about your skin.").font(SKFont.hero).foregroundStyle(SKColor.ink)
                        Text("Every verdict is matched against this profile.")
                            .font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                    }
                    .padding(.top, SKSpace.xl)

                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        SKFieldLabel("Skin type")
                        FlowLayout(spacing: SKSpace.sm) {
                            ForEach(SkinType.allCases) { t in
                                SKSelectChip(title: t.label, selected: model.skinType == t) {
                                    model.skinType = t
                                    Haptics.selection()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        SKFieldLabel("Concerns · pick any")
                        LazyVGrid(columns: columns, spacing: SKSpace.md) {
                            ForEach(SkinConcern.allCases) { c in
                                SKSelectCard(title: c.label, selected: model.concerns.contains(c)) { model.toggle(c) }
                            }
                        }
                    }
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
            }
            SKButton(title: "Continue", action: next)
                .disabled(!model.canContinue)
                .skPagePadding()
                .padding(.bottom, SKSpace.lg)
        }
    }
}

struct CameraStepView: View {
    @Bindable var model: OnboardingViewModel
    let back: () -> Void
    @AppStorage("onboarding.skipped") private var onboardingSkipped = false
    @State private var showDenied = false

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: 3, back: back).skPagePadding().padding(.top, SKSpace.sm)
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.xl) {
                    Text("Scan your first product.").font(SKFont.hero).foregroundStyle(SKColor.ink).padding(.top, SKSpace.xl)

                    ScannerIllustration()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [SKColor.cream, SKColor.bg], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SKSpace.lg) {
                        stepRow(1, "Point at any barcode — front or back")
                        stepRow(2, "AI reads the full ingredient list")
                        stepRow(3, "Verdict for your skin in seconds")
                    }

                    if let error = model.error {
                        SKInlineError(message: error)
                        SKButton(title: "Skip for now", kind: .ghost) {
                            onboardingSkipped = true
                        }
                    }
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
            }
            VStack(spacing: SKSpace.sm) {
                SKButton(title: "Allow camera access", systemImage: "camera", isLoading: model.isSaving) {
                    Task {
                        let status = await CameraPermission.request()
                        if status == .denied { showDenied = true }
                        _ = await model.complete()
                    }
                }
                SKButton(title: "Maybe later", kind: .ghost, isLoading: false) {
                    Task { _ = await model.complete() }
                }
                .disabled(model.isSaving)
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.lg)
        }
        .alert("Camera is off for Skintel", isPresented: $showDenied) {
            Button("Open Settings") { CameraPermission.openSettings() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("You can still add products by pasting the ingredient list. Turn the camera on in Settings whenever you're ready to scan.")
        }
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(spacing: SKSpace.lg) {
            Text("\(n)")
                .font(SKFont.mono(12, relativeTo: .caption))
                .foregroundStyle(SKColor.goodFg)
                .frame(width: 28, height: 28)
                .background(SKColor.goodBg, in: Circle())
            Text(text).font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
        }
    }
}

/// Bracketed viewfinder with a breathing terracotta scan line (design §05/§08).
struct ScannerIllustration: View {
    var brackets: Color = SKColor.primary
    var line: Color = SKColor.primary
    @State private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: 0xD6E0EA))
                .frame(width: 84, height: 120)
                .overlay {
                    RoundedRectangle(cornerRadius: 6).fill(SKColor.cream).frame(width: 56, height: 24)
                        .overlay {
                            HStack(spacing: 2) {
                                ForEach(0..<9, id: \.self) { i in
                                    Rectangle().fill(SKColor.ink).frame(width: i % 3 == 0 ? 2.5 : 1.2, height: 12)
                                }
                            }
                        }
                }
            ViewfinderBrackets(color: brackets).frame(width: 164, height: 128)
            Capsule()
                .fill(LinearGradient(colors: [line.opacity(0), line, line.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 150, height: 3)
                .shadow(color: line.opacity(0.6), radius: 6)
                .offset(y: reduceMotion ? 0 : (phase ? 30 : -30))
                .opacity(phase ? 1 : 0.65)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { phase = true }
        }
    }
}

struct ViewfinderBrackets: View {
    var color: Color = .white
    var lineWidth: CGFloat = 3
    var corner: CGFloat = 22
    var length: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                // top-left
                p.move(to: CGPoint(x: 0, y: length + corner))
                p.addLine(to: CGPoint(x: 0, y: corner))
                p.addQuadCurve(to: CGPoint(x: corner, y: 0), control: .zero)
                p.addLine(to: CGPoint(x: corner + length, y: 0))
                // top-right
                p.move(to: CGPoint(x: w - corner - length, y: 0))
                p.addLine(to: CGPoint(x: w - corner, y: 0))
                p.addQuadCurve(to: CGPoint(x: w, y: corner), control: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: corner + length))
                // bottom-right
                p.move(to: CGPoint(x: w, y: h - corner - length))
                p.addLine(to: CGPoint(x: w, y: h - corner))
                p.addQuadCurve(to: CGPoint(x: w - corner, y: h), control: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w - corner - length, y: h))
                // bottom-left
                p.move(to: CGPoint(x: corner + length, y: h))
                p.addLine(to: CGPoint(x: corner, y: h))
                p.addQuadCurve(to: CGPoint(x: 0, y: h - corner), control: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: 0, y: h - corner - length))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Wrapping row of chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
