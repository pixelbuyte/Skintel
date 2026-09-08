import Foundation
import os

/// Product events. There is deliberately no third-party SDK: the web uses Vercel
/// Analytics (web-only) and nothing else exists in the product. Events are named here so
/// a provider can be added behind this protocol later without touching features.
/// Payloads never include ingredient lists, journal text, or anything from a scan.
protocol Analytics: Sendable {
    func track(_ event: AnalyticsEvent)
}

enum AnalyticsEvent: Sendable {
    case onboardingCompleted
    case signIn(method: String)
    case scanStarted(mode: String)
    case scanCompleted(verdict: String)
    case productSaved
    case journalSaved
    case culpritViewed
    case routineAnalyzed
    case compareRun
    case paywallViewed(reason: String)
    case purchaseStarted(productID: String)
    case purchaseCompleted(productID: String)
    case restoreCompleted

    var name: String {
        switch self {
        case .onboardingCompleted: "onboarding_completed"
        case .signIn: "sign_in"
        case .scanStarted: "scan_started"
        case .scanCompleted: "scan_completed"
        case .productSaved: "product_saved"
        case .journalSaved: "journal_saved"
        case .culpritViewed: "culprit_viewed"
        case .routineAnalyzed: "routine_analyzed"
        case .compareRun: "compare_run"
        case .paywallViewed: "paywall_viewed"
        case .purchaseStarted: "purchase_started"
        case .purchaseCompleted: "purchase_completed"
        case .restoreCompleted: "restore_completed"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .signIn(let m): ["method": m]
        case .scanStarted(let m): ["mode": m]
        case .scanCompleted(let v): ["verdict": v]
        case .paywallViewed(let r): ["reason": r]
        case .purchaseStarted(let p), .purchaseCompleted(let p): ["product_id": p]
        default: [:]
        }
    }
}

struct LogAnalytics: Analytics {
    private let log = Logger(subsystem: "com.skintel.app", category: "analytics")
    func track(_ event: AnalyticsEvent) {
        log.info("\(event.name, privacy: .public) \(event.parameters.description, privacy: .public)")
    }
}
