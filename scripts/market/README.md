# Script Market

устанавливает, удаляет и обновляет скрипты из ScriptIvMarket / installs, removes, and updates scripts from ScriptIvMarket

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `market.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/market/market.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=market&expanded=true)
<!-- releases:end -->

## Что умеет

Клиент каталога ScriptIvMarket: получает список скриптов и загружает их по ссылкам upstream-проекта. Авторство скриптового клиента — Ромбит и команда; список скриптов и адрес автообновления находятся в проекте madonchik123/ScriptIvMarket.

- Устанавливает и удаляет доступные скрипты
- Обновляет установленные скрипты и умеет обновить сам Market
- При запуске автоматически проверяет каталог и обновляет установленные позиции
- Важно: Market записывает загруженный Lua-код в `umbrella\scripts` и может перезаписывать существующие файлы

## Установка

1. Поместите `market.lua` в `umbrella\scripts` и перезагрузите Lua-скрипты.
2. Откройте `Scripts → Other → Market`.
3. Проверьте источник загружаемых скриптов в меню перед установкой.

---

# Script Market (English)

## What it does

A ScriptIvMarket catalog client that fetches its script list and downloads scripts from the upstream project. The client is credited to RomBit and team; the script list and update endpoint are hosted in madonchik123/ScriptIvMarket.

- Installs and removes available scripts
- Updates installed scripts and can update the Market client itself
- Checks the catalog at startup and updates installed entries automatically
- Important: Market writes downloaded Lua code into `umbrella\scripts` and may overwrite existing files

## Install

1. Place `market.lua` in `umbrella\scripts` and reload Lua scripts.
2. Open `Scripts → Other → Market`.
3. Review the source of scripts listed in the menu before installing them.
