import Foundation
import Security

/// Minimal wrapper around the Keychain generic-password APIs for storing small secrets on-device.
enum KeychainHelper {
    /// Saves (or, for an empty value, removes) a secret. Returns false if the Keychain
    /// rejected the write, so callers don't report a key as saved when it isn't.
    @discardableResult
    static func save(_ value: String, account: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            print("Keychain delete failed for \(account): \(deleteStatus)")
            return false
        }

        guard !value.isEmpty else { return true }

        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        if addStatus != errSecSuccess {
            print("Keychain add failed for \(account): \(addStatus)")
        }
        return addStatus == errSecSuccess
    }

    static func read(account: String, service: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }
}
