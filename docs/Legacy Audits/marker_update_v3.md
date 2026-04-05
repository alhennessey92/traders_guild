

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
















<!-- MARKER UPDATE V3


Ok the preliminary update to markers is complete moving from static markers to more intent based markers but there is still a lot of work left to do.

The primary goal is allowing users to almost create a state of analysis on the chart for each individual marker, encapsualting for one the marker and its purpose (Analysis, setup, personal, alert etc...), specific indicators relating to the marker, specific patters (drawing on chart) and specific timeframes all relating to the marker, so when the user clicks a set marker the chart shows them the state the user has chosen relating to that marker.

At the moment the markers i believe have been converted over to this more intent based approach but a lot of the UI/functionality is missing.

There are two distinct phases to this to implement the marker placing phase and the set marker viewing phase. I will outline both below that need implementing.


Phase 1 - Marker Placing

On selecting marker type from bottom bar marker section the UI changes to ta marker placement mode altering the setup and look of the chart to cater for options in placing markers.

The top toolbar buttons hide themselves and are replaced by a cancel button (red glass button with white X in center) and a text value next to it saying Place a Marker. This is all that is present in the top toolbar

The bottom bar that originally pulls up and down to different heights and with different tab section is still left in place but the contents are altered, specific to marker placing. These tabs include a general tab, indicator tab, pattern/drawing tab, timeframe tab, marker placement button (not a tab, a button)

Each tab contains its own section much like the other tabbed bottom bar sections in default chart and the UI/ style can be kept the same or similar. It is important to understand the UI of this bottom bar needs to match the default bottom bar in the default chart state.

General Tab - general content and options relating to the marker, these can be specific to each marker or options that are general across all markers, they can update as the user places more components relating to the marker. The general tba icon can be a mimic of the actual marker being placed (its color and icon)

Indicator Tab - Copy the similar UI view to the Indicator tabbed section in default marker, allow indicator selection that shows on the chart (panels/overlays), these are specific to this marker being placed and will be shown to other users who click this marker. We can show in this tab the active indicators and indicators carried over from the users default chart setup in case they want to reuse them. Tab icon is Same icon as the indicator icon in default bottom bar

Pattern/drawing tab - Much like the indicator tab this tab displays options to place drawing/patterns etc... on the chart epcifically that will again be shown to every user. Some patterns/drawing can be placed/dragged, or annotated on, some like trendlines/ chart patterns will need to work off anchor points to create lines etc... Tab icon is similar to indicator tab icon but with drawing or pattern icon

Time frame tab - Will give options to link to other time frames. Ideally i would like to display a panel much like the indicator panel that is time specific to placed marker showing the markers place in the relevant timeframe, so users can cross reference it . Tab icon is similar to indicator tab icon but with a clock

Marker placement button - Not a tab its a button that can be greyed out until specific criteria for each marker are met before turning green and allowing placement. Tab icon is like the marker selection tab icon

This is the basics of the bottom bar, think of it as a general section for the markers, it will be the same for each marker and is a general set of options for when placing them

We will also add a floating action bar in between the x axis and the bottom bar, it will be in the shape of a capsule, stretching entireity of the screen (same width dimension as the bottom bar and same style look.) It wont be adjustable a fixed bar with specific button relating to the selected marker type. These are options that will be needed to be set before placing. For instance with an alert marker it will display all the options for the alert as icons (critical, severe, alert etc...), for Question marker it will for user to write a question. For setup marker it will force user to set their take profit and stoploss lines and select if its a prediction marker etc... In essence its a reactive, fluid, specific toolbar for each marker listing all the options they must set. It will only show buttons as icons not text really. It will stay in place even when user pulls bottom bar up to expand it moves over it, doesnt move with it or anything. Same look as the bottom bar.



Phase 2 - Set Marker Viewing

This phase is related to when a marker is set and a user selects a marker

On selecting a marker we move to a marker viewing phase, the UI changes to a marker viewing mode altering the setup and look of the chart to cater for options in viewing markers.

The top toolbar buttons hide themselves and are replaced by a cancel button (red glass button with white X in center) and a text value next to it saying Viewing "marker type" Marker. This is all that is present in the top toolbar

The bottom bar changes much like the marker placement mode to cater for specifics relating to the set marker, these will be General tab, Analysis tab, chat tab

The general tab again shows main information relating to the tab, User profile header, general tab info, options for liking, sharing etc... 

The components tab will show all set indicators, patterns, timeframes, these can be in the form of snapshots of the actual chart relating to them as panels, or details of them.

The chat tab is already developed for this and allows direct realtime chat in relation to the marker.


The chart itself will adapt to show the set indicators as panels or overlays, patterns/drawing directly how they were set by user on chart and possibly the timeframes again as panels in a timeseries relation to the markers time in place in that timeframe.

The user can still pan around as usual but remember this is almost like an overlay on the chart so user can see how the other user perceived it.
 
Users can from here select other markers and the UI adapts to view the newly selected marker



Advisory Notes ....


All UI and styling needs to match and reuse components set already in rest of the app, either from unified components or general set styling, this includes tabs, backgrounds, buttons, text boxes, text etc...

A hardline number needs to be set on how many panels are available - 2 panels for indicators and 2 for timeframes. 10-15 for overlay indicators and patters/drawings. The panels will need to be collapsible to allow for up to 4 panels

All indicator options carried forward from the default chart options

Pattern and drawing options will be - trendlines, ray line, horizontal line, vertical line, cross line, parallel channel. 
                                    Head and shoulders pattern, 
                                    different positions - long position, short position, take profit idea, stop loss idea
                                    annotations - text, note, emojis
                                    These can all be in different tabs to select from and allow us to add to in the future

                        
 -->
