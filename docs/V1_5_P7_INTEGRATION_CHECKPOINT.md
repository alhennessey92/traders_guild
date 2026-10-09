# v1.5 workspace: P7 integration and performance

Branch `claude/1.5.0-marker-workspace`. P6 was accepted by the owner on 8 October (device): the Add surface, framing, accessibility pass, drawing editor, edited-marker prominence (`4ee8359`), chart-first support/resistance (`4ee8359`) and level lines stopping before their price chip (`d6bee1e`). VoiceOver and Reduce Motion were not separately walked through on device; the owner chose to proceed.

## Owner decisions (8 October)

- Restore the local chart-service's code in place (no restart).
- Signed-in journeys: the owner tests by hand, and Claude also runs the opt-in integration test from the protected QA file.
- Same-device performance comparison: yes, when the owner is ready. Run on 9 October.

## Local stack

- **Found:** the chart-service bind-mounts its code from a temporary export of backend `5061824`, under another session's scratchpad. That export had been emptied (0 files). The service kept working only because Python had already loaded its modules; any restart would have failed to start it. The other services mount the stable `linked-markers-backend` worktree.
- **Repaired in place**, without a restart: `git archive 5061824 shared services/chart-service/app` back into the mounted folder. That is 151 shared files and 11 chart-service files, matching git. All 150 Python files compile inside the container, the schema has the text-only Analysis rule (`780398f`, an ancestor of `5061824`), and health stayed 200 throughout.
- **Made durable (9 October, owner: "do whatever you think is best").**
  - The stack's third compose file (`stage4/compose.stage4-5061824.yml`) had been cleaned away too.
  - Rebuilt as `~/TradersGuildLocal/backend-5061824/compose.chart-5061824.yml`. It mounts that folder's `git archive 5061824` copy and sets `LINKED_MARKERS_ENABLED=true`, which the lost override had set.
  - The rendered config was compared with the running container before anything changed, printing names only: environment identical, same mount targets, and only the mount sources differ.
  - Only the chart-service was recreated (`up -d --no-deps --no-build chart-service`, with `--env-file .env.local` and the base and safe files from `linked-markers-backend`). It was healthy after about 4 s. The Discord flags are still off, the text-only Analysis rule is present, there are no errors, and the other services were untouched (still up 9 days).
  - Recreate the chart-service the same way in future.

## Outbound-safety preflight

Checked on the running containers, printing only whether each setting is set, never its value:
- Discord webhooks, auto-post and result postback are off.
- FCM is off, APNs has no key, and Resend has no key.
- Digests and awards are off.
- TimescaleDB and Redis listen only on 127.0.0.1.

## Integration test (local backend, signed in)

`MarkerLocalWorkspaceIntegrationTests` was run against the running stack. It received only the protected file's path, and the file is mode 600.

**Result: PASS (run `phaseb-7e01c039`, 7 markers created in the QA guild):**
- A text-only Analysis is created and edited.
- A Question is created and edited.
- **Tracked Setup:** refused by the backend because an open tracked Setup exists there. It retried untracked with the draft preserved, saved geometry was unchanged by the edit, and Entry stayed at 50,000.
- **Locks:** existing tracked Setups were inspected read-only and are locked (`EXPIRED`).
- **Context:** two supports, RSI 19, a source and a horizontal line, plus a level edit. Server normalisation of unknown keys is as recorded in Phase B.
- **Responses:** Supports, Challenges and Builds On, each posted on 4h with a timeframe link, including a Setup conversion and back.
- **Failure and retry:** an authorization failure kept the draft, and the retry saved.

**Credential hygiene:**
- After the run, the log was scanned for every credential value in the file. One hit: the account's **email** (not a password, not a token) was printed by the DEBUG API response logger in the `/me` body.
- It was masked in the log and the result bundle was deleted.
- **Fixed** in `cae9329`: the DEBUG redactor now also masks keys ending in "email", with a test.
- No tokens or passwords appeared.

