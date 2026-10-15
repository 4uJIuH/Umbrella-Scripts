# Tinker Auto Farm

автоматический фарм на Тинкере / automatic farming on Tinker

<!-- releases:start -->
Скачать: [Tinker-Auto-Farm.zip](https://github.com/4uJIuH/umbrella-scripts/releases/download/tinker-auto-farm-v1.0.4/Tinker-Auto-Farm.zip) — `tinker-auto-farm-v1.0.4`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`tinker-auto-farm-v1.0.4`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/tinker-auto-farm-v1.0.4) | 2026-10-13 | [Tinker-Auto-Farm.zip](https://github.com/4uJIuH/umbrella-scripts/releases/download/tinker-auto-farm-v1.0.4/Tinker-Auto-Farm.zip) | 7 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=tinker-auto-farm&expanded=true)
<!-- releases:end -->

## Что умеет

Скрипт для автоматического фарма на Тинкере. Поддерживает фарм леса, линии и только безопасных линий под вышкой.

- Три режима: «Фарм леса», «Фарм линии», «Фарм только безопасных линий под вышкой»
- Автоматический Blink при опасности
- В Script Manager 2.0.2+ устанавливает `Tinker.lua` и все файлы `lib` одной кнопкой
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

## Что нового

**update v1.0.4**

- Script Manager теперь устанавливает `Tinker.lua` и файлы из `lib` автоматически; ручная установка из ZIP остается доступна.

**update v1.0.3**

- Добавлено 3-секундное окно после респавна: лагерь не считается пустым из-за проверки в самый момент появления крипов. Ожидание в безопасной точке завершается на ближайшей проверке после респавна.
- Скорректирована оценка маны для похода к лагерю: теперь учитывается Rearm, если он понадобится до первого March. Это должно предотвратить ситуации, когда герой прилетает и уходит, так и не начав фарм.
- March теперь выбирает направление по фактическому расположению крипов в выбранном лагере, включая лагерь древних, вместо фиксированного направления на центр.
- Убран запуск March по таймеру, когда на линии не обнаружено живых крипов, чтобы не тратить его впустую.
- Повышен приоритет фарма двойного лагеря под аванпостом.
- Улучшена общая производительность и скорость.

---

# Tinker Auto Farm (English)

## What it does

A script for automatic farming on Tinker. Supports jungle, lane, and safe-lane-under-tower farming modes.

- Three modes: Farm Woods, Farm Lane, and Farm Only Safe Lanes Under Tower
- Automatically Blinks when in danger
- Script Manager 2.0.2+ installs `Tinker.lua` and all `lib` files with one click
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

## Changelog

**update v1.0.4**

- Script Manager now installs `Tinker.lua` and the files in `lib` automatically; manual installation from the ZIP remains available.

**update v1.0.3**

- Added a 3-second window after respawn: the camp is not declared empty due to a check at the exact moment the creeps spawn. Waiting at the safe spot ends at the nearest check after respawn.
- Adjusted the mana evaluation for going to the camp: Rearm is now taken into account if it will be needed before the first March. This should prevent situations where the hero flies in and leaves without starting to farm.
- March now chooses its direction based on the actual location of the creeps in the selected camp, including the ancient camp, instead of a fixed direction toward the center.
- Removed the timer-based launch of March when no living creeps are detected in the lane, so as not to waste it on nothing.
- Increased the farming priority of the double camp under the outpost.
- Improved overall performance and speed.
