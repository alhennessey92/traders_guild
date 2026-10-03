# v1.5.0 bottom-sheet refinement: engineering checkpoint (Claude)

Branch `claude/1.5.0-avatar-markers`, worktree `.worktrees/marker-avatar-claude`, on top of `7795493`. Brief: `docs/V1_5_BOTTOM_SHEET_REFINEMENT.md` (owner-authorised).

**Stop point.** This is the engineering and owner visual review checkpoint, for Astra first. Nothing is pushed or deployed.
- No phone was used and no runner, trace or watcher was queued.
- No backend, auth, Android or production change was made.

**Kept separate.** This refinement is not part of the bounded warm-pan CPU conclusion (`e1ffd10`). It is also not part of the still-open evidence on frames and cold load, older-client compatibility and hand-run accessibility (`V1_5_STAGE5_OWNER_HANDS_ON.md`). None of those change here.

`$S` = `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad`. Captures are in `docs/visual-review/v1.5-bottom-sheet/{before,after}/`. Test summaries are in `…/test-results/`.

## 1. Commits

| Commit | What | Gate |
|---|---|---|
| `99877c4` | **Fix:** a pan takes over from marker centring (§4). Includes a test. | `MarkerAvatarExperiment` (the legacy chart is unchanged) |
| `6132ce2` | Guided creation sheet: one step at a time (§3a). Includes tests. | The guided flow, which only exists under the experiment. On the Add tab, `MarkerAvatarExperiment.isEnabled`. |
| `4cd83e2` | The marker detail sheet's General tab, refined. Edits titled "Edit ‹type›". A backend-free viewing fixture (§3b–§3c). | Experiment, and Analysis, Question or Setup only. Other types and experiment-off keep the shipped layout. |
| this commit | This checkpoint and its evidence | — |

## 2. What was wrong (inspected before changing anything)

**Sources.**
- The real-app captures from Stage 4 (`docs/visual-review/v1.5-stage4/01, 04, 06, 14, 19, 22, 24, 30`).
- New "before" captures of the guided harness, built from `7795493`, in `before/`.
- The detail sheet with the experiment off (`after/view-*-expNO.jpg`). That is identical code to what the experiment showed before `4cd83e2`.
- The existing handovers and conventions:
  - Stage 3/4 checkpoints, the setup-guard correction
  - `AppColors` tokens, `UnifiedMarkerBadge`, `MarkerLinkPlacementBanner`, `MarkerResponseTimeframeControl`, `UnifiedComponentsHostView`
  - the Stage 3 accessibility rules: chips stack at accessibility sizes, decorative symbols hidden, a fixed 68 pt bar

**Concrete problems.**

| # | Where | Problem |
|---|---|---|
| P1 | Add tab | Four competing elements before Setup is even visible: a header card, the "Post to the chart" card, a "STRUCTURED" label and a two-line accuracy warning. Then the Setup row (`stage4/01`). |
| P2 | Details | "Post to the chart" appears twice, as the toolbar title and the sheet heading. Nothing says which step this is or how many remain. |
| P3 | Details | Type chips (Analysis/Question) and "Change type" (to reach Setup) are two separate controls for one decision. |
| P4 | Details | The title field comes before the main text and looks required. "Ready to review" is noise once Review is enabled. |
| P5 | Bottom bar | The unmet requirement shows as a checklist *statement* in warning orange: "TP/SL direction is valid" and "Add analysis description" (`stage4/19, 22`). It reads as an error, even for a step simply not yet taken. The disabled Review is a dim version of the enabled colour, so it still looks pressable. |
| P6 | Setup details | Side, Entry, TP, SL, R:R, a hint, a toggle, a tracking card, two checklist lines, title, thesis, context and change-type are all stacked. At the low detent only the bar is visible (`stage4/22`). |
| P7 | Response details | The banner and the response-timeframe control push the writing field below the 0.35 detent (`stage4/19`). |
| P8 | Review | Prices are shown at full input precision ("83,393.8058", "83,840.98324", `stage4/24`). "No extra context" is always shown. Who sees the post is only implied. |
| P9 | Detail sheet | The author is not named in the first view; the hero says "Analysis / Share chart analysis". The title is hidden inside the collapsed General disclosure. The text is boxed inside a box. Respond and Share are two large dissimilar cards separated by three disclosures (`stage4/14`). |
| P10 | Edit | Editing (legacy editor) is titled "Place a Marker" (`stage4/30`). |

## 3. What changed

