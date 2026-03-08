Initial Ideas...

Traders Guild

Marker System — Update V3 Implementation Specification

Overview

The marker system is the core feature of Traders Guild, allowing users to communicate chart analysis and trade ideas directly on charts.

The new marker architecture already migrated from static marker types to intent-based markers with component architecture.

This update focuses on implementing the UI and interaction model required to support the new system.

Markers should allow users to construct a chart analysis state, including:
	•	Marker intent (analysis, setup, alert, etc.)
	•	Linked indicators
	•	Drawings/patterns
	•	Linked timeframes
	•	Additional notes or links

When another user selects a marker, the chart temporarily recreates the chart state defined by the marker author, allowing other traders to see the reasoning behind the marker.

The implementation consists of two primary UI states:
	1.	Marker Placement Mode
	2.	Marker Viewing Mode

⸻

Marker Architecture Summary

Markers now consist of:

Marker
 ├── Intent
 ├── Anchor (time + price)
 ├── Components
 │     ├── Levels
 │     ├── Drawings
 │     ├── Indicators
 │     ├── Timeframe links
 │     └── Additional metadata
 └── Metadata (title, note, visibility, etc.)

The UI must allow users to build these components visually.

⸻

UI Modes

Mode 1 — Marker Placement Mode

Activated when the user chooses to place a marker from the chart.

Top Toolbar

Default chart toolbar is hidden.

Replace with:

[ Cancel Button ]  Place a Marker

Cancel button:
	•	red glass style
	•	white “X” icon
	•	exits marker placement mode

No other controls are visible in the top bar during placement.

⸻

Bottom Bar — Marker Editor

The bottom bar remains the primary control interface.

The structure must match the existing bottom bar UI styling used in the rest of the application.

Tabs:

General
Indicators
Drawings
Timeframes
Place Marker (button)

The tab design should reuse existing UI components from the chart interface.

⸻

General Tab

Contains core metadata for the marker.

Fields:
	•	Marker Intent
	•	Title
	•	Description / Note
	•	Visibility (Guild / Private)
	•	Confidence (optional)

The General tab icon should reflect the current marker intent icon and color.

This tab may dynamically update based on selected components.

Example:

Intent: Setup
Title: Breakout Above Range
Note: Watching for continuation
Visibility: Guild
Confidence: ★★★☆☆


⸻

Indicators Tab

Displays available indicators that can be attached to the marker.

This tab should mirror the existing indicator selection UI already used by the chart.

Features:
	•	Select indicators
	•	Reuse indicators currently active on the user’s chart
	•	Configure indicator settings
	•	Choose a primary indicator

Indicators added here will be shown when the marker is viewed by other users.

Constraints:
	•	Maximum 2 indicator panels
	•	Maximum 1 primary indicator

⸻

Drawings Tab

Allows adding chart drawing components to the marker.

Supported drawing tools (v1):

Trendline
Ray Line
Horizontal Line
Vertical Line
Cross Line
Parallel Channel

Supported pattern templates:

Head and Shoulders
Long Position
Short Position
Take Profit Idea
Stop Loss Idea

Supported annotations:

Text
Note
Emoji

These drawings appear on the chart when the marker is viewed.

Constraints:
	•	Maximum 10–15 overlay elements

⸻

Timeframes Tab

Allows linking other chart timeframes relevant to the marker.

Example:

15m chart marker
Linked timeframes:
1H
4H
1D

V1 behavior:
	•	Display linked timeframe badges
	•	Tapping a badge switches the chart timeframe and navigates to the marker position

Future versions may add mini chart panels, but this is not required for V1.

Constraints:
	•	Maximum 2 timeframe links

⸻

Place Marker Button

The final tab location contains the Place Marker button.

Behavior:

Disabled → requirements not satisfied
Enabled → requirements satisfied

The button becomes green when valid.

Validation examples:
	•	Anchor must exist
	•	Setup markers require Entry + SL + TP
	•	Poll markers require question + options

⸻

Intent Action Strip

A capsule-style floating toolbar appears above the bottom bar.

This toolbar contains intent-specific required controls.

It spans the width of the chart and visually matches the bottom bar styling.

The bar remains fixed in place even when the bottom bar expands.

Purpose:

Provide quick access to required intent actions.

Examples:

Setup Marker

Entry
Stop Loss
Take Profit
Tracking Toggle

Alert Marker

Critical
Severe
Warning

Reaction Marker

Emoji Selector

Question Marker

Question Text Prompt