## Performance comparison (owner's iPhone 14 Pro, 9 October): no regression

- **What ran:** the perf driver hardening from `claude/1.5.0-avatar-markers` (`847449c`: the final state of its 9 test commits, which never types credentials), plus one fix made here (`8d409b5`, described under "What it took").
- **Builds:**
  - base: canonical `128ead3`, in a temporary worktree with the identical driver file;
  - proto: this branch.
  - Both are optimized DevProfile with the experiment on.
- **Account:** signed in by hand as QA account `a` (`stage4658f08a`).
- **Sequence:** prepare, then base, proto, base, proto. All runs were warm, with no avatar rotation, no trace and no stack changes. All 5 runs passed.

Medians per measured pan, pooled over 5 tests per state (CPU is the app process):

| | base run 1 | proto run 1 | base run 2 | proto run 2 |
|---|---|---|---|---|
| Pan with the thesis selected: CPU s | 3.85 | 3.63 | 3.44 | 3.54 |
| Pan with nothing selected: CPU s | 3.73 | 3.65 | 3.49 | 3.45 |
| Revisit in process: CPU s | 3.60 | 2.58 | 2.89 | 2.80 |
| Pan clock s (fixed gesture) | 8.64 / 8.81 | 8.64 / 8.73 | 8.64 / 8.81 | 8.74 / 8.64 |
| Pans ending off the seeded view | 0 of 10 | 0 of 10 | 0 of 10 | 0 of 10 |
| Avatar requests | 4 revalidations at launch, none after | same | same | same |

**Reading:**
- The workspace branch is level with base on every viewing path: selected and unselected pans, revisits, and launch avatar traffic. Its averages are marginally lower (selected pans 3.59 vs 3.65 s, unselected 3.55 vs 3.61 s, revisit 2.69 vs 3.24 s). The base-to-base spread (3.85 vs 3.44) is larger than any base-to-proto difference, so treat these as equal within noise rather than as an improvement.
- **Not measured here:**
  - Frame hitches: the device trace is off; see below.
  - The authoring sheet itself. Its performance was checked in P2 with render counters, which showed the chart is not invalidated while typing or scrolling.

**What it took** (tooling, not app, problems):
1. **Selected-pan checks failing on the base build.** The chart refits its price range on the first pan and keeps it through re-anchoring, so the driver's first reference view never matched again. Fix: one unmeasured settling pan before each reference (`8d409b5`, test-only, in both builds).
2. **The phone running out of storage.** The system-wide Animation Hitches trace reached 26 GB on the Mac for one run, and unfinalised traces were left on the phone. Fix: the trace is off by default (`TG_PERF_TRACE=1` opts in). The owner restarted the phone, which cleared the stranded data.
3. **"Timed out while enabling automation mode" after the restart.** The owner re-confirmed Settings ▸ Developer ▸ Enable UI Automation.

Evidence (this session's scratchpad `perf/`):
- per-run `run-p7c-*-requests.json`, `metrics-p7c-*.json` and `rb-perf-p7c-*.xcresult`;
- `sequence-summary-20261009T203330Z.json`.

## Owner hand pass (signed in to a local QA account on the phone)

1. Post a plain-text Analysis, see it on the chart, then edit it.
2. Post a Question (at least 10 characters).
3. Post a Setup tracked, on a symbol and timeframe with no open tracked Setup, and one untracked.
4. Add context (an indicator, a support line dragged on the chart, a timeframe), post it, then reopen it and check the chips and arcs.
5. Respond to a marker as Supports, Challenges and Builds On. Change the response timeframe, and turn a response into a Setup and back.
6. Failure and retry: with Airplane Mode on, post and confirm the error keeps the draft. Turn it off and Retry.
7. Collapse and resume with the keyboard up. Then open a shared marker link.
8. Optional realtime check: sign in as a *different* QA account (own markers are filtered from the socket) on BTC/USD 1w, and Claude posts from account `a`.
