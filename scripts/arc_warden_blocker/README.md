# Arc Warden Blocker

перехватывает хук Пуджа и перекат Earth Spirit копией Arc Warden / uses Arc Warden's clone to intercept Pudge hooks and Earth Spirit rolls

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `arc_warden_blocker.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/arc_warden_blocker/arc_warden_blocker.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=arc-warden-blocker&expanded=true)
<!-- releases:end -->

## Что умеет

Arc Warden Blocker использует Tempest Double, чтобы перехватить хук Пуджа, летящий в вас или союзника, а также перекат Earth Spirit. Скрипт активен только при игре на Arc Warden и наличии соответствующего героя у противника. Автор скрипта: sataroz (Discord: sataroz). Встроенная библиотека qLocalization: qfun (qfun_g9s).

- Перехватывает хуки Пуджа копией на траектории или перемещением уже призванного клона
- Позволяет включить спасение союзников и выбрать приоритет цели
- Настраивает реакцию на перекат Earth Spirit: перехват, уклонение или оба варианта
- Отключает фоновые проверки, если вы не играете на Arc Warden или у противника нет Pudge/Earth Spirit

## Установка

1. Поместите `arc_warden_blocker.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Heroes → Hero List → Arc Warden → Анти-Хук и Анти-Ролл`.

---

# Arc Warden Blocker (English)

## What it does

Arc Warden Blocker uses Tempest Double to intercept Pudge hooks aimed at you or an ally, as well as Earth Spirit rolls. It is active only when you are playing Arc Warden and the relevant enemy hero is present. Script author: sataroz (Discord: sataroz). Bundled qLocalization library by qfun (qfun_g9s).

- Intercepts Pudge hooks by placing a clone on their path or moving an existing clone
- Can intercept hooks aimed at allies and lets you configure target priority
- Configures the response to Earth Spirit's roll: intercept, evade, or both
- Skips background checks unless you are Arc Warden and the enemy has Pudge or Earth Spirit

## Install

1. Place `arc_warden_blocker.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Heroes → Hero List → Arc Warden → Anti-Hook and Anti-Roll`.
