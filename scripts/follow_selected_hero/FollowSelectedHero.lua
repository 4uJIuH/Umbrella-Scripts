local protobuf = require('protobuf')
local JSON = require('assets.JSON');

local follow = {}

local RADIANT_FOUNTAIN = Vector(6752.5625, 6281.28125, 384.0)
local DIRE_FOUNTAIN = Vector(-6988.40625, -6464.71875, 384.0)

local ui = {}
local built = false

local overlay = {
  fonts = { general = nil, ui = nil, title = nil, icon = nil },
  last_lines = {},
  last_action = "Idle",
  init_done = false,
  last_target_name = "",
  last_distance = 0,
  enemy_nearby = false,
  tp_ready = false,
  tether_status = "disconnected",
}

local WardHelper = nil
local WARD_OBSERVER_ID = 42
local WARD_SENTRY_ID = 43

Event.AddListener("dota_hero_on_gain_aggro")

local function overlay_init()
  if overlay.init_done then return end
  if not Render or not Enum then return end
  overlay.fonts.general = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
  overlay.fonts.ui = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
  overlay.fonts.title = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
  overlay.fonts.icon = Render.LoadFont("Segoe UI Symbol", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
  overlay.init_done = true
end

local function status_push(msg)
  if not msg or msg == "" then return end
  overlay.last_action = msg
  local t = GlobalVars.GetCurTime() or 0
  overlay.last_lines[#overlay.last_lines + 1] = { text = msg, time = t, fade = 1.0 }
  if #overlay.last_lines > 8 then
    table.remove(overlay.last_lines, 1)
  end
end

local function BuildUI()
  if built then return end
  local tab = Menu.Create("Scripts", "Utility", "Follow Hero")
  tab:Icon("\u{f554}")

  local followTab = tab:Create("Follow")
  local behavior = followTab:Create("Behavior")
  ui.enabled = behavior:Switch("Enable", false, "\u{f011}")
  ui.auto_select = behavior:Combo("Auto-Select Criterion", { "None", "Most Deaths", "Most Kills", "Best K/D" }, 0)
  ui.language = behavior:Combo("Chat Language", { "English", "Russian" }, 0)
  ui.should_chat = behavior:Switch("Should use chat", false, "\u{f011}")
  ui.movement_mode = behavior:Combo("Movement Mode", { "Behind Ally", "Smart Adaptive" }, 1)
  ui.distance = behavior:Slider("Follow Distance", 100, 1200, 350, "%d")
  ui.interval = behavior:Slider("Order Interval (ms)", 50, 1000, 150, "%d ms")
  ui.move_threshold = behavior:Slider("Move Threshold (u)", 10, 200, 30, "%d")

  local tp = followTab:Create("Teleport")
  ui.tp_enabled = tp:Switch("Enable", true, "\u{f362}")
  local tp_gear = ui.tp_enabled:Gear("Advanced")
  ui.tp_distance = tp_gear:Slider("TP Min Distance", 1500, 10000, 3000, "%d")

  local safety = followTab:Create("Safety")
  ui.safe_follow = safety:Switch("Enable", true, "\u{f3ed}")
  local safety_gear = ui.safe_follow:Gear("Advanced")
  ui.enemy_radius = safety_gear:Slider("Danger Radius", 300, 2500, 900, "%d")
  ui.min_enemy_distance = safety_gear:Slider("Keep Distance", 200, 2000, 700, "%d")
  ui.fountain_bias = safety_gear:Slider("Fountain Bias (u)", 0, 1200, 200, "%d")

  local wards = followTab:Create("Wards")
  ui.wards_enabled = wards:Switch("Enable", true, "\u{f1eb}")

  local ioRoot = tab:Create("Io Assistant")

  local ioTether = ioRoot:Create("Tether")
  ui.io_enabled = ioTether:Switch("Enable", true, "\u{f0c1}")
  local tether_gear = ui.io_enabled:Gear("Settings")
  ui.io_use_follow_target = tether_gear:Switch("Use Follow Target", true, "\u{f058}")
  ui.io_recast = tether_gear:Switch("Re-tether if Broken", true, "\u{f2f1}")
  ui.io_interval = tether_gear:Slider("Try Interval (ms)", 100, 2000, 300, "%d ms")
  ui.io_tether_buffer = tether_gear:Slider("Range Buffer (u)", 0, 300, 50, "%d")

  local ioCombat = ioRoot:Create("Combat")
  ui.io_auto_upgrade = ioCombat:Switch("Auto Upgrade", true, "\u{f2dd}")
  local combat_gear = ui.io_auto_upgrade:Gear("Advanced")
  ui.io_overcharge_hp_enabled = combat_gear:Switch("Overcharge when HP missing", true, "\u{f1e6}")
  ui.io_spirits_mana = combat_gear:Slider("Spirits Min Mana %", 0, 100, 50, "%d%%")
  ui.io_spirits_enemy_radius = combat_gear:Slider("Spirits Enemy Radius", 400, 1200, 700, "%d")

  local ioAttack = ioRoot:Create("Attack")
  ui.io_attack_with_hero = ioAttack:Switch("Attack with Hero", false, "\u{f140}")
  local attack_gear = ui.io_attack_with_hero:Gear("Settings")
  ui.io_attack_aggro_delay = attack_gear:Slider("Aggro Check Delay (ms)", 50, 500, 100, "%d ms")

  local harass = ioRoot:Create("Harass")
  ui.harass_enabled = harass:Switch("Enable", false, "\u{f06e}")
  local harass_gear = ui.harass_enabled:Gear("Settings")
  ui.harass_safe = harass_gear:Switch("Safe Harass (Threat-aware)", true, "\u{f3ed}")
  ui.harass_radius = harass_gear:Slider("Radius (u)", 300, 1400, 800, "%d")
  ui.harass_threat_limit = harass_gear:Slider("Max Threat to Engage", 0, 120, 35, "%d")
  ui.harass_min_hp_pct = harass_gear:Slider("Stop if HP below %", 1, 100, 35, "%d%%")
  ui.harass_order_cd_ms = harass_gear:Slider("Order Cooldown (ms)", 100, 1000, 250, "%d ms")

  local buyTab = tab:Create("Auto Buy"):Create("Build")
  ui.autobuy_enabled = buyTab:Switch("Enable", false, "\u{f07a}")
  local buy_gear = ui.autobuy_enabled:Gear("Settings")
  ui.autobuy_interval = buy_gear:Slider("Check Interval (s)", 1, 30, 3, "%d s")

  local itemTab = tab:Create("Item Check"):Create("Ownership")
  ui.itemcheck_enabled = itemTab:Switch("Enable", true, "\u{f292}")
  local item_gear = ui.itemcheck_enabled:Gear("Settings")
  ui.itemcheck_interval = item_gear:Slider("Check Interval (s)", 1, 10, 2, "%d s")

  built = true
end

local state = {
  hero = nil,
  player = nil,
  player_id = nil,
  my_pos = nil,
  timers = {},
  io = {
    allies = {},
    last_ally_update = 0,
    current_tether_target = nil,
    last_aggro_target = nil,
    last_aggro_attacker = nil,
    last_aggro_time = 0,
    attack_hold_until = 0,
    attack_target = nil,
  },
  follow = {
    auto_target = nil,
    current_target = nil,
    last_move_dest = nil,
  },
  autobuy = {
    stage_index = 1,
    secret_active = false,
    secret_target = nil,
    done = false,
  },
  link = {
    waiting = false,
    wait_start = 0,
    linked_player_id = nil,
    manual = false,
    last_unlink_reminder = 0,
    excluded_player_id = nil,
    last_random_target = nil,
    last_random_time = 0,
  },
  harass = {
    enabled = false,
    safe = true,
    last_order = 0,
  },
  wards = {
    helper = nil,
    has_positions = false,
    observer_spots = {},
    sentry_spots = {},
    heat_samples = {},
    heat_center = nil,
    last_sample = 0,
    heat_window = 45,
    sample_interval = 0.5,
    obs_plan_at = 0,
    sentry_plan_at = 0,
    next_observer = nil,
    next_sentry = nil,
    enemy_wards = {},
    recent_places = {},
    pause_follow_until = 0,
    placing = false,
    place_timeout = 0,
    swap_back_slot = nil,
    last_purchase = 0,
    last_place_time = 0,
    last_place_kind = nil,
    no_item_until = 0,
    next_place_after = 0,
    last_debug = 0,
  },
  buy_cmd = {
    last_time = 0,
    cooldown = 20,
  },
  use_cmd = {
    last_time = 0,
    cooldown = 3,
  },
  use_pending = nil,
  chat_channel = nil,
  announced_start = false,
  game_init_done = false,
}

local function is_courier_at_secret_shop(courier)
  if not courier then return false end
  if not Courier or not Courier.GetCourierState then return false end
  local st = Courier.GetCourierState(courier)
  local atSecret = (Enum and Enum.CourierState and Enum.CourierState.COURIER_STATE_AT_SECRET_SHOP) or 7
  return st == atSecret
end

local AUTOBUY_STAGES = {
  {
    complete_item = "item_mekansm",
    components = {
      { name = "item_ring_of_regen",    id = 27, done_if = { "item_headdress", "item_mekansm" } },
      { name = "item_recipe_headdress", id = 93, done_if = { "item_headdress", "item_mekansm" } },
      { name = "item_chainmail",        id = 4,  done_if = { "item_mekansm" } },
      { name = "item_recipe_mekansm",   id = 78, done_if = { "item_mekansm" } },
    }
  },
  {
    complete_item = "item_holy_locket",
    components = {
      { name = "item_magic_stick",        id = 34,  done_if = { "item_magic_wand", "item_holy_locket" } },
      { name = "item_branches",           id = 16,  qty = 2,                                            done_if = { "item_magic_wand", "item_holy_locket" } },
      { name = "item_recipe_magic_wand",  id = 35,  done_if = { "item_magic_wand", "item_holy_locket" } },
      { name = "item_crown",              id = 261, done_if = { "item_holy_locket" } },
      { name = "item_recipe_holy_locket", id = 268, done_if = { "item_holy_locket" } },
    }
  },
  {
    complete_item = "item_glimmer_cape",
    components = {
      { name = "item_shadow_amulet",       id = 215, done_if = { "item_glimmer_cape" } },
      { name = "item_cloak",               id = 31,  done_if = { "item_glimmer_cape" } },
      { name = "item_recipe_glimmer_cape", id = 253, done_if = { "item_glimmer_cape" } },
    }
  },
  {
    complete_item = "item_solar_crest",
    components = {
      { name = "item_energy_booster",     id = 59,   done_if = { "item_pavise", "item_solar_crest" }, secret_shop = true },
      { name = "item_ring_of_protection", id = 12,   done_if = { "item_pavise", "item_solar_crest" } },
      { name = "item_fluffy_hat",         id = 593,  done_if = { "item_pavise", "item_solar_crest" } },
      { name = "item_recipe_pavise",      id = 1127, done_if = { "item_pavise", "item_solar_crest" } },
      { name = "item_crown",              id = 261,  done_if = { "item_solar_crest" } },
      { name = "item_wind_lace",          id = 244,  done_if = { "item_solar_crest" } },
      { name = "item_recipe_solar_crest", id = 227,  done_if = { "item_solar_crest" } },
    }
  },
  {
    complete_item = "item_pipe",
    components = {
      { name = "item_cloak",             id = 31,  done_if = { "item_pipe" } },
      { name = "item_ring_of_regen",     id = 27,  done_if = { "item_headdress", "item_pipe" } },
      { name = "item_recipe_headdress",  id = 93,  done_if = { "item_headdress", "item_pipe" } },
      { name = "item_ring_of_tarrasque", id = 279, done_if = { "item_pipe" } },
      { name = "item_recipe_pipe",       id = 89,  done_if = { "item_pipe" } },
    }
  },
  {
    complete_item = "item_lotus_orb",
    components = {
      { name = "item_ring_of_health",   id = 56,  done_if = { "item_pers" } },
      { name = "item_void_stone",       id = 57,  done_if = { "item_pers" } },
      { name = "item_recipe_pers",      id = 68,  done_if = { "item_pers" } },
      { name = "item_platemail",        id = 9,   done_if = { "item_lotus_orb" }, secret_shop = true },
      { name = "item_energy_booster",   id = 59,  done_if = { "item_lotus_orb" }, secret_shop = true },
      { name = "item_recipe_lotus_orb", id = 221, done_if = { "item_lotus_orb" } },
    }
  },
}
local function my()
  state.hero = state.hero or Heroes.GetLocal()
  return state.hero
end

local function player()
  if state.player then return state.player end
  state.player = Players.GetLocal()
  return state.player
end

local function player_id()
  if state.player_id then return state.player_id end
  local p = player()
  state.player_id = p and Player.GetPlayerID(p) or nil
  return state.player_id
end

local function get_item_by_index_any(me, idx)
  if not me then return nil end
  if not NPC.GetItemByIndex then return nil end
  return NPC.GetItemByIndex(me, idx)
end

local function has_item_any(me, item_name)
  if not me or not item_name then return false end
  if NPC.HasItem(me, item_name, false) == true then
    return true
  end
  local p = player()
  if p and Player.GetNeutralStashItems then
    local stash_items = Player.GetNeutralStashItems(p)
    if stash_items then
      for _, it in ipairs(stash_items) do
        if it then
          local nm = Ability.GetName(it)
          if nm == item_name then
            return true
          end
        end
      end
    end
  end
  if Couriers and Couriers.GetLocal then
    local courier = Couriers.GetLocal()
    if courier then
      for i = 0, 20 do
        local it = get_item_by_index_any(courier, i)
        if it then
          local nm = Ability.GetName(it)
          if nm == item_name then
            return true
          end
        end
      end
    end
  end
  return false
end

local function count_item_any(me, item_name)
  if not me or not item_name then return 0 end
  local count = 0
  for i = 0, 20 do
    local it = get_item_by_index_any(me, i)
    if it then
      local nm = Ability.GetName(it)
      if nm == item_name then
        count = count + 1
      end
    end
  end
  local p = player()
  if p and Player.GetNeutralStashItems then
    local stash_items = Player.GetNeutralStashItems(p)
    if stash_items then
      for _, it in ipairs(stash_items) do
        if it then
          local nm = Ability.GetName(it)
          if nm == item_name then
            count = count + 1
          end
        end
      end
    end
  end
  if Couriers and Couriers.GetLocal then
    local courier = Couriers.GetLocal()
    if courier then
      for i = 0, 20 do
        local it = get_item_by_index_any(courier, i)
        if it then
          local nm = Ability.GetName(it)
          if nm == item_name then
            count = count + 1
          end
        end
      end
    end
  end
  return count
end

local function is_autobuy_component_done(me, stage_complete_item, component)
  if not me then return true end
  if stage_complete_item and has_item_any(me, stage_complete_item) then
    return true
  end
  if component and component.done_if then
    for i = 1, #component.done_if do
      if has_item_any(me, component.done_if[i]) then
        return true
      end
    end
  end
  local need_qty = (component and component.qty) or 1
  return count_item_any(me, component.name) >= need_qty
end

local translations = {
  start_en = "This is Wisp bot. Type !help for commands, if no one says !link in a minute will link to a random.",
  start_ru =
  "Это бот Wisp. Напишите !help для команд, если никто не напишет !link в течении минуты привяжусь к рандому.",
  commands_en =
  "Commands: !link, !unlink, !relocate <enemy>, !autoharass on/off, !safeharass on/off, !assist on/off, !distance <u>, !tp on/off, !buy <tango|clarity|salve|mango>, !use <tango|clarity|salve|mango>",
  commands_ru =
  "Команды: !link, !unlink, !relocate <враг>, !autoharass on/off, !safeharass on/off, !assist on/off, !distance <u>, !tp on/off, !buy <tango|clarity|salve|mango>, !use <tango|clarity|salve|mango>",
  linked_en = "Linked to",
  linked_ru = "Привязан к",
  unlinked_en = "Unlinked. Waiting for !link or auto-link in 60s.",
  unlinked_ru = "Отвязан. Ожидание !link или авто-привязка через 60с.",
  forcelink_success_en = "Force linked to",
  forcelink_success_ru = "Принудительно привязан к",
  forcelink_failed_en = "Hero not found",
  forcelink_failed_ru = "Герой не найден",
  forcelink_denied_en = "Only local player can use !forcelink",
  forcelink_denied_ru = "Только локальный игрок может использовать !forcelink",
  relocating_en = "Relocating to last seen position of",
  relocating_ru = "Телепорт к последней позиции",
  relocate_failed_en = "Relocate failed: relo on cd/not learned",
  relocate_failed_ru = "Телепорт не удался рело в кд/не вкачено",
  unlink_reminder_en =
  "If you don't want me tethered to you, type !unlink (All commands in !help, remember I can teleport to enemies with !relocate hero_name)",
  unlink_reminder_ru =
  "Если вы не хотите что бы я был к вам привязан напишите !unlink (Все команды в !help, не забывайте что я могу телепортироваться к врагам с !relocate имя_героя)",
  linked_status_en = "Linked: %s",
  linked_status_ru = "Привязан: %s",
  auto_link_en = "Auto-link: %s",
  auto_link_ru = "Авто-привязка: %s",
  relocating_fountain_en = "Relocating to fountain",
  relocating_fountain_ru = "Телепорт к фонтану",
  move_status_en = "Move: (%.0f, %.0f) d=%.0f",
  move_status_ru = "Движение: (%.0f, %.0f) d=%.0f",
  attack_status_en = "Attack: %s (d=%.0f)",
  attack_status_ru = "Атака: %s (d=%.0f)",
  chase_status_en = "Chase: %s (d=%.0f)",
  chase_status_ru = "Преследую: %s (d=%.0f)",
  harass_attack_en = "Harass: attack %s",
  harass_attack_ru = "Харасс: атакую %s",
  harass_chase_en = "Harass: chase %s",
  harass_chase_ru = "Харасс: преследую %s",
  tp_scroll_anchor_en = "TP: scroll -> anchor (d=%d)",
  tp_scroll_anchor_ru = "ТП: свиток -> якорь (d=%d)",
  tp_unavailable_en = "TP: unavailable (tp=%s, ch=%s)",
  tp_unavailable_ru = "ТП: недоступно (tp=%s, ch=%s)",
  io_tether_to_en = "Io: tether -> %s (d=%d)",
  io_tether_to_ru = "Ио: связка -> %s (d=%d)",
  io_overcharge_en = "Io: overcharge (missing HP on %s)",
  io_overcharge_ru = "Ио: overcharge (неполное ХП: %s)",
  io_spirits_en = "Io: spirits (enemy nearby)",
  io_spirits_ru = "Ио: spirits (рядом враг)",
  self_label_en = "self",
  self_label_ru = "сам",
  autobuy_complete_en = "AutoBuy: build complete",
  autobuy_complete_ru = "АвтоПокупка: сборка завершена",
  courier_go_secret_en = "Courier: go Secret for %s",
  courier_go_secret_ru = "Курьер: на секретка за %s",
  courier_at_secret_en = "Courier: at Secret, buy with courier",
  courier_at_secret_ru = "Курьер: на секретке, покупаю",
  autobuy_component_en = "AutoBuy: %s (id=%d)",
  autobuy_component_ru = "АвтоПокупка: %s (id=%d)",
  drop_hero_item_en = "Drop hero item: %s (owner=%d)",
  drop_hero_item_ru = "Сбросить предмет героя: %s (владелец=%d)",
  drop_courier_item_en = "Drop courier item: %s (owner=%d)",
  drop_courier_item_ru = "Сбросить предмет курьера: %s (владелец=%d)",
  auto_harass_on_en = "Auto Harass: ON",
  auto_harass_on_ru = "Авто харасс: ВКЛ",
  auto_harass_off_en = "Auto Harass: OFF",
  auto_harass_off_ru = "Авто харасс: ВЫКЛ",
  harass_enabled_en = "Harass: enabled",
  harass_enabled_ru = "Харасс: включён",
  harass_disabled_en = "Harass: disabled",
  harass_disabled_ru = "Харасс: выключен",
  safe_harass_on_en = "Safe Harass: ON",
  safe_harass_on_ru = "Безопасный харасс: ВКЛ",
  safe_harass_off_en = "Safe Harass: OFF",
  safe_harass_off_ru = "Безопасный харасс: ВЫКЛ",
  harass_safe_en = "Harass: safe",
  harass_safe_ru = "Харасс: безопасный",
  harass_aggressive_en = "Harass: aggressive",
  harass_aggressive_ru = "Харасс: агрессивный",
  assist_on_en = "Assist: ON",
  assist_on_ru = "Помощь: ВКЛ",
  assist_off_en = "Assist: OFF",
  assist_off_ru = "Помощь: ВЫКЛ",
  distance_set_en = "Distance set to %d",
  distance_set_ru = "Дистанция установлена на %d",
  tp_on_en = "TP usage: ON",
  tp_on_ru = "Исп. ТП: ВКЛ",
  tp_off_en = "TP usage: OFF",
  tp_off_ru = "Исп. ТП: ВЫКЛ",
  harass_radius_set_en = "Harass radius set to %d",
  harass_radius_set_ru = "Радиус харасса: %d",
  buy_wait_en = "Buy cooldown: wait %ds",
  buy_wait_ru = "Перезарядка покупки: подождите %dс",
  buy_success_en = "Buy: %s",
  buy_success_ru = "Покупка: %s",
  buy_invalid_en = "Buy failed: invalid entry",
  buy_invalid_ru = "Покупка не удалась: неверный ввод",
  buy_unknown_en = "Unknown item. Try: tango/clarity/salve/mango/dust",
  buy_unknown_ru = "Неизвестный предмет. Пробуйте: tango/clarity/salve/mango/dust",
  buy_already_have_en = "Already have %s",
  buy_already_have_ru = "Уже есть %s",
  use_unknown_en = "Unknown consumable. Try: tango/clarity/salve/mango",
  use_unknown_ru = "Неизвестный расходник. Пробуйте: tango/clarity/salve/mango",
  use_wait_en = "Use cooldown: wait %ds",
  use_wait_ru = "Перезарядка использования: подождите %dс",
  use_missing_en = "No consumable found: %s",
  use_missing_ru = "Не найден расходник: %s",
  move_backpack_fail_en = "Cannot move from backpack; free a slot",
  move_backpack_fail_ru = "Не могу переместить из рюкзака: освободите слот",
  use_preparing_en = "Preparing to use: %s",
  use_preparing_ru = "Готовлюсь использовать: %s",
  use_pending_en = "Use pending: %s",
  use_pending_ru = "Ожидание использования: %s",
  use_waiting_en = "Waiting for cooldown: %s",
  use_waiting_ru = "Жду перезарядку: %s",
  use_wait_status_en = "Use wait: %s",
  use_wait_status_ru = "Ожидание: %s",
  no_ally_en = "No ally to use on",
  no_ally_ru = "Нет союзника для применения",
  mango_on_ally_fail_en = "Cannot use mango on ally",
  mango_on_ally_fail_ru = "Нельзя использовать манго на союзнике",
  no_tree_near_ally_en = "No tree near ally for tango",
  no_tree_near_ally_ru = "Нет дерева рядом с союзником для танго",
  use_success_en = "Use: %s",
  use_success_ru = "Использование: %s",
  pending_use_missing_en = "Pending use failed: item missing",
  pending_use_missing_ru = "Ожидание использования: предмет отсутствует",
  use_failed_missing_en = "Use failed: missing",
  use_failed_missing_ru = "Использование не удалось: отсутствует",
  use_timeout_move_en = "Use cancelled: timeout moving",
  use_timeout_move_ru = "Отмена: истекло время перемещения",
  use_timeout_status_en = "Use timeout",
  use_timeout_status_ru = "Таймаут использования",
  use_timeout_cd_en = "Use cancelled: still on cooldown",
  use_timeout_cd_ru = "Отмена: ещё перезарядка",
  use_cd_status_en = "Use cooldown",
  use_cd_status_ru = "Перезарядка использования",
}

local function translate(key)
  local lang = (ui.language and ui.language:Get() == 1) and "ru" or "en"
  return translations[key .. "_" .. lang] or key
end

local function t(key, ...)
  local s = translate(key)
  if select('#', ...) > 0 then
    return string.format(s, ...)
  end
  return s
end

local function now()
  return GlobalVars.GetCurTime() or 0
end

local function timer_set(key, delay)
  state.timers[key] = now() + delay
end

local function timer_due(key)
  return (state.timers[key] or 0) <= now()
end

local function timer_ready(key, interval)
  local t = now()
  local next_at = state.timers[key] or 0
  if t >= next_at then
    state.timers[key] = t + interval
    return true
  end
  return false
end

local function get_display_name(hero)
  local unit_name = NPC.GetUnitName(hero)
  local display = Engine.GetDisplayNameByUnitName(unit_name)
  return display or unit_name
end

local function hero_icon_for(unit_name)
  local short = string.match(unit_name or "", "npc_dota_hero_(.+)") or unit_name or "unknown"
  return "panorama/images/heroes/icons/" .. short .. "_png.vtex_c"
end

local function is_valid_follow_target(h)
  if not h then return false end
  if not Entity.IsAlive(h) then return false end
  if NPC.IsIllusion(h) then return false end
  if h == my() then return false end
  return true
end

local function rebuild_io_ally_list(force)
  if not built then return end
  local t = now()
  if not force and (t - state.io.last_ally_update) < 1.0 then return end
  state.io.last_ally_update = t
  if not Engine.IsInGame() then
    state.io.allies = {}
    return
  end
  local me = my()
  if not me then
    state.io.allies = {}
    return
  end
  local allies = {}
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if h ~= me and Entity.IsAlive(h) and not NPC.IsIllusion(h) and Entity.IsSameTeam(me, h) then
      table.insert(allies, h)
    end
  end
  state.io.allies = allies
end

local function get_friendly_fountain(me)
  if not me then return RADIANT_FOUNTAIN end
  local team = Entity.GetTeamNum(me)
  return (team == 2) and DIRE_FOUNTAIN or RADIANT_FOUNTAIN
end

local function analyze_threat_landscape(my_pos, target_pos)
  local me = my()
  if not me then return { threats = {}, threat_score = 0, danger_zone = false } end

  local my_team = Entity.GetTeamNum(me)
  local all_heroes = Heroes.GetAll() or {}
  local threats = {}
  local total_threat_score = 0

  for _, enemy in ipairs(all_heroes) do
    if Entity.GetTeamNum(enemy) ~= my_team and Entity.IsAlive(enemy) and not NPC.IsIllusion(enemy) then
      local enemy_pos = Entity.GetAbsOrigin(enemy) or Hero.GetLastMaphackPos(enemy)
      if enemy_pos then
        local dist_to_me = my_pos:Distance2D(enemy_pos)
        local dist_to_target = target_pos and target_pos:Distance2D(enemy_pos) or dist_to_me

        local base_damage = NPC.GetTrueDamage(enemy)
        local enemy_hp_pct = (Entity.GetHealth(enemy) / Entity.GetMaxHealth(enemy)) * 100
        local enemy_armor = (NPC.GetPhysicalArmorValue(enemy) or 0)
        local is_attacking = NPC.IsAttacking(enemy)
        local attack_range = (NPC.GetAttackRange(enemy) or 150) + (NPC.GetHullRadius(enemy) or 0)

        local is_visible = NPC.IsVisible and NPC.IsVisible(enemy)

        local proximity_threat = 1.0 / math.max(dist_to_me, 300)
        local visibility_threat = is_visible and (dist_to_me < 1200 and 1.0 or 0.3) or 0.6
        local health_threat = (100 - enemy_hp_pct) / 100
        local position_advantage = dist_to_target < dist_to_me and 1.2 or 1.0

        local threat_score = base_damage * proximity_threat * visibility_threat * health_threat *
            position_advantage
        local in_attack_range = dist_to_me < (attack_range + 150)

        table.insert(threats, {
          entity = enemy,
          position = enemy_pos,
          distance = dist_to_me,
          threat_score = threat_score,
          in_attack_range = in_attack_range,
          is_attacking = is_attacking,
          health_pct = enemy_hp_pct,
          armor = enemy_armor,
          is_visible = is_visible,
        })

        total_threat_score = total_threat_score + threat_score
      end
    end
  end

  table.sort(threats, function(a, b) return a.threat_score > b.threat_score end)

  local danger_zone = false
  for _, threat in ipairs(threats) do
    if threat.in_attack_range and threat.is_attacking then
      danger_zone = true
      break
    end
  end

  return {
    threats = threats,
    threat_score = total_threat_score,
    danger_zone = danger_zone,
    primary_threat = threats[1],
  }
end
local function is_currently_tethered(me)
  if not me then return false end
  return NPC.HasModifier(me, "modifier_wisp_tether") or NPC.HasModifier(me, "modifier_io_tether")
end
local function adjust_for_environment(me, dest)
  if not me or not dest then return dest end

  local tethered = is_currently_tethered(me) and state.io and state.io.current_tether_target and
      Entity.IsAlive(state.io.current_tether_target)

  if NPCs and NPCs.GetAll then
    local towers = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_TOWER) or {}
    local closest, closest_dist = nil, math.huge
    for _, t in ipairs(towers) do
      if t and Entity.IsAlive(t) and not Entity.IsSameTeam(me, t) then
        local tp = Entity.GetAbsOrigin(t)
        if tp then
          local d = tp:Distance2D(dest)
          if d < closest_dist then
            closest_dist = d
            closest = tp
          end
        end
      end
    end
    if closest and closest_dist < 1200 then
      if not tethered then
        local push = math.max(280, 1200 - closest_dist)
        dest = dest + (dest - closest):Normalized() * math.min(push, 520)
      end
    end
  end

  if NPCs and NPCs.InRadius then
    local creeps = NPCs.InRadius(dest, 850, Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY, true, true) or {}
    local enemy_creep_count = 0
    for _, c in pairs(creeps) do
      if c and Entity.IsAlive(c) then
        local is_creep = (NPC.IsLaneCreep and NPC.IsLaneCreep(c)) or (NPC.IsCreep and NPC.IsCreep(c)) or false
        if is_creep then
          enemy_creep_count = enemy_creep_count + 1
        end
      end
    end
    if enemy_creep_count >= 6 then
      local fountain = get_friendly_fountain(me) or dest
      local offset = (fountain - dest):Normalized() * math.min(220 + enemy_creep_count * 8, 420)
      dest = dest + offset
    end
  end

  return dest
end

local function ensure_traversable_from(src, pos)
  if not src or not pos then return pos end

  local npc_map = GridNav.CreateNpcMap and GridNav.CreateNpcMap({ my() }, true) or nil
  local traversable = GridNav.IsTraversableFromTo and GridNav.IsTraversableFromTo(src, pos, false, npc_map)
  if traversable then
    if npc_map and GridNav.ReleaseNpcMap then GridNav.ReleaseNpcMap(npc_map) end
    return pos
  end

  if GridNav.BuildPath then
    local path = GridNav.BuildPath(src, pos, false, npc_map)
    if npc_map and GridNav.ReleaseNpcMap then GridNav.ReleaseNpcMap(npc_map) end
    if path and #path > 0 then
      return path[#path]
    end
  elseif npc_map and GridNav.ReleaseNpcMap then
    GridNav.ReleaseNpcMap(npc_map)
  end

  if GridNav.IsTraversable and GridNav.IsTraversable(pos) then return pos end
  local dir = (pos - src):Normalized()
  local step = 64
  local attempts = 12
  for i = 1, attempts do
    local test1 = pos + dir * (step * i)
    if GridNav.IsTraversable and GridNav.IsTraversable(test1) then return test1 end
    local test2 = pos - dir * (step * i)
    if GridNav.IsTraversable and GridNav.IsTraversable(test2) then return test2 end
  end
  return pos
end

local function compute_dest_behind(my_pos, target)
  local target_pos = Entity.GetAbsOrigin(target)
  local me = my()
  if not me then return target_pos end

  local want = ui.distance:Get()
  local forward = Entity.GetAbsRotation(target):GetForward():Normalized()
  local dest = target_pos - forward * want
  return ensure_traversable_from(my_pos, dest)
end

local function compute_dest_smart(my_pos, target, attack_info)
  local target_pos = Entity.GetAbsOrigin(target)
  local me = my()
  if not me then return target_pos end

  if attack_info and attack_info.active and attack_info.target then
    local attack_target_pos = Entity.GetAbsOrigin(attack_info.target)
    if attack_target_pos then
      local hull = NPC.GetHullRadius(me) or 0
      local attack_range = (NPC.GetAttackRange(me) or 150) + hull + 35
      local optimal_dist = attack_range * 0.85
      local dir_to_target = (attack_target_pos - my_pos):Normalized()
      return attack_target_pos - dir_to_target * optimal_dist
    end
  end

  local want_dist = ui.distance:Get()
  local target_hp = Entity.GetHealth(target)
  local target_max_hp = Entity.GetMaxHealth(target)
  local target_hp_pct = (target_hp / target_max_hp) * 100
  local is_target_attacking = NPC.IsAttacking(target)

  local threat_data = analyze_threat_landscape(my_pos, target_pos)
  local total_threat = threat_data.threat_score
  local primary_threat = threat_data.primary_threat
  local danger_zone = threat_data.danger_zone

  local my_team = Entity.GetTeamNum(me)
  local all_heroes = Heroes.GetAll() or {}
  local support_count = 0
  local avg_ally_pos = Vector(0, 0, 0)
  for _, ally in ipairs(all_heroes) do
    if Entity.GetTeamNum(ally) == my_team and Entity.IsAlive(ally) and ally ~= target then
      support_count = support_count + 1
      avg_ally_pos = avg_ally_pos + Entity.GetAbsOrigin(ally)
    end
  end
  if support_count > 0 then
    avg_ally_pos = avg_ally_pos / support_count
  end

  local fountain_pos = get_friendly_fountain(target)

  local dest = target_pos

  if target_hp_pct < 25 and danger_zone and primary_threat then
    local threat_pos = primary_threat.position
    local defend_pos = target_pos + (target_pos - threat_pos):Normalized() * (want_dist * 0.25)

    local toward_fountain = (fountain_pos - defend_pos):Normalized()
    dest = defend_pos + toward_fountain * (want_dist * 0.2)
  elseif target_hp_pct < 45 and is_target_attacking and danger_zone then
    if primary_threat then
      local threat_pos = primary_threat.position
      local away_vec = (target_pos - threat_pos):Normalized()

      if support_count == 0 then
        dest = target_pos + away_vec * (want_dist * 0.4)
      elseif support_count >= 2 then
        dest = target_pos + away_vec * (want_dist * 0.7)
      else
        dest = target_pos + away_vec * (want_dist * 0.55)
      end
    else
      dest = target_pos - (target_pos - my_pos):Normalized() * (want_dist * 0.5)
    end
  elseif is_target_attacking and total_threat > 20 then
    if primary_threat then
      local threat_pos = primary_threat.position
      local away_vec = (target_pos - threat_pos):Normalized()

      local spread_mult = support_count >= 2 and 0.85 or 0.95
      dest = target_pos + away_vec * (want_dist * spread_mult)
    else
      local dir = (fountain_pos - target_pos):Normalized()
      dest = target_pos + dir * (want_dist * 0.9)
    end
  else
    local tactical_enemies = 0
    for i, threat in ipairs(threat_data.threats) do
      if i <= 3 and threat.distance < 1500 then
        tactical_enemies = tactical_enemies + 1
      end
    end

    if tactical_enemies >= 3 then
      if primary_threat then
        local threat_vec = (my_pos - primary_threat.position):Normalized()
        local spread_angle = math.pi / 6 * (tactical_enemies - 2)
        local rotated_spread = Vector(
          threat_vec.x * math.cos(spread_angle) - threat_vec.y * math.sin(spread_angle),
          threat_vec.x * math.sin(spread_angle) + threat_vec.y * math.cos(spread_angle),
          0
        ):Normalized()
        dest = target_pos + rotated_spread * (want_dist * 1.2)
      else
        dest = target_pos + Vector(1, 0, 0) * want_dist
      end
    else
      local dir = (fountain_pos - target_pos):Normalized()
      dest = target_pos + dir * want_dist
    end
  end

  if ui.safe_follow:Get() and not (attack_info and attack_info.active) then
    if target_hp_pct > 65 and not danger_zone then
      local to_fountain = (fountain_pos - dest):Normalized()
      local fountain_bias = (ui.fountain_bias and ui.fountain_bias:Get()) or 300
      dest = dest + to_fountain * (fountain_bias * 0.4)
    end
  end

  dest = adjust_for_environment(me, dest)

  return dest
end

local function compute_dest(my_pos, target, attack_info)
  local mode = (ui.movement_mode and ui.movement_mode:Get()) or 1
  if mode == 0 then
    return compute_dest_behind(my_pos, target)
  end
  return compute_dest_smart(my_pos, target, attack_info)
end

local function is_in_fountain(unit)
  return NPC.HasModifier(unit, "modifier_fountain_aura")
end

local function is_item_enabled(item)
  if not item then return false end
  if Item.IsItemEnabled and not Item.IsItemEnabled(item) then return false end
  return true
end

local function get_item_charges(item)
  if not item then return 0 end
  if Item.GetCurrentCharges then
    return Item.GetCurrentCharges(item) or 0
  end
  return 0
end

local function is_item_ready(item)
  if not item then return false end
  if not is_item_enabled(item) then return false end
  local charges = get_item_charges(item)
  if charges ~= nil and charges <= 0 then return false end
  return true
end

local function get_item_by_names(me, names)
  if not me or not names then return nil end
  for i = 0, 8 do
    local it = NPC.GetItemByIndex(me, i)
    if it then
      local nm = Ability.GetName(it)
      if nm and names[nm] then
        return it
      end
    end
  end
  return nil
end

local function get_friendly_item_name(item_name)
  if GameLocalizer and GameLocalizer.FindItem then
    local ok, res = pcall(function() return GameLocalizer.FindItem(item_name) end)
    if ok and res and type(res) == "string" and #res > 0 then
      return res
    end
  end
  return item_name
end

local function get_item_and_slot(me, names)
  if not me or not names then return nil, nil end
  for i = 0, 20 do
    local it = NPC.GetItemByIndex(me, i)
    if it then
      local nm = Ability.GetName(it)
      if nm and names[nm] then
        return it, i
      end
    end
  end
  return nil, nil
end

local function ensure_item_in_main(me, item, slot_idx)
  if not me or not item then return false end
  if slot_idx and slot_idx >= 0 and slot_idx <= 5 then return true end
  local target_slot = nil
  for i = 0, 5 do
    if not NPC.GetItemByIndex(me, i) then
      target_slot = i
      break
    end
  end
  if not target_slot then
    return false
  end
  local ok = false
  local p = player()

  if Enum and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM then
    ok = pcall(function()
      Player.PrepareUnitOrders(
        p,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM,
        target_slot,
        Vector(0, 0, 0),
        item,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        me,
        false, false, false, true
      )
    end) and true or false
    if ok then return true end
  end
  return false
end

local function find_item_slot(me, name, main_only)
  if not me or not name then return nil end
  local max_slot = main_only and 5 or 20
  for i = 0, max_slot do
    local it = NPC.GetItemByIndex(me, i)
    if it and Ability.GetName(it) == name then
      return i, it
    end
  end
  return nil, nil
end

local function swap_with_holy_locket(me, item)
  if not me or not item then return false end
  local locket_slot, locket = find_item_slot(me, "item_holy_locket", true)
  if not locket_slot or not locket then return false end
  local p = player()
  if not p then return false end
  local ok = pcall(function()
    Player.PrepareUnitOrders(
      p,
      Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM,
      locket_slot,
      Vector(0, 0, 0),
      item,
      Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
      me,
      false, false, false, true
    )
  end) and true or false
  if ok then
    state.wards.swap_back_slot = locket_slot
  end
  return ok
end

local function restore_holy_locket_if_needed(me)
  if not me then return end
  local slot = state.wards.swap_back_slot
  if not slot then return end
  local _, locket = find_item_slot(me, "item_holy_locket", false)
  if not locket then
    state.wards.swap_back_slot = nil
    return
  end
  local p = player()
  if not p then return end
  pcall(function()
    Player.PrepareUnitOrders(
      p,
      Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM,
      slot,
      Vector(0, 0, 0),
      locket,
      Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
      me,
      false, false, false, true
    )
  end)
  state.wards.swap_back_slot = nil
end

local function find_nearest_tree(me, range)
  if not Trees or not Trees.GetAll then return nil end
  local trees = Trees.GetAll() or {}
  local my_pos = Entity.GetAbsOrigin(me)
  local best, bestD = nil, math.huge
  for _, tr in ipairs(trees) do
    local p = Entity.GetAbsOrigin(tr)
    if p then
      local d = my_pos:Distance(p)
      if d < (range or 600) and d < bestD then
        bestD = d
        best = tr
      end
    end
  end
  return best
end

local function get_preferred_ally_target(me)
  local ally = nil
  if state.io.current_tether_target and Entity.IsAlive(state.io.current_tether_target) then
    ally = state.io.current_tether_target
  elseif state.link.linked_player_id then
    for _, h in ipairs(Heroes.GetAll() or {}) do
      if Hero.GetPlayerID(h) == state.link.linked_player_id and Entity.IsAlive(h) then
        ally = h
        break
      end
    end
  end
  if not ally and state.follow and state.follow.current_target and Entity.IsAlive(state.follow.current_target) then
    local tgt = state.follow.current_target
    if Entity.IsSameTeam(me, tgt) then ally = tgt end
  end
  return ally
end

local function get_tp_scroll(me)
  return get_item_by_names(me, { item_tpscroll = true, item_town_portal_scroll = true })
end

local function GetLandingRadiusForAnchor(e)
  if not e or not Entity.IsEntity(e) then return 0 end
  if NPC.IsStructure(e) then
    if string.find((Entity.GetUnitName(e) or ""), "npc_dota_watch_tower") then
      return 250
    end
    return 800
  end
  return NPC.GetPaddedCollisionRadius(e) or 72
end

local function find_travel_anchor(me, desired_pos)
  if not me or not desired_pos then return nil end
  local heroTeam = Entity.GetTeamNum(me)
  if not heroTeam then return nil end
  local best, bestDist = nil, math.huge
  local function consider(e)
    if not e or not Entity.IsAlive(e) then return end
    if Entity.GetTeamNum(e) ~= heroTeam then return end
    if e == me then return end
    local p = Entity.GetAbsOrigin(e)
    if not p then return end
    local d = p:Distance2D(desired_pos)
    if d < bestDist then
      bestDist = d
      best = e
    end
  end
  for _, e in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_STRUCTURE) or {}) do
    consider(e)
  end
  for _, e in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP) or {}) do
    if Entity.IsSameTeam(e, me) and Entity.IsAlive(e) and not Entity.IsDormant(e) and not NPC.IsWaitingToSpawn(e) then
      consider(e)
    end
  end
  return best
