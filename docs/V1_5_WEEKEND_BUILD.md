# v1.5.0 weekend self-test build (Claude, 2026-10-03)

**For:** the owner, by hand, until the Tuesday checkpoint.

**Status:**
- The build is ready and signed.
- **It is not installed yet:** the phone has not been touched and is waiting on the owner's go-ahead (§3).
- Nothing is pushed or deployed; there is no production change.

## 1. The build

| | |
|---|---|
| Source | `claude/1.5.0-avatar-markers` at **`4681ab0`** (`4681ab01614339bbb53148cf2d18b1750dc38e8a`), clean tree |
| App | **TG LinkedDev**, `co.tradersguild.app.linkeddev`, version 1.5.0 (25). An isolated DEV app; production "Traders Guild" is untouched. |
| Scheme / config | `traders_guild LinkedDev Profile` / `DevProfile` (optimised, `TG_ISOLATED_DEV`) |
| Build command | `xcodebuild build -scheme "traders_guild LinkedDev Profile" -configuration DevProfile -destination generic/platform=iOS -allowProvisioningUpdates DEVELOPMENT_TEAM=B4WE2NR99U TG_LAN_HOST=192.168.1.249` |
| Gateway in the app | `http://192.168.1.249:30080/api/v1`: the Mac's current Wi-Fi address. **The checked-in config still says .182**; the address was overridden on the command line and no file was changed. |
| Signing | Apple Development: Alistair Hennessey (NX6SZ9N734), team B4WE2NR99U; `codesign --verify --deep --strict` passes |
| Profile | iOS Team Provisioning Profile `co.tradersguild.app.linkeddev`; includes the iPhone 14 Pro (`00008120-00186CA01470201E`); **expires 1 Oct 2027** |
| Certificate | valid until 28 Sep 2027 |
| Built | 3 Oct 2026 11:44 (local); binary sha256 prefix `373852c2d61b4c50` |
| **Install copy (durable)** | `~/TradersGuildLocal/weekend-2026-10-03/traders_guild.app` (plus `.dSYM`) |
| Original | `$S/dd-weekend/Build/Products/DevProfile-iphoneos/traders_guild.app` (`$S` is the session scratchpad under `/private/tmp`, cleared on reboot) |

**What is in it:** everything on the branch to `4681ab0`:
- the v1.5 avatar markers
- the pan hand-off fix
- refined creation: Change type, the social and structured split, and the half-height sheet (collapsed / 28% / 50%, Setup in three sections)
- the refined detail sheet
- guided editing with full payload preservation, and the fail-closed guard (§5)

## 2. Local backend (must stay up; nothing changed)

- **Stack:** Docker compose project `traders-guild-local`, 10 services, on this Mac. chart-service runs Sol's accepted `5061824` snapshot, mounted read-only (label `co.tradersguild.stage4.source=50618244…`).
- **Safeguards, unchanged from Stage 4:**
  - outbound Discord, email, push, autopost and digest are off
  - BTC/USD is the only active symbol
  - no production endpoint
- **Dependencies:**
  - the phone and the Mac on the **same Wi-Fi**
  - the **Mac awake**, with Docker running
  - the Mac keeping **192.168.1.249**
- **If the Mac's address changes,** the app cannot connect. Either reserve .249 for this Mac in the router, or rebuild with the new `TG_LAN_HOST` and reinstall.
- **Reboot risk:** the running snapshot and the original credentials file are under `/private/tmp`, which macOS clears on restart. Durable copies are in `~/TradersGuildLocal/weekend-2026-10-03/` (folder mode 700):
  - `backend-5061824/`
  - `compose.weekend-durable.yml` (the same override, pointing at the durable snapshot)
  - `qa-creds.json` (mode 600)
- **Only after a reboot,** run this from `.worktrees/linked-markers-backend` to recover. It recreates chart-service only, with volumes preserved; it is not needed otherwise:

  ```bash
  docker compose --env-file .env.local -f docker-compose.yml -f docker-compose.safe.yml -f ~/TradersGuildLocal/weekend-2026-10-03/compose.weekend-durable.yml up -d --no-deps chart-service
  ```

## 3. Install (owner, when the phone is available)

1. Unlock the phone and plug it into the Mac.
2. Run:

   ```bash
   xcrun devicectl device install app --device 0C90C5FD-D935-51C9-A75F-F8570802F382 ~/TradersGuildLocal/weekend-2026-10-03/traders_guild.app
   ```

   This replaces the previous TG LinkedDev build; the app's data and sign-in are kept.
