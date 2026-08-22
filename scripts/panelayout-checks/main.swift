import CoreGraphics
import Foundation

var failures = 0
func check(_ cond: Bool, _ what: String) {
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

print(failures == 0 ? "ALL PANE LAYOUT TESTS PASSED" : "\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
