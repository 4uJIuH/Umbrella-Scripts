# Ntfy Match Notifier

отправляет push-уведомление при принятии матча / sends a push notification when a match is accepted

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `notify.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/ntfy_match_notifier/notify.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=ntfy-match-notifier&expanded=true)
<!-- releases:end -->

## Что умеет

При входе Dota 2 в фазу выбора героя отправляет уведомление через ntfy.sh на подписанный телефон или другое устройство. Имя топика хранится в настройках скрипта.

- Уведомляет о переходе в фазу выбора героя
- Тестовое уведомление для проверки топика
- Переключатель уведомлений и очистка топика

## Установка

1. Установите приложение ntfy и подпишитесь на уникальный приватный топик.
2. Поместите `notify.lua` в `umbrella\scripts` и перезагрузите Lua-скрипты.
3. Откройте `UCZone → Utilities → Ntfy → Match Notifier → On Accept/Resolve` и укажите имя топика.
4. Считайте имя топика секретом: любой, кто его знает, может отправить туда уведомление.

---

# Ntfy Match Notifier (English)

## What it does

When Dota 2 enters hero selection, sends a notification through ntfy.sh to a subscribed phone or other device. The topic name is stored in the script settings.

- Notifies you when hero selection begins
- Test notification to verify the topic
- Notification toggle and topic clearing

## Install

1. Install the ntfy app and subscribe to a unique private topic.
2. Place `notify.lua` in `umbrella\scripts` and reload Lua scripts.
3. Open `UCZone → Utilities → Ntfy → Match Notifier → On Accept/Resolve` and enter the topic name.
4. Treat the topic name as a secret: anyone who knows it can send notifications to it.
