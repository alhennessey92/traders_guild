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


66. [FIXED] Want to change the icons for markers to a better selection, these will come from sf symbols and want to user them in palette mode, so we can use multiple colors, need to make sure we setup a color paletter for each marker intent so the icons run with multiple colors to match the marker theme, here is the list
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


67. [FIXED] Want to change the look/UI of the markers, this is critical to get right as they are vital, not feeling the look of them at the moment. Really like the look of the markers in the apple ios weather app, has a nice unique but generic look allowing for subtle color differences by using the palette color feature of the icons, so we can match the unique marker color subtlely in the marker. Ideally i want the marker to have a thicker white border, then the background can be a set/fixed gradient color of #000127 and #111111, which are both set in the assets, this gradient needs to be in a diagonal angle, not vertical or horizontal. The icon needs to be a good size filling most of the space in the marker, ideally white and where available in the sfsymbol icon having accent of the marker unique color. Im happy for certain markers the border to be the unique color, maybe give that a go to see how it looks, but it needs to be a dark color not bright. If possible i want the border to move to a point in the direction towards the chart, so if marker is below the chart the point is on top and visa versa. This is only for the first marker in the candle stack, if there are others in the stack on the same side the other markers are just plain circles. Very important to get this to look good, needs to be professional but also easy to look at if that makes sense, this will be viewed a lot

68. [FIXED] Still showing confidence rating in viewing marker mode, need to remove

69. [FIXED] for poll marker if answer selected in chart need to make sure answer turns blue in general marker tab

70. [FIXED] in placement mode the indicators are still not showing the same settings sheet when adding, for instance when adding ema in default chart it shows a sheet to choose ema value and to choose colors, we dont do this in marker placement mode

71. [FIXED] Remove the main indicator star icon/feature, dont need that, user adds what they like doesnt matter one being more important than the other, better to simplify

72. [FIXED] Tab button in bottom bar need adjusting, again like markers would be good to use sfsymbols and the palette feature to mix colors
	indicator tab - chart.line.uptrend.xyaxis.circle
	drawing tab - pencil.circle
	timeframe tab - clock.circle
	place marker button - target (Need to increase size)

73. [FIXED] Need to make the checklist box thinner, its too wide going into the chart, wondering if we should set at bottom left of chart. Maybe add a small handle to collapse to just icons and be abel to reopen

74. [FIXED] in relation to point 67, need to remove the text label below marker when placing them, dont need that, also marker needs to scale up to its viewing mode size when placing it

75. [FIXED] In relation to point 67, need to make sure any part of the app that displays a marker as a avatar etc... now shows this new marker look and to the correct scale





76. [FIXED] Chart settings need to include marker distance and distance between them etc...

77. [FIXED] Indicator panels in all views need to use default x axis style and conform better to y axis style, text is appearing too small

78. [FIXED] Need to make sure all marker looks are consistent, different look from placing mode to viewing mode and placed in chart. For instance the analysis marker looks great in placement mode but when set on chart and in viewing mode look boring, needs to conform exactly to the placement mode, so all markers are FULLY consistent from placement mode -> chart -> viewing mode -> to all other references throughout the app, must always look identical

79. [FIXED] Marker points need to be filled and borders need to be full opacity so maybe make colored darker if needed

80. [FIXED] Marker viewing mode info box should be at bottom like checklist and can extend further out maybe even full width but make easy to collapse to the left not up and down, needs to be horizontal collapsible and make more emphasis on the marker info such as question for question marker, poll options for poll etc...

81. [FIXED] Checklist info box needs to collapse horizontally not vertically like the marker info box 

82. [FIXED] In marker viewing mode move like button to far right and general tab left

83. [FIXED] In marker placement mode and viewing mode the general tab with marker avatar, name etc must conform to same style and ui look as symbol details tab in default chart bottom bar, keep it nice and clean

84. [FIXED] In default chart mode the bottom chart buttons (day date, marker visibility, latest, settings) hug too close to indicator panel when active

85. [FIXED] In marker placement mode the checklist box is too low, needs to sit above the x axis currently over it 

86. [FIXED] In marker placement mode the icons in the bottom bar for indicators, drawing and timeframes need to be larger to fit the button, also think the colors of them three need to stay white as they are a generic option for them marker, all tab buttons in bottom bar need to conform to a single sizing and style, must all be consistent

87. [FIXED] Make sure absolutely no lines, drawings, annotations or indicators or anything overlay markers, markers always have top z index priority

88. [FIXED] Like button for markers needs to have better UI, a state for liked and not yet liked, look at ui for blocking a user, similar to that

89. [FIXED] When viewing a marker need to adapt the ui for toolbar at the top, cancel button is fine but need to remove the viewing marker and show a ui displaying marker avatar same size as cancel button and name of marker next to it, in bold making it prominent

90. [FIXED] When viewing a marker adapt the marker info box to show user details for who posted it including their avatar, username, basic details like role, reputation and accuracy like we normally do in other parts of the app, if possible when clicking users avatar or username open profile detail view. that way we show user details and then the marker relevant info underneath it, all being collapsible to the left (look at other points)




