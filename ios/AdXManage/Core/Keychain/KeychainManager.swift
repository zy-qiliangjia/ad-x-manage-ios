import Foundation
import Security

// MARK: - Keychain 键名

private enum KeychainKey {
    static let accessToken = "com.adxmanage.access_token"
    static let expiresAt   = "com.adxmanage.token_expires_at"
    static let userEmail   = "com.adxmanage.user_email"
}

// MARK: - KeychainManager

final class KeychainManager {

    static let shared = KeychainManager()
    private init() {}

    // MARK: - Token

    func saveToken(_ token: String, expiresAt: Date, email: String) {
        set(value: token,  forKey: KeychainKey.accessToken)
        set(value: String(expiresAt.timeIntervalSince1970), forKey: KeychainKey.expiresAt)
        set(value: email,  forKey: KeychainKey.userEmail)
    }

    func loadToken() -> String? {
        get(forKey: KeychainKey.accessToken)
    }

    func tokenExpiresAt() -> Date? {
        guard let raw = get(forKey: KeychainKey.expiresAt),
              let ts  = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    func loadEmail() -> String? {
        get(forKey: KeychainKey.userEmail)
    }

    func deleteToken() {
        delete(forKey: KeychainKey.accessToken)
        delete(forKey: KeychainKey.expiresAt)
        delete(forKey: KeychainKey.userEmail)
    }

    var isLoggedIn: Bool {
        guard let token = loadToken(), !token.isEmpty else { return false }
        // token 本身存在就算已登录；自动续签在 APIClient 里处理
        return true
    }

    // MARK: - 私有 Keychain 操作

    private func set(value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func get(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
