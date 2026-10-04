# Final v1.5 Phase A review closure / bounded local Phase B

**Follow-up:** this checkpoint was accepted and integration advanced to `ec5146dcfe4587af8174a722e8f9fa79d721f3eb`. The subsequent bounded saved support/resistance chart handoff is implemented at `07996d636b0f87341f944ca1f2205c2df31e4a47`; see [`V1_5_FINAL_LEVEL_HANDOFF_CHECKPOINT.md`](V1_5_FINAL_LEVEL_HANDOFF_CHECKPOINT.md) for its passing model/native evidence and review hold. The historical integration and handoff-gap statements below describe this earlier checkpoint. Full Phase B remains open.

4 October 2026. Phase A review fixes complete. Bounded programmatic local integration verified; full Phase B and owner acceptance remain open. Integration stays at `d444158` until orchestration reviews this branch.

## Exact source and authority

- Sole editor/tree: `.worktrees/marker-workspace-final`, `sol/1.5.0-final-workspace`.
- App/review regression commit: **`fb7f70a3c5771cb4957d35da726c1377350dba16`**.
- Opt-in local harness commit: **`6c67945a329eecfd0eb90d907c55a44335afde56`**.
- Previous functional checkpoint: `85da7b3`; original tested implementation/safeguards: `874996f` / `4478e4d`.
- Authority: sanctuary `docs/version_docs/ios/1.5.0-final-handover.md`, `FINAL_PHASE_A_ASSIGNMENT.md`, `FINAL_PHASE_B_ASSIGNMENT.md`.
- No product replanning, taxonomy expansion, visual redesign, backend/source/schema/authentication change, stack restart/reset/reseed, production, push, deployment, Apple submission or owner-phone operation.

## Review closure

**Duplicate support/resistance: confirmed defect, fixed.** The Context summary supplies an exact local component ID, but the editor hydrated price/style from the first component of the type. Entry now resolves and validates the exact ID/type, and Done preserves that selected component's style/label. The saved duplicate-support regression decodes a real-shaped API payload, edits the second support through the workspace, verifies no-op Done, exact local identity, untouched first support, raw future keys and saved component order.

**IME composition: confirmed defect, fixed.** The multiline adapter could write stale text and selection while UIKit had a marked range. Draft text/cursor/offset synchronization now waits until marked composition ends. Style updates remain available. The single-line text setter also respects marked text, complementing its existing selection guard. A real `UITextView` regression uses Japanese marked text, attempts a stale draft/cursor update, verifies composition and selection survive, then verifies ordinary committed-text synchronization resumes.

**Horizontal numeric field: related confirmed defect, fixed.** The new workspace field called the legacy level binding, which ignores horizontal drawings. It now updates the exact horizontal drawing ID and retains label/color/line style/width. A two-drawing regression proves the other drawing is unchanged and Cancel restores the selected drawing exactly. Legacy bindings and other hosts are unchanged.

## Final-plan compliance matrix

| Final requirement | Status / evidence |
| --- | --- |
| Exactly Post to the chart / Setup entries | Retained shared two-entry UI; prior native entry test; no catalogue/Other changes in follow-up |
| Analysis/Question Details, optional Context, Review/Post | Retained; real local model/submitter create/read/edit for both social intents |
| Internal persistent sheet navigation | Retained; two final native input/resume journeys passed; pending editors stay in placement workspace |
| Linked response + deliberate Setup conversion | Real local model round-trips Supports / Challenges / Builds On with Setup conversion and return, parent and 4h response / 1w context retained |
| Exact saved Setup / lifecycle safeguards | Real local saved geometry and note-only update; existing tracked conflict preserves draft, then new draft retries untracked; live natural ACTIVE component lock and note-only save verified; fixture resolved-state locks remain intact |
| Context identity / legacy compatibility | Real local second-support price/style/order and attached indicator/source/drawing round-trip; client raw/unknown preservation regressions pass; server normalization limit below |
| Existing backend/released-client contracts | Existing endpoints, request types and semantic restrictions retained; no schema, enum or production-gate change |

The gate remains isolated-DEV-only/off by default. The Release build has no `TG_ISOLATED_DEV` define. No release promotion was performed.

## Safe local environment

Gateway `http://127.0.0.1:30080/api/v1`, `/healthz` 200. Inspected the running containers, not only Compose files: Discord/webhooks/result postback/digests, registration email, FCM, awards processing/notifications are disabled; Resend/APNs/FCM credential configuration is empty. TimescaleDB and Redis stay loopback. Chart source is the existing `backend-5061824` scratch mount; the other services use `linked-markers-backend`. No containers or configuration changed.

Existing Stage4 QA guild/accounts and BTC/USD were reused. QA credentials remain in the existing mode-600 protected file. Silent programmatic login keeps passwords/tokens out of test output and persistent app authentication; the independent `RealAPIService` holds its token in memory. UI automation never typed credentials. Test evidence contains only public QA IDs and check results.

Checks are additive and labelled `phaseb-*`, primarily 1w with linked 4h responses. Diagnostic run rows were preserved too. The local inventory records 21 new labelled QA rows, including diagnostics, separately from pre-existing fixtures; no prior user/fixture data was removed or rewritten. The lifecycle probe uses a new 1M Setup owned by QA B.

## Actual verification

