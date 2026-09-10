# iOS 1.3.0 Linked Markers — Claude implementation handover

Branch: `claude/1.3.0-marker-visuals`
Worktree: `.worktrees/linked-markers-claude`
Base: iOS `74c772c` (1.2.1 build 22) + DEV prerequisite `321e02d`
Version: **1.3.0 build 23** (`f36340f`)

Status: **buildable and verified against the live DEV backend**, with the
outstanding items named under *Not done* rather than folded into "complete".

Codex integration checkpoint: Claude commits through `1c8fe8c` are integrated.
`120b972` additionally clips focus hit testing to the rendered plot and shares
paint priority with drawing; the integrated unit suite passes **572/572** with
no skips. Saved screenshots and independent evidence notes are in
`docs/visual-review/live-simulator-2026-09-10/`. Physical testing is deferred
while the owner is away. Codex previously installed the isolated baseline app
only; the historical "nothing installed" statements below describe Claude's
own earlier stage, not the current device state.

Latest full run — `traders_guild Local Gateway`, 2026-09-10, counted with
`xcresulttool get test-results summary` rather than by grepping the log:
**604 passed, 5 skipped, 0 failed, 609 total**. The five skips are the
pre-existing credential-dependent auth and guild-picker UI cases, unrelated to
this feature. `ChartPanPerformanceDriver` **ran and passed** in this run, against
the prepared isolated app — the first end-to-end proof the corrected harness
drives a real chart rather than reporting success on a login screen. 0 warnings
in linked-marker files. The isolated `traders_guild LinkedDev Profile` /
`DevProfile` scheme also builds for test, and `Release` builds clean.

Visuals reviewed against a DEBUG fixture harness, against real backend data,
and — for the deep thesis — driven through the real UI (see *Live acceptance*).

---

## Passes so far

1. **Implementation** — the feature, against the 1.3.0 contract.
2. **Review pass** — five independent-review findings; privacy/moderation
   wiring; the DEBUG fixture harness and its visual review.
3. **Self-audit** — five defects found by auditing my own code.
4. **Compatibility** — four released/submitted baselines built and tested
   against the real backend fixtures.
5. **Integration repairs + live E2E** — ten queued findings, microsecond-exact
   revisions, and end-to-end verification against the local DEV backend, which
   itself surfaced a bug that disabled the whole feature.

---

## Live backend verification (2026-09-09)

Run against the local DEV gateway with the two QA accounts.

| Check | Result |
|---|---|
| Create response | `parent_direct_response_count` and `parent_responses_revision` **top-level**, advancing 3 → 4 → 5 |
| Delete response | All six added fields beside the original `detail`, decrementing 4 → 3 → 2 |
| Tombstones excluded from totals | `nodes=7, total_count=3` — matches `activeLoadedCount` exactly |
| `total_count` nullability | Arrives `null` the moment a branch cursor exists |
| Badges on chart | Real `direct_response_count` values; root's "5" matched the API |
| Focus on chart | Root ring, relationship rings, routed connectors, unrelated markers dimmed |
| **Cursor provenance** | Issuing marker → **200**; different marker → **409**; different viewer → **409** |

The cursor result is the important one. `marker_links._decode_cursor` validates
the cursor's embedded `requested` marker, the viewer, and a guild epoch, so
without `MarkerThreadCursor.issuedFor` every "More responses" tap after
navigating within a thesis would have failed. Cursors also carry a one-hour TTL
server-side; that expiry surfaces as the same 409 and recovers the same way.

**Bug found only by running it.** `chartViewModel.markerManager` is a weak,
non-published var, so a view observing app state cannot know when it appears.
The ordinary startup order is that runtime flags arrive while it is still nil —
so the capability was dropped silently and never re-applied, and focus never
activated. The symptom was deceptive: response badges are not capability-gated,
so they rendered real counts and the feature looked half-alive while rings,
connectors and dimming were all missing. Capability and thesis store are now
assigned in `handleOnAppear` alongside the manager itself.

---

## What is here

56 commits, each buildable:

| Commit | Contents |
|---|---|
| `5d017b1` | Pure link topology, thread window and connector geometry |
| `a3efeb2` | Link wire contract, thread store and placement session |
| `6a5c0bd` | Cover link topology, thread merging and curve routing |
| `e0a242f` | Thesis focus rendering, rings, badge and connectors |
| `03e4249` | Carry the link through placement |
| `4fef5a5` | Respond action, relationship row and thesis disclosure |
| `0d9bf48` | Placement banner, response notification, focus exit |
| `1cac77d` | Cache lifecycle, link session, counts and wire compat |
| `2fd4830` | Make Reduce Motion and badge geometry testable rules |
| `07a7df3` | Restore selection after reload, invalidate on reconnect |
| `08b7652` | Sibling order, cursor retirement, failure classification |
| `a0b720a` | DEBUG fixture harness, and two defects it exposed |
| `66d413f` | Record the review pass, privacy wiring and visual review |
| `267661a` | Converging thesis windows, lagging counts, stale navigation |
| `97434a2` | Record the self-audit pass |
| `0155db1` | List the new test files and the debug-only harness |
| `74f9569` | Microsecond-exact revisions, and a revision-aware list merge |
| `32d8267` | Export the fixture visual review as files |
| `901856d` | Cursor provenance, guarded mutations, and lifecycle repairs |
| `f04240e` | Malformed revision inputs must not trap |
| `4a8d827` | Wire the link capability where the manager actually exists |
| `9515002` | Pin cursor provenance against verified backend behaviour |
| `a90aba0` | Bring the handover current |
| `ffacc66` | Keep the fade rule off the pan path, and per selection |
| `e288398` | Device profiling plan, isolation first |
| `6f45f56` | Assert instead of skipping, and correct the commit table |
| `ce82cc2` | Record the compat suites' fixture dependency |
| `e2ebddd` | Close the commit table honestly |
| `8e462bb` | Isolated device DEV and profiling configuration |
| `7beffb0` | The queued integration-review findings |
| `382bbda` | Make the isolated build fail closed and reachable |
| `bb770df` | Wire the realtime repairs into the handlers that need them |
| `f1f5191` | Deterministic chart-pan driver for device profiling |
| `79cf2aa` | Record live acceptance, exact counts and artifact paths |
| `404875c` | Invalidate a marker event in one pass |
| `f7d3e97` | Audit what VoiceOver reaches in the linked-marker surfaces |
| `267df44` | Say exactly how far the VoiceOver check goes |
| `32afe63` | Record the chart-service cursor defect blocking the wide walk |
| `8915e92` | Make the pan driver measure the prepared app, not a relaunch |
| `9e1a1c1` | Invalidate on the viewer's own writes, and sweep by completeness |
| `2504734` | Reconcile counts and document the profiling harness |
| `bac0b07` | Percent-encode cursors placed in a query string |
| `79b6f94` | Record the wide-thesis walk and both cursor defects |
| `2bcd290` | Default the isolated gateway host per SDK |
| `7d654c0` | Count a member visible only if its disc is in the plot |
| `cab887c` | Resolve focus-mode taps against the geometry that was painted |
| `71b2461` | Hoist per-frame symbol, text and theme work out of the glyph loop |
| `57f7067` | Keep build-configuration files out of the app bundle |
| `4f96dbf` | Cover an author's own write reaching an open disclosure |
| `1c8fe8c` | Record the simulator profiling, and what it could not measure |
| `aba1f14` | Clip focus hit targets to the rendered plot |
| `2437e80` | Prepare version 1.3.0 build 23 |
| `7095534` | A focus miss must still exit, including below the plot |
| `2cc3c32` | Record the two-member acceptance, and correct the spine claim |
| `fdf28a0` | Keep a thesis reachable after its only response is deleted |
| `31da3ca` | Give deletion a reachable action and an honest failure |

