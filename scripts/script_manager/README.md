# Script Manager

каталог скриптов Umbrella с установкой и обновлениями / an Umbrella script catalog with script installation and updates

<!-- releases:start -->
Скачать: [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.6.0/script_manager.lua) — `script-manager-v1.6.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`script-manager-v1.6.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.6.0) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.6.0/script_manager.lua) | 0 |
| [`script-manager-v1.5.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.5.0) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.5.0/script_manager.lua) | 0 |
| [`script-manager-v1.4.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.4.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.4.0/script_manager.lua) | 1 |
| [`script-manager-v1.3.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.3.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.3.0/script_manager.lua) | 0 |
| [`script-manager-v1.2.2`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.2.2) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.2.2/script_manager.lua) | 1 |
| [`script-manager-v1.2.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.2.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.2.1/script_manager.lua) | 0 |
| [`script-manager-v1.2.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.2.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.2.0/script_manager.lua) | 0 |
| [`script-manager-v1.1.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.1.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.1.1/script_manager.lua) | 0 |
| [`script-manager-v1.1.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.1.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.1.0/script_manager.lua) | 0 |
| [`script-manager-v1.0.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.0.1) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.1/script_manager.lua) | 1 |
| [`script-manager-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.0.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.0.0/script_manager.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=script-manager&expanded=true)
<!-- releases:end -->

## Что умеет

Script Manager открывает общий каталог скриптов Umbrella в отдельной настраиваемой панели.

- Фильтры по категориям, героям и состоянию установки; поиск и сортировка
- Подробные карточки с описаниями, возможностями, авторами, источниками и версиями
- Автоматическая проверка каталога при запуске, ручное обновление и настраиваемая периодичность
- Установка, обновление и удаление скриптов с резервным копированием заменяемых файлов
- Автоматическая установка `!_qLocalizer.lua`, если библиотека требуется и отсутствует
- Отдельная отметка ZIP-пакетов для скачивания и ручной распаковки
- Настройки темы, акцентного цвета и поведения перезапуска
- Самообновление под прежним именем `script_manager.lua`

## Установка

1. Поместите `script_manager.lua` в `umbrella\scripts`.
2. Если у вас отдельно установлен `script_market.lua`, удалите его, чтобы не запускать два каталога одновременно.
3. Перезагрузите Lua-скрипты.
4. Откройте `Scripts → Scripts → Script Manager`, включите его и назначьте клавишу для открытия панели.

## Что нового

**Обновление v2.0.0**

- Script Market стал новой версией Script Manager с каталогом, поиском, фильтрами по героям и категориям и управлением установленными скриптами.
- Сохранены имя файла и схема релизов, поэтому менеджер обновляется поверх предыдущего Script Manager.
- Исправлена поддержка `SCRIPT_VERSION` и самообновление Script Manager.
- Отдельный `script_market.lua` нужно удалить, чтобы два каталога не запускались одновременно.

**Обновление v1.6.0**

- Добавлен Tinker Smart Escape от автора sataroz с установкой и обновлением через Script Manager.

**Обновление v1.5.0**

- Добавлен Dynamic Island от автора "ur2m" (GitHub: @qhols), версия 2.5.3.
- Менеджер теперь принимает скрипты из GitHub-репозиториев авторов и проверяет версии, заданные через `SCRIPT_VERSION`.
- Добавлены ссылка на исходный релиз и информация о дополнительном `media_bridge.exe`, необходимом для музыки и звуков.

**Обновление v1.4.0**

- Полностью переработана панель Script Manager: интерфейс стал чище, а информация о скрипте, версиях и состоянии обновления — нагляднее.
- Обновлены список скриптов и карточки: появились понятные значки, статусы, плавные анимации и подсказки.
- Настройки внешнего вида собраны в отдельном разделе с прокруткой: темы, акцентные цвета, размытие и прозрачность фона, масштаб и компактный режим.
- Существующий масштаб панели из настроек предыдущей версии сохраняется при обновлении.

**Обновление v1.3.0**

- Добавлена отдельная панель визуальных настроек: темы оформления и акцентные цвета.
- Появились настройки размытия фона, прозрачности и масштаба текста панели, а также компактный режим списка.
- Исправлены значения визуальных настроек по умолчанию; подписи панели настроек локализованы на русский и английский.

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

Script Manager displays the shared Umbrella script catalog in a customizable panel.

- Filters by category, hero, and installation status; supports search and sorting
- Shows script descriptions, features, authors, sources, and versions in detailed cards
- Checks the catalog on startup, with manual refresh and configurable recheck intervals
- Installs, updates, and removes scripts while backing up replaced files
- Installs `!_qLocalizer.lua` when required and missing
- Clearly marks ZIP packages for manual extraction
- Provides theme, accent-color, and post-install restart settings
- Supports self-updates under the existing `script_manager.lua` filename

## Install

1. Place `script_manager.lua` in `umbrella\scripts`.
2. If a separate `script_market.lua` is installed, remove it to avoid running two catalog windows.
3. Reload the Lua scripts.
4. Open `Scripts → Scripts → Script Manager`, enable it, and assign a key to open the panel.

## Changelog

**Update v2.0.0**

- Script Market is now the new Script Manager, with a catalog, search, hero/category filters, and installed-script management.
- Preserved the filename and release convention so existing installs can update in place.
- Fixed `SCRIPT_VERSION` support and Script Manager self-updates.
- Remove a separate `script_market.lua` installation to avoid running both catalog windows.

**Update v1.6.0**

- Added Tinker Smart Escape by sataroz to Script Manager for installation and updates.

**Update v1.5.0**

- Added Dynamic Island by "ur2m" (GitHub: @qhols), version 2.5.3.
- The manager can now use scripts hosted in authors' GitHub repositories and validate versions declared as `SCRIPT_VERSION`.
- Added a direct link to the author's release and information about the optional `media_bridge.exe` required for music and sounds.

**Update v1.4.0**

- Rebuilt the Script Manager panel with a cleaner layout and a clearer view of each script, its versions, and update status.
- Refreshed the script list and detail cards with recognizable icons, status indicators, smooth animations, and tooltips.
- Moved appearance controls into a dedicated, scrollable settings view with themes, accent colors, background blur and opacity, scaling, and compact mode.
- Preserved the panel scale saved by the previous version.

**Update v1.3.0**

- Added a dedicated appearance panel with selectable themes and accent colors.
- Added controls for background blur, panel opacity and text scale, plus a compact script-list mode.
- Fixed default appearance values and localized the settings panel in Russian and English.

**Update v1.2.2**

- The qLocalization library card in Script Manager now clearly credits its author, qfun (qfun_g9s).

**Update v1.2.1**

- Refreshed the panel UI with smooth open/close transitions and an animated backdrop.
- Removed the settings tab; catalog checks at startup remain enabled.
- Added short descriptions for every script.
- Fixed the script list layout so names and statuses do not overlap and rows stay clear of the footer buttons.
- Adapted the panel and its elements to the available screen height.
