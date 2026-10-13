# Dragon Camp Pull

отправляет пачки с линии в лес к приручённому дракону / pulls lane waves into the jungle for a controlled dragon to farm

<!-- releases:start -->
Последняя версия: [`v1.0` — `dragon_camp_pull.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/dragon_camp_pull/dragon_camp_pull.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=dragon-camp-pull&expanded=true)
<!-- releases:end -->

## Что умеет

Автоматизация фарма линии и нейтрального лагеря с приручённым Чёрным драконом от Helm of the Overlord.

- Отводит вражескую волну к лесному лагерю без атак по пути
- После столкновения крипов с нейтралами использует огненный шар и добивает пачку
- Чередует ближайшие лагеря у крайних вышек и исключает зачищенный лагерь до респауна
- Избегает вышек и вражеских героев, отступает при низком HP; приказ игрока ставит паузу

## Установка

1. Поместите `dragon_camp_pull.lua` и `!_qLocalizer.lua` в `umbrella\scripts`.
2. Для работы нужны Helm of the Overlord и приручённый Чёрный дракон. Перезагрузите Lua-скрипты.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Dragon Camp Pull (English)

## What it does

Automates lane and neutral-camp farming with a Black Dragon controlled through Helm of the Overlord.

- Leads an enemy wave to a jungle camp without attacking on the way
- Uses Fireball and attacks after the wave engages the neutral camp
- Alternates nearby camps by outer towers and skips cleared camps until they respawn
- Avoids towers and enemy heroes, retreats at low HP, and pauses after a player order

## Install

1. Place `dragon_camp_pull.lua` and `!_qLocalizer.lua` in `umbrella\scripts`.
2. Requires Helm of the Overlord and a controlled Black Dragon. Reload Lua scripts.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
