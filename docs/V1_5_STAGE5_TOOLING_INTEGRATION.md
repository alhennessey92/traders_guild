# v1.5.0 Stage 5: test-tooling changes since `f54b85a`, for integration

Branch `claude/1.5.0-avatar-markers`, `f54b85a..e1ffd10` plus this document. It contains one product change, `5f9ee89`, already reviewed and integrated by Astra as `37fb5e2`. Everything else is test-only code, test tooling or documentation.

**Secrets.** No credentials, tokens or token ids are in any committed file.
- Tooling reads credentials only from the local protected file at run time.
- Since `d3fcd57`, the UI-test driver neither types nor receives passwords, and `run_perf.py` passes only the username.
- Evidence JSON holds sha256 fingerprints and times only. A scan of `docs/` for every QA password, and its 12-character prefix, found 0 files.
- Result bundles (`.xcresult`), run logs and the session-check console output stay in the local scratchpad and are **not** for integration. Some early ones hold an old, since-rotated QA password in clear (checkpoint §6–§7).

## Product code (already integrated)

| Commit | File | Change |
|---|---|---|
| `5f9ee89` | `traders_guild/TradingChart/overlays/MarkerLinkRenderer.swift` | The intent-badge glyph is drawn as an 8 pt heavy SF Symbol template image (`MarkerBadgeGlyphImages`, built once per symbol, lock-guarded, tinted per pass) instead of `Text(Image(systemName:))`. Only the experiment's intent badge uses this path. |
| `3b0b539` | the same file | Doc comment only: attribution qualified as controlled simulator profiling, device confirmation pending (confirmed since in §10). |
| `5f9ee89` | `traders_guildTests/MarkerBadgeGlyphImagesTests.swift` (new) | 2 tests: a template glyph for every badge symbol at badge size, built once. |

## UI-test driver: `traders_guildUITests/MarkerAvatarPerformanceDriver.swift` (test-only, identical file in baseline and prototype builds)

| Commit | Change | Why |
|---|---|---|
| `7469606` | The sign-in step checks the drawer's account card against `TG_QA_USERNAME`. The park step opens the seeded parent and closes the selection first. | The phone held another local account; parking needed the symbol tab. |
| `09bf30d` → `d3fcd57` | Password typing tried, then **removed**: a signed-out app fails with "sign in by hand". | The device pasteboard is unavailable, and XCTest's secure-field redaction proved unreliable. |
| `2021bf3` | The drawer tap is retried after sign-in. | The first tap was ignored while the guild loaded. |
| `dc94a08` | `XCTHitchMetric` dropped. | It competes with the system trace for the kernel trace session. |
| `563e5ee` | Links go through `XCUIDevice.shared.system.open` instead of `XCUIApplication.open`. | `open(url)` launched a new app process for every link. |
| `53da977` | No app launch inside `measure`; the measured relaunch is removed; test1 is a single phase window. | Session loss correlated with launches inside `measure` on the phone. |
| `6b9fb4d` | The sign-in check waits up to 30 s for the chart before judging "signed out". | The welcome screen shows during session restore. |
| `5e7826a` | The deselect is awaited (up to 5 s) instead of a fixed 1.5 s pause. | One slow deselect failed a good run. |

The resulting test set: `test0` account check, `test1` first launch and load (unmeasured phase window), `test2` in-process revisit (measured), `test3_1…5` / `test4_1…5` one anchored pan each (measured; anchor outside `measure`), `test5` park. Metrics: app CPU, app memory, clock.

## Local tooling: `docs/visual-review/v1.5-stage5/perf-tooling/` (copies of what ran)

| File | Change since `f54b85a` |
|---|---|
| `run_perf.py` | Passes only the username, never credentials. The whole-run trace is **off** by default (`TG_WHOLE_RUN_TRACE=1` turns it back on): it filled the phone's storage. Records the xctestrun used and the destination. |
| `run_all.sh` | `TG_FROM=<step>` resumes a sequence (skipping earlier steps and their rotation). |
| `run_interleaved.sh` (new) | The short interleaved, cooled, warm comparison used for §10. |
| `session_check.py` (new) + `test_session_check.py` (new, 19 offline tests) | Fail-closed device gate. It correlates test exits, phase windows, refresh results and the account's push-token row per launch (fingerprints only). Redis timing is corroboration only. |
| `rotate_qa_passwords.py` (new) | Local-only password rotation for disposable QA accounts. Staged mode 600, prints no secrets. Used once, for A and B. |
| `fixture_snapshot.sh` (new) | Read-only fixture fingerprint (users, markers, device rows). |
| `run_frames.py`, `run_frames_all.sh` (new) | Per-test short-trace frames pass. **Not evidence:** under XCUITest the automation overlay dominated the trace (§8). Kept for reference; not recommended. |
| `hitches_by_phase.py` (new) | Per-phase hitch and frame read-out from a `.trace` (would serve a manual capture). |
| `summarize_sequence.py` | Shows zero-request windows as zeros, counts pans that end off the seeded view, and reads only run summaries. |

## Profiling evidence: `docs/visual-review/v1.5-stage5/profiling/`

- `timings.md`: the matched attribution and before/after tables.
- `sample-marker-canvas-subtree.txt`: main-thread subtree of the marker canvas.
- `badge-glyph-before-after-zoom.jpg`: the visual comparison.
- Scripts: `profile_pan.sh`, `time_pan.sh`, `main_thread_profile.py`, `subtree.py`.
- `profiling-instrumentation.diff`: the **temporary** instrumentation used, for reproduction only. **Never integrate it.**

## Integration notes

- The driver is test-only, but the baseline comparison relies on the **identical** file in the baseline snapshot. Keep them in step if it changes again.
- The perf tooling assumes the local DEV stack, its fixture ids and the scratchpad layout. Treat it as reference tooling, not CI.
- Recommended for integration: the driver, `MarkerBadgeGlyphImagesTests`, `session_check.py` with its tests, `run_perf.py`, `run_interleaved.sh`, `summarize_sequence.py`, and the profiling evidence.
- Optional or reference only: the frames pass, `hitches_by_phase.py`, and the password-rotation script.
