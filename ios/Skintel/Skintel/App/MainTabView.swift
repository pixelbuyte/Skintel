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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .id(tab)
            .transition(.opacity)
            .zIndex(0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: SKTabBar.height + 18)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: tab)

            SKTabBar(selection: $tab) {
                if env.subscription.entitlement.canUseScanner {
                    Haptics.tap()
                    presentScanner = true
                } else {
                    paywall = .scanner
                }
            }
            .zIndex(1)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $presentScanner) {
            ScannerHostView(embedded: false)
        }
        .sheet(item: $paywall) { reason in
            PaywallView(reason: reason)
        }
        .environment(\.openPaywall, OpenPaywallAction { reason in paywall = reason })
        .environment(\.openScanner, OpenScannerAction {
            if env.subscription.entitlement.canUseScanner {
                Haptics.tap()
                presentScanner = true
            } else {
                paywall = .scanner
            }
        })
    }
}

struct SKTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight
    @Binding var selection: MainTab
    let fabAction: () -> Void
    static let height: CGFloat = 62

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home)
            tabItem(.scanner)
            fab
            tabItem(.compare)
            tabItem(.journal)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .skGlassControl(in: RoundedRectangle(cornerRadius: 30, style: .continuous), interactive: false)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: selection)
    }

    private func tabItem(_ t: MainTab) -> some View {
        Button {
            guard selection != t else { return }
            selection = t
        } label: {
            VStack(spacing: 4) {
                Image(systemName: t.icon).font(.system(size: 21, weight: .regular))
                Text(t.title).font(SKFont.tab)
            }
            .foregroundStyle(selection == t ? SKColor.primary : SKColor.muted)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height - 9)
            .background {
                if selection == t {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(SKColor.blush)
                        .matchedGeometryEffect(id: "selectedTab", in: highlight)
                }
            }
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
                .skPrimaryGlow(strength: 0.2)
        }
        .buttonStyle(SKPressStyle())
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

    var openScanner: OpenScannerAction {
        get { self[OpenScannerKey.self] }
        set { self[OpenScannerKey.self] = newValue }
    }
}

struct OpenScannerAction {
    let handler: @MainActor () -> Void
    @MainActor func callAsFunction() { handler() }
}

private struct OpenScannerKey: EnvironmentKey {
    static let defaultValue = OpenScannerAction { }
}
