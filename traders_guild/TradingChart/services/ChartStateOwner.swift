import Foundation

/// Owns chart objects whose lifetime must match the root view's, *without* the root view observing
/// them.
///
/// `@StateObject` does two jobs at once: it pins an object's lifetime to the view, and it subscribes
/// the view to that object's changes. For `ChartGestureState` only the first is wanted. Its
/// `panOffset` publishes on every frame of a drag, so holding it as `@StateObject` on `MainView`
/// meant a chart pan re-evaluated the entire app shell — drawers, toolbars, panels and the chart —
/// roughly 37 times a second, and rebuilt `TradingChartView` each time on top of its own
/// subscription. Measured: ~37 MainView body passes and ~75 chart body passes per second while
/// panning, against 0.13 ms of actual candle drawing per frame.
///
/// This holder is an `ObservableObject` that never publishes anything: `@StateObject` on it gives
/// the lifetime guarantee while `objectWillChange` stays permanently silent, so the root view is
/// never invalidated by chart gestures. Views that genuinely need the live values — the chart
/// itself, the indicator panels, the timeframe panels — take `gestureState` as `@ObservedObject`
/// and pay for it only within their own subtree.
///
/// This restores what `ChartGestures.swift` has documented since it was written: the gesture state
/// belongs to the chart, not to the shell above it.
///
/// Add further chart-scoped objects here only if they have the same shape: root-owned lifetime,
/// high-frequency updates, and no root-level readers.
final class ChartStateOwner: ObservableObject {
    let gestureState = ChartGestureState()
}
