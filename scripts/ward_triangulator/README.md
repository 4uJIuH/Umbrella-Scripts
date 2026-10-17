# Ward Triangulator

находит вражеские сентри по наблюдениям и триангуляции / locates enemy sentries through visibility observations and triangulation

<!-- releases:start -->
Скачать: [ward_triangulator.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/ward-triangulator-v1.0.0/ward_triangulator.lua) — `ward-triangulator-v1.0.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`ward-triangulator-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/ward-triangulator-v1.0.0) | 2026-10-13 | [ward_triangulator.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/ward-triangulator-v1.0.0/ward_triangulator.lua) | 9 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=ward-triangulator&expanded=true)
<!-- releases:end -->

## Что умеет

Отслеживает моменты, когда герой становится видимым вражескому сентри, и по нескольким проходам оценивает местоположение варда.

- Рисует область возможного положения и уточняет её при новых входах в радиус
- Помогает найти сентри, блокирующий кемп или обзор территории
- Настройки обнаружения и производительности находятся в меню Ward Triangulator

## Установка

1. Поместите `ward_triangulator.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Other → Ward Triangulator`.

---

# Ward Triangulator (English)

## What it does

Tracks when your hero becomes visible to an enemy sentry and estimates the ward's location after several passes.

- Draws the possible ward area and narrows it with new entries into sentry range
- Helps locate a sentry blocking a camp or watching an area
- Detection and performance options are in the Ward Triangulator menu

## Install

1. Place `ward_triangulator.lua` in `umbrella\scripts`.
2. Reload Lua scripts.
3. Open `Scripts → Other → Ward Triangulator`.
