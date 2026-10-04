# v1.5 marker sheet — Slice 1 review checkpoint

2026-10-04. Local implementation on `sol/1.5.0-marker-sheets`, based on `52fdf64`, in `.worktrees/marker-sheet-sol`. **Stop at the Slice 1 orchestration review gate.** Master release scope remains sanctuary `docs/version_docs/ios/1.5.0.md`; coordination is in `docs/v1_5_sheet_ux_review/IMPLEMENTATION_HANDOVER.md`.

Initial source/evidence: `55be8ea` / `0e4eb0f`. Correction source: `1bc3b57`. Correction evidence/checkpoint follows in a separate documentation commit. Bounded orchestration corrections are recorded below. No integration, push, production changes, release, account changes, or physical-device automation were performed.

## Implemented

- Guided placement/editing has a dedicated compact task dock with draft status and **Continue editing**. It offers no Review/Post/Save action. **Show chart** dismisses the keyboard and returns to the dock, keeping the draft and current step. Interactive drawing also uses this dock.
- Add and guided forms capture intrinsic content height once per structural revision, width and text size, then bound the working height by the actual presenting container and window safe height. Compose typing does not resize the sheet. Title/disclosure expansion and Review snapshots can request a new fit. Flexible context uses a bounded fallback. Long text and large text scroll or use the 90% tall state. The guided dock is 18%; Add/legacy compact remains 11%. Valid compact/tall choices survive route transitions and chart/resume.
- Guided Add gets a concise heading and solid theme surface. Entry cards use small intent glyphs and concise descriptions. Setup stays separate; every legacy Other type stays reachable.
- Analysis Compose uses one current-type menu (Analysis/Question), the required text, and optional title/context. Type changes still use the existing incompatible-context confirmation and draft state. Context remains a side trip.
- Review shows the author/intent, title/text, timeframe, anchor price/time, optional context, audience and existing submission status. Post and edit Save use the existing submitter/share handoff. No payload contracts changed.
- Setup retains **Levels → optional Reasoning → Review**, tracking semantics and locked edit restrictions. “Show chart” makes no promise of draggable Setup lines.
- Experiment-off marker tab selection remains local state, as before. Original detents, translucent background, legacy Add layout and placement panel remain on that route. Marker viewing is excluded from the new Add presentation policy.
- Guided panels respect the keyboard safe area. Compact dock/button and bar use capped type sizes plus the Large Content Viewer; full form content supports larger text and scrolling.

## Source files

| File | Change |
|---|---|
| `traders_guild/Features/Core/MainView.swift` | Presentation policy, solid gated surface, dock routing, chart/resume callbacks, guided keyboard behavior; small presentation observer modifier |
| `traders_guild/Features/Core/subViews/chartSheetSubViews/chartSheetMarkersView.swift` | Concise guided Add; lifted experiment tab selection while preserving local legacy selection |
| `traders_guild/TradingChart/overlays/MarkerGuidedPlacement.swift` | Compact/tall constants; old screen-based working budgets removed, journey/submission logic unchanged |
| `traders_guild/TradingChart/overlays/MarkerGuidedPlacementViews.swift` | Dock, compact cards/header/menu, Review location summary, visible themed empty-field prompt |
| `traders_guild/Features/Shared/Marker/MarkerGuidedCreationHarness.swift` | Optional native sheet fixture reusing real panel/dock/bar/policy and in-memory transport |
| `traders_guild/TradingChart/overlays/MarkerSheetPresentation.swift` | Shared route/policy normalization, bounded intrinsic measurements, window/container probe and retained guided panel |
| `traders_guild/Features/Shared/Marker/MarkerSheetShellHarness.swift` | Backend-free real ChartBottomSheet/Add/tab composition |
| `traders_guildTests/MarkerSheetPresentationTests.swift` | Real shared policy transitions, typing stability, container cap and experiment-off detents |
| `traders_guildUITests/MarkerSheetShellTests.swift` | Real Add/tab, marker select/clear and guided/legacy transitions |
| `traders_guildTests/MarkerGuidedSheetRefinementTests.swift` | Updated navigation/height regression for the reopened height constraint |
| `traders_guildUITests/MarkerGuidedCreationAccessibilityTests.swift` | Current menu behavior and preserved Setup sequence assertions |
| `traders_guildUITests/MarkerGuidedSheetJourneyTests.swift` | Native-sheet journey, existing context payload, keyboard/dock/resume and largest-text expansion checks |

