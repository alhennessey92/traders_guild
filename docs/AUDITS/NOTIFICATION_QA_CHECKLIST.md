# Notification QA Checklist

Use this checklist to validate the March 26, 2026 notification implementation pass.

Recommended test setup:
- Two normal users: `User A` and `User B`
- One moderator or admin account: `Mod`
- One guild with at least one chatroom, one announcement, and one event
- Two active app sessions for at least one user to verify cross-device sync
- One marker owned by `User A`

Out of scope for this checklist:
- APNs / push notifications
- Awards
- Watchlist / symbol-activity notifications

## Messaging And Social

- [ ] DM message: `User A` sends `User B` a DM. Expected: `User B` gets one `dm` notification in the feed, unread count increments, badge surfaces update, websocket delivery is live, and tapping opens the DM thread.
- [ ] DM mute suppression: `User B` mutes the DM thread, then `User A` sends another DM. Expected: no feed notification is created for `User B`.
- [ ] DM reaction: `User A` reacts to a DM message written by `User B`. Expected: `User B` gets one `content_reaction` notification and tapping opens the DM thread.
- [ ] DM self-reaction suppression: `User B` reacts to their own DM message. Expected: no notification is created.
- [ ] Chatroom mention: `User A` posts a message in a guild chatroom mentioning `User B`. Expected: `User B` gets one `mention` notification and tapping opens that chatroom.
- [ ] Chatroom mute suppression: `User B` mutes the chatroom, then `User A` mentions `User B` again. Expected: no feed notification is created for `User B`.
- [ ] Normal chatroom message policy: `User A` sends a chatroom message without mentioning `User B`. Expected: no feed notification is created; only chat unread/activity behavior changes.
- [ ] Chatroom reaction: `User A` reacts to a chatroom message written by `User B`. Expected: `User B` gets one `content_reaction` notification and tapping opens the chatroom.
- [ ] Chatroom self-reaction suppression: `User B` reacts to their own chatroom message. Expected: no notification is created.
- [ ] Friend request: `User A` sends a friend request to `User B`. Expected: `User B` gets one `friend_request` notification and tapping opens the profile flow.
- [ ] Friend accept: `User B` accepts `User A`'s request. Expected: `User A` gets one `friend_accept` notification and tapping opens the DM thread.

## Guild And Community

- [ ] Announcement created: a guild announcement is created by someone other than `User B`. Expected: active guild members receive one `announcement` notification and tapping opens the announcement detail.
- [ ] Event created: a guild event is created by someone other than `User B`. Expected: active guild members receive one `event` notification and tapping opens the event detail.
- [ ] Event shared: `User A` shares an event with `User B`. Expected: `User B` gets one `event` notification with share-specific copy and tapping opens the event detail.
- [ ] Guild invite: `User A` invites `User B` to a guild. Expected: `User B` gets one `guild_invite` notification with inline accept/decline actions.
- [ ] Membership request submitted: `User A` requests to join a guild. Expected: guild moderators/admins/owner receive one `membership_request_submitted` notification.
- [ ] Membership request decision: a moderator approves or declines `User A`. Expected: `User A` gets one `membership_request_decision` notification.
- [ ] Member joined: `User A` joins a guild successfully. Expected: moderators/admins/owner get one `member_joined` notification and `User A` also receives the join confirmation notification if that flow is enabled in the guild path.

## Moderation

- [ ] Member banned: a moderator bans `User A`. Expected: `User A` gets one `member_banned` notification.
- [ ] Member unbanned: a moderator unbans `User A`. Expected: `User A` gets one `member_unbanned` notification.
- [ ] Member kicked: a moderator kicks `User A`. Expected: `User A` gets one `member_kicked` notification.
- [ ] Member muted: a moderator mutes `User A`. Expected: `User A` gets one `member_muted` notification.
- [ ] Member unmuted: a moderator unmutes `User A`. Expected: `User A` gets one `member_unmuted` notification.
- [ ] Member suspended: a moderator suspends `User A`. Expected: `User A` gets one `member_suspended` notification.
- [ ] Member unsuspended: a moderator unsuspends `User A`. Expected: `User A` gets one `member_unsuspended` notification.
- [ ] Role changed: a moderator changes `User A`'s guild role. Expected: `User A` gets one `role_changed` notification.
- [ ] User report: `User A` reports `User B`. Expected: moderators/admins/owner receive one `content_report` notification and tapping opens admin reports.
- [ ] Chatroom report: `User A` reports a chatroom. Expected: moderators/admins/owner receive one `content_report` notification and tapping opens admin reports.
- [ ] Chatroom message report: `User A` reports a chatroom message. Expected: moderators/admins/owner receive one `content_report` notification and tapping opens admin reports.
- [ ] DM message report: `User A` reports a DM message. Expected: moderators/admins/owner receive one `content_report` notification and tapping opens admin reports.
- [ ] Chart chat report: `User A` reports a chart chat message. Expected: moderators/admins/owner receive one `content_report` notification and tapping opens admin reports.
- [ ] Marker report: `User A` reports a marker. Expected: moderators/admins/owner receive one `content_report` notification and tapping opens admin reports.
- [ ] Marker comment report: `User A` reports a marker comment. Expected: moderators/admins/owner receive one `content_report` notification and tapping opens admin reports.

