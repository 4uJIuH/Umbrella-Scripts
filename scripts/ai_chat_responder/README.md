# AI Chat Responder

отвечает на сообщения в игровом чате через выбранную AI-модель / replies to in-game chat using a selected AI model

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `ai_chat_responder.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/ai_chat_responder/ai_chat_responder.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=ai-chat-responder&expanded=true)
<!-- releases:end -->

## Что умеет

Отправляет сообщения из выбранного канала на указанный OpenAI-совместимый API и публикует сгенерированный ответ в игровом чате. Функция выключена по умолчанию. Внешнему сервису передаются сообщения чата и контекст диалога; API-ключ вводится пользователем в настройках.

- Настраиваемый API endpoint, модель, ключ и системная инструкция
- Выбор каналов чата, истории контекста и задержки ответов
- Отключён по умолчанию
- Поддержка пользовательской системной инструкции в локальном файле

## Установка

1. Поместите `ai_chat_responder.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты и откройте `Scripts → User Scripts → AI Chat Responder → Main → AI Responder`.
3. Укажите совместимый API endpoint, модель и личный API-ключ; храните ключ в настройках только на доверенном компьютере.
4. Перед включением учтите, что выбранный API-провайдер получает сообщения чата и контекст, нужные для генерации ответа.

---

# AI Chat Responder (English)

## What it does

Sends messages from selected chat channels to a configured OpenAI-compatible API and posts the generated response in in-game chat. The feature is disabled by default. The external service receives chat messages and conversation context; the user supplies the API key in settings.

- Configurable API endpoint, model, key, and system prompt
- Choose chat channels, context history, and reply cooldown
- Disabled by default
- Supports a custom system prompt stored in a local file

## Install

1. Place `ai_chat_responder.lua` in `umbrella\scripts`.
2. Reload Lua scripts and open `Scripts → User Scripts → AI Chat Responder → Main → AI Responder`.
3. Enter a compatible API endpoint, model, and personal API key; keep the key only on a trusted computer.
4. Before enabling, note that the selected API provider receives chat messages and context used to generate replies.