This bar should only contain 4–6 icon buttons maximum.

It must not duplicate generic actions (indicators, drawings, etc).

⸻

Chart Interaction During Placement

The chart remains interactive.

Supported interactions:

Marker Placement

User taps the chart to create a new marker.
The marker appears immediately at the tapped location.

The user can drag the marker to adjust its position before confirming.

The final marker position (time + price) becomes the stored marker position.

Level placement

Example:

Entry line
Stop loss line
Support
Resistance

User drags horizontal line vertically.

Drawing tools

Example:

Trendline
Zone
Channel

User taps or drags on chart to place shapes.

Ghost preview rendering should show during placement.

⸻

Mode 2 — Marker Viewing Mode

Activated when the user taps an existing marker.

The UI transitions into marker viewing state.

⸻

Top Toolbar

Default toolbar hidden.

Replace with:

[ Close Button ]  Viewing Marker

Close button exits marker viewing mode.

⸻

Bottom Bar (Viewing)

Tabs:

General
Components
Chat


⸻

General Tab

Displays marker metadata.

Includes:
	•	Author profile header
	•	Marker intent badge
	•	Title and description
	•	Visibility
	•	Engagement controls

Actions:

Like
Share
Follow


⸻

Components Tab

Displays all components attached to the marker.

Sections:

Levels
Drawings
Indicators
Timeframes
Links

These may appear as:
	•	data summaries
	•	chart previews
	•	snapshots

⸻

Chat Tab

Existing marker chat functionality.

Allows users to discuss the marker in real time.

No changes required.

⸻

Chart Behavior During Viewing

The chart temporarily applies the marker’s chart state.

This includes:
	•	indicator panels
	•	overlay indicators
	•	drawing objects
	•	linked levels

Users can still pan and zoom normally.

When the marker is deselected, the user’s original chart state must restore cleanly.

⸻

Component Limits

To prevent UI overload:

Max indicator panels: 2
Max timeframe links: 2
Max overlay drawings: 10–15
Max primary indicators: 1

Panels should be collapsible if multiple are visible.

⸻

Styling Requirements

All UI components must reuse existing app design patterns:
	•	bottom bar styling
	•	unified button components
	•	unified tab components
	•	glass button styling
	•	consistent spacing and typography

No new UI systems should be introduced unless necessary.

⸻

V1 Scope

Must implement:
	•	marker placement mode
	•	marker viewing mode
	•	bottom bar marker editor
	•	intent action strip
	•	indicator and drawing linking
	•	chart state restore when viewing markers

Can defer:
	•	advanced pattern libraries
	•	multi-timeframe chart panels
	•	marker linking between markers

⸻

Expected Result

After implementation:

Users can create markers that capture a complete analysis state, including:
	•	reasoning
	•	supporting indicators
	•	supporting drawings
	•	timeframe context

When another trader selects the marker, they see the chart exactly as the creator intended, making collaboration clearer and more powerful.






Final Plan ... 


Context
The V2 marker system works but has a constrained UI: a 2-tab panel (Details/Contents) with a sidebar tool picker. The V3 spec redesigns the interaction model into two clear modes — Placement and Viewing — each with a purpose-built bottom bar, intent action strip, and cleaner top toolbar. This is a UI-layer rewrite; the data model (RLComponentType, MarkerComponentPayload, DTOs) stays unchanged.

Phase 1: State & Type Foundations
Files to modify:

TradingChart/overlays/MarkerPlacementMode.swift — add selectedPlacementTab, constraints
TradingChart/viewModels/ChartControlViewModel.swift — add isMarkerViewingMode

Work:

Add MarkerPlacementTab enum with 4 cases: .general, .indicators, .drawings, .timeframes — conform to UnifiedTabItem from Features/Shared/globalViews/UnifiedComponents.swift
Add MarkerViewingTab enum (.general, .components, .chat) replacing current MarkerDetailTab
Add @Published var selectedPlacementTab: MarkerPlacementTab = .general to MarkerPlacementState
Add @Published var isMarkerViewingMode: Bool = false to ChartControlViewModel
Add computed constraint properties to MarkerPlacementState: indicatorPanelCount, drawingOverlayCount, timeframeLinkCount with limits (2, 15, 2) + canAddIndicator, canAddDrawing, canAddTimeframe booleans
Add limit feedback text: limitMessage(for:) returning e.g. "Maximum 2 linked timeframes"


Phase 2: Top Toolbar Updates
Files to modify:

