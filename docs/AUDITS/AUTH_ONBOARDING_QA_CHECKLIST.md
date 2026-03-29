# Auth, Onboarding, And Session QA Checklist

Use this checklist to validate the March 29, 2026 auth, onboarding, and session-management audit pass.

Recommended test setup:
- `New User`: brand-new account that has never completed onboarding
- `User A`: existing password-based account with at least one guild
- `User B`: existing account with membership in at least two guilds
- One valid Apple ID that can be used for Sign in with Apple
- One physical device or simulator configuration that supports Face ID or Touch ID
- Access to password-reset and email-verification deep links
- One account state where only a single guild is available after login
- One account state where multiple guilds are available after login or restore

Out of scope for this checklist:
- Marker lifecycle, marker tabs, and marker result behavior. Covered in `MARKER_QA_CHECKLIST.md`.
- Persisted notification feed behavior and notification routing beyond auth-entry deep links. Covered in `NOTIFICATION_QA_CHECKLIST.md`.
- Reputation and accuracy values after entering the app. Covered in `REPUTATION_ACCURACY_QA_CHECKLIST.md`.

## Welcome Screen And Entry Points

- [ ] Welcome surface: cold-launch while logged out. Expected: the welcome screen loads without stale guild or main-view content visible behind it.
- [ ] Sign-in route: tapping the sign-in action opens the email/username sign-in screen.
- [ ] Sign-up route: tapping the create-account action opens the signup flow at step 1.
- [ ] Apple entry visibility: Sign in with Apple is visible on the welcome screen.
- [ ] Biometric entry visibility: the biometric sign-in button only appears when biometric login has already been enabled for the device.
- [ ] Loading-state protection: while Apple or biometric sign-in is in progress, duplicate taps do not trigger duplicate auth attempts.

## Password Sign-In

- [ ] Email sign-in: sign in with a valid email and password. Expected: login succeeds and the app advances to guild selection or the main app.
- [ ] Username sign-in: sign in with a valid username and password. Expected: login succeeds the same way as email sign-in.
- [ ] Identifier validation: enter an invalid email or username format. Expected: the form stays disabled or shows validation guidance.
- [ ] Wrong-password handling: submit a valid identifier with an invalid password. Expected: sign-in fails cleanly and the user stays on the auth screen.
- [ ] Forgot-password route: from sign-in, open the forgot-password flow without losing app stability or navigation state.

## Password Reset And Deep Links

- [ ] Reset request flow: submit a valid account email in forgot-password. Expected: the reset request completes and the user receives success feedback.
- [ ] Reset deep link entry: open the app with a valid reset-password deep link while logged out. Expected: the reset flow opens directly over auth.
- [ ] Reset deep link while already on auth: from the welcome or sign-in screen, trigger the deep link. Expected: the reset flow still opens correctly.
- [ ] Invalid reset token: open the reset flow with an invalid or expired token. Expected: the flow shows an error and does not log the user in.
- [ ] Post-reset reuse rule: complete a password reset, then retry the old password and new password. Expected: the old password fails and the new password succeeds.

## Signup Flow

- [ ] Step progression: create a new account and move through account, username, basics, interests, guild, and profile steps. Expected: progress advances in order without skipping required steps.
- [ ] Back navigation retention: move forward a few steps, go back, then return forward. Expected: previously entered values are preserved.
- [ ] Account step validation: invalid display name, invalid email, weak password, and mismatched confirmation all prevent continuing.
- [ ] Username validation: duplicate or invalid username input is rejected without breaking the navigation stack.
- [ ] Basics step save: enter valid basics data and continue. Expected: the next step opens with no data loss.
- [ ] Interests step save: select trading interests, continue, and later return. Expected: the choices persist.
- [ ] Open-guild selection: when public open guilds exist, the guild step lists them and allows selecting one for signup.
- [ ] Onboarding-guild fallback: when no open guilds are available, the signup flow assigns an onboarding guild and still allows progress.
- [ ] Guild-step copy clarity: private guilds are not incorrectly shown as directly joinable from signup.
- [ ] Profile setup optionality: complete profile setup with and without optional social fields. Expected: signup can continue in both cases.

