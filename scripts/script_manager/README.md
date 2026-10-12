# Script Manager

проверка и установка обновлений Dota-скриптов по кнопке / check and install Dota script updates on demand

<!-- releases:start -->
Скачать: [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.1/script_manager.lua) — `script-manager-v1.0.1`, 2026-10-12

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`script-manager-v1.0.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.0.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.1/script_manager.lua) | 1 |
| [`script-manager-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.0.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.0/script_manager.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=script-manager&expanded=true)
<!-- releases:end -->

## Что умеет

Отдельный менеджер Dota-скриптов: проверяет версии в GitHub-каталоге и устанавливает выбранное обновление по подтверждению пользователя.

- Проверяет доступные версии по кнопке
- Устанавливает обновления отдельных Dota-скриптов и перезагружает Script System
- Сохраняет резервную копию заменяемого файла
- Устанавливает обязательный `!_qLocalizer.lua`, если он требуется и отсутствует
- Скачивает Tinker Auto Farm как ZIP для ручной распаковки
- Открывает отдельную перетаскиваемую панель со списком скриптов, версиями и действиями

## Установка

1. Поместите `script_manager.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Scripts → Script Manager` и назначьте клавишу для `Open manager` (по умолчанию `Insert`).
4. Нажмите назначенную клавишу, выберите скрипт в панели и проверьте обновления. Если доступна новая версия, нажмите «Установить».

---

# Script Manager (English)

## What it does

A standalone Dota script manager that checks versions from the GitHub catalog and installs a selected update after user confirmation.

- Checks for available versions on demand
- Installs individual Dota script updates and reloads the Script System
- Keeps a backup of any file it replaces
- Installs the required `!_qLocalizer.lua` when needed and missing
- Downloads Tinker Auto Farm as a ZIP for manual extraction
- Opens a draggable panel with the script list, version status, and update actions

## Install

1. Place `script_manager.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Scripts → Scripts → Script Manager` and assign a key to `Open manager` (defaults to `Insert`).
4. Press the assigned key, select a script in the panel, and check for updates. If a newer version is available, click “Install update”.
