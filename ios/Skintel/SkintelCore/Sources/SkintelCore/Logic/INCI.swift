import Foundation

/// Exact port of src/lib/inci.ts. `inci_normalized` rows written by the web app were
/// produced by this normaliser, so the iOS app must produce byte-identical keys or
/// culprit correlation across web- and iOS-created products silently breaks.
public enum INCI {
    public struct ParsedIngredient: Sendable, Hashable {
        public var raw: String
        public var normalized: String
        public var position: Int

        public init(raw: String, normalized: String, position: Int) {
            self.raw = raw; self.normalized = normalized; self.position = position
        }
    }

    /// lowercase → strip "( … )" groups (replaced by a space) → strip * † ‡ → collapse whitespace → trim
    public static func normalize(_ name: String) -> String {
        var s = name.lowercased()
        s = s.replacing(/\s*\([^)]*\)\s*/, with: " ")
        s = s.replacing(/[*†‡]/, with: "")
        s = s.replacing(/\s+/, with: " ")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Split on , ; and newlines, strip leading list markers/digits, dedupe on the normalised key.
    public static func parse(_ raw: String) -> [ParsedIngredient] {
        guard !raw.isEmpty else { return [] }
        var seen = Set<String>()
        var out: [ParsedIngredient] = []
        let parts = raw.split(separator: /[,;\n\r]+/)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for original in parts {
            let cleaned = original.replacing(/^[.\-•·\d]+\s*/, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.isEmpty { continue }
            let normalized = normalize(cleaned)
            if normalized.isEmpty || seen.contains(normalized) { continue }
            seen.insert(normalized)
            out.append(ParsedIngredient(raw: cleaned, normalized: normalized, position: out.count))
        }
        return out
    }
}
