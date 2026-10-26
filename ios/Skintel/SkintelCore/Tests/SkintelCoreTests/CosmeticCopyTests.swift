import Foundation
import Testing
@testable import SkintelCore

// Face Scan wording guard (PRO-SPEC §6).

private let bannedTerms = [
    "acne vulgaris", "rosacea", "eczema", "dermatitis", "psoriasis", "melanoma", "malassezia", "fungal acne",
    "infection", "disease", "diagnose", "diagnosis", "prescription", "papule", "pustule", "comedone",
    "lesion", "cure", "treat",
]

@Test(arguments: bannedTerms)
func everyBannedTermIsFlagged(term: String) {
    #expect(CosmeticCopy.containsDiagnosisWords(term))
    #expect(CosmeticCopy.containsDiagnosisWords("This looks like \(term) on your chin."))
    #expect(CosmeticCopy.containsDiagnosisWords(term.uppercased() + "!"))
    #expect(CosmeticCopy.diagnosisWords(in: "About " + term) == [term])
}

@Test func treatmentIsAllowedButTreatIsFlagged() {
    #expect(!CosmeticCopy.containsDiagnosisWords("A gentle treatment for your evening routine."))
    #expect(!CosmeticCopy.containsDiagnosisWords("Treatments and Treatment"))
    #expect(CosmeticCopy.containsDiagnosisWords("This will treat your breakouts."))
    #expect(CosmeticCopy.containsDiagnosisWords("Treat"))
    #expect(CosmeticCopy.containsDiagnosisWords("treat, then moisturise"))
    #expect(CosmeticCopy.containsDiagnosisWords("Don't treat it (yet)."))
    #expect(CosmeticCopy.diagnosisWords(in: "Treatment, not treat") == ["treat"])
}

@Test func matchingIsCaseInsensitiveAndOnWholeWords() {
    #expect(CosmeticCopy.containsDiagnosisWords("ROSACEA"))
    #expect(CosmeticCopy.containsDiagnosisWords("Eczema-prone"))
    #expect(CosmeticCopy.containsDiagnosisWords("Fungal   ACNE"))
    #expect(CosmeticCopy.containsDiagnosisWords("fungal-acne"))
    #expect(CosmeticCopy.containsDiagnosisWords("fungal\nacne"))
    // Plural and past forms of the single-word terms are the same claim.
    #expect(CosmeticCopy.containsDiagnosisWords("two lesions"))
    #expect(CosmeticCopy.containsDiagnosisWords("Papules and pustules"))
    #expect(CosmeticCopy.containsDiagnosisWords("Comedones"))
    #expect(CosmeticCopy.containsDiagnosisWords("diagnosed last year"))
    #expect(CosmeticCopy.containsDiagnosisWords("Can't be cured"))
    #expect(CosmeticCopy.containsDiagnosisWords("prescriptions"))
    // A banned string inside a longer word is not a match.
    for word in ["secure", "obscure", "curated", "accurate", "procure", "treatment", "retreat", "pustulent"] {
        #expect(!CosmeticCopy.containsDiagnosisWords("A \(word) routine"), "\(word) should pass")
    }
    // Each half of a two-word term is fine on its own.
    #expect(!CosmeticCopy.containsDiagnosisWords("Acne-prone skin, fungal-free formula"))
    #expect(!CosmeticCopy.containsDiagnosisWords("Vulgaris"))
    #expect(!CosmeticCopy.containsDiagnosisWords("acne. Vulgaris"))
    #expect(!CosmeticCopy.containsDiagnosisWords("fungal skin, acne"))
    // A two-word term needs its words joined by spaces or a hyphen, not split by punctuation.
    #expect(!CosmeticCopy.containsDiagnosisWords("Nothing fungal. Acne is common."))
    #expect(!CosmeticCopy.containsDiagnosisWords("fungal, acne"))
    #expect(CosmeticCopy.containsDiagnosisWords("Not. A diagnosis."))
}

@Test func cosmeticWordingPasses() {
    #expect(!CosmeticCopy.containsDiagnosisWords(""))
    #expect(!CosmeticCopy.containsDiagnosisWords("Mostly calm. Shine on the T-zone, a few blemishes on the chin."))
    #expect(!CosmeticCopy.containsDiagnosisWords("A few raised blemishes along the jawline."))
    #expect(!CosmeticCopy.containsDiagnosisWords("Redness looks steady. Marks are fading. Barrier looks steady."))
    #expect(!CosmeticCopy.containsDiagnosisWords("Suggested active: azelaic acid, 3 nights a week. Check with your doctor."))
    #expect(!CosmeticCopy.containsDiagnosisWords("Acne"))   // the plain word is the person's own; only the clinical terms are banned
}

