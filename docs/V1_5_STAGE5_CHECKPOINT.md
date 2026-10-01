# v1.5.0 Stage 5 checkpoint: performance and acceptance (Claude)

Branch `claude/1.5.0-avatar-markers`, continuing from `a4631c7` (Stage 4 follow-up). Worktree `.worktrees/marker-avatar-claude`. Local commits only: not pushed, not deployed, not submitted. No backend, Android or production changes. This is the Stage 5 acceptance checkpoint for Astra and the owner.

`$S` = `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad`.

## Commits

| Commit | What |
|---|---|
| `1288203` | Review correction: the guided/request tracked-Setup guard refuses non-finite prices (`MarkerSetupSide.invalidPrice`). |
| `a8c7467` | Accessibility corrections to guided creation (Dynamic Type, VoiceOver), plus Reduce Motion for selection under the experiment. Includes unit and UI tests. |
| `188b8c0` | Device performance driver, test-only and portable. |
| `ab6f711` | First version of this checkpoint, evidence and tooling. |
| `8436dab` | Review correction: the prototype's initials disc reads in Light Grey (§4.1). Experiment-gated. |
| `18dc6e4` | Review correction: performance driver (§4.2). Test-only. |
| `431a9d6` | Driver: a pan that overshoots is reported, not fatal (§4.2). Test-only. |
| this commit | This checkpoint update, evidence and the corrected runner scripts. |

## Status at a glance

| Area | State |
|---|---|
| Finite-price guard (review correction) | Done, tested, mutation-checked. |
| Accessibility (themes, Dynamic Type, VoiceOver, Reduce Motion) | Done on the simulator, with corrections. VoiceOver speech and rotor were not driven by hand. |
| Initials contrast in Light Grey (review) | Fixed under the experiment: 1.61:1 → 7.47:1, measured from rendered pixels. |
| Performance tooling (review) | Corrected; the full device sequence ran clean on the simulator (9 / 9 steps). Two further contaminations were found and fixed along the way (§4.2). Early simulator signal: no added avatar requests; the prototype costs some extra CPU while panning (§4.5). |
| Regression | Full unit target **799 / 0** on `431a9d6` (797 / 0 on `a8c7467`, plus the 2 contrast tests). Accessibility UI tests **11 / 0**. Production binary checked. |
| **Physical-device baseline vs prototype** | **Not measured.** The phone was locked, and is now listed as `unavailable` (off the Wi-Fi tunnel). Bundles are rebuilt from the corrected driver and nothing is queued (§5). |

## 1. Review correction: non-finite prices (`1288203`)

**Problem.** A level field accepts `1e400`, which parses to infinity, and `nan`. `MarkerSetupSide.of` compared order only, while the request check claimed parity with the backend's "exactly one finite Entry/SL/TP, strictly ordered" rule.

**Fix.**
- A new `.invalidPrice` side covers any non-finite Entry, TP or SL. The side pill reads "Check your prices".
- The guided tracked guard treats it as needing adjustment. That covers Review, Post/Retry, the guided direction checklist item and the pre-send request check. Nothing is sent.
- The guided direction check reads the same side inference.
- Untracked Setups and the experiment-off legacy direction check are unchanged; a test pins this.

**Tests.** `MarkerTrackedSetupGuardTests` gains 3 tests plus request cases.
- Affected suites: **110 / 0**.
- Mutation: removing the finite guard fails 2 tests.
- Evidence: `$S/rb-s5-finite.xcresult`, `$S/rb-s5-finite-mut.xcresult`, and `test-results/finite-guard-*.json`.

## 2. Accessibility

Simulator: iPhone 17 Pro, iOS 26.5. The guided harness (`-MarkerGuidedCreationFixture`) and the marker gallery (`-MarkerLinkFixtures`) are backend-free.

### Found and fixed (`a8c7467`): guided views only, which are v1.5 code

The "before" captures are in `accessibility/before-fix-ax-xxxl-*.jpg`.

