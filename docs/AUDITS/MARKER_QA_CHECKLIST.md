# Marker QA Checklist

Use this checklist to validate the March 26, 2026 marker tracking, resolution, tab, and stale-marker recovery pass.

Recommended test setup:
- `User A`: normal user, marker owner, member of `Guild 1`
- `User B`: normal user, friend of `User A`, member of `Guild 1`
- `User C`: normal user, not a friend of `User A`, member of `Guild 1`
- `Mod`: moderator or admin in `Guild 1`
- Two active app sessions for `User A` to verify live sync across sessions
- One active app session for `User B` to verify friend-scope visibility
- One guild with at least two active symbols receiving live or near-live `1m` candles
- One chart opened on a current symbol so the bottom bar marker sheet can be tested
- Access to the left drawer marker section
- Ability to restart chart-service if you want to validate the stale-marker self-heal pass

Out of scope for this checklist:
- APNs / push notifications
- Performance / load testing
- Full moderation QA beyond marker-specific visibility and report side-effects

## Marker Creation And Placement

- [ ] Untracked marker creation: create a non-setup marker such as a poll or note. Expected: it appears in `Today`, `This Week`, and `This Month` for the correct scope, but not in `Active` or `Resolved`.
- [ ] Tracked setup creation: create a tracked setup marker with valid entry, SL, and TP. Expected: it appears in `Active` immediately after save.
- [ ] Personal scope visibility: create a marker as `User A`. Expected: it appears in `Personal` for `User A`.
- [ ] Friends scope visibility: create a marker as `User A`, then view as `User B`. Expected: it appears in `Friends` for `User B`.
- [ ] Guild scope visibility: create a marker as `User A`, then view as `User C`. Expected: it appears in `Guild` for `User C`.
- [ ] Bottom bar symbol scoping: with a chart open on `Symbol X`, create a marker on `Symbol X` and another on `Symbol Y`. Expected: the bottom bar marker feed only shows markers for `Symbol X`.
- [ ] Left drawer cross-symbol feed: create markers on at least two symbols. Expected: the left drawer marker feed can show both because it is guild activity, not single-symbol scoped.

## Active Tracking State

- [ ] Fresh tracked setup shows as active: immediately after creating a tracked setup, it appears in `Active` in both the bottom bar and left drawer.
- [ ] User-facing label clarity: a pre-entry tracked setup shows user-facing `Tracking` language rather than `Armed`.
- [ ] Active-only membership: tracked setups in a live state appear in `Active`; non-setup markers do not.
- [ ] Entry not touched yet: leave a setup where entry has not been touched. Expected: it stays in `Active` / tracking and does not show a resolved result.
- [ ] Bottom bar live PnL chip: open a symbol with a tracked setup in `Active`. Expected: the card shows a current PnL chip when current price is available.
- [ ] Bottom bar TP/SL swing strip: the same active setup card shows the horizontal blue/red strip from entry toward TP or SL.
- [ ] Left drawer live PnL chip: an active tracked setup in the left drawer also shows the current PnL chip once live symbol data has loaded.
- [ ] Left drawer TP/SL swing strip: the same active tracked setup in the left drawer shows the horizontal blue/red strip.
- [ ] Current-price directionality: for a setup currently moving toward TP, the live chip/strip uses the positive blue treatment; when moving toward SL, it uses the negative red treatment.
- [ ] Tracking persistence rule: if current price is far away but entry was never actually touched, the setup remains active/tracking and does not resolve incorrectly.

## Resolution Outcomes

