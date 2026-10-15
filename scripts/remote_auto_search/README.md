# Remote Auto Search

запускает поиск матча удалённой командой через ntfy.sh / starts matchmaking from a remote ntfy.sh command

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `remote.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/remote_auto_search/remote.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=remote-auto-search&expanded=true)
<!-- releases:end -->

## Что умеет

Позволяет удалённо запускать очередь поиска матча через сообщения в ntfy.sh и настраивать режим, регион и тип игры. Также содержит запись параметров поиска, автоочередь после матча и необязательную интеграцию с локальным Key Emulator. Любой, кто узнает имя ntfy-топика, сможет отправить команду запуска очереди.

- Удалённый запуск поиска через ntfy-команды
- Выбор режимов игры, регионов, рейтингового типа и роли
- Необязательный автоматический поиск после окончания игры
- Встроенные запись параметров поиска и локальный Key Emulator

## Установка

1. Поместите `remote.lua` в `umbrella\scripts` и перезагрузите Lua-скрипты.
2. Настройте режимы и регионы в `Miscellaneous → Other → Message Recorder → Main → Auto Search Game`.
3. Для удалённого запуска задайте уникальный приватный топик в `Ntfy Remote Queue`; топик является секретом — не публикуйте и не переиспользуйте его.
4. Сообщение `start_queue` в топике запускает поиск матча. Отключите `Enable remote queue`, если удалённые команды не нужны.
5. Автоочередь после матча включена по умолчанию; отключите её, если не хотите автоматически искать следующую игру.

---

# Remote Auto Search (English)

## What it does

Lets you remotely start matchmaking through ntfy.sh messages and configure game mode, region, and match type. It also includes queue recording, auto-queue after a match, and optional integration with a local Key Emulator. Anyone who learns the ntfy topic name can send a queue-start command.

- Remote matchmaking start through ntfy commands
- Select game modes, regions, ranked type, and role
- Optional auto-queue after a match ends
- Built-in search recording and local Key Emulator

## Install

1. Place `remote.lua` in `umbrella\scripts` and reload Lua scripts.
2. Configure modes and regions under `Miscellaneous → Other → Message Recorder → Main → Auto Search Game`.
3. For remote start, set a unique private topic under `Ntfy Remote Queue`; treat the topic as a secret and do not publish or reuse it.
4. Sending `start_queue` to the topic starts matchmaking. Disable `Enable remote queue` if you do not need remote commands.
5. Auto-queue after a match is enabled by default; disable it if you do not want another search to start automatically.
