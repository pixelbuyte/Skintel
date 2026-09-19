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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            Text("Skintel Pro").font(SKFont.mono(11)).textCase(.uppercase).tracking(2).foregroundStyle(SKColor.primary)
                .padding(.horizontal, 14).padding(.vertical, 7).background(SKColor.blush, in: Capsule())
            Text(headline).font(SKFont.editorial(32, relativeTo: .largeTitle)).foregroundStyle(SKColor.ink).multilineTextAlignment(.center)
            Text(reasonLine).font(SKFont.sans(16, relativeTo: .body)).foregroundStyle(SKColor.muted).multilineTextAlignment(.center)
        }
        .padding(.top, SKSpace.md)
    }

    private var headline: String {
        "More clarity.\nBetter skin choices."
    }

    private var reasonLine: String {
        switch reason {
        case .scanner: "Scan more products. Understand what’s in them and how they fit your skin."
        case .productLimit: "Free shelves hold five products. Pro shelves are unlimited."
        case .compare: "See how two products fit your skin, side by side."
        case .recommend: "Explore product suggestions based on your skin and the products you log."
        case .routine: "Check how the products in your morning and evening routines work together."
        case .journalAnalysis, .culprits: "Spot possible ingredient triggers in the products and skin changes you log."
        case .general: "Understand ingredients, spot possible triggers, and build a routine that fits you."
        }
    }

    private func plans(_ s: SubscriptionService) -> some View {
        VStack(spacing: SKSpace.md) {
            if case .failed(let msg) = s.phase, s.products.isEmpty {
                SKCard { VStack(alignment: .leading, spacing: SKSpace.md) { SKInlineError(message: msg); SKButton(title: "Try again", kind: .secondary) { Task { await s.loadProducts() } } } }
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
                Text("Founding member offer")
                    .font(SKFont.sans(14, weight: .bold, relativeTo: .subheadline))
                    .foregroundStyle(SKColor.primary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(p.displayPrice).font(SKFont.price).foregroundStyle(SKColor.ink)
                    Text("once").font(SKFont.sans(18, relativeTo: .title3)).foregroundStyle(SKColor.muted)
                }
                Text("3 months of Pro. One payment.").font(SKFont.sans(16, weight: .bold, relativeTo: .body)).foregroundStyle(SKColor.primary)
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
            HStack(alignment: .top, spacing: SKSpace.md) {
                Circle().stroke(selected == id ? SKColor.primary : SKColor.line, lineWidth: 1.5).frame(width: 22, height: 22)
                    .overlay { if selected == id { Circle().fill(SKColor.primary).frame(width: 12, height: 12) } }
                    .accessibilityHidden(true)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: SKSpace.sm))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: SKSpace.md))
                layout {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(id == .proMonthly ? "Monthly" : "Yearly").font(SKFont.sans(17, weight: .bold, relativeTo: .headline)).foregroundStyle(SKColor.ink)
                        Text(caption).font(SKFont.caption).foregroundStyle(SKColor.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                        Text(product.displayPrice).font(SKFont.editorial(24, relativeTo: .title2))
                        Text(service?.periodText(id) ?? "").font(SKFont.secondary)
                    }
                    .foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                }
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
            benefit("Unlimited product scans")
            benefit("Ingredient insights for your skin")
            benefit("Spot possible ingredient triggers")
            benefit("Build morning & evening routines")
            benefit("Unlimited products on your shelf")
            Text("Trigger insights show patterns in what you log; they don’t diagnose allergies.")
                .font(SKFont.caption).foregroundStyle(SKColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, SKSpace.sm)
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: SKSpace.md) {
            Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(SKColor.goodFg)
                .frame(width: 20, height: 24).accessibilityHidden(true)
            Text(text).font(SKFont.sans(16, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                .fixedSize(horizontal: false, vertical: true)
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
