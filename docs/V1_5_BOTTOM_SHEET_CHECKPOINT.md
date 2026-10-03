# v1.5.0 bottom-sheet refinement: engineering checkpoint (Claude)

Branch `claude/1.5.0-avatar-markers`, worktree `.worktrees/marker-avatar-claude`, on top of `7795493`. Brief: `docs/V1_5_BOTTOM_SHEET_REFINEMENT.md` (owner-authorised).

**Updated after Astra's initial review of `ff404b4`.**
- `8fdfd36` restores the frozen plan's social/structured separation (§9).
- The captures in `after/` and the runs in §5 are from the corrected source.
- The three-way-picker screens are superseded and kept in `ff404b4`'s history.

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
| `ff404b4` | This checkpoint and its evidence (first version) | — |
| `8fdfd36` | **Correction:** the separation restored; self-review fixes (§9). Includes tests. | The guided flow |
| this commit | This checkpoint, updated, with corrected captures and runs | — |

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
| P3 | *As corrected in `8fdfd36` (§9).* Social Details has the **Analysis · Question** selector as one segmented control, with one line on what the chosen type is for. **Setup is not in it.** Setup is reached from "Plan a trade", or from **Change type**, which returns to the creation hierarchy (Post to the chart, Plan a trade, Other marker types) and keeps the draft and the response. Every type change still goes through `requestGuidedIntentChange`, so the incompatible-component confirmation still applies. | `after/analysisDetails`, `setupTracked`, `entry`, `responseChooser` |
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
- accessibility identifiers. New ones: `guided.stepHeader`, `guided.nextStep`, `guided.addTitle`, `guided.title`, `guided.text`, `guided.planTrade`

Captures: `after/failedPost`, `setupMarketMoved`, `discardConfirm`, `context`.

**Large text and small phones:**
- At accessibility sizes the type control stacks, and the step header and entry cards put the face above the words.
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

**On the corrected source (`8fdfd36`):**

| Run | Result | Artifact |
|---|---|---|
| Whole unit target, `traders_guild LinkedDev` (DevDebug), iPhone 17 Pro simulator, serial | **815 / 815 passed** | `$S/bs/rb-corr-final-unit.xcresult`; `test-results/correction-full-unit-devdebug-{summary,tests}.json` |
| Focused: `MarkerSelectionPanHandoffTests` (3), `MarkerGuidedSheetRefinementTests` (11), `MarkerGuidedCreationTests`, `MarkerGuidedSubmissionSafetyTests`, `MarkerTrackedSetupGuardTests`, `MarkerSelectionMotionTests`, `MarkerTextOnlyAnalysisEditTests`, `MarkerResponseTimeframeTests` | **58 / 58** | `$S/bs/rb-corr-focused-2.xcresult`; `test-results/correction-focused-unit-*.json` |
| UI tests, `traders_guild LinkedDev Profile`: `MarkerGuidedCreationAccessibilityTests` (11, 4 new), `MarkerViewingRefinementTests` (6, new), `MarkerLinkAccessibilityTests` (4, existing) | **21 / 21** | `$S/bs/rb-corr-final-ui.xcresult`; `test-results/correction-ui-profile-*.json` |
| Plain Debug, `traders_guild Local Gateway`: refinement, pan hand-off, guided creation and experiment-gate tests | **33 / 33** | `$S/bs/rb-corr-final-debug.xcresult`; `test-results/correction-plain-debug-*.json` |
| `traders_guild GCP Public Prod`, Release, build only | BUILD SUCCEEDED. `strings` finds no `MarkerViewingFixture`, `MarkerGuidedCreationFixture` or `Fixture · `. | `$S/bs/build-corr-final-release.log` |

Astra independently re-ran the first version (`ff404b4`): 813 full unit, 50 focused and 19 UI tests, all passing. Those runs' summaries are kept as `test-results/{full-unit-devdebug,focused-unit-final,ui-profile,plain-debug}-*.json`.

