
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
from pathlib import Path
import re
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
CONSTANTS = "https://raw.githubusercontent.com/odota/dotaconstants/master/"
GUIDES = "https://raw.githubusercontent.com/leamare/nerds-builds/master/"


def fetch(url):
    with urlopen(Request(url, headers={"User-Agent": "UmbrellaSelfPlay/1.0"}), timeout=30) as response:
        return response.read().decode("utf-8")


def lua(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{" + ",".join(map(lua, value)) + "}"
    return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items()) + "}"


def values(value):
    if not isinstance(value, list):
        value = [value]
    result = []
    for entry in value:
        match = re.fullmatch(r"-?\d+(?:\.\d+)?", str(entry))
        if not match:
            return []
        result.append(float(entry))
    return result


def effects(record, item=False):

    desc = " ".join(a.get("description", "") for a in record.get("abilities", [])
                    if a.get("type") in ("active", "use")) if item else record.get("desc", "")
    desc = desc.lower()
    result = {}
    for key, pattern in {
        "disable": r"\b(stuns?|hex|silences?|roots?|fear(?:s|ed|ing)?)\b",
        "heal": r"\b(heals?|healing|restores? \d+ health|health regeneration)\b",
        "save": r"\b(barrier|invulnerab\w*|debuff immun\w*|invisib\w*|impossible to see|disjointing)\b",
        "mobility": r"\b(blink|short distance teleportation|teleports? to a unit)\b",
        "unitMobility": r"\bteleports? to a unit\b",
        "targetsBoth": r"\b(friendly or enemy|enemy or friendly|allied or enemy|enemy or allied)\b",
        "summon": r"\b(summons?|creates? (?:an? |\d+ )?illusions?)\b",
        "buff": r"\b(bonus attack speed|bonus damage|increases? .*attack speed)\b",
        "steal": r"\b(steals? .*spell|last spell|last ability)\b",
        "unsafe": r"\b(sacrific\w*|suicide|swap\w*|exchanges?|releases? .*stored|stops? channeling|detonates?|sub-abilit\w*|invok\w*)\b",
    }.items():
        if re.search(pattern, desc):
            result[key] = True
    direct_damage = values(record.get("dmg", []))
    if direct_damage:
        result["damage"] = direct_damage
    for attr in record.get("attrib", []):
        key, val = attr.get("key", ""), values(attr.get("value"))
        if not val:
            continue
        if (key == "damage" or key.endswith("_damage")) and not any(x in key for x in ("bonus", "self", "max", "pct", "incoming", "attack", "reflect")):
            result.setdefault("damage", val)
        if key == "radius" or key.endswith("_radius"):
            result.setdefault("radius", val)
        if key.endswith("_range") and "directly in front" in desc and "No Target" in record.get("behavior", []):
            result["frontOffset"] = val
        if key == "bonus_attack_speed":
            result["buff"] = True
        if "projectile_speed" in key or key.endswith("_speed") and "bonus" not in key and max(val) >= 800:
            result.setdefault("speed", val)
        if key in ("stun_duration", "hex_duration", "silence_duration", "root_duration"):
            result["disable"] = True
        if key in ("heal", "heal_amount", "health_restore", "health_regen"):
            result["heal"] = True
    if record.get("bkbpierce") == "Yes":
        result["pierces"] = True
    if item and not desc:
        return {}
    return result


