# Custom Stats

Заменяет стандартную панель статистики Dota Plus на настраиваемую / A customizable replacement for the Dota Plus stats panel

## Что умеет

Показывает KDA, нетворс и крипов в компактной панели. Нажмите на неё, чтобы раскрыть дополнительные показатели: GPM, XPM, крипов к 10-й минуте, участие в убийствах и урон по героям. Панель можно перетаскивать; настраиваются шрифт, размер, оформление и видимые строки.

- Показывает основные и расширенные показатели матча
- Сравнивает текущую статистику со средними значениями для героя, ранга и минуты матча через Stratz
- Позволяет перемещать панель и настраивать отображение
- Может скрыть стандартную панель статистики Dota

Автор скрипта: qhols (GitHub: [qhols](https://github.com/qhols), Discord: ur2m). Встроенная библиотека qLocalization: qfun (qfun_g9s).

Для сравнения со Stratz нужен бесплатный API-ключ: [получить ключ](https://stratz.com/api). Без ключа сама панель работает, но сравнение недоступно. Если шрифт SF Pro не установлен в Windows, выберите Segoe UI. Отдельный архив шрифтов в эту публикацию не входит.

## Установка

1. Поместите `custom_stats.lua` в `umbrella\scripts`.
2. Перезагрузите Lua-скрипты.
3. Откройте `Info Screen → Main → Custom Stats`.
4. Для сравнения откройте шестерёнку у пункта «Сравнение с другими» и вставьте API-ключ Stratz.

---

# Custom Stats (English)

## What it does

Displays KDA, net worth, and creeps in a compact panel. Click it to expand more stats: GPM, XPM, creeps at 10 minutes, kill participation, and hero damage. The panel can be dragged, and its font, size, appearance, and visible rows are configurable.

- Shows core and expanded match statistics
- Compares current stats with Stratz averages for the hero, rank, and match minute
- Lets you move the panel and customize its appearance
- Can hide Dota's default stats panel

Script author: qhols (GitHub: [qhols](https://github.com/qhols), Discord: ur2m). Bundled qLocalization library by qfun (qfun_g9s).

A free Stratz API key is required for comparisons: [get a key](https://stratz.com/api). The stats panel works without a key, but comparisons are unavailable. If SF Pro is not installed on Windows, select Segoe UI. A separate font archive is not included with this release.

## Installation

1. Place `custom_stats.lua` in `umbrella\scripts`.
2. Reload the Lua scripts.
3. Open `Info Screen → Main → Custom Stats`.
4. To enable comparisons, open the gear next to “Compare with others” and enter your Stratz API key.
