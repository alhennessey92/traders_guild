//
//  PlatformScreen.swift
//  traders_guild
//
//  `UIScreen` does not exist on macOS, and it is referenced ~32 times across the
//  chart and shell — almost always as a fallback for "the chart has not been laid
//  out yet, guess a size".
//
//  This is a **verbatim pass-through on iOS**. It returns exactly what
//  `UIScreen.main.bounds` returned, so no iOS layout or gesture changes. That is
//  deliberate: several of these fallbacks feed tuned gesture maths, and the iOS
//  app's behaviour is frozen. Do not "improve" the iOS branch here — if a fallback
//  wants to become container-relative, that belongs in the macOS layout work.
//

import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformScreen {

    /// iOS: `UIScreen.main.bounds`, unchanged.
    /// macOS: the main display's frame — the closest equivalent, and only ever
    /// consulted before a chart has been measured.
    static var bounds: CGRect {
        #if canImport(UIKit)
        return UIScreen.main.bounds
        #elseif canImport(AppKit)
        // `NSScreen.main` is nil with no attached display (headless CI, for one).
        return NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        #else
        return CGRect(x: 0, y: 0, width: 1440, height: 900)
        #endif
    }
}