3. **Turn the experiment on so it stays on** for ordinary home-screen launches. Use the saved switch; no production or default changes are needed:
   - Run:

     ```bash
     xcrun devicectl device process launch --device 0C90C5FD-D935-51C9-A75F-F8570802F382 --terminate-existing co.tradersguild.app.linkeddev -MarkerLinkFixtures
     ```

     Use exactly that one argument. Adding `-TGAvatarMarkersExperiment` disables the switch.
   - In the fixture gallery that opens, turn on **"Avatar markers experiment (saved)"**.
   - Close the app (swipe it away), then open TG LinkedDev from the home screen. Faces on the chart mean the experiment is on.
   - To turn it off later, do the same and switch it off.
4. **Sign in, if asked,** as the local QA account. Its password is only in the protected file `~/TradersGuildLocal/weekend-2026-10-03/qa-creds.json` (`accounts.a`). Read it on the Mac; it is never typed by tests or written to logs.
5. Optional: Settings → Developer → Enable UI Automation can be turned off; this build doesn't need it.

## 4. What to try (about 20–30 minutes)

Use **BTC/USD**, and post on **15m** or another timeframe, not **1h**: the 1h fixture is kept identical for comparisons. Markers are posted to the local QA guild only.

1. **Placing.** Markers → Add → "Post to the chart" (Analysis/Question) and "Plan a trade" (Setup). Check:
   - The sheet stops at half the screen and collapses to the capsule.
   - Drag the marker and pan the chart while placing.
   - Setup: Levels → Next → Reasoning → Review → Post.
   - Change type, and Back.
2. **Responding.** Select a marker → Respond → choose a relationship → write → Review → Post. Try changing the response timeframe.
3. **Viewing.** Select a marker. The sheet should read in this order: author, title and text, levels (for a Setup), Respond and Share, then the disclosures.
4. **Editing your own markers.** Detail sheet → Edit → change something → Review ("What changes") → Save changes. Try:
   - Analysis: clear the title, then save.
   - A Setup that is still tracking (ARMED): move the TP.
   - An Active Setup: levels locked, text editable.
   - Close with and without changes.
5. **Feel.** Select another marker and pan immediately: there should be no stutter. Also pan with nothing selected.
6. **VoiceOver,** briefly: step headings, the Review list, Save.

Write down anything odd, with the time.

## 5. Known gaps (not waived)

- **Not yet checked live** (no simulator sign-in was available): sheet detents, the keyboard over the sheet, the chart during an edit, and Setup lines during an edit (TP/SL are edited in the sheet). This weekend is the first live check.
- **Typing:** while a field is being typed in, iOS raises the sheet above the keyboard, so it briefly covers more than half the screen.
- **Fail-closed guard (§1):** if an edited marker's components can't be matched safely, context and level changes are refused with a message, and text still saves. Not expected with markers this app creates.
- **Small phones:** sections scroll on an iPhone SE-size screen.
- **Not covered this weekend:** frame and cold-load evidence, older-client compatibility (Sol), hand-run accessibility, and the deferred auth issues.
- **Legacy editor:** with the experiment off, the existing editor keeps its known flaws: a cleared title is not sent, unreadable components are dropped, and it can re-seat a Setup's Entry.

## 6. Tuesday checkpoint

Bring:
- notes from §4
- whether any screen was unclear about the next step
- any connection problems, and whether the Mac's address changed

Engineering items waiting:
- Astra's integration of `bd0560b` and `4681ab0`
- the live detent and keyboard evidence, from the owner's notes
- the legacy-editor findings, for a decision

## 7. Resume point (if this session stops)

- **Branch and build:** branch at `4681ab0` plus this doc. Durable build and backups are in `~/TradersGuildLocal/weekend-2026-10-03/`.
- **Phone:** nothing installed or launched by Claude; no runners or watchers.
- **Next action:** the install steps in §3, by the owner or on an explicit relay.
- **Verification of `4681ab0`:**
  - focused 43/43 (`$S/bs/rb-guard.xcresult`)
  - previous full unit 845/845 and UI 19/19 on `bd0560b`; the guard changes only guided-edit logic and tests, so the full suite was not re-run
  - the device Profile build is the compile check for this source; Release was last built clean on `bd0560b`
