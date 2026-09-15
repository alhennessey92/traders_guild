# Connectors / settings — owner feedback implementation (Claude tree)

Status: **started 2026-09-14**. Working in `.worktrees/linked-markers-claude`
only. The uncommitted stack fix (ChartBodyBoundary, byte-identical to 6bd2b62)
stays uncommitted and out of every connector commit.

## Scope taken
1. Every visible edge of the loaded focused component, not selected↔neighbours.
2. Opposite-stack / branch-grandchild routing that finds a safe curve instead of
   omitting.
3. Persisted line Thickness and Curvature in chart settings.

## Not touched
TradingChartView.swift, MainView.swift, placement files, Codex tree, backend.
Any wiring TradingChartView needs is written below for Codex to apply.

## Progress log
- reading MarkerLinkGraph / Geometry / Renderer / ChartMarkerSystem / settings

## Design (decided 2026-09-14, before coding)

**Why opposite-stack connectors vanish today.** A parent stacked above the
candle and its response stacked below share an x column, so routing uses the
same-candle quadratic ladder (max lateral bow 44pt at the *apex*). On a 200–300pt
chord the curve is still within ~20pt of the column at t≈0.13 — exactly where
the adjacent stack slots (40pt from each endpoint) sit — so every rung grazes an
intermediate glyph and the edge is omitted. A quadratic cannot clear obstacles
near both endpoints of a long chord without an enormous apex.

**Fix: a second curve family.** For long same-column chords the router tries a
cubic "bracket": two control points offset laterally by `d` at ¼ and ¾ of the
chord, so the line leaves the column immediately, runs beside the stack, and
rejoins. Ladder for `d` escalates like the quadratic one. Quadratic stays for
short chords, so nothing already-good changes. `MarkerLinkRoute` gains an
optional second control; trim and the reveal sub-curve get cubic de Casteljau;
the renderer emits `addCurve` for cubics.

**Every edge of the component.** `focusState` emits parent→child edges for every
loaded pair in the selected marker's connected component (`.withinThesis` kind),
after the selected marker's own parent/children. The 12-edge cap is removed —
no silent dropping. Cost is bounded by spatial filtering: each edge only tests
obstacles whose bounds intersect its own expanded bounding box.

**Settings.** `ChartSettings.linkLineWidth` (1.0–3.0, default 1.5) and
`ChartSettings.linkCurvature` (0.6–1.6, default 1.0), persisted in
UserDefaults like the existing viewport settings, with a Reset. Curvature
multiplies every bow magnitude; thickness is the stroke width. Dash patterns are
unchanged (points, independent of width).

**Wiring without touching TradingChartView.** `MarkerLinkRenderContext.init`
gains `lineWidth`/`curvature` parameters whose *defaults* read
`ChartSettings.shared`; TradingChartView already `@ObservedObject`s that
singleton, so a slider change re-renders the Canvas with the new values. Works
live from my tree with zero TradingChartView edits. An explicit hunk is given
below for Codex to make the dependency visible at the call site.

**Unchanged by design:** glyph positions, hit testing, endpoint trimming to
the scaled disc, obstacle/badge clearance, plot clipping, privacy/visibility
filtering (edges only exist between rendered glyphs), relationship dash
patterns, Reduce Motion, grey stack spine.

## Progress — implementation done, tests green (2026-09-14)

Files changed (mine): `MarkerLinkGraph.swift`, `MarkerLinkGeometry.swift`,
`MarkerLinkRenderer.swift`, `ChartMarkerSystem.swift` (two call-site args),
`ChartSettings.swift`, `ChartSettingsView.swift`; tests in
`MarkerLinkGraphTests`, `MarkerLinkGeometryTests`, `MarkerLinkRenderTests`,
new `ChartLinkAppearanceSettingsTests`.

Connector suites: 94/94 (geometry 22, graph, render, settings, self-audit,
hit-testing, visibility). Two existing tests were re-fixtured, not weakened:
* `omitsEdgeWhenNoSafeRouteExists` — its wall only reached the old ladder's
  44pt, and the bracket legitimately found a path around it at 72. The wall now
  spans the whole excursion the planner can search, so the omission contract
  is still pinned at the new bounds.
* the cap test — became `drawsParentFirstThenEveryChildWithASafePath`: 21 of 21
  routed on a plot wide enough to hold them, none omitted.

Next: fixture-gallery scene for opposite stack + grandchild, then the dense
fixture and the settings sliders live on the simulator.

## Second cause found during visual review — endpoint badges

The gallery's opposite-stack scene omitted the long edge even though the unit
test routed it. Difference: the gallery parent had *both* badges (response
count lower-left, likes lower-right). A thesis parent always wears the response
badge, so any connector leaving it downward hit its own badge at the first
sample and was rejected — on both sides when likes are present. This is
probably as large a part of the owner's report as the geometry.

