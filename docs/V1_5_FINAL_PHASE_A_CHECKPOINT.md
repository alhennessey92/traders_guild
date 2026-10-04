# Final v1.5 Phase A functional checkpoint

## Status and source

Follow-up review closure and real-local verification are recorded in [the bounded Phase B checkpoint](V1_5_FINAL_PHASE_B_LOCAL_CHECKPOINT.md). This document retains the original Phase A evidence and hashes.

Functional implementation complete, 4 October 2026. Ready for orchestration integration review and Claude pickup. Full visual/accessibility refinement, signed-in chart verification and owner device acceptance remain later gates.

- Sole implementation checkout: `.worktrees/marker-workspace-final`.
- Branch: `sol/1.5.0-final-workspace`.
- Tested app/test source commit: **`4478e4de5171626fc57d3c6566a97a09019a6a37`**.
- Main implementation commit: `874996fed4a19c8a44889848d007a27cd36a99c8`; final source safeguards: `4478e4d`.
- Integrated parent: `d444158d96a9128e5375649e6fa04df6c52a0af2`.
- Canonical scope: sanctuary `docs/version_docs/ios/1.5.0-final-handover.md` and `docs/v1_5_sheet_ux_review/FINAL_PHASE_A_ASSIGNMENT.md`.
- Superseded work remains preserved at `5fcacb5424224927e4f35792b1d8b624a4e32f42` in `marker-sheet-sol`. Its full flow was not merged or cherry-picked. Selected keyboard geometry/policy, actual MainView fixture and header/footer patterns were adapted.
- Other checkouts remain unchanged. Claude's existing checkout is still `d37fd26880882f55cce0f81dd5031012d5a9b373`; integration remains `d444158` pending orchestration pickup.

## Delivered

Exactly two shared avatar-led create entries: **Post to the chart** and **Setup**. The gated create path has no Other disclosure, type catalogue, Change type screen, progress track, separate Setup reasoning stage or Review now shortcut.

Social Details has visible Analysis / Question choices, required text, optional title and Add context, followed by Review and the existing Post path. Setup has one scrolling Details surface containing saved/new Entry, SL/TP, inferred side, RR, tracking, optional reasoning/title/context, then Review. Entry stays read-only when editing a saved Setup.

`MarkerPlacementState.workspace` owns navigation, editor values, component identity, per-destination scroll anchors, text selections/offsets and the resume detent/viewport. `guidedStep` has only Details, Context and Review; Context contains internal destinations for indicator picker/settings, drawings/editor, levels, supporting timeframes, source/note editors and response relationship/timeframe. Routine workspace actions do not open another sheet.

The technical indicator fields now render through an embedded adapter backed by `IndicatorSettingsDraft`; existing unrelated sheet hosts retain their wrapper and save API. Indicator calculations, managers and payload logic were not replaced. Saves retain the exact draft and moving-average instance identity.

- **Done** commits an editor and returns to the removable Context summary.
- **Cancel** discards only that editor's unfinished work and returns to its picker/previous destination.
- **Back** from a picker preserves already attached context.
- Graphical tools use the existing chart workflow. Cancel restores drawing geometry/style/identity without undoing live Setup Entry repricing or unrelated draft text.
- Source/note/level entry stages values before creating a component; invalid URL placeholders are never attached. New source creation is available only while no source is attached; existing sources are edited/removed by exact identity, preserving legacy components.
- Setup numeric input keeps unfinished strings and cursor positions. A deliberate chart repricing clears the previously typed display value so the sheet and chart agree.

Responses open social Analysis Details directly. Conversion to Setup and return to social keep parent, relationship, title/text, compatible components and the response timeframe operation. Incompatible removal still requires the existing warning. Saved edits expose no type/link conversion.

Saved Setup geometry is hydrated without latest-price seeding. Guided edits also refuse direct final-price refresh. Existing raw payload/order preservation, partial saves, fail-closed component pairing and retry behavior remain in place. ACTIVE / TP_HIT / SL_HIT / EXPIRED tracked Setups keep their levels, context and tracking locks.

Keyboard sizing uses the actual sheet's window and docked keyboard overlap, freezes fit by structural revision, excludes floating keyboards and restores the prior choice. Collapse stores its viewport/detent in the placement session. Guided animations respect Reduce Motion. The actual MainView fixture uses a view-only fake user; it does not populate authenticated app state or instantiate a signed-in chart. Marker fixture launches skip session restoration in DEV.

## Supported context matrix

Capabilities are the existing semantic client whitelist intersected with typed component support, checked before editor/payload creation. Backend's lack of an intent whitelist does not broaden this UI.

| Context | Analysis | Question | Setup |
| --- | --- | --- | --- |
| Existing indicator catalogue/settings | Yes | Yes | Yes |
| Trendline, horizontal line, zone | Yes | Yes | Yes |
| Enabled breakout/retest, range reversal, rising channel, head/shoulders patterns | Yes | Yes | Yes |
| Support/resistance price editor | Yes | No | No |
| Chart note | Yes | Yes | Yes |
| Supporting timeframes, existing two-panel limit | Yes | Yes | Yes |
| Valid http/https source link | Yes | No | No |
| Setup Entry / SL / TP in Details | No | No | Yes |

