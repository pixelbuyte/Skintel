import StoreKit
import SwiftUI
import SkintelCore

/// Design §16 with the shipped offer: the founding deal ($20 once, three months, 500
/// seats) featured while seats remain, Pro monthly/yearly underneath. Every price shown
/// comes from StoreKit's localized `displayPrice`.
struct PaywallView: View {
    let reason: PaywallReason
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var service: SubscriptionService?
    @State private var selected: SubscriptionService.ProductID = .founding

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SKSpace.lg) {
                    header
                    if env.subscription.entitlement.isPro {
                        alreadyPro
                        benefits
                    } else if let service {
                        plans(service)
                        benefits
                        cta(service)
                    } else {
                        SKLoadingView(message: "Loading plans…").frame(height: 200)
                    }
                    footer
                }
                .skPagePadding()
                .padding(.bottom, SKSpace.xl)
            }
            .skPageBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)) }
                        .accessibilityLabel("Close")
                }
            }
        }
        .tint(SKColor.primary)
        .task {
            env.analytics.track(.paywallViewed(reason: reason.rawValue))
            let s = env.subscriptionService
            service = s
            s.startObserving()
            async let p: () = s.loadProducts()
            async let f: () = env.subscription.loadFoundingSeats()
            _ = await (p, f)
            if (env.subscription.foundingSeatsRemaining ?? 1) <= 0 || s.product(.founding) == nil { selected = .proYearly }
        }
        .onChange(of: env.subscription.entitlement.isPro) { _, isPro in
            if isPro { Task { try? await Task.sleep(for: .seconds(1.2)); dismiss() } }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: SKSpace.md) {
            if !env.subscription.entitlement.isPro {
                if reason == .general {
                    MascotUpgradeHero().padding(.bottom, SKSpace.sm)
                } else {
                    FeatureDemo(reason: reason).padding(.bottom, SKSpace.sm)
                }
            }
            Text("Skintel Pro").font(SKFont.mono(11)).textCase(.uppercase).tracking(2).foregroundStyle(SKColor.primary)
                .padding(.horizontal, 14).padding(.vertical, 7).background(SKColor.blush, in: Capsule())
            Text(headline).font(SKFont.serif(38, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink).multilineTextAlignment(.center)
            Text(reasonLine).font(SKFont.sans(16, relativeTo: .body)).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
        }
        .padding(.top, SKSpace.md)
    }

    private var headline: String {
        (env.subscription.foundingSeatsRemaining ?? 1) > 0 ? "The founding member deal." : "Everything, for your skin."
    }

    private var reasonLine: String {
        switch reason {
        case .scanner: "Barcode, label and link scanning run through Skintel's AI."
        case .productLimit: "Free shelves hold five products. Pro shelves are unlimited."
        case .compare: "Side-by-side verdicts are a Pro feature."
        case .recommend: "Personal picks are built from your full history."
        case .routine: "Conflict checks read every step of your routine."
        case .journalAnalysis, .culprits: "Journal analysis correlates 90 days of entries with your shelf."
        case .assistant: "Ask Skintel answers from your shelf, routine and check-ins, and adds products you mention to your shelf."
        case .general: "Unlimited scans, culprit detection on your full history, and more."
        }
    }

    private func plans(_ s: SubscriptionService) -> some View {
        VStack(spacing: SKSpace.md) {
            if s.products.isEmpty, let msg = emptyProductsMessage(s.phase) {
                SKCard { VStack(alignment: .leading, spacing: SKSpace.md) { SKInlineError(message: msg); SKButton(title: "Try Again", kind: .secondary) { Task { await s.loadProducts() } } } }
            } else if s.products.isEmpty {
                SKSkeleton(height: 180); SKSkeleton(height: 72); SKSkeleton(height: 72)
            } else {
                let seats = env.subscription.foundingSeatsRemaining
                if let founding = s.product(.founding), (seats ?? 1) > 0 {
                    foundingCard(founding, seats: seats)
                }
                if let monthly = s.product(.proMonthly) { planRow(.proMonthly, product: monthly, caption: "Cancel anytime") }
                if let yearly = s.product(.proYearly) { planRow(.proYearly, product: yearly, caption: yearlyCaption(s)) }
            }
        }
    }

    private func yearlyCaption(_ s: SubscriptionService) -> String {
        if let m = s.product(.proMonthly), let y = s.product(.proYearly) {
            let saving = (m.price * 12) - y.price
            if saving > 0 { return "Save \(saving.formatted(.currency(code: y.priceFormatStyle.currencyCode))) a year" }
        }
        return "Billed yearly"
    }

    private func foundingCard(_ p: StoreKit.Product, seats: Int?) -> some View {
        let taken = Entitlement.foundingSeatsTotal - (seats ?? Entitlement.foundingSeatsTotal)
        return Button { selected = .founding; Haptics.selection() } label: {
            VStack(spacing: SKSpace.md) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(p.displayPrice).font(SKFont.price).foregroundStyle(SKColor.ink)
                    Text("once").font(SKFont.sans(18, relativeTo: .title3)).foregroundStyle(SKColor.muted)
                }
                Text("Three months of Pro · nothing renews").font(SKFont.sans(16, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.primary)
                SKProgressBar(fraction: Double(taken) / Double(Entitlement.foundingSeatsTotal), height: 8)
                Text(seats.map { "\(taken) of \(Entitlement.foundingSeatsTotal) founding spots taken · \($0) left" } ?? "500 founding spots")
                    .font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
            }
            .padding(SKSpace.xl)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [SKColor.cream, SKColor.blush], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                .stroke(selected == .founding ? SKColor.primary : SKColor.line, lineWidth: selected == .founding ? 1.5 : 1))
            .skCardShadow()
        }
        .buttonStyle(SKPressStyle())
        .accessibilityAddTraits(selected == .founding ? [.isButton, .isSelected] : .isButton)
    }

    private func planRow(_ id: SubscriptionService.ProductID, product: StoreKit.Product, caption: String) -> some View {
        Button { selected = id; Haptics.selection() } label: {
            HStack(spacing: SKSpace.md) {
                Circle().stroke(selected == id ? SKColor.primary : SKColor.line, lineWidth: 1.5).frame(width: 22, height: 22)
                    .overlay { if selected == id { Circle().fill(SKColor.primary).frame(width: 12, height: 12) } }
                VStack(alignment: .leading, spacing: 2) {
                    Text(id == .proMonthly ? "Pro Monthly" : "Pro Yearly").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Text(caption).font(SKFont.caption).foregroundStyle(SKColor.muted)
                }
                Spacer()
                (Text(product.displayPrice).font(SKFont.sans(17, weight: .semibold)) + Text(" \(service?.periodText(id) ?? "")").font(SKFont.secondary))
                    .foregroundStyle(SKColor.ink)
            }
            .padding(SKSpace.lg)
            .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                .stroke(selected == id ? SKColor.primary : SKColor.line, lineWidth: selected == id ? 1.5 : 1))
        }
        .buttonStyle(SKPressStyle())
        .accessibilityAddTraits(selected == id ? [.isButton, .isSelected] : .isButton)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            Text("Everything in Pro · tap to watch").skLabelStyle()
            ProBenefitsList()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, SKSpace.sm)
    }

    private func cta(_ s: SubscriptionService) -> some View {
        VStack(spacing: SKSpace.md) {
            if let msg = s.lastMessage { Text(msg).font(SKFont.secondary).foregroundStyle(SKColor.cautionFg).multilineTextAlignment(.center) }
            if case .failed(let msg) = s.phase, !s.products.isEmpty { SKInlineError(message: msg) }
            SKButton(title: ctaTitle(s), kind: .dark, isLoading: isBusy(s.phase)) { Task { await s.purchase(selected) } }
                .disabled(s.product(selected) == nil)
            if selected != .founding {
                Text("Auto-renews until cancelled in App Store settings. Cancel at least 24 hours before the period ends to avoid renewal.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
            } else {
                Text("One payment. Pro ends after three months and never renews. 14-day refund via Apple.")
                    .font(SKFont.caption).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
            }
        }
        .padding(.top, SKSpace.sm)
    }

    private func ctaTitle(_ s: SubscriptionService) -> String {
        guard let p = s.product(selected) else { return "Unavailable" }
        switch selected {
        case .founding: return "Join · \(p.displayPrice) once"
        case .proMonthly: return "Subscribe · \(p.displayPrice)/mo"
        case .proYearly: return "Subscribe · \(p.displayPrice)/yr"
        }
    }

    private func isBusy(_ p: SubscriptionService.Phase) -> Bool {
        switch p {
        case .purchasing, .verifying, .restoring: true
        default: false
        }
    }

    /// Both an empty-but-not-thrown StoreKit response and a thrown load error land here
    /// with the same "empty state + retry" card - they just carry different copy, so the
    /// distinction upstream is preserved without duplicating this view.
    private func emptyProductsMessage(_ p: SubscriptionService.Phase) -> String? {
        switch p {
        case .unavailable(let msg), .failed(let msg): msg
        default: nil
        }
    }

    private var alreadyPro: some View {
        SKCard(tint: .good) {
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                Text("You're on \(env.subscription.entitlement.tierLabel)").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                if let end = env.subscription.entitlement.periodEnd {
                    Text("Active until \(end.formatted(date: .abbreviated, time: .omitted)).").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                } else {
                    Text("Everything is unlocked.").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: SKSpace.xl) {
            Button("Restore") { Task { await service?.restore() } }
            Link("Terms", destination: env.config.termsURL)
            Link("Privacy", destination: env.config.privacyURL)
        }
        .font(SKFont.sans(14, weight: .medium)).foregroundStyle(SKColor.muted).underline()
        .padding(.top, SKSpace.sm)
    }
}

// MARK: - Feature demos

/// A looping demo of a Pro feature with sample data, so people see what they would get
/// before they pay. Reduce Motion shows the finished frame.
struct FeatureDemo: View {
    let reason: PaywallReason
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0
    /// Demos with several stories (Ask) move to the next one after each full loop.
    @State private var scene = 0
    @State private var sweep = false

    private var sceneCount: Int { reason == .assistant ? 3 : 1 }

    private let picks = [("Barrier Cream", "Ceramides, no fragrance", "$18"),
                         ("Daily Gel SPF 40", "Oil-free, zinc", "$24"),
                         ("Calm Toner", "Panthenol, no alcohol", "$16")]
    private let shelfItems = ["Gentle Cleanser", "Niacinamide Serum", "Barrier Cream", "Daily SPF 50", "Retinol 0.3%", "Calm Toner"]

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            HStack {
                Text("DEMO · SAMPLE DATA").font(SKFont.label).tracking(1.2).foregroundStyle(SKColor.muted)
                Spacer()
                Text(caption).font(SKFont.sans(12, weight: .semibold, relativeTo: .caption)).foregroundStyle(SKColor.primary)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(SKSpace.lg)
        .frame(height: reason == .assistant ? 320 : (reason == .journalAnalysis || reason == .culprits ? 300 : 290))
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(SKColor.line))
        .skSoftShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Demo with sample data. \(summary)")
        .task {
            if reduceMotion { phase = 3; return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { sweep = true }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(phase == 3 ? 2.2 : 1.5))
                withAnimation(SKAnimation.emil(0.6)) {
                    if phase == 3 { scene = (scene + 1) % sceneCount }
                    phase = (phase + 1) % 4
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch reason {
        case .journalAnalysis, .culprits: journalDemo
        case .scanner: scanDemo
        case .compare: compareDemo
        case .recommend: recommendDemo
        case .routine: routineDemo
        case .assistant: askDemo
        case .productLimit, .general: shelfDemo
        }
    }

    private var caption: String {
        let steps: [String]
        switch reason {
        case .journalAnalysis, .culprits: steps = ["Reading check-ins…", "Your last 7 days", "When products joined", "Pattern found"]
        case .scanner: steps = ["Point at a barcode", "Scanning…", "Found it", "Verdict for your skin"]
        case .compare: steps = ["Two cleansers", "Scoring both…", "Against your triggers", "Clear winner"]
        case .recommend: steps = ["Reading your shelf…", "Pick 1", "Pick 2", "Three that fit"]
        case .routine: steps = ["Your night routine", "Checking each step…", "Conflict found", "How to fix it"]
        case .assistant:
            steps = [["Tag from your shelf", "Reading its ingredients…", "About that product", "Answered from your shelf"],
                     ["Mention a product", "Thinking…", "Not on your shelf yet", "Added to your shelf"],
                     ["Ask about a product", "Checking your shelf…", "Already on your shelf", "No duplicate added"]][scene % 3]
        case .productLimit, .general: steps = ["Your shelf", "Adding products", "Free holds five", "Unlimited with Pro"]
        }
        return steps[phase]
    }

    private var summary: String {
        switch reason {
        case .journalAnalysis, .culprits: "Skintel lines up a week of check-ins with when each product joined the shelf and finds that breakouts followed a new toner."
        case .scanner: "A barcode scan returns a verdict of 86, clean, with no match to your triggers."
        case .compare: "Two cleansers are scored against your triggers and the gentler one wins."
        case .recommend: "Three product picks that avoid what broke you out."
        case .routine: "A night routine check flags retinol and glycolic acid on the same night."
        case .assistant: "Tag a shelf product and Ask Skintel reads its ingredients; mention a new product and it offers to add it; mention one you already have and it knows it's on your shelf."
        case .productLimit, .general: "A free shelf holds five products; Pro is unlimited."
        }
    }

    // MARK: Demos

    /// A week of check-ins over three shelf products: the new toner joins, bad days follow.
    private var journalDemo: some View {
        let days: [PatternDay] = [.good, .good, .okay, .bad, .bad, .okay, .good]
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.patternLabelWidth)
                ForEach(days.indices, id: \.self) { i in
                    let shown = phase >= 1 || i < 2
                    VStack(spacing: 4) {
                        Circle()
                            .fill(shown ? days[i].color : SKColor.neutralChip)
                            .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center)))
                            .background {
                                if shown, days[i] == .bad, phase >= 3 {
                                    Circle().fill(days[i].color.opacity(0.22)).scaleEffect(1.45)
                                }
                            }
                            .frame(width: 22, height: 22)
                            .scaleEffect(shown ? 1 : 0.8)
                        Text(Self.weekdays[i]).font(SKFont.mono(9, relativeTo: .caption2)).foregroundStyle(SKColor.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 8) {
                patternRow("Cleanser", art: ProductArt.pump, from: 0, hot: false)
                patternRow("Moisturiser", art: ProductArt.tube, from: 0, hot: false)
                patternRow("New toner", art: ProductArt.dropper, from: 2, hot: phase >= 3)
            }
            .opacity(phase >= 2 ? 1 : 0.35)
            Spacer(minLength: 0)
            patternFinding
        }
    }

    private static let patternLabelWidth: CGFloat = 112
    private static let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    private enum PatternDay {
        case good, okay, bad
        var color: Color {
            switch self {
            case .good: Color(hex: 0x6F9B63)
            case .okay: Color(hex: 0xD9A857)
            case .bad: SKColor.primary
            }
        }
    }

    /// Bottle, name, and a bar from the day the product joined the shelf.
    private func patternRow(_ name: String, art: String, from day: Int, hot: Bool) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(art)
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 3)
                    .frame(width: 24, height: 28)
                    .background(SKColor.neutralChip, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(name)
                    .font(SKFont.sans(12.5, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(SKColor.ink)
                    .lineLimit(1)
            }
            .frame(width: Self.patternLabelWidth, alignment: .leading)
            GeometryReader { geo in
                let col = geo.size.width / 7
                ZStack(alignment: .leading) {
                    Capsule().fill(SKColor.neutralChip)
                    Capsule()
                        .fill(hot ? SKColor.primary : Color(hex: 0xCDBFAE))
                        .frame(width: phase >= 2 ? geo.size.width - col * (CGFloat(day) + 0.3) : 0)
                        .offset(x: col * (CGFloat(day) + 0.15))
                        .shadow(color: hot ? SKColor.primary.opacity(0.45) : .clear, radius: 5)
                }
            }
            .frame(height: 8)
        }
    }

    private var patternFinding: some View {
        HStack(spacing: SKSpace.md) {
            ZStack {
                DropShape()
                    .stroke(SKColor.primary.opacity(0.35), lineWidth: 2)
                    .scaleEffect(sweep ? 1.3 : 1)
                    .opacity(sweep ? 0 : 1)
                DropShape().fill(SKColor.primary)
                Text("!")
                    .font(SKFont.sans(17, weight: .bold, relativeTo: .headline))
                    .foregroundStyle(SKColor.cream)
                    .offset(y: 4)
            }
            .frame(width: 28, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Breakouts follow the new toner").font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                Text("4 of 5 bad days came 3–6 days after it joined").font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(SKSpace.md)
        .background(SKColor.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(phase >= 3 ? 1 : 0)
        .offset(y: phase >= 3 ? 0 : 10)
    }

    /// The pink tube from the website, turned to its barcode, with a live scan line.
    private var scanDemo: some View {
        HStack(alignment: .center, spacing: SKSpace.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SKColor.bg)
                Image(ProductArt.tubeBack)
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 14)
                    .scaleEffect(phase >= 2 ? 0.94 : 1)
                ScanBrackets()
                    .stroke(phase >= 2 ? SKColor.goodFg : SKColor.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(8)
                GeometryReader { geo in
                    Capsule()
                        .fill(SKColor.primary)
                        .frame(height: 3)
                        .shadow(color: SKColor.primary.opacity(0.9), radius: 8)
                        .padding(.horizontal, 14)
                        .offset(y: geo.size.height * (sweep ? 0.8 : 0.2))
                }
                .opacity(phase <= 1 ? 1 : 0)
                if phase >= 2 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SKColor.cream)
                        .frame(width: 34, height: 34)
                        .background(SKColor.goodFg, in: Circle())
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 118)
            VStack(alignment: .leading, spacing: SKSpace.sm) {
                Text(phase == 0 ? "Point at the barcode" : phase == 1 ? "Reading 0 12345 67890 5" : "Found it")
                    .font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                Text("Rose Gel Cream").font(SKFont.sans(18, weight: .semibold, relativeTo: .headline)).foregroundStyle(SKColor.ink)
                    .opacity(phase >= 2 ? 1 : 0.25)
                HStack(spacing: SKSpace.sm) {
                    ZStack {
                        Circle().stroke(SKColor.neutralChip, lineWidth: 5)
                        Circle().trim(from: 0, to: phase >= 3 ? 0.86 : 0)
                            .stroke(SKColor.goodFg, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(phase >= 3 ? "86" : "–").font(SKFont.sans(15, weight: .semibold, relativeTo: .headline)).foregroundStyle(SKColor.ink)
                    }
                    .frame(width: 44, height: 44)
                    Text(phase >= 3 ? "Clean · nothing from your triggers" : "Checking your triggers…")
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                }
                .opacity(phase >= 2 ? 1 : 0)
                VStack(alignment: .leading, spacing: 6) {
                    SKChip("Ceramides", tone: .good)
                    SKChip("No fragrance", tone: .good)
                }
                .opacity(phase >= 3 ? 1 : 0)
            }
            Spacer(minLength: 0)
        }
    }

    private var compareDemo: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            compareRow("Gentle Gel Cleanser", score: 88, winner: phase >= 3)
            compareRow("Foaming Face Wash", score: 54, winner: false)
            Spacer(minLength: 0)
            result(icon: "checkmark.seal", title: "Gentle Gel Cleanser wins",
                   detail: "No coconut derivatives, which broke you out twice", good: true)
        }
    }

    private func compareRow(_ name: String, score: Int, winner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(name).font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                if winner { Image(systemName: "crown.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(SKColor.primary) }
                Spacer()
                Text(phase >= 2 ? "\(score)" : "…").font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SKColor.neutralChip)
                    Capsule().fill(score >= 70 ? SKColor.goodFg : SKColor.cautionFg)
                        .frame(width: geo.size.width * (phase >= 1 ? CGFloat(score) / 100 : 0))
                }
            }
            .frame(height: 8)
        }
        .padding(SKSpace.md)
        .background(SKColor.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recommendDemo: some View {
        VStack(spacing: SKSpace.sm) {
            ForEach(Array(picks.enumerated()), id: \.offset) { i, pick in
                HStack(spacing: SKSpace.md) {
                    SKProductMark(name: pick.0, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pick.0).font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                        Text(pick.1).font(SKFont.caption).foregroundStyle(SKColor.muted)
                    }
                    Spacer(minLength: 0)
                    Text(pick.2).font(SKFont.dataSmall).foregroundStyle(SKColor.muted)
                }
                .padding(SKSpace.sm)
                .background(SKColor.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(phase > i ? 1 : 0)
                .offset(x: phase > i ? 0 : 24)
            }
        }
    }

    private var routineDemo: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(["Cleanser", "Retinol serum", "Glycolic toner", "Moisturiser"].enumerated()), id: \.offset) { i, step in
                HStack(spacing: SKSpace.md) {
                    Text("\(i + 1)").font(SKFont.mono(12)).foregroundStyle(SKColor.muted).frame(width: 18)
                    Text(step).font(SKFont.sans(15, weight: .medium, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                    Spacer()
                    if phase >= 2 && (i == 1 || i == 2) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundStyle(SKColor.badFg)
                    }
                }
                .padding(.vertical, 5)
                .opacity(phase >= 1 || i == 0 ? 1 : 0.35)
            }
            Spacer(minLength: 0)
            result(icon: "moon.stars", title: "Split retinol and glycolic acid",
                   detail: "Same night raises irritation. Try acid on its own nights.", good: false)
        }
    }

    /// Three stories on a loop: a tagged shelf product, a new product added from the chat,
    /// and one Skintel recognises as already on the shelf.
    private var askDemo: some View {
        let story = AskStory.all[scene % AskStory.all.count]
        let cardAt = scene == 1 ? 2 : 3
        return VStack(alignment: .leading, spacing: SKSpace.sm) {
            VStack(alignment: .trailing, spacing: 6) {
                if let tag = story.tag {
                    HStack(spacing: 6) {
                        SKProductMark(name: tag, size: 20)
                        Text(tag).font(SKFont.sans(12.5, weight: .semibold, relativeTo: .caption)).foregroundStyle(SKColor.ink)
                    }
                    .padding(.leading, 4)
                    .padding(.trailing, 10)
                    .frame(height: 28)
                    .background(SKColor.bg, in: Capsule())
                    .overlay(Capsule().stroke(SKColor.line))
                }
                Text(story.question)
                    .font(SKFont.sans(14.5, relativeTo: .subheadline))
                    .foregroundStyle(SKColor.cream)
                    .padding(10)
                    .background(SKColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
            HStack(alignment: .top, spacing: SKSpace.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SKColor.cream)
                    .frame(width: 24, height: 24)
                    .background(SKColor.primary, in: Circle())
                if phase == 1 {
                    Text("• • •").font(SKFont.sans(14, weight: .bold)).foregroundStyle(SKColor.muted)
                } else if phase >= 2 {
                    Text(story.answer)
                        .font(SKFont.sans(14.5, relativeTo: .subheadline))
                        .foregroundStyle(SKColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(phase >= 1 ? 1 : 0)
            Spacer(minLength: 0)
            HStack(spacing: SKSpace.sm) {
                SKProductMark(name: story.product, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(story.product).font(SKFont.sans(13.5, weight: .semibold, relativeTo: .caption)).foregroundStyle(SKColor.ink)
                    Text(scene == 1 && phase < 3 ? "Add to your shelf?" : story.done)
                        .font(SKFont.caption).foregroundStyle(SKColor.muted)
                }
                Spacer(minLength: 0)
                if scene == 1 && phase < 3 {
                    Text("Add")
                        .font(SKFont.sans(13, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(SKColor.cream)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(SKColor.primary, in: Capsule())
                } else {
                    Label(story.badge, systemImage: "checkmark")
                        .font(SKFont.sans(13, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(SKColor.goodFg)
                }
            }
            .padding(SKSpace.sm)
            .background(SKColor.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(phase >= cardAt ? 1 : 0)
            .offset(y: phase >= cardAt ? 0 : 10)
        }
        .id(scene)
        .transition(.opacity)
    }

    private var shelfDemo: some View {
        let visible = [2, 4, 5, 6][phase]
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<shelfItems.count, id: \.self) { i in
                HStack(spacing: SKSpace.sm) {
                    SKProductMark(name: shelfItems[i], size: 24)
                    Text(shelfItems[i]).font(SKFont.sans(14, weight: .medium, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                    Spacer()
                    if i == 5 && phase >= 3 { SKChip("Pro", tone: .good) }
                }
                .opacity(visible > i ? 1 : 0)
            }
            Spacer(minLength: 0)
            Text(phase >= 3 ? "Pro: unlimited shelf, every product checked" : "Free: up to five products")
                .font(SKFont.sans(13, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(phase >= 3 ? SKColor.primary : SKColor.muted)
        }
    }

    // MARK: Pieces

    private func result(icon: String, title: String, detail: String, good: Bool) -> some View {
        HStack(alignment: .top, spacing: SKSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(good ? SKColor.goodFg : SKColor.badFg)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                Text(detail).font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(SKSpace.md)
        .background(good ? SKColor.goodBg : SKColor.badBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(phase >= 3 ? 1 : 0)
        .offset(y: phase >= 3 ? 0 : 10)
    }
}

/// The demo on its own, for Pro members who don't have enough data yet to see the real thing.
struct FeatureDemoSheet: View {
    let reason: PaywallReason
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.lg) {
            FeatureDemo(reason: reason)
            Text(title).font(SKFont.section).foregroundStyle(SKColor.ink)
            Text(message).font(SKFont.sans(16, relativeTo: .body)).foregroundStyle(SKColor.muted)
            Spacer(minLength: 0)
            SKButton(title: "Got it") { dismiss() }
        }
        .skPagePadding()
        .padding(.top, SKSpace.xl)
        .padding(.bottom, SKSpace.lg)
        .skPageBackground()
        .presentationDragIndicator(.visible)
    }
}

/// One Ask Skintel demo story.
private struct AskStory {
    let tag: String?
    let question: String
    let answer: String
    let product: String
    let done: String
    let badge: String

    static let all = [
        AskStory(tag: "Niacinamide Serum", question: "Can I use this with my retinol?",
                 answer: "Yes. Niacinamide is gentle with retinol. Use the serum in the morning and keep retinol for night.",
                 product: "Niacinamide Serum", done: "Answered from its ingredients", badge: "Tagged"),
        AskStory(tag: nil, question: "I started using Glow Toner last week.",
                 answer: "Noted. Glow Toner has glycolic acid, so keep it off your retinol nights.",
                 product: "Glow Toner", done: "Added to your shelf", badge: "Added"),
        AskStory(tag: nil, question: "Is my Barrier Cream okay for my chin?",
                 answer: "It's fragrance-free and hasn't matched a trigger, so it's an unlikely culprit.",
                 product: "Barrier Cream", done: "Already on your shelf", badge: "On shelf"),
    ]
}

/// Viewfinder corners around the scanned bottle.
private struct ScanBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let l = min(rect.width, rect.height) * 0.18
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

// MARK: - Pro benefits

/// Everything Pro adds, each with the website's side animation and a demo to play.
enum ProBenefit: String, CaseIterable, Identifiable {
    case unlimited, scan, routine, ask, triggers, compare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimited: "Unlimited products + scans"
        case .scan: "Barcode, label + link scanner"
        case .routine: "Routine builder + conflict checks"
        case .ask: "Ask Skintel, from your shelf"
        case .triggers: "Personal trigger map, kept private"
        case .compare: "Compare + picks for your skin"
        }
    }

    var detail: String {
        switch self {
        case .unlimited: "No five-product cap on your shelf"
        case .scan: "Point at any product for a verdict"
        case .routine: "Flags actives that clash, step by step"
        case .ask: "Tag products, add the ones you mention"
        case .triggers: "Your journal and shelf name the culprits"
        case .compare: "Side-by-side verdicts and safe picks"
        }
    }

    /// The feature demo this benefit plays.
    var reason: PaywallReason {
        switch self {
        case .unlimited: .productLimit
        case .scan: .scanner
        case .routine: .routine
        case .ask: .assistant
        case .triggers: .culprits
        case .compare: .compare
        }
    }

    var demoMessage: String {
        switch self {
        case .unlimited: "Keep every product you own on your shelf, and scan as many new ones as you like."
        case .scan: "Scan the barcode on the back of a bottle. Skintel finds the product, reads its ingredients and checks them against what broke you out."
        case .routine: "Skintel reads each step of your morning and night routines and warns you when two actives shouldn't share a night."
        case .ask: "Tag products from your shelf to ask about them, mention a new one to add it, and Skintel knows what you already own."
        case .triggers: "Skintel lines up your check-ins with when each product joined your shelf and names what keeps showing up before a bad day."
        case .compare: "Put two products side by side and see which one suits your skin, or get picks that avoid your triggers."
        }
    }
}

/// The small animated tile beside each benefit, after the pricing card on the website:
/// ∞ pulse, barcode sweep, check-in dot grid, sparkle, shield and check.
struct ProBenefitIcon: View {
    let benefit: ProBenefit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        ZStack {
            switch benefit {
            case .unlimited:
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SKColor.blush)
                Text("∞")
                    .font(SKFont.sans(24, weight: .semibold, relativeTo: .title3))
                    .foregroundStyle(SKColor.primary)
                    .scaleEffect(on ? 1.15 : 0.95)
            case .scan:
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SKColor.ink)
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { i in
                        Rectangle().fill(SKColor.cream.opacity(0.85)).frame(width: i % 3 == 0 ? 2.5 : 1.2, height: 18)
                    }
                }
                Capsule()
                    .fill(SKColor.primary)
                    .frame(width: 30, height: 2)
                    .shadow(color: SKColor.primary, radius: 4)
                    .offset(y: on ? 11 : -11)
            case .routine:
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SKColor.neutralChip)
                TimelineView(.periodic(from: .now, by: 0.35)) { context in
                    let lit = reduceMotion ? 9 : Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 14
                    VStack(spacing: 3) {
                        ForEach(0..<2, id: \.self) { row in
                            HStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { col in
                                    Circle()
                                        .fill(row * 7 + col == lit ? SKColor.primary : SKColor.muted.opacity(0.35))
                                        .frame(width: 3.5, height: 3.5)
                                }
                            }
                        }
                    }
                }
            case .ask:
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SKColor.primary.opacity(0.1))
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SKColor.primary)
                    .scaleEffect(on ? 1.1 : 0.9)
                    .rotationEffect(.degrees(on ? 8 : -8))
            case .triggers:
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SKColor.goodBg)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SKColor.goodFg)
                    .scaleEffect(on ? 1.08 : 0.94)
            case .compare:
                Circle().fill(SKColor.goodBg).scaleEffect(on ? 1 : 0.86)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(SKColor.goodFg)
            }
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: benefit == .scan ? 1.0 : 1.3).repeatForever(autoreverses: true)) { on = true }
        }
    }
}

