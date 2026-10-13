# Techies Auto Miner

автоматически минирует выбранные зоны карты на Techies / automatically mines selected map zones as Techies

<!-- releases:start -->
Скачать: [techies_auto_miner.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/techies-auto-miner-v1.1/techies_auto_miner.lua) — `techies-auto-miner-v1.1`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`techies-auto-miner-v1.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/techies-auto-miner-v1.1) | 2026-10-13 | [techies_auto_miner.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/techies-auto-miner-v1.1/techies_auto_miner.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=techies-auto-miner&expanded=true)
<!-- releases:end -->

## Что умеет

Автоматически обходит выбранные через интерактивную мини-карту зоны и закладывает Proximity Mines.

- Интерактивная панель карты с выбором зон, фильтрами и стартом/остановкой
- Покрывает проходимые участки и показывает мины, точки, границы и текущую цель
- Управляет маной: использует Arcane Boots, заряды, Mango и ждёт восстановления
- Прерывает автоматизацию при ручном приказе игрока; требуется qLocalization

## Установка

1. Поместите `techies_auto_miner.lua` и `!_qLocalizer.lua` в `umbrella\scripts`.
2. Перезагрузите скрипты, выберите зоны на панели карты и запустите минирование.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Techies Auto Miner (English)

## What it does

Automatically traverses zones selected on an interactive minimap and plants Proximity Mines.

- Interactive map panel with zone selection, filters, and start/stop controls
- Covers walkable areas and visualizes mines, points, zone boundaries, and the current target
- Manages mana with Arcane Boots, charges, Mango, and regeneration waits
- Stops automation on a manual player order; requires qLocalization

## Install

1. Place `techies_auto_miner.lua` and `!_qLocalizer.lua` in `umbrella\scripts`.
2. Reload scripts, select zones on the map panel, and start mining.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
