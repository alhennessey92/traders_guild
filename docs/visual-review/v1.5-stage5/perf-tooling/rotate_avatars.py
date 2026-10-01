"""Cold-avatar preparation: re-upload the same five avatar images so every author gets a new,
never-fetched avatar URL. Local DEV gateway (LAN address so the iPhone can reach it); disposable accounts."""
import json, sys, time, urllib.request, uuid
creds, adir = sys.argv[1], sys.argv[2]
c = json.load(open(creds)); local = c["gateway"]; lan = "http://192.168.1.182:30080/api/v1"
assert local.startswith("http://127.0.0.1:30080/")
def login(role):
    a = c["accounts"][role]
    for _ in range(40):
        req = urllib.request.Request(local + "/auth/login", method="POST", data=json.dumps({"email": a["email"], "password": a["password"]}).encode(), headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=20) as r: b = json.loads(r.read()); return (b.get("tokens") or b)["access_token"]
        except urllib.error.HTTPError as e:
            if e.code != 429: raise
            time.sleep(15)
    raise SystemExit("login still rate-limited")
urls = {}
for role in "abcde":
    t = login(role); boundary = uuid.uuid4().hex
    png = open(f"{adir}/avatar-{role.upper()}.png", "rb").read()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"avatar-{role}.png\"\r\nContent-Type: image/png\r\n\r\n").encode() + png + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(lan + "/users/me/avatar", method="PUT", data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}", "Authorization": f"Bearer {t}"})
    with urllib.request.urlopen(req, timeout=30) as r: urls[role] = json.loads(r.read()).get("avatar_url")
print(json.dumps(urls))