@Test func theStandardDisclaimerPassesButADiagnosisClaimDoesNot() {
    // The disclaimer the wire contract mandates says "not a diagnosis"; that exact use is allowed.
    #expect(!CosmeticCopy.containsDiagnosisWords(FaceScanResult.defaultDisclaimer))
    #expect(!CosmeticCopy.containsDiagnosisWords("A cosmetic read of a photo, not a diagnosis."))
    #expect(!CosmeticCopy.containsDiagnosisWords("A COSMETIC READ OF A PHOTO, NOT A DIAGNOSIS"))
    // Anything else with the word, even next to the disclaimer, is still flagged.
    #expect(CosmeticCopy.containsDiagnosisWords("This is a diagnosis."))
    #expect(CosmeticCopy.containsDiagnosisWords("Not a diagnosis, but a diagnosis of rosacea"))
    #expect(CosmeticCopy.diagnosisWords(in: "Not a diagnosis. Rosacea? A diagnosis!") == ["rosacea", "diagnosis"])
    #expect(CosmeticCopy.containsDiagnosisWords("not diagnosis"))
    #expect(CosmeticCopy.containsDiagnosisWords("not a medical diagnosis"))
}

@Test func diagnosisWordsListsEachMatchOnceInOrder() {
    #expect(CosmeticCopy.diagnosisWords(in: "").isEmpty)
    #expect(CosmeticCopy.diagnosisWords(in: "Fine and calm.").isEmpty)
    #expect(CosmeticCopy.diagnosisWords(in: "Eczema, then ECZEMA again, then Fungal Acne, a lesion and an Acne Vulgaris flare")
            == ["eczema", "fungal acne", "lesion", "acne vulgaris"])
    // "fungal acne vulgaris" reads as the first phrase; the leftover word is not a second hit.
    #expect(CosmeticCopy.diagnosisWords(in: "fungal acne vulgaris") == ["fungal acne"])
}

@Test func cleanTurnsEmDashesIntoCommas() {
    #expect(CosmeticCopy.clean("Mostly calm \u{2014} shine on the T-zone") == "Mostly calm, shine on the T-zone")
    #expect(CosmeticCopy.clean("Mostly calm\u{2014}shine on the T-zone") == "Mostly calm, shine on the T-zone")
    #expect(CosmeticCopy.clean("calm \u{2014}shine") == "calm, shine")
    #expect(CosmeticCopy.clean("calm\u{2014} shine") == "calm, shine")
    #expect(CosmeticCopy.clean("one \u{2014} two \u{2014} three") == "one, two, three")
    #expect(CosmeticCopy.clean("a\u{2014}b\u{2014}c") == "a, b, c")
    // Runs collapse, an existing comma is not doubled, a leading or trailing dash is dropped.
    #expect(CosmeticCopy.clean("a \u{2014}\u{2014} b") == "a, b")
    #expect(CosmeticCopy.clean("a, \u{2014} b") == "a, b")
    #expect(CosmeticCopy.clean("\u{2014} Hello") == "Hello")
    #expect(CosmeticCopy.clean("Hello \u{2014}") == "Hello")
    #expect(CosmeticCopy.clean("\u{2014}") == "")
}

@Test func cleanLeavesEverythingElseAlone() {
    #expect(CosmeticCopy.clean("") == "")
    #expect(CosmeticCopy.clean("Plain text, with a hyphen - and an en dash \u{2013} kept.") == "Plain text, with a hyphen - and an en dash \u{2013} kept.")
    #expect(CosmeticCopy.clean("  spaces kept  ") == "  spaces kept  ")
    // It does not rewrite banned words; the server rejects those and the screen should not show them.
    #expect(CosmeticCopy.clean("rosacea \u{2014} maybe") == "rosacea, maybe")
    #expect(CosmeticCopy.containsDiagnosisWords(CosmeticCopy.clean("rosacea \u{2014} maybe")))
    // Cleaned wire copy from the spec example is unchanged.
    #expect(CosmeticCopy.clean("Mostly calm. Shine on the T-zone, a few blemishes on the chin.")
            == "Mostly calm. Shine on the T-zone, a few blemishes on the chin.")
}