## Verification

Initial verification results are retained below and in `docs/visual-review/v1.5-sheet-slice1/*-summary.json`. Correction results and current captures are under `corrections/`; the earlier height-policy screenshots are historical.

- Initial main gate: DevDebug build and **72/72 passed** (63 unit + 9 UI), zero failures/skips, iPhone 17 Pro / iOS 26.0. This run predates the content-fit corrections.
- Small screen: iPhone SE (3rd generation), iOS 18.2, **16/16**: 15 sheet/state tests and the complete Analysis UI journey after the shorter-screen correction. That correction keeps the basic optional controls and Change type visible at the working height. The subsequent Add-only height helper leaves this Analysis policy unchanged.
- `xcodebuild -list -project traders_guild.xcodeproj` completed: app/unit/UI targets only, no `TradersGuildMac` target. No archive/upload commands were used.
- `git diff --check`: clean.

The main focused set is five unit suites (63 cases): `MarkerGuidedSheetRefinementTests`, `MarkerGuidedCreationTests`, `MarkerGuidedSubmissionSafetyTests`, `MarkerGuidedEditingTests`, `MarkerGuidedEditPayloadPreservationTests`; plus nine UI cases: all three `MarkerGuidedSheetJourneyTests`, four creation accessibility regressions (type menu, Setup separation, Setup sequence, response retention), and two editing regressions (Analysis edit and active Setup restrictions).

Corrections found during this slice: MainView exceeded SwiftUI's type-checking budget until presentation observers were factored out; the dock's Large Content Viewer wrapper needed explicit button semantics and a default accessibility action; the empty text field needed an explicit themed prompt; fixed fractions initially clipped small-screen controls; the subsequent review correction replaces these budgets with bounded content-fit. Earlier failing results remain in scratch; the checked-in summaries/screenshots represent passing runs.

## Evidence and limitations

**All captures are screenshots of the actual isolated DEV app running backend-free fixtures. None is a signed-in chart, physical phone, backend acceptance test or real share sheet.** Native mode uses UIKit's actual sheet presentation and the production guided components. Its background is fixture chrome with no chart. Embedded regression captures show the real panels but not a native chart sheet.

Native evidence folders: `docs/visual-review/v1.5-sheet-slice1/iphone17pro-ios26/` and `iphonese-ios18/`.

| Screenshot | Evidence |
|---|---|
| `native-fixture-compose-empty.png` | Required input and optional controls at working height |
| `native-fixture-compose-keyboard.png` | Keyboard and reachable Review bar |
| `native-fixture-compact-draft.png` | Task/status/Continue editing, keyboard dismissed, no submission control |
| `native-fixture-optional-context.png` | Optional context side trip |
| `native-fixture-review.png` | Title/text, author/type, location/audience, distinct Post stage |
| `native-fixture-post-transport-and-share-handoff.png` | Exact fixture request and existing share-context handoff; not real backend/share UI |
| `native-fixture-context-post-request.png` (iPhone 17) | Existing chart context retained in recorded request |
| `native-fixture-compact-largest-text.png`, `native-fixture-expanded-largest-text.png` (iPhone 17) | Reachable resume control and user expansion at Accessibility XXXL |

Embedded captures also cover Change type, response retention, Setup Levels/Reasoning and edit restrictions. Date/price/people are fixture data. Full form text at Accessibility XXXL requires scrolling even when expanded. No frame/performance measurements were made.

