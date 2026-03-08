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




<!-- 
CURRENT PLAN FOR INTEGRATION



Context
The marker system is the core feature of Traders Guild — users place chart markers to communicate analysis and trade ideas to guild members. The current system uses 17 flat marker types with JSONB metadata, which creates complexity and limits expressiveness. This refactor transforms it into a professional, intent-based system with a typed component architecture, a Tool Picker-driven placement mode, and tracked setup predictions. The goal is a clean, scalable foundation for future features (marker linking, pattern templates, etc.).
Current state: 17 RLMarkerType enum cases, flat metadata_ JSONB on chart_markers, modal MarkerCreationSheet for creation.
Target state: 8 marker intents, marker_components child table with typed payloads, on-chart Tool Picker + Marker Placement Mode, ghost/preview layer, setup tracking state machine.

Architecture Decisions

Hard cutover, no backward compat — Dev environment only, full DB cluster reset allowed. Update existing /api/v1/chart endpoints in-place. Remove old marker_type and metadata columns entirely. No v1/v2 dual routes.
Separate marker_components table — Explicit, queryable components. Indexed by component_type with GIN index on payload for rich queries. Adding new component types requires zero schema changes.
Strict typed payload validation — Pydantic discriminated models per component_type, not generic dict. Each component type (anchor, level.entry, drawing.trendline, etc.) has its own validated payload schema.
Replace RLMarkerType entirely — Clean-replace the 17-case enum with 8-case RLMarkerIntent. Rendering properties derive from intent + component helpers.
Tracked setup state machine — DRAFT → ARMED → ACTIVE → (TP_HIT | SL_HIT | EXPIRED). Same-candle TP/SL conflict resolves to SL_HIT. Configurable TTL for EXPIRED. Resolved setups keep status='active' — lifecycle tracked via tracking_state only.
Denormalized position fields — Keep candle_timestamp, timeframe, price on chart_markers (sourced from anchor component at write time) for query performance. timeframe remains a required top-level field in create request.
guild_id from path param — Remove guild_id from marker request bodies; path parameter is the source of truth.
Forward-compatible iOS decoding — iOS component payload decoding uses enum MarkerComponentPayload with unknown(type, rawPayload) fallback so new component types added later don't break the client.


Phase 1: Backend Database Schema
Files to modify:

traders-guild-backend/shared/models/chart.py
New migration: traders-guild-backend/shared/alembic/versions/20260304_1000_<hash>_marker_v2_schema.py

Changes:
New MarkerComponent model:
marker_components table:
  id              UUID PK
  marker_id       UUID FK → chart_markers.id (CASCADE)
  component_type  String(50) NOT NULL
  payload         JSONB NOT NULL
  ordering        Integer DEFAULT 0
  created_at      DateTime

Indexes:
  ix_marker_components_marker_ordering (marker_id, ordering)
  ix_marker_components_type (component_type)
  ix_marker_components_payload GIN (payload)  — for queryability
Modify ChartMarker columns:

ADD: intent String(20) NOT NULL
ADD: visibility String(20) NOT NULL default 'guild'
ADD: tracking_enabled Boolean NOT NULL default False
ADD: tracking_state String(20) nullable
ADD: primary_component_id UUID FK → marker_components.id nullable
ADD: title String(200) nullable
ADD: confidence Integer nullable
ADD: tracking index: ix_chart_markers_tracking (symbol_id, tracking_enabled, tracking_state, status)
REMOVE: marker_type column (hard cutover, full reset)
REMOVE: metadata_ column (data now lives in components)
KEEP: note, candle_timestamp, timeframe, price (denormalized from anchor), is_visible, like_count, comment_count, status, all relationships

DB constraints:

CHECK on intent IN ('analysis','setup','alert','question','poll','news','reaction','personal')
CHECK on visibility IN ('guild','private')
CHECK on tracking_state IN ('DRAFT','ARMED','ACTIVE','TP_HIT','SL_HIT','EXPIRED') OR NULL
CHECK on confidence BETWEEN 1 AND 5 OR NULL
Partial unique index: max one anchor component per marker (CREATE UNIQUE INDEX ... ON marker_components(marker_id) WHERE component_type = 'anchor')
primary_component_id FK validated in app layer to ensure it belongs to the same marker

Relationship on ChartMarker:

components → MarkerComponent (one-to-many, cascade all/delete-orphan, order_by ordering)

