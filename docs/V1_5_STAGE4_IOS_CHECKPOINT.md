# v1.5.0 Stage 4 checkpoint: local DEV iOS integration (Claude)

Branch `claude/1.5.0-avatar-markers`, continuing the accepted `b10ed51`. Worktree `.worktrees/marker-avatar-claude`.

**Commits:** local commits, not pushed, not deployed. No backend, Android or production changes by Claude.

| Commit | What |
|---|---|
| `c4ecb14` | Fix: a guided text-only Analysis stays editable. Includes tests. Integrated by Astra as `8e0686d`. |
| `05f5d00` | Fix: the guided discard confirmation is presented from the chart sheet. The old placement crashed the app. Integrated as `0550b73`. |
| `076fb52` | The first version of this checkpoint and its evidence. Integrated as `5f71c93`. |
| `2e8750e` | Approved correction: guided tracked Setup level integrity (§5a). Includes tests. |
| this commit | This checkpoint, updated for the correction, and its evidence. |

**Stop point.** This is an engineering checkpoint for Astra. Stage 5 has not started.

**Setup level-ordering defect: corrected, pending Astra's engineering review.** The owner approved a bounded correction (`docs/V1_5_SETUP_GUARD_CORRECTION.md`). The defect, its reproduction and its baseline are kept in §5 as found. The correction and its verification are in §5a. The existing invalid records are evidence and were not repaired.

`$S` = `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad`. All times are UTC unless marked otherwise. The app's clock labels are BST (UTC+1).

## 1. Local runtime: source, config, migration, ownership

**Stack.**
- Compose project `traders-guild-local`, run from `.worktrees/linked-markers-backend`:
  - `0055fbb`, clean
  - `docker-compose.yml` + `docker-compose.safe.yml` + `.env.local` (mode 600, never printed)
- One extra override kept outside both backend trees: `$S/stage4/compose.stage4-780398f.yml`, replaced for the correction by `$S/stage4/compose.stage4-5061824.yml` (same content, new snapshot path and label).
- Before this stage the stack was stopped. Only TimescaleDB was brought up, for the read-only inventory. No running stack was replaced.

**Backend source now running: Sol's tracked-Setup guard `5061824`.**
- chart-service is recreated from `$S/backend-5061824`, a `git archive` snapshot of `50618244942df1669bff626e8315e312fb502194` (checkpoint `f2e78dc`), mounted read-only.
- Label `co.tradersguild.stage4.source=50618244…`, both mounts `rw=false`.
- `sha1(/app/shared/schemas/chart_schema.py)` is `b4926289…` in the container, the snapshot and `git show 5061824:shared/schemas/chart_schema.py`.
- chart-service `app/` is identical to `780398f`, and `requirements.txt` and `Dockerfile` are unchanged, so no rebuild. `780398f..5061824` changes only `shared/schemas/chart_schema.py` at runtime.
- Flags after the swap are unchanged (linked markers on; Discord, autopost and postback off). Both smokes pass.
- Revert to the text-only-only runtime: the same `up -d --no-deps chart-service` with `compose.stage4-780398f.yml`.

**Backend source used for §2–§4 (before the correction).**
- chart-service `/app/app` and `/app/shared` are bind-mounted **read-only** from `$S/backend-780398f`. That is a `git archive` snapshot of Sol's accepted `780398f936e3fc877ac23700f4d2c94b5c9d502c`.
- Sol's working tree was never mounted or edited. Its later commits are documentation only: `c855879`, and the correction `be26788` that records migration head `m1n2o3p4q5r6`.
- Proof of what is mounted:
  - container label `co.tradersguild.stage4.source=780398f…`
  - both mounts are `rw=false`
  - `sha1(/app/shared/schemas/chart_schema.py)` is `8762690d…` in the container, in the snapshot and in `git show 780398f:shared/schemas/chart_schema.py`
  - only the Analysis rule "requires a description" remains
- Other services still run `0055fbb` source. Between `0055fbb` and `780398f` the only runtime difference is `shared/schemas/chart_schema.py`; the rest is tests, admin views, local infra, and a migration tweak under the same revision id.
- chart-service `requirements.txt` and `Dockerfile` are unchanged, so no image was rebuilt.

