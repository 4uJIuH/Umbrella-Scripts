# Meepo Auto Escape

автоматически отводит Meepo с низким здоровьем в безопасное место / automatically sends low-health Meepos to safety

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `meepo.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/meepo_auto_escape/meepo.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=meepo-auto-escape&expanded=true)
<!-- releases:end -->

## Что умеет

Отправляет раненых Meepo к фонтану с помощью Poof на союзного Meepo или свитка телепортации. Поддерживает оценку опасности по полученному урону и автоматический возврат в бой через Poof.

- Побег по порогу здоровья или оценке недавнего урона
- Спасение через Poof или Town Portal Scroll
- Автоматический возврат вылечившегося Meepo через Poof
- Опция блокировки управления отступающими Meepo

## Установка

1. Поместите `meepo.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Heroes → Hero List → Meepo → Meepo → Saver`.

---

# Meepo Auto Escape (English)

## What it does

Sends injured Meepos to the fountain using Poof to an allied Meepo or a Town Portal Scroll. It can estimate danger from recent damage and automatically return recovered Meepos to the fight with Poof.

- Escape based on an HP threshold or recent damage
- Save using Poof or a Town Portal Scroll
- Automatically Poof recovered Meepos back to the fight
- Option to prevent manual orders from interrupting retreating Meepos

## Install

1. Place `meepo.lua` in `umbrella\scripts`.
2. Reload Lua scripts.
3. Open `Heroes → Hero List → Meepo → Meepo → Saver`.