**Earlier run, kept as a finding.** The first full UI run on this source went **12 / 19** (`test-results/ui-profile-overlay-run-*.json`).
- **Cause:** the whole unit run had just run hosted in the same app, and left launch state behind.
- As a result, the app's "Traders Guild, loading" transition overlay sat over the fixtures and took every tap. The UI hierarchy is in the result bundle.
- `4cd83e2` keeps the transition and biometric-lock overlays off fixture launches only. The rerun passed 19 / 19.
- The product launch path is unchanged.

What the new tests pin:
- the step names and prompts, and every "what's missing" prompt, including the tracked-Setup guard cases
- review price precision, the audience line and the edit title (on and off)
- the legacy chart's centring overwrite, and the prototype hand-off
- the separation (§9): no Setup in the social selector; Change type shows the hierarchy with the current kind selected; Plan a trade opens Setup details, which carry no selector; a response keeps its banner in Change type
- Review held back while a response timeframe loads or after it fails, with the reason shown
- in the UI: the heading's label, a disabled Review with its reason, typing enabling Review, the title only on request
- the viewing order (author → post → actions), Respond still opening the picker, Edit and Delete for the author, the Setup ladder, the shipped layout with the experiment off, and actions reachable at the largest text size

## 6. Limitations

- **Harness and fixture tests do not cover the live Add tab, real sheet detents or the keyboard over the real sheet.** That evidence is still pending a manual simulator sign-in by the owner.
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

## 7. Decisions

Resolved by Astra:
- Keep "Review" and "Post".
- Editable Setup level fields keep full precision; chart precision is for display only.
- No tracked-Setup editing rule changes.

**Waiting on the owner:** guided Details → Review → "Save changes" for editing (type and link immutable, every existing update restriction kept), or the current editor. Guided editing is not implemented until that answer arrives.

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

## 9. Correction after Astra's initial review (`8fdfd36`)

**What was wrong.**
- `6132ce2` put Setup into the social selector as a three-way control.
- The frozen master plan (`docs/version_docs/ios/1.5.0.md`, §2) keeps "Setup … separate from the Analysis/Question selector".
- It also reaches a structured Setup response through "a separate change-type action [that] returns to the creation hierarchy while retaining the response session".
- I changed that decision without surfacing it.

**Restored:**
- Social Details offers **Analysis · Question** only. Setup Details carry no selector.
- **Change type** (`guided.changeType`) is on both. It returns to the creation hierarchy: "What do you want to post?", the response banner when responding, then:
  - **Post to the chart** (selected when the draft is social)
  - **Plan a trade** (selected when it is a Setup)
  - **Other marker types**
- Type changes are unchanged: `requestGuidedIntentChange` and `applyGuidedIntentChange`, with the incompatible-component confirmation. The draft, text, response session and response timeframe are kept.
- Kept from the refinement: the step header, the Optional section, the plain-words bar, the Levels card, Review, and the Add tab's "Plan a trade" entry.

**Self-review fixes in the same commit:**
- **Review held back silently.** While a response timeframe loads, or after it fails, Review is disabled with no unmet checklist item. The bar now says "Loading the response timeframe…" or "Choose a response timeframe that loads". Covered by a unit test.
- **Entry cards at accessibility sizes.** The cards (Add tab and Change type) squeezed their titles beside the face. They now stack (`after/entry-AccessibilityXL`).
- **Amber limited to Setup.** The bar's amber is now limited to a Setup's levels. Social prompts are always grey.

**Revised captures** (in `after/`):
- `analysisDetails`, `analysisEmpty`, `questionShort`, `setupTracked`, `setupUntracked`, `responseDetails`, `responseChooser`, `entry`, `discardConfirm`
- `-lightGrey`, `-dark`, `-AccessibilityXL` and `-iphone-se` variants

All of them are fixture renders.
