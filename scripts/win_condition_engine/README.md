# Win Condition Engine

подсказывает приоритетные действия по ситуации на карте / suggests priorities based on the current map situation

<!-- releases:start -->
Скачать: [win_condition_engine.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/win-condition-engine-v1.0.0/win_condition_engine.lua) — `win-condition-engine-v1.0.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`win-condition-engine-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/win-condition-engine-v1.0.0) | 2026-10-13 | [win_condition_engine.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/win-condition-engine-v1.0.0/win_condition_engine.lua) | 15 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=win-condition-engine&expanded=true)
<!-- releases:end -->

## Что умеет

Первая версия помощника, который оценивает ситуацию и предлагает направление действий: фарм, Roshan, поиск одиночной цели и другие варианты.

- оценивает текущую ситуацию на карте
- сравнивает несколько возможных целей
- ранняя версия; автор просит сообщать об ошибках

## Установка

1. Поместите `win_condition_engine.lua` и `!_qLocalizer.lua` в `Umbrella\scripts`.
2. Перезагрузите Lua-скрипты.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Win Condition Engine (English)

## What it does

An early assistant that evaluates the game state and suggests options such as farming, Roshan, or finding an isolated target.

- evaluates the current map situation
- compares several possible objectives
- early version; the author welcomes bug reports

## Install

1. Place `win_condition_engine.lua` and `!_qLocalizer.lua` in `Umbrella\scripts`.
2. Reload Lua scripts.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
