# Авто-пик

автоматически выбирает героя по приоритетам для каждой роли / automatically picks a hero using role-specific priorities

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `autopick.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/autopick/autopick.lua)

[Релизы автора на GitHub](https://github.com/w32sodinokibi/autopick)
<!-- releases:end -->

## Что умеет

Берёт первого свободного героя из очереди выбранной роли ролевого поиска. Настраивайте шесть очередей, меняйте порядок героев перетаскиванием и отключайте героев, не удаляя их из списка.

- Отдельный список приоритетов для пяти ролей и резерва на любую роль
- Сетка героев с поиском и фильтром по атрибуту
- Перетаскивание задаёт приоритет; снятая галочка временно отключает героя
- Пропускает недоступных, уже выбранных и забаненных героев

## Установка

1. Поместите `autopick.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты или запустите Umbrella, если он ещё не запущен.
3. Откройте `Scripts → Main → Авто-пик`.

---

# Авто-пик (English)

## What it does

Picks the first available hero in the selected Role Queue role. Configure six priority queues, reorder heroes by dragging, and disable heroes without removing them from the list.

- Separate priority lists for five roles and an any-role fallback
- Hero grid with search and attribute filters
- Drag to set priority; unchecking a hero disables it without removing it
- Skips unavailable, already picked, and banned heroes

## Install

1. Place `autopick.lua` in `umbrella\scripts`.
2. Reload Lua scripts, or start Umbrella if it is not running yet.
3. Open `Scripts → Main → Авто-пик`.
