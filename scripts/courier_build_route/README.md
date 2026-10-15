# Courier Build Route

отправляет курьера по маршруту к фонтану / sends your courier along a route toward the fountain

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `courier_build.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/courier_build_route/courier_build.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=courier-build-route&expanded=true)
<!-- releases:end -->

## Что умеет

По бинду отправляет курьера по последовательности заранее заданных точек для Radiant или Dire, а в конце использует способность передачи предметов.

- Отдельные маршруты для Radiant и Dire
- Случайное смещение точек маршрута
- Запуск по бинду `Send Courier By Route`
- Использует существующие настройки меню курьера Umbrella

## Установка

1. Поместите `courier_build.lua` в `umbrella\scripts`.
2. Убедитесь, что в меню Umbrella доступен раздел `Miscellaneous → In Game → Courier → Main → Courier`; без него скрипт не создаёт пункт бинда.
3. Перезагрузите Lua-скрипты и назначьте `Send Courier By Route`.

---

# Courier Build Route (English)

## What it does

On a keybind, sends the courier through a sequence of predefined waypoints for Radiant or Dire, then uses the courier's item-transfer ability.

- Separate routes for Radiant and Dire
- Randomized waypoint offsets
- Triggered by the `Send Courier By Route` keybind
- Uses the existing Umbrella courier menu

## Install

1. Place `courier_build.lua` in `umbrella\scripts`.
2. Make sure `Miscellaneous → In Game → Courier → Main → Courier` exists in Umbrella; the script does not create its keybind menu if this section is missing.
3. Reload Lua scripts and assign `Send Courier By Route`.
