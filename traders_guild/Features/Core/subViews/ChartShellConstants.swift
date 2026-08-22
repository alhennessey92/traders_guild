//
//  ChartShellConstants.swift
//  traders_guild
//
//  Layout and animation constants for the chart shell.
//
//  Moved verbatim out of MainView.swift. MainView is the iOS shell and is
//  excluded from the macOS target, but the drawers that use these constants are
//  shared — so leaving them there made them invisible to macOS. Pure move: no
//  value changed.
//

import SwiftUI

// MARK: - Constants
enum LayoutConstants {
    static let drawerWidthRatio: CGFloat = 0.9
    static let drawerDismissThreshold: CGFloat = 100
    static let overlayOpacity: CGFloat = 0.4
    static let cornerRadius: CGFloat = 33
    static let shadowRadius: CGFloat = 8
}

enum AnimationConstants {
    static let standard = Animation.spring(response: 0.6, dampingFraction: 0.8)
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
}