end

local function issue_cast_position(me, ability, position)
  local p = player()
  if not p or not ability or not position then return false end
  Player.PrepareUnitOrders(
    p,
    Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
    nil,
    position,
    ability,
    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
    me
  )
  return true
end

local function is_teleporting(unit)
  return NPC.IsChannellingAbility(unit)
end

local function attempt_tp_to_target(me, target)
  if not ui.tp_enabled:Get() then return false end
  if not me or not target then return false end
  if is_in_fountain(target) then return false end

  if not timer_due("tp_next") then return false end

  local my_pos = Entity.GetAbsOrigin(me)
  local tg_pos = Entity.GetAbsOrigin(target)
  local dist = my_pos:Distance2D(tg_pos)

  local min_tp_dist = (ui.tp_distance and ui.tp_distance:Get()) or 3000
  if dist < min_tp_dist then return false end

  if Entity.IsSameTeam(me, target) and is_in_fountain(target) then return false end

  local tp = get_tp_scroll(me)
  if not tp then
    status_push(t("tp_unavailable", "false", "0"))
    return false
  end

  if not is_item_ready(tp) or Ability.CanBeExecuted(tp) ~= -1 then
    local charges = get_item_charges(tp)
    status_push(t("tp_unavailable", "true", tostring(charges)))
    return false
  end

  local bestAnchor = find_travel_anchor(me, tg_pos)
  local cast_pos = nil
  if bestAnchor then
    local anchorPos = Entity.GetAbsOrigin(bestAnchor)
    local r = GetLandingRadiusForAnchor(bestAnchor)
    local d = tg_pos:Distance(anchorPos)
    cast_pos = (d > r) and (anchorPos + (tg_pos - anchorPos):Normalized() * r) or tg_pos
  else
    -- fallback: direct cast near target
    local dir = (tg_pos - my_pos):Normalized()
    cast_pos = tg_pos - dir * 150
  end

  if cast_pos then
    status_push(t("tp_scroll_anchor", math.floor(dist)))
    issue_cast_position(me, tp, cast_pos)
    timer_set("tp_next", 1.0)
    timer_set("tp_suppress", 4.0)
    return true
  end

  return false