| Issue | Fix |
|---|---|
| At AX XXXL, the Analysis/Question chips broke words mid-letter ("An·aly·sis"). | The chips stack vertically at accessibility sizes. |
| The 68 pt guided bar clipped Review/Post at large sizes. | Text is capped at `.accessibility1` and the Large Content Viewer is offered, the standard treatment for fixed-height bars. Tested: the button fits the bar and posts at AX XXXL. |
| Setup values were a fixed 13 pt monospaced font; price fields were a fixed 140 pt. | Values scale with Dynamic Type and stack at accessibility sizes. At normal sizes they keep exactly 140 pt. |
| Price fields spoke only their number. | They now say "Take Profit" and "Stop Loss". |
| The selected type chip and the current type row gave no state. | Both carry the selected trait. |
| Review lines spoke icon names such as "plus.viewfinder" and "scope". | Decorative icons are hidden; each line is one element ("Entry, Latest price when you post, 64,120"). |
| The author's own face beside the step title was a stop of its own. | Hidden as decoration. |
| The failure card's identifier overwrote the Adjust levels button's identifier. | The card is its own container. |

**Reduce Motion.** With the experiment on, the chart selection pop and wiggle honour Reduce Motion (`MarkerSelectionMotion`): no spring and no wiggle. With the experiment off, and in production, the shipped motion is unchanged. Faces already stay upright through the wiggle; they are drawn in the unrotated context.

**Tests.**
- `MarkerSelectionMotionTests` (unit, 2).
- UI tests, run in `LinkedDev Profile`, **11 / 11**: `MarkerGuidedCreationAccessibilityTests` (7) and the existing `MarkerLinkAccessibilityTests` (4).
- Evidence: `$S/rb-s5-a11y-ui.xcresult`, `test-results/a11y-*.json`, and accessibility trees `accessibility/tree-*.txt`.

### Themes

Dark, Mid-Grey and Light Grey (Light Grey uses the light colour scheme).
- Guided sheet: `accessibility/theme-*.jpg`.
- Marker gallery with intents, Setup states and relationships, selected: `themes/gallery-*.jpg`.

All three render faces, intent badges, rings, arcs and branches legibly. The initials discs in Light Grey were the exception; they are fixed in `8436dab` (§4.1).

### Recorded, not changed (outside v1.5 scope)

- **Link banner wrapping.** The 1.3.0 link banner ("Challenges … Change") breaks "Chang·e" at AX XXXL. It is shared with the legacy panel; shipped behaviour.
- **Chart markers are drawn on a Canvas.** VoiceOver cannot reach individual chart markers, and that was already true of legacy markers. The accessible routes are the marker list, the detail sheet and the thesis rows. Their relationship words are covered by `MarkerLinkAccessibilityTests`.
- **Legacy Reduce Motion.** The legacy (experiment-off) selection pop and wiggle still ignore Reduce Motion. Applying `MarkerSelectionMotion` to all users would be a one-line change, but it changes shipped behaviour, so it needs a separate decision.
- **Loading placeholder.** While a picture loads, `CachedAvatarImage` shows its own shared placeholder (accent initials on the accent at 30%). It is used app-wide and shipped; not changed.
- **Not driven by hand.** VoiceOver speech, rotor order and Switch Control. The UI tests verify the accessibility tree, not speech.

## 3. Regression

- **Full unit target** (`traders_guildTests`, LinkedDev DevDebug) on `a8c7467`: **797 passed, 0 failed, 0 skipped**. Evidence: `$S/rb-s5-full.xcresult`, `test-results/full-unit-target-summary.json`.
- **Full unit target on `431a9d6`** (after the initials change): **799 passed, 0 failed, 0 skipped**. Evidence: `$S/rb-s5-full-431a9d6.xcresult`, `test-results/full-unit-target-431a9d6-summary.json`.
- **Initials change** (`8436dab`): the affected suites (`MarkerAvatarInitialsContrastTests`, `MarkerAvatarRenderTests`, the identity, experiment, intent-decoration and selection-motion suites) **42 / 0**. Evidence: `$S/rb-s5-initials.xcresult`.
- **Production configuration.** In the `GCP Public Prod` Release binary:
  - the gate key `TGAvatarMarkersExperiment` and the fixture key `MarkerGuidedCreationFixture` are **absent**, so neither arguments nor saved preferences can enable the experiment there;
  - the guided views are compiled in but unreachable, because `MarkerAvatarExperiment.isAvailable` is `false`.

  The DevProfile binary contains both keys. Production was not launched.
- Stage 4's local-DEV runtime checks still stand, and the local stack is unchanged. It runs chart-service on `5061824`, with outbound integrations off.

## 4. Review corrections after `ab6f711`

### 4.1 Initials contrast in Light Grey (`8436dab`)

