# Dorman Combo Assistant

комбо-ассистент для Dorman в Deadlock / a combo assistant for Dorman in Deadlock

<!-- releases:start -->
Скачать: [Dorman.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/dorman-combo-assistant-v1.0.0/Dorman.lua) — `dorman-combo-assistant-v1.0.0`, 2026-10-10

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`dorman-combo-assistant-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/dorman-combo-assistant-v1.0.0) | 2026-10-10 | [Dorman.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/dorman-combo-assistant-v1.0.0/Dorman.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=dorman-combo-assistant&expanded=true)
<!-- releases:end -->

## Что умеет

Комбо-ассистент для Dorman в Deadlock с тремя независимыми режимами на отдельных клавишах.

- Аим 1-го скилла: по бинду выбирает ближайшую к прицелу цель в радиусе 1200 юнитов и конусе 35° и применяет умение почти в ноги цели
- «Тележка в дверь»: после попадания 3-го скилла ищет ближайшую стену по направлению движения цели и применяет 2-й скилл так, чтобы дверь оказалась перед тележкой
- Важно: дверь плохо работает на большом расстоянии от стены — в таком случае ставьте её вручную
- Комбо ультимейта: ждёт выхода цели из ультимейта, затем применяет 3-й и 2-й скиллы
- Каждый режим запускается отдельным биндом

## Установка

1. Поместите <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/dorman-combo-assistant-v1.0.0/Dorman.lua" target="_blank" rel="noopener"><code>Dorman.lua</code></a> в `%cheat_dir%/deadlock_scripts`.
2. Убедитесь, что рядом находится обязательный <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a>.
3. Перезагрузите Lua-скрипты.
4. Откройте настройки: `Heroes → Hero List → The Dorman → Dorman`.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Dorman Combo Assistant (English)

## What it does

A combo assistant script for Dorman in Deadlock with three independent modes, each on its own bind.

- Aim Skill 1: on bind, picks the target closest to the crosshair within 1200 units and a 35° cone, then casts the skill near the target's feet
- Cart into Door: after Skill 3 connects, finds the nearest wall in the target's movement direction and casts Skill 2 so the doorway lands in front of the cart
- Important: the door works poorly when far from a wall; place it manually in that situation
- Ultimate Combo: waits for the target to exit the ultimate, then casts Skill 3 followed by Skill 2
- Each mode has its own bind

## Install

1. Place <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/dorman-combo-assistant-v1.0.0/Dorman.lua" target="_blank" rel="noopener"><code>Dorman.lua</code></a> in `%cheat_dir%/deadlock_scripts`.
2. Make sure the required <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a> is alongside it.
3. Reload the Lua scripts.
4. Open settings: `Heroes → Hero List → The Dorman → Dorman`.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
