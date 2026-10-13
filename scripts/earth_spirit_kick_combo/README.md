# Earth Spirit Kick Combo

автоматическое Blink-комбо на Earth Spirit / automatic Blink combo on Earth Spirit

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `earth_spirit_kick_combo.lua`](https://github.com/4uJIuH/umbrella-scripts/releases/download/earth-spirit-kick-combo-v1.0.0/earth_spirit_kick_combo.lua)

[Релизы на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=earth-spirit-kick-combo&expanded=true)
<!-- releases:end -->

## Что умеет

Lua-скрипт для автоматического Blink-комбо на Earth Spirit: прыжок за спину врага и последующий толчок в выбранном направлении.

- По нажатию бинда выбирает вражеского героя под курсором, использует Blink Dagger и перемещает Earth Spirit на расстояние 150 за спину цели
- После Blink автоматически применяет Boulder Smash
- Отдельная внутриигровая панель по бинду позволяет выбирать нескольких союзников кликом по иконкам героев
- В режиме «Ближайший выбранный союзник» выбирает ближайшего союзника из отмеченных в панели
- В адаптивном режиме приоритет целей: выбранный союзник, ближайший союзник, ближайшая своя башня в радиусе 1000, затем собственная база
- Если союзники не выбраны в панели, автоматически использует ближайшую доступную цель
- Русский и английский интерфейс через qLocalization

## Установка

1. Поместите `earth_spirit_kick_combo.lua` в `umbrella\scripts`.
2. Убедитесь, что рядом находится <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a>.
3. Перезагрузите Lua-скрипты.
4. Откройте настройки: `General → Earth Spirit Kick Combo`.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

---

# Earth Spirit Kick Combo (English)

## What it does

A Lua script for an automatic Earth Spirit Blink combo: blink behind an enemy and kick them in the selected direction.

- Press the combo bind to select the enemy hero under the cursor, use Blink Dagger, and move 150 units behind the target
- Automatically casts Boulder Smash after the Blink
- A separate in-game panel opened by a bind lets you select multiple allies by clicking their hero icons
- Nearest Selected Ally mode picks the closest ally marked in the panel
- Adaptive mode prioritizes a selected ally, the nearest ally, the nearest allied tower within 1000, then the allied base
- If no ally is selected in the panel, automatically uses the nearest available target
- Russian and English interface through qLocalization

## Install

1. Place `earth_spirit_kick_combo.lua` in `umbrella\scripts`.
2. Make sure <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a> is alongside it.
3. Reload the Lua scripts.
4. Open settings: `General → Earth Spirit Kick Combo`.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.
