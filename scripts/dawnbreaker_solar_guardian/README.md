# Dawnbreaker Solar Guardian Auto-Save Helper

автоматизирует Solar Guardian для сейва и контринициации / automates Solar Guardian saves and counter-initiation

<!-- releases:start -->
Скачать: [dawnbreaker.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/dawnbreaker-solar-guardian-v1.0.0/dawnbreaker.lua) — `dawnbreaker-solar-guardian-v1.0.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`dawnbreaker-solar-guardian-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/dawnbreaker-solar-guardian-v1.0.0) | 2026-10-13 | [dawnbreaker.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/dawnbreaker-solar-guardian-v1.0.0/dawnbreaker.lua) | 3 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=dawnbreaker-solar-guardian&expanded=true)
<!-- releases:end -->

## Что умеет

Тактический помощник Dawnbreaker для глобального спасения союзников и контринициации. Важно: локальный файл, предоставленный для каталога, не является последней версией; последняя версия указана в Discord.

- Проверяет, успеет ли союзник дожить до приземления ульты, и отменяет каст, если цель погибла
- Не тратит ульту при низких HP/мане, на иллюзии, неуязвимых целях и союзниках с Aegis
- Реагирует на ключевые станы и смещает высадку к краю Chronosphere / Black Hole
- Поддерживает авто-BKB, тимфайт-ульт, перенаправление Aghanim и HUD с прогнозом лечения

## Установка

1. Поместите `dawnbreaker.lua` в `umbrella\scripts` и убедитесь, что установлен `!_qLocalizer.lua`.
2. Перезагрузите Lua-скрипты. Настройки находятся в разделе Dawnbreaker.
3. Последняя версия: <a href="https://discord.com/channels/408315082439917578/1556260601779724358/1556685245233758248" target="_blank" rel="noopener">публикация автора в Discord</a>. Загружаемый здесь файл может быть устаревшим.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Dawnbreaker Solar Guardian Auto-Save Helper (English)

## What it does

A tactical Dawnbreaker helper for global ally saves and counter-initiation. Note: the local file supplied for this catalog is not the latest version; the author links the latest version on Discord.

- Checks whether an ally can survive until the ultimate lands and cancels if the target dies
- Avoids casting at low HP/mana, illusions, invulnerable targets, and allies with Aegis
- Responds to key disables and shifts landing toward the edge of Chronosphere / Black Hole
- Includes auto-BKB, teamfight casts, Aghanim repositioning, and a HUD with heal forecasts

## Install

1. Place `dawnbreaker.lua` in `umbrella\scripts` and ensure `!_qLocalizer.lua` is installed.
2. Reload Lua scripts. Settings are under Dawnbreaker.
3. Latest version: <a href="https://discord.com/channels/408315082439917578/1556260601779724358/1556685245233758248" target="_blank" rel="noopener">the author's Discord post</a>. The file hosted here may be outdated.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
