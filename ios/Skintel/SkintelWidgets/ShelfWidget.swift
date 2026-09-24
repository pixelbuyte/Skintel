import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ShelfEntry: TimelineEntry, Sendable {
    enum Content: Sendable, Equatable {
        /// No snapshot in the App Group yet (never opened, or signed out).
        case unknown
        case shelf(ShelfWidgetSnapshot)
    }

    let date: Date
    let content: Content
}

/// Reads the snapshot the app writes to the App Group. The app reloads this timeline
/// whenever the shelf changes, so the widget never polls.
struct ShelfProvider: TimelineProvider {
    private static let sample = ShelfWidgetSnapshot(count: 4, names: ["Gentle Cleanser", "Niacinamide Serum", "Daily SPF 50"])

    func placeholder(in context: Context) -> ShelfEntry {
        ShelfEntry(date: Date(), content: .shelf(Self.sample))
    }

    func getSnapshot(in context: Context, completion: @escaping (ShelfEntry) -> Void) {
        let stored = ShelfSnapshotStore.read(from: ShelfSnapshotStore.sharedDefaults())
        // The widget gallery shows sample content until the app has written a real shelf.
        let snapshot = stored ?? (context.isPreview ? Self.sample : nil)
        completion(ShelfEntry(date: Date(), content: snapshot.map(ShelfEntry.Content.shelf) ?? .unknown))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShelfEntry>) -> Void) {
        let stored = ShelfSnapshotStore.read(from: ShelfSnapshotStore.sharedDefaults())
        let entry = ShelfEntry(date: Date(), content: stored.map(ShelfEntry.Content.shelf) ?? .unknown)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Widget

struct ShelfWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.Kind.shelf, provider: ShelfProvider()) { entry in
            ShelfWidgetView(entry: entry)
                .containerBackground(WidgetColor.background, for: .widget)
        }
        .configurationDisplayName("Shelf")
        .description("How many products are on your shelf, and the latest ones you added.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - View

struct ShelfWidgetView: View {
    let entry: ShelfEntry

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityAddTraits(.isButton)
            .widgetURL(SkintelDeepLink.shelf.url)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case .unknown:
            message("Open Skintel to see your shelf")
        case .shelf(let snapshot):
            if snapshot.count == 0 {
                message("Add your first product")
            } else {
                filled(snapshot)
            }
        }
    }

    private var label: some View {
        Text("YOUR SHELF")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(WidgetColor.primary)
            .lineLimit(1)
    }

    private func mascot(size: CGFloat) -> some View {
        Image(decorative: "ShelfMascot")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func filled(_ snapshot: ShelfWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    label
                    Text("\(snapshot.count)")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundStyle(WidgetColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 4)
                mascot(size: 50)
            }
            Spacer(minLength: 6)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(snapshot.names.enumerated()), id: \.offset) { _, name in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(WidgetColor.primary)
                            .frame(width: 4, height: 4)
                        Text(name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WidgetColor.ink)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func message(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                label
                Spacer(minLength: 4)
                mascot(size: 58)
            }
            Spacer(minLength: 4)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WidgetColor.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
    }

    private var accessibilityText: String {
        switch entry.content {
        case .unknown:
            return "Shelf. Open Skintel to see your shelf."
        case .shelf(let snapshot):
            if snapshot.count == 0 { return "Shelf is empty. Add your first product." }
            let noun = snapshot.count == 1 ? "product" : "products"
            let names = snapshot.names.joined(separator: ", ")
            return names.isEmpty
                ? "Shelf: \(snapshot.count) \(noun)."
                : "Shelf: \(snapshot.count) \(noun), including \(names)."
        }
    }
}
