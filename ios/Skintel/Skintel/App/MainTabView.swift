import Combine
import SwiftUI
import UIKit

enum MainTab: Hashable, CaseIterable {
    case today, shelf, ask, insights, you

    var title: String {
        switch self {
        case .today: "Today"
        case .shelf: "Shelf"
        case .ask: "Ask"
        case .insights: "Insights"
        case .you: "You"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .shelf: "tray.full"
        case .ask: "sparkles"
        case .insights: "chart.bar"
        case .you: "person"
        }
    }
}

/// Today · Shelf · (+) · Insights · You: floating Liquid Glass on iOS 26+, the raised FAB
/// over a cream bar before that. The + opens quick actions (scan, check in, add, compare).
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var tab: MainTab = .today
    @State private var presentScanner = false
    /// A Skintel+ gate's full-screen wall, and the plans sheet for `.general`.
    @State private var wall: ProLockedView.Feature?
    @State private var plans: PaywallReason?
    /// The wall last shown, so an unlock can carry on to that feature.
    @State private var lastWall: ProLockedView.Feature?
    @State private var showQuick = false
    @State private var pending: QuickAction?
    @State private var showCheckIn = false
    @State private var showAddProduct = false
    @State private var showCompare = false
    @State private var showAssistant = false
    @State private var showShelf = false
    @State private var keyboardUp = false
    @AppStorage(AssistantPlacement.key) private var assistantPlacement = AssistantPlacement.tab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .today: HomeView()
                case .shelf: ShelfTab()
                // Ask reserves the bar's space itself: an inset from out here doesn't reach a
                // composer pinned inside its own NavigationStack.
                case .ask: AssistantView(showsClose: false, tabBarClearance: keyboardUp ? 0 : SKTabBar.height + SKSpace.md, leave: { tab = .today })
                case .insights: InsightsView(leave: { tab = .today })
                case .you: YouTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: tab == .ask || keyboardUp || onLockedTab ? 0 : SKTabBar.height)
            }

            // Typing gets the whole screen; the bar comes back when the keyboard goes. A
            // Skintel+ tab's wall gets the whole screen too.
            if !keyboardUp && !onLockedTab {
                SKTabBar(selection: tabSelection) {
                    Haptics.medium()
                    showQuick = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(reduceMotion ? nil : SKAnimation.ios(0.25)) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(reduceMotion ? nil : SKAnimation.ios(0.25)) { keyboardUp = false }
        }
        .onChange(of: assistantPlacement) { _, placement in
            if placement == AssistantPlacement.tab && tab == .shelf { tab = .today }
            if placement == AssistantPlacement.corner && tab == .ask { tab = .today }
        }
        .fullScreenCover(isPresented: $presentScanner) {
            ScannerHostView(embedded: false)
        }
        .fullScreenCover(item: $wall, onDismiss: wallClosed) { feature in
            ProLockedView(feature: feature)
        }
        .sheet(item: $plans) { reason in
            PaywallView(reason: reason)
        }
        .sheet(isPresented: $showQuick, onDismiss: runPending) {
            QuickActionsSheet(canScan: env.subscription.entitlement.canUseScanner,
                              assistantInTab: assistantPlacement == AssistantPlacement.tab) { action in
                pending = action
                showQuick = false
            }
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .presentationBackground(SKColor.cream)
        }
        // Each sheet brings its own gates: a wall can't present from here over a sheet.
        .sheet(isPresented: $showCheckIn) { CheckInSheet() }
        .sheet(isPresented: $showAddProduct) { NavigationStack { ProductFormView(mode: .add(prefill: nil)) }.skProGates() }
        .sheet(isPresented: $showCompare) { CompareView().skProGates() }
        .skAskSheet(isPresented: $showAssistant)
        .sheet(isPresented: $showShelf) { ShelfTab().skProGates() }
        .environment(\.openPaywall, OpenPaywallAction { reason in gate(reason) })
        .onChange(of: env.pendingDeepLink, initial: true) { consumeDeepLink() }
        .onChange(of: env.subscription.loaded) { consumeDeepLink() }
    }

    // MARK: Widget deep links

    /// Routes `env.pendingDeepLink` (set by `RootView.onOpenURL`) through the same paths the
    /// + menu and tab bar use. Scan waits for the subscription row so a Pro member opening
    /// the Scan widget on a cold launch never sees the paywall flash before `warmUp` lands.
    private func consumeDeepLink() {
        guard let link = env.pendingDeepLink else { return }
        if link == .scan && !env.subscription.loaded { return }
        env.pendingDeepLink = nil
        Task { await openDeepLink(link) }
    }

    private var isPresenting: Bool {
        presentScanner || wall != nil || plans != nil || showQuick || showCheckIn || showAddProduct
            || showCompare || showAssistant || showShelf
    }

    private func openDeepLink(_ link: SkintelDeepLink) async {
        if isPresenting {
            // Only one sheet/cover can be up; close whatever is showing, let the dismissal
            // animation finish, then present the destination.
            pending = nil
            showQuick = false
            presentScanner = false
            lastWall = nil
            wall = nil
            plans = nil
            showCheckIn = false
            showAddProduct = false
            showCompare = false
            showAssistant = false
            showShelf = false
            try? await Task.sleep(for: .milliseconds(650))
        }
        let assistantInTab = assistantPlacement == AssistantPlacement.tab
        switch link {
        case .scan:
            openScanner()
        case .ask:
            if assistantInTab { select(.ask) } else { showAssistant = true }
        case .shelf:
            // Shelf owns the tab slot only when Ask Skintel lives on Today.
            if assistantInTab { showShelf = true } else { tab = .shelf }
        case .checkin:
            showCheckIn = true
        }
    }

    /// The Skintel+ gate for the scanner, shared by the + menu and the Scan widget.
    private func openScanner() {
        if env.subscription.entitlement.canUseScanner { presentScanner = true } else { gate(.scanner) }
    }

    // MARK: Skintel+ gates

    /// Every gate below the tab bar lands here: a gated feature covers the whole screen with
    /// its wall (the plans open from the wall's button); `.general` opens the plans.
    private func gate(_ reason: PaywallReason) {
        if let feature = ProLockedView.Feature(reason) {
            lastWall = feature
            wall = feature
        } else {
            plans = reason
        }
    }

    /// A tab that is itself a Skintel+ feature.
    private static func lockedFeature(for tab: MainTab) -> ProLockedView.Feature? {
        switch tab {
        case .ask: return .ask
        case .insights: return .insights
        case .today, .shelf, .you: return nil
        }
    }

    /// Free members on a Skintel+ tab (membership still loading, or it lapsed while they
    /// were there) see its wall as the tab's root; the bar hides so the wall is the screen.
    private var onLockedTab: Bool {
        Self.lockedFeature(for: tab) != nil && !env.subscription.entitlement.isPro
    }

    /// Tab taps: a Free member tapping a Skintel+ tab gets its wall over everything and
    /// stays where they were. Until the membership row loads, the tab opens and shows its
    /// own wall, so a member never sees a wall flash up and has to close it.
    private var tabSelection: Binding<MainTab> {
        Binding(get: { tab }, set: { select($0) })
    }

    private func select(_ next: MainTab) {
        if let feature = Self.lockedFeature(for: next), env.subscription.loaded, !env.subscription.entitlement.isPro {
            lastWall = feature
            wall = feature
        } else {
            tab = next
        }
    }

    /// After a wall closes: if the server now confirms Skintel+, go on to the tab that was
    /// asked for. Anything else stays put for the person to try again.
    private func wallClosed() {
        guard let feature = lastWall else { return }
        lastWall = nil
        guard env.subscription.entitlement.isPro else { return }
        switch feature {
        case .ask:
            if assistantPlacement == AssistantPlacement.tab { tab = .ask } else { showAssistant = true }
        case .insights:
            tab = .insights
        default:
            break
        }
    }

    /// The menu sheet has to finish dismissing before the next sheet or cover can present.
    private func runPending() {
        guard let action = pending else { return }
        pending = nil
        switch action {
        case .scan:
            openScanner()
        case .checkIn:
            showCheckIn = true
        case .addByHand:
            if env.subscription.entitlement.canAddProduct(currentCount: env.products.products.count) {
                showAddProduct = true
            } else {
                gate(.productLimit)
            }
        case .compare:
            if env.subscription.entitlement.isPro { showCompare = true } else { gate(.compare) }
        case .ask:
            showAssistant = true
        case .shelf:
            showShelf = true
        }
    }
}

