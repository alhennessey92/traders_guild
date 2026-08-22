//
//  ChartPaneArrangement.swift
//  Traders Guild for macOS
//
//  Which panes exist, which one has focus, and what happens to both when the
//  layout changes.
//
//  Focus is load-bearing rather than cosmetic: the top bar, the bottom inspector
//  and the sidebars all read from the focused pane, and "Place Marker" is
//  addressed to it. Getting focus wrong means a marker lands on the wrong chart.
//
//  Pure model, no views, macOS-only.
//

import CoreGraphics
import Foundation

struct ChartPaneArrangement: Equatable {

    private(set) var layout: ChartPaneLayout
    /// Pane identities in render order. Count always matches `layout.paneCount`.
    private(set) var paneIDs: [UUID]
    private(set) var focusedPaneID: UUID
    private(set) var splits: ChartPaneSplits

    init(layout: ChartPaneLayout = .single, makeID: () -> UUID = UUID.init) {
        self.layout = layout
        self.paneIDs = (0..<layout.paneCount).map { _ in makeID() }
        self.focusedPaneID = paneIDs[0]
        self.splits = ChartPaneSplits(layout: layout)
    }

    var focusedIndex: Int {
        paneIDs.firstIndex(of: focusedPaneID) ?? 0
    }

    // MARK: - Layout

    /// Switches layout, keeping as many existing panes as the new one holds.
    ///
    /// **The pane you are looking at always survives.** Going from a 2x2 to a
    /// single pane keeps the focused chart, not pane zero — dropping the chart
    /// someone is actively working in, because it happened to be in the
    /// bottom-right, would be indefensible.
    mutating func setLayout(_ newLayout: ChartPaneLayout, makeID: () -> UUID = UUID.init) {
        guard newLayout != layout else { return }
        let target = newLayout.paneCount

        if target < paneIDs.count {
            // Focused pane first, then the rest in their existing order.
            var kept = [focusedPaneID]
            for id in paneIDs where id != focusedPaneID && kept.count < target {
                kept.append(id)
            }
            paneIDs = kept
        } else {
            paneIDs.append(contentsOf: (paneIDs.count..<target).map { _ in makeID() })
        }

        layout = newLayout
        splits = ChartPaneSplits(layout: newLayout)
        if !paneIDs.contains(focusedPaneID) {
            focusedPaneID = paneIDs[0]
        }
    }

    /// Panes that were removed by the last layout change, so their view models,
    /// WebSocket subscriptions and marker managers can be torn down.
    static func removedPanes(from before: [UUID], to after: [UUID]) -> [UUID] {
        let surviving = Set(after)
        return before.filter { !surviving.contains($0) }
    }

    // MARK: - Focus

    mutating func focus(_ id: UUID) {
        guard paneIDs.contains(id) else { return }
        focusedPaneID = id
    }

    /// Wraps, so ⌘] cycles rather than dead-ending on the last pane.
    mutating func focusNext() {
        guard paneIDs.count > 1 else { return }
        focusedPaneID = paneIDs[(focusedIndex + 1) % paneIDs.count]
    }

    mutating func focusPrevious() {
        guard paneIDs.count > 1 else { return }
        focusedPaneID = paneIDs[(focusedIndex - 1 + paneIDs.count) % paneIDs.count]
    }

    enum FocusDirection { case left, right, up, down }

    /// Moves focus geometrically, for arrow-key navigation.
    ///
    /// Picks the nearest pane whose centre lies in that direction, measured from
    /// the focused pane's centre. Unlike cycling this does not wrap: pressing
    /// left at the left edge should do nothing, not jump across the window.
    mutating func focusPane(_ direction: FocusDirection, in size: CGSize) {
        let frames = ChartPaneGeometry.frames(layout: layout, in: size, splits: splits)
        guard frames.count == paneIDs.count, frames.indices.contains(focusedIndex) else { return }

        let origin = frames[focusedIndex]
        let from = CGPoint(x: origin.midX, y: origin.midY)

        var best: (index: Int, distance: CGFloat)?
        for (index, frame) in frames.enumerated() where index != focusedIndex {
            let to = CGPoint(x: frame.midX, y: frame.midY)
            let dx = to.x - from.x
            let dy = to.y - from.y

            let qualifies: Bool
            switch direction {
            case .left:  qualifies = dx < 0 && abs(dx) >= abs(dy)
            case .right: qualifies = dx > 0 && abs(dx) >= abs(dy)
            case .up:    qualifies = dy < 0 && abs(dy) >= abs(dx)
            case .down:  qualifies = dy > 0 && abs(dy) >= abs(dx)
            }
            guard qualifies else { continue }

            let distance = (dx * dx + dy * dy).squareRoot()
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }

        if let best {
            focusedPaneID = paneIDs[best.index]
        }
    }

    // MARK: - Splitters

    mutating func setSplit(_ fraction: CGFloat, at index: Int) {
        splits[index] = fraction
    }
}
