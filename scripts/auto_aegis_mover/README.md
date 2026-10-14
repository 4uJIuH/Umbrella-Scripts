# Auto Aegis Mover

возвращает важные предметы из рюкзака после гибели с Эгидой / moves a priority item from the backpack after dying with Aegis

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `auto_aegis_mover.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/auto_aegis_mover/auto_aegis_mover.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=auto-aegis-mover&expanded=true)
<!-- releases:end -->

## Что умеет

Auto Aegis Mover отслеживает Эгиду и после гибели героя переносит выбранный предмет из рюкзака в освободившийся слот, чтобы предмет не простаивал на перезарядке. Приоритет предметов настраивается перетаскиванием; можно включить заполнение остальных свободных ячеек после возрождения. Скрипт также обрабатывает потерю Эгиды при жизни героя. Автор: ⚔LegaXye禪 (Discord: legaxye).

- Переносит предмет из рюкзака в слот, освободившийся после потери Эгиды
- Выбор и сортировка приоритетных предметов перетаскиванием
- Опционально заполняет остальные свободные слоты после возрождения
- Настраиваемая задержка перед переносом

## Установка

1. Поместите `auto_aegis_mover.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Настройки находятся в `Scripts → General → Utility → Inventory → Auto Aegis Mover`.

---

# Auto Aegis Mover (English)

## What it does

Auto Aegis Mover tracks Aegis and, after the hero dies, moves a selected backpack item into the slot it left so the item can come off cooldown sooner. Item priorities can be reordered by dragging; an option can refill other empty slots after respawn. The script also handles losing Aegis while alive. Author: ⚔LegaXye禪 (Discord: legaxye).

- Moves a backpack item into the slot freed when Aegis is lost
- Choose and reorder item priorities by dragging
- Optionally refill other empty inventory slots after respawn
- Configurable delay before moving an item

## Install

1. Place `auto_aegis_mover.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Settings are under `Scripts → General → Utility → Inventory → Auto Aegis Mover`.
