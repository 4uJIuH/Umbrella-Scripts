# Echo BKB Dodge

автоматически нажимает BKB при блинке вражеского Earthshaker / automatically uses BKB when an enemy Earthshaker Blinks nearby

<!-- releases:start -->
Скачать: [echo_bkb_dodge.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/echo-bkb-dodge-v1.2.0/echo_bkb_dodge.lua) — `echo-bkb-dodge-v1.2.0`, 2026-10-17

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`echo-bkb-dodge-v1.2.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/echo-bkb-dodge-v1.2.0) | 2026-10-17 | [echo_bkb_dodge.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/echo-bkb-dodge-v1.2.0/echo_bkb_dodge.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=echo-bkb-dodge&expanded=true)
<!-- releases:end -->

## Что умеет

Echo BKB Dodge отслеживает подтверждённый блинк вражеского Earthshaker и использует BKB, только если Echo Slam готов, рядом достаточно союзных юнитов и предмет доступен. Автор: dofamineaddict (Discord: sn3gx).

- Реагирует на подтверждённый блинк Earthshaker рядом с героем, а не на обычное сближение
- Срабатывает, только если Echo Slam изучен, готов к применению и Шейкеру хватает маны
- Требует не менее трёх союзных юнитов вместе с вашим героем в пределах 700 единиц от вас и точки приземления; учитываются пауки Бруды, иллюзии, герои и крипы
- Проверяет доступность BKB и не отправляет повторную команду при активной невосприимчивости к эффектам
- Может не успеть защитить от мгновенной комбинации Blink и Echo Slam

## Установка

1. Поместите `echo_bkb_dodge.lua` в папку `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Other → echo_bkb_dodge → Защита → Echo Slam` и включите «Включить защиту».

---

# Echo BKB Dodge (English)

## What it does

Echo BKB Dodge watches for a confirmed Blink by an enemy Earthshaker and uses BKB only when Echo Slam is ready, enough allied units are nearby, and the item is available. Author: dofamineaddict (Discord: sn3gx).

- Reacts to a confirmed Earthshaker Blink near your hero, not ordinary movement toward you
- Triggers only when Echo Slam is learned and ready and Earthshaker has enough mana
- Requires at least three allied units including your hero within 700 units of you and the landing point; Broodmother spiders, illusions, heroes, and creeps count
- Checks that BKB is available and avoids another command while debuff immunity is already active
- May not protect against an instant Blink-and-Echo Slam combo

## Install

1. Place `echo_bkb_dodge.lua` in the `umbrella\scripts` folder.
2. Reload the Lua scripts.
3. Open `Scripts → Other → echo_bkb_dodge → Защита → Echo Slam` and enable “Включить защиту”.
