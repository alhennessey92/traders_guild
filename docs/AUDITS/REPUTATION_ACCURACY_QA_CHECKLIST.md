# Reputation And Accuracy QA Checklist

Use this checklist to validate the March 26, 2026 reputation and accuracy audit pass.

Recommended test setup:
- `User A`: normal user, marker owner, member of `Guild 1` and `Guild 2`
- `User B`: normal user, member of `Guild 1`, used for likes/comments and setup interactions
- `User C`: normal user, member of `Guild 1`, used as a second live observer for guild-wide updates
- `Mod`: moderator or admin in `Guild 1`
- Two active app sessions for `User A` to verify self updates across sessions
- One active app session for `User C` to verify guild-wide live updates for other members
- At least one tracked marker owned by `User A` in `Guild 1`
- At least one second tracked marker owned by `User A` in `Guild 2`
- At least one untracked marker owned by `User A`
- At least one marker comment on `User A`'s marker written by `User B`

Out of scope for this checklist:
- APNs / push notifications
- Awards
- Future reputation events that are defined but not wired: `comment_liked`, `message_liked`, `content_trending`
- Performance/load testing

## Canonical Rules Display

- [ ] Global reputation breakdown sheet: open the global reputation breakdown for `User A`. Expected: it shows `Prediction`, `Social`, optional `Activity`, and optional `Penalties`, plus a `How Reputation Changes` section that only lists active rules.
- [ ] Guild reputation breakdown sheet: open the guild reputation breakdown for `User A` in `Guild 1`. Expected: it shows the same active rule categories and does not advertise inactive/future event types.
- [ ] Global accuracy breakdown sheet: open the global accuracy breakdown for `User A`. Expected: it shows a `How Accuracy Changes` section stating `TP_HIT` counts as a win, `SL_HIT` counts as a loss, and `EXPIRED` does not change accuracy.
- [ ] Guild accuracy breakdown sheet: open the guild accuracy breakdown for `User A` in `Guild 1`. Expected: the same tracked-setup-only rules are shown.
- [ ] Freshness badge: each reputation and accuracy breakdown sheet shows a live/freshness badge such as `Updated just now`.

## User Reputation Inputs

- [ ] Marker like gain: `User B` likes a marker owned by `User A` in `Guild 1`. Expected: `User A` gains guild reputation, gains global reputation, the event appears once in recent impact/history, and the guild/global reputation cards update live.
- [ ] Marker unlike reversal: `User B` removes that like. Expected: the corresponding reputation is reduced once, the event appears as a reversal, and totals return to the prior value.
- [ ] Marker comment gain: `User B` comments on `User A`'s marker in `Guild 1`. Expected: `User A` gains social reputation once, and the event appears once in recent impact/history.
- [ ] Marker comment deletion reversal by author: `User B` deletes their comment on `User A`'s marker. Expected: the earlier comment reputation is reversed once for `User A`, and totals/history update accordingly.
- [ ] Marker comment deletion reversal by moderator: recreate the comment, then have `Mod` delete it. Expected: the earlier comment reputation is reversed once for `User A`, same as author deletion.
- [ ] Report penalty: apply a moderation/report penalty to `User A`. Expected: `User A` loses reputation, `Penalties` reflects the change, and guild/global reputation displays update accordingly.
- [ ] Activity bonus: trigger the daily activity processor path for `User A`. Expected: reputation increases under `Activity` and appears in recent history.
- [ ] Streak bonus: trigger a streak bonus for `User A`. Expected: reputation increases under `Activity` and appears in recent history.
- [ ] Decay: trigger the inactivity decay path for `User A`. Expected: reputation decreases under `Penalties`, history records the decay, and totals reconcile.

## Accuracy Inputs

