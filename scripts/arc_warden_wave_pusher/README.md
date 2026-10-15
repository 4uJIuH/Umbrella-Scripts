# Arc Warden Wave Pusher

умный пуш крип-волн клоном Arc Warden / smart creep-wave pushing with Arc Warden's clone

<!-- releases:start -->
Скачать: [ArcWardenWavePusher.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/arc-warden-wave-pusher-v1.0.0/ArcWardenWavePusher.lua) — `arc-warden-wave-pusher-v1.0.0`, 2026-10-15

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`arc-warden-wave-pusher-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/arc-warden-wave-pusher-v1.0.0) | 2026-10-15 | [ArcWardenWavePusher.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/arc-warden-wave-pusher-v1.0.0/ArcWardenWavePusher.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=arc-warden-wave-pusher&expanded=true)
<!-- releases:end -->

## Что умеет

Дополнение для автоигры клона Arc Warden: помогает эффективнее забирать крипов волны, распределяя атаки и Spark Wraith по приоритетным целям. После дальников и знаменосца отдаёт зачистку мили-крипов и вышек базовому скрипту; при комбо по герою уступает управление.

- Рассчитывает урон Spark Wraith и планирует атаки по дальним крипам, чтобы не тратить лишние удары
- Приоритет целей: дальники, затем знаменосец, затем мили-крипы
- Выбирает позицию для атаки дальников и знаменосца и ставит Magnetic Field под клона
- Подсвечивает текущую цель кольцом: голубым для дальника, золотым для знаменосца
- Передаёт зачистку мили-крипов и вышек базовому скрипту и уступает ему во время комбо по герою

## Установка

1. Поместите `ArcWardenWavePusher.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Heroes → Hero List → Arc Warden → Clone Settings → Auto Play Settings → Умный пуш пачек`.

---

# Arc Warden Wave Pusher (English)

## What it does

An add-on for Arc Warden clone auto-play that helps secure more lane creeps by prioritizing attacks and Spark Wraiths. After ranged creeps and the flagbearer are handled, it yields melee creeps and towers to the base script; it also yields control during hero combos.

- Accounts for Spark Wraith damage and plans attacks on ranged creeps to avoid wasted hits
- Target priority: ranged creeps, then the flagbearer, then melee creeps
- Positions to reach ranged creeps and the flagbearer, and places Magnetic Field under the clone
- Highlights the current target with a ring: cyan for ranged creeps and gold for the flagbearer
- Yields melee creep and tower cleanup to the base script and yields during hero combos

## Install

1. Place `ArcWardenWavePusher.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Heroes → Hero List → Arc Warden → Clone Settings → Auto Play Settings → Умный пуш пачек`.
