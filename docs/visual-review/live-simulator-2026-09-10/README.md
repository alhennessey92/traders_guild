# Live simulator verification — 10 September 2026

Claude exercised the retained local QA guild in an optimized isolated DEV build.
Codex inspected these screenshots and independently read the Xcode result bundle:
**577 passed, 5 skipped, 0 failed, 582 total**, including the chart pan driver.
The skips are existing credential-dependent authentication/guild UI tests.

Codex's subsequent integrated unit run passes **572/572, zero skipped**,
including three additional clipped-plot hit-testing regressions. Its result
bundle is `/tmp/linked-codex-edge-tests.xcresult`. This run verifies the final
edge correction; it does not repeat Claude's UI acceptance or pan-driver run.

The integrated clean Release simulator build passed. Feature packaging at
`f36340f` also built successfully and its Info.plist reports **1.3.0 build 23**,
`co.tradersguild.app`. The bundle contains no xcconfig or stray DEV Info.plist,
and the project contains no macOS target. This is local build evidence, not an
App Store upload or physical-device measurement.

- `03-focus-mode-live-dense.png`: selected marker, relationship rings and a curved
  connector on the dense real backend fixture; unrelated markers faded.
- `10-disclosure-survived-timeframe-change.png`: Step 64 selected after moving
  from 1h to 4h, disclosure retained, partial total and relationship tally visible.

The fixture uses synthetic local candles and disposable QA members. These are
interaction screenshots, not market data or production observations.

## Performance evidence and limits

Instruments did not produce a usable simulator trace. Claude used 30-second
`sample` captures with repeated pans to identify symbol preparation and theme
lookups in the glyph loop. The retained captures contain the reported hot-path
counts (2983 before; 1546 and 1709 after; 2543 in the focus capture). These are
sample counts at particular stack branches, not complete frame timings or FPS.

The viewport drifts toward sparser data during each sequence, and runs vary.
The captures support the targeted per-draw-pass preparation optimization; they
do **not** establish a frame-rate percentage improvement or absence of recurring
frame stalls. The physical iPhone Instruments/Core Animation gate remains open.
Raw capture paths and SHA-256 hashes are recorded in `evidence.json`.

Live checks confirmed cross-timeframe selection/disclosure retention and edit
entry/cancellation. The final open-disclosure update/delete refresh checks were
automated through the production acknowledgement/invalidation paths. A final
two-member manual update/delete walkthrough remains to be completed, preferably
using a separate disposable branch to preserve the performance fixture.
