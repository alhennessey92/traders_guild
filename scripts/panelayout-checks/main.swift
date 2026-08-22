import CoreGraphics
import Foundation

var failures = 0
var checksRun = 0
func check(_ cond: Bool, _ what: String) {
    checksRun += 1
    if !cond { failures += 1; print("  FAIL: \(what)") }
}
func approx(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat = 0.51) -> Bool { abs(a - b) <= t }

let size = CGSize(width: 1000, height: 600)
let G = ChartPaneGeometry.gutter

// Every layout yields exactly paneCount frames.
for layout in ChartPaneLayout.allCases {
    let f = ChartPaneGeometry.frames(layout: layout, in: size, splits: ChartPaneSplits(layout: layout))
    check(f.count == layout.paneCount, "\(layout) yields \(f.count) frames, expected \(layout.paneCount)")
    check(f.allSatisfy { $0.width > 0 && $0.height > 0 }, "\(layout) produced a non-positive frame")
    check(f.allSatisfy { $0.maxX <= size.width + 0.51 && $0.maxY <= size.height + 0.51 },
          "\(layout) overflows the container")
}

// Panes plus gutter reconstruct the container exactly — the creep bug.
do {
    let f = ChartPaneGeometry.frames(layout: .twoUpHorizontal, in: size, splits: ChartPaneSplits(layout: .twoUpHorizontal))
    check(approx(f[0].width + G + f[1].width, size.width), "two-up widths + gutter != container width")
    let v = ChartPaneGeometry.frames(layout: .twoUpVertical, in: size, splits: ChartPaneSplits(layout: .twoUpVertical))
    check(approx(v[0].height + G + v[1].height, size.height), "two-down heights + gutter != container height")
}

// Grid: columns and rows line up across panes.
do {
    let f = ChartPaneGeometry.frames(layout: .grid, in: size, splits: ChartPaneSplits(layout: .grid))
    check(f[0].width == f[2].width && f[1].width == f[3].width, "grid columns misaligned")
    check(f[0].height == f[1].height && f[2].height == f[3].height, "grid rows misaligned")
    check(f[0].maxX + G == f[1].minX, "grid gutter wrong between columns")
    check(f[0].maxY + G == f[2].minY, "grid gutter wrong between rows")
    check(approx(f[0].width + G + f[1].width, size.width), "grid widths + gutter != container width")
}

// threeUp: the right column's two panes stack inside the right half.
do {
    let f = ChartPaneGeometry.frames(layout: .threeUp, in: size, splits: ChartPaneSplits(layout: .threeUp))
    check(f[1].minX == f[2].minX && f[1].width == f[2].width, "threeUp right column not aligned")
    check(approx(f[0].height, size.height), "threeUp left pane should be full height")
    check(approx(f[1].height + G + f[2].height, size.height), "threeUp right column heights wrong")
}

// Dragging a splitter moves the boundary and still fills the container.
do {
    var splits = ChartPaneSplits(layout: .twoUpHorizontal)
    splits[0] = 0.8
    let f = ChartPaneGeometry.frames(layout: .twoUpHorizontal, in: size, splits: splits)
    check(f[0].width > f[1].width, "dragging right should widen the left pane")
    check(approx(f[0].width + G + f[1].width, size.width), "dragged widths + gutter != container width")
}

// A pane can never be dragged away to nothing.
do {
    var splits = ChartPaneSplits(layout: .grid)
    splits[0] = 0.001
    splits[1] = 0.999
    check(splits[0] >= ChartPaneSplits.minimumFraction, "split under-clamped")
    check(splits[1] <= 1 - ChartPaneSplits.minimumFraction, "split over-clamped")
    let f = ChartPaneGeometry.frames(layout: .grid, in: size, splits: splits)
    check(f.allSatisfy { $0.width > 0 && $0.height > 0 }, "extreme splits produced an empty pane")
}

// A window mid-resize can report zero; that must not yield negative frames.
for layout in ChartPaneLayout.allCases {
    check(ChartPaneGeometry.frames(layout: layout, in: .zero, splits: ChartPaneSplits(layout: layout)).isEmpty,
          "\(layout) should yield no frames for a zero size")
}

// Very small containers still produce valid, non-overlapping frames.
do {
    let tiny = CGSize(width: 40, height: 30)
    let f = ChartPaneGeometry.frames(layout: .grid, in: tiny, splits: ChartPaneSplits(layout: .grid))
    check(f.count == 4, "tiny grid lost panes")
    check(f.allSatisfy { $0.width >= 0 && $0.height >= 0 }, "tiny grid produced a negative frame")
}

