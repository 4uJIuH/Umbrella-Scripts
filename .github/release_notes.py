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
PACKAGE_FILE = re.compile(
    r"[A-Za-z0-9_-][A-Za-z0-9_.-]*\.json|filters/filter_[A-Za-z0-9_-]+_cached\.txt"
)


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
    if "source_file" in script:
        return script_dir / script["source_file"]
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


def build_archive(script):
    script_dir = BASE / "scripts" / script["id"]
    filename = Path(script["file"])
    if filename.name != script["file"] or filename.suffix.lower() != ".zip":
        raise SystemExit("archive file must be a .zip filename")

    names = script["archive_files"]
    if not isinstance(names, list) or not names or len(names) > 64:
        raise SystemExit("archive_files must contain 1-64 files")

    files = []
    for name in names:
        if not isinstance(name, str) or "\\" in name:
            raise SystemExit("unsupported archive file path: %r" % name)
        relative = Path(name)
        if relative.is_absolute() or any(part in ("", ".", "..") for part in relative.parts):
            raise SystemExit("unsupported archive file path: %r" % name)
        path = script_dir / relative
        try:
            path.resolve().relative_to(script_dir.resolve())
        except ValueError:
            raise SystemExit("archive file must stay inside %s" % script["id"])
        if not path.is_file():
            raise SystemExit("archive file not found: %s" % path)
        files.append((name, path))

    output = BASE / "dist" / filename.name
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, path in sorted(files):
            archive.write(path, name)
    return output.relative_to(BASE).as_posix()


def check_version(script, version):
    if script.get("version_marker") == "NONE":
        return
    text = script_source_path(script).read_text(encoding="utf-8")
    m = re.search(r'VERSION = "([^"]+)"', text)
    if not m or m.group(1) != version:
        raise SystemExit("%s has VERSION %s, tag says %s"
                         % (script_source_path(script).name, m.group(1) if m else "none", version))


def write_manager_catalog():
    items = []
    for script in CATALOG["scripts"]:
        if (
            script.get("category") != "dota"
            and script["id"] != "script_manager"
            and not script.get("manager_catalog")
        ):
            continue
        path = manifest_path(script)
        if path:
            version = json.loads(path.read_text(encoding="utf-8"))
        elif script.get("initial"):
            version = script["initial"]
        else:
            continue
        manual = script.get("manual", "package" in script)
        item = {
            "id": script["id"],
            "version": version["version"],
            "url": version["url"],
            "release": version.get("release", version["url"]),
            "manual": manual,
            "needs_q_localizer": script.get("needs_q_localizer", False),
            "author": script.get("author") or REPO.split("/", 1)[0],
        }
        if version.get("install_url") and version.get("files"):
            item["install_url"] = version["install_url"]
            item["files"] = version["files"]
        if script.get("heroes"):
            item["heroes"] = script["heroes"]
        if script.get("version_marker") in ("SCRIPT_VERSION", "NONE"):
            item["version_marker"] = script["version_marker"]
        items.append(item)

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
    print("%s updated (%d managed scripts)" % (path.relative_to(BASE).as_posix(), len(items)))


def write_manifest(script, tag, sha):
    version = tag[len(script["tag"]) + 2:]
    release_url = "https://github.com/%s/releases/download/%s/%s" % (REPO, tag, script["file"])
    source_path = script_source_path(script).relative_to(BASE).as_posix()
    data = {
        "version": version,
        "url": release_url if "package" in script or "archive_files" in script else
               "https://raw.githubusercontent.com/%s/%s/%s" % (REPO, sha, source_path),
        "release": release_url,
    }
    if "package" in script:
        package_dir = BASE / "scripts" / script["id"] / script["package"]
        lib_dir = package_dir / "lib"
        if lib_dir.is_dir():
            raw_base = "https://raw.githubusercontent.com/%s/%s/" % (REPO, sha)
            data["install_url"] = raw_base + source_path
            files = sorted(path for path in lib_dir.glob("*.lua") if path.is_file())
            if not files:
                raise SystemExit("package has no Lua files in lib: %s" % package_dir)
            if len(files) > 64 or any(
                not re.fullmatch(r"lib/[A-Za-z0-9_-]+\.lua",
                                 path.relative_to(package_dir).as_posix())
                for path in files
            ):
                raise SystemExit("package contains unsupported library paths: %s" % package_dir)
            data["files"] = [
                {
                    "path": path.relative_to(package_dir).as_posix(),
                    "url": raw_base + path.relative_to(BASE).as_posix(),
                }
                for path in files
            ]
    elif script.get("package_files"):
        script_dir = BASE / "scripts" / script["id"]
        raw_base = "https://raw.githubusercontent.com/%s/%s/" % (REPO, sha)
        package_files = script["package_files"]
        if not isinstance(package_files, list) or not package_files or len(package_files) > 64:
            raise SystemExit("package_files must contain 1-64 files")
        files = []
        for name in package_files:
            if not isinstance(name, str) or not PACKAGE_FILE.fullmatch(name):
                raise SystemExit("unsupported package file name: %r" % name)
            path = script_dir / name
            if not path.is_file():
                raise SystemExit("package file not found: %s" % path)
            files.append({"path": name, "url": raw_base + path.relative_to(BASE).as_posix()})
        data["install_url"] = raw_base + source_path
        data["files"] = files
    path = BASE / "scripts" / script["id"] / "version.json"
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
        elif "archive_files" in script:
            path = build_archive(script)
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