91. [FIXED] Need a full audit and upgrade to marker looks, this applies to each individual marker including their placement mode, viewing mode, chart mode and avatar mode(When viewed in another view like top marker tab etc...)
	Ideally they should all have the same design, a 2-4px border that is light in color to contrast the background, maybe something like #787878. Then the inner background to the marker should be of linear gradient look on a 45 degree angle using colors like #1B1A1F and #000000. 
	There needs to be a point on the first marker in the stack pointing to the chart, so if below chart points up, if marker is above chart it points down. Make it not too big but noticeable and needs to be full i.e. not hollow in color and color must match border color to make it all look as one. If there is another marker in the stack then there is no point for that marker.
	In terms of icons for the markers they are as follows:

	Setup - gearshape.arrow.trianglehead.2.clockwise.rotate.90 green
	Analysis - waveform.path.ecg.magnifyingglass blue
	Alert - 
		Critical - exclamationmark.octagan.fill	 - accent color red
		Severe - info.triangle.fill - accent color orange
		Warning - exclamationmark.shield.fill - accent color yellow
		Informational - info.circle.fill - accent color blue
	News - newspaper.fill - accent color magenta
	Question - questionmark.circle.dashed - accent color blue
	Poll - list.bullet.clipboard - accent color purple
	Reaction - face.smiling - accent color gold
	Personal - person.badge.shield.checkmark.fill - accent color black/grey

	All should be in #D9D9D9 color but you need apply the icons from sfsymbols in palette mode so we can adjust certain parts of the icon in the markers accent color. I havent listed the accent colors specifically so choose a nice color that fits well, this must be carried across the UI for the marker placement and viewing mode to make it feel professional where necessary.

	It is vital that the markers look identical in all aspects they appear and the icons are scaled accordingly to take up the correct space in the marker, if possible work out a way to make them always appear correct, no matte the scale, the icons must look "Full" in the marker, not to the edges but look dominant in the marker

92. [FIXED] I think the marker is still not right, going to attempt another look, how about we change the marker to act more like the glass buttons we use for example in the current toolbar for left and right drawer / cancel button when in viewing mode. I like the UI and functionality of it when tapping etc... Would be good and more right to stick to a proper ios design of using the buttons as the base of the marker and then overlay the correct icons on top. If possible lets have a go at doing that, because of this i dont think its necessary or possible to add the anchor point in direction of chart, lets just stick to full circle at the moment. I like the sizing of the cancel button we currently use un top toolbar in marker viewing mode as standard marker size and obviously increase on select etc...

93. [FIXED] Markers when placed in chart are still not showing correctly, mainly the icons, the colors are off, either being semi overlapped with white where they should be accent color etc... everywhere else seems fine, just when showing in chart. 

94. [FIXED] Icons in the marker need to be more scale aware, the icons look fine most places but specifically in toolbar the icon is too big, also certain icons like news, poll and personal are too big in the marker.

95. [FIXED] When looking at the general tab in placement mode and more specifically in viewing mode the tab button doesnt look right, it should mirror the look of the symbol tab button in default chart mode, where the marker icon should fit perfectly the capsule height etc like the symbol icon as its round - in the placmeent mode and more the viewing mode the marker avatar is too small, also the placement mode the text should be just the marker type and word marker under neath, so it would say "Alert Marker". In viewin mode it says the right stuff but needs more padding and text style to suit like the symbol tab button.

96. [FIXED] In viewing mode we need to copy same layout as the default chart bottom bar, buttons should sit to the right other than the general tab which sits to the left and is allowed more space/padding. The like button needs to look the same as the block button in the user profile detail view, its a red button to symbolise a like so look at that.

97. [FIXED] When placing a marker, it doesnt always register the starting placement of marker as its required position set, you have to move it a little to get it to register and allow placement. When placing sometimes it doesnt attach it to correct candle, sometimes a candle a few spaces away. Actually finding that it is ignoring where you move the amrker to, it anchors it on starting point

98. [FIXED] Marker info box needs its opacity removed for background or severaly reduced so you cant see anything or very little bhind, maybe even blur it and it needs to strech all the way across chart when open to the start of the y axis, and have a larger handle in right side to expand and contract it. The inner contents need a better style as well, making it easy to see the content in a clean simple way such as poll options, question in question amrker etc... have a look at the image uploaded, its a much cleaner example of a UI i think could work well. also look at no 104 as this affects marker info box

99. [FIXED] Chart symbol info box again still showing content of chart behind it, needs an opaque background or blur to hide chart content

100. [FIXED] Markers are appearing over the x and y axis when panning, 

101. [FIXED] Need to reduce y axis width a little, maybe reduce value by 1 point if necessary

102. [FIXED] the marker like button in the bottom bar needs to use a thumbs up, not heart and needs to show no of likes

103. [FIXED] in marker viewing mode the marker avatar in toolbar needs to be bigger, and also saying marker after name, like setup marker

104. [FIXED] in marker viewing mode add toolbar button at top right based on posting user, including their avatar - username and basic details underneath (reputation, role, accuracy) like normal user display, Style in standard toolbar glass look and base it how the symbol tab button in bottom bar is displayed. Because of yhis you can remove the posting user details in the marker info box on chart

105. [FIXED] look at marker chat section, + button doesnt work, nor does the microphone, and when tapping textbox its hidden by keyboard, needs to all wokr like other chat areas

106. [FIXED] When adding indicators in marker placement mode the UI is still not exactly the same as for when adding markers in normal default chart mode, there is a + button etc, whereas in normal mode it is a circle, need to make sure that these UI elements are the same to keep consistency

107. [FIXED] Still need to add the like No in like button in bottom bar in marker viewing mode and make it look better, perhaps white icon and no

