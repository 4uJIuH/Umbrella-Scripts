# Ward Predictor

прогнозирует места установки вардов вражескими саппортами / predicts where enemy supports may place wards

<!-- releases:start -->
Скачать: [ward_predictor.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/ward-predictor-v1.0.0/ward_predictor.lua) — `ward-predictor-v1.0.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`ward-predictor-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/ward-predictor-v1.0.0) | 2026-10-13 | [ward_predictor.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/ward-predictor-v1.0.0/ward_predictor.lua) | 4 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=ward-predictor&expanded=true)
<!-- releases:end -->

## Что умеет

Использует историю матчей OpenDota и текущую ситуацию, чтобы оценить вероятные места для observer и sentry. Это прогноз, а не гарантия: доступность истории зависит от открытого профиля и разобранных матчей.

- сам находит вражеских саппортов или использует выбор из меню
- учитывает сторону, время игры, роль и недавние матчи
- показывает метки на земле и миникарте, а также статистику попаданий

## Установка

1. Поместите `ward_predictor.lua` и `!_qLocalizer.lua` в `Umbrella\scripts`.
2. Перезагрузите скрипты и откройте General → Main → Ward Predictor.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Ward Predictor (English)

## What it does

Uses OpenDota match history and the current game state to estimate likely observer and sentry locations. This is a prediction, not a guarantee; history availability depends on public profiles and parsed matches.

- finds enemy supports automatically or lets you select them
- considers side, game time, role, and recent matches
- draws ground and minimap markers and reports prediction accuracy

## Install

1. Place `ward_predictor.lua` and `!_qLocalizer.lua` in `Umbrella\scripts`.
2. Reload scripts and open General → Main → Ward Predictor.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