def parse_guide(path, text):
    def field(name):
        match = re.search(r'"' + name + r'"\s*"([^"\r\n]*)"', text)
        return match.group(1) if match else ""
    groups = []
    for match in re.finditer(r'"([^"\r\n]+)"\s*\{([^{}]*)\}', text):
        title, body = match.groups()
        names = re.findall(r'"item"\s*"item_([a-z0-9_]+)"', body)
        if names and ("Starting" in title or title.lower() in ("early", "core", "lategame", "late game")):
            groups.append({"title": title, "items": names})
    order = re.search(r'"AbilityOrder"\s*\{([^{}]*)\}', text)
    skills = {int(level): name for level, name in re.findall(r'"(\d+)"\s*"([a-z0-9_]+)"', order.group(1))} if order else {}
    return {"hero": "npc_dota_hero_" + field("Hero"), "title": field("Title"),
            "support": "Support" in field("Role"), "patch": field("GameplayVersion"),
            "url": GUIDES + quote(path), "groups": groups, "skills": skills}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cached", action="store_true", help="Regenerate from local JSON snapshots only")
    args = parser.parse_args()
    DATA.mkdir(exist_ok=True)
    if not args.cached:
        for name in ("items", "heroes", "abilities"):
            (DATA / (name + ".json")).write_text(fetch(CONSTANTS + "build/" + name + ".json"), encoding="utf-8")
        tree = json.loads(fetch("https://api.github.com/repos/leamare/nerds-builds/git/trees/master?recursive=1"))
        paths = [entry["path"] for entry in tree["tree"] if entry["path"].startswith("builds/") and entry["path"].endswith(".build")]
        def download(path):
            return parse_guide(path, fetch(GUIDES + quote(path)))
        with ThreadPoolExecutor(max_workers=4) as pool:
            guides = list(pool.map(download, paths))
        (DATA / "guides.json").write_text(json.dumps(guides, indent=2), encoding="utf-8")
        for label, url in (("dotaconstants", CONSTANTS + "LICENSE"), ("nerds-builds", GUIDES + "LICENSE.md")):
            (DATA / (label + "-LICENSE.txt")).write_text(fetch(url), encoding="utf-8")
    raw_items = json.loads((DATA / "items.json").read_text(encoding="utf-8"))
    items = {}
    for name, item in raw_items.items():
        if "id" not in item:
            continue
        components = list(item.get("components") or [])
        recipe = "recipe_" + name
        if components and recipe in raw_items and raw_items[recipe].get("cost", 0) > 0 and recipe not in components:
            components.append(recipe)
        items[name] = {"id": item["id"], "cost": item.get("cost", 0), "components": components,
                       "secret": item.get("qual") == "secret_shop", "neutral": "tier" in item,
                       "consumable": item.get("qual") == "consumable", "effects": effects(item, True)}
        passive = " ".join(a.get("description", "") for a in item.get("abilities", []) if a.get("type") == "passive").lower()
        if "non-hero" in passive:
            attrs = {a.get("key"): values(a.get("value")) for a in item.get("attrib", [])}
            if attrs.get("damage_bonus") and attrs.get("damage_bonus_ranged"):
                items[name]["creepBonus"] = attrs["damage_bonus"][0]
                items[name]["creepRangedBonus"] = attrs["damage_bonus_ranged"][0]
    heroes = {h["name"]: {"id": h["id"], "attribute": h["primary_attr"], "roles": h["roles"]}
              for h in json.loads((DATA / "heroes.json").read_text(encoding="utf-8")).values()}
    raw_abilities = json.loads((DATA / "abilities.json").read_text(encoding="utf-8"))
    abilities = {name: effects(record) for name, record in raw_abilities.items()}
    directional_families = {record.get("dname") for name, record in raw_abilities.items() if abilities[name].get("frontOffset")}
    for name, record in raw_abilities.items():
        if record.get("dname") in directional_families and "No Target" in record.get("behavior", []):
            for attr in record.get("attrib", []):
                offset = values(attr.get("value"))
                if attr.get("key", "").endswith("_range") and offset:
                    abilities[name]["frontOffset"] = offset
    guides = json.loads((DATA / "guides.json").read_text(encoding="utf-8"))
    for guide in guides:
        guide["skills"] = {int(k): v for k, v in guide["skills"].items()}
    catalog = {"generated": datetime.now(timezone.utc).isoformat(), "heroes": heroes, "items": items,
               "abilities": abilities, "guides": guides}
    output = "local catalog = {}\n\n"
    for key, value in catalog.items():
        if isinstance(value, dict):
            output += "catalog." + key + " = {\n" + "".join("\t[" + lua(k) + "] = " + lua(v) + ",\n" for k, v in value.items()) + "}\n\n"
        else:
            output += "catalog." + key + " = " + lua(value) + "\n\n"
    (ROOT / "catalog.lua").write_text(output + "return catalog\n", encoding="utf-8")
    print(f"Generated {len(heroes)} heroes, {len(items)} items, {len(abilities)} ability records, {len(guides)} public guides")


if __name__ == "__main__":
    main()
