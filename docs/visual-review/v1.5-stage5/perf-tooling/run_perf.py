"""One device performance run: xcodebuild test-without-building of MarkerAvatarPerformanceDriver,
then gateway request counts for the run window. Usage: run_perf.py <label> <derived-data> <launch-args or ''>"""
import json, os, subprocess, sys, glob, datetime, re
S = "/private/tmp/claude-501/-Users-alhennessey-Desktop-traders-guild-sanctuary/aef5ca1e-57fa-46dd-9aa3-250e9c1d76d0/scratchpad"
label, dd, launch_args = sys.argv[1], sys.argv[2], sys.argv[3]
DEV = "00008120-00186CA01470201E"
MARKER = "0ab0ce3d-deca-4d49-8cc9-f8d388ae93fa"
creds = json.load(open(f"{S}/stage4/qa-creds.json"))["accounts"]["a"]
xctestrun = sorted(glob.glob(f"{dd}/Build/Products/*.xctestrun"))[-1]
rb = f"{S}/stage5/rb-perf-{label}.xcresult"
subprocess.run(["rm", "-rf", rb])
env = dict(os.environ,
           TEST_RUNNER_TG_QA_EMAIL=creds["email"], TEST_RUNNER_TG_QA_PASSWORD=creds["password"],
           TEST_RUNNER_TG_PERF_LAUNCH_ARGS=launch_args,
           TEST_RUNNER_TG_PERF_MARKER_URL=f"tradersguild-linkeddev://marker/{MARKER}")
t0 = datetime.datetime.now(datetime.timezone.utc)
with open(f"{S}/stage5/run-{label}.log", "w") as log:
    rc = subprocess.run(["xcodebuild", "test-without-building", "-xctestrun", xctestrun, "-destination", f"id={DEV}",
                         "-resultBundlePath", rb, "-only-testing:traders_guildUITests/MarkerAvatarPerformanceDriver"],
                        env=env, stdout=log, stderr=subprocess.STDOUT).returncode
t1 = datetime.datetime.now(datetime.timezone.utc)
since = int((datetime.datetime.now(datetime.timezone.utc) - t0).total_seconds()) + 5
def access(container):
    out = subprocess.run(["docker", "logs", "--since", f"{since}s", container], capture_output=True, text=True)
    rows = []
    for ln in (out.stdout + out.stderr).splitlines():
        try: j = json.loads(ln)
        except Exception: continue
        if j.get("name") != "http.access": continue
        ts = datetime.datetime.strptime(j["timestamp"], "%Y-%m-%d %H:%M:%S,%f").replace(tzinfo=datetime.timezone.utc)
        if t0 <= ts <= t1 + datetime.timedelta(seconds=1):
            rows.append((j.get("http_method"), j.get("http_path", ""), j.get("http_status")))
    return rows
core = access("traders-guild-local-core-service-1")
chart = access("traders-guild-local-chart-service-1")
avatar = [(p, st) for m, p, st in core if m == "GET" and p.startswith("/avatars/")]
marker_gets = [p for m, p, st in chart if m == "GET" and p.endswith("/markers")]
summary = {"label": label, "exit": rc, "start": t0.isoformat(), "end": t1.isoformat(),
           "avatar_requests": len(avatar), "avatar_unique_urls": len({p for p, _ in avatar}),
           "avatar_statuses": sorted({st for _, st in avatar}),
           "marker_list_gets": len(marker_gets), "core_requests": len(core), "chart_requests": len(chart)}
json.dump(summary, open(f"{S}/stage5/run-{label}-requests.json", "w"), indent=2)
print(json.dumps(summary))