Features/Core/MainView.swift — .toolbar {} block (lines 412–518)

Extract toolbar logic into a helper view or computed properties to avoid further bloating MainView.
Work:

Placement toolbar — Replace text "Cancel" with red glass circle button (X icon, Color.red.opacity(0.3) background, 36x36). Change principal text to "Place a Marker". Remove intent icon circle from principal.
Viewing toolbar — New branch: when isMarkerViewingMode, show close button (white glass, X icon) + "Viewing Marker" principal. Hide trailing items.
Wire isMarkerViewingMode in .onChange(of: chartViewModel.selectedMarkerForSheet?.id) — set true when selected, false when cleared.


Phase 3a: Tab Bar Shell + General Tab
Goal: Get the 4-tab bar structure + Place Marker button working with the General tab as the first content tab.
Files to modify:

Features/Core/MainView.swift — ChartBottomSheet: replace placementModeContent, add placementTabBar
TradingChart/overlays/MarkerPlacementPanel.swift — rewrite as tab router

Files to create:

TradingChart/overlays/MarkerPlacementGeneralTab.swift

Tab Bar
Replace EmptyView() at line 1470 with placementTabBar:

HStack of 4 RootBottomBarIconButton tabs (General, Indicators, Drawings, Timeframes) + 1 separate Place Marker button pinned right
Place Marker is not a tab — it's an action button that lives in the tab bar row but doesn't switch content
Green fill when placementState.isValid, dimmed when not
Tapping calls onPlaceMarker?()
Tab bar styling matches standardTabBar (50x50 circles, shadow, same spacing)

General Tab
Extract from current MarkerPlacementPanel.detailsView:

Intent picker (horizontal capsule scroll — reuse existing pattern, lines 110–145)
Title text field
Description/Note text field
Visibility toggle (Guild/Private — reuse lines 147–159)
Confidence stars (reuse lines 162–189)
Tab icon dynamically reflects current intent icon + color

PlacementPanel rewrite
Convert MarkerPlacementPanel into a tab router that switches content based on placementState.selectedPlacementTab. Remove old 2-tab segmented picker and Cancel/Place buttons (those move to the tab bar).

Phase 4: Viewing Mode Bottom Bar — 3-Tab Interface
Goal: Get viewing mode shell working with proper state transitions.
Files to modify:

Features/Core/MainView.swift — markerDetailContent, markerDetailTabBar, markerDetailTab state

Files to create:

TradingChart/overlays/MarkerViewingGeneralTab.swift
TradingChart/overlays/MarkerViewingComponentsTab.swift

General Tab
Reuse content from EmbeddedMarkerDetailView:

Author profile header
Intent badge
Title and description
Engagement controls (Like, Share, Follow)

Components Tab
Group marker components by type (Levels, Drawings, Indicators, Timeframes, Links):

Reuse contentGroup() helper pattern from current MarkerPlacementPanel.contentsView
Read from marker.components ([RLMarkerComponentDTO])
Linked indicators listed here but not all auto-rendered on chart (see Phase 5)

Chat Tab
Reuse existing EmbeddedMarkerChatTabView — no changes.
Tab Bar
Replace current markerDetailTabBar (capsule with author name + Chat/Analysis) with:

Close button (X, left side)
3 RootBottomBarIconButton tabs: General, Components, Chat
Matching standardTabBar styling


Phase 5: Chart State Save/Restore (Viewing Mode)
Files to modify:

TradingChart/indicators/IndicatorManager.swift — add snapshot methods
TradingChart/overlays/MarkerOverlayState.swift — coordinate indicator state
Features/Core/MainView.swift — wire to viewing mode lifecycle

V1 viewing rules (intentionally limited):

Always show marker lines/drawings/levels
Show at most 1 primary indicator panel (the one marked isPrimary)
Non-primary linked indicators listed in Components tab but NOT auto-rendered
Timeframe links shown as badges only, no auto-loaded panels

Work:

IndicatorManager.saveSnapshot() — copy current activeIndicators
IndicatorManager.applyMarkerIndicators([RLMarkerComponentDTO]) — activate only the primary indicator temporarily
IndicatorManager.restoreSnapshot() — restore saved state, clear snapshot
On viewing activate: save → apply primary indicator only
On viewing deactivate: restore
Drawing/level overlays already handled by MarkerComponentOverlayLayer


Phase 3b/3c/3d: Remaining Placement Tabs
3b. Indicators Tab (MarkerPlacementIndicatorsTab.swift)
V1 curated list only — do NOT mirror the full chart indicator settings system:

RSI, MACD, EMA, VWAP, Bollinger Bands
Simple toggle to attach (on/off)
Basic settings (period, etc.) — optional for V1
Option to attach indicators currently active on chart
Primary indicator toggle (max 1 primary)
Enforce max 2 indicator panels
When limit hit: disable add, show "Maximum 2 indicator panels" inline message + haptic
Store as RLComponentType.indicator with IndicatorPayload

3c. Drawings Tab (MarkerPlacementDrawingsTab.swift)
V1 drawing set — keep it minimal:

Lines: Trendline, Horizontal Line, Zone
Annotations: Text, Note, Emoji
Uses capsule button pattern from ToolOptionStrip
Enforce max 15 overlay elements
When limit hit: disable add, show "Maximum 15 drawing overlays" + haptic

Deferred to post-V3 rollout:

Ray, Vertical Line, Cross Line, Parallel Channel
Pattern templates (H&S, Long/Short Position, TP/SL Idea)
New RLComponentType cases + backend migration

3d. Timeframes Tab (MarkerPlacementTimeframesTab.swift)

Show all RLChartTimeframe cases as selectable badges
Max 2 linked timeframes
When limit hit: disable add, show "Maximum 2 linked timeframes" + haptic
Tapping a linked badge switches chart timeframe for context
Store as RLComponentType.timeframeLink components


Phase 6: Intent Action Strip
Files to create:

TradingChart/overlays/IntentActionStrip.swift

Files to modify:

Features/Core/MainView.swift — position as overlay above bottom sheet

Strict scope rule: Only required or high-frequency intent-specific actions. No generic tools.
Content by intent:
IntentControls.setupEntry, SL, TP, Tracking.alertCritical, Severe, Warning.reactionEmoji quick-select.newsAdd link.pollAdd poll prompt.analysisSupport, Resistance (2 buttons max).personalSupport, Resistance (2 buttons max).question(none — question text lives in General tab)

Max 4–6 buttons, capsule style from ToolOptionStrip
Actions call placementState.upsertComponent() / placementState.applyToolOption()
Fixed position above bottom bar via .padding(.bottom, bottomSheetHeight + 8)
Does NOT duplicate generic actions (indicators, drawings, timeframes stay in their tabs)


Phase 7: Cleanup — Remove ToolPickerView Sidebar
Files to modify:

TradingChart/overlays/MarkerPlacementMode.swift — remove ToolPickerView usage
TradingChart/overlays/MarkerComposerSheet.swift — update or deprecate

The sidebar is fully replaced by the 4-tab bottom bar. MarkerPlacementMode view (full-sheet variant) simplified or removed.

Implementation Order
1. Phase 1  — State foundations
2. Phase 2  — Top toolbar (extract logic out of MainView)
3. Phase 3a — General tab shell + tab bar structure + Place Marker button
4. Phase 4  — Viewing bottom bar structure (3 tabs)
5. Phase 5  — Save/restore chart state (primary indicator only)
6. Phase 3b — Indicators tab (curated V1 list)
7. Phase 3c — Drawings tab (Trendline, Horizontal, Zone, annotations)
8. Phase 3d — Timeframes tab
9. Phase 6  — Intent Action Strip
10. Phase 7 — Remove old sidebar
Shells and state transitions first, then rich tab content, then polish.

Key Patterns to Reuse
PatternSource FileRootBottomBarIconButton (50x50 circle)Features/Shared/buttons/RootBottomBarIconButton.swiftUnifiedTabItem protocolFeatures/Shared/globalViews/UnifiedComponents.swiftGlass button: .background(AppColors.whiteText.opacity(0.12))ThroughoutCapsule button groupMarkerPlacementPanel intent pickerToolOptionStrip capsule buttonsTradingChart/overlays/ToolPickerView.swiftTab bar toggle patternstandardTabBar in MainView.swift (line 1629)

Terminology
Consistently use throughout implementation:

intent (not "marker type")
components (not "elements" or "items")
tracking state (not "tracking mode")


Limit Feedback UX
When any component limit is hit:

Disable the add button (reduce opacity)
Show inline message: "Maximum N [component type]"
Subtle haptic feedback (UIImpactFeedbackGenerator(.light))


MainView Bloat Mitigation
Extract from MainView into standalone views/helpers:

PlacementToolbar — placement mode toolbar content
ViewingToolbar — viewing mode toolbar content
PlacementTabBar — the 4-tab + Place Marker button bar
ViewingTabBar — the 3-tab + Close button bar

