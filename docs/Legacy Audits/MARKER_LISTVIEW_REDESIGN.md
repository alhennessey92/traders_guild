
Had an AI already look at this and attempt to start it but i stopped as it got started, so not sure exactly what parts it touched. Here is the original idease i had 


Objective

Redesign the marker list item UI across the app to achieve a more professional, lightweight, and readable appearance.

⸻

Current Problem
	•	The existing marker list item design feels visually cluttered.
	•	Each item contains too much information at once, reducing clarity and usability.
	•	The overall look does not match the desired clean, polished app aesthetic.

⸻

Design Direction

Move from a dense, “open” layout to a more structured capsule-based design.

⸻

Proposed UI Pattern

Each marker in a list should be displayed as a large capsule component with a clear hierarchy:

1. Left Section (Visual Identity)
	•	A large circular icon representing the marker type (same visual as used on bottom bar symbol tab button).
	•	This should be prominent and anchor the item visually.

2. Primary Content (Top Row)
Displayed to the right of the icon:
	•	Symbol name (e.g. AAPL, BTCUSD)
	•	Timeframe pill (e.g. 1m, 1H, 1D)
	•	Contextual pills (dynamic based on marker type):
	•	Setup markers: status (Live, Tracking, SL Hit, Nearing TP, etc.)
	•	Question/Poll markers: short preview of the question
	•	Other marker types: most relevant short descriptor
	•	Far right of this row:
	•	Like count

⸻

3. Secondary Content (Bottom Row)
Below the primary content:
	•	User metadata:
	•	Username
	•	Role (e.g. Admin, Mod, Member)
	•	Reputation
	•	Accuracy
	•	Far right:
	•	Time since posted (e.g. “2m ago”)

⸻

4. Expand Interaction (Right Edge)
	•	On the far right of the capsule:
	•	A subtle circular affordance/icon indicating the item can be expanded.
	•	Expanding reveals:
	•	Full question text (for question/poll markers)
	•	Detailed setup info (SL/TP, reasoning, etc.)
	•	Any additional marker-specific data

⸻

Key Design Principles
	•	Reduce visual noise → only show essential info by default
	•	Consistent hierarchy → clear separation of primary vs secondary info
	•	Scannability → users should quickly browse many markers
	•	Consistency across app → same component used everywhere

⸻

Scope

This redesign must be applied globally wherever marker list items appear:
	•	Left drawer (marker tab)
	•	Bottom bar marker view
	•	Profile marker view
	•	Any other list-based marker displays

⸻

Implementation Notes
	•	Create a reusable MarkerListItem component
	•	Support dynamic content based on marker type
	•	Ensure layout is adaptable for different data densities
	•	Maintain alignment with existing app styling (glass, lightweight UI, etc.)




PLAN


# Unified MarkerListItem Redesign

## Context

Three separate marker list item components exist with overlapping functionality:
- **`MarkerActivityCard`** (TopMarkersView.swift:631-1099) - capsule layout, used in left drawer + chart bottom sheet
- **`ProfileMarkerCard`** (ProfileContentViews.swift:522-734) - card layout, used in profile views
- **`MarkerActivitySheet` row** (MarkerActivitySheet.swift:133-300) - timeline layout, chart bottom sheet activity

All render essentially the same data (symbol, timeframe, author, tracking state, likes, notes) with different layouts. The goal is to unify them into a single reusable `MarkerListItem` component with the new capsule-based design.

---

## Step 1: Define `MarkerListItemData` Protocol

**File:** `Models/RLChartDTOs.swift` (after line ~190)

Create a protocol capturing the shared surface of `RLTopMarkerDTO` and `RLMarkerActivityItemDTO`:

```swift
protocol MarkerListItemData {
    var id: UUID { get }
    var symbolId: UUID { get }
    var symbolTicker: String { get }
    var symbolBrandColor: String? { get }
    var symbolAssetClass: String { get }
    var authorId: UUID { get }
    var authorUsername: String { get }
    var authorInitials: String { get }
    var authorAvatarUrl: String? { get }
    var authorIsOnline: Bool { get }
    var authorReputation: Int { get }
    var authorAccuracyRate: Double? { get }
    var authorRole: String { get }
    var intent: String { get }
    var title: String? { get }
    var notePreview: String? { get }
    var createdAt: Date { get }
    var createdAtFormatted: String { get }
    var timeframe: String { get }
    var price: Double { get }
    var setupSummary: RLSetupSummaryDTO? { get }
    var likeCount: Int { get }
    var isLikedByCurrentUser: Bool { get }
    var commentCount: Int { get }
    var isCurrentUserMarker: Bool { get }
    var intentEnum: RLMarkerIntent { get }
    var authorAccuracyFormatted: String? { get }
    // Activity-only (optional for RLTopMarkerDTO)
    var predictionResult: RLPredictionResultDTO? { get }
    var displayTimestamp: String { get }
    var trackingStateEnum: RLTrackingState? { get }
}
```

Add conformances:
- `RLMarkerActivityItemDTO` - already has all fields; `displayTimestamp` maps to `activityTimestampFormatted`
- `RLTopMarkerDTO` - `predictionResult` returns `nil`, `displayTimestamp` returns `createdAtFormatted`, `trackingStateEnum` computed from `setupSummary?.trackingState`