108. [FIXED] In marker viewing mode the user profile button in toolbar on right needs adjusting, looks weird at the moment, perhaps just show the avatar, in a glass button look to mimick the cancel button on right, could give it a special tint or border like white or light blue etc...

109. [FIXED] In marker viewing mode the marker info box on chart needs better UI, its too black, needs to be aligned with UI in profile detail view etc with better heading and better UI display that is coherent with rest of the app. The close handle needs to be a thin vertical rectangle in white with black or similar arrow icon on the right side of the rectangle indicating it closes the info box, and similar to re open

110. [FIXED] In marker viewing mode the general tab needs a better UI, more interesting a bit like the symbol tab in main chart, with a seperate section at bottom showing basics of user posting it that also links to their account. In terms of sections needs to be top section basic info about the marker as it is but improved, then unique information relating to marker, then general information regarding the marker, then general info regarding the symbol at time of marker placement, then a section for information about posting user.

110. [FIXED] the symbol info box on top left is ok but still the background is too dark, needs a more subtle look, while still being MOSTLY opaque, can have a little seethrough

111. [FIXED] Need a full review of marker looks when in chart, they look good sizing wise etc, but the icons are still appearing white, they need to have the same palette multi color look as when in placement mode  and all other areas of app they appear as avatars, for instance the setup marker has white cog and green arrows, but appears full white in chart. Also the setup icon in when on the chart needs to be slightly bigger, and the alert markers need to make sure they have their tint background and full color icon

112. [FIXED] When changing the alert severity marker in placement mode the background to the top section in general tab is not changing color, stays the same






113. [FIXED] Symbol list item in watchlist in bottom bar symbol tab has letter wrapping for the extra views such as hot, oanda etc, they re not appearing correct unlike their counterpart in top section which does look good.

114. [FIXED] When selecting a drawing from the drawing tab in marker placement mode, needs to minimise the sheet to allow user to immediately begin placing a point, think also for drawings we should also auto collapse the checklist info box to give more space. Also think we need to guide users through the process of adding the drawing other wise it can get quite confusing, think we should do this in the toolbar. So for instance with the trendline the toolbar should say "Draw a Trendline - Place first point on chart" or similar then "drag line or place second dot" etc... The guide needs to follow the process of placing the drawing on chart and i will outline the process below for each drawing as they are currently not working correctly, at the moment you cant get out of drawing mode, you should be able to by clicking on the chart. We should also display a rubbish icon or similar in toolbar allwoing to exit drawing mode and remove the drawing
	Trendline: Rather than clicking a point to place first point to start trendline, should move a crosshair to first point, then click anywhere on chart to set, then move second crosshair to next point and click anywhere to set. After this the line is created and shows 2 semi large circles at each point - which is in drawing viewing mode also available when clicking a drawing from chart, allowing to drag the points around individually to reset position, when dragging a point that point shows a crosshair displaying price and time values in respective axis. At this point by clicking somewhere on the chart saves drawing in state on chart and exits back to marker placement mode. Viewing mode is only available in placment marker mode. Once set cant do anything by clicking drawing in chart. Can edit colors and line style

	Horizontal line: is just a generic line that doesnt allow point movement, just position on chart vertically, being able to be dragged up and down, edit color and edit text on y axis placeholder "Support" or "Low Level" etc...

	Support / Resistance levels: Like horizontal line just drag up and down and edit color/liny type etc... but not placeholder working

	Zone: Similar to trendline, using crosshairs place both points, once set can re adjust points by dragging them individually, clicking outside of popints on chart exits drawing mode and saves drawing, can edit colors 

	Quick add zone: nice, but once selecting can drag points like in zone, when click outside saves the drawing and exits drawing mode

	Annotation/note: Needs to look better UI wise on screen, when selecting in sheet opens keyboard to set annotation, submit button adds to chart, user can drag around, edit, color, size of writing etc... Selecting outside of it saves and exits drawing mode, selecting again shows Ui wise its been selected

	Emoji: On selection adds to chart, can drag and can resize it by gesture pinching to enlarge/smaller etc... clicking outside of it exits drawing mode

These are all the steps to the current drawings, need to make sure its vital, once set clicking outside of a selected drawing exits the drawing mode so users can interact with chart, when in drawing mode and say have a trendline selected, user should be able to still pan around and pinch to zoom etc without affecting trendline, trendline or other drawings only react when selecting/dragging them specifically from their positions.

115. [FIXED] Want to play with the idea of making the y axis background similar to the toolbar header background that has the same color as the chart, but acts as a mask so content disappears with a blur, have a look how the toolbar is on the chart and see if you can mimick it for the y axis. Remember the chart background is a linear gradient of 2 colors so lighter at the bottom, you may need to take this in consideration with the y axis background, or keep it one color


116. [FIXED] Updates needed to drawings
	trendline - once placed and reselecting to move points again, whatever point i click it auto selects the second point only to move, so if i select the first point it selects the second one and resets it to users click location on the first point, making it impossible to move the first point, also clicking outside of it to save trendline is sometimes tricky 
	
	horizontal line - looks like a small trendline currently, should look like a support/resistance line, but allow custom text for price indicator bar - also needs custom text for guide. Need to make sure it looks exactly like a support or resistance line with same handle, line, price indicator etc...

	support/resistance line - need to make sure delete/rubbish button exists to cancel it . also not appearing in active tab

	zone - should mirror process as trendline - showing crosshairs to place points so users can see price and time, and again can only select second point. also allows dragging from seelcting anywhere in zone - should only be from points. also hard to make it save by clikcing chart

	auto zone - same issue as dragging from anywhere inside the zone. also hard to make it save by tapping chart

	annotations - when tapping annotation button should close sheet and show annotation on chart

	emoji - when in drawing mode lock chart and allow pinch gesture to scale emoji, tap on chart to save.

	General - absolutely make sure that at any point in any drawing - tapping the chart saves the drawing and exits drawing mode. and make sure all drawings appear in active tab. Need to make it apparent that when a point of bar is selected it look difffernt in a selection state

