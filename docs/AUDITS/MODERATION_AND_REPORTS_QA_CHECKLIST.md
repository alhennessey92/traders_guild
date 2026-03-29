# Moderation And Reports QA Checklist

Use this checklist to validate the March 29, 2026 moderation, report-review, and member-sanction audit pass.

Recommended test setup:
- `Owner`: guild owner account
- `Admin`: guild admin account
- `Mod`: guild moderator account
- `User A`: normal member who can be muted, suspended, kicked, or banned in a safe test guild
- One guild with a mix of active members and at least one existing content report
- One reported user that still exists in the current guild-member list
- One pending report for each of the major supported content types if possible: chatroom message, DM message, chart chat, marker, and user
- Two app sessions for one sanctioned user if you want to observe downstream UI effects

Out of scope for this checklist:
- Notification-feed delivery for moderation events such as ban, mute, suspend, or content reports. Covered in `NOTIFICATION_QA_CHECKLIST.md`.
- Reputation and accuracy side effects of reports or moderation penalties. Covered in `REPUTATION_ACCURACY_QA_CHECKLIST.md`.
- Non-punitive admin configuration such as guild settings, invites, and chatroom creation. Covered in `GUILD_ADMIN_QA_CHECKLIST.md`.

## Member Moderation Tabs

- [ ] Manage-members load: open `Manage Members`. Expected: `Active`, `Muted`, `Suspended`, and `Banned` tabs appear when role permissions allow.
- [ ] Moderator tab gating: for moderator accounts, the `Banned` tab is hidden if ban management is not allowed.
- [ ] Active-members list: active members render in the `Active` tab.
- [ ] Empty muted state: when nobody is muted, the muted tab shows a proper empty state.
- [ ] Empty suspended state: when nobody is suspended, the suspended tab shows a proper empty state.
- [ ] Empty banned state: when nobody is banned, the banned tab shows a proper empty state.

## Mute And Suspend Flows

- [ ] Mute dialog open: choose an active member and open the mute flow. Expected: the duration selection dialog appears.
- [ ] Mute success: apply a mute duration. Expected: the user leaves `Active` and appears in `Muted`.
- [ ] Muted-until display: muted rows show the mute-expiry relative time when present.
- [ ] Unmute success: unmute a muted member. Expected: the user leaves `Muted` and returns to `Active`.
- [ ] Suspend dialog open: choose an active member and open the suspend flow. Expected: the duration selection dialog appears.
- [ ] Suspend success: apply a suspension duration. Expected: the user leaves `Active` and appears in `Suspended`.
- [ ] Suspended-until display: suspended rows show the suspension-expiry relative time when present.
- [ ] Unsuspend success: unsuspend a suspended member. Expected: the user leaves `Suspended` and returns appropriately.
- [ ] Live moderation patch: when mute or suspension notifications arrive, the affected member row updates in-place.

## Kick, Ban, And Unban

- [ ] Kick confirmation: choose an eligible member and open the kick alert. Expected: the confirmation copy is clear before action.
- [ ] Kick success: confirm kick. Expected: the user is removed from the current guild member list.
- [ ] Ban confirmation: choose an eligible member and open the ban alert. Expected: optional reason entry is available.
- [ ] Ban success: confirm ban. Expected: the user is removed from active membership and appears in `Banned`.
- [ ] Ban reason rendering: a ban with a reason shows that reason in the banned-user row.
- [ ] Unban success: unban a banned user. Expected: the row disappears from `Banned`.
- [ ] Unban loading state: during unban, the row shows busy state and does not allow duplicate taps.

## Report Filters And List Behavior

- [ ] Reports screen load: open `Manage Reports`. Expected: reports load with pending count and default filters.
- [ ] Status filters: switch between `All`, `Pending`, `Resolved`, and `Dismissed`. Expected: the list updates to match the selected status.
- [ ] Content-type filters: switch across `All`, `Chat`, `DMs`, `Chart`, `Markers`, and `Users`. Expected: the list updates to match the selected content type.
- [ ] Pending badge: the pending count appears on the pending status filter when applicable.
- [ ] Empty filter states: when a filter has no matches, a relevant empty state appears instead of blank space.
- [ ] Report cards: report rows show content type, reason badge, reporter, status, and content snippet or details when available.

## Report Detail And Resolution

- [ ] Detail sheet open: tap a report row. Expected: the detail sheet opens with status, reported content, and report details.
- [ ] Reported-user block: when the reported user still exists in guild members, the detail sheet shows a route to that user's profile.
- [ ] Already-resolved reports: resolved or dismissed reports show reviewer and resolution-note context in detail view.
- [ ] Resolve action: as an admin/owner, resolve a pending report with an optional note. Expected: the report leaves pending state and becomes resolved.
- [ ] Dismiss action: dismiss a pending report. Expected: the report leaves pending state and becomes dismissed.
- [ ] Resolution-note persistence: a saved resolution note is visible when reopening the resolved report.
- [ ] Moderator read-only behavior: moderator accounts can view reports but do not incorrectly receive resolve/dismiss controls if not permitted.

## Report-Driven Member Actions

- [ ] Suspend-from-report action: from a report tied to a guild member, use the suspend action. Expected: the member is suspended and the report is resolved.
- [ ] Kick-from-report action: from a report tied to a guild member, use the kick action. Expected: the member is removed and the report is resolved.
- [ ] Ban-from-report action: from a report tied to a guild member, use the ban action. Expected: the member is banned and the report is resolved.
- [ ] Member-action loading state: while a report-driven member action is running, the action row shows busy state and prevents duplicate taps.
- [ ] Report-to-profile route: from report detail, open the reported member profile when available.

## Permission Gating And Safety Rules

- [ ] Higher-role protection: staff cannot punish users they should not be allowed to manage.
- [ ] Self-action suppression: the current moderator/admin cannot apply sanctions to themselves through the normal member-management UI.
- [ ] Owner protection: non-owner staff cannot ban or otherwise punish the owner from standard flows.
- [ ] Unauthorized resolution suppression: users without resolve/dismiss permission cannot finalize reports.

## Downstream Consistency

- [ ] Member-list consistency after sanction: after mute, suspend, kick, or ban, reopen user and admin lists. Expected: the member appears only in the correct place.
- [ ] Cross-session effect: if the sanctioned user has another active session, the app behavior updates appropriately after the sanction is applied.
- [ ] Report-count consistency: after resolving or dismissing reports, pending counts and filters reflect the updated totals.
- [ ] Ban-list persistence: after closing and reopening manage-members, the banned list still reflects server-backed state.

## Negative Cases And Guard Rails

- [ ] Double-action suppression: rapidly trigger mute, suspend, kick, ban, unban, resolve, or dismiss. Expected: only one effective action is applied.
- [ ] Filter-switch stability: switch report filters quickly. Expected: the final filter wins and stale results do not linger.
- [ ] Empty-state isolation: empty tabs do not leak rows from another moderation or report filter.
- [ ] Detail-dismiss stability: closing report detail returns to the reports list without leaving a blocked overlay.

## Final Sanity Pass

- [ ] Staff can review pending reports, inspect context, and take allowed moderation actions from stable admin surfaces.
- [ ] Muted, suspended, kicked, and banned users transition into the correct downstream states in member management.
- [ ] Report resolution and report-driven sanctions update pending counts and status filters cleanly.
- [ ] Permission gating protects self, owner, and higher-role scenarios from unauthorized moderation actions.
