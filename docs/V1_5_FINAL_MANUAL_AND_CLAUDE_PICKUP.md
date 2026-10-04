# v1.5 manual session and Claude Tuesday pickup

4 October 2026. Latest functional integration is accepted. This document prepares the manual session and Tuesday polish; full Phase B, device acceptance and release approval remain open.

## Exact source and builds

- Integration accepted by orchestration: **`ec65f6fb6496960a2cce5ad7872be01606412475`**.
- App/tests source: **`07996d636b0f87341f944ca1f2205c2df31e4a47`**. The subsequent commits contain documentation/evidence only.
- Sole Sol checkout: `.worktrees/marker-workspace-final`, branch `sol/1.5.0-final-workspace`.
- Canonical product scope: sanctuary `docs/version_docs/ios/1.5.0-final-handover.md`; current assignment/status: `docs/v1_5_sheet_ux_review/FINAL_PHASE_B_ASSIGNMENT.md`.

| Build | Latest-source result | Artifact / evidence |
| --- | --- | --- |
| LinkedDev Profile / DevProfile, universal simulator | **BUILD SUCCEEDED**, exit 0; `-O`, whole-module optimization, `TG_ISOLATED_DEV` | `/private/tmp/tg-final-workspace-profile-dd/Build/Products/DevProfile-iphonesimulator/traders_guild.app`; `/private/tmp/tg-final-handoff-profile.log` |
| Local Gateway / standard Release, universal simulator | **BUILD SUCCEEDED**, exit 0; `-O`, whole-module optimization, isolated define absent | `/private/tmp/tg-final-workspace-release-dd/Build/Products/Release-iphonesimulator/traders_guild.app`; `/private/tmp/tg-final-handoff-release.log` |
| LinkedDev / DevDebug, native handoff test build | Passed previously on same app source | `/private/tmp/tg-final-workspace-dd/Build/Products/DevDebug-iphonesimulator/traders_guild.app`; `/private/tmp/tg-level-handoff-native-keyboard.xcresult` |

The two compilation checks use simulator SDK, generic iOS Simulator destination, `ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO` and separate derived-data directories. The generic destination produced universal arm64 + x86_64 binaries, and both architecture app modules compiled. They are unsigned simulator artifacts. No device artifact/archive or release candidate was produced. The Release experiment remains compiled off; the current marker workspace is available only in isolated DEV with the opt-in switch.

Sanitized results, exact build commands, artifact bundle IDs/versions, executable/Info.plist hashes and full scratch-log hashes are recorded in [`build-summary.json`](visual-review/v1.5-final-workspace/build-pickup/build-summary.json). Both app modules compiled on the latest source; no broad tests were rerun.

## Manual simulator pickup

Dedicated standard simulator: iPhone 17 Pro / iOS 26, **`12A720B0-3FA0-4987-B9DE-1C856643F758`**. Its last known state is signed out. No sign-in or simulator installation/launch was performed in this preparation task.

At the manual session, install the verified optimized DEV artifact and launch the real app with only `-TGAvatarMarkersExperiment YES`, using bundle **`co.tradersguild.app.linkeddev`**. Use no fixture arguments for this session. Preserve its existing app data/session; the owner signs in manually to the existing protected local QA account. Simulator gateway configuration is `127.0.0.1:30080`; recheck the existing local environment and disabled outbound integrations before additive QA writes. Do not reset/reseed/restart the stack or alter authentication to make the session work.

Record the source commit, configuration, device/OS, marker IDs and actual results for:

1. Post to the chart → Analysis and Question, text/anchor-only creation, optional Context, Review/Post, saved reopen/edit and failure/retry.
2. Saved duplicate support/resistance: Edit the intended second level, Work on chart, drag the existing handle, adjust numerically, collapse/resume, Cancel restores that level only, Done retains it. Check style, label, other components and internal return routes.
3. Indicator settings/instance identity; drawings/handles; supporting timeframes; source link and chart note; unfinished input, keyboard and retained scroll/cursor.
4. New Setup chart repricing and TP/SL; saved Setup Entry remains read-only, TP/SL use existing permitted numeric edits; tracked lifecycle locks and note-only save behavior.
5. Supports / Challenges / Builds On, branch navigation, Setup conversion/return, response/context timeframes and relationship retention.
6. Actual chart placement and repaint after create/edit/realtime delivery, reconnect, errors/retry, dense charts and avatar loading/failure.

Programmatic API/WebSocket success and fixture resume tests are evidence at their respective layers; they do not establish signed-in chart gesture or repaint acceptance.

## Later physical-device pickup

