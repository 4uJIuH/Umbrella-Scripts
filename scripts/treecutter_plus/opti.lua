
local script = {}

local menu = Menu.Create("Scripts", "Utility", "TreeCutter+")
local page = menu:Create("Main")
local group = page:Create("Настройки", Enum.GroupSide.FullWidth)

local ui = {}
ui.enable          = group:Switch("Включить скрипт", true, "\u{f1bb}")
ui.use_key         = group:Switch("Только по зажатой клавише", false, "\u{f11c}")
ui.key             = group:Bind("Клавиша шортката", Enum.ButtonCode.BUTTON_CODE_INVALID)
ui.corridor        = group:Slider("Ширина коридора пути", 45, 90, 68, "%d")
ui.max_search_dist = group:Slider("Макс. дистанция шортката", 400, 1500, 1000, "%d")
ui.quelling        = group:Switch("Quelling Blade", true, "panorama/images/items/quelling_blade_png.vtex_c")
ui.bfury           = group:Switch("Battle Fury", true, "panorama/images/items/bfury_png.vtex_c")

ui.use_key:SetCallback(function()
    ui.key:Disabled(not ui.use_key:Get())
end, true)

local CHOP_ITEMS = {
    { name = "item_quelling_blade", switch = function() return ui.quelling:Get() end },
    { name = "item_bfury",          switch = function() return ui.bfury:Get() end },
}

local active_shortcut = nil 
local is_internal_order = false 

local function X(v) return v and (v.x or (v.GetX and v:GetX()) or 0) or 0 end
local function Y(v) return v and (v.y or (v.GetY and v:GetY()) or 0) or 0 end
local function Z(v) return v and (v.z or (v.GetZ and v:GetZ()) or 0) or 0 end

local function Distance2D(a, b)
    local dx = X(a) - X(b)
    local dy = Y(a) - Y(b)
    return math.sqrt(dx * dx + dy * dy)
end

local function IsKeyActive()
    if not ui.use_key:Get() then return true end
    local key = ui.key:Get()
    if key == Enum.ButtonCode.BUTTON_CODE_INVALID then return false end
    return ui.key:IsDown()
end

local function GetPerpDistanceAndT(tree_pos, hero_pos, dest_pos)
    local hx, hy = X(hero_pos), Y(hero_pos)
    local dx, dy = X(dest_pos), Y(dest_pos)
    local tx, ty = X(tree_pos), Y(tree_pos)

    local line_x = dx - hx
    local line_y = dy - hy
    local line_len_sq = line_x * line_x + line_y * line_y

    if line_len_sq < 1 then return 999999, -1 end

    local t = ((tx - hx) * line_x + (ty - hy) * line_y) / line_len_sq
    if t <= 0 or t > 1.0 then return 999999, t end

    local proj_x = hx + t * line_x
    local proj_y = hy + t * line_y
    local diff_x = tx - proj_x
    local diff_y = ty - proj_y

    return math.sqrt(diff_x * diff_x + diff_y * diff_y), t
end

local function IsValidShortcutPassage(tree, tree_pos, dir_x, dir_y, all_trees, hero_pos, dest_pos)
    if math.abs(Z(tree_pos) - Z(dest_pos)) > 120 then
        return false
    end
    if math.abs(Z(hero_pos) - Z(tree_pos)) > 140 then
        return false
    end

    local nearby_count = 0
    for i = 1, #all_trees do
        local other = all_trees[i]
        if other ~= tree and Tree.IsActive(other) then
            local o_pos = Entity.GetAbsOrigin(other)
            if Distance2D(o_pos, tree_pos) < 135 then
                nearby_count = nearby_count + 1
            end
        end
    end
    if nearby_count >= 2 then
        return false
    end

    local probe_distances = { 80, 140 }
    for _, p_dist in ipairs(probe_distances) do
        local exit_x = X(tree_pos) + dir_x * p_dist
        local exit_y = Y(tree_pos) + dir_y * p_dist
        local exit_pos = Vector(exit_x, exit_y, Z(tree_pos))

        for i = 1, #all_trees do
            local other = all_trees[i]
            if other ~= tree and Tree.IsActive(other) then
                local o_pos = Entity.GetAbsOrigin(other)
                if Distance2D(o_pos, exit_pos) < 80 then
                    return false
                end
            end
        end
    end

    return true
end

local function get_chop_item(hero)
    local mana = NPC.GetMana(hero)
    for i = 1, #CHOP_ITEMS do
        local entry = CHOP_ITEMS[i]
        if entry.switch() then
            local item = NPC.GetItem(hero, entry.name, true)
            if item and Ability.IsReady(item) and Ability.IsCastable(item, mana) then
                return item
            end
        end
    end
    return nil
