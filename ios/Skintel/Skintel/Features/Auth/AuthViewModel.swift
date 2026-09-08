import AuthenticationServices
import Foundation
import Observation
import SkintelCore

@MainActor
@Observable
final class AuthViewModel {
    enum Mode: Hashable { case signIn, signUp, reset }

    var mode: Mode
    var email = ""
    var password = ""
    var isLoading = false
    var error: String?
    /// Non-error feedback ("Check your inbox…").
    var notice: String?

    private let session: SessionManager
    private let analytics: any Analytics
    /// Raw nonce for the in-flight Apple request; its SHA-256 went to Apple.
    private var appleNonce: String?

    init(session: SessionManager, analytics: any Analytics, mode: Mode = .signIn) {
        self.session = session
        self.analytics = analytics
        self.mode = mode
    }

    var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard e.contains("@"), e.contains(".") else { return false }
        if mode == .reset { return true }
        return password.count >= 8   // web's minimum
    }

    var submitTitle: String {
        switch mode {
        case .signIn: "Continue"
        case .signUp: "Create account"
        case .reset: "Send reset link"
        }
    }

    func submit() async {
        guard canSubmit, !isLoading else { return }
        isLoading = true; error = nil; notice = nil
        defer { isLoading = false }
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            switch mode {
            case .signIn:
                try await session.signIn(email: e, password: password)
                analytics.track(.signIn(method: "password"))
                Haptics.success()
            case .signUp:
                switch try await session.signUp(email: e, password: password) {
                case .session:
                    analytics.track(.signIn(method: "password_signup"))
                    Haptics.success()
                case .needsConfirmation(let email):
                    notice = "Check \(email) for a confirmation link, then sign in here."
                    mode = .signIn
                    password = ""
                }
            case .reset:
                try await session.requestPasswordReset(email: e)
                notice = "If that address has an account, a reset link is on its way. Set the new password from the email, then sign in here."
                mode = .signIn
            }
        } catch let err as APIError {
            error = friendly(err)
            Haptics.error()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: Apple

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleNonce.random()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256(nonce)
    }

    func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let e):
            if (e as? ASAuthorizationError)?.code == .canceled { return }
            error = "Apple sign-in didn't complete. Try again or use your email."
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce else {
                error = "Apple didn't return a usable credential."
                return
            }
            let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            isLoading = true; error = nil
            defer { isLoading = false }
            do {
                try await session.signInWithApple(idToken: idToken, nonce: nonce, fullName: name.isEmpty ? nil : name)
                analytics.track(.signIn(method: "apple"))
                Haptics.success()
            } catch let err as APIError {
                error = friendly(err)
                Haptics.error()
            } catch {
                self.error = error.localizedDescription
            }
        }
        appleNonce = nil
    }

    private func friendly(_ e: APIError) -> String {
        switch e {
        case .badRequest(let m):
            let msg = (m ?? "").lowercased()
            if msg.contains("invalid login") { return "That email and password don't match." }
            if msg.contains("already registered") || msg.contains("already exists") { return "That email already has an account — sign in instead." }
            if msg.contains("password") { return m ?? "Password needs at least 8 characters." }
            if msg.contains("email not confirmed") { return "Confirm your email from the link we sent, then sign in." }
            return m ?? e.userMessage
        case .unprocessable(let m): return m ?? "That email address doesn't look right."
        case .rateLimited: return "Too many attempts. Wait a minute and try again."
        default: return e.userMessage
        }
    }
}
