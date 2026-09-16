# Cross-timeframe badges: outward placement + tether — implementation report

Date: 2026-09-15. Tree `.worktrees/linked-markers-claude`, synced to Codex HEAD `bd5b946` first
(worked tree made identical to `bd5b946` file-by-file, then `git reset bd5b946` — no hard reset;
a backup of the 63 previously differing paths is in the scratchpad `pre-sync-backup/`). All work
below is a delta on `bd5b946`; nothing else is uncommitted.

Status: **complete.** Commit `4b36eeb` on top of `bd5b946` (7 files, +502/−79). Working tree clean.

## What changed

### Outward badges with a dotted tether (`MarkerTimeframeJump.swift`, `MarkerLinkRenderer.swift`)

* Badges now sit **outward, away from the candle**: above a glyph that sits above its candle,
  below one that sits below. Each splays 45° off that vertical — parent to the right, response to
  the left — so neither lands on the stack neighbour directly outward of the selected glyph.
  Standoff 36pt from the glyph's scaled edge, which leaves a visible tether.
* A **thin dotted tether** (1pt, dash `[1, 3]`, relationship colour at 0.85) runs from just outside
  the glyph's ring to just outside the badge's arrow ring, so a badge floating clear of the candle
  still reads as belonging to *this* glyph. `Placement` now carries `tetherStart`/`tetherEnd`.
* **Shared final positions**: `MarkerTimeframeJumpLayout.placements(...)` is the only source, used
  by the draw pass and the tap hit-test with the same inputs (`plotRect`, `avoidRect`), and a test
  pins that the two calls agree.
* **Edge clipping**: a badge that would leave the plot top/bottom cannot use that band; one that
  would leave the sides is slid back in.
* **Info-card readability**: `TradingChartView` measures the top-left info column
  (`onGeometryChange`, chart coordinates) and passes it as `avoidRect`. Search order when the
  preferred spot is blocked: slide outward on the same side (4pt steps, ≤44pt); take the other side
  of the outward band, sliding past a badge already placed there; only then the candle side.
  Keeping the badge *outward* is preferred over keeping parent-right / response-left — the tether
  makes attribution unambiguous either way.