/// Every Pro benefit as a row; tapping one plays its demo.
struct ProBenefitsList: View {
    @State private var demo: ProBenefit?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ProBenefit.allCases) { b in
                Button { Haptics.tap(); demo = b } label: {
                    HStack(spacing: SKSpace.md) {
                        ProBenefitIcon(benefit: b)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.title).font(SKFont.sans(16, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                            Text(b.detail).font(SKFont.caption).foregroundStyle(SKColor.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(SKColor.primary.opacity(0.85))
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SKPressStyle())
                .accessibilityHint("Plays a short demo")
                if b != ProBenefit.allCases.last {
                    Rectangle().fill(SKColor.line).frame(height: 1).padding(.leading, 56)
                }
            }
        }
        .sheet(item: $demo) { b in
            FeatureDemoSheet(reason: b.reason, title: b.title, message: b.demoMessage)
        }
    }
}


/// The Skintel drop: a teardrop with a round base, used for the pattern warning badge.
struct DropShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let base = CGPoint(x: r.midX, y: r.maxY - w / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: base.y),
                   control1: CGPoint(x: r.midX + w * 0.2, y: r.minY + r.height * 0.22),
                   control2: CGPoint(x: r.maxX, y: base.y - r.height * 0.22))
        p.addArc(center: base, radius: w / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: base.y - r.height * 0.22),
                   control2: CGPoint(x: r.midX - w * 0.2, y: r.minY + r.height * 0.22))
        p.closeSubpath()
        return p
    }
}

