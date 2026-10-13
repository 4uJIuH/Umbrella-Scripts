--[[
    ~ Spirit Breaker (Bara) Combo & Ghoul 1000-7 Script
    ~ Umbrella Dota 2
]]

local VERSION = "1.0.0"
local tab = Menu.Create("Scripts", "Spirit Breaker", "Settings", "Settings")
local group = tab:Create("Spirit Breaker")

local opt_enable        = group:Switch("Enable Script", true, "\u{f0e7}")
local opt_auto_bulldoze = group:Switch("Auto Bulldoze Before Impact", true, "\u{f0e7}")
local opt_auto_ult      = group:Switch("Auto Nether Strike After Charge", false, "\u{f0e7}")

local opt_pause         = group:Switch("Auto Pause On Impact", true, "\u{f04c}")
local opt_chat_ghoul    = group:Switch("1000-7 Chat Countdown", true, "\u{f075}")
local opt_ghoul_steps   = group:Slider("Countdown Steps", 1, 20, 8, "%d")
local opt_chat_delay    = group:Slider("Chat Delay", 2, 20, 5, function(v) return string.format("%.1f s", v * 0.1) end)
local opt_chat_all      = group:Switch("All Chat", true, "\u{f0ac}")

local opt_items_enable  = group:Switch("Auto Use Items", true, "\u{f0b2}")
local opt_vessel        = group:Switch("Urn & Spirit Vessel", true, "\u{f043}")
local opt_orchid        = group:Switch("Orchid & Bloodthorn", true, "\u{f0e7}")
local opt_hex           = group:Switch("Scythe of Vyse", true, "\u{f0e7}")
local opt_halberd       = group:Switch("Heaven's Halberd", true, "\u{f132}")
local opt_solar         = group:Switch("Solar Crest & Medallion", true, "\u{f185}")
local opt_shiva         = group:Switch("Shiva's Guard", true, "\u{f2dc}")
local opt_dagon         = group:Switch("Dagon", true, "\u{f0e7}")

local chat_queue = {}
local next_chat_time = 0
local was_charging = false
local charge_target = nil
local last_target_pos = nil
local has_collided = false
local collision_time = 0

local function exec(cmd)
    if not cmd or cmd == "" then return end

    if Engine and Engine.ExecuteCommand then
        Engine.ExecuteCommand(cmd)
    end

    if Engine and Engine.RunScript then
        local safe_cmd = cmd:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("'", "\\'")
        Engine.RunScript(string.format("try { GameInterfaceAPI.ConsoleCommand('%s'); } catch(e) {}", safe_cmd))
    end
end

