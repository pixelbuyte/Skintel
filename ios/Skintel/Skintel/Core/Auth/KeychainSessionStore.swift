import Foundation
import Security
import SkintelCore

/// Stores the Supabase session as JSON in the Keychain (generic password item,
/// this-device-only, available after first unlock so background refreshes work).
/// Never UserDefaults.
struct KeychainSessionStore: Sendable {
    private let service = "com.skintel.app.session"
    private let account = "supabase"

    enum KeychainError: Error { case status(OSStatus) }

    func load() -> Session? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    func save(_ session: Session) throws {
        let data = try JSONEncoder().encode(session)
        var attrs = baseQuery
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attrs as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [String: Any] = [kSecValueData as String: data]
            let s2 = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
            guard s2 == errSecSuccess else { throw KeychainError.status(s2) }
        } else if status != errSecSuccess {
            throw KeychainError.status(status)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
