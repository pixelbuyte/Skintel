import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SkintelCore

/// Fails the first request to each URL with `failure`, answers the next one with 200.
final class FlakyProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var failure: URLError.Code = .timedOut
    nonisolated(unsafe) static var calls = 0
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lock.lock(); Self.calls += 1; let n = Self.calls; Self.lock.unlock()
        if n == 1 {
            client?.urlProtocol(self, didFailWithError: URLError(Self.failure))
            return
        }
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("[]".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite(.serialized) struct NetworkRetryTests {
    private func client() -> HTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FlakyProtocol.self]
        return HTTPClient(session: URLSession(configuration: config), timeout: 5)
    }

    @Test func getRetriesOnceAfterTimeout() async throws {
        FlakyProtocol.calls = 0; FlakyProtocol.failure = .timedOut
        let r = try await client().send(URLRequest(url: URL(string: "https://example.test/a")!))
        #expect(r.status == 200)
        #expect(FlakyProtocol.calls == 2)
    }

    @Test func postIsNotRetried() async {
        FlakyProtocol.calls = 0; FlakyProtocol.failure = .timedOut
        var req = URLRequest(url: URL(string: "https://example.test/b")!)
        req.httpMethod = "POST"
        await #expect(throws: APIError.self) { try await client().send(req) }
        #expect(FlakyProtocol.calls == 1)
    }

    @Test func offlineIsNotRetried() async {
        FlakyProtocol.calls = 0; FlakyProtocol.failure = .notConnectedToInternet
        await #expect(throws: APIError.self) { try await client().send(URLRequest(url: URL(string: "https://example.test/c")!)) }
        #expect(FlakyProtocol.calls == 1)
    }
}
