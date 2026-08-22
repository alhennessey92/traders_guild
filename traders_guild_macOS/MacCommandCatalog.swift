//
//  MacCommandCatalog.swift
//  Traders Guild for macOS
//
//  Every menu-bar command and its keyboard shortcut, in one place.
//
//  A catalogue rather than shortcuts scattered through the view tree, for two
//  reasons that are both bugs waiting to happen otherwise: two commands quietly
//  claiming the same chord, and a command claiming one macOS has already reserved
//  — ⌘M is Minimize, ⌘W closes the window, ⌘, opens Settings. A shortcut that
//  fights the system loses, silently, and only on someone else's machine.
//
//  Pure model, no views, macOS-only.
//

import Foundation

struct MacShortcut: Hashable, Sendable {

    struct Modifiers: OptionSet, Hashable, Sendable {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }
        static let command = Modifiers(rawValue: 1 << 0)
        static let shift   = Modifiers(rawValue: 1 << 1)
        static let option  = Modifiers(rawValue: 1 << 2)
        static let control = Modifiers(rawValue: 1 << 3)
    }

    let key: String
    let modifiers: Modifiers

    init(_ key: String, _ modifiers: Modifiers = .command) {
        self.key = key.lowercased()
        self.modifiers = modifiers
    }

    /// Chords macOS assigns application-wide. Claiming one of these does not
    /// override it reliably and confuses users who expect the standard behaviour.
    static let systemReserved: Set<MacShortcut> = [
        MacShortcut("q"), MacShortcut("w"), MacShortcut("m"), MacShortcut("h"),
        MacShortcut("n"), MacShortcut("o"), MacShortcut("p"), MacShortcut("s"),
        MacShortcut("z"), MacShortcut("x"), MacShortcut("c"), MacShortcut("v"),
        MacShortcut("a"), MacShortcut("f"), MacShortcut(","), MacShortcut("?"),
        MacShortcut("z", [.command, .shift]),
    ]

    var isSystemReserved: Bool { Self.systemReserved.contains(self) }
}

enum MacCommandSection: String, CaseIterable, Sendable {
    case view, chart, marker, guild, window
}

struct MacCommand: Identifiable, Hashable, Sendable {

    enum Requirement: Hashable, Sendable {
        /// Always available once signed in.
        case signedIn
        /// Needs more than one pane on screen.
        case multiplePanes
        /// Only while a marker is being placed.
        case placingMarker
        /// Only while NOT placing a marker.
        case notPlacingMarker
    }

    let id: String
    let title: String
    let section: MacCommandSection
    let shortcut: MacShortcut?
    let requirement: Requirement

    func isEnabled(signedIn: Bool, paneCount: Int, isPlacingMarker: Bool) -> Bool {
        guard signedIn else { return false }
        switch requirement {
        case .signedIn:         return true
        case .multiplePanes:    return paneCount > 1
        case .placingMarker:    return isPlacingMarker
        case .notPlacingMarker: return !isPlacingMarker
        }
    }
}

enum MacCommandCatalog {

    static let all: [MacCommand] = layoutCommands + [
        // View
        MacCommand(id: "view.toggleLeftSidebar", title: "Toggle Guild Sidebar",
                   section: .view, shortcut: MacShortcut("\\"), requirement: .signedIn),
        MacCommand(id: "view.toggleRightSidebar", title: "Toggle Messages Sidebar",
                   section: .view, shortcut: MacShortcut("\\", [.command, .option]), requirement: .signedIn),
        MacCommand(id: "view.toggleInspector", title: "Toggle Inspector",
                   section: .view, shortcut: MacShortcut("i", [.command, .option]), requirement: .signedIn),

        // Chart
        MacCommand(id: "chart.symbolSearch", title: "Find Symbol…",
                   section: .chart, shortcut: MacShortcut("k"), requirement: .signedIn),
        MacCommand(id: "chart.focusNextPane", title: "Next Pane",
                   section: .chart, shortcut: MacShortcut("]"), requirement: .multiplePanes),
        MacCommand(id: "chart.focusPreviousPane", title: "Previous Pane",
                   section: .chart, shortcut: MacShortcut("["), requirement: .multiplePanes),
        MacCommand(id: "chart.resetViewport", title: "Reset Chart Position",
                   section: .chart, shortcut: MacShortcut("r"), requirement: .signedIn),

        // Marker — note ⌘M is Minimize, so placing a marker takes ⌘⇧M.
        MacCommand(id: "marker.place", title: "Place Marker",
                   section: .marker, shortcut: MacShortcut("m", [.command, .shift]),
                   requirement: .notPlacingMarker),
        MacCommand(id: "marker.confirmPlacement", title: "Confirm Marker",
                   section: .marker, shortcut: MacShortcut("\r"), requirement: .placingMarker),
        MacCommand(id: "marker.cancelPlacement", title: "Cancel Placement",
                   section: .marker, shortcut: MacShortcut("\u{1b}", []), requirement: .placingMarker),
        MacCommand(id: "marker.showMarkers", title: "Markers",
                   section: .marker, shortcut: MacShortcut("m", [.command, .option]), requirement: .signedIn),

        // Guild
        MacCommand(id: "guild.switch", title: "Switch Guild…",
                   section: .guild, shortcut: MacShortcut("g", [.command, .shift]), requirement: .signedIn),
        MacCommand(id: "guild.saveWorkspace", title: "Save Workspace…",
                   section: .guild, shortcut: MacShortcut("s", [.command, .shift]), requirement: .signedIn),
    ]

    /// ⌘1…⌘5 — the digits are not system-reserved and map to the layout order.
    static let layoutCommands: [MacCommand] = ChartPaneLayout.allCases.map { layout in
        MacCommand(
            id: "view.layout.\(layout.rawValue)",
            title: layout.title,
            section: .view,
            shortcut: MacShortcut(String(layout.keyboardShortcut)),
            requirement: .signedIn
        )
    }

    static func commands(in section: MacCommandSection) -> [MacCommand] {
        all.filter { $0.section == section }
    }

    /// Any chord claimed by more than one command. Must always be empty.
    static var conflictingShortcuts: [MacShortcut] {
        var seen: [MacShortcut: Int] = [:]
        for command in all {
            guard let shortcut = command.shortcut else { continue }
            seen[shortcut, default: 0] += 1
        }
        return seen.filter { $0.value > 1 }.map(\.key)
    }

    /// Any command fighting a macOS-reserved chord. Must always be empty.
    static var systemConflicts: [MacCommand] {
        all.filter { $0.shortcut?.isSystemReserved == true }
    }
}
