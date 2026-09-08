# App Store "What's New" — Traders Guild 1.2.1 (iOS)

Guild flows feel smoother in 1.2.1, with clearer progress for creating, joining, switching and deleting guilds. Each action keeps the selected guild's identity visible through the transition, with more reliable welcome and invitation screens.

Share a marker setup with your guild's Discord as you place it, post weekly standings, or share your own leaderboard position. Marker layouts also remain stable as older chart history loads.

New-account onboarding now recovers cleanly when starter-guild assignment completes during an interrupted network response.

Plus reliability improvements across guild deletion, marker links, confirmations, sheet presentation and loading states.

## Internal release details

* Marketing version: `1.2.1`
* Build: `22`
* Cut from `5332c06` (the 1.2.0 notes commit); the final candidate is the commit carrying
  `fix: finalize 1.2.1 guild and marker flows`.
* **Guild deletion is confirmed live on production.** `POST /guilds/{id}/delete` returned
  200 against `api.tradersguild.co` on 2026-09-08 with `members_relocated: 0`. The last
  handover listed the PR #23 deploy as unverified; it is verified now.
* The Discord result loop is server-side and already deployed — the marker opt-in, the
  standings post and the resolved-result post are all backend-rendered.
* No response-contract changes. Everything added this cycle is additive and optional, so
  1.1.x clients in the wild decode every payload unchanged.
* Signup now suppresses the assignment toast only while it verifies whether a failed/lost response
  already committed the starter-guild membership. A real failure retains the inline Retry path.
* The Discord setup prompt is now non-dismissable by swipe. It records itself as shown
  *before* presenting, so an accidental swipe used to cost an owner the prompt for 30 days.
  "Not now" and "Connect a channel" are the ways out.
* macOS sources, targets and project settings are outside this release —
  `grep -c TradersGuildMac traders_guild.xcodeproj/project.pbxproj` is 0.
* Android ships the same guild and marker work from its own repo.

### Scope check

Everything in this release, measured against the `1.2.0` cut (`5332c06`):

| Commit | User-facing |
| --- | --- |
| `919d6a6` opt a marker into Discord as you place it; share standings | yes |
| `519c280` stop double-posting a marker; remind owners to connect | yes |
| `d892ef0` land a personal leaderboard share on the sharer's row | yes |
| `66be1ad` anchor a personal share to the sharer's row | no — fix to the above, same cycle |
| `18596e5` stop the leaderboard hiding itself | yes |
| `32ae962` guild creation flow, marker deep links, guild deletion | yes |
| `44ab94b` shared guild sheet header, share to Discord, pinned footer | yes |
| `abe50ea` guild header everywhere; no uninvited sheets; toasts over sheets | yes |
| final candidate — finalise guild + marker flows (transitions, welcome sheet, stable marker layout, deletion-transition failsafe, onboarding assignment recovery) | yes |

`66be1ad` and `d892ef0` are two passes at the same defect inside this cycle, so they are
one bullet above, not two.
