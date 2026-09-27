# App Store "What's New" — Traders Guild 1.4.0 (iOS)

New to Traders Guild? A short walkthrough now shows you around the first time you sign in — five quick pages on the shared chart, placing your first marker, tracked setups, responding to other members, and building your own guild. It ends by taking you straight to your first marker, and you can watch it again any time from Settings → How Traders Guild works.

Share a marker straight into your guild's conversations: "Send to chat" posts it to the chart chat or any of your guild's chatrooms, where it appears as a card anyone can tap.

Plus: member avatars in chat now update as soon as someone changes theirs, the marker details and placement checklist start tucked to the side so the chart stays clear, and tapping "More" in the share sheet no longer closes the app.

## Internal release details

* Marketing version: `1.4.0`
* Build: `24` — **check App Store Connect before archiving**: if a build 24 was ever uploaded
  (TestFlight included), bump `CURRENT_PROJECT_VERSION` to the next free number first. Only
  1.3.0 (23) is known to have been uploaded.
* Cut from `8801a6a` (1.3.0 build 23, the current App Store release) on
  `feat/1.4.0-onboarding-walkthrough`. There is no separate 1.3.1: `claude/1.3.1-production-feedback`
  never moved past `8801a6a`, and everything planned for it is in this release.
* Backend: none needed. Every change is client-only — no endpoint, schema, request or response
  change. `beta_welcome_enabled` is still decoded from `GET /users/me/runtime-flags` and simply
  unused, so the DTO is unchanged. Older clients are unaffected: a marker shared into a chat is an
  ordinary `TG_MARKER_SHARE_V1` message body, which 1.3.0 and the current Android app
  already decode and render as a marker card.
* Walkthrough completion stays local under the tour's existing keys, so anyone who finished or
  skipped the old tour is not shown the walkthrough.
* Shipping path: the **traders_guild GCP Public Prod** scheme, Archive (Release). Never the
  Prod QA or LinkedDev schemes — they carry their own bundle ids and plists. A Release simulator
  build of the shipping scheme compiled with no warnings: bundle `co.tradersguild.app` 1.4.0 (24),
  no development endpoints in the binary, all five walkthrough clips bundled, and the DEBUG-only
  `-WalkthroughPreview` harness absent.
* macOS sources, targets and project settings are outside this release —
  `xcodebuild -list -project traders_guild.xcodeproj | grep -c TradersGuildMac` is 0.
* Unit target at the candidate: 710/710.
* Walkthrough media: five clips, 720×1000 H.264, silent, ~6.7 MB in the bundle. Only the visible
  page has a player; it plays muted under `.ambient` + `.mixWithOthers`, so the user's music
  keeps playing. Reduce Motion shows posters only.
* Before archiving, on a physical device (the Prod QA build is fine):
  * all five walkthrough pages play (Settings → How Traders Guild works), page 3 especially — an
    earlier build froze page 3 on its poster on an iPhone 14 Pro; the single-player change is
    the fix and simulators cannot reproduce the decoder limit;
  * the guild-invite share sheet's "More" opens without crashing (the marker path is verified;
    both share one `ShareLinkIcon`).
* Android ships the walkthrough from its own repo (`feat/1.4.0-onboarding-walkthrough` there);
  Android parity for Send to chat and the avatar directory is still to do.

### Scope check

Everything in this release, measured against 1.3.0 (`8801a6a`), by commit:

| Area | Commit | User-facing |
| --- | --- | --- |
| Share sheet "More" crash: one `ShareLinkIcon` for markers and invites | `1a71795` | yes |
| Send a marker to the chart chat or guild chatrooms | `2c5ce49` | yes |
| Chat avatars update live (`MemberAvatarDirectory`; its RLAppState feeds are in `d3598ce`) | `96f12f4` | yes |
| First-run walkthrough replaces the 16-step tour; beta welcome sheet retired | `d3598ce` | yes |
| Marker details card and placement checklist start collapsed | `a045a29` | yes |
| Version 1.4.0 (24) and these notes | the commit adding this file | no |
