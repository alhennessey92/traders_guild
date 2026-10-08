"""One device performance invocation of MarkerAvatarPerformanceDriver.

Usage: run_perf.py <label> <derived-data> <launch-args or ''> <prepare|measure> [destination-id]

- Never deletes an earlier result: each invocation writes rb-perf-<label>-<UTC stamp>.xcresult.
- Exits non-zero if xcodebuild fails, so the sequence stops instead of reporting "done".
- Attributes local-DEV avatar requests (core-service http.access) to the driver's
  TG_PHASE windows and to authors (the avatar path carries the author's user id), and
  counts URLs requested more than once. Local gateway only; disposable QA account.
"""
import collections, datetime, glob, json, os, re, subprocess, sys
S = "/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad"
label, dd, launch_args, mode = sys.argv[1:5]
dest = sys.argv[5] if len(sys.argv) > 5 else "00008120-00186CA01470201E"
MARKER = "0ab0ce3d-deca-4d49-8cc9-f8d388ae93fa"   # seeded parent, 3 responses, 30 Sep 18:00 1h
OTHER = "0347baeb-3544-402c-a4cb-4387d61f53f6"    # seeded parent, 30 Sep 06:00 1h
AUTHORS = json.load(open(f"{S}/stage5/author-ids.json"))  # user id -> username
creds = json.load(open(f"{S}/stage4/qa-creds.json"))["accounts"][os.environ.get("TG_PERF_ACCOUNT", "a")]  # disposable local-DEV QA account
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
name = f"{label}-{stamp}"
xctestrun = max(glob.glob(f"{dd}/Build/Products/*.xctestrun"), key=os.path.getmtime)  # the latest build
rb = f"{S}/stage5/rb-perf-{name}.xcresult"
tests = ["test0_signInIfNeeded", "test5_parkOnMarkerFreeTimeframe"] if mode == "prepare" else None
# Measure runs skip the sign-in check: test1's launch must be the first after any avatar rotation.
only = [f"-only-testing:traders_guildUITests/MarkerAvatarPerformanceDriver/{t}" for t in tests] if tests \
    else ["-only-testing:traders_guildUITests/MarkerAvatarPerformanceDriver",
          "-skip-testing:traders_guildUITests/MarkerAvatarPerformanceDriver/test0_signInIfNeeded"]
env = dict(os.environ,
           # Only the username: the driver never types credentials (sign in by hand).
           TEST_RUNNER_TG_QA_USERNAME=creds["username"],
           TEST_RUNNER_TG_PERF_LAUNCH_ARGS=launch_args,
           TEST_RUNNER_TG_PERF_MARKER_URL=f"tradersguild-linkeddev://marker/{MARKER}",
           TEST_RUNNER_TG_PERF_OTHER_URL=f"tradersguild-linkeddev://marker/{OTHER}")
logpath = f"{S}/stage5/run-{name}.log"
SIMULATOR = "9B8DAACB-DB63-4F23-A75B-3BC6C52E5705"
# Frame behaviour fallback for physical devices: a system-wide Animation Hitches trace for the
# whole invocation (survives the app relaunches a run makes), stopped with SIGINT so it finalises.
trace = None
if mode == "measure" and dest != SIMULATOR:
    trace_path = f"{S}/stage5/trace-{name}.trace"
    trace = subprocess.Popen(["xcrun", "xctrace", "record", "--device", dest, "--template", "Animation Hitches",
                              "--all-processes", "--time-limit", "900s", "--output", trace_path],
                             stdout=open(f"{S}/stage5/trace-{name}.log", "w"), stderr=subprocess.STDOUT)
    import time; time.sleep(8)  # let recording start before the run
t0 = datetime.datetime.now(datetime.timezone.utc)
with open(logpath, "w") as log:
    rc = subprocess.run(["xcodebuild", "test-without-building", "-xctestrun", xctestrun, "-destination", f"id={dest}",
                         "-resultBundlePath", rb] + only, env=env, stdout=log, stderr=subprocess.STDOUT).returncode
