# Marker Redesign Baseline (Todo 38 Audit)

**Date:** 2025-03-02  
**Purpose:** Document marker render and guide-line composition. Superseded by redesign implementation.

## Chart Marker Render Pipeline (`ChartMarkerSystem.drawMarkers`)

1. **Grouping:** Markers grouped by `candleIndex`, sorted by candle.
2. **Positions:** `MarkerPositionCalculator.computeMarkerScreenPosition` per marker.
3. **Connection lines:** `drawStackedConnectionLines` — dashed gray lines from candle to marker edge.
4. **Username labels:** `visibleUsernameMarkerIDs` filters collision; `drawUsernameLabel` for each visible.
5. **Glyphs:** Sorted (selected first, then by sortKey); `drawSingleMarker` for each.

## `drawSingleMarker` Layer Order (bottom to top)

1. Selection glow (ellipse, `marker.displayColor.opacity(0.3)`) — selected only
2. Shadow (ellipse, black 0.35, offset +1.5)
3. Circle fill: tint (`displayColor` 0.12) + dark material (25,25,33 @ 0.4)
4. Inner stroke (innerRadius 0.82×, `displayColor` 0.15 or blue 0.35 for prediction)
5. Outer border: selected = `displayColor` 0.6 / 2pt; unselected = white 0.25 / 1pt
6. Icon: emoji (Text) or SF Symbol (`marker.displayColor` tint)
7. Like badge (if `likeCount > 0`)

**Current scale:** selected = 1.3×, unselected = 1.0×  
**baseRadius:** 16

## Username Label Path

- `usernameLabelCandidate` builds rect per marker (above/below based on `positionedBelow`).
- `visibleUsernameMarkerIDs` suppresses overlapping labels via rect intersection.
- `drawUsernameLabel` draws `marker.author.username` at labelY, 8pt medium, `MarkerLabelStyling.usernameColor`.

## Guide Line Composition (`TradingChartView`)

- `markerGuideOverlay` draws a dashed vertical Path when `markerPlacementGuide.isActive`.
- Stroke: `lineWidth: 2`, `dash: [5, 5]`, `.blue.opacity(0.6)`.
- **Z-order:** `mainChartCanvas` (contains markers in Canvas) → `markerGuideOverlay` at zIndex(8).
- Markers are drawn inside `mainChartCanvas` via `drawChart` → `ChartMarkerSystem.drawMarkers`.
- **Issue:** Guide line is a separate overlay; markers are in Canvas. Canvas is drawn first, then guide overlay on top. So guide line is drawn *over* markers, meaning dashes can appear *through/over* marker bodies depending on compositing.

## Preview Marker (`previewMarkerContent`)

- Three circles: clear hit target (80×80), dark fill (40×40) + colored stroke, inner icon (24×24).
- Icon: emoji or SF Symbol, white fill.
- Info box below with marker type name.

## Tap / Selection Flow

- `tapGestureForMarkers` → `findMarkerAtLocation` → `markerManager.selectedMarker = marker`, `tappedMarkerId = marker.id`.
- `markerHaptic.impactOccurred()` (UIImpactFeedbackGenerator medium).
- `selectedMarkerId` passed to `drawMarkers` as `markerManager.selectedMarker?.id ?? tappedMarkerId`.
- No wiggle animation; scale comes from `isSelected` in render.
