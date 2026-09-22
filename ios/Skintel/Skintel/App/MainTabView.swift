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

/// Four tabs + a centre FAB (design §07), floating Liquid Glass on iOS 26+ and the raised
/// FAB over a cream bar before that. The FAB opens the scanner from anywhere as a
/// full-screen cover; the Scanner tab hosts the same surface inline.
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
    /// Space reserved under screen content so the last row scrolls clear of the bar.
    static let height: CGFloat = 62

    var body: some View {
        // The compiler check keeps the build green on a pre-26 SDK (CI runs `xcode: latest`);
        // Xcode 26 ships Swift 6.2 alongside the SDK that has the Liquid Glass APIs.
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            SKGlassTabBar(selection: $selection, fabAction: fabAction)
        } else {
            classicBar
        }
        #else
        classicBar
        #endif
    }

    private var classicBar: some View {
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

#if compiler(>=6.2)
private let glassTabBarSpace = "SKGlassTabBar"

/// iOS 26 Liquid Glass bar: two floating glass capsules with the terracotta scan FAB between
/// them, sharing one `GlassEffectContainer` so they sample the same backdrop. Labels use
/// `Color.primary` rather than `SKColor.muted` so they stay legible when the glass adapts
/// over dark content (the embedded Scanner tab is a black camera view).
///
/// Like the system iOS 26 tab bar, you can press and slide: the pill follows the finger
/// across both capsules (ticking on each tab) and the tab switches on lift. Switching only
/// on lift keeps the Scanner tab's camera from starting and stopping mid-slide.
@available(iOS 26, *)
private struct SKGlassTabBar: View {
    @Binding var selection: MainTab
    let fabAction: () -> Void
    @Namespace private var selectionPill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tabFrames: [MainTab: CGRect] = [:]
    /// Tab under the finger while pressing; resets to nil when the touch ends or is cancelled.
    @GestureState private var scrubbing: MainTab? = nil

    private var highlighted: MainTab { scrubbing ?? selection }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                capsule(.home, .scanner)
                fab
                capsule(.compare, .journal)
            }
        }
        .coordinateSpace(.named(glassTabBarSpace))
        .padding(.horizontal, 16)
        // Scoped here so only the selection pill animates, not MainTabView's screen swap.
        // Reduce Motion still shows the pill move, just as an instant cut, not a slide.
        .animation(reduceMotion ? nil : SKAnimation.emil(0.4), value: highlighted)
    }

    private func capsule(_ leading: MainTab, _ trailing: MainTab) -> some View {
        HStack(spacing: 0) {
            tabItem(leading)
            tabItem(trailing)
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: Capsule())
        .contentShape(Capsule())
        .gesture(scrub)
    }

    /// Starts on touch-down (so a plain tap still works) and keeps tracking after the finger
    /// leaves its capsule, so one slide can cross the FAB into the other capsule.
    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(glassTabBarSpace))
            .updating($scrubbing) { value, state, _ in
                guard let t = nearestTab(to: value.location.x), t != state else { return }
                if t != (state ?? selection) { Haptics.selection() }
                state = t
            }
            .onEnded { value in
                guard let t = nearestTab(to: value.location.x), t != selection else { return }
                selection = t
            }
    }

    private func nearestTab(to x: CGFloat) -> MainTab? {
        tabFrames.min { abs($0.value.midX - x) < abs($1.value.midX - x) }?.key
    }

    private func tabItem(_ t: MainTab) -> some View {
        let isHighlighted = highlighted == t
        return VStack(spacing: 3) {
            Image(systemName: t.icon).font(.system(size: 20, weight: .regular))
            Text(t.title).font(SKFont.tab)
        }
        .foregroundStyle(isHighlighted ? SKColor.primary : Color.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background {
            if isHighlighted {
                Capsule()
                    .fill(SKColor.primary.opacity(0.12))
                    .matchedGeometryEffect(id: "selection", in: selectionPill)
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(glassTabBarSpace))
        } action: { frame in
            tabFrames[t] = frame
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t.title)
        .accessibilityAddTraits(selection == t ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            guard selection != t else { return }
            Haptics.selection()
            selection = t
        }
    }

    private var fab: some View {
        Button(action: fabAction) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(SKColor.cream)
                .frame(width: 56, height: 56)
                .glassEffect(.regular.tint(SKColor.primary).interactive(), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan a product")
    }
}
#endif

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
