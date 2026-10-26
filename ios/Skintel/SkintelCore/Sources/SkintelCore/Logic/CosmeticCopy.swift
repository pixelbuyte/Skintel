import Foundation

/// Client-side guard for Face Scan wording (PRO-SPEC §6). The product is a cosmetic read of a
/// photo; it never names a condition or promises treatment. The server rejects banned words, so
/// this is a second check on what the screen is about to show, not the first.
///
/// Matching is on whole words, case-insensitive. A term also matches its plural or past form
/// (`lesions`, `diagnosed`, `cured`), but never a longer word that merely contains it, so
/// `secure`, `curated`, `treatment` and `treatments` all pass. `treat` is matched as a whole word
/// only, which keeps `treatment` allowed.
///
/// No regular expressions and no stored non-`Sendable` state: the text is split into words and the
/// words are looked up in a set, so behaviour is identical on Apple platforms and Linux.
public enum CosmeticCopy {

    // MARK: Banned words

    /// One-word terms. Plural and `-d` forms are derived in `bannedWords`.
    private static let singleWordTerms = [
        "rosacea", "eczema", "dermatitis", "psoriasis", "melanoma", "malassezia", "infection",
        "disease", "diagnose", "diagnosis", "prescription", "papule", "pustule", "comedone",
        "lesion", "cure",
    ]

    /// Two-word terms, matched when the words are adjacent (any whitespace or hyphen between).
    private static let phrases = [["acne", "vulgaris"], ["fungal", "acne"]]

    /// The one sanctioned use of a banned word: the standard disclaimer says "not a diagnosis"
    /// (`FaceScanResult.defaultDisclaimer`). Skipped as a unit, so a bare "diagnosis" still flags.
    private static let allowedPhrases = [["not", "a", "diagnosis"]]

    /// Every accepted single-word form: each term, its plural, its `-d` form when it ends in `e`
    /// (`diagnosed`, `cured`), and `treat` on its own.
    private static let bannedWords: Set<String> = {
        var words: Set<String> = ["treat"]
        for term in singleWordTerms {
            words.insert(term)
            words.insert(term + "s")
            if term.hasSuffix("e") { words.insert(term + "d") }
        }
        return words
    }()

    // MARK: API

    /// True when `text` contains a diagnosis or treatment word.
    public static func containsDiagnosisWords(_ text: String) -> Bool {
        !diagnosisWords(in: text).isEmpty
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
