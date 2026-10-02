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
| **Physical-device baseline vs prototype** | **Not compared yet.** Baseline cold was measured on the phone (§6). The sequence then stopped on the app losing its session (401 on token refresh), which needs triage. Frame evidence needs a short-trace pass. |

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

## 6. Physical-device session, 2026-10-01: partial, blocked again

The owner made the phone available, unlocked, with UI Automation enabled (the first blocker: "Timed out while enabling automation mode"). Over about two hours the session produced one complete, valid measure run (baseline cold). It also found and fixed six driver problems on the device, which a simulator could not show. The sequence then stopped on a session loss that needs a decision.

### Device problems found and fixed (all test-only, both builds share the identical driver file)

| Commit | Problem on the phone | Fix |
|---|---|---|
| `7469606` | The phone's LinkedDev app was signed in to an older local QA account (another guild), so the fixtures were out of reach; parking needed the BTC/USD tab. | The sign-in step checks the drawer's account card against the run's username. Logging out is left to a person: Settings also holds Delete Account. Parking opens the seeded parent and closes it first. |
| `09bf30d` → `d3fcd57` | The test runner cannot write the pasteboard on a device, so the pasted password never arrived. Typing it was tried after a dummy-password probe logged `<redacted>`, but a real run then logged the start of the password in clear. | **The driver never types credentials.** `run_perf.py` passes only the username. A signed-out app fails with a request to sign in by hand. |
| `2021bf3` | The drawer ignored a tap straight after sign-in. | Retry the tap. |
| `dc94a08` | `XCTHitchMetric` read 0 everywhere, and the run's system trace lost its frame data when the first recorded measure began: they compete for the kernel trace session. | The metric is dropped; frames come from the trace. |
| `563e5ee` | **`XCUIApplication.open(url)` launches a new app process for every link.** The pid changed on every open and the server saw a full app start each time. So "in-process revisit" was a relaunch, and every measured pan began just after a launch, with launch work able to spill into the window. | Links go through `XCUIDevice.shared.system.open`, as a tapped link would. Simulator check: 13/13, only the 3 intended launches, no revalidation bursts outside them. The prototype's pan CPU fell from 5.7–6.3 s to 4.8–4.9 s per window. **So the simulator CPU signal in §4.5 was measured with relaunching anchors, and must be re-measured with this driver before it is read at all.** |

### Valid device evidence: baseline cold (`base-cold-20261001T173621Z`, corrected driver, exit 0)

- **Selection and branches:** every pan test asserted its state. View checks: 0 of 10 pans ended off the seeded view, max shift 17 of 64 columns, min spread 0.95.
- **Pans:** app CPU 4.04 s (selected) and 3.89 s (unselected) per ~8.7 s window, medians of 5. Memory about 159–167 MB at the end of each pan, with no growth across the five.
- **Load:** the first (cold) launch and load made 6 downloads and 4 revalidations. **The two measured relaunches downloaded avatars again (14 downloads)**. So on the phone the URL cache did not carry avatars across a relaunch, unlike the simulator. This is the baseline build, so it predates v1.5.
- **No avatar requests** during in-process revisits, anchors or pans.
- Summary: `test-results/device-base-cold-summary.json`.

No prototype run completed, so **there is no baseline/prototype comparison yet, and no acceptance**.

### Frame and hitch evidence: not yet obtained

- A system-wide Animation Hitches trace works on the phone for about a minute: a 15 s preflight was complete, and one run's frame data stopped at 61.7 s.
- A trace covering a whole 7-minute measure run comes back "Transferred trace file is malformed", with no frame data.
- `run_frames.py` / `run_frames_all.sh` are ready for a follow-up frames pass: one short trace per test (cold first launch plus each of the 10 pans, for both builds; about 25 minutes of phone time). `hitches_by_phase.py` reads each trace per phase window. It was checked on the 61.7 s trace, which gave per-window frames and hitches.

