# Force Cookie Cursor Cast

направляет Force, Pike и Firesnap Cookie к курсору / aims Force, Pike, and Firesnap Cookie toward the cursor

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `forcecookies.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/force_cookie_cursor_cast/forcecookies.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=force-cookie-cursor-cast&expanded=true)
<!-- releases:end -->

## Что умеет

Перехватывает соответствующий self-cast, сбрасывает инерцию движения и сначала разворачивает героя к текущему курсору. Учитывает телепорт, применение заклинаний, контроль, ману и перезарядку.

- Поддерживает Force Staff, Hurricane Pike и Firesnap Cookie
- Разворачивает героя к курсору перед использованием
- Откладывает разворот до выхода из стана и повторно считывает позицию курсора
- Не вмешивается во время телепорта или другой способности

## Установка

1. Поместите `forcecookies.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Miscellaneous → In Game → Использование по курсору`.

---

# Force Cookie Cursor Cast (English)

## What it does

Intercepts the relevant self-cast, clears movement momentum, and turns the hero toward the current cursor before use. Accounts for teleporting, casting, disables, mana, and cooldowns.

- Supports Force Staff, Hurricane Pike, and Firesnap Cookie
- Turns the hero toward the cursor before use
- Waits for stuns to end and then reads the current cursor position
- Does not interfere while teleporting or casting another ability

## Install

1. Place `forcecookies.lua` in `umbrella\scripts`.
2. Reload Lua scripts.
3. Open `Miscellaneous → In Game → Использование по курсору`.
