# Huskar Life Break

прерывает полёт Life Break, сохраняя попадание ульты / stops Life Break travel while preserving the ultimate hit

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `huskar_life_break.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/huskar_life_break/huskar_life_break.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=huskar-life-break&expanded=true)
<!-- releases:end -->

## Что умеет

Комбо для Хускара: прыжок ультой по цели, затем предметом остановить движение, пока снаряд Life Break продолжает полёт.

- Клавиша запускает Life Break по цели под курсором и предмет во время прыжка
- Поддерживает Blink и Hurricane Pike; Blink направляется назад от цели или к курсору
- Повторяет приказ предмета во время полёта и останавливает Хускара после попадания
- Бинд по умолчанию — T

## Установка

1. Поместите `huskar_life_break.lua` и `!_qLocalizer.lua` в `umbrella\scripts`.
2. Перезагрузите скрипты. Меню: Heroes → Hero List → Huskar → Life Break.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Huskar Life Break (English)

## What it does

A Huskar combo that casts Life Break on the target, then uses an item to stop movement while the Life Break projectile continues.

- A hotkey casts Life Break on the target under the cursor, then uses an item during the leap
- Supports Blink and Hurricane Pike; Blink can go behind the target or toward the cursor
- Retries the item order during flight and stops Huskar after the hit
- Default hotkey: T

## Install

1. Place `huskar_life_break.lua` and `!_qLocalizer.lua` in `umbrella\scripts`.
2. Reload scripts. Menu: Heroes → Hero List → Huskar → Life Break.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