### Blocker: the app loses its session on the phone

Three times the app's launch-time token refresh got 401 and the app signed out (17:16:06, 17:32:48, 17:44:13 UTC). Each time, the rest of the run failed with "not on the chart".
- The auth service rotates refresh tokens, with a 30-second replay grace.
- The pattern fits the app keeping a stale refresh token at launch: launches within 30 s of each other succeed, and the first launch after a longer gap is rejected.
- The app's restore path does save the rotated token, and the server's only user-wide revocation is password reset. So the cause is not yet known.
- It may be specific to rapid test-driven relaunches, or a pre-existing app issue. **It needs triage before another device sequence:** each measure run's first launch would be rejected.

### Credential exposure (local only)

- The start of local QA account A's password appears, in clear, in local scratchpad files under `$S/stage5`: two run logs, two result bundles, and their exported attachments.
- The test runner's environment, which held account A's password, was also written into a result bundle's session log. So other result bundles, including the simulator runs that used account B, probably hold one of them in compressed form.
- **Nothing in the repo or in any commit contains them.**
- **Recommended:** rotate the local QA passwords for accounts A and B, then sign the phone back in by hand. The account is disposable local DEV and the stack is reachable only on the LAN. The files are kept, since results are preserved.

## 7. Session-loss triage (read-only), and the recovery sequence

**Method.**
- Sources: the auth service's access log (times and status codes only), and the server's own rotation record in local Redis. Each rotated refresh token leaves a revoked-id key whose remaining lifetime gives the token's issue time (refresh tokens live exactly 30 days). So for every launch-time refresh, it is known whether the token it issued was presented again later.
- Plus a reading of the client and server code.
- No token, token id or password was printed or written.

**What the record shows.**

| Device run | Driver | Tokens issued by launches |
|---|---|---|
| prepare runs (all) | any | all kept |
| 17:00 base cold, 17:10 base warm (≈45 launches) | `2021bf3`: app CPU/memory **plus `XCTHitchMetric`** | all kept, including launches inside `measure` |
| 17:15 base cold | `dc94a08`: no hitch metric | kept until the first launch inside `measure`; not kept from 17:15:36. At 17:16:06 the app presented a token rotated more than 30 s earlier: rejected, signed out. |
| 17:36 base cold | `d3fcd57` | first launch (outside `measure`) kept. Both launches inside `measure` not kept: the second presented the first's token again, which was accepted only through the 30 s replay. 17:44:13 rejected, signed out. |

The simulator never lost a token, including a measured relaunch in its 17:27 run.

**Ruled out.**
- *Cross-app keychain.* LinkedDev has its own access group (`…co.tradersguild.app.linkeddev`), separate from production and Prod QA.
- *Biometric login.* It runs only when a person taps it on the sign-in screen.
- *Server policy.* Rotation and the 30 s replay behave as designed, and there are no per-user revocation watermarks (0 keys).
- *App installs between runs.* Prepare runs kept tokens straight after installs.

**Classification: the strongest observed correlation, not a proven root cause.** Session loss correlates with app launches inside an XCTest `measure` block with the app CPU and memory metrics on the phone, under drivers from `dc94a08`. **The internal mechanism remains unknown.** It is not isolated because the app logs with `print`, which the device's unified log does not keep. The evidence fits two explanations:
- the app's keychain write silently failing for processes launched under that measurement;
- the refresh response being lost to the client, in which case `restoreSession` keeps (and writes back) the cached token.

**Latent application fragility** (shipped, not v1.5; affects old clients the same way):
- `KeychainPreferences.save` deletes and then adds, and ignores both statuses. A failed add after a successful delete loses the token; a failed delete plus a failed add keeps a stale one silently.
- `restoreSession` keeps the cached refresh token after a transient refresh failure, even if the server already rotated it.