* **Neighbouring glyphs are obstacles too** (added after the first simulator pass showed the
  ellipsis badge landing on a same-timeframe response's glyph, `O09a`): one helper,
  `ChartMarkerSystem.timeframeJumpObstacles(...)`, recomputes nearby glyph discs — including the
  selection nudge — from the same marker/candle inputs in both passes, so draw and tap agree.
* Glyphs and candles are not moved.

### Owner's mid-review asks (same files)

* **Supports icon**: `hand.thumbsup` → `checkmark` (`MarkerLinkRelationship.icon`, the single
  source every surface reads). Leaf badges are now drawn as heavy-weight symbol text instead of a
  regular-weight resolved image, so the 8pt glyph reads as a mark rather than a hollow outline.
* **Like / count badges on a highlighted marker**: they previously stayed at the resting offsets
  (x±8/22, y+5/−17) and sank inside the 1.5× disc. `MarkerLinkRenderer.badgeOutset(scale:)` moves
  both out along their diagonal by the disc's growth, so they straddle the enlarged edge exactly as
  they straddle the resting one (resting geometry unchanged, pinned by test). The connector
  obstacle rects use the same scaled rects. `drawSingleMarker` and `linkGlyphBounds` pass the scale.

### Wiring (`TradingChartView.swift`, `ChartMarkerSystem.swift`)

* `drawMarkers(... markerPlotRect:infoCardRect:)` and `timeframeJumpAtLocation(... plotRect:avoidRect:)`
  gain optional rect parameters; `TradingChartView` passes `plotRect` and the measured
  `chartInfoColumnFrame` at both call sites. One new `@State` and one `.onGeometryChange` on the
  info column are the only other chart-file changes.

## Tests

`MarkerTimeframeJumpTests` (layout section rewritten; 20 tests total): splay outward parent-right /
response-left and mirror below the candle; tether runs from glyph ring to arrow ring, collinear,
≥10pt visible; clears the stack neighbour and both candle-side badges; a badge clipped at the plot
top/bottom flips to the candle side; a badge at the plot's side slides back in without flipping;
blocked on its own side → crosses to the other side of the outward band without overlapping the
first badge; under the info card → slides outward, then flips only when the whole band is covered;
never sits on a neighbouring glyph; draw and hit-test share one placement (incl. after avoidance).
`MarkerLinkRenderTests` (+2): resting badge rects are byte-for-byte the old ones; selected badges
straddle the enlarged disc, mirror about the glyph, stay on the candle side, and the connector
obstacle rects equal the drawn rects.

Ran with the neighbouring marker-link suites (jump, render, geometry, graph, by-id, realtime):
**95/95** (`outward-units4.xcresult`). DevProfile simulator build: BUILD SUCCEEDED, 0 errors
(`outward-build4.log`).

## Simulator verification (DevProfile, iPhone 17 Pro, local DEV with live 1m ingestion)

| Case | Result | Evidence |
|---|---|---|
| Glyph **above** its candle, two responses elsewhere (ellipsis) | Badge outward (up), crossed to the right because the left outward spot is under the info card; dotted tether from glyph ring to arrow ring; card fully readable | `O01-root-above-candle-outward-ellipsis.png` |
| Tap ellipsis → chooser → 4 Hours row | Chooser opens from the relocated badge; lands on the 4h response, selected | (chooser identical to yesterday's `C02`) `O03…` |
| Glyph **below** its candle (4h response) | Parent badge outward (down-right) with tether; count/leaf badge on the candle side | `O03-4h-response-below-candle-outward-parent-badge.png` |
| Parent badge returns directly | Back on the 30m root, no chooser | `O04-parent-badge-returns-to-root.png` |
| Middle node: **parent + response badges** | "30m" (parent, green) and "5m" (response, teal) both outward, the response crossed to the right and slid past the parent badge; two tethers; count "1" straddling the enlarged disc | `O05-response-A-selected-scaled-badges.png` |
| Like + count badges on a selected glyph | After liking: red "1" (like) lower-right and green "1" (count) lower-left both sit on the 1.5× disc edge, mirrored | `O06-selected-like-and-count-badges-straddle-disc.png` |
| Resting geometry unchanged | Deselected: both badges at the old resting offsets on the small disc, cross-timeframe badges gone | `O07-resting-badges-unchanged.png` |
| Supports leaf icon | Heavy green ✓ badge on the 15m supports response; its "5m" parent badge outward with tether; tap → lands on the 5m parent | `O08-supports-leaf-checkmark-15m.png` |
| Neighbouring glyph avoidance | Before: ellipsis on the 5m root landed on the adjacent same-timeframe response glyph (`O09a`). After: badge crossed to the free side, connector to the neighbour intact; tapping the relocated badge opens the chooser (hit-test in agreement) | `O09a-…BEFORE…png`, `O09-5m-root-badge-clears-neighbour-glyph.png`, `O10-chooser-from-relocated-badge.png` |

Console for the session (`launch-console.txt`): navigations 1h→15m→5m logged, zero
`fatal|EXC_BAD|crash`, zero "only presenting a single sheet", zero `String(format` warnings.

## Findings / notes for Codex

* **Resolver gap (Codex's `MarkerTimeframeJumpResolver`, not changed here):** a marker whose
  response branch is not loaded (`branchCursors[node] != nil` but no children in the window)
  gets **no** response badge at all, although its count badge says it has responses — seen on
  response A right after its 5m grandchild was created (`O05a`, "1" count, no badge). The
  `requiresChoice` ellipsis only appears once at least one child is loaded. Suggest: when the
  branch cursor exists and `directResponseCount > loadedSameTimeframeChildren`, emit an
  ellipsis jump even with zero loaded children (target = the marker itself; the chooser loads the
  branch).
* The ellipsis badge still takes the newest loaded response's colour (yesterday's note); with
  the tether now pointing at the marker, a neutral fill would read even better. Cosmetic.
* Trade-off made deliberately: when the outward band on the badge's own side is blocked (card or
  glyph), the badge crosses to the other side rather than flipping toward the candle, so
  parent-right / response-left is not guaranteed — the tether and the label carry attribution.
  If the owner prefers the strict side convention, swap the two inner loops in
  `MarkerTimeframeJumpLayout.placements` (side before vertical).
* Not covered on the simulator: plot-edge clipping (unit-tested only) — it needs a selected glyph
  hard against the plot top/bottom, which the selection centring avoids.

Fixture rows added today (QA guild only): `fcbef176…` (5m grandchild under response A) and one
like on response A.


## Device-log follow-up (separate from the badge visuals)

Second commit: `fefab7c` (formatting fix). Nothing else changed for this part.

### `String(format:locale:arguments:)` … `%.0f` vs `Swift.Int` — **reproduced and fixed**

Exact source: `RSIPanelView.yAxisLabels` lines 626/632 (and the identical shape in
`StochasticPanelView` 502/508):

```swift
text: String(format: "%.0f", rsiConfig?.overboughtLevel ?? 70)
```

`overboughtLevel` is a `Double`, so this looks typed — but in the `CVarArg` parameter position
Swift may lift the optional chain to `CVarArg?` and default the literal to `Int`. When the chain
is **nil** the argument is the `Int` 70. A probe test on the iOS 26 simulator pins it:

| expression | result |
|---|---|
| `String(format: "%.0f", present?.overboughtLevel ?? 70)` | "70" |
| `String(format: "%.0f", none?.overboughtLevel ?? 70)` | **"0"** ← the warning |
| `String(format: "%.0f", d ?? 70)` with `let d: Double? = nil` | "70" |

The third row is the shape the desk test used, which is why it passed on macOS: a plain `Double?`
variable resolves the other way; an optional *chain* does not. Two labels per panel pass → the
pairs of warnings, and they fire while `activeIndicators.rsi` is transiently nil — the frame in
which a marker's indicator components are being swapped in on selection/creation, which is where
the owner's log shows them (marker with an RSI component created; the same marker selected after
each navigation).

