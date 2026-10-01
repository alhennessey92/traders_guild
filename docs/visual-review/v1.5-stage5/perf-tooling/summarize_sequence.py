"""Summarise one run_all.sh sequence into a comparison table.

Usage: summarize_sequence.py <run-summary.json> [...]   (run-<label>-<stamp>-requests.json files)

Per run: avatar downloads (200) and revalidations (304) per phase window, the
driver's view checks, and the medians of the measured metrics per phase
(pans pooled over test3_*/test4_*). Prints Markdown and writes the same as
JSON next to the first input (sequence-summary-<stamp>.json).
"""
import collections, json, os, statistics, subprocess, sys, datetime

PHASES = ["first-launch-and-load", "relaunch-and-load", "revisit-in-process",
          "pans-selected-thesis-anchor", "pans-selected-thesis",
          "pans-unselected-anchor", "pans-unselected", "outside-phases"]
TESTS = {"relaunch": "test1_", "revisit": "test2_", "pans-selected": "test3_", "pans-unselected": "test4_"}


def metrics(result_bundle):
    out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", "metrics", "--path", result_bundle],
                         capture_output=True, text=True).stdout
    pooled = collections.defaultdict(lambda: collections.defaultdict(list))
    for test in json.loads(out or "[]"):
        name = test["testIdentifier"].split("/")[-1]
        group = next((g for g, prefix in TESTS.items() if name.startswith(prefix)), None)
        if group is None:
            continue
        for run in test.get("testRuns", []):
            for metric in run.get("metrics", []):
                pooled[group][metric["displayName"]] += metric["measurements"]
    return {g: {m: round(statistics.median(v), 3) for m, v in ms.items()} for g, ms in pooled.items()}


def summarise(path):
    run = json.load(open(path))
    # every window the driver opened counts, with zero requests if none arrived
    phases = {w["phase"]: {"200": 0, "304": 0, "other": 0, "downloads_by_author": {}} for w in run.get("phases", [])}
    for phase, requests in run["avatar_requests_by_phase"].items():
        status = collections.Counter(r.split()[1] for r in requests)
        downloads = collections.Counter(r.split()[0] for r in requests if r.split()[1] == "200")
        phases[phase] = {"200": status.get("200", 0), "304": status.get("304", 0),
                         "other": sum(n for s, n in status.items() if s not in ("200", "304")),
                         "downloads_by_author": dict(sorted(downloads.items()))}
    checks = [c for cs in run.get("view_drift", {}).values() for c in cs]
    panned = [c for c in checks if c["view"] == "panned"]
    anchored = [c for c in checks if c["view"] == "anchored"]
    return {
        "label": run["label"], "name": run["name"], "exit": run["exit"], "launch_args": run["launch_args"],
        "phases": phases,
        "view_checks": {
            "anchored_max_shift": max((abs(c["shift_columns"]) for c in anchored), default=None),
            "anchored_max_residual": max((c["residual"] for c in anchored), default=None),
            "panned_max_shift": max((abs(c["shift_columns"]) for c in panned), default=None),
            "panned_max_residual": max((c["residual"] for c in panned), default=None),
            "panned_min_spread": min((c["spread_ratio"] for c in panned), default=None),
            "panned_off_seeded_view": sum(1 for c in panned if not c.get("on_seeded_view", True)),
            "panned_total": len(panned),
        },
        "metric_medians": metrics(run["result_bundle"]) if os.path.exists(run["result_bundle"]) else {},
        "hitches_trace": run.get("hitches_trace"),
    }


def cell(phase):
    if phase is None:
        return "–"
    text = f"{phase['200']}↓ {phase['304']}↺"
    return text + (f" {phase['other']}✗" if phase["other"] else "")


def main(paths):
    rows = [summarise(p) for p in paths]
    print("Avatar requests per window (↓ download 200, ↺ revalidation 304):\n")
    print("| run | exit | " + " | ".join(PHASES) + " |")
    print("|---|---|" + "---|" * len(PHASES))
    for r in rows:
        print(f"| {r['label']} | {r['exit']} | " + " | ".join(cell(r["phases"].get(p)) for p in PHASES) + " |")
    print("\nDownloads by author in the first-launch window:\n")
    for r in rows:
        first = r["phases"].get("first-launch-and-load")
        print(f"- {r['label']}: {first['downloads_by_author'] if first else '–'}")
    print("\nView checks and metric medians (pans pooled over 5 tests each):\n")
    print("| run | pans ending off the seeded view | panned max shift / residual / min spread | pans-selected CPU s / clock s / memory MB | pans-unselected CPU s / clock s / memory MB | relaunch CPU s / clock s |")
    print("|---|---|---|---|---|---|")
    for r in rows:
        v, m = r["view_checks"], r["metric_medians"]
        def triple(group):
            g = m.get(group, {})
            cpu = next((x for k, x in g.items() if k.startswith("CPU Time")), None)
            clock = g.get("Clock Monotonic Time")
            memory = next((x for k, x in g.items() if k.startswith("Absolute Memory Physical")), None)
            return " / ".join("–" if x is None else f"{x:.2f}" if i < 2 else f"{x / 1024:.1f}" for i, x in enumerate((cpu, clock, memory)))
        relaunch = m.get("relaunch", {})
        rcpu = next((x for k, x in relaunch.items() if k.startswith("CPU Time")), None)
        print(f"| {r['label']} | {v['panned_off_seeded_view']} of {v['panned_total']} | {v['panned_max_shift']} / {v['panned_max_residual']} / {v['panned_min_spread']} | "
              f"{triple('pans-selected')} | {triple('pans-unselected')} | "
              f"{'–' if rcpu is None else f'{rcpu:.2f}'} / {relaunch.get('Clock Monotonic Time', '–')} |")
    hitch = sorted({k for r in rows for g in r["metric_medians"].values() for k in g if "itch" in k})
    if hitch:
        print("\nHitch metrics recorded: " + ", ".join(hitch))
    else:
        print("\nNo hitch metric recorded (simulator); device runs carry an Animation Hitches trace per run.")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = os.path.join(os.path.dirname(paths[0]), f"sequence-summary-{stamp}.json")
    json.dump(rows, open(out, "w"), indent=2)
    print(f"\n(written {out})")


if __name__ == "__main__":
    main(sys.argv[1:])
