# Script Manager

каталог скриптов Umbrella с установкой и обновлениями / an Umbrella script catalog with script installation and updates

<!-- releases:start -->
Скачать: [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.5/script_manager.lua) — `script-manager-v2.0.5`, 2026-10-13

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`script-manager-v2.0.5`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v2.0.5) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.5/script_manager.lua) | 11 |
| [`script-manager-v2.0.4`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v2.0.4) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.4/script_manager.lua) | 0 |
| [`script-manager-v2.0.3`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v2.0.3) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.3/script_manager.lua) | 0 |
| [`script-manager-v2.0.2`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v2.0.2) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.2/script_manager.lua) | 0 |
| [`script-manager-v2.0.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v2.0.1) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.1/script_manager.lua) | 1 |
| [`script-manager-v2.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v2.0.0) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v2.0.0/script_manager.lua) | 2 |
| [`script-manager-v1.6.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.6.0) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.6.0/script_manager.lua) | 0 |
| [`script-manager-v1.5.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.5.0) | 2026-10-13 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.5.0/script_manager.lua) | 0 |
| [`script-manager-v1.4.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.4.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.4.0/script_manager.lua) | 1 |
| [`script-manager-v1.3.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/script-manager-v1.3.0) | 2026-10-12 | [script_manager.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/script-manager-v1.3.0/script_manager.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=script-manager&expanded=true)
<!-- releases:end -->

## Что умеет

Script Manager объединяет каталог скриптов в отдельной настраиваемой панели: показывает описания, авторов и версии, поддерживает поиск, фильтры по героям и категориям, а также установку и удаление. Визуальная/UI-часть: watahell / papagdetto.

- Загружает общий каталог с сайта и показывает скрипты по категориям, героям и статусу установки
- Отображает описания, возможности, автора, источник и доступную версию выбранного скрипта
- Ищет скрипты и сортирует каталог, установленные файлы и доступные обновления
- Автоматически проверяет каталог при запуске; проверку можно повторить вручную или настроить периодичность
- Устанавливает и обновляет отдельные скрипты, создавая резервную копию заменяемого файла
- Устанавливает многофайловые Lua-пакеты и создает необходимые подпапки
- Устанавливает `!_qLocalizer.lua`, если он нужен выбранному скрипту и ещё не установлен
- Показывает ZIP-пакеты для скачивания и ручной распаковки
- Позволяет менять тему, акцентный цвет и поведение перезапуска после установки
- Поддерживает собственное обновление под тем же именем `script_manager.lua`
- Автор визуальной/UI-части: watahell / papagdetto

## Установка

1. Поместите `script_manager.lua` в `umbrella\scripts`.
2. Если у вас отдельно установлен `script_market.lua`, удалите его, чтобы не запускать два каталога одновременно.
3. Перезагрузите Lua-скрипты.
4. Откройте `Scripts → Scripts → Script Manager`, включите его и назначьте клавишу для открытия панели.

## Что нового

# Обновление v2.0.5

- Многофайловая установка поддерживает файлы фильтров `filters/filter_*_cached.txt` и создаёт папку `scripts/filters`.
- Добавлен BehaviorScoreHelper: авто GG, авто репорт и авто лайк.

# Обновление v2.0.4

- Пакетные установки поддерживают дополнительные JSON-файлы рядом с Lua-скриптом; для них не требуется создание подпапок.
- Hero Grid устанавливается вместе с тремя примерами сеток.

# Обновление v2.0.3

- Установка многофайловых пакетов теперь продолжает работу, если папка `lib` уже создана; это позволяет обойти запрет запуска shell-команд в Lua-рантайме.

# Обновление v2.0.2

- Добавлена установка Lua-пакетов из нескольких файлов; Tinker Auto Farm устанавливается кнопкой вместе с папкой `lib`.
- Каталог сохраняет ZIP-ссылку для старых версий менеджера, а обновлённый менеджер использует прямые ссылки на файлы пакета.
- При ошибке загрузки пакет не устанавливается частично; файлы восстанавливаются, если запись пакета не удалась.

# Обновление v2.0.1

- Добавлены скрипты и актуальные релизы автора But3rflys, а также авторство в карточках каталога.
- Для скриптов без встроенного маркера версии запоминается установленная версия, чтобы корректно показывать обновления.
- Фильтр героев использует только явное поле `heroes`; общие скрипты больше не определяются по совпадениям в описаниях.
- Добавлена загрузка RAR-пакетов для ручной установки.
- Автор визуальной/UI-части: watahell / papagdetto.

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

Script Manager brings the script catalog into a customizable panel. It shows descriptions, authors, and versions, supports search and hero/category filters, and installs or removes scripts. Visual/UI design: watahell / papagdetto.

- Loads the shared website catalog and groups scripts by category, hero, and installation status
- Shows a selected script's description, features, author, source, and available version
- Searches and sorts the catalog, installed files, and available updates
- Checks the catalog on startup, with manual refresh and configurable recheck intervals
- Installs and updates individual scripts while keeping a backup of replaced files
- Installs multi-file Lua packages and creates their required subfolders
- Installs `!_qLocalizer.lua` when a selected script requires it and it is missing
- Lists ZIP packages for download and manual extraction
- Lets users change the theme, accent color, and post-install restart behavior
- Supports self-updates while keeping the `script_manager.lua` filename
- Visual/UI authors: watahell / papagdetto

## Install

1. Place `script_manager.lua` in `umbrella\scripts`.
2. If `script_market.lua` is installed separately, remove it so two catalog windows do not run at once.
3. Reload the Lua scripts.
4. Open `Scripts → Scripts → Script Manager`, enable it, and assign a key to open the panel.

## Changelog

# Update v2.0.5

- Multi-file installs support `filters/filter_*_cached.txt` filter files and create the `scripts/filters` folder.
- Added BehaviorScoreHelper: auto GG, auto report, and auto like.

# Update v2.0.4

- Multi-file installs support additional JSON files alongside the Lua script without creating subfolders.
- Hero Grid installs with three sample grids.

# Update v2.0.3

- Multi-file package installation now proceeds when the `lib` folder already exists, avoiding shell commands when the Lua runtime blocks them.

# Update v2.0.2

- Added multi-file Lua package installation; Tinker Auto Farm is installed with its `lib` folder using the Install button.
- The catalog retains its ZIP URL for older manager versions while updated managers use direct package file URLs.
- Failed downloads do not install partial packages; files are restored if writing the package fails.

# Update v2.0.1

- Added But3rflys scripts and their latest releases, with author attribution in catalog cards.
- Records the installed version of scripts without an embedded marker so available updates are detected correctly.
- Hero filtering now uses only the explicit `heroes` field; general scripts are no longer matched to heroes from their descriptions.
- Added RAR package downloads for manual installation.
- Visual/UI authors: watahell / papagdetto.

**Update v2.0.0**

- Script Market is now the new Script Manager. The catalog ID, `script_manager.lua` filename, and `script-manager-v*` tag convention are retained so existing installs can update in place.
- Added a searchable catalog with hero, category, and installation-status filters, detailed script cards, and installed-file management.
- Fixed version detection and download validation for scripts declaring `SCRIPT_VERSION`, including Dynamic Island.
- Manager self-updates use `VERSION`, preventing the old Script Manager from replacing the new version.
- Downloads are validated, replaced files are backed up, and `!_qLocalizer.lua` is installed when a script requires it.
- The window and menu are named Script Manager. Remove a separate `script_market.lua` installation to avoid running two catalog windows.
