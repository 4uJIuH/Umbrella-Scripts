# PudgeHook AI

автоматический Meat Hook по врагам и спасение союзников / automated Meat Hook targeting and ally saves

<!-- releases:start -->
Скачать: [PudgeHook.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/pudge-hook-ai-v1.0.0/PudgeHook.lua) — `pudge-hook-ai-v1.0.0`, 2026-10-15

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`pudge-hook-ai-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/pudge-hook-ai-v1.0.0) | 2026-10-15 | [PudgeHook.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/pudge-hook-ai-v1.0.0/PudgeHook.lua) | 0 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=pudge-hook-ai&expanded=true)
<!-- releases:end -->

## Что умеет

При удержании Mouse 4 скрипт выбирает вражеского героя рядом с курсором и автоматически бросает Meat Hook, когда оценка вероятности попадания достигает заданного порога. Mouse 3 предназначена для спасения союзников из опасных ситуаций. В комплекте есть экранная панель с состоянием наведения и переназначением клавиш. Автор предупреждает, что скрипт может быть требовательным к производительности; заявленная оценка попадания — около 60–70%, а порог 75% по умолчанию является внутренней оценкой, не гарантией.

- Mouse 4 (удерживать): выбор ближайшего к курсору врага и автоматический Hook при достаточной оценке попадания
- Mouse 3 (удерживать): Meat Hook по союзнику для спасения из опасности
- Настраиваемый порог уверенности — по умолчанию 75%
- Экранный HUD показывает состояние наведения и позволяет переназначить клавиши
- Подробные диагностические записи можно сохранять в `logspudge.md`; автор просит присылать их для обратной связи
- Может заметно нагружать слабые компьютеры; фактическая точность зависит от ситуации

## Установка

1. Поместите `PudgeHook.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Heroes → Hero List → Pudge → PudgeHook AI`.

---

# PudgeHook AI (English)

## What it does

While Mouse 4 is held, the script selects an enemy hero near the cursor and automatically casts Meat Hook when its hit-confidence estimate reaches the configured threshold. Mouse 3 is for hooking allies out of danger. An on-screen panel displays targeting state and supports key rebinding. The author warns that the script may be demanding on weaker PCs; reported accuracy is around 60–70%, and the default 75% threshold is an internal estimate, not a guarantee.

- Mouse 4 (hold): selects the enemy closest to the cursor and casts Hook when confidence is high enough
- Mouse 3 (hold): hooks an ally out of danger
- Configurable confidence threshold, 75% by default
- On-screen HUD shows targeting state and supports key rebinding
- Detailed diagnostic logs can be saved to `logspudge.md`; the author welcomes them as feedback
- May be demanding on weaker PCs; actual accuracy depends on the situation

## Install

1. Place `PudgeHook.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Heroes → Hero List → Pudge → PudgeHook AI`.
