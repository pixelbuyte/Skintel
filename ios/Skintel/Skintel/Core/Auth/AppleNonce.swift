import CryptoKit
import Foundation
import Security

/// Sign in with Apple replay protection: a random nonce goes to Supabase raw, its SHA-256
/// goes to Apple in the request, and Supabase checks the token's hashed nonce matches.
enum AppleNonce {
    static func random(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// PKCE for the OAuth web flow (Continue with Google). The raw verifier stays on the device
/// until the code exchange; only its SHA-256 (base64url) goes out in the authorize URL.
enum OAuthPKCE {
    static let callbackScheme = "skintel"
    /// Must be allowed in Supabase Auth → URL Configuration → Redirect URLs.
    static let redirectURL = URL(string: "skintel://auth-callback")!
    static let callbackHost = "auth-callback"

    /// 64 URL-safe characters (RFC 7636 allows 43–128). The alphabet has exactly 64 symbols,
    /// so `byte % 64` has no bias.
    static func verifier(length: Int = 64) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        let charset = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    /// `base64url(SHA256(verifier))`, unpadded (the S256 method).
    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
