# BehaviorScoreHelper

повышает порядочность: авто GG, авто репорт и авто лайк / raises your behavior score: auto GG, auto report, and auto like

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `BehaviorScoreHelper.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/behavior_score_helper/BehaviorScoreHelper.lua)

[Релизы на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=behavior-score-helper&expanded=true)
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

## Установка

1. Нажмите «Установить» в Script Manager: он загрузит `BehaviorScoreHelper.lua` и четыре файла фильтров в `umbrella\scripts` и `umbrella\scripts\filters`.
2. Или скачайте `BehaviorScoreHelper.lua` и положите его вместе с папкой `filters` в `umbrella\scripts`.
3. Перезагрузите Lua-скрипты.
4. Откройте `Scripts → Utility → Порядочность` и включите нужные вкладки: Авто GG, Авто Репорт, Авто Репорт (Фид) и Авто Лайк.

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

## Install

1. Click Install in Script Manager to download `BehaviorScoreHelper.lua` and the four filter files into `umbrella\scripts` and `umbrella\scripts\filters`.
2. Or download `BehaviorScoreHelper.lua` and place it with the `filters` folder in `umbrella\scripts`.
3. Reload the Lua scripts.
4. Open `Scripts → Utility → Порядочность` and enable the tabs you need: Авто GG, Авто Репорт, Авто Репорт (Фид), and Авто Лайк.
