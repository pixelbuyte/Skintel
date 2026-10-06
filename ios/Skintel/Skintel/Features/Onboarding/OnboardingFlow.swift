import SwiftUI
import SkintelCore
import SkinstelMascot

/// Signed-in but not yet profiled: age range, skin profile (§04), then camera permission (§05).
/// Step 1 of the four is the welcome screen shown before sign-in.
struct OnboardingFlow: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: OnboardingViewModel?
    @State private var step = 2

    var body: some View {
        Group {
            if let model {
                switch step {
                case 2:
                    AgeStepView(model: model, next: { withAnimation(SKAnimation.ios()) { step = 3 } })
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                case 3:
                    ProfileStepView(model: model,
                                    back: { withAnimation(SKAnimation.ios()) { step = 2 } },
                                    next: { withAnimation(SKAnimation.ios()) { step = 4 } })
                        .transition(.move(edge: .trailing))
                default:
                    CameraStepView(model: model, back: { withAnimation(SKAnimation.ios()) { step = 3 } })
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
    static let total = 4
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
                ForEach(1...StepHeader.total, id: \.self) { i in
                    Capsule().fill(i <= step ? SKColor.primary : SKColor.line).frame(width: 36, height: 4)
                }
            }
            .accessibilityHidden(true)
            Spacer()
            Text("\(step)/\(StepHeader.total)").font(SKFont.secondary).foregroundStyle(SKColor.muted).frame(width: 44)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step) of \(StepHeader.total)")
    }
}

/// One tap: an age bracket or "Prefer not to say", then it moves on by itself.
struct AgeStepView: View {
    @Bindable var model: OnboardingViewModel
    let next: () -> Void
    @State private var picked = false

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: 2).skPagePadding().padding(.top, SKSpace.sm)
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.xl) {
                    VStack(alignment: .leading, spacing: SKSpace.sm) {
                        Text("How old are you?").font(SKFont.hero).foregroundStyle(SKColor.ink)
                        Text("Skin changes with age. Ask Skintel uses this when it answers you. Optional.")
                            .font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.muted)
                    }
                    .padding(.top, SKSpace.xl)

                    VStack(alignment: .leading, spacing: SKSpace.md) {
                        SKFieldLabel("Age")
                        FlowLayout(spacing: SKSpace.sm) {
                            ForEach(AgeRange.allCases) { a in
                                SKSelectChip(title: a.label, selected: picked && model.ageRange == a) { choose(a) }
                            }
                            SKSelectChip(title: "Prefer not to say", selected: picked && model.ageRange == nil) { choose(nil) }
                        }
                    }
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xxl)
            }
        }
        .onAppear { picked = model.ageRange != nil }
    }

    private func choose(_ age: AgeRange?) {
        model.ageRange = age
        picked = true
        Haptics.selection()
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            next()
        }
    }
}

struct ProfileStepView: View {
    @Bindable var model: OnboardingViewModel
    let back: () -> Void
    let next: () -> Void