- [ ] TP result in guild: resolve a tracked setup owned by `User A` in `Guild 1` as `TP_HIT`. Expected: guild accuracy win count increments, total predictions increments, accuracy rate updates, and a `prediction_win` reputation event is recorded.
- [ ] SL result in guild: resolve a tracked setup owned by `User A` in `Guild 1` as `SL_HIT`. Expected: guild loss count increments, total predictions increments, accuracy rate updates, and a `prediction_loss` reputation event is recorded.
- [ ] EXPIRED setup: resolve a tracked setup owned by `User A` in `Guild 1` as `EXPIRED`. Expected: no reputation change, no accuracy change, and no prediction impact item appears.
- [ ] Recent impact filtering: after a TP and SL outcome, open guild/global accuracy breakdown sheets. Expected: `Recent Impact` only shows prediction events, not likes/comments/activity bonuses.
- [ ] Streak updates: after consecutive TP or SL results, verify current streak, loss streak, and best streak values update correctly in guild/global accuracy views.
- [ ] 30-day rolling accuracy: with at least a few prediction results in the last 30 days, verify the rolling 30-day card updates and reflects recent results.
- [ ] Average R:R: for tracked setups with valid risk/reward data, verify average R:R updates after resolved predictions.

## Guild And Global Rollups

- [ ] Guild reputation rollup: perform a reputation-changing action for `User A` in `Guild 1`. Expected: `Guild 1`'s aggregate guild reputation updates without waiting for a batch job.
- [ ] Guild accuracy rollup: resolve a tracked setup for `User A` in `Guild 1`. Expected: `Guild 1`'s total predictions, correct predictions, and average accuracy update without waiting for a batch job.
- [ ] Global reputation rollup across guilds: perform reputation actions for `User A` in both `Guild 1` and `Guild 2`. Expected: global reputation reflects the weighted/aggregate result across active guild memberships.
- [ ] Global accuracy rollup across guilds: resolve tracked setups for `User A` in both `Guild 1` and `Guild 2`. Expected: global accuracy and global prediction totals reflect active memberships rather than marker-volume proxies.
- [ ] Guild contribution breakdown: open `User A`'s global reputation view. Expected: guild contributions list shows both guilds and their contribution ordering/weights consistently with the current memberships.

## Live Update Propagation

- [ ] Current user guild reputation live patch: while `User A` is viewing `Guild 1`, trigger a reputation event for `User A`. Expected: current guild membership reputation in app state updates immediately without manual refresh.
- [ ] Current user global reputation live patch: trigger a reputation event for `User A`. Expected: the global reputation shown in user-global surfaces updates immediately.
- [ ] Current user guild accuracy live patch: resolve a tracked setup for `User A` in `Guild 1`. Expected: current guild accuracy updates immediately in the user bar and breakdown-linked views.
- [ ] Current user global accuracy live patch: resolve a tracked setup for `User A` in either guild. Expected: global accuracy updates immediately in the global profile header/overview.
- [ ] Cross-session current-user sync: keep two sessions open as `User A`, then trigger a reputation or prediction event. Expected: both sessions reflect the updated values without manual refresh.
- [ ] Guild-wide observer sync: keep `User C` online in `Guild 1`, then trigger a reputation or prediction event for `User A`. Expected: `User C` sees `User A`'s member row / leaderboard / related surfaces update without manual refresh.

## Breakdown And Profile Surfaces

- [ ] User guild profile: open `User A`'s guild profile, trigger a rep change, then an accuracy change. Expected: the profile refreshes and shows the new canonical values.
- [ ] User global profile: open `User A`'s global profile, trigger a rep change, then an accuracy change. Expected: the profile refreshes and shows the new canonical values.
- [ ] Guild reputation breakdown: with the sheet open, trigger a rep event for `User A` in the same guild. Expected: breakdown rows, recent impact, weekly delta, and freshness badge refresh.
- [ ] Guild accuracy breakdown: with the sheet open, resolve a tracked setup for `User A` in the same guild. Expected: performance, streaks, rolling accuracy, recent impact, and freshness badge refresh.
- [ ] Global reputation breakdown: with the sheet open, trigger rep events across one or two guilds. Expected: breakdown, modifiers, guild contributions, and recent impact refresh.
- [ ] Global accuracy breakdown: with the sheet open, resolve tracked setups in one or two guilds. Expected: totals, record, streaks, rolling accuracy, and recent impact refresh.