117. Need to review the state machine is working for any setup markers to make sure they are being updated as the chart moves past take profits and stop losses to provide details on setup trade outcome annd if tracked any reputation gained etc... Also feel that when viewing setup in marker viewing mode we display outcome and current details on setup trade in the general tab and in the details view on chart

118. [FIXED] Sometimes when viewing a marker it doesnt center on the marker but on the candle its connected to, happens more on stacked markers

119. When pinching chart for zoom, the markers sometimes start overlapping, they should never get to the point of overlapping, the minimum basic distance is a few points between them, users can extend this in settings but never allow to overlap

120. [FIXED] When viewing profile in marker viewing mode, allows chat button for current user, which cant happen that ui should display current user buttons like in current user profile view

121. [FIXED] Markers on chart are still overlaying the symbol info box and x axis. and in marker viewing mode they are overlaying the marker info box on chart. Markers shouldnt be above any main elements of the chart


122. [FIXED] Alert needs to be neutral color until selected

123. [FIXED] Panning smoother very jittery in marker viewing mode

124. [FIXED] Weird jump in n pinch zoom on chart

125. [FIXED] Sometimes place marker keeps in placement mode doesn’t go to default chart view

126. [FIXED] Need to copy indicator ui for markers more and drawing adding custom sheet etc

127. [FIXED] Edit button for personal markers to jump back into placement mode, can’t move the marker but can edit indicators and drawings

128. [FIXED] Like marker button unliked state needs same outline color as tab buttons more light greyish

129. [FIXED] Markers overlay price indicators

130. [FIXED] In marker viewing mode shows 4 components in general tab but there are none set in components or on marker actual 

131. [FIXED] Reduce width of price indicator and make tp/sl entry bold . Maybe add a slight pattern overlay like static background 

132. [FIXED] Chart buttons still sit too high when a indicator panel is active 

133. [FIXED] Still not seeing any edit button on marker select to edit the marker

134. [FIXED] In chart symbol info box need to move the timeframe to second line next to provider name to be able to reduce the width of the box. Also background needs to be more opaque but keep background similar if not the same to chart background

135. [FIXED] When adding any form of text in the requirements or general section of marker placement mode need a button next or inside each textbox that saves the text, at the moment only way to do this and close the keyboard is to select outside the textbox, but this is a little unintuitive, so need a simple way to allow users to do this.

136. [FIXED] When initially entering the marker placement mode the markers position follows the users center of screen until they first move the marker to a new position of which it then is fixed to that position, this looks a little weird when panning around, marker should have its intial position as if its been placed there by user so we dont get this following center of screen effect, user can then move as they desire

137. [FIXED] Need to look into the state machine that controls outcome of the setup marker, so we can properly track results, even if the server goes offline so almost need to check when retrieving the marker each time that a value has been set for finalised outcome, listing results of the setup mock trade, and for if its tracked, the reputation gain and loss. Also need to update the marker info box to display this result and more/ better UI for the result in general tab of marker

138. [FIXED] Need to look into timeframe section of markers. At the moment we just link other timeframes, but this is not benefitial to users, what would be benefitial is seeing a panel on chart like an indicator panel that shows a relative time state of the timeframe chart for the symbol, relative to the chart position, in a way showing their correlation, obviously when the user is viewing a 1 min timeframe with marker and links to a 1 day timeframe the time frame wont mov at all, but we could do it where it doesnt pan with the chart, shows a snapshot of the timeframe chart with an indicator of the marker position timewise in that timeframe chart, so the user can see its position in that timeframe. This panel should allow pinch gesture and independent panning. Need to make panels similar looking to indicator panel, maybe with their own axis etc... and make them collapsible to allow fitment with other indicator panels. SHould be allowed 2 timeframe panels and 2 indicator panels on chart. The timeframe panel should be viewable on chart and in the timeframe sheet in bottom bar

139. [FIXED] Need like No next to thumbs up icon in bottom bar like button for markers

140. [FIXED] UI for attahcement buttons need to be improved, dont like the coloring, need to be more inline wioth our own UI. Also the icon for markers is wrong, use the target icon like used in marker placement button

141. When creating guild need to label which values are required to create guild, also need dropdown of different languages, and location should be dropdown of different countries

142. [FIXED] When adding a poll marker and add questuon with answers, when viewing in viewing mode, shows no question in general tab - no poll question and no question in marker info box



144. [FIXED] May combine Indicator, drawing and timeframe buttons/sections in bottom bar in marker placement mode into single screen/button with sub tabs for each section, this can mirror in the marker viewing mode to make it look identical, this way all components are int he same space, and give more space for the general tab to extend and show full marker name. Because of this we can remove the active tabs in each section and create one single components active tab for all components together that are active, will be easier to view. Use icon plus.viewfinder for main bottom bar tab icon

145. Marker in placement mode too far from chart, can be closer

146. [FIXED] Checklist info box needs same UI as marker info box with same handle

