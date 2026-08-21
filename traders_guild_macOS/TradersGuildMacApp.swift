//
//  TradersGuildMacApp.swift
//  Traders Guild for macOS
//
//  The macOS entry point. Deliberately separate from traders_guildApp.swift
//  rather than shared behind #if: the iOS shell is frozen, and the two platforms
//  want genuinely different scene structure — one full-screen chart versus a
//  resizable window hosting a pane grid, sidebars and a real menu bar.
//

import SwiftUI

@main
struct TradersGuildMacApp: App {

    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate

    @StateObject private var rlAppState = RLAppState()
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environmentObject(rlAppState)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .defaultSize(width: 1440, height: 900)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}
