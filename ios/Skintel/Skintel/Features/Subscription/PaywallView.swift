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
                FeatureDemo(reason: reason).padding(.bottom, SKSpace.sm)
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
        VStack(alignment: .leading, spacing: SKSpace.md) {
            benefit("Unlimited scans & AI verdicts")
            benefit("Culprit detection on your full history")
            benefit("Compare, routines & conflict alerts")
            benefit("Unlimited products on your shelf")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, SKSpace.sm)
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: SKSpace.md) {
            Text("✓").font(SKFont.sans(15, weight: .semibold)).foregroundStyle(SKColor.goodFg)
            Text(text).font(SKFont.sans(17, relativeTo: .body)).foregroundStyle(SKColor.ink)
        }
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
        .frame(height: 290)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(SKColor.line))
        .skSoftShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Demo with sample data. \(summary)")
        .task {
            if reduceMotion { phase = 3; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(SKAnimation.emil(0.6)) { phase = (phase + 1) % 4 }
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
        case .assistant: steps = ["You ask", "Thinking…", "From your shelf", "Adds to your shelf"]
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
        case .assistant: "Ask Skintel answers from your shelf and offers to add the product you mentioned."
        case .productLimit, .general: "A free shelf holds five products; Pro is unlimited."
        }
    }

    // MARK: Demos

    private var journalDemo: some View {
        let tones: [Color] = [SKColor.goodFg, SKColor.goodFg, SKColor.cautionFg, SKColor.badFg, SKColor.badFg, SKColor.cautionFg, SKColor.goodFg]
        return VStack(alignment: .leading, spacing: SKSpace.md) {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(phase >= 1 || i < 2 ? tones[i] : SKColor.neutralChip)
                        .frame(height: 30)
                        .scaleEffect(phase >= 1 || i < 2 ? 1 : 0.85)
                }
            }
            VStack(spacing: 8) {
                bar("Cleanser", start: 0, length: 1, hot: false)
                bar("Moisturiser", start: 0, length: 1, hot: false)
                bar("New toner", start: 0.42, length: 0.58, hot: phase >= 3)
            }
            .opacity(phase >= 2 ? 1 : 0.3)
            Spacer(minLength: 0)
            result(icon: "exclamationmark.triangle", title: "Breakouts follow the new toner",
                   detail: "4 of 5 bad days came 3–6 days after it joined", good: false)
        }
    }

    private var scanDemo: some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SKColor.ink)
                HStack(spacing: 3) {
                    ForEach(0..<20, id: \.self) { i in
                        Rectangle().fill(SKColor.cream).frame(width: i % 3 == 0 ? 3 : 1.5)
                    }
                }
                .frame(height: 40)
                Rectangle().fill(SKColor.primary).frame(height: 2)
                    .shadow(color: SKColor.primary, radius: 6)
                    .offset(y: phase == 1 ? 22 : -22)
                    .opacity(phase <= 1 ? 1 : 0)
            }
            .frame(height: 92)
            HStack(spacing: SKSpace.md) {
                ZStack {
                    Circle().stroke(SKColor.neutralChip, lineWidth: 6)
                    Circle().trim(from: 0, to: phase >= 3 ? 0.86 : 0)
                        .stroke(SKColor.goodFg, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(phase >= 3 ? "86" : "–").font(SKFont.sans(17, weight: .semibold, relativeTo: .headline)).foregroundStyle(SKColor.ink)
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Foaming Facial Cleanser").font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                    Text(phase >= 3 ? "Clean · nothing from your triggers" : "Looking it up…").font(SKFont.caption).foregroundStyle(SKColor.muted)
                }
            }
            .opacity(phase >= 2 ? 1 : 0.25)
            HStack(spacing: 6) {
                SKChip("Ceramides", tone: .good)
                SKChip("Niacinamide", tone: .good)
                SKChip("No fragrance", tone: .good)
            }
            .opacity(phase >= 3 ? 1 : 0)
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

    private var askDemo: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack {
                Spacer(minLength: 40)
                Text("My chin keeps breaking out. I use CeraVe PM lotion.")
                    .font(SKFont.sans(14.5, relativeTo: .subheadline))
                    .foregroundStyle(SKColor.cream)
                    .padding(10)
                    .background(SKColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            HStack(alignment: .top, spacing: SKSpace.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SKColor.cream)
                    .frame(width: 24, height: 24)
                    .background(SKColor.primary, in: Circle())
                if phase == 1 {
                    Text("• • •").font(SKFont.sans(14, weight: .bold)).foregroundStyle(SKColor.muted)
                } else if phase >= 2 {
                    Text("Two products that broke you out share fragrance. This lotion has none, so it's a less likely culprit.")
                        .font(SKFont.sans(14.5, relativeTo: .subheadline))
                        .foregroundStyle(SKColor.ink)
                }
            }
            .opacity(phase >= 1 ? 1 : 0)
            Spacer(minLength: 0)
            HStack(spacing: SKSpace.sm) {
                Image(systemName: "square.stack").foregroundStyle(SKColor.primary)
                Text("Add CeraVe PM lotion to your shelf?").font(SKFont.sans(13.5, weight: .semibold, relativeTo: .caption)).foregroundStyle(SKColor.ink)
                Spacer(minLength: 0)
                Text("Add")
                    .font(SKFont.sans(13, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(SKColor.cream)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(SKColor.primary, in: Capsule())
            }
            .padding(SKSpace.sm)
            .background(SKColor.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(phase >= 3 ? 1 : 0)
            .offset(y: phase >= 3 ? 0 : 10)
        }
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

    private func bar(_ name: String, start: CGFloat, length: CGFloat, hot: Bool) -> some View {
        HStack(spacing: SKSpace.sm) {
            Text(name).font(SKFont.caption).foregroundStyle(SKColor.muted).frame(width: 84, alignment: .leading).lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SKColor.neutralChip)
                    Capsule().fill(hot ? SKColor.badFg : SKColor.primary)
                        .frame(width: geo.size.width * (phase >= 2 ? length : 0))
                        .offset(x: geo.size.width * start)
                }
            }
            .frame(height: 8)
        }
    }

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
