# v1.5.0 Stage 3 checkpoint: guided creation (Claude)

Branch `claude/1.5.0-avatar-markers`, continuing the accepted `ec2812a`. Worktree `.worktrees/marker-avatar-claude`. This is one local commit: not pushed, not deployed, and no backend, Android or production changes. The commit hash is reported in chat. The next step is Astra's engineering review; Stage 4 has not started.

**Transport versus backend.** Every posting result in this checkpoint comes from `MarkerFixtureTransport`, an in-memory `MarkerAPIClient` in the fixtures folder. It records the exact request the app builds and answers as it is told.

It is **not** the backend. The live and local backends still reject a text-only Analysis with a 400 ("Analysis markers require at least one chart component"). The fixture's "fail first" mode mirrors that refusal. Real acceptance of a text-only Analysis is the Stage 4 local-DEV validation change, and it is not claimed here.

## What was built

**Gate.**
- Everything below is reachable only when `MarkerAvatarExperiment.isEnabled` is true, which means isolated DEV (DevDebug or DevProfile) with the switch on.
- With the experiment off, and in every production configuration, the experiment is unreachable: the Add tab shows the legacy flat list, responses use the legacy panel, and Analysis still requires a component.
- Editing an existing marker always uses the legacy editor.

**Entry** (`chartSheetMarkersView`).
- The Add tab shows a hierarchy:
  - a prominent **Post to the chart** card with the viewer's face, which starts a guided Analysis
  - **Structured**, with a **Setup** row that starts guided Setup, using the same tracked-setup preflight as the legacy row
  - an **Other marker types** disclosure holding the legacy rows for Alert, Poll, News, Reaction and Personal, which open the legacy panel
- Setup is not in the social selector.
- Option rows now pass a face only for Personal. With the experiment off this is identical, because non-Personal rows never showed a face. With it on, it removes Stage 2's "viewer's face on every Add row".

**Guided panel** (`MarkerGuidedPlacementViews.swift`, shown in place of the legacy tabs while `placementState.guidedStep` is set).
- **Social Details:**
  - Analysis/Question choice
  - optional title
  - contribution text, with a live hint
  - **Add context**, which is optional and opens the existing `UnifiedComponentsHostView` editors unchanged
  - **Change type**
- The primary action goes **directly to Review**. There is no mandatory context or skip step.
- **Setup Details:**
  - side, derived from TP versus Entry exactly as the chart lines already do (Long, Short, or TP/SL on the same side)
  - Entry, fixed to the latest price at post, as before
  - TP and SL fields on the shared level binding
  - R:R
  - the Tracked toggle, defaulting on as before
  - the shared tracked card
  - an explicit **Untracked** notice
  - the tracked checklist hints, optional title and thesis, context, and Change type
  - the on-chart Entry/TP/SL lines stay draggable
- **Review:**
  - face, with the intent badge showing Setup's tracking status
  - intent
  - "Posting to [Guild]"
  - the response line, when replying
  - title and text
  - context summary
  - timeframe
  - for Setup: side, Entry/TP/SL, R:R and tracked/untracked
  - posting, failure and "draft is saved" state
- **Post** reuses the existing path (`.placeMarkerRequested` → `placeMarkerFromState`), with its permissions, preflight and share prompt.
- The bottom bar shows Back, Review, Done and Post/Retry. The toolbar title follows the step.

**One draft, not two.**
- Every guided view binds to `MarkerPlacementState`.
- New state is only the guided step, submission phase and draft baseline, stored in the class; the behaviour lives in `MarkerGuidedPlacement.swift`.
- `reset` leaves the guided step alone, so an entry point can choose the guided flow before placement initialises the draft.
- Leaving placement, success included, calls `endGuidedFlow()`.
- Back, context editing, type changes, a failed post and a retry leave text, title, components, Setup values, the link context and the response timeframe untouched.

**Submission.**
- `MarkerPlacementSubmitter.submitCreate` is extracted from `TradingChartView.placeMarkerFromState` without changing behaviour:
  - success ends the response session and yields the share context for the existing prompt
  - failure keeps the draft and link and records the reason, now also as `submissionPhase` for Review
- The chart keeps presentation: ending placement, haptics, the toast, and posting the share prompt.
- The "load the response candle" early exit also reports to Review.

**Type changes and responses.**
- `requestGuidedIntentChange` returns a pending change whenever the switch would remove components. Removal needs the author's confirmation ("Remove and Switch").
- The list of what is removed comes from the state's own rules, the same ones `setIntent` purges with, so nothing is removed silently.
- Changing to Setup applies Setup's tracked default.
- Responses still start as Analysis and, with the experiment on, enter the guided flow. Change type → Setup keeps the link.

