# qLocalization

вспомогательная библиотека для локализации Lua-интерфейсов / a helper library for localizing Lua interfaces

<!-- releases:start -->
Скачать: [_qLocalizer.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua) — `q-localizer-v1.0.0`, 2026-10-10

| версия | дата | файл | загрузок |
| --- | --- | --- | --- |
| [`q-localizer-v1.0.0`](https://github.com/4uJIuH/umbrella-scripts/releases/tag/q-localizer-v1.0.0) | 2026-10-10 | [_qLocalizer.lua](https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua) | 3 |

[Все релизы](https://github.com/4uJIuH/umbrella-scripts/releases?q=q-localizer&expanded=true)
<!-- releases:end -->

## Что умеет

qLocalization автоматически локализует интерфейсы Lua-скриптов. Библиотека разработана для Dota 2 и также работает в Deadlock. Оригинальный автор — qfun (qfun_g9s); это не мой скрипт.

- Автоматически сопоставляет доступные языки интерфейса с переводами — вручную задавать индексы языков не нужно
- Поддерживает собственные языки: достаточно добавить перевод с соответствующим кодом
- Позволяет использовать ключи переводов для названий элементов меню и подсказок, а также оборачивать библиотеку Menu через `WrapLibrary`
- Нужен некоторым скриптам каталога для русского и английского интерфейса; автономным скриптам не требуется
- Не мой скрипт: автор оригинала — qfun (qfun_g9s)

## Установка

1. Скачайте <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a>.
2. Переименуйте скачанный файл в `!_qLocalizer.lua`.
3. Поместите файл в папку `scripts` рядом со скриптами, которым нужна локализация.
4. Перезагрузите Lua-скрипты.

## Что нового

**Первая публикация в каталоге**

- Добавлена сторонняя библиотека qLocalization для автоматической локализации Lua-интерфейсов.
- Оригинальный автор — qfun (qfun_g9s); это не моя разработка.

---

# qLocalization (English)

## What it does

qLocalization automatically localizes Lua script interfaces. It was developed for Dota 2 and also works in Deadlock. The original author is qfun (qfun_g9s); this is not my script.

- Maps available interface languages to translations automatically, without manually setting language indexes
- Supports custom languages by adding translations under the corresponding language code
- Lets scripts use translation keys for menu labels and tooltips, and wrap the Menu library with `WrapLibrary`
- Required by some scripts in this catalog for localized interfaces; standalone scripts do not need it
- Not my script: the original author is qfun (qfun_g9s)

## Install

1. Download <a href="https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua" target="_blank" rel="noopener"><code>_qLocalizer.lua</code></a>.
2. Rename the downloaded file to `!_qLocalizer.lua`.
3. Place the file in the `scripts` folder alongside scripts that need localization.
4. Reload the Lua scripts.

## Changelog

**First catalog release**

- Added the third-party qLocalization library for automatic localization of Lua interfaces.
- Original author: qfun (qfun_g9s); this is not my work.
