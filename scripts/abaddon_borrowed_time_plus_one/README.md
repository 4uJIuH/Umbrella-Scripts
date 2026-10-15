# Abaddon Borrowed Time+1

берёт ульт Abaddon, когда ожидается опасный урон / learns Abaddon's ultimate when dangerous damage is predicted

<!-- releases:start -->
Последняя версия: [`v1.0.0-beta.1` — `borrowed_time_plus_one.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/abaddon_borrowed_time_plus_one/borrowed_time_plus_one.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=abaddon-borrowed-time-plus-one&expanded=true)
<!-- releases:end -->

## Что умеет

Оценивает ожидаемый урон по Abaddon за выбранное окно времени и при угрозе изучает Borrowed Time, если ульт ещё не прокачан. Бета-скрипт; автор отмечает, что некоторые внезапные источники урона невозможно предсказать заранее.

- Настраиваемые окно прогноза урона и порог здоровья
- Изучает ультимейт при расчётной угрозе, в том числе во время контроля
- Панель визуализации для отладки
- Бета-версия; отдельные способности и форс-ситуации могут не учитываться

## Установка

1. Поместите `borrowed_time_plus_one.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Найдите `borrowed time` в настройках Abaddon; раздел может находиться в `Auto Usage` или быть создан рядом.

---

# Abaddon Borrowed Time+1 (English)

## What it does

Estimates incoming damage to Abaddon over a configurable time window and learns Borrowed Time when danger is detected and the ultimate is unlearned. This is a beta script; the author notes that sudden damage sources cannot always be predicted.

- Configurable damage-prediction window and health threshold
- Learns the ultimate when danger is predicted, including while disabled
- Debug visualization overlay
- Beta release; some abilities and edge cases may not be detected

## Install

1. Place `borrowed_time_plus_one.lua` in `umbrella\scripts`.
2. Reload Lua scripts.
3. Find `borrowed time` in Abaddon's settings; it may be under `Auto Usage` or created alongside it.
