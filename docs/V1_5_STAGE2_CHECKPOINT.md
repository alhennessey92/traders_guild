# v1.5.0 Stage 2 checkpoint: live avatar markers (Claude)

Branch `claude/1.5.0-avatar-markers`, on top of Stage 1 `d199983`. It is one local commit: not pushed, not deployed, with no backend or production contact. The commit hash is reported in chat.

The owner asked for Stage 2 to start before Astra had reviewed Stage 1, so Astra reviews both stages together. Stage 3 (guided creation) has not started.

## What changed

**Live chart integration** (`TradingChartView`).
- When the prototype is on in an isolated DEV launch, the real chart gives faces to Analysis, Question and Setup, historical markers included, as well as Personal. It does this through the Stage 1 store and renderer seam. `MarkerAvatarPresentation.live` is decided once per launch.
- When the prototype is off, and in every production configuration, the chart is unchanged.
- The switch is now read once per launch (`MarkerAvatarExperiment.isEnabled` is a `static let`) because marker badges read it in view bodies. A changed saved switch applies on the next launch.

**Intent badge** (`TradingChart/Models/MarkerIntentBadge.swift`, drawn in `ChartMarkerSystem`).
- A 14pt badge sits on the side away from the candle, mirroring the like badge. It uses existing TG iconography and colours: Analysis `waveform.path.ecg` in analysis teal, Question `questionmark` in question blue.
- Setup shows its lifecycle, with the existing `RLTrackingState` icons and colours:
  - untracked: draft pencil, grey
  - armed: radio waves
  - live: bolt
  - TP hit: check, TP colour
  - SL hit: cross, SL colour
  - expired: clock
- A resolved `predictionResult` wins over a stale tracking state.
- The badge's rectangle is included in `badgeRects`, so connectors route around it. Hit testing is unchanged and remains disc-only.

**Rings.**
- At rest, one restrained ring in the intent colour (1.25pt, 0.7 opacity) replaces the glass stroke.
- When a marker has a relationship ring (it is a member of the focused branch, or the parent of a response being placed), the relationship ring replaces the intent ring. Colours, patterns, routing, focus and navigation are untouched.
- The precedence rule is `MarkerIntentRing.strokeColor`, and it is unit-tested.

**Component arcs**, on the selected marker only.
- Up to three separated arcs sit 3.5pt outside the disc, in fixed order and fixed slots on the left and outward rim, the only stretch no badge uses:
  - indicators, in `componentIndicatorOrange`
  - drawings and supporting levels, in `componentSupportPurple` (text notes and reaction emoji excluded since the correction below)
  - timeframes and links, in `componentTimeframeCyan`
- Repeated components are grouped into one arc. The anchor and Setup Entry/SL/TP never produce an arc.
- Arcs fade in with the selection pop and drop to 0.4 opacity under a relationship ring, which stays authoritative.
- Entry/SL/TP lines are still drawn only during creation and selection; that code is unchanged.

**Shared SwiftUI marker badge** (`UnifiedMarkerBadge`).
- The same intents get the face, with a matching intent pip at 45° top-right. This covers lists, the info box, marker detail, the placement hero and the ghost.
- `MarkerAvatarIdentity` now carries the author id and Setup status. The badge prefers the avatar directory over the snapshot, as chat avatars do, and honours removals.
- The intent-picker cards still pass a face only for Personal, so the type picker keeps its glyphs.

**Personal markers** keep their current presentation: a face, with no badge, ring or arcs.

**Density** is unchanged, as the plan requires.

**Fixtures.**
- Markers can carry components (typed only).
- New scene "Selected: component arcs", with launch key `componentArcs`.
- The intents and relationships scenes carry context.
- A SwiftUI badge strip opens with `-MarkerFixtureSection badges`.

## Tests

