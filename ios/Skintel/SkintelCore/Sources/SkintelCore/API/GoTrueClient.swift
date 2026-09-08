import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Supabase Auth over REST. Same endpoints supabase-js uses, so accounts are shared with
/// the web app. No token is ever logged.
public struct GoTrueClient: Sendable {
    public let config: SupabaseConfig
    public let http: HTTPClient

    public init(config: SupabaseConfig, http: HTTPClient = HTTPClient()) {
        self.config = config
        self.http = http
    }

    public enum SignUpResult: Sendable, Equatable {
        case session(Session)
        /// Email confirmation is on: the user must click the link the web app sends, then sign in.
        case needsConfirmation(email: String)
    }

    // MARK: Password

    public func signIn(email: String, password: String) async throws -> Session {
        struct Body: Encodable { let email: String; let password: String }
        return try await token(query: ["grant_type": "password"], body: Body(email: email, password: password))
    }

    public func signUp(email: String, password: String) async throws -> SignUpResult {
        struct Body: Encodable { let email: String; let password: String }
        let req = try RequestBuilder.json(
            RequestBuilder.url(config.authBase, path: "signup"),
            method: "POST", body: Body(email: email, password: password), headers: baseHeaders
        )
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
        if let tok = try? JSONCoding.decoder.decode(TokenResponse.self, from: r.data), tok.access_token != nil {
            return .session(try tok.session())
        }
        return .needsConfirmation(email: email)
    }

    public func requestPasswordReset(email: String) async throws {
        struct Body: Encodable { let email: String }
        let req = try RequestBuilder.json(
            RequestBuilder.url(config.authBase, path: "recover"),
            method: "POST", body: Body(email: email), headers: baseHeaders
        )
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
    }

    // MARK: Apple

    /// `idToken` is the JWT from `ASAuthorizationAppleIDCredential.identityToken`; `nonce` is the
    /// raw nonce whose SHA-256 was put in the request. Supabase verifies both.
    public func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        struct Body: Encodable { let provider = "apple"; let id_token: String; let nonce: String }
        return try await token(query: ["grant_type": "id_token"], body: Body(id_token: idToken, nonce: nonce))
    }

    // MARK: Session lifecycle

    public func refresh(refreshToken: String) async throws -> Session {
        struct Body: Encodable { let refresh_token: String }
        return try await token(query: ["grant_type": "refresh_token"], body: Body(refresh_token: refreshToken))
    }

    public func signOut(accessToken: String) async throws {
        let req = try RequestBuilder.json(
            RequestBuilder.url(config.authBase, path: "logout"),
            method: "POST", body: Optional<String>.none, headers: authHeaders(accessToken)
        )
        let r = try await http.send(req)
        // 401/404 here just means the token was already dead; the local sign-out proceeds regardless.
        guard (200..<300).contains(r.status) || r.status == 401 || r.status == 404 else {
            throw mapError(status: r.status, data: r.data)
        }
    }

    public func user(accessToken: String) async throws -> AuthUser {
        let req = try RequestBuilder.json(
            RequestBuilder.url(config.authBase, path: "user"),
            method: "GET", body: Optional<String>.none, headers: authHeaders(accessToken)
        )
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
        return try JSONCoding.decode(AuthUser.self, from: r.data)
    }

    /// Merges `data` into `user_metadata` (GoTrue merges shallowly — send the full patch).
    public func updateUserMetadata(accessToken: String, data: [String: JSONValue]) async throws -> AuthUser {
        struct Body: Encodable { let data: [String: JSONValue] }
        let req = try RequestBuilder.json(
            RequestBuilder.url(config.authBase, path: "user"),
            method: "PUT", body: Body(data: data), headers: authHeaders(accessToken)
        )
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
        return try JSONCoding.decode(AuthUser.self, from: r.data)
    }

    public func updatePassword(accessToken: String, newPassword: String) async throws {
        struct Body: Encodable { let password: String }
        let req = try RequestBuilder.json(
            RequestBuilder.url(config.authBase, path: "user"),
            method: "PUT", body: Body(password: newPassword), headers: authHeaders(accessToken)
        )
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
    }

    // MARK: Internals

    private var baseHeaders: [String: String] {
        ["apikey": config.anonKey]
    }

    private func authHeaders(_ accessToken: String) -> [String: String] {
        ["apikey": config.anonKey, "Authorization": "Bearer \(accessToken)"]
    }

    private func token(query: [String: String], body: some Encodable) async throws -> Session {
        let req = try RequestBuilder.json(
            RequestBuilder.url(config.authBase, path: "token", query: query),
            method: "POST", body: body, headers: baseHeaders
        )
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
        let tok = try JSONCoding.decode(TokenResponse.self, from: r.data)
        return try tok.session()
    }

    struct TokenResponse: Decodable {
        var access_token: String?
        var token_type: String?
        var expires_in: Double?
        var expires_at: Double?
        var refresh_token: String?
        var user: AuthUser?

        func session(now: Date = Date()) throws -> Session {
            guard let access_token, let refresh_token, let user else {
                throw APIError.decoding("Token response missing session fields")
            }
            let expiry: Date
            if let expires_at { expiry = Date(timeIntervalSince1970: expires_at) }
            else { expiry = now.addingTimeInterval(expires_in ?? 3600) }
            return Session(accessToken: access_token, refreshToken: refresh_token,
                           tokenType: token_type ?? "bearer", expiresAt: expiry, user: user)
        }
    }
}