Keep MainView as the coordinator; move visual composition out.

Verification

Placement mode: Enter placement → 4-tab bar + Place Marker button appears, top toolbar shows red X + "Place a Marker". General tab shows metadata fields. Place Marker button green only when valid, dimmed otherwise.
Viewing mode: Tap marker → top toolbar shows "Viewing Marker", bottom bar shows 3 tabs. Chart shows marker lines/drawings + primary indicator only. Close → user's chart state restores cleanly.
Intent action strip: Change intent → strip updates with correct intent-specific controls only. No generic tools leak in.
Component limits: Hit limits → add button disables, inline message appears, haptic fires.
Build: Project compiles. Existing marker CRUD, WebSocket updates, navigation all still work.


Deferred to V3.1 (Post-Core Rollout)

Drawing expansion: Ray, Vertical, Cross, Parallel Channel
Pattern templates: H&S, Long/Short Position, TP/SL Idea
New RLComponentType cases + backend migration
Full indicator settings mirror in placement
Multi-timeframe mini chart panels
Auto-rendering all linked indicators in viewing mode



TODO section

1. [FIXED] Remove the anchor point when placing markers, the little dot that moves when you click, markers should only be placed where they are dragged to by the user
2. [FIXED] There are 2 take profit and stop loss horizontal lines with setup marker, ideally all price lines should conform to the ones that can be dragged up and down not just clicked at a point to move, this is the same for any other price lines, they needs to be dragabble
3. [FIXED] When switching from setup to alert for example sl and tp lines still remain
4. [FIXED] intent action bar is good, but it needs to appear between the bottom bar and the x axis, this means the x axis needs to move up above it.
5. [FIXED] when panning in placement mode certain elements on screen like price lines and markers are appearing in fron of the x axis and their subsequent backgrounds
6. [FIXED] When dragging bottom bar up, intent action bar is moving as well, it needs to remain in its place and let the bottom bar sheet go over it
7. [FIXED] All tabs in placement mode have an unexpected inner background and the general UI is wrong, we should be following same UI as tabs in default bottom bar i.e. chartsheetsymbolview, charsheetmarkerview and Indicatorsettingsview, look at these and integrate similar design and ui principles into the placement mode tab sections
8. [FIXED] When adding a indicator in placement mode where it is a panel or overlay indicator it should appear on the chart
9. [FIXED] Adding indicators should be available to all intent markers
10. [FIXED] When adding patterns or drawings it should be available to all intent markers.
11. [FIXED] When adding a drawing on first click show circle and crosshair to show starting point and then each subsququent clikc add another circle and joins up with line etc or however the pattern is described, these circles after placing should be draggable to adjust the lines
12. [FIXED] a ghost like tooolbar button is showing in top right of screen in placement mode and viewing mode
13. [FIXED] When in viewing mode any indicators and or patterns need to show in the chart - panel or overlay
14. [FIXED] when in viewing mode there is a x or cancel button in bottom bar, this should be changed to a like button, and the general tab button in bottom bar for viewing mode needs to be a representation of the marker - its looks

15. [FIXED] I think i might remove the intent action bar and integrate the options into the general tab, this tab can hold specific options relating to each intent marker, think of it as a contextual tab for the specific marker, we should still allow switching marker types here, but the lower sections are about designing values for the marker. The standard general tab will include a hero top panel outlining selected marker to place including an avat display of the marker look, its name, basic standard info about its type, purpose and required values to place. The marker avatar will have a small cicrular icon on bottom right signalling that if you click the avatar it changes look of current panel/sheet displaying all possible markers to switch to a different type.

Under the top panel is the requirements section outling all the required fields for selected marker, for: 
	Setup - this requires values for take profit and stop loss, users can set exact values here instead of dragging the bars and the values update bar positions. We will also provide a button here to switch the marker to tracked so its tracked by the state machine and affects reputation
	Analysis - this requires values for an analysis text input, this is a description on what the user thinks
	Alert - this requires user to select severity of the alert, critical, severe, warning, informational. Should display icons with name underneath
	Question - Requires user to input a question that will be displayed to other users and they will respond in marker chat
	Poll - this requires values for initial question and 2 possible answers, may also allow users to add more answers later
	News - this requires values for a URL link, how this is done is up to you, could give options for adding link, image etc...
	Reaction - requires one emoji selected, display a grid of different emojis most used, no names or text just the icons to select one
	Personal - requires no values

