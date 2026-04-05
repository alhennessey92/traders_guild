Traders Guild Auth + Apple Sign In + Optional Face ID Implementation Plan

Goal

Extend the current authentication system to support:
	•	Existing complete email/password auth
	•	Existing complete email signin, signup, and reset password flow
	•	Sign in with Apple
	•	Optional Face ID as a convenience feature on a per-device basis
	•	A shared onboarding structure across auth methods
	•	A single user account model that can support multiple login methods in future

This plan assumes:
	•	Email auth is already fully working and should remain the main stable path
	•	Face ID is optional only
	•	No passcode-based unlock flow should be offered by the app
	•	Face ID is not part of account creation or identity verification
	•	Face ID is only a device-local convenience unlock after a user has already authenticated

⸻

Core Rule

Separate these two concerns completely

1. Account authentication

This is how the user proves who they are to the backend.

Supported methods:
	•	Email + password
	•	Sign in with Apple

2. Device convenience unlock

This is only for faster app re-entry on the current device.

Supported method:
	•	Optional Face ID only

Important architectural rule

Face ID must not act as a login provider.

It should only allow the app to unlock a securely stored session restoration path on that device after the user has already signed in using a real authentication method.

⸻

Current State

Already complete

The app already has:
	•	Email signup
	•	Email signin
	•	Reset password flow
	•	Existing onboarding flow
	•	Face ID capability inside the app
	•	Apple Sign In button already present in UI

Existing onboarding flow

The current onboarding flow is:
	1.	Initial user details
	•	name
	•	DOB
	•	password
	2.	Pick username
	3.	Initial app info
	4.	Pick initial guild
	5.	Add optional details
	6.	Enter main app

This flow is already working well and should remain the base onboarding model.

⸻

Target Outcome

The final system should support:
	•	Fully working email auth as it already exists
	•	Apple Sign In as an additional auth method
	•	Shared onboarding after account creation
	•	Optional Face ID prompt after successful auth
	•	One user record per person
	•	A future path for linking multiple auth methods to the same account

⸻

High-Level Product Logic

Principle 1

Email auth remains unchanged and should not be reworked unless needed for account-linking support later.

Principle 2

Apple Sign In should plug into the same backend user model and onboarding system.

Principle 3

Face ID should only appear after successful authentication, and only as an optional convenience setting for that device.

⸻

Functional Implementation Plan

Part 1: Leave email auth flow as the stable foundation

The current email flow is complete and should remain the baseline auth path.

That includes:
	•	signup
	•	signin
	•	reset password
	•	normal session creation
	•	routing into onboarding or main app

Email signup flow

For email signup, keep the current experience:
	•	Enter name, DOB, email, password
	•	Create account
	•	Continue through onboarding
	•	Pick username
	•	Enter app info
	•	Pick guild
	•	Add optional details
	•	Enter main app

Email signin flow

For email signin:
	•	Enter email and password
	•	Backend authenticates user
	•	App checks onboarding completion state
	•	If incomplete, resume onboarding
	•	If complete, enter main app

After successful email signin/signup

After the user is authenticated and reaches a stable signed-in state, optionally prompt:

Enable Face ID on this device for quicker access?

If they decline, nothing changes.

If they accept, Face ID is enabled only for future re-entry on that device.

⸻

Part 2: Add Apple Sign In as an additional authentication provider

Apple Sign In should be implemented as a second authentication method, not as a separate account system.

Apple first-time user flow

When the user taps Sign in with Apple:
	•	App performs Apple authorization
	•	App sends Apple credential/token to backend
	•	Backend verifies the Apple identity token
	•	Backend checks whether that Apple identity already exists
	•	If it does not exist:
	•	create a new auth identity for Apple
	•	create a linked user record
	•	store any Apple-provided data that is available
	•	route user into onboarding

Apple returning user flow

If the Apple identity already exists:
	•	Sign user into the existing account
	•	Check onboarding state
	•	If incomplete, resume onboarding
	•	If complete, enter main app

⸻

Part 3: Reuse the same onboarding system for both auth methods