Fix: `IndicatorLevelFormatting.wholeNumber(_:fallback:)` binds a `Double` first; the four sites
use it. `IndicatorLevelFormattingTests` (2) pin the nil and present cases. A sweep of the tree
found no other `String(format:…, x?.y ?? literal)` sites.

### "Currently, only presenting a single sheet is supported" after the 15m→5m return — **not reproduced; uncertain**

Reproduced the owner's sequence on the simulator (same build lineage, local DEV): selected a 5m
marker, *Respond with marker → Supports*, switched the response timeframe to 15m, placed it
(share prompt, `L01`), *Not now*, selected the new 15m response, tapped its "5m" parent badge →
15m→5m navigation completed with the parent selected (`L02`). Also returned via the sheet's
"Open parent on 5 Minutes" and via the chooser earlier in the session. **Zero** "only presenting
a single sheet" lines in the whole console (`launch-console.txt`).

What the warning means, for the next attempt: SwiftUI logs it when two `.sheet` modifiers **on
the same view** are active at once, and repeats it on every update while both stay active —
which matches the ~40 repeats until the app was stopped. The chains in play:

* `TradingChartView.withSheetPresentations`: `showMarkerTypeFilterSheet`, `timeframeChoicesMarker`
  (the chooser), `showChartSettingsSheet`, `drawingTextEditorContext`.
* `MainView`: the bottom sheet (whose `isPresented` stands down for its peers), then
  `selectedViewingMarkerAuthorRoute`, `markerSharePromptContext`, `welcomedGuild`,
  `showDiscordSetupReminder`.

In the owner's log the warnings start in the same instant as `NAVIGATION COMPLETE` (line 466),
before the thread fetch for the landed marker (483), so the second sheet was requested at or just
before landing. Nothing in the return path sets any of those bindings, and the share prompt is
modal over a dimmed chart (background taps do not reach the badges). Two things I could not
exercise on the simulator that the log shows on the device: an `app_became_active` resync a few
seconds earlier (the app was backgrounded mid-flow) and "System gesture gate timed out" lines.
So: mechanism understood, pair not identified, no speculative change made.

Cheapest way to name the pair on the next device run (DevDebug-only, a few lines each for Codex):
log when more than one of the four chart-sheet bindings is active, and likewise for MainView's
peers — the first such line will say which two. If it turns out to be the chooser against the
bottom sheet re-presenting, the fix that fits the existing design is to fold `timeframeChoicesMarker`
into MainView's sheet-slot condition the way `markerSharePromptContext` is, so the bottom sheet
stands down while the chooser is up.

### "Debug session ended with code 9: killed"

SIGKILL with no exception trace is the debugger/host stopping the process (Xcode stop, or the
owner force-quitting), not a crash. Nothing to chase there.

Evidence for this part: `L01-share-prompt-after-15m-response.png`, `L02-after-15m-to-5m-return.png`,
`launch-console.txt`. One more disposable row was created: a 15m supports response under the 5m
"Severe alert" root's supports child.
