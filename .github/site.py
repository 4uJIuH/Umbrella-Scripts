import hashlib
import json
import re
import shutil
from collections import Counter
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
GH = BASE / ".github"
OUT = BASE / "_site"
CATALOG = json.loads((GH / "catalog.json").read_text(encoding="utf-8"))
ROWS = [json.loads(line) for line in (GH / "stats" / "stats.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]

def version_key(version):
    return [(0, int(p)) if p.isdigit() else (-1, p) for p in re.split(r"[.\-]", version)]


def read(path):
    return path.read_text(encoding="utf-8") if path.exists() else ""


def series():
    seen = {}
    out = []
    for row in ROWS:
        for a in row["assets"]:
            seen[(a["tag"], a["file"])] = (a["script"], a["downloads"])
        counts = Counter()
        for key, (script_id, downloads) in seen.items():
            counts[script_id] += downloads
        out.append([row["date"], sum(counts.values()), dict(counts)])
    return out


SERIES = series()


def entry(script, folder, kind):
    prefix = script["tag"] + "-v"
    assets = [a for a in ROWS[-1]["assets"] if a["tag"].startswith(prefix)]
    versions = [{"v": a["tag"][len(prefix):], "date": a["date"], "dl": a["downloads"], "file": a.get("file") or script["file"]} for a in assets]
    versions.sort(key=lambda v: version_key(v["v"]), reverse=True)
    if not versions and script.get("initial"):
        initial = script["initial"]
        versions.append({
            "v": initial["version"],
            "date": initial["date"],
            "dl": 0,
            "file": script["file"],
            "url": initial["url"],
        })
    preview = GH / "previews" / (script["id"] + ".png")
    return {
        "id": script["id"],
        "title": script["title"],
        "kind": kind,
        "category": script["category"],
        "needs_q_localizer": script.get("needs_q_localizer", False),
        "author": script.get("author"),
        "author_github": script.get("author_github"),
        "source_url": script.get("source_url"),
        "releases_url": script.get("releases_url"),
        "file": versions[0]["file"] if versions else script["file"],
        "total": SERIES[-1][2].get(script["id"], 0),
        "tag": script["tag"],
        "folder": folder,
        "ru": script["ru"],
        "en": script["en"],
        "preview": preview.exists(),
        "versions": versions,
        "changelog": {
            "ru": read(BASE / folder / "CHANGELOG.md"),
            "en": read(BASE / folder / "CHANGELOG.en.md") or read(BASE / folder / "CHANGELOG.md"),
        },
    }


def main():
    items = [entry(s, "scripts/" + s["id"], s["kind"]) for s in CATALOG["scripts"]]
    items = [i for i in items if i["versions"]]
    data = "window.DATA=" + json.dumps({"repo": CATALOG["repo"], "items": items, "series": SERIES}, ensure_ascii=False)

    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "previews").mkdir(parents=True)
    (OUT / "data.js").write_text(data, encoding="utf-8")
    for item in items:
        if item["preview"]:
            shutil.copy(GH / "previews" / (item["id"] + ".png"), OUT / "previews")
    stamp = hashlib.sha1(data.encode("utf-8")).hexdigest()[:10]
    html = (BASE / "site" / "index.html").read_text(encoding="utf-8").replace("data.js", "data.js?v=" + stamp)
    (OUT / "index.html").write_text(html, encoding="utf-8")
    (OUT / ".nojekyll").write_text("", encoding="utf-8")
    print("site: %d items, %d days" % (len(items), len(ROWS)))


main()
