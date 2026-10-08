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

## Owner device round (7 October)

- **The draft marker vanishing**, confirmed fixed by the owner. It happened on the *first pan* after starting a post, not on a sheet move. That pan loaded a page of older candles and shifted every candle index. Saved markers were shifted by `ChartViewModel`, but the draft's `previewCandleIndex` and a Setup's prediction index were not, so the draft jumped a page of history off-screen. Both are now shifted (`8aafa76`).
- **"Setup not allowed on this symbol and timeframe"**, confirmed. An open tracked Setup there blocked starting any Setup. It now starts untracked: the tracking switch is disabled and shows the reason.
- The **number-pad Done bar** is removed at the owner's request (`323d902`).

# P6 part 2

## Accessibility audit (`MarkerWorkspaceAccessibilityAuditUITests`)

Apple's `performAccessibilityAudit` ran on seven workspace screens: Add, Details, Review, Add context, Setup, a response, and an edit's Review. Every issue is written to an attachment. Fixed:
- **Contrast.** White words on bright fills failed: the selected context tab on orange or cyan, Long on green, the LONG pill. Selected controls are now tinted with an outline in their colour and use readable words. The hero caption is full-strength text.
- **Indicator category tabs.** They were a shared component with fixed font sizes, so they didn't scale with Dynamic Type and failed contrast unselected. They are now workspace chips with text styles.
- **Hit areas.** The footer's Back/Edit/Cancel and "Respond with a Setup" are now full 44pt targets.
- **Unlabelled images.** The header's face exposed its picture and its badge glyph ("waveform.path.ecg") despite `accessibilityHidden`. It is now one element, "Your marker, Analysis". The type chips carry explicit labels.

152 issues became 125. What remains has been reviewed:
- "Text clipped" on text inside the scrolling sheet that is fully visible.
- "Dynamic Type partially unsupported" on the controls deliberately capped at accessibility1 (with the Large Content Viewer).
- "Nearly passed" contrast on the app's standard primary buttons.
- The shared badge's initials.
- Two price-field labels hidden on purpose because the field speaks its own name.
- Three contrast flags on text that is legible in screenshots, on gradient or translucent fills.

## Light Grey theme

Add, Details, Review, Add context, Setup and a response were captured with `-appTheme lightGrey` (`docs/visual-review/v1.5-p6/`). Every surface adapts, with no hard-coded dark colours.

## Drawing editor restyled

Editing an attached drawing now shows: the tool ("Horizontal Line", with its icon in the drawings colour), "Done keeps it; Cancel puts it back exactly", a full-width **Move it on the chart** button, a **Price** field for horizontal lines, **Line** chips that preview their stroke, and larger **Colour** swatches with a selected ring. The old system picker and the small dots are gone. The header says "Edit drawing".

## Editing keeps the marker in view

The framing from part 1 now applies to guided **edits** as well. The edited marker (or a Setup's saved Entry) is moved into the strip above the sheet when the edit opens and whenever the sheet settles somewhere that would hide it.

## Evidence (part 2)

| Check | Result |
|---|---|
| Focused unit suites (11) | **136/136** |
| Workspace UI suites, iPhone 17 Pro / iOS 26.5 | **60/60**, including the drawing editor and Light Grey captures |
| Sheet journeys + visual review, iPhone SE / iOS 18.2 | **14/14 + 1 skipped** (hardware keyboard) |
| Release build | Succeeded |
| Device build | Not run: the phone was unavailable. Install when it is back. |

## Compact-height phones (SE class, screens under 700pt)

The SE pass found two problems:
- At the small height, Details showed only the header, the type chips and one line of text.
- The Add hero and Setup card no longer fit at the working height.

Changes, on compact-height phones only:
- **The workspace opens at the working height**, not the small one (`MarkerSheetDetents.workspaceStart`). The whole text box is in view. The draft stays visible in the strip above, which the framing keeps it in.
- **Markers ▸ Add uses a compact form.** Post to the chart is one filled teal row (face, "Post to the chart", "Analysis or a question", →), with the Setup row ("Entry, stop and target · trackable") beneath. Both fit without scrolling. The hero card stays on larger phones.

The shell's Add fit test, the entry test, the opens-small tests (now expecting each device's own opening height) and the Post screens all pass on the iPhone SE simulator.

Evidence for this round: unit tests **136/136**; large-simulator UI suites **60/60**; SE shell and visual suites **16/16 + 1 skipped**; Release build succeeded. The scroll step of the redraw journey now raises the sheet first: below the tallest height a swipe up grows the sheet, which is a height change, not a scroll. SE screenshots are in `docs/visual-review/v1.5-p6/se/`.

## Still to do

- A spoken VoiceOver walk-through on device (the route announcements are in place) and a Reduce Motion check (every transition reads the environment). Both need the owner's phone.
- **The P6 gate is owner hands-on acceptance.**