Current shell evidence renders the real ChartBottomSheet, marker Add, tab controls and shared presentation observer with no configured user/guild/symbol; chart initialization/realtime is not started. Fixture actions drive select/clear and guided/legacy routes. It does not instantiate all of MainView or prove signed-in loaders/chart behavior. Remaining runtime evidence: signed-in chart panning/placement/drawing, signed-in response/view transitions, actual SharePrompt, all themes, tablet/rotation, physical performance and manual VoiceOver. Plain Debug/experiment-off compilation passed; signed-in off-state UI remains unverified. No generic measurement framework was added.

## Bounded corrections after orchestration review

- **Supported selections:** one policy resolves Add, guided steps, legacy tabs/placement and viewed markers. MainView and the real-shell fixture share the normalizer. Every old working height maps into the destination set; compact maps to the destination compact state; supported tall stays tall. Experiment-on selection/placement exit no longer has a competing forced-collapse handler. Experiment-off keeps its established collapse behavior and detent set.
- **Tighter forms and fit:** repeated social description and body Show chart/Change type rows removed. Visible Compose heading says Write analysis/Ask a question; Change type is in the current-type menu and Chart is in the action bar. Content measurements include bounded chrome allowances (Add 110pt, guided 100pt); long content is capped at 90% of actual container safe height. The UIKit probe handles MainView's ignored safe areas without UIScreen sizing. No resize on every keystroke.
- **State retention:** the live guided panel remains mounted at its last viewport while docked and is hidden from touch/accessibility. An intentionally opened empty title, scroll position and user expansion return on resume. Tests also cover Review/Back while tall. Draft/submission ownership is unchanged.
- **Real shell evidence:** `-MarkerSheetShellFixture` renders production ChartBottomSheet/Add/tab controls with guarded loaders and no initialized chart network session. Standard and SE captures demonstrate supported Add → Symbol/Chat/Components and select/clear/guided/legacy transitions.
- Setup still uses **Levels → optional Reasoning → Review**. Existing submission/share paths and backend contracts are unchanged.

Correction verification: Initial correction run `/private/tmp/tg-sheet-slice1-corrections.xcresult`: **31/31 test functions (33 executions)**, including 21 unit functions and 10 UI cases. It covers Setup separation/sequence and Analysis edit as well as the new policy/shell/retention checks. Later affected runs use the final window probe and gated root handlers.

| Final verification | Result |
|---|---|
| DevDebug build-for-testing | Succeeded, dedicated iPhone 17 Pro, signing disabled |
| Final affected run, iPhone 17 Pro / iOS 26 | **28/28 functions (30 executions)**: 21 unit functions + 7 UI, zero failures/skips |
| Small phone, iPhone SE / iOS 18.2 | **4/4 UI**: real Add/tab/select/clear/legacy, Analysis journey and empty-title/scroll retention |
| Plain Debug / experiment-off | **BUILD SUCCEEDED**, generic simulator, arm64/x86_64, signing disabled |
| Source whitespace | `git diff --check` clean |

Final bundles: `/private/tmp/tg-sheet-slice1-corrections-final.xcresult` and `-small.xcresult`. JSON summaries and original-resolution captures are in `docs/visual-review/v1.5-sheet-slice1/corrections/`. Initial correction summary is retained separately; its three extra UI cases are Setup separation, Setup stages and Analysis edit. Parameterized tab normalization accounts for two additional executions in the unit suite.

Visual inspection: Add measured **385pt** in a **778pt** available container on iPhone 17 Pro and **417pt** in **647pt** on SE (card subtitles wrap on the narrower width). Both primary choices and Other are visible at working height. Short Compose shows type/input/title/context; Review shows content/location/audience and actions. Before/after empty-title captures retain the scrolled section. Small-phone `native-fixture-review-settled.png` is a separate `analysisReview` launch supplement showing Chart/Edit/Post after transition settles; journey screenshots can catch transient action rendering. Current captures are fixtures, not signed-in acceptance.


## Safe reproduction

Use this isolated iOS checkout, DEV configuration, simulator and fixture launch only. No account is needed. The temporary review scheme adds the existing UI test target to LinkedDev and is removed after use; no existing scheme/project file is edited.