The new `MarkerIntentDecorationTests` suite covers:
- which intents get a badge, and the Setup lifecycle mapping (including a result overriding a stale state, and untracked looking different from live)
- ring precedence
- which markers wear decorations, with the experiment on and off
- arc grouping, fixed order and structural exclusion
- badge clearance from the glyph's own like and response badges, and from the outward stack neighbour's disc and like badge, at rest and selected, above and below the candle
- arc slots never running under a badge, above and below
- the intent badge as a connector obstacle, both at the router's `contains(_:clearance:)` predicate and through `MarkerLinkGeometry.route`
- pixel differences through the real renderer:
  - an indicator adds exactly one arc, inside its band and slot, above and below
  - Setup levels and the anchor add nothing
  - arcs never appear unselected

In `MarkerAvatarRenderTests`:
- Face-bounds and uprightness are now measured on Personal. It is the same avatar path, and the new intent badge would otherwise sit over the measured corner.
- Added: Analysis, Question and Setup wear the face when the prototype is on.

| Command (simulator iPhone 17 Pro, iOS 26.0; `CODE_SIGNING_ALLOWED=NO`; `ONLY_ACTIVE_ARCH=YES` for tests) | Result |
|---|---|
| `xcodebuild test`, `LinkedDev` (DevDebug), `-only-testing:traders_guildTests`, final source | **757 tests passed (768 runs); 0 failed, 0 skipped** |
| `xcodebuild test`, `Local Gateway` (plain Debug, not isolated): experiment, decoration, render and identity suites | 35 tests passed (46 runs). The gate is off and live intents are `[.personal]` |
| `xcodebuild build`, `LinkedDev Profile`, `DevProfile` | BUILD SUCCEEDED (`-O -wmo`) |
| `xcodebuild build`, `GCP Public Prod`, `Release` | BUILD SUCCEEDED. `strings` finds 0 fixture strings and 0 `TGAvatarMarkersExperiment`, which is supporting evidence only (see the gate statement in the correction section) |

The first Stage 2 run failed four tests.
- One was real: the mirrored indicator arc slot came within the 1pt margin of the response badge for markers below the candle. The slots were narrowed to 167–203°, 215–251° and 263–299°.
- Three were in the tests:
  - angle normalisation for below-candle arcs
  - a connector control that assumed a straight route, when routes bow; it was rewritten as a predicate check plus a placed bystander
  - the Stage 1 bounds test, which was measuring across the new intent badge

## Visual evidence

Location: `docs/visual-review/v1.5-stage2/`. Captured in the isolated DevDebug simulator app with `-MarkerLinkFixtures -TGAvatarMarkersExperiment YES` unless stated otherwise. Every marker goes through the production `ChartMarkerSystem.drawMarkers` path.

| File | What to look at |
|---|---|
| `01-intents-idle-badges-rings.png` | Idle: one intent-colour ring each; outward badges (Analysis pulse, Question ?, live Setup bolt, untracked Setup pencil); like and response badges unchanged on the candle side |
| `02-intents-selected-analysis-three-arcs.png` | Selected Analysis with indicators ×2, a trendline and a timeframe: three separated arcs, fixed order and slots |
| `03-intents-selected-live-setup.png` | Selected live Setup: Entry/SL/TP make no arc; its indicator makes one |
| `04-selection-mid-animation-1.2.png` | Arcs fading in with the selection pop |
| `05`–`09-arcs-*.png` | The `componentArcs` scene with each marker selected: indicators only; drawings + links; all three; Setup levels only (no arcs); Setup levels + context |
| `10-setup-status-badges.png` | Untracked, armed, live, TP hit, SL hit, told apart at rest |
| `11-relationships-focus-ring-precedence.png` | Focus: relationship rings replace intent rings; the selected parent's arcs are faint under the root ring; the unrelated marker is dimmed |
| `12-relationships-idle.png` | Same markers unfocused: intent rings back |
| `13-opposite-stacks-focus.png`, `14-dense-focus.png` | Routing and badges in stacks, faces and badges together |
| `15-same-candle-stacks.png`, `16-adjacent-candles.png`, `17-zoomed-out.png` | Density with badges and rings; unchanged layout |
| `18-avatar-states.png` | Stage 1 identity states with Stage 2 decorations |
| `19-mixed-legacy.png` / `20-mixed-legacy-experiment-off.png` | Only the three intents are decorated; Personal is a plain face; experiment off is the legacy chart |
| `21-swiftui-badges-experiment-on.png` / `22-swiftui-badges-experiment-off.png` | The shared SwiftUI badge: faces and matching pips (Setup live, untracked, TP, SL); Personal plain; Alert glyph. Off: glyphs |

