# Toxic Chat Guard

локально выявляет токсичные сообщения в игровом чате / locally detects toxic messages in in-game chat

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `ToxicChatGuard.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/toxic_chat_guard/ToxicChatGuard.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=toxic-chat-guard&expanded=true)
<!-- releases:end -->

## Что умеет

Анализирует полученные сообщения по настраиваемым правилам и показывает уведомления и журнал обнаружений. Порог, словари и параметры оверлея настраиваются; сообщения не отправляются наружу.

- Оценка сообщений по совпадениям с настраиваемыми категориями слов
- Уведомления, звук, журнал событий и HUD-оверлей
- Настройка порога обнаружения и хранения журнала

## Установка

1. Поместите `ToxicChatGuard.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Utility → Toxic Chat Guard`.

---

# Toxic Chat Guard (English)

## What it does

Analyzes received messages using configurable rules and shows notifications and a detection log. Thresholds, word matching, and overlay options are configurable; messages are not sent externally.

- Scores messages against configurable word categories
- Notifications, sound, event log, and HUD overlay
- Configurable detection threshold and log retention

## Install

1. Place `ToxicChatGuard.lua` in `umbrella\scripts`.
2. Reload Lua scripts.
3. Open `Scripts → Utility → Toxic Chat Guard`.
