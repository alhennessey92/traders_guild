//
//  ChartWorkspace.swift
//  Traders Guild for macOS
//
//  Named pane layouts, saved per guild — "BTC scalp", "Majors overview" — and
//  restored on launch.
//
//  Persisted data outlives the code that wrote it, so this leans on decoding
//  defensively rather than trusting what comes back: a workspace saved by a newer
//  build, or one whose pane count no longer matches its layout, must degrade to
//  something usable instead of throwing on launch. Losing someone's saved layouts
//  because a field changed shape would be a poor trade for strictness.
//
//  Pure model, no views, macOS-only.
//

import CoreGraphics
import Foundation

/// One pane's restorable state. Symbols are referenced by id, with the ticker
/// kept alongside purely so a workspace can still be *listed* meaningfully if the
/// symbol has since been delisted.
struct ChartPaneSnapshot: Codable, Equatable, Sendable {
    var symbolID: UUID?
    var symbolTicker: String?
    var timeframe: String
    var linkGroup: ChartPaneLinkGroup
    var indicatorIDs: [String]

    init(
        symbolID: UUID? = nil,
        symbolTicker: String? = nil,
        timeframe: String = "5m",
        linkGroup: ChartPaneLinkGroup = .none,
        indicatorIDs: [String] = []
    ) {
        self.symbolID = symbolID
        self.symbolTicker = symbolTicker
        self.timeframe = timeframe
        self.linkGroup = linkGroup
        self.indicatorIDs = indicatorIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbolID = try c.decodeIfPresent(UUID.self, forKey: .symbolID)
        symbolTicker = try c.decodeIfPresent(String.self, forKey: .symbolTicker)
        timeframe = try c.decodeIfPresent(String.self, forKey: .timeframe) ?? "5m"
        indicatorIDs = try c.decodeIfPresent([String].self, forKey: .indicatorIDs) ?? []
        // A group added by a newer build decodes to unlinked rather than throwing
        // and taking the whole workspace with it.
        let raw = try c.decodeIfPresent(String.self, forKey: .linkGroup) ?? ""
        linkGroup = ChartPaneLinkGroup(rawValue: raw) ?? .none
    }
}

struct ChartWorkspace: Codable, Equatable, Identifiable, Sendable {

    /// Bumped only for changes older builds cannot read. Anything with a higher
    /// version is skipped on load rather than guessed at.
    static let currentSchemaVersion = 1

    var id: UUID
    var name: String
    var guildID: UUID
    var layout: ChartPaneLayout
    var splitFractions: [CGFloat]
    var panes: [ChartPaneSnapshot]
    /// Link group rawValue -> aspects rawValue.
    var linkAspects: [String: Int]
    var savedAt: Date
    var schemaVersion: Int

    init(
        id: UUID = UUID(),
        name: String,
        guildID: UUID,
        layout: ChartPaneLayout,
        splitFractions: [CGFloat] = [],
        panes: [ChartPaneSnapshot] = [],
        linkAspects: [String: Int] = [:],
        savedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.guildID = guildID
        self.layout = layout
        self.splitFractions = splitFractions
        self.panes = panes
        self.linkAspects = linkAspects
        self.savedAt = savedAt
        self.schemaVersion = Self.currentSchemaVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        guildID = try c.decode(UUID.self, forKey: .guildID)
        let rawLayout = try c.decodeIfPresent(String.self, forKey: .layout) ?? ""
        layout = ChartPaneLayout(rawValue: rawLayout) ?? .single
        splitFractions = try c.decodeIfPresent([CGFloat].self, forKey: .splitFractions) ?? []
        panes = try c.decodeIfPresent([ChartPaneSnapshot].self, forKey: .panes) ?? []
        linkAspects = try c.decodeIfPresent([String: Int].self, forKey: .linkAspects) ?? [:]
        savedAt = try c.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }

    /// Brings a decoded workspace into a self-consistent state.
    ///
    /// Pane count and split count must match the layout. They can disagree if a
    /// layout's shape changed between builds, and a mismatch would otherwise
    /// surface as an index crash while rendering the grid.
    func repaired() -> ChartWorkspace {
        var copy = self

        if copy.panes.count > layout.paneCount {
            copy.panes = Array(copy.panes.prefix(layout.paneCount))
        } else if copy.panes.count < layout.paneCount {
            copy.panes.append(
                contentsOf: (copy.panes.count..<layout.paneCount).map { _ in ChartPaneSnapshot() }
            )
        }

        if copy.splitFractions.count != layout.splitCount {
            copy.splitFractions = Array(repeating: 0.5, count: layout.splitCount)
        }
        copy.splitFractions = copy.splitFractions.map { ChartPaneSplits.clamp($0) }

        if copy.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.name = "Untitled"
        }
        return copy
    }

    var splits: ChartPaneSplits { ChartPaneSplits(fractions: splitFractions) }
}

// MARK: - Storage

/// Somewhere to keep the encoded blob. Injectable so the model is testable
/// without touching UserDefaults or the disk.
protocol ChartWorkspaceStorage: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

final class ChartWorkspaceStore {

    private let storage: ChartWorkspaceStorage
    private let key = "macos.chartWorkspaces.v1"

    init(storage: ChartWorkspaceStorage) {
        self.storage = storage
    }

    /// Workspaces for a guild, newest first.
    ///
    /// Anything written by a newer build is skipped rather than guessed at, and a
    /// corrupt blob yields an empty list rather than a launch failure.
    func workspaces(forGuild guildID: UUID) -> [ChartWorkspace] {
        all()
            .filter { $0.guildID == guildID }
            .sorted { $0.savedAt > $1.savedAt }
    }

    func save(_ workspace: ChartWorkspace) {
        var stored = all().filter { $0.id != workspace.id }
        stored.append(workspace)
        write(stored)
    }

    func delete(id: UUID) {
        write(all().filter { $0.id != id })
    }

    func mostRecent(forGuild guildID: UUID) -> ChartWorkspace? {
        workspaces(forGuild: guildID).first
    }

    /// A name not already taken in this guild — "BTC scalp", then "BTC scalp 2".
    func availableName(_ desired: String, inGuild guildID: UUID) -> String {
        let trimmed = desired.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Untitled" : trimmed
        let taken = Set(workspaces(forGuild: guildID).map(\.name))
        guard taken.contains(base) else { return base }
        var suffix = 2
        while taken.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    private func all() -> [ChartWorkspace] {
        guard let data = storage.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ChartWorkspace].self, from: data) else {
            return []
        }
        return decoded
            .filter { $0.schemaVersion <= ChartWorkspace.currentSchemaVersion }
            .map { $0.repaired() }
    }

    private func write(_ workspaces: [ChartWorkspace]) {
        storage.set(try? JSONEncoder().encode(workspaces), forKey: key)
    }
}
