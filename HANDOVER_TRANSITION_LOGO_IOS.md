# iOS 1.3.0 — brand transition handover

Branch: `claude/1.3.0-marker-visuals`, worktree `.worktrees/linked-markers-claude`
Commits: `0453685` — *feat(transition): the app icon, not a pulsing welcome, at launch*
and the follow-up that moves the wordmark to the bottom (see git log).
Base for this change: `deb7b4f` (curve fix, integrated by Codex as `e94f5de`)
Version/build untouched: 1.3.0 (23)

## What changed, in one paragraph

The full-screen transition overlay drew a pulsing "Welcome to / Traders
Guild" for launch, and a guild crest in a progress ring for creating, joining,
deleting and switching guilds. Launch is now a splash in the Coinbase manner:
the square App Store icon alone in the centre of the screen, the "Traders
Guild" wordmark small at the bottom, nothing else. The guild operations keep
their crest-in-a-ring treatment exactly. The pulse is gone. Authentication,
navigation, loading and guild-operation behaviour are unchanged; this is
presentation only.

## Where the old welcome appeared, and why one change covers all of it

There is exactly one place `TransitionView` is presented —
`traders_guild/App/traders_guildApp.swift:57` — and it draws whatever
`RLAppState.transitionRequest` says. The launch request (`action == .launch`)
is what produced "Welcome to / Traders Guild", and it is used by:

| Situation | Where the launch request comes from |
|---|---|
| Cold start | `RLAppState.transitionRequest` initial value, `RLAppState.swift:519`, with `showingTransition = true` at `:199` |
| Return after termination / session restore | Same initial value; the overlay waits on `isSessionRestored` / `isChartReady` |
| End of signup | `showTransitionForChartLoad()` with no request, `RLAppState.swift:754` |
| End of onboarding | `showTransitionForChartLoad(minimumDuration: 0.6)`, `RLAppState.swift:1162` |

Every guild operation passes an explicit `.guild(action, guild:)` request
(`RLAppState.swift:1835`, `:1848`, `:1863`, `:1892`, `:2028`, `:2188`) and is
drawn by the same view. None of those call sites changed.

Two surfaces say "Traders Guild" and are deliberately **not** in scope: the
login landing (`WelcomeView.swift`, static large text, not a transition) and
the biometric lock (`BiometricAppLockView.swift`, "Unlock Traders Guild").

## Files

| File | Change |
|---|---|
| `traders_guild/Features/Shared/globalViews/AppLogoMark.swift` | **New.** The square icon, composed from the same two bundled layers Icon Composer builds the App Store icon from (`AppIconPreview/Assets/appiconbg 2.png` + `TG 3.png`). Proportional continuous corner radius (22.4% of side), optional stroke and shadow, decorative for accessibility. |
| `traders_guild/Features/Auth/GuildTransitionContext.swift` | `GuildTransitionAction.launch.headline` is now `"Traders Guild"` rather than `"Welcome to"`. **New** `GuildTransitionPresentation` — the pure, testable description of what the overlay draws: badge kind, layout (`standaloneMark` for launch, `badgeWithCaption` for guild operations), title, optional subtitle, whether a ring is shown and whether it animates, spoken label. |
| `traders_guild/Features/Auth/TransitionView.swift` | Launch branch replaced with the standalone mark and bottom wordmark; guild operations keep their composition. `scale` pulse state and its `repeatForever` animation removed. `@Environment(\.accessibilityReduceMotion)` added; a guild operation's ring rotation is skipped under it. Dismiss logic, `onChange` watchers, failsafe and minimum-duration handling untouched. |
| `traders_guild/Features/Core/subViews/leftDrawerSubViews/userProfile/UserSettingsSubViews.swift` | Private `AppIconPreviewView` deleted; About uses `AppLogoMark(size: 100)`. Identical output. |
| `traders_guildTests/GuildTransitionContextTests.swift` | `launchKeepsTheOriginalWelcome` → `launchIsTheBrandNotAWelcomeLine`; four presentation tests added. |
| `traders_guildTests/TransitionViewRenderTests.swift` | **New.** Renders launch, all four guild operations and the no-crest fallback through `ImageRenderer` and records each as a result-bundle attachment. |

## Design decisions

* **Launch is a splash, not a status.** The user's direction, after seeing a
  first cut that put the icon inside the guild ring with the name beneath: the
  icon on its own, the name at the bottom, the way Coinbase does it. So the
  launch layout is the 96pt icon centred with nothing around it, and a quiet
  wordmark — `.subheadline.weight(.semibold)`, white at 88%, light tracking —
  28pt above the bottom safe area. No ring: nothing competes with the mark.
* **Guild operations are untouched.** The crest in its ring with the verb and
  the guild's name beneath is the 1.2.1 treatment the user likes; it is drawn
  by the same view from the same presentation model, and the only change to it
  is that its ring now honours Reduce Motion.
* **The icon is the About screen's icon.** `AppLogoMark` was extracted from
  the private `AppIconPreviewView` rather than written again, so the two are
  visibly the same mark at 100pt and 96pt.
* **No pulse.** The launch overlay fades in once (the existing 1.0s ease-in)
  and holds. A guild operation's ring is the only continuous motion in either
  variant, it is progress rather than decoration, and it stops under Reduce
  Motion while still being drawn.

## Accessibility

* VoiceOver: one combined element. Launch speaks *"Traders Guild, loading"*;
  guild operations speak *"Switching Night Owls"* etc. The icon and crest are
  hidden as decorative.
