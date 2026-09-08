# iOS 1.3.0 Linked Markers — Claude implementation handover

Branch: `claude/1.3.0-marker-visuals`
Worktree: `.worktrees/linked-markers-claude`
Base: iOS `74c772c` (1.2.1 build 22) + DEV prerequisite `321e02d`

Status: **complete and buildable**. Clean Debug build for iOS Simulator, full
unit suite green (449 passing, 0 failures), app installs and launches.

---

## What is here

Seven commits, each buildable:

| Commit | Contents |
|---|---|
| `5d017b1` | Pure link topology, thread window, connector geometry |
| `a3efeb2` | Wire contract, thread store, placement session |
| `6a5c0bd` | Tests for the pure layer |
| `e0a242f` | Focus rendering: rings, badge, connectors |
| `03e4249` | Link carried through placement |
| `4fef5a5` | Respond action, relationship row, thesis disclosure |
| `0d9bf48` | Placement banner, response notification, focus exit |
| `1cac77d` | Cache/session/count/wire-compat tests |
| `2fd4830` | Reduce Motion + badge geometry as tested rules |

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

**Tests** — `MarkerLinkGraphTests`, `MarkerLinkGeometryTests`, `MarkerThreadWindowTests`,
`MarkerLinkStateTests`, `MarkerLinkDecodingTests`, `MarkerLinkRenderTests`.

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

## Verification performed

- **Clean Debug build**, iOS Simulator (iPhone 16 Pro, iOS 18.2), scheme
  `traders_guild Compose Dev`.
- **Full unit suite: 460 passing, 0 failures.** No pre-existing test changed
  behaviour; two test fakes gained the new `MarkerAPIClient` members.
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

1. **No end-to-end visual verification.** The simulator reaches the sign-in
   screen; without a backend serving linked payloads and two accounts I could not
   place a response and look at it. Everything visual is verified by geometry and
   policy tests, not by eye. **Still to check by hand once the backend is up:**
   default same-candle response, parent-unrelated-response stack, both themes,
   light-grey theme contrast at 0.22, small screen, Dynamic Type, VoiceOver
   ordering in the thesis list, Reduce Motion, a dense stack, and a 20-response
   thesis.
2. **No physical-device Instruments run.** Connector routing is O(edges × samples)
   per frame with a 12-edge cap; membership is computed on selection change, not
   per frame. Unmeasured against the 57 fps baseline.
3. **Cache invalidation covers logout, guild change, marker deletion and
   websocket reconnect.** Not yet wired: `.privacyChanged` and `.moderation`.
   `invalidateAll(reason:)` accepts both and `invalidateThesis(containing:)`
   exists — they need calling from wherever a block or a moderation action
   lands. That is the remaining integration gap, and it matters because a
   cached window could otherwise show a node the viewer has since blocked.
4. **Discord relation copy** (generic sentence only) is backend-side; nothing on
   iOS was changed for it, and public share cards are untouched as specified.
5. **Android** untouched, as instructed.

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
