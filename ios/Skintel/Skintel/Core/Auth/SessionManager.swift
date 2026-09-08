import Foundation
import Observation
import SkintelCore

/// Owns the auth session: restore from Keychain at launch, refresh before expiry,
/// sign in/up/out, and profile (user_metadata) updates. It is the app's `TokenProvider`,
/// so every API client asks it for a token and never sees the refresh dance.
@MainActor
@Observable
final class SessionManager: TokenProvider {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(Session)
    }

    private(set) var state: State = .restoring
    /// Set when a refresh failed for network reasons; cleared on the next success.
    private(set) var lastNetworkProblem: APIError?

    private let auth: GoTrueClient
    private let store: KeychainSessionStore
    private var refreshTask: Task<Session, Error>?

    init(auth: GoTrueClient, store: KeychainSessionStore = KeychainSessionStore()) {
        self.auth = auth
        self.store = store
    }

    var session: Session? {
        if case .signedIn(let s) = state { return s }
        return nil
    }

    var user: AuthUser? { session?.user }
    var isSignedIn: Bool { session != nil }

    // MARK: Launch

    /// Called once from the router. Fast path is a Keychain read; a refresh only happens
    /// if the token is already expiring, and a *network* failure keeps the session so an
    /// offline launch still lands on Home rather than bouncing to sign-in.
    func restore() async {
        guard let saved = store.load() else { state = .signedOut; return }
        state = .signedIn(saved)
        if saved.isExpiring(within: 120) {
            do { _ = try await refresh(saved) }
            catch let e as APIError where e == .unauthenticated { signOutLocally() }
            catch { /* offline: keep the stale session; next call retries */ }
        }
    }

    // MARK: TokenProvider

    func validAccessToken() async throws -> String {
        guard let s = session else { throw APIError.unauthenticated }
        if !s.isExpiring() { return s.accessToken }
        return try await refresh(s).accessToken
    }

    /// Coalesces concurrent refreshes into one request.
    @discardableResult
    func refresh(_ current: Session? = nil) async throws -> Session {
        if let running = refreshTask { return try await running.value }
        guard let s = current ?? session else { throw APIError.unauthenticated }
        let task = Task<Session, Error> { [auth] in
            try await auth.refresh(refreshToken: s.refreshToken)
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let fresh = try await task.value
            commit(fresh)
            lastNetworkProblem = nil
            return fresh
        } catch let e as APIError {
            if e == .unauthenticated || e == .badRequest(nil) { signOutLocally() }
            else if e.isRetryable { lastNetworkProblem = e }
            throw e
        }
    }

    // MARK: Sign in / up / out

    func signIn(email: String, password: String) async throws {
        commit(try await auth.signIn(email: email, password: password))
    }

    func signUp(email: String, password: String) async throws -> GoTrueClient.SignUpResult {
        let r = try await auth.signUp(email: email, password: password)
        if case .session(let s) = r { commit(s) }
        return r
    }

    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws {
        var s = try await auth.signInWithApple(idToken: idToken, nonce: nonce)
        // Apple only sends the name on the very first authorisation; persist it now or lose it.
        if let fullName, !fullName.isEmpty, s.user.displayName == nil {
            if let updated = try? await auth.updateUserMetadata(accessToken: s.accessToken,
                                                                 data: [AuthUser.displayNameKey: .string(fullName)]) {
                s.user = updated
            }
        }
        commit(s)
    }

    func requestPasswordReset(email: String) async throws {
        try await auth.requestPasswordReset(email: email)
    }

    func signOut() async {
        if let s = session { try? await auth.signOut(accessToken: s.accessToken) }
        signOutLocally()
    }

    func signOutLocally() {
        store.clear()
        state = .signedOut
    }

    // MARK: Profile

    func updateMetadata(_ data: [String: JSONValue]) async throws {
        let token = try await validAccessToken()
        let user = try await auth.updateUserMetadata(accessToken: token, data: data)
        if var s = session { s.user = user; commit(s) }
    }

    func reloadUser() async {
        guard let token = try? await validAccessToken(),
              let user = try? await auth.user(accessToken: token),
              var s = session else { return }
        s.user = user
        commit(s)
    }

    private func commit(_ s: Session) {
        state = .signedIn(s)
        try? store.save(s)
    }
}
