import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Direct table access, exactly the queries `useProducts.ts` / `useSubscription.ts` run.
/// RLS on the server restricts every row to `auth.uid()`, which is why `user_id` is sent
/// explicitly on inserts (the policy's `with check` requires it).
public struct PostgRESTClient: Sendable {
    public let config: SupabaseConfig
    public let http: HTTPClient
    public let tokens: any TokenProvider

    public init(config: SupabaseConfig, http: HTTPClient = HTTPClient(), tokens: any TokenProvider) {
        self.config = config
        self.http = http
        self.tokens = tokens
    }

    // MARK: Products

    public func products() async throws -> [ProductWithIngredients] {
        let url = RequestBuilder.url(config.restBase, path: "products",
                                     query: ["select": "*,product_ingredients(*)", "order": "created_at.desc"])
        return try await get([ProductWithIngredients].self, url)
    }

    public func product(id: String) async throws -> ProductWithIngredients? {
        let url = RequestBuilder.url(config.restBase, path: "products",
                                     query: ["select": "*,product_ingredients(*)", "id": "eq.\(id)"])
        return try await get([ProductWithIngredients].self, url).first
    }

    public struct ProductInput: Encodable, Sendable {
        public var user_id: String
        public var brand: String?
        public var product_name: String
        public var category: String?
        public var outcome: Outcome
        public var notes: String?

        public init(userID: String, brand: String?, productName: String, category: String?, outcome: Outcome, notes: String?) {
            user_id = userID; self.brand = brand; product_name = productName
            self.category = category; self.outcome = outcome; self.notes = notes
        }
    }

    public struct IngredientInput: Encodable, Sendable {
        public var product_id: String
        public var user_id: String
        public var position: Int
        public var inci_raw: String
        public var inci_normalized: String
    }

    /// Insert product then its ingredients; on ingredient failure the product is removed,
    /// matching the web's compensating delete.
    public func addProduct(_ input: ProductInput, ingredients: [INCI.ParsedIngredient]) async throws -> Product {
        let created = try await insert([Product].self, path: "products", body: input, returning: true)
        guard let product = created.first else { throw APIError.decoding("Insert returned no product") }
        if !ingredients.isEmpty {
            let rows = ingredients.map {
                IngredientInput(product_id: product.id, user_id: input.user_id, position: $0.position,
                                inci_raw: $0.raw, inci_normalized: $0.normalized)
            }
            do {
                _ = try await insert([ProductIngredient].self, path: "product_ingredients", body: rows, returning: false)
            } catch {
                try? await deleteProduct(id: product.id)
                throw error
            }
        }
        return product
    }

    /// Explicit tri-state so callers can clear a field (`.set(nil)`) or leave it (`.keep`).
    public enum FieldUpdate<T: Sendable>: Sendable {
        case keep
        case set(T?)
    }

    public struct ProductPatch: Sendable {
        public var brand: FieldUpdate<String> = .keep
        public var productName: FieldUpdate<String> = .keep
        public var category: FieldUpdate<String> = .keep
        public var outcome: FieldUpdate<Outcome> = .keep
        public var notes: FieldUpdate<String> = .keep

        public init(brand: FieldUpdate<String> = .keep, productName: FieldUpdate<String> = .keep,
                    category: FieldUpdate<String> = .keep, outcome: FieldUpdate<Outcome> = .keep,
                    notes: FieldUpdate<String> = .keep) {
            self.brand = brand; self.productName = productName; self.category = category
            self.outcome = outcome; self.notes = notes
        }

        var json: [String: JSONValue] {
            var o: [String: JSONValue] = [:]
            if case .set(let v) = brand { o["brand"] = v.map(JSONValue.string) ?? .null }
            if case .set(let v) = productName, let v { o["product_name"] = .string(v) }
            if case .set(let v) = category { o["category"] = v.map(JSONValue.string) ?? .null }
            if case .set(let v) = outcome, let v { o["outcome"] = .string(v.rawValue) }
            if case .set(let v) = notes { o["notes"] = v.map(JSONValue.string) ?? .null }
            return o
        }
    }

    public func updateProduct(id: String, userID: String, patch: ProductPatch,
                              ingredients: [INCI.ParsedIngredient]? = nil) async throws {
        let json = patch.json
        if !json.isEmpty {
            let url = RequestBuilder.url(config.restBase, path: "products", query: ["id": "eq.\(id)"])
            var req = try RequestBuilder.json(url, method: "PATCH", body: json, headers: try await headers())
            req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            try await expectSuccess(req)
        }
        if let ingredients {
            let del = RequestBuilder.url(config.restBase, path: "product_ingredients", query: ["product_id": "eq.\(id)"])
            try await expectSuccess(try RequestBuilder.json(del, method: "DELETE", body: Optional<String>.none, headers: try await headers()))
            if !ingredients.isEmpty {
                let rows = ingredients.map {
                    IngredientInput(product_id: id, user_id: userID, position: $0.position,
                                    inci_raw: $0.raw, inci_normalized: $0.normalized)
                }
                _ = try await insert([ProductIngredient].self, path: "product_ingredients", body: rows, returning: false)
            }
        }
    }

    public func deleteProduct(id: String) async throws {
        let url = RequestBuilder.url(config.restBase, path: "products", query: ["id": "eq.\(id)"])
        try await expectSuccess(try RequestBuilder.json(url, method: "DELETE", body: Optional<String>.none, headers: try await headers()))
    }

    // MARK: Subscription

    public func subscription(userID: String) async throws -> Subscription? {
        let url = RequestBuilder.url(config.restBase, path: "subscriptions",
                                     query: ["select": "*", "user_id": "eq.\(userID)"])
        return try await get([Subscription].self, url).first
    }

    public func foundingSeatsRemaining() async throws -> Int {
        let url = RequestBuilder.url(config.restBase, path: "rpc/founding_seats_remaining")
        var req = try RequestBuilder.json(url, method: "POST", body: [String: String](), headers: try await headers())
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
        return try JSONCoding.decode(Int.self, from: r.data)
    }

    // MARK: Internals

    private func headers() async throws -> [String: String] {
        let token = try await tokens.validAccessToken()
        return ["apikey": config.anonKey, "Authorization": "Bearer \(token)"]
    }

    private func get<T: Decodable>(_ type: T.Type, _ url: URL) async throws -> T {
        let req = try RequestBuilder.json(url, method: "GET", body: Optional<String>.none, headers: try await headers())
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
        return try JSONCoding.decode(T.self, from: r.data)
    }

    private func insert<T: Decodable>(_ type: T.Type, path: String, body: some Encodable, returning: Bool) async throws -> T {
        let url = RequestBuilder.url(config.restBase, path: path)
        var req = try RequestBuilder.json(url, method: "POST", body: body, headers: try await headers())
        req.setValue(returning ? "return=representation" : "return=minimal", forHTTPHeaderField: "Prefer")
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
        if returning { return try JSONCoding.decode(T.self, from: r.data) }
        return try JSONCoding.decode(T.self, from: Data("[]".utf8))
    }

    private func expectSuccess(_ req: URLRequest) async throws {
        let r = try await http.send(req)
        guard (200..<300).contains(r.status) else { throw mapError(status: r.status, data: r.data) }
    }
}
