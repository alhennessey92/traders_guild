# v1.5.0 Stage 4 checkpoint: local DEV iOS integration (Claude)

Branch `claude/1.5.0-avatar-markers`, continuing the accepted `b10ed51`. Worktree `.worktrees/marker-avatar-claude`.

**Commits:** three local commits, not pushed, not deployed. No backend, Android or production changes.

| Commit | What |
|---|---|
| `c4ecb14` | Fix: a guided text-only Analysis stays editable. Includes tests. |
| `05f5d00` | Fix: the guided discard confirmation is presented from the chart sheet. The old placement crashed the app. |
| this commit | This checkpoint and its evidence. |

**Stop point.** This is an engineering checkpoint for Astra. Stage 5 has not started.

**Open item: Setup level-ordering defect.** One defect is **open and not marked passed**: a tracked Setup can be stored with its levels in the wrong order. It predates Stage 4. Changing the Setup rules waits on the owner's decision (§5).

`$S` = `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad`. All times are UTC unless marked otherwise. The app's clock labels are BST (UTC+1).

## 1. Local runtime: source, config, migration, ownership

**Stack.**
- Compose project `traders-guild-local`, run from `.worktrees/linked-markers-backend`:
  - `0055fbb`, clean
  - `docker-compose.yml` + `docker-compose.safe.yml` + `.env.local` (mode 600, never printed)
- One extra override kept outside both backend trees: `$S/stage4/compose.stage4-780398f.yml`.
- Before this stage the stack was stopped. Only TimescaleDB was brought up, for the read-only inventory. No running stack was replaced.

**Backend source.**
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
| Setup, tracked | **Open: see §5** | `3895ba9d` stored with entry above both TP and SL; ARMED→ACTIVE at 15:31:20. | 22–27 |
| Experiment off | Legacy flat list | Per-launch gate observed as off. | 36 |

**Not exercised at runtime:**
- closing an *untouched* guided draft (covered by the Stage 3 unit tests)
- a `marker_updated` event received by a second client (only one app instance)
- physical-device behaviour and performance

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

## 5. Open defect: tracked Setup stored with inconsistent levels (decision pending)

**Status.** Not passed and not fixed. Setup rules were left unchanged, as instructed, pending the owner's scoped decision relayed by Astra.

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
- On Place, the entry was rewritten to `lastCandle.close` = 83,934.01, with no re-check. Result: `772cfd7a`, ARMED.
- The price had moved down, so the stored levels happen to be consistent.
- Chasing the exact price timing further was stopped at Astra's request.

### Minimal correction recommendation (not implemented)

1. **Client (smallest).**
   - In `placeMarkerFromState`, after rewriting a tracked Setup's entry to `lastCandle.close`, check `isSetupDirectionValid`. If it fails, send nothing: keep the draft and record a failure, for example "Price moved past your stop or target. Adjust the levels and post again." In the guided flow that is `submissionPhase = .failed`; in the legacy flow, `presentPlacementFailure`.
   - Disable guided Post/Retry while Review shows `.inconsistent`.
   - Scope choice for the owner: guided/experiment-only, which leaves frozen legacy behaviour untouched, or all clients as a separately approved fix.
   - Also show, in Review's Entry row, the price that will be sent instead of the anchor price.
2. **Backend (defence in depth, separate decision).** Reject tracked Setup create or update when TP and SL are not on opposite sides of the entry, and/or skip activating such a record.
   - This is additive and needs no migration.
   - Old clients that hit the price race would get a generic failure instead of an invalid record.
   - Existing records are untouched.

## 6. Other observations (not fixed)

- **Review Entry value.** For a response Setup, the guided Review's Entry shows the anchor price (83,553.98), labelled "Latest price when you post". The chart's Entry line showed 83,744.01 and the posted entry was 83,920.01. For a new Setup the values match: 84,000.005 at Review, 83,982.16 posted, the difference being price movement. Folded into §5, recommendation 1.
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
- Source inspection suggests an author editing a text-only Analysis from an old build would be asked to add a component before saving. This does not prove absence of crashes or data loss in the shipped versions. **Runtime not exercised; exact 1.1.1/1.1.2 source provenance remains unverified.**

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

The whole unit target was not re-run for this bounded stage. The last full run is Stage 3's (772 tests).

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
| `test-results/` | Summaries, junit, row counts, crash frames |