**Config.**
- `LINKED_MARKERS_ENABLED=true` on chart, core and realtime, set in the override. The default is false. Earlier linked-marker QA ran with this setting, and linked markers are live in production.
- Outbound channels, verified inside the containers:
  - off: Discord webhooks, autopost, postback, digest, registration alerts, Google sign-in, FCM
  - empty: APNs key and Resend key
- `trading_symbols` holds one row, BTC/USD, active.
- `make smoke-compose` and `make smoke-gateway` pass before and after the swap.

**Migration.** None was needed. The database is at `m1n2o3p4q5r6`, the source head. There was no reset, wipe or reseed, and the named volumes are preserved.

**Ownership and revert.**
- I own this running stack for Stage 4. It is still up with the override applied.
- To revert, run this from `linked-markers-backend`:
  `docker compose --env-file .env.local -f docker-compose.yml -f docker-compose.safe.yml up -d --no-deps chart-service core-service realtime-service`
  That restores the `0055fbb` mounts and `LINKED_MARKERS_ENABLED` to its default.

**Local data created (local DEV only).**
- **Accounts:** two disposable accounts, `stage4658f08a` and `stage4658f08b`, both `@example.com`.
  - Registered through the local gateway. The API rejects `.invalid` as reserved.
  - `is_verified` was set directly in the local DB, for those two rows only, because verification mail is disabled locally.
  - Credentials are in `$S/stage4/qa-creds.json` (mode 600) and were never printed.
  - Passwords were entered through the simulator pasteboard, which was cleared after each use.
- **Guild:** open guild "Stage4 QA 658f08" (`199155c3-22f3-4f07-b7f4-664ba560a14e`), with A as owner and B as member.
- **Markers in that guild:**
  - `dd02fc7f` (B, created via the API)
  - `3895ba9d`, `69aff9b5`, `6fa2782b`, `772cfd7a` (A, created in the app)
  - for the correction (§5a): `f65276b9`, `3f0fbe6a`, `5028f408`, `499bf540` (B, via the API) and `e2641cfc` (A, in the app)
- **Marker in the existing QA guild:** `66bf3fc6` in "Linked Markers QA d1f509e3", posted by the restored `linkqad1f509e30` session.

## 2. Backend real-Postgres gate (local DEV)

`test_text_only_analysis_linked_create_and_update_keep_response_event_shape` **passed: 1 passed, not skipped.**

**Setup.**
- Run from the `780398f` snapshot, using `traders-guild-backend/venv` (Python 3.13.3, pytest 9.0.3, SQLAlchemy 2.0.36).
- `LINKED_MARKERS_TEST_DATABASE_URL` was built inside the command from `.env.local` and never printed.

**Isolation.** The fixture wraps all writes in an outer connection transaction and rolls it back. Under SQLAlchemy 2.0's default join mode, a session `commit()` does not commit that outer transaction. Row counts before and after are identical:

| Table | Rows |
|---|---|
| users | 11 |
| guilds | 3 |
| memberships | 10 |
| symbols | 1 |
| markers | 379 |
| components | 406 |

**Evidence.**
- Log: `$S/stage4/pg-text-only-analysis.log`
- `docs/visual-review/v1.5-stage4/test-results/pg-text-only-analysis.junit.xml` (hostname stripped)
- `pg-test-row-counts.txt`

## 3. Real app results

**Setup.**
- Isolated DEV build: `traders_guild LinkedDev`, DevDebug, bundle `co.tradersguild.app.linkeddev`, with `-TGAvatarMarkersExperiment YES`.
- Simulator: iPhone 17 Pro `9B8DAACB-DB63-4F23-A75B-3BC6C52E5705`, against `http://127.0.0.1:30080/api/v1`.
- Server results are read from access logs and the DB. Screenshots are in `docs/visual-review/v1.5-stage4/`: 2/3-scale JPEGs, with full-resolution originals in this session's tool-results.

