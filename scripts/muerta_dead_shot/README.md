# Muerta Dead Shot

подбирает траекторию Dead Shot с рикошетами и страхом к Muerta / plans Dead Shot ricochets and fears targets toward Muerta

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `muerta_dead_shot.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/muerta_dead_shot/muerta_dead_shot.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=muerta-dead-shot&expanded=true)
<!-- releases:end -->

## Что умеет

Заменяет применение первого навыка в комбо Umbrella и ищет подходящую траекторию Dead Shot с учётом рикошетов от героев, крипов и деревьев.

- Оценивает урон, направление страха и вероятность попадания после рикошета
- По возможности направляет испуганную цель к Muerta, в том числе для связки с Io
- Избегает рискованных дальних рикошетов с низким шансом попадания
- Важно: отключите автокаст пули в стандартном комбо Umbrella и назначьте скрипту ту же клавишу комбо

## Установка

1. Отключите автокаст Dead Shot в стандартном комбо Umbrella.
2. Поместите `muerta_dead_shot.lua` в `umbrella\scripts` и перезагрузите скрипты.
3. Назначьте этому скрипту клавишу комбо Umbrella; настройки находятся в `Heroes → Hero List → Muerta → Main Settings → Dead Shot`.

---

# Muerta Dead Shot (English)

## What it does

Replaces the first-skill cast from Umbrella's combo and searches for a suitable Dead Shot trajectory, accounting for bounces off heroes, creeps, and trees.

- Scores damage, fear direction, and the chance of hitting after a ricochet
- When possible, fears the target toward Muerta, including for Muerta-Io play
- Avoids risky long ricochets with a low hit probability
- Important: disable bullet auto-cast in Umbrella's built-in combo and bind this script to the same combo key

## Install

1. Disable Dead Shot auto-cast in Umbrella's built-in combo.
2. Place `muerta_dead_shot.lua` in `umbrella\scripts` and reload scripts.
3. Bind this script to the Umbrella combo key; settings are under `Heroes → Hero List → Muerta → Main Settings → Dead Shot`.
