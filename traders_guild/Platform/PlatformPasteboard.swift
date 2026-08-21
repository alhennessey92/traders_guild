//
//  PlatformPasteboard.swift
//  traders_guild
//
//  `UIPasteboard.general.string = x` has no macOS equivalent — AppKit requires
//  an explicit clear before write — so both sides go through `copy(_:)`.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformPasteboard {

    /// Replace the pasteboard contents with `string`.
    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #endif
    }

    /// Current pasteboard text, if any.
    static var string: String? {
        #if canImport(UIKit)
        return UIPasteboard.general.string
        #elseif canImport(AppKit)
        return NSPasteboard.general.string(forType: .string)
        #else
        return nil
        #endif
    }
}