**Measured, not assumed.** Contrast was computed from rendered pixels in gallery captures (`-MarkerLinkFixtures`, intents scene, experiment on), sampling the disc and its text:

| Theme | Before | After |
|---|---|---|
| Dark | 7.47 : 1 | 7.47 : 1 |
| Mid-Grey | 7.47 : 1 | 7.47 : 1 |
| Light Grey | **1.61 : 1** (disc `#8B8F9A`, text `#676D78`) | **7.47 : 1** |

**Cause.** With the experiment on, every Analysis/Question/Setup author without a picture shows the initials fallback. That fallback tints the theme's Personal fill and uses the theme's icon colour, which on Light Grey's pale chrome is grey on grey.

**Fix, within the prototype only.**
- Under `MarkerAvatarExperiment.isEnabled`, the initials sit on an opaque disc (`#3D3F43`) with light text (`#D9D9D9`): the pairing the dark themes already render, now the same in every theme. The dark disc also stands out from the Light Grey chart.
- With the experiment off, and in production, the code path is the legacy one, unchanged. That was checked by reading the code, not by a new capture: the intents scene shows no initials with the experiment off.

**Tests.** `MarkerAvatarInitialsContrastTests`: the prototype pair meets WCAG AA (≥ 4.5 : 1, computed 7.47), and the measured legacy Light Grey pair is pinned as the failing case.

**Evidence.**
- `themes/initials-lightGrey-before-after.png`: a crop of the disc before and after.
- `themes/initials-fix-{dark,midGrey,lightGrey}-intents.jpg`: the full scene after the fix.

### 4.2 Performance driver and runner (`18dc6e4`, `431a9d6`; runner scripts in this commit)

Astra's review raised the first four rows. The last three were found while validating the corrections, by reading the captures and the numbers rather than trusting a green run.

| # | Problem | Evidence | Correction |
|---|---|---|---|
| 1 | `test0` launched without the run's arguments, so the app could prefetch under the previously saved gate before `test1`. | Driver source. | Every launch takes `TG_PERF_LAUNCH_ARGS`. Measure runs skip `test0`; sign-in is a separate **prepare** run, before the avatar rotation. |
| 2 | Selected/unselected tests only asserted that a chart was showing. | Driver source. | Each pan test asserts the selection title ("Analysis Marker") present or absent, uses the Close control, and attaches the anchored and the panned view. |
| 3 | `run_perf.py` deleted the previous result bundle and returned success after a failed `xcodebuild`. | Script source. | Each invocation writes `rb-perf-<label>-<UTC stamp>.xcresult` and deletes nothing. A failed `xcodebuild` exits 1, and `run_all.sh` stops (exit 3). Seen working: two failing validation runs exited 65 and the runner exited 1. The first simulator dry run of the full sequence stopped at step 4 with exit 3, without starting step 5. |
| 4 | Cold loading sat in an unmeasured 8-second load and warm-up, so measured pans never saw cold stalls. | Driver source. | Loading has its own windows (below). Cold frame behaviour comes from the first-launch window. |
| 5 | **The cold launch was being discarded.** XCTest runs a measure block once more than its iteration count and drops the first run. A launch inside `measure` therefore put the cold launch in the dropped run; the recorded number came from a warm relaunch. | `test1` took 38 s for one recorded 17.7 s iteration. Its window held 8 downloads (200), then 13 revalidations (304) (`test-results/perf-cold-launch-in-discarded-run.json`). | `first-launch-and-load` runs once, outside `measure`: cold on a cold run, a fresh process with the URL cache in place on a warm run. Its evidence is the phase window: device frame trace, server requests and screenshot. `relaunch-and-load` is measured, and is always a warm fresh process. |
| 6 | **The pans measured an empty chart.** | Captures from both builds: after the first pans, and for every unselected pan, the chart had drifted to an empty stretch with no markers (`perf-captures/old-driver-*.jpg`). The older simulator pan numbers are void. | See "How the pans stay on the markers" below. |
| 7 | **The CPU metric ignores `startMeasuring`.** `XCTCPUMetric(application:)` covers the whole measure block. | The same 8 s idle window read 10.8 s of CPU straight after an anchor, and 14.1 s when the block also held a 12 s wait. Anchored pans measured inside the block read 15–16.6 s of CPU per 8.8 s window; with the anchor moved out, 6.0–6.5 s (`test-results/perf-cpu-metric-spans-block.json`; the experiment was a throwaway build, never committed). | The anchor runs before `measure`, with one measured pan per test method (`test3_…_1…5`, `test4_…_1…5`). |

