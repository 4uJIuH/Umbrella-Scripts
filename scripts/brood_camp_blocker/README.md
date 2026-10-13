# Broodmother Camp Blocker

отправляет пауков Брудмазер блокировать спавн кемпов / sends Broodmother's spiders to block neutral camp spawns

<!-- releases:start -->
Скачать: [brood_camp_blocker.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/brood-camp-blocker-v1.6/brood_camp_blocker.lua) — `brood-camp-blocker-v1.6`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`brood-camp-blocker-v1.6`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/brood-camp-blocker-v1.6) | 2026-10-13 | [brood_camp_blocker.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/brood-camp-blocker-v1.6/brood_camp_blocker.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=brood-camp-blocker&expanded=true)
<!-- releases:end -->

## Что умеет

Автоматически назначает пауков на выбранные лагеря нейтралов в момент минутного респауна.

- Интерактивная карта кемпов открывается по F6; есть фильтры по стороне и древним
- Рассчитывает момент отправки так, чтобы паук пришёл к спавн-боксу к :00
- Выбирает живучего паука, после проверки респауна возвращает его к героине
- Автономные пауки не перехватывают выделение и команды; визуалы показывают кемпы и маршруты

## Установка

1. Поместите `brood_camp_blocker.lua` и `!_qLocalizer.lua` в `umbrella\scripts`.
2. Перезагрузите скрипты, настройте кемпы и включите блокировку в меню Broodmother.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Broodmother Camp Blocker (English)

## What it does

Automatically assigns spiderlings to selected neutral camps at the minute spawn check.

- Camp selection map opens with F6 and includes side and Ancient filters
- Times dispatch so a spider reaches the camp spawn box at :00
- Selects a durable spider and returns it after the spawn check
- Managed spiders ignore selection and move commands; visuals show camps and routes

## Install

1. Place `brood_camp_blocker.lua` and `!_qLocalizer.lua` in `umbrella\scripts`.
2. Reload scripts, configure camps, and enable blocking in the Broodmother menu.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
