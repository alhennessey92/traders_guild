# Guild Content QA Checklist

Use this checklist to validate the March 29, 2026 non-marker guild-content audit pass.

Recommended test setup:
- `User A`: normal guild member
- `User B`: a guild moderator or admin who can create announcements and events
- One guild with at least one announcement, one important announcement, and one event
- One guild with empty announcements/events to verify empty states
- One event that `User A` is not attending yet
- One event already marked as attending by `User A`
- Access to pull-to-refresh and at least one second app session to observe live updates where relevant

Out of scope for this checklist:
- Notification feed behavior for announcement and event notifications. Covered in `NOTIFICATION_QA_CHECKLIST.md`.
- Marker-heavy content inside `Top Markers`. Covered in `MARKER_QA_CHECKLIST.md`.
- Reputation and accuracy leaderboard correctness. Covered in `REPUTATION_ACCURACY_QA_CHECKLIST.md`.

## Left Drawer Main Navigation

- [ ] Main drawer menu: open the left drawer main view. Expected: announcements, notifications, top markers, leaderboard, watchlist, events, users, statistics, and admin entry points render when applicable.
- [ ] Section routing: tap `Announcements`, `Events`, and `Statistics`. Expected: each route opens the correct section header and content.
- [ ] Badge visibility: unread dots or counts appear on announcement and event rows when unread content exists.
- [ ] Pull-to-refresh stability: refresh the main drawer. Expected: content refreshes without losing navigation state.
- [ ] Profile entry retention: opening and closing the current-user profile from the drawer does not break drawer navigation.

## Announcements

- [ ] Announcement list load: open announcements with existing data. Expected: rows render with title, preview, author info, and unread styling.
- [ ] Important-announcement styling: important announcements show stronger visual treatment than normal announcements.
- [ ] Empty announcements state: in a guild with no announcements, the empty state explains the absence cleanly.
- [ ] Announcement detail open: tap an announcement row. Expected: the detail sheet opens with full content.
- [ ] Announcement read tracking: opening an unread announcement records the view and removes unread styling afterward.
- [ ] Announcement author metadata: author username, role, reputation, and accuracy metadata render in list and detail views.
- [ ] Announcement deep routing from drawer state: if the drawer navigates into a specific announcement, the correct announcement detail opens.

## Events

- [ ] Events list load: open events with existing data. Expected: event rows render with title, date pill, time, and attendance summary.
- [ ] Empty events state: in a guild with no events, the empty state renders instead of a blank list.
- [ ] Event detail open: tap an event row. Expected: the detail sheet opens with date, host, description, and action buttons.
- [ ] Event read tracking: opening an unread event records the view and removes unread styling afterward.
- [ ] Attend flow: on an event not yet attended, tap `Attend`. Expected: attendance state updates in the detail view.
- [ ] Unattend flow: on an event already attended, remove attendance. Expected: attendance state reverses correctly.
- [ ] Share flow: use the share action for an event. Expected: the share flow opens and returns without breaking the detail sheet.
- [ ] Event deep routing from drawer state: if the drawer navigates into a specific event, the correct event detail opens.

## Statistics

- [ ] Statistics load: open the statistics section in a populated guild. Expected: snapshot, prediction quality, weekly momentum, and derived efficiency cards render.
- [ ] Statistics empty/loading state: while data is loading, the statistics screen shows a loading state instead of broken placeholders.
- [ ] Snapshot card values: guild reputation total, guild rank, total predictions, and member count all render.
- [ ] Prediction-quality card values: wins, losses, accuracy, and error rate render together.
- [ ] Weekly-momentum card values: new members, active users, predictions, and rep earned render together.
- [ ] Derived-efficiency card values: derived metrics render without division-by-zero or placeholder glitches.

## Remaining Drawer Content Routes

- [ ] Leaderboard route: open leaderboard from the drawer. Expected: the route opens cleanly even though leaderboard correctness is validated elsewhere.
- [ ] Top markers route: open top markers from the drawer. Expected: the route opens cleanly even though marker content is validated elsewhere.
- [ ] Notifications route: open notifications from the drawer. Expected: the section opens cleanly even though feed behavior is validated elsewhere.
- [ ] Users route: open the users section from the drawer. Expected: the route opens cleanly and returns cleanly.
- [ ] Watchlist route: open the guild watchlist section from the drawer. Expected: the route opens cleanly and remains usable.

## Cross-Surface Consistency

- [ ] Main menu badge clearing: after reading announcements or events, return to the main drawer. Expected: badge state updates correctly.
- [ ] Sheet dismissal behavior: opening and dismissing announcement/event detail sheets does not leave the drawer overlay stuck.
- [ ] Refresh after content creation: after a new announcement or event is created by another user, refresh and confirm the list updates.

## Negative Cases And Guard Rails

- [ ] Rapid route switching: switch quickly between announcements, events, and statistics. Expected: no blank section or stale title appears.
- [ ] Empty-state isolation: empty announcements or events do not affect statistics or other drawer sections.
- [ ] Detail-view resilience: long announcement or event content remains scrollable and does not clip action buttons or dismiss controls.

## Final Sanity Pass

- [ ] Core non-marker guild content surfaces in the left drawer open, load, refresh, and dismiss cleanly.
- [ ] Announcements and events support list, detail, unread/read, and action flows without breaking drawer navigation.
- [ ] Statistics render meaningful cards or a loading state instead of unstable placeholders.
- [ ] Remaining drawer content routes are reachable even where deeper validation lives in other audit files.
