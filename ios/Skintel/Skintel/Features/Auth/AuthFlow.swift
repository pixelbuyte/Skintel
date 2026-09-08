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
            Spacer(minLength: SKSpace.xxl)
            FloatingShelfCards(appeared: appeared)
                .frame(height: 300)
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

            Spacer(minLength: SKSpace.xl)
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

    private struct Card { let name: String; let score: Int; let tone: SKTone; let label: String; let tile: (Color, Color) }
    private let cards: [Card] = [
        Card(name: "CeraVe Moisturizer", score: 86, tone: .good, label: "Good", tile: (Color(hex: 0xD6E0EA), Color(hex: 0x3F5E7A))),
        Card(name: "Fragrance-heavy lotion", score: 31, tone: .bad, label: "Skip it", tile: (Color(hex: 0xEED2CC), Color(hex: 0x8E4538))),
        Card(name: "Paula's Choice 2% BHA", score: 64, tone: .caution, label: "Caution", tile: (Color(hex: 0xE9DEC3), Color(hex: 0x7A6230))),
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
                .fill(LinearGradient(colors: [c.tile.0, c.tile.0.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 62)
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