    private let columns = [GridItem(.flexible(), spacing: SKSpace.md), GridItem(.flexible(), spacing: SKSpace.md)]

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: 3, back: back).skPagePadding().padding(.top, SKSpace.sm)
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.xl) {
                    VStack(alignment: .leading, spacing: SKSpace.sm) {
                        Text("Tell us about your skin.").font(SKFont.hero).foregroundStyle(SKColor.ink)
                        Text("Ask Skintel uses this to tailor its answers to you.")
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
    @AppStorage(OnboardingOfferView.pendingKey) private var offerPending = false
    @State private var permission: CameraPermission.Status = CameraPermission.status
    @State private var showDenied = false
    @State private var showRestricted = false

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(step: 4, back: back).skPagePadding().padding(.top, SKSpace.sm)
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
                        stepRow(3, "Ingredient verdict in seconds")
                    }

                    Text("Skintel uses the camera to scan barcodes and photograph ingredient labels.")
                        .font(SKFont.secondary).foregroundStyle(SKColor.muted)

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
                SKButton(title: "Continue", isLoading: model.isSaving) {
                    Task { await proceed() }
                }
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.lg)
        }
        .onAppear { permission = CameraPermission.status }
        .alert("Camera is off for Skintel", isPresented: $showDenied) {
            Button("Open Settings") { CameraPermission.openSettings() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("You can still add products by pasting the ingredient list. Turn the camera on in Settings whenever you're ready to scan.")
        }
        .alert("Camera access is restricted", isPresented: $showRestricted) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device doesn't allow Skintel to use the camera. You can still add products by pasting the ingredient list.")
        }
    }

    /// A neutral "Continue" always moves onboarding forward — it never blocks on the
    /// camera. It triggers the native prompt only when status is still undetermined
    /// (never re-prompts after a denial or restriction). Denied gets an explanation plus
    /// an Open Settings action that will actually fix it; restricted gets an explanation
    /// only — Settings can't reliably lift a device restriction, so we don't imply it will.
    private func proceed() async {
        if permission == .notDetermined {
            permission = await CameraPermission.request()
        }
        switch permission {
        case .denied: showDenied = true
        case .restricted: showRestricted = true
        case .notDetermined, .authorized: break
        }
        // The Skintel+ offer shows once, between this step and the app (see `RootView`).
        // Set first so "Skip for now" after a failed save still passes through it.
        offerPending = true
        _ = await model.complete()
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

// MARK: - Skintel+ offer

/// One screen between the last onboarding step and the app, for accounts that aren't
/// Skintel+ yet. What it offers comes from StoreKit, never assumed:
/// 1. a free trial, only when the yearly or monthly plan has an introductory free-trial
///    offer AND this Apple ID can still take it;
/// 2. otherwise the founding deal, while it is on sale;
/// 3. otherwise the regular plan.
/// Prices are StoreKit's `displayPrice`. Buying goes through `SubscriptionService.purchase`,
/// and Skintel+ only unlocks once the server confirms it. "Continue with Free" is always on
/// screen.
struct OnboardingOfferView: View {
    /// Set as onboarding finishes; cleared when this screen is done with (see `RootView`).
    static let pendingKey = "onboarding.offerPending"

    let done: () -> Void

    @Environment(AppEnvironment.self) private var env
    /// False while the membership is checked, so a member never sees the offer.
    @State private var ready = false
    @State private var loaded = false
    @State private var offer: Offer? = nil
    @State private var attempt = 0
    @State private var finished = false

    enum Offer {
        case trial(SubscriptionService.ProductID, SubscriptionService.FreeTrial)
        case founding
        case plan(SubscriptionService.ProductID)

        var productID: SubscriptionService.ProductID {
            switch self {
            case .trial(let id, _), .plan(let id): id
            case .founding: .founding
            }
        }
    }

    private static let benefitLines: [(icon: String, text: String)] = [
        ("viewfinder", "Scan a barcode, label photo or product link"),
        ("sparkles", "Ask Skintel, answered from your shelf"),
        ("checkmark.shield", "Triggers, Insights, Compare and an unlimited shelf"),
    ]

    private var service: SubscriptionService { env.subscriptionService }

    var body: some View {
        Group {
            if ready { screen } else { SplashView() }
        }
        .task(id: attempt) {
            if attempt == 0 {
                await env.subscription.confirmIfUnsure()
                if env.subscription.entitlement.isPro { finish(); return }
                ready = true
                env.analytics.track(.paywallViewed(reason: "onboarding"))
            }
            loaded = false
            let s = env.subscriptionService
            s.startObserving()
            async let p: () = s.loadProducts()
            async let f: () = env.subscription.loadFoundingSeats()
            _ = await (p, f)
            offer = await resolveOffer(s)
            loaded = true
        }
        .onChange(of: env.subscription.entitlement.isPro) { _, isPro in
            if isPro { finish() }
        }
    }

    /// Trial first (yearly, then monthly), then the founding deal, then the plain plan.
    private func resolveOffer(_ s: SubscriptionService) async -> Offer? {
        for id in [SubscriptionService.ProductID.proYearly, .proMonthly] {
            if let trial = await s.eligibleFreeTrial(id) { return .trial(id, trial) }
        }
        if s.product(.founding) != nil, (env.subscription.foundingSeatsRemaining ?? 1) > 0 { return .founding }
        if s.product(.proYearly) != nil { return .plan(.proYearly) }
        if s.product(.proMonthly) != nil { return .plan(.proMonthly) }
        return nil
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        done()
    }

    // MARK: Screen

    private var screen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SKSpace.lg) {
                    SKMascot(action: .wave, height: 128, settleAfter: .seconds(3))
                        .accessibilityHidden(true)
                    VStack(spacing: SKSpace.sm) {
                        Text("Skintel+")
                            .font(SKFont.mono(11, relativeTo: .caption))
                            .textCase(.uppercase)
                            .tracking(2)
                            .foregroundStyle(SKColor.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(SKColor.blush, in: Capsule())
                        Text(title)
                            .font(SKFont.hero)
                            .foregroundStyle(SKColor.ink)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                    }
                    benefits
                    price
                }
                .frame(maxWidth: .infinity)
                .skPagePadding()
                .padding(.top, SKSpace.xl)
                .padding(.bottom, SKSpace.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            actions
        }
        .skPageBackground()
    }

    private var title: String {
        guard let offer else { return "Meet Skintel+." }
        switch offer {
        case .trial: return "Try Skintel+ free."
        case .founding: return "The founding member deal."
        case .plan: return "Meet Skintel+."
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            ForEach(Self.benefitLines.indices, id: \.self) { i in
                HStack(spacing: SKSpace.md) {
                    Image(systemName: Self.benefitLines[i].icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SKColor.primary)
                        .frame(width: 34, height: 34)
                        .background(SKColor.blush, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                    Text(Self.benefitLines[i].text)
                        .font(SKFont.sans(16, relativeTo: .body))
                        .foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(SKSpace.lg)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
    }

    /// The offer's price, straight from StoreKit.
    @ViewBuilder
    private var price: some View {
        if !loaded {
            SKSkeleton(height: 96)
        } else if let offer {
            VStack(spacing: SKSpace.xs) {
                switch offer {
                case .trial(let id, let trial):
                    Text("\(trial.length) free")
                        .font(SKFont.serif(44, relativeTo: .largeTitle))
                        .foregroundStyle(SKColor.ink)
                    Text("then \(service.priceText(id) ?? "")\(service.periodText(id))")
                        .font(SKFont.sans(16, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(SKColor.primary)
                case .founding:
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(service.priceText(.founding) ?? "").font(SKFont.price).foregroundStyle(SKColor.ink)
                        Text("once").font(SKFont.sans(18, relativeTo: .title3)).foregroundStyle(SKColor.muted)
                    }
                    Text("Three months of Skintel+ · nothing renews")
                        .font(SKFont.sans(16, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(SKColor.primary)
                case .plan(let id):
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(service.priceText(id) ?? "").font(SKFont.price).foregroundStyle(SKColor.ink)
                        Text(service.periodText(id)).font(SKFont.sans(18, relativeTo: .title3)).foregroundStyle(SKColor.muted)
                    }
                    Text(id == .proYearly ? "Skintel+ Yearly · cancel anytime" : "Skintel+ Monthly · cancel anytime")
                        .font(SKFont.sans(16, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(SKColor.primary)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: SKSpace.md) {
                SKInlineError(message: unavailableMessage)
                SKButton(title: "Try Again", kind: .secondary) { attempt += 1 }
            }
        }
    }

    private var unavailableMessage: String {
        switch service.phase {
        case .unavailable(let msg), .failed(let msg): msg
        default: "Plans are unavailable right now. You can get Skintel+ later from You."
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: SKSpace.sm) {
            if let msg = service.lastMessage {
                Text(msg).font(SKFont.secondary).foregroundStyle(SKColor.cautionFg).multilineTextAlignment(.center)
            }
            if case .failed(let msg) = service.phase, offer != nil {
                SKInlineError(message: msg)
            }
            if let offer, loaded {
                SKButton(title: primaryTitle(offer), isLoading: isBusy) {
                    Haptics.tap()
                    Task { await service.purchase(offer.productID) }
                }
                Text(smallPrint(offer))
                    .font(SKFont.caption)
                    .foregroundStyle(SKColor.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            SKButton(title: "Continue with Free", kind: .secondary) { finish() }
            footer
        }
        .skPagePadding()
        .padding(.top, SKSpace.md)
        .padding(.bottom, SKSpace.sm)
        .background {
            SKColor.bg
                .overlay(alignment: .top) { Rectangle().fill(SKColor.line).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func primaryTitle(_ offer: Offer) -> String {
        switch offer {
        case .trial: "Start free trial"
        case .founding, .plan: "Get Skintel+"
        }
    }

    /// The terms beside the button: what is charged, when, and how to stop it.
    private func smallPrint(_ offer: Offer) -> String {
        switch offer {
        case .trial(_, let trial):
            "\(trial.terms) Renews automatically until cancelled. Cancel anytime in Settings, at least 24 hours before the trial ends, to avoid being charged."
        case .founding:
            "One payment. Skintel+ ends after three months and never renews."
        case .plan(let id):
            "\(service.priceText(id) ?? "")\(service.periodText(id)), renews automatically until cancelled. Cancel anytime in Settings, at least 24 hours before the period ends, to avoid renewal."
        }
    }

    private var isBusy: Bool {
        switch service.phase {
        case .purchasing, .verifying, .restoring: true
        default: false
        }
    }

    private var footer: some View {
        HStack(spacing: SKSpace.xl) {
            Button("Restore") { Task { await service.restore() } }
            Link("Terms", destination: env.config.termsURL)
            Link("Privacy", destination: env.config.privacyURL)
        }
        .font(SKFont.sans(14, weight: .medium)).foregroundStyle(SKColor.muted).underline()
        .padding(.top, SKSpace.xs)
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
