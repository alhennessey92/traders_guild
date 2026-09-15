# Response / timeframe fixes — simulator UI review

Date: 2026-09-14. Reviewing Codex's 12 response-only files as copied into
`.worktrees/linked-markers-claude` (manifest `/tmp/linked-response-review-files.txt`).
These copies and the earlier `ChartBodyBoundary` copies stay **uncommitted**;
nothing in Codex's tree or the connector commits is touched.

Build: `traders_guild LinkedDev Profile` scheme, **DevProfile**, iPhone 17 Pro
simulator (`9B8DAACB-…`), gateway `http://127.0.0.1:30080/api/v1`. No physical
device, no user Xcode.

Status: **complete** (2026-09-14 19:22 local). All five UI checks done on the refreshed sources; one disposable response submitted and read back from the server.

Sources under test: the review copies were refreshed from Codex's tree after the preliminary code
read (the 12 manifest files **plus** `ChartSettingsView.swift`), so the UI checks run against
Codex's corrections (loading release on failed/cancelled switch, `canShowRespondAction`
guild/symbol match, submitted-anchor normalisation via `resolvedAnchorTime`, banner editing
disabled while loading, settings card gated on `linkedMarkersEnabled`). Base check: every copied
file's committed base is identical between the two trees except `TradingChartView.swift`, whose
Codex base additionally carries the already-integrated `ChartBodyBoundary` + connector-wiring
hunks — both of which were already present uncommitted in this tree.

## 1. Code read of the changed state-loading path

Read: `ChartViewModel.loadChartData` / `prepareChartContext` / `loadNavigationWindow`,
`MarkerPlacementState` response-timeframe change API, `ChartBottomSheet.selectPlacementTimeframe`,
`TradingChartView` (`effectiveCandleIndex`, `handleTimeframeChange`, `handleCandleCountChange`,
`initializeLatestPositionIfNeeded`, `focusResponseAnchor`), `MarkerResponseAnchorResolver`,
`MarkerViewingGeneralTab` deferred `onRespondToMarker`.

**Sound:**

* `loadChartData` now returns `Bool` and re-checks generation / account / symbol / guild /
  timeframe after the await, on both the success and the catch path. Every early return is
  `false`, and the trailing return re-verifies the context, so a stale completion can no longer
  report success. `prepareChartContext` sets `currentTimeframe` synchronously before the await,
  which is what makes `isCurrentChartContext` meaningful and what fires the chart's
  `handleTimeframeChange` (deliberately short-circuited while `isChangingResponseTimeframe`).
* Request identity (`responseTimeframeChangeID`) is checked in `selectPlacementTimeframe` after
  *both* awaits and again inside `finishResponseTimeframeChange`, so a cancelled or superseded
  change cannot clear a newer one's loading flag. `beginRespondingTo`, `removeLink` and
  `endLinkSession` all clear it.
* `isValid` is false while loading or after a failed load, so the Place button cannot submit a
  draft whose chart context is not the one the anchor was resolved against.
* `MarkerResponseAnchorResolver.index` is a correct lower-bound binary search with an
  interval-membership check (`start ≤ t < start + tf`, calendar month for `1M`), returning `nil`
  for unloaded history rather than clamping to the nearest visible candle. In `effectiveCandleIndex`
  the ghost follows `anchorDraft.anchorTime`, and `persistPreviewMarkerDragIfNeeded` rewrites that
  time on drag-end, so dragging the ghost in a response still moves it.
* Deferring `onRespondToMarker` to the picker sheet's `onDismiss` is the right fix for the
  "Builds on does nothing" symptom: the presenting view is no longer torn down while its sheet is
  mid-dismissal.

**Concerns raised on the first copy — status after the refresh:**

* **C1 — chart left in a loading state after a failed timeframe change.** `handleTimeframeChange`
  sets `hasInitializedPosition = false; isChartLoading = true` and then returns early for a
  response change; `handleCandleCountChange` also returns early. Only `focusResponseAnchor()`
  (success path) sets them back. On `finishResponseTimeframeChange(succeeded: false)` nothing
  does, and `initializeLatestPositionIfNeeded` is never re-run. Because `loadChartData`'s catch
  path leaves the previous candles in place, `shouldShowLoadingOverlay` (`isChartLoading &&
  !candles.isEmpty`) stays true and `requestOlderCandlesIfNeeded` (guarded by `!isChartLoading`)
  is blocked. A successful retry recovers it; cancelling the draft after a failure does not.
  Suggested: on a failed change (and on `endLinkSession`/`removeLink` while a change is
  outstanding), the chart should run the ordinary `initializeLatestPositionIfNeeded()` +
  `isChartLoading = false` path — or `finishResponseTimeframeChange` could expose the failure via
  a published value the chart observes.
  **Addressed in the refreshed copy:** `withPlacementObservers` now has
  `.onChange(of: placementState.isChangingResponseTimeframe)` that runs
  `initializeLatestPositionIfNeeded()` + `isChartLoading = false` when the flag drops while the
  chart is still marked loading (success has already centred synchronously by then, so it no-ops).
  Correction to my first note: `loadChartData`'s catch path *does* clear candles; it is the
  navigation-window failure that retains them — the onChange covers both.
