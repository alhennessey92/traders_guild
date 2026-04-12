//
//  KeychainPreferences.swift
//  traders_guild
//
//  Lightweight Keychain-backed preference storage for flags that must
//  survive app reinstalls (UserDefaults is wiped on reinstall, Keychain is not).
//

import Foundation
import Security

enum KeychainPreferences {
    private static let service = "com.tradersguild.preferences"

    // MARK: - Bool values

    static func setBool(_ value: Bool, forKey key: String) {
        let data = Data([value ? 1 : 0])
        save(data: data, forKey: key)
    }

    static func bool(forKey key: String) -> Bool {
        guard let data = load(forKey: key), let byte = data.first else { return false }
        return byte != 0
    }

    // MARK: - Remove

    static func removeValue(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private

    private static func save(data: Data, forKey key: String) {
        // Delete existing first
        removeValue(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