Component ordering semantics:

Backend ignores client-provided ordering values in v1 and assigns deterministic ordering server-side
Stable render ordering: levels → drawings → indicators → links (by type category, then created_at within category)
ordering field exists in schema for future PATCH/reorder support but is fully server-managed for now

No data migration needed — full DB cluster reset.

Phase 2: Backend Schemas (Request/Response)
Files to modify:

traders-guild-backend/shared/schemas/chart_schema.py

Replace marker schemas entirely:
Strict typed component payloads:
python# Discriminated payload models per component_type
class AnchorPayload(BaseModel):
    time: datetime
    price: float

class LevelPayload(BaseModel):
    price: float
    label: Optional[str] = None

class TrendlinePayload(BaseModel):
    start_time: datetime
    start_price: float
    end_time: datetime
    end_price: float

class ZonePayload(BaseModel):
    top_price: float
    bottom_price: float
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None

class IndicatorPayload(BaseModel):
    name: str           # RSI, MACD, EMA, etc.
    settings: dict = {}
    is_primary: bool = False

class NotePayload(BaseModel):
    text: str

class LinkPayload(BaseModel):
    url: str
    title: Optional[str] = None
    preview_image: Optional[str] = None

class EmojiPayload(BaseModel):
    emoji: str

class TimeframeLinkPayload(BaseModel):
    timeframe: str
    note: Optional[str] = None
Request:
pythonclass MarkerComponentInput(BaseModel):
    component_type: str
    payload: dict        # Validated against typed model based on component_type
    ordering: int = 0

class CreateMarkerRequest(BaseModel):   # replaces old entirely
    symbol_id: UUID
    # guild_id from path param — not in body
    timeframe: str = Field(..., pattern=r"^(1m|5m|15m|30m|1h|4h|1d|1w|1M)$")
    intent: str          # analysis | setup | alert | question | poll | news | reaction | personal
    title: Optional[str] = None
    note: Optional[str] = None
    visibility: str = "guild"
    confidence: Optional[int] = Field(None, ge=1, le=5)
    tracking_enabled: bool = False
    components: List[MarkerComponentInput]
    poll_question: Optional[str] = None
    poll_options: Optional[List[str]] = None

class UpdateMarkerRequest(BaseModel):   # replaces old entirely
    intent: Optional[str] = None
    title: Optional[str] = None
    note: Optional[str] = None
    visibility: Optional[str] = None
    confidence: Optional[int] = Field(None, ge=1, le=5)
    tracking_enabled: Optional[bool] = None
    components: Optional[List[MarkerComponentInput]] = None
Response:
pythonclass MarkerComponentResponse(BaseModel):
    id: UUID
    component_type: str
    payload: dict
    ordering: int

class ChartMarkerResponse(BaseModel):   # replaces old entirely
    id: UUID
    symbol_id: UUID
    guild_id: UUID
    author: GuildMemberResponse
    candle_timestamp: datetime
    timeframe: str
    price: float
    intent: str
    title: Optional[str] = None
    note: Optional[str] = None
    visibility: str
    confidence: Optional[int] = None
    tracking_enabled: bool
    tracking_state: Optional[str] = None
    created_at: datetime
    created_at_formatted: str
    is_visible: bool
    like_count: int
    is_liked_by_current_user: bool
    comment_count: int
    comments: List[MarkerCommentResponse]
    components: List[MarkerComponentResponse]
    primary_component_id: Optional[UUID] = None
    is_current_user_marker: bool
    can_edit: bool
    can_delete: bool
    poll_question: Optional[str] = None
    poll_options: Optional[List[PollOptionResponse]] = None
    user_poll_vote: Optional[UUID] = None
```

**Update `TopMarkerResponse`:**
- Replace `marker_type` → `intent`
- Remove `target_price`, `stop_loss_price`
- Add setup summary (entry/sl/tp prices extracted from components if present)

---

## Phase 3: Backend API Endpoints

### Files to modify:
- `traders-guild-backend/services/chart-service/app/api/chart.py`

### Update existing endpoints in-place:
```
POST   /api/v1/chart/guilds/{guild_id}/markers
GET    /api/v1/chart/guilds/{guild_id}/symbols/{symbol_id}/markers
PUT    /api/v1/chart/guilds/{guild_id}/markers/{marker_id}
DELETE /api/v1/chart/guilds/{guild_id}/markers/{marker_id}
Implementation Details:

