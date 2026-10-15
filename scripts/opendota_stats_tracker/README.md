# OpenDota Stats Tracker

строит статистику игры по последним матчам и данным OpenDota / builds performance statistics from recent matches and OpenDota

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `dotaplus.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/opendota_stats_tracker/dotaplus.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=opendota-stats-tracker&expanded=true)
<!-- releases:end -->

## Что умеет

Загружает историю матчей и временные ряды показателей героя через OpenDota API, сохраняет данные локально в папке scripts и показывает сравнение с ориентиром в HUD. API-ключ не требуется; кэш обновляется периодически.

- История матчей и анализ статистики героя
- Сравнение K/D/A, крипов, золота и опыта по времени игры
- Локальный кэш с периодическим обновлением
- Настраиваемые панель, показатели и отладочные данные

## Установка

1. Поместите `dotaplus.lua` в `umbrella\scripts`.
2. Разрешите Umbrella создавать и обновлять локальные файлы кэша в папке `scripts`.
3. Перезагрузите Lua-скрипты.
4. Откройте `Info Screen → Main → Tracker → Main → Settings`.

---

# OpenDota Stats Tracker (English)

## What it does

Fetches match history and time-series hero metrics from the OpenDota API, stores data locally in the scripts folder, and displays comparisons in a HUD. No API key is required; the cache is refreshed periodically.

- Match history and hero-stat analysis
- Compare K/D/A, last hits, gold, and experience over game time
- Local cache with periodic refresh
- Configurable panel, metrics, and debug data

## Install

1. Place `dotaplus.lua` in `umbrella\scripts`.
2. Allow Umbrella to create and update local cache files in the `scripts` folder.
3. Reload Lua scripts.
4. Open `Info Screen → Main → Tracker → Main → Settings`.