## Not verified

- **Live chart against real data.** No local backend is running (`127.0.0.1:30080` unreachable), and starting backend services is outside this assignment. The live integration is two lines through the same renderer and store the fixtures exercise; it compiles and is covered by the gating tests. The owner's visual review on the real chart (LinkedDev on device with local DEV) is still to do before Stage 3.
- **Performance.** Unmeasured, as planned for Stage 5. Per-frame additions for decorated markers: one stroke, one badge fill, and one glyph drawn from a per-pass cache. For the selected marker only, up to three arc strokes.

## Known issues

- ~~On a selected marker with jump badges, the parent-jump tether starts under the intent badge's outer corner.~~ Fixed in the correction below.
- Stage 1 issues still open: the selection-nudge 6pt overlap, and the two initials styles. Stage 1's "all Setup states look alike" is resolved by the status badges.
- ~~Thesis rows show glyphs.~~ Fixed in the correction below. The original note was also inaccurate: the rows already used `UnifiedMarkerBadge`, just without an author identity.
- The Add-marker rows already passed the viewer's avatar to every intent. With the prototype on, Analysis, Question and Setup rows show the viewer's face plus a pip. Stage 3 replaces that screen.
- Adjacent-candle density is unchanged by design. Faces overlap as glyphs do (see `17-zoomed-out.png`).

## Correction after Astra's review (separate commit)

### Changes

1. **Parent-jump tether no longer runs under the intent badge.**
   - `MarkerTimeframeJumpLayout.tethers(_:clearOf:)` moves only a tether's start, along its own line, to just past a given rectangle.
   - The renderer passes the selected glyph's intent-badge rectangle, and only when that glyph wears the prototype decorations.
   - Badge centres are untouched, so placement is unchanged. `timeframeJumpAtLocation` still resolves against the untrimmed `placements(...)`, so tap targets are unchanged.
   - With the experiment off (no rectangles) the placements come back unchanged, so experiment-off geometry is identical.
2. **Thesis rows show the author's face** for Analysis, Question and Setup while the prototype is on.
   - New `MarkerAvatarIdentity.forPreview(_:avatarIntents:)`, passed to `UnifiedMarkerBadge` in `MarkerThreadRowView`.
   - It uses only data already in the thread contract: `RLMarkerLinkPreviewDTO.authorId`, `authorUsername`, `authorDisplayName` and `authorAvatarUrl`. The deployed baseline `1ec0885` fills these in `shared/services/marker_links.py`, and the client reads them read-only.
   - The preview carries **no tracking state**, so a thesis-row Setup shows the neutral Setup badge (`.unknown`, green `scope`). Astra confirmed this is correct: **no contract change**.
   - Personal, legacy intents, unavailable nodes, and every row with the experiment off keep their existing glyph.
3. **Arc grouping matches the plan.** The drawings group is "drawings and supporting levels", so `textNote` and `reactionEmoji` no longer produce an arc. No existing documented requirement supported including them.
4. **Fixtures:**
   - New scene `timeframeJumps` with a parent and a response jump, selectable above (1) or below (2) the candle.
   - Thread-preview fixtures carry author ids and avatars, with mixed intents including a legacy News row.
   - `-MarkerFixtureSection thread` opens on the thesis rows.

### Production gate, stated precisely

Outside `TG_ISOLATED_DEV`, `MarkerAvatarExperiment.evaluate()` compiles to `return false`, so `isEnabled` and `MarkerAvatarPresentation.live` are `false` and `[.personal]`. The fixture gallery entry is compiled only under `DEBUG || TG_ISOLATED_DEV`.