**How the pans stay on the markers.**
- Swiping toward newer candles first is clipped at the latest-candle edge, so the return swipe overshoots. The pans now go toward older candles first.
- A swipe that lands mid-fling does not balance the one before it. Each swipe now waits out the fling (3.5 s; the fling decays per frame, about 2.6 s at 60 Hz).
- Even balanced, fling length varies, so pan errors add up. Every measured pan therefore starts from a re-anchored parent: away to a second parent and back. XCTest's discarded first run stands still, so the recorded run is that single pan. The driver asserts the block ran exactly twice, so a different XCTest behaviour on the device fails loudly.
- Each anchored and panned view is checked against the first anchored view on a 64×48 grey fingerprint of the chart body. "On the seeded view" means:
  - sideways shift ≤ 20 columns;
  - match residual < 10;
  - spread ≥ 0.6 of the reference.

  **An anchored view off it stops the run**: the pan would not start on the seeded markers. A view off it after a pan is **reported, not fatal** (`431a9d6`), and counted per run. Fling length varies, and the next test re-anchors anyway.
- On the simulator:
  - every anchored view matched with shift 0 and residual ≤ 0.35;
  - single pans ended within −11…+15 columns, residual ≤ 5.2, spread 0.97–1.01; at +15 the thesis and its branches are fully in view;
  - one baseline pan in about 30 overshot to the latest-candle edge (shift beyond 24, residual 18). That stopped the first dry run of the full sequence, and led to `431a9d6`;
  - the empty view the old pans reached has spread 1–4, against 16–24 for the seeded view.

**What the captures show** (`perf-captures/corrected-anchored-and-panned-views.jpg`; and `two-pans-per-test-thesis-leaves-view.jpg`, the run that showed two pans per test are too many):
- Selected: the "Analysis Marker" title, dashed branches from the parent to its responses, and unrelated markers dimmed, before and after every pan.
- Unselected: the TG header, no branches, and every marker at full colour.

**Windows a run now records** (`TG_PHASE`, UTC; server avatar requests are attributed to them):
- `first-launch-and-load` (cold or fresh-process warm);
- `relaunch-and-load` (measured);
- `revisit-in-process` (measured; it holds two revisits, the discarded run and the recorded one);
- `pans-*-anchor`, kept apart from the measured pans;
- `pans-*` (measured).

The view checks are recorded in each run summary under `view_drift`.

### 4.3 Cache policy, as inspected (not assumed)

- **Chart faces (prototype)** go through `AvatarImageCache.shared`:
  1. an in-process `NSCache` (400 images);
  2. on a miss, an explicit lookup in `URLCache.shared`;
  3. on a miss, a fetch. The fetch transport has no cache of its own (`urlCache = nil`, `.reloadIgnoringLocalCacheData`). A response is stored into `URLCache.shared` only after the token check that keeps a removed avatar from coming back.

  So an in-process revisit is served from memory. A fresh process is served from `URLCache.shared` only if that entry survived, and nothing on this path revalidates.
- **`URLCache.shared` is not configured by the app.** It runs at system defaults, and whether entries survive a relaunch is the system's call (capacity, eviction). The runs therefore count what happens instead of assuming persistence.
- **Other avatar views** (drawer member rows and similar, unchanged since the baseline) use `AsyncImage` over `URLSession.shared` with the protocol cache policy. The server sends `ETag`/`Last-Modified` and no `Cache-Control`, so those views revalidate. That is the source of the 304s, in both builds.
- **Both builds prefetch member avatars at launch** (`LeftDrawerViewModel`).

**Simulator observations** (indicative, not device evidence):
- A fresh-process warm launch made no downloads, only 304 revalidations, so `URLCache.shared` entries did survive a relaunch there.
- Measured pans made **no avatar requests at all**.
- Each anchor made 8 revalidations: the drawer, not the chart faces.
- The device runs record the same per-phase, per-author counts.

### 4.4 Simulator validation (tooling only, not performance evidence)

The corrected driver passes on the simulator. It ran `prepare`, then `measure` on the prototype with the experiment on (`test-results/perf-sim-validation-corrected-driver.json`, 13 / 13 tests in 6.4 min, exit 0). The pan CPU above comes from that run. The baseline and the full sequence are in §4.5.