Fix: endpoint badges are **soft** obstacles — a badge-free side is still
preferred when one exists (unchanged, prettier), and only if nothing routes
are the endpoint's own badges exempted. The line's body is still tested against
every other glyph's badges in both passes; the badge is painted over the line's
emergence anyway. One existing test (`avoidsEndpointBadges`) encoded "omit
rather than emerge from under your own badge"; it now asserts what still
matters — no badge under the line's *body* — and requires the route to exist.

## Final state

**Commit:** `1d53330` — *feat(markers): draw every edge of a thesis, and route
the ones that were lost* — on `claude/1.3.0-marker-visuals` in
`.worktrees/linked-markers-claude`. 11 files, +1130/−111. **Contains none of
the stack fix**; `TradingChartView.swift` and the two `ChartBodyBoundary`
files remain uncommitted in my tree exactly as before (byte-identical to
6bd2b62), so the cherry-pick is clean.

**Tests** (this change's suites, `-only-testing`, result bundle
`scratchpad/conn-units5.xcresult`, log copied to
`/tmp/linked-connectors-evidence/connector-suites.log`):
**96 passed, 0 failed** across `MarkerLinkGeometryTests` (24),
`MarkerLinkGraphTests`, `MarkerLinkRenderTests`,
`ChartLinkAppearanceSettingsTests` (new, 5), `MarkerLinkSelfAuditTests`,
`MarkerFocusHitTestingTests`, `MarkerGlyphVisibilityTests`. Full suite not
rerun, per instruction. New regressions:

* graph — every loaded edge offered once, nearest first, other theses excluded,
  unloaded endpoints produce no edge
* geometry — opposite-stack routes clear of both stacks (plain and with the
  response selected at 1.5×); branch grandchild gets both edges; short pairs
  keep the arc; a parent with badges on both sides still connects; a badge-free
  side is still preferred; curvature scales sagitta and is clamped; 21 of 21
  children routed with no cap; spatial filtering changes no route; omission
  still happens when genuinely walled in across the whole search width
* render — bracket emitted as one cubic with an exact partial reveal
* settings — defaults, persist/reload, clamp on set and load (incl. NaN),
  reset, and the render context picking up persisted values

**Visual evidence** (`/tmp/linked-connectors-evidence/`):

| File | What it shows |
|---|---|
| `G02-gallery-opposite-stacks.png` | New gallery scene. Root above the candle (badges both corners), stranger above, candle, stranger below, response, grandchild. Green bracket root→response beside the column, clear of both strangers; teal arc response→grandchild (a within-thesis edge). Before this change the green edge was omitted. |
| `G01-gallery-unrelated.png` | Parent → unrelated → response, unchanged: same smooth arc as before. |
| `G03-gallery-dense.png` | Long red and teal brackets to the opposite stack beside a same-side green arc; no cap. |
| `R01-real-chart-focus-whole-component.png` | Live dense QA fixture, 1h, Sep 6 region. Selection shows its parent edge (red), its opposite-stack edge across the candle to the below stack (green), and a within-thesis edge between two *non-selected* members (teal). Unrelated glyphs untouched, spine grey. |
| `S01-settings-linked-markers-max.png` | The new Linked Markers card in Chart Settings: Line Thickness 3.0 pt, Curvature 160%, Reset. |
| `R02-real-chart-thick-curvy.png` | Same selection after the sliders, no relaunch: heavier strokes, wider bows, same dash rhythm. |

Simulator UserDefaults for the two keys were reset afterwards.

## Wiring hunk for Codex — TradingChartView (optional, makes the dependency explicit)

The feature works without this because `MarkerLinkRenderContext.init` defaults
`lineWidth`/`curvature` from `ChartSettings.shared`, which `TradingChartView`
already observes. If you prefer the dependency visible at the call site, in
`linkRenderContext(plotRect:)`:

```swift
        return MarkerLinkRenderContext(
            focus: focus,
            ringStyles: ringStyles,
            revealProgress: reduceMotion ? 1 : linkRevealProgress,
            plotRect: plotRect,
            lineWidth: chartSettings.linkLineWidth,
            curvature: chartSettings.linkCurvature
        )
```

No other TradingChartView change is needed. `ChartMarkerSystem.drawMarkers`
already passes `linkRender.curvature` to `plan` and `linkRender.lineWidth` to
`drawConnectors` (both in this commit).

## Limitations, stated plainly

* Visual review is simulator-only (DevProfile, iPhone 17 / iOS 26.0); no
  device. Performance was not measured this round, per instruction; the
  spatial filter is exercised by `obstacleFilteringDoesNotChangeAnyRoute`.
* With endpoint badges soft, a connector may emerge from *under* the glyph's
  own badge when that is the only way out (`avoidsEndpointBadges` documents
  this). The prettier badge-free side is always tried first.
* The dense gallery scene is a synthetic stress layout and I adjusted only
  its price range so a below stack fits the canvas; the real chart is the
  evidence that matters (`R01`, `R02`).
