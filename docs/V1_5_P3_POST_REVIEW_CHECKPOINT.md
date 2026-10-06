# v1.5 workspace: P3 checkpoint, Post, Review and responses

Claude, 6 October 2026. Branch `claude/1.5.0-marker-workspace`, on top of P2 (`91e9cab`). Nothing has been merged into `feat/1.5.0-avatar-markers`. **This is the P3 owner visual gate.**

## What changed

| Area | Change |
|---|---|
| **Sheet background** (owner: "appears darker than other sheets") | The workspace and the Markers ▸ Add surface now use the app's standard sheet: material, gradient and honeycomb. The opaque special case is gone. |
| **Secondary text** | On the standard sheet the app's fixed mid-grey all but vanished. The workspace's secondary lines now use `overlayPanelSecondaryText`, the same token the marker viewing panels use: white at 74% on Dark and Mid Grey, unchanged on Light Grey. Placeholders and disabled buttons stay dim. |
| **Header carries the screen** | Your face (live ring), then the screen's name with the task beneath it: "New Analysis / Posting to Alpha Guild" on Details, then "Review / New Analysis", "Add indicator / New Analysis", and so on. The title cross-fades as the screen below slides, like a navigation bar. Each screen now starts with its content: the large "Post details" / "Review" titles are gone, which is about 40pt back at the small height. |
| **Analysis / Question** | Two ring chips, each carrying its marker badge glyph and colour. The chosen one fills, as your face's ring and the draft marker recolour. The chips are left-aligned rather than a full-width segmented bar. |
| **Review = what the guild sees** | Laid out as a member reads your marker when they tap it (the refined viewing layout): your face, then "@you", then "Analysis · 5 Minutes chart · now"; the relationship; the title (large) and your words; the Setup ticket or the anchor line; the context. It sits in one frame, so it reads as a preview. |
| **Discord** | A new post's Review has the existing "Post to Discord" row, the same component and per-guild channel memory as the legacy composer, when the guild has a usable channel. Channels load best-effort and are written only when they change, so they never redraw the chart. Edits don't show it, since they have already been posted. |
| **Response banner** | A workspace banner draws the relationship as the chart does: the parent's face, tethered in the relationship's colour (with its icon) to your face, then "Challenges @sam's BTC breakout · Parent on 1h", with Change and ✕. Your face wears the ring of what you are posting, so turning the response into a Setup shows here too. The parent's face comes from a new client-only `parentAvatar` on the link context; it is never sent. The released linked-marker banner is untouched. |
| Tests | The 3 tests that were stale at baseline now pass, rewritten for the new screens. The workspace's scroll helpers find the screen by `guided.screen`. There is a new visual-review journey (`MarkerWorkspaceVisualReviewUITests`). |

Unchanged: the draft model, Setup semantics (Entry is the latest price at post), submission, the backend contract, and the experiment-off path. Only the shared sheet background branch was removed, and it was experiment-only.

## Evidence

Screenshots: `docs/visual-review/v1.5-p3/{large,se}/`, covering Analysis and Question at the small height, Analysis raised, Review, Setup small and raised, Setup Review, a response with its banner, and a response turned into a Setup.

| Check | Result |
|---|---|
| Focused unit suites (10) | **119/119** |
| Workspace UI suites, iPhone 17 Pro / iOS 26.5 (shell, final workspace, sheet shell, journeys, editing, accessibility, viewing, visual review) | **54/54**. The 3 baseline-stale tests now pass, rewritten for the new screens. |
| Sheet journeys + visual review, iPhone SE / iOS 18.2 | **12/12 + 1 skipped**. The keyboard-lift check skips because the simulator has a hardware keyboard attached: the keyboard is reported off-screen at 705 on a 667pt screen, from tall as well as small. |
| Shell redraws while navigating, scrolling and staging editor values | **0**. Review's Discord load writes only on change. |
| Release build; signed device build | Succeeded |

## For you on device

1. Markers ▸ Add ▸ **Post to the chart**. The sheet should look like your other sheets. The header says "New Analysis · Posting to <guild>" and the text box is directly beneath the type chips.
2. Tap **Question** and back. The chip, your face's ring and the marker on the chart recolour together.
3. Write, then **Review**. It should read like your post when someone taps it. If the guild has a Discord channel, the Discord row is under it.
4. Open someone's marker ▸ **Challenges**. You should see their face tethered to yours. Then **Respond with a Setup**: your face's ring changes in the banner.

**Questions for you at this gate:**
1. Does the standard sheet background look right now, including the text contrast?
2. Do you like the header carrying the screen name, instead of the big "Post details" / "Review" titles?
3. Is Review close enough to "the real thing"?

## Known, next

- **Setup ticket colours** (P4). On the standard sheet, the coloured labels (green Entry, red Stop Loss, the green "Setup" tag) have low contrast. The P4 ticket redesign will move colour into chips and lines, with white labels.
- **Add context** (P5) will use the original Components tab layout, per your note.
- On an iPhone SE at the small height, the text box shows its first line and the rest is a scroll or a raise away. A raise shows everything.
- The SE simulator here has a hardware keyboard attached, so it shows no on-screen keyboard. The keyboard-lift check skips there and is covered on the iPhone 17 Pro simulator.
