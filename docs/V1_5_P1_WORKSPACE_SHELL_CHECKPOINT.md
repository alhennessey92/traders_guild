# v1.5 workspace — P1 checkpoint: sheet shell and stable detents

Claude, 6 October 2026. Branch `claude/1.5.0-marker-workspace` (worktree `.worktrees/marker-workspace-claude`), based on canonical `128ead3`. Nothing was merged into `feat/1.5.0-avatar-markers`. The scope is P0 and P1 only, stopping at the owner device gate before P2 (plan: `~/.claude/plans/users-alhennessey-downloads-claude-v1-5-synthetic-wand.md`).

## Round 2 — owner device feedback (6 October), applied

The owner reported that moving around the workspace "feels really nice". Changes made in response to the rest of the feedback:

| Feedback | Change |
|---|---|
| Collapsed bar too tall; should be the app's standard collapsed height, as a capsule | The workspace collapses to the app's own 11% dock: a single-row capsule (50pt, placed exactly like the tab bar) naming the draft and the screen it returns to. The chart-tool bar is the same capsule: the tool's label (tap for options), then Cancel and Done. The separate tool height is gone. |
| Open small/medium so the marker shows on the chart straight away | Every marker workspace (new post, Setup, response, edit) opens **small (35%)**. The workspace now offers exactly the app's own four heights, so opening or finishing a marker changes only where the sheet sits, never what it offers. |
| (Owner choice) Autofocus | **Removed.** The keyboard comes up when the text is tapped, so the marker stays visible on open. |
| Keyboard opening: "nasty jumping transition, with the chart jumping up" | Cause: the chart layer behind the sheet made room for the keyboard and was squashed from 724pt to 375pt as the keyboard rose. While a marker is authored it now ignores the keyboard. **Control evidence:** the typing journey measures the chart layer every frame. Without the fix it squashes 724→375; with the fix it holds exactly still both ways, cold and warm. The sheet's own expansion is unchanged (full height, smooth, as the owner preferred). |

**Round 2 evidence** (`docs/visual-review/v1.5-p1-workspace/round2/`):

| Check | Result |
|---|---|
| Focused unit suites | **101/101**. Per-session height tests retired; new: opens small from any height, the set never changes, dock collapse/resume, drag-to-dock, stray-write mapping |
| Sheet journeys, iPhone 17 Pro / iOS 26.5 | **11/11** (adds "a new post / Setup opens small without the keyboard"; typing asserts the chart layer never resizes) |
| Sheet journeys, iPhone SE / iOS 18.2 | **11/11**. On the SE, the text field is reached by raising the sheet first (P3 compact layout). |
| Keyboard control | Fix removed: chart layer 724→375pt during the keyboard rise. Fix present: constant. |
| Existing workspace UI suites (large) | **47/50**, same 3 baseline-stale failures. The older tests now raise the sheet by its grabber where they need lower controls (`MarkerWorkspaceUITestSupport.swift`). |
| Release build; signed device build | Succeeded |

Note: on iOS 18, if the keyboard pushes an already-tall sheet to the very top, iOS applies its standard card-stack scaling to the screen behind. That is native and animated, and is not the squash.

## What the owner should feel

Ordinary movement inside the marker workspace no longer touches the sheet:
- switching Analysis ↔ Question;
- going Details → Review → Back;
- going Details → Context → Add indicator → settings → Cancel/Back/Done;
- the same moves on a Setup.

The header (your avatar and its ring) and the footer stay where they are. Only the screen between them changes: the incoming screen slides a short way in from the side it leads to, and the one being left fades. With Reduce Motion on, both crossfade.

The sheet moves only when you move it, or when you deliberately show the chart:
- **⌖ (Show chart):** the sheet collapses to a small bar naming the screen you were on.
- **Resume, or dragging it back up:** returns to the same height and the same screen, with unsaved values intact.
- **"Work on chart" for a level or drawing:** the sheet becomes a tool bar with Cancel and Done, and either one brings the workspace back.

A new Post opens with the keyboard up, ready to type. Setups and edits never auto-focus. The keyboard now has a **Done** button.

The visual design of the screens themselves is unchanged in P1. That is P3–P5.

## Root cause of the drop / hide / reopen

