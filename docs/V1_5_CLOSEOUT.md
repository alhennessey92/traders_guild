# Traders Guild iOS v1.5: where it stands, and what is left

Close-out of the Claude workspace takeover (P0–P7), 9 October 2026.

- **Branch:** `claude/1.5.0-marker-workspace`, 20 commits on canonical `feat/1.5.0-avatar-markers` @ `128ead3`.
- **Canonical:** has not moved since, so integration is a fast-forward. It needs owner approval.
- **Live App Store version:** 1.4.0 (24). 1.4.1 (25) was never released; its changes, and its open QA gaps, are inside v1.5.

Sources:
- the product spec, `docs/version_docs/ios/1.5.0-final-handover.md` (sanctuary);
- the takeover scope, `docs/CLAUDE_V1_5_TAKEOVER.md`;
- the phase checkpoints `docs/V1_5_P1…P7_*` in this repo.

---

## 1. Done

### The creation workspace (P1–P6, each phase owner-accepted on device)

**One continuous sheet**
- Stable detents: dock 11%, browse 35%, working 50%, tall 90%. The sheet opens at working height on compact (SE-class) phones.
- It never drops or re-presents itself while you move between screens.
- Collapse to the capsule dock and resume to the exact screen, values, cursor and scroll.
- The keyboard lifts the sheet in one step, with a deferred collapse while the keyboard is up.

**Session model (P2)**
- The workspace session owns navigation, editors and memory, separate from the draft.
- One route stack.
- Typing and scrolling do not redraw the chart.

**Markers ▸ Add**
- Exactly two choices. *Post to the chart* is the hero card. *Setup* sits below it as "Or plan a trade", with a description. On SE-sized phones both become compact rows.

**Post**
- Details has the identity header, an Analysis/Question ring selector, text, an optional title and Add context.
- Review shows the post as the guild will see it, with an optional Discord channel row. The share prompt is kept after posting.
- Text-only Analysis works.

**Setup ticket**
- Long/Short mirrors the levels automatically until a meaningful edit, then asks before flipping.
- Entry reads "latest price when you post" (the released behaviour).
- Target and Stop are typeable or adjustable on the chart.
- The ticket shows R:R and the tracking badge.
- When tracking is blocked (an open tracked Setup on that symbol and timeframe), the Setup starts untracked and says why.

**Add context**
- Tabs: Indicators (category chips, tiles, settings), Drawings (Levels, Lines, Patterns), Timeframes (up to two) and Notes (note, source link).
- An "On this marker" row lets you edit or remove what's attached. It is always on screen as one row, so adding the first item or removing the last moves nothing.
- Drawings go to the chart with a tool bar.
- Support and resistance start on the chart with a drag handle. The level editor has a typed price, line style and colour.
- The drawing editor was restyled.

**Responses**
- They land directly in Details, with the parent and relationship banner.
- A response can become a Setup and back, with an incompatible-content warning.

**Editing**
- Analysis, Question and Setup edit in the same workspace. Intent and links are fixed.
- A Setup edit shows the saved Entry, Target and Stop on the chart. Target and Stop move; Entry and the anchor never do.
- Tracked Setups that are active or resolved are locked.
- The marker being edited stays selected and prominent.

**Chart framing**
- The draft, or the edited marker, is kept in the strip above the sheet.
- The draft survives the first page of older candles loading.

**Accessibility (P6)**
- Apple's audit went from 152 issues to 125. The remainder were reviewed as intentional or audit noise.
- Controls cap at accessibility1 text size, with the Large Content Viewer.
- Contrast was fixed, and every target is 44pt.
- Each screen is announced as it changes, and Reduce Motion is honoured in code.
- Checked in the Light Grey theme.

### Viewing (owner's hand pass, 9 October)
- The description is a card in the intent's colour, labelled ANALYSIS, QUESTION or WHY THIS TRADE.
- The Setup tracking stepper is single-line ("Tracking" no longer wraps).
- Level lines stop before their price chip.
- All of this applies with the experiment on only; the shipped layout is unchanged with it off.

### Integration and performance (P7)
- **Local-backend integration test PASS.** It covers:
  - creating and editing text-only Analysis, Question and Setup;
  - the tracked-Setup refusal, then an untracked retry with the draft preserved;
  - saved Setup geometry unchanged by an edit, and locked states;
  - context, including level edits;
  - Supports, Challenges and Builds On across timeframes;
  - an auth failure, then a retry.
