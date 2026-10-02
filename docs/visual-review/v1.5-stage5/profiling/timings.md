# Matched pan timings (simulator iPhone 17 Pro, iOS 26.5; instrumented DevProfile build)

Per-second NSLog counters around each Canvas draw closure plus process CPU (CLOCK_PROCESS_CPUTIME_ID),
over the measured pan window of `test3_pansWithSelectedThesis_1` / `test4_pansUnselected_1`, runs alternated.

## Attribution (before the fix, selected pan)
| run | redraws/10 s | candle canvas ms/frame | marker canvas ms/frame | process CPU ms/s |
|---|---|---|---|---|
| experiment off | 423 | 0.31 | 1.58 | 604 |
| experiment on | 399 | 0.32 | 2.45 | 670 |
| on, face draw skipped | 406 | 0.32 | 2.51 | 658 |
| on, circle clip skipped | 397 | 0.32 | 2.60 | 657 |
| **on, intent badge skipped** | 403 | 0.32 | **1.56** | **615** |
| experiment off (repeat) | 430 | 0.31 | 1.41 | 594 |
| experiment on (repeat) | 389 | 0.32 | 2.40 | 677 |

Redraw frequency (bodies/draws per second) is the same in both builds, idle (9–12/s) and panning (50–56/s).

## After the fix (5f9ee89)
| run | marker canvas ms/frame | process CPU ms/s |
|---|---|---|
| selected, on | 1.63 / 1.73 | 593 / 574 |
| selected, off | 1.48 / 1.47 | 576 / 604 |
| unselected, on | 1.74 / 1.63 | 564 / 597 |
| unselected, off | 1.42 / 1.47 | 550 / 553 |
