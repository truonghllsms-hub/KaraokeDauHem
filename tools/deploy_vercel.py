#!/usr/bin/env python3
"""Tải bản web (build/web) lên Vercel qua REST API.
Dùng: python3 tools/deploy_vercel.py [tên_dự_án]
Token: đặt biến VERCEL_TOKEN, hoặc để trống nếu proxy của môi trường tự chèn."""
import hashlib, json, os, sys, urllib.request, urllib.error
from pathlib import Path

API = "https://api.vercel.com"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
NAME = sys.argv[1] if len(sys.argv) > 1 else "karaoke-dau-hem"
TOKEN = os.environ.get("VERCEL_TOKEN", "proxy-injected")


def call(method, path, data=None, headers=None):
    h = {"Authorization": "Bearer " + TOKEN}
    h.update(headers or {})
    if isinstance(data, (dict, list)):
        data = json.dumps(data).encode()
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(API + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        sys.exit("Lỗi %s %s: %s" % (e.code, path, e.read().decode()[:400]))


team = call("GET", "/v2/user")["user"].get("defaultTeamId")
q = "?teamId=" + team if team else ""
files = []
for path in sorted(Path(ROOT).rglob("*")):
    if not path.is_file() or path.name.endswith(".import"):
        continue
    fname = path.relative_to(ROOT).as_posix()
    blob = path.read_bytes()
    sha = hashlib.sha1(blob).hexdigest()
    call("POST", "/v2/files" + q, blob, {"Content-Type": "application/octet-stream", "x-vercel-digest": sha})
    files.append({"file": fname, "sha": sha, "size": len(blob)})
    print("đã tải", fname, len(blob))

dep = call("POST", "/v13/deployments" + q + ("&" if q else "?") + "skipAutoDetectionConfirmation=1", {
    "name": NAME, "files": files, "target": "production",
    "projectSettings": {"framework": None, "buildCommand": None, "outputDirectory": None, "installCommand": None},
})
print("id:", dep.get("id"), "| trạng thái:", dep.get("readyState"))
print("url:", "https://" + dep.get("url", ""))
print("alias:", dep.get("alias"))
