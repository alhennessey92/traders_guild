# v1.5.0 Stage 5 checkpoint: performance and acceptance (Claude)

Branch `claude/1.5.0-avatar-markers`, continuing from `a4631c7` (Stage 4 follow-up). Worktree `.worktrees/marker-avatar-claude`. Local commits only: not pushed, not deployed, not submitted. No backend, Android or production changes. This is the Stage 5 acceptance checkpoint for Astra and the owner.

`$S` = `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad`.

## Commits

| Commit | What |
|---|---|
| `1288203` | Review correction: the guided/request tracked-Setup guard refuses non-finite prices (`MarkerSetupSide.invalidPrice`). |
| `a8c7467` | Accessibility corrections to guided creation (Dynamic Type, VoiceOver), plus Reduce Motion for selection under the experiment. Includes unit and UI tests. |
| `188b8c0` | Device performance driver, test-only and portable. |
| this commit | This checkpoint, evidence and reproducible tooling. |

## Status at a glance

| Area | State |
|---|---|
| Finite-price guard (review correction) | Done, tested, mutation-checked. |
| Accessibility (themes, Dynamic Type, VoiceOver, Reduce Motion) | Done on the simulator, with corrections. VoiceOver speech and rotor were not driven by hand. |
| Regression | Full unit target **797 / 0**. Accessibility UI tests **11 / 0** (DevProfile). Production binary checked. |
| **Physical-device baseline vs prototype** | **Not measured: device locked.** Builds, data, driver and the full run sequence are ready and queued (see "Physical device"). |

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

All three render faces, intent badges, rings, arcs and branches legibly.

**Observation.** In Light Grey, the initials-fallback discs are grey on grey, with lower contrast than in the dark themes. Faces and badges are unaffected. Not changed.

### Recorded, not changed (outside v1.5 scope)

- **Link banner wrapping.** The 1.3.0 link banner ("Challenges … Change") breaks "Chang·e" at AX XXXL. It is shared with the legacy panel; shipped behaviour.
- **Chart markers are drawn on a Canvas.** VoiceOver cannot reach individual chart markers, and that was already true of legacy markers. The accessible routes are the marker list, the detail sheet and the thesis rows. Their relationship words are covered by `MarkerLinkAccessibilityTests`.
- **Legacy Reduce Motion.** The legacy (experiment-off) selection pop and wiggle still ignore Reduce Motion. Applying `MarkerSelectionMotion` to all users would be a one-line change, but it changes shipped behaviour, so it needs a separate decision.
- **Not driven by hand.** VoiceOver speech, rotor order and Switch Control. The UI tests verify the accessibility tree, not speech.

## 3. Regression

- **Full unit target** (`traders_guildTests`, LinkedDev DevDebug) on `a8c7467`: **797 passed, 0 failed, 0 skipped**. Evidence: `$S/rb-s5-full.xcresult`, `test-results/full-unit-target-summary.json`.
- **Production configuration.** In the `GCP Public Prod` Release binary:
  - the gate key `TGAvatarMarkersExperiment` and the fixture key `MarkerGuidedCreationFixture` are **absent**, so neither arguments nor saved preferences can enable the experiment there;
  - the guided views are compiled in but unreachable, because `MarkerAvatarExperiment.isAvailable` is `false`.

  The DevProfile binary contains both keys. Production was not launched.
- Stage 4's local-DEV runtime checks still stand, and the local stack is unchanged. It runs chart-service on `5061824`, with outbound integrations off.

## 4. Physical device (baseline vs prototype): blocked, ready to run

**Device.**
- "Al's iPhone", an iPhone 14 Pro on iOS 26.6.1, paired and in Developer Mode.
- Wi-Fi tunnel, so it reaches the local gateway at `192.168.1.182:30080`.
- Installed apps checked: only `co.tradersguild.app` and the production-connected `TG Prod QA`. **Neither was used.** The isolated `co.tradersguild.app.linkeddev` installs beside them.

**Blocker.** The runs reach the phone and stop with "Unlock Al's iPhone to Continue": XCTest cannot drive a locked device. `devicectl` reports `passcodeRequired: true`. **The owner needs to unlock the phone and keep it awake** (Auto-Lock → Never for the duration, then restore it).

**What is ready.**

| Piece | State |
|---|---|
| Builds (`LinkedDev Profile`, DevProfile, device) | Baseline `72b6f2b`, from a `git archive`, with the identical driver file copied in: `$S/dd-device-base`. Prototype at HEAD: `$S/dd-device-proto`. Both `TEST BUILD SUCCEEDED`. |
| Fixtures (identical for both builds) | Local DEV, guild "Stage4 QA 658f08", BTC/USD **1h**: 61 seeded markers from 5 disposable authors, all with uploaded avatars. They are Analysis, Question and untracked Setup, with same-candle stacks and 3 parents carrying Supports/Challenges/Builds on responses (`perf-tooling/seed_perf.py`). The deep link opens parent `0ab0ce3d` with its thesis. |
| Driver (`188b8c0`) | Signs in once if needed, then measures 5 iterations of fixed out-and-back pans with the thesis selected, and then with nothing selected. Metrics: XCTHitchMetric, CPU, memory, clock. |
| Downloads | Core/chart access logs counted per run window (`run_perf.py`). |
| Cold / warm | "Cold" = avatar URLs rotated just before the run (same images, new URLs never fetched). "Warm" = the following run, with the URL cache in place (`rotate_avatars.py`). |
| Sequence (`run_all.sh`) | baseline cold → baseline warm → prototype cold → prototype warm → prototype with the gate off → baseline warm repeat → prototype warm repeat. |

It was queued in this session; each run waits for the phone to unlock.

**Expectations to check, not results.**
- The baseline draws faces only for Personal markers, so it should fetch no marker avatars.
- The prototype should fetch one avatar per distinct author on a cold run (5), none on a warm run, and none during pans.
- Hitches, CPU and memory are compared per phase across the two builds. Any new sustained growth or stall blocks acceptance (master plan §4).

**Not yet measured.** Frame behaviour, memory, downloads, panning, selection and branch rendering on the physical device. No performance acceptance is claimed.

## Local data added in Stage 5 (local DEV only, additive)

- Accounts `stage4658f08c/d/e` (`@example.com`). `is_verified` was set in the local DB for those rows, as in Stage 4. They joined guild "Stage4 QA 658f08". Credentials live only in `$S/stage4/qa-creds.json` and were never printed.
- Avatars for accounts A–E, uploaded through the LAN gateway address. They are rotated before cold runs.
- 61 markers on BTC/USD 1h in that guild. Stage 4 evidence records are untouched.

## Remaining work and gaps

1. **Physical-device comparison**: unlock the phone; the queued sequence, or `perf-tooling/run_all.sh`, runs it. Then evaluate the results against the master plan's acceptance rules.
2. **VoiceOver and Switch Control by hand** on the device.
3. **Older-client runtime compatibility** (iOS 1.1.1/1.1.2, Android): still source inference only. This is required before production adoption (master plan §4) and needs Astra-coordinated worktrees.
4. **Decisions carried forward:** the owner-delete permission mismatch (deferred for separate triage); legacy Reduce Motion; the link-banner wrap; initials contrast in Light Grey.