## Email Verification

- [ ] Verification screen entry: after signup completes, the email-verification screen opens instead of jumping straight into the app.
- [ ] Manual code validation: entering a valid verification code succeeds and advances onboarding completion.
- [ ] Invalid code handling: entering a bad or partial code shows an error and does not complete onboarding.
- [ ] Verification deep link: open the app with a valid verify-email deep link. Expected: verification is processed and the user receives success feedback.
- [ ] Expired verification token: open with an invalid or expired verification token. Expected: an error is shown and the app remains usable.
- [ ] Onboarding gating: before verification completes, the app stays inside the onboarding/auth branch instead of entering `MainView`.

## Apple Sign In And Biometrics

- [ ] Apple sign-in success: complete Sign in with Apple for an eligible account. Expected: auth succeeds and the app continues into guild selection or the main app.
- [ ] Apple sign-in cancellation: cancel the Apple sheet. Expected: the loading state clears and the user returns to the welcome screen without a broken state.
- [ ] Post-login biometric prompt: after a successful eligible login, the biometric-enrollment sheet is offered.
- [ ] Biometric decline handling: decline biometric enrollment. Expected: the sheet dismisses and does not immediately re-open in the same session.
- [ ] Biometric enrollment success: enable biometrics, confirm identity, and store the protected token. Expected: success feedback appears.
- [ ] Biometric login on next launch: relaunch after enabling biometrics. Expected: the welcome screen offers biometric sign-in and it restores the session when authentication succeeds.
- [ ] Biometric failure path: cancel or fail biometric auth. Expected: the app remains logged out and stable.

## Guild Selection And Session Restore

- [ ] Required guild selection after first login: authenticate with no current guild selected. Expected: the full-screen guild selector opens.
- [ ] Single-guild requirement: for an account with only one guild, first login still presents the selection screen with that guild preselected.
- [ ] Multi-guild selection: for an account with multiple guilds, selecting a guild enters the app under the chosen guild context.
- [ ] Session restore with guild: relaunch with a valid saved session and saved guild. Expected: the app restores directly into the main app.
- [ ] Session restore without guild: relaunch with a valid session but no current guild. Expected: the app opens guild selection rather than showing a blank or stuck loading screen.
- [ ] Switching-account safety: log out, then log in as a different user. Expected: the second user does not inherit the prior user's guild or onboarding state.

## Logout And Session Failure

- [ ] Manual logout: use the logout action. Expected: user, token, membership, and guild state clear and the app returns to auth.
- [ ] Relaunch after logout: close and reopen after logout. Expected: the app stays logged out.
- [ ] Expired refresh-token path: force an auth failure during restore or active use. Expected: the app logs out cleanly and does not keep stale in-app state visible.
- [ ] Pending deep-link resilience after logout: after logout, auth deep links still open the correct reset or verification flow.

## Negative Cases And Guard Rails

- [ ] Double-submit suppression: rapidly tap sign-in, signup continue, or verification actions. Expected: the app does not create duplicate requests or duplicate navigations.
- [ ] Disabled-back behavior during submit: while login or signup submission is in flight, navigation does not leave the stack in a corrupted state.
- [ ] Invalid onboarding recovery: if any signup step fails server-side, the user stays in the flow with prior inputs intact.
- [ ] Loading-state safety: temporary loading states do not trap the user on a blank screen after auth completes.

## Final Sanity Pass

- [ ] Logged-out users can reliably reach sign-in, sign-up, password reset, Apple sign-in, and biometric sign-in entry points when applicable.
- [ ] New users can complete signup, guild selection, profile setup, and verification without falling out of the onboarding flow early.
- [ ] Existing users can log in by email, username, Apple, or biometrics where supported.
- [ ] Guild selection and session restore always land in a valid guild context or prompt for one.
- [ ] Logout and auth-failure paths clear session state and return to a stable auth surface.
