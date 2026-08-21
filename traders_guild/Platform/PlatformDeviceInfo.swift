//
//  PlatformDeviceInfo.swift
//  traders_guild
//
//  The device descriptors sent with auth/session requests. This was the single
//  UIKit dependency in RLAppState.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum PlatformDeviceInfo {

    /// Hardware family — "iPhone", "iPad", or "Mac".
    static var model: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "Mac"
        #endif
    }

    static var systemName: String {
        #if canImport(UIKit)
        return UIDevice.current.systemName
        #else
        return "macOS"
        #endif
    }

    static var systemVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #endif
    }

    /// The value registered against a push token. The backend accepts
    /// "ios" | "android" today; "macos" is additive (see the port plan).
    static var pushPlatform: String {
        #if os(macOS)
        return "macos"
        #else
        return "ios"
        #endif
    }
}
