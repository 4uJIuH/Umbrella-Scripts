# HP/Mana 67 Ping

сообщения при достижении значений HP и маны, оканчивающихся на 67 / chat messages when HP or mana reaches a value ending in 67

<!-- releases:start -->
Скачать: [hp_mana_67_ping.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/hp-mana-67-ping-v1.0.1/hp_mana_67_ping.lua) — `hp-mana-67-ping-v1.0.1`, 2026-10-10

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`hp-mana-67-ping-v1.0.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/hp-mana-67-ping-v1.0.1) | 2026-10-10 | [hp_mana_67_ping.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/hp-mana-67-ping-v1.0.1/hp_mana_67_ping.lua) | 1 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=hp-mana-67-ping&expanded=true)
<!-- releases:end -->

## Что умеет

Lua-скрипт для Dota 2, который отслеживает здоровье и ману и отправляет сообщение в общий чат при достижении отображаемого значения, оканчивающегося на 67.

- После нажатия бинда отслеживает HP и ману и срабатывает на отображаемых значениях от 67 до 6767, оканчивающихся на 67
- После отправки сообщения отслеживание останавливается; для нового цикла нажмите бинд снова
- Можно задать отдельные пользовательские сообщения для HP и маны; если поля пусты, используются стандартные сообщения
- Отдельный бинд независимо отслеживает достижение 67% HP или маны и отправляет стандартный игровой alert
- Русский и английский интерфейс через qLocalization
- Скрипт и обновление 1.0.1: <a href="https://discord.com/channels/408315082439917578/1550937404464955572/1550952857640108106" target="_blank" rel="noopener">Discord</a>

## Установка

1. Поместите <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/hp-mana-67-ping-v1.0.1/hp_mana_67_ping.lua" target="_blank" rel="noopener"><code>hp_mana_67_ping.lua</code></a> в `umbrella\scripts`.
2. Убедитесь, что рядом находится <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a>.
3. Перезагрузите Lua-скрипты.
4. Откройте настройки: `General → HP/Mana 67 Ping → Settings`.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

## Что нового

## Обновление 1.0.1

- При достижении 67% HP или маны отправляется стандартный игровой alert.
- Добавлен отдельный бинд для независимого отслеживания достижения 67%.

---

# HP/Mana 67 Ping (English)

## What it does

A Dota 2 Lua script that tracks the hero's health and mana and sends a message to all chat when a displayed value ending in 67 is reached.

- After pressing the bind, tracks HP and mana and triggers on displayed values from 67 to 6767 that end in 67
- Tracking stops after a message is sent; press the bind again to start a new cycle
- Set separate custom messages for HP and mana; default messages are used when the fields are empty
- A separate bind independently tracks when HP or mana reaches 67% and sends the standard in-game alert
- Russian and English interface through qLocalization
- Script and 1.0.1 update: <a href="https://discord.com/channels/408315082439917578/1550937404464955572/1550952857640108106" target="_blank" rel="noopener">Discord</a>

## Install

1. Place <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/hp-mana-67-ping-v1.0.1/hp_mana_67_ping.lua" target="_blank" rel="noopener"><code>hp_mana_67_ping.lua</code></a> in `umbrella\scripts`.
2. Make sure <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a> is alongside it.
3. Reload the Lua scripts.
4. Open settings: `General → HP/Mana 67 Ping → Settings`.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.

## Changelog

## Update 1.0.1

- Sends the standard in-game alert when HP or mana reaches 67%.
- Added a separate bind to track reaching 67% independently.