Either one becomes a sign-out on the next launch more than 30 s later. The code dates from April–May 2026, in builds from 1.1.5 on. Server rotation dates from 2026-04-23 and the replay from 2026-05-06. No evidence of real-user impact was gathered.
- A fix would be an app change (check `SecItem` statuses and update in place; after a failure that may have reached the server, retry within the replay window before keeping the old token). That goes beyond test tooling, so **it is not made here and needs a separate decision.**
- Backend observation, unchanged: `PUT /api/v1/users/me/password` does not revoke existing sessions; only the email reset flow does.

**Smallest correction: test-only, made.** No test launches the app inside `measure`. The measured relaunch is removed: on a warm run, the single first launch already is the fresh-process warm launch. Every remaining `measure` block (the in-process revisit, the pans) launches nothing.
- Simulator: 13/13, one launch per run.
- Device bundles rebuilt.
- This uses only the pattern the record shows keeping tokens. It is a recovery experiment, not a proven fix: `session_check.py` must pass on the phone before the long sequence.

**Session check, corrected after review (`perf-tooling/session_check.py`).** It fails closed. Every rule must hold:
- prepare, launch-1 and launch-2 all exit 0 (launch-2, more than 30 s later, must reach the chart with the parent selected);
- each launch has a complete `first-launch-and-load` window, with at least one refresh returning 200 inside it;
- no refresh is rejected anywhere in the check;
- launch-2's refresh is more than 30 s after launch-1's, with no other refresh in between, so it cannot be a replay;
- exactly one of the run account's push-token rows (`traders_guild.device_tokens`, read after each launch) is updated inside each window, and the device fingerprint is the same for both launches. That ties both launches to this account on this phone.

Identifiers appear only as sha256 fingerprints (account, device, request correlation id). The Redis rotation record is reported as corroboration only, never as proof.
- Offline tests: `perf-tooling/test_session_check.py`, **19 / 19**: the consistent case passes, and each failure or missing-evidence case fails for the stated reason. Cases: prepare failed or missing; either launch's test failed; one or no launches; a missing or incomplete window; no refresh evidence; only one refresh; a rejection anywhere; launches inside the replay window; a refresh between the launches; a missing, duplicate or out-of-window device row; different devices.
- Readers checked read-only against local DEV: the phone's row for account A was last updated at 17:37:05, the last measured relaunch before the sign-out.

**Password rotation for QA A and B: done** (`perf-tooling/rotate_qa_passwords.py`, local script, no GUI).
- Run from this Mac against the local gateway only, after review of its safeguards:
  - accounts a–e only;
  - the credentials file must already be mode 600;
  - new credentials are staged mode 600 in the same directory, persisted the moment the change succeeds, and removed on any failure before that;
  - output is account letters and HTTP status codes only.
- Result: for both A and B, current-password login 200, change 200, new-password login 200. `qa-creds.json` is still mode 600, with no staged file left. The new passwords appear in no other file under the scratchpad or `docs/`.
- **Fixtures preserved:** before and after snapshots (`test-results/fixtures-{before,after}-rotation.txt`) are identical except the password-hash fingerprint. That covers 5 users (ids, avatars, status), all 72 markers in the guild, and the device row.
- **Limitation, recorded and not changed:** `PUT /api/v1/users/me/password` does not revoke existing sessions; only the email reset flow sets the per-user revocation watermark. Sessions opened with the old passwords stay valid (the simulator app is still signed in as A). No auth policy was broadened.

**Manual sign-in handoff (owner, about 1 minute).**
- The credentials are in the protected local file `$S/stage4/qa-creds.json` (mode 600), under `accounts.a`: `email` and `password`.
- On the iPhone, open **TG LinkedDev** (not Traders Guild or TG Prod QA), tap Sign in with Email, and enter account A's email and password from that file. Choose the guild **Stage4 QA 658f08** if asked.
- Leave the phone unlocked on the same Wi-Fi.
- Claude does not enter credentials on the phone or in any test.