The experiment is therefore **unreachable** in production configurations. It is not absent: shared helpers are compiled in but never enabled, among them:
- `MarkerAvatarPresentation`
- `MarkerIntentBadge`
- `MarkerComponentArcs`
- the renderer's decoration branches
- `forPreview`

Evidence:
- The Stage 2 plain-Debug run (`/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/rb-s2-debug.xcresult`) exercises the non-isolated branch of `evaluate()`.
- The Release build succeeds.
- The `strings` result is supporting evidence only.

### Tests added

All in `MarkerIntentDecorationTests`:
- `tethersStartPastTheIntentBadgeWithoutMovingJumpBadges(isBelow:)`, above and below the candle.
  - Control: the untrimmed parent tether does cross the badge.
  - After trimming: no tether point lies inside the badge, and more than 6pt of tether remains.
  - Badge centres and tether ends are unchanged; the response tether is identical; tap resolution is identical.
- `withNothingToClearTethersAreUnchanged`: the experiment-off geometry.
- `arcsGroupRepeatsKeepAFixedOrderAndSkipStructure` now also asserts that text notes and reaction emoji make no arc.
- `thesisRowsGetTheAuthorsFaceForThePrototypesIntentsOnly`:
  - For the three intents: author id, URL and initials come from the preview, Setup status is `.unknown`, and the experiment-off result is `.none`.
  - Personal, legacy and unavailable nodes get `.none`.

### Verification (bounded, as requested)

| Run | Result | Evidence |
|---|---|---|
| `xcodebuild test`, scheme `traders_guild LinkedDev` (DevDebug), simulator iPhone 17 Pro `9B8DAACB-DB63-4F23-A75B-3BC6C52E5705`, `ONLY_ACTIVE_ARCH=YES`, `-only-testing:` MarkerIntentDecorationTests, MarkerTimeframeJumpTests, MarkerAvatarRenderTests, MarkerGeometryInvariantTests, MarkerAvatarIdentityTests, MarkerLinkRenderTests, MarkerFocusHitTestingTests | **96 tests passed (108 runs), 0 failed, 0 skipped** | Bundle `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/rb-s2c-affected.xcresult`; log `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/s2c-affected.log`; exported copies in-repo: `docs/visual-review/v1.5-stage2-correction/test-results/affected-suites-summary.json` and `affected-suites-tests.json` |
| `xcodebuild build`, `GCP Public Prod`, `Release`, generic iOS Simulator | BUILD SUCCEEDED | `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/s2c-release.log` |
| `xcodebuild build`, `LinkedDev Profile`, `DevProfile`, generic iOS Simulator | BUILD SUCCEEDED (`-O -wmo`) | `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/s2c-devprofile.log` |

The full unit target was not re-run for this bounded correction. The last full run is the Stage 2 final: 757 tests / 768 runs passed, bundle `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/rb-s2-final.xcresult`. That bundle, and the plain-Debug bundle `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/rb-s2-debug.xcresult`, predate this correction.

The scratchpad bundles live in a session temp directory and may be cleaned up. The exported JSON in the repo is the durable copy.

### Screenshots

Location: `docs/visual-review/v1.5-stage2-correction/`. Built from the same DevDebug product the tests ran against.

| File | Shows |
|---|---|
| `01-jump-tethers-above-candle-selected.png` | The 4H parent tether starts past the Analysis badge; the 15m response tether and both jump badges are unchanged |
| `02-jump-tethers-below-candle-selected.png` | The same below the candle, with a live-Setup (bolt) badge |
| `03-jump-tethers-experiment-off.png` | Experiment off: glyph, no intent badge, untrimmed tethers (original geometry) |
| `04-thesis-rows-experiment-on.png` | Thesis rows: Setup face with the neutral Setup pip, Analysis face with pulse, Question initials with ?, News glyph and the unavailable row unchanged |
| `05-thesis-rows-experiment-off.png` | Thesis rows with the experiment off: all glyphs, as before |
