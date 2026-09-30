"""Stage 4 guard correction: real local-DEV API checks (local gateway only, disposable QA accounts)."""
import json, sys, urllib.request, datetime
CREDS = sys.argv[1]; OUT = sys.argv[2]
c = json.load(open(CREDS)); base = c["gateway"]; assert base.startswith("http://127.0.0.1:30080/")
def call(method, path, body=None, token=None):
    req = urllib.request.Request(base + path, method=method, data=json.dumps(body).encode() if body is not None else None,
        headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})})
    try:
        with urllib.request.urlopen(req, timeout=20) as r: return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")
def token(role):
    a = c["accounts"][role]; s, b = call("POST", "/auth/login", {"email": a["email"], "password": a["password"]}); return (b.get("tokens") or b)["access_token"]
tok = {r: token(r) for r in ("a", "b")}
g, sym = c["guild_id"], c["symbol_id"]
now = datetime.datetime.now(datetime.timezone.utc).replace(second=0, microsecond=0).isoformat()
def setup(entry, sl, tp, tf, tracked=True, note="guard check", parent=None, rel=None):
    body = {"symbol_id": sym, "timeframe": tf, "intent": "setup", "visibility": "guild", "note": note, "tracking_enabled": tracked,
            "components": [{"component_type": "anchor", "payload": {"time": now, "price": entry}, "ordering": 0},
                           {"component_type": "level.entry", "payload": {"price": entry, "label": "Entry"}, "ordering": 1},
                           {"component_type": "level.sl", "payload": {"price": sl, "label": "SL"}, "ordering": 2},
                           {"component_type": "level.tp", "payload": {"price": tp, "label": "TP"}, "ordering": 3}]}
    if parent: body.update(parent_marker_id=parent, link_relationship=rel)
    return body
def detail(b):
    d = b.get("detail") if isinstance(b, dict) else b
    if isinstance(d, list): return [{k: x.get(k) for k in ("loc", "msg")} for x in d]
    return d
results = []
def record(name, status, body, expect):
    ok = status in expect
    results.append({"check": name, "status": status, "expected": sorted(expect), "pass": ok,
                    "id": body.get("id") if isinstance(body, dict) else None, "detail": None if status < 300 else detail(body)})
    print(f"{'PASS' if ok else 'FAIL'} {name}: {status} {results[-1]['id'] or results[-1]['detail']}")
    return body
mk = f"/chart/guilds/{g}/markers"
# 1. The original retry request, replayed exactly (tracked short, both exits below Entry, linked 15m challenge).
record("invalid tracked create: original retry levels (linked, 15m)", *call("POST", mk, setup(83920.01, 83840.98, 83393.81, "15m", parent=c["parent_b"], rel="challenges", note="guard: original retry levels"), tok["a"]), {400, 422})
# 2. Invalid tracked long-shaped (TP above, SL above Entry), unlinked.
record("invalid tracked create: SL and TP both above Entry (30m)", *call("POST", mk, setup(50000, 50100, 50300, "30m"), tok["b"]), {400, 422})
# 3. Valid tracked long and short, far from market so they stay ARMED.
long_ = record("valid tracked long (1h)", *call("POST", mk, setup(50000, 49800, 50400, "1h", note="guard: valid long"), tok["b"]), {200, 201})
short = record("valid tracked short (4h)", *call("POST", mk, setup(50000, 50200, 49600, "4h", note="guard: valid short"), tok["b"]), {200, 201})
# 4. Untracked with same-side levels: untracked behaviour unchanged.
untracked = record("untracked same-side levels still accepted (1d)", *call("POST", mk, setup(50000, 50100, 50300, "1d", tracked=False, note="guard: untracked same-side"), tok["b"]), {200, 201})
# 5. Effective update: turning tracking on for the untracked same-side record.
record("effective update: enable tracking on same-side untracked", *call("PUT", f"{mk}/{untracked.get('id')}", {"tracking_enabled": True}, tok["b"]), {400, 422})
# 6. Effective update: moving the valid long's SL above Entry (components replaced while ARMED).
if long_.get("id"):
    bad = setup(50000, 50100, 50400, "1h")["components"]
    record("effective update: valid long -> SL above Entry", *call("PUT", f"{mk}/{long_['id']}", {"components": bad}, tok["b"]), {400, 422})
    record("valid update: note-only edit on valid long", *call("PUT", f"{mk}/{long_['id']}", {"note": "guard: valid long (note edited)"}, tok["b"]), {200})
# 7. Analysis regression: text-only create + note-only update.
an = record("text-only Analysis create (regression)", *call("POST", mk, {"symbol_id": sym, "timeframe": "5m", "intent": "analysis", "visibility": "guild", "note": "guard: text-only analysis regression",
          "components": [{"component_type": "anchor", "payload": {"time": now, "price": 84000}, "ordering": 0}]}, tok["b"]), {200, 201})
if an.get("id"):
    record("text-only Analysis update (regression)", *call("PUT", f"{mk}/{an['id']}", {"note": "guard: text-only analysis regression (edited)"}, tok["b"]), {200})
json.dump(results, open(OUT, "w"), indent=2)
