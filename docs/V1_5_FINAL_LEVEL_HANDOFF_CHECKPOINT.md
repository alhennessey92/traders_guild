# Final v1.5 saved-level chart handoff

4 October 2026. The bounded support/resistance handoff is implemented and verified locally. Hold for integration review; full Phase B and owner acceptance remain open.

**Subsequent acceptance:** orchestration integrated this checkpoint at `ec65f6fb6496960a2cce5ad7872be01606412475`. Latest-source compilation and manual/Claude pickup are recorded in [`V1_5_FINAL_MANUAL_AND_CLAUDE_PICKUP.md`](V1_5_FINAL_MANUAL_AND_CLAUDE_PICKUP.md). The review hold below is historical; the manual session gate remains open.

## Source and scope

- Sole editor/tree: `.worktrees/marker-workspace-final`, `sol/1.5.0-final-workspace`.
- Accepted integration/base: **`ec5146dcfe4587af8174a722e8f9fa79d721f3eb`**.
- Tested app/tests commit: **`07996d636b0f87341f944ca1f2205c2df31e4a47`**.
- Authority: sanctuary final handover and Phase A/B assignments, plus the owner's bounded saved support/resistance follow-up.
- Client-only change. No backend, request/response schema, taxonomy, extra step, modal, authentication, deployment or Apple submission changes.

## Functional closure

Context's existing support/resistance Edit opens the Level editor with its numeric price field and **Work on chart** action. The action snapshots that exact selected component, applies any pending numeric adjustment, activates the existing support/resistance drawing tool and collapses the same sheet. The renderer's existing coordinate-to-price handle callback updates that same component ID, preserving its saved label, color, line style and width. No-op handoff/Done also preserves an absent saved label.

The workspace stays on Level during chart work. Collapse/resume retains its route, raw numeric text and editor state. Chart changes update the numeric value; valid numeric changes after handoff update the same chart component. Existing chart tap-to-save ends handle interaction while keeping the Level editor available for re-entry. Explicit Done retains the selected edits and returns internally to Context. Explicit Cancel restores only the selected component and its color override, leaving other levels, Setup components and unrelated draft text intact.

The selected ID owns this handoff: chart re-entry cannot silently select a different same-type level. Saved Setup Entry dragging remains disabled; existing saved Setup lifecycle permissions are unchanged.

Native verification found two reachability defects: plain summary rows did not accept a center tap in their empty space, and the new chart action retained the price keyboard so the sheet could not collapse. The full summary row now has a rectangular hit shape; the new action uses the existing keyboard dismissal helper before collapsing.

## Actual verification

| Layer | Result | Coverage |
| --- | --- | --- |
| Four focused model suites | **55 passed** | Workspace, drawing workflow, saved edit/lifecycle guards and raw payload preservation |
| New saved support/resistance regressions | Included above | Second duplicate exact identity/style/order; raw future keys; selected-only Cancel; internal route/scroll/selection retention; chart re-entry and numeric synchronization |
| New guard/no-op regression | Included above | Setup Entry refused; saved resistance with nil label/style stays exact on no-op handoff/Done |
| Native Level journey | **1 passed, 0 failed/skipped** | Full-row Edit tap, numeric edit, chart collapse/resume, original price after Cancel, adjusted price after Done, internal Context/Details/Review/Post and preserved label in in-memory request |
| DevDebug simulator compilation | **Succeeded** | App and test targets compiled for the passing native run |

Model bundle: `/private/tmp/tg-level-handoff-focused.xcresult`. It contains 55 passing model tests and an initial failing native selector, so the bundle's overall result is Failed. Model/state/renderer code did not change afterward; only the summary hit area, new action's keyboard dismissal and UI selector were corrected. The independent accepted native bundle is `/private/tmp/tg-level-handoff-native-keyboard.xcresult` (overall Passed). Intermediate native bundles recorded the confirmed hit-area and keyboard defects; they are diagnostics, not accepted passing evidence.

Accepted native device: dedicated iPhone SE (3rd generation), iOS 18.2, `5DAF71B8-2AD0-4274-BE05-97967604193F`. Scheme: temporary `Slice1 Fixture Review`; DevDebug, simulator SDK, serial tests, existing derived data. The temporary scheme was removed. No optimized DevProfile or standard Release rebuild is claimed for this new source.

Sanitized summaries, model result lines, unedited XCTest capture and exact source/device/test/time provenance are under [`level-handoff`](visual-review/v1.5-final-workspace/level-handoff/). The native fixture uses the actual sheet/panel/footer and an in-memory submitter. It does not contain the signed-in chart: renderer reuse is established by code and shared model callback tests, not a live drag gesture claim.

## Final-plan compliance matrix

| Final requirement | Checkpoint status |
| --- | --- |
| Exactly Post to the chart / Setup entries | Retained; entry code unchanged |
| Analysis/Question Details, optional Context, Review/Post | Retained; new native journey returns internally through these routes |
| One persistent sheet and internal editors | Level remains the same route during handoff/resume; Cancel/Done stay internal; no extra navigation bar or modal |
| Chart-native saved support/resistance editing | Gap closed with existing level handles, exact component ID and numeric synchronization |
| Exact saved Setup / lifecycle safeguards | Entry drag guard unchanged; existing saved lifecycle tests pass; new handoff refuses Setup Entry |
| Linked response relationships/conversion/timeframes | Unchanged; previous accepted local checkpoint remains the evidence |
| Legacy and released-client/API compatibility | Existing non-workspace handle path retained; no backend contracts or payload assumptions changed; raw saved payload regressions pass |

The existing isolated-DEV experiment gate remains unchanged. This checkpoint does not promote it to a release.

## Review and manual pickup

Review source commit `07996d6` and this evidence on top of accepted base `ec5146d`; this worktree holds for review. Claude's planned visual polish should preserve exact identity, selected-only Cancel, numeric synchronization and current Setup/lifecycle restrictions.

The signed-out dedicated iPhone 17 Pro/iOS 26 simulator still requires the owner's manual sign-in. The next actual chart session should verify saved support/resistance handle dragging, style/geometry, collapse/resume and Cancel/Done against the existing protected local QA environment. No credentials were typed or authentication bypassed; no phone was operated. Signed-in realtime repaint, physical-device acceptance and the other full Phase B gates remain open.

The backend audit subsequently completed: unknown-key normalization is pre-existing, and no evidence shows v1.5 depends on extras. Retain typed contracts; no blanket JSON passthrough or backend fix is justified. A bounded read-only historical production payload-key inventory remains a promotion gate, alongside actual released-client runtime checks. The authoritative audit is sanctuary `docs/v1_5_sheet_ux_review/FINAL_BACKEND_PAYLOAD_REVIEW.md`. This follow-up made no backend writes, resets, restarts or normalization changes. See [`V1_5_FINAL_PHASE_B_LOCAL_CHECKPOINT.md`](V1_5_FINAL_PHASE_B_LOCAL_CHECKPOINT.md) for historical local API/lifecycle evidence and remaining gates.
