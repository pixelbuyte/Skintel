import Foundation
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
    @Environment(\.openURL) private var openURL
    @State private var service: SubscriptionService?
    @State private var selected: SubscriptionService.ProductID = .founding
    @State private var isUSStorefront = false
    @State private var appeared = false

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
                        if isUSStorefront { webOffer(service) }
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
            async let us: Bool = USStorefront.isActive()
            let (_, _, usResult) = await (p, f, us)
            isUSStorefront = usResult
            if (env.subscription.foundingSeatsRemaining ?? 1) <= 0 || s.product(.founding) == nil { selected = .proYearly }
            appeared = true
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
        case .general: "Unlimited scans, culprit detection on your full history, and more."
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

    private struct ProBenefit: Identifiable {
        let order: Int
        let symbol: String
        let title: String
        let detail: String
        var id: String { symbol }
    }

    /// Every symbol here is either already used elsewhere in the app or a core SF Symbol.
    /// `order` drives the entrance stagger — a plain `ForEach` over these avoids needing a
    /// key path into `enumerated()`'s tuple, which Swift does not allow.
    private static let proBenefits: [ProBenefit] = [
        ProBenefit(order: 0, symbol: "barcode.viewfinder", title: "Scan before you buy",
                   detail: "Barcode or label — a full ingredient read and a verdict in seconds."),
        ProBenefit(order: 1, symbol: "exclamationmark.triangle", title: "Catches products that clash",
                   detail: "Retinol stacked with acids and other conflicts, flagged before they cost you a barrier."),
        ProBenefit(order: 2, symbol: "wand.and.stars", title: "Picks that suit your skin",
                   detail: "Suggestions built from your own history — not a generic top-ten list."),
        ProBenefit(order: 3, symbol: "square.stack", title: "Your whole shelf, no cap",
                   detail: "Free stops at five products. Pro tracks everything you own.")
    ]

    private var benefits: some View {
        VStack(spacing: SKSpace.sm) {
            Text("What Pro unlocks")
                .font(SKFont.label).textCase(.uppercase).tracking(1.6)
                .foregroundStyle(SKColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, SKSpace.xs)
            leadBenefit
            ForEach(Self.proBenefits) { item in
                benefitRow(item)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(SKAnimation.emil().delay(0.08 + Double(item.order) * 0.07), value: appeared)
            }
        }
        .padding(.top, SKSpace.sm)
    }

    private var leadBenefit: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            HStack(spacing: SKSpace.md) {
                benefitIcon("magnifyingglass")
                Text("Names your trigger ingredient").font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
            }
            Text("Cross-checks every product you own against the days your skin actually reacted — and tells you which ingredient they share.")
                .font(SKFont.secondary).foregroundStyle(SKColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SKSpace.lg)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
            .stroke(SKColor.primary.opacity(0.3), lineWidth: 1.5))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(SKAnimation.emil(), value: appeared)
    }

    private func benefitRow(_ item: ProBenefit) -> some View {
        HStack(alignment: .top, spacing: SKSpace.md) {
            benefitIcon(item.symbol)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(SKFont.sans(15, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                Text(item.detail).font(SKFont.caption).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(SKSpace.md)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
            .stroke(SKColor.line, lineWidth: 1))
    }

    private func benefitIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(SKColor.primary)
            .frame(width: 30, height: 30)
            .background(SKColor.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .symbolEffect(.bounce, value: appeared)
    }

    private func cta(_ s: SubscriptionService) -> some View {
        VStack(spacing: SKSpace.md) {
            if let msg = s.lastMessage { Text(msg).font(SKFont.secondary).foregroundStyle(SKColor.cautionFg).multilineTextAlignment(.center) }
            if case .failed(let msg) = s.phase, !s.products.isEmpty { SKInlineError(message: msg) }
            SKButton(title: ctaTitle(s), kind: .primary, isLoading: isBusy(s.phase)) {
                env.analytics.track(.appleSubscriptionTapped(productID: selected.rawValue))
                Task { await s.purchase(selected) }
            }
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

    // MARK: Web offer (US storefront only)

    /// Same Pro Monthly plan, purchased on skinstel.com instead of the App Store. Shown
    /// only when `USStorefront.isActive()` is true — never as a replacement for Apple's
    /// flow, just a second option underneath it. Apple's live `displayPrice` is never
    /// hardcoded here; only the web price is a fixed constant (see `WebOffer`), since
    /// there is no client-side way to read the live Stripe price.
    private func webOffer(_ s: SubscriptionService) -> some View {
        VStack(spacing: SKSpace.md) {
            HStack(spacing: SKSpace.sm) {
                Rectangle().fill(SKColor.line).frame(height: 1)
                Text("OR").font(SKFont.mono(11)).foregroundStyle(SKColor.muted)
                Rectangle().fill(SKColor.line).frame(height: 1)
            }
            .padding(.top, SKSpace.sm)

            VStack(alignment: .leading, spacing: SKSpace.md) {
                HStack(spacing: SKSpace.sm) {
                    Text("On skinstel.com")
                        .font(SKFont.label).textCase(.uppercase).tracking(1.4)
                        .foregroundStyle(SKColor.primary)
                    Spacer(minLength: 0)
                    if let saving = webSavingsText(s) {
                        Text("Save \(saving)").font(SKFont.chip).foregroundStyle(SKColor.primary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(SKColor.cream, in: Capsule())
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(webPriceText).font(SKFont.serif(30, relativeTo: .title)).foregroundStyle(SKColor.ink)
                    Text("/month").font(SKFont.secondary).foregroundStyle(SKColor.muted)
                    Spacer(minLength: 0)
                    if let apple = s.product(.proMonthly) {
                        Text(apple.displayPrice).font(SKFont.secondary).foregroundStyle(SKColor.muted).strikethrough()
                    }
                }
                // Web checkout has no session handoff from the app, so the account is matched
                // by email. Saying so here is the difference between Pro unlocking and not.
                Text("Check out with the same email you use for this Skintel account — that's how Pro unlocks in the app.")
                    .font(SKFont.caption).foregroundStyle(SKColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SKSpace.md)
                    .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.tile, style: .continuous))
                SKButton(title: "Subscribe on the web", kind: .secondary) {
                    env.analytics.track(.webSubscriptionTapped)
                    openURL(env.config.webSubscribeURL)
                    env.analytics.track(.webSubscriptionOpened)
                }
                Button("Already subscribed? Refresh") {
                    Task {
                        env.analytics.track(.subscriptionStatusRefreshed)
                        await env.subscription.load()
                    }
                }
                .font(SKFont.sans(13, weight: .medium)).foregroundStyle(SKColor.muted).underline()
                .frame(maxWidth: .infinity)
            }
            .padding(SKSpace.lg)
            .background(LinearGradient(colors: [SKColor.cream, SKColor.blush], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous)
                .stroke(SKColor.primary.opacity(0.3), lineWidth: 1.5))
        }
    }

    private var webPriceText: String {
        WebOffer.monthlyPrice.formatted(.currency(code: WebOffer.currencyCode))
    }

    /// A percentage rather than a dollar figure, derived from Apple's live price so it can
    /// never advertise a discount the user doesn't actually get. Truncated, so it rounds
    /// down — understating the saving is safe, overstating it is not.
    private func webSavingsText(_ s: SubscriptionService) -> String? {
        guard let apple = s.product(.proMonthly), apple.price > 0 else { return nil }
        let saving = apple.price - WebOffer.monthlyPrice
        guard saving > 0 else { return nil }
        let percent = NSDecimalNumber(decimal: saving / apple.price * 100).intValue
        guard percent > 0 else { return nil }
        return "\(percent)%"
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