t1 = datetime.datetime.now(datetime.timezone.utc)
if trace is not None:
    import signal
    trace.send_signal(signal.SIGINT)
    try: trace.wait(timeout=180)
    except subprocess.TimeoutExpired: trace.kill()

def parse_ts(s): return datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
phases, opened, drift = [], {}, {}
for ln in open(logpath, errors="replace"):
    d = re.search(r"TG_DRIFT (\S+) iteration=(\d+) (anchored|panned) shift=(-?\d+) residual=([0-9.]+|inf) spread=([0-9.]+) seeded=(true|false)", ln)
    if d: drift.setdefault(d.group(1), []).append({"iteration": int(d.group(2)), "view": d.group(3), "shift_columns": int(d.group(4)),
                                                  "residual": float(d.group(5)), "spread_ratio": float(d.group(6)),
                                                  "on_seeded_view": d.group(7) == "true"})
    m = re.search(r"TG_PHASE (begin|end) (\S+) (\S+)", ln)
    if not m: continue
    edge, ph, ts = m.group(1), m.group(2), parse_ts(m.group(3))
    if edge == "begin": opened[ph] = ts
    elif ph in opened: phases.append((ph, opened.pop(ph), ts))

since = int((datetime.datetime.now(datetime.timezone.utc) - t0).total_seconds()) + 5
out = subprocess.run(["docker", "logs", "--since", f"{since}s", "traders-guild-local-core-service-1"], capture_output=True, text=True)
reqs = []
for ln in (out.stdout + out.stderr).splitlines():
    try: j = json.loads(ln)
    except Exception: continue
    if j.get("name") != "http.access" or j.get("http_method") != "GET": continue
    path = j.get("http_path", "")
    if not path.startswith("/avatars/"): continue
    ts = datetime.datetime.strptime(j["timestamp"], "%Y-%m-%d %H:%M:%S,%f").replace(tzinfo=datetime.timezone.utc)
    if t0 <= ts <= t1 + datetime.timedelta(seconds=1):
        reqs.append((ts, path, j.get("http_status")))
slack = datetime.timedelta(milliseconds=750)
def phase_of(ts):
    for ph, b, e in phases:
        if b - slack <= ts <= e + slack: return ph
    return "outside-phases"
per_phase = collections.defaultdict(list)
for ts, path, st in reqs:
    author = AUTHORS.get(path.split("/")[2], "other")
    per_phase[phase_of(ts)].append({"author": author, "path": path, "status": st, "ts": ts.isoformat()})
repeats = {p: n for p, n in collections.Counter(p for _, p, _ in reqs).items() if n > 1}
metrics = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "metrics", "--path", rb], capture_output=True, text=True).stdout
open(f"{S}/stage5/metrics-{name}.json", "w").write(metrics)
summary = {"label": label, "name": name, "mode": mode, "launch_args": launch_args, "exit": rc,
           "xctestrun": xctestrun, "destination": dest,
           "hitches_trace": f"{S}/stage5/trace-{name}.trace" if trace is not None else None,
           "start": t0.isoformat(), "end": t1.isoformat(), "result_bundle": rb,
           "phases": [{"phase": p, "begin": b.isoformat(), "end": e.isoformat()} for p, b, e in phases],
           # per pan test, the anchored and the panned view vs the first anchored view: sideways
           # shift (of 64 columns), grey-level residual, spread ratio. Seeded = within 20 columns,
           # residual < 10, spread >= 0.6. An anchored view off it fails the run; a panned one is
           # reported only (a fling that overshot).
           "view_drift": drift,
           "avatar_requests_total": len(reqs),
           "avatar_requests_by_phase": {p: [f"{x['author']} {x['status']}" for x in v] for p, v in per_phase.items()},
           "avatar_urls_requested_more_than_once": repeats}
json.dump(summary, open(f"{S}/stage5/run-{name}-requests.json", "w"), indent=2)
print(json.dumps({k: summary[k] for k in ("name", "exit", "view_drift", "avatar_requests_total", "avatar_requests_by_phase", "avatar_urls_requested_more_than_once")}))
sys.exit(0 if rc == 0 else 1)