Under the requirements panel is the general section for general options available for all markers, at the moment we just give options to add a description and basic stats on the marker (its placing user, current guild, symbol, timeframe etc...)

I want you to try and keep the UI similar to the ChartSheetSymbolView.swift

16. [FIXED] Looking at point 15 we need to mirror the design for the viewing mode when user views the marker, displaying the same information in a viewable state rather than an input state, try and keep it looking the same as possible to the placement mode tab

17. [FIXED] Indicator tab in placement mode needs to mirror more the look of the IndicatorSettingView.swift dislaying the different tabs for the different indicators, we also need to allow every type of indicator as an option here. Need to make sure the active sub tab in this section displays the selected tab on chart for the marker with the ability to remove them and edit them. This indicator tab should be available to all markers

18. [FIXED] Drawings tab in placement mode again needs to follow a more similar UI as the IndicatorSettingView.swift and or the indicator tab outlined in point 17. We need all the different sub tabs for different drawing, annotations, patterns with all the available options. Also need an active sub tab for drawings added to chart with ability to remove them + edit them. This drawing tab should be available to all markers

19. [FIXED] Timeframes tab in placement mode need a better UI design much like the chartSheetMarkersView.swift displaying a list of different timeframes linked. Eventually we will show mini panels showing marker location in that timeframe, for now just a select/deselect of the timeframe. This timeframe tab should be available to all markers

20. [FIXED] Place marker button in bottom right should not be text, needs to be an icon perhaps the arrow.down.circle icon with a better color more suited to current UI

21. [FIXED] Placing indicators in placement mode are still not showing on chart, this includes panels only, i think overlays are working currently.

22. [FIXED] When placing setup marker you shouldnt be able to set the entry line, it should only be the take profit and stop loss. Also still allows you to set seperate take profit, stop loss and entry lines from the action bar, obviously with this removed the user shouldnt be able to do this, when in placement mode user is forced to place the take profit and stop loss markers via the draggable lines already present so remove them other options. The entry is fixed to most recent candle close.

23. [FIXED] In setup marker need to maker sure we implement the original or similar info panel listing pnl, pip range, entry/tp and sl point lines in a small box under the chart info box on top left, do in a similar design to chart info box. The information will adjust as user adjusts the tp and sl lines.

24. [FIXED] When drawing a line like the trendline on select in tab it displays a point on screen with vertical and horizontal dashed lines like a crosshair with relevant x and y axis price and time indicators, user can drag this point, when they tap the screen it sets the point in its place, next tap sets a new point with crosshair and draw line between the two, this point can be dragged around until user taps the chart again which sets it in place. On this final tap with both points set both points scale to show their positions and user can continue to drag them individually. When user taps the chart outside of them points it sets them in place, if user taps line again it shows scaled points to move again. This process needs to carry on with all drawings. Any annotation like notes and emojis need to show on screen and be draggable on tap and fixed when tapped outside, emoji and notes can be changed, edited from inside drawing tab in bottom bar

25. [FIXED] When in viewing mode need to ensure all set indicators are displayed in their panel or overlay form

26. [FIXED] When in viewing mode the components tab needs to have set sections for indicators, drawings and timeframes outlining the overview of what has been included, follow similar design patterns to chartsheetsymbolview.swift

27. [FIXED] When in viewing mode the like button needs to show Number next to it, with a better UI, red capsule, white heart

28. [FIXED] When in viewing mode need to remove the bottom chart buttons (day date, marker visibility, latest candle)

29. [FIXED] When in viewing mode the tab button for general tab which displays general marker information needs more information as its tab button, needs to show avatar of marker intent type, then marker type name and underneath that the username of user who placed it