The branch starts at `74c772c` (iOS 1.2.1 build 22). `321e02d`, the commit
immediately after it, is yours — the isolated local-development schemes — and is
excluded here. A final documentation commit updates this table and so cannot
appear in it; `git log --oneline 74c772c..HEAD` is the authority.

### New files (all auto-join the target — the project uses synchronized groups)

**Pure, no SwiftUI or networking — the intended test seams**
- `Models/MarkerLink/MarkerLinkRelationship.swift` — the three relationships plus
  `MarkerLinkRelationshipValue`, the tolerant wrapper for unknown server values
- `Models/MarkerLink/MarkerThreadDTOs.swift` — preview / thread / delete wire types
- `Models/MarkerLink/MarkerThreadWindow.swift` — progressive page merging
- `Models/MarkerLink/MarkerLinkSession.swift` — placement link lifecycle
- `Models/MarkerLink/MarkerResponseCountReconciler.swift` — monotonic counts
- `TradingChart/services/MarkerLinkGraph.swift` — synchronous connected component
- `TradingChart/overlays/MarkerLinkGeometry.swift` — collision-checked routing

**Integration**
- `TradingChart/overlays/MarkerLinkRenderer.swift` — rings, badge, connectors, reveal policy
- `TradingChart/overlays/MarkerManager+Links.swift` — focus, counts, thread paging
- `Features/Shared/Marker/MarkerThreadStore.swift` — cache above chart layout
- `Features/Shared/Marker/MarkerLinkViews.swift` — picker, relationship row, thread row, banner, capability observer
- `Features/Shared/Marker/MarkerThesisDisclosure.swift` — lazy thread loader + disclosure

**Debug-only** (excluded from Release, proven by binary inspection)
- `Features/Shared/Marker/MarkerLinkFixtureGallery.swift` — visual harness

**Tests** — `MarkerLinkGraphTests`, `MarkerLinkGeometryTests`, `MarkerThreadWindowTests`,
`MarkerLinkStateTests`, `MarkerLinkDecodingTests`, `MarkerLinkRenderTests`,
`MarkerLinkReviewFixTests` (independent-review findings),
`MarkerLinkSelfAuditTests` (self-audit findings),
`MarkerRevisionPrecisionTests`, `MarkerLinkIntegrationRepairTests`,
`MarkerThreadLoaderCallSiteTests`.

Plus `Models/MarkerLink/MarkerRevision.swift` — microsecond-exact revision
ordering, because no Foundation date type can carry these.

---

## Contract conformance

Every field from the 1.3.0 Backend / iOS interface is implemented as specified:
create pairing via `RLCreateMarkerRequest.withLink(_:)`, the seven marker fields
all optional, `node_key`-keyed merging, depth rebased by `parent_key`, ancestry
and branch cursors, `total_count` nullable and never inferred from a page,
tombstones carrying structure only, `linked_markers_enabled` defaulting off, and
`marker_response` mapped to the existing engagement preference.

Three decisions worth flagging to Codex because they are judgement calls, not
transcriptions:

1. **`RLRuntimeFlagsDTO` already existed** (`RLCoreDTOs.swift:1958`) with beta and
   awards flags, fetched by `RLAppState.refreshRuntimeFlags()` and reset on
   logout. `linkedMarkersEnabled` was added to it rather than creating a second
   capability type, so it inherits all of that plumbing.

2. **`deleteMarker` now returns `RLMarkerDeleteResponseDTO`** instead of
   `RLDetailResponseDTO`. The new type still carries `detail`. There was one
   production call site, which discarded the result.

3. **Counts survive a symbol or timeframe change; only a guild change clears
   them.** They are absolute and keyed by marker id, so a cached list payload
   must not roll a badge backwards on return.

---

## Deviations and why

**A straight-line clearance test would have broken the default flow.** The first
routing pass rejected any edge whose glyph discs overlapped on the chord. A
selected marker draws at 1.5 scale (radius 27), so it overlaps a stack neighbour
40pt away — meaning the flagship curve would have silently disappeared for the
most common case. Routing now decides on the *trimmed drawn span* along the
curve (`minimumDrawnSpan`, 10pt), which is the honest test.
Pinned by `adjacentStackPairStillRoutesAtSelectionScale`.

**Three call sites had to be extracted into named members** — `MainView`'s two
modifier chains and the `ChartBottomSheet` construction were already at the Swift
type-checker's practical limit, and adding one callback tipped each over
("unable to type-check this expression in reasonable time"). Hence
`MarkerLinkCapabilityObserver` (a ViewModifier bundling two observations),
`MainView.chartBottomSheet`, and driving the reveal from the existing selection
`onChange` rather than its own. No behaviour changed; this is purely structural,
but it is the reason those diffs touch more lines than the feature needs.

---

## Independent review findings — all five acted on

| # | Finding | Resolution |
|---|---|---|
| 1 | `expandBranch` retired the cursor on **any** error, losing every remaining response under a node when offline / 503 / 429 | `MarkerThreadRequestFailure.classify` splits transient / staleCursor / gone / unavailable. Transient keeps the cursor and the button becomes a live retry; a stale cursor force-reloads the thread; only 404/410 retires |
| 2 | Branch/ancestry tasks were untracked and lacked a marker-identity check, so a stale page or error could mutate another selection | All requests tracked and cancelled on marker change; every completion re-checks marker identity **and** generation; the generation check moved *into* `MarkerThreadStore.ingest` so no caller can omit it |
| 3 | Append-only merge reversed sibling chronology on the deep-link path | Pages are spliced with `anchoredMerge`, which preserves both orderings using shared keys as anchors and files non-overlapping incoming keys ahead. Tombstones have no `createdAt`, so server sequence is the only authority |
| 4 | Cursor retirement compared `directResponseCount` to loaded child count — counts exclude deleted children while rows include tombstones, so the cursor lived forever | Retirement now follows **consumed-branch identity**: spend a cursor, and absence of a replacement for that anchor means exhausted |
| 5 | Capability disabled then re-enabled reopened a stale cached thread | A capability flip calls `invalidateAll(reason: .capabilityChanged)` |