XCTest's hitch metric (`XCTHitchMetric`, iOS 26) recorded nothing on the simulator. On the device, `run_perf.py` records a system-wide Animation Hitches trace for each measure run. Hitches are then read per phase window from the `TG_PHASE` stamps. That export has not yet been exercised on a real device trace.

### 4.5 Full sequence on the simulator

`run_all.sh` with `TG_DEST=<simulator>` runs exactly the device sequence against the simulator builds. The first attempt stopped at step 4 (the overshot pan in §4.2). The second, on `431a9d6`, **completed all 9 steps with exit 0** in 46 minutes (`$S/stage5/run_all-sim-20261001T090321Z.log`). Summary: `test-results/perf-sim-sequence-summary.json`, produced by `perf-tooling/summarize_sequence.py`, which the device runs will use too.

**This is simulator data: tooling validation and an early signal, not the device comparison.**

Avatar requests per window (↓ download 200, ↺ revalidation 304):

| run | first launch | relaunch | revisit | anchors (sel / unsel) | pans (sel / unsel) |
|---|---|---|---|---|---|
| baseline cold | 8↓ 6↺ | 0↓ 16↺ | 0↓ 16↺ | 0↓ 40↺ / 0↓ 40↺ | 0 / 0 |
| baseline warm | 0↓ 8↺ | 0↓ 16↺ | 0↓ 16↺ | 0↓ 40↺ / 0↓ 40↺ | 0 / 0 |
| prototype, on, cold | 8↓ 5↺ | 0↓ 16↺ | 0↓ 16↺ | 0↓ 40↺ / 0↓ 40↺ | 0 / 0 |
| prototype, on, warm | 0↓ 8↺ | 0↓ 16↺ | 0↓ 16↺ | 0↓ 40↺ / 0↓ 40↺ | 0 / 0 |
| prototype, off, warm | 0↓ 8↺ | 0↓ 16↺ | 0↓ 16↺ | 0↓ 40↺ / 0↓ 40↺ | 0 / 0 |
| baseline warm, repeat | 0↓ 8↺ | 0↓ 16↺ | 0↓ 16↺ | 0↓ 40↺ / 0↓ 40↺ | 0 / 0 |
| prototype, on, warm, repeat | 0↓ 8↺ | 0↓ 16↺ | 0↓ 16↺ | 0↓ 40↺ / 0↓ 40↺ | 0 / 0 |

- **The prototype adds no avatar requests**, cold or warm, in any window. Pans make none in either build.
- **Cold launches download some authors twice, in both builds.** The split varies by run (baseline A2 B1 C1 D2 E2; prototype A1 B2 C2 D1 E2). The prefetch's own transport and the drawer's `AsyncImage` race for the same new URL. This predates v1.5; recorded, not changed.
- **Warm fresh-process launches download nothing.** On the simulator, `URLCache.shared` entries survived the relaunch; the device runs will show whether they do there. The 8 revalidations come from the drawer's `AsyncImage`.

Pans: medians of 5 single pans per state. App CPU and clock per pan window; memory is the app's physical footprint at the end.

| run | pans off the seeded view | selected: CPU / clock / memory | unselected: CPU / clock / memory |
|---|---|---|---|
| baseline cold | 0 of 10 | 5.19 s / 8.64 s / 111.5 MB | 5.24 s / 8.67 s / 110.7 MB |
| baseline warm | 0 of 10 | 5.38 s / 8.73 s / 111.6 MB | 5.08 s / 8.64 s / 110.5 MB |
| baseline warm, repeat | 0 of 10 | 5.13 s / 8.65 s / 111.6 MB | 5.19 s / 8.68 s / 111.4 MB |
| prototype, on, cold | 0 of 10 | 6.06 s / 8.96 s / 115.0 MB | 6.25 s / 8.67 s / 116.4 MB |
| prototype, on, warm | 0 of 10 | 5.90 s / 8.64 s / 116.6 MB | 6.05 s / 8.64 s / 115.6 MB |
| prototype, on, warm, repeat | 0 of 10 | 5.74 s / 8.65 s / 116.0 MB | 6.11 s / 8.69 s / 118.3 MB |
| prototype, off, warm | 0 of 10 | 5.64 s / 8.76 s / 110.6 MB | 4.90 s / 8.64 s / 111.1 MB |

