import Foundation
import Testing
import UIKit
@testable import Skintel

// The one-time tips registry (DesignSystem/Components/SKHints.swift).

@Test func hintKeysAreUniqueAndNamespaced() {
    let keys = HintID.allCases.map(\.key)
    #expect(Set(keys).count == keys.count)
    #expect(keys.allSatisfy { $0.hasPrefix("hint.") && $0.hasSuffix(".seen") })
}

/// A misspelt asset name compiles and renders nothing, so check every card's drop exists.
@MainActor
@Test func everyHintDropIsInTheAssetCatalog() {
    let missing = HintID.allCases.filter { UIImage(named: $0.drop) == nil }.map(\.drop)
    #expect(missing.isEmpty)
}

@Test func skipAllAndResetAllFlipEveryFlag() {
    HintID.skipAll()
    #expect(HintID.allCases.allSatisfy { UserDefaults.standard.bool(forKey: $0.key) })
    #expect(!HintID.noneSeen)
    HintID.resetAll()
    #expect(HintID.allCases.allSatisfy { !UserDefaults.standard.bool(forKey: $0.key) })
    #expect(HintID.noneSeen)
}

/// Where part of a screen is Skintel+, a free account's tip says so; a member's doesn't.
@Test func hintCopyNamesSkintelPlusOnlyForFreeAccounts() {
    #expect(HintID.allCases.allSatisfy { !$0.message(isPro: true).contains("Skintel+") })
    #expect(HintID.shelf.message(isPro: false).contains("Skintel+"))
    #expect(HintID.routine.message(isPro: false).contains("Skintel+"))
    #expect(!HintID.today.message(isPro: false).contains("scan"))
}