147. [FIXED] Color style for poll answer in marker info box is different to color in general tab, needs to be the same

148. [FIXED] Looking at point 144 once it is implemented need to adapt the indicator bottom bar section to be similar, allowing users to place drawings in chart like when placing a marker - this is for their default chart

149. [FIXED] Add button in marker placement mode in new components tab that uses current chart setup mirrored to marker, so users viewing marker will see their current components setup, indicators, drawings etc... This basically takes the users current on chart indicators and drawings and sets them contextually to the marker being placed

150. [FIXED] Looking at sub tabs in sections not the main tabs in bottom bar, the sub tabs in each section, the coloring is off, first layer the main layer needs to be the standard blue, then next hierarchical layer down another color and so on, this needs to be throughout the app so first layer is blue, second layer maybe dark blue etc... whatever neutral colors that are the same throughout

151. [FIXED] crosshair price indicator above x axis

152. [FIXED] Need all panels to be collapsible and say the name with handle to re open - or just drag to show only top panel bar


153. [FIXED] When displaying question in marker info box need to increase its size a little to make it more apparent. A bit too small at the moment. Same can be said for poll marker, question appears a bit too small

154. [FIXED] Copy chart setup doesn’t work or do anything in marker placement mode

155. [FIXED] When editing shows marker as ghost and new marker above it, even though cant change position of marker which is good, can still move this new marker around which is off putting and not correct

156. [FIXED] In marker placement mode the add components button needs to move to the right so general tab can have more width padding

157. [FIXED] In marker placement mode all components tabs need to move down a bit have title header of add compoents, any sub tabs appear under main tabs and under all that is the mirror chart button so:
	Add Components header
	Tabs for active, indicator etc
	Sub tabs relative to above tabs
	Mirror chart setup button
	Content
	In that order


158. [FIXED] Time indicator needs to be darker blue/grey no opacity and move up a little bit so runs cleanly in x axis

159. [FIXED] Marker info box can move down a little so maybe 5px from top of x axis and then subsequently 5 px from top of any panel on screen 

160. [FIXED] When collapsing panels in chart they cover the x axis and need slightly more pronounced border. Also chart button on bottom sit too high from panel

161. [FIXED] Panels being added to chart need to be added to the chart info box. Ema gets added correctly but just added rsi and macd panels and neither were added. Need a review of components on chart so user can see all added components in the chart info box.

162. [FIXED] Need a toggle for panel indicators on main chart for active state like ema does

163. [FIXED] Need to review indicators and drawing sections for markers and default chart. They should both look and work identical, ideally from a unified indicator and drawing section so they work on marker section and default chart section. Due to this, on default chart view need to update indicator bottom bar section to be updated to the component section like when adding markers,  combining indicators and now drawings for adding to default chart. Obviously we dont want timeframes at the moment but maybe in the future. Basically my idea is that they work the same for users default chart to adding markers so user see a identical ui and functionality when adding components as i call them now, same sub tab section of indicators and drawings etc... would be good if it could all derive from the same part - a unified indicator/drawing component system

164. [FIXED] Panel background needs to be slightly less dark more aligned with bottom gradient color of main chart 

165. [FIXED] Like button for markers - on like background should go red 

166. [FIXED] Guild reputation breakdown showing weird screen when no data need placeholder, similar to guild accuracy

167. [FIXED] Need a full audit of the owner, admin and moderator panel to bring it more into line with the rest of the UI in the app. This includes headers, text boxes, buttons etc
This also includes making sure requirements are shown for any form, highlighting areas users need to fill to complete the form.



170. [FIXED] Need to audit all sub tab sections of the app . Looking at sub tabs in sections not the main tabs in bottom bar, the sub tabs in each section, the coloring is off, first layer the main layer needs to be the standard blue, then next hierarchical layer down another color and so on, this needs to be throughout the app so first layer is blue, second layer maybe dark blue etc... whatever neutral colors that are the same throughout. Make it look nice but consistent across the app. This is mostly done but want to make sure the color scheme is good and cant be improved, each layer of the sub tabs should have a slightly different shade.

171. [FIXED] Need to make sure in marker palcement section any options that are required in the general tab have a small req text or similar to symbolise they are a required part of the marker to be placed

172. [FIXED] Not really sure on the UI/style of the guild reputaiton and accuracy in profile view and reputation/accuracy sections in global view, for one both sets are different look button/list wise before entering each section and the sections are too dark and not in keeping with rest of app ui

173. [FIXED] Crosshair time indicator still running above the x axis not not it, and needs a better color, for its entire use throuhgout the app, to make it more readable

174. [FIXED] crosshair time indicator resorting back to old look when panel is active, need to check this



143. [FIXED] Lines need a little more work in marker placement mode, when adding support/resistance lines, shouldnt be able to move them by tapping on chart, only movable by dragging, tapping the chart moves out of line editing mode, same for horizontal line, should have a drag handle like support and resistance and tapping chart exits line editing mode. Have to click line again to show handle and drag. Also whe viewing them in marker viewing mode the support indicator and resistance indicator are getting lost on the right side so you cant see the prices, they should extend out into the chart, same for horizontal line, it doesnt show the price indicator at all, should extend from right of screen out left into chart. Should be a character cap on title for horizontal line, so its not craxy long, maybe 10-15 max



177. [FIXED] The big one. Need to review the drawing/ pattern section of the app. Currently not working great, needs to be a super smooth experience that is intuitive to the user to complete the process of adding a drawing or pattern.

