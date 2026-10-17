# Hoodwink Blast Off Catch

ловит Techies способностью Bushwhack во время Blast Off / catches Techies with Bushwhack during Blast Off

<!-- releases:start -->
Скачать: [hoodwink_bushwhack_techies.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/hoodwink-bushwhack-techies-v1.0.0/hoodwink_bushwhack_techies.lua) — `hoodwink-bushwhack-techies-v1.0.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`hoodwink-bushwhack-techies-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/hoodwink-bushwhack-techies-v1.0.0) | 2026-10-13 | [hoodwink_bushwhack_techies.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/hoodwink-bushwhack-techies-v1.0.0/hoodwink_bushwhack_techies.lua) | 4 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=hoodwink-bushwhack-techies&expanded=true)
<!-- releases:end -->

## Что умеет

Вспомогательный скрипт Hoodwink, который старается поймать Techies сетью в полёте после Blast Off.

- Отслеживает Blast Off после ухода способности на перезарядку и траты маны
- Смещает Bushwhack к ближайшему дереву, чтобы связать Techies
- Опционально может посадить Iron Branch
- Для меню требуется qLocalization; автор отмечает, что скрипт сделан для личного использования

## Установка

1. Поместите `hoodwink_bushwhack_techies.lua` и `!_qLocalizer.lua` в `umbrella\scripts`.
2. Перезагрузите скрипты. Меню: Hoodwink → Blast Off Catch.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Hoodwink Blast Off Catch (English)

## What it does

A Hoodwink helper that attempts to catch Techies in midair with a net after Blast Off.

- Tracks Blast Off after it goes on cooldown and consumes mana
- Shifts Bushwhack toward the nearest tree to catch Techies
- Can optionally plant an Iron Branch
- Requires qLocalization for its menu; the author says the script was made for personal use

## Install

1. Place `hoodwink_bushwhack_techies.lua` and `!_qLocalizer.lua` in `umbrella\scripts`.
2. Reload scripts. Menu: Hoodwink → Blast Off Catch.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
