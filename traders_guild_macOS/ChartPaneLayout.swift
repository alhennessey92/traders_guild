//
//  ChartPaneLayout.swift
//  Traders Guild for macOS
//
//  Geometry for the chart pane grid: how a window's chart area divides into
//  1–4 panes, and where the draggable splitters sit.
//
//  Pure maths, deliberately outside any view — the same reasoning as
//  [MainChartViewport] on the iOS side. Layout bugs in a resizable, drag-to-split
//  grid are miserable to diagnose through the UI, and this way they are unit
//  tests instead.
//
//  macOS-only: iOS shows one full-screen chart and its shell is frozen.
//

import CoreGraphics
import Foundation

enum ChartPaneLayout: String, CaseIterable, Codable, Sendable {

    /// One chart filling the area — the iOS arrangement.
    case single
    /// Two side by side.
    case twoUpHorizontal
    /// Two stacked.
    case twoUpVertical
    /// One tall pane on the left, two stacked on the right.
    case threeUp
    /// Classic 2x2.
    case grid

    var paneCount: Int {
        switch self {
        case .single: return 1
        case .twoUpHorizontal, .twoUpVertical: return 2
        case .threeUp: return 3
        case .grid: return 4
        }
    }

    var title: String {
        switch self {
        case .single: return "Single"
        case .twoUpHorizontal: return "Two Across"
        case .twoUpVertical: return "Two Down"
        case .threeUp: return "Three"
        case .grid: return "Grid"
        }
    }

    /// ⌘1…⌘5 in the View menu.
    var keyboardShortcut: Character {
        switch self {
        case .single: return "1"
        case .twoUpHorizontal: return "2"
        case .twoUpVertical: return "3"
        case .threeUp: return "4"
        case .grid: return "5"
        }
    }

    /// How many independent split ratios this layout has, in the order
    /// `ChartPaneSplits` stores them.
    var splitCount: Int {
        switch self {
        case .single: return 0
        case .twoUpHorizontal, .twoUpVertical: return 1
        case .threeUp: return 2   // vertical divide, then the right column's split
        case .grid: return 2      // one column divide, one row divide
        }
    }
}

/// Where the user has dragged each splitter, as a fraction of the available
/// extent. Stored per layout so switching back and forth preserves the feel.
struct ChartPaneSplits: Equatable, Codable, Sendable {

    /// Smallest a pane may become, as a fraction. Below roughly this, a chart has
    /// too few candles on screen to read.
    static let minimumFraction: CGFloat = 0.15

    private(set) var fractions: [CGFloat]

    init(layout: ChartPaneLayout) {
        fractions = Array(repeating: 0.5, count: layout.splitCount)
    }

    init(fractions: [CGFloat]) {
        self.fractions = fractions.map { Self.clamp($0) }
    }

    static func clamp(_ value: CGFloat) -> CGFloat {
        Swift.min(1 - minimumFraction, Swift.max(minimumFraction, value))
    }

    subscript(index: Int) -> CGFloat {
        get { fractions.indices.contains(index) ? fractions[index] : 0.5 }
        set {
            guard fractions.indices.contains(index) else { return }
            fractions[index] = Self.clamp(newValue)
        }
    }
}

enum ChartPaneGeometry {

    /// Gap between panes, and therefore the splitter's visual width.
    static let gutter: CGFloat = 8

    /// Frames for every pane, in the pane order the grid renders.
    ///
    /// Returns an empty array for a degenerate size rather than negative frames —
    /// a window can legitimately report zero during a resize.
    static func frames(
        layout: ChartPaneLayout,
        in size: CGSize,
        splits: ChartPaneSplits
    ) -> [CGRect] {
        guard size.width > 0, size.height > 0 else { return [] }

        switch layout {
        case .single:
            return [CGRect(origin: .zero, size: size)]

        case .twoUpHorizontal:
            let (left, right) = divide(size.width, at: splits[0])
            return [
                CGRect(x: 0, y: 0, width: left, height: size.height),
                CGRect(x: left + gutter, y: 0, width: right, height: size.height),
            ]

        case .twoUpVertical:
            let (top, bottom) = divide(size.height, at: splits[0])
            return [
                CGRect(x: 0, y: 0, width: size.width, height: top),
                CGRect(x: 0, y: top + gutter, width: size.width, height: bottom),
            ]

        case .threeUp:
            let (left, right) = divide(size.width, at: splits[0])
            let (upper, lower) = divide(size.height, at: splits[1])
            let rightX = left + gutter
            return [
                CGRect(x: 0, y: 0, width: left, height: size.height),
                CGRect(x: rightX, y: 0, width: right, height: upper),
                CGRect(x: rightX, y: upper + gutter, width: right, height: lower),
            ]

        case .grid:
            let (left, right) = divide(size.width, at: splits[0])
            let (top, bottom) = divide(size.height, at: splits[1])
            let rightX = left + gutter
            let bottomY = top + gutter
            return [
                CGRect(x: 0, y: 0, width: left, height: top),
                CGRect(x: rightX, y: 0, width: right, height: top),
                CGRect(x: 0, y: bottomY, width: left, height: bottom),
                CGRect(x: rightX, y: bottomY, width: right, height: bottom),
            ]
        }
    }

    /// Splits `extent` at `fraction`, reserving the gutter between the two parts.
    ///
    /// The gutter comes out of the total before dividing, so two panes plus the
    /// gutter always sum back to the original extent — otherwise the grid creeps
    /// past the window edge as splits are dragged.
    private static func divide(_ extent: CGFloat, at fraction: CGFloat) -> (CGFloat, CGFloat) {
        let usable = Swift.max(0, extent - gutter)
        let first = (usable * fraction).rounded()
        return (first, usable - first)
    }
}
