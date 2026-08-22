//
//  PlatformURLOpener.swift
//  traders_guild
//
//  Opening a URL outside the app. `UIApplication.shared.open` reports success
//  asynchronously; `NSWorkspace.open` returns it directly. The completion form
//  exists for the "try the app's own scheme, fall back to the web" flow in
//  GuildInviteShareKit.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
enum PlatformURLOpener {

    static func open(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Opens the app's own entry in the system settings app.
    ///
    /// iOS deep-links to the app's page; macOS has no per-app settings pane, so it
    /// opens Notifications, which is what this button is for in both apps.
    static func openSystemSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif canImport(AppKit)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    /// Opens `url` and reports whether the system accepted it. Used to decide
    /// whether a custom-scheme link resolved before falling back to https.
    static func open(_ url: URL, completion: @escaping (Bool) -> Void) {
        #if canImport(UIKit)
        UIApplication.shared.open(url, options: [:]) { success in
            completion(success)
        }
        #elseif canImport(AppKit)
        completion(NSWorkspace.shared.open(url))
        #else
        completion(false)
        #endif
    }
}