| Layer | Result | Coverage |
| --- | --- | --- |
| Focused review model/raw preservation suites | **25 passed** | Exact support identity, IME, horizontal price/Cancel plus existing related guards |
| Final combined simulator run | **28 passed, 0 failed/skipped** | 25 models + one real-local integration journey + two native fixture input journeys |
| Real local model/submitter/API | **Passed** | Analysis/Question create/read/edit; saved Setup geometry; context second-support identity/style/order; RSI/source/drawing; three response relationships/conversion/cross-timeframe; authorization failure/retry |
| REST / WebSocket | **5 checks passed** | Drawing create/read/edit, marker_created/updated, second-QA-recipient delivery, reconnect/resubscribe, short Question rejection |
| Linked Setup REST | **1 check passed** | New untracked Supports response, parent + 4h response / 1w supporting context read back intact; API-only |
| Existing local processor / lifecycle | **4 checks passed** | Tracked create → natural ARMED/ACTIVE; ACTIVE full-component refusal; note-only geometry preservation |
| Optimized DevProfile | **BUILD SUCCEEDED** | Isolated define and `-O` verified |
| Standard Release | **BUILD SUCCEEDED** | Isolated define absent; experiment off |

The combined simulator test is **programmatic workspace model/submitter integration**, not a signed-in UI journey. The two native tests use backend-free fixtures. WebSocket receipt establishes server delivery; chart manager repaint after receipt is not yet end-to-end verified.

Accepted scratch bundles/logs:

- `/private/tmp/tg-phaseb-local-verified.xcresult` / `.log`
- `/private/tmp/tg-phaseb-local-workspace.xcresult`: focused 25-model result
- `/private/tmp/tg-phaseb-review-profile.log`, `/private/tmp/tg-phaseb-review-release.log`
- Local sanitized results/provenance: `docs/visual-review/v1.5-final-workspace/local-checks/`

Exploratory diagnostics included a test-target compile flag excluding the opt-in test, inherited scheme env causing a skip, a pending timeframe operation left unfinished in the harness, a mistaken component string in a test, an existing tracked-Setup conflict, and a simulator clone failure before execution. These were corrected in the test harness/run setup; they are not accepted product failures or evidence. Unknown-key normalization was a genuine existing backend observation, retained below.

## Genuine functional gaps / compatibility limit

1. **Chart-native level editing:** new drawings use the existing graphical workflow (including support/resistance via the drawing picker). Existing support/resistance summary Edit opens a numeric editor with no direct graphical edit handoff. Saved Setup Entry is read-only and editable TP/SL remain numeric by explicit assignment. New Setup chart dragging remains its existing path. Native gesture/state coordination is still unverified signed in; the support/resistance numeric-only summary route is a final-handover interaction gap to review, not visual polish acceptance.
2. **Server normalization:** this existing local backend validates component payloads into typed Pydantic models and persists `model_dump` on create/full-component replacement. Unrecognised keys in otherwise-known payloads are stripped at create; the live probe cannot establish historical future-key preservation. Client preservation is verified by the decoded saved-data fixtures. A historical saved key could likewise be lost on a full-component server update despite the client sending it unchanged. Orchestration must review that pre-existing compatibility limitation before backend/payload promotion; no backend fix or contract broadening was attempted.
3. **Lifecycle coverage:** ARMED tracked create/conflict and saved geometry are exercised live. The new monthly Setup naturally progressed ARMED → ACTIVE after the existing scheduled processor cycle (reconcile interval 300 seconds). An identical full-component update was refused with 400; a note-only save succeeded with exact component IDs/order/payloads. The initial 50-second wait stayed ARMED; a later read of that same marker observed ACTIVE, without creating another marker or forcing state. `lifecycle-summary.json` records all four successful checks. Fixture coverage handles TP_HIT / SL_HIT / EXPIRED client locks; live terminal states were not forced.

## Manual gates and pickup

The dedicated iPhone 17 Pro / iOS 26 simulator (`12A720B0-3FA0-4987-B9DE-1C856643F758`) was launched normally with the experiment enabled and is **signed out**. Manual sign-in was requested; no sign-in/authentication workaround was added. The owner's phone is untouched. Install the final simulator artifact before the eventual signed-in run; existing app data/session should be retained:

```sh
xcrun simctl install 12A720B0-3FA0-4987-B9DE-1C856643F758 \
  /private/tmp/tg-final-workspace-dd/Build/Products/DevDebug-iphonesimulator/traders_guild.app
```

Owner/manual session gate: sign in to the existing protected local QA account, then validate social create/edit, Setup levels, context chart gestures, response navigation/timeframes, actual chart realtime refresh, failure recovery and collapse/keyboard behavior. Notifications/deep links/sharing and physical-device acceptance remain later real-client gates. Programmatic results do not waive these.

Claude: use the final branch as described in `V1_5_FINAL_PHASE_A_CHECKPOINT.md`; preserve these source/contract safeguards while refining visuals, interaction and accessibility. Review the recorded support/resistance chart handoff gap with orchestration before expanding its mechanics. No reset or legacy-data decision is authorized here.

Orchestration: review/accept the app fixes and local evidence, address the server raw-key compatibility observation, then integrate from `d444158` using the final branch. This worktree holds after the bounded checkpoint; full Phase B, owner hands-on acceptance and release promotion are not declared complete.

### Opt-in local rerun

Recreate `Slice1 Fixture Review.xcscheme` with the existing helper. Set TestAction `shouldUseLaunchSchemeArgsEnv="NO"` and `TG_LOCAL_WORKSPACE_QA_FILE` to the existing mode-600 protected path in the temporary scheme only. Use isolated DevDebug, simulator SDK, `ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO`; `-parallel-testing-enabled NO` avoids the observed simulator clone failure. The test skips without the opt-in path or an isolated build. Verify outbound safety before any rerun; the harness is additive. Remove the generated scheme afterward. Credentials must not be supplied as environment values or UI text.

REST/WebSocket and lifecycle scripts take only the protected file path and sanitized output path. Run after the same outbound-safe local preflight. Lifecycle checks rely on the existing processor timing and must not force terminal states or restart/reseed the stack.
