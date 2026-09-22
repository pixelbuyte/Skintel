import SwiftUI

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

struct WelcomeView: View {
    let getStarted: () -> Void
    let haveAccount: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: SKSpace.xl) {
                    VStack(spacing: SKSpace.sm) {
                        FloatingShelfCards(appeared: appeared)
                            .frame(height: 300)
                            .accessibilityHidden(true)
                        Text("Sample products · example results")
                            .font(SKFont.caption).foregroundStyle(SKColor.muted)
                    }
                    .padding(.top, SKSpace.lg)

                    VStack(alignment: .leading, spacing: SKSpace.lg) {
                        (Text("Know what ").font(SKFont.editorialHero)
                         + Text("touches").font(SKFont.editorial(36, relativeTo: .largeTitle, italic: true)).foregroundColor(SKColor.primary)
                         + Text(" your skin.").font(SKFont.editorialHero))
                            .foregroundStyle(SKColor.ink)
                            .tracking(-1.2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Scan a skincare product. Understand its ingredients — for **your skin**.")
                            .font(SKFont.sans(17, relativeTo: .body))
                            .foregroundStyle(SKColor.muted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .skPagePadding()
                }
                .padding(.bottom, SKSpace.xl)
            }
            .scrollIndicators(.hidden)

            PageDots(count: 3, index: 0).padding(.bottom, SKSpace.lg)

            VStack(spacing: SKSpace.sm) {
                SKButton(title: "Get started", action: getStarted)
                SKButton(title: "I already have an account", kind: .ghost, action: haveAccount)
            }
            .skPagePadding()
            .padding(.bottom, SKSpace.lg)
        }
        .skPageBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation(SKAnimation.emil(0.9).delay(0.1)) { appeared = true } }
        }
    }
}

/// Three tilted verdict cards (good / bad / caution) — the promise before any UI copy.
private struct FloatingShelfCards: View {
    let appeared: Bool

    private struct Card { let name: String; let score: Int; let tone: SKTone; let label: String; let artwork: OnboardingProductArtwork.Kind }
    private let cards: [Card] = [
        Card(name: "Daily moisturizer", score: 86, tone: .good, label: "Good", artwork: .moisturizer),
        Card(name: "Scented lotion", score: 31, tone: .bad, label: "Skip it", artwork: .lotion),
        Card(name: "Exfoliating serum", score: 64, tone: .caution, label: "Caution", artwork: .serum),
    ]

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, 430)
            let cardWidth = width * 0.43
            ZStack {
                card(cards[0], width: cardWidth).rotationEffect(.degrees(-6)).offset(x: -width * 0.23, y: -40)
                card(cards[1], width: cardWidth).rotationEffect(.degrees(5)).offset(x: width * 0.23, y: -49)
                card(cards[2], width: cardWidth).rotationEffect(.degrees(1)).offset(x: 10, y: 64)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94)
        // The hero is decorative. Keep the small demonstration cards legible and
        // bounded; the actual introduction and controls still follow Dynamic Type.
        .dynamicTypeSize(.large)
    }

    private func card(_ c: Card, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            OnboardingProductArtwork(kind: c.artwork)
                .frame(width: 56, height: 66)
                .background(SKColor.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(c.name).font(SKFont.sans(15, weight: .bold, relativeTo: .subheadline)).foregroundStyle(SKColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            SKChip("\(c.score) · \(c.label)", tone: c.tone, dot: true)
        }
        .padding(SKSpace.md)
        .frame(width: width, alignment: .leading)
        .background(SKColor.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(SKColor.line))
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