Process for most drawings is as follows
On selecting drawing to add, a crosshair is shown with price and time labels on respective axis, user drags this to first position, can drag from any drag position on chart, chart is locked in this state
User then taps the screen anywhere to set it and activate next point/crosshair
User then drags again from anywhere and the crosshair moves with line/zone attached.
User taps anywhere to set. 
At this point the process continues for how many points the drawing requires, mostly 2. Once all points are set the drawing mode deactivates and the drawing is set in its locked position allowing chart to be moved/panned again
If user taps the drawing, circles appear at each point which can be dragged individually to move them to any position and adjust drawing.
If user taps anywhere on chart the drawing mode deactivates and the chart is free to move
At no point by tapping the chart does the point/drawing move to that position, tapping the chart is only ever to save/set the drawing point
Make sure you run through all drawing options and make improve them the way they should, obviously the above affects trendlines, zones etc... Horizontal lines like the custom one, support and resistance, works like any other horizontal line we have in place, user can drag vertically with handle and tapping the chart saves in position. Annotations get added to chart, can drag around and tapping chart saves them

178. [FIXED] alert marker needs select severity as required and vertical line same color as severity.

179. [FIXED] bottom x axis time indicator needs generalising for when markers selected, crosshairs etc. Like the price indicator has a generic yellow box black writing, the x axis needs a generic look for gneeral situations, thinking white or grey with black writing, something generic but easy to view, its height needs to be generalised as well, top of rectangle should run at top of x axis. Can also remove the little triangle if still present

180. [FIXED] drawings added to chart need to be added to the chart info box and need to be carried over/available to be added to markers via the mirror chart setup

181. [FIXED] drawings not being carried across and available to add to markers for mirror chart setup button in marker placmeent mode. However when i add a marker and select it to go into the viewing mode the drawings fromt the default chart still appear and are editable

182. [FIXED] Need some form of UI on screen while drawings are selected to edit them - color, delete, adjust text, perhaps we could run it along the bottom, just above the x axis in a fixed width box like the marker info box, but not that high, just high enough to show icons etc... and dont allow it to be collapsible, it could hold the icons to adjust the coloring, line type, delete button, text button etc... for all types of drawings, only shows when drawing selected.

183. [FIXED] Due to now no 182 i think the checklist should be move to under the chart info box on top left, and try to reduce its width further removing the req and tim sections and incorporating required state into the icons on left, maybe give a yellow alert warning for required or similar. In terms of the marker info box, i think it too needs to go under the chart info box, still allowing the collapse handle, and obviously needs to be greatly reduced in width

184. [FIXED] the marker info box needs to be lower in the chart, closer to the top of the x axis

185. [FIXED] the background for the chart info box needs to be similar to background of the toolbar

186. [FIXED] Drawings are appearing over the y and x axis

187. [FIXED] when adding trendline its adding a blue price indicator label on y axis with anchor icon over the top of the yellow price indicator, this is not needed.

188. [FIXED] Horizontal line, support line and resistance line dont extend full to y axis, label/price indicator is sitting slightly over the edge on right, price indicator could be a bit bigger, support/resistance should have default color of purple/red respectively, horizontal line default color of grey

189. [FIXED] text note and emoji options should look same and act same as options in zones and lines sections.

190. [FIXED] Emoji option should just show emoji options in edit box, sothing else and shouldnt have border round it in chart

191. [FIXED] Time indicator in x axis sitting slightly too high still needs to drop a little

192. [FIXED] Theres a bug of sometimes when adding a timeframe the header doesnt appear and it looks a bit messed up, only as high as when collapsed but with no header, the timeframe chart is below the timeframe x axis and all sitting over the main x axis, cant do anything with it only delete from active tab.

193. [FIXED] Sometimes adding a timeframe in marker carries over to default chart, which it shouldnt

194. Need to make the timeframe panel move with the user relative to their marker if timeframe set with marker or center of screen if in default chart. For marker timeframe this is easy as the marker is set and user can pan horizontally to see timeframe candles. If its default chart then need to mark screen center relative on timeframe panel, and as user panns the main chart the marker point moves in timeframe chart.



197. [FIXED] Updating chart info box with components is sluggish, can take a bit or different actions in other sections for it to update if component removed from chart

175. [FIXED] Need to show direction of latest candle in y axis when out of scope, so user can see which direction it is in

176. [FIXED] Need a full audit again of the chat system, making sure all options, edits, settings, are in place and working. Want to introduce a like option / emoji reaction to chat messages, and a option to reference someones message like a reply that displays it like a caption with their own message. All of this can come from long pressing the message and choosing options, so need a better UI for it. Also need a major revamp of the attachments section, better UI/styling for each option and a much better process in applying, feels very disjointed and tricky to attach a image with a caption, camera doesnt work etc... Also images being added to the chat need their background/container message view to be the size of the image, almost like a small border round it, at the moment the image is there but theres a lot of space around it that looks bad, so it all needs to be nicely contained in the message. When there is a caption on the message as well there needs to be more of a distinguish between them - border or different color etc... make it look good





170. [FIXED] Sometimes a timeframe active on chart is unable to be removed, clicking - red button in active tab does nothing

171. [FIXED] no 175 said about showing direction of latest candle when panning vertically past it, but when panning up the label should show at the bottom signalling the latest candle is below, but its set behind the chart buttons, and needs to be made narrower so only as wide as the y axis - showing in a yellow box like current price label a arrow in direction to latest candle. This needs to also happen the other way around showing at the top of the y axis but not covered by the toolbar.

