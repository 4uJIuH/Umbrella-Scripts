# Денай-токсик

шуточные сообщения противнику после деная крипа / playful chat lines after denying a creep

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `deny_taunt.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/deny_taunt/deny_taunt.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=deny-taunt&expanded=true)
<!-- releases:end -->

## Что умеет

После деная своего крипа скрипт ищет ближайшего видимого вражеского героя поблизости и с заданным шансом отправляет ему фразу. По умолчанию сообщения идут в общий чат, пауза — 30 секунд, шанс — 70%; можно переключить чат на союзный или отключить скрипт.

- Автоматически выбирает ближайшего видимого вражеского героя рядом с заденайным крипом
- Использует 12 встроенных русскоязычных фраз и не повторяет одну фразу два раза подряд
- Можно задать собственные фразы через `;`; `{hero}` заменяется именем героя
- Настраиваются общий или союзный чат, пауза между сообщениями и шанс отправки
- Встроенные подколы без мата; общий чат включён по умолчанию

## Установка

1. Поместите `deny_taunt.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Utility → Денай-токсик`.

---

# Deny Taunt (English)

## What it does

After you deny one of your creeps, the script finds the nearest visible enemy hero nearby and may send them a line. By default it uses all-chat, a 30-second cooldown, and a 70% chance; you can switch to allied chat or disable it.

- Finds the nearest visible enemy hero near the denied creep
- Includes 12 Russian-language lines and avoids repeating the same line twice in a row
- Accepts custom semicolon-separated lines; `{hero}` is replaced with the hero's name
- Configure all-chat or allied chat, message cooldown, and send chance
- Built-in lines are non-profane; all-chat is enabled by default

## Install

1. Place `deny_taunt.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Scripts → Utility → Денай-токсик`.