There should be one onboarding pipeline, shared by email and Apple users.

The main difference is that Apple users will not necessarily provide the same initial fields.

Email-created users

Email users already enter:
	•	name
	•	DOB
	•	password

So their onboarding can remain as it already exists.

Apple-created users

Apple users will not have a password step, and may not always provide all profile fields.

So after Apple authentication succeeds:
	•	prefill whatever Apple provides
	•	collect any missing required fields
	•	continue into the same onboarding sequence

Apple onboarding version

Likely structure:
	1.	Apple auth success
	2.	Collect any missing required fields
	•	name if missing
	•	DOB if required by your app
	3.	Pick username
	4.	Initial app info
	5.	Pick initial guild
	6.	Optional details
	7.	Enter main app

This means the onboarding system should be driven by completion state, not by assuming all users came through email signup.

⸻

Part 4: Face ID should be optional and offered only after successful authentication

Face ID should never be part of:
	•	account creation
	•	initial identity verification
	•	password reset
	•	Apple account verification

Face ID should only be offered after a real login/signup completes.

Recommended user experience

After successful signin/signup, show a prompt like:

Use Face ID on this device for faster access?

Options:
	•	Enable Face ID
	•	Not now

If enabled

The app should:
	•	store the refresh/session restoration credential securely in Keychain
	•	require Face ID to access that credential later
	•	use it only for re-entering the app on that device

If declined

The app should:
	•	continue working normally
	•	require normal session/login restoration rules without biometric unlock

⸻

Part 5: Face ID should work the same for email and Apple users

Face ID should not care how the user originally authenticated.

Whether the user signed in with:
	•	email/password
	•	Apple Sign In

The Face ID flow should be identical.

Face ID role

Face ID is only:
	•	a local gate to re-open the app quickly
	•	a secure unlock for stored session restoration data

Face ID is not:
	•	an identity provider
	•	a replacement for email/password
	•	a replacement for Apple Sign In
	•	a standalone sign-in method

⸻

Backend Architecture Plan

Main requirement

You should move toward a model where one app user can have multiple auth methods attached.

Even if you do not implement account linking immediately, the backend should be structured with that future in mind.

Recommended model

User record

This is the main app-level identity.

It should hold things like:
	•	user id
	•	display name / name
	•	DOB
	•	username
	•	onboarding status
	•	guild-related profile state
	•	app profile data

Auth identity record

This stores how that user signs in.

Each identity should represent one provider, for example:
	•	email
	•	apple

Each auth identity should contain fields such as:
	•	provider type
	•	provider user id
	•	email
	•	email verified
	•	password hash only for email provider
	•	linked user id

⸻

Important provider rules

Email auth

Email auth remains exactly as it already works.

It should continue supporting:
	•	signup
	•	signin
	•	password reset
	•	password update as you already have it

Apple auth

For Apple Sign In:
	•	use Apple’s stable unique subject/user identifier as the main provider identity
	•	do not rely only on email matching
	•	treat Apple relay email as valid but not as the primary identity key

⸻

Onboarding State Plan

Because you already have a multi-step onboarding system, onboarding should be explicitly tracked.

The backend should know whether the user has completed onboarding and where they are in the flow.

Suggested onboarding state model

Track states like:
	•	account_created
	•	required_profile_completed
	•	username_completed
	•	app_info_completed
	•	guild_selected
	•	optional_details_completed
	•	onboarding_complete

Or a similar step-based approach.

Why this matters

This allows:
	•	email and Apple users to share the same onboarding pipeline
	•	users to resume onboarding after interruption
	•	app reinstalls to recover onboarding progress
	•	better routing after auth

⸻

Session and Face ID Plan

Recommended session model

Use:
	•	short-lived access token
	•	longer-lived refresh token or equivalent session-restoration credential

Storage approach

When the user enables Face ID:
	•	store the refresh/session-restoration credential in Keychain
	•	protect access to it with Face ID
	•	use it to restore the backend session on later app launches

App launch logic

On app launch:

If Face ID is not enabled
	•	follow your standard signed-in/session restore logic
	•	otherwise show normal auth flow if needed

If Face ID is enabled
	•	show local Face ID gate before restoring session from secure storage
	•	if Face ID succeeds, unlock stored credential and restore session
	•	if Face ID fails or is cancelled, keep user at locked/auth entry state rather than offering your own passcode flow

Since you only want Face ID and not an app passcode option, the app should simply not provide a separate passcode unlock path.

⸻

UX Structure Plan

Auth entry screen

Main entry points should be:
	•	Continue with Apple
	•	Continue with Email

And a secondary path:
	•	Sign in

Depending on your current design, Continue with Email may open signup or auth choice as it already does.

⸻

Email path

Keep current flow unchanged.

Signup
	•	name
	•	DOB
	•	email
	•	password
	•	create account
	•	continue onboarding

Signin
	•	email
	•	password
	•	authenticate
	•	route to onboarding resume or main app

Reset password

Keep existing flow unchanged.

⸻

Apple path

New Apple user
	•	Apple authorization
	•	backend verification
	•	create Apple auth identity
	•	create user
	•	collect missing required fields
	•	continue through onboarding
	•	optionally offer Face ID after auth success / onboarding checkpoint

Returning Apple user
	•	Apple authorization
	•	backend verification
	•	sign in existing linked user
	•	route to onboarding resume or main app
	•	optionally offer Face ID if not already enabled

⸻

Face ID UX Rules

Only prompt at the right moment

Do not prompt for Face ID:
	•	before signup
	•	during signup
	•	before signin
	•	in the middle of onboarding steps

Best time to prompt

Prompt after:
	•	successful signup
	•	successful signin
	•	successful Apple auth
	•	or once the user reaches a stable signed-in state inside the app

Suggested wording

Use something simple like:

Enable Face ID for faster access on this device?

With options:
	•	Enable
	•	Not now

Settings support

Users should later be able to:
	•	enable Face ID
	•	disable Face ID

This should live in a security or account settings area.

⸻

Account Model Rules

One user should not become multiple accounts

Do not create:
	•	one account for email
	•	another separate account for Apple

Instead aim for:
	•	one user
	•	one or more linked auth identities

Even if account linking is a later phase, the backend model should be built to support it now.

⸻

Future-Friendly Linking Plan

This can be phase two, but the structure should allow for it.

Future case 1

User signs up with email first, then later links Apple in settings.

Future case 2

User signs up with Apple first, then later adds email/password in settings.

This avoids account duplication and gives users recovery options.

⸻

Implementation Order

Phase 1

Keep existing email auth exactly as it is.

Phase 2

Implement Apple Sign In backend verification and user creation/signin flow.

Phase 3

Adapt onboarding so it can handle:
	•	email-created users
	•	Apple-created users with missing fields

Phase 4

Hook Face ID into post-auth device setup as an optional feature.

Phase 5

Add settings controls for Face ID on/off.

Phase 6

Prepare backend/account model for future provider linking.

⸻

Non-Negotiable Rules for Implementation

Rule 1

Email auth flow must remain working exactly as it does now.

Rule 2

Apple Sign In must integrate into the same user model, not create an isolated auth system.

Rule 3

Face ID must be optional only.

Rule 4

Face ID must only be a device-local convenience unlock, never a primary authentication method.

Rule 5

There must be one onboarding pipeline, with conditional handling for missing fields depending on auth provider.

Rule 6

Backend onboarding progress must be tracked so users can resume properly.

Rule 7

The system should be designed so one user can eventually have multiple linked login methods.

⸻

Final Summary for Implementation

Implement the auth system as:
	•	existing email/password auth unchanged
	•	Apple Sign In added as a second auth provider
	•	one shared user/account model
	•	one shared onboarding flow with provider-aware missing-field handling
	•	optional Face ID offered only after successful auth as a device-local convenience feature
	•	no app passcode unlock flow
	•	backend onboarding state used to resume users correctly
	•	backend structured for future linking of email and Apple to the same user account