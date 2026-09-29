# v1.5.0 Stage 1 checkpoint: fixtures and avatar foundation (Claude)

Branch `claude/1.5.0-avatar-markers`, based on `72b6f2b`. Worktree `.worktrees/marker-avatar-claude`. This is one local commit: not pushed, not deployed, with no backend or production contact. The commit hash is reported separately in chat, because a commit cannot contain its own hash.

Scope is Stage 1 only. The live chart still gives faces to `.personal` only, as before. Nothing from Stage 2 is implemented: no intent badges, rings, arcs, or live integration of the three intents.

## What changed

**Experiment gate:** `TradingChart/Models/MarkerAvatarExperiment.swift` (new).
- The gate is available only under `TG_ISOLATED_DEV`, which covers DevDebug and the optimised DevProfile. It is off by default.
- Launch override: `-TGAvatarMarkersExperiment YES|NO`. It is not persisted, and an unreadable value is ignored.
- Saved switch: set from the fixture gallery. It is read only from the app's own persistent domain.
- Every other configuration compiles `isEnabled` to `false`. In the Release binary neither the key nor any fixture strings survive.

**Fixture entry in optimised DEV:** `App/traders_guildApp.swift`, `Features/Shared/Marker/MarkerLinkFixtureGallery.swift`.
- `-MarkerLinkFixtures` now works in Debug and in both isolated configurations, including DevProfile, not just in `DEBUG`.
- The walkthrough harness stays DEBUG-only.

**Shared Canvas symbols:** `TradingChart/overlays/MarkerCanvasSymbols.swift` (new).
- `MarkerCanvasSymbols.content(avatars:)` produces the intent-glyph symbols and one avatar symbol per author. It is used by both the chart and the fixture canvas; the fixture had no `symbols:` closure before, so it only drew monochrome fallbacks.
- `MarkerAvatarSymbolStore` precomputes the author list when markers or the directory change, never per frame.
  - It deduplicates by author.
  - It uses the newest marker's snapshot as the fallback.
  - It publishes only on real change.
  - It prefetches each new URL once.
- The store observes `MemberAvatarDirectory` and never writes marker snapshots into it.
- `TradingChartView` now reads `store.entries` in its `symbols:` builder. The old per-body iteration over `filteredMarkers` is gone.

**Selection scaling:** `ChartMarkerSystem.swift`, `Models/MarkerVisualSpec.swift`.
- Each author's symbol is rendered once at selected resolution (54pt disc).
- It is drawn into bounds computed from the disc's current, animated diameter (`MarkerAvatarLayout`).
- It is drawn on the unrotated context, so the face stays upright through the wiggle, and it is clipped to its circle.
- Previously the face was drawn at native symbol size and overflowed the disc during the selection pop.
- New seam: an `avatarIntents` parameter on `drawMarkers`. Its default is `[.personal]`, which is today's behaviour.

**Identity:** `MarkerAvatarIdentity.forAuthor(_:directory:)`.
- The directory wins over the snapshot.
- An explicit removal (`""`) beats the snapshot.
- The snapshot is used only for authors the directory has never seen.
- The rule is shared with chat avatars through `MemberAvatarDirectory.resolve(userId:fallback:in:)`.
- The stale header that claimed personal markers are always private and the viewer's own is corrected.

**Image loading:** `Features/Shared/globalViews/CachedAvatarImage.swift`.
- Pending loads are deduplicated per URL. A prefetch and the view that needs the same picture now share one request; previously the view fetched through `URLSession.shared` directly.
- Correctness fixes from Astra's reviews, all in this checkpoint:
  - **Atomic cache operations.** Cache lookup, the decision to create a request, token-checked publication, and invalidation all run in one critical section under one lock. The cache is rechecked inside that section.
  - **No automatic transport caching.** The loader's session is a copy of its configuration with `urlCache = nil`. Responses reach the response cache only through the token-checked store, so a removal while a load is in flight cannot be undone by transport caching.
  - **No painting after cancellation.** `CachedAvatarImage` checks its own task's cancellation before writing state. The shared load outlives the view, so this check is what stops a superseded URL painting.
- Consumers `GuildBannerView`, `TradingSymbolIconView` and `LeftDrawerViewModel` are unchanged apart from sharing the dedup.

**Fixtures:** `Features/Shared/Marker/MarkerAvatarFixtures.swift` (new), plus the gallery.
- Local, deterministic avatar pictures are drawn in code with a stable djb2 hash. They are stored into `AvatarImageCache` under a reserved `.invalid` host, so the real `CachedAvatarImage` → symbol → renderer path shows them with no network.
- The deliberate failed load uses a missing `file:` URL.
- There are 13 scenes, listed below.
- Review controls:
  - scene menu
  - experiment toggle, which writes the saved switch
  - focus toggle
  - selected-scale slider (1.0–1.5)
  - wiggle slider
  - tap to select, through the production `findMarkerAtLocation`
  - clear selection
  - on the Avatar states scene, "Rae: next picture" and "Ivy: toggle removal", which write to the real directory to show live refresh
