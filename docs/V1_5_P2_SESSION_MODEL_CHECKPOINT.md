# v1.5 workspace: P2 checkpoint, the workspace session model

Claude, 6 October 2026. Branch `claude/1.5.0-marker-workspace`, on top of P1 round 3 (`266a962`). Nothing has been merged into `feat/1.5.0-avatar-markers`. The owner approved moving on to P2 after the round-3 device feedback.

P2 has no visible change. It is the model the P3–P5 screens are built on, and it takes work off the main thread while authoring.

## What changed

| Before | After |
|---|---|
| Two navigation sources: `@Published guidedStep` (Details/Review/Context) and `workspace.path` (inside Context only). Opening Context from Review dropped Review from the path. | **One route stack** in the workspace session: Details at the root, with Review and every Context screen pushed on top. `guidedStep` is derived from it, so the outer shell's call sites and tests are unchanged. A screen opened from Review returns to Review, which P3's Review-section edits need. |
| Workspace navigation and editor values lived in `@Published workspace` on the draft (`MarkerPlacementState`). Every screen change and every staged value (an indicator's period, a source URL, a level price before Done) was announced to MainView, the chart and the ghost layer. | **`MarkerWorkspaceSession`** owns them. The draft holds it as a plain `let` and exposes `workspace` as a pass-through, so existing call sites read the same. Only the workspace's own views observe the session (`MarkerWorkspaceObserving`). |
| Cursor, text offset and scroll memory were also published, on every keystroke, cursor move and scroll. | They are kept in `MarkerWorkspaceMemory`, a reference box inside the state. They are read back only when a screen is rebuilt, and writing them announces nothing to anyone. |
| `isGuidedFlowActive` was `guidedStep != nil` | It is a stored, published flag, set only at flow start and end. The chart still hears that change, and it is the only workspace change it hears. |

The session has the draft's lifetime. `prepareGuidedFlow`, `prepareGuidedEdit` and `endGuidedFlow` give it a fresh state, including fresh memory. The draft model, edit preservation, submission, Setup semantics and backend contract are untouched. The experiment-off path never enters the guided flow, so it behaves exactly as before.

## Gate evidence

| Check | Result |
|---|---|
| Model tests (`MarkerWorkspaceSessionTests`, new) | Covers: navigating and staging editor values never announce a draft change, while a real draft edit still does; cursor, scroll and offset memory is announced to nobody; a screen opened from Review returns to Review; depth follows the one stack, and the same screen is never stacked twice; each draft starts with a fresh workspace; type changes and refused levels go straight back to Details. |
| Existing workspace, editing, creation, Setup guard and submission suites | All unchanged and passing (results below) |
| **Shell redraws on the real MainView sheet** (`testTheChartRedrawsOnlyForDraftEdits`, trace counter of MainView body runs) | **Navigation** (Details → Review → Back → Context → Add indicator → EMA settings → Back → Back → Done): **0**. **Scrolling** the workspace: **0**. **Typing 6 characters** in the post: **5**. The post text is draft content, and SwiftUI coalesces the announcements. |

The shell is counted rather than the chart view because the fixture has no guild, so it builds no chart. MainView owns the draft, though, so a MainView render is what rebuilds the chart on a real account. Before P2, each of those navigation steps re-rendered MainView, the chart and the ghost layer. So did every cursor move and every scroll anchor change.

**Still announced while typing: the post's own text.** It is draft state, and the Review button, the next-step prompt and the dock's progress depend on it. This is the same as the released composer. Staging the text in the session would need a flush on every exit path (Review, collapse, type change, Setup conversion, post), which is a correctness risk. It is not worth taking until the P7 same-device performance gate shows typing hitches.

## Results

| Check | Result |
|---|---|
| Focused unit suites (10, including the new session suite) | **119/119** |
| Sheet journeys, iPhone 17 Pro / iOS 26.5 | **10/10**, including the new shell-redraw journey |
| Sheet journeys, iPhone SE / iOS 18.2 | **10/10** |
| Existing workspace UI suites (large) | **48/51**, the same 3 baseline-stale failures (P3 rewrites those screens) |
| Release build; signed device build | Succeeded |

Typing-position check: after a deferred focus (at the small height), typing goes to the remembered cursor or the end. After an immediate focus (at tall), the caret goes where you tap: the left edge puts it at the start; the centre, the end or below the text put it at the end. That is native behaviour and is kept.

## Not in P2

- Category memory for the Components tabs (P5, with the restored tab layout).
- Visual changes. P3 starts the screens.