| Check | Result | Server / DB evidence | Captures |
|---|---|---|---|
| Text-only Analysis create | **Pass** | POST 200 at 15:11:40. `66bf3fc6` stored as `analysis`, components `[anchor]`, thesis only. | 01–07, 10, 12–14 |
| Ghost and anchor drag on the real chart | **Pass** | Face moved 4 candles and re-seated above that candle; guide followed. | 02, 03 |
| Sheet detents | **Pass** | Low detent keeps chart and ghost visible; large detent shows the full Details step. | 04–06 |
| In-flight lifecycle, real network | **Pass** | chart-service `docker pause` 15:11:25–15:11:40. Shows "Posting…"; Edit, Post and close were inert when tapped. After unpause: POST 200, placement closed, share prompt shown. | 08–11 |
| Share-prompt handoff | **Pass** | The real `MarkerSharePromptSheet` appeared after a create, after a retry, and for an untracked Setup. Dismissed with "Not now"; no external destination tapped. | 11, 27, 38 |
| Text-only Analysis edit | **Failed → fixed (`c4ecb14`) → Pass** | Before: 0 PUTs sent; Save routed to Components (2/4). After: 3/4, PUT 200. `69aff9b5` note updated, components still `[anchor]`. | 15, 16 → 30, 31 |
| Question validation | **Pass** | "Breakout?" (9 characters): hint "Write at least 10 characters", Review disabled, face badge shows "?". | 28 |
| Linked response, type change, timeframe kept | **Pass** | Respond → Challenges → response timeframe 15m → Change type → Setup. Link banner and "Response timeframe 15m" kept throughout. `3895ba9d` stored `setup`, 15m, parent `dd02fc7f`, `challenges`. | 18–21, 24 |
| Realtime refresh | **Pass (create event)** | B's API create at 15:24:53 appeared on A's open chart with no marker refetch; the last `GET …/markers` was at 15:24:22. After A's response, B's marker shows response badge "1". | 17 |
| Failed submission and retry | **UI passes; exposes §5** | chart-service stopped at 15:29:22. Gateway 502 → "Couldn't post … Your draft is saved" plus toast. Restarted, then Retry → POST 200 at 15:30:03. | 25–27 |
| Draft cancellation (edited draft) | **Failed (crash) → fixed (`05f5d00`) → Pass** | Before: EXC_BREAKPOINT in UIKit `dismissViewController` via `SheetBridge.present` (`test-results/crash-discard-before-fix-frames.txt`). After: "Discard this draft?" appears over the sheet; Discard ends placement; no crash and no marker created. | 29 |
| Incompatible-component warning | **Pass** | Analysis + Support, then tap Question → "Switch to Question? This removes context Question can't carry: Support." Cancel keeps Analysis with 1 level. | 32, 33 |
| Setup, untracked | **Pass** | `6fa2782b`: `tracking_enabled=false`, state DRAFT, long with consistent levels. Review showed the untracked copy. | 34, 35, 38 |
| Setup, tracked | **Failed as found (§5); corrected in §5a** | `3895ba9d` stored with entry above both TP and SL; ARMED→ACTIVE at 15:31:20. Kept as evidence, not repaired. | 22–27 |
| Experiment off | Legacy flat list | Per-launch gate observed as off. | 36 |

**Not exercised at runtime:**
- physical-device behaviour and performance

Closing an *untouched* guided draft, and a `marker_updated` event received by another client, were exercised later (§10).

## 4. Client fixes (separate commits)

1. **`c4ecb14`: text-only Analysis edit.**
   - Under the experiment, `MainView.beginEditingSelectedMarker` calls `allowTextOnlyAnalysisEdit()` after `beginEditingMarker`.
   - `requiresAnalysisContext` is false when guided, or when editing with that allowance.
   - The allowance is cleared when an edit session begins or ends, and ignored outside one. The thesis is still required.
   - With the experiment off, and in production, the rule is unchanged (unreachable).
   - Tests: `MarkerTextOnlyAnalysisEditTests` (4). Mutation-checked: reverting the rule to guided-only fails `underTheExperimentATextOnlyAnalysisSavesAsText` and `theAllowanceEndsWithTheEditSession`.
2. **`05f5d00`: discard confirmation.**
   - The toolbar close button now only raises the request. `ChartBottomSheet`, which is what is on screen, presents `MarkerGuidedDiscardConfirmation`.
   - The request needs `cancellingNeedsConfirmation`, which needs the guided flow. So it stays unreachable with the experiment off and in production.
   - No unit test: the fault is in the presentation hierarchy, which the unit target cannot host. Evidence is the crash frames before the fix and capture 29 after.

## 5. Defect as found: tracked Setup stored with inconsistent levels