Build from the accepted iOS source in a separate owner/Claude checkout with **traders_guild LinkedDev Profile / DevProfile** for optimized performance. A signed `iphoneos` build is required; none is available from this preparation. Configure `TG_LAN_HOST` to the Mac's current reachable private LAN address and port `30080` rather than using simulator loopback or assuming the checked-in address is current. Retain the isolated bundle/keychain/entitlements and opt-in experiment setting. The owner controls device installation and sign-in.

The later device gate covers normal/Setup creation, context and chart manipulation, branches, dense chart/avatar failures, keyboard/collapse, Dynamic Type, VoiceOver, Reduce Motion, themes and measured performance against the same-device baseline. Owner acceptance of the visual and interaction model is required. Notifications/deep links/sharing and released-client runtime handling need their actual-client checks; an isolated DEV build drops production associated domains and does not prove production link behavior.

## Claude Tuesday handover

Use accepted integration `ec65f6f` as the functional starting point, plus this documentation-only pickup commit. Work in a separate tree; preserve existing Claude work and do not reset another checkout. Sol holds its current tree. The obsolete wizard/WIP in `marker-sheet-sol` is superseded.

Tuesday scope: visual polish, compact summaries, spacing/chrome, retained sheet interaction, themes, Dynamic Type, VoiceOver traversal and visual evidence against the final plan. Keep two creation entries, social Details → optional Context → Review, one Setup Details surface, and internal same-sheet editors. Preserve exact-ID context edits, raw payload/order handling, selected-only Cancel, numeric/chart synchronization, IME protection, resume state, saved Setup/lifecycle locks and explicit conversion confirmation. No new taxonomy, workflow step or backend contract is authorized by this pickup.

Use the native captures in `docs/visual-review/v1.5-final-workspace/functional-small/` and `level-handoff/` as functional references. Capture final visuals from Claude's exact source/device/configuration; do not describe existing fixture images as signed-in or final owner acceptance. Rerun only checks affected by subsequent changes.

## Final-plan acceptance matrix

Numbers refer to section 37 of the canonical final handover.

| Criteria | Established baseline | Remaining gate |
| --- | --- | --- |
| 1: exactly two creation entries | Implemented; prior native checks | Owner interaction/visual acceptance |
| 2–3: avatar-led chart and technical Setup | Existing gated implementation | Signed-in/dense chart and Claude visual review |
| 4–6, 9–10: social posts, optional Context, concise editable Review | Fixture/model and local API evidence | Actual signed-in create/edit/failure journey |
| 7–8: internal persistent workspace, collapse/resume | Model/native checks, including exact saved-level handoff | Live chart handles with retained sheet/editor state |
| 11: response relationships | Existing local create/read/conversion evidence | Branch UI/navigation and actual realtime repaint |
| 12: Setup lifecycle/tracking | Saved fixture locks; local natural ARMED→ACTIVE, replacement refusal and note-only save | Actual saved Setup UI; terminal-state/runtime acceptance |
| 13: existing 1.4.1 functionality | Related client regressions; original paths/contracts retained | Wider actual-client regression review |
| 14: Android/released-client compatibility | Declared typed contracts retained; normalization audit completed | Released-client runtime checks and bounded historical production-key inventory |
| 15: notifications/deep links | Unchanged by this follow-up | Real-client notification/link/sharing checks |
| 16–17: performance/accessibility | Latest optimized compilation; existing Reduce Motion support | Same-device measurements and Claude/owner accessibility acceptance |
| 18: production data strategy | Retain historical data; no reset authorized | Astra's explicit promotion/data decision and read-only inventory |
| 19–20: release candidate and rollback | Exact functional source/builds recorded | Known approved RC, experiment promotion/removal plan, rollback plan |

## Completed backend audit and promotion follow-up

Authoritative read-only audit: sanctuary `docs/v1_5_sheet_ux_review/FINAL_BACKEND_PAYLOAD_REVIEW.md` (4 October 2026). Unknown payload-key stripping is pre-existing typed normalization; no evidence shows current v1.5 relies on such extras. It is not an evidenced v1.5 release blocker. Retain the typed contract; neither blanket JSON passthrough nor merging duplicate components by type/order is justified.

Before promotion, Astra owns a bounded read-only production component-type/payload-key inventory against declared models, including historical clients/migrations. Any required historical field needs an explicit reviewed compatibility solution. No production inventory or operation is assigned to Sol here. This audit does not complete released iOS/Android runtime compatibility.

See `V1_5_FINAL_PHASE_B_LOCAL_CHECKPOINT.md` for historical API/lifecycle evidence and `V1_5_FINAL_LEVEL_HANDOFF_CHECKPOINT.md` for the accepted 55-model/one-native handoff results. No broad test rerun, new product work, credentials, device operation, installation, backend change or deployment occurred in this preparation. Hold for the manual session gate.