enum QuickAction: Hashable {
    case scan, checkIn, ask, shelf, addByHand, compare
}

/// What the + button opens: the four things people do outside their routine.
private struct QuickActionsSheet: View {
    let canScan: Bool
    /// Ask Skintel has its own tab, so the menu offers Shelf (which lost its tab) instead.
    let assistantInTab: Bool
    let choose: (QuickAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SKSpace.sm) {
            Text("Add or log").font(SKFont.section).foregroundStyle(SKColor.ink)
                .padding(.horizontal, SKSpace.xs).padding(.top, SKSpace.lg).padding(.bottom, SKSpace.xs)
            row(icon: "viewfinder", tint: SKColor.primary, title: "Scan a product",
                subtitle: "Barcode or ingredient label", badge: canScan ? nil : "Pro", action: .scan)
            row(icon: "face.smiling", tint: SKColor.goodFg, title: "Check in skin",
                subtitle: "How is your skin today?", badge: nil, action: .checkIn)
            if assistantInTab {
                row(icon: "tray.full", tint: SKColor.ink, title: "Your shelf",
                    subtitle: "Every product you've added", badge: nil, action: .shelf)
            } else {
                row(icon: "sparkles", tint: SKColor.primary, title: "Ask Skintel",
                    subtitle: "Questions about your skin and products", badge: nil, action: .ask)
            }
            row(icon: "square.and.pencil", tint: SKColor.ink, title: "Add by hand",
                subtitle: "Search or paste an ingredient list", badge: nil, action: .addByHand)
            row(icon: "arrow.left.arrow.right", tint: SKColor.ink, title: "Compare products",
                subtitle: "Side by side, up to three", badge: nil, action: .compare)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SKSpace.xl)
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String, badge: String?, action: QuickAction) -> some View {
        Button { choose(action) } label: {
            HStack(spacing: SKSpace.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(SKFont.cardTitle).foregroundStyle(SKColor.ink)
                    Text(subtitle).font(SKFont.secondary).foregroundStyle(SKColor.muted)
                }
                Spacer(minLength: 0)
                if let badge { SKChip(badge, tone: .neutral) }
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(SKPressStyle())
        .accessibilityElement(children: .combine)
    }
}

