# v1.5 workspace: P7 integration and performance

Branch `claude/1.5.0-marker-workspace`. P6 was accepted by the owner on 8 October (device): the Add surface, framing, accessibility pass, drawing editor, edited-marker prominence (`4ee8359`), chart-first support/resistance (`4ee8359`) and level lines stopping before their price chip (`d6bee1e`). VoiceOver and Reduce Motion were not separately walked through on device; the owner chose to proceed.

## Owner decisions (8 October)

- Restore the local chart-service's code in place (no restart).
- Signed-in journeys: the owner tests by hand, and Claude also runs the opt-in integration test from the protected QA file.
- Same-device performance comparison: yes, when the owner is ready.

## Local stack

- **Found:** the chart-service bind-mounts its code from a temporary export of backend `5061824`, under another session's scratchpad. That export had been emptied (0 files). The service kept working only because Python had already loaded its modules; any restart would have failed to start it. The other services mount the stable `linked-markers-backend` worktree.
- **Repaired in place**, without a restart: `git archive 5061824 shared services/chart-service/app` back into the mounted folder. That is 151 shared files and 11 chart-service files, matching git. All 150 Python files compile inside the container, the schema has the text-only Analysis rule (`780398f`, an ancestor of `5061824`), and health stayed 200 throughout.
- **Still fragile:** the folder is still under `/private/tmp`, so it could be cleaned again. A durable fix is to point the chart-service at a stable checkout, which takes one container recreate. That is the owner's decision.

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

## Performance comparison (prepared, waiting for the owner)

- The perf driver hardening from `claude/1.5.0-avatar-markers` is in (`847449c`). It is the final state of the 9 test commits, and the driver never types credentials. The Stage 5 session docs and the QA password-rotation script were left on their branch.
- **Builds:**
  - base: canonical `128ead3`, in a temporary worktree carrying the identical driver file;
  - proto: this branch.
  - Both are optimized DevProfile, built for the owner's iPhone, with the experiment on.
- **Sequence:** prepare, then base, proto, base, proto. Runs are warm only and interleaved to even out thermal drift. There is no avatar rotation, so no local data changes.
- **Inputs:**
  - the seeded thesis markers `0ab0ce3d…` and `0347baeb…`, which are still in the QA guild;
  - slot `a` of the protected file, which is a member of that guild.
- **Owner steps:** sign in as QA account `a` on the phone by hand, unlock it, and keep it on the cable. Each measured run takes about 15 minutes.

## Owner hand pass (signed in to a local QA account on the phone)

1. Post a plain-text Analysis, see it on the chart, then edit it.
2. Post a Question (at least 10 characters).
3. Post a Setup tracked, on a symbol and timeframe with no open tracked Setup, and one untracked.
4. Add context (an indicator, a support line dragged on the chart, a timeframe), post it, then reopen it and check the chips and arcs.
5. Respond to a marker as Supports, Challenges and Builds On. Change the response timeframe, and turn a response into a Setup and back.
6. Failure and retry: with Airplane Mode on, post and confirm the error keeps the draft. Turn it off and Retry.
7. Collapse and resume with the keyboard up. Then open a shared marker link.
8. Optional realtime check: sign in as a *different* QA account (own markers are filtered from the socket) on BTC/USD 1w, and Claude posts from account `a`.
