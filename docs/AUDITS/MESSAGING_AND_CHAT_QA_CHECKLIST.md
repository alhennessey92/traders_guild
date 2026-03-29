# Messaging And Chat QA Checklist

Use this checklist to validate the March 29, 2026 messaging, DM, chatroom, and chart-chat audit pass.

Recommended test setup:
- `User A`: normal user with at least one active DM thread and one guild chatroom membership
- `User B`: friend of `User A` for DM, reactions, typing, reply, and read-state checks
- `User C`: non-friend guild member for directory/search and chatroom checks
- Two active app sessions for `User A` to verify live sync and read-state propagation
- One guild with at least two chatrooms
- One chart opened on an active symbol so chart-chat can be exercised
- One image attachment and one document attachment available for upload tests
- One relationship state where `User A` has blocked or is blocked by another user

Out of scope for this checklist:
- Persisted notification feed entries for DM, mention, reaction, and friend-request events. Covered in `NOTIFICATION_QA_CHECKLIST.md`.
- Marker-comment notification behavior. Covered in `MARKER_QA_CHECKLIST.md` and `NOTIFICATION_QA_CHECKLIST.md`.
- Moderation/report back-office handling after a message is reported. Covered in `MODERATION_AND_REPORTS_QA_CHECKLIST.md`.

## Right Drawer Discovery And Search

- [ ] Drawer open state: open the right drawer from the main app. Expected: `Messages` loads with guild name and unread badge if applicable.
- [ ] Chatroom search: search by chatroom name. Expected: matching chatrooms filter correctly.
- [ ] User search: search by username or display name. Expected: matching users surface in the correct friend, online, or offline sections.
- [ ] Empty-search state: enter a query with no matches. Expected: the no-results state renders instead of empty disclosure groups.
- [ ] Friend/online/offline counts: as filters change, section counts update consistently with visible rows.
- [ ] Chatroom open: tap a chatroom row. Expected: the guild-chatroom surface opens on the correct channel.
- [ ] Existing DM open: tap an existing DM row. Expected: the DM thread opens on the correct participant.
- [ ] Member-without-thread open: tap a friend or member without an existing thread. Expected: the app opens or creates the DM thread.

## Chatroom And DM Messaging

- [ ] Send text in chatroom: post a normal text message in a guild chatroom. Expected: it appears once and anchors to the bottom correctly.
- [ ] Send text in DM: send a DM from `User A` to `User B`. Expected: the message appears once in both users' thread views.
- [ ] Read-state on open: open a thread with unread messages. Expected: the thread is marked as read and unread counts update.
- [ ] Reply flow: start a reply, send it, and verify the reply draft clears after success.
- [ ] Edit own message: edit a previously sent message. Expected: content updates in place without a duplicate row.
- [ ] Delete own message: delete a previously sent message. Expected: it disappears from the conversation.
- [ ] Reaction add/remove: add a reaction to a message, then remove or toggle it. Expected: counts and current-user reaction state update correctly.
- [ ] Reaction reactors sheet: tap visible reactions on a message. Expected: the reactor overlay loads and shows the correct emoji/user list.
- [ ] Date separators and grouping: send messages across grouping boundaries. Expected: headers and date separators render consistently.
- [ ] Scroll-to-bottom behavior: receive messages while scrolled away from the bottom. Expected: the unread/scroll affordance appears and returns to latest messages.

## Attachments And Composer Behavior

- [ ] Image attachment in DM: send an image attachment in a DM. Expected: upload succeeds and the attachment appears in the message thread.
- [ ] Document attachment in DM: send a non-image attachment in a DM. Expected: upload succeeds and the thread remains usable.
- [ ] Image attachment in chatroom: send an image attachment in a guild chatroom. Expected: it appears without corrupting thread order.
- [ ] Attachment plus text: send a message that includes text plus an attachment. Expected: the composed content still renders correctly.
- [ ] Attachment-only send: send an attachment with no typed message. Expected: the upload still produces a valid message row.
- [ ] Composer reset after send: after text or attachment send succeeds, the draft and reply state clear.

