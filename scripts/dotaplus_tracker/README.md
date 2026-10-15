# STRATZ Live Stats Tracker

сравнивает игровые показатели героя со статистикой STRATZ / compares live hero performance with STRATZ statistics

<!-- releases:start -->
Последняя версия: [`v1.0.0` — `dotaplus.lua`](https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/dotaplus_tracker/dotaplus.lua)

[Релизы автора на GitHub](https://github.com/4uJIuH/umbrella-scripts/releases?q=dotaplus-tracker&expanded=true)
<!-- releases:end -->

## Что умеет

Сопоставляет текущие убийства, смерти, помощи, крипстат, networth, GPM и XPM с данными STRATZ для выбранного ранга и роли. Данные кэшируются локально и отображаются настраиваемой панелью. Для запросов требуется личный API-токен STRATZ.

- Сравнение игровых показателей с выбранным рангом и ролью
- Обновление сравнительных данных через STRATZ API
- Локальный кэш для повторного использования загруженных данных
- Настраиваемые позиция, масштаб и отображаемые показатели
- Скрытие стандартных Panorama-плашек статистики

## Установка

1. Поместите `dotaplus.lua` в `umbrella\scripts`.
2. Получите личный токен на `https://stratz.com/api`.
3. В локальной копии файла замените `API HERE` в строке `STRATZ_TOKEN` на свой токен. Не публикуйте и не отправляйте файл с личным токеном.
4. Перезагрузите Lua-скрипты и откройте `Info Screen → Main → Tracker → Main → Settings`.

---

# STRATZ Live Stats Tracker (English)

## What it does

Compares current kills, deaths, assists, last hits, net worth, GPM, and XPM with STRATZ data for a selected rank and role. Results are cached locally and shown in a configurable panel. A personal STRATZ API token is required for requests.

- Compare live performance with a selected rank and role
- Fetch benchmark data through the STRATZ API
- Local cache for reuse of downloaded data
- Configurable panel position, scale, and displayed metrics
- Hide the default Panorama statistics panels

## Install

1. Place `dotaplus.lua` in `umbrella\scripts`.
2. Get a personal token at `https://stratz.com/api`.
3. In your local copy, replace `API HERE` in `STRATZ_TOKEN` with your token. Do not publish or share a file containing your personal token.
4. Reload Lua scripts and open `Info Screen → Main → Tracker → Main → Settings`.
