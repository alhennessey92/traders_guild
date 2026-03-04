Below is a thorough, professional, developer-facing plan that consolidates everything: intent-based markers, a highly interactive Tool Picker, Marker Placement Mode, a component-based marker model, and Setup markers with optional tracked prediction.

You can paste this as your spec.

⸻

Marker System Refactor (Intent-Based + Tool Picker + Component Model)

Developer Specification v1

1. Overview and Objective

Markers are the core feature of the app: users place chart markers in real time to communicate analysis and trade ideas to other guild members. Current marker mechanics (movement, anchor lines, rendering, marker selection, chat) work well, but the placement workflow and overall expressiveness need a major refactor to feel more professional and closer to “real charting tool” standards.

This refactor aims to:
	•	Make marker placement a deliberate, professional workflow
	•	Allow users to build and share a saved chart state (indicators, drawings, price levels) as part of a marker
	•	Reduce marker “type” complexity by moving to intent-based markers
	•	Introduce a Tool Picker as the primary on-chart interactive control for building marker content
	•	Support Setup markers that can optionally be tracked predictions (entry/SL/TP, state machine, accuracy metrics)
	•	Ensure the backend model is scalable via a typed component architecture, avoiding future refactors

⸻

2. Core Concept: Intent-Based Markers (not Type-Based)

We will remove/avoid a large list of “marker types” and instead define a smaller set of marker intents representing what the user is trying to achieve.

Initial Marker Intents
	•	analysis — “Here’s how I see the chart”
	•	setup — “Here’s my trade idea” (entry/SL/TP etc.)
	•	alert — “Pay attention to this”
	•	question — “What do you think about this?”
	•	poll — “Vote on this”
	•	news — “This news is relevant”
	•	reaction — quick emoji reaction
	•	personal — private annotation (optional)

Note: UI can still present “categories” for user friendliness, but data model and logic should use intent.

⸻

3. Marker as “Saved Chart State”

A marker should represent a single primary point + supporting context.

In practice:
	•	User creates a marker with a primary idea (e.g., analysis or setup)
	•	While placing it, they can attach:
	•	price levels
	•	drawings/patterns
	•	indicators
	•	timeframe references
	•	links/news
	•	This creates a “chart state” the creator intends others to see when selecting the marker.

⸻

4. Marker Placement Mode (New UX Mode)

When user starts creating a marker, the chart enters a dedicated Marker Placement Mode.

UI Changes During Placement Mode

Top Toolbar
	•	Hide/fade normal top controls (guild drawer + user drawer)
	•	Replace with:
	•	Cancel button (top left)
	•	Title: “Placing Marker”

Chart Interaction
	•	Chart remains visible and interactive for placement gestures.
	•	Show Ghost/Preview Layer (see section 6).

Bottom Panel
	•	Replace standard bottom bar with a Marker Placement Panel (details/summary/validation).
	•	A Place Marker button finalizes creation (enabled only when valid).

Tool Picker
	•	A vertical Tool Picker appears and becomes the primary interactive tool surface for building the marker’s chart state.

⸻

5. Tool Picker (Primary Interactive Control)

Purpose

The Tool Picker is a context-sensitive, on-chart tool palette used during Marker Placement Mode to:
	•	Select the active tool (drawings, levels, indicators, notes, links)
	•	Add/modify marker components directly on the chart
	•	Make the placement workflow feel professional and fast (TradingView-like)

General Rules
	•	Tool Picker appears only in Marker Placement Mode (and later optional “edit mode”)
	•	Tool Picker is intent-aware (analysis vs setup vs news etc.)
	•	Tool Picker selection drives the Ghost/Preview layer
	•	Tool Picker is not a drawer; it’s a compact tool palette

Tool Picker Structure (Recommended)

Two-level palette:

Level 1: Tool Groups
	•	Anchor (place marker anchor point)
	•	Levels (price lines)
	•	Draw (trendlines/zones/patterns)
	•	Indicators (main + linked)
	•	Note (text/labels)
	•	Timeframes (references)
	•	Link (URL/news/social)
	•	Style (icon/label/color preset if needed)

