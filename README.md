# Umbrella Scripts

Сайт Lua-скриптов для Umbrella.

Сайт: https://4ujiuh.github.io/umbrella-scripts/
Репозиторий: https://github.com/4uJIuH/umbrella-scripts

<!-- scripts:ru:start -->
- [Tinker Turret Dodge](scripts/tinker_turret_dodge) — автоматический додж опасных способностей турелями Тинкера
- [Tinker Auto Farm](scripts/tinker_auto_farm) — автоматический фарм на Тинкере
- [Auto Shackleshot](scripts/auto_shackleshot) — автоматическое применение Shackleshot за Windranger
- [Auto Spark](scripts/auto_spark) — автоматическое использование спарков на линии
- [Rune Destruction](scripts/rune_destruction) — отправка подконтрольных юнитов к рунам
- [Earth Spirit Kick Combo](scripts/earth_spirit_kick_combo) — автоматическое Blink-комбо на Earth Spirit
- [HP/Mana 67 Ping](scripts/hp_mana_67_ping) — сообщения при достижении значений HP и маны, оканчивающихся на 67
- [Spirit Bear Pull](scripts/spirit_bear_pull) — автоматический отвод крипов медведем Lone Druid
- [Dorman Combo Assistant](scripts/dorman_combo_assistant) — комбо-ассистент для Dorman в Deadlock
- [Rem Assistant](scripts/rem_assistant) — ассистент способностей и лечения для Rem в Deadlock
- [Souls Vault / Rem's Tunnel ESP](scripts/vault_tunnel_esp) — ESP для Souls Vault и Rem's Tunnel с таймером возрождения
- [qLocalization](scripts/q_localizer) — вспомогательная библиотека для локализации Lua-интерфейсов
- [Script Manager](scripts/script_manager) — проверка и установка обновлений Dota-скриптов по кнопке
<!-- scripts:ru:end -->

На странице скрипта есть описание, установка, история версий и загрузка.

## Установка

Tinker Turret Dodge: скачай `tinker_turret_dodge.lua` и `!_qLocalizer.lua` в `umbrella\scripts`,
перезагрузи Lua-скрипты и открой `General → Tinker Turret Dodge`.

Tinker Auto Farm: скачай и распакуй `Tinker-Auto-Farm.zip`, помести `Tinker.lua` и папку `lib`
в `umbrella\scripts`, перезагрузи Lua-скрипты и открой `Scripts → Scripts → Tinker`.

Auto Shackleshot: скачай `Auto_Shackleshot.lua` и `!_qLocalizer.lua` в `umbrella\scripts`,
перезагрузи Lua-скрипты и открой `Скрипты → Скрипты → Auto Shackleshot`.

Auto Spark: скачай `Auto_Spark.lua` и `!_qLocalizer.lua` в `umbrella\scripts`,
перезагрузи Lua-скрипты и открой `Скрипты → Скрипты → Auto Spark`.

Rune Destruction: скачай `rune_units.lua` в `umbrella\scripts`, перезагрузи Lua-скрипты
и открой `Scripts → Rune Units`.

Earth Spirit Kick Combo: скачай `earth_spirit_kick_combo.lua` и `!_qLocalizer.lua` в
`umbrella\scripts`, перезагрузи Lua-скрипты и открой `General → Earth Spirit Kick Combo`.

HP/Mana 67 Ping: скачай `hp_mana_67_ping.lua` и `!_qLocalizer.lua` в `umbrella\scripts`,
перезагрузи Lua-скрипты и открой `General → HP/Mana 67 Ping → Settings`.

Spirit Bear Pull: скачай `lone_druid_bear_pull.lua` и `!_qLocalizer.lua` в `umbrella\scripts`,
перезагрузи Lua-скрипты и открой `General → Spirit Bear Pull`.

Dorman Combo Assistant: скачай `Dorman.lua` и `!_qLocalizer.lua` в `%cheat_dir%/deadlock_scripts`,
перезагрузи Lua-скрипты и открой `Heroes → Hero List → The Dorman → Dorman`.

Rem Assistant: скачай `Rem_Assistant.lua` и `!_qLocalizer.lua` в `%cheat_dir%/deadlock_scripts`,
перезагрузи Lua-скрипты и открой `Heroes → Hero List → Rem → Rem Assistant`.

Souls Vault / Rem's Tunnel ESP: скачай `VaultTunnelESP.lua` в папку скриптов Deadlock,
перезагрузи Lua-скрипты и открой `Visuals → World → Show Me More → Vault & Tunnel ESP`.

qLocalization: [скачай `_qLocalizer.lua`](https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua),
переименуй файл в `!_qLocalizer.lua` и положи рядом со скриптами, которым нужна локализация.
Это сторонняя библиотека автора qfun (qfun_g9s), не мой скрипт.

---

# English

Lua scripts for Umbrella.

Site: https://4ujiuh.github.io/umbrella-scripts/
Repository: https://github.com/4uJIuH/umbrella-scripts

<!-- scripts:en:start -->
- [Tinker Turret Dodge](scripts/tinker_turret_dodge) — automatically dodges dangerous abilities with Tinker turrets
- [Tinker Auto Farm](scripts/tinker_auto_farm) — automatic farming on Tinker
- [Auto Shackleshot](scripts/auto_shackleshot) — automatic Shackleshot on Windranger
- [Auto Spark](scripts/auto_spark) — automatic Spark Wraith usage on the lane
- [Rune Destruction](scripts/rune_destruction) — send controlled units to runes
- [Earth Spirit Kick Combo](scripts/earth_spirit_kick_combo) — automatic Blink combo on Earth Spirit
- [HP/Mana 67 Ping](scripts/hp_mana_67_ping) — chat messages when HP or mana reaches a value ending in 67
- [Spirit Bear Pull](scripts/spirit_bear_pull) — automatically pull a creep wave with Lone Druid's bear
- [Dorman Combo Assistant](scripts/dorman_combo_assistant) — a combo assistant for Dorman in Deadlock
- [Rem Assistant](scripts/rem_assistant) — ability and healing assistant for Rem in Deadlock
- [Souls Vault / Rem's Tunnel ESP](scripts/vault_tunnel_esp) — ESP for Souls Vault and Rem's Tunnel with respawn timers
- [qLocalization](scripts/q_localizer) — a helper library for localizing Lua interfaces
- [Script Manager](scripts/script_manager) — check and install Dota script updates on demand
<!-- scripts:en:end -->

The script page includes its description, installation steps, version history, and download.

## Install

Tinker Turret Dodge: download `tinker_turret_dodge.lua` and `!_qLocalizer.lua` into
`umbrella\scripts`, reload the Lua scripts, and open `General → Tinker Turret Dodge`.

Tinker Auto Farm: download and extract `Tinker-Auto-Farm.zip`, place `Tinker.lua` and the `lib`
folder in `umbrella\scripts`, reload the Lua scripts, and open `Scripts → Scripts → Tinker`.

Auto Shackleshot: download `Auto_Shackleshot.lua` and `!_qLocalizer.lua` into
`umbrella\scripts`, reload the Lua scripts, and open `Scripts → Scripts → Auto Shackleshot`.

Auto Spark: download `Auto_Spark.lua` and `!_qLocalizer.lua` into `umbrella\scripts`,
reload the Lua scripts, and open `Scripts → Scripts → Auto Spark`.

Rune Destruction: download `rune_units.lua` into `umbrella\scripts`, reload the Lua scripts,
and open `Scripts → Rune Units`.

Earth Spirit Kick Combo: download `earth_spirit_kick_combo.lua` and `!_qLocalizer.lua` into
`umbrella\scripts`, reload the Lua scripts, and open `General → Earth Spirit Kick Combo`.

HP/Mana 67 Ping: download `hp_mana_67_ping.lua` and `!_qLocalizer.lua` into
`umbrella\scripts`, reload the Lua scripts, and open `General → HP/Mana 67 Ping → Settings`.

Spirit Bear Pull: download `lone_druid_bear_pull.lua` and `!_qLocalizer.lua` into
`umbrella\scripts`, reload the Lua scripts, and open `General → Spirit Bear Pull`.

Dorman Combo Assistant: download `Dorman.lua` and `!_qLocalizer.lua` into
`%cheat_dir%/deadlock_scripts`, reload the Lua scripts, and open `Heroes → Hero List → The Dorman → Dorman`.

Rem Assistant: download `Rem_Assistant.lua` and `!_qLocalizer.lua` into
`%cheat_dir%/deadlock_scripts`, reload the Lua scripts, and open `Heroes → Hero List → Rem → Rem Assistant`.

Souls Vault / Rem's Tunnel ESP: download `VaultTunnelESP.lua` into your Deadlock scripts folder,
reload the Lua scripts, and open `Visuals → World → Show Me More → Vault & Tunnel ESP`.

qLocalization: [download `_qLocalizer.lua`](https://github.com/4uJIuH/umbrella-scripts/releases/download/q-localizer-v1.0.0/_qLocalizer.lua),
rename it to `!_qLocalizer.lua`, and place it alongside scripts that require localization.
This third-party library is by qfun (qfun_g9s), not my script.

## Downloads

<!-- stats:start -->
| script | downloads | latest |
| --- | --- | --- |
| [Tinker Turret Dodge](scripts/tinker_turret_dodge) | 4 | `tinker-turret-dodge-v1.1.5` |
| [Tinker Auto Farm](scripts/tinker_auto_farm) | 4 | `tinker-auto-farm-v1.0.3` |
| [Auto Shackleshot](scripts/auto_shackleshot) | 2 | `auto-shackleshot-v1.0.0` |
| [Auto Spark](scripts/auto_spark) | 1 | `auto-spark-v1.0.0` |
| [Rune Destruction](scripts/rune_destruction) | 1 | `rune-destruction-v1.0.2` |
| [Earth Spirit Kick Combo](scripts/earth_spirit_kick_combo) | 1 | `earth-spirit-kick-combo-v1.0.0` |
| [HP/Mana 67 Ping](scripts/hp_mana_67_ping) | 1 | `hp-mana-67-ping-v1.0.1` |
| [Spirit Bear Pull](scripts/spirit_bear_pull) | 1 | `spirit-bear-pull-v1.0.0` |
| [Dorman Combo Assistant](scripts/dorman_combo_assistant) | 1 | `dorman-combo-assistant-v1.0.0` |
| [Rem Assistant](scripts/rem_assistant) | 1 | `rem-assistant-v1.0.0` |
| [Souls Vault / Rem's Tunnel ESP](scripts/vault_tunnel_esp) | 1 | `vault-tunnel-esp-v1.0.0` |
| [qLocalization](scripts/q_localizer) | 4 | `q-localizer-v1.0.0` |
| [Script Manager](scripts/script_manager) | 2 | `script-manager-v1.4.0` |

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/stats/stats-dark.svg">
  <img alt="Downloads over time" src=".github/stats/stats-light.svg" width="840">
</picture>

2026-10-12
<!-- stats:end -->
