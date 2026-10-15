# Synoptic Forecast

шутливый прогноз погоды по текущей обстановке на линиях / a playful weather forecast based on current lane activity

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `synoptic.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/synoptic_forecast/synoptic.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=synoptic-forecast&expanded=true)
<!-- releases:end -->

## Что умеет

Раз в несколько минут игрового времени оценивает видимых и пропавших врагов и недавние смерти союзников на линиях, после чего выпускает шуточный прогноз. По умолчанию прогноз отправляется в союзный чат; включите «Только себе», если не хотите отправлять сообщения.

- Учитывает видимых и пропавших врагов, недавние смерти союзников и число невидимых противников
- По умолчанию выпускает прогноз каждые 5 минут игрового времени; интервал настраивается
- Можно запросить прогноз биндом, скрыть его из чата и показывать только себе
- Можно включить имена пропавших героев и случайную шутку в конце
- Строки прогноза отправляются в союзный чат с паузой между сообщениями

## Установка

1. Поместите `synoptic.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Utility → Синоптик`.

---

# Synoptic Forecast (English)

## What it does

Every few minutes of game time, checks visible and missing enemies and recent allied deaths on the lanes, then posts a playful forecast. Forecasts are sent to allied chat by default; enable “Only for me” to avoid sending messages.

- Considers visible and missing enemies, recent allied deaths, and how many enemies are unseen
- Posts a forecast every 5 minutes of game time by default; the interval is configurable
- Request a forecast with a bind, keep it out of chat, and show it only to yourself
- Optionally name missing heroes and add a random joke at the end
- Forecast lines are sent to allied chat with a pause between messages

## Install

1. Place `synoptic.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Scripts → Utility → Синоптик`.
