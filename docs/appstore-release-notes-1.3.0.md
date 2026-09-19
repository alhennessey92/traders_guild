# App Store "What's New" — Traders Guild 1.3.0 (iOS)

Build on each other's ideas. Any marker can now be answered with another marker — **supports**, **challenges** or **builds on** — and a discussion becomes a thesis you can see on the chart. Select a linked marker and its thesis lights up: related markers stay bright, the rest fade, and colour-coded lines trace who answered whom. Tap any highlighted marker to walk the thesis; open the sheet to read the full thread.

Faint lines join linked markers at rest, so you can tell a discussion is there before you tap. A response on another timeframe wears a small round badge — tap it to jump across, and jump back the same way.

Placing a response shows exactly what it answers: the parent stays lit and a line follows your marker as you position it.

Plus: markers keep their place when you switch timeframes, deletions made on another device reach every open chart, and connector lines and badges stay fixed to their markers while you pan and zoom.

## Internal release details

* Marketing version: `1.3.0`
* Build: `23` — **check App Store Connect before archiving**: if a 1.3.0 build 23 was ever
  uploaded to TestFlight, bump `CURRENT_PROJECT_VERSION` to 24 first.
* Cut from `74c772c` (`fix: finalize 1.2.1 guild and marker flows`, the 1.2.1 candidate);
  the candidate is the head of `feat/1.3.0-linked-markers` once `claude/1.3.1-production-feedback`
  has been fast-forwarded into it (the branch name is a working label — the shipped version is 1.3.0).
* Backend: linked markers are live on production — PR #24 (`release/1.3.0-linked-markers`) was
  merged 2026-09-16, migration `m1n2o3p4q5r6` is additive, and `LINKED_MARKERS_ENABLED` is on
  (verified by production QA on 2026-09-19). Nothing in the production-feedback commits
  (`602a19b..33cf11d`) touches the API client or any wire DTO; no backend deploy is needed for
  this submission.
* Same-account devices only learn of a deletion at their next resync (foreground, reconnect or
  the staleness watchdog): the realtime router drops every event whose `sender_id` matches the
  socket's user. Other members' devices update instantly. A backend one-liner would change this;
  deliberately not done for this release.
* Old clients decode every new payload unchanged: the link fields are optional, a response is an
  ordinary marker to 1.2.x, and the `marker_response` notification type degrades to title/body.
* Shipping path: the **traders_guild GCP Public Prod** scheme, Archive (Release). Never the
  Prod QA or LinkedDev schemes — they carry their own bundle ids and plists. A Release simulator
  build of the shipping scheme at the candidate compiled warning-free with bundle
  `co.tradersguild.app` 1.3.0 (23) and no development endpoints in the binary.
* macOS sources, targets and project settings are outside this release —
  `grep -c TradersGuildMac traders_guild.xcodeproj/project.pbxproj` is 0.
* Unit target at the candidate: 697/697.
* Known, tracked, not blocking: the `Currently, only presenting a single sheet is supported`
  warning seen twice in the owner's device logs has not been reproduced on the simulator.
* Android ships linked markers from its own repo (code 18, `feat/1.3.0-linked-markers` there).

### Scope check

Everything in this release, measured against the `1.2.1` candidate (`74c772c`) — 96 commits,
by area:

| Area | Commits (first…last) | User-facing |
| --- | --- | --- |
| Link topology, thread window, connector geometry, wire contract | `69114c0`…`f7894de` | no (foundation) |
| Focus rendering: rings, response badge, connectors, fade | `f288224`, `9f6f108`, `828b579` | yes |
| Respond flow: carry the link through placement, banner, relationship row, thesis disclosure, notification | `9705b1c`, `67c4a17`, `18da7c6`, `ea5c169` | yes |
| Cross-timeframe jump badges (round, outward on a tether, ellipsis chooser) | `0c168f2`, `bbce60e`, `6af4558`, `31dae06` | yes |
| Lines at rest, off-screen endpoints, via-deleted bridges | `bb03d91` | yes |
| Deletion reconciliation, layout memory, centring from the sheet, ring under badges | `602a19b`, `d2d882b`, `95da3bf`, `105d67b` | yes |
| Viewport-independent routing and badge placement; prepend index shift | `a22b676`, `3ea5e63`, `33cf11d` | yes |
| Launch transition (icon, wordmark) | `e9fd646`, `9650886` | yes |
| Indicator level label formatting (`%.0f` on a Double) | `47e4eaa` | yes (labels) |
| Production QA scheme, docs, tests, evidence | `934a106`, `cdd0a00`, the rest | no |
