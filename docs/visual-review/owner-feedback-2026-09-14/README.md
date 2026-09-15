# Owner feedback — 14 September 2026

Implementation: connector commit `9f6f108` (Claude source `1d53330`) and response-flow commit `e2802fb`.

- All safely routable edges of the loaded selected thesis now draw, including grandchildren. Dedicated cubic curves recover opposite-stack paths; own endpoint badges are soft obstacles, with a clear side preferred. Other glyphs and badges still block routes.
- Chart Settings has persisted Line Thickness (1–3 pt) and Curvature (60–160%), defaulting to 1.5 pt / 100%. The card follows the runtime capability.
- Respond with marker defers entry until the scrollable relationship picker dismisses. Drafts expose Response timeframe and preserve link/content through awaited context loading. Request identity and account/guild/symbol/timeframe guards reject stale completions. Creation is prevented while loading or after failure; retry retains the draft.
- The original draft timestamp survives interval changes; submission alone normalizes the anchor to its containing candle, preserving price. Failure/cancellation releases the chart loading state.

## Verification

The committed source passes **641 unit tests, zero failures or skips**. `test-summary.json` was extracted independently from `/tmp/linked-feedback-final-tests.xcresult`. A preliminary 621-test run had one known notification timing failure; both integrated runs (640 and 641 tests) passed it without changing that test or notification implementation.

Final **LinkedDev DevDebug** and **production Release** simulator builds both passed (`/tmp/linked-feedback-final-debug.log`, `/tmp/linked-feedback-final-release.log`). Artifact metadata is retained in `build-artifacts.json`. Claude completed all five response-flow UI checks, including real failed-load/retry and a server-verified Builds on response on 4h. See `claude-response-and-jumps.md`. Connector simulator evidence is retained here with Claude’s detailed report. No physical-device performance claim is made.

## Remaining limitations

An edge with no safe route can still be omitted. Offscreen/unloaded nodes use thread navigation. A reconnect refresh can supersede a response-timeframe load and produce a conservative retry message; the draft is retained. Physical iPhone frame-rate comparison, manual VoiceOver acceptance, and production rollout gates remain open.

## 15 September follow-up

Integrated Claude navigation fallback (`d3df7ba`, source `6b96343`) and circular cross-timeframe jump badges (`0c168f2`, source `3a1253a`), wired through `bbce60e`. All review-copy response sources match Claude’s tested tree. **656 unit tests passed, zero failures/skips** after integration; see `cross-timeframe-test-summary.json`. Claude verified 30m → 1h → 30m badge navigation in the simulator. The earlier production Release build predates these two follow-up features and must be repeated before release.

The response badge selects the newest accessible direct response on another timeframe in the loaded thread window; the thread list provides other branches. Badges are not a claim that an incomplete thread window contains every response. Small pending polish: duplicate punctuation in failed-load copy, and alert Place colour can remain vivid despite correctly blocked submission after load failure.

Local DEV ingestion health returned 503 (`ingestion_component_stopped:candle_ingestor:stopped`) on 15 September. Restarted only the local ingestion container; health recovered to OK. Read-only PostgreSQL verification found 58 1m candles from the last hour, 56 distinct closes, newest 2026-09-15T05:23Z. Existing data was retained. This confirms fresh persistence, not complete repair of older history gaps.

Production deployment has not occurred. Saved GKE access timed out again; live images, database migration head and recoverable backup are unverified. The capability is global. Plan the first rollout with linking disabled, then verify released-client behavior on the deployed version before enablement. Use DEV’s recovered current candles for continued testing.