Create: Validate intent + component payloads (strict typed), create ChartMarker with intent/visibility/tracking fields, bulk-create MarkerComponent rows, denormalize anchor to candle_timestamp/timeframe/price, set primary_component_id
List: Eager-load components via joinedload(ChartMarker.components), return new ChartMarkerResponse
Update: Replace components if provided (full replace; PATCH semantics deferred to later). Edit window rule: tracked setups cannot have components edited once tracking_state is ARMED or beyond. On component replace, always recompute denormalized candle_timestamp + price from the new anchor; reject update if no anchor in replacement set
Delete: Unchanged — cascade handles components
Validation per intent:

All: require exactly one anchor component
setup + tracking_enabled: require level.entry, level.sl, level.tp + direction consistency
poll: require poll_question + poll_options
question: require non-empty note
confidence: range 1-5


Top markers: return intent, setup_summary as explicit typed object:

python  class SetupSummary(BaseModel):
      entry_price: Optional[float] = None
      sl_price: Optional[float] = None
      tp_price: Optional[float] = None
      tracking_state: Optional[str] = None

Combined chart-data: update ChartDataResponse markers field to include components
Moderation text: assemble from title, note, poll text for report context


Phase 4: Backend Cross-Service Updates + Marker Processor
Files to modify:

traders-guild-backend/services/chart-service/app/services/marker_processor.py
traders-guild-backend/services/core-service/app/api/guilds.py
traders-guild-backend/services/admin-service/app/views/trading.py
traders-guild-backend/shared/utils/model_schema_conversion.py

Marker Processor Rewrite:

Query markers with tracking_enabled=True and tracking_state IN ('ARMED', 'ACTIVE')
Join components to get entry/SL/TP prices
ARMED → ACTIVE: entry level touched by candle; then evaluate TP/SL within same candle
ACTIVE → TP_HIT: TP level touched
ACTIVE → SL_HIT: SL level touched (or same-candle TP+SL conflict → SL_HIT)
EXPIRED: configurable TTL exceeded while ARMED/ACTIVE
Keep marker status='active' throughout — lifecycle via tracking_state only
Idempotency guard: conditional update + row lock (SELECT ... FOR UPDATE) to prevent duplicate resolves/events on concurrent candle processing
Real-time event payloads (all include full marker with components so clients update without refetch):

marker_created — full marker body
marker_updated — full marker body (fired on edit, state transitions)
tracking_state_changed — marker_id + old_state + new_state + full marker body
Like/comment events remain separate as today


Initial tracking state on create:

intent=setup + tracking_enabled=true + valid components (entry/sl/tp) → tracking_state = ARMED
intent=setup + tracking_enabled=true but missing required components → validation error (reject create)
intent=setup + tracking_enabled=false → tracking_state = DRAFT (untracked setup idea)
Any other intent → tracking_state = null


Terminal persistence rules:

TP_HIT / SL_HIT → create marker_prediction_results row with PnL
EXPIRED → do NOT create prediction result row (no PnL impact)


Publish reputation events unchanged (prediction_win/prediction_loss) — only on TP_HIT/SL_HIT, not EXPIRED

Runtime config plumbing:

Add processor env var reading in chart-service settings.py / main.py:

MARKER_PROCESSOR_ENABLED (bool, default false)
MARKER_SETUP_TTL_MINUTES (int, default 10080 = 7 days)
MARKER_SAME_CANDLE_CONFLICT (str, default "sl")


Gate processor startup in main.py: only start MarkerProcessor if MARKER_PROCESSOR_ENABLED is true
Processor reads config at startup, not hardcoded

Cross-service updates:

guilds.py (core-service): Update report snippet logic from marker_type → intent/title
trading.py (admin-service): Update admin marker tables/search/sort from marker_type → intent
model_schema_conversion.py: Align to single v2 source of truth, remove legacy marker conversion


Phase 5: iOS DTOs and Models
Files to modify:

traders_guild_ios/traders_guild/Models/RLChartDTOs.swift
traders_guild_ios/traders_guild/TradingChart/Models/ChartMarkerUI.swift

