# Slice 1 bounded correction evidence

2026-10-04. All captures are the real isolated DEV app on dedicated simulators, using backend-free fixtures. No signed-in chart, actual backend acceptance, physical phone or SharePrompt UI is shown.

- `iphone17pro-ios26/`: final affected test run. `real-shell-fixture-*` renders actual ChartBottomSheet/Add/tab controls; `native-fixture-*` renders production guided panel/dock/bar and in-memory submission.
- `iphonese-ios18/`: small-screen real shell, Analysis journey and empty-title/scroll retention. The settled Review supplement launches `analysisReview` separately; it confirms all bar actions after animation.
- `capture-index.json` maps each unedited full-resolution screenshot to its test (or explicitly labelled manual fixture capture).
- `final-summary.json`: 28 test functions, 30 executions, all passed.
- `small-summary.json`: 4 UI tests, all passed.
- `initial-correction-summary.json`: 31 functions, 33 executions, all passed; includes Setup and edit checks before the last container-probe/root-handler correction.

Authoritative implementation notes, commands and review gate: `docs/V1_5_SHEET_SLICE1_CHECKPOINT.md`. Older evidence outside `corrections/` predates bounded content-fit and is historical.
