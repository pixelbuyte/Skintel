import Foundation

// Compiled into BOTH the Skintel app and the SkintelWidgets extension (see project.yml), so
// the two sides agree on the App Group, widget kinds, deep links and the snapshot format.
// Foundation only: the extension does not link SkintelCore.

enum WidgetShared {
    /// Must match `com.apple.security.application-groups` in both targets' entitlements.
    static let appGroup = "group.com.skintel.app"

    enum Kind {
        static let ask = "com.skintel.widget.ask"
        static let shelf = "com.skintel.widget.shelf"
    }
}

/// `skintel://<host>` links opened by the widgets. The scheme is registered in project.yml
/// (`CFBundleURLTypes`); the app routes them in `MainTabView.handle(_:)`.
enum SkintelDeepLink: String, CaseIterable, Sendable {
    case scan, ask, shelf, checkin

    static let scheme = "skintel"

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = rawValue
        // Scheme + a plain lowercase host always form a valid URL.
        return components.url!
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host()?.lowercased(),
              let link = SkintelDeepLink(rawValue: host)
        else { return nil }
        self = link
    }
}

/// What the Shelf widget shows. Deliberately tiny: a count and the first few product
/// names. No ingredients, outcomes, notes or account data ever leave the app.
struct ShelfWidgetSnapshot: Codable, Sendable, Equatable {
    var count: Int
    var names: [String]

    static let maxNames = 3

    init(count: Int, names: [String]) {
        self.count = max(0, count)
        self.names = Array(names.prefix(Self.maxNames))
    }
}

/// Reads and writes the snapshot in the App Group's shared `UserDefaults`.
/// `defaults` is injectable for tests; `nil` (no App Group) makes every call a no-op.
enum ShelfSnapshotStore {
    static let key = "widget.shelf.snapshot.v1"

    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: WidgetShared.appGroup)
    }

    static func read(from defaults: UserDefaults?) -> ShelfWidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ShelfWidgetSnapshot.self, from: data)
    }

    /// Returns `true` only when the stored value actually changed, so callers reload the
    /// widget timeline only when there is something new to draw.
    @discardableResult
    static func write(_ snapshot: ShelfWidgetSnapshot, to defaults: UserDefaults?) -> Bool {
        guard let defaults, read(from: defaults) != snapshot,
              let data = try? JSONEncoder().encode(snapshot)
        else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    /// Returns `true` when there was a snapshot to remove.
    @discardableResult
    static func clear(in defaults: UserDefaults?) -> Bool {
        guard let defaults, defaults.object(forKey: key) != nil else { return false }
        defaults.removeObject(forKey: key)
        return true
    }
}