- **Same-device performance on the owner's iPhone 14 Pro: no regression** against `128ead3`, warm and interleaved. Selected pans averaged 3.59 s of CPU against 3.65 s. 0 of 40 pans drifted off the seeded markers, and avatar traffic was identical.
- **Local stack repaired and made durable.** The chart-service ran from a deleted temporary export. It is now at `~/TradersGuildLocal/backend-5061824`.
- The DEBUG API log now redacts account emails (found in the integration run).
- The perf driver was hardened: it never types credentials, it settles the price range before its reference, and the device trace is off by default (it filled the phone).

### Tests at close (9 October)
- Unit: 141 passed, 1 skipped (the opt-in local-backend test).
- Large-simulator UI: 64 of 64, including the accessibility audit (124 issues recorded, all reviewed).
- SE suites: 17 passed, 1 skipped.
- The Release build succeeds.

---

## 2. Required before v1.5 can ship (handover phases C–G)

| # | Item | State | Who |
|---|---|---|---|
| 1 | **Integrate** this branch into `feat/1.5.0-avatar-markers` | Fast-forward, ready | Owner approval |
| 2 | **Promote the experiment gate.** Release builds compile the switch to `false`, so a v1.5 Release build today ships the *old* markers and creation menu. Choose: remove the gate, or a controlled production flag. Plus a rollback switch. | Not started; plan needed | Owner + Claude/Astra |
| 3 | **Backend promotion**: text-only Analysis (`780398f`) must reach production *before* the iOS release, or plain Posts are rejected with 422. Review tracked-Setup ordering (`5061824`): old clients may get 422 for out-of-order tracked Setups, and some legacy rows may refuse note-only edits. | Local only | PROD DEPLOY 2, owner |
| 4 | **Legacy-data strategy (Phase C)**: inventory marker rows, components, links, comments/likes, poll/news/personal/alert data and derived stats. Then retain, or a controlled reset with backup. | Not started | Astra/owner |
| 5 | **Released-client compatibility**: run Android 1.4.0 (19) and iOS 1.4.0, 1.3.x and 1.1.1/1.1.2 against text-only Analysis and v1.5 Setups/responses. Check decode, display, realtime and navigation. Older editors require context to save a text-only Analysis; that is a known limitation to document. | Not run | Sol (bounded) / Claude |
| 6 | **Notifications and deep links**: replies, link relationships, Setup results, cross-guild and cross-timeframe navigation, realtime reconciliation. Push (FCM/APNs) is disabled on local DEV, so push delivery for v1.5 flows has not been exercised. | Unchanged code; not validated | Needs a push-capable environment |
| 7 | **Realtime from a second account** (posts arriving live) | Not run | Owner + Claude, 5 minutes |
| 8 | **Setup lifecycle end to end** on a v1.5-created tracked Setup (ARMED → ACTIVE → TP/SL/EXPIRED, result card, reputation). Only locks on existing EXPIRED rows were exercised. | Not run | Local DEV over time |
| 9 | **Sharing**: Discord/X/link share and the OG card for text-only Analysis, Question and v1.5 Setups. Discord is disabled locally. | Not validated | Staging/production-like environment |
| 10 | **Device accessibility**: a spoken VoiceOver walkthrough and Reduce Motion on the phone | Code done; not walked through | Owner |
| 11 | **Performance gaps**: frame hitches (the trace was off in P7), cold-avatar runs, dense charts | Warm CPU/memory done | Claude + owner's phone (short per-test traces) |
| 12 | **1.4.1 QA gaps** inherited into v1.5 (Setup detail at AX sizes, relationship selection/cancel, …) | Open, per `1.4.1.md` | Owner/Claude |
| 13 | **Release candidate**: exact iOS+backend commits, config, migration/reset steps, known limitations, rollback, TestFlight QA | Not started | Astra/PROD DEPLOY 2 |

---

## 3. Feature areas that still need building (deferred by the handover, §23/§38)

**Important consequence:** with v1.5 on, marker creation offers only Post and Setup. **Polls, Alerts, News, Reactions and Personal markers can no longer be created** until they are re-homed. Existing ones still render, open, vote and edit through their existing flows.

### Notifications
- **Today:**
  - Marker notification types exist: new marker, comment, like, response, link relationship, result and mention.
  - Rows show the sender's avatar, and Setup results say "Your setup hit TP/SL … open it to share the result".
  - v1.5 did not change notifications.
