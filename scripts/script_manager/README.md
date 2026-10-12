# Script Manager

автопроверка и установка обновлений скриптов Umbrella / automatic checks and updates for Umbrella scripts

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

Менеджер скриптов Umbrella с отдельной перетаскиваемой панелью: проверяет версии всего каталога при запуске и устанавливает выбранные обновления по запросу.

- Автоматически проверяет версии всего каталога при запуске и сохраняет результаты и время проверки
- Кнопка «Проверить все» принудительно загружает каталог заново
- Устанавливает обновления отдельных Dota-скриптов и перезагружает Script System
- Может обновлять собственную версию
- Сохраняет резервную копию заменяемого файла
- Устанавливает обязательный `!_qLocalizer.lua`, если он требуется и отсутствует
- Скачивает Tinker Auto Farm как ZIP для ручной распаковки
- Показывает список скриптов, установленную и последнюю версии в отдельной панели
- Внутренние настройки включают автопроверку и компактный список

## Установка

1. Поместите `script_manager.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Scripts → Script Manager`, назначьте клавишу для `Open manager` (по умолчанию `Insert`), затем откройте панель и проверьте выбранный скрипт.

## Что нового

**Обновление v1.2.0**

- Script Manager есть в списке и каталоге обновлений и умеет обновлять себя.
- При запуске автоматически проверяется весь каталог; версии и время проверки сохраняются.
- Кнопка «Проверить все» загружает актуальные данные. Обновления устанавливаются только по вашему нажатию.
- В панель добавлена вкладка настроек для автопроверки и компактного списка.

---

# Script Manager (English)

## What it does

An Umbrella script manager with a draggable panel that checks the GitHub catalog on startup and installs selected updates on demand.

- Checks all catalog versions on startup and saves results and the check time
- The “Check all” button fetches a fresh catalog
- Installs individual Dota script updates and reloads the Script System
- Can update itself
- Keeps a backup of any file it replaces
- Installs the required `!_qLocalizer.lua` when needed and missing
- Downloads Tinker Auto Farm as a ZIP for manual extraction
- Shows the script list and installed/latest versions in a dedicated panel
- Includes in-panel settings for startup checks and compact list layout

## Install

1. Place `script_manager.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Scripts → Scripts → Script Manager`, assign a key to `Open manager` (defaults to `Insert`), then open the panel and check the selected script.

## Changelog

**Update v1.2.0**

- Script Manager is listed in the update catalog and can update itself.
- The full catalog is checked at startup; versions and check time are saved.
- “Check all” fetches fresh data. Updates are installed only after your click.
- Added in-panel settings for startup checks and compact list layout.