* Dynamic Type: the launch wordmark is `.subheadline` with `lineLimit(1)` and
  `minimumScaleFactor(0.7)`; guild titles are `.title2` / `.subheadline` with
  `lineLimit(2)`. Verified at accessibility-XXXL: the wordmark scales, stays on
  one line, centred, and still clears the home indicator (`02-…`). The icon is
  fixed-size, as icons should be.
* Safe area: the wordmark is laid out inside the safe area (a `VStack` with a
  `Spacer`, not `ignoresSafeArea`), so it sits above the home indicator on
  every device rather than at a hard-coded offset.
* Reduce Motion: launch has no motion to reduce beyond the single fade;
  `GuildTransitionPresentation.animatesRing == false` for guild operations and
  the rotation is never started. Covered by test.
* Light/dark: the overlay sits on `StaticAuthBackgroundView`, whose gradient
  tokens are theme-aware; the icon carries its own navy ground so it reads on
  any theme; text uses the existing `whiteText` / `greyText` tokens as the guild
  variants already did.
* Small screens: the composition is an 88pt badge and two text lines, centred.
  No SE-class simulator was available to photograph.

## Evidence

All under `docs/transition-evidence/`.

| File | What it shows |
|---|---|
| `01-launch-cold-start-dark.png` | Cold launch of the isolated DevProfile build on the simulator: icon alone in the centre, "Traders Guild" at the bottom above the home indicator, no welcome line, no ring, no pulse. Captured at the overlay's peak on a warm session, which is about 70% opacity — see limitations. |
| `01b-launch-full-opacity-render.png` | The same composition at full opacity, from `ImageRenderer`. |
| `02-launch-dynamic-type-ax-xxxl.png` | Cold launch at `accessibility-extra-extra-extra-large` via `simctl ui content_size`: the wordmark scales, stays on one line, still clears the indicator. |
| `04-about-shared-logo.png` | About screen using the shared `AppLogoMark` — unchanged appearance, version 1.3.0 (23). |
| `render-launch.png`, `render-guild-{switching,creating,joining,deleting}.png`, `render-guild-initial.png` | `ImageRenderer` output of every variant at 402×874 @2x, from `TransitionViewRenderTests`. |

Simulator: iPhone 17 (`DA8FD3E2-…`), iOS 26.0 — a separate device from the one
used for marker work, and no physical device was touched.

## Tests and build

* Unit target, this change: **612 passed, 0 failed, 0 skipped** —
  `scratchpad/tr2-units.xcresult` (bottom-wordmark layout); the earlier ringed
  cut was also 612/612 at `scratchpad/tr-units2.xcresult`. (Previously 605 on the curve commit; +4
  presentation tests, +3 render tests.)
* `TransitionViewRenderTests` alone: 3/3, attachments exported with
  `xcrun xcresulttool export attachments`.
* Builds: `traders_guild Local Gateway` Debug (`build-for-testing`) and
  `traders_guild LinkedDev Profile` DevProfile, both clean.
* Full suite not re-run for this change. For the record, the last full-suite
  runs on the curve commit were: 612 passed / 1 failed / 5 skipped, the failure
  being `ChartPanPerformanceDriver` refusing to run against a signed-out app (a
  harness precondition I caused during the A/B, not a regression); and,
  excluding that driver, 611 passed / 1 failed — `NotificationSyncAndBottomSheetTests/
  statsIncreaseWithoutRealtimeInsertSchedulesCatchUpRefresh`, which passed in
  the prior full run and passes 9/9 in isolation, so a pre-existing
  order/timing flake unrelated to either change. The independently verified
  figure for the curve commit is the 605/605 unit run.

## Limitations, stated plainly

* **A live guild-operation transition was not photographed.** The QA account
  has one guild, the guild picker's *Enter* deliberately passes
  `showTransition: false`, and re-selecting the current guild is a no-op.
  Driving one live would mean creating or joining a guild, which changes DEV
  data. The variant is rendered instead (`render-guild-*.png`); the code path is
  the same one the launch variant now shares, and the crest/verb/name output is
  pinned by `guildOperationsKeepTheCrestVerbAndName`.
* **The on-simulator launch capture is not at full opacity.** On a warm
  session the session restores and the chart is ready within a second, so the
  overlay begins dismissing before its 1.0s entrance fade finishes — the
  brightest on-device frame is about 70%. That is the existing dismiss timing,
  which this change does not touch, and it is good for users; the full-opacity
  composition is in `01b-…` from `ImageRenderer`, and a cold session or a slow
  chart load shows it on device.
* **Reduce Motion is proven at the model level, not by stills.** For guild
  operations a single frame cannot show that a ring is *not* turning;
  `reduceMotionHoldsTheRingAndChangesNothingElse` covers the decision and the
  view never starts the rotation when `animatesRing` is false. Launch now has
  no ring.
* **Light-grey theme not photographed.** Switching the in-app theme is several
  taps through settings; the overlay's colours are all theme tokens the guild
  variants already used, so no new colour was introduced.
* **`TEST_RUNNER_TG_TRANSITION_RENDER_DIR`** is honoured by the render tests
  for anyone who wants the PNGs on the host; the reliable route is the
  result-bundle attachments.

## Integration notes for Codex

* Everything is in `0453685`, on top of `deb7b4f`. No changes to markers,
  backend, Android, macOS, signing or version.
* `AppIconPreviewView` was private to `UserSettingsSubViews.swift`; if any
  in-flight work references it by name, point it at `AppLogoMark`.
* `GuildTransitionAction.launch.headline` changed value. The only consumer is
  `TransitionView`, via `GuildTransitionPresentation`.
