import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Thin URLSession wrapper: one place for timeouts, error mapping and debug logging.
/// Production builds never log bodies or headers.
public struct HTTPClient: Sendable {
    public var session: URLSession
    public var timeout: TimeInterval
    public var logger: (@Sendable (String) -> Void)?

    public init(session: URLSession = .shared, timeout: TimeInterval = 20, logger: (@Sendable (String) -> Void)? = nil) {
        self.session = session
        self.timeout = timeout
        self.logger = logger
    }

    public struct Response: Sendable {
        public let status: Int
        public let data: Data
        public let headers: [String: String]
    }

    public func send(_ request: URLRequest) async throws -> Response {
        var req = request
        if req.timeoutInterval == 60 { req.timeoutInterval = timeout }
        logger?("→ \(req.httpMethod ?? "GET") \(req.url?.path ?? "")")
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw APIError.network("Not an HTTP response")
            }
            var headers: [String: String] = [:]
            for (k, v) in http.allHeaderFields {
                if let ks = k as? String, let vs = v as? String { headers[ks.lowercased()] = vs }
            }
            logger?("← \(http.statusCode) \(req.url?.path ?? "") (\(data.count)b)")
            return Response(status: http.statusCode, data: data, headers: headers)
        } catch let e as APIError {
            throw e
        } catch let e as URLError {
            switch e.code {
            case .cancelled: throw APIError.cancelled
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: throw APIError.offline
            case .timedOut: throw APIError.network("The request timed out.")
            default: throw APIError.network(e.localizedDescription)
            }
        } catch is CancellationError {
            throw APIError.cancelled
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }
}

// MARK: - JSON helpers

public enum JSONCoding {
    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decoding("\(T.self): \(error)") }
    }
}

/// Minimal JSON value for `user_metadata` and other open-ended objects.
public enum JSONValue: Codable, Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    public var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    public var doubleValue: Double? { if case .number(let n) = self { return n }; return nil }
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { return a }; return nil }
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
}

/// LLM-shaped responses sometimes return numbers as strings ("87" / "87%"). Decode either.
public struct FlexibleNumber: Codable, Sendable, Hashable {
    public var value: Double
    public init(_ value: Double) { self.value = value }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self) {
            let cleaned = s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            if let d = Double(cleaned) { value = d; return }
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Not a number")
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

/// Accepts `["a","b"]`, `"a"`, or null → `[String]`.
public struct FlexibleStrings: Codable, Sendable, Hashable {
    public var values: [String]
    public init(_ values: [String]) { self.values = values }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { values = []; return }
        if let a = try? c.decode([String].self) { values = a; return }
        if let s = try? c.decode(String.self) { values = s.isEmpty ? [] : [s]; return }
        if let a = try? c.decode([JSONValue].self) {
            values = a.compactMap { v in
                if let s = v.stringValue { return s }
                if let o = v.objectValue { return o.values.compactMap(\.stringValue).first }
                return nil
            }
            return
        }
        values = []
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(values)
    }
}
