"""Stage 5 local-DEV performance fixture: a dense, deterministic BTC/USD 1h chart in the
disposable Stage 4 QA guild. Local gateway only; disposable accounts; additive."""
import json, sys, urllib.request, datetime
CREDS, OUT = sys.argv[1], sys.argv[2]
c = json.load(open(CREDS)); base = c["gateway"]; assert base.startswith("http://127.0.0.1:30080/")
def call(method, path, body=None, token=None):
    req = urllib.request.Request(base + path, method=method, data=json.dumps(body).encode() if body is not None else None,
        headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})})
    try:
        with urllib.request.urlopen(req, timeout=20) as r: return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")
def token(role):
    a = c["accounts"][role]; s, b = call("POST", "/auth/login", {"email": a["email"], "password": a["password"]}); return (b.get("tokens") or b)["access_token"]
tok = {r: token(r) for r in "abcde"}
s, cs = call("GET", f"/chart/symbols/{c['symbol_id']}/candles?timeframe=1h&limit=60", None, tok["a"])
candles = cs if isinstance(cs, list) else (cs.get("candles") or cs.get("items") or [])
assert s == 200 and candles, (s, str(cs)[:200])
candles = sorted(candles, key=lambda x: x["timestamp"])
print("candles", len(candles), candles[0]["timestamp"], "->", candles[-1]["timestamp"])
# Leave the newest 2 candles free; use the 40 before them.
pool = candles[-42:-2]
mk = f"/chart/guilds/{c['guild_id']}/markers"
def anchor(cd): return {"component_type": "anchor", "payload": {"time": cd["timestamp"], "price": float(cd["close"])}, "ordering": 0}
created = []
def make(role, cd, intent, note, extra=None, link=None):
    body = {"symbol_id": c["symbol_id"], "timeframe": "1h", "intent": intent, "visibility": "guild", "note": note,
            "tracking_enabled": False, "components": [anchor(cd)] + (extra or [])}
    if link: body.update(parent_marker_id=link[0], link_relationship=link[1])
    s, m = call("POST", mk, body, tok[role])
    created.append({"status": s, "id": m.get("id"), "role": role, "intent": intent, "t": cd["timestamp"], "link": link[1] if link else None})
    return m.get("id")
def setup_levels(cd, long):
    p = float(cd["close"]); d = p * 0.006
    tp, sl = (p + 2 * d, p - d) if long else (p - 2 * d, p + d)
    return [{"component_type": "level.entry", "payload": {"price": p, "label": "Entry"}, "ordering": 1},
            {"component_type": "level.sl", "payload": {"price": sl, "label": "SL"}, "ordering": 2},
            {"component_type": "level.tp", "payload": {"price": tp, "label": "TP"}, "ordering": 3}]
roles = "abcde"
intents = ["analysis", "question", "setup"]
parents = []
for i, cd in enumerate(pool):
    role = roles[i % 5]; intent = intents[i % 3]
    if intent == "analysis":
        mid = make(role, cd, "analysis", f"Perf {i}: structure note from {role.upper()}")
    elif intent == "question":
        mid = make(role, cd, "question", f"Perf {i}: does this level hold for {role.upper()}?")
    else:
        mid = make(role, cd, "setup", f"Perf {i}: untracked idea", setup_levels(cd, long=(i % 2 == 0)))
    if i in (6, 18, 30): parents.append((mid, cd))
    # same-candle stacks every 7th candle
    if i % 7 == 3:
        make(roles[(i + 1) % 5], cd, "analysis", f"Perf {i}b: stacked view")
        make(roles[(i + 2) % 5], cd, "question", f"Perf {i}c: stacked question here?")
# linked responses: three per parent, all relationships, by other authors
rels = ["supports", "challenges", "builds_on"]
for k, (pid, pcd) in enumerate(parents):
    idx = pool.index(pcd)
    for j, rel in enumerate(rels):
        cd = pool[min(idx + j + 1, len(pool) - 1)]
        make(roles[(k + j + 1) % 5], cd, "analysis", f"Perf response {k}.{j}: {rel}", link=(pid, rel))
ok = sum(1 for x in created if x["status"] in (200, 201))
print("created", ok, "of", len(created), "| failures:", [x for x in created if x["status"] not in (200, 201)][:3])
json.dump(created, open(OUT, "w"), indent=2)
