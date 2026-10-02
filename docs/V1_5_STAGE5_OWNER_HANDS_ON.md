# v1.5.0 Stage 5: owner hands-on review note

For the owner, on the iPhone, by hand. **Not an acceptance waiver.** This covers what the automated runs could not judge: feel, visuals, posting and VoiceOver. Nothing here was turned on or started by Claude.

`$S` = `/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad`.

## What is on the phone now

- **App:** "TG LinkedDev" (`co.tradersguild.app.linkeddev`), the isolated local-DEV app.
  - Last installed by the device run on 2026-10-02 at about 18:03 UTC, from `$S/dd-device-proto` (DevProfile).
  - That is **prototype code `5f9ee89`** (integrated as `37fb5e2`), including the badge-glyph optimisation.
  - Production "Traders Guild" and "TG Prod QA" are untouched. Do not use them for this review.
- **Account:** signed in as **@stage4658f08a** (local QA account A), guild **Stage4 QA 658f08**. If it is ever signed out, the password is in the protected local file `$S/stage4/qa-creds.json` (`accounts.a`), mode 600.
- **Experiment gate:** read once per launch, from a launch argument, else a saved switch, else off.
  - The automated runs used launch arguments only, which are not saved. So **a normal home-screen launch has the experiment OFF** (legacy markers), unless the saved switch was set.
  - **To review with the experiment on, either:**
    - **one launch:** from the Mac, `xcrun devicectl device process launch --device 0C90C5FD-D935-51C9-A75F-F8570802F382 --terminate-existing co.tradersguild.app.linkeddev -TGAvatarMarkersExperiment YES`. It lasts until the app is next launched from the home screen;
    - **saved:** launch the fixture gallery once with the same command, but with `-MarkerLinkFixtures` as the argument. Turn on "Avatar markers experiment (saved)", then launch normally from the home screen. Turn it off the same way afterwards.
- **Phone settings changed for testing:** Settings → Developer → **Enable UI Automation** is on. That was the owner's change, and it is not needed for this review. Turn it off whenever you like.

## Where the test data is

Everything is in the local DEV stack. Keep the Mac's local stack running and the phone on the same Wi-Fi.
- **BTC/USD, 1h timeframe**, 29 Sep to 1 Oct. 61 seeded markers from authors A–E: Analysis, Question and Setup, with same-candle stacks.
- **The test thesis:** the Analysis parent around **30 Sep 18:00–19:00**, with three responses: Supports, Challenges and Builds on.
  - Quickest route: open `tradersguild-linkeddev://marker/0ab0ce3d-deca-4d49-8cc9-f8d388ae93fa` in Safari on the phone.
  - A second parent, around 30 Sep 06:00: `tradersguild-linkeddev://marker/0347baeb-3544-402c-a4cb-4387d61f53f6`.

## Hands-on checks, about 15 minutes

Do each with the experiment **on**, then glance at the same screen with it **off** for comparison.

1. **Panning feel.** On BTC/USD 1h, with nothing selected and then with the thesis selected, drag and fling left and right, slowly and fast. Note any stutter, lag or visual tearing around faces, badges, rings or branches. The automated CPU numbers say nothing about smoothness.
2. **Selection and branches.** Tap a face to select it. Check:
   - the title and the bottom chip;
   - the dashed branches to its responses;
   - the relationship colours (Supports green, Challenges red, Builds on accent);
   - unrelated markers dimmed;
   - the pop and settle.
   Tap ✕ and check everything returns to rest. Try a same-candle stack.
3. **Faces and badges.**
   - Every Analysis/Question/Setup marker shows its author's face, with a small intent badge (the optimised glyph). Check it reads clearly at normal size.
   - Setup badges show their state.
   - Switch the theme (Dark, Mid-Grey, Light Grey) and check the initials discs and badges stay legible.
4. **Posting** (guided creation): Markers → "Post to the chart" → type → details → review → Post. Try one Analysis and one Setup.
   - **Post on another timeframe (e.g. BTC/USD 15m), not 1h,** so the 1h fixture used for performance runs stays identical.
   - Posts create real local-DEV markers in the QA guild only.
   - Check the review screen, the posted marker's face and badge, and that it opens correctly.
5. **VoiceOver** (Settings → Accessibility → VoiceOver, or triple-click the side button if set up):
   - In guided creation, the type chips announce their names and "selected".
   - Price fields say "Take Profit" and "Stop Loss".
   - Each review line is one element ("Entry, Latest price when you post, …").
   - The moved-market card offers "Adjust levels".
   - The marker list, detail sheet and thesis rows speak the relationship words.
   - Known and unchanged: individual chart markers are drawn on a Canvas, so VoiceOver can't reach them, as with legacy markers.
   - Optionally, a short Switch Control pass.

Write down anything odd with the time, so it can be matched to the local logs.

## Optional: manual frame capture (bounded, owner-driven)

Frame and hitch evidence is still missing: under XCUITest, iOS's automation overlay dominated the trace, and long all-process traces filled the phone's storage. A short, hand-driven capture avoids both.

- **Setup:** Mac Xcode → Open Developer Tool → **Instruments** → **Animation Hitches**. Device: Al's iPhone. Target: **the running "TG LinkedDev" process** (attach), **not All Processes**.
- **Bounded:** recording mode "Last 30 seconds" (windowed), or a 30 s time limit. **One state per recording:** pan by hand for about 15 s with the thesis selected; then a separate recording with nothing selected.
- **Pairs:** the same gestures with the experiment on and with it off (prototype build, gate off ≈ baseline). That is 4 recordings, each about 30 s; all are saved on the Mac.
- **Storage:** check the phone's free storage before and after (Settings → General → iPhone Storage). If a recording reports "malformed" or storage drops sharply, stop. Do not delete phone data to make room; restart the phone instead.
- **Then:** Claude can read the saved `.trace` files on the Mac (hitch count, hitch time ratio, frames per window) without touching the phone.

## Still open, and not waived

- **Frame smoothness and cold-load frames:** no frame or hitch evidence yet (§8, §10 of `V1_5_STAGE5_CHECKPOINT.md`). Cold-load behaviour was measured only as requests and timing, not frames.
- **Warm-pan CPU:** resolved within the baseline spread (Astra, `e1ffd10`). That is the bounded conclusion only, not Stage 5 or production acceptance.
- **Older-client runtime compatibility** (iOS 1.1.1/1.1.2, Android): source inference only. Sol found uploaded iOS 1.1.1 build 6 and 1.1.2 builds 7/8/9 archives, but exact source and the shipped 1.1.2 build remain unproved. These production-targeted archives cannot exercise local DEV unchanged. Android 1.4.0 code 19 artifacts and source line were identified; local DEV runtime coverage is still pending.
- **VoiceOver and Switch Control by hand:** the checks above.
- **Carried decisions:** the owner-delete permission mismatch, legacy Reduce Motion, the link-banner wrap.
- **Deferred auth issues** (recorded, not changed): the client token-persistence fragility, and password change not revoking sessions.
- Earlier owner approvals (the tracked-Setup integrity correction and others) stand as recorded. Nothing here changes them.
