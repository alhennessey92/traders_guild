# LinkedDev chart startup crash — 12 September 2026

The physical iPhone's DevDebug build failed during restored-session chart
construction at `TradingChartView.activeSelectedMarker`, line 706. Authentication,
guild restoration and runtime flags had succeeded.

## Diagnosis and change

The fault address `0x16b2b7ff0` was in the inaccessible stack guard region
`[0x16b2b4000, 0x16b2b8000)`. The 282-frame backtrace spanned 1,028,160 bytes.
The chart content builder alone occupied 447,600 bytes; eager nested view builders
and their large modifier values exhausted the device's main-thread stack. The
first `@Published` selected-marker read then instantiated key-path metadata at
that depth. The source line was where exhaustion surfaced, rather than evidence
of an invalid marker. Claude independently reviewed the captured trace and
confirmed the diagnosis.

`ChartBodyBoundary` stores a builder closure and defers its evaluation to a
separate SwiftUI body. One boundary separates chart content from GeometryReader;
another separates the interactive chart subtree from its parent modifier chain.
The existing modifier order, gestures, state and marker getter remain unchanged.
DevDebug remains unoptimized. No backend contract, stack-size override or
type erasure was introduced.

## Verified evidence

Captured on the same iPhone 14 Pro, using Xcode's **traders_guild LinkedDev**
scheme and a fresh process with the existing restored QA session:

| Measurement | Before | After |
| --- | ---: | ---: |
| Stack-pointer span from `activeSelectedMarker` to outermost frame | 1,000,240 bytes | 237,616 bytes |
| Entire captured backtrace span | 1,028,160 bytes (fault in metadata) | 237,616 bytes (breakpoint before getter read) |
| Captured frames | 282 | 226 |

The comparable getter span fell about 76%. These are backtrace stack-pointer
spans, not a direct `pthread_get_stacksize_np` measurement. The corrected trace
contains `ChartBodyBoundary.body` and no eagerly enclosing `chartContent` builder
frame at the getter. It meets the independent review's 512 KB target at this
measurement point. Static disassembly prologues alone do not capture the original
function's dynamic stack allocations.

- Signed physical-device DevDebug build passed (`/tmp/linked-device-debug-fix.log`).
- Integrated production-scheme Release simulator build passed on 12 September
  (`/tmp/linked-chart-boundary-release.log`, scheme **traders_guild GCP Public
  Prod**, arm64 and x86_64). This was an incremental rebuild after the earlier
  clean logo Release build, and includes source fix `6bd2b62`.
- Full unit target: **615 passed, 0 failed, 0 skipped**, independently read from
  `/tmp/linked-chart-boundary-debug-tests.xcresult`. The three new tests cover
  deferred construction, fresh body evaluation and bounded parent storage.
- Unit tests ran with **traders_guild Compose Dev**, using the existing test
  configuration. An earlier LinkedDev/DevDebug test invocation could not resolve
  the app module in the test target; that configuration issue is separate from
  the passing device application build.
- Raw diagnostic captures remain at `/tmp/linked-device-crash-frames.json`,
  `/tmp/linked-device-crash-region.txt`, `/tmp/linked-device-fixed-frames.json` and
  `/tmp/linked-stack-review.md`. Compact evidence is in `stack-evidence/`.

## Acceptance still to complete

The diagnostic breakpoint was removed and execution resumed. Xcode subsequently
lost its debug-server connection; CoreDevice's follow-up request returned a
connection reset. A complete physical cold launch and chart interaction pass
must therefore still be confirmed. Do not equate the improved breakpoint
measurement with a verified completed launch.

Rebuild using **traders_guild LinkedDev**, keep the existing QA login/data, and
check restored launch, marker selection and empty-tap deselection, timeframe
changes, panning and entering/cancelling marker placement. Optimized physical
performance comparison and manual VoiceOver remain separate release gates.

Xcode also rewrote project references and LinkedDev scheme formatting during
the debugging session. Those working-tree changes are preserved separately and
are not part of this source fix.
