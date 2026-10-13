# Chat Translator

перевод сообщений игрового чата между английским и русским / translates in-game chat messages between English and Russian

<!-- releases:start -->
Скачать: [chat_translator.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/chat-translator-v1.0.0/chat_translator.lua) — `chat-translator-v1.0.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`chat-translator-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/chat-translator-v1.0.0) | 2026-10-13 | [chat_translator.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/chat-translator-v1.0.0/chat_translator.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=chat-translator&expanded=true)
<!-- releases:end -->

## Что умеет

Автоматически переводит сообщения игроков в чате с английского на русский и наоборот, с выбором направления. По желанию может переводить ваши русские сообщения на английский перед отправкой. Автор: фригидный [разум] (Discord: .emocry). Встроенная библиотека qLocalization — qfun (qfun_g9s).

- Направление перевода: английский → русский, русский → английский или в обе стороны
- Возможность пропускать собственные входящие сообщения
- Пропуск игровых сокращений и фраз вроде `gg`, `wp`, `ez`, `ty`, `gl hf` и `nt`
- Перевод собственных русских сообщений перед отправкой; сообщения, начинающиеся с `-`, не перехватываются
- Кэширует переводы и использует цепочку Google, Yandex, Microsoft Edge и Lingva
- MyMemory выключен по умолчанию: его можно включить как последний резерв, но отдельные слова он может переводить неточно
- При ошибках временно пропускает недоступный сервис
- Настраиваемые цвета ника и перевода, имя игрока или героя

Текст отправляется выбранным внешним сервисам перевода. MyMemory используется только после включения соответствующего параметра.

## Установка

1. Поместите `chat_translator.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Scripts → Chat Translator` и включите скрипт.
4. Выберите направление перевода. Настройки цветов находятся в шестерёнке; MyMemory при необходимости включается отдельно.

## Что нового

# 1.0.0

- Первый релиз «Переводчика чата».
- Добавлен автоматический перевод сообщений чата между английским и русским с выбором направления.
- Добавлены кэш переводов, пропуск игровых сокращений и резервная цепочка сервисов перевода.
- Добавлен необязательный перевод собственных сообщений перед отправкой.

---

# Chat Translator (English)

## What it does

Automatically translates players' chat messages between English and Russian, with a configurable direction. It can optionally translate your own Russian messages before sending. Author: фригидный [разум] (Discord: .emocry). Bundled qLocalization library by qfun (qfun_g9s).

- Choose English to Russian, Russian to English, or both directions
- Optionally skip your own incoming messages
- Skips common gaming abbreviations and phrases such as `gg`, `wp`, `ez`, `ty`, `gl hf`, and `nt`
- Optionally translates your own Russian messages before sending; messages beginning with `-` are not intercepted
- Caches translations and tries Google, Yandex, Microsoft Edge, and Lingva in sequence
- MyMemory is off by default; it can be enabled as a last resort, but may translate individual words inaccurately
- Temporarily skips unavailable services after errors
- Configurable nickname and translation colors; displays the player name or hero name

Chat text is sent to the selected external translation services. MyMemory is only used when explicitly enabled.

## Install

1. Place `chat_translator.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Scripts → Scripts → Chat Translator` and enable the script.
4. Choose a translation direction. Color options are in the gear menu; enable MyMemory separately if needed.

## Changelog

# 1.0.0

- Initial Chat Translator release.
- Added automatic English/Russian chat translation with a configurable direction.
- Added a translation cache, common gaming phrase skips, and a fallback chain of translation services.
- Added optional translation of your own messages before sending.