`MarkerSheetPresentationPolicy.working` was `.height(measured)`, re-measured per screen and per intent. Every Analysis↔Question or Details↔Review move therefore replaced the *selected* detent with a new identity. UIKit fell back to the smallest detent, the observer raised the sheet again, and the retained panel showed the dock whenever the selection passed through compact. The P1 frame traces confirm the fix: the sheet top holds within the native 2pt touch wobble through every such move.

## What changed

| File | Change |
|---|---|
| `TradingChart/overlays/MarkerSheetPresentation.swift` | **Rewritten.** Fixed detent vocabulary; `MarkerSheetDetentSequencer` (union → select → shrink, so the selection is always offered and always animates); `MarkerSheetDetentController` (enter/leave authoring, collapse/resume, user-drag memory, stray-write repair); `MarkerSheetDetentHost`; `MarkerSheetAuthoringSync`. The measured policy, measurement cache, keyboard-constrained detent set and retained panel are gone. |
| `TradingChart/overlays/MarkerWorkspaceSheetBody.swift` | **New.** Keeps the workspace mounted at its last size under the collapsed bar: the chart-tool bar (Cancel/Options/Done) while a drawing or level is worked on the chart, the resume dock otherwise. The workspace holds that size until the sheet has grown back, so it is revealed exactly as it was. Resizing a scroll view through small heights lost its position; the largest-text journey caught this. |
| `TradingChart/overlays/MarkerGuidedPlacementViews.swift` | Persistent header; one scroll view per screen (each remembers its own position); direction-aware screen transition; VoiceOver screen-changed announcement; footer crossfade; the dock names the screen it returns to. Content measurement removed. |
| `TradingChart/overlays/MarkerWorkspace.swift` | `workspaceDepth`, `isWorkspaceChartToolActive`, the new-Post autofocus rule. Dead measurement code removed. |
| `TradingChart/overlays/MarkerWorkspaceViews.swift` | A screen renders the destination it was created for, so the one fading out never redraws as the next. |
| `TradingChart/overlays/MarkerWorkspaceTextInput.swift` | One-time autofocus, read live from the draft; keyboard **Done** bar. |
| `TradingChart/overlays/MarkerSheetGeometry.swift` | Fixture/trace instrumentation only. The geometry probe no longer runs in normal builds, and there is a new per-frame sheet trace (`-MarkerSheetTrace`, DEBUG/isolated DEV only). |
| `Features/Core/MainView.swift` | The experiment-on sheet goes through the controller. The chart sheet body is extracted (type-checker). Experiment-off detents and writes are unchanged. |
| Harnesses, `chartSheetMarkersView.swift` | Moved to the controller; Add-tab measurement removed. |

The experiment-off path still offers exactly `[0.11, 0.35, 0.5, 0.9]` with the same selection writes. The draft model, edit preservation, submission, Setup semantics and backend contract are untouched.

## Keyboard: decided from evidence (the plan's documented fallback)

The plan proposed a smaller "compose" height while typing, to keep a strip of chart visible. P1 measured every way of doing that on the real MainView sheet (`trace-*.json` attachments):

| Approach | Measured |
|---|---|
| Move to compose height, then focus | Sheet drops 460→586 before rising: the keyboard's first appearance stalls the main thread. |
| Switch detents on the keyboard notification | One frame at 602–612, below the rest position. |
| Switch on the first frame of the keyboard's lift | Snap 452→530 mid-rise: UIKit applies a detent change during the keyboard animation unanimated. |
| One custom detent whose height follows the keyboard | Lands correctly but still one frame at 604; on exit a blip up to 68; a warm re-entry missed the compose height. |
| **Native expansion (no height change)** | **One monotonic motion each way, cold and warm; the selected detent never changes; Done returns to exactly the rest height.** |

So typing uses the native expansion. While the keyboard is up the sheet covers most of the chart, as Apple Maps does. The chart returns the moment typing ends. This is the gate question below.

## Evidence (all at this commit)

| Check | Result |
|---|---|
| P0 baseline at `128ead3` | DevProfile and Release simulator builds succeeded; focused unit suites **99/99** |
| Focused unit suites (9 suites, DevDebug, iPhone 17 Pro / iOS 26.5) | **106/106**. New: sequencer invariants, metrics, controller entry/exit, collapse/resume, drag memory, stray-write repair, fixed heights, tall Setup on short screens, `preferTall` |
| P1 journeys, iPhone 17 Pro / iOS 26.5, optimised DevProfile | **9/9**, plus the updated response-convert test **1/1** |
| P1 journeys, iPhone SE (3rd gen) / iOS 18.2 | **9/9** |
| Existing workspace UI suites (7 suites, 50 tests, large simulator) | **47/50.** The 3 failures are the stale tests that already fail at baseline (see above). |
| Release (`traders_guild Local Gateway`) simulator build | Succeeded |
| Signed device build (LinkedDev Profile, `co.tradersguild.app.linkeddev` 1.5.0 (25), gateway `http://192.168.1.182:30080/api/v1`) | Succeeded, at `/private/tmp/tg-claude-owner-device`. **Not installed** (waiting for the owner). |

