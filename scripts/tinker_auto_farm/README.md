# Tinker Auto Farm

автоматический фарм на Тинкере / automatic farming on Tinker

<!-- releases:start -->
Релизов пока нет. No releases yet.

[Релизы на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=tinker-auto-farm&expanded=true)
<!-- releases:end -->

## Что умеет

Скрипт для автоматического фарма на Тинкере. Поддерживает фарм леса, линии и только безопасных линий под вышкой.

- Три режима: «Фарм леса», «Фарм линии», «Фарм только безопасных линий под вышкой»
- Автоматический Blink при опасности
- Карта выбора кемпов для фарма, открывается по бинду
- «Фарм леса» — фарм выбранных на карте кемпов
- «Фарм линии» — фармит под вышкой и за ней; улучшенная логика поиска врагов, не рекомендуется к использованию
- «Безопасные линии под вышкой» — при волне в радиусе 1400 от вышки Тинкер прилетает к ней, использует March, возвращается Blink и продолжает фарм
- Поддерживает совместную работу с <a href="https://discord.com/channels/408315082439917578/1551292946576580648" target="_blank" rel="noopener">этим скриптом</a>

## Установка

1. Скачайте и распакуйте `Tinker-Auto-Farm.zip`.
2. Поместите `Tinker.lua` и папку `lib` в `umbrella\scripts`.
3. Перезагрузите Lua-скрипты.
4. Откройте настройки: `Scripts → Scripts → Tinker`.

---

# Tinker Auto Farm (English)

## What it does

A script for automatic farming on Tinker. Supports jungle, lane, and safe-lane-under-tower farming modes.

- Three modes: Farm Woods, Farm Lane, and Farm Only Safe Lanes Under Tower
- Automatically Blinks when in danger
- A map for selecting which camps to farm, opened with a bind
- Farm Woods farms the camps selected on the map
- Farm Lane farms under and beyond the tower; enemy detection was improved, but this mode is not recommended for use
- Safe Lanes Under Tower sends Tinker to a creep wave within 1400 range of a tower, casts March, Blinks back, and continues farming
- Supports working together with <a href="https://discord.com/channels/408315082439917578/1551292946576580648" target="_blank" rel="noopener">this script</a>

## Install

1. Download and extract `Tinker-Auto-Farm.zip`.
2. Place `Tinker.lua` and the `lib` folder in `umbrella\scripts`.
3. Reload the Lua scripts.
4. Open settings: `Scripts → Scripts → Tinker`.