## Typing, Presence, And Active Status

- [ ] DM typing indicator: start typing in a DM from `User A`. Expected: `User B` sees the typing state.
- [ ] Chatroom typing indicator: start typing in a chatroom. Expected: other viewers see typing usernames for the active room.
- [ ] Typing clear on idle: stop typing and wait. Expected: the typing indicator clears without sending a message.
- [ ] Typing clear on send: send the message while typing. Expected: the typing indicator clears immediately afterward.
- [ ] DM online/offline status: DM header status reflects online, offline, or typing state without breaking the layout.

## Settings, Restrictions, And Reporting

- [ ] Chatroom settings route: from an active chatroom, open the settings surface. Expected: the settings sheet opens for that chatroom.
- [ ] DM settings route: from an active DM, open the settings surface. Expected: the settings sheet opens for that thread.
- [ ] Blocked-DM send suppression: attempt to send a DM to a blocked user. Expected: the app blocks sending and shows an error instead of posting.
- [ ] Report DM message: report a DM message and complete the reason picker. Expected: the report flow closes cleanly.
- [ ] Report chatroom message: report a guild chatroom message and complete the reason picker. Expected: the report flow closes cleanly.
- [ ] Self-message controls: destructive or edit controls only appear where the current user should be allowed to use them.

## Chart Chat

- [ ] Chart-chat entry: open the chart chat for the current symbol. Expected: the header shows the symbol ticker and guild context.
- [ ] Chart-chat empty state: on a symbol with no messages, the empty state renders cleanly.
- [ ] Chart-chat send: post a text message in chart chat. Expected: it appears once in the symbol chat.
- [ ] Chart-chat reply: reply to an existing chart-chat message. Expected: the reply draft and sent message behave normally.
- [ ] Chart-chat edit: edit one of the current user's chart-chat messages. Expected: content updates in place.
- [ ] Chart-chat delete: delete one of the current user's chart-chat messages. Expected: it disappears from the list.
- [ ] Chart-chat reactions: react to a chart-chat message and inspect the reaction overlay.
- [ ] Chart-chat report: report a chart-chat message and confirm the sheet dismisses correctly.
- [ ] Author profile routing: tap another user's chart-chat author surface. Expected: the member profile opens.

## Live Sync And Cross-Session Consistency

- [ ] New-message sync: keep two sessions open as `User A`, send from one, and confirm the other updates live.
- [ ] Read-state sync: open and read a thread on one `User A` session. Expected: unread counts and read state update on the second session.
- [ ] Edit sync: edit a message on one session. Expected: the second session reflects the edit without manual refresh.
- [ ] Delete sync: delete a message on one session. Expected: the second session removes it without manual refresh.
- [ ] Reaction sync: add or remove a reaction on one session. Expected: the second session reflects the updated reaction state.
- [ ] Chatroom-vs-DM isolation: activity in one conversation does not mutate unread counts or scroll state in unrelated conversations.

## Negative Cases And Guard Rails

- [ ] Empty-send suppression: sending with no text and no attachment does not create a blank message.
- [ ] Double-send suppression: rapidly tap send. Expected: only one message is created.
- [ ] Search reset: clearing the drawer search restores full chatroom and user lists.
- [ ] Overlay dismissal: background taps dismiss reaction/report overlays without leaving ghost UI behind.
- [ ] No stale thread routing: switching between chatroom, DM, and chart chat does not carry the wrong reply draft or overlay state.

## Final Sanity Pass

- [ ] Users can discover chatrooms and users from the right drawer, open the intended conversation, and exchange text or attachments.
- [ ] Reply, edit, delete, reaction, typing, unread, and reporting behaviors work consistently across DM, chatroom, and chart-chat surfaces where applicable.
- [ ] Live updates propagate across active sessions without manual refresh.
- [ ] Restrictions such as blocked-user send suppression prevent invalid actions without breaking the conversation UI.