- [ ] TP resolution: create or simulate a tracked setup that hits take profit. Expected: it leaves `Active`, appears in `Resolved`, shows a win/result presentation, and records TP result data.
- [ ] SL resolution: create or simulate a tracked setup that hits stop loss. Expected: it leaves `Active`, appears in `Resolved`, shows a loss/result presentation, and records SL result data.
- [ ] EXPIRED resolution: let a setup exceed TTL or simulate expiry. Expected: it leaves `Active`, appears in `Resolved`, shows non-scoring expired copy, and does not show a scoring win/loss treatment.
- [ ] Same-candle TP/SL conflict: if one candle touches both TP and SL, expected behavior resolves to `SL_HIT` under the current config.
- [ ] Resolved card details: a TP/SL result row shows terminal state plus trigger/PnL-style result data.
- [ ] Expired neutrality: an expired row shows resolved terminal state but no reputation/accuracy scoring callout.
- [ ] No return to active: once a setup is resolved, it does not reappear in `Active`.
- [ ] Resolved tab completeness: `Resolved` includes `TP_HIT`, `SL_HIT`, and `EXPIRED`.

## Tabs, Layout, And Colors

- [ ] Bottom bar primary row: the primary row is `Add | Markers | Analysis`.
- [ ] Bottom bar `Add` color: `Add` remains green when selected.
- [ ] Bottom bar `Markers` color: `Markers` is blue, not orange.
- [ ] Active top-tab color: only the `Active` top tab uses the orange treatment.
- [ ] Other top-tab colors: `Today`, `This Week`, `This Month`, and `Resolved` all use blue-toned treatments.
- [ ] Scope-tab colors: `Guild`, `Friends`, and `Personal` use the darker blue sub-tab treatment.
- [ ] Bottom bar markers layout: `Markers` uses exactly two visible layers: top tabs (`Active | Today | This Week | This Month | Resolved`) and scope tabs (`Guild | Friends | Personal`).
- [ ] Left drawer layout: the left drawer marker section uses the same two-layer tab model as the bottom bar.
- [ ] No extra nesting: there is no third or fourth visible layer of marker tabs in either surface.
- [ ] Analysis simplicity: bottom bar `Analysis` renders as a single universal section with no visible sub-tabs.
- [ ] Count badges: tab counts update correctly when switching top tabs and scopes.
- [ ] Empty states: each empty tab/scope combination shows the correct empty-state title and copy.
- [ ] Fast tab switching: rapidly switch between `Active`, `Today`, and `Resolved`. Expected: no `CancellationError` empty state appears.

## Time Windows And Filtering

- [ ] Today window: markers created today appear in `Today` for the correct scope.
- [ ] This Week window: markers from the last week appear in `This Week` for the correct scope.
- [ ] This Month window: markers from the last month appear in `This Month` for the correct scope.
- [ ] Today/Week/Month includes all intents: setup and non-setup markers both appear in these time-window tabs.
- [ ] Active excludes non-setups: polls/notes/comments do not appear in `Active`.
- [ ] Resolved excludes non-setups: polls/notes/comments do not appear in `Resolved`.
- [ ] Friends filter correctness: `Friends` only shows markers from friends of the current user.
- [ ] Personal filter correctness: `Personal` only shows markers owned by the current user.
- [ ] Guild filter correctness: `Guild` shows all eligible guild markers, not just current user or friends.

## Notifications And Navigation

- [ ] Marker result notification on TP: when a tracked setup hits TP, `User A` receives exactly one `marker_result` notification.
- [ ] Marker result notification on SL: when a tracked setup hits SL, `User A` receives exactly one `marker_result` notification.
- [ ] No marker result notification on EXPIRED: expiry does not create a TP/SL result notification.
- [ ] Marker result navigation: tapping a marker result notification opens the relevant chart / symbol context, not a user profile.
- [ ] Marker activity card navigation: tapping a marker activity card opens the corresponding chart marker context.
- [ ] Marker like notification: `User B` likes `User A`'s marker. Expected: `User A` gets one `marker_like` notification.
- [ ] Marker comment notification: `User B` comments on `User A`'s marker. Expected: `User A` gets one `marker_comment` notification.

## Reputation And Accuracy