```sh
python3 docs/visual-review/v1.5-sheet-slice1/make_review_scheme.py
TG_SHEET_SIM=12A720B0-3FA0-4987-B9DE-1C856643F758
TG_SHEET_DD=/private/tmp/tg-sheet-slice1-dd
xcodebuild build-for-testing -project traders_guild.xcodeproj \
  -scheme 'Slice1 Fixture Review' -configuration DevDebug \
  -destination "platform=iOS Simulator,id=$TG_SHEET_SIM" \
  -derivedDataPath "$TG_SHEET_DD" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building -project traders_guild.xcodeproj \
  -scheme 'Slice1 Fixture Review' -configuration DevDebug \
  -destination "platform=iOS Simulator,id=$TG_SHEET_SIM" \
  -derivedDataPath "$TG_SHEET_DD" -parallel-testing-enabled NO \
  -only-testing:traders_guildTests/MarkerSheetPresentationTests \
  -only-testing:traders_guildTests/MarkerGuidedSheetRefinementTests \
  -only-testing:traders_guildUITests/MarkerSheetShellTests \
  -only-testing:traders_guildUITests/MarkerGuidedSheetJourneyTests \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
python3 docs/visual-review/v1.5-sheet-slice1/make_review_scheme.py --remove
```

The dedicated small simulator is `5DAF71B8-2AD0-4274-BE05-97967604193F`. Use another suitable simulator if these local IDs are absent. Result bundles require a fresh output path. Scratch results: `/private/tmp/tg-sheet-slice1-verified.xcresult` (initial main gate) and `/private/tmp/tg-sheet-slice1-small-final.xcresult` (corrected small screen). Build logs and earlier diagnostics are under `/private/tmp/tg-sheet-slice1-*.log`.

Manual simulator fixture after building/installing:

```sh
xcrun simctl install "$TG_SHEET_SIM" "$TG_SHEET_DD/Build/Products/DevDebug-iphonesimulator/traders_guild.app"
xcrun simctl launch --terminate-running-process "$TG_SHEET_SIM" co.tradersguild.app.linkeddev \
  -MarkerGuidedCreationFixture analysisEmpty -MarkerGuidedSheetFixture YES \
  -TGAvatarMarkersExperiment YES
```

Real Add/tab shell: replace the guided fixture flags with `-MarkerSheetShellFixture` (keep `-TGAvatarMarkersExperiment YES`). No account is needed.

Other useful scenarios: `analysisDetails`, `context`, `analysisReview`, `responseDetails`, `setupTracked`, `setupReasoning`, `editAnalysis`, `editSetupActive`. Add `-appTheme dark|midGrey|lightGrey` for themes, or `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` for large text. Omitting `-MarkerGuidedSheetFixture YES` keeps the embedded regression harness. Fixture mode is debug/isolated DEV only; the experiment is unavailable in production configurations.

Plain Debug reproduction (no fixture/account/launch):

```sh
xcodebuild build -project traders_guild.xcodeproj \
  -scheme 'traders_guild Local Gateway' -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/tg-sheet-slice1-off-dd CODE_SIGNING_ALLOWED=NO
```

## Next owner review, through the orchestrator

1. Review these fixture screenshots and source commit before integration; decide whether the compact/working/tall presentation and Compose/Review structure are acceptable.
2. Coordinate an owner-led device session on the integrated isolated DEV baseline. Do not automatically launch/install/operate the phone.
3. On a signed-in chart, open Markers → Add; inspect concise choices and all Other entries. Start Analysis, write a short note/title, Show chart, pan/position, resume, add existing context, review exact location/audience, edit back, and use the existing authorized DEV Post/share path.
4. Drag between compact/working/tall states; test keyboard show/hide, longer text and large text. Verify tab switching and experiment-off presentation.
5. Smoke-check Question, a linked response, Setup's three steps with optional reasoning, locked active Setup editing, discard/retry, and marker viewing. Confirm actual chart-edit restrictions rather than assuming draggable lines.
6. Report findings to the orchestrator. Setup merging and Slice 2 remain unapproved until a separate decision; do not continue them from this checkpoint.