Level 2: Tool Options
Opens when user taps a group.

Examples:
	•	Levels → Entry / SL / TP / Exit / Support / Resistance (intent dependent)
	•	Draw → Trendline / Zone / Channel / Pattern Template
	•	Indicators → RSI / MACD / EMA / VWAP / More…
	•	Link → Paste URL / Select from recent links (optional)

Intent-Based Tool Picker Behavior

Tool availability changes based on marker intent:

Analysis intent
	•	Tools available:
	•	Anchor
	•	Draw (trendline/zone/support-resistance/channel/pattern)
	•	Indicators (add/remove; set “main indicator”)
	•	Note
	•	Timeframes
	•	Link (optional)
	•	“Levels” should include analysis-style levels (support/resistance), not entry/SL/TP.

Setup intent
	•	Tools available:
	•	Anchor
	•	Levels (Entry / SL / TP / Exit)
	•	Draw (optional supporting drawings)
	•	Indicators (optional main + linked)
	•	Note
	•	Timeframes
	•	Setup should be able to construct a full trade idea via Tool Picker without needing separate “pattern marker” etc.

News intent
	•	Link tool emphasized; can still include anchor/note.

Poll/Question intents
	•	Poll/question content is created in bottom panel, but can be anchored to chart via Anchor tool.

Reaction intent
	•	Emoji selection is Tool Picker primary.

⸻

6. Ghost / Preview Layer (Professional Placement)

During Marker Placement Mode, the chart displays a ghost preview of whatever the user is placing:
	•	semi-transparent marker/drawing/level
	•	updates live as the user drags/taps
	•	helps ensure accuracy before committing

Examples:
	•	Trendline: first anchor fixed, line previews to finger until second anchor placed
	•	Entry line: previews horizontally at chosen candle; vertical adjust if supported
	•	Zone: rectangle previews while dragging

Ghost components are not persisted/broadcast until “Place Marker” is pressed.

⸻

7. Bottom Panel (Placement Panel) – Simplified and Professional

With Tool Picker as the main interactive selection surface, the bottom panel becomes:
	•	metadata entry
	•	validation and summary
	•	optional configuration that doesn’t need direct chart manipulation

Proposed Tabs

Tab 1: Details
	•	intent (if not chosen earlier)
	•	title/description
	•	visibility (guild/private)
	•	optional tags
	•	optional confidence
	•	(Setup only) tracking toggle (see section 9)

Tab 2: Contents (Summary)
Shows what will be included in this marker:
	•	Levels: Entry/SL/TP etc.
	•	Drawings: trendline/zone/pattern
	•	Indicators: main + linked
	•	Timeframes: linked
	•	Links: URLs/news
This is a clear “what you’re about to post” checklist.

Tab 3 (Optional): Advanced
Only if needed (e.g. indicator settings, timeframe note, etc.). Prefer to keep this minimal in v1.

Place Button
	•	Green “Place Marker” button on the right
	•	Only enabled when marker passes validation rules for the chosen intent

⸻

8. Marker Viewing Mode Improvements (Selected Marker Behavior)

When a marker is selected, the chart should temporarily adapt to represent the creator’s intended chart state.

Marker Overlay State
	•	Apply the marker’s components as an overlay state:
	•	show marker drawings
	•	show marker levels
	•	show marker’s “main indicator” if present
	•	Preferred behavior:
	•	Temporarily hide user’s own indicators while marker selected
	•	Restore user’s indicators/state on deselect
	•	Marker selection should not permanently alter user’s chart configuration.

Marker Detail Panel (When Selected)

Bottom panel displays structured sections:
	•	Overview (intent, author, time, description, visibility)
	•	Interactions (like/comment/reply)
	•	Contents:
	•	Levels
	•	Drawings
	•	Indicators
	•	Timeframes
	•	Links/news preview
	•	Optional: “Open marker thread” (chat/comments)

⸻

9. Setup Markers and Tracked Predictions (Integrate Prediction into Setup)

We previously had a “prediction marker” concept that calculates outcomes and updates accuracy/reputation. We will integrate this into the setup intent as an optional tracking mode.