172. [FIXED] Need to change the y axis background so its similar to the top toolbar background, i want almost a clear background mask that blurs the content behind, however we do this with the top toolbar.

173. [FIXED] Looking at no 176 we already updated the chat interface/functionality but a lot still needs doing and checking. For one, sometimes when selecting the + button for adding attachments i cant cancel/remove the popup option sheet, o should be able to do this via swiping down or tapping the chat background. When long clicking on the message bubble for options sometimes it gets caught in a loop and starts opening and closing infinitely, also the UI for this popup needs improving. When selecting textbox to enter message, its getting hidden by the keyboard, should sit on top of keybaord to see what typing. Likes/emojie reactions on messages dont appear on the mesage, appear off of it in middle of screen. When adding images etc... the image should fit to the bubble so only a small border round it, not a massive amount of the bubble should show. Basically need again a full audit of the chat section to make sure all polished etc...


195. [FIXED] Mirror chart setup doesnt look at timeframe active on chart and mirror to marker palcement. Also when mirroring if emoji is being mirrored it moves when user taps screen so cant get out of emoji placement if you understand me. Sometimes the emoji gets copied over with mirror setup even if deleted from default chart

196. [FIXED] Need some form of line/border at bottom of timeframe and any other panel to distinguish between timeframe x axis and main chart x axis


197. [FIXED] When rotation is on it’s turning the app and then bugging out, need to stop this. App should be fixed at all times in portrait mode 

198. Need to investigate why bottom chat text boxes are jumping when showing keyboard 

199. [FIXED] When adding indicators no longer being shown option box automatically for style and variables etc for each indicator, this happens in both marker placement mode and default chart mode

200. [FIXED] When adding/removing indicator/timeframe in marker placement mode and default chart mode the button acts weird, the transition between added and unadded - linked and unlinked is slow and fades too much making it look weird, needs addressing

201. [FIXED] Need to adjust the emoji section in marker placement mode and emoji section in reactions for chat etc... to display all the default emojis available in a better more concise format, at the moment we only allow a few and they may not be significant. We need all possible emoji options that are available to th user.

202. Need a major review of the authentication and register/login section of the app working out what has been implemented and what is remaining, this goes down to signing up and logging in using alternative options such as apple, google accounts etc... forgetting passwords etc... making sure all relevant authentication such as faceid etc... are all implemented, everything we need for this section fo the app

203. [FIXED] Need to adjust the timeframe panels to show current price when not set for a marker - i.e. set in default chart, so user can see current price marker etc... Could expand this to show vertical pinpoint lines aswell that can be relevant in the timeframe

204. [FIXED] Would be nice if we can allow the timeframe panel to pan like the indicator panels

205. [FIXED] Look to reduce decimal number after most if not all symbols, dont need to go to 5 or 6 decimal place

206. [FIXED] Price indicators need to be reviewed stick too far out into chart especially the main yellow price indicator - look to reduce width padding

207. [FIXED] Y axis needs a review dont like the border, chart background should morph seemlesly into y axis, but obiously content that goes into y axis is hidden/blurred

208. Emoji marker needs its icon changed relative to when its changed, especially real time when changing and same for when editing marker the icon on the chart needs to change realtime

209. When editing a marker the selected marker reverts to a faded out marker like the other markers, it should stay stand out like when selected

210. [FIXED] When editing a marker the place marker button in bottom right needs to change to a green accent look to signal a save button - in accordance with the paletter look multi color

211. [FIXED] Can afford to give more width padding to marker tab bottom left in edit/marker placement mode, only a little

212. [FIXED] May adjust the todays top markers section to just Markers with target icon etc... This allows more scope to add sections for active markers etc... So can now keep the today section but add a sub tab section for all relevant filters for markers of the day - Active, Symbol, friends, mine etc. Then add a active section with green background like in components listing all active markers - again with sub tab headings. Could also have a top section of friends and mine and weekly etc Whatever feels and works best

213. [FIXED] Need to make sure there is a x axis time for most recent candle whatever happens

214. [FIXED] Concerning panels - the draw handle needs to remain center in whatever state, would prefer text to move to the left side and symbolise if it is a timeframe panel, rsi panel etc...with basic settings

215. [FIXED] When adding a zone and trendline drawing, after placing first point if move second point to most recent candle the point springs off to the left and struggle to get back, weird bug i noticed






216. [FIXED] Coming back into the app don’t think we are auto subscribing to live tick for current candle seems to be 1 candle behind and no movement on price indicator. Also noticed when returning to app candles sometimes seem stuck in last candle we saw before leaving. Switching symbols and returning seems to fix it 

217. [FIXED] Also sometimes behind the current candle by 1 candle or quite a bit went on one symbol and was 15 minutes behind, another symbol only 1 candle behind. Need to make sure at all cost we are up to date, it’s vital, even if we show error for not in time would be good to know 


220. [FIXED] Sometimes adding marker doesn’t always place on candle selected in marker placement mode 

221. Still need to make sure the markers are position correctly on the chart. Sometimes appearing underneath when they should appear on top, always make sure markers arent obscuring candles and or other markers

222. [FIXED] Claude - Contact support needs work, ui is rough and functionality not great, keyboard needs to be removable by tapping outside etc, send button not working etc…

223. In settings user online status not always working as it should