---

## Step 2: Move `MarkerActivityMetaChip` to UnifiedComponents.swift

**From:** TopMarkersView.swift:1074-1099
**To:** UnifiedComponents.swift (after `MarkerListSpecificsLabel` ~line 912)

This pill component is already used across multiple files. Moving it to the shared location.

---

## Step 3: Create `MarkerListItem.swift`

**New file:** `Features/Shared/globalViews/MarkerListItem.swift`

### Style enum:
```swift
enum MarkerListItemStyle {
    case capsule   // Left drawer, chart bottom sheet
    case card      // Profile view (wraps in UnifiedContentCard)
    case inline    // Timeline rows (no background, compact)
}
```

### Component: `MarkerListItem<M: MarkerListItemData>`

**Properties:** marker, style, showMyBadge, currentPrice, likeAnimationMarkerId, onLike, onTap

**Layout (capsule style - the primary new design):**
```
+----------------------------------------------------------+
| [Large Badge] Symbol [1H] [Live/Status] [ctx]  heart 12 V|
|              @user . Admin . shield 23 . target 72%  2m ago|
+----------------------------------------------------------+
  (expanded content below when V tapped)
```

- **Left:** `UnifiedMarkerBadge` at `.large` (44pt)
- **Top row:** Symbol ticker (bold) + timeframe pill + contextual pills (TrackingStatePill for setups, note preview for questions/polls, intent label for others) + like count (far right)
- **Bottom row:** @username + role + reputation + accuracy + relative timestamp (far right)
- **Expand chevron:** Circular affordance on far right, shows when `hasExpandableContent`
- **Expanded section:** Setup metrics/outcome, full note text, marker-specific details

Port computed properties from `MarkerActivityCard`: `trackingState`, `approachingStatus`, `liveSetupMetrics`, `outcome`, `hasExpandableContent`, `contextSummary`, like animation logic.

Use generics (`<M: MarkerListItemData>`) instead of `any MarkerListItemData` to avoid existential boxing overhead in scroll lists.

---

## Step 4: Update Call Sites

### a) TopMarkersView.swift
Replace `MarkerActivityCard(...)` calls (~lines 232, 266, 289, 328) with `MarkerListItem(marker:style:.capsule...)`

### b) chartSheetMarkersView.swift
Replace `MarkerActivityCard(...)` calls (~lines 333, 368, 389) with `MarkerListItem(marker:style:.capsule...)`

### c) ProfileContentViews.swift
Replace `ProfileMarkerCard(marker:onTap:)` with `MarkerListItem(marker:style:.card...)`

### d) MarkerActivitySheet.swift
Refactor `markerRow(_:isLast:)` - keep timeline chrome (vertical line + colored dot), replace inner content with `MarkerListItem(marker:style:.inline...)`

---

## Step 5: Delete Dead Code

- `MarkerActivityCard` from TopMarkersView.swift (lines 631-1070, ~440 lines)
- `MarkerActivityMetaChip` original from TopMarkersView.swift (lines 1074-1099)
- `ProfileMarkerCard` from ProfileContentViews.swift (lines 522-734, ~213 lines)
- `markerRow` + `markerRowSpecifics` from MarkerActivitySheet.swift (lines 133-300+)

**Estimated net reduction:** ~400 lines

---

## Step 6: Verify

- Build project, fix compilation errors
- Visual test each location:
  1. Left drawer marker tab (Live Feed, Setups, By Symbol tabs)
  2. Chart bottom sheet markers tab (All, Setups, Social, Mine tabs)
  3. User profile markers tab
  4. MarkerActivitySheet timeline
- Verify expand/collapse on setup markers + question/poll markers
- Verify like animation
- Verify both DTO types work through the protocol

---

## Critical Files

| File | Action |
|------|--------|
| `Models/RLChartDTOs.swift` | Add protocol + conformances |
| `Features/Shared/globalViews/MarkerListItem.swift` | **CREATE** - new unified component |
| `Features/Shared/globalViews/UnifiedComponents.swift` | Receive `MarkerActivityMetaChip` |
| `Features/Core/subViews/leftDrawerSubViews/guildTopMarkers/TopMarkersView.swift` | Update calls, delete `MarkerActivityCard` + `MarkerActivityMetaChip` |
| `Features/Core/subViews/chartSheetSubViews/chartSheetMarkersView.swift` | Update calls |
| `Features/Core/subViews/leftDrawerSubViews/guildUsers/ProfileContentViews.swift` | Update calls, delete `ProfileMarkerCard` |
| `Features/Core/subViews/chartSheetSubViews/MarkerActivitySheet.swift` | Refactor timeline row |

## Existing Components to Reuse
- `UnifiedMarkerBadge` (UnifiedComponents.swift:1431) - large circular icon
- `TrackingStatePill` (UnifiedComponents.swift:2051) - status capsule
- `ApproachingLevelChip` (UnifiedComponents.swift:2162) - TP/SL proximity
- `MarkerActivityMetaChip` (to be moved to UnifiedComponents) - timeframe pill
- `UnifiedAuthorFooter` (UnifiedComponents.swift:919) - author info pattern
- `UnifiedSeparatorDot` - inline separators
- `UnifiedContentCard` - card wrapper for profile style