**Status.** Kept here as found. The owner then approved a bounded correction, which is in §5a. The paths and line numbers below describe the code before `2e8750e` and before Sol's `5061824`.

### Exact reproduction (guided flow, real runtime)

1. **Draft.** As A on 15m, respond to B's `dd02fc7f` (Challenges) and use Change type → Setup.
   - The chart seeds Entry 83,744.01 / TP 83,905.64 / SL 83,647.03 (capture 22).
   - Dragging TP below the entry flips the Setup to short, and SL mirrors to 83,840.98; TP is 83,393.81 (capture 23).
2. **Review** (capture 24): SHORT, R:R 1 : 0.56. Its "Entry — Latest price when you post" shows **83,553.98**.
   - That value is `setupEntryPrice` = the anchor draft price. It is not the chart's Entry line (83,744.01) and not the live price (~83,830). See the secondary observation below.
3. **Post fails.** chart-service stopped → Post → 502. `placeMarkerFromState` had already rewritten the anchor and `level.entry` to `lastCandle.close` before sending.
4. **Review after the failure** (capture 25): the live price had risen through the stop. Review now shows Entry 83,882.005, **"TP / SL same side"**, R:R 1 : 11.90, and **Retry stays enabled**.
5. **Retry.** The entry was rewritten again, to 83,920.01. POST 200.
   - Stored `3895ba9d`: tracked, `level.entry` 83,920.01, `level.sl` 83,840.98, `level.tp` 83,393.81. **Both exits are below the entry.**
   - The processor moved it ARMED→ACTIVE at 15:31:20. It was still ACTIVE at 18:2x.

The failed post only widened the window. Without any failure, the same result follows whenever the live price crosses the SL (or TP) between setting the levels and tapping Post.

### Guard paths today

| Layer | Guard | Where |
|---|---|---|
| Client submission | For a Setup, the anchor and `level.entry` are overwritten with `lastCandle.close` just before building the request. Direction is **not** re-checked afterwards. | `TradingChartView.placeMarkerFromState`; the identical block is at branch base `72b6f2b` `TradingChartView.swift:2916–2925` |
| Client validity | `isValid` for `.setup` returns `true` unconditionally. The checklist item `setup_direction_required` ("TP/SL direction is valid", required when tracked) exists, but neither `isValid`, the legacy Place button nor the guided Post/Retry consults it. | `MarkerPlacementMode.swift` (base `:756–759`, `:516–523`); guided `MarkerGuidedPlacementBar`: `enabled: isValid && !isSubmitting` |
| Client display | The guided Review computes `.inconsistent` and shows "TP / SL same side" as a warning only. | `MarkerSetupEditorParts.swift:114–128`, `MarkerGuidedPlacementViews.swift:818` |
| Backend validation | A tracked Setup requires only the **presence** of `level.entry`, `level.sl` and `level.tp`; no ordering check. | `shared/schemas/chart_schema.py:186–191` (in `780398f`; Sol confirmed the same at `1ec0885`) |
| Backend processor | ARMED→ACTIVE when a candle range contains the entry. TP and SL hit tests are direction-agnostic (`low <= level <= high`), so an inconsistent Setup resolves by whichever level is touched first. Here, a fall to 83,840.98 would score SL_HIT, although a fall favours the short the author drew. | `services/chart-service/app/services/marker_processor.py:312–323, 399–401` |

### Does the baseline reproduce it?

