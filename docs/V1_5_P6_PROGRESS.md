# v1.5 workspace: P6 progress (part 1)

Claude, 7 October 2026. Branch `claude/1.5.0-marker-workspace`, on top of P5 (`69c4f5d`). Nothing has been merged into `feat/1.5.0-avatar-markers`.

Owner feedback on P4/P5 (7 October):
- Prefers the new Add context UI.
- Asked for a richer Markers ▸ Add sheet.
- Reported a long-standing bug: after **Post to the chart**, resizing the sheet makes the draft marker vanish until placement restarts.
- Approved P6.

## Markers ▸ Add, redesigned

| Before | After |
|---|---|
| Two equal rows: "Post to the chart" and "Setup". | **Post to the chart is the hero.** A card in the Analysis-to-Question colours: your face, the two kinds of post (Analysis or a question, with their badges), "Share what you see, or ask the guild. Your face marks the spot.", and a full-width **Post to the chart →** button. |
| | **"Or plan a trade"**, separated below. A Setup card with your face wearing the Setup ring: "Entry, Take Profit and Stop Loss on the chart. Track it to build your accuracy and reputation." |

Both still fit at the working height on a large phone (the shell test asserts it), and identifiers are unchanged.

## The disappearing draft marker: chart framing above the sheet

The draft marker is drawn at its candle's price. Until now the chart centred everything on its **full** height, so the draft could sit behind the sheet, and raising the sheet covered it. The plan's P6 item "chart framing above the sheet" is now in:

- MainView tells the chart how much of it the authoring sheet covers (`placementObscuredBottom`). It is computed from the four standard heights and is 0 outside the guided workspace, so nothing else changes.
- **When a post starts**, and **whenever the sheet settles at a new height**, the chart moves up or down, never sideways, so the draft sits in the middle of the strip between the top bar and the sheet. It does this only when the draft would otherwise be hidden. A draft already in view is left alone. A new Setup's opening centring uses the same strip for its Entry.
- At the tallest height there is no strip worth framing, so nothing moves.
- Implementation: `ChartGestureState.animateCenterOnMarker` gains an optional `focusY` (the default is the old centre, so the algebra is unchanged), and there is a new `animateVerticalFocus` (vertical only). The framing never interrupts a centring already under way, a drag of the draft, or a drawing session.

**This is unverified on a live chart.** The fixture has no guild, so there is no chart in the simulator, and signing in is the owner's. If the vanishing was the sheet covering the draft, this fixes it. If not, a short screen recording of the steps would pin it down.

## Accessibility pass (largest text size)

Captured the Add surface, Post details, Add context, the Setup ticket and an edit's Review at **Accessibility XXXL**. Fixes:
- The workspace header and the side control stop growing at the first accessibility size, with the Large Content Viewer, as the footer already did. Titles had truncated to "New Ana…".
- The Analysis / Question chips stack at accessibility sizes and never break a word.
- Long / Short stay on one line each, and the ticket's top row stacks.
- The hero button is capped like the footer's.

Body text still scales fully, and context tiles go to one column.

## Evidence

| Check | Result |
|---|---|
| Focused unit suites (11) | **135/135** |
| Workspace UI suites, iPhone 17 Pro / iOS 26.5 | **58/58**, including the new largest-text-size capture and the Add-surface fit test |
| Sheet journeys + visual review, iPhone SE / iOS 18.2 | **14/14 + 1 skipped** (hardware keyboard) |
| Release build; signed device build | Succeeded |

Screenshots: `docs/visual-review/v1.5-p6/` (the Add surface on the main sheet and the harness; the accessibility XXXL set).

## Next in P6

- Framing a guided **edit**: the saved marker kept above the sheet.
- VoiceOver walk-through of every route, Reduce Motion check, Light Grey theme screenshots, and the SE compact pass.
- The drawing editor screen restyle.