end

local function FindShortcutTree(hero, hero_pos, dest_pos, item)
    local total_dist = Distance2D(hero_pos, dest_pos)
    if total_dist < 220 then return nil end

    local search_dist = math.min(total_dist, ui.max_search_dist:Get())
    local dir_x = (X(dest_pos) - X(hero_pos)) / total_dist
    local dir_y = (Y(dest_pos) - Y(hero_pos)) / total_dist

    local trees = Entity.GetTreesInRadius(hero, search_dist, true)
    local best_tree = nil
    local best_tree_pos = nil
    local min_t = 999999
    local corridor = ui.corridor:Get()

    for i = 1, #trees do
        local tree = trees[i]
        if Tree.IsActive(tree) then
            local t_pos = Entity.GetAbsOrigin(tree)
            local perp_dist, t = GetPerpDistanceAndT(t_pos, hero_pos, dest_pos)

            if perp_dist <= corridor and t < min_t then
                if IsValidShortcutPassage(tree, t_pos, dir_x, dir_y, trees, hero_pos, dest_pos) then
                    best_tree = tree
                    best_tree_pos = t_pos
                    min_t = t
                end
            end
        end
    end

    if best_tree then
        local approach_pos = Vector(X(best_tree_pos) - dir_x * 160, Y(best_tree_pos) - dir_y * 160, Z(hero_pos))
        local through_pos = Vector(X(best_tree_pos) + dir_x * 60, Y(best_tree_pos) + dir_y * 60, Z(best_tree_pos))

        return {
            tree = best_tree,
            tree_pos = best_tree_pos,
            approach = approach_pos,
            through = through_pos,
            final_dest = dest_pos
        }
    end

    return nil
end

function script.OnUpdate()
    if not ui.enable:Get() or not active_shortcut then return end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then 
        active_shortcut = nil
        return 
    end

    if not Tree.IsActive(active_shortcut.tree) then
        is_internal_order = true
        Player.PrepareUnitOrders(
            Players.GetLocal(),
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            active_shortcut.final_dest,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            hero,
            false, false, false, false
        )
        is_internal_order = false
        active_shortcut = nil
        return
    end

    local item = get_chop_item(hero)
    if not item then 
        active_shortcut = nil
        return 
    end

    local hero_pos = Entity.GetAbsOrigin(hero)
    local cast_range = Ability.GetCastRange(item) + 50
    local dist_to_tree = Distance2D(hero_pos, active_shortcut.tree_pos)

    if dist_to_tree <= cast_range then
        local my_player = Players.GetLocal()
        is_internal_order = true

        Player.PrepareUnitOrders(
            my_player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET_TREE,
            active_shortcut.tree,
            active_shortcut.tree_pos,
            item,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            hero,
            false, false, false, false
        )

        Player.PrepareUnitOrders(
            my_player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            active_shortcut.through,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            hero,
            true,
            false, false, false
        )

        Player.PrepareUnitOrders(
            my_player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            active_shortcut.final_dest,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            hero,
            true,
            false, false, false
        )

        is_internal_order = false
        active_shortcut = nil
    end
end

function script.OnPrepareUnitOrders(order)
    if not ui.enable:Get() or is_internal_order or not order then return end

    local o_type = order.order_type or order.type or order.order
    local o_pos = order.position or order.pos

    if o_type == Enum.UnitOrder.DOTA_UNIT_ORDER_STOP or o_type == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION then
        active_shortcut = nil
        return
    end

    if o_pos and (o_type == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION or o_type == 1) then
        if not IsKeyActive() then 
            active_shortcut = nil
            return 
        end

        local hero = Heroes.GetLocal()
        if not hero or not Entity.IsAlive(hero) then return end

        local item = get_chop_item(hero)
        if not item then 
            active_shortcut = nil
            return 
        end

        local hero_pos = Entity.GetAbsOrigin(hero)
        local shortcut = FindShortcutTree(hero, hero_pos, o_pos, item)

        if shortcut then
            active_shortcut = shortcut

            is_internal_order = true
            Player.PrepareUnitOrders(
                Players.GetLocal(),
                Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil,
                shortcut.approach,
                nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                hero,
                false, false, false, false
            )
            is_internal_order = false

            return false
        else
            active_shortcut = nil
        end
    end
end

local function DisableWaypoints()
    if Engine and Engine.ExecuteCommand then
        Engine.ExecuteCommand("dota_unit_show_waypoints 0")
    end
end

function script.OnGameRulesStateChange(data)
    if data.new_state == Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME then
        DisableWaypoints()
    end
end

function script.OnGameEnd()
    active_shortcut = nil
    is_internal_order = false
end

DisableWaypoints()

return script