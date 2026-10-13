# Chat Translator

автоматически переводит игровой чат между английским и русским / automatically translates in-game chat between English and Russian

<!-- releases:start -->
Скачать: [chat_translator.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/chat-translator-v1.0.0/chat_translator.lua) — `chat-translator-v1.0.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`chat-translator-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/chat-translator-v1.0.0) | 2026-10-13 | [chat_translator.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/chat-translator-v1.0.0/chat_translator.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=chat-translator&expanded=true)
<!-- releases:end -->

## Что умеет

Chat Translator переводит сообщения игроков с выбором направления: английский → русский, русский → английский или в обе стороны. По желанию переводит ваши русские сообщения перед отправкой. Автор: фригидный [разум] (Discord: .emocry). Текст отправляется внешним сервисам перевода; MyMemory выключен по умолчанию.

- Выбор направления: английский → русский, русский → английский или в обе стороны
- Опция пропуска собственных входящих сообщений
- Пропускает игровые сокращения и фразы вроде gg, wp, ez, ty, gl hf и nt
- Может переводить собственные русские сообщения на английский перед отправкой; строки, начинающиеся с дефиса, пропускаются
- Кэширует переводы и пробует Google, Yandex, Microsoft Edge и Lingva по очереди
- MyMemory — необязательный резервный сервис; отдельные слова может переводить неточно
- При ошибке временно пропускает сервис перевода
- Настраиваемые цвета ника и перевода; показывает имя игрока или название героя

## Установка

1. Поместите `chat_translator.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Scripts → Chat Translator` и включите скрипт.
4. Выберите направление перевода; цвета настраиваются в шестерёнке. MyMemory включается отдельно.

## Что нового

# 1.0.0

- Первый релиз «Переводчика чата».
- Добавлен автоматический перевод сообщений чата между английским и русским с выбором направления.
- Добавлены кэш переводов, пропуск игровых сокращений и резервная цепочка сервисов перевода.
- Добавлен необязательный перевод собственных сообщений перед отправкой.

---

# Chat Translator (English)

## What it does

Chat Translator translates players' messages in a selected direction: English to Russian, Russian to English, or both. It can optionally translate your own Russian messages before sending. Author: фригидный [разум] (Discord: .emocry). Chat text is sent to external translation services; MyMemory is off by default.

- Choose English to Russian, Russian to English, or both directions
- Optionally skip your own incoming messages
- Skips common gaming abbreviations and phrases such as gg, wp, ez, ty, gl hf, and nt
- Can translate your own Russian messages into English before sending; messages beginning with a hyphen are skipped
- Caches translations and tries Google, Yandex, Microsoft Edge, and Lingva in sequence
- MyMemory is an optional fallback service and may translate individual words inaccurately
- Temporarily skips a translation service after an error
- Configurable nickname and translation colors; displays the player name or hero name

## Install

1. Place `chat_translator.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Scripts → Scripts → Chat Translator` and enable the script.
4. Choose a translation direction; customize colors in the gear menu. MyMemory is opt-in.

## Changelog

# 1.0.0

- Initial Chat Translator release.
- Added automatic English/Russian chat translation with a configurable direction.
- Added a translation cache, common gaming phrase skips, and a fallback chain of translation services.
- Added optional translation of your own messages before sending.
