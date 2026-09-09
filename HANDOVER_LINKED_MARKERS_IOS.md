# iOS 1.3.0 Linked Markers — Claude implementation handover

Branch: `claude/1.3.0-marker-visuals`
Worktree: `.worktrees/linked-markers-claude`
Base: iOS `74c772c` (1.2.1 build 22) + DEV prerequisite `321e02d`

Status: **complete, buildable and verified against the live DEV backend**.
Clean Debug and Release builds, **477 swift-testing + 30 XCTest passing**,
visuals reviewed against both a DEBUG fixture harness and real backend data.

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

25 commits, each buildable:

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
   selection change, not per frame. Unmeasured against the 57 fps baseline.
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

---

## Notes for integration

- Nothing in this branch calls production. No pushes, no deploys.
- The feature is dark by default: with `linked_markers_enabled` false the chart
  renders exactly as 1.2.1 — no rings, no connectors, no badge, no respond
  action — while existing links still decode and display as ordinary markers.
- `MarkerManager.linkFocus` is derived state; assign it only from
  `refreshLinkFocus()`.
- The fade decision is **latched per selection** so progressive pages cannot
  flicker the dim on and off; a deliberate filter change clears the latch and
  re-applies the rule.


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
   An isolated DEV build/profile plan is still to be agreed.
2. **No Instruments run**, so no FPS figure against the 57 fps baseline.
3. **VoiceOver not driven.** Labels, traits and hints are set throughout and
   relationship is always spoken rather than carried by colour, but the rotor was
   not stepped. Chart glyphs remain Canvas pixels with no accessibility elements —
   unchanged from 1.2.1 — so the thesis list is the accessible path.
4. **0.22 unchanged**, as instructed. The light-grey observation stands: unrelated
   markers there are closer to invisible than recessive, and a theme-aware floor
   near 0.35 would read better. Owner's call.
5. **Ancestry paging never exercised live.** The QA thesis is shallow, so no
   ancestry cursor was ever issued. Branch cursors were, and are proven.
