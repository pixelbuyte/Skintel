import SwiftUI
import WidgetKit

// MARK: - Timeline

struct AskSkintelEntry: TimelineEntry, Sendable {
    let date: Date
}

/// The quick-launch widget has no data: one entry, never refreshed.
struct AskSkintelProvider: TimelineProvider {
    func placeholder(in context: Context) -> AskSkintelEntry {
        AskSkintelEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AskSkintelEntry) -> Void) {
        completion(AskSkintelEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AskSkintelEntry>) -> Void) {
        completion(Timeline(entries: [AskSkintelEntry(date: Date())], policy: .never))
    }
}

// MARK: - Widget

struct AskSkintelWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.Kind.ask, provider: AskSkintelProvider()) { _ in
            AskSkintelWidgetView()
                .containerBackground(WidgetColor.background, for: .widget)
        }
        .configurationDisplayName("Ask Skintel")
        .description("Ask about your skin, scan a product, open your shelf or check in.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - View

private struct QuickLaunchItem: Identifiable, Sendable {
    let link: SkintelDeepLink
    let title: String
    let icon: String
    let accessibilityLabel: String

    var id: String { link.rawValue }

    static let all: [QuickLaunchItem] = [
        QuickLaunchItem(link: .scan, title: "Scan", icon: "viewfinder",
                        accessibilityLabel: "Scan a product"),
        QuickLaunchItem(link: .ask, title: "Ask Skintel", icon: "sparkles",
                        accessibilityLabel: "Ask Skintel"),
        QuickLaunchItem(link: .shelf, title: "Shelf", icon: "tray.full",
                        accessibilityLabel: "Open your shelf"),
        QuickLaunchItem(link: .checkin, title: "Check-in", icon: "face.smiling",
                        accessibilityLabel: "Check in your skin"),
    ]
}

struct AskSkintelWidgetView: View {
    var body: some View {
        VStack(spacing: 0) {
            Link(destination: SkintelDeepLink.ask.url) { pill }
                .accessibilityLabel("Ask Skintel about your skin")

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                ForEach(QuickLaunchItem.all) { item in
                    Link(destination: item.link.url) { QuickLaunchButton(item: item) }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(item.accessibilityLabel)
                }
            }
        }
        // Taps that miss every link still open Ask Skintel.
        .widgetURL(SkintelDeepLink.ask.url)
    }

    private var pill: some View {
        HStack(spacing: 8) {
            Image(decorative: "AskMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            Text("Ask about your skin…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(WidgetColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetColor.card)
                .frame(width: 28, height: 28)
                .background(WidgetColor.primary, in: Circle())
                .accessibilityHidden(true)
        }
        .padding(.leading, 6)
        .padding(.trailing, 7)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .background(WidgetColor.card, in: Capsule())
        .overlay(Capsule().strokeBorder(WidgetColor.line, lineWidth: 1))
    }
}

private struct QuickLaunchButton: View {
    let item: QuickLaunchItem

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: item.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(WidgetColor.primary)
                .frame(width: 42, height: 42)
                .background(WidgetColor.bubble, in: Circle())
            Text(item.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