Setup Modes
	•	Draft Setup (not tracked): analysis/trade idea only; engagement still applies
	•	Tracked Setup (prediction tracking enabled): processed by prediction engine (not sure of current name); used for accuracy metrics and automated notifications

UI

In Setup marker Details tab:
	•	Toggle: “Track Outcome” / “Enable Tracking”

Validation Rules for Setup

Minimum for any setup marker:
	•	anchor + optional levels

Required for tracked setup:
	•	Entry level
	•	Stop Loss level
	•	Take Profit level (at least 1)
	•	Direction (long/short)
	•	Timeframe

Tracking State Machine (Backend)

Tracked setups follow:
	•	DRAFT → ARMED → ACTIVE → (TP_HIT | SL_HIT | EXPIRED)
	•	Deterministic candle-based hit testing
	•	Worst-case handling if TP and SL touched in same candle

Tracked outcomes update:
	•	user accuracy metrics (win rate, avg RR, total tracked)
	•	notifications (entry hit / resolved)
	•	optional contribution/reputation events (if applicable, but do not over-gamify)

Important: contribution score remains engagement-based; accuracy remains statistical.

⸻

10. Data Model: Typed Component Architecture - obviously not based on current schemas, just ideas of additions etc...

Markers should be stored as:
	•	one marker record + many marker component records

Marker (core)
	•	id
	•	guild_id
	•	user_id
	•	symbol
	•	timeframe
	•	intent
	•	visibility
	•	created_at
	•	primary_component_id (optional)
	•	tracking_enabled (setup only)
	•	tracking_state (setup only)

Marker Components

Each component has:
	•	id
	•	marker_id
	•	component_type (string)
	•	payload (JSON)
	•	ordering (int)

Component Types (v1 set)
Core:
	•	anchor (time, price)
	•	text.note
Levels:
	•	level.support
	•	level.resistance
	•	level.entry
	•	level.sl
	•	level.tp
	•	level.exit (optional)
Drawings:
	•	drawing.trendline
	•	drawing.zone
	•	drawing.channel (optional)
	•	drawing.pattern (template_id + points[] or polygon)
Indicators:
	•	indicator (name + settings + primary flag)
Timeframes:
	•	timeframe_link
External:
	•	link.url (news/social)
Interactive:
	•	reaction.emoji
	•	poll
	•	question

primary_component_id indicates the “main point” the marker represents. Tool Picker changes this quickly.

⸻

11. Interactions and Engagement

Markers support:
	•	Like (required)
	•	Optional dislike (consider carefully)
	•	Comments/threads (already implemented)

Certain intents should have inline interaction on chart:
	•	poll: vote on chart
	•	question: quick reply action
	•	reaction: quick change emoji (if allowed)

⸻

12. News Markers

News is handled as intent news with components:
	•	link.url plus metadata (title/preview)
When selected:
	•	show preview in marker detail panel.

⸻

13. Future Feature Compatibility

Marker Linking (Chains of Analysis)

Planned future component:
	•	link.marker { marker_id, relationship_type }

This will allow linking markers into sequences like:
	•	analysis → setup → follow-up → invalidation

Not required for v1, but ensure schema supports it.

⸻

14. Implementation Principles
	•	Keep intents small and stable
	•	Keep components explicit and queryable
	•	Tool Picker is the main interactive surface
	•	Bottom panel is for metadata, validation, summary
	•	Marker selection applies a temporary “marker overlay state” and restores user state on exit
	•	Tracked predictions are opt-in within Setup intent

⸻

15. Suggested v1 Scope (to keep delivery realistic)

Must have (v1)
	•	analysis + setup + news + question + poll + reaction + alert intents
	•	Tool Picker with groups:
	•	Anchor, Levels, Draw, Indicators, Note, Link
	•	Ghost placement for trendline, horizontal level, zone, entry/SL/TP
	•	Setup tracking toggle + backend state machine (for tracked setups)
	•	Marker overlay state on selection + restore user state
	•	Marker detail panel with structured content sections

Nice to have (v1.1)
	•	Pattern templates
	•	Timeframe linking via Tool Picker
	•	Marker linking

