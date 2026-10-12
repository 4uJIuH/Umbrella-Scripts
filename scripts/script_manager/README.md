# Script Manager

проверка и установка обновлений Dota-скриптов по кнопке / check and install Dota script updates on demand

<!-- releases:start -->
Скачать: [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.2.2/script_manager.lua) — `script-manager-v1.2.2`, 2026-10-12

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`script-manager-v1.2.2`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.2.2) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.2.2/script_manager.lua) | 0 |
| [`script-manager-v1.2.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.2.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.2.1/script_manager.lua) | 0 |
| [`script-manager-v1.2.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.2.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.2.0/script_manager.lua) | 0 |
| [`script-manager-v1.1.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.1.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.1.1/script_manager.lua) | 0 |
| [`script-manager-v1.1.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.1.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.1.0/script_manager.lua) | 0 |
| [`script-manager-v1.0.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.0.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.1/script_manager.lua) | 1 |
| [`script-manager-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.0.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.0/script_manager.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=script-manager&expanded=true)
<!-- releases:end -->

## Что умеет

Менеджер скриптов Umbrella с перетаскиваемой панелью: автоматически проверяет весь каталог, сохраняет версии и время проверки и устанавливает обновления по запросу.

- Проверяет доступные версии по кнопке
- Устанавливает обновления отдельных Dota-скриптов и перезагружает Script System
- Сохраняет резервную копию заменяемого файла
- Устанавливает обязательный `!_qLocalizer.lua`, если он требуется и отсутствует
- Скачивает Tinker Auto Farm как ZIP для ручной распаковки
- Показывает список скриптов, установленную и последнюю версии в отдельной панели
- Автоматически проверяет каталог при запуске, сохраняет результаты и время последней проверки
- Может обновлять собственную версию из каталога

## Установка

1. Поместите `script_manager.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Scripts → Script Manager`, назначьте клавишу для `Open manager` (по умолчанию `Insert`), затем откройте панель и проверьте выбранный скрипт.

## Что нового

**Обновление v1.2.2**

- В карточке библиотеки в Script Manager явно указано авторство qLocalization: qfun (qfun_g9s).

**Обновление v1.2.1**

- Обновлён визуальный стиль панели: добавлены плавное появление и закрытие с анимацией фона.
- Удалена вкладка настроек; автопроверка каталога при загрузке остаётся включённой.
- Добавлены короткие описания всех скриптов.
- Исправлена раскладка списка: названия и статусы не накладываются, а список не перекрывает нижние кнопки.
- Панель и её элементы адаптируются к доступной высоте экрана.

---

# Script Manager (English)

## What it does

An Umbrella script manager with a draggable panel that checks the full catalog on startup, saves versions and check time, and installs updates on demand.

- Checks for available versions on demand
- Installs individual Dota script updates and reloads the Script System
- Keeps a backup of any file it replaces
- Installs the required `!_qLocalizer.lua` when needed and missing
- Downloads Tinker Auto Farm as a ZIP for manual extraction
- Shows the script list and installed/latest versions in a dedicated panel
- Checks the catalog on startup and saves results and the last check time
- Can update itself from the catalog

## Install

1. Place `script_manager.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Scripts → Scripts → Script Manager`, assign a key to `Open manager` (defaults to `Insert`), then open the panel and check the selected script.

## Changelog

**Update v1.2.2**

- The qLocalization library card in Script Manager now clearly credits its author, qfun (qfun_g9s).

**Update v1.2.1**

- Refreshed the panel UI with smooth open/close transitions and an animated backdrop.
- Removed the settings tab; catalog checks at startup remain enabled.
- Added short descriptions for every script.
- Fixed the script list layout so names and statuses do not overlap and rows stay clear of the footer buttons.
- Adapted the panel and its elements to the available screen height.