### 3a. Guided creation (`6132ce2`)

The central criterion was **one clear step at a time.** Details → Review → Post is unchanged in logic. Every change below is presentation over the same `MarkerPlacementState`.

| Problem | After | Captures |
|---|---|---|
| P1 | The Add tab offers two starting points: **Post to the chart** (Analysis or Question) and **Plan a trade** (Setup, with the accuracy note as its subtitle). Then "Other marker types" behind a disclosure. The header subtitle reads "Choose what to post. You'll write it, then review it before it goes live." | Not capturable without sign-in (§6). Code: `chartSheetMarkersView.guidedAddContent` |
| P2 | A **step header**: the author's face, "Step 1 of 2 · Posting to ‹guild›", then the step's question. The questions: "What are you seeing?", "What do you want to ask?", "Plan your trade", "What's your view?" for a response, and "Check your post". The toolbar now names the task instead: "New Analysis", "New Setup", "New response". The header is one VoiceOver heading. | `after/analysisEmpty`, `setupTracked`, `responseDetails`, `analysisReview` |
| P3 | **One segmented control**, Analysis · Question · Setup, with one line on what the chosen type is for. It uses the same `requestGuidedIntentChange`, so the incompatible-component confirmation still applies. The other five types are under "Other marker types" and open the existing editor with the text kept. | `after/analysisDetails`, `entry` |
| P4 | **The required input first.** "Title" and "Add chart context" sit under **OPTIONAL**. The title field appears only on request ("Add a title", +), or when the draft already has one. The question counter shows only while short. | `after/analysisEmpty`, `questionShort`, `discardConfirm` (shows a draft with a title) |
| P5 | Beside a disabled Review, the bar says **what to do next** in plain words: "Write your analysis to continue", "Write 1 more character", "Set a take profit and a stop loss", "Put Entry between your stop and target" (the approved guard wording). It is grey for a step not yet taken, and amber only for levels that are set but wrong. A disabled button is outlined and grey; an enabled one is filled. | `after/analysisEmpty`, `questionShort` |
| P6 | Setup: **one Levels card**. The side pill sits in the card header. It holds Entry ("Latest price when you post"), TP and SL fields, R:R, and "Drag the lines on the chart, or type a price". Then **Track this Setup** with its existing estimate card or untracked notice. Then "Why this trade? (optional)". The duplicate checklist lines are removed; the bar carries them. | `after/setupTracked`, `setupUntracked`, `setupTracked-iphone-se` |
| P7 | Response: the relationship banner stays at the top. The **response-timeframe control moves below the writing field**, so the field is the second thing on screen. Same control, same loading and failure handling. | `after/responseDetails`, `responseDetails-iphone-se` |
| P8 | Review shows the post **as the guild will read it**: the type tag and timeframe, the relationship, title, text, the Setup ladder and tracking. Prices are at chart precision ("63,920.00"; `MarkerGuidedFormat.displayPrice`, display only, so the fields keep every digit). The context line appears only when there is context. Then "Members of ‹guild› will see this on the chart." | `after/analysisReview`, `setupReview`, `responseSetupReview` |

**Unchanged on purpose:**
- the draft, `prepareGuidedFlow`/`endGuidedFlow`, submission ownership and the stale-completion rules
- the in-flight freeze, Retry and the tracked-Setup level guard with "Adjust levels"
- discard confirmation, the share-prompt handoff, the link banner (Change / ✕) and response-timeframe behaviour
- the context editor (`UnifiedComponentsHostView`)
- accessibility identifiers. New ones: `guided.stepHeader`, `guided.nextStep`, `guided.addTitle`, `guided.title`, `guided.text`, `guided.intent.setup`, `guided.planTrade`

Captures: `after/failedPost`, `setupMarketMoved`, `discardConfirm`, `context`.

**Large text and small phones:**
- At accessibility sizes the type control stacks, and the step header puts the face above the words.
- The bar keeps its 68 pt cap.
- On iPhone SE every step keeps its primary action visible.

Captures: `after/*-AccessibilityXL`, `*-iphone-se`.

### 3b. Viewing (`4cd83e2`, experiment, Analysis/Question/Setup)

The new reading order (P9):
1. **Who and what:** the face, which opens the profile as the Author section does; "@author"; the type in its colour; "1 Hour chart · 2 hr ago"; Edit for the author.
2. The relationship row, unchanged.
3. **The title and text as plain reading,** including a Setup's thesis.
4. The Setup ladder, outcome and tracking timeline, unchanged.
5. **Respond and Share side by side**: 44 pt and equal height. They use the same relationship picker and `onShareMarker` as before.
6. Thesis, General, Symbol Info and Author disclosures.
7. Delete.

