//
//  PushNotificationManager.swift
//  traders_guild
//
//  Handles APNs permission requests, device token lifecycle,
//  and push notification tap routing.
//

import Foundation
import UIKit
import UserNotifications

protocol DeviceTokenAPIClient: AnyObject {
    func registerDeviceToken(deviceToken: String, platform: String) async throws
    func deregisterDeviceToken(deviceToken: String) async throws
}

extension RealAPIService: DeviceTokenAPIClient {}

protocol PushNotificationAuthorizationProviding {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
}

struct SystemPushNotificationAuthorizationProvider: PushNotificationAuthorizationProviding {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
}

protocol RemoteNotificationRegistering {
    func registerForRemoteNotifications()
}

struct UIApplicationRemoteNotificationRegistrar: RemoteNotificationRegistering {
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}

enum PushRegistrationReason: String {
    case login = "login"
    case sessionRestore = "session_restore"
    case biometricLogin = "biometric_login"
    case appActive = "app_active"
    case manual = "manual"
    case permissionPrompt = "permission_prompt"
    case apnsCallback = "apns_callback"
}

enum PushBackendRegistrationState: Equatable {
    case idle
    case success
    case failure

    var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .success:
            return "Success"
        case .failure:
            return "Failure"
        }
    }
}

struct PushRegistrationDiagnostics: Equatable {
    var lastAPNsToken: String?
    var lastAPNsRegistrationAttemptAt: Date?
    var lastAPNsRegistrationReason: String?
    var lastBackendRegistrationAttemptAt: Date?
    var lastBackendRegistrationReason: String?
    var lastBackendRegistrationState: PushBackendRegistrationState = .idle
    var lastBackendRegisteredToken: String?
    var lastErrorMessage: String?
    var lastErrorAt: Date?
    var isBackendRegisteredThisSession: Bool = false
    var isRegisteringWithBackend: Bool = false
}

extension UNAuthorizationStatus {
    var supportsRemoteNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    var debugLabel: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
}

@MainActor
final class PushNotificationManager: ObservableObject {

    static let shared = PushNotificationManager()

    @Published private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var isRegistered: Bool = false
    @Published private(set) var diagnostics = PushRegistrationDiagnostics()

    private var currentDeviceToken: String?
    private var pendingTapPayload: RLPushNotificationTapPayload?
    private let authorizationProvider: any PushNotificationAuthorizationProviding
    private let remoteRegistrar: any RemoteNotificationRegistering
    private weak var apiService: (any DeviceTokenAPIClient)?

    init(
        authorizationProvider: any PushNotificationAuthorizationProviding = SystemPushNotificationAuthorizationProvider(),
        remoteRegistrar: any RemoteNotificationRegistering = UIApplicationRemoteNotificationRegistrar()
    ) {
        self.authorizationProvider = authorizationProvider
        self.remoteRegistrar = remoteRegistrar
    }

    // MARK: - Configuration

    func configure(apiService: any DeviceTokenAPIClient) {
        self.apiService = apiService
    }

    // MARK: - Permission & Registration

    /// Request notification permission if needed and then register with APNs.
    func requestPermissionAndRegister(reason: PushRegistrationReason = .permissionPrompt) async {
        let permissionGranted = await requestPermissionIfNeeded()
        guard permissionGranted else { return }
        await registerForRemoteNotifications(reason: reason)
    }

