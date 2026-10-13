---@diagnostic disable: undefined-global

local script = {}

local localization = qLocalization.new({
    en = {
        menu = {
            main = "Eul Combo",
            enabled = "Enabled",
            key = "Combo key",
            key_tip = "Hold: Eul or Wind Waker on the enemy nearest to the cursor, then the spells land right as it falls",
            spells = "Spells",
            spells_tip = "Tame the Beasts cracks at full power right as the target falls, then the Wheel goes behind the target so the fear walks it in, daggers follow",
            daggers = "Daggers",
            items_group = "Item Settings",
            items = "Items Usage",
            items_tip = "Blink / Fallen Sky: jump in when the enemy is out of Eul range. Self buffs go before Eul. After the Wheel: Shiva, Vessel, Bloodthorn and the other debuffs. Hex and Abyssal only extend control that is about to end. Meteor Hammer and invisibility last",
            important = "Important Items",
            semi = "Semi-Important Items",
            other = "Other Items",
            utility = "Utility Items",
            neutral = "Neutral Items",
            linken = "Linken Breaker",
            linken_tip = "Before Eul spends the first available item on the target when its Linken's Sphere is up. Drag to set the order.",
        },
        panel = {
            menu_failed = "Ringmaster Eul Combo: menu failed",
        },
    },
    ru = {
        menu = {
            main = "Прокаст через Eul",
            enabled = "Включить",
            key = "Клавиша комбо",
            key_tip = "Зажми: Eul или Wind Waker на врага у курсора, затем скиллы прилетают ровно к его падению",
            spells = "Способности",
            spells_tip = "Кнут бьёт на полном заряде ровно к падению, затем колесо за спину цели — страх заводит её в него, следом кинжалы",
            daggers = "Кинжалы",
            items_group = "Настройки предметов",
            items = "Использование предметов",
            items_tip = "Блинк / Fallen Sky: врыв, если враг дальше радиуса Eul. Баффы на себя — до Eul. После колеса: Шива, Весл, Блудторн и остальные дебаффы. Хекс и Абиссал только продлевают заканчивающийся контроль. Метеор и невидимость — в самом конце",
            important = "Важные предметы",
            semi = "Полу-важные предметы",
            other = "Другие предметы",
            utility = "Дополнительные предметы",
            neutral = "Нейтральные предметы",
            linken = "Сбитие Линки",
            linken_tip = "Перед Eul тратит в цель первый доступный предмет, если у неё поднята Линка. Порядок задаётся перетаскиванием.",
        },
        panel = {
            menu_failed = "Ringmaster Eul Combo: меню не создалось",
        },
    },
    cn = {
        menu = {
            main = "吹风连招",
            enabled = "启用",
            key = "连招按键",
            key_tip = "按住：对光标附近的敌人使用吹风或风之杖，技能在其落地时命中",
            spells = "技能",
            spells_tip = "驯兽之鞭在目标落地时满蓄力抽击，随后奇观之轮落在目标身后，恐惧使其走入，最后投掷匕首",
            daggers = "匕首",
            items_group = "物品设置",
            items = "物品使用",
            items_tip = "跳刀/天陨：敌人超出吹风距离时切入。自身增益在吹风前使用。奇观之轮之后：希瓦、魂之灵瓮、血棘等减益。邪恶镰刀和深渊之刃只用于延长即将结束的控制。陨星锤和隐身最后使用",
            important = "重要物品",
            semi = "次重要物品",
            other = "其他物品",
            utility = "辅助物品",
            neutral = "中立物品",
            linken = "破林肯",
            linken_tip = "吹风前若目标林肯法球可用，先对其使用第一个可用物品。拖动调整顺序。",
        },
        panel = {
            menu_failed = "Ringmaster Eul Combo: 菜单创建失败",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local HERO = "npc_dota_hero_ringmaster"
local CYCLONE_ITEMS = { "item_wind_waker", "item_cyclone" }
local CYCLONE = "modifier_eul_cyclone"
local WIND_CYCLONE = "modifier_wind_waker"
local CYCLONE_MODS = { CYCLONE, WIND_CYCLONE }
local WHEEL = "ringmaster_wheel"
local WHIP = "ringmaster_tame_the_beasts"
local DAGGER = "ringmaster_impalement"

local WHEEL_POINT = 0.2
local WHEEL_SPEED = 1200
local WHEEL_MIN_RANGE = 700
local WHEEL_OVERRUN = 150
local WHIP_REACH = 750
local FEAR_DELAY = 0.3
local FEAR_TIMES = { 0.6, 0.8, 1.0, 1.2 }
local DAGGER_POINT = 0.3
local WHIP_CHANNEL = 1.0
local WHIP_AFTER = 0.05
local ORDER_LEAD = 0.083
local DAGGER_AFTER = 0.05
local GAP = 0.1
local EUL_TIMEOUT = 0.5
local CYCLONE_TIME = 2.5
local MAX_LATENCY = 0.5
local COMBO_TAIL = 3

local CHAIN_LEAD = 0.1
local CHAIN_WAIT = 0.35
local TRAP_TIME = 4
local RANGE_SLACK = 50
local SHIVA_RANGE = 600
local COMBO_MAX = 9

local SPELLS = {
    { name = WHEEL },
    { name = WHIP },
    { name = DAGGER },
}

local BLINKS = { "item_blink", "item_swift_blink", "item_arcane_blink", "item_overwhelming_blink" }
local ITEM_GROUPS = { "important", "semi", "other", "utility", "neutral" }

local ITEMS = {
    { name = "item_blink", group = "important", kind = "point", phase = "blink", names = BLINKS },
    { name = "item_fallen_sky", group = "important", kind = "point", phase = "blink", off = true },
    { name = "item_soul_ring", group = "utility", kind = "self", phase = "pre" },
    { name = "item_armlet", group = "other", kind = "self", phase = "pre", toggle = true, off = true },
    { name = "item_black_king_bar", group = "important", kind = "self", phase = "pre" },
    { name = "item_satanic", group = "important", kind = "self", phase = "pre" },
    { name = "item_blade_mail", group = "other", kind = "self", phase = "pre" },
    { name = "item_manta", group = "other", kind = "self", phase = "pre", off = true },
    { name = "item_mask_of_madness", group = "other", kind = "self", phase = "pre" },
    { name = "item_phase_boots", group = "other", kind = "self", phase = "pre" },
    { name = "item_bloodstone", group = "semi", kind = "self", phase = "pre" },
    { name = "item_ancient_janggo", group = "utility", kind = "self", phase = "pre" },
    { name = "item_boots_of_bearing", group = "utility", kind = "self", phase = "pre" },
    { name = "item_crimson_guard", group = "utility", kind = "self", phase = "pre" },
    { name = "item_guardian_greaves", group = "utility", kind = "self", phase = "pre" },
    { name = "item_mekansm", group = "utility", kind = "self", phase = "pre" },
    { name = "item_pipe", group = "utility", kind = "self", phase = "pre" },
    { name = "item_mjollnir", group = "other", kind = "ally", phase = "pre" },
    { name = "item_solar_crest", group = "utility", kind = "ally", phase = "pre" },
    { name = "item_essence_distiller", group = "utility", kind = "ally", phase = "pre" },
    { name = "item_polliwog_charm", group = "neutral", kind = "ally", phase = "pre" },
    { name = "item_ash_legion_shield", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_dagger_of_ristul", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_demonicon", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_essence_ring", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_flayers_bota", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_idol_of_screeauk", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_jidi_pollen_bag", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_kobold_cup", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_minotaur_horn", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_riftshadow_prism", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_spider_legs", group = "neutral", kind = "self", phase = "pre" },
    { name = "item_shivas_guard", group = "semi", kind = "self", phase = "after", range = SHIVA_RANGE },
    { name = "item_spirit_vessel", group = "utility", kind = "enemy", phase = "after", charges = true },
    { name = "item_urn_of_shadows", group = "utility", kind = "enemy", phase = "after", charges = true },
    { name = "item_bloodthorn", group = "important", kind = "enemy", phase = "after" },
    { name = "item_orchid", group = "important", kind = "enemy", phase = "after" },
    { name = "item_nullifier", group = "important", kind = "enemy", phase = "after" },
    { name = "item_veil_of_discord", group = "semi", kind = "self", phase = "after" },
    { name = "item_ethereal_blade", group = "semi", kind = "enemy", phase = "after" },
    { name = "item_dagon", group = "semi", kind = "enemy", phase = "after", names = { "item_dagon_5", "item_dagon_4", "item_dagon_3", "item_dagon_2", "item_dagon" }, icon = "dagon_5" },
    { name = "item_diffusal_blade", group = "other", kind = "enemy", phase = "after" },
    { name = "item_disperser", group = "other", kind = "enemy", phase = "after" },
    { name = "item_heavens_halberd", group = "semi", kind = "enemy", phase = "after" },
    { name = "item_rod_of_atos", group = "semi", kind = "enemy", phase = "after" },
    { name = "item_gungir", group = "semi", kind = "point", phase = "after" },
    { name = "item_blood_grenade", group = "other", kind = "point", phase = "after" },
    { name = "item_crippling_crossbow", group = "neutral", kind = "enemy", phase = "after" },
    { name = "item_medallion_of_courage", group = "neutral", kind = "enemy", phase = "after" },
    { name = "item_heavy_blade", group = "neutral", kind = "point", phase = "after" },
    { name = "item_harpoon", group = "semi", kind = "enemy", phase = "after", off = true },
    { name = "item_hurricane_pike", group = "utility", kind = "enemy", phase = "after", off = true },
    { name = "item_sheepstick", group = "important", kind = "enemy", phase = "chain" },
    { name = "item_abyssal_blade", group = "important", kind = "enemy", phase = "chain" },
    { name = "item_meteor_hammer", group = "other", kind = "point", phase = "last", off = true, hold = 2.1 },
    { name = "item_invis_sword", group = "other", kind = "self", phase = "last", off = true },
    { name = "item_silver_edge", group = "other", kind = "self", phase = "last", off = true },
}

local BREAKERS = {
    { "item_sheepstick", "sheepstick", false },
    { "item_nullifier", "nullifier", false },
    { "item_orchid", "orchid", false },
    { "item_bloodthorn", "bloodthorn", false },
    { "item_ethereal_blade", "ethereal_blade", false },
    { "item_dagon", "dagon_5", false, { "item_dagon_5", "item_dagon_4", "item_dagon_3", "item_dagon_2", "item_dagon" } },
    { "item_spirit_vessel", "spirit_vessel", false },
    { "item_urn_of_shadows", "urn_of_shadows", false },
    { "item_rod_of_atos", "rod_of_atos", true },
    { "item_gungir", "gungir", true },
    { "item_diffusal_blade", "diffusal_blade", true },
    { "item_disperser", "disperser", true },
    { "item_abyssal_blade", "abyssal_blade", true },
    { "item_heavens_halberd", "heavens_halberd", true },
    { "item_force_staff", "force_staff", true },
    { "item_hurricane_pike", "hurricane_pike", true },
    { "item_harpoon", "harpoon", true },
}
local BREAKER_BY_ID = {}
for _, b in ipairs(BREAKERS) do BREAKER_BY_ID[b[1]] = b[4] or { b[1] } end
local LINKEN = "item_sphere"
local BREAK_WAIT = 0.6
local BLINK_STAND = 400
local BLINK_EDGE = 25
local BLINK_WAIT = 0.15
local BLINK_HOLD = 0.6

local function api(tbl, name)
    return type(tbl) == "table" and type(tbl[name]) == "function" and tbl[name] or nil
end

local HAS_ENUM = type(Enum) == "table"
local CAST_READY = HAS_ENUM and type(Enum.AbilityCastResult) == "table" and Enum.AbilityCastResult.READY or -1
local TEAM_ENEMY = HAS_ENUM and type(Enum.TeamType) == "table" and Enum.TeamType.TEAM_ENEMY or 0
local KEY_V = HAS_ENUM and type(Enum.ButtonCode) == "table" and Enum.ButtonCode.KEY_V or 32
local STATES = HAS_ENUM and type(Enum.ModifierState) == "table" and Enum.ModifierState or {}
local STATE_STUN = STATES.MODIFIER_STATE_STUNNED or 5
local STATE_HEX = STATES.MODIFIER_STATE_HEXED or 6
local STATE_FEAR = STATES.MODIFIER_STATE_FEARED or 47
local STATE_RESTRICTED = STATES.MODIFIER_STATE_COMMAND_RESTRICTED or 20
local STATE_MAGIC_IMMUNE = STATES.MODIFIER_STATE_MAGIC_IMMUNE or 9
local STATE_DEBUFF_IMMUNE = STATES.MODIFIER_STATE_DEBUFF_IMMUNE or 56
local MESMERIZE_FACING = "modifier_ringmaster_wheel_mesmerize_facing"
local WHIP_FEAR = "modifier_ringmaster_tame_the_beasts_fear"
local CURSOR_HERO = api(Input, "GetNearestHeroToCursor")
local AVG_LATENCY = api(NetChannel, "GetAvgLatency")

local ui = {}
local ready = false
local g_menu_error = nil
local S = { phase = "idle", target = nil, sentAt = 0, land = 0, whipAt = nil, nextOrder = 0, daggers = 0, error = nil, font = nil, landSource = nil, latency = 0, used = {}, wheelCast = false, whipCast = false, wheelLand = 0, breakUntil = 0, blinkUntil = 0 }

local function log(level, message, data)
    if type(ai_bridge) ~= "table" or type(ai_bridge.mcp_log) ~= "function" then return end
    pcall(ai_bridge.mcp_log, level, message, data)
end

local function initialize_menu()
    local side = (HAS_ENUM and Enum.GroupSide) or {}
    local section = Menu.Create("Heroes", "Hero List", "Ringmaster", "Eul Combo")
    local group = section:Create("menu.main", side.Left)

    ui.enabled = group:Switch("menu.enabled", true, "\u{f0e7}")
    ui.key = group:Bind("menu.key", KEY_V, "panorama/images/items/cyclone_png.vtex_c")
    ui.key:ToolTip("menu.key_tip")
    local rows = {}
    for i, spell in ipairs(SPELLS) do rows[i] = { spell.name, "panorama/images/spellicons/" .. spell.name .. "_png.vtex_c", true } end
    ui.spells = group:MultiSelect("menu.spells", rows, true)
    ui.spells:ToolTip("menu.spells_tip")
    ui.daggers = group:Slider("menu.daggers", 0, 4, 3, "%d")
    pcall(ui.daggers.Image, ui.daggers, "panorama/images/spellicons/ringmaster_impalement_png.vtex_c")

    local goods = section:Create("menu.items_group", side.Right)
    local usage = goods:Label("menu.items")
    usage:Icon("\u{e196}")
    usage:ToolTip("menu.items_tip")
    local gear = usage:Gear("menu.items", "\u{f0c9}")
    ui.items = {}
    for _, g in ipairs(ITEM_GROUPS) do
        local itemRows = {}
        for _, item in ipairs(ITEMS) do
            if item.group == g then
                local icon = item.icon or item.name:gsub("^item_", "")
                itemRows[#itemRows + 1] = { item.name, "panorama/images/items/" .. icon .. "_png.vtex_c", not item.off }
            end
        end
        ui.items[g] = gear:MultiSelect("menu." .. g, itemRows, true)
        ui.items[g]:DragAllowed(false)
    end
    local breakerRows = {}
    for i, b in ipairs(BREAKERS) do breakerRows[i] = { b[1], "panorama/images/items/" .. b[2] .. "_png.vtex_c", b[3] } end
    ui.breaker = goods:MultiSelect("menu.linken", breakerRows, false)
    ui.breaker:Image("panorama/images/items/sphere_png.vtex_c")
    ui.breaker:ToolTip("menu.linken_tip")
    ui.breaker:DragAllowed(true)
    return true
end

local function reset(reason)
    if S.phase ~= "idle" then log("info", "combo end", { reason = reason }) end
    S.phase = "idle"
    S.target = nil
    S.whipAt = nil
    S.daggers = 0
    S.used = {}
    S.wheelCast = false
    S.whipCast = false
    S.wheelLand = 0
end

local function castable(h)
    return h ~= nil and Ability.GetLevel(h) > 0 and Ability.IsReady(h) and Ability.CanBeExecuted(h) == CAST_READY
end

local function wanted(name, hero)
    if not ui.spells:Get(name) then return nil end
    local h = NPC.GetAbility(hero, name)
    if castable(h) then return h end
    return nil
end

local function first_item(hero, names)
    for _, name in ipairs(names) do
        local h = NPC.GetItem(hero, name, true)
        if castable(h) then return h end
    end
    return nil
end

local function break_linken(hero, target, dist, now)
    local sphere = NPC.GetItem(target, LINKEN)
    if sphere == nil or Ability.GetCooldown(sphere) ~= 0 then return false end
    if now < S.breakUntil then return true end
    S.breakUntil = now + BREAK_WAIT
    local bonus = NPC.GetCastRangeBonus(hero)
    for _, id in ipairs(ui.breaker:ListEnabled()) do
        local h = BREAKER_BY_ID[id] and first_item(hero, BREAKER_BY_ID[id])
        if h and dist <= Ability.GetCastRange(h) + bonus + RANGE_SLACK then
            Ability.CastTarget(h, target)
            S.used[id] = true
            log("info", "linken break", { item = id, dist = dist })
            return true
        end
    end
    log("info", "linken up, no breaker", { dist = dist })
    return true
end

local function blink_distance(dist, reach, range)
    local r = math.min(dist - BLINK_STAND, reach)
    if r <= 0 or dist - r > range then return nil end
    return r
end

local function our_cyclone(target, hero)
    for _, name in ipairs(CYCLONE_MODS) do
        local mod = NPC.GetModifier(target, name)
        if mod ~= nil and Modifier.GetCaster(mod) == hero then return mod end
    end
    return nil
end

local function has_bit(mask, bit)
    local p = 1
    for _ = 1, bit do p = p * 2 end
    return mask % (p * 2) >= p
end

local function disable_left(target, at)
    local left, found, facing = 0, false, false
    for _, mod in ipairs(NPC.GetModifiers(target)) do
        local on, name = Modifier.GetState(mod), Modifier.GetName(mod)
        local control = type(on) == "number" and (has_bit(on, STATE_STUN) or has_bit(on, STATE_HEX) or has_bit(on, STATE_FEAR) or has_bit(on, STATE_RESTRICTED))
        if name == MESMERIZE_FACING then
            facing = true
        elseif control and name ~= CYCLONE and name ~= WIND_CYCLONE then
            left, found = math.max(left, Modifier.GetDieTime(mod) - at), true
        end
    end
    if facing then return math.max(left, TRAP_TIME), true end
    return left, found
end

local function item_on(e)
    return ui.items[e.group]:Get(e.name)
end

local function usable(hero, e, dist)
    if S.used[e.name] or not item_on(e) then return nil end
    local h = first_item(hero, e.names or { e.name })
    if h == nil then return nil end
    if (e.kind == "enemy" or e.kind == "point" or e.range) and dist > (e.range or Ability.GetCastRange(h)) + NPC.GetCastRangeBonus(hero) + RANGE_SLACK then return nil end
    if e.charges and Item.GetCurrentCharges(h) <= 0 then return nil end
    if e.toggle and Ability.GetToggleState(h) then return nil end
    return h
end

local function pick_phase(hero, dist, phase)
    for _, e in ipairs(ITEMS) do
        if e.phase == phase then
            local h = usable(hero, e, dist)
            if h then return e, h end
        end
    end
    return nil
end

local function pick_item(hero, t, dist, at)
    local left, found, waiting = nil, false, false
    for _, e in ipairs(ITEMS) do
        if e.phase == "after" or e.phase == "chain" then
            local h = usable(hero, e, dist)
            if h then
                if e.phase == "after" then return e, h, false end
                if left == nil then left, found = disable_left(t, at) end
                if found and left <= CHAIN_LEAD then return e, h, false end
                waiting = true
            end
        end
    end
    return nil, nil, waiting
end

local function cast_item(hero, e, h, t)
    if e.kind == "enemy" then
        Ability.CastTarget(h, t)
    elseif e.kind == "ally" then
        Ability.CastTarget(h, hero)
    elseif e.kind == "point" then
        Ability.CastPosition(h, Entity.GetAbsOrigin(t))
    else
        Ability.CastNoTarget(h)
    end
    S.used[e.name] = true
end

local function blink_in(hero, target, dist, range, now)
    if now < S.blinkUntil then return end
    for _, e in ipairs(ITEMS) do
        local blink = e.phase == "blink" and item_on(e) and first_item(hero, e.names or { e.name })
        if blink and Item.IsItemEnabled(blink) then
            local r = blink_distance(dist, Ability.GetCastRange(blink) + NPC.GetCastRangeBonus(hero) - BLINK_EDGE, range)
            if r == nil then return end
            local o, p = Entity.GetAbsOrigin(hero), Entity.GetAbsOrigin(target)
            Ability.CastPosition(blink, Vector(o.x + (p.x - o.x) / dist * r, o.y + (p.y - o.y) / dist * r, o.z))
            S.nextOrder = now + BLINK_WAIT
            S.blinkUntil = now + BLINK_HOLD
            log("info", "blink in", { item = e.name, dist = dist, jump = r })
            return
        end
    end
end

local function mod_list(target, now)
    local names, out = {}, {}
    for _, mod in ipairs(NPC.GetModifiers(target)) do
        local name = Modifier.GetName(mod)
        names[#names + 1] = name
        out[#out + 1] = { name = name, state = Modifier.GetState(mod), left = Modifier.GetDieTime(mod) - now }
    end
    table.sort(names)
    return table.concat(names, ","), out
end

local function items_state(hero)
    local out = {}
    for _, e in ipairs(ITEMS) do
        for _, name in ipairs(e.names or { e.name }) do
            local h = NPC.GetItem(hero, name, true)
            if h ~= nil then out[name] = { selected = item_on(e), result = Ability.CanBeExecuted(h), cd = Ability.GetCooldown(h), charges = Item.GetCurrentCharges(h) } end
        end
    end
    return out
end

local function whip_state(hero)
    local h = NPC.GetAbility(hero, WHIP)
    if h == nil then return { found = false, selected = ui.spells:Get(WHIP) } end
    return { selected = ui.spells:Get(WHIP), level = Ability.GetLevel(h), ready = Ability.IsReady(h), result = Ability.CanBeExecuted(h), cd = Ability.GetCooldown(h) }
end

local function watch(hero, now)
    local w = S.watch
    if w == nil then return end
    if now > w.stop then S.watch = nil return end
    local air = Entity.IsAlive(w.target) and our_cyclone(w.target, hero) ~= nil
    local ch = NPC.IsChannellingAbility(hero)
    if air ~= w.air then log("info", "watch cyclone", { on = air, t = now - w.land }) end
    if ch ~= w.ch then log("info", "watch channel", { on = ch, t = now - w.land }) end
    w.air, w.ch = air, ch
    if Entity.IsAlive(w.target) then
        local sig, mods = mod_list(w.target, now)
        if sig ~= w.mods then log("info", "watch target mods", { t = now - w.land, mods = mods }) end
        w.mods = sig
    end
end

local function latency()
    local v = AVG_LATENCY and AVG_LATENCY() or 0
    if type(v) ~= "number" or v ~= v then return 0 end
    if v > 1 then v = v / 1000 end
    return math.max(0, math.min(v, MAX_LATENCY))
end

local function land_time(mod, now)
    local die = Modifier.GetDieTime(mod)
    if type(die) == "number" and die - now > 0 and die - now <= CYCLONE_TIME + 0.1 then return die, "die" end
    return now + CYCLONE_TIME, "seen"
end

local function plan(land, useWhip)
    return useWhip and land - WHIP_CHANNEL + WHIP_AFTER - ORDER_LEAD or nil
end

local function wheel_land(now, dist)
    return now + WHEEL_POINT + math.max(dist, WHEEL_MIN_RANGE) / WHEEL_SPEED
end

local function wheel_plan(dist, speed, at, fearStart, fearEnd, range)
    local w = WHEEL_MIN_RANGE
    for _ = 1, 4 do
        local lands = at + WHEEL_POINT + w / WHEEL_SPEED
        local ahead = dist + speed * math.max(0, math.min(lands, fearEnd) - math.max(at, fearStart)) + WHEEL_OVERRUN
        if ahead <= w then break end
        w = ahead
    end
    if w > range then return nil, "out of range" end
    local lands = at + WHEEL_POINT + w / WHEEL_SPEED
    if lands >= fearEnd then return nil, "lands after fear" end
    return w, lands
end

local function start(hero, now)
    if CURSOR_HERO == nil or now < S.nextOrder then return end
    local target = CURSOR_HERO(Entity.GetTeamNum(hero), TEAM_ENEMY)
    if target == nil or not Entity.IsAlive(target) then return end
    if our_cyclone(target, hero) ~= nil then
        S.phase, S.target = "sent", target
        return
    end
    local eul = first_item(hero, CYCLONE_ITEMS)
    if eul == nil then return end
    local dist = (Entity.GetAbsOrigin(target) - Entity.GetAbsOrigin(hero)):Length()
    local range = Ability.GetCastRange(eul) + NPC.GetCastRangeBonus(hero)
    if dist > range then return blink_in(hero, target, dist, range, now) end
    if break_linken(hero, target, dist, now) then return end
    local buff, h = pick_phase(hero, dist, "pre")
    if buff then
        cast_item(hero, buff, h, target)
        S.nextOrder = now + GAP
        log("info", "item " .. buff.name, { phase = "pre" })
        return
    end
    Ability.CastTarget(eul, target)
    S.phase, S.target, S.sentAt = "sent", target, now
    log("info", "eul sent", { item = Ability.GetName(eul), dist = dist })
end

local function run(hero, now)
    local t = S.target
    if not Entity.IsAlive(t) then return reset("target dead") end
    local pos = Entity.GetAbsOrigin(t)
    local dist = (pos - Entity.GetAbsOrigin(hero)):Length()
    local mod = our_cyclone(t, hero)

    if S.phase == "sent" then
        if mod == nil then
            if now - S.sentAt > EUL_TIMEOUT then reset("no cyclone") end
            return
        end
        S.land, S.landSource = land_time(mod, now)
        S.whipAt = plan(S.land, wanted(WHIP, hero) ~= nil)
        S.phase = "air"
        S.watch = { target = t, land = S.land, stop = S.land + COMBO_MAX, air = true, ch = NPC.IsChannellingAbility(hero) }
        log("info", "cyclone", { modifier = Modifier.GetName(mod), land_in = S.land - now, source = S.landSource, die_raw = Modifier.GetDieTime(mod), latency_raw = AVG_LATENCY and AVG_LATENCY(), whip_at = S.whipAt and S.whipAt - now, whip = whip_state(hero), items = items_state(hero) })
    end

    S.latency = latency()
    local at = now + S.latency
    if now < S.nextOrder or NPC.IsChannellingAbility(hero) then return end

    local whip = S.whipAt and wanted(WHIP, hero)
    if not whip then S.whipAt = nil end

    if whip and at >= S.whipAt then
        Ability.CastPosition(whip, pos)
        S.whipAt = nil
        S.whipCast = true
        S.nextOrder = now + GAP
        log("info", "whip", { land_in = S.land - now })
        return
    end
    if S.whipAt ~= nil or at < S.land + DAGGER_AFTER then return end

    local wheel = not S.wheelCast and wanted(WHEEL, hero)
    if wheel and not S.whipCast then
        Ability.CastPosition(wheel, pos)
        S.wheelCast = true
        S.wheelLand = wheel_land(now, dist)
        S.nextOrder = now + WHEEL_POINT + GAP
        log("info", "wheel", { t = now - S.land, lands_in = S.wheelLand - now, items = items_state(hero) })
        return
    elseif wheel then
        S.wheelCast = true
        local speed = NPC.GetMoveSpeed(t)
        local info = { t = now - S.land, dist = dist, speed = speed }
        if dist > WHIP_REACH or NPC.HasState(t, STATE_DEBUFF_IMMUNE) or NPC.HasState(t, STATE_MAGIC_IMMUNE) then
            info.reason = "no fear"
            log("info", "wheel skip", info)
        else
            local fear = NPC.GetModifier(t, WHIP_FEAR)
            local level = Ability.GetLevel(NPC.GetAbility(hero, WHIP))
            local fearStart = fear and at or S.land + FEAR_DELAY
            local fearEnd = fear and Modifier.GetDieTime(fear) or fearStart + (FEAR_TIMES[level] or FEAR_TIMES[#FEAR_TIMES])
            local w, lands = wheel_plan(math.max(dist, 1), speed, at, fearStart, fearEnd, Ability.GetCastRange(wheel) + NPC.GetCastRangeBonus(hero))
            info.fear_seen, info.fear_end, info.w = fear ~= nil, fearEnd - at, w
            if w == nil then
                info.reason = lands
                log("info", "wheel skip", info)
            else
                local o = Entity.GetAbsOrigin(hero)
                local d = math.max(dist, 1)
                Ability.CastPosition(wheel, Vector(o.x + (pos.x - o.x) / d * w, o.y + (pos.y - o.y) / d * w, pos.z))
                S.wheelLand = lands
                S.nextOrder = now + WHEEL_POINT + GAP
                info.lands_in = lands - at
                log("info", "wheel", info)
                return
            end
        end
    end

    local entry, item, waiting = pick_item(hero, t, dist, at)
    if item then
        cast_item(hero, entry, item, t)
        S.nextOrder = now + (entry.phase == "chain" and CHAIN_WAIT or GAP)
        log("info", "item " .. entry.name, { t = now - S.land, disable_left = disable_left(t, now) })
        return
    end
    local dagger = S.daggers < ui.daggers:Get() and wanted(DAGGER, hero)
    if dagger then
        Ability.CastPosition(dagger, pos)
        S.daggers = S.daggers + 1
        S.nextOrder = now + DAGGER_POINT + GAP
        log("info", "dagger", { n = S.daggers })
        return
    end
    if waiting then
        if now > S.land + COMBO_MAX then reset("done") end
        return
    end
    local final, fh = pick_phase(hero, dist, "last")
    if final then
        cast_item(hero, final, fh, t)
        S.nextOrder = now + (final.hold or GAP)
        log("info", "item " .. final.name, { t = now - S.land, phase = "last" })
        return
    end
    if now > S.land + COMBO_TAIL then reset("done") end
end

local function update()
    local hero = Heroes.GetLocal()
    if hero == nil or NPC.GetUnitName(hero) ~= HERO or not Entity.IsAlive(hero) then return reset("no hero") end
    local now = GameRules.GetGameTime()
    watch(hero, now)
    if not ui.key:IsDown() then
        if S.phase == "air" then log("info", "key released in air", { t = now - S.land }) end
        return reset("key released")
    end
    if S.phase == "idle" then return start(hero, now) end
    run(hero, now)
end

function script.OnScriptsLoaded()
    local ok, res = pcall(initialize_menu)
    ready = ok and res == true
    if not ready then g_menu_error = ok and "initialize_menu returned false" or tostring(res) end
    S.font = Render.LoadFont("Arial", 0, 500)
    log("info", "ringmaster_eul_combo loaded", { menu_ready = ready, error = g_menu_error, cursor = CURSOR_HERO ~= nil, latency = AVG_LATENCY ~= nil })
end

function script.OnUpdate()
    if not ready or not ui.enabled:Get() or not Engine.IsInGame() then return end
    local ok, err = pcall(update)
    if not ok then
        reset("error")
        if S.error == nil then log("error", "update failed", { error = tostring(err) }) end
        S.error = tostring(err)
    end
end

function script.OnGameEnd()
    reset("game end")
    S.error = nil
end

local function draw_error_banner()
    local title = g_menu_error and localization.Get("panel.menu_failed") or "Ringmaster Eul Combo"
    local msg = g_menu_error or S.error
    Render.FilledRect(Vec2(20, 400), Vec2(760, 446), Color(20, 20, 24, 235), 4)
    Render.Text(S.font, 14, title, Vec2(30, 406), Color(224, 50, 45, 245))
    Render.Text(S.font, 12, msg:sub(1, 150), Vec2(30, 426), Color(220, 220, 225, 240))
end

function script.OnDraw()
    if g_menu_error ~= nil or S.error ~= nil then pcall(draw_error_banner) end
end

return script
