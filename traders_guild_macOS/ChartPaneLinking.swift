//
//  ChartPaneLinking.swift
//  Traders Guild for macOS
//
//  Link groups: the colour-coded badges that make several panes move together,
//  as Bloomberg terminals and TradingView layouts do.
//
//  The arrangement that makes the Mac app worth opening is one symbol on four
//  timeframes. That wants symbol linked and timeframe *not* — so the aspects are
//  independent per group rather than a single on/off.
//
//  Pure model, no views, macOS-only.
//

import Foundation

/// A pane belongs to at most one group. `.none` means it moves alone.
enum ChartPaneLinkGroup: String, CaseIterable, Codable, Identifiable, Sendable {
    case none, red, orange, green, blue, purple

    var id: String { rawValue }

    var title: String {
        self == .none ? "Unlinked" : rawValue.capitalized
    }

    /// Groups a user can actually pick, i.e. everything but `.none`.
    static var assignable: [ChartPaneLinkGroup] {
        allCases.filter { $0 != .none }
    }
}

/// What a group keeps in step.
struct ChartPaneLinkAspects: OptionSet, Codable, Sendable {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let symbol    = ChartPaneLinkAspects(rawValue: 1 << 0)
    static let timeframe = ChartPaneLinkAspects(rawValue: 1 << 1)
    static let crosshair = ChartPaneLinkAspects(rawValue: 1 << 2)

    /// One symbol across several timeframes — the default because it is the
    /// layout the grid exists for.
    static let `default`: ChartPaneLinkAspects = [.symbol, .crosshair]
    static let all: ChartPaneLinkAspects = [.symbol, .timeframe, .crosshair]
}

struct ChartPaneLinking: Equatable {

    private var groupsByPane: [UUID: ChartPaneLinkGroup] = [:]
    private var aspectsByGroup: [ChartPaneLinkGroup: ChartPaneLinkAspects] = [:]

    init() {}

    // MARK: - Membership

    func group(for pane: UUID) -> ChartPaneLinkGroup {
        groupsByPane[pane] ?? .none
    }

    mutating func assign(_ group: ChartPaneLinkGroup, to pane: UUID) {
        if group == .none {
            groupsByPane.removeValue(forKey: pane)
        } else {
            groupsByPane[pane] = group
        }
    }

    /// Called when a layout change removes panes, so a group does not keep
    /// members that no longer exist.
    mutating func forget(panes: [UUID]) {
        for pane in panes { groupsByPane.removeValue(forKey: pane) }
    }

    func panes(in group: ChartPaneLinkGroup, among panes: [UUID]) -> [UUID] {
        guard group != .none else { return [] }
        return panes.filter { groupsByPane[$0] == group }
    }

    // MARK: - Aspects

    func aspects(for group: ChartPaneLinkGroup) -> ChartPaneLinkAspects {
        guard group != .none else { return [] }
        return aspectsByGroup[group] ?? .default
    }

    mutating func setAspects(_ aspects: ChartPaneLinkAspects, for group: ChartPaneLinkGroup) {
        guard group != .none else { return }
        aspectsByGroup[group] = aspects
    }

    // MARK: - Propagation

    /// Panes that should follow `origin` when `aspect` changes there.
    ///
    /// Never includes `origin` itself — the caller has already applied the change
    /// to it, and echoing it back is how feedback loops start.
    func panesFollowing(
        _ aspect: ChartPaneLinkAspects,
        changedBy origin: UUID,
        among panes: [UUID]
    ) -> [UUID] {
        let group = group(for: origin)
        guard group != .none, aspects(for: group).contains(aspect) else { return [] }
        return panes.filter { $0 != origin && groupsByPane[$0] == group }
    }
}