end

local function is_wisp(me)
  local name = me and NPC.GetUnitName(me) or nil
  return name == "npc_dota_hero_wisp" or name == "npc_dota_hero_io"
end


local function apply_safety(dest, follow_target, attack_info)
  if not ui.safe_follow:Get() then return dest end
  local me = my()
  if not me or not follow_target then return dest end

  local my_pos = Entity.GetAbsOrigin(me)
  local target_pos = Entity.GetAbsOrigin(follow_target)
  local fountain_pos = get_friendly_fountain(me)

  local threat_data = analyze_threat_landscape(my_pos, target_pos)
  local primary_threat = threat_data.primary_threat
  local total_threat = threat_data.threat_score

  if not primary_threat then return dest end

  local enemy_pos = primary_threat.position
  local dist_to_enemy = my_pos:Distance2D(enemy_pos)
  local min_dist = ui.min_enemy_distance:Get()

  local is_attacking = attack_info and attack_info.active and attack_info.target
  local my_team = Entity.GetTeamNum(me)
  local all_heroes = Heroes.GetAll() or {}
  local target_allies = {}
  for _, ally in ipairs(all_heroes) do
    if Entity.GetTeamNum(ally) == my_team and Entity.IsAlive(ally) and ally ~= follow_target then
      table.insert(target_allies, ally)
    end
  end
  local ally_count = 0
  for _, a in ipairs(target_allies) do
    if Entity.IsAlive(a) and a ~= follow_target then ally_count = ally_count + 1 end
  end

  local has_backup = ally_count >= 2
  local is_in_danger_zone = threat_data.danger_zone

  local threat_multiplier = math.min(total_threat / 100, 2.0)
  local effective_min_dist = min_dist

  if is_attacking then
    effective_min_dist = min_dist * 0.5
  elseif is_in_danger_zone and not has_backup then
    effective_min_dist = min_dist * (1.0 + threat_multiplier * 0.5)
  elseif is_in_danger_zone and has_backup then
    effective_min_dist = min_dist * 0.85
  elseif has_backup then
    effective_min_dist = min_dist * 0.7
  end

  if dist_to_enemy >= effective_min_dist then
    return dest
  end

  if is_wisp(me) then
    local ally_pos = Entity.GetAbsOrigin(follow_target)
    local tether = NPC.GetAbility(me, "wisp_tether") or NPC.GetAbility(me, "io_tether")
    local tether_range = (tether and Ability.GetCastRange(tether)) or 1000

    local away_from_enemy = (ally_pos - enemy_pos):Normalized()
    local safe_multiplier = is_attacking and 1.0 or (has_backup and 1.15 or 1.35)
    local safe_pos = enemy_pos + away_from_enemy * (effective_min_dist * safe_multiplier)

    local dist_to_ally = my_pos:Distance2D(ally_pos)
    if dist_to_ally > tether_range * 0.85 then
      local toward_ally = (ally_pos - my_pos):Normalized()
      safe_pos = my_pos + toward_ally * (tether_range * 0.8)
    end

    if #threat_data.threats >= 2 and not is_attacking then
      local secondary_threat = threat_data.threats[2]
      local away_from_secondary = (safe_pos - secondary_threat.position):Normalized()
      safe_pos = safe_pos + away_from_secondary * 50
    end

    if not is_attacking and not is_in_danger_zone and has_backup then
      local to_fountain = (fountain_pos - safe_pos):Normalized()
      local bias = (ui.fountain_bias and ui.fountain_bias:Get()) or 100
      safe_pos = safe_pos + to_fountain * (bias * 0.3)
    end

    return safe_pos
  else
    local away_from_enemy = (my_pos - enemy_pos):Normalized()

    local retreat_direction = away_from_enemy
    if #threat_data.threats >= 2 then
      local avg_threat_pos = primary_threat.position
      if threat_data.threats[2] then
        avg_threat_pos = (primary_threat.position + threat_data.threats[2].position) / 2
      end
      retreat_direction = (my_pos - avg_threat_pos):Normalized()
    end

    local retreat_multiplier = is_attacking and 1.0 or (has_backup and 1.25 or 1.5)
    local retreat_dist = math.max(effective_min_dist * retreat_multiplier, effective_min_dist + 150)
    local chosen = my_pos + retreat_direction * retreat_dist

    return chosen
  end
