# Independent Claude report

Codex review note: the inner boundary wraps only `interactiveChartLayer`. The existing `.onChange` modifiers stay outside that boundary. Visible updates were exercised; individual handler execution was not instrumented. Screenshots below are copied into this directory; raw console/build logs remain local under `/tmp` and are not committed.

# ChartBodyBoundary — simulator interaction smoke check

Date: 2026-09-12. Read-only against Codex's tree; the fix was copied into
`.worktrees/linked-markers-claude` for testing only and is **not committed
there**.

## What was applied, and parity with Codex's commit

Three source items, nothing else:

* `traders_guild/TradingChart/ChartBodyBoundary.swift` — byte-identical copy.
* `traders_guildTests/ChartBodyBoundaryTests.swift` — byte-identical copy.
* `traders_guild/TradingChart/TradingChartView.swift` — the two wrapper hunks
  only (`rootChartContainer` GeometryReader closure at ~945, and the first
  element of `chartContent`'s ZStack at ~1089). The applied diff was checked
  line-for-line against `git show 6bd2b62 -- TradingChartView.swift`:
  **identical**.

Deliberately not copied: the `project.pbxproj` and `LinkedDev.xcscheme`
working-tree changes in Codex's tree (file-reference normalisation, a
"Recovered References" group, scheme edits). They are Xcode churn from the
device session, not part of the fix, and 6bd2b62 does not include them either.

## Build under test

`traders_guild LinkedDev` scheme, **`DevDebug` configuration, `-Onone`**
(confirmed in the build log: `swiftc -module-name traders_guild -Onone`),
simulator destination, bundle `co.tradersguild.app.linkeddev`, gateway baked to
`http://127.0.0.1:30080/api/v1` (`/healthz` → 200 before launch). This is the
unoptimised configuration the device crash lived in, on the simulator.

Device: iPhone 17 simulator, iOS 26.0 (`DA8FD3E2-…`) — a separate simulator
from any marker work; no physical device or Xcode was touched. Signed in as
the retained QA member account. Credentials were not printed.

## Interactions performed and what happened

Each step: performed with the simulator control tool, screenshot taken with
`simctl io screenshot`, and the process checked alive with
`launchctl list` afterwards. Console captured via `--console-pty` for the
whole session: 178 lines, zero matches for `fatal|EXC_BAD|crash`.

| # | Step | Result | Evidence |
|---|---|---|---|
| 1 | **Cold launch** — `simctl terminate`, install DevDebug build, `simctl launch`. Session restore → transition → chart. This is the exact path that overflowed on the device (session restore → chart → first `selectedMarker` read in `markerDrawingOverlay`). | Chart up at 5m with the live candle, no crash, process alive. Console shows `restoreSession … Tokens refreshed`, `Showing ContentView`. | `S01-cold-launch-chart.png`, `launch-console.txt` |
| 2 | **Timeframe change** — open the symbol sheet, tap 1H, close. | Chip reads 1H, axis re-labels to 12 Sep, chart re-fetches. Alive. | `S02-timeframe-1h.png` |
| 3 | **Pan** — two 270pt swipes back in time to the dense QA fixture (Sep 8–9). | Dense marker stacks render with badges (including the `99+` cap on the wide root). Alive. | `S03-pan-back.png` |
| 4 | **Marker selection** — tap a glyph in the stack. | Focus mode engages: selected glyph scaled with a green ring, red-ringed companion, rest faded to 0.22, chart animates to centre the marker (09 Sep 09:00 pill), info card and *Question Marker* header shown. This is `activeSelectedMarker` (line 706) being read live at -Onone — the crash's victim frame. Alive. | `S04-marker-selected-focus.png` |
| 5 | **Deselection** — tap empty plot space. | Focus exits: full opacity restored, header gone, chart controls back. Alive. | `S05-deselected.png` |
| 6 | **Enter placement** — bottom bar *target* tab → expanded Markers sheet → *Question*. | *Place a Marker* mode: checklist 1/4, ghost anchor on the candle, marker layer under the placement dim, composer panel below. This drives the `isMarkerPlacementMode` `.onChange` inside the inner boundary and the `GhostPreviewLayer` branch of `chartContent`. Alive. | `S06-placement-entered.png` |
| 7 | **Cancel placement** — the ✕ at top-left. | Idle chart restored exactly: dim cleared, no ghost, controls back. Alive. | `S07-placement-cancelled.png` |

All seven checks passed. Nothing was created, edited or deleted; the deep/wide
fixture was only viewed.

One navigation note, not a finding: the *target* bottom-bar button selects the
Markers **tab** of the collapsed sheet rather than starting placement
directly, so placement is reached by expanding the sheet and choosing a
marker type. That is existing behaviour and the same on the unfixed build.

## Findings

* **No regression observed** in any of the five interaction classes on the
  `-Onone` simulator build with both boundaries in place. The observation
  narrowing I flagged in the stack review — values read inside the wrapped
  chain are now observed by the boundary's body rather than by
  `chartContent` — did not show up as a missed update: selection scale and
  focus animated, deselection settled, the placement-mode `onChange` fired
  both ways, and panning reached the fixture with candles and markers
  loading.
* **The launch path that crashed the device now completes on the same
  optimisation level** in the simulator. This is not a substitute for the
  device measurement (the simulator's main thread has a different stack
  size and the metadata caches may be warm), but it is the interaction
  evidence the device could not give while unreachable.
* Nothing to report against the fix's shape. The inner boundary wraps only
  `interactiveChartLayer(…)` and leaves the 24-modifier chain outside it,
  which is a smaller carried value than wrapping the whole chain would be;
  the outer boundary decouples the `GeometryReader` closure. Both match the
  intent of the review recommendation.

## Not done, by instruction

* No full unit run (Codex's 615/615 stands), no performance measurement, no
  device or Xcode control, no documentation edits in Codex's tree.
* My tree keeps the copied fix **uncommitted** so it cannot diverge from
  6bd2b62; drop it or take Codex's commit on integration.

## Evidence

`/tmp/linked-boundary-smoke/`:
`S01-cold-launch-chart.png`, `S02-timeframe-1h.png`, `S03-pan-back.png`,
`S04-marker-selected-focus.png`, `S05-deselected.png`,
`S06-placement-entered.png`, `S07-placement-cancelled.png`,
`launch-console.txt`, `devdebug-simulator-build.log`.