- [ ] TP reputation update: a `TP_HIT` result updates `User A`'s guild/global reputation correctly.
- [ ] TP accuracy update: a `TP_HIT` result increments wins and updates accuracy correctly.
- [ ] SL reputation update: an `SL_HIT` result updates `User A`'s guild/global reputation correctly.
- [ ] SL accuracy update: an `SL_HIT` result increments losses and updates accuracy correctly.
- [ ] EXPIRED no reputation impact: an `EXPIRED` result does not change reputation.
- [ ] EXPIRED no accuracy impact: an `EXPIRED` result does not change wins/losses or accuracy.
- [ ] Guild rollups update live: guild-level reputation/accuracy surfaces update without waiting for a manual refresh.
- [ ] Global rollups update live: global reputation/accuracy surfaces update without waiting for a manual refresh.
- [ ] Marker author metrics refresh: visible marker cards refresh author reputation/accuracy metadata after a relevant result.

## Live Sync And Cross-Surface Consistency

- [ ] Active-to-resolved live movement: keep `User A` on two sessions, resolve a tracked setup, and confirm both sessions move it from `Active` to `Resolved` without manual refresh.
- [ ] Bottom bar vs left drawer consistency: the same active or resolved setup appears consistently in both surfaces when the selected filters should overlap.
- [ ] Notification + feed sync: after TP/SL, the notification arrives and the marker feeds update without needing app relaunch.
- [ ] New marker sync: after placing a marker on one session, the relevant marker feeds update on the second session.

## Historical Recovery And Stale-Marker Self-Heal

- [ ] Startup reconcile: stop or restart chart-service with at least one live tracked setup that should already be terminal. Expected: on startup, the processor replays history and resolves the marker correctly.
- [ ] Background reconcile interval: leave chart-service running with a deliberately stale active marker. Expected: it is corrected by the background reconcile pass within the configured interval.
- [ ] Historical TP recovery: if a live TP was missed, the stale-marker sweep resolves it historically as `TP_HIT`.
- [ ] Historical SL recovery: if a live SL was missed, the stale-marker sweep resolves it historically as `SL_HIT`.
- [ ] Historical expiry recovery: if neither TP nor SL was hit and TTL has elapsed, the stale-marker sweep resolves it historically as `EXPIRED`.
- [ ] Historical trigger timestamp: the resolved result uses the candle timestamp where the line was historically crossed.
- [ ] Historical trigger price rule: the resolved result records the TP/SL line price as the trigger price because candle history only proves the line was touched.
- [ ] No duplicate result side-effects: once a stale marker is recovered, later reconcile passes do not create duplicate prediction results, notifications, or reputation events.
- [ ] Terminal marker immunity: already-resolved markers are ignored by later reconcile passes and do not flip states again.

## Negative Cases And Guard Rails

- [ ] Untracked setup isolation: create an untracked setup marker. Expected: it does not enter tracked `Active` / `Resolved` lifecycle behavior.
- [ ] Non-setup isolation: create polls/notes and confirm they never show TP/SL or tracking presentation.
- [ ] Duplicate-terminal suppression: attempt to trigger the same terminal result more than once. Expected: only one result record, one notification, and one reputation/accuracy change occur.
- [ ] Self-like suppression: if allowed by UI, `User A` likes their own marker. Expected: no marker-like notification or unintended reputation gain.
- [ ] Self-comment suppression: `User A` comments on their own marker. Expected: no `marker_comment` notification to self.
- [ ] Symbol mismatch suppression: markers for a different symbol do not leak into the bottom bar feed for the currently selected symbol.

## Final Sanity Pass

- [ ] Tracked setups move cleanly from active/tracking to resolved when TP, SL, or expiry is reached.
- [ ] Stale active markers are eventually corrected by startup or background reconciliation.
- [ ] Bottom bar and left drawer use the same marker tab model and color rules.
- [ ] `Analysis` remains a single universal section without nested tabs.
- [ ] Result notifications, marker feeds, and reputation/accuracy surfaces stay in sync for TP and SL outcomes.
- [ ] Expired setups stay fully neutral for scoring while still appearing in resolved history.