end

local function is_currently_tethered(me)
  if not me then return false end
  return NPC.HasModifier(me, "modifier_wisp_tether") or NPC.HasModifier(me, "modifier_io_tether")
end

local function clamp_dest_to_tether(me, dest, tether_target)
  if not me or not dest or not tether_target then return dest end
  if not Entity.IsAlive(tether_target) or not Entity.IsSameTeam(me, tether_target) then return dest end
  if not is_currently_tethered(me) then return dest end

  local tether = NPC.GetAbility(me, "wisp_tether") or NPC.GetAbility(me, "io_tether")
  if not tether then return dest end

  local base_range = Ability.GetCastRange(tether) or 1000
  local buffer = (ui.io_tether_buffer and ui.io_tether_buffer:Get()) or 50
  local break_range = base_range + 600 + buffer

  local tgt_pos = Entity.GetAbsOrigin(tether_target)
  if not tgt_pos then return dest end

  local dist = dest:Distance2D(tgt_pos)
  if dist <= break_range * 0.9 then return dest end

  local dir = (dest - tgt_pos):Normalized()
  return tgt_pos + dir * (break_range * 0.85)
end

local function get_overcharge_ability(me)
  if not me or not is_wisp(me) then return nil end
  return NPC.GetAbility(me, "wisp_overcharge")
end

local function has_overcharge_learned(me)
  local oc = get_overcharge_ability(me)
  return oc and Ability.GetLevel(oc) > 0
end

local function is_overcharge_active(me)
  if not me then return false end
  return NPC.HasModifier(me, "modifier_wisp_overcharge")
end

local function is_missing_hp(unit)
  if not unit then return false end
  local hp = Entity.GetHealth(unit)
  local max = Entity.GetMaxHealth(unit)
  if not hp or not max then return false end
  return hp > 0 and max > 0 and hp < max
end

local function get_hero_by_player_id(pid)
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if Hero.GetPlayerID(h) == pid then return h end
  end
  return nil
end

