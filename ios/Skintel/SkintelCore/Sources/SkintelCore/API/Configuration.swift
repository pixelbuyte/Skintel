import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Public client configuration. The anon key is a *public* key by design (it ships in
/// the web bundle and is protected by Row Level Security); service-role and Stripe/Anthropic
/// keys never leave the server and have no representation in this package.
public struct SupabaseConfig: Sendable, Hashable {
    public var url: URL
    public var anonKey: String

    public init(url: URL, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }

    var authBase: URL { url.appendingPathComponent("auth/v1") }
    var restBase: URL { url.appendingPathComponent("rest/v1") }
}

public struct APIConfig: Sendable, Hashable {
    /// e.g. https://www.skinstel.com/api
    public var baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

/// Shared request plumbing.
enum RequestBuilder {
    static func json(_ url: URL, method: String, body: (some Encodable)?, headers: [String: String]) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONCoding.encoder.encode(body)
        }
        return req
    }

    static func url(_ base: URL, path: String, query: [String: String] = [:]) -> URL {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return comps.url!
    }
}

/// Error envelope shapes seen across GoTrue, PostgREST and /api.
struct ErrorEnvelope: Decodable {
    var error: String?
    var error_description: String?
    var msg: String?
    var message: String?
    var code: String?
    var hint: String?

    var bestMessage: String? {
        error_description ?? message ?? msg ?? error
    }

    static func parse(_ data: Data) -> ErrorEnvelope? {
        try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
    }
}

/// Maps an HTTP status + body into the one error type views understand.
func mapError(status: Int, data: Data) -> APIError {
    let env = ErrorEnvelope.parse(data)
    let msg = env?.bestMessage
    let text = msg ?? String(data: data, encoding: .utf8) ?? ""
    if text.contains("FREE_PLAN_LIMIT") || env?.code == "P0001" && text.contains("FREE_PLAN") {
        return .freePlanLimit
    }
    switch status {
    case 400: return .badRequest(msg)
    case 401: return .unauthenticated
    case 402: return .proRequired
    case 403: return .unauthenticated
    case 404: return .notFound(msg)
    case 409: return .conflict(msg)
    case 422: return .unprocessable(msg)
    case 429: return .rateLimited
    default: return .server(status: status, message: msg)
    }
}
