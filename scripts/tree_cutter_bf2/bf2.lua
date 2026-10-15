---@diagnostic disable: undefined-global
--[[
    Tree Cutter v1.0 | uc.zone API v2.0

    Автоматически рубит ближайшее дерево в заданном радиусе
    с помощью Quelling Blade или Battle Fury.

    Установка: положить файл в %cheat_dir%/scripts
    Меню: Scripts -> Main -> Tree Cutter
--]]

local script = {}

--#region UI
local group = Menu.Create("Scripts", "Main", "Tree Cutter", "Main", "Tree Cutter")

local ui = {}
ui.enable      = group:Switch("Enable", false, "\u{f1bb}")
ui.only_key    = group:Switch("Only on hotkey", false, "\u{f11c}")
ui.key         = group:Bind("Hotkey", Enum.ButtonCode.BUTTON_CODE_INVALID)
ui.range       = group:Slider("Range", 0, 1200, 30, "%d")
ui.limit_cast  = group:Switch("Clamp to cast range", false)
ui.limit_cast:ToolTip("Не даёт герою идти к дереву: радиус поиска обрезается по каст-ренжу предмета")
ui.quelling    = group:Switch("Quelling Blade", true, "panorama/images/items/quelling_blade_png.vtex_c")
ui.bfury       = group:Switch("Battle Fury", true, "panorama/images/items/bfury_png.vtex_c")
ui.delay       = group:Slider("Order delay", 0.05, 1.0, 0.2, "%.2f s")
ui.no_channel  = group:Switch("Don't interrupt channeling", true)

ui.enable:SetCallback(function()
    local off = not ui.enable:Get()
    ui.only_key:Disabled(off)
    ui.key:Disabled(off)
    ui.range:Disabled(off)
    ui.limit_cast:Disabled(off)
    ui.quelling:Disabled(off)
    ui.bfury:Disabled(off)
    ui.delay:Disabled(off)
    ui.no_channel:Disabled(off)
end, true)
--#endregion UI

--#region Vars
-- деревья, на которые уже отправлен ордер: [entity index] = время, до которого игнорим
local ordered_trees = {}
local next_order_time = 0.0

-- предметы, которыми умеем рубить, в порядке приоритета
local CHOP_ITEMS = {
    { name = "item_quelling_blade", switch = function() return ui.quelling:Get() end },
    { name = "item_bfury",          switch = function() return ui.bfury:Get() end },
}
--#endregion Vars

--#region Helpers
---Возвращает первый готовый к касту предмет для рубки
---@param hero CNPC
---@return CItem|nil
local function get_chop_item(hero)
    local mana = NPC.GetMana(hero)
    for i = 1, #CHOP_ITEMS do
        local entry = CHOP_ITEMS[i]
        if entry.switch() then
            -- isReal = true: только слоты 1-6, из бэкпака кастовать нельзя
            local item = NPC.GetItem(hero, entry.name, true)
            if item and Ability.IsReady(item) and Ability.IsCastable(item, mana) then
                return item
            end
        end
    end
    return nil
end

---Ближайшее живое дерево в радиусе
---@param hero CNPC
---@param radius number
---@param now number
---@return CTree|nil
local function get_nearest_tree(hero, radius, now)
    local hero_pos = Entity.GetAbsOrigin(hero)
    local trees = Entity.GetTreesInRadius(hero, radius, true)

    local best, best_dist = nil, math.huge
    for i = 1, #trees do
        local tree = trees[i]
        if Tree.IsActive(tree) then
            local index = Entity.GetIndex(tree)
            local ignore_until = ordered_trees[index]
            if not ignore_until or ignore_until < now then
                local dist = hero_pos:DistanceSqr2D(Entity.GetAbsOrigin(tree))
                if dist < best_dist then
                    best, best_dist = tree, dist
                end
            end
        end
    end
    return best
end

---Чистка списка уже заказанных деревьев
---@param now number
local function cleanup(now)
    for index, ignore_until in pairs(ordered_trees) do
        if ignore_until < now then
            ordered_trees[index] = nil
        end
    end
end

local function is_active()
    if not ui.enable:Get() then return false end
    if ui.only_key:Get() then
        return ui.key:Get() ~= Enum.ButtonCode.BUTTON_CODE_INVALID and ui.key:IsDown()
    end
    return true
end
--#endregion Helpers

--#region Logic
function script.OnUpdate()
    if not is_active() then return end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then return end

    local now = GameRules.GetGameTime()
    if now < next_order_time then return end

    cleanup(now)

    if NPC.IsStunned(hero) then return end
    if ui.no_channel:Get() and NPC.IsChannellingAbility(hero) then return end

    local item = get_chop_item(hero)
    if not item then return end

    local radius = ui.range:Get()
    if ui.limit_cast:Get() then
        local cast_range = Ability.GetCastRange(item)
        if cast_range > 0 and radius > cast_range then
            radius = cast_range
        end
    end
    if radius <= 0 then return end

    local tree = get_nearest_tree(hero, radius, now)
    if not tree then return end

    local delay = ui.delay:Get()

    Player.PrepareUnitOrders(
        Players.GetLocal(),                                      -- player
        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET_TREE,         -- type
        tree,                                                    -- target
        Entity.GetAbsOrigin(tree),                               -- pos
        item,                                                    -- ability
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        hero,                                                    -- issuer_npc
        false,                                                   -- queue
        false,                                                   -- show_effects
        false,                                                   -- callback
        false                                                    -- execute_fast
    )

    -- не спамим тем же деревом, пока сервер не подтвердит вырубку
    ordered_trees[Entity.GetIndex(tree)] = now + math.max(delay, 0.5)
    next_order_time = now + delay
end

function script.OnGameEnd()
    ordered_trees = {}
    next_order_time = 0.0
end
--#endregion Logic

return script