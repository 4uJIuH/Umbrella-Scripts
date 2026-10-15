import json
import re
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
CREATE_CALL = re.compile(r"\b(?:UI|Menu)\.Create\s*\(")
STRING_LITERAL = re.compile(r'''^\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')\s*$''')
ROUTE_SEPARATOR = " → "

OVERRIDES = {
    "lane_pull": {
        "ru": ["Creeps → Main → Lane Pull"],
        "en": ["Creeps → Main → Lane Pull"],
    },
    "ds_spot_block": {
        "ru": ["Heroes → Hero List → Dark Seer → Spot Block"],
        "en": ["Heroes → Hero List → Dark Seer → Spot Block"],
    },
    "custom_background": {
        "ru": ["Scripts → Scripts → Кастом фон"],
        "en": ["Scripts → Scripts → Кастом фон"],
    },
    "auto_stack": {
        "ru": ["Heroes → Hero List → Kunkka → Main Settings", "Heroes → Hero List → Invoker → Main Settings"],
        "en": ["Heroes → Hero List → Kunkka → Main Settings", "Heroes → Hero List → Invoker → Main Settings"],
    },
    "draft_helper": {
        "ru": ["Scripts → Scripts → Draft Helper"],
        "en": ["Scripts → Scripts → Draft Helper"],
    },
    "musicui": {
        "ru": ["Scripts → Scripts → MusicUI"],
        "en": ["Scripts → Scripts → MusicUI"],
    },
    "mom_swapper": {
        "ru": ["Scripts → Other → MoM Swapper"],
        "en": ["Scripts → Other → MoM Swapper"],
    },
    "invoker_jarvis": {
        "ru": ["Heroes → Hero List → Invoker → Jarvis", "Scripts → Scripts → Jarvis"],
        "en": ["Heroes → Hero List → Invoker → Jarvis", "Scripts → Scripts → Jarvis"],
    },
    "umbrella_tiktok": {
        "ru": ["Scripts → Scripts → TikTok"],
        "en": ["Scripts → Scripts → TikTok"],
    },
    "invoker_autostack": {
        "ru": ["Heroes → Hero List → Invoker → Автостак", "Scripts → Scripts → Invoker AutoStack"],
        "en": ["Heroes → Hero List → Invoker → Автостак", "Scripts → Scripts → Invoker AutoStack"],
    },
    "achievements": {
        "ru": ["General → Main → Achievements"],
        "en": ["General → Main → Achievements"],
    },
    "counter_items": {
        "ru": ["General → Main → Counter Items"],
        "en": ["General → Main → Counter Items"],
    },
    "arc_warden_multi_stack": {
        "ru": ["Heroes → Hero List → Arc Warden → Мульти Стак"],
        "en": ["Heroes → Hero List → Arc Warden → Мульти Стак"],
    },
    "techies_auto_miner": {
        "ru": ["Heroes → Hero List → Techies → Авто-минирование"],
        "en": ["Heroes → Hero List → Techies → Авто-минирование"],
    },
    "brood_camp_blocker": {
        "ru": ["Heroes → Hero List → Broodmother → Авто-блок кемпов"],
        "en": ["Heroes → Hero List → Broodmother → Авто-блок кемпов"],
    },
    "invoker_beta": {
        "ru": ["Heroes → Hero List → Invoker (Beta)"],
        "en": ["Heroes → Hero List → Invoker (Beta)"],
    },
    "techies_tazer_dispel": {
        "ru": ["Heroes → Hero List → Techies → Main Settings → Auto Dispel"],
        "en": ["Heroes → Hero List → Techies → Main Settings → Auto Dispel"],
    },
    "dota_no_limit": {
        "ru": ["Scripts → Item Eater → Eater"],
        "en": ["Scripts → Item Eater → Eater"],
    },
    "eul_wind_waker_blink_helper": {
        "ru": ["General → Main → Помощник Blink после Eul / Wind Waker"],
        "en": ["General → Main → Помощник Blink после Eul / Wind Waker"],
    },
    # naga_pt_abuse: у скрипта нет меню
    "backwards_cast": {
        "ru": ["General → Main → Скиллы спиной"],
        "en": ["General → Main → Back Cast"],
    },
    "creep_aggro": {
        "ru": ["Creeps → Переагр V2"],
        "en": ["Creeps → Re-Aggro V2"],
    },
    "dorman_combo_assistant": {
        "ru": ["Heroes → Hero List → The Dorman"],
        "en": ["Heroes → Hero List → The Dorman"],
    },
    "kotl_illuminate_pro": {
        "ru": [
            "Heroes → Hero List → Keeper Of The Light",
            "General → Utility → KOTL Illuminate",
        ],
        "en": [
            "Heroes → Hero List → Keeper Of The Light",
            "General → Utility → KOTL Illuminate",
        ],
    },
    "auto_ruin": {
        "ru": ["Miscellaneous → Other → Авто-Руин"],
        "en": ["Miscellaneous → Other → Авто-Руин"],
    },
    "windranger_powershot": {
        "ru": [
            "Heroes → Hero List → Windranger",
            "Scripts → User Scripts → Windranger Powershot",
        ],
        "en": [
            "Heroes → Hero List → Windranger",
            "Scripts → User Scripts → Windranger Powershot",
        ],
    },
}


