//
//  PlatformDisplayLink.swift
//  traders_guild
//
//  The chart's pan momentum and its centring animation are both driven by a
//  display link. `CADisplayLink(target:selector:)` is iOS-only; macOS 14 vends
//  an equivalent from the screen itself. Both return a `CADisplayLink`, so only
//  construction differs — `add(to:forMode:)` and the callback signature are
//  identical, and the iOS branch is the shipped expression verbatim.
//

import QuartzCore

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformDisplayLink {

    /// Returns nil on macOS when there is no attached display, in which case the
    /// caller simply gets no animation rather than a crash.
    static func make(target: Any, selector: Selector) -> CADisplayLink? {
        #if canImport(UIKit)
        return CADisplayLink(target: target, selector: selector)
        #elseif canImport(AppKit)
        return NSScreen.main?.displayLink(target: target, selector: selector)
        #else
        return nil
        #endif
    }
}