30. [FIXED] Ok, very good so far, a couple of things, in setup mode the values in the requirements box dont seem to change when moving the price bars, also the values in the setup chart info box dont seem to change
31. [FIXED] in setup marker the marker chart info box stretches the entire screen, it should be constrianed to the same width as the main chart info box, with the same style (opacity, colors etc...)
32. [FIXED] In setup marker the entry price line can still be moved, it needs to remain fixed to the close price of latest candle
33. [FIXED] remove options for guild visibility and confidence for the minute, all markers are guild wide visible except personal ones
34. [FIXED] in placement mode need to add a indicator, drawing and timeframe title header in their respective tabs
35. [FIXED] When changing severity in alert marker it needs to update marker on screen and have different colors for each severity
36. [FIXED] When switching marker type in general tab need a better ui of marker options, ideally showing marker avatar look, in a grid format
37. [FIXED] When placing lines/drawings on first tap of first point the chart is still panning around, so cant drag to next point, it needs to remain fixed, when adding lines, unless user tries to drag outside of the point
38. [FIXED] Need to review the drawings tab and sections, for each component to make sure they are easy to add, some components feel a bit clunky when adding, there should be a simple process of selecting the tool, clicking the chart to place it and be able to drag it around. When tapping outside it it locks in place. when tapping again it becomes movable. This needs a full audit
39. [FIXED] when in viewing mode the general marker tab that displays marker avatar, title and user placing it need to be in a capsule shape not a rectangular.
40. [FIXED] Need to make sure all tab buttons in bottom bar conform to ui looks like in rest of the app
41. [FIXED] See if you can make the sub tabs in indicator and drawing section show the relative text in their tab at all times, rather than collapsing to their icons


42. [FIXED]When drawing lines, its impossible to get out of the drawing phase, the second anchor dot is permanently attached. Need to be able to get out of it by tapping outside the anchor dot radius, anywhere in the chart, anchor dots only movable by dragging them. When outside of movement if click a anchor dot it becomes movable again
43. [FIXED]In placmeent mode the place marker button needs to be a icon only, preferably the target icon, happy for you to play around with colors in paletter mode to make it look better.
44. [FIXED]Only marker that needs a required horizontal price indicator is setup marker all others dont need a preset horizontal marker.
45. [FIXED]when changing reaction marker image, it adds a seperate image on chart of the same image. It should only change the image in the actual marker
46. [FIXED]when viewing drawing tab in placement mode the content expand past screen in both directions a bit, making it unusable
47. [FIXED]when in placement mode anywhere user enters text and the keyboard is shown, the bottom bar tabs are also moved up above the keyboard, they dont need to, they can remain where they are, user doesnt need to see them
48. [FIXED]in placement mode the setup marker info box on chart is too wide. And when in tracking mode need to show reputation gain/loss in info box.
49. [FIXED]in placement mode when tracking is active in setup marker, need to make more of a thing about it, showing gain/loss reputation in the general tab, maybe changing a few colors so user knows they are in a different marker mode
50. [FIXED]in placement mode when adding a setup marker there are ent, sl and tp text views on the horizontal lines for prices, there are already these price indicators showing behind so we now have two sets, remove the ones with the black abckground, keeping the original one. Also because the entry price indicator is same as the current yellow price indicator there is now an overlay, to combat this, i suggest we either hide the default yellow price indicator while its showing and give the entry price indicator a yellow border or increase size of the entry price indicator and give yellow border to hide it.
51. [FIXED]When in placement mode, unable to resize chart by pinching on y axis, x axis pinching works 

52. [FIXED] Thinking about adding a small todo for each marker, so user knows what they need to add before placing marker, this could be done in the same place the setup info box is located under the chart info box, could use same UI, and show a simple checklist that updates as user adds the required options - question for question amrker, poll options for poll etc... could also recommend say a support or resistance lines for analysis, etc... make it a useful box







53. [FIXED] I think there is too much info for setup marker on chart, so will remove the setup info box, just leaving the checklist box

54. [FIXED] Checklist box needs higher opacity or blur background can see the horizontal lines behind which is off putting, also in some circumstance the text is being cut off and therefore unreadable, either shorten the text or make it wrap underneath more

55. [FIXED] Review the indicatorsettingview used in default bottom bar for default chart, want to mirror that UI for the placement mode indicator addition, this goes for all indicators and the views presented when adding such as picking indicator values and colors. It needs to mirror exactly as users will be used to using it in default chart and so needs to carry onto this mode. This means when selecting an indicator from list it needs to look exactly the same

56. [FIXED] Looking at point 55 carry this on for the placement mode drawing tab, similar UI and make it easy to edit colors etc... and other options, drawings should be selectable from clicking entire list item box, not text label activate or add etc... TYhis goes for same functionality in indicator tab and timeframe tab

57. [FIXED] when adding support and resistance lines from drawing needs to mirror the current lines we use for take profit and stop loss, same price indicator box and drag handles etc... except with different color

58. [FIXED] When adding patterns such as trendlines it works well making the two points but should be able to jump from point to point by tapping to remove it, and when clicking outside of it the line disappears rather than remaining. Also should have edit button for color changing.

59. [FIXED] in placement mode the bottom bar general tab icon needs bigger marker avatar and larger marker name, can have smaller username. Also still need to remove confidence section