**By source: yes.** The submit override, `isValid == true` for Setup, and the unenforced direction item are all present unchanged at branch base `72b6f2b`. The backend validator and processor are identical at `1ec0885` (Sol's audit). v1.5 did not introduce the defect. The guided Review only makes it visible, as a warning that does not block.

**At runtime: the mechanism was observed; the inconsistent outcome was not reproduced.**
- Run with the experiment off, in the legacy panel (captures 36, 37).
- Chart handles keep TP and SL consistent relative to the displayed entry: dragging SL across the entry flips the side and mirrors TP.
- A tracked short was placed with SL 83,957.08 just above the displayed entry 83,954.01 while the live price read 83,958.
- On Place, the entry was rewritten to `lastCandle.close` = 83,934.01, with no re-check. Result: `772cfd7a`, ARMED; the processor later scored it SL_HIT.
- The price had moved down, so the stored levels happen to be consistent.
- Chasing the exact price timing further was stopped at Astra's request.

### Minimal correction recommendation (as written before approval)

1. **Client (smallest).**
   - In `placeMarkerFromState`, after rewriting a tracked Setup's entry to `lastCandle.close`, check `isSetupDirectionValid`. If it fails, send nothing: keep the draft and record a failure, for example "Price moved past your stop or target. Adjust the levels and post again." In the guided flow that is `submissionPhase = .failed`; in the legacy flow, `presentPlacementFailure`.
   - Disable guided Post/Retry while Review shows `.inconsistent`.
   - Scope choice for the owner: guided/experiment-only, which leaves frozen legacy behaviour untouched, or all clients as a separately approved fix.
   - Also show, in Review's Entry row, the price that will be sent instead of the anchor price.
2. **Backend (defence in depth, separate decision).** Reject tracked Setup create or update when TP and SL are not on opposite sides of the entry, and/or skip activating such a record.
   - This is additive and needs no migration.
   - Old clients that hit the price race would get a generic failure instead of an invalid record.
   - Existing records are untouched.

## 5a. Approved correction: tracked Setup level integrity

Scope: `docs/V1_5_SETUP_GUARD_CORRECTION.md`. Claude owns iOS and the local runtime; Sol owns the backend guard.

### Client (`2e8750e`, guided flow under the experiment only)

- **Review shows the Entry the chart shows.** The guided Setup card, Review, side pill and R:R read `guidedSetupEntryPrice`: the Entry level (what the chart's Entry line drives), falling back to the anchor only if no Entry level exists. A linked Setup's anchor sits on the parent's candle with an old price, which Stage 4 showed as "Entry".
- **Post-time check.** The chart's latest-price Entry refresh is unchanged; it moved into `MarkerPlacementState.refreshSetupEntryForPosting(latest:)` with identical behaviour.
  - Straight after it, `MarkerPlacementSubmitter.submitCreate` checks the request that is about to be sent.
  - A guided tracked Setup whose Entry is not strictly between SL and TP, or that lacks exactly one of each, is **not sent**. It fails with `MarkerPlacementFailure.trackedSetupLevelsOutOfOrder`.
  - The side inference is the editor's `MarkerSetupSide.of`.
- **On rejection.**
  - Review shows "Couldn't post — The price moved: Entry is no longer between your stop and target. Adjust your levels, then post again. Your draft is saved." It offers **Adjust levels**, which returns to Details. The chart shows the "Adjust Your Levels" warning toast.
  - The draft, link, response timeframe, tracking and exits are kept. Nothing moves TP or SL, freezes the old Entry or flips direction.
  - The chart's Entry line moves to the refreshed price, as a new candle would, so the chart and Review agree.
  - Nothing is marked as submitting. The chart's `isSubmittingPlacement` is cleared by the normal non-stale outcome path, so nothing is left pending. Duplicate-post protection, stale-completion handling and retry after a server failure are unchanged.
- **Before Post.** Review and Post/Retry are disabled while a guided tracked Setup's levels are out of order, and Details explains why. This also covers Retry after a failure during which the price moved.
- **Unchanged.**
  - Untracked Setups are never held.
  - With the experiment off, the legacy panel, checklist, validity and submission behave exactly as before. The new guided-only checks read `isGuidedFlowActive`.
  - Production is unchanged because the guided flow is unreachable there.

### Tests

`MarkerTrackedSetupGuardTests` (8 tests):
- linked Review Entry
- valid long and short
- a price move through the stop: no transport call; draft, link and timeframe kept; no pending state; retry also sends nothing
- adjustment, then success
- untracked
- experiment-off legacy
- the refresh moves only Entry and the anchor
- the request check against the backend rule: strict order, missing level, duplicate Entry, untracked, non-Setup

**Mutation check:**
- Reading the anchor again fails 3 tests.
- Removing the preflight fails 2: `aPriceMoveThroughTheStopIsStoppedBeforeSending` and `adjustingTheLevelsThenPostingSucceeds`.

**Harness scenarios** (in-memory transport, not the backend):
- `responseSetupEntry` (capture 39): Review Entry 63,920, the Entry line. The anchor is 63,520.
- `setupMarketMoved` (capture 40): the price rose 200 through a +120 stop. "TP / SL same side", the explanation, Adjust levels, and Retry disabled; the transport received nothing.

### Backend (Sol, `5061824`), verified on local DEV

`$S/stage4/guard_checks.py` ran against the local gateway only, using the disposable accounts. Results are in `test-results/guard-local-dev-api-checks.json`; the DB after the run is in `test-results/guard-local-dev-guild-markers.txt`. **10 of 10 as expected:**

| Check | Result |
|---|---|
| Invalid tracked create: the original retry levels exactly (Entry 83,920.01, SL 83,840.98, TP 83,393.81), linked `challenges`, 15m | **422** "Tracked setup requires SL < Entry < TP or TP < Entry < SL". Not persisted. |
| Invalid tracked create: SL and TP both above Entry, 30m | **422**. Not persisted. |
| Valid tracked long (1h) and short (4h) | 200, `f65276b9` / `3f0fbe6a` ARMED |
| Untracked with same-side levels (1d) | 200, `5028f408` DRAFT. Untracked behaviour is unchanged. |
| Effective update: turn tracking on for that untracked record | **400** |
| Effective update: move the valid long's SL above Entry (ARMED, components replaceable) | **400**; the stored levels are unchanged |
| Note-only edit of the valid long | 200 |
| Text-only Analysis create and edit (regression) | 200 / 200, `499bf540`, `[anchor]` |

- **No new invalid rows.** The guild went from 5 to 9 markers: the four accepted API creates. `3895ba9d` (still ACTIVE) and `772cfd7a` (SL_HIT) are untouched.
- **Original retry case, without live-price timing.** Covered twice:
  - The backend rejects that exact request (above).
  - The client never sends it: the `setupMarketMoved` harness scenario and `aPriceMoveThroughTheStopIsStoppedBeforeSending`.
- **Real app, same runtime.**
  - As A: respond to B's `499bf540` (Challenges, 5m) → Change type → Setup.
  - Details and Review show Entry 83,825.085, the Entry line (captures 41, 42).
  - Post → POST 200. `e2641cfc` is a tracked long (SL 83,728.11 < Entry 83,841.66 < TP 83,986.72), ARMED, parent `499bf540`, `challenges`, 5m (capture 43).
  - The live rejection path in the real app was not triggered, because it depends on price timing. It is covered by the harness and the unit tests.
- **Consequences** (from Sol's checkpoint; the backend is not deployed):
  - An effective-state update of an existing invalid tracked Setup, including a note-only edit, now returns 400.
  - An ACTIVE invalid Setup cannot have its levels replaced through the current endpoint.
  - Turning tracking off bypasses the rule.
  - In today's app, such an edit would show the generic "Could not save changes" failure. That is inferred from the update path and was not exercised, to avoid writing to the evidence records.

## 6. Other observations (not fixed)

- **Review Entry value.** Fixed in `2e8750e` (§5a). As found: for a response Setup the guided Review's Entry showed the anchor price (83,553.98), while the chart's Entry line showed 83,744.01.
- **Response thesis text cut short: a tool artifact, not an app bug** (§10). Two response drafts typed by the simulator tool were stored truncated: "Stage4 response: reje" (`3895ba9d`) and "Guard check:" (`e2641cfc`).
- **Legacy edit panel wording.** The panel still lists "Add at least one chart component" with a warning icon for a text-only Analysis, although under the experiment it is optional (capture 31). Cosmetic.
- **Unit tests sign the app out.** The unit-test host is the same LinkedDev bundle on the same simulator, and after each test run the app came back signed out. At 15:19:24 and 15:20:31, refresh returned 401 right after a run. This is a harness effect, not a product finding.
- **Simulator input.**
  - The first tap after a view transition is often dropped.
  - Text typed by the tool into the Setup level fields did not apply, so levels were set by dragging.

## 7. Legacy compatibility (source and test inference, no old-client runtime)

**Wire shape.**
- A text-only Analysis is `intent: "analysis"`, `components: [anchor]`, the same shape as the anchor-only Questions already served (332 locally).
- The `marker_created` and `marker_updated` event shape is unchanged, according to Sol's real-Postgres test, which passed locally (§2): keys `{type, sender_id, payload}`, and the payload equals `neutral_marker_payload`.

**iOS 1.1.1 / 1.1.2.**
- There is no tag or `MARKETING_VERSION` commit for either version in `traders_guild_ios`. The nearest verifiable source is `c401710` ("Prepare v1.1 app update"), the parent of the 1.1.3 preparation commit `09775e3`.
- There:
  - `RLChartMarkerDTO.components` is a required array with synthesized Codable, so `[anchor]` decodes.
  - Non-test source has no `components.first!` or `[0]`.
  - The only rule tying Analysis to a component is placement validation (`MarkerPlacementMode.swift:720` there).
- So, by source reading, an author editing a text-only Analysis from an old build would be asked to add a component before saving. This is inference only: it does not prove the absence of a crash or data loss, and `c401710` is not proven to be the exact 1.1.1 or 1.1.2 source (Astra's qualification, `546f9bf`). **Runtime not exercised.**

**Tracked-Setup guard (`5061824`), by source.** Released clients that send valid tracked levels keep the same request, response and event shapes. A released client that hits the price race gets a failure instead of an invalid record. Current iOS with the experiment off maps that 422 to the generic "Could not place marker" toast and keeps the draft; the guided flow does not send the request. Older clients' messages were not checked at runtime.

**Current iOS, experiment off.** Same rule; unchanged. Only the experiment-gated path allows a text-only edit.

**Android.**
- Checked `traders-guild-android` `c5a5c91` (`feat/1.3.0-linked-markers`):
  - `MarkerDto.components` defaults to `emptyList()`, with no `first()` or `[0]`.
  - `analysis_structure` is required in `MarkerPlacementController.kt:439`, so source inspection suggests the same edit-validation limitation.
- **Runtime not exercised.** The shipped Play 1.4.0 (code 19, `6df2000`) was not inspected.

The deployed backend is untouched.

## 8. Verification (bounded)

All runs use `ONLY_ACTIVE_ARCH=YES`. `grep -c TradersGuildMac` = 0.

| Run | Result | Evidence |
|---|---|---|
| `LinkedDev` DevDebug: MarkerTextOnlyAnalysisEdit, ChartComponentReactivity, MarkerDrawingWorkflow, MarkerGuidedSubmissionSafety, MarkerGuidedCreation, MarkerHorizontalLinePayload, MarkerPlacementVisibility, MarkerPlanFixes, MarkerResponseTimeframe, MarkerLinkState, MarkerAvatarExperiment. Final tree, identical to `05f5d00`. | **159 passed, 0 failed, 0 skipped** | `$S/rb-s4-final.xcresult`, `$S/s4-final.log`; `docs/visual-review/v1.5-stage4/test-results/final-devdebug-summary.json` |
| Same suites before the discard fix | 159 passed | `$S/rb-s4-devdebug.xcresult`, `$S/s4-devdebug.log` |
| Mutation: edit rule reverted to guided-only | 2 of 4 failed, as intended | `$S/rb-s4-mutation.xcresult`; `test-results/mutation-textonly-edit-summary.json` |
| `LinkedDev Profile` build | BUILD SUCCEEDED | `$S/s4-devprofile.log` |
| `GCP Public Prod` Release build | BUILD SUCCEEDED | `$S/s4-release.log` |
| Backend real-Postgres gate (local DEV) | 1 passed | §2 |
| Compose and gateway smokes | pass, before and after the swap | §1 |
| **Correction** `2e8750e`, `LinkedDev` DevDebug: MarkerTrackedSetupGuard plus all the suites above | **167 passed, 0 failed, 0 skipped** | `$S/rb-s4g-devdebug.xcresult`, `$S/s4g-devdebug.log`; `test-results/guard-devdebug-summary.json` |
| Mutation: Review reads the anchor | 3 of 8 failed, as intended | `$S/rb-s4g-mutation-entry.xcresult`; `test-results/guard-mutation-review-entry-summary.json` |
| Mutation: preflight removed | 2 of 8 failed, as intended | `$S/rb-s4g-mutation-preflight.xcresult`; `test-results/guard-mutation-preflight-summary.json` |
| Correction: `LinkedDev` DevDebug app / `LinkedDev Profile` / `GCP Public Prod` Release builds | BUILD SUCCEEDED ×3 | `$S/s4g-build-devdebug.log`, `$S/s4g-devprofile.log`, `$S/s4g-release.log` |
| Correction: backend guard on local DEV | 10 of 10 as expected | §5a |

| **Full unit target** (`traders_guildTests`), `LinkedDev` DevDebug, on `a257851` (code identical to `2e8750e`) | **792 passed, 0 failed, 0 skipped** | `$S/rb-s4-full.xcresult`, `$S/s4-full.log`; `test-results/full-unit-target-summary.json` |

The previous full run was Stage 3's (772 tests).

## 9. Evidence index (`docs/visual-review/v1.5-stage4/`)

| Files | What |
|---|---|
| 01–14 | Text-only Analysis: create, drag, detents, review, in-flight, posted, share prompt, resting, selected, detail |
| 15–16 | Edit before the fix |
| 17 | Realtime |
| 18–24 | Linked response, 15m, type change to Setup, level drag, review |
| 25–27 | Failure, retry, share prompt |
| 28 | Question validation |
| 29 | Discard dialog after the fix |
| 30–31 | Edit after the fix |
| 32–33 | Incompatible-component warning |
| 34–35, 38 | Untracked Setup |
| 36–37 | Experiment-off baseline |
| 39–40 | Correction, harness: linked Review Entry; market moved, not sent |
| 41–43 | Correction, real app: linked Setup Details and Review Entry line; posted |
| 44–45 | Follow-up: response-draft typing probes (tool artifact) |
| 46–47 | Follow-up: owner's view before and after a realtime `marker_updated` (new note; Delete affordance) |
| 48–49 | Follow-up: untouched guided draft closes without a dialog |
| `test-results/` | Summaries, junit, row counts, crash frames; `guard_checks.py`, `guard-local-dev-api-checks.json`, `guard-local-dev-guild-markers.txt`, guard test and mutation summaries; `followup-owner-delete-check.txt` |

## 10. Follow-up while Astra and Sol were unavailable (no code changes)

Bounded to the gaps this checkpoint listed. Same runtime (`5061824`), same accounts. The only writes were the API calls named below; none touched the evidence records' levels or state.

**1. Response-thesis truncation (§6): a tool artifact.** Two probes on a real response draft (Supports, 5m), then discarded:
- Test A (capture 44): 67 characters including a colon, typed, then a 3-second wait. All of them arrived.
- Test B (capture 45): 37 more characters, typed, then "Change type" tapped straight away. Only " plus probe" arrived. The simulator typing tool returns before every keystroke has been delivered, and removing the field drops the rest.

Both truncated notes were typed immediately before a Change type tap. Text that has arrived survives a type change and back. Nothing in the app needs changing.

**2. `marker_updated` on a second client: passes, and exposed a permission mismatch that predates v1.5.**
- At 19:07:14, B edited `499bf540`'s note through the API. A's app, already open on the chart, showed the new note on selection. chart-service logged no marker GET after the PUT, so the update arrived over realtime (capture 47).
- **Finding: owner Delete affordance.** The same selection now offered A **Delete Marker** on B's marker; before the update it did not (capture 46).
  - iOS `neutralMerge`/`locallyPermissioned` (1.3.0, commit `e236543`, present in the 1.3.0 RC `8801a6a`) sets `canDelete = isMine || viewerCanModerate`. `MemberRole.canModerate` includes **owner**.
  - The backend allows delete, and reports `can_delete`, only for the author, admin or moderator (`chart.py` `delete_marker`; `can_delete` at `:1346`).
  - Runtime check on a throwaway marker (`test-results/followup-owner-delete-check.txt`): B created a Question; A (guild owner) got `can_delete=false` and DELETE **403** "You don't have permission to delete this marker"; B, the author, then deleted it (200).
  - Effect: a guild owner sees Delete on other members' markers that arrived or changed over realtime; tapping it fails with the generic failure. Nothing is lost.
  - Not fixed: the code is shipped 1.3.0 behaviour, and which side is right (should owners moderate?) is a product/backend decision. Candidates: include `owner` in the backend delete rule and `can_delete` (additive, and every client benefits), or drop owner from the client derivation.
  - That this affects released builds is inferred from `8801a6a`; a released binary was not run.

**3. Closing an untouched guided draft: passes.** "Post to the chart", then close, with nothing typed: placement ended with no confirmation and no request (captures 48, 49).

**4. Full unit target: 792 passed, 0 failed, 0 skipped** (§8). Running it on the same simulator signed the LinkedDev app out again, the known harness effect.