local function select_auto_target_by_criterion()
  local me = my()
  if not me then return nil end
  local mePos = Entity.GetAbsOrigin(me)
  local criterion = tonumber(ui.auto_select:Get()) or 0

  local candidates = {}
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if is_valid_follow_target(h) and Entity.IsSameTeam(me, h) then
      local pid = Hero.GetPlayerID(h)
      if pid ~= state.link.excluded_player_id then
        table.insert(candidates, h)
      end
    end
  end

  state.link.excluded_player_id = nil
  if #candidates == 0 then return nil end

  if criterion == 0 then
    local t = now()
    if state.link.last_random_target and state.link.last_random_time and (t - state.link.last_random_time) < 30 then
      if Entity.IsAlive(state.link.last_random_target) then
        return state.link.last_random_target
      end
    end
    local seed = math.floor((now() * 1000) % 1000000)
    if seed > 0 then math.randomseed(seed) end
    local chosen = candidates[math.random(1, #candidates)]
    state.link.last_random_target = chosen
    state.link.last_random_time = t
    return chosen
  end

  local best, bestScore, bestDist = nil, -math.huge, math.huge
  for _, h in ipairs(candidates) do
    local pid = Hero.GetPlayerID(h)
    local p = pid and Players.Get(pid) or nil
    local td = p and Player.GetTeamData(p) or nil
    local kills = (td and td.kills) or 0
    local deaths = (td and td.deaths) or 0
    local score = 0
    if criterion == 1 then
      score = deaths
    elseif criterion == 2 then
      score = kills
    elseif criterion == 3 then
      score = kills / math.max(deaths, 1)
    end
    local dist = mePos:Distance2D(Entity.GetAbsOrigin(h))
    if (score > bestScore) or (score == bestScore and dist < bestDist) then
      bestScore = score
      bestDist = dist
      best = h
    end
  end

  if best then return best end
  return candidates[math.random(1, #candidates)]
end

local function attempt_io_tether(follow_target)
  local me = my()
  if not me or not is_wisp(me) then return end
  if not ui.io_enabled:Get() then return end
  if not timer_due("io_tether") then return end
  if is_currently_tethered(me) then
    timer_set("io_tether", 0.5)
    return
  end
  local tether_target = nil
  if ui.io_use_follow_target:Get() and follow_target and Entity.IsAlive(follow_target) and Entity.IsSameTeam(me, follow_target) then
    tether_target = follow_target
  elseif state.io.current_tether_target and Entity.IsAlive(state.io.current_tether_target) and Entity.IsSameTeam(me, state.io.current_tether_target) then
    tether_target = state.io.current_tether_target
  end
  if not tether_target or not Entity.IsAlive(tether_target) then
    tether_target = select_auto_target_by_criterion()
  end
  if not tether_target or not Entity.IsAlive(tether_target) then return end
  local tether = NPC.GetAbility(me, "wisp_tether") or NPC.GetAbility(me, "io_tether")
  if not tether or Ability.GetLevel(tether) <= 0 then return end
  local mana_ok = Ability.IsCastable(tether, NPC.GetMana(me))
  local cast_range = Ability.GetCastRange(tether)
  if not cast_range or cast_range <= 0 then cast_range = 1000 end
  local buffer = (ui.io_tether_buffer and ui.io_tether_buffer:Get()) or 50
  local my_pos = Entity.GetAbsOrigin(me)
  local tg_pos = Entity.GetAbsOrigin(tether_target)
  local dist = my_pos:Distance2D(tg_pos)
  if mana_ok and dist <= cast_range + buffer then
    Ability.CastTarget(tether, tether_target)
    state.io.current_tether_target = tether_target
    timer_set("io_tether", ui.io_interval:Get() / 1000.0)
    status_push(t("io_tether_to", get_display_name(tether_target), math.floor(dist)))
  end
end

local function attempt_io_overcharge()
  local me = my()
  if not me or not is_wisp(me) then return end
  if not has_overcharge_learned(me) then return end
  if ui.io_overcharge_hp_enabled and not ui.io_overcharge_hp_enabled:Get() then return end
  if not is_currently_tethered(me) then
    state.io.current_tether_target = nil
    return
  end
  local tether = NPC.GetAbility(me, "wisp_tether") or NPC.GetAbility(me, "io_tether")
  if tether and CustomEntities and CustomEntities.GetTetheredUnit then
    local linked = CustomEntities.GetTetheredUnit(tether)
    if linked and Entity.IsAlive(linked) then
      state.io.current_tether_target = linked
    end
  end
  local ally = state.io.current_tether_target
  local need_overcharge = is_missing_hp(me) or (ally and Entity.IsAlive(ally) and is_missing_hp(ally))
  if not need_overcharge then return end
  if not is_overcharge_active(me) then
    local overcharge = get_overcharge_ability(me)
    if overcharge and Ability.CanBeExecuted(overcharge) == -1 then
      Ability.CastNoTarget(overcharge)
      local who = ally and get_display_name(ally) or t("self_label")
      status_push(t("io_overcharge", who))
    end
  end
end

local function attempt_wisp_spirits()
  local me = my()
  if not me or not is_wisp(me) then return end
  local spirits = NPC.GetAbility(me, "wisp_spirits") or NPC.GetAbility(me, "io_spirits")
  if not spirits or Ability.IsHidden(spirits) then return end
  if Ability.CanBeExecuted(spirits) ~= -1 then return end
  local mana_pct = (NPC.GetMana(me) / NPC.GetMaxMana(me)) * 100
  if mana_pct < ui.io_spirits_mana:Get() then return end
  if Entity.GetHeroesInRadius then
    local radius = (ui.io_spirits_enemy_radius and ui.io_spirits_enemy_radius:Get()) or 700
    local enemies = Entity.GetHeroesInRadius(me, radius, Enum.TeamType.TEAM_ENEMY)
    if enemies and #enemies > 0 then
      local has_alive_enemy = false
      for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) then
          has_alive_enemy = true
          break
        end
      end
      if has_alive_enemy then
        Ability.CastNoTarget(spirits)
        status_push(t("io_spirits"))
      end
    end
  end
end

local function attempt_auto_buy()
  if state.autobuy.done then return end
  if not ui.autobuy_enabled:Get() then return end
  if not timer_ready("autobuy_check", ui.autobuy_interval:Get()) then return end
  local me = my()
  if not me then return end
  local si = state.autobuy.stage_index or 1
  while si <= #AUTOBUY_STAGES do
    local stage = AUTOBUY_STAGES[si]
    if stage and stage.complete_item and has_item_any(me, stage.complete_item) then
      si = si + 1
    else
      break
    end
  end
  state.autobuy.stage_index = si
  if si > #AUTOBUY_STAGES then
    if not state.autobuy.done then
      state.autobuy.done = true
      status_push(t("autobuy_complete"))
    end
    return
  end
  local stage = AUTOBUY_STAGES[si]
  if not stage or not stage.components then return end
  local to_buy = nil
  for _, comp in ipairs(stage.components) do
    if not is_autobuy_component_done(me, stage.complete_item, comp) then
      to_buy = comp
      break
    end
  end
  if not to_buy then
    timer_set("autobuy_check", 0.5)
    return
  end
  local p = player()
  if not p then return end
  local attemptKey = "autobuy_attempt_" .. tostring(to_buy.id)
  if not timer_ready(attemptKey, 1.5) then return end
  timer_set("autobuy_check", math.max(0.5, ui.autobuy_interval:Get()))
  if to_buy.secret_shop == true then
    local courier = (Couriers and Couriers.GetLocal and Couriers.GetLocal()) or nil
    if courier then
      local atShop = is_courier_at_secret_shop(courier)
      if not atShop then
        local goSecret = NPC.GetAbility(courier, "courier_go_to_secretshop")
        if goSecret and Ability.IsReady(goSecret) and timer_ready("autobuy_secret_go", 1.0) then
          Ability.CastNoTarget(goSecret)
          status_push(t("courier_go_secret", tostring(to_buy.name)))
        end
        state.autobuy.secret_active = true
        state.autobuy.secret_target = to_buy.name
        timer_set("autobuy_check", 1.0)
        return
      else
        status_push(t("courier_at_secret"))
        Player.PrepareUnitOrders(
          p,
          Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM,
          to_buy.id,
          Vector(0, 0, 0),
          to_buy.id,
          Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
          courier
        )
        state.autobuy.secret_active = false
        state.autobuy.secret_target = nil
        timer_set("autobuy_check", math.max(0.5, ui.autobuy_interval:Get()))
        return
      end
    end
  end
  Player.PrepareUnitOrders(
    p,
    Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM,
    to_buy.id,
    Vector(0, 0, 0),
    to_buy.id,
    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
    me
  )
  if state.autobuy.secret_active and state.autobuy.secret_target == to_buy.name then
    state.autobuy.secret_active = false
    state.autobuy.secret_target = nil
  end
  status_push(t("autobuy_component", tostring(to_buy.name), to_buy.id or -1))
end

local function check_and_drop_foreign_items()
  if not ui.itemcheck_enabled:Get() then return end
  if not timer_ready("itemcheck", ui.itemcheck_interval:Get()) then return end
  local me = my()
  if not me then return end
  local p = player()
  if not p then return end
  local my_player_id = player_id()
  if not my_player_id or my_player_id < 0 then return end
  local my_pos = Entity.GetAbsOrigin(me)
  if not my_pos then return end
  for i = 0, 20 do
    local it = get_item_by_index_any(me, i)
    if it and Item.GetPlayerOwnerID then
      local owner_id = Item.GetPlayerOwnerID(it)
      if owner_id and owner_id >= 0 and owner_id ~= my_player_id then
        local item_name = Ability.GetName(it) or "unknown"
        status_push(t("drop_hero_item", item_name, owner_id))
        NPC.DropItem(me, it, my_pos, false, false, false)
      end
    end
  end
  if Couriers and Couriers.GetLocal then
    local courier = Couriers.GetLocal()
    if courier and Entity.IsAlive(courier) then
      local courier_pos = Entity.GetAbsOrigin(courier)
      if courier_pos then
        for i = 0, 20 do
          local it = get_item_by_index_any(courier, i)
          if it then
            local owner_id = Item.GetPlayerOwnerID and Item.GetPlayerOwnerID(it) or -1
            if owner_id and owner_id >= 0 and owner_id ~= my_player_id then
              local item_name = Ability.GetName(it) or "unknown"
              status_push(t("drop_courier_item", item_name, owner_id))
              NPC.DropItem(courier, it, courier_pos, false, false, false)
            end
          end
        end
      end
    end
  end
end

local function bool_from(value)
  if type(value) == "boolean" then return value end
  if type(value) == "number" then return value ~= 0 end
  if type(value) == "string" then
    local v = value:lower()
    return v == "true" or v == "1" or v == "yes"
  end
  return false
end

local function vector_from_any(v)
  if not v then return nil end
  if type(v) == "userdata" and v.x then return v end
  if type(v) == "table" and v.x then
    return Vector(v.x, v.y, v.z or 0)
  end
  if type(v) == "string" then
    local x, y, z = string.match(v, "Vector%(([-%d%.]+),%s*([-%d%.]+),%s*([-%d%.]+)%)")
    if x and y and z then
      return Vector(tonumber(x), tonumber(y), tonumber(z))
    end
  end
  return nil
end

local function cache_ward_positions()
  if state.wards.has_positions then return end
  if not XHelpers or not XHelpers.GetScript then return end
  WardHelper = WardHelper or XHelpers.GetScript("WardHelper")
  state.wards.helper = state.wards.helper or WardHelper
  local helper = state.wards.helper
  if not helper or not helper.positions then return end

  local function ingest(src, target)
    if not src then return end
    for id, data in pairs(src) do
      local pos = vector_from_any(data.position)
      local needs_tree = bool_from(data.tree_cut)
      local team_val = tonumber(data.team or 0) or 0
      local team_ok = team_val == 0 or (my() and Entity.GetTeamNum(my()) == team_val)
      if pos and not needs_tree and team_ok then
        table.insert(target, { pos = pos, data = data, id = id })
      end
    end
  end

  state.wards.observer_spots = {}
  state.wards.sentry_spots = {}
  ingest(helper.positions["observer"], state.wards.observer_spots)
  ingest(helper.positions["sentry_camp_block"], state.wards.sentry_spots)
  if #state.wards.observer_spots > 0 then
    state.wards.has_positions = true
  end
end

local function record_heat_sample(pos, weight)
  if not pos then return end
  local t = now()
  if (t - (state.wards.last_sample or 0)) < (state.wards.sample_interval or 0.5) then return end
  state.wards.last_sample = t
  table.insert(state.wards.heat_samples, { pos = pos, time = t, w = weight or 1.0 })
  local window = state.wards.heat_window or 45
  local i = 1
  while i <= #state.wards.heat_samples do
    if (t - state.wards.heat_samples[i].time) > window then
      table.remove(state.wards.heat_samples, i)
    else
      i = i + 1
    end
  end
end

local function compute_heat_center()
  local samples = state.wards.heat_samples
  if not samples or #samples == 0 then return nil end
  local t = now()
  local window = state.wards.heat_window or 45
  local sum = Vector(0, 0, 0)
  local weight = 0
  for _, s in ipairs(samples) do
    local age = t - s.time
    if age <= window then
      local w = (1 - (age / window)) * (s.w or 1)
      sum = sum + s.pos * w
      weight = weight + w
    end
  end
  if weight <= 0 then return nil end
  return sum / weight
end

local function refresh_enemy_wards(me)
  state.wards.enemy_wards = {}
  if not NPCs or not NPCs.GetAll then return end

  local ward_list = nil
  if Enum and Enum.UnitTypeFlags and Enum.UnitTypeFlags.TYPE_WARD then
    ward_list = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_WARD)
  else
    ward_list = NPCs.GetAll(function(npc)
      return NPC.IsWard and NPC.IsWard(npc)
    end)
  end
  ward_list = ward_list or {}

  for _, ent in pairs(ward_list) do
    if ent and Entity.IsEntity(ent) and Entity.IsAlive(ent) and not Entity.IsSameTeam(me, ent) then
      table.insert(state.wards.enemy_wards, ent)
    end
  end
end

local function collect_visible_enemy_wards(me, radius)
  local res = {}
  if not me then return res end
  local r = radius or 1600
  if not NPCs or not NPCs.InRadius then return res end
  local origin = state.my_pos or Entity.GetAbsOrigin(me)
  local team_num = Entity.GetTeamNum(me)
  local units = NPCs.InRadius(origin, r, team_num, Enum.TeamType.TEAM_ENEMY, true, true) or {}
  for _, ent in pairs(units) do
    if ent and Entity.IsEntity(ent) and Entity.IsAlive(ent) and NPC.IsWard(ent) and not Entity.IsSameTeam(me, ent) then
      table.insert(res, ent)
    end
  end
  return res
end

local function dist_point_segment_2d(p, a, b)
  if not p or not a or not b then return math.huge end
  local apx, apy = p.x - a.x, p.y - a.y
  local abx, aby = b.x - a.x, b.y - a.y
  local ab_len2 = abx * abx + aby * aby
  if ab_len2 <= 0.001 then
    return math.sqrt(apx * apx + apy * apy)
  end
  local t = (apx * abx + apy * aby) / ab_len2
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  local projx = a.x + abx * t
  local projy = a.y + aby * t
  local dx, dy = p.x - projx, p.y - projy
  return math.sqrt(dx * dx + dy * dy)
end

local function friendly_ward_near(me, pos, range)
  if not pos or not NPCs or not NPCs.GetAll then return false end
  local r = range or 600
  local wards = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_WARD) or {}
  for _, ent in pairs(wards) do
    if ent and Entity.IsAlive(ent) and Entity.IsSameTeam(me, ent) then
      local ep = Entity.GetAbsOrigin(ent)
      if ep and ep:Distance2D(pos) <= r then
        return true
      end
    end
  end
  return false
end

local function add_recent_ward(pos, kind)
  if not pos then return end
  state.wards.recent_places = state.wards.recent_places or {}
  local now_t = now()
  state.wards.recent_places[#state.wards.recent_places + 1] = { pos = pos, kind = kind, time = now_t }
  local pruned = {}
  for _, entry in ipairs(state.wards.recent_places) do
    if entry.time and (now_t - entry.time) < 20 then
      pruned[#pruned + 1] = entry
    end
  end
  state.wards.recent_places = pruned
end

local function recently_placed_near(pos, radius)
  if not pos then return false end
  local list = state.wards.recent_places or {}
  local now_t = now()
  local keep = {}
  for _, entry in ipairs(list) do
    if entry.time and (now_t - entry.time) < 20 then
      keep[#keep + 1] = entry
      if entry.pos and entry.pos:Distance2D(pos) < (radius or 480) then
        state.wards.recent_places = keep
        return true
      end
    end
  end
  state.wards.recent_places = keep
  return false
end

local function tower_nearby(pos, radius)
  if not pos then return false end
  local r = radius or 850
  local structs = NPCs.GetAll and NPCs.GetAll(Enum.UnitTypeFlags.TYPE_TOWER) or {}
  for _, e in ipairs(structs or {}) do
    if e and Entity.IsAlive(e) and not Entity.IsSameTeam(me, e) then
      local ep = Entity.GetAbsOrigin(e)
      if ep and ep:Distance2D(pos) < r then
        return true
      end
    end
  end
  return false
end

local function choose_best_spot(spots, center, my_team)
  if not spots or not center then return nil end
  local best, best_score = nil, -math.huge
  for _, spot in ipairs(spots) do
    local data = spot.data or {}
    local team_val = tonumber(data.team or 0) or 0
    if team_val == 0 or team_val == my_team then
      local pos = spot.pos
      if pos then
        if not (state.wards.blocked_obs_until and state.wards.blocked_obs_pos and now() < state.wards.blocked_obs_until and state.wards.blocked_obs_pos:Distance2D(pos) < 400) then
          local dist = center:Distance2D(pos)
          local survivability = tonumber(data.survivability or data.wards_pct or data.matches_pct or 0) or 0
          local matches = tonumber(data.matches_pct or data.wards_count or 0) or 0
          local score = (survivability * 3.0) + (matches * 0.5) - (dist * 0.004)
          if score > best_score then
            best_score = score
            best = { pos = pos, data = data, id = spot.id, dist = dist }
          end
        end
      end
    end
  end
  return best
end

local function is_position_safe_for_ward(me, pos)
  if not me or not pos then return false end
  local my_pos = state.my_pos or Entity.GetAbsOrigin(me)
  if not my_pos then return false end

  local threat = analyze_threat_landscape(my_pos, pos)
  local threat_score = (threat and threat.threat_score) or 0
  local primary_close = threat and threat.primary_threat and threat.primary_threat.distance < 900
  if (threat and threat.danger_zone) or threat_score > 120 or primary_close then
    return false
  end

  local enemies_near_path = 0
  local enemies_near_dest = 0
  for _, enemy in ipairs(Heroes.GetAll() or {}) do
    if enemy and Entity.IsAlive(enemy) and not Entity.IsSameTeam(me, enemy) and not NPC.IsIllusion(enemy) then
      local ep = Entity.GetAbsOrigin(enemy) or (Hero.GetLastMaphackPos and Hero.GetLastMaphackPos(enemy))
      if ep then
        local d_dest = ep:Distance2D(pos)
        local d_path = dist_point_segment_2d(ep, my_pos, pos)
        if d_dest < 1100 then
          enemies_near_dest = enemies_near_dest + 1
        end
        if d_dest < 900 or d_path < 750 then
          enemies_near_path = enemies_near_path + 1
        end
        if d_dest < 700 then
          return false
        end
      end
    end
  end

  if enemies_near_path >= 2 and my_pos:Distance2D(pos) > 900 then
    return false
  end
  if enemies_near_dest >= 3 then
    return false
  end

  return true
end

local function get_ward_item(me, kind)
  local names = {}
  if kind == "observer" then
    names["item_ward_observer"] = true
    names["item_ward_dispenser"] = true
  elseif kind == "sentry" then
    names["item_ward_sentry"] = true
    names["item_ward_dispenser"] = true
  end
  return get_item_and_slot(me, names)
end

local function ensure_ward_type(me, item, want_observer)
  if not item or not me then return false end
  local item_name = Ability.GetName(item)
  if not item_name then return false end

  if item_name == "item_ward_dispenser" then
    local is_observer = Ability.GetToggleState(item)
    if want_observer and not is_observer then
      Ability.Toggle(item)
      return false
    elseif not want_observer and is_observer then
      Ability.Toggle(item)
      return false
    end
  end
  return true
end

local function try_buy_ward(me, item_id, target_pos)
  if not me or not player() then return end
  if now() < (state.wards.last_purchase or 0) then return end

  local dispenser = get_item_by_names(me, { ["item_ward_dispenser"] = true })
  if dispenser then return end

  if Item.GetStockCount and Item.GetStockCount(item_id) ~= nil and Item.GetStockCount(item_id) <= 0 then return end
  if target_pos and state.my_pos and state.my_pos:Distance2D(target_pos) > 2600 then return end
  Player.PrepareUnitOrders(
    player(),
    Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM,
    item_id,
    Vector(0, 0, 0),
    item_id,
    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
    me
  )
  state.wards.last_purchase = now() + 1.0
  status_push("Queued ward purchase " .. tostring(item_id))
end

local function move_and_place_ward(me, item, item_slot, pos, label, kind)
  if not me or not item or not pos then return false end
  local p = player()
  if not p then return false end
  local my_pos = state.my_pos or Entity.GetAbsOrigin(me)
  if not my_pos then return false end
  local dist = my_pos:Distance2D(pos)
  local cast_range = 500

  state.wards.placing = true
  local ms = math.max(NPC.GetMoveSpeed(me) or 300, 300)
  local travel_time = dist / ms
  state.wards.place_timeout = now() + math.min(6.0, math.max(3.0, travel_time + 1.5))
  state.wards.pause_follow_until = state.wards.place_timeout
  state.wards.next_place_after = now() + 0.5

  -- If ward is in backpack, move it to main inventory and wait for cooldown
  if item_slot and item_slot >= 6 then
    local moved = ensure_item_in_main(me, item, item_slot)
    if not moved then
      moved = swap_with_holy_locket(me, item)
    end
    state.wards.place_timeout = now() + 7.5
    state.wards.next_place_after = now() + 6.2
    state.wards.pause_follow_until = state.wards.place_timeout
    status_push("Moving ward to inventory for placement")
    if not moved then
      state.wards.placing = false
      state.wards.place_timeout = 0
    end
    return moved
  end

  if dist > cast_range - 50 then
    Player.PrepareUnitOrders(
      p,
      Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
      nil,
      pos,
      nil,
      Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
      me
    )
    return true
  end

  local want_observer = (kind == "observer")
  if not ensure_ward_type(me, item, want_observer) then
    return false
  end

  if Ability.CanBeExecuted(item) == -1 and is_item_ready(item) then
    Ability.CastPosition(item, pos)
    state.wards.last_place_time = now()
    state.wards.last_place_kind = kind
    state.wards.next_place_after = now() + 0.6
    state.wards.pause_follow_until = now() + 0.8
    state.wards.place_timeout = now() + 1.2
    status_push(label)
    timer_set("order", 0.25)
    state.wards.placing = false
    restore_holy_locket_if_needed(me)
    add_recent_ward(pos, kind)
    if kind == "sentry" then
      state.wards.blocked_sentry_pos = pos
      state.wards.blocked_sentry_until = now() + 8.0
    elseif kind == "observer" then
      state.wards.blocked_obs_pos = pos
      state.wards.blocked_obs_until = now() + 8.0
    end
    if kind == "observer" then
      state.wards.next_observer = nil
    elseif kind == "sentry" then
      state.wards.next_sentry = nil
    end
    return true
  end
  return false
end

local function try_destroy_enemy_ward(me)
  if not me then return end
  if not timer_ready("ward_attack", 0.6) then return end
  local wards = state.wards.enemy_wards or {}
  if #wards == 0 then
    wards = collect_visible_enemy_wards(me, 1600)
    if #wards == 0 then return end
  end
  local p = player()
  if not p then return end
  local my_pos = state.my_pos or Entity.GetAbsOrigin(me)
  local target, best = nil, math.huge
  for _, w in ipairs(wards) do
    if w and Entity.IsEntity(w) and Entity.IsAlive(w) then
      local wp = Entity.GetAbsOrigin(w)
      if wp then
        local d = my_pos:Distance2D(wp)
        if d < best then
          best = d
          target = w
        end
      end
    end
  end
  if target then
    local hull = NPC.GetHullRadius(me) or 0
    local attack_range = (NPC.GetAttackRange(me) or 150) + hull + 35
    if best <= (attack_range + 30) then
      Player.AttackTarget(p, me, target, false, false, true, "ward_attack", true)
      status_push("Attacking enemy ward")
      state.harass.hold_until = now() + 1.0
      state.wards.pause_follow_until = now() + 1.2
      return true
    end
  end
end

local function ward_logic_tick()
  local me = my()
  if not me or not Entity.IsAlive(me) then return false end
  if state.link and state.link.waiting then
    return false
  end

  local tether = state.io and state.io.current_tether_target or nil
  local tether_ok = false
  if tether and Entity.IsAlive(tether) then
    local thp = Entity.GetHealth(tether) or 0
    local thp_max = Entity.GetMaxHealth(tether) or 1
    tether_ok = thp_max > 0 and (thp / thp_max) >= 0.45
  end
  local tether_low = false
  if tether and Entity.IsAlive(tether) then
    local thp = Entity.GetHealth(tether) or 0
    local thp_max = Entity.GetMaxHealth(tether) or 1
    tether_low = thp_max > 0 and (thp / thp_max) < 0.35
  end

  local hp = Entity.GetHealth(me) or 0
  local hp_max = Entity.GetMaxHealth(me) or 1
  local hp_ok = hp_max > 0 and (hp / hp_max) >= 0.45
  local safe_scan = analyze_threat_landscape(state.my_pos or Entity.GetAbsOrigin(me),
    state.wards.heat_center or state.my_pos or Entity.GetAbsOrigin(me))
  local threat_score = (safe_scan and safe_scan.threat_score) or 0
  local can_act = hp_ok and threat_score < 150 and not (safe_scan and safe_scan.danger_zone)
  if tether and Entity.IsAlive(tether) then
    can_act = can_act and tether_ok
  end

  if state.wards.placing and tether_low then
    status_push("Ward cancelled: ally low HP")
    if state.wards.next_observer then
      state.wards.blocked_obs_pos = state.wards.next_observer.pos or state.wards.next_observer
      state.wards.blocked_obs_until = now() + 5.0
      state.wards.next_observer = nil
      state.wards.obs_plan_at = 0
    end
    if state.wards.next_sentry then
      state.wards.blocked_sentry_pos = state.wards.next_sentry
      state.wards.blocked_sentry_until = now() + 5.0
      state.wards.next_sentry = nil
      state.wards.sentry_plan_at = 0
    end
    state.wards.placing = false
    state.wards.place_timeout = 0
    state.wards.pause_follow_until = now() + 0.6
    restore_holy_locket_if_needed(me)
  elseif state.wards.placing and now() > (state.wards.place_timeout or 0) then
    state.wards.placing = false
    state.wards.place_timeout = 0
    restore_holy_locket_if_needed(me)
  end

  local placement_blocked = now() < (state.wards.next_place_after or 0)

  cache_ward_positions()
  if timer_ready("ward_heat_sample", state.wards.sample_interval or 0.5) then
    for _, enemy in ipairs(Heroes.GetAll() or {}) do
      if enemy and Entity.IsAlive(enemy) and not Entity.IsSameTeam(me, enemy) and not NPC.IsIllusion(enemy) then
        local ep = Entity.GetAbsOrigin(enemy) or Hero.GetLastMaphackPos(enemy)
        if ep then
          record_heat_sample(ep, 1.0)
        end
      end
    end
  end

  if timer_ready("ward_enemy_scan", 0.35) then
    refresh_enemy_wards(me)
  end

  if state.wards.enemy_wards and #state.wards.enemy_wards > 0 then
    local any_visible = false
    for _, w in ipairs(state.wards.enemy_wards) do
      if w and Entity.IsEntity(w) and Entity.IsAlive(w) then
        any_visible = true
        break
      end
    end
    if not any_visible then
      local nearby = collect_visible_enemy_wards(me, 1600)
      if #nearby > 0 then
        state.wards.enemy_wards = nearby
        any_visible = true
      end
    end
    if any_visible and can_act and not placement_blocked then
      try_destroy_enemy_ward(me)
      state.wards.next_sentry = nil
    end
  else
    local nearby = collect_visible_enemy_wards(me, 1600)
    if #nearby > 0 and can_act and not placement_blocked then
      state.wards.enemy_wards = nearby
      try_destroy_enemy_ward(me)
      state.wards.next_sentry = nil
    end
  end

  if timer_ready("ward_target_refresh", 1.0) then
    state.wards.heat_center = compute_heat_center()
    local obs = choose_best_spot(state.wards.observer_spots, state.wards.heat_center, Entity.GetTeamNum(me))
    state.wards.next_observer = obs
    state.wards.obs_plan_at = obs and now() or 0
    state.wards.next_sentry = nil
    state.wards.sentry_plan_at = 0
    if #state.wards.enemy_wards > 0 then
      local nearest, best = nil, math.huge
      for _, w in ipairs(state.wards.enemy_wards) do
        if w and Entity.IsEntity(w) and Entity.IsAlive(w) then
          local wp = Entity.GetAbsOrigin(w)
          if wp then
            local d = (state.my_pos or wp):Distance2D(wp)
            if d < best then
              best = d
              nearest = wp
            end
          end
        end
      end
      state.wards.next_sentry = nearest
      state.wards.sentry_plan_at = nearest and now() or 0
    end
  end

  if (not state.wards.next_sentry) and NPC.HasModifier(Heroes.GetLocal(), "modifier_truesight") then
    local my_pos = state.my_pos or Entity.GetAbsOrigin(me)
    if my_pos and not tower_nearby(my_pos, 850) and not friendly_ward_near(me, my_pos, 550) then
      if is_position_safe_for_ward(me, my_pos) then
        state.wards.next_sentry = my_pos
        state.wards.sentry_plan_at = now()
      end
    end
  end

  local t_now = now()
  if state.wards.next_observer and state.wards.obs_plan_at > 0 and (t_now - state.wards.obs_plan_at) > 9.0 then
    state.wards.blocked_obs_pos = state.wards.next_observer.pos
    state.wards.blocked_obs_until = t_now + 2.5
    state.wards.next_observer = nil
    state.wards.obs_plan_at = 0
  end
  if state.wards.next_sentry and state.wards.sentry_plan_at > 0 and (t_now - state.wards.sentry_plan_at) > 7.5 then
    state.wards.blocked_sentry_pos = state.wards.next_sentry
    state.wards.blocked_sentry_until = t_now + 2.5
    state.wards.next_sentry = nil
    state.wards.sentry_plan_at = 0
  end

  if state.wards.next_sentry and can_act and not placement_blocked then
    local nearby_visible = collect_visible_enemy_wards(me, 1600)
    if #nearby_visible > 0 then
      return state.wards.placing and true or false
    end

    local target_pos = state.wards.next_sentry
    local block_pos = state.wards.blocked_sentry_pos
    if block_pos and state.wards.blocked_sentry_until and now() < state.wards.blocked_sentry_until then
      if target_pos and block_pos:Distance2D(target_pos) < 420 then
        state.wards.next_sentry = nil
        state.wards.sentry_plan_at = 0
        return state.wards.placing and true or false
      end
    end
    if recently_placed_near(target_pos, 520) then
      state.wards.next_sentry = nil
      state.wards.sentry_plan_at = 0
      return state.wards.placing and true or false
    end
    if friendly_ward_near(me, target_pos, 550) then
      state.wards.next_sentry = nil
      state.wards.sentry_plan_at = 0
      return state.wards.placing and true or false
    end

    local sentry_item, sentry_slot = get_ward_item(me, "sentry")
    if not sentry_item then
      try_buy_ward(me, WARD_SENTRY_ID, state.wards.next_sentry)
      sentry_item, sentry_slot = get_ward_item(me, "sentry")
      if not sentry_item then
        state.wards.no_item_until = now() + 3.0
      end
    end
    if (state.wards.no_item_until or 0) > now() then
      placement_blocked = true
      return state.wards.placing and true or false
    end
    if tower_nearby(state.wards.next_sentry, 850) then
      state.wards.blocked_sentry_pos = state.wards.next_sentry
      state.wards.blocked_sentry_until = now() + 4.0
      state.wards.next_sentry = nil
      state.wards.sentry_plan_at = 0
      return state.wards.placing and true or false
    end

    local safe = is_position_safe_for_ward(me, state.wards.next_sentry)
    if sentry_item and safe then
      local acted = move_and_place_ward(me, sentry_item, sentry_slot, state.wards.next_sentry, "Placed sentry ward",
        "sentry")
      if acted then
        state.wards.sentry_plan_at = 0
        return true
      end
    end
    state.wards.blocked_sentry_pos = state.wards.next_sentry
    state.wards.blocked_sentry_until = now() + 4.0
    state.wards.next_sentry = nil
    state.wards.sentry_plan_at = 0
  end

  local observer_target = state.wards.next_observer
  if observer_target and observer_target.pos and can_act and not placement_blocked then
    local block_pos = state.wards.blocked_obs_pos
    if block_pos and state.wards.blocked_obs_until and now() < state.wards.blocked_obs_until then
      if block_pos:Distance2D(observer_target.pos) < 420 then
        state.wards.next_observer = nil
        state.wards.obs_plan_at = 0
        return state.wards.placing and true or false
      end
    end
    if recently_placed_near(observer_target.pos, 520) then
      state.wards.blocked_obs_pos = observer_target.pos
      state.wards.blocked_obs_until = now() + 4.0
      state.wards.next_observer = nil
      state.wards.obs_plan_at = 0
      return state.wards.placing and true or false
    end
    if not friendly_ward_near(me, observer_target.pos, 600) then
      local obs_item, obs_slot = get_ward_item(me, "observer")
      if not obs_item then
        try_buy_ward(me, WARD_OBSERVER_ID, observer_target.pos)
        obs_item, obs_slot = get_ward_item(me, "observer")
        if not obs_item then
          state.wards.no_item_until = now() + 3.0
        end
      end
      if (state.wards.no_item_until or 0) > now() then
        placement_blocked = true
        return state.wards.placing and true or false
      end
      local safe = is_position_safe_for_ward(me, observer_target.pos)
      if obs_item and safe then
        local acted = move_and_place_ward(me, obs_item, obs_slot, observer_target.pos, "Placed observer ward",
          "observer")
        if acted then
          state.wards.obs_plan_at = 0
          return true
        end
      end
      state.wards.blocked_obs_pos = observer_target.pos
      state.wards.blocked_obs_until = now() + 4.0
      state.wards.next_observer = nil
      state.wards.obs_plan_at = 0
    else
      state.wards.blocked_obs_pos = observer_target.pos
      state.wards.blocked_obs_until = now() + 6.0
      state.wards.next_observer = nil
      state.wards.obs_plan_at = 0
    end
  end

  if #state.wards.enemy_wards > 0 and can_act and not placement_blocked then
    try_destroy_enemy_ward(me)
  end

  return state.wards.placing and true or false
end

local function resolve_chat_channel()
  local channels = Chat.GetChannels() or {}
  local target = "DOTAChannelType_GameAllies"
  for _, c in ipairs(channels) do
    if c == target then
      state.chat_channel = c
      return
    end
  end
  state.chat_channel = channels[1] or target
end

local function chat_say(text)
  if not state.chat_channel then resolve_chat_channel() end
  if ui.should_chat:Get() ==  false then return end
  Chat.Say(state.chat_channel, text)
end

local function announce_start_if_needed()
  local me = my()
  if state.announced_start then return end
  if not me or not is_wisp(me) then return end
  resolve_chat_channel()
  chat_say(translate("start"))
  state.announced_start = true
end

local function link_to_hero(h, is_manual)
  if not h then return end
  local pid = Hero.GetPlayerID(h)
  state.link.linked_player_id = pid
  state.link.manual = is_manual and true or false
  state.link.waiting = false
  state.link.wait_start = 0
  state.link.last_unlink_reminder = 0
  chat_say(translate("linked") .. " " .. get_display_name(h))
  status_push(t("linked_status", get_display_name(h)))
end

local function start_link_wait(immediate)
  state.link.waiting = true
  state.link.wait_start = now() - (immediate and 60 or 0)
  state.link.manual = false
  state.link.last_unlink_reminder = 0
  state.link.linked_player_id = nil
end

local function auto_link_by_criterion(immediate)
  local auto = select_auto_target_by_criterion()
  if auto then
    link_to_hero(auto, false)
    return auto
  end
  start_link_wait(immediate)
  return nil
end

local function process_chat_command(playerid, text)
  if not playerid or not text then return end
  local me = my()
  if not me or not is_wisp(me) then return end
  local msg = string.lower(string.gsub(text, "^%s+", ""))
  if msg == "!help" then
    local lang_ru = (ui.language and ui.language:Get() == 1)
    local tango = get_friendly_item_name("item_tango")
    local clarity = get_friendly_item_name("item_clarity")
    local salve = get_friendly_item_name("item_flask")
    local mango = get_friendly_item_name("item_enchanted_mango")
    local dust = get_friendly_item_name("item_dust")
    if lang_ru then
      chat_say(
        "Команды: !link, !unlink, !relocate <враг>, !autoharass on/off, !safeharass on/off, !assist on/off, !distance <u>, !tp on/off, !harass radius <u>")
      chat_say("!buy <" ..
        tango ..
        "/" ..
        clarity ..
        "/" ..
        salve ..
        "/" ..
        mango ..
        "/" ..
        dust .. "> (кд) | !use <" .. tango .. "/" .. clarity .. "/" .. salve .. "/" .. mango .. "> на союзника")
    else
      chat_say(
        "Commands: !link, !unlink, !relocate <enemy>, !autoharass on/off, !safeharass on/off, !assist on/off, !distance <u>, !tp on/off, !harass radius <u>")
      chat_say("!buy <" ..
        tango ..
        "/" ..
        clarity ..
        "/" ..
        salve ..
        "/" ..
        mango ..
        "/" ..
        dust .. "> (cd) | !use <" .. tango .. "/" .. clarity .. "/" .. salve .. "/" .. mango .. "> on ally")
    end
    return
  end
  local is_linked_ally = (state.link.linked_player_id and playerid == state.link.linked_player_id)
  if msg == "!link" then
    if state.link.linked_player_id and state.link.manual then return end
    local h = get_hero_by_player_id(playerid)
    if h and Entity.IsSameTeam(me, h) then
      link_to_hero(h, true)
    end
    return
  end
  if msg == "!unlink" then
    if state.link.linked_player_id == playerid then
      state.link.excluded_player_id = playerid
      state.link.linked_player_id = nil
      state.link.manual = false
      state.link.waiting = true
      state.link.wait_start = now()
      state.wards.next_observer = nil
      state.wards.next_sentry = nil
      state.wards.obs_plan_at = 0
      state.wards.sentry_plan_at = 0
      state.wards.placing = false
      state.wards.place_timeout = 0
      chat_say(translate("unlinked"))
    end
    return
  end
  if msg == "!forcelink" or string.sub(msg, 1, 11) == "!forcelink " then
    local local_player = Players.GetLocal()
    if not local_player or playerid ~= Player.GetPlayerID(local_player) then
      chat_say(translate("forcelink_denied"))
      return
    end
    local hero_name = string.gsub(string.sub(msg, 12), "^%s+", "")
    if hero_name == "" then
      chat_say(translate("forcelink_failed"))
      return
    end
    local target_hero = nil
    for _, h in ipairs(Heroes.GetAll() or {}) do
      if Entity.IsSameTeam(me, h) and h ~= me then
        local nameA = string.lower(get_display_name(h) or "")
        if string.find(nameA, hero_name) then
          target_hero = h
          break
        end
      end
    end
    if target_hero then
      link_to_hero(target_hero, true)
      chat_say(translate("forcelink_success") .. " " .. get_display_name(target_hero))
    else
      chat_say(translate("forcelink_failed"))
    end
    return
  end
  if msg == "!relocate" or string.sub(msg, 1, 10) == "!relocate " then
    if state.link.linked_player_id ~= playerid then return end
    local enemy_name = string.gsub(string.sub(msg, 11), "^%s+", "")
    local relocate = NPC.GetAbility(me, "wisp_relocate")
    if not relocate or Ability.CanBeExecuted(relocate) ~= -1 or not is_currently_tethered(me) then
      chat_say(translate("relocate_failed"))
      return
    end
    local last_pos = nil
    if enemy_name ~= "" then
      local target_enemy = nil
      for _, e in ipairs(Heroes.GetAll() or {}) do
        if not Entity.IsSameTeam(me, e) then
          local nameA = string.lower(get_display_name(e) or "")
          if string.find(nameA, enemy_name) then
            target_enemy = e
            break
          end
        end
      end
      if target_enemy then
        last_pos = Entity.GetAbsOrigin(target_enemy) or Hero.GetLastMaphackPos(target_enemy)
      end
      if last_pos then
        Ability.CastPosition(relocate, last_pos)
        chat_say(translate("relocating") .. " " .. get_display_name(target_enemy))
      else
        chat_say(translate("relocate_failed"))
      end
    else
      last_pos = get_friendly_fountain(me)
      Ability.CastPosition(relocate, last_pos)
      chat_say(t("relocating_fountain"))
    end
    return
  end

  if is_linked_ally then
    if msg == "!autoharass on" or msg == "!autoharass" then
      state.harass.enabled = true
      if ui.harass_enabled then ui.harass_enabled:Set(true) end
      chat_say(t("auto_harass_on"))
      status_push(t("harass_enabled"))
      return
    elseif msg == "!autoharass off" then
      state.harass.enabled = false
      if ui.harass_enabled then ui.harass_enabled:Set(false) end
      chat_say(t("auto_harass_off"))
      status_push(t("harass_disabled"))
      return
    end

    if msg == "!safeharass on" then
      state.harass.safe = true
      if ui.harass_safe then ui.harass_safe:Set(true) end
      chat_say(t("safe_harass_on"))
      status_push(t("harass_safe"))
      return
    elseif msg == "!safeharass off" then
      state.harass.safe = false
      if ui.harass_safe then ui.harass_safe:Set(false) end
      chat_say(t("safe_harass_off"))
      status_push(t("harass_aggressive"))
      return
    end

    if msg == "!assist on" then
      if ui.io_attack_with_hero then ui.io_attack_with_hero:Set(true) end
      chat_say(t("assist_on"))
      status_push(t("assist_on"))
      return
    elseif msg == "!assist off" then
      if ui.io_attack_with_hero then ui.io_attack_with_hero:Set(false) end
      chat_say(t("assist_off"))
      status_push(t("assist_off"))
      return
    end

    if string.sub(msg, 1, 9) == "!distance" then
      local num = tonumber(string.match(msg, "!distance%s+(%d+)") or "")
      if num and ui.distance then
        ui.distance:Set(math.max(100, math.min(1200, num)))
        chat_say(t("distance_set", ui.distance:Get()))
        status_push(t("distance_set", ui.distance:Get()))
      end
      return
    end

    if msg == "!tp on" then
      if ui.tp_enabled then ui.tp_enabled:Set(true) end
      chat_say(t("tp_on"))
      status_push(t("tp_on"))
      return
    elseif msg == "!tp off" then
      if ui.tp_enabled then ui.tp_enabled:Set(false) end
      chat_say(t("tp_off"))
      status_push(t("tp_off"))
      return
    end

    if string.sub(msg, 1, 14) == "!harass radius" then
      local num = tonumber(string.match(msg, "!harass%sradius%s+(%d+)") or "")
      if num and ui.harass_radius then
        ui.harass_radius:Set(math.max(300, math.min(1400, num)))
        chat_say(t("harass_radius_set", ui.harass_radius:Get()))
        status_push(t("harass_radius_set", ui.harass_radius:Get()))
      end
      return
    end

    if string.sub(msg, 1, 5) == "!buy " then
      local item = string.match(msg, "!buy%s+([a-z_ ]+)") or ""
      item = string.gsub(item, "^%s+", "")
      local name_map = {
        tango = { id = 44, name = "item_tango" },
        clarity = { id = 38, name = "item_clarity" },
        ["healing salve"] = { id = 39, name = "item_flask" },
        salve = { id = 39, name = "item_flask" },
        mango = { id = 216, name = "item_enchanted_mango" },
        dust = { id = 40, name = "item_dust" },
      }
      local entry = name_map[item]
      local now_t = now()
      if (state.buy_cmd.last_time or 0) + (state.buy_cmd.cooldown or 20) > now_t then
        local wait = math.max(0, math.floor((state.buy_cmd.last_time + state.buy_cmd.cooldown) - now_t))
        chat_say(t("buy_wait", wait))
        return
      end
      if entry then
        local no_duplicate_items = { item_tango = true, item_clarity = true, item_enchanted_mango = true }
        if no_duplicate_items[entry.name] then
          if has_item_any(me, entry.name) then
            chat_say(t("buy_already_have", get_friendly_item_name(entry.name)))
            return
          end
        end
        local p = player()
        if p and entry.id then
          Player.PrepareUnitOrders(
            p,
            Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM,
            tonumber(entry.id),
            Vector(0, 0, 0),
            tonumber(entry.id),
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            me
          )
          state.buy_cmd.last_time = now_t
          chat_say(t("buy_success", entry.name))
          status_push(t("buy_success", entry.name))
        else
          chat_say(t("buy_invalid"))
        end
      else
        chat_say(t("buy_unknown"))
      end
      return
    end

    if string.sub(msg, 1, 5) == "!use " then
      local wanted = string.match(msg, "!use%s+([a-z_ ]+)") or ""
      wanted = string.gsub(wanted, "^%s+", "")
      local names = {
        item_tango = (wanted == "tango"),
        item_clarity = (wanted == "clarity"),
        item_flask = (wanted == "healing salve" or wanted == "salve"),
        item_enchanted_mango = (wanted == "mango"),
      }
      if not (names.item_tango or names.item_clarity or names.item_flask or names.item_enchanted_mango) then
        chat_say(t("use_unknown"))
        return
      end
      local now_t = now()
      if (state.use_cmd.last_time or 0) + (state.use_cmd.cooldown or 3) > now_t then
        local wait = math.max(0, math.floor((state.use_cmd.last_time + state.use_cmd.cooldown) - now_t))
        chat_say(t("use_wait", wait))
        return
      end
      local item, slot = get_item_and_slot(me, names)
      if not item then
        chat_say(t("use_missing", wanted))
        return
      end
      if slot and slot >= 6 then
        local moved = ensure_item_in_main(me, item, slot)
        if not moved then
          chat_say(t("move_backpack_fail"))
          return
        end
        state.use_pending = { wanted = wanted, names = names, start = now(), last = 0, deadline = now() + 3.0 }
        chat_say(t("use_preparing", wanted))
        status_push(t("use_pending", wanted))
        return
      end
      if not is_item_ready(item) or Ability.CanBeExecuted(item) ~= -1 then
        state.use_pending = { wanted = wanted, names = names, start = now(), last = 0, deadline = now() + 3.0 }
        chat_say(t("use_waiting", wanted))
        status_push(t("use_wait_status", wanted))
        return
      end
      local used = false
      local ally = get_preferred_ally_target(me)
      if not ally then
        chat_say(t("no_ally"))
        return
      end
      if names.item_enchanted_mango then
        local ok = pcall(function() Ability.CastTarget(item, ally) end)
        if ok then used = true else chat_say(t("mango_on_ally_fail")) end
      elseif names.item_flask or names.item_clarity then
        Ability.CastTarget(item, ally)
        used = true
      elseif names.item_tango then
        local shared_ok = pcall(function() Ability.CastTarget(item, ally) end)
        if shared_ok then
          used = true
        else
          local origin = ally or me
          local tree = find_nearest_tree(origin, 600)
          if tree then
            local ok = pcall(function() Ability.CastTarget(item, tree) end)
            if not ok then
              local pos = Entity.GetAbsOrigin(tree)
              if pos then pcall(function() Ability.CastPosition(item, pos) end) end
            end
            used = true
          else
            chat_say(t("no_tree_near_ally"))
            return
          end
        end
      end
      if used then
        state.use_cmd.last_time = now_t
        chat_say(t("use_success", wanted))
        status_push(t("use_success", wanted))
      end
      return
    end
  end
end

local function clear_attack_state()
  state.io.attack_target = nil
  state.io.attack_hold_until = 0
end

local function update_attack_with_hero(me, tether_target)
  if not ui.io_attack_with_hero or not ui.io_attack_with_hero:Get() then
    clear_attack_state()
    return { active = false, in_leash = false }
  end
  if not me or not tether_target then
    clear_attack_state()
    return { active = false, in_leash = false }
  end
  if not Entity.IsAlive(me) or not Entity.IsAlive(tether_target) then
    clear_attack_state()
    return { active = false, in_leash = false }
  end

  local aggro_target = state.io.attack_target or state.io.last_aggro_target
  local aggro_attacker = state.io.last_aggro_attacker
  if not aggro_target or not aggro_attacker then
    clear_attack_state()
    return { active = false, in_leash = false }
  end
  if aggro_attacker ~= tether_target then
    clear_attack_state()
    return { active = false, in_leash = false }
  end
  if not Entity.IsAlive(aggro_target) then
    clear_attack_state()
    return { active = false, in_leash = false }
  end
  if Entity.IsSameTeam(me, aggro_target) then
    clear_attack_state()
    return { active = false, in_leash = false }
  end

  local t_now = GlobalVars.GetCurTime() or 0
  local delay = (ui.io_attack_aggro_delay and ui.io_attack_aggro_delay:Get() or 100) / 1000.0
  local aggro_age = t_now - (state.io.last_aggro_time or 0)
  if aggro_age < delay or aggro_age > 8.0 then
    clear_attack_state()
    return { active = false, in_leash = false }
  end

  local my_pos = Entity.GetAbsOrigin(me)
  local target_pos = Entity.GetAbsOrigin(aggro_target)
  if not my_pos or not target_pos then return { active = false, in_leash = false } end

  local ally_pos = Entity.GetAbsOrigin(tether_target)
  if ally_pos then
    local ally_dist = ally_pos:Distance2D(target_pos)
    local ally_hull = NPC.GetHullRadius(tether_target) or 0
    local ally_attack_range = (NPC.GetAttackRange(tether_target) or 150) + ally_hull + 50
    if ally_dist > ally_attack_range then
      clear_attack_state()
      return { active = false, in_leash = false }
    end
  end

  local dist = my_pos:Distance2D(target_pos)
  local hull = NPC.GetHullRadius(me) or 0
  local attack_range = (NPC.GetAttackRange(me) or 150) + hull + 35
  local leash = attack_range + 425
  local chase_range = attack_range + 800

  if dist > chase_range then
    return { active = false, in_leash = false, target = aggro_target }
  end

  local hp = Entity.GetHealth(me) or 1
  local hp_max = Entity.GetMaxHealth(me) or 1
  local hp_frac = hp_max > 0 and (hp / hp_max) or 1
  if hp_frac < 0.16 and dist < attack_range * 0.9 then
    clear_attack_state()
    return { active = false, in_leash = true, target = aggro_target }
  end

  local order_cd = 0.15
  local hold_time = 0.9

  local want_attack = dist <= (attack_range + 75)
  local want_attack_move = (not want_attack) and dist <= chase_range

  return {
    active = want_attack or want_attack_move,
    in_leash = dist <= leash,
    want_attack = want_attack,
    want_attack_move = want_attack_move,
    target = aggro_target,
    dist = dist,
    attack_range = attack_range,
    hold_time = hold_time,
    order_cd = order_cd,
    chase_range = chase_range,
  }
end

function follow.OnScriptsLoaded()
  BuildUI()
end

function follow.OnFireEventClient(event)
  if event.name == "dota_hero_on_gain_aggro" then
    local attacker = Entity.Get(Event.GetInt(event.event, "entindex_attacker"))
    local target = Entity.Get(Event.GetInt(event.event, "entindex_hero"))

    if not attacker or not target then return end
    if not NPC.IsHero(attacker) or not NPC.IsHero(target) then return end

    local me = my()
    if not me then return end

    if not Entity.IsSameTeam(me, attacker) then return end
    if Entity.IsSameTeam(me, target) then return end

    state.io.last_aggro_attacker = attacker
    state.io.last_aggro_target = target
    state.io.last_aggro_time = GlobalVars.GetCurTime() or 0
  end
end

function follow.OnFrame()
  rebuild_io_ally_list(false)
end

function follow.OnPostReceivedNetMessage(data)
  if data.message_id == 612 then
    local json = JSON:decode(protobuf.decodeToJSONfromObject(data.msg_object))
    local playerid = json.source_player_id
    local channel = json.channel_type
    local text = json.message_text
    if channel == 12 then
      process_chat_command(playerid, text)
    end
  end
end

local function attempt_auto_upgrade()
  local me = my()
  if not me or not is_wisp(me) then return end
  if me ~= state.hero then return end
  if not timer_ready("upgrade", 0.25) then return end
  local abilityPoints = Hero.GetAbilityPoints(me)
  if abilityPoints <= 0 then return end
  local t = now()
  local function can_upgrade_any(mh)
    for i = 0, 25 do
      local ab = NPC.GetAbilityByIndex(mh, i)
      if ab and not Ability.IsHidden(ab) then
        local level = Ability.GetLevel(ab)
        local maxLevel = Ability.GetMaxLevel(ab)
        if level < maxLevel then
          return true
        end
      end
    end
    return false
  end
  if not can_upgrade_any(me) then return end
  local abilityList = Panorama.GetPanelByName("DOTAAbilityList", true)
  local talentList = Panorama.GetPanelByName("DOTAHUDLevelStatsFrame", true)
  if not abilityList or not talentList then return end
  if talentList:HasClass("recommended_upgrade") then
    local talentBranch = Panorama.GetPanelByName("DOTAStatBranch", false)
    if talentBranch then
      Engine.RunScript("$.DispatchEvent('DOTAHUDToggleStatBranchVisibility')", talentList)
      local statColumn = talentBranch and talentBranch:FindChildTraverse("StatBranchColumn") or nil
      if statColumn then
        for i = 0, statColumn:GetChildCount() - 1 do
          local upgradeOption = statColumn:GetChild(i)
          if upgradeOption then
            Engine.RunScript("$.DispatchEvent('DOTAHUDSelectStatBranchChoice')", upgradeOption)
            break
          end
        end
      end
      Engine.RunScript("$.DispatchEvent('DOTAHUDToggleStatBranchVisibility')", talentList)
    end
  elseif NPC.GetCurrentLevel(me) >= 26 then
    local talentBranch = Panorama.GetPanelByName("DOTAStatBranch", false)
    if talentBranch then
      Engine.RunScript("$.DispatchEvent('DOTAHUDToggleStatBranchVisibility')", talentList)
      local statColumn = talentBranch and talentBranch:FindChildTraverse("StatBranchColumn") or nil
      if statColumn then
        for i = 0, statColumn:GetChildCount() - 1 do
          local upgradeOption = statColumn:GetChild(i)
          if upgradeOption then
            Engine.RunScript("$.DispatchEvent('DOTAHUDSelectStatBranchChoice')", upgradeOption)
            break
          end
        end
      end
      Engine.RunScript("$.DispatchEvent('DOTAHUDToggleStatBranchVisibility')", talentList)
    end
  else
    for i = 0, abilityList:GetChildCount() - 1 do
      local ability = abilityList:GetChild(i)
      if ability and ability:HasClass("recommended_upgrade") then
        Engine.RunScript("$.DispatchEvent('DOTAHUDLevelUpAbility')", ability)
      end
    end
  end
  local remaining = Hero.GetAbilityPoints(me) or 0
  if remaining >= 1 and abilityList then
    local candidates = {}
    for i = 0, abilityList:GetChildCount() - 1 do
      local abilityPanel = abilityList:GetChild(i)
      if abilityPanel then
        local levelTab = abilityPanel:FindChildTraverse("LevelUpTab")
        if levelTab then
          candidates[#candidates + 1] = abilityPanel
        end
      end
    end
    if #candidates > 0 then
      local seed = math.floor(t * 1000)
      if seed > 0 then math.randomseed(seed) end
      for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
      end
      for idx = 1, #candidates do
        local before = Hero.GetAbilityPoints(me) or 0
        if before < 1 then break end
        local panel = candidates[idx]
        if panel then
          Engine.RunScript("$.DispatchEvent('DOTAHUDLevelUpAbility')", panel)
          local after = Hero.GetAbilityPoints(me) or 0
          if after < before then
            break
          end
        end
      end
    end
  end
end

function follow.OnUpdate()
  if not built then return end
  if not ui.enabled:Get() then return end
  if not Engine.IsInGame() then return end
  state.hero = Heroes.GetLocal()
  local me = state.hero
  if not me or not Entity.IsAlive(me) then return end
  state.player = Players.GetLocal()
  state.player_id = state.player and Player.GetPlayerID(state.player) or nil
  state.my_pos = Entity.GetAbsOrigin(me)
  rebuild_io_ally_list(false)
  attempt_auto_buy()
  check_and_drop_foreign_items()

  if (not state.link.waiting) and (not ui.wards_enabled or ui.wards_enabled:Get()) then
    ward_logic_tick()
  else
    state.wards.placing = false
    state.wards.place_timeout = 0
  end
  if state.use_pending then
    if not timer_ready("use_retry", 0.15) then return end
    local pend = state.use_pending
    local item, slot = get_item_and_slot(me, pend.names)
    if not item then
      chat_say(t("pending_use_missing"))
      status_push(t("use_failed_missing"))
      state.use_pending = nil
    else
      if slot and slot >= 6 then
        ensure_item_in_main(me, item, slot)
        pend.last = now()
        if now() > (pend.deadline or (pend.start + 3.0)) then
          chat_say(t("use_timeout_move"))
          status_push(t("use_timeout_status"))
          state.use_pending = nil
        end
        return
      end
      if Ability.CanBeExecuted(item) ~= -1 or not is_item_ready(item) then
        if now() > (pend.deadline or (pend.start + 3.0)) then
          chat_say(t("use_timeout_cd"))
          status_push(t("use_cd_status"))
          state.use_pending = nil
        end
        return
      end
      local used = false
      local ally = get_preferred_ally_target(me)
      if not ally then
        chat_say(t("no_ally"))
        status_push(t("no_ally"))
        state.use_pending = nil
        return
      end
      if pend.names.item_enchanted_mango then
        local ok = pcall(function() Ability.CastTarget(item, ally) end)
        if ok then used = true else chat_say(t("mango_on_ally_fail")) end
      elseif pend.names.item_flask or pend.names.item_clarity then
        Ability.CastTarget(item, ally)
        used = true
      elseif pend.names.item_tango then
        local shared_ok = pcall(function() Ability.CastTarget(item, ally) end)
        if shared_ok then
          used = true
        else
          local origin = ally or me
          local tree = find_nearest_tree(origin, 600)
          if tree then
            local ok = pcall(function() Ability.CastTarget(item, tree) end)
            if not ok then
              local pos = Entity.GetAbsOrigin(tree)
              if pos then pcall(function() Ability.CastPosition(item, pos) end) end
            end
            used = true
          else
            chat_say(t("no_tree_near_ally"))
            status_push(t("no_tree_near_ally"))
            state.use_pending = nil
            used = false
          end
        end
      end
      if used then
        state.use_cmd.last_time = now()
        chat_say(t("use_success", pend.wanted))
        status_push(t("use_success", pend.wanted))
        state.use_pending = nil
      end
    end
  end
  if is_wisp(me) and ui.io_auto_upgrade and ui.io_auto_upgrade:Get() then
    attempt_auto_upgrade()
  end
  announce_start_if_needed()
  if not state.game_init_done then
    if is_wisp(me) then
      state.link.waiting = true
      state.link.wait_start = now()
    end
    state.game_init_done = true
  end
  local target = nil
  local manual_link_dead = false
  if is_wisp(me) then
    if state.link.linked_player_id then
      local h = get_hero_by_player_id(state.link.linked_player_id)
      if h and Entity.IsAlive(h) then
        target = h
        if state.link.manual then
          state.follow.auto_target = nil
        end
      else
        if state.link.manual then
          manual_link_dead = true
        else
          state.link.linked_player_id = nil
          target = auto_link_by_criterion(true)
        end
      end
    end

    if state.link.linked_player_id and (now() - (state.link.last_unlink_reminder or 0)) >= 180 then
      chat_say(translate("unlink_reminder"))
      state.link.last_unlink_reminder = now()
    end
    if state.link.waiting then
      if not is_in_fountain(me) then
        if timer_ready("fountain_order", 1.0) then
          local p = Players.GetLocal()
          if p then
            local f = get_friendly_fountain(me)
            Player.PrepareUnitOrders(p, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, f, nil,
              Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
          end
        end
      end
      if now() - (state.link.wait_start or 0) >= 60 then
        local auto = select_auto_target_by_criterion()
        if auto then
          link_to_hero(auto, false)
          target = auto
          status_push(t("auto_link", get_display_name(auto)))
        end
      else
        return
      end
    end
  end
  if timer_ready("auto_follow", 500 / 1000.0) then
    state.follow.auto_target = select_auto_target_by_criterion()
  end
  if manual_link_dead then
    target = state.follow.auto_target
  elseif not target then
    target = state.follow.auto_target
  end
  if target and not Entity.IsAlive(target) then
    target = nil
    state.follow.auto_target = nil
  end
  if not target then
    state.follow.auto_target = select_auto_target_by_criterion()
    target = state.follow.auto_target
  end
  if not target then
    local p = Players.GetLocal()
    if p then
      local f = get_friendly_fountain(me)
      if f and timer_ready("fountain_order", 1.0) and not is_in_fountain(me) then
        Player.PrepareUnitOrders(p, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, f, nil,
          Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
        status_push("No target: moving to fountain")
      end
    end
    rebuild_io_ally_list(false)
    return
  end

  state.follow.current_target = target

  if is_in_fountain(target) then return end

  local ward_pause = state.wards and state.wards.pause_follow_until and state.wards.pause_follow_until > now()
  local ward_active = state.wards and state.wards.placing

  if is_teleporting(me) then return end
  if not timer_due("tp_suppress") then return end
  if attempt_tp_to_target(me, target) then return end

  attempt_io_tether(target)
  attempt_io_overcharge()
  attempt_wisp_spirits()
  local attack_info = { active = false, in_leash = false }
  if state.io.current_tether_target then
    attack_info = update_attack_with_hero(me, state.io.current_tether_target)
  else
    clear_attack_state()
  end

  local function attempt_auto_harass()
    if not ui.harass_enabled or not ui.harass_enabled:Get() then return false end
    state.harass.enabled = true
    state.harass.safe = (ui.harass_safe and ui.harass_safe:Get()) or state.harass.safe

    local radius = (ui.harass_radius and ui.harass_radius:Get()) or 800
    local min_hp_pct = (ui.harass_min_hp_pct and ui.harass_min_hp_pct:Get()) or 35
    local order_cd = ((ui.harass_order_cd_ms and ui.harass_order_cd_ms:Get()) or 300) / 1000.0
    local max_threat = (ui.harass_threat_limit and ui.harass_threat_limit:Get()) or 35

    local hp = Entity.GetHealth(me) or 1
    local hp_max = Entity.GetMaxHealth(me) or 1
    local hp_pct = (hp_max > 0) and (hp / hp_max * 100) or 100
    if hp_pct < min_hp_pct then return false end

    local t_now = now()
    if t_now < (state.harass.last_order or 0) + order_cd then return false end

    if state.follow.last_move_dest and state.follow.last_move_time then
      local my_pos = state.my_pos or Entity.GetAbsOrigin(me)
      local dir_to_dest = (state.follow.last_move_dest - my_pos):Normalized()
      local last_vel = dir_to_dest:Length2D() > 0 and dir_to_dest or nil
      if last_vel and state.harass.last_target_pos then
        local dir_to_prev_enemy = (state.harass.last_target_pos - my_pos):Normalized()
        if dir_to_prev_enemy:Dot2D(last_vel) < -0.25 then
          return false
        end
      end
    end

    local origin_unit = state.io.current_tether_target or me
    local origin_pos = Entity.GetAbsOrigin(origin_unit)
    local enemies = Entity.GetHeroesInRadius(origin_unit, radius, Enum.TeamType.TEAM_ENEMY) or {}
    local best_target, best_score = nil, -math.huge
    for _, e in ipairs(enemies) do
      if e and Entity.IsAlive(e) and not NPC.IsIllusion(e) then
        local epos = Entity.GetAbsOrigin(e)
        local dist = origin_pos:Distance2D(epos)
        local threat = analyze_threat_landscape(state.my_pos or origin_pos, epos)
        local total_threat = threat.threat_score or 0
        local danger = threat.danger_zone or false
        if (not state.harass.safe) or (total_threat <= max_threat and not danger) then
          local ehp = Entity.GetHealth(e)
          local emax = Entity.GetMaxHealth(e)
          local ehp_pct = (emax > 0) and (ehp / emax * 100) or 100
          local score = (100 - ehp_pct) + math.max(0, (radius - dist) * 0.05)
          if score > best_score then
            best_score = score
            best_target = e
          end
        end
      end
    end
    if not best_target then return false end

    local my_pos = Entity.GetAbsOrigin(me)
    local tgt_pos = Entity.GetAbsOrigin(best_target)
    if not my_pos or not tgt_pos then return false end

    if state.follow.last_move_dest then
      local dir_to_enemy = (tgt_pos - my_pos):Normalized()
      local dir_to_dest = (state.follow.last_move_dest - my_pos):Normalized()
      if dir_to_enemy:Dot2D(dir_to_dest) < -0.25 then return false end
    end

    local hull = NPC.GetHullRadius(me) or 0
    local attack_range = (NPC.GetAttackRange(me) or 150) + hull + 35
    local dist = my_pos:Distance2D(tgt_pos)
    local p = Players.GetLocal()
    if not p then return false end

    local same_target = state.harass.last_target and Entity.IsEntity(state.harass.last_target)
        and state.harass.last_target == best_target
    local moved_far = (state.harass.last_target_pos and state.harass.last_target_pos:Distance2D(tgt_pos) > 120)

    if dist <= (attack_range + 50) then
      if (not same_target) or moved_far then
        Player.PrepareUnitOrders(p, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, best_target, nil, nil,
          Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
        state.harass.last_order = t_now
        status_push(t("harass_attack", get_display_name(best_target)))
      end
    end

    state.harass.last_target = best_target
    state.harass.last_target_pos = tgt_pos
    state.harass.hold_until = t_now + 0.9
    return true
  end

  local my_pos = Entity.GetAbsOrigin(me)
  local base_dest = compute_dest(my_pos, target, attack_info)
  local safe_dest = apply_safety(base_dest, target, attack_info)
  local dest = ensure_traversable_from(my_pos, safe_dest)
  dest = clamp_dest_to_tether(me, dest, state.io.current_tether_target)
  local dist_to_dest = my_pos:Distance2D(dest)

  if attack_info.active and attack_info.target then
    local t_now = now()
    local p = Players.GetLocal()
    local attack_ready = timer_ready("io_attack", attack_info.order_cd or 0.15)
    if attack_ready then
      if attack_info.want_attack then
        Player.PrepareUnitOrders(p, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, attack_info.target, nil, nil,
          Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
        state.io.attack_hold_until = t_now + (attack_info.hold_time or 0.9)
        state.io.attack_target = attack_info.target
        status_push(t("attack_status", get_display_name(attack_info.target), math.floor(attack_info.dist or 0)))
      end
    end
  end

  local hold_active = state.io.attack_hold_until and state.io.attack_hold_until > now()
  local harass_hold = state.harass.hold_until and state.harass.hold_until > now()
  if attack_info.active and attack_info.in_leash then
    local my_attack_range = (NPC.GetAttackRange(me) or 150)
    if dist_to_dest < (my_attack_range * 0.55 + 80) then
      return
    end
  elseif hold_active or harass_hold then
    local my_attack_range = (NPC.GetAttackRange(me) or 150)
    if dist_to_dest < (my_attack_range * 0.35 + 50) then
      return
    end
  end

  if ward_pause or ward_active then return end

  if not attack_info.active then
    if attempt_auto_harass() then return end
  end

  local move_threshold = (ui.move_threshold and ui.move_threshold:Get()) or 30
  if dist_to_dest < move_threshold then return end
  if state.follow.last_move_dest and dest:Distance2D(state.follow.last_move_dest) < 25 then
    return
  end
  if not timer_ready("order", ui.interval:Get() / 1000.0) then
    return
  end
  state.follow.last_move_dest = dest
  state.follow.last_move_time = now()
  local p = Players.GetLocal()
  if not p then return end
  Player.PrepareUnitOrders(p, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, dest, nil,
    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
  status_push(t("move_status", dest.x, dest.y, math.floor(dist_to_dest)))
end

local function draw_minimal_arrow(start_pos, end_pos, color)
  if not start_pos or not end_pos then return end
  local s, s_vis = Render.WorldToScreen(start_pos)
  local e, e_vis = Render.WorldToScreen(end_pos)
  if not s_vis or not e_vis then return end

  Render.Line(s, e, color, 2)

  local dx = e.x - s.x
  local dy = e.y - s.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return end

  local nx = dx / len
  local ny = dy / len

  local arrow_len = 12
  local arrow_width = 8

  local p1x = e.x - (nx * arrow_len) + (ny * arrow_width)
  local p1y = e.y - (ny * arrow_len) - (nx * arrow_width)

  local p2x = e.x - (nx * arrow_len) - (ny * arrow_width)
  local p2y = e.y - (ny * arrow_len) + (nx * arrow_width)

  Render.FilledTriangle({ e, Vec2(p1x, p1y), Vec2(p2x, p2y) }, color)
end

function follow.OnDraw()
  if not built then return end
  if not ui.enabled or not ui.enabled:Get() then return end
  if not Engine.IsInGame() then return end
  overlay_init()

  local me = state.hero or my()
  if not me or not Entity.IsAlive(me) then return end

  local my_pos = Entity.GetAbsOrigin(me)
  if not my_pos then return end

  local move_dest = state.follow.last_move_dest
  if move_dest and (now() - (state.follow.last_move_time or 0) < 1.0) then
    draw_minimal_arrow(my_pos, move_dest, Color(0, 255, 200, 180))
  end

  local target = state.follow.current_target
  if target and Entity.IsAlive(target) then
    local target_pos = Entity.GetAbsOrigin(target)
    if target_pos then
      local s, s_vis = Render.WorldToScreen(my_pos)
      local t, t_vis = Render.WorldToScreen(target_pos)
      if s_vis and t_vis then
        Render.Line(s, t, Color(255, 255, 255, 30), 1)
      end
    end
  end

  if state.wards and (not ui.wards_enabled or ui.wards_enabled:Get()) then
    if state.wards.next_observer and state.wards.next_observer.pos then
      local s, v = Render.WorldToScreen(state.wards.next_observer.pos)
      if v then Render.FilledCircle(s, 5, Color(120, 210, 120, 200)) end
    end
    if state.wards.next_sentry then
      local s, v = Render.WorldToScreen(state.wards.next_sentry)
      if v then Render.FilledCircle(s, 5, Color(190, 160, 255, 200)) end
    end
  end

  local head_pos = my_pos + Vector(0, 0, 160)
  local s, visible = Render.WorldToScreen(head_pos)
  if not visible then return end

  local font = overlay.fonts.general or overlay.fonts.ui
  local font_size = 13

  local target_name = target and get_display_name(target) or "No Target"
  local hp_pct = 0
  if target and Entity.IsAlive(target) then
    hp_pct = Entity.GetHealth(target) / Entity.GetMaxHealth(target)
  end

  local action = overlay.last_action or "Idle"
  local threat = analyze_threat_landscape(my_pos, target and Entity.GetAbsOrigin(target) or my_pos)
  local threat_score = (threat and threat.threat_score) or 0

  local text_col = Color(255, 255, 255, 255)
  local sub_col = Color(200, 200, 200, 220)
  local threat_col = (threat_score > 100) and Color(255, 80, 80, 255) or Color(80, 255, 120, 255)

  local line1 = string.format("%s > %s", action, target_name)
  local sz1 = Render.TextSize(font, font_size, line1)

  local x = s.x - sz1.x / 2
  local y = s.y - 50

  Render.Shadow(Vec2(x - 6, y - 4), Vec2(x + sz1.x + 6, y + sz1.y + 4), Color(0, 0, 0, 180), 15, 4)
  Render.Text(font, font_size, line1, Vec2(x, y), text_col)

  local dist = target and math.floor(my_pos:Distance2D(Entity.GetAbsOrigin(target))) or 0
  local line2 = string.format("%.0f u  |  %.0f%%", dist, hp_pct * 100)
  local sz2 = Render.TextSize(font, 11, line2)
  local x2 = s.x - sz2.x / 2
  local y2 = y + sz1.y + 2

  Render.Shadow(Vec2(x2 - 4, y2 - 2), Vec2(x2 + sz2.x + 4, y2 + sz2.y + 2), Color(0, 0, 0, 180), 10, 4)
  Render.Text(font, 11, line2, Vec2(x2, y2), sub_col)

  Render.FilledCircle(Vec2(x2 - 10, y2 + 6), 3, threat_col)

  if is_wisp(me) and state.io.current_tether_target then
    local tname = get_display_name(state.io.current_tether_target)
    local line3 = "Tether: " .. tname
    local sz3 = Render.TextSize(font, 11, line3)
    Render.Text(font, 11, line3, Vec2(s.x - sz3.x / 2, y2 + sz2.y + 2), Color(100, 200, 255, 220))
  end
end

function follow.OnGameEnd()
  state.hero = nil
  state.timers = {}
  state.io.allies = {}
  state.io.last_ally_update = 0
  state.io.current_tether_target = nil
  state.follow.auto_target = nil
  state.follow.current_target = nil
  state.follow.last_move_dest = nil
  state.autobuy.stage_index = 1
  state.autobuy.secret_active = false
  state.autobuy.secret_target = nil
  state.autobuy.done = false
  state.player = nil
  state.player_id = nil
  state.my_pos = nil
  state.chat_channel = nil
  state.announced_start = false
  state.game_init_done = false
  state.link.waiting = false
  state.link.wait_start = 0
  state.link.linked_player_id = nil
  state.link.manual = false
  state.link.last_unlink_reminder = 0
  state.link.last_random_target = nil
  state.link.last_random_time = 0
  state.wards.helper = nil
  state.wards.has_positions = false
  state.wards.observer_spots = {}
  state.wards.sentry_spots = {}
  state.wards.heat_samples = {}
  state.wards.heat_center = nil
  state.wards.next_observer = nil
  state.wards.next_sentry = nil
  state.wards.enemy_wards = {}
  state.wards.pause_follow_until = 0
  state.wards.placing = false
  state.wards.place_timeout = 0
  state.wards.swap_back_slot = nil
  state.wards.last_purchase = 0
  state.wards.last_place_time = 0
end

return follow
