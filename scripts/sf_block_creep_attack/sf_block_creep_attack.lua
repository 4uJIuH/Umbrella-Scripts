---@diagnostic disable: undefined-global, lowercase-global
-- Block Creep Attacks During Feast — v1.2
-- Blocks right-click attack orders on creeps while Shadow Fiend's Feast of Souls
-- collection buff is active.

local script = {}
local menu_root = Menu.Create("Heroes", "Hero List", "Shadow Fiend", "Feast of Souls Abuse")
local general = menu_root:Create("Block Creep Attacks During Feast")
local ui = {}

ui.enabled = general:Switch("Enable", false)
ui.enabled:Icon("\u{f05e}")
ui.hero_block_radius = general:Slider("Block if enemy hero within", 0, 1600, 900)
ui.hero_block_radius:ToolTip("While Feast is active, block attacking creeps if an alive enemy hero is within this range.")
ui.hold_block_key = general:Bind("Hold to block creep attacks", Enum.ButtonCode.BUTTON_CODE_INVALID)
ui.hold_block_key:ToolTip("While Feast is active and this key is held down, creep attacks are blocked.")

local FEAST_COLLECTION_MODIFIER = "modifier_nevermore_feast_of_souls_collection"
local function is_shadow_fiend(hero)
    if not hero then return false end
    return NPC.GetUnitName(hero) == "npc_dota_hero_nevermore"
end
local function is_feast_active(hero)
    if not hero then return false end
    return NPC.HasModifier(hero, FEAST_COLLECTION_MODIFIER)
end
local function d2(a, b)
    return (a - b):Length2D()
end
local function enemy_hero_nearby(hero, radius)
    if radius <= 0 then return false end
    local hero_pos = Entity.GetAbsOrigin(hero)
    local my_team = Entity.GetTeamNum(hero)
    for _, enemy in pairs(Heroes.GetAll()) do
        if enemy and enemy ~= hero
            and Entity.IsAlive(enemy)
            and not Entity.IsDormant(enemy)
            and Entity.GetTeamNum(enemy) ~= my_team then
            local enemy_pos = Entity.GetAbsOrigin(enemy)
            if d2(enemy_pos, hero_pos) <= radius then
                return true
            end
        end
    end
    return false
end
function script.OnPrepareUnitOrders(order)
    if not ui.enabled:Get() then return end
    if order.order ~= Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET then return end
    if not order.target then return end
    if not NPC.IsCreep(order.target) then return end
    local hero = Heroes.GetLocal()
    if not hero or not is_shadow_fiend(hero) then return end
    if not is_feast_active(hero) then return end

    local auto_block = enemy_hero_nearby(hero, ui.hero_block_radius:Get() or 0)
    local manual_block = ui.hold_block_key:IsPressed()
    if auto_block or manual_block then
        return false
    end
end
return script
