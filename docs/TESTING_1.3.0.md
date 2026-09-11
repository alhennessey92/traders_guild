# Testing iOS 1.3.0

Use this feature worktree's Xcode project and the **traders_guild LinkedDev**
scheme for hands-on testing. It installs **TG LinkedDev** with separate app data.
The **traders_guild LinkedDev Profile** scheme uses optimized code for profiling.
The production scheme is for release packaging and uses the App Store bundle ID.

Candidate: **1.3.0 build 23**, on `feat/1.3.0-linked-markers`.

The simulator uses the Mac's loopback gateway on port 30080. A physical iPhone
needs the Mac's current LAN address in `TG_LAN_HOST` and network access to that
gateway. A previously installed build can contain an outdated address; rebuild
after a network change. Local DEV services and data are retained.

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