    /// Request notification permission only when the user has not made a decision yet.
    func requestPermissionIfNeeded() async -> Bool {
        await refreshPermissionStatus()
        guard permissionStatus == .notDetermined else {
            return permissionStatus.supportsRemoteNotifications
        }

        do {
            let granted = try await authorizationProvider.requestAuthorization()
            permissionStatus = await authorizationProvider.authorizationStatus()
            print("📬 Push permission request result: granted=\(granted) status=\(permissionStatus.debugLabel)")
            if !granted && !permissionStatus.supportsRemoteNotifications {
                diagnostics.lastErrorMessage = "Notifications are not authorized on this device."
                diagnostics.lastErrorAt = Date()
            }
            return permissionStatus.supportsRemoteNotifications
        } catch {
            recordError("Push notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    /// Ask iOS to register with APNs and retry backend token registration when a cached token exists.
    func registerForRemoteNotifications(
        reason: PushRegistrationReason,
        allowPermissionPrompt: Bool = false
    ) async {
        let canRegister: Bool
        if allowPermissionPrompt {
            canRegister = await requestPermissionIfNeeded()
        } else {
            await refreshPermissionStatus()
            canRegister = permissionStatus.supportsRemoteNotifications
        }

        guard canRegister else {
            print("📬 Skipping APNs registration (\(reason.rawValue)) because status=\(permissionStatus.debugLabel)")
            return
        }

        diagnostics.lastAPNsRegistrationAttemptAt = Date()
        diagnostics.lastAPNsRegistrationReason = reason.rawValue
        print("📬 Requesting APNs registration (\(reason.rawValue)) status=\(permissionStatus.debugLabel)")
        remoteRegistrar.registerForRemoteNotifications()

        if let token = currentDeviceToken,
           (!isRegistered || diagnostics.lastBackendRegisteredToken != token || reason == .manual) {
            await registerTokenWithBackend(token, reason: reason)
        }
    }

    /// Refresh the cached permission status (e.g. when returning from system settings).
    func refreshPermissionStatus() async {
        permissionStatus = await authorizationProvider.authorizationStatus()
    }

    // MARK: - Token Lifecycle

    /// Called by AppDelegate when iOS provides a device token.
    func didReceiveDeviceToken(_ token: String) async {
        currentDeviceToken = token
        diagnostics.lastAPNsToken = token
        print("📬 Received APNs device token (\(token.prefix(16)))")
        await registerTokenWithBackend(token, reason: .apnsCallback)
    }

    /// Called by AppDelegate when APNs registration fails.
    func didFailToRegisterForRemoteNotifications(_ error: Error) {
        recordError("APNs registration failed: \(error.localizedDescription)")
    }

    /// Register the token with the backend.
    private func registerTokenWithBackend(_ token: String, reason: PushRegistrationReason) async {
        guard let api = apiService else {
            recordError("Push token registration skipped because the API service is unavailable.")
            return
        }

        diagnostics.lastBackendRegistrationAttemptAt = Date()
        diagnostics.lastBackendRegistrationReason = reason.rawValue
        diagnostics.isRegisteringWithBackend = true
        diagnostics.lastBackendRegistrationState = .idle
        print("📬 Registering device token with backend (\(reason.rawValue))")

        do {
            try await api.registerDeviceToken(deviceToken: token, platform: "ios")
            isRegistered = true
            diagnostics.isRegisteringWithBackend = false
            diagnostics.isBackendRegisteredThisSession = true
            diagnostics.lastBackendRegistrationState = .success
            diagnostics.lastBackendRegisteredToken = token
            diagnostics.lastErrorMessage = nil
            diagnostics.lastErrorAt = nil
            print("📬 Device token registered with backend")
        } catch {
            isRegistered = false
            diagnostics.isRegisteringWithBackend = false
            diagnostics.isBackendRegisteredThisSession = false
            diagnostics.lastBackendRegistrationState = .failure
            recordError("Failed to register device token: \(error.localizedDescription)")
        }
    }

    /// Deregister the current token (call on logout).
    func deregisterToken() async {
        guard let api = apiService, let token = currentDeviceToken else { return }
        do {
            try await api.deregisterDeviceToken(deviceToken: token)
        } catch {
            recordError("Failed to deregister device token: \(error.localizedDescription)")
        }
        currentDeviceToken = nil
        isRegistered = false
        diagnostics.lastAPNsToken = nil
        diagnostics.lastBackendRegisteredToken = nil
        diagnostics.isBackendRegisteredThisSession = false
        diagnostics.lastBackendRegistrationState = .idle
        diagnostics.isRegisteringWithBackend = false
    }

    // MARK: - Tap Handling

    /// Decode the push payload and post a system notification so
    /// NotificationNavigationManager can route the user.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) async {
        guard let payload = RLPushNotificationTapPayload(userInfo: userInfo) else {
            print("⚠️ Ignoring push tap because the payload could not be parsed")
            return
        }

        pendingTapPayload = payload
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil
        )
        print("📬 Push tap queued for navigation (\(payload.notificationType))")
    }

    func consumePendingTapPayload() -> RLPushNotificationTapPayload? {
        let payload = pendingTapPayload
        pendingTapPayload = nil
        return payload
    }

    private func recordError(_ message: String) {
        diagnostics.lastErrorMessage = message
        diagnostics.lastErrorAt = Date()
        if diagnostics.isRegisteringWithBackend {
            diagnostics.isRegisteringWithBackend = false
        }
        print("⚠️ \(message)")
    }
}

// MARK: - Notification.Name Extension

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
