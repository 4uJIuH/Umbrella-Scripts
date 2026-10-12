# Script Manager

проверка и установка обновлений Dota-скриптов по кнопке / check and install Dota script updates on demand

<!-- releases:start -->
Скачать: [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.1.1/script_manager.lua) — `script-manager-v1.1.1`, 2026-10-12

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`script-manager-v1.1.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.1.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.1.1/script_manager.lua) | 0 |
| [`script-manager-v1.1.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.1.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.1.0/script_manager.lua) | 0 |
| [`script-manager-v1.0.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.0.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.1/script_manager.lua) | 1 |
| [`script-manager-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.0.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.0/script_manager.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=script-manager&expanded=true)
<!-- releases:end -->

## Что умеет

Менеджер Dota-скриптов с отдельной перетаскиваемой панелью: показывает версии, проверяет GitHub и устанавливает выбранные обновления по запросу.

- Проверяет доступные версии по кнопке
- Устанавливает обновления отдельных Dota-скриптов и перезагружает Script System
- Сохраняет резервную копию заменяемого файла
- Устанавливает обязательный `!_qLocalizer.lua`, если он требуется и отсутствует
- Скачивает Tinker Auto Farm как ZIP для ручной распаковки
- Показывает список скриптов, установленную и последнюю версии в отдельной панели

## Установка

1. Поместите `script_manager.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Scripts → Script Manager`, назначьте клавишу для `Open manager` (по умолчанию `Insert`), затем откройте панель и проверьте выбранный скрипт.

## Что нового

**Обновление v1.1.1**

- Убран Script Manager из списка управляемых Dota-скриптов: он не входит в каталог обновлений и не должен отображаться как доступный для проверки.
- Устранена ошибка `script not found in catalog` при выборе самого менеджера.

---

# Script Manager (English)

## What it does

A Dota script manager with a draggable panel that displays versions, checks GitHub, and installs selected updates on demand.

- Checks for available versions on demand
- Installs individual Dota script updates and reloads the Script System
- Keeps a backup of any file it replaces
- Installs the required `!_qLocalizer.lua` when needed and missing
- Downloads Tinker Auto Farm as a ZIP for manual extraction
- Shows the script list and installed/latest versions in a dedicated panel

## Install

1. Place `script_manager.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Scripts → Scripts → Script Manager`, assign a key to `Open manager` (defaults to `Insert`), then open the panel and check the selected script.

## Changelog

**Update v1.1.1**

- Removed Script Manager from the managed Dota scripts list because it is not part of the update catalog.
- Fixed the `script not found in catalog` error caused by selecting the manager itself.