local function dist2d(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function cast_target(my_hero, item_name, target, my_mana)
    local item = NPC.GetItem(my_hero, item_name)
    if item and Ability.IsCastable(item, my_mana) then
        Ability.CastTarget(item, target)
        return true
    end
    return false
end

local function cast_no_target(my_hero, item_name, my_mana)
    local item = NPC.GetItem(my_hero, item_name)
    if item and Ability.IsCastable(item, my_mana) then
        Ability.CastNoTarget(item)
        return true
    end
    return false
end

local function cast_bulldoze(my_hero, my_mana)
    local w = NPC.GetAbility(my_hero, "spirit_breaker_bulldoze")
    if w and Ability.IsCastable(w, my_mana) then
        Ability.CastNoTarget(w)
        return true
    end
    return false
end

local function cast_ult(my_hero, target, my_mana)
    local r = NPC.GetAbility(my_hero, "spirit_breaker_nether_strike")
    if r and Ability.IsCastable(r, my_mana) then
        Ability.CastTarget(r, target)
        return true
    end
    return false
end

local function cast_debuffs(my_hero, target, my_mana)
    if not target or not Entity.IsAlive(target) then return end

    if opt_hex:Get() then
        cast_target(my_hero, "item_sheepstick", target, my_mana)
    end

    if opt_orchid:Get() then
        if not cast_target(my_hero, "item_bloodthorn", target, my_mana) then
            cast_target(my_hero, "item_orchid", target, my_mana)
        end
    end

    if opt_vessel:Get() then
        if not cast_target(my_hero, "item_spirit_vessel", target, my_mana) then
            cast_target(my_hero, "item_urn_of_shadows", target, my_mana)
        end
    end

    if opt_halberd:Get() then
        cast_target(my_hero, "item_heavens_halberd", target, my_mana)
    end

    if opt_solar:Get() then
        if not cast_target(my_hero, "item_solar_crest", target, my_mana) then
            cast_target(my_hero, "item_medallion_of_courage", target, my_mana)
        end
    end

    if opt_shiva:Get() then
        cast_no_target(my_hero, "item_shivas_guard", my_mana)
    end

    if opt_dagon:Get() then
        for i = 5, 1, -1 do
            local dagon = i == 1 and "item_dagon" or ("item_dagon_" .. i)
            if cast_target(my_hero, dagon, target, my_mana) then
                break
            end
        end
    end
end

local function start_ghoul_countdown()
    chat_queue = {}
    local steps = opt_ghoul_steps:Get()
    local val = 1000
    for _ = 1, steps do
        local next_val = val - 7
        table.insert(chat_queue, string.format("%d - 7 = %d", val, next_val))
        val = next_val
    end
    next_chat_time = os.clock()
end

local function on_collision(my_hero, target, my_mana)
    if opt_items_enable:Get() then
        cast_debuffs(my_hero, target, my_mana)
    end

    if opt_auto_ult:Get() then
        cast_ult(my_hero, target, my_mana)
    end

    if opt_pause:Get() then
        exec("dota_pause")
    end

    if opt_chat_ghoul:Get() then
        start_ghoul_countdown()
    end
end

local function on_update()
    local now = os.clock()

    if #chat_queue > 0 and now >= next_chat_time then
        local msg = table.remove(chat_queue, 1)
        local chat_cmd = opt_chat_all:Get() and "say" or "say_team"
        exec(string.format('%s "%s"', chat_cmd, msg))
        local delay = opt_chat_delay:Get() * 0.1
        next_chat_time = now + delay
    end

    if not opt_enable:Get() then return end

    local my_hero = Heroes.GetLocal and Heroes.GetLocal()
    if not my_hero or not Entity.IsAlive(my_hero) then return end
    if NPC.GetUnitName(my_hero) ~= "npc_dota_hero_spirit_breaker" then return end

    local my_team = Entity.GetTeamNum(my_hero)
    local my_pos = Entity.GetAbsOrigin(my_hero)
    local my_mana = NPC.GetMana(my_hero)
    local is_charging = NPC.HasModifier(my_hero, "modifier_spirit_breaker_charge_of_darkness")

    if is_charging then
        local current_target = nil
        for _, enemy in ipairs(Heroes.GetAll()) do
            if enemy and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and Entity.GetTeamNum(enemy) ~= my_team then
                if NPC.HasModifier(enemy, "modifier_spirit_breaker_charge_of_darkness_vision") then
                    current_target = enemy
                    break
                end
            end
        end

        if current_target then
            charge_target = current_target
            last_target_pos = Entity.GetAbsOrigin(current_target)
        end

        if charge_target and Entity.IsAlive(charge_target) then
            local t_pos = Entity.GetAbsOrigin(charge_target)
            last_target_pos = t_pos
            local d = dist2d(my_pos, t_pos)

            if d < 650 and opt_auto_bulldoze:Get() then
                cast_bulldoze(my_hero, my_mana)
            end

            if d <= 200 and not has_collided then
                has_collided = true
                collision_time = now
                on_collision(my_hero, charge_target, my_mana)
            end
        end
    else
        if was_charging and not has_collided and charge_target and last_target_pos then
            local d = dist2d(my_pos, last_target_pos)
            if d <= 400 then
                has_collided = true
                collision_time = now
                on_collision(my_hero, charge_target, my_mana)
            end
        end

        if not is_charging and now - collision_time > 3.0 then
            has_collided = false
            charge_target = nil
            last_target_pos = nil
        end
    end

    was_charging = is_charging
end

if Callbacks and Callbacks.Register then
    Callbacks.Register("OnUpdate", on_update)
    Callbacks.Register("OnFrame", on_update)
end

return {
    OnUpdate = on_update,
    OnFrame = on_update,
}