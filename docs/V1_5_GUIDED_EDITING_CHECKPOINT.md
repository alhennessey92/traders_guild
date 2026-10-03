# v1.5.0 guided editing and half-height sheet: engineering checkpoint (Claude)

Branch `claude/1.5.0-avatar-markers`, worktree `.worktrees/marker-avatar-claude`, on top of `5133a03`.

**Briefs:**
- `docs/V1_5_GUIDED_EDITING_CLAUDE.md` (the owner approved guided editing)
- the owner's two in-session requirements on sheet height (§5)

**Stop point.** Engineering review by Astra, then owner visual review. Nothing is pushed or deployed. No phone, runner, credentials, backend, auth, schema, Android or production change.

`$S` = `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad`. Captures are in `docs/visual-review/v1.5-guided-editing/`; test summaries are in `…/test-results/`.

**Not covered here.** These remain owner-assisted and are not implied by fixture evidence:
- live chart behaviour in an edit
- real sheet detents and their drag behaviour
- the keyboard over the real sheet

The simulator app is signed out, and I did not type credentials.

## 1. Commits

| Commit | What |
|---|---|
| `5133a03` | Bottom-sheet checkpoint corrected: Astra inspected the 815/21 results and did not re-run them. |
| `dbfd793` | Groundwork: the update request can clear a title or note (opt-in). Optionally, a Setup's Entry is sent as saved. The legacy encoding is unchanged. |
| `ec193e0` | **Guided editing:** Details → Review → Save changes (§2–§4). Includes 16 unit and 6 UI tests. |
| `eab30bb` | **Half-height sheet** (owner requirement): collapsed / 28% / 50%, with a Setup split into sections (§5). Includes tests. |
| `1d511af` | Fix: the header counts a Setup's three steps. An edit's Review leads with what changes. |
| this commit | This checkpoint and its evidence. |

## 2. Contracts read before implementing

