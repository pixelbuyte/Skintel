import SwiftUI

enum MainTab: Hashable, CaseIterable {
    case home, scanner, compare, journal

    var title: String {
        switch self {
        case .home: "Home"
        case .scanner: "Scanner"
        case .compare: "Compare"
        case .journal: "Journal"
        }
    }

    var icon: String {
        switch self {
        case .home: "square.grid.2x2"
        case .scanner: "viewfinder"
        case .compare: "arrow.left.arrow.right"
        case .journal: "book.closed"
        }
    }
}

/// Four tabs + a raised centre FAB (design §07). The FAB opens the scanner from anywhere
/// as a full-screen cover; the Scanner tab hosts the same surface inline.
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var tab: MainTab = .home
    @State private var presentScanner = false
    @State private var paywall: PaywallReason?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home: HomeView()
                case .scanner: ScannerHostView(embedded: true)
                case .compare: CompareView()
                case .journal: JournalView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: SKTabBar.height)
            }

            SKTabBar(selection: $tab) {
                if env.subscription.entitlement.canUseScanner {
                    Haptics.medium()
                    presentScanner = true
                } else {
                    paywall = .scanner
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $presentScanner) {
            ScannerHostView(embedded: false)
        }
        .sheet(item: $paywall) { reason in
            PaywallView(reason: reason)
        }
        .environment(\.openPaywall, OpenPaywallAction { reason in paywall = reason })
    }
}

struct SKTabBar: View {
    @Binding var selection: MainTab
    let fabAction: () -> Void
    static let height: CGFloat = 62

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tabItem(.home)
            tabItem(.scanner)
            fab
            tabItem(.compare)
            tabItem(.journal)
        }
        .padding(.top, 9)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(SKColor.cream.opacity(0.85))
                Rectangle().fill(SKColor.line).frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabItem(_ t: MainTab) -> some View {
        Button {
            if selection != t { Haptics.selection() }
            selection = t
        } label: {
            VStack(spacing: 4) {
                Image(systemName: t.icon).font(.system(size: 21, weight: .regular))
                Text(t.title).font(SKFont.tab)
            }
            .foregroundStyle(selection == t ? SKColor.primary : SKColor.muted)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height - 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.title)
        .accessibilityAddTraits(selection == t ? [.isButton, .isSelected] : .isButton)
    }

    private var fab: some View {
        Button(action: fabAction) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(SKColor.cream)
                .frame(width: 56, height: 56)
                .background(SKColor.primary, in: Circle())
                .overlay(Circle().stroke(SKColor.bg, lineWidth: 4))
                .skPrimaryGlow(strength: 0.45)
        }
        .buttonStyle(SKPressStyle(scale: 0.92))
        .offset(y: -26)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Scan a product")
    }
}

// MARK: - Paywall routing available to every screen

enum PaywallReason: String, Identifiable, Sendable {
    case scanner, productLimit, compare, recommend, routine, journalAnalysis, culprits, general
    var id: String { rawValue }
}

struct OpenPaywallAction {
    let handler: @MainActor (PaywallReason) -> Void
    @MainActor func callAsFunction(_ reason: PaywallReason) { handler(reason) }
}

private struct OpenPaywallKey: EnvironmentKey {
    static let defaultValue = OpenPaywallAction { _ in }
}

extension EnvironmentValues {
    var openPaywall: OpenPaywallAction {
        get { self[OpenPaywallKey.self] }
        set { self[OpenPaywallKey.self] = newValue }
    }
}
