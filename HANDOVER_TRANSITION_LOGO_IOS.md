# iOS 1.3.0 — brand transition handover

Branch: `claude/1.3.0-marker-visuals`, worktree `.worktrees/linked-markers-claude`
Commit: `0453685` — *feat(transition): the app icon, not a pulsing welcome, at launch*
Base for this change: `deb7b4f` (curve fix, integrated by Codex as `e94f5de`)
Version/build untouched: 1.3.0 (23)

## What changed, in one paragraph

The full-screen transition overlay drew two different things: a pulsing
"Welcome to / Traders Guild" for launch, and a guild crest in a progress ring
for creating, joining, deleting and switching guilds. It now draws one
composition for all of them — a badge inside the ring, a title, and for a guild
operation the guild's name — where the badge is the square App Store icon at
launch and the crest otherwise. The pulse is gone. Authentication, navigation,
loading and guild-operation behaviour are unchanged; this is presentation only.

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
| `traders_guild/Features/Auth/GuildTransitionContext.swift` | `GuildTransitionAction.launch.headline` is now `"Traders Guild"` rather than `"Welcome to"`. **New** `GuildTransitionPresentation` — the pure, testable description of what the overlay draws: badge kind, title, optional subtitle, whether the ring animates, spoken label. |
| `traders_guild/Features/Auth/TransitionView.swift` | Launch branch replaced; both variants share one layout. `scale` pulse state and its `repeatForever` animation removed. `@Environment(\.accessibilityReduceMotion)` added; the ring rotation is skipped under it. Dismiss logic, `onChange` watchers, failsafe and minimum-duration handling untouched. |
| `traders_guild/Features/Core/subViews/leftDrawerSubViews/userProfile/UserSettingsSubViews.swift` | Private `AppIconPreviewView` deleted; About uses `AppLogoMark(size: 100)`. Identical output. |
| `traders_guildTests/GuildTransitionContextTests.swift` | `launchKeepsTheOriginalWelcome` → `launchIsTheBrandNotAWelcomeLine`; four presentation tests added. |
| `traders_guildTests/TransitionViewRenderTests.swift` | **New.** Renders launch, all four guild operations and the no-crest fallback through `ImageRenderer` and records each as a result-bundle attachment. |

## Design decisions

* **The icon sits in the same ring the guild crest does.** The user liked the
  1.2.1 guild transitions; putting the app icon in that exact slot, with the
  brand accent as the ring colour where a crest colour would be, is what makes
  the five transitions read as one family. 60pt inside an 88pt ring leaves the
  square's corners about as far from the ring as the 72pt crest's edge is.
* **"Traders Guild" beneath the badge, as the title.** The guild variants put
  the verb in the title slot and the name beneath; launch has no verb, so the
  brand takes the title slot and there is no subtitle — repeating the name
  would be noise. Placing it toward the bottom of the screen was considered and
  rejected: it would break the shared layout for no gain.
* **No pulse; the ring is the only motion.** The ring is a progress indicator,
  which is honest about what the overlay is doing (waiting for the chart). It
  turns under normal motion and holds under Reduce Motion — still drawn, so the
  state still reads. The old guild-operation ring was never gated on Reduce
  Motion; it is now.
* **One entrance.** The existing 1.0s ease-in fade is kept. Nothing loops.

## Accessibility

* VoiceOver: one combined element. Launch speaks *"Traders Guild, loading"*;
  guild operations speak *"Switching Night Owls"* etc. The icon and crest are
  hidden as decorative.
* Dynamic Type: title and subtitle use semantic fonts (`.title2`, `.subheadline`)
  with `minimumScaleFactor(0.7)` and `lineLimit(2)`. Verified at
  accessibility-XXXL: the title scales, stays centred, no clipping (`02-…`).
  The icon and ring are fixed-size, as icons should be.
* Reduce Motion: `GuildTransitionPresentation.animatesRing == false`; the
  rotation animation is never started. Covered by test; see limitations for
  what the simulator could and could not show.
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
| `01-launch-cold-start-dark.png` | Cold launch of the isolated DevProfile build, overlay at full opacity: icon in the ring, "Traders Guild" beneath, no welcome line, no pulse. |
| `01b-launch-badge-detail.png` | Crop of the badge and title. |
| `02-launch-dynamic-type-ax-xxxl.png` | Same, at `accessibility-extra-extra-extra-large` via `simctl ui content_size`. |
| `03-launch-reduce-motion-frame.png` | The one usable overlay frame with `ReduceMotionEnabled` set; the arc is at its unrotated position. |
| `04-about-shared-logo.png` | About screen using the shared `AppLogoMark` — unchanged appearance, version 1.3.0 (23). |
| `render-launch.png`, `render-guild-{switching,creating,joining,deleting}.png`, `render-guild-initial.png` | `ImageRenderer` output of every variant at 402×874 @2x, from `TransitionViewRenderTests`. |
| `cmp-launch-badge.png` / `cmp-switching-badge.png` | Matching crops of the launch and switching variants, for a side-by-side. |

Simulator: iPhone 17 (`DA8FD3E2-…`), iOS 26.0 — a separate device from the one
used for marker work, and no physical device was touched.

## Tests and build

* Unit target, this change: **612 passed, 0 failed, 0 skipped** —
  `scratchpad/tr-units2.xcresult`. (Previously 605 on the curve commit; +4
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
* **Reduce Motion is proven at the model level, not by stills.** With a warm
  session the overlay is up for barely a second, and a single frame cannot
  show that a ring is *not* turning. `reduceMotionHoldsTheRingAndChangesNothingElse`
  covers the decision, and the view never starts the rotation when
  `animatesRing` is false.
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
