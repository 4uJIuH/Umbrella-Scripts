# Lone Druid Auto Farm

отправляет Lone Druid безопасно фармить лес, пока вы управляете медведем / farms the jungle with Lone Druid while you control the bear

<!-- releases:start -->
Последняя версия: [`v1.7` — `ld_farm.lua`](https://github.com/4uJIuH/umbrella-scripts/releases/download/ld-farm-v1.7/ld_farm.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=ld-farm&expanded=true)
<!-- releases:end -->

## Что умеет

Автоматически выбирает ближайший доступный лагерь и фармит героем, не перехватывая управление Spirit Bear. Учитывает состояние карты, здоровье, респавн кемпов и угрозы.

- оценивает безопасность маршрута по вышкам и продвижению линии
- предупреждает о видимых врагах и отводит героя на базу или включает True Form
- учитывает восстановление здоровья, стаки и время респавна лагерей

## Установка

1. Поместите `ld_farm.lua` и `!_qLocalizer.lua` в `Umbrella\scripts`.
2. Перезагрузите скрипты и откройте `Heroes → Hero List → Lone Druid → ~Auto-LD`.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Lone Druid Auto Farm (English)

## What it does

Automatically selects the nearest available camp and farms with the hero without taking control of Spirit Bear. It considers map state, health, camp respawns, and threats.

- estimates route safety from tower status and lane pressure
- alerts on visible enemies and retreats to base or activates True Form
- accounts for health recovery, stacking, and camp respawn timing

## Install

1. Place `ld_farm.lua` and `!_qLocalizer.lua` in `Umbrella\scripts`.
2. Reload scripts and open `Heroes → Hero List → Lone Druid → ~Auto-LD`.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
