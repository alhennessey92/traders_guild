# v1.5 workspace: P4 checkpoint, the Setup ticket

Claude, 6 October 2026. Branch `claude/1.5.0-marker-workspace`, on top of P3 (`72cc29e`). The owner approved P3 on device. Nothing has been merged into `feat/1.5.0-avatar-markers`.

## What changed

| Area | Change |
|---|---|
| **Long / Short** (owner decision) | An explicit two-way control replaces the read-only side pill. Choosing a side puts Take Profit and Stop Loss on that side of Entry, each keeping its distance from Entry. **While the levels are still the chart's suggestion they flip at once** and stay the suggestion. **Once the author has set a level, or for any saved Setup,** the side change asks first and shows exactly what moves ("Take Profit 62,500.00 → 65,340.00 · Stop Loss 64,840.00 → 63,000.00" · Flip levels / Cancel). Nothing is ever mirrored silently. Levels on the same side of Entry are explained next to the control, and choosing a side fixes them. A flip whose mirrored price would not be a price is not offered. Every flip keeps each level's saved label, colour and style. |
| **Legible ticket** | On the standard sheet, coloured words (green Entry, red Stop Loss) had low contrast. Each level now has a short stroke of its chart line in its colour (Entry solid, TP and SL dashed) and a readable name. The side control and Review's side pill are filled, with white text. |
| **Risk to reward** | "R:R 1 : 2.40" over a small bar split risk (red) and reward (green), like the chart's fills. |
| **Adjust on chart** | A button on the ticket collapses the workspace to its capsule tool bar: "Take Profit and Stop Loss · TP 65,000.00 · SL 63,000.00 · R:R 1:1.17", updating live as the lines are dragged. **✕** restores the levels exactly (identity, label and keys). **✓**, a tap on the bar, or dragging the sheet back up keeps them. |
| **Setup edit on the chart** (owner decision) | Editing a Setup (not locked) now draws its **saved** Entry, Take Profit and Stop Loss on the chart, on its own candle. Take Profit and Stop Loss drag, and each move changes only that level's price: the saved label, colour and unmodelled keys are kept. Entry and the anchor are never written, so they are sent exactly as saved. The saved Entry never follows the latest candle. Locked Setups (past ARMED) show no handles, and their levels refuse every change. |
| **Price fields** | Tapping a price selects it, so typing replaces it. The text is right-aligned, so a tap on the field's left used to put the cursor before the old value. |
| Unchanged | A new Setup's Entry is still the latest close at post (released 1.3.0/1.4.0 semantics). Tracking, the reputation estimate, reasoning, title and context are unchanged. The backend contract is unchanged. |

## Evidence

| Check | Result |
|---|---|
| `MarkerGuidedSetupTests` (new) | The chart's suggestion flips at once and stays the suggestion. The author's levels never flip without asking, and the summary is exact. Choosing the current side does nothing. Same-side levels go on the chosen sides at their distances. A mirror below zero is not offered. Flipping keeps label, colour and width. Adjust cancel restores exactly; adjust done keeps. Only a Setup adjusts. |
| Edit geometry (`MarkerGuidedEditPayloadPreservationTests`, new cases) | Chart handles in an edit move only Target and Stop: anchor and Entry are sent byte-exact, and the target's label and unmodelled keys are kept. Adjust then cancel leaves the drafts as loaded, with nothing to save and no component sent. A saved Setup asks before its side changes. A locked Setup refuses side, adjust and handle moves. |
| `MarkerSetupTicketUITests` (new, real MainView sheet) | Suggested levels flip at once (Take Profit 62,840 · Stop Loss 64,840). After typing 62,500, Long asks with the exact summary; Cancel moves nothing; Flip moves them. Adjust on chart shows the tool bar with the readout, and ✕ returns to the ticket with the levels unchanged. |
| Focused unit suites (11) | **132/132** |
| Workspace UI suites, iPhone 17 Pro / iOS 26.5 | **56/56** (adds the two Setup ticket journeys) |
| Sheet journeys + visual review, iPhone SE / iOS 18.2 | **12/12 + 1 skipped** (hardware keyboard, as in P3) |
| Release build; signed device build | Succeeded |

Screenshots: `docs/visual-review/v1.5-p4/`: the ticket, the side confirmation, the adjust bar, and the Setup at small, raised and Review.

## For you on device

1. **Setup**: Long is selected. Tap **Short**: the lines on the chart flip straight away (they are still the chart's suggestion).
2. Type a Take Profit, then tap **Long**: it asks, and shows what moves.
3. **Adjust on chart**: the workspace becomes the bar. Drag TP or SL and watch the readout. Tap ✕ to put them back, or ✓ to keep them.
4. Edit one of your own ARMED Setups: its saved lines appear on the chart, TP and SL drag, and Entry stays put. Save shows "What changes".

**Question:** the number pad still has its Done button (a floating blue checkmark on iOS 26), because a number pad has no return key. You can also dismiss it by dragging the content down. Keep it or remove it?

## Known, next

- If an edited Setup's candle is not loaded on the chart, there are no lines to drag. The ticket's fields still edit, but **Adjust on chart** shows the chart without handles. That is rare; a follow-up hides the button in that case.
- P5: Add context, free to improve on the original Components tabs.
