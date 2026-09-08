import Foundation
import SkintelCore

/// Public client configuration, read once from Info.plist (populated by
/// Config/*.xcconfig at build time). Nothing here is secret; nothing secret exists
/// in the app. A missing value surfaces as `ConfigurationError` and the app shows a
/// clear screen instead of failing on the first network call.
struct AppConfiguration: Sendable {
    let supabase: SupabaseConfig
    let api: APIConfig
    let termsURL: URL
    let privacyURL: URL

    enum ConfigurationError: LocalizedError {
        case missing(String)
        var errorDescription: String? {
            switch self {
            case .missing(let key):
                "Info.plist is missing \(key). Copy ios/Skintel/Config/Config.example.xcconfig to Config.xcconfig and rebuild."
            }
        }
    }

    static func load(bundle: Bundle = .main) throws -> AppConfiguration {
        func value(_ key: String) throws -> String {
            guard let v = bundle.object(forInfoDictionaryKey: key) as? String,
                  !v.isEmpty, !v.hasPrefix("$(") else { throw ConfigurationError.missing(key) }
            return v
        }
        func url(_ key: String) throws -> URL {
            guard let u = URL(string: try value(key)) else { throw ConfigurationError.missing(key) }
            return u
        }
        return AppConfiguration(
            supabase: SupabaseConfig(url: try url("SUPABASE_URL"), anonKey: try value("SUPABASE_ANON_KEY")),
            api: APIConfig(baseURL: try url("API_BASE_URL")),
            termsURL: try url("LEGAL_TERMS_URL"),
            privacyURL: try url("LEGAL_PRIVACY_URL")
        )
    }

    /// Used by previews and tests; never by the shipping app.
    static let preview = AppConfiguration(
        supabase: SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "preview"),
        api: APIConfig(baseURL: URL(string: "https://example.invalid/api")!),
        termsURL: URL(string: "https://www.skinstel.com/terms")!,
        privacyURL: URL(string: "https://www.skinstel.com/privacy")!
    )
}
