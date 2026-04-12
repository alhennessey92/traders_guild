//
//  BiometricAuthManager.swift
//  traders_guild
//

import Foundation
import LocalAuthentication
import Security

/// Manages FaceID/TouchID authentication and secure Keychain storage
/// of refresh tokens with biometric protection.
class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private let keychainService = "com.tradersguild.biometric"
    private let keychainAccount = "biometric_refresh_token"
    private let biometricEnabledKey = "traders_guild_biometric_enabled"

    // MARK: - Biometric Availability

    enum BiometricType {
        case faceID
        case touchID
        case none
    }

    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .faceID // Treat Vision Pro optic ID like FaceID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    var isBiometricAvailable: Bool {
        biometricType != .none
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "Biometrics"
        }
    }

    var biometricIconName: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.shield"
        }
    }

    // MARK: - Biometric Enabled State

    var isBiometricEnabled: Bool {
        get {
            // Check Keychain first (survives reinstall), fall back to UserDefaults for migration
            KeychainPreferences.bool(forKey: biometricEnabledKey)
                || UserDefaults.standard.bool(forKey: biometricEnabledKey)
        }
        set {
            KeychainPreferences.setBool(newValue, forKey: biometricEnabledKey)
            UserDefaults.standard.set(newValue, forKey: biometricEnabledKey)
        }
    }

    /// Whether biometric login is available and enabled
    var canUseBiometricLogin: Bool {
        isBiometricAvailable && isBiometricEnabled && hasBiometricToken
    }

    // MARK: - Biometric Authentication

    /// Authenticate user with FaceID/TouchID
    func authenticate(reason: String? = nil) async throws -> Bool {
        let context = LAContext()
        let reason = reason ?? "Sign in to Traders Guild"

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    // MARK: - Biometric-Protected Keychain Storage

    /// Store refresh token in Keychain with biometric protection
    func storeBiometricRefreshToken(_ token: String) throws {
        // Delete existing item first
        deleteBiometricRefreshToken()

        guard let tokenData = token.data(using: .utf8) else {
            throw BiometricError.invalidData
        }

        // Create access control requiring biometric authentication
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw BiometricError.keychainError(error?.takeRetainedValue().localizedDescription ?? "Unknown error")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: tokenData,
            kSecAttrAccessControl as String: accessControl,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricError.keychainError("Failed to store token: \(status)")
        }
    }

    /// Retrieve refresh token from Keychain (triggers biometric prompt)
    func retrieveBiometricRefreshToken() async throws -> String? {
        let context = LAContext()
        context.localizedReason = "Sign in to Traders Guild"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context,
        ]

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)

                if status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: token)
                } else if status == errSecUserCanceled || status == errSecAuthFailed {
                    continuation.resume(throwing: BiometricError.authenticationFailed)
                } else if status == errSecItemNotFound {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(throwing: BiometricError.keychainError("Failed to retrieve token: \(status)"))
                }
            }
        }
    }

    /// Check if a biometric-protected token exists (without triggering auth)
    var hasBiometricToken: Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecUseAuthenticationContext as String: context,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // errSecInteractionNotAllowed means the item exists but needs biometric
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    /// Delete biometric-protected token from Keychain
    func deleteBiometricRefreshToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Disable biometric login and remove stored token
    func disableBiometric() {
        KeychainPreferences.setBool(false, forKey: biometricEnabledKey)
        UserDefaults.standard.set(false, forKey: biometricEnabledKey)
        deleteBiometricRefreshToken()
    }

    // MARK: - Errors

    enum BiometricError: LocalizedError {
        case authenticationFailed
        case notAvailable
        case invalidData
        case keychainError(String)

        var errorDescription: String? {
            switch self {
            case .authenticationFailed:
                return "Biometric authentication failed or was cancelled."
            case .notAvailable:
                return "Biometric authentication is not available on this device."
            case .invalidData:
                return "Failed to process authentication data."
            case .keychainError(let detail):
                return "Keychain error: \(detail)"
            }
        }
    }
}