Kept: the report flow (in General), moderation permissions (`canDelete`, `canEdit`), linked navigation, the Respond guards (guild-visible, same guild and symbol, linked markers on) and the delete confirmation copy.

Captures: `after/view-{analysis,response,setup,own}-expYES` against `-expNO` (before / experiment off), plus `-lightGrey`, `-AccessibilityXL` and `-iphone-se`.

### 3c. Editing (`4cd83e2`)

Edits keep the existing editor, as recorded in Stage 3 (`beginEditingMarker`: "Editing keeps the existing editor"). Under the experiment, its toolbar says **"Edit Analysis" / "Edit Setup" …** instead of "Place a Marker" (P10). Values and validation are untouched; the text-only Analysis allowance from `c4ecb14` still applies.

**Decision surfaced, not implemented:** whether edits of Analysis, Question and Setup should move into the guided Details → Review → "Save changes" flow. That would reverse the recorded decision, and it touches update submission and tracked-Setup level rules (§7). It is for the owner and Astra to decide.

## 4. Selection wiggle and immediate pan (`99877c4`)

**Deterministic reproduction (simulator).**
- Selecting a marker calls `animateHistoricalMarkerEntry` → `ChartGestureState.animateCenterOnMarker`. That is a **0.9 s `CADisplayLink` animation that writes `panOffset` outright every frame**.
- The wiggle runs from about 0.47 s to 0.87 s after the tap (a 0.12 s staged selection, a 0.35 s delay, then 5 steps). It therefore ends just as the centring does, which is why "before the wiggle finishes" is the window the owner felt.
- `beginDrag()` stopped momentum, not the centring. So a drag inside the window applied its movement, and the next frame overwrote it.
- `MarkerSelectionPanHandoffTests.testOnTheLegacyChartTheCentringOverwritesADragStartedInsideIt` runs this on the real class and real display link:
  - start centring
  - after 0.25 s, drag −150 pt
  - result: the chart ends exactly on the centring target, with the drag lost

**Fix, experiment-gated.**
- `beginDrag(interruptsCentering: MarkerAvatarExperiment.isEnabled)` stops the centring when the finger lands, the way a scroll view stops an animated scroll.
- Selection, focus, the pop and the wiggle are unchanged; the wiggle is kept.
- `testUnderThePrototypeTheFingerTakesOverFromTheCentring` passes: the chart stays where the drag put it. With no centring running, a drag is unchanged either way.

**Limits.**
- This is a state-level reproduction, not a frame measurement. It does not claim frame smoothness.
- The wiggle's own five `@State` steps also re-evaluate `TradingChartView` during that window. I did not change them, and I did not measure them separately.
- **Physical confirmation is still needed**, by hand on the phone when the owner is ready: select another marker, then pan at once.

## 5. Verification (exact artifacts)

| Run | Result | Artifact |
|---|---|---|
| Whole unit target, `traders_guild LinkedDev` (DevDebug), iPhone 17 Pro simulator, serial | **813 / 813 passed** | `$S/bs/rb-bs-full-unit.xcresult`; `test-results/full-unit-devdebug-{summary,tests}.json` |
| Focused, final source: `MarkerSelectionPanHandoffTests` (3), `MarkerGuidedSheetRefinementTests` (10), `MarkerGuidedCreationTests`, `MarkerGuidedSubmissionSafetyTests`, `MarkerTrackedSetupGuardTests`, `MarkerSelectionMotionTests`, `MarkerTextOnlyAnalysisEditTests` | **50 / 50** | `$S/bs/rb-focused-final.xcresult`; `test-results/focused-unit-final-*.json` |
| UI tests, `traders_guild LinkedDev Profile`: `MarkerGuidedCreationAccessibilityTests` (9, 2 new), `MarkerViewingRefinementTests` (6, new), `MarkerLinkAccessibilityTests` (4, existing) | **19 / 19** | `$S/bs/rb-bs-ui-2.xcresult`; `test-results/ui-profile-*.json` |
| Plain Debug, `traders_guild Local Gateway`: refinement, pan hand-off, guided creation and experiment-gate tests | **31 / 31** | `$S/bs/rb-bs-debug.xcresult`; `test-results/plain-debug-*.json` |
| `traders_guild GCP Public Prod`, Release, build only | BUILD SUCCEEDED. `strings` finds no `MarkerViewingFixture`, `MarkerGuidedCreationFixture` or `Fixture · `. The parameter name `fixtureViewerContext` appears as metadata; it is nil in the app. | `$S/bs/build-release.log` |

