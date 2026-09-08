import Foundation
import Observation
import SkintelCore

@MainActor
@Observable
final class OnboardingViewModel {
    var skinType: SkinType?
    var concerns: Set<SkinConcern> = []
    var isSaving = false
    var error: String?

    private let session: SessionManager
    private let analytics: any Analytics

    init(session: SessionManager, analytics: any Analytics) {
        self.session = session
        self.analytics = analytics
        let existing = session.user?.skinProfile ?? SkinProfile()
        skinType = existing.skinType
        concerns = Set(existing.concerns)
    }

    var profile: SkinProfile {
        SkinProfile(skinType: skinType, concerns: SkinConcern.allCases.filter { concerns.contains($0) })
    }

    var canContinue: Bool { skinType != nil }

    func toggle(_ c: SkinConcern) {
        if concerns.contains(c) { concerns.remove(c) } else { concerns.insert(c) }
        Haptics.selection()
    }

    /// Writes the profile + `onboarding_complete` to auth user_metadata. Returns false if
    /// the save failed (the view offers retry or a local skip).
    func complete() async -> Bool {
        isSaving = true; error = nil
        defer { isSaving = false }
        do {
            try await session.updateMetadata(
                AuthUser.metadataPatch(profile: profile, displayName: nil, onboardingComplete: true)
            )
            analytics.track(.onboardingCompleted)
            Haptics.success()
            return true
        } catch let e as APIError {
            error = e.userMessage
        } catch {
            self.error = error.localizedDescription
        }
        Haptics.error()
        return false
    }
}
