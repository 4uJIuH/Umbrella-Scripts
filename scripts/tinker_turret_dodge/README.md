# Tinker Turret Dodge

автоматический додж опасных способностей турелями Тинкера / automatically dodges dangerous abilities with Tinker turrets

<!-- releases:start -->
Скачать: [tinker_turret_dodge.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/tinker-turret-dodge-v1.1.5/tinker_turret_dodge.lua) — `tinker-turret-dodge-v1.1.5`, 2026-10-12

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`tinker-turret-dodge-v1.1.5`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/tinker-turret-dodge-v1.1.5) | 2026-10-12 | [tinker_turret_dodge.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/tinker-turret-dodge-v1.1.5/tinker_turret_dodge.lua) | 1 |
| [`tinker-turret-dodge-v1.1.3`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/tinker-turret-dodge-v1.1.3) | 2026-10-10 | [tinker_turret_dodge.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/tinker-turret-dodge-v1.1.3/tinker_turret_dodge.lua) | 3 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=tinker-turret-dodge&expanded=true)
<!-- releases:end -->

## Что умеет

Lua-скрипт для автоматической постановки турелей Тинкера против опасных способностей в Dota 2. Скрипт конфликтует с <a href="https://discord.com/channels/408315082439917578/1552392228284923904" target="_blank" rel="noopener">Tinker Helper</a>.

- Автоматический додж: откидывает Тинкера от вражеских блинков и способностей
- Реагирует на Black Hole, Chronosphere, Reverse Polarity и множество других скиллов
- Для фарма можно использовать <a href="https://discord.com/channels/408315082439917578/1553927573229142027" target="_blank" rel="noopener">эту сборку</a> (буду менять по необходимости, тестируйте)

## Установка

1. Поместите `tinker_turret_dodge.lua` в `umbrella\scripts`.
2. Поместите <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a> в `umbrella\scripts`.
3. Перезагрузите Lua-скрипты.
4. Откройте настройки: `General → Tinker Turret Dodge`.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

## Что нового

**Обновление v1.1.5**

- Добавлен додж способности Monkey King `Boundless Strike` с проверкой пересечения линии удара с героем.
- Добавлен додж способности Hoodwink `Bushwhack`.
- Добавлен додж второго навыка Marci (`marci_companion_run`; название подтверждено игровыми данными).
- Добавлен додж способности Ogre Magi `Fireblast`.
- Добавлен додж способности Riki `Smoke Screen`.

---

# Tinker Turret Dodge (English)

## What it does

Tinker Turret Dodge is a Lua script for automatically placing Tinker turrets against dangerous abilities in Dota 2. It conflicts with <a href="https://discord.com/channels/408315082439917578/1552392228284923904" target="_blank" rel="noopener">Tinker Helper</a>.

- Automatic dodge: pushes Tinker away from enemy blinks and abilities
- Reacts to Black Hole, Chronosphere, Reverse Polarity, and many other skills
- For farming, you can use <a href="https://discord.com/channels/408315082439917578/1553927573229142027" target="_blank" rel="noopener">this setup</a> (I will change it as needed; please test it)

## Install

1. Place `tinker_turret_dodge.lua` in `umbrella\scripts`.
2. Place <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a> in `umbrella\scripts`.
3. Reload the Lua scripts.
4. Open settings: `General → Tinker Turret Dodge`.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.

## Changelog

**Update v1.1.5**

- Added dodge support for Monkey King's `Boundless Strike`, including a check that the strike line intersects the hero.
- Added dodge support for Hoodwink's `Bushwhack`.
- Added dodge support for Marci's second ability (`marci_companion_run`; the name was confirmed using in-game data).
- Added dodge support for Ogre Magi's `Fireblast`.
- Added dodge support for Riki's `Smoke Screen`.
