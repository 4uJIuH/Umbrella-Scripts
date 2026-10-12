# Rune Destruction

отправка подконтрольных юнитов к рунам / send controlled units to runes

<!-- releases:start -->
Скачать: [rune_units.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/rune-destruction-v1.0.2/rune_units.lua) — `rune-destruction-v1.0.2`, 2026-10-10

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`rune-destruction-v1.0.2`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/rune-destruction-v1.0.2) | 2026-10-10 | [rune_units.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/rune-destruction-v1.0.2/rune_units.lua) | 1 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=rune-destruction&expanded=true)
<!-- releases:end -->

## Что умеет

Lua-скрипт для отправки подконтрольных юнитов к рунам в Dota 2.

- Автоматически отправляет подконтрольных юнитов к местам появления водяных, усиленных рун и рун богатства
- Поддерживает автоматический режим и отправку выделенных юнитов по кнопке
- Заранее отправляет юнитов; время до появления руны настраивается
- Позволяет выбрать, какие руны собирать или атаковать, и указать типы усиленных рун
- Не трогает руну, если рядом союзный герой; при близком враге атакует её
- Скрипт и обновление v1.0.2: <a href="https://discord.com/channels/408315082439917578/1552492995578691646/1552642997940916317" target="_blank" rel="noopener">Discord</a>

## Установка

1. Поместите <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/rune-destruction-v1.0.2/rune_units.lua" target="_blank" rel="noopener"><code>rune_units.lua</code></a> в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте настройки: `Scripts → Rune Units`.

## Что нового

**Rune Destruction v1.0.2**

- Удалены отладочные логи.
- Добавлены настройки радиуса поиска врагов и союзников (значения по умолчанию: союзники — 2000, враги — 1000).
- Добавлена настройка «Всегда ломать руну».
- Добавлена поддержка любых подконтрольных иллюзий.

---

# Rune Destruction (English)

## What it does

A Lua script for sending controlled units to runes in Dota 2.

- Automatically sends controlled units to water, power, and bounty rune spawn locations
- Supports automatic mode and sending selected units with a hotkey
- Sends units ahead of the spawn time, which can be configured
- Choose which runes to collect or deny, and which power rune types to target
- Leaves a rune alone when an allied hero is nearby; attacks it if an enemy is close
- Script and v1.0.2 update: <a href="https://discord.com/channels/408315082439917578/1552492995578691646/1552642997940916317" target="_blank" rel="noopener">Discord</a>

## Install

1. Place <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/rune-destruction-v1.0.2/rune_units.lua" target="_blank" rel="noopener"><code>rune_units.lua</code></a> in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open settings: `Scripts → Rune Units`.

## Changelog

**Rune Destruction v1.0.2**

- Removed debug logs.
- Added enemy and ally search radius settings (defaults: allies — 2000, enemies — 1000).
- Added the "Always break rune" setting.
- Added support for any controllable illusions.
