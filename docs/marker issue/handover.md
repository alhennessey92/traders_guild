Marker Navigation Bug — Handoff Summary
The Issue
Tapping a marker in the markers panel is supposed to: scroll the chart to the marker's candle and open the detail sheet. Three failure modes:

Chart lands roughly near the marker but the marker icon doesn't render / detail sheet doesn't open.
Chart goes "into view mode" (detail sheet opens) but lands nowhere near the marker — typically clamped to the chart's left or right edge.
Brief "weird shaped" candles / bunched x-axis labels during the transition.
Worst when the tap requires both a symbol change AND a timeframe change, and when the user's prior candleWidthScale is at minimum (0.15) so candles are tiny and the chart spans many screen-widths.

Root Causes Identified
Multiple state machines write panOffset concurrently. handleTimeframeChange schedules resetChartToMostRecentCandles() (snap to right edge), handleCandleCountChange re-snaps when candle delta > 10, and loadChartData / loadOlderCandles / loadNavigationWindow directly mutate gestureState.panOffset.width to compensate for prepended candles. Any of these can fire during marker navigation and overwrite/clamp the marker scroll.
Back-to-back data fetches replace the candle array. setSymbol and setTimeframe each kick off their own loadChartData fetch. The marker helper finds the target index against an interim array (e.g. 1000 candles), then a later fetch replaces it (e.g. with 250 candles) — the cached pan target is now off-screen and gets clamped to the chart edge. The user's logs showed panOffset = 193.6 and -1157.0, which are exactly +edgePadding (max) and -(250*5.8 − 393 + 100) (min).
Division-by-zero during transitions. priceRange.max == priceRange.min and totalCandleWidth == 0 produce NaN in candlestick draw and time-label engine — that's the flat candles + bunched labels.
Fixes Attempted
All in traders_guild_ios/traders_guild/TradingChart/:

viewModels/ChartViewModel.swift — added @Published var isNavigatingToMarker: Bool flag.
services/MarkerNavigationHelper.swift —
Sets isNavigatingToMarker = true at start, clears 1.5s after centering completes.
Replaced fixed 0.5s asyncAfter with a poll loop that waits for the target timeframe to be active and candles to be in range (3s cap).
Added a stability wait — poll until candle count is unchanged for 400ms (4s cap) before centering, so we don't snap against an interim array.
Switched from animated animateCenterOnMarker (display link, ~0.9s, can be interrupted) to instant centerOnMarker.
Re-center loop — for 1.5s after the initial snap, watch candle count and re-snap on every change (re-lookup by timestamp, not by stale index).
Bumped selectMarkerForDetail retry budget from 6 → 25 attempts (5s total) to cover late marker fetches.
TradingChart/TradingChartView.swift —
handleTimeframeChange: skip resetChartToMostRecentCandles() when isNavigatingToMarker == true.
handleCandleCountChange: skip the >10 candle delta auto-reset when navigating.
drawCandlesticks: guard against empty data and priceRange.max <= priceRange.min.
calculateCenterCandleIndex: guard against totalCandleWidth == 0 / empty candles; fall back to latest candle, not 0.
services/ChartGestures.swift —
applyPanInternal clamping skipped when candleCount == 0 (was forcing pan to candle 0).
centerOnCandle / centerOnMarker / animateCenterOnMarker no-op on candleWidth <= 0.
What's Still Failing
User reports same symptoms persist after both rounds of fixes. The pan offset target appears to still get clobbered. Suspected remaining culprits to investigate:

Direct panOffset.width writes inside ChartViewModel that aren't gated by isNavigatingToMarker:
loadChartData:270 — gestureState.panOffset.width -= prependedCount * totalCandleWidth on merge
loadNavigationWindow:450 — same pattern
loadOlderCandles:513 — same pattern
processRealCandle:992 — gestureState.panOffset.width += trimmedCount * totalCandleWidth on WS tick when front candles trimmed
setSymbol and setTimeframe fire two separate loadChartData calls back-to-back — the second can land after the helper's stability window thinks data is settled. Worth checking if these can be coalesced or if loadChartData should be cancellable.
Marker icon not rendering when chart lands at correct area — likely a marker-glyph visibility filter. Check ChartMarkerSystem.swift for is_visible / candle-index assignment timing — the marker may be in markerManager.markers but not yet placed against the new candle array when the chart renders. markerManager.recalculateCandleIndices is called in handleCandleCountChange's prepend branch but not on full replacement.
predictionPlacement block in handleCandleCountChange still runs unconditionally — shouldn't matter for navigation but worth ruling out.
Consider moving navigation off panOffset entirely and onto a "centered candle index" model — let SwiftUI compute pan from (centeredIndex, candleWidthScale, chartWidth) reactively rather than imperatively writing pan offset and racing against everyone else.
Plan File
Full original analysis: /Users/alhennessey/.claude/plans/ok-also-noticed-a-encapsulated-quilt.md