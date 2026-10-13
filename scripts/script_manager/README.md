# Script Manager

каталог скриптов Umbrella с установкой и обновлениями / an Umbrella script catalog with script installation and updates

<!-- releases:start -->
Скачать: [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.0/script_manager.lua) — `script-manager-v2.0.0`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`script-manager-v2.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v2.0.0) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.0/script_manager.lua) | 0 |
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

Script Manager объединяет каталог скриптов в отдельной настраиваемой панели: показывает описания, авторов и версии, поддерживает поиск, фильтры по героям и категориям, а также установку и удаление.

- Загружает общий каталог с сайта и показывает скрипты по категориям, героям и статусу установки
- Отображает описания, возможности, автора, источник и доступную версию выбранного скрипта
- Ищет скрипты и сортирует каталог, установленные файлы и доступные обновления
- Автоматически проверяет каталог при запуске; проверку можно повторить вручную или настроить периодичность
- Устанавливает и обновляет отдельные скрипты, создавая резервную копию заменяемого файла
- Устанавливает `!_qLocalizer.lua`, если он нужен выбранному скрипту и ещё не установлен
- Показывает ZIP-пакеты для скачивания и ручной распаковки
- Позволяет менять тему, акцентный цвет и поведение перезапуска после установки
- Поддерживает собственное обновление под тем же именем `script_manager.lua`

## Установка

1. Поместите `script_manager.lua` в `umbrella\scripts`.
2. Если у вас отдельно установлен `script_market.lua`, удалите его, чтобы не запускать два каталога одновременно.
3. Перезагрузите Lua-скрипты.
4. Откройте `Scripts → Scripts → Script Manager`, включите его и назначьте клавишу для открытия панели.

## Что нового

**Обновление v2.0.0**

- Script Market стал новым Script Manager: каталог, файл `script_manager.lua` и тег `script-manager-v*` сохранены, поэтому прежняя установка сможет обновиться на новую версию.
- Добавлены каталог с поиском и фильтрами по героям, категориям и статусу установки, подробные карточки скриптов и управление установленными файлами.
- Исправлена проверка и установка версий, объявленных как `SCRIPT_VERSION`, включая Dynamic Island.
- Самообновление менеджера работает через `VERSION` и не устанавливает старый Script Manager поверх новой версии.
- Установщик проверяет загружаемый файл, сохраняет резервную копию и ставит `!_qLocalizer.lua`, если библиотека нужна скрипту.
- Окно и меню переименованы в Script Manager. Отдельный `script_market.lua` нужно удалить, чтобы не запускать два каталога одновременно.

---

# Script Manager (English)

## What it does

Script Manager brings the script catalog into a customizable panel. It shows descriptions, authors, and versions, supports search and hero/category filters, and installs or removes scripts.

- Loads the shared website catalog and groups scripts by category, hero, and installation status
- Shows a selected script's description, features, author, source, and available version
- Searches and sorts the catalog, installed files, and available updates
- Checks the catalog on startup, with manual refresh and configurable recheck intervals
- Installs and updates individual scripts while keeping a backup of replaced files
- Installs `!_qLocalizer.lua` when a selected script requires it and it is missing
- Lists ZIP packages for download and manual extraction
- Lets users change the theme, accent color, and post-install restart behavior
- Supports self-updates while keeping the `script_manager.lua` filename

## Install

1. Place `script_manager.lua` in `umbrella\scripts`.
2. If `script_market.lua` is installed separately, remove it so two catalog windows do not run at once.
3. Reload the Lua scripts.
4. Open `Scripts → Scripts → Script Manager`, enable it, and assign a key to open the panel.

## Changelog

**Update v2.0.0**

- Script Market is now the new Script Manager. The catalog ID, `script_manager.lua` filename, and `script-manager-v*` tag convention are retained so existing installs can update in place.
- Added a searchable catalog with hero, category, and installation-status filters, detailed script cards, and installed-file management.
- Fixed version detection and download validation for scripts declaring `SCRIPT_VERSION`, including Dynamic Island.
- Manager self-updates use `VERSION`, preventing the old Script Manager from replacing the new version.
- Downloads are validated, replaced files are backed up, and `!_qLocalizer.lua` is installed when a script requires it.
- The window and menu are named Script Manager. Remove a separate `script_market.lua` installation to avoid running two catalog windows.