224. CODEX - When sending photos in chat they appear only as name, no image is appearing. Do we need to implement file storage on hetzner

225. [FIXED] Dark space under bottom bar and x axis needs extending to bottom

226. [FIXED] Claude - Implement a second theme, lighter, not white but almost a mid grey tone, allow users to switch from the settings

227. [Fixed] Change resend token to be something better, more easier to relay back like a 5 string (7UY67)

228. Need to have a look at timeframe panel, would be nice if they could update in realtime on the chart, including new candles, active candle, moving price indicator (tick)relative to current default chart etc... Also the main chart timeframe panel, still has the vertical marker view/icon on latest candle, this isnt ncessary as we have the window view, its only necessary when used in marker view mode to show where the marker is located





229. [FIXED] need to make sure all components affected by theme such as bottom x axis section, chart info box, panel header background and any other component not yet touched are in accordance with new theme selection (mid grey) need to make it easy to add more themes if we want, so the actual different colors across the app for views are almost a configurable sub set of base color of theme


230. [FIXED] Price indicators like tp and sl not appearing over the y axis

231. Add tabs to announcements and events for relevant sections

232. [Fixed] Support section still needs work need confirmation email etc and place for message to appear. Ui needs work minimum description etc

233. Timeframe panel price indicator not live and very dim

234. [Fixed] Setup marker still not in active tab

235. [FIXED] Need to double check setup marker is correctly being watched for results as it’s not dealing out reputation and not reporting results in marker view mode. Also should fire a notification. In marker view mode should show some sort of result as to how the setup marker performed against the TP and SL

236. [Testing] Notifications need a full audit listing current areas notifications are triggered and areas we need to implement

237. Reputation for personal, guild and global need a full audit. Again listing areas reputation is applied and areas we still need to apply to

238. Need to review user permissions making sure things like user blocks, bans, suspended and muted are all applied to relevant areas and things like caps on chat message (50 per hour) for anti spam are in place and marker placement limits etc

239. Crosshair info box needs proper reporting on indicators like stochs and macd etc

240. Noticed sometimes when interacting with the app the music I am listening to gets paused, this should never happen music shouldn’t be interfered with by the app

241. [FIXED] Find here is the outline for how i want the marker tabs and sections to work in the bottom bar and the left drawer.
	Bottom Bar marker tabs
		Add 
			Prediction
			Trade
			Analysis
			Signals
			Social	

		Markers	
			Active
				Guild
				Friends
				Personal
			Resolved
				Guild
				Friends
				Personal
			All
				Today
					Guild
					Friends
					Personal
				This Week
					Guild
					Friends
					Personal
				This Month
					Guild
					Friends
					Personal

		Analysis (Preferably a universal section for all markers)

	Left Drawer Marker Section
		Today
			Active
				Guild
				Friends
				Personal
			Resolved
				Guild
				Friends
				Personal
			All
				Guild
				Friends
				Personal

		This Week
			Active
				Guild
				Friends
				Personal
			Resolved
				Guild
				Friends
				Personal
			All
				Guild
				Friends
				Personal


		This Month
			Active
				Guild
				Friends
				Personal
			Resolved
				Guild
				Friends
				Personal
			All
				Guild
				Friends
				Personal


242. [Fixed] Init message in each chat room creation

243. [Fixed] No welcome notification on seeded account - Never got a welcome notification for joinging traders guild /joining initial guild

244. [Fixed] No initial guild announcement for onboarding guild - need a generic announcement for welcoming guild creation. System generated fairly univeral among guilds

245. [Fixed] Panel sometimes gets into a state of appearing above and below x axis and header is removed so can’t interact with it. some panels also overlaying each other when in this state. Only happens periodically when adding micture of timeframe and indicator panels so not sure

246. [Fixed] No notification on setup loss and no negative reputation awarded/ global/personal/guild accuracy and reputation affected. Actually need to remove negative reputation on loss just affect accuracy

247. [Fixed] Notification on sl hit needs to be red border for sl and getting missing marker context when tapping to go to marker

248. [Fixed] Need network error toast when network drop

249. [Fixed] Timeframe panel needs to appear in top chart info box and certain indicators like stochastics only show a single color and value in info box yet are represented by 2 values, need to make sure these are all accounted for

250. Marker detail view can be adapted, need to remove title in marker placement mode, so only emphasis on description. In marker detail view - remove requirements header and leave top box as specifics to marker (question, poll, setup info etc...) Make the box a slightly different color so it stands out - make general, symbol and author info disclosure like symbol details in bottom bar symbol info. With slightly more simple ui design - not soo many boxes etc... but keep relevant info

251. Review all setup tp - sl scale visual indicating swing of current price to sl and tp. Make sure all references and implementations of it in marker list views in left drawer, bottom bar marker section, marker detail view and marker info chart box all have same if not similar design and functionality. Need to double check they all work as should, noticed a couple where current swing was different to chart price levels

252. In marker section in left drawer the timeframe pill needs to be moved next to the symbol name, before the YOU pill, so it always stays there. Also in same list views for markers need to make sure we dedicate a detail section for specifics to the marker - with slightly darker background, this could be question, alert status, setup amrker swing graphic, poll standings etc... make it look visually inline with how it looks in the marker info box on chart. In setup marker because the timeframe pill is moved, can move the live pill next to the active/tracking pill - make sure bottom bar marker section conforms to this new look for list view markers and also profile references showing markers and anywhere else that shows similar list view markers