Tracked lifecycle locks and unverifiable saved-component pairing further restrict context edits. Future drawing tools and emoji creation are excluded. Polls, alerts/news intents, media, new intent strings and visibility placeholders were not added. Legacy decoding/rendering/opening and existing inexpensive editors remain available through their original paths.

## Verification

All runs used safe fixtures or the in-memory transport, simulator SDK, and `CODE_SIGNING_ALLOWED=NO`.

| Check | Result |
| --- | --- |
| iPhone SE 3 / iOS 18.2 focused model + native regressions | **95 passed, 0 failed, 0 skipped** |
| iPhone 17 Pro / iOS 26 final native journeys + expanded-height round trip | **9 passed, 0 failed, 0 skipped** |
| Optimized isolated DEV: LinkedDev Profile / DevProfile | **BUILD SUCCEEDED**, `TG_ISOLATED_DEV`, `-O` |
| Standard Local Gateway / Release | **BUILD SUCCEEDED**, experiment compiles off |
| `xcodebuild -list ... \| grep -c TradersGuildMac` | **0** |
| Whitespace gate | `git diff --check` clean |

The small run covers `MarkerWorkspaceTests`, guided creation/editing/raw-payload/submission-safety/refinement/presentation suites, all eight `MarkerFinalWorkspaceUITests`, remembered empty title/scroll, tall height through Review/Back/collapse, actual Add tab transitions, saved Setup locks and failed-save retry. Contracts include trimmed Analysis/Question validation, multi-instance indicator identity, pending settings/source cancellation, refusal to replace an existing source through Add, capability exclusions, linked Setup conversion/timeframe preservation, exact saved Setup prices/anchor, unknown payload/order, partial saves, fail-closed pairing and retries.

The native journeys verify unsaved indicator value and height through collapse/reopen, no stacked indicator navigation sheet, Done to Context, source URL state through keyboard/collapse, immutable creation entries, Setup's single Details, relationship retention and actual MainView keyboard bounds. An accessibility container identifier initially masked the social choice identifiers; container ownership was corrected. Failed exploratory runs are scratch diagnostics, not accepted evidence.

Exact scratch artifacts:

- `/private/tmp/tg-final-workspace-checkpoint-small.xcresult` and `.log`
- `/private/tmp/tg-final-workspace-checkpoint-standard.xcresult` and `.log`
- `/private/tmp/tg-final-workspace-checkpoint-profile.log`
- `/private/tmp/tg-final-workspace-checkpoint-release.log`
- Derived data: `/private/tmp/tg-final-workspace-dd`, `tg-final-workspace-profile-dd`, `tg-final-workspace-release-dd`

Eight unmodified passed-fixture screenshots and their provenance index are in `docs/visual-review/v1.5-final-workspace/functional-small/`. These are functional references, not a declaration of final visual acceptance.

## Claude / orchestration pickup

Use the final branch, which includes the checkpoint/evidence commit after the tested source commit. Do not reuse the superseded Sol flow or reset Claude's existing tree. One agent per working tree.

```sh
# Run only after orchestration accepts this checkpoint, from the iOS repository.
git worktree add -b claude/1.5.0-final-workspace-polish \
  /Users/alhennessey/Desktop/traders_guild/sanctuary/.worktrees/marker-workspace-claude \
  sol/1.5.0-final-workspace
```

The integrated target can fast-forward from `d444158` to this branch after its owner verifies that checkout is clean. No integration merge or push was performed by Sol.

To recreate the temporary UI-test scheme in the new checkout:

```sh
python3 docs/visual-review/v1.5-sheet-slice1/make_review_scheme.py
```

Use scheme `Slice1 Fixture Review`, configuration `DevDebug`, `ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO`, a dedicated simulator and separate derived data/result paths. The generated scheme is excluded from commits and removed from the final Sol tree after verification. Model suites and native journey test names are listed above for targeted reruns.

Safe launches: `-MarkerGuidedCreationFixture <scenario> -MarkerGuidedSheetFixture YES -TGAvatarMarkersExperiment YES`; actual presenter: `-MarkerMainViewSheetFixture -TGAvatarMarkersExperiment YES`; Add shell: `-MarkerSheetShellFixture -TGAvatarMarkersExperiment YES`.

## Remaining gates and intentional limits

- Claude: refine compact summaries, field/chrome spacing, full themes/Dynamic Type/VoiceOver traversal, interactions, and final evidence. Functional state/contract preservation should remain the baseline.
- Actual signed-in chart placement/drawing/realtime behavior and owner device acceptance have not been exercised here. Setup edit line dragging remains disabled; existing safe numeric TP/SL controls are retained. New-Setup chart dragging remains on its existing path.
- Fixture transport is not a live backend. Historical invalid tracked Setup edits may still be refused by the existing stricter backend guard; errors and draft retry are preserved.
- Experiment remains isolated-DEV-only and off by default. Release promotion is separate.
- No backend/schema/API change, production operation, data reset, minimum-version cutover, credentials, owner's phone, push, deployment or Apple submission was performed.

Sol holds at this functional checkpoint for orchestration/Claude pickup.
