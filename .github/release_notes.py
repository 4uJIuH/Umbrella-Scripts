import json
import os
import re
import sys
import zipfile
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
GH = BASE / ".github"
CATALOG = json.loads((GH / "catalog.json").read_text(encoding="utf-8"))
REPO = CATALOG["repo"]
NL = chr(10)


def find(tag):
    for script in CATALOG["scripts"]:
        if tag.startswith(script["tag"] + "-v"):
            return script
    return None


def body(script, tag):
    folder = BASE / "scripts" / script["id"]
    version = tag[len(script["tag"]) + 1:]
    out = ["## %s %s" % (script["title"], version), ""]

    ru = folder / "CHANGELOG.md"
    en = folder / "CHANGELOG.en.md"
    if ru.exists():
        out += ["### Что нового", "", ru.read_text(encoding="utf-8").strip(), ""]
    if en.exists():
        out += ["### What's new", "", en.read_text(encoding="utf-8").strip(), ""]
    if not ru.exists() and not en.exists():
        out += [script["ru"]["tagline"], "", script["en"]["tagline"], ""]

    out += [
        "---",
        "",
        "Описание и все версии: https://github.com/%s/tree/main/scripts/%s"
        % (REPO, script["id"]),
    ]
    return NL.join(out) + NL


def manifest_path(script):
    path = BASE / "scripts" / script["id"] / "version.json"
    return path if path.exists() else None


def script_source_path(script):
    script_dir = BASE / "scripts" / script["id"]
    if "package" in script:
        return script_dir / script["package"] / "Tinker.lua"
    return script_dir / script["file"]


def build_package(script):
    script_dir = BASE / "scripts" / script["id"]
    package_dir = script_dir / script["package"]
    try:
        package_dir.resolve().relative_to(script_dir.resolve())
    except ValueError:
        raise SystemExit("package directory must stay inside %s" % script["id"])
    if not package_dir.is_dir():
        raise SystemExit("package directory not found: %s" % package_dir)

    filename = Path(script["file"])
    if filename.name != script["file"] or filename.suffix.lower() != ".zip":
        raise SystemExit("package file must be a .zip filename")

    output = BASE / "dist" / filename.name
    output.parent.mkdir(parents=True, exist_ok=True)
    files = sorted(path for path in package_dir.rglob("*") if path.is_file())
    if not files:
        raise SystemExit("package directory is empty: %s" % package_dir)

    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, path.relative_to(package_dir).as_posix())
    return output.relative_to(BASE).as_posix()


def check_version(script, version):
    text = script_source_path(script).read_text(encoding="utf-8")
    m = re.search(r'VERSION = "([^"]+)"', text)
    if not m or m.group(1) != version:
        raise SystemExit("%s has VERSION %s, tag says %s"
                         % (script_source_path(script).name, m.group(1) if m else "none", version))


def write_manager_catalog():
    items = []
    for script in CATALOG["scripts"]:
        path = manifest_path(script)
        if script.get("category") != "dota" or not path:
            continue
        version = json.loads(path.read_text(encoding="utf-8"))
        items.append({
            "id": script["id"],
            "version": version["version"],
            "url": version["url"],
            "release": version.get("release"),
            "manual": "package" in script,
            "needs_q_localizer": script.get("needs_q_localizer", False),
        })

    dependency = next(script for script in CATALOG["scripts"] if script["id"] == "q_localizer")
    feed = {
        "schema": 1,
        "q_localizer": {
            "version": dependency["initial"]["version"],
            "url": dependency["initial"]["url"],
        },
        "scripts": items,
    }
    path = BASE / "scripts" / "manager" / "catalog.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(feed, indent=2) + NL, encoding="utf-8", newline=NL)
    print("%s updated (%d Dota entries)" % (path.relative_to(BASE).as_posix(), len(items)))


def write_manifest(script, tag, sha):
    version = tag[len(script["tag"]) + 2:]
    release_url = "https://github.com/%s/releases/download/%s/%s" % (REPO, tag, script["file"])
    source_path = script_source_path(script).relative_to(BASE).as_posix()
    data = {
        "version": version,
        "url": release_url if "package" in script else
               "https://raw.githubusercontent.com/%s/%s/%s" % (REPO, sha, source_path),
        "release": release_url,
    }
    path = manifest_path(script)
    path.write_text(json.dumps(data, indent=2) + NL, encoding="utf-8", newline=NL)
    print("%s -> %s" % (path.relative_to(BASE).as_posix(), version))
    write_manager_catalog()


def main():
    tag = sys.argv[1]
    script = find(tag)
    if script and len(sys.argv) > 3 and sys.argv[2] == "--manifest":
        write_manifest(script, tag, sys.argv[3])
        return
    out = os.environ.get("GITHUB_OUTPUT")
    lines = []
    if script:
        (BASE / "body.md").write_text(body(script, tag), encoding="utf-8", newline=NL)
        if manifest_path(script):
            check_version(script, tag[len(script["tag"]) + 2:])
            lines += ["manifest=%s" % script["id"].replace("_", " ")]
        path = ""
        if "package" in script:
            path = build_package(script)
        elif script["kind"] == "lua":
            path = "scripts/%s/%s" % (script["id"], script["file"])
        lines += ["found=true", "path=%s" % path, "title=%s" % script["title"],
                  "version=%s" % tag[len(script["tag"]) + 1:]]
        print("release %s%s" % (tag, (" with " + path) if path else " without files"))
    else:
        lines += ["found=false"]
        print("no script in catalog.json matches tag %s" % tag)
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write(NL.join(lines) + NL)


if __name__ == "__main__":
    main()