// Shortcuts are unique, so ⌘1…⌘5 cannot collide.
check(Set(ChartPaneLayout.allCases.map(\.keyboardShortcut)).count == ChartPaneLayout.allCases.count,
      "duplicate keyboard shortcuts")


// ===========================================================================
// Focus, layout transitions and link groups
// ===========================================================================

func ids(_ n: Int) -> [UUID] { (0..<n).map { _ in UUID() } }

// Pane count always matches the layout.
for layout in ChartPaneLayout.allCases {
    let a = ChartPaneArrangement(layout: layout)
    check(a.paneIDs.count == layout.paneCount, "\(layout) arrangement has wrong pane count")
    check(a.paneIDs.contains(a.focusedPaneID), "\(layout) focus is not one of its panes")
    check(Set(a.paneIDs).count == a.paneIDs.count, "\(layout) has duplicate pane ids")
}

// THE rule: shrinking the layout keeps the pane you are looking at.
do {
    var a = ChartPaneArrangement(layout: .grid)
    let bottomRight = a.paneIDs[3]
    a.focus(bottomRight)
    a.setLayout(.single)
    check(a.paneIDs == [bottomRight], "shrinking dropped the focused pane")
    check(a.focusedPaneID == bottomRight, "focus moved away from the surviving pane")
}

// Shrinking to two keeps the focused pane plus one other, in order.
do {
    var a = ChartPaneArrangement(layout: .grid)
    let original = a.paneIDs
    a.focus(original[2])
    a.setLayout(.twoUpHorizontal)
    check(a.paneIDs.count == 2, "twoUp should hold two panes")
    check(a.paneIDs[0] == original[2], "focused pane should come first after shrinking")
    check(a.paneIDs[1] == original[0], "remaining pane should keep its relative order")
    check(ChartPaneArrangement.removedPanes(from: original, to: a.paneIDs).count == 2,
          "two panes should have been reported as removed")
}

// Growing preserves existing panes and appends new ones.
do {
    var a = ChartPaneArrangement(layout: .single)
    let first = a.paneIDs[0]
    a.setLayout(.grid)
    check(a.paneIDs.count == 4, "grid should hold four panes")
    check(a.paneIDs[0] == first, "growing should preserve the existing pane")
    check(a.focusedPaneID == first, "growing should not move focus")
    check(ChartPaneArrangement.removedPanes(from: [first], to: a.paneIDs).isEmpty,
          "growing should remove nothing")
}

// Cycling wraps in both directions.
do {
    var a = ChartPaneArrangement(layout: .grid)
    let p = a.paneIDs
    check(a.focusedPaneID == p[0], "focus should start on the first pane")
    a.focusPrevious()
    check(a.focusedPaneID == p[3], "focusPrevious from the first pane should wrap to the last")
    a.focusNext()
    check(a.focusedPaneID == p[0], "focusNext from the last pane should wrap to the first")
}

// Cycling a single pane is a no-op rather than a crash.
do {
    var a = ChartPaneArrangement(layout: .single)
    let only = a.paneIDs[0]
    a.focusNext(); a.focusPrevious()
    check(a.focusedPaneID == only, "cycling one pane should stay put")
}

// Focusing an unknown pane is ignored.
do {
    var a = ChartPaneArrangement(layout: .twoUpHorizontal)
    let before = a.focusedPaneID
    a.focus(UUID())
    check(a.focusedPaneID == before, "focusing an unknown pane should be ignored")
}

// Arrow navigation follows the geometry, and does not wrap at the edges.
do {
    var a = ChartPaneArrangement(layout: .grid)
    let p = a.paneIDs                       // 0 1 / 2 3
    let size = CGSize(width: 1000, height: 600)
    check(a.focusedPaneID == p[0], "precondition")
    a.focusPane(.right, in: size);  check(a.focusedPaneID == p[1], "right from top-left should reach top-right")
    a.focusPane(.down, in: size);   check(a.focusedPaneID == p[3], "down from top-right should reach bottom-right")
    a.focusPane(.left, in: size);   check(a.focusedPaneID == p[2], "left from bottom-right should reach bottom-left")
    a.focusPane(.up, in: size);     check(a.focusedPaneID == p[0], "up from bottom-left should reach top-left")
    a.focusPane(.left, in: size);   check(a.focusedPaneID == p[0], "left at the left edge should do nothing")
    a.focusPane(.up, in: size);     check(a.focusedPaneID == p[0], "up at the top edge should do nothing")
}

