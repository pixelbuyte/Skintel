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
    @State private var visited: Set<MainTab> = [.home]
    @State private var scrubbing = false
    /// Whether the Scanner tab's camera is mounted: false while a slide is passing over it.
    @State private var scannerLive = false
    @State private var presentScanner = false
    @State private var paywall: PaywallReason?

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                // Like a system TabView, a visited page stays alive while hidden: switching
                // back is instant, keeps scroll/navigation state, and doesn't re-run `.task`
                // loads each time a finger slides across its tab.
                ForEach([MainTab.home, .compare, .journal], id: \.self) { t in
                    if tab == t || visited.contains(t) {
                        page(t)
                            .opacity(tab == t ? 1 : 0)
                            .allowsHitTesting(tab == t)
                            .accessibilityHidden(tab != t)
                    }
                }
                // The camera is torn down whenever Scanner isn't showing, and only starts once
                // a slide settles on it, so passing over the tab never spins it up.
                if tab == .scanner {
                    if scannerLive {
                        ScannerHostView(embedded: true)
                    } else {
                        SKColor.scannerBg.ignoresSafeArea()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: SKTabBar.height)
            }

            SKTabBar(selection: $tab, isScrubbing: $scrubbing) {
                if env.subscription.entitlement.canUseScanner {
                    Haptics.medium()
                    presentScanner = true
                } else {
                    paywall = .scanner
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: tab) { _, t in
            visited.insert(t)
            scannerLive = t == .scanner && !scrubbing
        }
        .onChange(of: scrubbing) { _, sliding in
            if !sliding, tab == .scanner { scannerLive = true }
        }
        .fullScreenCover(isPresented: $presentScanner) {
            ScannerHostView(embedded: false)
        }
        .sheet(item: $paywall) { reason in
            PaywallView(reason: reason)
        }
        .environment(\.openPaywall, OpenPaywallAction { reason in paywall = reason })
    }

    @ViewBuilder
    private func page(_ t: MainTab) -> some View {
        switch t {
        case .home: HomeView()
        case .compare: CompareView()
        case .journal: JournalView()
        case .scanner: EmptyView()
        }
    }
}

struct SKTabBar: View {
    @Binding var selection: MainTab
    /// True while a finger is sliding across the tabs (the iOS 26 bar; the classic bar is tap-only).
    @Binding var isScrubbing: Bool
    let fabAction: () -> Void
    /// Space reserved under screen content so the last row scrolls clear of the bar.
    static let height: CGFloat = 62

    var body: some View {
        // The compiler check keeps the build green on a pre-26 SDK (CI runs `xcode: latest`);
        // Xcode 26 ships Swift 6.2 alongside the SDK that has the Liquid Glass APIs.
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            SKGlassTabBar(selection: $selection, isScrubbing: $isScrubbing, fabAction: fabAction)
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
/// Like the system iOS 26 tab bar you can press and slide: the pill tracks the finger on a
/// spring, and the tab under it becomes the selected tab as you go (with a tick), so the
/// screen changes live. The capsules use non-interactive glass so they don't stretch toward
/// the finger mid-slide, and the container never blends them into the tinted FAB.
@available(iOS 26, *)
private struct SKGlassTabBar: View {
    @Binding var selection: MainTab
    @Binding var isScrubbing: Bool
    let fabAction: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tabFrames: [MainTab: CGRect] = [:]
    /// Finger x in bar space while touching the tabs; resets to nil on lift or cancel.
    @GestureState private var touchX: CGFloat? = nil

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 10) {
                capsule(.home, .scanner)
                fab
                capsule(.compare, .journal)
            }
        }
        .coordinateSpace(.named(glassTabBarSpace))
        .padding(.horizontal, 16)
        // Scoped here so only the bar animates, not MainTabView's screen swap.
        .animation(lensAnimation, value: lensX)
        // A cancelled touch skips onEnded; the gesture state resetting still clears it.
        .onChange(of: touchX == nil) { _, idle in if idle { isScrubbing = false } }
    }

    /// Tight while following a finger, a softer settle once it lets go. Reduce Motion keeps
    /// the pill moving with the finger, just without the spring.
    private var lensAnimation: Animation? {
        if reduceMotion { return nil }
        return touchX == nil
            ? Animation.spring(response: 0.38, dampingFraction: 0.74)
            : Animation.interactiveSpring(response: 0.2, dampingFraction: 0.86)
    }

    /// Pill centre in bar space: under the finger while pressing (held inside that finger's
    /// capsule), otherwise on the selected tab.
    private var lensX: CGFloat? {
        guard let x = touchX, let t = nearestTab(to: x) else { return tabFrames[selection]?.midX }
        let pair = Self.capsulePair(containing: t)
        guard let lo = tabFrames[pair.0]?.midX, let hi = tabFrames[pair.1]?.midX else {
            return tabFrames[selection]?.midX
        }
        return min(max(x, lo), hi)
    }

    private static func capsulePair(containing t: MainTab) -> (MainTab, MainTab) {
        switch t {
        case .home, .scanner: return (MainTab.home, MainTab.scanner)
        case .compare, .journal: return (MainTab.compare, MainTab.journal)
        }
    }

    private func capsule(_ leading: MainTab, _ trailing: MainTab) -> some View {
        HStack(spacing: 0) {
            tabItem(leading)
            tabItem(trailing)
        }
        .background { lens(from: leading) }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
        .contentShape(Capsule())
        .gesture(scrub)
    }

    /// Drawn in both capsules at the same bar x and clipped to each, so crossing between
    /// them reads as the pill sliding under the FAB rather than jumping.
    @ViewBuilder
    private func lens(from leading: MainTab) -> some View {
        if let x = lensX, let origin = tabFrames[leading] {
            Capsule()
                .fill(SKColor.primary.opacity(touchX == nil ? 0.12 : 0.18))
                .frame(width: origin.width, height: origin.height)
                .offset(x: x - origin.midX)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .clipShape(Capsule())
        }
    }

    /// Starts on touch-down (so a plain tap still works) and keeps tracking after the finger
    /// leaves its capsule, so one slide can cross the FAB into the other capsule.
    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(glassTabBarSpace))
            .updating($touchX) { value, state, _ in
                state = value.location.x
            }
            .onChanged { value in
                // Set before `selection` so MainTabView sees the slide when the tab changes.
                if !isScrubbing { isScrubbing = true }
                guard let t = nearestTab(to: value.location.x), t != selection else { return }
                Haptics.selection()
                selection = t
            }
            .onEnded { _ in isScrubbing = false }
    }

    private func nearestTab(to x: CGFloat) -> MainTab? {
        tabFrames.min { abs($0.value.midX - x) < abs($1.value.midX - x) }?.key
    }

    private func tabItem(_ t: MainTab) -> some View {
        let isSelected = selection == t
        return VStack(spacing: 3) {
            Image(systemName: t.icon).font(.system(size: 20, weight: .regular))
            Text(t.title).font(SKFont.tab)
        }
        .foregroundStyle(isSelected ? SKColor.primary : Color.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
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