**Recovery sequence:**
1. ~~Rotate QA A and B passwords~~: done.
2. *(Owner)* Manual sign-in, as above.
3. *(Claude, about 3 minutes of phone time)* `session_check.py <dd-device-base>`. **No long sequence unless it prints PASS.** On FAIL, stop and report.
   - **Result, 2026-10-01: PASS** (`test-results/device-session-check.json`, fingerprints and times only). The owner signed in by hand.
     - Prepare exit 0.
     - launch-1 exit 0: window 19:10:01–19:10:18, refresh 19:10:05 → 200, device row `fb7292cb` updated 19:10:05.
     - launch-2 exit 0, reaching the chart with the parent selected: window 19:11:26–19:11:41, refresh 19:11:28 → 200 (83 s after launch-1, no refresh between), the same device row updated 19:11:28.
     - Account `ef5590f3` (account A).
     - Corroboration (not proof): the token issued at launch-1's refresh appears in the rotation record.
     - This supports the recovery experiment, launches only outside `measure`. It does not prove the root cause.
4. *(Owner keeps the phone awake for about 95 minutes; Claude)* `run_all.sh` once, then `run_frames_all.sh` once.
5. *(Claude)* Per-phase results, the checkpoint update, and a report to Astra before any acceptance.

## 8. Device comparison, 2026-10-01 21:49–22:30 UTC: complete

iPhone 14 Pro, iOS 26.6.1, LinkedDev Profile, local DEV. Driver `5e7826a`: launches only outside `measure`, links in-process, no whole-run trace. The whole-run trace was switched off because each 7-minute trace appeared to leave its data on the phone, filling its storage twice. All seven measured runs exited 0. Summary: `test-results/device-sequence-summary.json`.

**Pans: app CPU per ~8.7 s pan window, medians of 5; memory at the end of the pan.**

| run (UTC start) | selected | unselected | memory |
|---|---|---|---|
| baseline cold (21:50) | 3.53 s | 3.52 s | 159 MB |
| baseline warm (21:55) | 3.35 s | 3.59 s | 159 MB |
| prototype on, cold (22:00) | **5.31 s** | **5.24 s** | 164 MB |
| prototype on, warm (22:05) | **6.54 s** | **5.18 s** | 172 / 162 MB |
| prototype off, warm (22:10) | 4.06 s | 3.93 s | 159 MB |
| baseline warm, repeat (22:20) | 5.00 s | 4.54 s | 160 MB |
| prototype on, warm, repeat (22:25) | **8.52 s** | **6.91 s** | 164 MB |

- **The experiment adds CPU while panning:** about +1.5 to +3.5 s of app CPU per pan window over the baseline and the gate-off build run at nearby times (roughly 1.4–1.8×), with the thesis selected and with nothing selected. The simulator signal is confirmed on the device. With the gate off, the prototype is close to the baseline.
- **Every build rises later in the session** (the baseline repeat is 5.00 s against 3.35 s earlier), so device warmth matters. The experiment-on runs are higher than their neighbours each time.
- The final experiment-on run had 2 of 10 pans ending off the seeded view (an overshoot), and a longer selected-pan window (9.6 s).
- Memory: about +3 to +13 MB with the experiment on, and no growth across pans.
- Selection checks held in every run: title present or absent as required, and the anchored views exact.

**Avatar requests**
- Cold first launch: the baseline downloaded each author twice (10); the prototype downloaded each once (5).
- Warm launches: 0 downloads and 4 revalidations in every build.
- Revisits, anchors and pans: 0 requests.
- **The prototype adds no avatar network traffic.**

**Frames and hitches: not obtained.** The per-test short traces came back with no displayed-frame data (the first-launch trace was empty). The pan trace attributed many hitches to `AutomationModeUI`, the overlay iOS draws while UI automation runs. Under XCUITest on this phone the frame instrument measures the automation overlay as much as the app, so the pass was stopped after three tests and is not evidence. Frame smoothness would need a manual, non-automated recording session (Instruments with the phone driven by hand).

