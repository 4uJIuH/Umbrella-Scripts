# Creep Control

управляет подконтрольными существами для фарма и пуша / controls summoned and dominated units for farming and pushing

<!-- releases:start -->
Скачать: [creep_control.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/creep-control-v1.0.1/creep_control.lua) — `creep-control-v1.0.1`, 2026-10-14

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`creep-control-v1.0.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/creep-control-v1.0.1) | 2026-10-14 | [creep_control.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/creep-control-v1.0.1/creep_control.lua) | 10 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=creep-control&expanded=true)
<!-- releases:end -->

## Что умеет

Разделяет подконтрольных юнитов на фармящих лес и тех, кто продвигает линии и атакует вышки. Учитывает угрозы, здоровье и доступность нейтральных лагерей.

- выбирает свободный лагерь, ждёт респавна и может пропускать ancient
- кастит способности по нейтралам и отходит от врагов или вышек
- юниты для пуша не атакуют вражескую вышку без союзных крипов

## Установка

1. Поместите `creep_control.lua` в `Umbrella\scripts`.
2. Перезагрузите Lua-скрипты и настройте фильтры подконтрольных юнитов.

## Что нового

- Исправлена очистка состояния юнитов, чтобы повторно используемые индексы сущностей не наследовали старые приказы.
- Улучшены выбор лагеря и поведение подконтрольных юнитов с ограниченным временем жизни.
- Добавлен поиск безопасного направления отхода от ближайших видимых угроз.
- Оптимизированы поиск способностей и выбор целей для пуша.

---

# Creep Control (English)

## What it does

Assigns controlled units to jungle farming or to pushing lanes and attacking towers. It considers threats, health, and neutral camp availability.

- selects free camps, waits for respawns, and can skip ancient camps
- casts abilities on neutrals and retreats from enemies or towers
- push units do not attack enemy towers without allied creeps

## Install

1. Place `creep_control.lua` in `Umbrella\scripts`.
2. Reload Lua scripts and configure the controlled-unit filters.

## Changelog

- Fixed unit-state cleanup so reused entity indexes do not inherit stale orders.
- Improved camp selection and behavior for controlled units with limited lifetimes.
- Added safe retreat-point selection away from nearby visible threats.
- Optimized ability scanning and push-target selection.
