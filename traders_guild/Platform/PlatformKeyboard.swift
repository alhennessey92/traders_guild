//
//  PlatformKeyboard.swift
//  traders_guild
//
//  Dismissing the keyboard and tracking its frame. Both are expressed on iOS via
//  UIKit responder-chain plumbing that has no direct macOS analogue — a Mac has
//  no software keyboard, so "dismiss" means resigning first responder and the
//  frame is always zero.
//
//  The iOS branches are the shipped expressions verbatim.
//

import Combine
import CoreGraphics
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformKeyboard {

    /// End editing globally.
    ///
    /// iOS walks the responder chain because there is no view context here;
    /// macOS clears the key window's first responder, which is the equivalent.
    @MainActor
    static func dismiss() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #elseif canImport(AppKit)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
    }

    /// Height the software keyboard currently covers, in points.
    ///
    /// Always 0 on macOS, so layouts that inset for the keyboard simply do not
    /// inset. Emitting a real publisher rather than nothing keeps the call sites
    /// identical across platforms.
    static var heightPublisher: AnyPublisher<CGFloat, Never> {
        #if canImport(UIKit)
        let willChange = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .map { note -> CGFloat in
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                return frame?.height ?? 0
            }
        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        return willChange.merge(with: willHide).eraseToAnyPublisher()
        #else
        return Just(CGFloat(0)).eraseToAnyPublisher()
        #endif
    }
}