**Earlier run, kept as a finding.** The first full UI run on this source went **12 / 19** (`test-results/ui-profile-overlay-run-*.json`).
- **Cause:** the whole unit run had just run hosted in the same app, and left launch state behind.
- As a result, the app's "Traders Guild, loading" transition overlay sat over the fixtures and took every tap. The UI hierarchy is in the result bundle.
- `4cd83e2` keeps the transition and biometric-lock overlays off fixture launches only. The rerun passed 19 / 19.
- The product launch path is unchanged.

What the new tests pin:
- the step names and prompts, and every "what's missing" prompt, including the tracked-Setup guard cases
- review price precision, the audience line and the edit title (on and off)
- the legacy chart's centring overwrite, and the prototype hand-off
- in the UI: the heading's label, a disabled Review with its reason, typing enabling Review, the title only on request
- the viewing order (author → post → actions), Respond still opening the picker, Edit and Delete for the author, the Setup ladder, the shipped layout with the experiment off, and actions reachable at the largest text size

## 6. Limitations

- **No real-app captures after the change.** The simulator's LinkedDev app is signed out. Per the standing rule, I did not enter QA credentials into the app or a test.
  - "After" evidence is therefore the guided harness and the new viewing fixture. Both render the real views over the real state and submission code, but without the chart.
  - Not seen live: the Add tab, the sheet at real detents with the ghost on the chart, and the keyboard over the real sheet.
  - The "before" for those is the Stage 4 real captures.
  - If the owner signs in to TG LinkedDev on the iPhone 17 Pro simulator by hand, I can do the real-app pass without credentials, the same way as Stage 4 (no posting to the 1h fixture).
- Viewing "before" is the experiment-off fixture. That is the same code the experiment showed before; only the hero face differs, because faces are experiment-only.
- Light Grey, Dark and Mid-Grey were captured; I made no other theme change. Text-field placeholder contrast in Light Grey is the existing shared field style and was not changed.
- VoiceOver was checked through the accessibility tree in UI tests, not by ear.
- The wiggle/pan fix is not confirmed on device (§4).
- The simulator's LinkedDev keychain may still hold state written by unit tests hosted in the app. That predates this work and is simulator-only.
- An `xctrace` process from another, older session (`db687bc5…`, 22 days old) is still attached to this simulator's name. I left it alone.

## 7. Decisions for Astra and the owner

1. **Guided editing** (§3c): move Analysis, Question and Setup edits into Details → Review → "Save changes", with the type fixed and the link immutable. That would reverse the Stage 3 decision, and it needs:
   - a guided update-submission state (Saving…, failure, retry)
   - an answer on whether a tracked Setup's levels may be edited after arming
2. **Review button wording:** it stays "Review" and "Post". "Next" or "Post to ‹guild›" are one-line changes if preferred.
3. **Setup level fields** keep their input formatter, so they show "64,160" next to Entry's "63,920.00". Formatting the fields to chart precision would round a dragged level when the author edits that field. I left it for a decision.

## 8. Owner visual review steps (after Astra's engineering review)

**Simulator, no account needed.** Use TG LinkedDev from `$S/bs/dd-after` (DevDebug):
- `-MarkerGuidedCreationFixture <scenario> -TGAvatarMarkersExperiment YES`. Scenarios: `analysisEmpty`, `analysisDetails`, `questionShort`, `setupTracked`, `setupUntracked`, `responseDetails`, `analysisReview`, `setupReview`, `responseSetupReview`, `failedPost`, `setupMarketMoved`, `discardConfirm`, `context`, `entry`.
- `-MarkerViewingFixture analysis|response|setup|own -TGAvatarMarkersExperiment YES|NO`.
- Add `-appTheme lightGrey|dark` or `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL` to check themes and text size.

**Phone, when the owner chooses** (no runner):
- Install a build of this branch, then follow `V1_5_STAGE5_OWNER_HANDS_ON.md` for the gate and fixtures.
- Check:
  - Markers → Post to the chart → write → Review → Post, on 15m, not the 1h fixture
  - Plan a trade
  - Respond from a selected marker
  - the refined detail sheet
  - Edit of your own marker
  - select another marker and pan at once (§4)
