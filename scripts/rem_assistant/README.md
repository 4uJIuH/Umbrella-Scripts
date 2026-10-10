# Rem Assistant

ассистент способностей и лечения для Rem в Deadlock / ability and healing assistant for Rem in Deadlock

<!-- releases:start -->
Скачать: [Rem_Assistant.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/rem-assistant-v1.0.0/Rem_Assistant.lua) — `rem-assistant-v1.0.0`, 2026-10-10

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`rem-assistant-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/rem-assistant-v1.0.0) | 2026-10-10 | [Rem_Assistant.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/rem-assistant-v1.0.0/Rem_Assistant.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=rem-assistant&expanded=true)
<!-- releases:end -->

## Что умеет

Скрипт для героя Rem в Deadlock. Автоматизирует способности и лечение союзников, предсказывает движение и помогает попадать по движущимся целям.

- Предсказывает движение целей и выбирает хитбоксы тела, исключая голову
- Улучшенный Skill 1 с Magic Bullet и поиском обхода препятствий
- Может пропускать парирование и неуязвимость; проверка настраивается отдельной галочкой
- Автоматически лечит союзников вторым скиллом, поддерживает цепное лечение и автопродолжение
- Выбирает приоритет целей по минимальному HP или расстоянию
- Автоматически удерживает Alt-Cast, пока Rem прикреплён к цели
- Автоматически использует Lil Helpers и проверяет активный Helping Hands
- Поддерживает цели: ящики, статуи, Sinner’s Sacrifice, знаменосцы, крипы и игроки
- Фильтр игроков учитывает участие в бою и дистанцию до врага
- Скрипт самодостаточный: aim.lua, prediction.lua, utils.lua и ally_manager.lua не требуются; улучшены производительность и FPS

## Установка

1. Поместите <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/rem-assistant-v1.0.0/Rem_Assistant.lua" target="_blank" rel="noopener"><code>Rem_Assistant.lua</code></a> в `%cheat_dir%/deadlock_scripts`.
2. Поместите туда же обязательный <a href="https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/tinker_turret_dodge/!_qLocalizer.lua" target="_blank" rel="noopener"><code>!_qLocalizer.lua</code></a> для переводов.
3. Перезагрузите Lua-скрипты.
4. Откройте настройки: `Heroes → Hero List → Rem → Rem Assistant`.

## Что нового

**Версия 1.0.0**

- Повышена точность первого скилла; проверка видимости теперь использует реальную дистанцию до цели.
- Скрипт стал самодостаточным: aim.lua, prediction.lua, utils.lua и ally_manager.lua больше не нужны.
- Трекинг скорости врагов обновляется каждый тик и не сбрасывается при повторных вызовах в одном кадре.
- Финальная точка Magic Bullet согласована с точкой поиска обхода.
- Исправлена блокировка каста второго скилла и устранено залипание при выборе цели.
- Повышена производительность и FPS.
- Доработана логика второго скилла; исправлено применение первого без включённого переключателя.
- Добавлены английский перевод, режим выстрела при удержании клавиши первого скилла и корректная работа переключателей, слайдеров, биндов и выбора целей через qLocalization.

---

# Rem Assistant (English)

## What it does

A script for Rem in Deadlock that automates abilities and ally healing, predicts movement, and improves accuracy against moving targets.

- Predicts target movement and selects body hitboxes while excluding the head
- Improved Skill 1 with Magic Bullet and obstacle bypass
- Can skip parrying and invulnerable targets with a separate toggle
- Automatically heals allies with Skill 2, with chain healing and automatic continuation
- Prioritizes targets by lowest HP or distance
- Automatically holds Alt-Cast while Rem is attached
- Automatically uses Lil Helpers and checks for active Helping Hands
- Supports boxes, statues, Sinner’s Sacrifice, banner carriers, creeps, and players as targets
- Player filtering checks combat participation and distance to enemies
- Standalone script: aim.lua, prediction.lua, utils.lua, and ally_manager.lua are no longer required; performance and FPS are improved

## Install

1. Place <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/rem-assistant-v1.0.0/Rem_Assistant.lua" target="_blank" rel="noopener"><code>Rem_Assistant.lua</code></a> in `%cheat_dir%/deadlock_scripts`.
2. Place the required <a href="https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/tinker_turret_dodge/!_qLocalizer.lua" target="_blank" rel="noopener"><code>!_qLocalizer.lua</code></a> alongside it for translations.
3. Reload the Lua scripts.
4. Open settings: `Heroes → Hero List → Rem → Rem Assistant`.

## Changelog

**Version 1.0.0**

- Improved Skill 1 accuracy; visibility checks now use the real distance to the target.
- Made the script standalone: aim.lua, prediction.lua, utils.lua, and ally_manager.lua are no longer required.
- Enemy speed tracking now warms up every tick and is not reset by repeated calls in the same frame.
- Aligned the final Magic Bullet point with the obstacle-bypass search point.
- Fixed Skill 2 cast blocking and target-selection lockups.
- Improved performance and FPS.
- Improved Skill 2 logic and fixed Skill 1 being used automatically while its switch is disabled.
- Added English translation, hold-to-shoot for Skill 1, and correct qLocalization handling for switches, sliders, binds, and target selection.
