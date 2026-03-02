# Marker Redesign Validation Checklist (Todo 38)

**Date:** 2025-03-02  
**Purpose:** Manual and automated validation sign-off for marker redesign.

## Automated Tests

Run in Xcode: **Product > Test** (⌘U)

- [ ] `MarkerManagerAuditTests.visibilityModeAndTypeFiltering` passes
- [ ] `MarkerPlacementFormattingTests.usernameCollisionSuppressionIsDeterministic` passes (uses `visibleUsernameMarkerIDs`)
- [ ] All other `MarkerManagerAuditTests` pass

## Manual Validation Checklist

### Marker Appearance
- [ ] Marker shells use neutral light/dark grey (weather-app style)
- [ ] Icons are bold and pronounced with neutral light/dark tint
- [ ] Selected marker has thicker border and scales up smoothly
- [ ] Optional gradient overlay visible on Entry, Exit, Stop Loss, Take Profit, Alert types
- [ ] Like badge still displays correctly when `likeCount > 0`

### Username Removal
- [ ] No usernames appear under chart markers
- [ ] Author info visible in marker detail view (bottom sheet)

### Guide Line Occlusion
- [ ] Dashed vertical guide line never visible inside marker bodies (placement mode)
- [ ] Dashed vertical guide line never visible inside marker bodies (selected marker mode)
- [ ] Guide line draws behind markers (markers occlude it)

### Selection Interaction
- [ ] Tapping a marker triggers haptic feedback (selection)
- [ ] Selected marker scales up with spring animation
- [ ] Deselecting (closing detail) animates scale back to 1.0
- [ ] Chart centers on selected marker

### Stack Behavior
- [ ] When one marker is selected, neighboring markers in same stack nudge away
- [ ] No overlap between selected (enlarged) marker and neighbors
- [ ] Hit testing: tapping markers still selects correct marker

### Cross-Surface Consistency
- [ ] Chart markers match preview marker style (placement mode)
- [ ] Preview marker info box uses neutral shell tokens
- [ ] MarkerView (creation/activity) uses same shell variant and icon style

### Timeframes and Zoom
- [ ] Markers render correctly at 1m, 5m, 15m, 30m, 1h, 4h, 1d, 1w, 1M
- [ ] Zoom in/out: markers scale and stack correctly
- [ ] Dense stacks (3+ markers per candle): no overlap, nudge works

### Regression Checks
- [ ] Marker tap-to-focus works
- [ ] Marker detail sheet takeover works
- [ ] Marker placement flow (all types) works
- [ ] Prediction marker placement (3-line) works
- [ ] Connection lines (dashed to candle) still render