**Server** (chart-service `update_marker` and `UpdateMarkerRequest`, read from Sol's accepted snapshot `$S/backend-5061824`; not changed):
- `model_dump(exclude_unset=True)`: every field present in the body is applied, **`null` included (a clear)**. A field left out is unchanged.
- `components`, when present, **replace all** components and must contain exactly one anchor. The anchor sets `price` and `candle_timestamp`.
- `parent_marker_id` and `link_relationship` are refused ("Marker relationships are immutable").
- **Components cannot change on a tracked Setup in ACTIVE, TP_HIT, SL_HIT or EXPIRED** (400). Before that, `tracking_enabled` moves DRAFT↔ARMED, with the open-setup limits checked.
- The effective-state validation uses the request's fields, falling back to the stored ones.

**Client, as found:**
- `RLUpdateMarkerRequest` encodes `title` and `note` with `encodeIfPresent`, so a cleared title or note was left out and the server kept the old one.
- The legacy editor always sends `trackingEnabled`, `visibility` and every component. It also re-seats a Setup's Entry on the anchor price.
- Hydration (`beginEditingMarker`) drops component types this build cannot read. A full replace then deleted them.
- The client has no tracked-Setup edit lock, so an edit of an ACTIVE Setup failed with the server's 400.
- The update path is `MarkerManager.updateMarkerFromPlacement`: an optimistic patch, server reconciliation, and rollback on failure. It has no share prompt and creates nothing.

## 3. Behaviour (experiment only; Analysis, Question, Setup)

`MainView.beginEditingSelectedMarker`, under the experiment and for these three types, calls `beginEditingMarker`, then `allowTextOnlyAnalysisEdit`, then `prepareGuidedEdit`. Every other type, and every edit with the experiment off, keeps the existing editor (titled "Edit ‹type›" under the experiment, as before).

| Requirement | Implementation | Evidence |
|---|---|---|
| Edit / Save changes wording, with no Post, creation or response | The toolbar says "Edit Analysis". The header says "Edit your analysis" and "Editing your marker". Review says "Check your changes" and "What changes", then "Saving updates your marker for members of ‹guild›". The bar says "Save changes", then "Retry". There is no link session, share prompt or create. | `aGuidedEditSavesAnUpdateAndNeverCreates` (creates 0, one PUT to the marker, no second marker); UI `testAnEditIsTitledAsOne…`, `testRetrySucceedsWithoutCreatingOrSharing`; captures `editAnalysis`, `editAnalysisReview` |
| Type and link fixed | No selector and no Change type. `requestGuidedIntentChange`, `applyGuidedIntentChange` and `openTypeChooser` do nothing in an edit. The relationship is shown read-only ("Supports sam's BTC breakout"). The request never carries `intent`, link fields or `visibility`. | `typeAndLinkCannotChange`; UI `testAnEditIsTitledAsOne…` |
| Only what changed is sent | `buildGuidedUpdateRequest`: title and note only if changed, tracking only if switched on an editable Setup, components only if context or levels changed. | `onlyWhatChangedIsSent` (body keys = `["note"]`) |
| Complete hydration; components the UI does not expose are kept | Hydration is the existing `beginEditingMarker`. Component types this build cannot read are captured as raw requests and appended whenever the components are replaced. | `editingContextKeepsEveryComponentIncludingOnesThisBuildCannotRead` (`future.widget` sent back with its payload; anchor exact) |
| Clearing an optional field | A cleared title or thesis is sent as an explicit `null` (`clearsTitle` / `clearsNote`), which the server applies. The legacy editor's encoding is unchanged. | `clearingTheTitleAndThesisSendsExplicitNulls` (JSON `"title": null`, `"note": null`; saved nil); `theLegacyEncodingIsUnchanged` |
| Exact prices, no rebasing | Components use `rewritesSetupEntry: false`, so Entry and the anchor go exactly as saved. The edit path never calls `refreshSetupEntryForPosting`. **Found by reading, then fixed:** an edit of a Setup could start the chart's three-line placement through the intent change, seeding latest-price defaults and then re-pinning Entry to each new candle. `handlePlacementIntentChange` and `syncSetupComponentsFromPredictionPlacement` now skip a guided edit. | `anArmedSetupSendsItsLevelsExactlyWithoutRebasing` (Entry 63,920.5 ≠ anchor 63,500 kept; the legacy builder would send 63,500). The chart fix is code-read only; live check pending. |
| Setup restrictions | `MarkerGuidedEditOriginal.isSetupLocked` mirrors the server: tracked and in ACTIVE, TP_HIT, SL_HIT or EXPIRED. When locked, the levels are shown read-only with the reason. There is no tracking switch and no context row. Components and tracking are never sent, and the level guard does not apply. DRAFT/ARMED and untracked Setups keep today's editable levels and tracking, with the level-order guard. | `anActiveSetupLocksLevelsTrackingAndContext` (saves the thesis; the legacy builder would have sent components); `finishedSetupsAreLockedAndUntrackedOnesAreNot`; `anEditableTrackedSetupStillNeedsItsLevelsInOrder`; UI `testAnActiveSetupShows…`; captures `editSetupActive*` |
| Validation | Text-only Analysis allowed (the accepted DEV rule). Question needs 10 characters. Setup uses the existing guard. Review needs a change ("Make a change to review it"). | `validationMatchesCreation` |
| Ownership, duplicates, freeze, stale | `MarkerPlacementSubmitter.submitUpdate`: draft and attempt identity; `submitting` freezes navigation and Save; a completion for a draft that has gone returns `isStale`, and the chart does nothing with it. | `whileSavingTheEditIsFrozenAndALateAnswerCannotTouchTheNextDraft` |
| Failure and retry | Failure keeps every edit. The optimistic change is rolled back by the existing path. The text says "Couldn't save … Your changes are kept", and the button becomes Retry. | `aFailedSaveKeepsTheChangesAndRetrySucceeds`; UI `testAFailedSaveKeeps…`; capture `editFailedSave` |
| Back, context, cancel | Back goes one section at a time; context returns to where it was opened; nothing is reset. An untouched edit closes silently. An edited one asks "Discard your changes? The marker stays as it was." | `onlyAnEditedDraftAsksBeforeDiscarding`; UI `testDiscardingAnEditedDraft…`; capture `editDiscard` |

**Mutation checks** (each reverted afterwards). Each failed exactly the test meant to catch it, 15/16 in each case, in `test-results/mutation-*`:
- sending components on a locked Setup
- re-seating Entry
- removing the stale-completion guard

## 4. Accessibility and layout

- The header is one heading. The changes list is one element. The locked card contains its rows, and the reason is spoken.
- Save sits in the fixed 68 pt bar and stays reachable at the largest text size (`testLargestTextKeepsSaveReachable`).
- On iOS 26 the discard dialog is a popover: "Keep Editing" (the cancel role) is a tap outside it, as for a new draft.

Captures: `editAnalysisReview-AccessibilityXL`, `*-iphone-se`, `*-lightGrey`.

## 5. Half-height sheet (owner requirement, this session)

The owner asked that the placing sheet:
- go no higher than 50%, so the chart stays usable
- still collapse fully to the normal capsule
- have a detent at about 25–30%

**Implementation** (`MarkerGuidedSheetHeight`, experiment and guided flow only):
- **Heights:** while the guided flow is placing or editing, the chart sheet's detents are **0.11 (collapsed capsule; the bar and its primary action stay visible), 0.28 and 0.5**. It opens at 0.5.
- **Clamping:** any other height is clamped in `ChartBottomSheet.handleSelectedDetentChange`. 0.9 becomes 0.5 and 0.35 becomes 0.28.
- **Unchanged:** the legacy panel and every other sheet use keep 0.11 / 0.35 / 0.5 / 0.9.

**Sections, so each fits.** A Setup is now three steps:
1. **Levels**: side, R:R, Entry, TP and SL, and the tracking switch with the reputation estimate in its line (replacing the estimate card).
2. **Reasoning**: thesis, then title and chart context as one compact row.
3. **Review.**

Change type appears on both Setup sections, so a Setup with no levels yet can still be left. Analysis and Question stay two steps, with title and context compacted to one row. The bar shows Next / Levels / Review, and Back goes one section at a time.

**Fit evidence:**
- The harness now renders the panel at its real half-sheet height: 50% of the screen, less the grabber and the 68 pt bar.
- On iPhone 17 Pro, UI tests assert that each section's controls are on screen without scrolling:
  - Levels: TP, SL and the switch
  - Reasoning: text, Title and Context
  - Analysis: selector, text, Title, Context and Change type
  - an edit's Review: "What changes" (`testASetupIsSplit…`, `testAnAnalysisFits…`)
- iPhone SE still scrolls within a section (`*-iphone-se`), since half its screen is about 245 pt of content. Reviews with long text also scroll.
- **Not verified live:** dragging the real detents, and the keyboard. When a text field is focused, iOS raises the sheet above the keyboard, so typing temporarily covers more of the chart.

## 6. Verification (final source, `1d511af`)

| Run | Result | Artifact |
|---|---|---|
| Whole unit target, `traders_guild LinkedDev` (DevDebug), iPhone 17 Pro simulator, serial | **835 / 835** | `$S/bs/rb-final-unit2.xcresult`; `test-results/full-unit-devdebug-*.json` |
| UI tests, `traders_guild LinkedDev Profile`: `MarkerGuidedEditingUITests` (6), `MarkerGuidedCreationAccessibilityTests` (13), `MarkerViewingRefinementTests` (6), `MarkerLinkAccessibilityTests` (4) | **29 / 29** | `$S/bs/rb-final-ui3.xcresult`; `test-results/ui-profile-*.json` |
| Plain Debug, `traders_guild Local Gateway`: editing, refinement, creation, experiment gate and text-only edit tests | **54 / 54** | `$S/bs/rb-final-debug.xcresult` (source `eab30bb`; `1d511af` changes only the header text and Review order); `test-results/plain-debug-*.json` |
| `traders_guild GCP Public Prod`, Release, build only | BUILD SUCCEEDED; `strings` finds no fixture launch arguments, `Fixture · ` or "fixture transport" | `$S/bs/build-final-release.log` |

**Runs that failed on the way, kept as findings:**
- An interrupted UI run left a partial result bundle, and the rerun refused to overwrite it. No tests ran.
- One UI run failed 28/29. Change type was only on the Setup's second section, so a Setup with no levels could not get back to Analysis or Question. It was fixed in `eab30bb`.
- The captures showed "Step 3 of 2": the header had the step count hard-coded. Fixed in `1d511af`.

## 7. Limitations and open items

- **No live evidence:** chart, detents and keyboard, as above. This includes whether the chart shows a Setup's saved TP/SL lines during an edit. The chart's three-line placement no longer starts, so TP and SL are edited in the sheet ("Type a new take profit or stop loss").
- **Legacy editor, not changed:** by code reading, the experiment-off editor can still re-seat a Setup's Entry, seed defaults through the same chart path, drop unreadable component types, and leave a cleared title unsent. Recorded for Astra, not fixed here.
- **Re-encoding:** when context or levels change, known components are re-encoded by `MarkerComponentPayload.rawPayload`, as the legacy editor does. A payload key this build does not model could be dropped. Unreadable component types are kept whole.
- **Invalid saved levels:** a tracked Setup whose saved levels are already out of order (Stage 4 evidence records) holds an edit at the level guard while still editable. If it is locked, the server may refuse even a thesis edit, and that error is shown with the changes kept.

## 8. Owner review steps

**Simulator, no account needed.** Use TG LinkedDev from `$S/bs/dd-after`, launched with `-MarkerGuidedCreationFixture <scenario> -TGAvatarMarkersExperiment YES`:
- Edit scenarios: `editAnalysis`, `editAnalysisReview`, `editQuestion`, `editSetupArmedReview`, `editSetupActive`, `editFailedSave`, `editRetrySuccess`, `editDiscard`.
- Creation scenarios: `analysisEmpty`, `setupTracked`, `setupReasoning`, `setupReview`, `responseDetails`.
- The panel is shown at its real half-sheet height.

**Live** (after an owner sign-in on the simulator, or on the phone when the owner chooses):
- Edit your own Analysis, Question, an ARMED Setup and an ACTIVE Setup, from the detail sheet's Edit.
- Drag the sheet: collapsed, about 28%, 50%, and no higher.
- Type in each section with the keyboard up.
- Place a marker while the sheet is at 28% and at 50%.
