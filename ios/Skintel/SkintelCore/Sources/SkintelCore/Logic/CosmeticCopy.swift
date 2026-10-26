import Foundation

/// Client-side guard for Face Scan wording (PRO-SPEC §6). The product is a cosmetic read of a
/// photo; it never names a condition, promises treatment, or shows an invented-precision number.
/// The server rejects the same words, so this is a second check on what the screen is about to
/// show, not the first. The word list mirrors the server's pattern.
///
/// Matching is on whole words, case-insensitive, against an explicit list of forms (`treat`,
/// `treats`, `treated`, `treating`, `lesions`, `diagnostic`, and so on). A longer word that only
/// contains one never matches, so `treatment`, `secure`, `curated` and `accurate` all pass.
///
/// No regular expressions and no stored non-`Sendable` state: the text is split into words and the
/// words are looked up in a set, so behaviour is identical on Apple platforms and Linux.
public enum CosmeticCopy {

    // MARK: Banned words

    /// Every banned single-word form.
    private static let bannedWords: Set<String> = [
        // Conditions.
        "rosacea", "eczema", "dermatitis", "psoriasis", "melanoma", "melanomas", "malassezia",
        // Treatment and cure claims. "treatment" is not here and stays allowed.
        "treat", "treats", "treated", "treating",
        "cure", "cures", "cured", "curing",
        // Diagnosis and clinical framing.
        "diagnose", "diagnoses", "diagnosed", "diagnosing", "diagnosis", "diagnostic", "diagnostics",
        "clinical", "clinically",
        "prescription", "prescriptions",
        // Clinical names for blemishes and marks.
        "papule", "papules", "micropapule", "micropapules", "pustule", "pustules",
        "comedone", "comedones", "microcomedone", "microcomedones", "lesion", "lesions",
        "pie", "pih", "postinflammatory", "atrophic",
        // Illness.
        "infection", "infections", "infected", "disease", "diseases",
    ]

    /// Multi-word terms, matched when the words are joined only by spaces or hyphens.
    private static let phrases = [["acne", "vulgaris"], ["fungal", "acne"], ["post", "inflammatory"]]

    /// The one sanctioned use of a banned word: the standard disclaimer says "not a diagnosis"
    /// (`FaceScanResult.defaultDisclaimer`). Skipped as a unit, so a bare "diagnosis" still flags.
    private static let allowedPhrases = [["not", "a", "diagnosis"]]

    // MARK: API

    /// True when `text` contains a diagnosis or treatment word.
    public static func containsDiagnosisWords(_ text: String) -> Bool {
        !diagnosisWords(in: text).isEmpty
    }

    /// True when `text` states a score as a number: a figure followed by `%`, `percent`, `/100`
    /// (spaces allowed around the slash) or `out of 100`, such as "85%", "72.5 percent",
    /// "35 / 100" or "35 out of 100". Scores travel as 0-100 on the wire but the screen shows
    /// bands and trends, never the number (PRO-SPEC §6). Plain counts ("3 nights a week",
    /// "2 of 3 scans", "Day 4") are fine.
    public static func containsScoreNumbers(_ text: String) -> Bool {
        let chars = Array(text.lowercased())
        func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }
        func hasPrefix(_ prefix: String, at start: Int) -> Bool {
            let p = Array(prefix)
            return start + p.count <= chars.count && Array(chars[start..<(start + p.count)]) == p
        }
        var i = 0
        while i < chars.count {
            // Only at the start of a run of digits, so a run is read once, whole.
            guard isDigit(chars[i]), i == 0 || !isDigit(chars[i - 1]) else { i += 1; continue }
            var end = i
            while end < chars.count, isDigit(chars[end]) { end += 1 }
            if end + 1 < chars.count, chars[end] == ".", isDigit(chars[end + 1]) {
                end += 1
                while end < chars.count, isDigit(chars[end]) { end += 1 }
            }
            var next = end
            while next < chars.count, chars[next].isWhitespace { next += 1 }
            if hasPrefix("%", at: next) || hasPrefix("percent", at: next) || hasPrefix("out of 100", at: next) {
                return true
            }
            if hasPrefix("/", at: next) {
                var afterSlash = next + 1
                while afterSlash < chars.count, chars[afterSlash].isWhitespace { afterSlash += 1 }
                if hasPrefix("100", at: afterSlash) { return true }
            }
            i = end
        }
        return false
    }

    /// The banned words found in `text`, lowercased, in order of first appearance, without repeats.
    /// Phrases are reported joined by a space ("fungal acne"). The words of "not a diagnosis" are
    /// not reported, so the standard disclaimer passes.
    public static func diagnosisWords(in text: String) -> [String] {
        let words = tokens(text)
        var found: [String] = []
        var index = 0
        while index < words.count {
            if let allowed = allowedPhrases.first(where: { matches($0, in: words, at: index) }) {
                index += allowed.count
                continue
            }
            var hit: String?
            var length = 1
            if let phrase = phrases.first(where: { matches($0, in: words, at: index) }) {
                hit = phrase.joined(separator: " ")
                length = phrase.count
            } else if bannedWords.contains(words[index].word) {
                hit = words[index].word
            }
            if let hit, !found.contains(hit) { found.append(hit) }
            index += length
        }
        return found
    }

    /// Turns an em dash into a comma: " — " and "—" both become ", ". Spaces around the dash are
    /// absorbed, runs of dashes collapse to one comma, and a dash at the very start or end of the
    /// text is dropped. Everything else, banned words included, is returned untouched.
    public static func clean(_ text: String) -> String {
        let dash: Character = "\u{2014}"
        guard text.contains(dash) else { return text }
        var out = ""
        var pendingDash = false
        for ch in text {
            if ch == dash {
                while let last = out.last, last.isWhitespace { out.removeLast() }
                pendingDash = true
            } else if pendingDash && ch.isWhitespace {
                continue
            } else {
                if pendingDash {
                    if !out.isEmpty && out.last != "," { out += "," }
                    if !out.isEmpty { out += " " }
                    pendingDash = false
                }
                out.append(ch)
            }
        }
        return out
    }

    // MARK: Tokens

    private struct Token {
        let word: String
        /// Only spaces, line breaks or hyphens separate this word from the one before it, so
        /// "fungal acne" and "fungal-acne" are one phrase but "fungal. Acne" is not.
        let joinsPrevious: Bool
    }

    /// Lowercased runs of letters and digits. Any other character ends a word.
    private static func tokens(_ text: String) -> [Token] {
        var result: [Token] = []
        var word = ""
        var wordJoinsPrevious = true
        var gapIsSoft = true
        for ch in text.lowercased() {
            if ch.isLetter || ch.isNumber {
                if word.isEmpty {
                    wordJoinsPrevious = gapIsSoft
                    gapIsSoft = true
                }
                word.append(ch)
            } else {
                if !word.isEmpty {
                    result.append(Token(word: word, joinsPrevious: wordJoinsPrevious))
                    word = ""
                }
                if !(ch.isWhitespace || ch == "-") { gapIsSoft = false }
            }
        }
        if !word.isEmpty { result.append(Token(word: word, joinsPrevious: wordJoinsPrevious)) }
        return result
    }

    /// Whether `phrase` starts at `index`, its words joined only by spaces or hyphens.
    private static func matches(_ phrase: [String], in tokens: [Token], at index: Int) -> Bool {
        guard index + phrase.count <= tokens.count else { return false }
        for (offset, expected) in phrase.enumerated() {
            let token = tokens[index + offset]
            if token.word != expected || (offset > 0 && !token.joinsPrevious) { return false }
        }
        return true
    }
}