// Link groups: only same-group panes follow, and never the originator.
do {
    var linking = ChartPaneLinking()
    let panes = ids(4)
    linking.assign(.blue, to: panes[0])
    linking.assign(.blue, to: panes[1])
    linking.assign(.red,  to: panes[2])
    // panes[3] stays unlinked

    check(linking.group(for: panes[0]) == .blue, "group not recorded")
    check(linking.group(for: panes[3]) == .none, "unassigned pane should be unlinked")

    let followers = linking.panesFollowing(.symbol, changedBy: panes[0], among: panes)
    check(followers == [panes[1]], "only the other blue pane should follow a symbol change")
    check(!followers.contains(panes[0]), "the originating pane must never follow itself")

    check(linking.panesFollowing(.symbol, changedBy: panes[3], among: panes).isEmpty,
          "an unlinked pane should propagate nothing")
    check(linking.panesFollowing(.symbol, changedBy: panes[2], among: panes).isEmpty,
          "a lone member of a group has nobody to propagate to")
}

// Aspects are independent: one symbol across four timeframes is the point.
do {
    var linking = ChartPaneLinking()
    let panes = ids(2)
    linking.assign(.green, to: panes[0])
    linking.assign(.green, to: panes[1])

    check(linking.aspects(for: .green).contains(.symbol), "symbol should be linked by default")
    check(!linking.aspects(for: .green).contains(.timeframe),
          "timeframe should NOT be linked by default — the default layout is one symbol, many timeframes")

    check(linking.panesFollowing(.timeframe, changedBy: panes[0], among: panes).isEmpty,
          "timeframe must not propagate while unlinked")
    linking.setAspects(.all, for: .green)
    check(linking.panesFollowing(.timeframe, changedBy: panes[0], among: panes) == [panes[1]],
          "timeframe should propagate once linked")
}

// Removed panes are forgotten, so a group cannot keep ghosts.
do {
    var linking = ChartPaneLinking()
    let panes = ids(3)
    for p in panes { linking.assign(.purple, to: p) }
    linking.forget(panes: [panes[1], panes[2]])
    check(linking.group(for: panes[1]) == .none, "removed pane should be forgotten")
    check(linking.panes(in: .purple, among: panes) == [panes[0]], "group should hold only surviving panes")
}

// `.none` is not assignable and never links anything.
do {
    var linking = ChartPaneLinking()
    let panes = ids(2)
    linking.assign(.none, to: panes[0])
    linking.assign(.none, to: panes[1])
    check(linking.panesFollowing(.symbol, changedBy: panes[0], among: panes).isEmpty,
          "unlinked panes must not follow each other")
    check(!ChartPaneLinkGroup.assignable.contains(.none), ".none should not be user-assignable")
    check(linking.aspects(for: .none).isEmpty, ".none should link no aspects")
}


// ===========================================================================
// Menu commands
// ===========================================================================

// No two commands may claim the same chord.
check(MacCommandCatalog.conflictingShortcuts.isEmpty,
      "duplicate shortcuts: \(MacCommandCatalog.conflictingShortcuts.map { "\($0.modifiers.rawValue)+\($0.key)" })")

// No command may fight a chord macOS has already reserved.
check(MacCommandCatalog.systemConflicts.isEmpty,
      "commands claiming system shortcuts: \(MacCommandCatalog.systemConflicts.map(\.title))")

// Command ids are unique — they key the dispatch table.
check(Set(MacCommandCatalog.all.map(\.id)).count == MacCommandCatalog.all.count, "duplicate command ids")

// Place Marker must NOT be plain Cmd-M; that is Minimize.
do {
    let place = MacCommandCatalog.all.first { $0.id == "marker.place" }
    check(place != nil, "Place Marker command missing")
    check(place?.shortcut != MacShortcut("m"), "Place Marker must not claim Cmd-M (Minimize)")
    check(place?.shortcut?.isSystemReserved == false, "Place Marker shortcut is system reserved")
}

// Every layout has a command, and the digits match the layout's own shortcut.
for layout in ChartPaneLayout.allCases {
    let cmd = MacCommandCatalog.all.first { $0.id == "view.layout.\(layout.rawValue)" }
    check(cmd != nil, "no command for layout \(layout)")
    check(cmd?.shortcut == MacShortcut(String(layout.keyboardShortcut)),
          "layout \(layout) command shortcut does not match the layout")
}

