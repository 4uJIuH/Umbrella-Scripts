--by m0rc1

local VERSION = "1.0.0"
local VisageTpHelper = {}

-- ============================================================================
-- Menu Variables
-- ============================================================================
local ui_enabled            = nil
local ui_safe_hide          = nil
local ui_hide_duration      = nil
local ui_draw_hud           = nil

-- ============================================================================
-- States & Tracking
-- ============================================================================
local STATE_IDLE            = 0
local STATE_HIDING          = 1
local STATE_CASTING         = 2
local STATE_DONE            = 3

local current_state         = STATE_IDLE
local state_start_time      = 0
local tp_was_active         = false

-- Target safe spot per familiar: [entity_index] = Vector(x, y, z)
local familiar_destinations = {}

-- Fonts
local font_bold = nil
local font_main = nil

pcall(function()
    font_bold = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
    font_main = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
end)

if not font_bold then
    pcall(function()
        font_bold = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
        font_main = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
    end)
end

-- ============================================================================
-- Menu Setup (Heroes -> Hero List -> Visage -> Familiar TP Helper)
-- ============================================================================
local function SetupMenu()
    if ui_enabled ~= nil then return end

    local function group(name)
        return Menu.Find("Heroes", "Hero List", "Visage", "Familiar TP Helper", name)
            or Menu.Create("Heroes", "Hero List", "Visage", "Familiar TP Helper", name)
            or Menu.Find("Heroes", "Hero List", "Visage", name)
            or Menu.Create("Heroes", "Hero List", "Visage", name)
    end

    local main_grp = group("Авто-ТП Гаргулий (Recall)")
    if main_grp then
        ui_enabled          = main_grp:Switch("Включить синхронизацию ТП", true)
        ui_safe_hide        = main_grp:Switch("Уводить в глубь леса перед ТП", true)
        ui_hide_duration    = main_grp:Slider("Макс. время на отход в сейв-зону (сек)", 0.5, 3.0, 1.8, "%.1f s")
    end

    local vis_grp = group("Интерфейс")
    if vis_grp then
        ui_draw_hud         = vis_grp:Switch("Отображать статус и кулдаун", true)
    end
end

-- ============================================================================
-- Helpers & Interop
-- ============================================================================
local function GetVal(item)
    if not item or not item.Get then return false end
    return item:Get()
end

local function GetAccentColor(alpha)
    if Menu and Menu.Style then
        local ok, col = pcall(Menu.Style, "primary")
        if ok and col and col.r then
            return Color(col.r, col.g, col.b, alpha or 255)
        end
    end
    return Color(0, 200, 255, alpha or 255)
end

local function IsVisage(hero)
    if not hero or not Entity.IsAlive(hero) then return false end
    local name = NPC.GetUnitName(hero)
    return name and name == "npc_dota_hero_visage"
end

local function IssueUnitOrder(player, order_type, target, pos, ability, unit)
    if not player or not unit then return false end

    pcall(Player.PrepareUnitOrders,
        player,
        order_type,
        target,
        pos or Vector(0, 0, 0),
        ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        unit,
        false,
        false,
        false,
        true
    )
    return true
end

-- ============================================================================
-- Teleport Detection
-- ============================================================================
local function IsHeroTeleporting(my_hero)
    if not my_hero or not Entity.IsAlive(my_hero) then return false end

    if NPC.HasModifier and NPC.HasModifier(my_hero, "modifier_teleporting") then
        return true
    end

    local tp_slot = NPC.GetItemByIndex and NPC.GetItemByIndex(my_hero, 15)
    if tp_slot and Ability.IsChannelling and Ability.IsChannelling(tp_slot) then
        return true
    end

    for i = 0, 5 do
        local item = NPC.GetItemByIndex and NPC.GetItemByIndex(my_hero, i)
        if item then
            local name = Ability.GetName(item) or ""
            if (name:find("travel_boots") or name:find("tpscroll")) and Ability.IsChannelling and Ability.IsChannelling(item) then
                return true
            end
        end
    end

    return false
end

-- ============================================================================
-- Familiars Collector & Deep Forest Geometry
-- ============================================================================
local function CollectFamiliars(my_hero)
    local list = {}
    local pid = Hero.GetPlayerID(my_hero)
    local my_team = Entity.GetTeamNum(my_hero)
    local npcs = NPCs.GetAll() or {}

    for i = 1, #npcs do
        local n = npcs[i]
        if n and Entity.IsAlive(n) and not Entity.IsDormant(n) and Entity.GetTeamNum(n) == my_team then
            if NPC.IsControllableByPlayer and NPC.IsControllableByPlayer(n, pid) then
                local name = NPC.GetUnitName(n) or ""
                if name:find("visage_familiar") then
                    table.insert(list, n)
                end
            end
        end
    end

    return list