def _source_path(script):
    folder = BASE / "scripts" / script["id"]
    if script.get("source_file"):
        return folder / script["source_file"]
    if script.get("package"):
        candidate = folder / script["package"] / "Tinker.lua"
        if candidate.is_file():
            return candidate
    candidate = folder / script["file"]
    return candidate if candidate.suffix.lower() == ".lua" else None


def _split_arguments(text):
    arguments = []
    start = 0
    depth = 0
    quote = None
    escaped = False
    for index, char in enumerate(text):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in ("'", '"'):
            quote = char
        elif char in "({[":
            depth += 1
        elif char in ")}]":
            depth -= 1
        elif char == "," and depth == 0:
            arguments.append(text[start:index].strip())
            start = index + 1
    arguments.append(text[start:].strip())
    return arguments


def _call_arguments(source):
    for match in CREATE_CALL.finditer(source):
        start = match.end()
        index = start
        depth = 1
        quote = None
        escaped = False
        while index < len(source) and depth:
            char = source[index]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
            elif char in ("'", '"'):
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            index += 1
        if depth == 0:
            yield _split_arguments(source[start:index - 1])


def _decode_literal(expression):
    match = STRING_LITERAL.match(expression)
    if not match:
        return None
    value = match.group(1)
    if value.startswith('"'):
        value = re.sub(
            r"\\u\{([0-9a-fA-F]+)\}",
            lambda item: chr(int(item.group(1), 16)),
            value,
        )
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value[1:-1]
    return value[1:-1].replace("\\'", "'").replace("\\\\", "\\")


def _resolve_simple(expression, source):
    value = _decode_literal(expression)
    if value is not None:
        return re.sub(r"[\ue000-\uf8ff]", "", value).strip()
    name = expression.strip()
    if re.fullmatch(r"[A-Za-z_]\w*", name):
        match = re.search(
            r"(?:local\s+)?" + re.escape(name) + r"\s*=\s*"
            r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''',
            source,
        )
        if match:
            value = _decode_literal(match.group(1))
            return re.sub(r"[\ue000-\uf8ff]", "", value).strip() if value else value
    table_index = re.fullmatch(r"([A-Za-z_]\w*)\[(\d+)\]", name)
    if table_index:
        table_name, number = table_index.groups()
        match = re.search(
            r"(?:local\s+)?" + re.escape(table_name) + r"\s*=\s*\{([^}]*)\}",
            source,
            re.DOTALL,
        )
        if match:
            values = [
                _decode_literal(argument)
                for argument in _split_arguments(match.group(1))
            ]
            position = int(number) - 1
            if 0 <= position < len(values):
                value = values[position]
                return re.sub(r"[\ue000-\uf8ff]", "", value).strip() if value else value
    nested = re.fullmatch(r"([A-Za-z_]\w*)\.menu\.(\w+)", name)
    if nested:
        table_name, key = nested.groups()
        match = re.search(
            r"(?:local\s+)?" + re.escape(table_name) + r"\s*=\s*\{",
            source,
        )
        if match:
            tail = source[match.end():]
            menu = re.search(r"\bmenu\s*=\s*\{([^}]*)\}", tail, re.DOTALL)
            if menu:
                field = re.search(
                    r"\b" + re.escape(key) + r"\s*=\s*"
                    r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''',
                    menu.group(1),
                )
                if field:
                    value = _decode_literal(field.group(1))
                    return re.sub(r"[\ue000-\uf8ff]", "", value).strip() if value else value
    return None


def _source_paths(script):
    path = _source_path(script)
    if not path or not path.is_file():
        return []
    source = path.read_text(encoding="utf-8", errors="replace")
    routes = []
    for arguments in _call_arguments(source):
        values = [_resolve_simple(arg, source) for arg in arguments[:3]]
        if values and all(isinstance(value, str) and value for value in values):
            route = ROUTE_SEPARATOR.join(values)
            if route not in routes:
                routes.append(route)
    return routes


def _documented_paths(script, language):
    routes = []
    for line in script.get(language, {}).get("install", []):
        parts = line.split("`")
        for index in range(1, len(parts), 2):
            value = parts[index].strip()
            if "→" in value or "->" in value:
                route = value.replace("->", ROUTE_SEPARATOR).strip()
                if route not in routes:
                    routes.append(route)
    return routes


def _route_matches_source(route, source_route):
    route_parts = [part.strip() for part in route.split("→")]
    source_parts = [part.strip() for part in source_route.split("→")]
    return route_parts[:len(source_parts)] == source_parts


def paths_for(script):
    """Return menu paths by language, preferring literal menu calls and matching docs."""
    override = OVERRIDES.get(script["id"])
    if override:
        return override

    source_paths = _source_paths(script)
    result = {}
    for language in ("ru", "en"):
        documented = _documented_paths(script, language)
        if documented and (
            not source_paths
            or any(
                _route_matches_source(route, source_route)
                for route in documented
                for source_route in source_paths
            )
        ):
            result[language] = documented
        else:
            result[language] = source_paths
    return result
