//
//  MacAppDelegate.swift
//  Traders Guild for macOS
//
//  macOS counterpart to App/AppDelegate.swift. The APNs and notification-tap
//  handling is the same work; only the delegate protocol and the registration
//  call differ, so the bodies mirror the iOS versions exactly.
//

import AppKit
import UserNotifications

final class MacAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - APNs Token Registration

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { @MainActor in
            await PushNotificationManager.shared.didReceiveDeviceToken(token)
        }
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// iOS returns [] here so the in-app WebSocket UI handles a foreground push
    /// instead of a banner. That reasoning does not carry over: a Mac app is
    /// routinely frontmost for hours with the window behind other apps, so a
    /// banner is the only way the user learns about a DM or a marker result.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await PushNotificationManager.shared.handleNotificationTap(userInfo: userInfo)
    }
}
