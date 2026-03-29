# Account Settings QA Checklist

Use this checklist to validate the March 29, 2026 account-profile, settings, and current-user shell audit pass.

Recommended test setup:
- `User A`: current signed-in user with an avatar, profile bio, and at least one saved trading interest
- `User B`: a blocked user already present in `User A`'s blocked-users list
- One account with memberships in at least two guilds
- One account with enough profile activity for overview, markers, awards, and activity tabs to load content
- One account that can exercise change-email and change-password flows
- Ability to request a data export and to test logout/delete-account flows safely in a non-production account

Out of scope for this checklist:
- Reputation and accuracy math, freshness, and breakdown correctness. Covered in `REPUTATION_ACCURACY_QA_CHECKLIST.md`.
- Notification-feed behavior and unread counts. Covered in `NOTIFICATION_QA_CHECKLIST.md`.
- Marker-card lifecycle behavior. Covered in `MARKER_QA_CHECKLIST.md`.

## Current User Profile Shell

- [ ] Profile sheet entry: open the current-user profile from the left drawer. Expected: the profile shell opens without dismissing the app context.
- [ ] Header identity: avatar, display name, username, and current-user-specific actions render correctly.
- [ ] Content tabs: `Overview`, `Markers`, `Awards`, and `Activity` load without layout breakage.
- [ ] Marker tab routing: tapping one of the current user's markers routes back toward the relevant chart context.
- [ ] Global view button: tapping the globe action opens the global account sheet.
- [ ] Settings button: tapping the gear action opens the settings sheet.
- [ ] Switch guild button: tapping the switch-guild action opens the guild-switch surface from the profile shell.

## Switch Guild

- [ ] Current guild preselection: open switch-guild while already in a guild. Expected: the current guild is preselected.
- [ ] Change guild flow: select a different guild and continue. Expected: the app switches into the newly selected guild context.
- [ ] Cancel switch flow: back out of switch-guild without confirming. Expected: the original guild remains active.
- [ ] Single-guild presentation: with only one guild available, the screen stays stable and does not imply an invalid second choice.
- [ ] Multi-guild detail rendering: member count, owner info, online count, and reputation summary render for each guild row.

## Profile Editing

- [ ] Edit profile route: open `Edit Profile` from settings. Expected: the subview loads and the back action returns to settings.
- [ ] Save profile changes: update editable profile fields and save. Expected: changes persist and reflect in the current-user shell.
- [ ] Cancel profile changes: back out without saving. Expected: unsaved changes do not leak into the profile shell.
- [ ] Avatar selection: open avatar selection, choose a new avatar, and confirm. Expected: the profile avatar updates.
- [ ] Date of birth update: set or change date of birth. Expected: the success flow completes and the updated value persists.
- [ ] Trading interests update: change trading-interest selections and save. Expected: the interests persist and reopen correctly.

## Credentials And Security

- [ ] Change email validation: invalid email, identical current email, and mismatched confirmation are rejected.
- [ ] Change email success: submit a valid new email plus current password. Expected: a verification-email success alert appears.
- [ ] Change password validation: weak password or mismatched confirmation prevents submission.
- [ ] Change password success: submit valid current and new passwords. Expected: a success alert appears and the new password works on next login.
- [ ] Change password failure handling: wrong current password fails cleanly without closing the subview.

## Privacy And Data

- [ ] Main settings privacy toggles: online-status visibility, friend-request preference, and DM permission mode load with the user's current settings.
- [ ] Online-status toggle: change the online-status preference. Expected: the setting persists after leaving and reopening settings.
- [ ] Friend-request toggle: disable then re-enable friend requests. Expected: the setting persists both ways.
- [ ] DM permission mode: cycle through the available DM permission options. Expected: the selected mode persists and reopens correctly.
- [ ] Blocked-users list load: open `Blocked Users`. Expected: blocked users load or the empty state explains the surface.
- [ ] Unblock flow: unblock an existing blocked user. Expected: the user disappears from the blocked list and the view stays consistent.
- [ ] Data-and-privacy activity toggle: change `Activity Visible`. Expected: the setting persists on refresh.
- [ ] Data-and-privacy analytics toggle: change analytics sharing. Expected: the setting persists on refresh.
- [ ] Data-and-privacy personalized-content toggle: change personalized-content preference. Expected: the setting persists on refresh.
- [ ] Data export request: use `Download My Data`. Expected: the request completes without crashing the settings flow.
- [ ] Clear local data: use `Clear Local Data`, confirm, and continue using the app. Expected: cached data clears without deleting account data.

## Support And Legal

- [ ] Help center load: open `Help Center`. Expected: FAQ categories and entries render correctly.
- [ ] Help center search: search within help center. Expected: filtering works and no stale expansion state breaks the list.
- [ ] Contact support route: open `Contact Support` from settings and from the help center CTA. Expected: both paths land on the same support surface.
- [ ] Contact support submit: send a support request with valid content. Expected: the flow completes without leaving the sheet stack broken.
- [ ] Terms and privacy view: open `Terms & Privacy`. Expected: terms and privacy rows render and remain scrollable.
- [ ] About view: open `About`. Expected: version/app info and external-contact rows render correctly.
- [ ] Rate app action: trigger the rate-app path. Expected: the route returns cleanly to settings after the system prompt handoff.

## Destructive Actions

- [ ] Logout confirmation: tap logout from settings. Expected: a confirmation alert appears before state is cleared.
- [ ] Logout cancellation: cancel the confirmation. Expected: the user remains logged in and inside settings.
- [ ] Delete-account step 1: open `Delete Account`. Expected: the warning copy and password gate appear.
- [ ] Delete-account step 2: continue to the typed-confirmation step only after entering a password.
- [ ] Typed confirmation rule: deletion only becomes available when the exact confirmation text is entered.
- [ ] Delete-account completion: complete account deletion in a safe test account. Expected: account state clears and the app exits the authenticated shell.

## Negative Cases And Guard Rails

- [ ] Back-stack stability: repeatedly move between profile, settings, global view, and switch-guild. Expected: there are no orphaned sheets or stuck detents.
- [ ] Save-button disable rules: save buttons stay disabled until required fields are valid or changes exist.
- [ ] Refresh persistence: after editing settings, close and reopen the sheet. Expected: the server-backed values are still present.
- [ ] Current-user isolation: current-user settings surfaces do not accidentally open another member's profile or controls.

## Final Sanity Pass

- [ ] Current-user profile, global view, switch-guild, and settings surfaces all open from the profile shell and return cleanly.
- [ ] Profile edits, credential changes, privacy settings, and support/legal routes behave like stable subflows rather than dead-end screens.
- [ ] Logout and delete-account remain clearly destructive and require confirmation.
- [ ] Settings changes persist after leaving and reopening the account surfaces.