Frame traces and screenshots for every journey are in `docs/visual-review/v1.5-p1-workspace/{large,se}/`. Each trace sample records the sheet top in points, the presenting controller index, the selected detent, the screen and whether the dock is showing. Result bundles are under `/private/tmp/tg-claude-ws/` (not committed).

## Owner device gate (P1)

Launch the LinkedDev build on your iPhone 14 Pro, signed in as usual, with only `-TGAvatarMarkersExperiment YES`. Then:

1. Markers ▸ Add ▸ **Post to the chart**. The sheet does not move, the content changes, and the keyboard rises with the sheet in one motion. Tap **Done**: it comes back down.
2. Tap **Analysis / Question** back and forth. The sheet stays still and your ring recolours.
3. Write something, then **Review** → **Back** a few times. The sheet stays still.
4. **Add context → Add indicator → EMA**, move a slider, then **⌖**. The chart shows with a bar naming *Indicator settings*. Pan the chart, tap the bar: you're back on the same screen with the same value. Cancel, Back, Done.
5. Drag the sheet up to tall yourself, then navigate. It stays tall.
6. **Setup**: Review → Back. The sheet stays still.
7. Open someone's marker ▸ **Supports**. The workspace opens in the same sheet, with no dismiss and re-open.
8. Context ▸ add a support level ▸ edit it ▸ **Work on chart**. You get the tool bar; Done and Cancel each bring the workspace back.

**Questions for you at this gate:**
1. Does ordinary navigation now feel like one continuous workspace?
2. Is native keyboard expansion acceptable (chart covered only while typing)?
3. Are the collapsed bar and chart-tool bar heights right on your phone? They are starting points.

## Test changes (all recorded)

- **New:** `MarkerWorkspaceShellUITests` (9 journeys with frame-trace assertions) and the detent/controller unit tests.
- **Updated for approved behaviour:**
  - `testLevelChartHandoff…` resumes from a chart tool through its bar's **Options** (formerly the resume dock).
  - `testResponseConvertsWithinDetails` and `testEmptyTitleAndScrolledSectionSurviveChartMode` first put away the auto-focused keyboard (a new empty Post opens ready to type).
  - Content scrolling in tests drags between fixed points inside the workspace. A swipe at the screen centre now lands on the fixed-height sheet's edge and resizes it, and a swipe on a content element lets XCUITest scroll that element back into view first.
  - The inline (non-native) creation harness gives its panel a fixed 560pt in place of the retired measured fit.
- **Already failing at baseline `128ead3`, unchanged by P1** (verified by running them on an untouched export of the baseline):
  - `MarkerGuidedCreationAccessibilityTests.testDetailsNamesTheStepAndWhatIsMissing` expects removed header copy ("Write analysis", "Step 1 of 2").
  - `…testAnalysisWorkingHeightKeepsOptionalControlsReachable` queries the intent picker as a button.
  - `MarkerSheetShellTests.testRealShellSelectionClearAndGuidedLegacyExit` makes the same button query.

  These are stale assertions; P3 rewrites these screens and their tests.

## Small-screen finding for P3

On an iPhone SE at 50%, Details shows only the header, the Analysis/Question picker and part of the text field. **Title** and **Add context** need a scroll, or the user drags the sheet up. The sheet behaves correctly (the journeys pass after revealing them). P3 needs a tighter Details layout for compact heights, or a taller default working height on small screens.

## Known issues / not in P1

- Screen visuals, hierarchy, the indicator and drawing pickers, the Setup ticket and the Review card are unchanged (P3–P5).
- The session model refactor (navigation state off the draft publisher) is P2. Typing still republishes the draft, as before.
- A tap on sheet content moves the native sheet by up to 2pt (UIKit touch tracking). This is unchanged from before and not a drop.
- Post success still stands the chart sheet down for the share prompt, by owner decision.
