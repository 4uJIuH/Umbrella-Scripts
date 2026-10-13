# Auto Spark

автоматическое использование спарков на линии / automatic Spark Wraith usage on the lane

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `Auto_Spark.lua`](https://github.com/4uJIuH/umbrella-scripts/releases/download/auto-spark-v1.0.0/Auto_Spark.lua)

[Релизы на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=auto-spark&expanded=true)
<!-- releases:end -->

## Что умеет

Скрипт для автоматического использования Spark Wraith на линии.

- Находит вражеских героев, анализирует их позицию и настройки попадания перед использованием Spark Wraith
- Режим для неподвижных врагов, которого нет в Sunstrike от Umbrella
- Не использует Spark Wraith, если живой вражеский крип находится внутри заданного радиуса
- Автоматический режим работает до заданной минуты игры
- Настройки точности выбора цели; автор рекомендует значения со скриншота
- Публикация скрипта и скриншот настроек: <a href="https://discord.com/channels/408315082439917578/1552693551685443684/1554128119210840064" target="_blank" rel="noopener">Discord</a>

## Установка

1. Поместите <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/auto-spark-v1.0.0/Auto_Spark.lua" target="_blank" rel="noopener"><code>Auto_Spark.lua</code></a> в `umbrella\scripts`.
2. Поместите <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a> туда же.
3. Перезагрузите Lua-скрипты.
4. Откройте настройки: `Скрипты → Скрипты → Auto Spark`.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Auto Spark (English)

## What it does

A script for automatically using Spark Wraith on the lane.

- Finds enemy heroes and checks their position and hit settings before casting Spark Wraith
- Includes a mode for stationary enemies, which Umbrella's Sunstrike does not have
- Does not cast Spark Wraith if a living enemy creep is within the configured radius
- Automatic mode runs until the configured game minute
- Includes targeting precision settings; the author recommends the values shown in the screenshot
- Script post and settings screenshot: <a href="https://discord.com/channels/408315082439917578/1552693551685443684/1554128119210840064" target="_blank" rel="noopener">Discord</a>

## Install

1. Place <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/auto-spark-v1.0.0/Auto_Spark.lua" target="_blank" rel="noopener"><code>Auto_Spark.lua</code></a> in `umbrella\scripts`.
2. Place <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a> alongside it.
3. Reload the Lua scripts.
4. Open settings: `Scripts → Scripts → Auto Spark`.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