Changes:
Replace RLMarkerType with RLMarkerIntent:
swiftenum RLMarkerIntent: String, Codable, CaseIterable {
    case analysis, setup, alert, question, poll, news, reaction, personal
    var displayName: String { ... }
    var icon: String { ... }
    var color: Color { ... }
}
Typed component payload decoding with forward-compat fallback:
swiftstruct RLMarkerComponentDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let componentType: String
    let payload: MarkerComponentPayload  // typed enum
    let ordering: Int
}

enum MarkerComponentPayload: Codable, Hashable {
    case anchor(AnchorPayload)
    case levelEntry(LevelPayload)
    case levelSl(LevelPayload)
    case levelTp(LevelPayload)
    case levelSupport(LevelPayload)
    case levelResistance(LevelPayload)
    case drawingTrendline(TrendlinePayload)
    case drawingZone(ZonePayload)
    case indicator(IndicatorPayload)
    case note(NotePayload)
    case link(LinkPayload)
    case reactionEmoji(EmojiPayload)
    case timeframeLink(TimeframeLinkPayload)
    case unknown(type: String, rawPayload: [String: AnyCodable])  // forward compat
}
Replace RLChartMarkerDTO in-place:

Remove: horizontalLinePrice, targetPrice, stopLossPrice, alertSeverity, trendlineDirection, selectedIndicator, chartPattern, selectedEmoji, markerType
Add: intent, title, visibility, confidence, trackingEnabled, trackingState, components[], primaryComponentId
Keep: poll fields at marker level

Replace request DTOs:
swiftstruct CreateMarkerRequest: Encodable {
    let symbolId: UUID
    // guildId NOT included — path param is source of truth
    let timeframe: String    // required, matches backend
    let intent: String
    let title: String?
    let note: String?
    let visibility: String
    let confidence: Int?
    let trackingEnabled: Bool
    let components: [MarkerComponentInput]
    let pollQuestion: String?
    let pollOptions: [String]?
}
Update ChartMarkerUI:

Replace type: RLMarkerType → intent: RLMarkerIntent
Add components: [RLMarkerComponentDTO]
Add computed helpers: levels, drawings, indicators, anchorComponent, entryLevel, slLevel, tpLevel
Update displayColor, linePrice() to derive from intent + components


Phase 6: iOS MarkerManager + Blast Radius Updates
Files to modify:

traders_guild_ios/traders_guild/TradingChart/overlays/ChartMarkerSystem.swift
traders_guild_ios/traders_guild/Services/RealAPIService.swift
traders_guild_ios/traders_guild/Features/Core/subViews/chartSheetSubViews/chartSheetMarkersView.swift
traders_guild_ios/traders_guild/Features/Core/subViews/chartSheetSubViews/MarkerActivitySheet.swift
traders_guild_ios/traders_guild/Features/Core/subViews/leftDrawerSubViews/guildTopMarkers/TopMarkersView.swift
traders_guild_ios/traders_guild/Features/Messaging/MessagingComponents.swift
traders_guild_ios/traders_guild/Features/Shared/globalViews/UnifiedComponents.swift
traders_guild_ios/traders_guild/TradingChart/Extensions/RLTopMarkerDTO+Extensions.swift
traders_guild_ios/traders_guild/TradingChart/viewModels/ChartControlViewModel.swift
traders_guild_ios/traders_guild/TradingChart/services/ChartGestures.swift
traders_guild_ios/traders_guild/TradingChart/services/MarkerNavigationHelper.swift
traders_guild_ios/traders_guild/Features/Core/subViews/leftDrawerSubViews/guildUsers/ProfileContentViews.swift
traders_guild_ios/traders_guild/TradingChart/Extensions/EnumConversions.swift

Changes:

MarkerManager: Update API methods, addMarker() accepts intent + components, loadMarkersFromAPI() parses new response, real-time event handling parses new schema only
RealAPIService: Update marker endpoint methods to new request/response types, remove guild_id from request bodies
chartSheetMarkersView: Update marker type references → intent
MarkerActivitySheet: Update marker type display → intent
TopMarkersView: Update to show intent, setup_summary instead of marker_type
MessagingComponents: Move from markerType → intent in share payload; keep decode fallback from old markerType for existing message history
UnifiedComponents: Update UnifiedMarkerBadge to accept intent (or generic badge model), not legacy type
TopMarkerDTO+Extensions: Update from marker_type to intent
ChartControlViewModel: Update marker creation flow entry points for intent-based system
ChartGestures: Update gesture handling for placement mode integration
MarkerNavigationHelper: Update navigation to work with intent-based markers
ProfileContentViews: Update user marker statistics display for intents
EnumConversions: Remove/update legacy RLMarkerType conversions, add intent conversions


