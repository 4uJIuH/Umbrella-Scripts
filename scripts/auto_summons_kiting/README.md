# Auto Summons

уводит кабанов и фордж-спиритов от атакующих врагов / kites Beastmaster boars and Invoker Forge Spirits away from attackers

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `AutoSummons.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/auto_summons_kiting/AutoSummons.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=auto-summons-kiting&expanded=true)
<!-- releases:end -->

## Что умеет

Отслеживает вражеские атаки по вашим кабанам Beastmaster и Forge Spirit Invoker и при необходимости приказывает призыву отступить. Учитывает снаряды атак и может автоматически выключить кайтинг через восемь минут игры.

- Поддерживает кабанов Beastmaster и Forge Spirit Invoker
- Настраиваемая проверка атаки врага и цели снаряда
- Режим hit-and-run и резервная эвристика для мили-атак
- Сохраняет и возвращает значение автоатаки призывов
- Автоматически выключается через восемь минут

## Установка

1. Поместите `AutoSummons.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Scripts → Other → Auto Summons → Main → Main`.

---

# Auto Summons (English)

## What it does

Tracks enemy attacks against your Beastmaster boars and Invoker Forge Spirits and orders threatened summons to retreat. It considers attack projectiles and can automatically disable kiting after eight minutes of game time.

- Supports Beastmaster boars and Invoker Forge Spirits
- Configurable enemy attack and projectile-target checks
- Hit-and-run mode and melee fallback heuristic
- Saves and restores the summoned-unit auto-attack setting
- Automatically disables itself after eight minutes

## Install

1. Place `AutoSummons.lua` in `umbrella\scripts`.
2. Reload Lua scripts.
3. Open `Scripts → Other → Auto Summons → Main → Main`.
