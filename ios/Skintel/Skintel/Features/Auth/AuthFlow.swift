import SwiftUI
import SkintelCore
import SkinstelMascot

/// Signed-out experience: the welcome promise (design §03) then sign-in / sign-up (§06).
struct AuthFlow: View {
    @Environment(AppEnvironment.self) private var env
    @State private var path: [AuthViewModel.Mode] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                getStarted: { path = [.signUp] },
                haveAccount: { path = [.signIn] }
            )
            .navigationDestination(for: AuthViewModel.Mode.self) { mode in
                SignInView(model: AuthViewModel(session: env.session, analytics: env.analytics, mode: mode))
            }
        }
        .tint(SKColor.primary)
    }
}

/// Signed-out welcome: three swipeable pages — the promise, what a free account gets, and
/// what Pro adds (each Pro row plays its demo) — before sign-up.
struct WelcomeView: View {
    let getStarted: () -> Void
    let haveAccount: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var page = 0

    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                promisePage.tag(0)
                FreeBenefitsPage().tag(1)
                ProBenefitsPage().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: lastPage + 1, index: page)
                .padding(.vertical, SKSpace.lg)
                .animation(SKAnimation.ios(0.3), value: page)

            VStack(spacing: SKSpace.sm) {
                if page < lastPage {
                    SKButton(title: "Next") {
                        Haptics.tap()
                        withAnimation(SKAnimation.ios()) { page += 1 }
                    }
                } else {
                    SKButton(title: "Get started", action: getStarted)
                }
                SKButton(title: "I already have an account", kind: .ghost, action: haveAccount)
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.lg)
        }
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topTrailing) {
            if page < lastPage {
                Button {
                    withAnimation(SKAnimation.ios()) { page = lastPage }
                } label: {
                    Text("Skip")
                        .font(SKFont.sans(15, weight: .medium, relativeTo: .subheadline))
                        .foregroundStyle(SKColor.muted)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, SKSpace.md)
                .transition(.opacity)
            }
        }
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation(SKAnimation.emil(0.9).delay(0.1)) { appeared = true } }
        }
    }

    private var promisePage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: SKSpace.xl)
            FloatingShelfCards(appeared: appeared)
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                // A hello in the free corner below the verdict cards; paused once swiped away.
                .overlay(alignment: .bottomTrailing) {
                    SKMascot(action: .wave, height: 104, isPlaying: page == 0, settleAfter: .seconds(3))
                        .padding(.trailing, SKSpace.md)
                        .opacity(appeared ? 1 : 0)
                }
                .accessibilityHidden(true)
            Spacer(minLength: SKSpace.xl)

            VStack(alignment: .leading, spacing: SKSpace.lg) {
                (Text("Know what ").font(SKFont.hero)
                 + Text("touches").font(SKFont.serif(40, relativeTo: .largeTitle, italic: true)).foregroundColor(SKColor.primary)
                 + Text("\nyour skin.").font(SKFont.hero))
                    .foregroundStyle(SKColor.ink)
                    .lineSpacing(-2)
                Text("Scan any skincare product and get an instant, honest verdict — for **your** skin, not skin in general.")
                    .font(SKFont.sans(17, relativeTo: .body))
                    .foregroundStyle(SKColor.muted)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .skPagePadding()
        }
    }
}

/// What every account gets, before any purchase. Keep in step with `Entitlement` (free =
/// profile, a five-product shelf, check-ins; scanning and the rest are Pro).
enum FreeBenefit: CaseIterable, Identifiable {
    case profile, shelf, checkIns, sync

    var id: Self { self }

    var symbol: String {
        switch self {
        case .profile: "person.crop.circle"
        case .shelf: "square.stack.3d.up"
        case .checkIns: "sun.and.horizon"
        case .sync: "arrow.triangle.2.circlepath"
        }
    }

    var title: String {
        switch self {
        case .profile: "Your skin profile"
        case .shelf: "A shelf for \(Entitlement.freeProductLimit) products"
        case .checkIns: "Morning + night check-ins"
        case .sync: "Synced with the website"
        }
    }

    var detail: String {
        switch self {
        case .profile: "Skin type and concerns shape every verdict"
        case .shelf: "Keep what you use, with its full ingredient list"
        case .checkIns: "A quick journal of how your skin feels"
        case .sync: "One account on your phone and on the web"
        }
    }
}

/// One free benefit: tinted icon tile, title and a short line.
struct FreeBenefitRow: View {
    let benefit: FreeBenefit

