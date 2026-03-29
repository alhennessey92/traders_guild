# Members And Relationships QA Checklist

Use this checklist to validate the March 29, 2026 member-list, friend-request, and relationship-surface audit pass.

Recommended test setup:
- `User A`: current user inside a populated guild
- `User B`: existing friend of `User A`
- `User C`: non-friend guild member
- `User D`: user who has sent an incoming friend request to `User A`
- `User E`: user who has a pending outgoing friend request from `User A`
- One guild with enough members to show online and offline presence differences
- Two app sessions for `User A` if you want to observe relationship-state propagation

Out of scope for this checklist:
- Notification-feed entries for friend requests and accepts. Covered in `NOTIFICATION_QA_CHECKLIST.md`.
- Current-user account settings such as blocked-users management and privacy toggles. Covered in `ACCOUNT_SETTINGS_QA_CHECKLIST.md`.
- Reputation and accuracy breakdown correctness inside profile sheets. Covered in `REPUTATION_ACCURACY_QA_CHECKLIST.md`.

## User List Navigation And Tabs

- [ ] Users section open: open the users section from the left drawer. Expected: the section loads with fixed `Guild` and `Friends` tabs.
- [ ] Guild tab count: the guild-tab badge reflects the number of visible guild members.
- [ ] Friends tab count: the friends-tab badge includes friends plus incoming and outgoing requests.
- [ ] Pull-to-refresh behavior: refresh the users section. Expected: guild members, friends, and requests all reload cleanly.
- [ ] Empty-state handling: in a sparse guild or test account, empty states explain absent friends or members instead of leaving blank space.

## Guild Members

- [ ] Guild member rows: member rows show identity and remain tappable throughout the list.
- [ ] Current-user row routing: tapping the current user's row opens the current-user profile sheet.
- [ ] Other-member row routing: tapping another member opens that member's guild-member profile sheet.
- [ ] Loading-state stability: if guild members are still loading, the list shows a loading state rather than stale or duplicate rows.

## Friend Requests And Friends List

- [ ] Incoming requests section: incoming friend requests render in the friends tab when present.
- [ ] Accept request: accept `User D`'s friend request. Expected: the request disappears and the user moves into the friends list.
- [ ] Decline request: decline an incoming request. Expected: the request disappears and no friend relationship is created.
- [ ] Outgoing requests section: outgoing friend requests render separately from accepted friends.
- [ ] Existing friends rows: accepted friends render as tappable friend rows.
- [ ] Friends-to-profile routing: tapping an accepted friend opens that member's guild-member profile when guild-member data is available.
- [ ] Relationship refresh: after accept or decline, reopening the friends tab shows the updated server-backed state.

## Member And Profile Routing

- [ ] Current-user profile path: from the users section, open the current-user profile and return. Expected: the users section remains on the same tab when dismissed.
- [ ] Other-user profile path: from the users section, open another member profile and return. Expected: the users section remains stable.
- [ ] Global-view access from current-user profile: opening the current-user global sheet from the profile shell works from this entry path.
- [ ] Switch-guild access from current-user profile: the current-user profile still exposes switch-guild correctly when entered from users.

## Current User Versus Other User Behavior

- [ ] Action differences: current-user profile surfaces show current-user controls, while other-user profiles do not incorrectly expose them.
- [ ] Self-profile isolation: opening the current user's row never routes to the other-member detail sheet.
- [ ] Non-self profile isolation: opening another user never routes to the current-user settings shell by mistake.

## Relationship And Reporting Actions

- [ ] User report action: from another user's profile or user-list actions, report a user and complete the report reason flow.
- [ ] Report flow dismissal: after reporting, the reporting sheet closes without leaving the profile or list in a broken state.
- [ ] Friend-state persistence: after relationship changes, friend-related affordances stay in the correct accepted/pending/not-friends state.

## Presence And Live Updates

- [ ] Presence visibility: online/offline presentation in member surfaces remains consistent with the current user's privacy settings.
- [ ] Relationship live update: keep two sessions as `User A`, accept a request on one, and confirm the friends list updates on the other after refresh or live patch.
- [ ] Profile refresh on performance updates: current-user and member profile surfaces remain refreshable when related activity changes.

## Negative Cases And Guard Rails

- [ ] Duplicate accept suppression: rapidly tap accept on the same friend request. Expected: it resolves once.
- [ ] Duplicate decline suppression: rapidly tap decline on the same request. Expected: it resolves once.
- [ ] Missing-member fallback: if friend row metadata loads before guild-member metadata, the app shows safe fallback behavior instead of crashing.
- [ ] Tab-switch resilience: switch repeatedly between `Guild` and `Friends`. Expected: rows and counts stay aligned with the selected tab.

## Final Sanity Pass

- [ ] Users can browse guild members, review incoming and outgoing friend requests, and manage accepted friendships from one stable section.
- [ ] Current-user and other-user profile routes stay clearly separated.
- [ ] Relationship changes update the visible lists without leaving stale pending rows behind.
- [ ] User-report actions work from member surfaces without destabilizing the list or profile sheets.