// MARK: - Mascot upgrade story

/// The Skintel drop's short story for the general upgrade: it hops in, scans a bottle,
/// gets a clean verdict, then the Pro perks float up while it does a happy hop.
/// Storybook backdrop (light rays, a drawn sun, a floor). Reduce Motion shows the last beat.
struct MascotUpgradeHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false
    /// 0 idle, 1 scanning, 2 verdict, 3 perks.
    @State private var beat = 0

    private static let green = Color(hex: 0x6F9B63)
    private static let perks: [(symbol: String, title: String)] = [
        ("infinity", "Unlimited scans"), ("sparkles", "Ask Skintel"), ("checkmark.shield", "Trigger map"),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let mascotH = h * 0.72
                ZStack {
                    backdrop(t: t, w: w, h: h)
                    Ellipse()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: mascotH * 0.55, height: 14)
                        .position(x: w * 0.33, y: h - 25)
                        .opacity(entered ? 1 : 0)
                    mascot(t: t)
                        .frame(height: mascotH)
                        .position(x: w * 0.33, y: h - mascotH / 2 - 24)
                    sparkles(t: t, w: w, h: h)
                    verdictBubble
                        .position(x: w * 0.75, y: h * 0.3)
                    perkStack
                        .position(x: w * 0.77, y: h * 0.62)
                }
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(SKColor.line))
        .skSoftShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The Skintel drop scans a bottle and finds it's good for your skin.")
        .task {
            if reduceMotion { entered = true; beat = 3; return }
            try? await Task.sleep(for: .seconds(0.25))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { entered = true }
            try? await Task.sleep(for: .seconds(1.0))
            while !Task.isCancelled {
                withAnimation(SKAnimation.emil(0.4)) { beat = 1 }
                try? await Task.sleep(for: .seconds(1.6))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { beat = 2 }
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { beat = 3 }
                try? await Task.sleep(for: .seconds(3.0))
                withAnimation(SKAnimation.emil(0.5)) { beat = 0 }
                try? await Task.sleep(for: .seconds(0.7))
            }
        }
    }

    private func backdrop(t: Double, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Color(hex: 0xF8F1E4)
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 30, height: h * 2)
                    .rotationEffect(.degrees(-32))
                    .offset(x: CGFloat(i) * 92 - w * 0.25 + CGFloat(sin(t * 0.5 + Double(i))) * 6)
            }
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    Capsule()
                        .fill(Color(hex: 0xE3A04A).opacity(0.85))
                        .frame(width: 2.5, height: 9)
                        .offset(y: -30)
                        .rotationEffect(.degrees(Double(i) * 36))
                }
                Circle().fill(Color(hex: 0xEDB25A)).frame(width: 38, height: 38)
            }
            .rotationEffect(.degrees(t * 12))
            .position(x: 44, y: 44)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color(hex: 0xEBD6CC))
                    .frame(height: 48)
                    .overlay(alignment: .top) { Rectangle().fill(SKColor.primary.opacity(0.22)).frame(height: 1.5) }
            }
        }
    }

    private func mascot(t: Double) -> some View {
        let breathe = CGFloat(sin(t * 2.2)) * 0.018
        let hop = beat == 3 ? -abs(CGFloat(sin(t * 5))) * 10 : 0
        return Image("Mascot")
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { g in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .blur(radius: 6)
                        .position(x: g.size.width * 0.31, y: g.size.height * 0.655)
                        .opacity(beat == 1 ? 0.5 + 0.4 * sin(t * 18) : 0)
                    Circle()
                        .fill(Self.green)
                        .frame(width: 26, height: 26)
                        .blur(radius: 8)
                        .position(x: g.size.width * 0.51, y: g.size.height * 0.63)
                        .opacity(beat >= 2 ? 0.55 : 0)
                }
            }
            .scaleEffect(x: 1 + breathe, y: 1 - breathe, anchor: .bottom)
            .rotationEffect(.degrees(sin(t * 1.3) * 1.5), anchor: .bottom)
            .offset(x: entered ? 0 : -300, y: hop)
    }

    private var verdictBubble: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SKColor.cream)
                .frame(width: 24, height: 24)
                .background(Self.green, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text("86 · Good").font(SKFont.sans(14, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                Text("for your skin").font(SKFont.caption).foregroundStyle(SKColor.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(alignment: .bottomLeading) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SKColor.cream)
                Rectangle().fill(SKColor.cream).frame(width: 12, height: 12).rotationEffect(.degrees(45)).offset(x: 12, y: 5)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .scaleEffect(beat >= 2 ? 1 : 0.3, anchor: .bottomLeading)
        .opacity(beat >= 2 ? 1 : 0)
    }

    private var perkStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Self.perks.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    Image(systemName: Self.perks[i].symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SKColor.primary)
                    Text(Self.perks[i].title)
                        .font(SKFont.sans(12.5, weight: .semibold, relativeTo: .caption))
                        .foregroundStyle(SKColor.ink)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(SKColor.cream, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                .opacity(beat >= 3 ? 1 : 0)
                .offset(y: beat >= 3 ? 0 : 18)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(i) * 0.12), value: beat)
            }
        }
    }

    private func sparkles(t: Double, w: CGFloat, h: CGFloat) -> some View {
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.12, 0.42, 14), (0.55, 0.2, 11), (0.6, 0.5, 9), (0.2, 0.7, 10)]
        return ZStack {
            ForEach(spots.indices, id: \.self) { i in
                let twinkle = abs(sin(t * 2.4 + Double(i) * 1.7))
                Image(systemName: "sparkle")
                    .font(.system(size: spots[i].2, weight: .semibold))
                    .foregroundStyle(i.isMultiple(of: 2) ? Color(hex: 0xE3A04A) : SKColor.primary)
                    .scaleEffect(0.6 + 0.5 * twinkle)
                    .opacity(beat >= 2 ? 0.35 + 0.65 * twinkle : 0)
                    .position(x: w * spots[i].0, y: h * spots[i].1)
            }
        }
    }
}