// Enablement.
do {
    let next = MacCommandCatalog.all.first { $0.id == "chart.focusNextPane" }!
    check(!next.isEnabled(signedIn: true, paneCount: 1, isPlacingMarker: false),
          "Next Pane should be disabled with one pane")
    check(next.isEnabled(signedIn: true, paneCount: 4, isPlacingMarker: false),
          "Next Pane should be enabled with four panes")
    check(!next.isEnabled(signedIn: false, paneCount: 4, isPlacingMarker: false),
          "nothing should be enabled while signed out")

    let cancel = MacCommandCatalog.all.first { $0.id == "marker.cancelPlacement" }!
    check(cancel.isEnabled(signedIn: true, paneCount: 1, isPlacingMarker: true),
          "Cancel should be enabled while placing")
    check(!cancel.isEnabled(signedIn: true, paneCount: 1, isPlacingMarker: false),
          "Cancel should be disabled when not placing")

    let place = MacCommandCatalog.all.first { $0.id == "marker.place" }!
    check(!place.isEnabled(signedIn: true, paneCount: 1, isPlacingMarker: true),
          "Place should be disabled while already placing")
}

// Every section has at least one command, so no empty menu is rendered.
for section in MacCommandSection.allCases where section != .window {
    check(!MacCommandCatalog.commands(in: section).isEmpty, "section \(section) has no commands")
}

// ===========================================================================
// Workspace persistence
// ===========================================================================

final class MemoryStorage: ChartWorkspaceStorage {
    var store: [String: Data] = [:]
    func data(forKey key: String) -> Data? { store[key] }
    func set(_ data: Data?, forKey key: String) { store[key] = data }
}

let guildA = UUID(), guildB = UUID()

func makeWorkspace(_ name: String, guild: UUID, layout: ChartPaneLayout = .grid) -> ChartWorkspace {
    ChartWorkspace(
        name: name, guildID: guild, layout: layout,
        splitFractions: Array(repeating: 0.5, count: layout.splitCount),
        panes: (0..<layout.paneCount).map { i in
            ChartPaneSnapshot(symbolID: UUID(), symbolTicker: "SYM\(i)", timeframe: "15m",
                              linkGroup: .blue, indicatorIDs: ["rsi"])
        },
        linkAspects: [ChartPaneLinkGroup.blue.rawValue: ChartPaneLinkAspects.all.rawValue]
    )
}

// Round-trip.
do {
    let storage = MemoryStorage()
    let store = ChartWorkspaceStore(storage: storage)
    let ws = makeWorkspace("BTC scalp", guild: guildA)
    store.save(ws)
    let loaded = store.workspaces(forGuild: guildA)
    check(loaded.count == 1, "expected one workspace, got \(loaded.count)")
    check(loaded.first?.name == "BTC scalp", "name did not round-trip")
    check(loaded.first?.layout == .grid, "layout did not round-trip")
    check(loaded.first?.panes.count == 4, "panes did not round-trip")
    check(loaded.first?.panes.first?.linkGroup == .blue, "link group did not round-trip")
    check(loaded.first?.panes.first?.indicatorIDs == ["rsi"], "indicators did not round-trip")
}

// Guild scoping.
do {
    let store = ChartWorkspaceStore(storage: MemoryStorage())
    store.save(makeWorkspace("A one", guild: guildA))
    store.save(makeWorkspace("B one", guild: guildB))
    check(store.workspaces(forGuild: guildA).map(\.name) == ["A one"], "guild A leaked B's workspaces")
    check(store.workspaces(forGuild: guildB).map(\.name) == ["B one"], "guild B leaked A's workspaces")
}

// Saving the same id updates rather than duplicating.
do {
    let store = ChartWorkspaceStore(storage: MemoryStorage())
    var ws = makeWorkspace("Majors", guild: guildA)
    store.save(ws)
    ws.name = "Majors renamed"
    store.save(ws)
    let all = store.workspaces(forGuild: guildA)
    check(all.count == 1, "re-saving duplicated the workspace")
    check(all.first?.name == "Majors renamed", "re-saving did not update the name")
}

