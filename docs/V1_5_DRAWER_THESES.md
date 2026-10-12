# v1.5: the drawer's Markers section as theses, and "How markers work"

Owner request, 12 October 2026: highlight the thesis instead of a long feed, and explain the marker system (colours, icons, segmented rings) with a drawn breakdown rather than an image.

## Drawer ▸ Markers

**Theses tab** (first tab, only from servers that send thesis context). Every marker with replies, newest debate first. Each card shows:
- the marker: face, headline, `@author · type · ticker · timeframe`, and the time of the newest reply;
- a **stance bar** and key, `Supports n · Challenges n · Builds on n`, in the chart's relationship colours (`MarkerLinkRelationship.accentColor`);
- the two newest replies, joined by an elbow drawn in the relationship's colour and dash;
- the repliers' faces, the reply count, and **Open thesis**.

Tapping the card opens the thesis on the chart; tapping a reply opens that reply. A thesis outside the loaded page, but with replies inside it, is built from the replies' `parent_preview`. Tombstoned parents are never theses.

**Live Feed, threaded.** Each reply sits under the oldest ancestor the page also holds, in thread order: replies oldest first, each followed by its own replies, stepped in. A thread rises with its newest reply. A reply that answers someone other than the head names them (`@sam → @jo`). A reply whose marker isn't in the page gets a line above it, `↳ Challenges @jo · Breakout or fakeout…`, which opens the parent.

**Server dependency.** Six optional activity-item fields (`docs/V1_5_THESES_FEED_HANDOVER.md` in sanctuary; backend `claude/1.5.0-marker-theses` `2216df0`).
- Without them, the Theses tab is not offered and the Live Feed is unchanged.
- Support is detected from any feed load (`MarkerThesisFeed.isSupported`) and remembered in `TGDrawerThesesSupported`.
- The Theses tab loads the newest 200 markers in the scope (`MarkerActivityListLoadMode.theses`); the Live Feed still loads 60.

**Code.**
- Model (pure, unit-tested): `Features/Shared/other/MarkerThesisFeed.swift`, covering `MarkerThesisStance`, `MarkerThesis`, `MarkerFeedCluster` and `theses(from:)` / `clusters(from:)`.
  - Relationship keys are read through `MarkerThesisStance.relationship(forKey:)`, which accepts both `builds_on` and the decoder's camel-cased `buildsOn`.
- Views: `leftDrawerSubViews/guildTopMarkers/MarkerThesisViews.swift`. Wired in `TopMarkersView`.
- Fixture: `-DrawerThesesFixture theses|feed` (Debug and isolated DEV).
- Tests: `MarkerThesisFeedTests` (11) and `MarkerThesesDrawerUITests` (2).

## How markers work

`Features/Shared/Marker/MarkerGuideView.swift`.
- **The example is drawn by the chart's own marker layer** (`ChartMarkerSystem.drawMarkers`) over a small sample:
  - the reader's face as a selected Analysis thesis, with three arcs, likes and a reply count;
  - a supporting Analysis reply and a challenging Question reply.
- Numbered callouts are placed with the chart's own layout maths. The thesis is drawn at ×2 (`heroScale`) so its parts can be pointed at.
- Below it: a parts key, then post types, context arc colours, the four alert urgencies, the six Setup statuses and the three reply lines.
- Theme-aware, and follows any change to the markers without a new picture.

Entry points:
- Markers ▸ Add, "How markers work" under the two cards;
- Help Center, a card at the top while markers wear faces.

The Help Center FAQ "What are chart markers?" was rewritten for posts pinned to candles.

Test: `MarkerGuideUITests`, which opens the guide from Add, walks every section and closes it.

## Android parity

- **Theses:** decode the six optional fields, which the network `Json` already tolerates. Port `MarkerThesisFeed` as-is, since it is pure logic.
  - Theses tab: card, stance bar, reply rows with the relationship elbow.
  - Live Feed clusters with depth indent; the context line on orphan replies.
  - Show the tab only once a feed response carries `direct_response_count`.
- **Guide:** draw the example with the Android marker renderer the same way, with the same parts key and sections and the same two entry points.
