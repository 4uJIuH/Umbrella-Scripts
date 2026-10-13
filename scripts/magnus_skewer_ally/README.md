# Magnus Skewer Ally

направляет Skewer в выбранного союзника во встроенном комбо / redirects the built-in Magnus combo's Skewer towards an ally

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `magnus_skewer_ally.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/magnus_skewer_ally/magnus_skewer_ally.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=magnus-skewer-ally&expanded=true)
<!-- releases:end -->

## Что умеет

Перехватывает Skewer во встроенном комбо Магнуса и направляет врага к выбранному союзнику. Если союзник погибает, комбо может вернуться к стандартному направлению на базу. Автор скрипта: sataroz (Discord: sataroz). Встроенная библиотека qLocalization: qfun (qfun_g9s).

- Выбор союзника из списка или фиксация цели биндом Lock Ally
- Линия и статус дальности Skewer при наведении на врага
- Показывает, хватает ли дальности, и сообщает недостающее расстояние
- Может переключиться на стандартное комбо, если выбранный союзник погиб

## Установка

1. Поместите `magnus_skewer_ally.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Heroes → Magnus → Main Settings → Skewer Combo Settings`.
4. Включите Skewer To Ally и выберите союзника.

---

# Magnus Skewer Ally (English)

## What it does

Intercepts Skewer in Magnus's built-in combo and sends the enemy towards a selected ally. If that ally dies, the combo can fall back to its default direction towards base. Script author: sataroz (Discord: sataroz). Bundled qLocalization library by qfun (qfun_g9s).

- Select an ally from the list or lock one with the Lock Ally bind
- Draws a line and range status while hovering over an enemy
- Shows whether Skewer is in range and how much distance is missing
- Can fall back to the standard combo if the selected ally dies

## Install

1. Place `magnus_skewer_ally.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Heroes → Magnus → Main Settings → Skewer Combo Settings`.
4. Enable Skewer To Ally and select an ally.