**Cancel.**
- The toolbar close button asks "Discard this draft?" (Discard Draft / Keep Editing) only when a guided draft has material edits:
  - trimmed title or text
  - attached context
  - tracking changed
  - poll fields
  - Setup levels moved from where placement seeded them
- Moving the anchor is not a material edit. A type change to Setup does count, because it turns tracking on.
- Untouched drafts, and the legacy flow, close as before.
- The decision is `cancellingNeedsConfirmation`, and the dialog is the shared `MarkerGuidedDiscardConfirmation`, used by both the app and the fixture harness.

**Shared Setup parts** (`MarkerSetupEditorParts.swift`).
- `levelPriceBinding(for:)` and `MarkerTrackedSetupCard` moved from `MarkerPlacementGeneralTab` unchanged. The General tab now calls them.
- `MarkerSetupSide` is new.

## Decisions

These are interpretations of the frozen contract, not new scope.

- **Setup validation is unchanged.** As in the legacy Place button, `isValid` never blocks a Setup. Tracked TP/SL requirements show as unmet hints, and the backend enforces them. The guided Review/Post uses the same `isValid`.
- **Analysis without context is valid only in the guided flow** (`requiresAnalysisContext`). The legacy flow, and every older app build, still require a component.
- **Side is derived, not chosen.** There is no new flip control, which preserves existing Setup semantics.
- **Other marker types leave the guided flow** for their existing legacy panel. The same applies from the in-placement Change type.
- Placement start already raises the sheet to 0.35. Guided entry does not collapse it, because Details is where the author starts.

## Tests

The new `traders_guildTests/MarkerGuidedCreationTests.swift` has 12 tests over the real state, submitter and `MarkerManager`, with the fixture transport:

| Test | What it proves |
|---|---|
| `analysisGoesFromDetailsToReviewWithTextAlone` | Details → Review with text alone; the payload has exactly one anchor and no context |
| `whitespaceIsNotAnAnalysis` | Whitespace-only text is rejected |
| `theLegacyFlowStillRequiresAnalysisContext` | The legacy flow still requires a component; only the guided checklist marks it optional |
| `questionKeepsItsTenCharacterMinimumAndTheDraftSurvivesTheSwitch` | Question keeps its 10-character minimum, and switching intent keeps the text |
| `contextRoundTripAndBackKeepEverything` | Context round trip and Back → Review produce a byte-identical request |
| `changingTypeNeverRemovesContextSilently` | Change type to Setup returns a pending change listing Support and Link, and changes nothing until confirmed; applying it removes exactly those and turns tracking on |
| `aResponseStartsAsAnalysisAndCanBecomeASetupWithoutLosingItsLink` | A response starts as Analysis; after changing to Setup the link context, parent id and relationship are in the payload |
| `trackedAndUntrackedSetupsCarryTheirLevelsAndTracking` | Tracked and untracked payloads, side and R:R; the tracked same-side requirement still appears |
| `onlyMaterialEditsNeedAConfirmationToCancel` | Cancel asks only after material edits: not for an untouched draft, an anchor move, or whitespace; yes for text, an indicator, or a moved TP; never in the legacy flow |
| `endingTheFlowClearsGuidedStateButNotTheLegacyDraft` | Ending the flow clears guided state but not the draft |
| `aFailedPostKeepsTheDraftAndARetryPostsTheSamePayload` | Failed post, then retry (details below) |
| `aSuccessfulTrackedSetupHandsOffToSharing` | A tracked Setup posts and hands an ARMED marker to the share prompt |

`aFailedPostKeepsTheDraftAndARetryPostsTheSamePayload` follows a linked text-only Analysis through a fixture 400 and a retry:
- After the failure: the draft, the Review step and the link are kept, the reason is recorded, and the optimistic marker is withdrawn.
- The retry sends a byte-identical request, and it succeeds.
- The success ends the session and hands the created marker to the share prompt.

**Gate coverage.**
- The suite also runs under the plain Debug scheme (not isolated), where `MarkerAvatarExperimentTests` checks that the gate cannot be enabled.
- Production configurations reach none of the entry points: they are behind `MarkerAvatarExperiment.isEnabled`, which is compiled to `false` outside `TG_ISOLATED_DEV`.

## Verification

All runs used simulator iPhone 17 Pro `9B8DAACB-DB63-4F23-A75B-3BC6C52E5705` (iOS 26.0), with `CODE_SIGNING_ALLOWED=NO`, and `ONLY_ACTIVE_ARCH=YES` for tests. Scratchpad `S=/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad`.