// Delete, and most-recent ordering.
do {
    let store = ChartWorkspaceStore(storage: MemoryStorage())
    var older = makeWorkspace("Older", guild: guildA); older.savedAt = Date(timeIntervalSince1970: 1000)
    var newer = makeWorkspace("Newer", guild: guildA); newer.savedAt = Date(timeIntervalSince1970: 2000)
    store.save(older); store.save(newer)
    check(store.mostRecent(forGuild: guildA)?.name == "Newer", "most recent should be the newest")
    store.delete(id: newer.id)
    check(store.workspaces(forGuild: guildA).map(\.name) == ["Older"], "delete did not remove the workspace")
}

// Name collisions get a suffix rather than silently overwriting.
do {
    let store = ChartWorkspaceStore(storage: MemoryStorage())
    store.save(makeWorkspace("BTC scalp", guild: guildA))
    check(store.availableName("BTC scalp", inGuild: guildA) == "BTC scalp 2", "first collision should suffix 2")
    store.save(makeWorkspace("BTC scalp 2", guild: guildA))
    check(store.availableName("BTC scalp", inGuild: guildA) == "BTC scalp 3", "second collision should suffix 3")
    check(store.availableName("Fresh", inGuild: guildA) == "Fresh", "a free name should be untouched")
    check(store.availableName("   ", inGuild: guildA) == "Untitled", "a blank name should fall back")
}

// A pane count that disagrees with the layout is repaired, not crashed on.
do {
    var ws = makeWorkspace("Broken", guild: guildA, layout: .grid)
    ws.panes = [ChartPaneSnapshot()]            // 1 pane for a 4-pane layout
    ws.splitFractions = []                       // and no splits
    let fixed = ws.repaired()
    check(fixed.panes.count == 4, "repair should pad panes to the layout")
    check(fixed.splitFractions.count == ChartPaneLayout.grid.splitCount, "repair should restore splits")

    var tooMany = makeWorkspace("Too many", guild: guildA, layout: .single)
    tooMany.panes = (0..<4).map { _ in ChartPaneSnapshot() }
    check(tooMany.repaired().panes.count == 1, "repair should trim panes to the layout")
}

// Out-of-range split fractions are clamped on load.
do {
    var ws = makeWorkspace("Extreme", guild: guildA, layout: .grid)
    ws.splitFractions = [0.0001, 0.9999]
    let fixed = ws.repaired()
    check(fixed.splitFractions.allSatisfy { $0 >= ChartPaneSplits.minimumFraction }, "splits under-clamped")
    check(fixed.splitFractions.allSatisfy { $0 <= 1 - ChartPaneSplits.minimumFraction }, "splits over-clamped")
}

// A workspace from a newer build is skipped, not guessed at.
do {
    let storage = MemoryStorage()
    let store = ChartWorkspaceStore(storage: storage)
    var future = makeWorkspace("From the future", guild: guildA)
    future.schemaVersion = ChartWorkspace.currentSchemaVersion + 1
    storage.set(try? JSONEncoder().encode([future]), forKey: "macos.chartWorkspaces.v1")
    check(store.workspaces(forGuild: guildA).isEmpty, "a newer schema version should be skipped")
}

// A corrupt blob yields nothing rather than throwing on launch.
do {
    let storage = MemoryStorage()
    storage.set(Data("not json".utf8), forKey: "macos.chartWorkspaces.v1")
    check(ChartWorkspaceStore(storage: storage).workspaces(forGuild: guildA).isEmpty,
          "corrupt storage should decode to no workspaces")
}

// An unknown link group from a newer build decodes to unlinked.
do {
    let json = Data("""
    [{"id":"\(UUID().uuidString)","name":"X","guildID":"\(guildA.uuidString)","layout":"single",
      "splitFractions":[],"panes":[{"timeframe":"1h","linkGroup":"chartreuse","indicatorIDs":[]}],
      "linkAspects":{},"savedAt":0,"schemaVersion":1}]
    """.utf8)
    let storage = MemoryStorage()
    storage.set(json, forKey: "macos.chartWorkspaces.v1")
    let loaded = ChartWorkspaceStore(storage: storage).workspaces(forGuild: guildA)
    check(loaded.count == 1, "an unknown link group should not lose the workspace")
    check(loaded.first?.panes.first?.linkGroup == ChartPaneLinkGroup.none,
          "an unknown link group should decode to unlinked")
}

print(failures == 0 ? "ALL \(checksRun) MACOS MODEL CHECKS PASSED" : "\(failures) of \(checksRun) FAILED")
exit(failures == 0 ? 0 : 1)