/// The shelf as a tab: every product, newest first.
struct ShelfTab: View {
    var body: some View {
        NavigationStack { ProductsListView() }
            .tint(SKColor.primary)
    }
}

/// Profile, membership and settings as a tab.
struct YouTab: View {
    var body: some View {
        NavigationStack { SettingsView(isRoot: true) }
            .tint(SKColor.primary)
    }
}

struct SKTabBar: View {
    @Binding var selection: MainTab
    let fabAction: () -> Void
    /// Space reserved under screen content so the last row scrolls clear of the bar.
    static let height: CGFloat = 62
    @AppStorage(AssistantPlacement.key) private var assistantPlacement = AssistantPlacement.tab

    private var secondTab: MainTab { assistantPlacement == AssistantPlacement.tab ? .ask : .shelf }

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            SKGlassTabBar(selection: $selection, fabAction: fabAction, second: secondTab)
        } else {
            classicBar
        }
        #else
        classicBar
        #endif
    }

    private var classicBar: some View {
        HStack(alignment: .top, spacing: 0) {
            tabItem(.today)
            tabItem(secondTab)
            fab
            tabItem(.insights)
            tabItem(.you)
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
        .accessibilityLabel("Add or log")
    }
}

#if compiler(>=6.2)
/// iOS 26 Liquid Glass bar: two floating glass capsules (Home/Scanner, Compare/Journal)
/// with the terracotta-tinted scan FAB between them, in one `GlassEffectContainer` so they
/// sample the same backdrop. Unselected items use `Color.primary` rather than
/// `SKColor.muted` so they follow the glass's legibility adaptation over dark content
/// (the embedded Scanner tab is a black camera view).
@available(iOS 26, *)
private struct SKGlassTabBar: View {
    @Binding var selection: MainTab
    let fabAction: () -> Void
    let second: MainTab
    @Namespace private var selectionPill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                capsule(.today, second)
                fab
                capsule(.insights, .you)
            }
        }
        .padding(.horizontal, SKSpace.lg)
        // Scoped to the bar so only the selection pill moves, never MainTabView's screen swap.
        .animation(reduceMotion ? nil : SKAnimation.emil(0.4), value: selection)
    }

    private func capsule(_ leading: MainTab, _ trailing: MainTab) -> some View {
        HStack(spacing: 0) {
            tabItem(leading)
            tabItem(trailing)
        }
        .padding(4)
        .glassEffect(Glass.regular.interactive(), in: Capsule())
    }

    private func tabItem(_ t: MainTab) -> some View {
        let isSelected = selection == t
        return Button {
            if selection != t { Haptics.selection() }
            selection = t
        } label: {
            VStack(spacing: 3) {
                Image(systemName: t.icon).font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                Text(t.title).font(SKFont.tab)
            }
            .foregroundStyle(isSelected ? SKColor.primary : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                if isSelected {
                    Capsule()
                        .fill(SKColor.primary.opacity(0.12))
                        .matchedGeometryEffect(id: "selection", in: selectionPill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var fab: some View {
        Button(action: fabAction) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(SKColor.cream)
                .frame(width: 56, height: 56)
                .glassEffect(Glass.regular.tint(SKColor.primary).interactive(), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add or log")
    }
}
#endif

// MARK: - Paywall routing available to every screen

enum PaywallReason: String, Identifiable, Sendable {
    case scanner, productLimit, compare, recommend, routine, journalAnalysis, culprits, assistant, general
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