// MARK: - Hard wall

/// What a Free member sees in place of a whole Pro area (Ask, Insights): the feature's
/// looping demo, what it does, Upgrade, and a way back. Nothing behind it is reachable.
struct ProLockedView: View {
    enum Feature { case ask, insights }

    let feature: Feature
    /// Room kept for the floating tab bar when the view fills a tab that reserves none.
    var bottomClearance: CGFloat = 0
    /// Where "back" goes when this fills a tab; nil closes the sheet instead.
    var leave: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showPlans = false

    private var reason: PaywallReason { feature == .ask ? .assistant : .journalAnalysis }

    private var title: String {
        switch feature {
        case .ask: "Upgrade for Ask Skintel"
        case .insights: "Upgrade for Insights"
        }
    }

    private var message: String {
        switch feature {
        case .ask: "Your skin assistant that knows your shelf, check-ins and triggers. Tag products, ask anything, and add what you mention."
        case .insights: "See what your check-ins add up to: routine streaks, good and bad days, suspects and the patterns behind breakouts. Your check-ins are saved either way."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: SKSpace.xl) {
                    FeatureDemo(reason: reason)
                    VStack(spacing: SKSpace.sm) {
                        Text(title)
                            .font(SKFont.serif(34, relativeTo: .largeTitle))
                            .foregroundStyle(SKColor.ink)
                            .multilineTextAlignment(.center)
                        Text(message)
                            .font(SKFont.sans(17, relativeTo: .body))
                            .foregroundStyle(SKColor.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, SKSpace.sm)
                }
                .skPagePadding()
                .padding(.top, SKSpace.xl)
                .padding(.bottom, SKSpace.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: SKSpace.sm) {
                SKButton(title: "Upgrade") { showPlans = true }
                SKButton(title: leave == nil ? "Not now" : "Back to Today", kind: .secondary) {
                    if let leave { leave() } else { dismiss() }
                }
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.md + bottomClearance)
        }
        .skPageBackground()
        .sheet(isPresented: $showPlans) { PaywallView(reason: reason) }
    }
}
