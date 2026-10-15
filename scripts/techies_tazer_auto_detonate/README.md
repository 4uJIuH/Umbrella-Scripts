# Techies Reactive Tazer Auto-Detonate

взрывает Reactive Tazer при опасных эффектах у врага / detonates Reactive Tazer when enemies have selected effects

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `techies_tazer_auto_detonate.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/techies_tazer_auto_detonate/techies_tazer_auto_detonate.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=techies-tazer-auto-detonate&expanded=true)
<!-- releases:end -->

## Что умеет

Автоматически детонирует уже активный Reactive Tazer, когда в радиусе есть враг с выбранным эффектом от Force Staff, Hurricane Pike, Ghost или Ethereal Blade. Само умение Tazer скрипт не применяет.

- Проверяет врагов в радиусе взрыва
- Реагирует на выбранные эффекты перемещения и ethereal
- Детонирует только уже активный Tazer и не применяет его самостоятельно

## Установка

1. Поместите `techies_tazer_auto_detonate.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Heroes → Hero List → Techies → Main Settings → Auto Dispel`.

---

# Techies Reactive Tazer Auto-Detonate (English)

## What it does

Automatically detonates an already-active Reactive Tazer when an enemy in its radius has a selected Force Staff, Hurricane Pike, Ghost, or Ethereal Blade effect. The script does not cast Tazer itself.

- Checks enemies within the detonation radius
- Responds to selected displacement and ethereal effects
- Detonates only an already-active Tazer and never casts it automatically

## Install

1. Place `techies_tazer_auto_detonate.lua` in `umbrella\scripts`.
2. Reload Lua scripts.
3. Open `Heroes → Hero List → Techies → Main Settings → Auto Dispel`.
