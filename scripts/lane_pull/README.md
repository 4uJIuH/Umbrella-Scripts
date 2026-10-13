# Lane Pull

выпул вражеской волны крипом с Доминатора / pull the enemy wave with your Dominator creep

<!-- releases:start -->
Последняя версия: [`v1.0.4` — `lane_pull.lua`](https://github.com/But3rflys/umbrella-work/releases/download/lane-pull-v1.0.4/lane_pull.lua)

[Релизы автора на GitHub](https://github.com/But3rflys/umbrella-work/releases?q=lane-pull&expanded=true)
<!-- releases:end -->

## Что умеет

По клавише подконтрольный крип уходит за вражеской волной и ведет ее к герою.

- три режима выбора волны: к герою, к нашему крипу, у курсора
- сам выбирает место встречи: перед вышкой, за вышкой или ближе к герою
- не берет волну, которая вот-вот сойдется с нашими крипами
- обходит нейтральные лагеря и вражеских героев
- ждет волну в деревьях, меняет укрытие, если его увидели
- работает на миде через реку и на хайграунде
- отмена по HP, по второму нажатию и при герое вплотную
- панель статуса и отладочный оверлей

## Установка

1. Поместите `lane_pull.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.

---

# Lane Pull (English)

## What it does

One key and your dominated creep goes for the enemy wave and drags it to you.

- three ways to pick a wave: closest to you, to your creep, or by cursor
- picks the catch spot itself: in front of their tower, behind it, or closer to you
- skips a wave that is about to meet your own creeps
- walks around neutral camps and enemy heroes
- waits in the trees, changes cover once spotted
- works on mid across the river and on the high ground
- aborts on low HP, on a second key press, and when a hero gets close
- status bar and a debug overlay

## Install

1. Place `lane_pull.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
