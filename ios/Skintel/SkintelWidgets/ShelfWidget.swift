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
    private static let sample = ShelfWidgetSnapshot(count: 4, names: ["Gentle Cleanser", "Niacinamide Serum", "Daily SPF 50"],
                                                    outcomes: [.good, .good, .unsure])

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
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

// MARK: - View

struct ShelfWidgetView: View {
    let entry: ShelfEntry
    @Environment(\.widgetFamily) private var family

    /// The small widget lists at most this many names, even though the snapshot holds more.
    private static let smallNameCount = 3
    private static let largeTileCount = 4

    var body: some View {
        Group {
            if family == .systemLarge {
                largeContent
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(family == .systemLarge ? largeAccessibilityText : accessibilityText)
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
                ForEach(Array(snapshot.names.prefix(Self.smallNameCount).enumerated()), id: \.offset) { _, name in
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

    // MARK: Large

    private enum LargeTile {
        case product(name: String, outcome: ShelfWidgetOutcome?)
        /// Stands in for every product the grid has no room for.
        case more(Int)
        case empty
    }

    @ViewBuilder
    private var largeContent: some View {
        switch entry.content {
        case .unknown:
            largeMessage("Open Skintel to see your shelf")
        case .shelf(let snapshot):
            if snapshot.count == 0 {
                largeMessage("Add your first product")
            } else {
                largeFilled(snapshot)
            }
        }
    }

    /// Always `largeTileCount` tiles, so the grid keeps its shape with one or two products.
    /// When not every product fits (or an older snapshot lacks names), the last tile is "+N more".
    private func largeTiles(_ snapshot: ShelfWidgetSnapshot) -> [LargeTile] {
        let slots = Self.largeTileCount
        let fitsAll = snapshot.count <= slots && snapshot.names.count >= snapshot.count
        let shown = fitsAll ? min(snapshot.names.count, slots) : min(snapshot.names.count, slots - 1)
        var tiles: [LargeTile] = (0..<shown).map { index in
            LargeTile.product(name: snapshot.names[index], outcome: snapshot.outcome(at: index))
        }
        if !fitsAll {
            tiles.append(.more(snapshot.count - shown))
        }
        while tiles.count < slots {
            tiles.append(.empty)
        }
        return tiles
    }

    private func largeFilled(_ snapshot: ShelfWidgetSnapshot) -> some View {
        let tiles = largeTiles(snapshot)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    label
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(snapshot.count)")
                            .font(.system(size: 34, weight: .regular, design: .serif))
                            .foregroundStyle(WidgetColor.ink)
                        Text(snapshot.count == 1 ? "product" : "products")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(WidgetColor.muted)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                mascot(size: 56)
            }
            VStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<2, id: \.self) { column in
                            largeTile(tiles[row * 2 + column])
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func largeTile(_ tile: LargeTile) -> some View {
        switch tile {
        case .product(let name, let outcome):
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(WidgetColor.background)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let outcome {
                    outcomeTag(outcome)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WidgetColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .more(let extra):
            Text("+\(extra) more")
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(WidgetColor.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WidgetColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .empty:
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func outcomeTag(_ outcome: ShelfWidgetOutcome) -> some View {
        Text(outcome.title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(outcome.tone)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(outcome.tone.opacity(0.14), in: Capsule())
    }

    private func largeMessage(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                label
                Spacer(minLength: 4)
                mascot(size: 120)
            }
            Spacer(minLength: 8)
            Text(text)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(WidgetColor.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
    }

    private var largeAccessibilityText: String {
        guard case .shelf(let snapshot) = entry.content, snapshot.count > 0 else {
            return accessibilityText
        }
        let noun = snapshot.count == 1 ? "product" : "products"
        let items: [String] = largeTiles(snapshot).compactMap { tile -> String? in
            switch tile {
            case .product(let name, let outcome):
                return outcome.map { "\(name), \($0.title.lowercased())" } ?? name
            case .more(let extra):
                return "and \(extra) more"
            case .empty:
                return nil
            }
        }
        return items.isEmpty
            ? "Shelf: \(snapshot.count) \(noun)."
            : "Shelf: \(snapshot.count) \(noun): \(items.joined(separator: "; "))."
    }
}

private extension ShelfWidgetOutcome {
    /// Same wording as the app's outcome labels (`Outcome.label` in SKColor.swift).
    var title: String {
        switch self {
        case .good: "Worked"
        case .unsure: "Unsure"
        case .bad: "Broke out"
        }
    }

    var tone: Color {
        switch self {
        case .good: WidgetColor.good
        case .unsure: WidgetColor.caution
        case .bad: WidgetColor.bad
        }
    }
}
