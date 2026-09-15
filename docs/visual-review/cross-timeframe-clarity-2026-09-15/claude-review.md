# Cross-timeframe clarity follow-up — simulator usability check

Date: 2026-09-15. Codex's clarity follow-up (badge jumps directly for a single response;
multiple destinations or an incomplete branch show an ellipsis badge that opens the existing
`MarkerThesisDisclosure` in a chooser sheet; parent banner / parent-details action name the
parent's timeframe; draft copy says changing the response timeframe does not move the original).

Files copied from `.worktrees/linked-markers-ios` per `/tmp/linked-clarity-review-files.txt`
(9 files), left **uncommitted** in `.worktrees/linked-markers-claude` (HEAD `3a1253a`). Every other
Swift source already matched Codex's tree; only docs/evidence/xcconfig/pbxproj differ, untouched.

Build: `traders_guild LinkedDev Profile`, DevProfile, iPhone 17 Pro simulator, local gateway.

Status: **complete** (2026-09-15 06:38 local). Build `clarity-build.log`: BUILD SUCCEEDED, 0 errors.

Note: `/tmp/linked-marker-qa-credentials.json` and `/tmp/linked-device-login.txt` were no longer present; the QA owner account was re-logged for API fixture setup from the earlier session's identity (nothing printed). The simulator app was still signed in.

Fixture (disposable, QA guild, created against the now-live persisted series — 1m last `05:34Z`, 30m `05:30Z`, 1h `05:00Z`, 4h `04:00Z`): root `d7a4b516…` (30m alert, `2026-09-15T02:30Z`, "QA clarity root on 30m — two responses on other timeframes"), response A `e1ea286b…` (1h, *supports*), response B `06d1ebb4…` (4h, *challenges*). `fixture.json` alongside the screenshots.

## Checks

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Root with two cross-timeframe responses shows the ellipsis badge | **Pass.** Feed → root: 30m chart, root selected, "2" count badge, and to its left a round **…** badge with the circular arrow (coloured red — the newest response's relationship). | `C01-root-selected-ellipsis-badge.png` |
| 2 | Tap ellipsis → chooser → choose a row → destination selected | **Pass, both rows.** Chooser sheet opens with the existing Thesis disclosure: root highlighted ("30 Minutes", 2), rows "1 Hour · Supports" and "4 Hours · Challenges" (`C02`). Tapped *4 Hours* → sheet dismissed, navigation 30m→4h, response B selected (Critical, leaf badge, its "30m" parent badge to the right) (`C03`). Later tapped *1 Hour* → 1H, response A selected, green "30m" badge (`C05`). | `C02-chooser-sheet.png`, `C03-after-row-4h-destination-selected.png`, `C05-after-row-1h-destination-selected.png` |
| 3 | From the destination, parent badge returns directly | **Pass.** On 4H, tapped the "30m" badge → straight back to 30m with the root selected, no chooser (`C04`). Console: three navigations (30m → 4h → 30m), then 30m → 1h; zero `fatal|EXC_BAD|crash` lines. | `C04-parent-badge-returns-to-root.png`, `launch-console.txt` |
| 4 | Chooser explanation / timeframe labels | **Clear.** Header "Choose a linked marker — Each marker stays on its own timeframe." says the one thing a first-time user needs. Rows carry long-form timeframes ("30 Minutes", "1 Hour", "4 Hours") and relationship chips; the response sheet's parent row now reads "Supports Alex Link QA's Alert — **Open parent on 30 Minutes**" (`C06`), which matches the chooser's wording. Notes below. | `C02`, `C06-response-sheet-parent-action-names-timeframe.png` |

## Findings

No blocker. The flow reads: badge → "choose" → row → land → badge back. Four small notes, none
requiring a change before ship:

* **Ellipsis badge colour.** It takes the newest response's relationship colour (red here because
  the 4h *challenges* was created last), which implies one relationship while meaning "several".
  A neutral fill (accent or the grey the root count badge uses) for `requiresChoice` would say
  "choose" rather than "challenges". Cosmetic.
* **Chooser detent.** `.presentationDetents([.large])` leaves ~half the sheet empty for a
  three-row thesis (`C02`). `[.medium, .large]` would feel lighter and still grow for long
  branches.
* **Second sentence.** "More branches can be loaded in this list." is accurate but reads
  mechanical next to the first line; "Longer branches load as you scroll." or dropping it would
  read cleaner. The rows themselves are self-explanatory.
* **Row identity.** Rows show type + author + timeframe ("Alert / Alex Link QA / 1 Hour"). With
  several alerts by one author the timeframe is the only differentiator — which is exactly the
  case this chooser exists for, so it works, but a one-line note snippet would make rows
  recognisable at a glance. That is the existing disclosure row, not this change.

Short-form badge labels ("30m", "1H") versus long-form rows and parent action ("30 Minutes",
"1 Hour") is a deliberate-looking split that reads fine: the badge is a glance, the rows are a
choice.

Tree state: HEAD `3a1253a`; the 9 copied files plus the earlier response/ChartBodyBoundary
copies remain uncommitted. No Codex-tree edits, no production changes, no device use.
