# Spirit Bear Pull

автоматический отвод крипов медведем Lone Druid / automatically pull a creep wave with Lone Druid's bear

<!-- releases:start -->
Скачать: [lone_druid_bear_pull.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/spirit-bear-pull-v1.0.0/lone_druid_bear_pull.lua) — `spirit-bear-pull-v1.0.0`, 2026-10-10

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`spirit-bear-pull-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/spirit-bear-pull-v1.0.0) | 2026-10-10 | [lone_druid_bear_pull.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/spirit-bear-pull-v1.0.0/lone_druid_bear_pull.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=spirit-bear-pull&expanded=true)
<!-- releases:end -->

## Что умеет

Lua-скрипт для автоматического отвода пачки медведем Lone Druid к игроку.

- Если вражеская T1-башня на линии жива, медведь занимает центральную позицию перед ней вне радиуса атаки
- Если T1 уничтожена, а T2 жива, медведь перемещается на позицию перед T2
- Если T1 и T2 уничтожены, используется стандартная точка линии перед T3
- После агра крипов медведь ведёт их обратно к Lone Druid
- Защищает назначенного медведя от случайных ручных приказов
- Русский и английский интерфейс через qLocalization

## Установка

1. Поместите `lone_druid_bear_pull.lua` в `umbrella\scripts`.
2. Убедитесь, что рядом находится <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a>.
3. Перезагрузите Lua-скрипты.
4. Откройте настройки: `General → Spirit Bear Pull`.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Spirit Bear Pull (English)

## What it does

A Lua script for automatically pulling a creep wave with the Lone Druid's Spirit Bear to the player.

- If the enemy T1 tower on the lane is alive, the bear takes a central position in front of it, outside its attack range
- If the T1 is destroyed but the T2 is alive, the bear moves to a position in front of the T2
- If both the T1 and T2 are destroyed, uses the standard lane position in front of the T3
- After aggroing the creeps, the bear brings them back to Lone Druid
- Protects the assigned bear from accidental manual orders
- Supports Russian and English interfaces through qLocalization

## Install

1. Place `lone_druid_bear_pull.lua` in `umbrella\scripts`.
2. Make sure <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a> is alongside it.
3. Reload the Lua scripts.
4. Open settings: `General → Spirit Bear Pull`.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