**Early signal, simulator only.**
- With the experiment on, comparing run medians, the prototype used more app CPU per pan window than the baseline:
  - 0.4–0.9 s more with the thesis selected (+7–18%);
  - 0.8–1.2 s more with nothing selected (+15–23%).
- It also held 3–8 MB more memory (the faces' images).
- With the gate off, it matched the baseline.
- Memory did not grow across the five pans in any run; the per-pan values wander within about ±2.5 MB.
- The simulator renders on the Mac's GPU and recorded no hitch data. **The device runs are what decide this**, with frames from the trace. The CPU difference is the first thing to check there.

## 5. Physical device (baseline vs prototype): gate reported separately

**Device.**
- "Al's iPhone", an iPhone 14 Pro on iOS 26.6.1, paired and in Developer Mode.
- Installed apps checked: only `co.tradersguild.app` and the production-connected `TG Prod QA`. **Neither was used.** The isolated `co.tradersguild.app.linkeddev` installs beside them.

**Gate: closed.**
- Earlier the runs reached the phone and stopped at "Unlock Al's iPhone to Continue" (`passcodeRequired: true`). That runner was stopped as instructed; its smoke result is kept (`rb-perf-smoke-proto-on.xcresult`).
- The phone is now listed as `unavailable`, so it is no longer on the Wi-Fi tunnel at all.
- **No device runner is queued or running.**
- **Owner action:** bring the phone onto the same Wi-Fi, unlock it, and keep it awake (Auto-Lock → Never for about 70 minutes, then restore it). After that, one command runs the whole sequence: `perf-tooling/run_all.sh`.

**Ready.**

| Piece | State |
|---|---|
| Builds (`LinkedDev Profile`, DevProfile, generic iOS) | Prototype from `431a9d6`: `$S/dd-device-proto`. Baseline `72b6f2b` from a `git archive`, with the identical driver file copied in: `$S/dd-device-base`. |
| Fixtures (identical for both builds) | Local DEV, guild "Stage4 QA 658f08", BTC/USD **1h**: 61 seeded markers from 5 disposable authors, all with uploaded avatars. They are Analysis, Question and untracked Setup, with same-candle stacks and 3 parents carrying Supports/Challenges/Builds on responses (`perf-tooling/seed_perf.py`). |
| Sequence (`run_all.sh`) | prepare (baseline) → rotate → baseline cold → baseline warm → prepare (prototype) → rotate → prototype cold → prototype warm → prototype with the gate off → baseline warm repeat → prototype warm repeat. It waits for an unlocked phone before every step, keeps the simulator's LinkedDev app closed (every client's avatar requests reach the same server log), and stops at the first failure. |
| Cold / warm | "Cold" = the first launch after `rotate_avatars.py` re-uploads the same five pictures under new URLs. "Warm" = a later run with the URL cache in place; fresh-process and in-process warm are separate windows. |

**Acceptance still to be judged, against the master plan §4.** On the device runs, compare per phase and per build:
- the first-launch window on cold runs: frames from the trace, and the 200s per author;
- warm windows: whether downloads repeat;
- pans: hitches, CPU and memory, plus drift checks and captures.

Any new sustained growth or stall blocks acceptance. **No performance acceptance is claimed.**

## Local data added in Stage 5 (local DEV only, additive)

- Accounts `stage4658f08c/d/e` (`@example.com`). `is_verified` was set in the local DB for those rows, as in Stage 4. They joined guild "Stage4 QA 658f08". Credentials live only in `$S/stage4/qa-creds.json` and were never printed.
- Avatars for accounts A–E, uploaded through the LAN gateway address. They are re-uploaded under new URLs before cold runs; the pictures stay the same.
- 61 markers on BTC/USD 1h in that guild. Stage 4 evidence records are untouched.

## Remaining work and gaps

1. **Physical-device comparison** (§5): needs the phone available, unlocked and awake. Then export hitches per phase from the traces, and evaluate against the master plan's acceptance rules.
2. **VoiceOver and Switch Control by hand** on the device.
3. **Older-client runtime compatibility** (iOS 1.1.1/1.1.2, Android): still source inference only. This is required before production adoption (master plan §4) and needs Astra-coordinated worktrees.
4. **Decisions carried forward:** the owner-delete permission mismatch (deferred for separate triage); legacy Reduce Motion; the link-banner wrap.