## Leaderboards And Member Lists

- [ ] Guild member list reputation: open the guild member list for `Guild 1`, then trigger a reputation change for `User A`. Expected: `User A`'s row updates with the new guild/global reputation values.
- [ ] Guild member list accuracy: resolve a tracked setup for `User A` while the guild member list is open. Expected: `User A`'s accuracy row updates live.
- [ ] Guild user detail view: open `User A`'s detail view from the member list, then trigger rep and accuracy changes. Expected: the detail card updates in place.
- [ ] Guild reputation leaderboard: open the guild leaderboard and trigger a reputation change for `User A`. Expected: ordering and displayed values update correctly if the change affects rank.
- [ ] Guild accuracy leaderboard: open the accuracy leaderboard and resolve a tracked setup for `User A`. Expected: displayed values refresh and ordering changes if rank changes.
- [ ] No duplicate jumps: trigger a single reputation or accuracy event. Expected: leaderboard rows update once and do not flicker through duplicate inserts.

## Marker Activity And Analysis Surfaces

- [ ] Top markers view author metrics: open top markers for `Guild 1`, then trigger a reputation or accuracy change for a visible marker author. Expected: displayed author reputation/accuracy-related metadata refreshes.
- [ ] Chart-sheet analysis / marker section: open the chart sheet markers/analysis surface for a marker by `User A`, then trigger a rep or prediction result. Expected: the related author performance information refreshes.
- [ ] Untracked marker isolation: interact with an untracked marker. Expected: marker activity may change, but tracked prediction accuracy totals do not change.
- [ ] Generic marker-volume isolation: verify markers placed / activity counters may change independently, but reputation and accuracy cards continue to reflect canonical reputation-service values.

## Negative Cases And Suppression

- [ ] Self-like suppression: if the UI allows it, `User A` likes their own marker. Expected: no reputation is awarded.
- [ ] Self-comment suppression for reputation: `User A` comments on their own marker. Expected: no extra social reputation is awarded to `User A`.
- [ ] Comment deletion without original award: delete a comment that never created a valid reputation award. Expected: no duplicate reversal or extra negative event is applied.
- [ ] Inactive event types hidden: inspect the reputation UI after normal usage. Expected: `comment_liked`, `message_liked`, and `content_trending` do not appear as active rules or recent-impact items unless they become truly wired.
- [ ] EXPIRED visibility suppression: resolve a setup as `EXPIRED`. Expected: it does not appear as a win/loss in recent impact and does not alter displayed accuracy.

## Reconciliation And Consistency

- [ ] Guild totals reconcile: compare a guild member's displayed reputation breakdown against their total guild reputation. Expected: prediction + social + activity + penalties reconciles to the shown total.
- [ ] Global totals reconcile: compare the global reputation breakdown against the global total. Expected: prediction + social + activity + penalties reconciles to the shown total.
- [ ] Accuracy totals reconcile in guild: verify guild wins + losses equals total predictions for resolved tracked setups, excluding expired setups.
- [ ] Accuracy totals reconcile globally: verify global wins + losses equals global total predictions across active guild memberships, excluding expired setups.
- [ ] History uniqueness: each reputation-changing action creates one matching recent impact/history entry, and reversals also appear once.
- [ ] No stale proxy accuracy: compare a user's global accuracy display with generic marker-volume stats. Expected: the accuracy display follows resolved tracked setups, not total markers placed.

## Final Sanity Pass

- [ ] Every active reputation rule listed in the audit is testable from the UI or admin flow and updates the expected surfaces.
- [ ] Every tracked prediction result updates both reputation and accuracy where applicable.
- [ ] Guild-wide viewers receive live member performance updates without manual refresh.
- [ ] Current-user profile and breakdown surfaces stay in sync with member list and leaderboard values.
- [ ] Comment deletion/moderation reverses prior comment-earned reputation exactly once.
- [ ] Expired tracked setups remain fully neutral for both reputation and accuracy.
- [ ] Inactive/future reputation event types remain absent from the visible rules and active-impact UI.