* **C2 — spurious failure from an unrelated concurrent load.** `chartLoadGeneration` is bumped by
  *every* `loadChartData`, including the realtime resync (`mergeWithExisting: true`) and
  `retryChartDataLoad`. If one of those fires during the response change's fetch, the change is
  reported as "Couldn't load this timeframe" even though the chart ends up correctly loaded.
  Rare (needs a reconnect/staleness resync inside a ~1s window); accepted by Codex as
  conservative failure + retry.
* **C3 — silent no-op.** `beginRespondingToSelectedMarker` now guards on guild/symbol match and
  `linkedMarkersEnabled`; `canShowRespondAction` in the sheet only checks
  `linkedMarkersEnabled` and visibility. A viewing sheet for a marker on a different symbol/guild
  would show *Respond*, dismiss the picker, and do nothing. Edge case; align the two predicates.
  **Addressed in the refreshed copy:** `canShowRespondAction` now also requires guild and symbol
  match.
* Minor: `handleCandleCountChange`'s early return also skips the `predictionPlacement` re-pin
  and the `abs(newCount-oldCount) > 10` reset — intended, but it means a response with `.setup`
  intent is not re-pinned to the latest candle on the new timeframe until the next candle event.

## 2. UI checks

**Fixture note (backend data, not an iOS finding).** On local DEV the 1m candle series for the QA
BTC/USD symbol ends at `2026-09-10T22:39Z` (`/chart/symbols/{id}/candles?timeframe=1m` returns
nothing later, with or without `end_time`), while 5m/1h/4h are current. The owner's alert
`4213a6da…` (1m, `2026-09-12T06:40Z`) therefore has **no 1m candle** here: navigating to it from the
markers list runs to completion but lands on Thursday 22:40 with an empty viewport
(`N01-owner-alert-navigation-lands-in-1m-gap.png`). That is pre-existing navigation behaviour for a
marker in a data gap and out of scope; the practical consequence is that the owner's alert cannot
be used for a clean 1m→4h check on this backend, so the checks below use disposable QA alerts
placed on candles that exist (the user allowed "or create your own disposable alert").


