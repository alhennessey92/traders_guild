# Lifecycle acceptance evidence — 10 September 2026

Claude drove the isolated simulator app against the local DEV backend using two disposable QA members. Codex reviewed the implementation and the retained-branch and failed-submit screenshots, and independently read the Xcode result bundle on 11 September.

- `C03`: moderator deletion asks for confirmation.
- `C05`: a root with zero active direct responses retains its thesis disclosure.
- `C07`: the surviving grandchild is reachable beneath its unavailable parent.
- `D02`: a parent deleted while the response composer was open causes submission to fail; the link banner and draft remain visible.

These captures use a separate disposable acceptance branch. The deep/wide performance fixture was preserved. Backend commit `0e8eaf4` supplies structural response flags; Claude commits `fdf28a0` and `31da3ca` consume them and repair deletion. Integrated iOS source at `179cbe6` matches Claude `3a5ef4b` for application and tests.

`test-summary.json` is the independent `xcresulttool get test-results summary` output for `scratchpad/full11.xcresult`: **604 passed, 5 skipped, 0 failed, 609 total**. The device-level invocation count includes an additional parameterized invocation; the top-level test count is used here. Skips are the existing credential-dependent auth and guild-picker UI cases.

This is simulator interaction evidence. Physical frame-rate/stall measurement, manual VoiceOver speech/rotor acceptance, and production rollout verification remain open. Hard-deleted detached responses have backend integration and iOS decoding coverage, but were not manually produced in the running simulator.

## Integrated Release build — 11 September 2026

Codex's clean production-scheme simulator Release build passed after integration, with zero compiler errors. Log: `/tmp/linked-codex-release-lifecycle.log`. Artifact: `/tmp/linked-codex-release/Build/Products/Release-iphonesimulator/traders_guild.app`; inspected identity `co.tradersguild.app`, version **1.3.0**, build **23**, iPhoneSimulator platform. No xcconfig or stray DEV plist resources are bundled. Final Xcode inventory lists the app, unit tests and UI tests only, with zero macOS targets. This simulator artifact is not a device archive or App Store submission.