- **Needed:**
  - First, validation (item 6 above).
  - Then a v1.5 redesign: avatar- and intent-aware copy, relationship-specific wording ("@sam Challenges your Analysis"), grouping, and deep links that open the refined view sheet on the exact marker and timeframe.
  - Watch/Alert notifications need a recipient policy decision (see Alerts).

### Share-sheet and OG cards
- **Today:**
  - The post-share prompt is kept.
  - The Marker card v3 (server, `og_images.py`, `MARKER_CARD_VERSION = 3`) has an author identity block with the avatar, but draws the *old intent glyph* on its chart.
  - Result cards exist for resolved Setups.
- **Needed:**
  - Cards in the avatar-led model: the author's face as the marker, the intent ring and badge, and the contribution text.
  - A good layout for text-only Analysis and for Question.
  - Response/relationship cards ("Challenges @sam").
  - Bump `MARKER_CARD_VERSION` in all three places so shared links re-render.

### Polls
- **Today:** standalone Poll intent only, with voting in the view sheet. On the backend, poll options and votes are tied to `intent = 'poll'`: create, response building and the vote route all require it. The update request has no poll fields.
- **Needed:**
  - Poll as an attachment on a Post: a nullable poll question on the marker, reuse of the option/vote rows, and a vote route that accepts attached polls. Options become immutable once voted.
  - iOS: an Add-context composer and the view-sheet voting.
  - Old-client checks: old apps would not see an attached poll.
- The contract is drafted in `docs/v1_5_sheet_ux_review/EXPANDED_FEATURE_CONTRACTS.md`.

### Alerts / Watch
- **Today:** an Alert is a marker with a severity-prefixed note. There is no condition, trigger or status model; the processor evaluates only Setups.
- **Owner decision on record:** a guild-visible watch condition attached to a post.
- **Needed:**
  - Decisions first: the exact trigger semantics (price source, crossing vs touch, one-shot vs repeat) and who gets notified.
  - Then a Watch-condition table, its own evaluator (kept out of Setup reputation and accuracy), status on the chart, and the iOS UI.

### News / sources
- A source link (`link.url`) already attaches to v1.5 Analysis through Add context, so it is done for Analysis.
- A Catalyst post type is deferred: it would need a `post_kind` subtype field, never a new intent string.

### Personal → visibility
- The backend already has guild/private visibility, with filters on most read paths.
- v1.5 is Guild-first by decision.
- **Needed:** a full authorization audit (lists, UUID reads, links/shares, Discord, WebSocket audiences, notifications), then a visibility control on Post/Setup.

### Reactions
- Likes and comment emoji reactions exist, and a legacy Reaction marker type exists.
- **Needed:** lightweight emoji reactions *on a marker*, with a new table and endpoint, viewability checks and filtered realtime delivery.

### New post types
- Observation, Update and Catalyst, as a persisted `post_kind` subtype on Analysis. This is compatible with old clients and needs no new intent strings.

### Structured objects
- Level/Zone as first-class objects. Only worth doing if chart behaviour justifies it.

### Android
- No v1.5 work exists (no branch). It follows the validated iOS spec, and does not start automatically.

### Chart density
- Clustering or zoom-dependent sizing only if device evidence demands it. None has.

---

## 4. Housekeeping

- **Temporary perf worktree:** `/private/tmp/tg-claude-ws/perf-base` (detached `128ead3` plus the driver). Remove with `git worktree remove` when done.
- **Perf tooling:** the run scripts and results are in this session's scratchpad, which is ephemeral. The driver and `run_perf.py` with the trace opt-in are in the repo.
- **Local stack:** the chart-service runs from `~/TradersGuildLocal/backend-5061824`, using `compose.chart-5061824.yml`. Recreate it as in the P7 checkpoint. The other services use `.worktrees/linked-markers-backend`.
- **QA credentials:** `~/TradersGuildLocal/weekend-2026-10-03/qa-creds.json` (mode 600, slots a–e). Never print it, and scan logs after any run that uses it.
- **Older branches:** `sol/*` and `claude/1.5.0-avatar-markers` are preserved and not merged.
- **Phone:** the TG LinkedDev icon launches without the experiment. Use the persisted switch in the fixture gallery, or launch from the Mac.