    var body: some View {
        HStack(spacing: SKSpace.md) {
            Image(systemName: benefit.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SKColor.goodFg)
                .frame(width: 44, height: 44)
                .background(SKColor.goodBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(benefit.title).font(SKFont.sans(16, weight: .semibold, relativeTo: .body)).foregroundStyle(SKColor.ink)
                Text(benefit.detail).font(SKFont.caption).foregroundStyle(SKColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(SKColor.goodFg)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// Page 2: the bottles on a shelf, then everything a free account includes.
private struct FreeBenefitsPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                ShelfIllustration()
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .padding(.top, SKSpace.xxl)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    (Text("Free, from ").font(SKFont.hero)
                     + Text("day one.").font(SKFont.serif(40, relativeTo: .largeTitle, italic: true)).foregroundColor(SKColor.primary))
                        .foregroundStyle(SKColor.ink)
                    Text("Create an account and you get:")
                        .font(SKFont.sans(17, relativeTo: .body))
                        .foregroundStyle(SKColor.muted)
                }

                VStack(spacing: 0) {
                    ForEach(FreeBenefit.allCases) { b in
                        FreeBenefitRow(benefit: b)
                        if b != FreeBenefit.allCases.last {
                            Rectangle().fill(SKColor.line).frame(height: 1).padding(.leading, 56)
                        }
                    }
                }
            }
            .skPagePadding()
            .padding(.top, SKSpace.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Page 3: every Pro benefit; tapping a row plays its demo with sample data.
private struct ProBenefitsPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SKSpace.lg) {
                VStack(alignment: .leading, spacing: SKSpace.sm) {
                    Text("SKINTEL PRO").font(SKFont.label).tracking(1.4).foregroundStyle(SKColor.primary)
                    (Text("Go further with ").font(SKFont.hero)
                     + Text("Pro.").font(SKFont.serif(40, relativeTo: .largeTitle, italic: true)).foregroundColor(SKColor.primary))
                        .foregroundStyle(SKColor.ink)
                    Text("Tap any feature to watch it work. Upgrade whenever you're ready.")
                        .font(SKFont.sans(17, relativeTo: .body))
                        .foregroundStyle(SKColor.muted)
                }
                .padding(.top, SKSpace.xxl)

                ProBenefitsList()
                    .padding(.horizontal, SKSpace.lg)
                    .padding(.vertical, SKSpace.sm)
                    .background(SKColor.cream, in: RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SKRadius.card, style: .continuous).stroke(SKColor.line))
            }
            .skPagePadding()
            .padding(.top, SKSpace.lg)
            .padding(.bottom, SKSpace.md)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// The three bottles standing on a shelf line, with a gentle stagger in.
private struct ShelfIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private let bottles: [(asset: String, height: CGFloat)] = [
        (ProductArt.pump, 140), (ProductArt.tube, 124), (ProductArt.dropper, 104),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: SKSpace.lg) {
                ForEach(bottles.indices, id: \.self) { i in
                    let b = bottles[i]
                    Image(b.asset)
                        .resizable()
                        .scaledToFit()
                        .frame(height: b.height)
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 4)
                        .offset(y: shown ? 0 : 16)
                        .opacity(shown ? 1 : 0)
                        .animation(reduceMotion ? nil : SKAnimation.emil(0.7).delay(Double(i) * 0.08), value: shown)
                }
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(SKColor.line)
                .frame(width: 240, height: 4)
        }
        .onAppear { shown = true }
    }
}

/// Three tilted verdict cards (good / bad / caution) — the promise before any UI copy.
private struct FloatingShelfCards: View {
    let appeared: Bool

    private struct Card { let name: String; let score: Int; let tone: SKTone; let label: String; let tile: Color; let art: String }
    private let cards: [Card] = [
        Card(name: "CeraVe Moisturizer", score: 86, tone: .good, label: "Good", tile: Color(hex: 0xD6E0EA), art: ProductArt.pump),
        Card(name: "Fragrance-heavy lotion", score: 31, tone: .bad, label: "Skip it", tile: Color(hex: 0xEED2CC), art: ProductArt.tube),
        Card(name: "Paula's Choice 2% BHA", score: 64, tone: .caution, label: "Caution", tile: Color(hex: 0xE9DEC3), art: ProductArt.dropper),
    ]

    var body: some View {
        ZStack {
            card(cards[0]).rotationEffect(.degrees(-6)).offset(x: -95, y: -20)
            card(cards[1]).rotationEffect(.degrees(5)).offset(x: 95, y: -60)
            card(cards[2]).rotationEffect(.degrees(1)).offset(x: 8, y: 70)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94)
    }

    private func card(_ c: Card) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.md) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [c.tile, c.tile.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 50, height: 66)
                .overlay {
                    Image(c.art)
                        .resizable()
                        .scaledToFit()
                        .padding(.vertical, 7)
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1.5)
                }
            Text(c.name).font(SKFont.sans(15, weight: .semibold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            SKChip("\(c.score) · \(c.label)", tone: c.tone, dot: true)
        }
        .padding(SKSpace.lg)
        .frame(width: 168, alignment: .leading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .skSoftShadow()
    }
}

struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? SKColor.primary : SKColor.line)
                    .frame(width: i == index ? 18 : 6, height: 6)
            }
        }
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }
}