Phase 7: iOS Marker Placement Mode + Tool Picker
New files:

traders_guild_ios/traders_guild/TradingChart/overlays/MarkerPlacementMode.swift
traders_guild_ios/traders_guild/TradingChart/overlays/ToolPickerView.swift
traders_guild_ios/traders_guild/TradingChart/overlays/MarkerPlacementPanel.swift
traders_guild_ios/traders_guild/TradingChart/overlays/GhostPreviewLayer.swift

Wire into:

traders_guild_ios/traders_guild/TradingChart/TradingChartView.swift

MarkerPlacementMode:

MarkerPlacementState ObservableObject:

intent, components (mutable drafts), activeTool, activeSubTool, isValid, title, note, visibility, confidence, trackingEnabled


Top toolbar: Cancel + "Placing Marker"
Chart interactive for placement gestures
Bottom: MarkerPlacementPanel
"Place Marker" button (enabled when valid)

ToolPickerView:

Vertical compact palette, two-level (groups → options)
Groups: Anchor, Levels, Draw, Indicators, Note, Timeframes, Link, Style
Intent-aware availability:

analysis: Anchor, Draw, Indicators, Note, Timeframes, Link, Levels (support/resistance)
setup: Anchor, Levels (Entry/SL/TP/Exit), Draw, Indicators, Note, Timeframes
news: Link emphasized, Anchor, Note
poll/question: Anchor (content in bottom panel)
reaction: Emoji selection primary
alert: Anchor, Note, severity



GhostPreviewLayer:

Canvas overlay, semi-transparent previews
Updates live on drag/tap
Reuses MarkerPlacementPriceIndicator patterns

MarkerPlacementPanel:

Tab 1 — Details: intent picker, title, note, visibility, confidence, tracking toggle (setup)
Tab 2 — Contents: checklist summary of attached components
"Place Marker" button (green)

Remove dependency on:

MarkerCreationSheet.swift (legacy creation flow)


Phase 8: iOS Marker Viewing Updates
Files to modify:

traders_guild_ios/traders_guild/TradingChart/overlays/MarkerDetailView.swift
traders_guild_ios/traders_guild/TradingChart/overlays/EmbeddedMarkerDetailView.swift

New file:

traders_guild_ios/traders_guild/TradingChart/overlays/MarkerOverlayState.swift

MarkerDetailView:

Structured sections from components:

Overview: intent badge, author, time, title, description, visibility
Levels: entry/SL/TP/support/resistance with prices
Drawings: trendlines/zones/channels
Indicators: with settings
Links: URL previews
Interactions: like/comment/reply (existing)


Setup markers: tracking state badge, R:R ratio, PnL if resolved

MarkerOverlayState:

Save user's chart state on marker select
Apply marker components as temporary overlay (drawings, levels, main indicator)
Restore user state on deselect
Integrate with MarkerManager.selectedMarker


Phase 9: iOS Setup Tracking Integration
Files to modify:

traders_guild_ios/traders_guild/TradingChart/services/MarkerPredictionProgress.swift

Changes:

Read entry/SL/TP from components
Display tracking state (DRAFT/ARMED/ACTIVE/TP_HIT/SL_HIT/EXPIRED) with badges
State transition timeline in marker detail
Real-time state change notification handling


Phase 10: Testing & Verification
Backend Tests (services/chart-service/tests/):

Create/list/update/delete for each intent with strict component validation
Component validation failures per intent rule (missing anchor, missing entry/sl/tp for tracked setup, etc.)
Poll create + vote behavior unchanged (intent == "poll" check)
Top markers include intent and setup_summary
Combined chart-data includes component-rich markers
Processor: ARMED→ACTIVE, ACTIVE→TP_HIT, ACTIVE→SL_HIT, EXPIRED
Same-candle TP+SL resolves to SL_HIT
Same-candle entry activation + TP/SL evaluation
Idempotency test: duplicate candle/process calls do not emit duplicate terminal transitions/events
Reputation event payload assertions

Cross-Service Tests:

Core-service report context returns intent-based snippet
Admin-service marker pages search/sort by intent

iOS Tests:

DTO decode/encode for marker + component payloads, including unknown component fallback
MarkerManager filters and rendering by intent/components
Tracking progress and badges from components/state
Marker share payload decode supports both legacy markerType and new intent
Update: MarkerPredictionProgressTests.swift, MarkerManagerAuditTests.swift

End-to-End Smoke:

Place analysis marker with drawings/indicator/link → verify in DB → verify display
Place tracked setup → verify ARMED→ACTIVE→TP_HIT/SL_HIT transitions
Place poll and vote
Select marker → confirm overlay apply/restore


Implementation Order
Rollout Strategy: Backend first, verify, then iOS.
Milestone A: Backend (Phases 1-4)

Phase 1 — Database schema (new table, column changes, drop legacy columns)
Phase 2 — Schemas (strict typed payloads, new request/response)
Phase 3 — API endpoints (in-place update, validation, eager loading)
Phase 4 — Cross-service updates + marker processor rewrite

Checkpoint: Run backend tests, smoke test endpoints.
Milestone B: iOS (Phases 5-10)

Phase 5 — DTOs/models (intent enum, component DTOs, ChartMarkerUI)
Phase 6 — MarkerManager + blast radius (API service, all views referencing marker type)
Phase 7 — Placement Mode + Tool Picker (new UX)
Phase 8 — Viewing updates (detail view + overlay state)
Phase 9 — Setup tracking integration
Phase 10 — Testing across all layers


Critical Files Reference
Backend:

traders-guild-backend/shared/models/chart.py — MarkerComponent model, intent/tracking columns, drop legacy
traders-guild-backend/shared/schemas/chart_schema.py — Strict typed schemas
traders-guild-backend/services/chart-service/app/api/chart.py — Endpoint updates
traders-guild-backend/services/chart-service/app/services/marker_processor.py — Tracking state machine
traders-guild-backend/services/core-service/app/api/guilds.py — Report snippet
traders-guild-backend/services/admin-service/app/views/trading.py — Admin tables
traders-guild-backend/shared/utils/model_schema_conversion.py — Conversion cleanup

iOS:

traders_guild_ios/traders_guild/Models/RLChartDTOs.swift — Intent enum, component DTOs
traders_guild_ios/traders_guild/TradingChart/Models/ChartMarkerUI.swift — Intent-based model
traders_guild_ios/traders_guild/TradingChart/overlays/ChartMarkerSystem.swift — MarkerManager
traders_guild_ios/traders_guild/Services/RealAPIService.swift — API methods
traders_guild_ios/traders_guild/TradingChart/overlays/MarkerDetailView.swift — Component sections
traders_guild_ios/traders_guild/TradingChart/services/MarkerPredictionProgress.swift — Tracking
traders_guild_ios/traders_guild/TradingChart/TradingChartView.swift — Wire placement mode
traders_guild_ios/traders_guild/Features/Core/subViews/chartSheetSubViews/chartSheetMarkersView.swift
traders_guild_ios/traders_guild/Features/Core/subViews/chartSheetSubViews/MarkerActivitySheet.swift
traders_guild_ios/traders_guild/Features/Core/subViews/leftDrawerSubViews/guildTopMarkers/TopMarkersView.swift
traders_guild_ios/traders_guild/Features/Messaging/MessagingComponents.swift
traders_guild_ios/traders_guild/Features/Shared/globalViews/UnifiedComponents.swift

New iOS files:

MarkerPlacementMode.swift — Placement state + toolbar
ToolPickerView.swift — Two-level tool palette
MarkerPlacementPanel.swift — Bottom panel (Details/Contents)
GhostPreviewLayer.swift — Semi-transparent previews
MarkerOverlayState.swift — Chart state save/restore on marker selection

Platform:

traders-guild-platform/environments/staging-local/values/backend.yaml — Add under services.chart-service.extraEnv (list of {name, value} entries):

yaml  - name: MARKER_PROCESSOR_ENABLED
    value: "true"
  - name: MARKER_SETUP_TTL_MINUTES
    value: "10080"   # 7 days
  - name: MARKER_SAME_CANDLE_CONFLICT
    value: "sl"

traders-guild-platform/environments/production-gke/values/backend.yaml — Same entries

Assumptions

Full DB cluster reset allowed (no data migration)
Hard cutover on /api/v1/chart — no dual routes, no v1 compat
Same-candle TP/SL → SL_HIT
Contribution reputation stays engagement-based; accuracy is statistical only -->