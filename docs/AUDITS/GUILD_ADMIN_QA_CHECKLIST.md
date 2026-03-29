# Guild Admin QA Checklist

Use this checklist to validate the March 29, 2026 guild-admin, owner/admin tooling, and non-punitive guild-management audit pass.

Recommended test setup:
- `Owner`: guild owner account
- `Admin`: guild admin account
- `Mod`: guild moderator account
- `User A`: normal guild member who is not staff
- One guild with several members and at least one existing chatroom
- One pending guild invitation
- One pending guild watchlist request
- One guild watchlist with at least one current symbol

Out of scope for this checklist:
- Mute, suspend, kick, ban, unban, and report-resolution behavior. Covered in `MODERATION_AND_REPORTS_QA_CHECKLIST.md`.
- Notification-feed behavior for invites or guild-admin events. Covered in `NOTIFICATION_QA_CHECKLIST.md`.
- Marker-specific guild watchlist outcomes after symbols are used in marker flows. Covered in `MARKER_QA_CHECKLIST.md`.

## Permission Gating

- [ ] Owner visibility: the guild-admin entry points are visible to the owner account.
- [ ] Admin visibility: admin-only management surfaces are visible to admins where expected.
- [ ] Moderator gating: moderator accounts do not incorrectly see owner/admin-only surfaces such as full guild settings or watchlist management if not allowed.
- [ ] Member gating: normal members do not see privileged guild-admin controls.

## Guild Settings

- [ ] Guild settings load: open `Guild Settings`. Expected: current guild name, description, and open/invite-only state are prefilled.
- [ ] Save validation: clearing or shortening guild name below the minimum disables saving.
- [ ] No-change disable rule: save stays disabled when nothing has changed.
- [ ] Edit and save: change name, description, or visibility and save. Expected: the edit completes and the sheet dismisses cleanly.
- [ ] Cancel flow: dismiss guild settings without saving. Expected: unsaved changes are discarded.

## Invite Members

- [ ] Invite-members load: open `Invite Members`. Expected: search and pending-invite sections render.
- [ ] Search users: search for a user not already in the guild. Expected: matching results appear.
- [ ] Existing-member badge: existing guild members show `Member` rather than an invite action.
- [ ] Pending-invite badge: users with pending invites show `Invited` rather than a fresh invite action.
- [ ] Send invite: invite an eligible user. Expected: the row enters pending-invite state.
- [ ] Pending invites list: existing pending invites load below the search results.
- [ ] Cancel pending invite: cancel an outstanding invite. Expected: the invite disappears from the pending list.

## Chatroom Management

- [ ] Manage-chatrooms load: open `Manage Chatrooms`. Expected: active chatrooms load with counts and metadata.
- [ ] Create chatroom: use `New` to create a chatroom. Expected: it appears in the list after save.
- [ ] Edit chatroom: edit a chatroom's name, description, or icon. Expected: the updated metadata appears in the list.
- [ ] Archive chatroom: archive a chatroom from the action menu. Expected: it is removed from the active list after confirmation.
- [ ] Refresh-right-drawer consistency: after create, edit, or archive, the right-drawer chatroom list refreshes to match.
- [ ] Empty-chatroom state: in a guild with no chatrooms, the empty state explains that admins can create one.

## Role Management

- [ ] Manage-roles load: open `Manage Roles`. Expected: guild members load in role-priority order.
- [ ] Current-user restriction: the current user cannot manage their own row.
- [ ] Owner restriction: non-owner staff cannot manage the owner row.
- [ ] Higher-role restriction: users cannot manage members at an equal or higher effective role.
- [ ] Change role: change an eligible member's role. Expected: the role badge updates without requiring a full app relaunch.
- [ ] Role-change live patch: when a role-change notification arrives, the list updates the affected member row in place.
- [ ] Kick and ban entry availability: destructive role-management actions are visible only on rows that can actually be managed.

## Guild Watchlist Administration

- [ ] Watchlist-admin load: open `Guild Watchlist`. Expected: `Requests` and `Current` tabs render.
- [ ] Pending-request badge: the `Requests` tab badge reflects pending request count.
- [ ] Approve request: approve a pending symbol request. Expected: it leaves `Requests` and appears in `Current`.
- [ ] Reject request: reject a pending symbol request. Expected: it leaves `Requests` and does not appear in `Current`.
- [ ] Current watchlist list: current guild symbols render in the `Current` tab.
- [ ] Search-add new guild symbol: use the search area in `Current` to add a symbol directly as staff. Expected: it appears in the guild watchlist.
- [ ] Remove current guild symbol: remove a symbol from the current guild watchlist. Expected: it disappears from the list.
- [ ] Refresh action: use the explicit refresh action and confirm request/current state reloads cleanly.

## Cross-Surface Consistency

- [ ] Guild visibility after settings change: after toggling open or closed status, guild-selection or guild-detail copy reflects the change on next load.
- [ ] Invite consistency: after sending or canceling an invite, reopening `Invite Members` shows server-backed invite state.
- [ ] Chatroom consistency: after chatroom edits, opening the right drawer uses the updated channel data.
- [ ] Watchlist consistency: after approving or directly adding a symbol, user-facing guild watchlist surfaces reflect the updated guild set.

## Negative Cases And Guard Rails

- [ ] Double-submit suppression: rapidly submit create/edit/save actions. Expected: only one effective mutation is applied.
- [ ] Search empty states: searching users or symbols with no matches shows a stable empty state rather than stale results.
- [ ] Unauthorized entry protection: if a user loses privileges mid-session, privileged screens fail safely rather than applying unauthorized edits.
- [ ] Destructive-confirmation clarity: archive and remove actions always require clear user intent before mutating guild state.

## Final Sanity Pass

- [ ] Owner/admin users can manage guild settings, invites, chatrooms, roles, and watchlist state from stable dedicated sheets.
- [ ] Permission gating keeps staff tooling out of reach for unauthorized roles.
- [ ] Post-edit surfaces in the drawer and messaging stack reflect guild-admin changes without requiring an app restart.
- [ ] Guild-admin flows remain focused on configuration and membership management, with punitive moderation behavior delegated to the moderation audit.
