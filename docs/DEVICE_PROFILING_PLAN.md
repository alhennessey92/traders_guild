# iPhone 14 Pro — isolated DEV build and profiling plan

Draft for approval. **Nothing has been installed on the device.** The App Store
build of `co.tradersguild.app` on Al's iPhone 14 Pro must survive this untouched,
so the whole plan turns on not colliding with it.

## The collision risk

The project builds `co.tradersguild.app` in every configuration — Debug and
Release share one bundle identifier (`project.pbxproj:414`, `:441`). Installing a
DEV build as-is would **replace the App Store app and its keychain-backed
session**. That is the thing to avoid, and it is not hypothetical: the simulator
already autofilled a personal account during this session's E2E, which is the
same credential store a device build would reach.

## Isolation, in order of preference

1. **Distinct bundle id via an xcconfig override** — `co.tradersguild.app.dev`,
   applied to Debug only, so both apps coexist on the device with separate
   containers, keychain access groups and notification registrations.
   Needs: a matching development provisioning profile for the new id, and a
   check that nothing hard-codes the identifier (Sign in with Apple's
   `appleSignInClientID` is `co.tradersguild.app` in `AppConfig.swift:21`, so
   Apple sign-in will not work on the DEV id — use email sign-in with the QA
   account, which is what the E2E used anyway).
2. **Separate scheme** carrying the DEV bundle id and the env vars below, so the
   normal schemes cannot produce a device build by accident.

Do **not** proceed by simply running the existing scheme at the device.

## Reaching the local backend from the device

Device builds do not resolve `localhost`. `AppConfig` already provides for this:

- `TG_GATEWAY_BASE_URL_DEV_DEVICE` — set to `http://<mac-lan-ip>:30080/api/v1`.
  Setting it also flips `apiRoutingMode` to `.apiGateway` on device debug builds
  (`AppConfig.swift:34`), which is what the simulator E2E used successfully.
- `TG_DEV_MAC_IP` — the direct-services fallback (`RealAPIService.swift:106`),
  only needed if the gateway is bypassed.

Both the phone and the Mac must be on the same network, and the Docker gateway
must be bound so it is reachable off-host — it currently listens on `*:30080`,
which should suffice.

Plain HTTP to a LAN address needs an ATS exception for that host in the DEV
target only. Do not weaken ATS in the shared configuration.

## What to measure

**The 57 frames/s figure is context, not a baseline.**

The gesture-perf work measured 57 frames drawn per second during a pan, on a
different build of a different version, on an unrecorded dataset, some weeks
ago. Comparing a new measurement against it would attribute to linked markers
every difference that has accumulated since — other 1.2.x chart changes, a
different marker count, a different iOS version, a warmer or colder device.

So it is a sanity check on the order of magnitude and nothing more. The number
that decides whether this feature costs frames is a **matched pair**, measured
in one sitting:

| | Build | Bundle id |
|---|---|---|
| A | `.worktrees/linked-markers-ios-device-baseline` — 1.2.1 as submitted | `co.tradersguild.app.linkeddev` |
| B | this worktree — 1.3.0 with linked markers | `co.tradersguild.app.linkeddev` |

Both built `DevProfile`, both installed on the same iPhone 14 Pro, both driven
over the same guild, symbol, timeframe and marker set, back to back, on the same
charge state. The isolated configuration is deliberately free of feature code so
that it applies unchanged to the baseline worktree; that is what makes A and B
differ only by the feature.

Report the pair, never a single number against history.

1. **Same fixture, same gesture.** A thesis with enough responses to force a
   dense stack, one sustained horizontal pan, repeated three times.
2. **Two runs: focus inactive and focus active.** The interesting number is the
   delta, since focus is the only state that adds work.
3. **Instruments — Time Profiler and Animation Hitches.** Watch for
   `MarkerLinkGeometry.plan`, `isSafe` and `trim` on the main thread; they are
   sampled curve maths and are the plausible cost.
4. **Acceptance**: ≤5% mean FPS regression against baseline, and no recurring
   hitch attributable to marker drawing.

Two costs were already removed after audit — the painted-member report no longer
allocates per frame, and does nothing at all unless a thesis is focused — but
that is reasoning, not measurement, and this is the measurement.

## Teardown

Uninstall the DEV app, confirm the App Store build and its session are intact,
and remove the LAN ATS exception if the DEV target is not kept.
