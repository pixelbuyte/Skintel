import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The Vercel `/api/*` routes. Every call carries the Supabase bearer token; the server
/// validates it and applies the Pro gate (402 → `APIError.proRequired`).
public struct SkintelAPI: Sendable {
    public let config: APIConfig
    public let http: HTTPClient
    public let tokens: any TokenProvider

    public init(config: APIConfig, http: HTTPClient = HTTPClient(timeout: 45), tokens: any TokenProvider) {
        self.config = config
        self.http = http
        self.tokens = tokens
    }

    // MARK: Lookup

    public func lookupBarcode(_ upc: String) async throws -> BarcodeLookup {
        try await get(BarcodeLookup.self, "lookup", ["mode": "barcode", "upc": upc])
    }

    public func searchProducts(_ q: String) async throws -> [ProductSearchResult] {
        try await get(ProductSearchResponse.self, "lookup", ["mode": "search", "q": q]).results
    }

    public func importURL(_ url: String) async throws -> URLImport {
        struct Body: Encodable { let url: String }
        return try await post(URLImport.self, "lookup", ["mode": "url"], body: Body(url: url))
    }

    public func compare(_ request: CompareRequest) async throws -> CompareResult {
        try await post(CompareResult.self, "lookup", ["mode": "compare"], body: request)
    }

    // MARK: Scan

    public func scan(_ request: ScanAIRequest) async throws -> ScanResult {
        try await post(ScanAIResponse.self, "scan-ai", body: request).result
    }

    public func scanPhoto(imageBase64: String, mimeType: String) async throws -> PhotoScanResult {
        struct Body: Encodable { let imageBase64: String; let mimeType: String }
        return try await post(PhotoScanResponse.self, "scan-photo", body: Body(imageBase64: imageBase64, mimeType: mimeType)).result
    }

    // MARK: Journal

    public func journalEntries() async throws -> [JournalEntry] {
        try await get(JournalEntriesResponse.self, "journal").entries
    }

    public func saveJournalEntry(entryDate: String, condition: JournalCondition, notes: String?, photoURL: String?) async throws -> JournalEntry {
        struct Body: Encodable { let entryDate: String; let condition: String; let notes: String?; let photoUrl: String? }
        return try await post(JournalEntryResponse.self, "journal",
                              body: Body(entryDate: entryDate, condition: condition.rawValue, notes: notes, photoUrl: photoURL)).entry
    }

    public func deleteJournalEntry(id: String) async throws {
        try await send("DELETE", "journal", ["id": id], body: Optional<String>.none)
    }

    public func analyzeJournal() async throws -> JournalAnalysis {
        try await post(JournalAnalysisResponse.self, "journal", ["action": "analyze"], body: [String: String]()).result
    }

    // MARK: Routine / Recommend

    public func analyzeRoutine(amProductIDs: [String], pmProductIDs: [String]) async throws -> RoutineAnalysis {
        struct Body: Encodable { let amProductIds: [String]; let pmProductIds: [String] }
        return try await post(RoutineAnalysisResponse.self, "analyze-routine",
                              body: Body(amProductIds: amProductIDs, pmProductIds: pmProductIDs)).result
    }

    public func recommend(_ request: RecommendRequest) async throws -> RecommendResult {
        try await post(RecommendResponse.self, "recommend", body: request).result
    }

    // MARK: Account

    public func exportData() async throws -> Data {
        let r = try await raw("GET", "export-data", [:], body: Optional<String>.none)
        return r.data
    }

    public func deleteAccount() async throws {
        try await send("POST", "delete-account", [:], body: [String: String]())
    }

    // MARK: Apple IAP

    public func verifyAppleTransaction(signedTransaction: String) async throws -> Subscription {
        try await post(AppleVerifyResponse.self, "apple-verify",
                       body: AppleVerifyRequest(signedTransaction: signedTransaction)).subscription
    }

    // MARK: Internals

    private func headers() async throws -> [String: String] {
        ["Authorization": "Bearer \(try await tokens.validAccessToken())"]
    }

    private func raw(_ method: String, _ path: String, _ query: [String: String], body: (some Encodable)?) async throws -> HTTPClient.Response {
        let url = RequestBuilder.url(config.baseURL, path: path, query: query)
        let req = try RequestBuilder.json(url, method: method, body: body, headers: try await headers())
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
        return r
    }

    private func get<T: Decodable>(_ type: T.Type, _ path: String, _ query: [String: String] = [:]) async throws -> T {
        try JSONCoding.decode(T.self, from: try await raw("GET", path, query, body: Optional<String>.none).data)
    }

    private func post<T: Decodable>(_ type: T.Type, _ path: String, _ query: [String: String] = [:], body: some Encodable) async throws -> T {
        try JSONCoding.decode(T.self, from: try await raw("POST", path, query, body: body).data)
    }

    private func send(_ method: String, _ path: String, _ query: [String: String], body: (some Encodable)?) async throws {
        _ = try await raw(method, path, query, body: body)
    }
}
