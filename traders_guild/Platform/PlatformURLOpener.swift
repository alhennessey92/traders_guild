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