| Run | Result | Evidence |
|---|---|---|
| `xcodebuild test`, `traders_guild LinkedDev` (DevDebug), `-only-testing:traders_guildTests` (whole unit target, final source) | **772 tests passed (784 runs), 0 failed, 0 skipped** | `$S/rb-s3-full.xcresult`, `$S/s3-full.log`; in-repo `docs/visual-review/v1.5-stage3/test-results/full-unit-devdebug-summary.json` and `…-tests.json` |
| `xcodebuild test`, `traders_guild Local Gateway` (plain Debug, not isolated), `MarkerGuidedCreationTests` + `MarkerAvatarExperimentTests` | **19 passed, 0 failed, 0 skipped** | `$S/rb-s3-debug.xcresult`, `$S/s3-debug.log`; in-repo `…/plain-debug-guided-gate-summary.json` and `…-tests.json` |
| `xcodebuild build`, `traders_guild LinkedDev Profile`, `DevProfile` | BUILD SUCCEEDED | `$S/s3-devprofile.log` |
| `xcodebuild build`, `traders_guild GCP Public Prod`, `Release` | BUILD SUCCEEDED; `strings` finds no harness or fixture-transport strings. Supporting evidence only: the gate is unreachable, not compiled out | `$S/s3-release.log` |
| `git diff --check` | clean | |

The scratchpad is a session temp directory. The in-repo JSON summaries are the durable copy.

The whole unit target was re-run because this stage changes `MarkerPlacementState`, `MainView`, the chart's submission path and the General tab.

## Interaction evidence

**Harness.** `MarkerGuidedCreationHarness` is DEBUG / isolated-DEV only, launched with `-MarkerGuidedCreationFixture <scenario> -TGAvatarMarkersExperiment YES`.
- It renders the **real** guided panel, bottom bar and discard dialog over a real `MarkerPlacementState`.
- Post goes through the production submitter and `MarkerManager` to the fixture transport, and the harness prints the exact request it received.
- The chart is not in the harness, and neither is the app's sheet chrome.

Screenshots are in `docs/visual-review/v1.5-stage3/`:

| File | Shows |
|---|---|
| `01-entry.png` | In-placement hierarchy: Post to the chart, Structured → Setup, Other marker types |
| `15-entry-other-types-expanded.png` | Other marker types expanded (tapped in the simulator) |
| `02-analysisEmpty.png` | Empty Analysis: "Write something to post", Review disabled |
| `03-analysisDetails.png` | Social Details, ready to review |
| `04-questionShort.png` | Question at 9 characters: "1 more character needed", Review disabled |
| `05-context.png` | Add context: the existing component editors with the draft's level and timeframe |
| `16-context-round-trip-back-to-details.png` | Done → back on Details (tapped): text kept, context summarised as "1 level · 1 timeframe" |
| `06-analysisReview.png` | Text-only Analysis Review: avatar, intent, Posting to Alpha Traders, no extra context, timeframe |
| `07-setupTracked.png` / `08-setupUntracked.png` | Setup Details, tracked (rep card) and untracked (explicit notice, grey pencil badge) |
| `09-setupReview.png` | Setup Review: side, levels, R:R, tracked status |
| `10-responseChooser.png` | A response at Change type, with its link banner |
| `11-responseSetupReview.png` | Response changed to Setup: "Challenges sam's BTC breakout", Short, tracked |
| `12-failedPost.png` | Fixture 400 on a text-only Analysis: "Couldn't post… Your draft is saved", Retry, and request #1 (anchor only) |
| `13-retrySuccess.png` | Retry accepted: request #2 and the share-prompt handoff, with the context the app presents `MarkerSharePromptSheet` with |
| `14-discardConfirm.png` | Close on an edited draft: "Discard this draft?" (a popover from the close button on iOS 26; tapping outside keeps editing) |

## Known limits and follow-ups

- **No real-backend or live-chart verification.** No local backend is running here, and Stage 4 owns local-DEV posting.
  - Not exercised in the running app: the chart ghost and anchor drag during the guided flow, sheet detents, the real `MarkerSharePromptSheet`, and a real 400.
  - Against today's backend, a guided text-only Analysis fails with the generic "Could not place marker. Try again." until Stage 4.
- **The "Remove and Switch" alert has no screenshot.** Simulator tap delivery into the harness's scroll view was unreliable, so its behaviour is evidenced by `changingTypeNeverRemovesContextSilently` rather than a capture.
- **The on-chart placement checklist is still shown in guided mode.** It reads the same rules, so Analysis's component item appears as optional.
- **No accessibility pass yet** (VoiceOver labels and actions, Dynamic Type at accessibility sizes). The key controls carry accessibility identifiers. This belongs to Stage 5 acceptance.
- **Poll attachments, taxonomy expansion, density and private visibility** remain out of scope, as instructed.