- Launch arguments: `-MarkerFixtureScene <key>`, `-MarkerFixtureSelect <n|0>`, `-MarkerFixtureScale <x>`, `-MarkerFixtureRotation <deg>`.

**Tests (new):**
- `MarkerAvatarExperimentTests`: gate resolution, override precedence, and suite isolation. It also checks per-host-build availability. The host build is identified by bundle id, because the test target does not inherit the app's `TG_ISOLATED_DEV`.
- `MarkerAvatarIdentityTests`: fallback, newer-wins, removal, nothing-to-draw, dedupe, intent filter, newest snapshot, directory refresh, no republish or re-prefetch on unchanged input, and snapshots never written to the directory.
- `AvatarImageCacheLoadTests`:
  - one request shared by concurrent callers
  - invalidation between response and publication (a test seam)
  - removal while in flight detaches the old load
  - cacheable-response control, plus no resurrection through transport caching (mutation-checked: fails with transport caching re-enabled)
  - failures are not cached and are retried
  - a cancelled caller paints nothing
- `MarkerAvatarRenderTests`: pixel measurement through the real `drawMarkers` and `symbols:` path.
  - At scales 1.0, 1.1, 1.25, 1.4 and 1.5, the face is ±1.5pt of `avatarDiameter(36×s)` and clipped inside the disc.
  - It stays upright at 8°, −6° and 45° of wiggle.
  - Legacy intents keep their glyph, as does Analysis with the experiment off. Personal still shows a face.
- `MarkerGeometryInvariantTests`: pins the 36pt disc, 1.5× selected scale, 28pt hit radius, 40pt minimum stack spacing and 10pt nudge, and checks that the face always sits inside the disc.

## Commands and results

All runs used simulator `iPhone 17 Pro` (iOS 26.0), `CODE_SIGNING_ALLOWED=NO`, and a DerivedData folder in the session scratchpad.

| Command | Result |
|---|---|
| `xcodebuild build`, scheme `traders_guild LinkedDev`, `DevDebug` | BUILD SUCCEEDED |
| `xcodebuild test`, `LinkedDev` (DevDebug), new suites + `MemberAvatarDirectoryTests` | 42/42 passed |
| `xcodebuild test`, `Local Gateway` (plain Debug, not isolated), new suites | 38/38 passed; covers the production branch of the gate. Run before the transport-cache follow-up, which does not touch the gate |
| `xcodebuild test`, `LinkedDev`, `-only-testing:traders_guildTests` (whole unit target), before the transport-cache follow-up | 741 tests passed (747 runs including parameterised cases); 0 failed, 0 skipped |
| Re-run after the transport-cache fix: cache, render and identity suites | 30/30 passed |
| **Final source**: `xcodebuild test`, `LinkedDev`, `-only-testing:traders_guildTests` (whole unit target) | **744 tests passed (750 runs); 0 failed, 0 skipped** |
| Mutation: transport caching re-enabled | `removalInFlightCannotBeResurrectedByTransportCaching` failed as expected; source restored |
| `xcodebuild build`, `LinkedDev Profile`, `DevProfile`, final source | BUILD SUCCEEDED; compiled with `-O -wmo`. Installed and ran the fixture (screenshot 19) |
| `xcodebuild build`, `GCP Public Prod`, `Release` | BUILD SUCCEEDED |
| `strings` on the binaries | Release: 0 fixture strings, 0 `TGAvatarMarkersExperiment`. DevProfile: fixture and experiment present |
| `git diff --check` | clean |

Test runs need `ONLY_ACTIVE_ARCH=YES` on the command line. Without it the test target builds x86_64 against an arm64-only app module and fails with "unable to resolve module dependency". This predates Stage 1; the project's test targets carry no `ONLY_ACTIVE_ARCH` setting.

## Visual evidence

Location: `docs/visual-review/v1.5-stage1/`. Captured in the isolated DevDebug simulator app (`co.tradersguild.app.linkeddev`, dark appearance), launched with `-MarkerLinkFixtures`. Every marker is drawn by `ChartMarkerSystem.drawMarkers` through Canvas symbols; the faint candles behind them are fixture context only.

