# Session Info

панель MMR, статистики матчей и текущей игровой сессии / an MMR, match-statistics, and current-session panel

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `SessionInfo.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/session_info/SessionInfo.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=session-info&expanded=true)
<!-- releases:end -->

## Что умеет

Показывает Steam-ник, MMR и прогресс до следующего ранга, статистику пяти последних матчей и итоги сессии. Панель настраивается по содержимому и внешнему виду; позицию можно сбросить. Для некоторых иконок можно указать собственные PNG в `C:\Umbrella\images\MenuIcons`.

- MMR и прогресс до следующего ранга
- Урон, K/D, networth, крипстат и роль в последних пяти матчах
- Сессионные победы, поражения, win rate и изменение MMR
- Настраиваемые элементы, цвета, шрифты, прозрачность и положение панели
- Настройки матча и отладочные логи для диагностики статистики

## Установка

1. Поместите `SessionInfo.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Other → Session Info → Main`; параметры диагностики находятся в `Settings`.
4. Для пользовательской иконки MMR положите PNG в `C:\Umbrella\images\MenuIcons` и укажите имя файла в настройках.

---

# Session Info (English)

## What it does

Displays your Steam name, MMR and progress toward the next rank, statistics from your five latest matches, and session totals. The panel's contents and appearance are configurable, and its position can be reset. Custom PNG icons can be placed in `C:\Umbrella\images\MenuIcons`.

- MMR and progress toward the next rank
- Damage, K/D, net worth, creep stats, and role for the last five matches
- Session wins, losses, win rate, and MMR change
- Configurable panel elements, colors, fonts, opacity, and position
- Match settings and debug logs for troubleshooting statistics

## Install

1. Place `SessionInfo.lua` in `umbrella\scripts`.
2. Reload Lua scripts.
3. Open `Scripts → Other → Session Info → Main`; diagnostic options are under `Settings`.
4. For a custom MMR icon, place a PNG in `C:\Umbrella\images\MenuIcons` and enter its filename in the settings.