## Marker And Reputation

- [ ] Marker result: a tracked marker owned by `User A` resolves or hits a result state. Expected: `User A` gets one `marker_result` notification.
- [ ] Marker like: `User B` likes a marker owned by `User A`. Expected: `User A` gets one `marker_like` notification.
- [ ] Marker like self-action suppression: `User A` likes their own marker if the UI allows it. Expected: no notification is created.
- [ ] Marker comment: `User B` comments on `User A`'s marker. Expected: `User A` gets one `marker_comment` notification.
- [ ] Marker comment self-action suppression: `User A` comments on their own marker. Expected: no `marker_comment` notification is created for `User A`.
- [ ] Marker comment reaction: `User B` reacts to a marker comment written by `User A`. Expected: `User A` gets one `content_reaction` notification.
- [ ] Chart chat reaction: `User B` reacts to a chart chat message written by `User A`. Expected: `User A` gets one `content_reaction` notification.
- [ ] Reputation tier change: adjust `User A` so a tier boundary is crossed. Expected: `User A` gets one persisted `reputation_tier_change` notification and the live payload matches the normal feed DTO shape.
- [ ] Reputation update live-only: trigger a reputation delta that does not change tiers. Expected: live app state updates without creating a feed notification.
- [ ] Accuracy update live-only: resolve a prediction for `User A`. Expected: live app state updates without creating a feed notification.

## Read, Delete, Sync, And Badges

- [ ] Mark read on one device: open one notification on device/session 1. Expected: it becomes read there and also updates on device/session 2 without a manual refresh.
- [ ] Mark all read: use the mark-all-read flow. Expected: all items become read and unread badges drop to zero on every active session.
- [ ] Delete one notification: delete a single notification on device/session 1. Expected: it disappears from session 2 without a manual refresh.
- [ ] Clear read notifications: clear read items on one device/session. Expected: read items are removed everywhere and unread stats stay correct.
- [ ] Drawer badge: create any unread feed notification. Expected: the left drawer notifications row shows the unread count.
- [ ] Notifications tab badges: create a mix of guild and personal notifications. Expected: `All`, `Guild`, and `Personal` tab badges reflect unread stats accurately.
- [ ] App icon badge: create unread notifications, then read/delete them, then log out. Expected: the app icon badge increments from unread stats, decrements on read/delete, and clears on logout.

## Navigation Expectations

- [ ] DM notification tap opens the target DM thread.
- [ ] Mention notification tap opens the target chatroom.
- [ ] Friend request notification tap opens the user profile flow.
- [ ] Announcement notification tap opens the announcement detail.
- [ ] Event notification tap opens the event detail.
- [ ] Content report notification tap opens the admin reports screen.
- [ ] Guild invite remains actionable via inline controls even without a deep link target.
- [ ] Membership request submitted and membership request decision notifications remain visible in the feed even though they do not yet open a dedicated request-management screen.

## Final Sanity Pass

- [ ] Every persisted notification appears in the feed after app relaunch.
- [ ] Every persisted notification arrives live over websocket without requiring a manual refresh.
- [ ] Personal vs guild tab classification is correct for all notification types.
- [ ] Self-actions do not create duplicate or incorrect notifications.
- [ ] Muted DM threads suppress DM notifications.
- [ ] Muted chatrooms suppress mention notifications.
- [ ] No generic chatroom-message feed notifications are emitted.
- [ ] Awards and watchlist/symbol activity remain absent from the feed and are treated as intentionally out of scope for this pass.
