# MMR Log

ведёт журнал MMR и ежедневную статистику матчей / tracks MMR changes and daily match statistics

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `mmr_log.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/mmr_log/mmr_log.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=mmr-log&expanded=true)
<!-- releases:end -->

## Что умеет

Сохраняет match ID, героя, длительность матча и изменение MMR в `mmr_log.csv`, а дневную статистику побед, поражений и MMR — в `mmr_daily.txt` в папке Umbrella. Для синхронизации замените `YOUR_ACCOUNT_ID_HERE` на свой игровой Dota ID.

- Общий CSV-журнал матчей и изменения MMR
- Дневной итог MMR, побед и поражений
- Статистика по герою, времени начала и длительности матчей
- Для синхронизации требуется указать свой account ID в файле скрипта

## Установка

1. Поместите `mmr_log.lua` в `umbrella\scripts`.
2. Перед использованием замените `YOUR_ACCOUNT_ID_HERE` на свой игровой Dota ID.
3. Перезагрузите Lua-скрипты.
4. Откройте `MMR Tracker → Stats → Overview`; файлы статистики создаются в папке Umbrella.

---

# MMR Log (English)

## What it does

Saves match ID, hero, match duration, and MMR change to `mmr_log.csv`, with daily wins, losses, and MMR totals in `mmr_daily.txt` in the Umbrella folder. Replace `YOUR_ACCOUNT_ID_HERE` with your in-game Dota account ID to enable syncing.

- Overall match and MMR-change CSV log
- Daily MMR, win, and loss summary
- Statistics by hero, match start time, and duration
- Requires your account ID to be set in the script

## Install

1. Place `mmr_log.lua` in `umbrella\scripts`.
2. Before use, replace `YOUR_ACCOUNT_ID_HERE` with your in-game Dota account ID.
3. Reload Lua scripts.
4. Open `MMR Tracker → Stats → Overview`; log files are created in the Umbrella folder.