**Acceptance: not met for performance.** The prototype costs noticeably more CPU while panning on a real device. This is for Astra and the owner to judge against the master plan §4; it needs a profiling and optimisation pass before acceptance. Downloads and memory look acceptable.

## 9. Profiling and optimisation pass (after Astra: Stage 5 not accepted)

Mac only; no phone work.

**Method.** Measurements were controlled, not assumed.
1. `/usr/bin/sample` of the simulator app during the pan test, main-thread call trees (`profiling/main_thread_profile.py`, `subtree.py`). The XCUITest-driven samples did not control frame counts, so they were used only to point at candidates.
2. Temporary, uncommitted instrumentation (`profiling/profiling-instrumentation.diff`): per-second counts of chart body evaluations and Canvas draws, time inside each Canvas draw closure, process CPU time, and SwiftUI `_printChanges()`. Pans were driven identically by the same XCUITest pan test, with builds alternated (`profiling/time_pan.sh`). Switches temporarily skipped the face draw, its circle clip, or the intent badge.

**Findings** (`profiling/timings.md`):
- **Not the cause:**
  - *Body invalidation or redraw frequency:* bodies and draws per second are the same with the experiment on and off (9–12/s idle, 50–56/s panning), triggered by the same state (`gestureState`, `indicatorManager`). Idle CPU is similar.
  - *Canvas resolution or the candle canvas:* 0.31–0.32 ms per frame in both.
  - *Face symbol draw, image decode or resize, circle clip:* skipping the face draw or the clip changed nothing (2.51 and 2.60 ms against 2.45).
  - *Symbol creation:* the avatar symbol list is rebuilt only when markers or avatars change, not per frame.
- **Attributed cause (by controlled simulator profiling; device confirmation pending):** the experiment's **intent badge glyph**. It was a `Text(Image(systemName:))` drawn for every marker on every frame, through string layout (`StringDrawing.size` in the profile). Skipping just the badge brought the marker canvas from 2.45 to 1.56 ms per frame (experiment off: 1.41–1.58), and process CPU from 670 to 615 ms/s (off: 594–604).

**Fix (`5f9ee89`).** The badge glyph is now the same SF Symbol (8 pt, heavy) as a template image:
- built once per symbol, tinted per draw pass (theme-safe), drawn at the same point;
- only the experiment's intent badge used this path, so experiment-off drawing is unchanged;
- geometry, the 36 pt disc, hit targets, selection, branches, avatar freshness and request deduplication are untouched.

**After the fix** (matched, alternating):

| pan | marker canvas, on → off | process CPU per second, on → off |
|---|---|---|
| selected | 1.63–1.73 → 1.47–1.48 ms per frame | 574–593 → 576–604 ms |
| unselected | 1.63–1.74 → 1.42–1.47 ms per frame | 564–597 → 550–553 ms |

The marker canvas's extra cost fell from about +1.0 ms to +0.2–0.3 ms per frame, and process CPU is within run-to-run noise of experiment off.

**Visual check.** Gallery captures (intents, Setup states, relationships; Dark and Light Grey; selected) before and after differ in 287–527 pixels per scene, all at the badge glyphs. Zoomed, the glyph, weight and colour are the same, with only sub-pixel anti-aliasing differing (`profiling/badge-glyph-before-after-zoom.jpg`).

**Tests.**
- New `MarkerBadgeGlyphImagesTests` (2): every badge symbol has a template glyph at badge size, built once.
- Focused marker suites (badge glyphs, intent decoration, link render and geometry, avatar render, focus hit testing): **95 / 0**.
- Full unit target: **801 / 0**.