60. [FIXED] In placement mode need to change bottom bar chat tab icon to same icon used in chart chat bottom bar tab icon - circular not rectangularchat bubble

61. [FIXED] Have a look at all sub tab sections in the app, not the bottom bar tabs, the sections within them that have collapsible tabs for text and icons. In the placement marker mode you have made these sub tabs non collapsible so the text always shows as well as the icon. I prefer this look so convert all other tab sections in the app like this conform to same rule, always show text and icon

62. [FIXED]  Noticed when adding a analysis marker, i didnt add any horizontal lines, but when placed and went to viewing mode a support and a resistance line appeared, also in components tab showed 3 total but 0 for indicators, drawings and timeframes

63. [FIXED] Look at the chat section in main chart symbol, i like the UI on that so want to carry that forward for the marker chat and make it the same. Obviously the header section to it could be adapted to maybe the marker name, avatar and posting user details etc...

64. [FIXED] I think in marker viewing mode we could add a info box on left similar to the info box for marker checklist in placement mode, except we could display the absolute relevant information for that marker, for instance with a poll marker show the question and options and allow user to select from there. With a question marker display the question, for alert display the description/reasoning etc... dont need it for reaction, setup could display vital information, analysis could display main indicator or a list of active indicators/patterns etc... News could say a brief description of the news alert - either a title of news story or similar. Whatever looks and works best

65. [FIXED] Noticed the marker settings button in main chart bottom bar marker selection sheet doesnt work. When tapping it it does nothing


66. Want to change the icons for markers to a better selection, these will come from sf symbols and want to user them in palette mode, so we can use multiple colors, need to make sure we setup a color paletter for each marker intent so the icons run with multiple colors to match the marker theme, here is the list
	Setup - gearshape.arrow.trianglehead.2.clockwise.rotate.90
	Analysis - waveform.path.ecg.magnifyingglass
	Alert - 
		Critical - exclamationmark.octagan.fill	
		Severe - info.triangle.fill
		Warning - exclamationmark.shield.fill
		Informational - info.circle.fill
	News - news.fill
	Question - questionmark.message
	Poll - chart.bar.fill
	Reaction - face.smiling
	Personal - person.badge.shield.checkmark.fill


67. Want to change the look/UI of the markers, this is critical to get right as they are vital, not feeling the look of them at the moment. Really like the look of the markers in the apple ios weather app, has a nice unique but generic look allowing for subtle color differences by using the palette color feature of the icons, so we can match the unique marker color subtlely in the marker. Ideally i want the marker to have a thicker white border, then the background can be a set/fixed gradient color of #000127 and #111111, which are both set in the assets, this gradient needs to be in a diagonal angle, not vertical or horizontal. The icon needs to be a good size filling most of the space in the marker, ideally white and where available in the sfsymbol icon having accent of the marker unique color. Im happy for certain markers the border to be the unique color, maybe give that a go to see how it looks, but it needs to be a dark color not bright. If possible i want the border to move to a point in the direction towards the chart, so if marker is below the chart the point is on top and visa versa. This is only for the first marker in the candle stack, if there are others in the stack on the same side the other markers are just plain circles. Very important to get this to look good, needs to be professional but also easy to look at if that makes sense, this will be viewed a lot

68. Still showing confidence rating in viewing marker mode, need to remove

69. for poll marker if answer selected in chart need to make sure answer turns blue in general marker tab

70. in placement mode the indicators are still not showing the same settings sheet when adding, for instance when adding ema in default chart it shows a sheet to choose ema value and to choose colors, we dont do this in marker placement mode

71. Remove the main indicator star icon/feature, dont need that, user adds what they like doesnt matter one being more important than the other, better to simplify

72. Tab button in bottom bar need adjusting, again like markers would be good to use sfsymbols and the palette feature to mix colors
	indicator tab - chart.line.uptrend.xyaxis.circle
	drawing tab - pencil.circle
	timeframe tab - clock.circle
	place marker button - target (Need to increase size)

73. Need to make the checklist box thinner, its too wide going into the chart, wondering if we should set at bottom left of chart. Maybe add a small handle to collapse to just icons and be abel to reopen

74. in relation to point 67, need to remove the text label below marker when placing them, dont need that, also marker needs to scale up to its viewing mode size when placing it

75. In relation to point 67, need to make sure any part of the app that displays a marker as a avatar etc... now shows this new marker look and to the correct scale