Contract clarification applied: `parent_direct_response_count` /
`parent_responses_revision` are read as **top-level** fields on create HTTP,
create event, delete HTTP and delete event. The "at least" floor counts
`activeLoadedCount` (tombstones excluded), and a complete window with no
server-supplied total still reports a floor rather than promoting its row count.

## Privacy, moderation and membership invalidation

| Trigger | Reason | Where |
|---|---|---|
| Block / unblock a member | `.privacyChanged` | `RLAppState.blockUser` / `unblockUser` |
| Report content or a member | `.moderation` | `markReportedContent` / `markReportedUser` |
| Role change, mute, suspend | `.moderation` | `setupGuildEventListeners` |
| Leave a guild; guild deleted | `.membershipLost` | `leaveCurrentGuild`; guild-deleted event |
| Guild or account change | `.scopeChanged` | `MarkerThreadStore.activate` |
| Websocket reconnect | `.reconnect` | `MarkerManager.configureRealTime` |
| Capability flip | `.capabilityChanged` | `MarkerLinkCapabilityObserver` |
| Logout | `.logout` | `RLAppState` reset |
| Marker deleted | per-thesis | `handleMarkerDeleted` |

Windows are **dropped, not filtered**. A cached tombstone carries no author
identity by design, so the cache cannot be filtered against a blocklist safely
— which makes dropping the only correct response to a privacy change.

## Visual review — fixture harness

`MarkerLinkFixtureGallery`, reached with `-MarkerLinkFixtures`, drives the real
`ChartMarkerSystem.drawMarkers` and the real linked-detail views against
synthetic markers laid out by the real `MarkerPositionCalculator`. No backend, no
auth, no network. Verified absent from Release: 9 references in the Debug dylib,
**0 in the 107MB Release binary**.

Reviewed on iPhone 16 Pro and iPhone SE (3rd gen):

| Case | Result |
|---|---|
| Parent → unrelated → response, one candle | **Correct.** The green `supports` connector curves around the faded stranger, never through it; the grey stack spine below stays untinted |
| All three relationships | Colour, ring and dash pattern all distinguishable; `[5,3]` / `[2,3]` / `[7,3,2,3]` read as different lines |
| Dense chart (19 markers, 8-response thesis) | Holds after the ring fix; three stacked connectors compress into a bundle, which is inherent to same-candle stacking — the thread list carries the detail |
| Light-grey theme | Rings and connectors clearly visible |
| iPhone SE (375pt) | Layout and chart hold; rows full-width and legible |
| Dynamic Type (accessibility-XL) | Rows reflow to a column; chips scale; tombstone keeps structure and relationship with no identity |
| Reduce Motion | Connector at full length on first paint — focus appears, it just does not animate |
| Count honesty | Window of 5 nodes incl. 1 tombstone with a live branch cursor renders **"4+"** — tombstone excluded, "+" retained |

**Two defects found by looking, not by testing** (both fixed in `a0b720a`):
rings drawn outside the glass edge made a focused stack read as one continuous
tube at 40pt spacing; and the thesis row's chip/count used fixed 10pt type that
ignored Dynamic Type entirely.

**One finding reported, not changed:** at 0.22 on the **light-grey** theme,
unrelated markers are not merely recessive — they are close to invisible, and a
faded like badge reads as a colour smudge. 0.22 is a locked decision so it was
implemented as specified; the recommendation is a theme-aware floor of roughly
0.35 for `lightGrey` only. Owner's call.

## Self-audit pass — five further defects found and fixed

Found by auditing my own implementation rather than working from the contract,
so none of these were in Codex's review either.

| Defect | Failure it caused |
|---|---|
| **Converging thesis windows clobbered each other** | A thesis opened from two different responses makes two provisional windows that later resolve the same root. Promotion wrote straight to the confirmed key, so the second arrival replaced the first — discarding its pages and its **live branch cursors**, making a branch the reader had started paging silently unreachable. Fixed: destination key resolved before the window is built, and `MarkerThreadWindow.absorb` folds them together |
| **Cursor collision during absorb** | Two windows can hold different cursors for one node. Absorb keeps the **less advanced** one: a redundant page dedupes harmlessly, an over-advanced one skips siblings permanently |
| **Focus trusted a lagging count** | The gate read `directResponseCount`, which lags by design — the reconciler exists because of it — so a stale zero suppressed focus on a marker whose responses were already on screen. Loaded topology now counts too |
| **Pending navigation could hijack a later selection** | A target that never loaded was re-staged on every attempt, renewing itself indefinitely, so a marker appearing minutes later could yank the selection. Now expires 30s from the *original* tap; re-staging preserves that instant |
| **Stale-cursor recovery left a dead button** | On 409 I reloaded the thread, but an initial page spends no cursor and therefore cannot retire one, so the dead cursor survived and left a "More responses" button that could never succeed. The cursor is now dropped first; a fresh page restores it if the branch is still live |

Also removed `linkRingStyle` and `isDimmedByLinkFocus` — dead duplicates of
decisions the renderer already derives from `MarkerLinkRenderContext` — and the
loader's unused `reset()`, since a capability flip already re-mounts the
disclosure and the generation check forces a re-read.

## Verification performed

- **Clean Debug build**, iOS Simulator (iPhone 16 Pro, iOS 18.2), scheme
  `traders_guild Compose Dev`.
- **Full unit suite: 481 passing, 0 failures.** No pre-existing test changed
  behaviour; two test fakes gained the new `MarkerAPIClient` members. One of my
  own earlier tests was corrected: it encoded the count-based cursor-retirement
  rule that review showed to be wrong.
- **Clean Release build**, with the fixture harness proven absent from the
  binary.
- **App installs and launches** to the sign-in screen without crashing.

The tests the owner asked for, and where they live:

| Requirement | Test |
|---|---|
| Parent-unrelated-response same-candle stack | `MarkerLinkGeometryTests.sameCandleStackRoutesAroundAnUnrelatedMarker` |
| Collision-free true curves | same, plus `avoidsEndpointBadges`, `staysWithinThePlotRect`, `omitsEdgeWhenNoSafeRouteExists` |
| Post-nudge hit positions | `routesFollowPostNudgePositions` |
| Cross-timeframe retained thread | `MarkerLinkStateTests.threadSurvivesTimeframeChange` |
| Out-of-order counts before timeframe filter | `outOfOrderCountsAreRejected` + the call ordering in `handleMarkerCreated` |
| Unknown DTO values | `toleratesAnUnknownRelationship`, `preThirteenMarkerPayloadStillDecodes` |
| Failed drafts | `failedSubmissionKeepsTheDraft` |
| Reduce Motion | `MarkerLinkRenderTests.reduceMotionSnapsInsteadOfHidingFocus` |

---

## Known gaps — not done, do not assume otherwise

1. **Fixture visual verification is not backend E2E.** The harness renders the
   real drawing and detail code against synthetic data, which covers layout,
   colour, contrast, type and reflow. It does **not** cover: a real
   create→notify→realtime round trip, server-authored `node_key` shapes, real
   cursor pagination against a live thread, actual block enforcement on reads,
   or the cross-timeframe jump against real history paging. Those need Codex's
   backend and two accounts.