**Reproducible artifacts** (local scratchpad, kept):
- **Focused suites, 95 / 0:** `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/stage6/rb-s6-focused-065738.xcresult`
- **Full unit target, 801 / 0:** `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/stage6/rb-s6-full-065918.xcresult`
- Both ran on `5f9ee89`, simulator iPhone 17 Pro, `traders_guild LinkedDev` scheme, DevDebug.
- **Prototype device build:** `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad/dd-device-proto/Build/Products/`
  - test plan: `traders_guild LinkedDev Profile_iphoneos26.5-arm64.xctestrun`
  - apps: `DevProfile-iphoneos/traders_guild.app` and `traders_guildUITests-Runner.app`
- How the device build was made: `xcodebuild build-for-testing -scheme "traders_guild LinkedDev Profile" -configuration DevProfile -destination generic/platform=iOS -allowProvisioningUpdates DEVELOPMENT_TEAM=B4WE2NR99U`, at 2026-10-02 07:26 UTC. That is after `5f9ee89` (07:00 UTC) and before `a1eafa0` (docs only), so it is `5f9ee89` code.
- Build checks:
  - `** TEST BUILD SUCCEEDED **` (log `stage6/build-device-proto.log`);
  - the app binary contains the `MarkerBadgeGlyphImages` symbols;
  - it is signed `co.tradersguild.app.linkeddev`, team `B4WE2NR99U`.
- The later comment-only correction to the badge glyph's doc comment does not change the built code.
- The baseline device build (`dd-device-base`, `72b6f2b` plus the identical driver) is unchanged.

**Wording note.** Commit subject `a1eafa0` says "badge glyph was the pan regression". Read it, like the rest of this section, as attributed by controlled simulator profiling. Device confirmation is pending, and physical performance acceptance remains pending.

**Limits.**
- The simulator renders on the Mac's GPU, so this justifies a device session; it does not replace one.
- No frame-smoothness claim is made from CPU alone.
- The earlier device run's thermal drift (every build rose later in the session) and its overshot pans are limitations of that evidence.

**Proposed device session** (to coordinate before any phone time; short, not the hour-long run):
- The prototype device bundle is rebuilt from `5f9ee89`; the baseline is unchanged.
- Run interleaved, cooled pairs: baseline warm, prototype on, prototype off, baseline, prototype on, with a few minutes' pause between runs. About 35 minutes.
- No whole-run traces, and no trace capture without coordination.
- The `session_check.py` gate comes first.

## 10. Device confirmation of `5f9ee89` (integrated as `37fb5e2`), 2026-10-02 17:28–18:07 UTC

iPhone 14 Pro, iOS 26.6.1, LinkedDev Profile, local DEV. The same fixtures and the same driver (identical file in both builds), with selection and drift checks.

**Pre-flight.**
- Phone connected and unlocked; no runner active; outbound integrations off.
- The prototype bundle contains the glyph optimisation (`MarkerBadgeGlyphImages` symbols present); the baseline does not.
- No whole-run or frame traces, no credentials in tests.
- Thermal state: devicectl does not expose it. Cooling was a fixed 2-minute pause between runs.

**Gate.** `session_check.py` **PASS** (`test-results/device-session-check-2026-10-02.json`): both launches reached the chart, refreshes returned 200, and launch-2 came 83 s after launch-1 with no replay possible.

**Interleaved, all warm** (`perf-tooling/run_interleaved.sh`; `test-results/device-interleaved-summary.json`). App CPU per ~8.7 s pan window, median of 5 [range]; memory at the end of the pan:

| run (UTC start) | selected | unselected | memory | pans off the seeded view |
|---|---|---|---|---|
| baseline warm (17:31) | 4.19 s [4.15–4.30] | 4.11 s [3.95–4.17] | 161 / 157 MB | 0 of 10 |
| **prototype on (17:38)** | **4.12 s [4.07–4.33]** | **4.09 s [4.03–4.27]** | 166 / 164 MB | 0 of 10 |
| prototype off (17:45) | 4.05 s [3.96–6.25] | 3.98 s [3.77–4.02] | 159 / 158 MB | 0 of 10 |
| baseline warm, repeat (17:51) | 4.09 s [3.83–4.29] | 4.03 s [3.92–4.27] | 158 / 159 MB | **1 of 10** (an overshoot, shift 24) |
| **prototype on, repeat (18:02)** | **4.17 s [3.91–4.38]** | **3.90 s [3.76–3.96]** | 162 / 159 MB | 0 of 10 |

- **The pan CPU regression from §8 (+1.5 to +3.5 s per window) is not present.** With the experiment on, pan CPU is within the spread of the baseline and the gate-off build, in both states and both repeats.
- Memory with the experiment on is about +1 to +7 MB, with no growth across pans.
- Avatar requests are identical in every run: 0 downloads and 4 revalidations at launch, nothing during revisits, anchors or pans.
- **Reported honestly:**
  - one baseline pan overshot (shown above);
  - the prototype-off run has one high selected sample (6.25 s, its first pan);
  - the background task running the sequence hit its time limit during the last run. The interrupted attempt is kept (`rb-perf-i-proto-on-2-…-175810Z`). The run was repeated after a 1-minute pause as `i-proto-on-2b` (the cooling before it was about 4.5 minutes in total).
- Wall time about 39 minutes including the gate (owner expected about 35).

**Not claimed:**
- No acceptance; that is for Astra and the owner against master plan §4.
- No frame-smoothness claim from CPU: frame and hitch evidence remains unobtained under XCUITest (§8).
- Thermal state was not recorded.

## Local data added in Stage 5 (local DEV only, additive)

- Accounts `stage4658f08c/d/e` (`@example.com`). `is_verified` was set in the local DB for those rows, as in Stage 4. They joined guild "Stage4 QA 658f08". Credentials live only in `$S/stage4/qa-creds.json` and were never printed.
- Avatars for accounts A–E, uploaded through the LAN gateway address. They are re-uploaded under new URLs before cold runs; the pictures stay the same.
- 61 markers on BTC/USD 1h in that guild. Stage 4 evidence records are untouched.

## Remaining work and gaps (current, 2026-10-02)

Owner hands-on review note: `V1_5_STAGE5_OWNER_HANDS_ON.md`. Test-tooling summary for integration: `V1_5_STAGE5_TOOLING_INTEGRATION.md`. Warm-pan CPU regression accepted by Astra as resolved within the baseline spread (`e1ffd10`); this is not Stage 5, frame-smoothness or production acceptance.

1. **Device confirmation of the fix:** done (§10). Pan CPU with the experiment on is within the spread of the baseline and gate-off builds. Performance acceptance is for Astra and the owner.
2. **Frame smoothness:** not measurable under XCUITest on the phone (§8). It needs a hand-driven Instruments session if Astra wants frame or hitch evidence.
3. **VoiceOver and Switch Control by hand** on the device.
4. **Older-client runtime compatibility** (iOS 1.1.1/1.1.2, Android): still source inference only. Required before production adoption (master plan §4); needs Astra-coordinated worktrees.
5. **Decisions carried forward:** the owner-delete permission mismatch; legacy Reduce Motion; the link-banner wrap.

## Deferred issues, recorded separately (not v1.5 scope; no change made)

- **Client auth-token fragility** (shipped since about 1.1.5; §7). `KeychainPreferences.save` deletes then adds and ignores both statuses, and `restoreSession` keeps a cached refresh token after a transient refresh failure. Either can turn a lost token update into a sign-out on the next launch more than 30 s later. Seen only under test-driven launches on the phone; root cause not proven.
- **Password change does not revoke sessions:** `PUT /api/v1/users/me/password` leaves existing sessions valid; only the email reset flow sets the revocation watermark (§7). Recorded only; auth policy unchanged.