end

local function GetRecallAbility(familiar)
    if not familiar then return nil end

    local ab = NPC.GetAbility(familiar, "visage_summon_familiars_recall")
    if ab and Ability.GetLevel(ab) > 0 then
        return ab
    end

    local ab_fallback = NPC.GetAbilityByIndex and NPC.GetAbilityByIndex(familiar, 1)
    if ab_fallback and Ability.GetLevel(ab_fallback) > 0 then
        return ab_fallback
    end

    return nil
end

local function FindDeepForestSpot(familiar, my_hero)
    local f_pos = Entity.GetAbsOrigin(familiar)
    local my_team = Entity.GetTeamNum(my_hero)

    -- 1. Check nearby friendly tower (< 1300 range)
    local towers = Towers.GetAll() or {}
    local nearest_tower = nil
    local min_t_dist = 1300

    for i = 1, #towers do
        local t = towers[i]
        if t and Entity.IsAlive(t) and Entity.GetTeamNum(t) == my_team then
            local dist = (Entity.GetAbsOrigin(t) - f_pos):Length2D()
            if dist < min_t_dist then
                min_t_dist = dist
                nearest_tower = t
            end
        end
    end

    if nearest_tower then
        local t_pos = Entity.GetAbsOrigin(nearest_tower)
        local safe_offset = (t_pos - f_pos):Normalized() * 220
        return t_pos - safe_offset
    end

    -- 2. Find Dense Tree Cluster & Unpathable Woods Interior
    if Trees and Trees.InRadius then
        local nearby_trees = Trees.InRadius(f_pos, 1000)
        if nearby_trees and #nearby_trees >= 3 then
            local enemies = Heroes.InRadius(f_pos, 1500, my_team, Enum.TeamType.TEAM_ENEMY) or {}
            local best_spot = nil
            local best_score = -math.huge

            for i = 1, math.min(#nearby_trees, 30) do
                local tree = nearby_trees[i]
                if tree then
                    local t_pos = Entity.GetAbsOrigin(tree)
                    local dist = (t_pos - f_pos):Length2D()

                    -- Target trees within realistic flight range (150 - 750 units)
                    if dist >= 120 and dist <= 750 then
                        -- Check neighbor density around this tree
                        local neighbors = Trees.InRadius(t_pos, 280) or {}
                        local density = #neighbors

                        -- Must be at least 3 trees nearby to qualify as a cluster
                        if density >= 3 then
                            -- Calculate cluster centroid to place familiar right inside the wood pack
                            local sum_x, sum_y = t_pos.x, t_pos.y
                            local sample_count = math.min(density, 6)
                            for k = 1, sample_count do
                                local np = Entity.GetAbsOrigin(neighbors[k])
                                sum_x = sum_x + np.x
                                sum_y = sum_y + np.y
                            end

                            local cluster_center = Vector(sum_x / (sample_count + 1), sum_y / (sample_count + 1), t_pos.z)

                            -- Distance from nearest enemy
                            local min_enemy_d = 1600
                            for e_idx = 1, #enemies do
                                local ed = (cluster_center - Entity.GetAbsOrigin(enemies[e_idx])):Length2D()
                                if ed < min_enemy_d then min_enemy_d = ed end
                            end

                            -- Bonus for unpathable mesh (ground units cannot walk here)
                            local is_unpathable = false
                            if GridNav and GridNav.IsTraversable then
                                is_unpathable = not GridNav.IsTraversable(cluster_center)
                            end

                            local score = (density * 60) + (min_enemy_d * 0.4) - (dist * 0.25)
                            if is_unpathable then
                                score = score + 250
                            end

                            if score > best_score then
                                best_score = score
                                best_spot = cluster_center
                            end
                        end
                    end
                end
            end

            if best_spot then
                return best_spot
            end
        end
    end

    return f_pos
end

-- ============================================================================
-- Main Logic Loop
-- ============================================================================
function VisageTpHelper.OnUpdate()
    SetupMenu()

    if not Engine.IsInGame() or not GetVal(ui_enabled) then return end

    local my_hero = Heroes.GetLocal()
    if not IsVisage(my_hero) then
        current_state = STATE_IDLE
        tp_was_active = false
        familiar_destinations = {}
        return
    end

    local my_player = Players.GetLocal()
    if not my_player then return end

    local is_tping = IsHeroTeleporting(my_hero)
    local now = GameRules.GetGameTime()

    -- Reset when TP ends or is cancelled
    if not is_tping then
        current_state = STATE_IDLE
        tp_was_active = false
        familiar_destinations = {}
        return
    end

    local familiars = CollectFamiliars(my_hero)
    if #familiars == 0 then return end

    -- TP Began: Send Familiars deep into forest
    if is_tping and not tp_was_active then
        tp_was_active = true
        state_start_time = now
        familiar_destinations = {}

        if GetVal(ui_safe_hide) then
            for i = 1, #familiars do
                local fam = familiars[i]
                local fam_idx = Entity.GetIndex(fam)
                local safe_spot = FindDeepForestSpot(fam, my_hero)

                familiar_destinations[fam_idx] = safe_spot
                IssueUnitOrder(my_player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, safe_spot, nil, fam)
            end
            current_state = STATE_HIDING
        else
            current_state = STATE_CASTING
        end
    end

    -- Phase: Flying into deep cover with early arrival detection
    if current_state == STATE_HIDING then
        local max_hide_timeout = GetVal(ui_hide_duration) or 1.8
        local elapsed = now - state_start_time

        local all_arrived = true
        for i = 1, #familiars do
            local fam = familiars[i]
            local fam_idx = Entity.GetIndex(fam)
            local dest = familiar_destinations[fam_idx]

            if dest then
                local dist_to_spot = (Entity.GetAbsOrigin(fam) - dest):Length2D()
                if dist_to_spot > 80 then
                    all_arrived = false
                    break
                end
            end
        end

        -- Cast Recall early if arrived in cover, or when timeout expires
        if all_arrived or (elapsed >= max_hide_timeout) then
            current_state = STATE_CASTING
        end
    end

    -- Phase: Synchronized Recall Cast
    if current_state == STATE_CASTING then
        for i = 1, #familiars do
            local fam = familiars[i]
            local recall_ab = GetRecallAbility(fam)
            if recall_ab and Ability.GetCooldown(recall_ab) == 0 then
                IssueUnitOrder(my_player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, nil, recall_ab, fam)
            end
        end

        current_state = STATE_DONE
    end
end

-- ============================================================================
-- Visual Status & Live Cooldown Overlay
-- ============================================================================
function VisageTpHelper.OnDraw()
    if not ui_draw_hud or not GetVal(ui_draw_hud) then return end
    if not Engine.IsInGame() or not GetVal(ui_enabled) then return end

    local my_hero = Heroes.GetLocal()
    if not IsVisage(my_hero) then return end

    local familiars = CollectFamiliars(my_hero)
    if #familiars == 0 then return end

    local hero_pos = Entity.GetAbsOrigin(my_hero)
    local s_pos, vis = hero_pos:ToScreen()
    if not vis or not s_pos then return end

    local accent = GetAccentColor()
    local font_b = font_bold or Render.LoadFont("Segoe UI", 12, Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)

    -- Live Cooldown Scan across all active familiars
    local max_cd = 0
    local any_ready = false

    for i = 1, #familiars do
        local fam = familiars[i]
        local recall_ab = GetRecallAbility(fam)
        if recall_ab then
            local cd = Ability.GetCooldown(recall_ab) or 0
            if cd > max_cd then max_cd = cd end
            if cd == 0 then any_ready = true end
        end
    end

    local status_text = "RECALL: READY"
    local status_col  = accent

    if max_cd > 0 then
        status_text = string.format("RECALL CD: %.1fs", max_cd)
        status_col  = Color(255, 80, 80, 255)
    end

    if current_state == STATE_HIDING then
        local now = GameRules.GetGameTime()
        local max_t = GetVal(ui_hide_duration) or 1.8
        local remaining = math.max(0, max_t - (now - state_start_time))
        status_text = string.format("HIDING IN FOREST (%.1fs)", remaining)
        status_col  = Color(255, 200, 0, 255)
    elseif current_state == STATE_CASTING or current_state == STATE_DONE then
        status_text = "RECALL CHANNELING"
        status_col  = Color(0, 255, 128, 255)
    end

    local sz = Render.TextSize(font_b, 11, status_text)
    local p_start = s_pos + Vec2(-sz.x * 0.5 - 6, 32)
    local p_end   = s_pos + Vec2(sz.x * 0.5 + 6, 52)

    Render.FilledRect(p_start, p_end, Color(16, 18, 24, 210), 4)
    Render.Rect(p_start, p_end, status_col, 4, nil, 1)
    Render.Text(font_b, 11, status_text, p_start + Vec2(6, 3), Color(255, 255, 255, 255))
end

-- ============================================================================
-- Initialization
-- ============================================================================
SetupMenu()

return VisageTpHelper