2. **VoiceOver not driven.** Labels, traits and hints are set on every linked
   view and relationship is always spoken rather than carried by colour, but I
   did not run VoiceOver and step the rotor. Chart glyphs remain Canvas pixels
   with no accessibility elements — unchanged from 1.2.1 — which is why the
   thesis list is the accessible path and must stay reachable without focus mode.
3. **No physical-device Instruments run.** Connector routing is
   O(edges × samples) per frame with a 12-edge cap; membership is computed on
   selection change, not per frame. The simulator sampling above measured both
   and found them small (86 and 149 samples), but that is diagnostic and cannot
   satisfy the ≤5% gate. The 57 fps figure from the gesture-perf work is context
   from another build on other hardware, not a baseline — see
   `docs/DEVICE_PROFILING_PLAN.md` for the matched-pair method that replaces it.
   Note also that Instruments' Time Profiler could not be driven against a
   simulator process at all here; on device it should work normally.
4. **Reduce Motion cannot be toggled by `simctl`.** I set it via the
   accessibility defaults and the connector renders at full length on first
   paint, which together with `reduceMotionSnapsInsteadOfHidingFocus` is good
   evidence — but a still screenshot cannot prove the *absence* of an animation.
5. **Bilateral blocks initiated by the other party** have no client event. This
   viewer learns of them on refetch, so the thesis cache is protected by
   reconnect and moderation invalidation rather than by a dedicated signal. If
   the backend gains a "blocked by" event, wire it to `.privacyChanged`.
6. **Discord relation copy** (generic sentence only) is backend-side; nothing on
   iOS was changed for it, and public share cards are untouched as specified.
7. **Android** untouched, as instructed.
8. **Suppressed connectors leave the stack spine grey — by design, not a gap.**
   In a tight stack the router can find no obstacle-free bow on either side at
   any magnitude, and correctly declines rather than drawing a line across other
   glyphs; the same happens below the 24pt chord minimum. The result is a pair of
   ringed markers with a plain grey stack line between them (screenshot `11`).

   The approved plan is explicit that the shared stack spine is **never**
   recoloured, and that an unsafe dedicated curve is simply omitted, with the
   badge and the thread list carrying navigation instead. Relationship remains
   redundantly encoded by the ring, the badge and the row text, so nothing is
   lost for colour-blind readers.

   Recorded here because an earlier draft of this document called it a missing
   fallback, quoting the superseded original plan. It is not; no design decision
   is outstanding.

---

## One finding that is not about linked markers

The app target's sources are in a file-system synchronized group, and that group
copies every non-source file it finds into the bundle. Before this branch the
shipped app already contained `Debug-StagingK8s.xcconfig` — a build-configuration
file naming a staging gateway, sitting inside the production `.app`. The isolated
DEV work added three more xcconfigs and an `Info-LinkedDev.plist` beside it, and
Xcode began warning about the plist because a second Info.plist in Copy Bundle
Resources is a validation hazard.

`57f7067` adds a membership exception for those five files. Nothing reads them at
runtime, so the change is inert; it is recorded here because it alters what the
**production** artifact contains, which is not something a linked-markers branch
would normally touch. Verified from the built products: DevProfile and Release
bundles now hold no xcconfig and no stray plist, and Release still builds as
`co.tradersguild.app` / "Traders Guild".

---

## Notes for integration

- Nothing in this branch calls production. No pushes, no deploys.
- The feature is dark by default: with `linked_markers_enabled` false the chart
  renders exactly as 1.2.1 — no rings, no connectors, no badge, no respond
  action — while existing links still decode and display as ordinary markers.
- `MarkerManager.linkFocus` is derived state; assign it only from
  `refreshLinkFocus()`.
- The fade decision is latched per selection so progressive pages cannot flicker
  the dim on and off — but the latch is **subordinate to the visibility rule**,
  not a substitute for it. "Suppress the fade below two visible members" is an
  invariant: `reportRenderedMarkers` drops the latch whenever the painted member
  set changes, and `refreshLinkFocus` floors any latched decision by the current
  threshold, so panning a second member off screen undims and panning it back
  re-dims. The latch protects against topology churn between paints; a filter
  change clears it outright. Deferred renderer reports carry their selection id,
  because the report is dispatched from inside a draw pass and the selection can
  move before it lands.


---

## Test counts and evidence paths

Recorded exactly, from the run that produced them.

| | |
|---|---|
| Full suite | **604 passed, 5 skipped, 0 failed, 609 total** — `xcresulttool get test-results summary` |
| Full-suite result bundle | `scratchpad/full11.xcresult` (log: `scratchpad/full11.log`) |
| Unit target alone | 596 passed, 0 failed, 0 skipped — `scratchpad/lc-units.xcresult` |
| Two-member acceptance evidence | `scratchpad/acceptance/` — `A01`–`A16`, `B01`–`B11` |
| Earlier full-suite bundles | `scratchpad/full9.xcresult` (577/5/582), `scratchpad/full7.log` (574/5/579) |
| Wide-thesis UI walk console | `scratchpad/z.txt` |
| Device build log | `scratchpad/b-iso.log` (`** BUILD SUCCEEDED **`) |
| Simulator build log | `scratchpad/b-normal.log` |
| Live HTTP ancestry probe | `scratchpad/live-ancestry.json` |
| App console during the UI walk | `scratchpad/console2.txt` |
| UI walk screenshots | `scratchpad/w3.png` … `w8.png` |

Scratchpad root:
`/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/db687bc5-c94e-4a2a-bb97-65e63897681e/scratchpad/`

Signed device artifact (built, **not installed**):
`<scratchpad>/dd-device/Build/Products/DevProfile-iphoneos/traders_guild.app`
with `traders_guild.app.dSYM` beside it.

These are session-scoped temp paths — treat them as provenance for this
report, not as durable locations.

---

## Live acceptance — deep/wide fixture

Driven in the simulator against the owner's seeded fixture
(`/tmp/linked-navigation-fixture.json`: an 81-node chain including one deleted
intermediate, and a 226-node wide thesis), signed in as the disposable QA
account, routed to the local gateway. No production endpoint was contacted.

**Ancestry, three windows, in the UI.** Opening the Thesis disclosure on the
deep leaf (`QA Deep Thesis Step 80`, a linked leaf with zero responses) issued
`GET /chart/markers/{leaf}/thread`, then two more carrying Fernet cursors:

| Page | Header | Rows begin at | "Load earlier responses" |
|---|---|---|---|
| initial | `32+ in this thesis` | Step 49 | shown |
| +1 | `62+ in this thesis` | Step 18 | shown |
| +2 | `80+ in this thesis` | **QA Deep Thesis Root** | **gone** |

