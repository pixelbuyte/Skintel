import Foundation
import Testing
@testable import SkintelCore

/// `HomeFocus` owns the copy Home prints under the routine. These pin both the priority
/// order and the exact sentences, because the counts have to survive a rewrite.
@Suite("HomeFocus")
struct HomeFocusTests {

    // MARK: - Priority order

    @Test("An empty shelf asks for the first product before anything else")
    func emptyShelfWins() {
        let n = HomeFocus.nudge(productCount: 0, unsureProductIDs: ["a", "b"], decidedCount: 0, routineTotal: 0)
        #expect(n.kind == .firstProduct)
        #expect(n.headline == "Start with one product")
        #expect(n.detail == "Add what you used this morning and tell Skintel how your skin took it.")
        #expect(n.productID == nil)
    }

    @Test("A single product asks for a second, even with a routine already built")
    func oneProductWins() {
        let n = HomeFocus.nudge(productCount: 1, unsureProductIDs: ["a"], decidedCount: 0, routineTotal: 4)
        #expect(n.kind == .secondProduct)
        #expect(n.headline == "One product on your shelf")
        #expect(n.detail == "Add a second and Skintel can start finding what they share.")
    }

    @Test("Unsure products outrank a missing routine")
    func unsureBeatsRoutine() {
        let n = HomeFocus.nudge(productCount: 5, unsureProductIDs: ["p1"], decidedCount: 4, routineTotal: 0)
        #expect(n.kind == .markOutcomes)
    }

    @Test("A missing routine surfaces once the shelf is decided")
    func routineWhenShelfClean() {
        let n = HomeFocus.nudge(productCount: 5, unsureProductIDs: [], decidedCount: 5, routineTotal: 0)
        #expect(n.kind == .buildRoutine)
        #expect(n.headline == "No routine yet")
        #expect(n.detail == "Build one from your shelf and Skintel can track what you actually use.")
    }

    @Test("Nothing outstanding falls through to the quiet state")
    func allSet() {
        let n = HomeFocus.nudge(productCount: 6, unsureProductIDs: [], decidedCount: 6, routineTotal: 3)
        #expect(n.kind == .allSet)
        #expect(n.headline == "Nothing needs you")
        #expect(n.detail == "Your shelf is up to date. Skintel keeps watching as you log.")
        #expect(n.productID == nil)
    }

    // MARK: - Unsure copy

    @Test("One unsure product is singular")
    func unsureSingular() {
        let n = HomeFocus.nudge(productCount: 4, unsureProductIDs: ["p1"], decidedCount: 3, routineTotal: 2)
        #expect(n.headline == "1 product still unsure")
        #expect(n.productID == "p1")
    }

    @Test("Several unsure products are plural and carry the first one through")
    func unsurePlural() {
        let n = HomeFocus.nudge(productCount: 6, unsureProductIDs: ["p1", "p2", "p3"], decidedCount: 3, routineTotal: 2)
        #expect(n.headline == "3 products still unsure")
        #expect(n.productID == "p1")
    }

    @Test("Below the pattern floor the detail explains what it unlocks")
    func unsureBelowFloor() {
        let n = HomeFocus.nudge(productCount: 3, unsureProductIDs: ["p1", "p2"], decidedCount: 1, routineTotal: 0)
        #expect(n.detail == "Say how each one went and Skintel can start finding what they share.")
    }

    @Test("At or above the pattern floor the detail states the cost instead")
    func unsureAboveFloor() {
        let n = HomeFocus.nudge(productCount: 5, unsureProductIDs: ["p1"], decidedCount: HomeFocus.patternFloor, routineTotal: 0)
        #expect(n.detail == "Skintel leaves these out until you say how they went.")
    }

    // MARK: - Voice

    @Test("No nudge uses a word the owner struck out")
    func bannedWords() {
        let all = [
            HomeFocus.nudge(productCount: 0, unsureProductIDs: [], decidedCount: 0, routineTotal: 0),
            HomeFocus.nudge(productCount: 1, unsureProductIDs: [], decidedCount: 0, routineTotal: 0),
            HomeFocus.nudge(productCount: 4, unsureProductIDs: ["p1"], decidedCount: 2, routineTotal: 0),
            HomeFocus.nudge(productCount: 4, unsureProductIDs: [], decidedCount: 4, routineTotal: 0),
            HomeFocus.nudge(productCount: 4, unsureProductIDs: [], decidedCount: 4, routineTotal: 2),
        ]
        for n in all {
            let text = (n.headline + " " + n.detail).lowercased()
            for word in ["ai", "verdict", "culprit", "suspect", "analysis"] {
                #expect(!text.contains(word), "\(n.kind.rawValue) leaked “\(word)”")
            }
        }
    }

    @Test("Every nudge is a finished sentence pair")
    func finishedSentences() {
        let all = [
            HomeFocus.nudge(productCount: 0, unsureProductIDs: [], decidedCount: 0, routineTotal: 0),
            HomeFocus.nudge(productCount: 1, unsureProductIDs: [], decidedCount: 0, routineTotal: 0),
            HomeFocus.nudge(productCount: 9, unsureProductIDs: ["p1"], decidedCount: 8, routineTotal: 3),
            HomeFocus.nudge(productCount: 9, unsureProductIDs: [], decidedCount: 9, routineTotal: 0),
            HomeFocus.nudge(productCount: 9, unsureProductIDs: [], decidedCount: 9, routineTotal: 3),
        ]
        for n in all {
            #expect(!n.headline.isEmpty)
            #expect(n.detail.hasSuffix("."))
            #expect(!n.headline.hasSuffix("."))
        }
    }
}
