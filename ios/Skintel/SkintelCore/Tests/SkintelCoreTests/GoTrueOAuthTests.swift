import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SkintelCore

// OAuth PKCE web flow (Continue with Google): the authorize URL and the code exchange.

private let supabase = SupabaseConfig(url: URL(string: "https://proj.supabase.co")!, anonKey: "anon-key")

@Test func authorizeURLCarriesProviderRedirectAndChallenge() throws {
    let client = GoTrueClient(config: supabase)
    let url = client.authorizeURL(provider: "google",
                                  redirectTo: URL(string: "skintel://auth-callback")!,
                                  codeChallenge: "abc-_123")
    let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(comps.scheme == "https")
    #expect(comps.host == "proj.supabase.co")
    #expect(comps.path == "/auth/v1/authorize")
    let items = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    #expect(items == [
        "provider": "google",
        "redirect_to": "skintel://auth-callback",
        "code_challenge": "abc-_123",
        "code_challenge_method": "s256",
    ])
}

@Test func pkceRequestPostsAuthCodeAndVerifierToTheTokenEndpoint() throws {
    let req = try GoTrueClient(config: supabase).pkceRequest(authCode: "code-1", codeVerifier: "verifier-2")
    #expect(req.httpMethod == "POST")
    let comps = try #require(req.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
    #expect(comps.path == "/auth/v1/token")
    #expect(comps.queryItems == [URLQueryItem(name: "grant_type", value: "pkce")])
    #expect(req.value(forHTTPHeaderField: "apikey") == "anon-key")
    #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let body = try #require(req.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
    #expect(json == ["auth_code": "code-1", "code_verifier": "verifier-2"])
}

/// Answers every request with a fixed status and body, and records the URL it saw.
final class GoTrueStubProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var lastURL: URL?
    private static let lock = NSLock()

    static func reset(status: Int, body: String) {
        lock.lock(); defer { lock.unlock() }
        self.status = status
        self.body = Data(body.utf8)
        lastURL = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lock.lock()
        Self.lastURL = request.url
        let status = Self.status, body = Self.body
        Self.lock.unlock()
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite(.serialized) struct GoTrueExchangeTests {
    private func client() -> GoTrueClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GoTrueStubProtocol.self]
        return GoTrueClient(config: supabase, http: HTTPClient(session: URLSession(configuration: config), timeout: 5))
    }

    @Test func exchangeCodeDecodesTheSameSessionAsOtherGrants() async throws {
        GoTrueStubProtocol.reset(status: 200, body: #"{"access_token":"at","token_type":"bearer","expires_at":2000000000,"refresh_token":"rt","user":{"id":"u1","email":"g@example.com","user_metadata":{}}}"#)
        let s = try await client().exchangeCode(authCode: "c", codeVerifier: "v")
        #expect(s.accessToken == "at")
        #expect(s.refreshToken == "rt")
        #expect(s.user.email == "g@example.com")
        #expect(s.expiresAt == Date(timeIntervalSince1970: 2_000_000_000))
        #expect(GoTrueStubProtocol.lastURL?.path == "/auth/v1/token")
        #expect(GoTrueStubProtocol.lastURL?.query == "grant_type=pkce")
    }

    @Test func exchangeCodeMapsAnExpiredCodeToAnAPIError() async {
        GoTrueStubProtocol.reset(status: 400, body: #"{"error":"invalid_grant","error_description":"invalid flow state, no valid flow state found"}"#)
        await #expect(throws: APIError.self) { try await client().exchangeCode(authCode: "c", codeVerifier: "v") }
    }
}

@Test func oauthCallbackYieldsTheCodeOrTheProviderError() {
    #expect(GoTrueClient.parseOAuthCallback(URL(string: "skintel://auth-callback?code=abc123")!) == .code("abc123"))
    #expect(GoTrueClient.parseOAuthCallback(
        URL(string: "skintel://auth-callback?error=access_denied&error_description=User%20cancelled")!)
        == .failure("User cancelled"))
    #expect(GoTrueClient.parseOAuthCallback(
        URL(string: "skintel://auth-callback#error=server_error&error_description=Unable+to+exchange")!)
        == .failure("Unable to exchange"))
    #expect(GoTrueClient.parseOAuthCallback(URL(string: "skintel://auth-callback?error=access_denied")!)
        == .failure("access_denied"))
    #expect(GoTrueClient.parseOAuthCallback(URL(string: "skintel://auth-callback?code=")!)
        == .failure("No authorization code returned"))
}