The affordance retires exactly when the root resolves. This matches the HTTP
behaviour measured directly against the backend the same day — 32 + 32 + 19
nodes, `root_resolved` only on the third, one tombstone in the second window —
so the client's paging agrees with the server's own windowing.

**The header fix, visible.** At the first page the tally read
`11 supports · 10 challenges · 11 builds on`, which sums to exactly 32. Before
this change the tally *replaced* the count, so an 81-node thesis would have
presented "32" as though it were the whole of it. The count now always shows,
carries its `+`, and the breakdown sits beneath it.

**Badges on the chart.** Relationship-coloured left badges render in the resting
state, and a linked leaf shows the relationship **glyph** rather than a count —
the case that previously rendered nothing at all, leaving a response
indistinguishable from an ordinary marker until tapped.

**Cross-timeframe.** Tapping the root (1h) from the 4h chart switched the chart
to 1h and carried the selection across.

### Wide thesis — branch continuation, walked in the UI

Selected `QA Wide Response 010` ("Builds on Alex Link QA's QA Wide Thesis
Root") from the dense 1h stack and expanded the disclosure. One tap on
**"⊕ More responses"**:

| | before the tap | after |
|---|---|---|
| Header | `2+ in this thesis` | **`200+ in this thesis`** |
| Tally | `1 builds on` | **`66 supports · 66 challenges · 67 builds on`** |
| Rows | root + the selected marker | root + Responses 001, 002, … |
| Footer | `Showing part of this thesis` | still shown — 226 nodes, 200 loaded |

The request was
`GET /chart/markers/CA88CBA9…/thread?cursor=gAAAAABqolLmk-Dl…` — a Fernet
cursor replayed against the **issuing** marker rather than the selected one.
Cursor provenance holding in the real UI, not only in the spy tests.

The root row shows `225` while the header reads `200+`: the count is the
window's, the root's own badge is its direct-response total, and neither is
silently rounded into the other.

**And the header fix earning its keep on the case it was written for.** The
tally sums to 199. Had it still replaced the count, a 226-node thesis would
have presented "199" as though that were the whole of it.

### Focus mode on real dense data

With ~100 markers loaded on 1h, selecting a linked marker produced the
flagship visual against genuinely cluttered data:

- a **teal** ring on the selected builds-on marker, **green** on a supports
  member, **red** on a challenges member — relationship carried by ring colour
  *and* by the dash pattern and badge, never by hue alone
- a long **curved dashed teal connector** between them, the quadratic Bézier
  rather than a straight trendline
- every unrelated marker visibly recessed at 0.22, candles untouched
- the clutter guards visible: connectors reach the parent and direct children
  only, not across all 226 nodes

Also confirmed live on this pass: the **`99+`** count badge (the >99 path),
leaf glyph badges in all three relationship colours across the dense stack, and
`Showing part of this thesis`.

Screenshots: `scratchpad/v1.png` (dense stack, `99+`), `v8.png` (focus mode,
three rings, connector, dimming), `u1c.png` / `u2c.png` (before and after the
branch continuation).

---

## Two cursor defects the wide-thesis walk uncovered — both now fixed

Marker-list pagination was broken from both ends. Neither had anything to do
with linked markers; both blocked this feature's acceptance, and both would
have hit any guild that outgrew a single page.

### 1. `chart-service` imported a package it never declared (backend — owner fixed)

```
File "/app/app/api/chart.py", line 2890, in get_markers
    from dateutil.parser import isoparse
ModuleNotFoundError: No module named 'dateutil'
```

Function-local at four sites — 2890 `get_markers`, 3040
`get_marker_activity`, 3927 `get_marker_comments`, 4684
`get_chart_chat_messages` — while `python-dateutil` was declared only in
`market-ingestion-service/requirements.txt`. Not deployment drift. It survived
because a function-local import fires only on the cursor path, and the *first*
page of any list carries no cursor, so everything looked healthy until a guild
grew past one page.

Fixed by the owner. All four cursor routes now verified.

### 2. iOS sent the cursor unencoded (client — fixed here, `bac0b07`)

After the backend fix the app still 500'd while direct HTTP succeeded. One
character apart:

| cursor spelling | result |
|---|---|
| `%2B00:00` | 200 |
| `+00:00` — what the app sent | **500** `ValueError: Unused components in ISO string` |
| `Z` | 200 |

`.urlQueryAllowed` permits `+`, and `+` in a query string means a space, so
`…415598+00:00` reached the service as `…415598 00:00`. Seven call sites
interpolated the cursor raw; two more used `.urlQueryAllowed`, which does not
help here. All now go through one `tgQueryEncoded` helper that escapes `+`
along with the query delimiters, while base64url and `Z`-spelled cursors pass
through byte-exact — opaque cursors are decrypted server-side and compared
against an embedded marker id, so they must not change.

**Why the thesis worked while the list did not.** Thread cursors are Fernet
tokens in base64url, an alphabet with `-` and `_` but no `+`. They were correct
by luck, not by encoding. That is exactly why ancestry paged cleanly in the UI
on the earlier pass while the marker list returned 500 on every page after the
first.

Verified end to end afterwards: three 1h marker pages, **all 200, zero
failures**, and the wide thesis rendered.

### A third condition, not a defect

The seeded fixture initially used timestamps beyond the DEV instance's retained
candle history, so markers loaded but rendered nothing —
`findCandleIndex` drops a marker whose candle is absent. Corrected by the owner
(backend `a639ef1`) by adding local synthetic coverage. Worth knowing because
the symptom — a 200 response and an empty chart — looks like a client bug and
is not.

---

## Simulator profiling — what it found, and its limits (2026-09-10)

Diagnostic only. Simulator numbers cannot satisfy the physical ≤5% gate; what
they can do is show *where* the main thread goes, and that turned out to be
worth doing.

### Instruments could not be used, and that is a real limitation

`xctrace record --template 'Time Profiler' --device <simulator udid> --attach
traders_guild` produces a trace containing nothing but an empty `RunIssues`
store — no data streams, and `xctrace export --toc` then fails with *Document
Missing Template Error*. Attaching on the host instead (`--attach 8028`, or by
name) is refused outright: the host device list does not include
simulator-hosted processes. Both were tried, bounded, before moving on.

`/usr/bin/sample` on the simulator app's host pid works, gives per-thread call
trees with sample counts, and is what every figure below comes from.

### Protocol

Optimised `DevProfile` build, the owner's seeded dense QA thesis on 1h, signed
in as the disposable QA account against the local gateway. Each pass: 30s of
sampling at 1 ms while eight identical `press-and-drag` pans run (four
out-and-back pairs, 270pt, 1.2s each, from the same starting viewport).

Two honest caveats. The pairs do **not** cancel — the viewport walks backwards
over the run, because forward pans clamp at the newest candle and backward ones
do not — so each pass covers progressively sparser data. And repeating a pass
moves the top-line figure by about ten percent. Both passes of any comparison
below start from the same viewport and run the same eight gestures, so they are
comparable to each other; none of them is a steady-state figure.

### What it found

`drawTopPriorityMarkers` held 2983 of the main thread's samples, and 1760 of
those were inside `drawResponseBadge` — not drawing it, *preparing* to draw it.
Three separate per-marker-per-frame costs, described in `71b2461`: a
`LocalizedStringKey` walk to render a number, an SF Symbol rebuilt from its name
for each of three distinct symbols, and a `UserDefaults` read behind every
`AppColors` access.

| Pass | `drawTopPriorityMarkers` | `drawMarkers` | badge prep | theme reads in the glyph loop |
|---|---|---|---|---|
| focus off, before | 2983 | 2279 | 1760 | 332 |
| focus off, after | 1546 | 973 | — | 246 |
| focus off, after both fixes | 1709 | — | — | **0** |
| focus on, after | 2543 | 1316 | — | — |

Read that as: the halving is real and outside the noise band; the theme-read
removal is exact where it is attributable (332 → 0 inside `drawSingleMarker`)
and invisible in the top-line figure, which is why both rows are shown. Focus
mode — which paints a second dimmed context, sorts a focus tier and routes
Bézier connectors — now costs less than the idle chart did before the fixes.

Within focus, the feature's own work is small: connector routing
(`MarkerLinkGeometry.route`) 86 samples, the extra glyph sort 149. The rest is
SwiftUI rasterising more glyph state, not link logic.

No recurring stall or hitch pattern appeared in any pass — no single frame's
work dominated, and nothing blocked the main thread on I/O.

Evidence: `scratchpad/perf-evidence/` — `focus-off.sample.txt` (before),
`focus-off-fixed.sample.txt`, `focus-off-pass.sample.txt`, `focus-on.sample.txt`,
and screenshots `01`–`12`.

---

## Dense thread walking — disclosure and selection (2026-09-10)

Driven in the UI on the owner's 81-node deep fixture, isolated DEV build,
local gateway.

- **Header policy holds after loading.** Expanded on *QA Deep Thesis Step 62*
  the header reads `32+ in this thesis` with `11 supports · 11 challenges ·
  10 builds on` beneath it — the whole-thesis partial count preserved, the
  relationship tally secondary, and the `+` refusing to imply the tally is the
  whole thesis. Screenshot `06`.
- **Tombstone in place.** The deleted intermediate renders as *Unavailable
  marker*, keeps its relationship chip, and the branch below it still reads.
  Screenshot `07`.
- **The current row follows selection**, highlighted from the loader's marker id
  rather than authorship — the highlighted row is *Step 62*, authored by the
  other QA account. Screenshot `08`.
- **Across a timeframe change.** Tapping the row for *Step 64*, which lives on
  4h, switched the chart to 4H, animated to the node and selected it, and left
  the disclosure **expanded** with the header recomputed (`34+`, `12 · 11 · 11`)
  and the retained window reused rather than discarded. The relationship row
  followed too, from *Supports … Step 61* to *Builds on … Step 63*. Screenshots
  `09`, `10`.
- **Focus correctly does not engage on 4h** for that node: its parent and child
  are 1h markers, absent from this chart, so there is no visible companion to
  compare against and the chart is not faded. Walking back to a 1h node
  re-engaged focus immediately, with rings in three relationship colours and the
  rest of the layer at 0.22. Screenshot `11`.
- **Author actions.** The Edit affordance appears on nodes this account authored
  and not on the other account's, and a linked marker offers no route back to
  private. Entering and cancelling edit restored the idle chart exactly —
  placement dim cleared, no selection, no residue (screenshot `12`).

  I did **not** perform a live update or delete: those mutate the fixture the
  owner is running acceptance against, and a soft delete would leave a permanent
  tombstone in one of their chains. The behaviour is covered instead by
  `4f96dbf`, which drives the same DTOs the update and delete paths hand to the
  invalidator and asserts an open disclosure re-reads and keeps its place.

---

## Codex commits reviewed and integrated

`120b972` (clipped-plot focus hit) and `f36340f` (1.3.0 build 23) were
cherry-picked and reviewed independently. The clipping is right and the paint
priority is now genuinely shared: `MarkerStackLayout.paintPriority` drives both
the renderer's `glyphQueue` and the hit test, and the added
`marker.id.uuidString` tiebreak matters, because `order` is per candle group and
two markers in different groups can collide on it — an unstable sort there would
make a dense tap non-deterministic.

One defect found and repaired in `7095534`: the clip was added as an early return
*in front of* the hit test, and the tap handler's miss branch sits after it, so a
tap in the x-axis reserved band stopped exiting focus. Detail in that commit; the
short version is that clipping belongs inside `findMarkerAtLocation`, which
already does it, and the view must ask before it decides.

I first reported this as affecting the price axis too. It does not: the 64pt
y-axis lane carries `yAxisGestureOverlay`, applied *after* this gesture, so taps
there never reach the marker layer either way. Only the band below the plot
changed behaviour.

`f36340f` needed no repair. Verified from built products that Release still
produces `co.tradersguild.app` / "Traders Guild" at 1.3.0 (23), and that the
bundle-contents exception from `57f7067` survived the cherry-pick.

---

## Two-member update/delete acceptance (2026-09-10)

Run on a **new disposable thesis**, deliberately separate from the deep/wide
performance fixture, which was left untouched. Two simulators, two accounts:
iPhone 17 Pro as *Alex Link QA* (guild ADMIN) and iPhone 17 as *Sam Link QA*
(MEMBER), both on the isolated `co.tradersguild.app.linkeddev` DevProfile build,
1.3.0 build 23, routed to the local gateway.

The thesis, all `question` intent on BTC/USD:

| | marker | author | timeframe | relationship |
|---|---|---|---|---|
| R | QA Accept Root | Alex | 1h @ Sep 10 05:00Z | — |
| C | QA Accept Response | Sam | 1h | supports R |
| G | QA Accept Grandchild | Alex | **4h** | builds on C |
| C2 | QA Accept Cross-TF Reply | Sam | **4h** | challenges R |

### What was driven through the UI

* **Respond-with-marker, end to end.** Sam opened R, tapped *Respond with
  marker*, chose *Supports* from the three-way picker, and the placement session
  came up carrying the link: a banner reading *"Supports linkqad1f509e30's QA
  Accept Root — Shared with the guild"* with **Change** and **✕** controls, the
  parent's candle seeded, price left at the viewport default so the two glyphs
  separate, and visibility locked to guild. Submitted, and the post-placement
  share sheet was dismissed with *Not now* — nothing left this machine.
  (`B03`–`B05`)
* **Badge policy on real data.** With R and C stacked on the same candle, R wears
  a **neutral grey `1`** and C a **green `1`** — root count neutral, linked count
  in its own relationship colour, one badge each, likes still on the right.
  (`A07`)
* **Author edit.** Sam edited C's note through the edit flow and submitted; the
  edit sheet correctly showed **no link banner**, since the relationship is
  immutable and `buildUpdateRequest` ignores link context. (`B07`–`B09`)
* **Permissions.** Sam sees *Edit* on C and not on R; Alex sees *Edit* on R and
  not on C, and no route back to private on a linked marker.
* **Cross-timeframe walking.** From C, Sam's disclosure showed all three nodes
  with the header recomputed to *"3+ in this thesis — 1 supports · 1 builds on"*
  and the grandchild indented two levels. (`B10`)
* **Inbox navigation, cross-timeframe.** Alex's guild Notifications list carries
  *"Sam Link QA responded to your marker — A new challenges response on
  BTC/USD."* Opening it switched the chart **1H → 4H**, animated to Sep 10 05:00
  and selected C2, which wears the red *challenges* badge. Focus correctly did
  not engage: C2's parent is on 1h and absent from this chart. (`A15`, `A16`)

### Refresh while a disclosure is open

Alex held R's thesis disclosure open throughout. When Sam retitled C, **Alex's
open disclosure updated in place with no interaction**: the row text changed from
*Question* to *QA Accept Response (title e…*, while the root row stayed
highlighted and the header stayed put. That is the assigned check —
edit-while-open refreshes and preserves selection — verified across two clients.
(`A08` → `A10`)

### Delete of the intermediate

C was soft-deleted by its author. On **Alex's client**, which had C selected, the
websocket event closed the marker sheet and cleared the selection, removed C from
the canvas, and dropped R's badge to no count — `direct_response_count` 1 → 0,
live. (`A12`, `A13`) On **Sam's client**, after refetch, G's detail shows the
parent row as *"Builds on an unavailable marker — The marker this answers isn't
available to you"*, greyed and not tappable, and the thread renders root →
**Unavailable marker** (keeping its *Supports 1* chip) → **QA Accept Grandchild**,
current row highlighted. The descendant survives and the chain still reads.
(`B11`)

Server side, confirmed over HTTP: the thread from G returns three nodes with the
middle one `is_unavailable: true` and its title and timeframe nulled, while R's
`direct_response_count` is 0 — soft-deleted children are not counted.

### Two lifecycle gaps this round found — both now closed

1. **Deletion had no reachable action.** `MarkerDetailView` and
   `EmbeddedMarkerDetailView` each carry a Delete Marker menu and neither is
   instantiated anywhere in the app, so the menu was dead code; the sheet that is
   actually presented ended at *Share Marker*, as author and as ADMIN moderator
   alike. Closed in `31da3ca`, together with the manager path behind it, which
   was optimistic and silent on failure — see that commit.
2. **A root whose only response is a tombstone lost its thesis affordance.** The
   disclosure was gated on an active count that excludes soft-deleted children,
   so the branch below the tombstone was reachable from underneath and never from
   the root. Closed in `fdf28a0` against the backend's additive `has_responses` /
   `parent_has_responses`, with the active count's meaning unchanged.

### Not performed

* **A live detached response.** The parent-id-cleared shape needs a *hard*
  delete, and the backend soft-deletes, so I could not produce one against the
  live DEV data without doing something to the database that is not mine to do.
  Covered at decode level instead, in `MarkerLinkDecodingTests`.
* No physical device, no production endpoint, no external share destination, and
  the deep/wide fixture and the other member's markers were not modified.

---

## Lifecycle round — structural responses and a reachable delete (2026-09-10)

Backend added `has_responses` on markers and `parent_has_responses` on the
create/delete payloads, additive and defaulted false, with the active count's
definition untouched. iOS matched it in `fdf28a0`, and the delete seam that the
same acceptance exposed was closed in `31da3ca`.

Live on the isolated DevProfile build against the rebuilt DEV backend, on the
disposable QA branch — the deep/wide fixture was not touched:

* **Moderator delete through the new action.** Alex (ADMIN) opened Sam's
  cross-timeframe reply, and the sheet now ends with a destructive *Delete
  Marker* row. It confirms first, and the delete landed. (`C02`–`C04`)
* **The root kept its thesis at zero active responses.** With the reply gone,
  `direct_response_count` is 0 and `has_responses` is true, and the disclosure is
  still there reading *0 direct responses* — where before this round it vanished.
  (`C05`)
* **The branch is reachable from the root again.** Expanding it walks
  *QA Accept Root* → *Unavailable marker (Supports 1)* → *QA Accept Grandchild
  (Builds on)*, which is exactly the path that was lost. (`C06`, `C07`)
* **Failed-request draft retention**, done the way you suggested rather than by
  breaking the gateway: a new throwaway parent, a response composed against it
  with the link banner attached, the parent deleted out from under the open
  composer, then submit. The composer stays open, the draft text and the banner
  survive, and the failure is stated in place — *"Placement Failed. Your response
  is still here — try again."* (`D01`, `D02`)

Server-side spot check through the gateway confirmed the wire values these
depend on: the root at `direct_response_count: 0` / `has_responses: true`, and
both replies carrying `parent_has_responses: true`.

---

## Profiling harness — setup and commands

`traders_guildUITests/ChartPanPerformanceDriver.swift`. Portable and
test-only: no feature code, no assertions about linked markers, so it applies
to the 1.2.1 baseline worktree unchanged. That is the point — a matched pair is
only matched if both halves are driven identically.

**Prepare the device first.** The driver `activate()`s an app that is already
running and already prepared; it deliberately never launches one, because
launching discards the chart position, selection and thesis focus that the
measurement is about.

1. Install and launch `co.tradersguild.app.linkeddev` (`DevProfile`), sign in
   with the QA account, and open the guild, symbol and timeframe holding the
   dense fixture.
2. Put the chart where the measurement should happen — markers visible, and a
   thesis selected if focus is being measured.
3. Attach Instruments to the **app**, not the test runner.
4. Leave it foreground, no debugger. The `LinkedDev Profile` scheme's run *and*
   test actions both launch without one.

```
xcodebuild build-for-testing \
  -project traders_guild.xcodeproj \
  -scheme "traders_guild LinkedDev Profile" \
  -configuration DevProfile \
  -destination 'platform=iOS,name=<device name>'

xcodebuild test-without-building \
  -project traders_guild.xcodeproj \
  -scheme "traders_guild LinkedDev Profile" \
  -configuration DevProfile \
  -destination 'platform=iOS,name=<device name>' \
  -only-testing:traders_guildUITests/ChartPanPerformanceDriver
```

Cut the Instruments trace between the `TG_PROFILE_BEGIN` and `TG_PROFILE_END`
markers it prints, and compare the two builds over the same pair count.

**Two scheme facts that are load-bearing, not incidental.**

The `LinkedDev Profile` scheme carries the UI-test target *only*. Adding the
unit-test target fails the build: `@testable import` needs
`ENABLE_TESTABILITY`, which `DevProfile` disables because testability
suppresses cross-module optimisation — a build with it on is not the build
being measured. Unit tests stay on `traders_guild Compose Dev`.

`ChartPanPerformanceDriver` is skipped in `traders_guild Compose Dev`. It
drives an installed, prepared isolated app, so in the ordinary suite it failed
every run. That is a scheme decision and does not soften the driver: run it
against an unprepared app and it still fails visibly, with the chart controls
it looked for. Verified — on a simulator with no prepared isolated app it fails
"No chart control found… refusing to record a meaningless trace" rather than
passing.

**It does not time anything itself.** Wall clock in the driver is dominated by
its own settle sleeps, so an elapsed-time assertion would pass whether or not a
gesture ever reached the chart. Frame timings come from Instruments; what the
driver guarantees is that the gestures are identical, that they landed on a
real chart, and that the app is still on that chart afterwards.

---

## Isolated device configuration

Built and signed, **not installed** — awaiting owner verification.

- Artifact: `DevProfile-iphoneos/traders_guild.app`, bundle id
  `co.tradersguild.app.linkeddev`, display name `TG LinkedDev`, signed
  `Apple Development` on team `B4WE2NR99U`, `.dSYM` retained.
- Entitlements as signed: `aps-environment development`, keychain group
  `B4WE2NR99U.co.tradersguild.app.linkeddev` **only** — it cannot read or
  overwrite the production session.
- Routing fails closed: under `TG_ISOLATED_DEV` there is no production endpoint,
  and a missing, unexpanded or non-local baked URL resolves to loopback rather
  than to `api.tradersguild.co`.
- `MARKETING_VERSION` reads 1.3.0 in **both** the feature and baseline
  DevProfile builds, so identify a measurement by commit and artifact path, never
  by the displayed version.

---

## Compatibility worktrees (test-only, separate branches)

Four baselines, each **built and run**, not merely identified:

| Worktree | Baseline | Result |
|---|---|---|
| `linked-markers-ios-compat` | iOS `74c772c` — 1.2.1 build 22, submitted | 18 tests, 0 failures |
| `linked-markers-ios-118-compat` | iOS `ios-v1.1.8-build18` — newest **released** | 9 tests, 0 failures |
| `linked-markers-android-compat` | Android `c296316` — 1.2.1 code 17, withheld | 9 tests, 0 failures |
| `linked-markers-android-117-compat` | Android `acc2a30` — 1.1.7 code 5, **debut Play release** | 7 tests, 0 failures |

### These four suites depend on the backend worktree

All four read the seven wire fixtures from
`.worktrees/linked-markers-backend/services/chart-service/tests/fixtures/linked_markers/`
by a path relative to the test file. Nothing copies them, so the fixtures stay
the single source of truth and cannot silently drift from the backend.

**All four fail — deliberately — when a fixture is missing.** They do not skip.
A compatibility suite that skips still reports success, which is the same
vacuous pass the 1.1.8 target produced by running nothing at all. So if that
backend worktree is moved or removed, these suites go red on purpose: the
message names the expected directory. Restore the worktree, or regenerate the
fixtures with the backend smoke runner, rather than reading it as a regression
in the baseline under test.

Testing the older baselines separately was justified, not ceremonial:

- **iOS 1.1.8** does not have `RLPushNotificationTapPayload.markerGuildId`, and
  its target does not execute swift-testing at all — a `@Test` file there
  reported "Executed 0 tests" and passed having run nothing, so the suite was
  rewritten as XCTest.
- **Android 1.1.7** has no `parseWireInstant`, no `WsEvent.MarkerCreated` or
  `MarkerDeleted`, and only the older `marker_event` wrapper the backend no
  longer sends. Its marker websocket path is dead against the current backend,
  and `marker_created` correctly degrades to `Unknown` rather than throwing.

**The guard that matters for Android.** 1.1.7 maps markers with a bare
`Instant.parse`, and the app's own `WireInstant.kt` records a numeric offset
taking the live-candle stream down in production. So the linked-marker work must
never change the spelling of a field that build already parses; the additive
fields may use `+00:00` freely because it ignores them. That invariant is
asserted directly rather than by asserting the offset throws — this suite runs on
the desktop JVM, whose `ISO_INSTANT` accepts offsets, while Android's desugared
`java.time` is what actually crashed.

---

## QA state left behind

My E2E created and then deleted five markers in the QA thesis. Deletion is soft
by contract, so those five remain as **tombstones** — structural rows with no
identity or content. They are excluded from `total_count`, which is why the
thread reads `nodes=8, total_count=null` with one branch cursor outstanding
rather than its original `nodes=4, total_count=3`. The original root thesis and
both disposable members are untouched; nothing can restore the pre-run node
count, because that is what soft deletion means.

## Not done

1. **Physical device.** Nothing installed on the iPhone 14 Pro, as instructed.
   The isolated DEV/profiling configuration is built and signed — see
   *Isolated device configuration* below — and is waiting on the owner's
   verification before any install.
2. **No Instruments run**, so no FPS figure at all. Do not compare against the
   57 fps figure from the gesture-perf work: different build, different
   hardware, unrecorded dataset. The number that decides this is a matched pair
   measured in one sitting, per `docs/DEVICE_PROFILING_PLAN.md`.
3. **VoiceOver still not driven by hand**, but no longer unchecked.
   `MarkerLinkAccessibilityTests` runs against the DEBUG fixture gallery and
   asserts the three claims that regress silently: relationship is reachable as
   a word rather than carried by colour, unavailable tombstones are not offered
   as destinations, and nothing actionable reads as an SF Symbol name. It
   attaches the element tree to the result bundle as a record.

   What it cannot prove is rotor order or how speech sounds — that still needs a
   person. And one thing it deliberately does **not** assert: XCUITest's
   descendant enumeration is not VoiceOver's element order, so a row using
   `children: .combine` exposes child images to the query that VoiceOver never
   stops on. Asserting on those would have meant changing production code to
   satisfy a surface no user reaches. `UnifiedMarkerBadge`'s intent symbols
   (`waveform.path.ecg.magnifyingglass` and friends) carry no label of their
   own; that is app-wide chrome predating linked markers, is counted in the
   attached snapshot, and is worth a separate look outside this branch.

   Chart glyphs remain Canvas pixels with no accessibility elements — unchanged
   from 1.2.1 — so the thesis list is still the accessible path.
4. **0.22 unchanged**, as instructed. The light-grey observation stands: unrelated
   markers there are closer to invisible than recessive, and a theme-aware floor
   near 0.35 would read better. Owner's call.
5. ~~Ancestry paging never exercised live.~~ **Done.** Both paging directions
   are now walked in the real UI against the owner's deep/wide fixture:
   three-window ancestry to the root on the 81-node chain, and branch
   continuation on the 226-node wide thesis. See *Live acceptance*.

## Left for the owner, not gaps in this work

- **Physical device install and the matched-pair Instruments run.** The
  isolated artifact and the corrected pan driver are ready; the owner holds
  installation.
- **`UnifiedMarkerBadge`'s unlabelled intent symbols.** App-wide chrome
  predating this feature, surfaced by the accessibility audit, counted in its
  attached snapshot. Worth a pass outside this branch.
- **A rotor-driven VoiceOver session**, which no automated check replaces.