| File | Scene | What to look at |
|---|---|---|
| `01-intents-selected-picture.png` | Analysis, Question and Setup by a picture author, then by an initials author; alex's Analysis selected at 1.5× | Faces replace the three intents' glyphs; the selected face fills the enlarged disc |
| `02-intents-resting.png` | Same, nothing selected | Resting 36pt size; badges unchanged |
| `03-selection-mid-animation-1.2-wiggle8.png` | Selection frozen at 1.2× with an 8° wiggle | Face sized to the disc mid-animation, upright, clipped |
| `04-selection-initials-selected.png` | An initials author selected | The initials symbol scales in the same way |
| `05-repeated-and-distinct-authors.png` | alex four times (one symbol), plus sam, jamie, kit, omar | Repeated identity is recognisable |
| `06-same-candle-stacks.png` | Four above one candle, three below another | Stack spacing and the selection nudge are unchanged |
| `07-adjacent-candle-stacks.png` | Neighbouring candles with proximity tiers | Faces on neighbouring candles |
| `08-dense-thesis-focus.png` | Existing dense thesis scene with focus active | Relationship rings, connectors, dimming and badges intact over faces |
| `09-zoomed-out.png` | 60 narrow candles, 36 markers | Density evidence: faces overlap across candles exactly as glyphs do. No density change made |
| `10-chart-edges.png` | First and last candles, plus an eight-deep stack | Faces clip at the plot edges as glyphs do. The deep stack does not reach the top clamp at this canvas height; the viewport clamp is unchanged code and pinned by existing tests |
| `11-relationships-focus.png` | Supports / Challenges / Builds on, focused | Relationship colours on faces |
| `12-opposite-stacks-focus.png` | Parent above, responses below, focused | Routing around faces |
| `13-setup-states.png` | Untracked / armed / live / TP hit / SL hit | Setup faces. Status treatment is Stage 2 |
| `14-avatar-states.png` | Picture, initials, failed load, changed (directory newer than snapshot), removed (directory `""`), nothing to draw | Resolution rules. Nothing-to-draw falls back to the intent glyph |
| `15-mixed-legacy.png` | The three intents beside Alert, Poll, News, Reaction and Personal (private and shared) | Only the three intents plus Personal wear faces |
| `16-mixed-legacy-experiment-off.png` | Same with the experiment off | Legacy glyphs, now drawn with the proper palette symbols in the fixture; Personal keeps its face |
| `17-dense-experiment-off.png` | Dense scene with the experiment off | Baseline for comparison with 08 |
| `18-avatar-states-after-directory-change-and-restore.png` | Scene 14 after tapping "Rae: next picture" and "Ivy: toggle removal" | Live refresh through the real directory observation: Rae's picture changes, Ivy's restored picture replaces the initials |
| `19-devprofile-optimised-same-candle-stacks.png` | Scene 06 in the optimised **DevProfile** build | Fixture entry works in optimised local DEV |

## Performance

Unmeasured. Stage 1 profiled nothing, per the master plan: physical-device comparison belongs to Stage 5 with LinkedDev Profile.

The structural change on the pan path is a reduction. The `symbols:` builder used to iterate every filtered marker on each body evaluation; it now reads a precomputed array. That array changes only when markers or the avatar directory change.

## Known issues

- Selection nudge overlap, pre-existing and now more visible. The nudge moves a selected marker's ±1 stack neighbours 10pt away. That leaves 30pt between the nudged neighbour and the ±2 marker, while the disc is 36pt, so they overlap by about 6pt (`06-same-candle-stacks.png`). Glyphs overlap identically; faces make it easier to see. The geometry is unchanged and pinned. Any change is a Stage 2 decision.
- Setup states all look alike. Untracked, armed, live, TP and SL show the same face (`13-setup-states.png`), and a Setup cannot be told from an Analysis at rest. This is expected before the Stage 2 intent and status badges.

- Two initials styles. A missing avatar uses the existing personal-marker fallback (grey tint). A failed load uses `CachedAvatarImage`'s own placeholder (teal accent tint; "FE" in screenshot 14). Both predate Stage 1. Unifying them changes shared avatar styling, so it is left for a decision in Stage 2.
- Density is unchanged by design. The zoomed-out and adjacent-candle scenes show faces overlapping across neighbouring candles exactly as glyphs do today. This is the evidence the master plan asks for before any density work.
- When the gallery shows a scene it clears and repopulates `MemberAvatarDirectory.shared`. This happens only in fixture mode, which has no signed-in surfaces.
- The live chart (`TradingChartView`) passes `avatarIntents` as `[.personal]`. Turning the experiment on changes only the fixture gallery until Stage 2.

## Remaining work (Stage 2 onward, not started)

- Live integration of the three intents behind the gate.
- Widen the SwiftUI badge and the placement ghost to the three intents.
- Intent badge and connector obstacles; idle intent ring and relationship precedence; selected component arcs; Setup status badge.
- Owner visual review after Stage 2.
