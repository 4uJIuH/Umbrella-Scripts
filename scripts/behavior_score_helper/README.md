# BehaviorScoreHelper

повышает порядочность: авто GG, авто репорт и авто лайк / raises your behavior score: auto GG, auto report, and auto like

<!-- releases:start -->
Скачать: [BehaviorScoreHelper.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/behavior-score-helper-v1.1.1/BehaviorScoreHelper.lua) — `behavior-score-helper-v1.1.1`, 2026-10-15

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`behavior-score-helper-v1.1.1`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/behavior-score-helper-v1.1.1) | 2026-10-15 | [BehaviorScoreHelper.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/behavior-score-helper-v1.1.1/BehaviorScoreHelper.lua) | 8 |
| [`behavior-score-helper-v1.1.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/behavior-score-helper-v1.1.0) | 2026-10-15 | [BehaviorScoreHelper.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/behavior-score-helper-v1.1.0/BehaviorScoreHelper.lua) | 4 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=behavior-score-helper&expanded=true)
<!-- releases:end -->

## Что умеет

BehaviorScoreHelper — утилита автоматизации повышения порядочности в Dota 2. Берёт на себя рутину: лайки после матча, жалобы на токсичность и сообщения в чат, не отвлекая от игры.

- Авто GG: пишет выбранную фразу или ваш текст в общий или командный чат сразу после падения трона, задержку отправки можно настроить
- Авто приветствие: здоровается с союзниками в начале матча
- Авто репорт: сканирует входящие пакеты чата в реальном времени и фильтрует мат и запрещённые слова, поддерживает файлы фильтров из Steam
- Режимы поиска: точное совпадение, поиск по корню (подстроке) или оба сразу; встроенный белый список длинных слов против ложных срабатываний («ребята», «хлеб», «тебя»)
- Жалоба уходит тем же пакетом, что и при ручном репорте; после неё автоматически ставится размут
- Авто репорт за фид: отслеживает ранние выкупы через игровые события и жалуется на союзника или врага, который потратил байбек на ранней минуте (время настраивается)
- Авто лайк: ставит лайки на экране итогов матча через Panorama UI; можно лайкать только союзников или выбранных героев (иконки героев подгружаются из текущей сессии)
- Интерфейс локализуется на русский и английский с помощью qLocalization

## Установка

1. Нажмите «Установить» в Script Manager: он загрузит `BehaviorScoreHelper.lua`, qLocalization и четыре файла фильтров в `umbrella\scripts` и `umbrella\scripts\filters`.
2. При ручной установке скачайте `BehaviorScoreHelper.lua`, четыре файла из папки `filters` и `!_qLocalizer.lua`; разместите их в соответствующих папках `umbrella\scripts` и `umbrella\scripts\filters`.
3. Перезагрузите Lua-скрипты.
4. Откройте `Scripts → Utility → Порядочность` и включите нужные вкладки: Авто GG, Авто Репорт, Авто Репорт (Фид) и Авто Лайк.

Примечание: GitHub скачивает библиотеку как `_qLocalizer.lua`; переименуй её в `!_qLocalizer.lua` перед загрузкой Lua-скриптов.

## Что нового

# Исправление v1.1.1

- Исправлены названия раздела и вкладок, которые отображались как ключи локализации.

# Обновление v1.1.0

- Добавлена локализация интерфейса на русский и английский языки через qLocalization.
- Script Manager устанавливает qLocalization вместе со скриптом.
- Добавлена ручная установка локализатора и файлов фильтров в инструкции.

# Обновление v1.0.0

- Первый релиз BehaviorScoreHelper.
- Авто GG и приветствие союзников в начале матча.
- Авто репорт токсичных сообщений по файлам фильтров (мат и запрещённые слова) с режимами поиска и белым списком.
- Авто репорт за ранний выкуп (фид).
- Авто лайк на экране итогов матча.
- Script Manager устанавливает скрипт вместе с файлами фильтров в `scripts/filters`.

---

# BehaviorScoreHelper (English)

## What it does

BehaviorScoreHelper is a Dota 2 utility that automates raising your behavior score. It handles the routine: post-match likes, reports for toxic chat, and chat messages, without distracting you from the game.

- Auto GG: sends a chosen phrase or your own text to all chat or team chat right after the throne falls, with a configurable delay
- Auto greeting: greets your allies at the start of the match
- Auto report: scans incoming chat packets in real time and filters profanity and banned words; supports Steam filter files
- Search modes: exact match, root (substring) match, or both; a built-in whitelist of long words prevents false positives (for example Russian «ребята», «хлеб», «тебя»)
- The report is sent with the same packet as a manual report, and the player is unmuted automatically afterwards
- Auto feed report: tracks early buybacks through game events and reports an ally or enemy who spends a buyback early in the match (time is configurable)
- Auto like: presses likes on the post-match screen through Panorama UI; like only allies or selected heroes (hero icons are loaded from the current session)
- The interface is localized in Russian and English with qLocalization

## Install

1. Click Install in Script Manager to download `BehaviorScoreHelper.lua`, qLocalization, and the four filter files into `umbrella\scripts` and `umbrella\scripts\filters`.
2. For manual installation, download `BehaviorScoreHelper.lua`, the four files from the `filters` folder, and `!_qLocalizer.lua`; place them in the corresponding `umbrella\scripts` and `umbrella\scripts\filters` folders.
3. Reload the Lua scripts.
4. Open `Scripts → Utility → Behavior Score` and enable the tabs you need: Auto GG, Auto Report, Auto Report (Feed), and Auto Like.

Note: GitHub downloads the library as `_qLocalizer.lua`; rename it to `!_qLocalizer.lua` before loading Lua scripts.

## Changelog

# Fix v1.1.1

- Fixed the section and tab names that were displayed as localization keys.

# Update v1.1.0

- Added Russian and English interface localization through qLocalization.
- Script Manager now installs qLocalization with the script.
- Added manual installation instructions for the localizer and filter files.

# Update v1.0.0

- Initial release of BehaviorScoreHelper.
- Auto GG and a greeting for allies at the start of the match.
- Auto report for toxic chat messages using filter files (profanity and banned words), with search modes and a whitelist.
- Auto report for early buybacks (feeding).
- Auto like on the post-match screen.
- Script Manager installs the script together with the filter files into `scripts/filters`.
