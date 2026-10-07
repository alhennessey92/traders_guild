# v1.5 workspace: P5 checkpoint, Add context

Claude, 7 October 2026. Branch `claude/1.5.0-marker-workspace`, on top of P4 (`46e3018`). Nothing has been merged into `feat/1.5.0-avatar-markers`.

The owner's direction (6 October): keep something like the original Components tab layout for indicators and components, but "don't be too constrained by the original tab layout, if you feel you can improve then do so". The owner said the existing indicator settings editor (options and values) "look great"; it is kept unchanged.

## What changed

Add context is now **one screen** in the Components sheet's tab layout, improved for the workspace:

| Part | Design |
|---|---|
| **On this marker** | Everything the marker already carries, as chips across the top: "Support 63,780.00", "4h", "RSI 14", "Note: Range low…". Each chip wears its arc family's colour; tap a chip to edit it, ✕ to remove it. This replaces the old "Active" tab, so what is attached stays visible while browsing. |
| **Tabs** | Indicators · Drawings · Timeframes · Notes, as equal segments with the icon over the name, so all four fit on any phone. The chosen tab fills in its **arc colour** (orange, purple and cyan, the same colours the guild sees on a selected marker), and a dot counts what is attached. Only tabs the type can use appear. The tab is remembered, so returning from an editor or the chart lands on it. |
| **Indicators** | The category tabs from the original (Trend · Volatility · Momentum · Volume). Below them is a two-column grid of tiles (icon, short name, full name). Tiles show a ✓ (or "×2" for moving averages) when already on the marker. A tile opens the existing settings editor in place. "Use my chart's indicators (n)" copies the chart's set, within the limits. |
| **Drawings** | Sections: **Levels** (Support, Resistance: "Set a price, or drag it on the chart"), **Lines** (Trendline, Horizontal Line, Zone: "Choose a tool, then draw it on the chart") and **Patterns** (Breakout Retest, Range Reversal, Rising Channel, Head & Shoulders). Tools go straight to the chart as before. "Use my chart's drawings (n)" is there too. |
| **Timeframes** | A grid of timeframe tiles: tap to link, tap again to unlink. The chart's own timeframe is marked "This chart"; linked ones fill cyan. The limit of two is enforced with the existing message. |
| **Notes** | Chart note, and Source link (Analysis only; "Edit" once there is one). |
| Header | "Add context · New Analysis". |

Unchanged: the capability matrix (`workspaceAllows`: Question and Setup never see Source or levels), every editor's stage, commit and cancel semantics, the drawing and level chart hand-offs, and the limits. The old picker routes (`.indicators`, `.drawings`, `.timeframes`) still resolve, but they now land on this screen.

Implementation: `MarkerWorkspaceContextViews.swift` (new). `MarkerContextTab`, and the session's `contextTab` / `indicatorCategory`, are in `MarkerWorkspace.swift`. `MarkerTileGrid` is a small non-lazy two-column `Layout`, so every tile exists for VoiceOver and tests, with one column at accessibility text sizes. Browsing (tabs, categories) is session state, so it never redraws the chart.

## Evidence

Screenshots: `docs/visual-review/v1.5-p5/`.

| Check | Result |
|---|---|
| New model tests (`MarkerWorkspaceSessionTests`) | Each type gets only the context it can carry. The tab and category are remembered across an editor, and browsing announces nothing to the chart. A tab the draft cannot use falls back to the first it can. |
| Updated UI journeys | Unsaved indicator collapse/resume/cancel; indicator Done commits and posts; an unfinished source link resumes without a placeholder; a Question excludes source and levels; the level chart hand-off; shell trace journeys, including the redraw count, which now also switches tabs and categories (still **0** MainView redraws). |
| Focused unit suites (11) | **135/135** |
| Workspace UI suites, iPhone 17 Pro / iOS 26.5 | **56/57** on the first run; the one failure was **a real crash, found and fixed** (below). The Setup ticket suite then passed **3 iterations of 3** with the fix. |
| Sheet journeys + visual review, iPhone SE / iOS 18.2 | **13/13 + 1 skipped** (hardware keyboard) |
| Release build; signed device build | Succeeded |

**Crash found and fixed.** `PatternOverlay.drawHoneycomb` trapped ("Range requires lowerBound <= upperBound") when UIKit briefly laid the sheet background out at a negative height. That happened during a Setup side-change alert while the number pad was going away. The honeycomb is part of the standard sheet background the workspace adopted in P3, and the pattern is shared by the app's other sheets. It now draws nothing at a zero, negative or non-finite size, and valid sizes draw exactly as before.

## For you on device

**Add context** on a new Analysis:
1. Browse Trend → Momentum. Tap **RSI**, change a value, then **Done**: an "RSI 14" chip appears on top, and the RSI tile shows ✓.
2. **Drawings** ▸ **Support**: set a price, or Work on chart.
3. **Timeframes** ▸ **4h**, then **Notes** ▸ **Source link**.
4. Tap a chip to edit it, or ✕ to remove it.

## Known, next

- The drawing editor screen, opened by editing an attached drawing, still uses the older style picker and colour dots. A follow-up restyles it as an inline strip.
- P6: editing entry for all three types, chart framing above the sheet, viewing → respond continuity, a VoiceOver, Dynamic Type and Reduce Motion pass, and small screens.
