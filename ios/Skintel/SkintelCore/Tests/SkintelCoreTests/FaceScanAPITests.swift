import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import SkintelCore

/// Answers every request with a fixed status and body, and records what it saw.
final class FaceScanStubProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var calls = 0
    nonisolated(unsafe) static var lastTimeout: TimeInterval = 0
    nonisolated(unsafe) static var lastURL: URL?
    nonisolated(unsafe) static var lastMethod: String?
    nonisolated(unsafe) static var lastAuth: String?
    private static let lock = NSLock()

    static func reset(status: Int, body: String) {
        lock.lock(); defer { lock.unlock() }
        self.status = status
        self.body = Data(body.utf8)
        calls = 0; lastTimeout = 0; lastURL = nil; lastMethod = nil; lastAuth = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lock.lock()
        Self.calls += 1
        Self.lastTimeout = request.timeoutInterval
        Self.lastURL = request.url
        Self.lastMethod = request.httpMethod
        Self.lastAuth = request.value(forHTTPHeaderField: "Authorization")
        let status = Self.status, body = Self.body
        Self.lock.unlock()
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

private struct StubTokens: TokenProvider {
    func validAccessToken() async throws -> String { "tok-123" }
}

private let okBody = """
{ "quality": { "ok": true, "issues": [] },
  "zones": [ { "zone": "chin", "scores": { "redness": 34 }, "note": "n" } ],
  "summary": "Mostly calm.", "disclaimer": "A cosmetic read of a photo, not a diagnosis." }
"""

@Suite(.serialized) struct FaceScanAPITests {
    private func api() -> SkintelAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FaceScanStubProtocol.self]
        // The shared client's timeout is deliberately not 60, to prove the call overrides it.
        return SkintelAPI(config: APIConfig(baseURL: URL(string: "https://example.test/api")!),
                          http: HTTPClient(session: URLSession(configuration: config), timeout: 5),
                          tokens: StubTokens())
    }

    private let request = FaceScanRequest(stage: .baseline, cycleId: "c1", day: 1,
                                          images: [FaceScanImage(role: .front, base64: "AAAA")],
                                          answers: FaceAnswers())

    private func failure(status: Int, body: String) async -> APIError? {
        FaceScanStubProtocol.reset(status: status, body: body)
        do {
            _ = try await api().faceScan(request)
            return nil
        } catch {
            return error as? APIError
        }
    }

    @Test func faceScanPostsToFaceScanWithTheTokenAndASixtySecondTimeout() async throws {
        FaceScanStubProtocol.reset(status: 200, body: okBody)
        let result = try await api().faceScan(request)
        #expect(result.summary == "Mostly calm.")
        #expect(result.score(.redness, in: .chin) == 34)
        #expect(FaceScanStubProtocol.calls == 1)
        #expect(FaceScanStubProtocol.lastURL?.path == "/api/face-scan")
        #expect(FaceScanStubProtocol.lastMethod == "POST")
        #expect(FaceScanStubProtocol.lastAuth == "Bearer tok-123")
        #expect(FaceScanStubProtocol.lastTimeout == 60)
        #expect(SkintelAPI.faceScanTimeout == 60)
    }

    @Test func statusIsCheckedBeforeTheBodyIsDecoded() async {
        // Every one of these carries a perfectly good result body; the status still decides.
        #expect(await failure(status: 402, body: okBody) == .proRequired)
        #expect(await failure(status: 429, body: okBody) == .rateLimited)
        #expect(await failure(status: 413, body: okBody) == .payloadTooLarge)
        #expect(await failure(status: 401, body: okBody) == .unauthenticated)
        #expect(await failure(status: 500, body: #"{"error":"boom"}"#) == .server(status: 500, message: "boom"))
        // A 413 from the platform is often not JSON at all.
        #expect(await failure(status: 413, body: "Request Entity Too Large") == .payloadTooLarge)
        #expect(FaceScanStubProtocol.calls == 1)       // one attempt each: a POST is never retried
    }

    @Test func aSuccessfulReplyThatIsNotAResultIsADecodingError() async {
        guard case .decoding = await failure(status: 200, body: "[]") else {
            Issue.record("expected a decoding error")
            return
        }
    }

    @Test func aTolerantReplyDecodesEvenWhenSparse() async throws {
        FaceScanStubProtocol.reset(status: 200, body: "{}")
        let result = try await api().faceScan(request)
        #expect(result.quality.ok == false)
        #expect(result.disclaimer == FaceScanResult.defaultDisclaimer)
    }

    @Test func anInvalidRequestNeverLeavesTheDevice() async {
        FaceScanStubProtocol.reset(status: 200, body: okBody)
        let tooMany = FaceScanRequest(stage: .daily, cycleId: "c1", day: 2, images: [
            FaceScanImage(role: .front, base64: "AAAA"), FaceScanImage(role: .front, base64: "AAAA"),
        ])
        do {
            _ = try await api().faceScan(tooMany)
            Issue.record("expected a bad request")
        } catch let e as APIError {
            guard case .badRequest(let reason) = e else { Issue.record("wrong error \(e)"); return }
            #expect(reason?.contains("at most 1") == true)
        } catch {
            Issue.record("wrong error \(error)")
        }
        #expect(FaceScanStubProtocol.calls == 0)
    }
}

@Test func payloadTooLargeIsMappedAndNotRetryable() {
    #expect(mapError(status: 413, data: Data()) == .payloadTooLarge)
    #expect(mapError(status: 413, data: Data(#"{"error":"too big"}"#.utf8)) == .payloadTooLarge)
    #expect(!APIError.payloadTooLarge.isRetryable)
    #expect(!APIError.payloadTooLarge.requiresPaywall)
    #expect(APIError.payloadTooLarge.userMessage.contains("photos"))
    // The neighbours are untouched.
    #expect(mapError(status: 402, data: Data()) == .proRequired)
    #expect(mapError(status: 429, data: Data()) == .rateLimited)
    #expect(mapError(status: 422, data: Data()) == .unprocessable(nil))
}
