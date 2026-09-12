# Testing iOS 1.3.0

## Open the feature project

The normal Xcode recent project on `feat/1.2.0-result-cards-guild-identity` is
the protected release checkout. The feature lives in a separate, hidden
`.worktrees` directory; switching branches in the release checkout is unnecessary.

1. In Finder, press **Command-Shift-G** (Go to Folder) and paste:

   `/Users/alhennessey/Desktop/traders_guild/sanctuary/.worktrees/linked-markers-ios/`

2. Open **traders_guild.xcodeproj** in that folder. Alternatively, run:

   ```sh
   open '/Users/alhennessey/Desktop/traders_guild/sanctuary/.worktrees/linked-markers-ios/traders_guild.xcodeproj'
   ```

3. In Xcode's top toolbar choose scheme **traders_guild LinkedDev** and
   destination **iPhone 17 Pro (iOS 26.0)**. This simulator is installed locally.
   Press **Command-R**. The scheme selects **DevDebug** automatically; no manual
   build-configuration or database changes are needed.

The Git branch in this project should read **feat/1.3.0-linked-markers**.
Xcode calls the toolbar choice a *scheme*. Its name is separate from both
the Git branch and the backend database schema.

## App and backend

Use this feature worktree's Xcode project and the **traders_guild LinkedDev**
scheme for hands-on testing. It installs **TG LinkedDev** with separate app data.
The **traders_guild LinkedDev Profile** scheme uses optimized code for profiling.
The production scheme is for release packaging and uses the App Store bundle ID.

Candidate: **1.3.0 build 23**, on `feat/1.3.0-linked-markers`.

The simulator uses the Mac's loopback gateway on port 30080. A physical iPhone
needs the Mac's current LAN address in `TG_LAN_HOST` and network access to that
gateway. A previously installed build can contain an outdated address; rebuild
after a network change. Local DEV services and data are retained.

Verified on 11 September: local Docker project `traders-guild-local` is running,
database migration head is `m1n2o3p4q5r6`, QA login works, and
`linked_markers_enabled` is true. This setup uses the Mac's local DEV database,
not the remote DEV deployment. Keep Docker Desktop running.

For a physical iPhone, select it as Xcode's destination with the same LinkedDev
scheme. Connect USB, unlock the phone, enable Developer Mode and keep it on the
same network as this Mac; USB alone does not route the LAN gateway. If iOS asks
for Local Network access, allow it. The Mac address verified on 11 September is
`192.168.1.182`, matching `TG_LAN_HOST` in both `Debug-LinkedDev.xcconfig` and
`Profile-LinkedDev.xcconfig` under `traders_guild/Config/`. Update those device
settings if the Mac address changes; leave the simulator loopback override intact.
Use **traders_guild LinkedDev Profile** for the later performance measurement.

The 12 September chart startup fix is intended for the ordinary **LinkedDev**
scheme too. Rebuild with **Command-R**; switching to Profile is unnecessary.
The fix reduces chart construction stack usage in DevDebug. Physical stack
evidence and remaining launch checks are recorded in
`DEVICE_CHART_STACK_OVERFLOW.md`.

For automated unit tests, use **traders_guild Compose Dev** with a simulator.
The LinkedDev/DevDebug unit-test target currently fails to resolve the app
module; this does not prevent building and running the LinkedDev app.

QA account details are in the private local files
`/tmp/linked-marker-qa-credentials.json` and `/tmp/linked-device-login.txt`.
Do not commit or share those files. Use a new disposable marker branch for edits
and deletions; keep **QA Deep Thesis** and **QA Wide Thesis** unchanged for the
repeatable performance comparison.

The prepared BTC/USD fixture is historical, around **9 September 2026**:
wide thesis on **1h**, deep leaf on **4h**. An empty current viewport does not
mean those markers are missing. Open a fixture marker from the marker list or
navigate back to its candle. Local synthetic candle coverage runs from
6 September 05:00 UTC through 10 September 06:00 UTC; it is not a live feed.

## Short hands-on pass

After pulling in the transition update, rebuild with **Command-R** from this
feature project using **traders_guild LinkedDev** and your iPhone as destination.
It remains version **1.3.0 build 23**; the version label alone does not distinguish
the earlier local build from the new one. Keep existing app data and QA login.

For the new launch screen, stop the Xcode run, then open **TG LinkedDev** from
the phone's Home Screen. Repeat after force-quitting the app. Expect the square
TG logo centered and a small Traders Guild wordmark above the bottom safe area,
with no pulsing welcome text. On a fast restored session this can be brief;
loading/dismissal timing has not been prolonged to display the artwork. Check
large text and Reduce Motion. Guild operations keep their existing crest/name
treatment, with the rotating ring held still under Reduce Motion.

1. Create a guild marker. From its details or action bar, respond using Supports,
   Challenges and Builds on. Check the link banner, locked guild visibility,
   cancellation, and removing the banner to return to ordinary creation.
2. Respond to a response, including one on another timeframe. Walk the thesis
   from chart markers and thread rows; selection and the expanded thread should
   survive the timeframe change.
3. With another member viewing the thread, edit a response. Their open thread
   should refresh while retaining their selected marker.
4. Open marker details, scroll to **Delete Marker**, and confirm. The action is
   available to its author and permitted moderators. Delete an intermediate
   response with a surviving descendant. Its parent must
   still offer the thesis, show the active direct count accurately, and let you
   reach the descendant through an unavailable row.
5. Open a response notification. It should select the child marker on the right
   chart/timeframe. Check author and moderator permissions separately.
6. Check a dense chart, light/dark themes, large text and Reduce Motion. Focus
   taps should match the drawn glyphs; an empty chart tap exits focus. Unsafe
   connectors may be omitted; the shared stack line remains grey.

## Remaining release gates

- Manual VoiceOver speech and navigation order, including unavailable rows.
- Matched physical iPhone performance measurements, following
  `DEVICE_PROFILING_PLAN.md`: no greater than 5% average FPS regression and no
  new recurring frame stalls. Simulator sampling is diagnostic only.
- Verify deployed backend images and database migration head, then perform the
  disabled rollout/compatibility checks before enablement and Apple submission.

When reporting a defect, include app build, account role, symbol/timeframe,
steps, expected/actual behavior, and a screenshot or recording where useful.
