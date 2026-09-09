# Linked markers — fixture visual review

Captured from the DEBUG-only harness (`-MarkerLinkFixtures`), which drives the
real `ChartMarkerSystem.drawMarkers` and the real linked-detail views against
synthetic markers laid out by the real `MarkerPositionCalculator`. No backend,
no account, no network.

**This is fixture verification, not backend E2E.** It covers layout, colour,
contrast, type and reflow. It does not cover a real create→notify→realtime round
trip, server-authored node keys, live cursor pagination, or block enforcement.

| File | Condition | What it shows |
|---|---|---|
| `01-parent-unrelated-response-dark.png` | iPhone 16 Pro, mid-grey | The case the design turns on: parent, an unrelated marker, and a response stacked on one candle. The green `supports` connector routes **around** the faded stranger; the grey stack spine below stays untinted |
| `02-all-three-relationships-dark.png` | iPhone 16 Pro, mid-grey | Supports / challenges / builds-on distinguishable by colour, ring and dash pattern |
| `03-dense-chart-dark.png` | iPhone 16 Pro, mid-grey | 19 markers, an 8-response thesis. Rings stay separated after the inset fix; stacked connectors compress into a bundle, which is inherent to same-candle stacking |
| `04-parent-unrelated-response-lightgrey.png` | iPhone 16 Pro, light-grey | Rings and connectors clearly visible. **Also the open finding:** unrelated markers at the contract's 0.22 are close to invisible here, and a faded like badge reads as a colour smudge |
| `05-dynamic-type-accessibility-xl.png` | accessibility-extra-large | Thesis rows reflow to a column; chips scale; tombstone keeps structure and relationship with no identity; the count reads "4+" — tombstone excluded, "+" retained |
| `06-iphone-se-reduce-motion.png` | iPhone SE (3rd gen), Reduce Motion on | Layout holds at 375pt; the connector is at full length on first paint rather than animating in |

## Honest limits on these images

- **Reduce Motion**: `simctl` cannot toggle it, so it was set through the
  accessibility defaults. A still frame cannot prove the *absence* of an
  animation; the behavioural guarantee is carried by
  `MarkerLinkRenderTests.reduceMotionSnapsInsteadOfHidingFocus`.
- **VoiceOver was not driven.** Labels, traits and hints are set on every linked
  view and relationship is always spoken rather than carried by colour, but the
  rotor was not stepped. Chart glyphs remain Canvas pixels with no accessibility
  elements — unchanged from 1.2.1 — which is why the thesis list is the
  accessible path and must stay reachable without entering focus mode.
- **No physical device and no Instruments run.** These are simulator captures.


## Live backend E2E (2026-09-09)

Driven against the local DEV gateway with the QA accounts. These are the real
feature, real data — not fixtures.

| File | What it shows |
|---|---|
| `07-live-backend-thesis-badges.png` | The QA thesis on 1H. Response-count badges on the left of each glyph carry real `direct_response_count` values; the root's "5" matched the API exactly |
| `08-live-backend-focus.png` | Focus against live data: teal root ring on the selected marker, green `supports` ring above it, coloured dashed connectors routing left around the stack, unrelated markers dimmed |

Verified in the same run, at API level:

- create returns `parent_direct_response_count` and `parent_responses_revision`
  **top-level**, advancing 3 → 4 → 5;
- delete returns all six added fields beside the original `detail`, decrementing
  4 → 3 → 2;
- after teardown the thread reports `nodes=7, total_count=3` — four tombstones
  excluded from the total, which is exactly what `activeLoadedCount` computes.

Still not covered here: real opaque cursor pagination. Even with five responses
the QA thesis fits in one window, so the server issued no branch cursors and the
provenance path could not be exercised end to end. It is covered by unit tests.