Signed in as the QA owner account (`linkqa-…-0`, guild *Linked Markers QA d1f509e3*), BTC/USD.
Disposable fixtures created: **one** parent alert `ce18fbfa-edb2-493a-bd4c-915d42fff772` (1m,
Warning, candle `2026-09-14T18:12Z` — a realtime 1m candle, which is exactly the shape of the
owner's alert) and **one** response `114881f0-c195-43af-af87-9540ee8ddebf`. The deep/wide fixture
and the owner's alert were only read. Console captured for the whole session
(`launch-console.txt`, 102 lines): zero `fatal|EXC_BAD|crash` matches.

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Open alert → *Respond with marker* → **Builds on** (third row) enters draft | **Pass.** Picker presents at the new 430pt detent with all three rows and Cancel visible; choosing *Builds on* dismisses the picker and, on dismissal, the chart is in *Place a Marker* with the ghost stacked on the parent candle, the link banner "Builds on linkqad1f509e30's marker · Shared with the guild", and the new *Response timeframe 1m* control directly under the banner. Repeated once more later with *Supports* on the response marker — same clean handover (R14). | `R01`, `R02`, `R03` |
| 2 | Add note; *Response timeframe* 1m → 4h; note/link kept; chart recentres on containing parent candle | **Pass.** Severity *Informational* + a 45-char note entered; menu (`R04`) shows 1 Minute ticked; choosing *4 Hours* reloads and the panel shows **4H** with note, severity and banner untouched and Place still enabled (`R05`). Chart: **4H** chip, ghost on the `14 Sep 17:00` local (= `16:00Z`) 4h candle — the candle containing the `18:12Z` draft anchor — checklist 4/4 (`R06`). Centring is clamped by the newest-candle limit because that 4h candle *is* the latest one; the candle is fully visible, so this is the correct outcome, not a miss. Menu reopened afterwards shows the tick moved to *4 Hours* (state-consistent). | `R04`, `R05`, `R06` |
| 3 | Submit ONE disposable response; verify server | **Pass.** `GET /chart/markers/114881f0…`: `parent_marker_id = ce18fbfa…`, `link_relationship = builds_on`, `timeframe = 4h`, `candle_timestamp = 2026-09-14T16:00:00Z`, anchor component payload `time = 2026-09-14T16:00:00Z` (the submitted anchor was normalised to the containing 4h candle, not left at the 1m draft time `18:12Z`), note text intact, `visibility = guild`. Parent: `direct_response_count 0 → 1`, `has_responses false → true`. Thread endpoint lists the node at depth 1 with `builds_on`/`4h`. On the chart the response renders on the 16:00Z candle with the builds-on badge (`R12`); its sheet reads "Builds on Alex Link QA's Alert" (`R13`). | `R11`, `R12`, `R13`, API output in §3 |
| 4 | Cancellation clears context | **Pass.** Started a second response (*Supports*) on the response marker (`R14`), cancelled with ✕ → idle chart (`R15`); an ordinary *Add → Alert* placement afterwards shows **no** link banner, **no** *Response timeframe* control, empty note (`R16`). Cancelled that too; nothing was created (server count still 1). | `R14`, `R15`, `R16` |
| 5 | Failed load / retry keeps draft, blocks invalid submission | **Pass — exercised for real, not simulated.** Local DEV has no persisted 1m candles after Sep 10 22:39Z, so switching the 4h draft to *1 Minute* loads a 1m window that cannot contain the `18:12Z` anchor. Result: red banner in the link card "Couldn't load this timeframe. Your draft is saved; choose the timeframe again to retry.. Your response is still here — try again.", control shows **1m**, note/severity/link untouched (`R07`). Tapping Place did nothing and the server count stayed 0 (`R08`). Chart after failure: 1m at latest, **no stuck loading overlay** (Codex's `isChangingResponseTimeframe` onChange release verified), checklist 3/4 with *Placement requirements met* amber, ghost hidden because the anchor is unresolvable (`R09`). Retry by choosing *4 Hours* again: banner cleared, **4H**, draft intact, Place enabled (`R10`) — and the subsequent submit is the check-3 response. | `R07`, `R08`, `R09`, `R10` |

## 3. Findings

No blocker. Everything the owner reported (Builds-on from an alert failing to enter a draft;
timeframe switch losing the draft) is fixed on these sources, and the server-side result of the
switch is right (`4h`, anchor on the containing candle, link intact).

Two small things worth a follow-up, both cosmetic/UX, neither blocks:

* **F1 — double full stop in the failure banner.** `finishResponseTimeframeChange` records
  "…choose the timeframe again to retry." and `MarkerLinkViews.swift:438` renders
  `"\(failureMessage). Your response is still here — try again."`, producing "retry.. Your
  response…" (`R07`). Either drop the trailing period from the recorded message or have the view
  skip its own period when the message already ends with one.
* **F2 — Place button reads as ready while a switch has failed.** `placementBottomBarShowsMarkerColor`
  (`MainView.swift:3287`) keeps the button in marker colour whenever an alert severity is set, so
  after a failed load the button is fully coloured yet `isValid` is false; a tap does nothing
  because `unmetRequiredChecklistItems` has no tab to navigate to for this condition (`R08`).
  Submission is correctly blocked and the checklist row turns amber, but the affordance is
  misleading. Suggest the colour predicate also require
  `!placementState.isChangingResponseTimeframe && !placementState.responseTimeframeLoadFailed`,
  or make the dead tap re-surface the banner.

Observations, no action needed:

* After a failed switch the ghost is not drawn (anchor unresolvable on the loaded candles) — the
  draft is intact and the checklist explains; once the retry succeeds the ghost returns on the
  containing candle.
* Recentring on the containing candle is subject to the existing newest-candle pan clamp; when the
  containing candle is the latest one it sits at the right-hand resting position rather than dead
  centre.
* The 1m gap on local DEV (fixture note above) is why the owner's own alert cannot be centred on
  a 1m candle here; the alert I created shows the same shape (a 1m candle that exists only in the
  realtime stream), and the flow handles it: 4h/1h succeed, 1m fails cleanly with a retry.

## 4. Tree state

`.worktrees/linked-markers-claude` HEAD `1d53330`; working tree holds only the uncommitted review
copies (10 modified + 3 untracked from the manifest/ChartSettingsView refresh) and the earlier
`ChartBodyBoundary` copies (1 source + 1 test, untracked). Nothing committed, nothing in Codex's
tree touched. Build log: scratchpad `resp-build2.log` (**BUILD SUCCEEDED**, 0 errors).

## 5. Evidence

`/tmp/linked-response-ui-evidence/`: `N01-owner-alert-navigation-lands-in-1m-gap.png`,
`R01-alert-viewing-sheet.png`, `R02-respond-picker-430pt.png`, `R03-builds-on-enters-draft.png`,
`R04-response-timeframe-menu.png`, `R05-after-switch-to-4h-panel.png`,
`R06-4h-chart-recentered-on-parent-candle.png`, `R07-switch-to-1m-failed-load-panel.png`,
`R08-place-tap-while-failed-blocked.png`, `R09-1m-chart-after-failed-switch.png`,
`R10-retry-4h-panel-recovered.png`, `R11-after-submit.png`, `R12-4h-chart-with-response.png`,
`R13-response-viewing-sheet.png`, `R14-second-draft-supports-before-cancel.png`,
`R15-after-cancel.png`, `R16-plain-placement-after-cancel-no-link.png`, `launch-console.txt`.

Server read-back (verbatim from the API, ids only):

```
PARENT ce18fbfa-edb2-493a-bd4c-915d42fff772: direct_response_count 0 → 1, has_responses false → true
RESPONSE 114881f0-c195-43af-af87-9540ee8ddebf:
  parent_marker_id = ce18fbfa-edb2-493a-bd4c-915d42fff772
  link_relationship = builds_on
  timeframe = 4h
  candle_timestamp = 2026-09-14T16:00:00Z
  anchor component payload time = 2026-09-14T16:00:00Z, price = 79055.1466
  visibility = guild
THREAD /markers/ce18fbfa…/thread: node 114881f0… depth 1, builds_on, 4h, 2026-09-14T16:00:00Z
```

## 6. Owner follow-up (2026-09-14 evening): "Marker unavailable" when jumping from the response back to its parent

From the owner's device log (5m parent `55b98150…` at `2026-09-14T19:05Z`, 30m *supports* response
`21798e8c…` at `19:00Z`, then *open parent* from the response's sheet):

* Navigation ran correctly: symbol found, `Needs timeframe change: true`, 5m `chart-data` reloaded,
  centred, `MARKER NAVIGATION COMPLETE`. The failure is the **5 s `waitForMarkerForDetail`
  timeout** afterwards → `.failed("Marker data did not load")` → the "Marker unavailable" card
  (`MarkerNavigationHelper.swift:386-389`).
* Why the marker never arrived: the 5m marker fetch was
  `markers?timeframe=5m&start_time=2026-09-12T08:00Z&end_time=2026-09-13T17:15Z` → `[]`. That window
  is `candles.first…candles.last` of the chart-data response (`ChartMarkerSystem.swift:488-489`),
  and on local DEV the **persisted 5m series ends at `2026-09-13T17:15Z`** (verified via the API:
  400 candles, last `17:15Z`; 30m/1h/4h are current). The parent sits on `19:05Z` — a candle that
  existed only as the realtime-appended live candle when it was placed — so it is outside every
  window the 5m chart will ever request, and after any 5m reload it is simply not loaded.
* Same shape as the 1m gap in the fixture note above (1m ends `2026-09-10T22:39Z`). On this
  backend, any marker placed on a live-only 1m/5m candle disappears from that timeframe on reload
  and cannot be navigated to; 30m and coarser are fine, which is why the 30m response itself
  worked. Not caused by the response/timeframe changes under review.

Hardening worth doing on iOS regardless (Codex-owned files, so recommendation only):

1. `MarkerNavigationHelper`: if `waitForMarkerForDetail` finds nothing, fetch the target by id
   (`GET /chart/markers/{id}`, already used by the thread/preview path), insert it into the manager
   and select it, and only fail if that also fails. Navigation already knows the marker id; it
   should not depend on the window fetch happening to contain it.
2. `MarkerManager.loadMarkersFromAPI` (via `ChartViewModel.loadChartData`): let the newest page's
   `end_time` extend to `max(candles.last.timestamp, now)` (or omit `end_time` for the latest
   page) so a marker on the live candle — or on a candle the persisted series has not caught up to
   — is included. This also covers production's ordinary case of a marker placed on the
   in-progress candle by another member just before you reload.

Backend (local DEV only, owner's call): the 1m/5m candle writer is stale while 30m+ is live; the
navigation symptom goes away once 1m/5m persistence catches up to real time.

## 7. Implemented: navigation falls back to a by-id fetch — commit `6b96343`

Owner asked for it ("yes implement"). Files touched are outside the Codex-owned set
(`ChartMarkerSystem.swift`, `MarkerNavigationHelper.swift`, five test fakes, one new test file);
the copied response files and the `ChartBodyBoundary` copies remain uncommitted, so the commit
cherry-picks cleanly on top of `9f6f108`.

* `MarkerAPIClient.getMarker(markerId:)` — new protocol requirement; `RealAPIService` already had
  the method (`GET /chart/markers/{id}`). The five test fakes gained a throwing stub.
* `MarkerManager.loadMarker(id:candles:) async -> ChartMarkerUI?` — returns the loaded copy if
  present; otherwise fetches by id and positions it on the given candles with the same
  `calculatePositionForNewMarker` path the realtime create uses. Refuses another symbol/timeframe/
  guild, a private marker that is not ours, a layout context that changed in flight, and a
  timestamp with no loaded candle within tolerance (so it never invents a candle).
* `MarkerNavigationHelper.navigateToMarker` — when the 5 s `waitForMarkerForDetail` finds nothing,
  calls `loadMarker` against `dataManager.candles` *as they are now* (which by then include the
  live candle), re-checks the session, and selects the result. The failure phase is unchanged for
  the case where the by-id fetch also cannot place it.

**Only the second hardening from §6 was implemented, deliberately.** Extending the window's
`end_time` to "now" would not help on its own: `positionedMarkers` drops any DTO without a loaded
candle within 0.6 × median spacing, and at window-fetch time the live candle has not arrived yet.
The by-id fallback runs after the wait, when it has.

Tests: `MarkerLoadByIdTests` (6) — places a window-missed marker on the live candle, returns the
loaded copy without a fetch, refuses another timeframe/symbol, does not conjure a far-away candle,
hides someone else's private marker, and tolerates a failed fetch. Ran together with the five
suites whose fakes changed: **40/40 pass** (`nav-units.xcresult`).

Simulator proof (DevProfile, local DEV, persisted 5m series a day behind): created a 5m alert on
the *current* live candle (`5a9d50d5…`, `2026-09-14T21:30Z`) via the API while the app sat on 1M,
then tapped it in the Live Feed. Navigation 1M→5m, window fetch empty (its range ends
`2026-09-13T17:15Z`), `Candle count: 401`, and the marker is **selected on the live candle** —
`F01-nav-centering-live-candle-parent.png`, `F02-nav-result-live-candle-parent.png`,
`fallback-console.txt`. The owner's log for the identical shape ended in "Marker unavailable".

Limit that remains (backend): a marker whose candle is neither persisted nor the current live
candle — e.g. the owner's original 5m alert now that its 5-minute period has passed on this DEV
backend — still cannot be shown; nothing on the client can supply that candle.

Disposable QA rows created while reproducing (all in the QA guild, none on the deep/wide
fixture): `5f3454c0…` (5m alert, `21:20Z`), one 1M alert placed by a mis-tap during the timed
attempt ("QA parent two on live candle"), and `5a9d50d5…` (5m alert, `21:30Z`).

## 8. Owner follow-up 2 (device log, 21:35–21:40Z): "a little messed up"

Read against the API. Every symptom traces to the local-DEV candle data except one client gap:

* **Only one 5m candle showing** — persisted 5m ends `2026-09-13T17:15Z`; the live candle is the
  only current one. Also: every persisted 1m and 5m candle has the *same* close (`79055.1466`,
  1 distinct value in 400), which is why every response ever placed here carries that price —
  the draft seeds the centre candle's close, and on this backend that is a constant. Not a bug.
* **Response on 1m errored** — correct: no 1m candles since Sep 10, so the switch fails and the
  draft is kept (the path verified in §2 check 5).
* **"Both markers on 30m, the original in a random place"** — the second marker on 30m is
  `21798e8c…`, the *supports* response from the earlier session (30m, `19:00Z`, note
  "[Severe] Severe alert" — identical text to the new parent `940da9b3…`, so it reads as the
  original). The log shows its thread being opened (`GET /chart/markers/21798E8C…/thread`), with
  `55b98150…` as its parent. The new 5m parent never appeared on 30m; markers are per-timeframe.
* **"5m marker disappeared"** — on returning to 5m the marker window is the persisted range
  (`…→2026-09-13T17:15Z`), so `940da9b3…` at `21:35Z` is excluded even though its candle was
  still the live one. Same mechanism as §6. The navigation fallback (§7) covers *jumping to* it;
  a plain reload still loses it. Client hardening for that: end the newest window at "now" and
  keep DTOs whose candle has not arrived yet, positioning them in `recalculateCandleIndices`
  when it does. Offered, not implemented (each cycle costs; on production the gap is the
  persistence lag of seconds, on DEV it is permanent until the 1m/5m writer is fixed).

Owner feature idea (same message): an on-chart cross-timeframe affordance on the selected
marker, tappable, in both directions. Design sketch and the one Codex-side hunk it needs are in
the chat reply; not started.

## 9. Implemented: cross-timeframe jump badge — commit `3a1253a`

Owner asked for a circular, time-flavoured glyph close to the selected marker that jumps to a
linked marker on another timeframe, in both directions.

* **Model** `Models/MarkerLink/MarkerTimeframeJump.swift`: `MarkerTimeframeJump` (target id,
  direction, relationship colour, timeframe, `others`, preview), `MarkerTimeframeJumpResolver`
  (parent from `parentPreview`; most recent response elsewhere from the thesis window; anything
  `MarkerNavigationTarget(linkPreview:)` would refuse is left out), `MarkerTimeframeJumpLayout`
  (level with the glyph, parent right / response left, standoff 22pt, hit radius 18pt, reveal
  tied to the selection pop).
* **Manager** (`MarkerManager+Links.swift`, `ChartMarkerSystem.swift`): `timeframeJumps`
  (derived on read), `loadThreadForTimeframeJumps()` on selection of a responded-to marker
  (through the store, generation-guarded, no-op if the sheet already loaded it),
  `timeframeJumpAtLocation(...)` hit-test and `performTimeframeJump(...)` (stages the selection on
  the thread store, then the same `MarkerNavigationHelper` path the sheet uses; the by-id fallback
  from §7 covers the landing).
* **Renderer** (`MarkerLinkRenderer.drawTimeframeJumpBadges`): 22pt disc in the relationship
  colour, target timeframe label in the middle, a 300° arrow ring outside it — clockwise down to
  a response, anticlockwise up to a parent — over a faint halo for legibility; drawn after every
  glyph, never during placement.
* **TradingChartView** (Codex-owned; applied uncommitted here, patch at
  `/tmp/linked-crosstf-jump-TradingChartView.patch`, 2 hunks): pass
  `timeframeJumps: markerManager.timeframeJumps` into `drawMarkers`, and check
  `timeframeJumpAtLocation` before `findMarkerAtLocation` in the marker tap gesture.

Tests: `MarkerTimeframeJumpTests` (10) — parent elsewhere / same timeframe / tombstone, newest
response elsewhere with `others`, no window → no response badge, both badges on a middle node,
placement geometry (level, clears the glyph ring and both existing badges), hit radius, reveal.
Ran with the neighbouring marker-link suites: **110/110**.

Simulator (DevProfile, local DEV): disposable pair `e70c0fcf…` (30m alert, 20:00Z) ⇄
`7376a409…` (1h, builds_on). From the feed to the 30m parent → teal **1H** badge to its left
(`J01`); tap → 1H chart, response selected, **30m** badge to its right (`J02`); tap → back on 30m
with the parent selected (`J03`). Three navigations in `jump-console2.txt`, no crash lines.
First-pass layout was diagonal-up and collided with the info card when the glyph sat above the
candle; moved level with the glyph before committing.

Not done: a count on the badge when several responses live on other timeframes (`others` is
carried but not drawn — the sheet lists them); a badge for responses whose thesis window has not
loaded yet (deliberate, see resolver doc).

### The other error — DEV or production?

DEV. Persisted 1m ends `2026-09-10T22:39Z` and 5m ends `2026-09-13T17:15Z` on local DEV while
30m/1h/4h are current; every symptom in §8 except the client gap follows from that, and the client
gap (a marker on a live-only candle vanishing on reload) needs persistence to lag the live stream,
which production's writer does not do beyond seconds. The by-id fallback (§7) covers navigation
even then. Not implemented: keeping unpositionable DTOs pending until their candle arrives —
offered if wanted for DEV testing comfort.
