--by m0rc1

local VERSION = "1.0.0"
local GrimHelper = {}

-- ============================================================================
-- Menu Variables
-- ============================================================================
local ui_enabled            = nil
local ui_draw_panel         = nil

-- Ink Swell settings
local ui_ink_enabled        = nil
local ui_ink_mode           = nil
local ui_ink_max_dist       = nil
local ui_ink_self           = nil

-- Dark Portrait settings
local ui_dp_enabled         = nil
local ui_dp_target_mode     = nil
local ui_dp_heroes_only     = nil
local ui_dp_fallback        = nil

-- ============================================================================
-- State & Performance Cache
-- ============================================================================
local panel_active          = true
local last_ink_cast_time    = 0
local last_illu_orders      = {}
local allowed_allies        = {}

local cache = {
    last_ally_scan_t = 0,
    last_illu_scan_t = 0,
    allies = {},
    illusions = {},
    illu_target = nil,
    allowed_count = 0
}

-- ============================================================================
-- On-Screen Panel State & Animation
-- ============================================================================
local hud_panel = {
    x = 40,
    y = 160,
    w = 260,
    header_h = 24,
    collapsed = false,
    anim_progress = 1.0,
    dragging = false,
    drag_off = Vec2(0, 0),
    last_click = 0
}

-- Fonts
local font_main = nil
local font_bold = nil
local font_icon = nil

pcall(function()
    font_main = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    font_bold = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
    font_icon = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
end)

if not font_main then
    pcall(function()
        font_main = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
        font_bold = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
    end)
end

-- ============================================================================
-- Menu Setup (Heroes -> Hero List -> Grimstroke -> Helper)
-- ============================================================================
local function SetupMenu()
    if ui_enabled ~= nil then return end

    local function group(name)
        return Menu.Find("Heroes", "Hero List", "Grimstroke", "Helper", name)
            or Menu.Create("Heroes", "Hero List", "Grimstroke", "Helper", name)
            or Menu.Find("Heroes", "Hero List", "Grimstroke", name)
            or Menu.Create("Heroes", "Hero List", "Grimstroke", name)
    end

    local main_grp = group("Main Settings")
    if main_grp then
        ui_enabled      = main_grp:Switch("Enable Script", true)
        ui_draw_panel   = main_grp:Switch("Show Interactive Panel", true)
    end

    local ink_grp = group("Ink Swell (3rd Ability)")
    if ink_grp then
        ui_ink_enabled  = ink_grp:Switch("Auto-Cast Ink Swell", true)
        ui_ink_mode     = ink_grp:Combo("Target Selection Mode", { "Closest to Enemy", "Whitelist Only", "Closest from Whitelist" }, 2)
        ui_ink_max_dist = ink_grp:Slider("Max Ally-to-Enemy Distance", 300, 1000, 650)
        ui_ink_self     = ink_grp:Switch("Allow Self-Cast by Default", true)
    end

    local dp_grp = group("Dark Portrait (Aghanim's Illusion)")
    if dp_grp then
        ui_dp_enabled     = dp_grp:Switch("Auto-Control Illusion", true)
        ui_dp_target_mode = dp_grp:Combo("Target Priority", { "Lowest HP (Amount)", "Lowest HP (%)" }, 0)
        ui_dp_heroes_only = dp_grp:Switch("Attack Heroes Only", true)
        ui_dp_fallback    = dp_grp:Combo("If No Heroes in Vision", { "Follow Grimstroke", "Attack Nearest Enemies", "Hold Position" }, 0)
    end
end

-- ============================================================================
-- Helpers
-- ============================================================================
local function GetVal(item)
    if not item or not item.Get then return false end
    return item:Get()
end

local function GetThemeColor(name, fallback)
    if Menu and Menu.Style then
        local ok, col = pcall(Menu.Style, name)
        if ok and col and col.r then return col end
    end
    return fallback
end

local function GetAccentColor(alpha)
    local col = GetThemeColor("primary", Color(0, 255, 128, 255))
    return Color(col.r, col.g, col.b, alpha or 255)
end

local function IsGrimstroke(hero)
    if not hero or not Entity.IsAlive(hero) then return false end
    local name = NPC.GetUnitName(hero)
    return name and name == "npc_dota_hero_grimstroke"
end

local function IsAbilityReady(hero, ability)
    if not ability or not hero then return false end
    if Ability.GetLevel(ability) == 0 then return false end
    if Ability.GetCooldown(ability) > 0 then return false end

    local mana_cost = Ability.GetManaCost(ability) or 0
    if NPC.GetMana(hero) < mana_cost then return false end

    if Ability.CanBeExecuted then
        local res = Ability.CanBeExecuted(ability)
        return (res == -1 or res == 0 or res == true)
    end
    return true
end

local function IsHeroDisabled(hero)
    if not hero then return true end

    if NPC.IsStunned then
        local ok, s = pcall(NPC.IsStunned, hero)
        if ok and s then return true end
    end

    if NPC.IsSilenced then
        local ok, s = pcall(NPC.IsSilenced, hero)
        if ok and s then return true end
    end

    if NPC.HasModifier then
        if NPC.HasModifier(hero, "modifier_sheepstick_debuff") or
           NPC.HasModifier(hero, "modifier_lion_voodoo") or
           NPC.HasModifier(hero, "modifier_shadow_shaman_voodoo") or
           NPC.HasModifier(hero, "modifier_eul_cyclone") or
           NPC.HasModifier(hero, "modifier_stunned") or
           NPC.HasModifier(hero, "modifier_silence") then
            return true
        end
    end

    return false
end

local function IssueOrder(player, order_type, target, pos, ability, unit)
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
-- Performance Optimized Cache Updates
-- ============================================================================
local function UpdateThrottledData(my_hero)
    local now = GameRules.GetGameTime()

    -- 1. Allies & Distances Scan (every 0.15s)
    if now - cache.last_ally_scan_t >= 0.15 then
        cache.last_ally_scan_t = now

        local my_team = Entity.GetTeamNum(my_hero)
        local all_heroes = Heroes.GetAll() or {}

        local enemy_positions = {}
        for i = 1, #all_heroes do
            local h = all_heroes[i]
            if h and Entity.IsAlive(h) and not Entity.IsDormant(h) and Entity.GetTeamNum(h) ~= my_team then
                if not (NPC.IsIllusion and NPC.IsIllusion(h)) then
                    table.insert(enemy_positions, Entity.GetAbsOrigin(h))
                end
            end
        end

        local allies = {}
        local count_allowed = 0

        for i = 1, #all_heroes do
            local h = all_heroes[i]
            if h and Entity.IsAlive(h) and not Entity.IsDormant(h) and Entity.GetTeamNum(h) == my_team then
                if not (NPC.IsIllusion and NPC.IsIllusion(h)) then
                    local name = NPC.GetUnitName(h) or ""
                    if name ~= "" then
                        if allowed_allies[name] == nil then
                            if h == my_hero then
                                allowed_allies[name] = GetVal(ui_ink_self)
                            else
                                allowed_allies[name] = true
                            end
                        end

                        local is_allowed = allowed_allies[name]
                        if is_allowed then count_allowed = count_allowed + 1 end

                        local ally_pos = Entity.GetAbsOrigin(h)
                        local min_e_dist = math.huge

                        for k = 1, #enemy_positions do
                            local d = (enemy_positions[k] - ally_pos):Length2D()
                            if d < min_e_dist then min_e_dist = d end
                        end

                        local display = name:gsub("npc_dota_hero_", ""):gsub("_", " ")
                        display = display:sub(1, 1):upper() .. display:sub(2)
                        if h == my_hero then display = display .. " (You)" end

                        table.insert(allies, {
                            ent = h,
                            name = name,
                            display = display,
                            pos = ally_pos,
                            is_self = (h == my_hero),
                            enemy_dist = min_e_dist,
                            enabled = is_allowed
                        })
                    end
                end
            end
        end

        cache.allies = allies
        cache.allowed_count = count_allowed
    end

    -- 2. Dark Portrait Illusions Scan (every 0.25s)
    if now - cache.last_illu_scan_t >= 0.25 then
        cache.last_illu_scan_t = now

        local pid = Hero.GetPlayerID(my_hero)
        local my_team = Entity.GetTeamNum(my_hero)
        local npcs = NPCs.GetAll() or {}
        local list = {}

        for i = 1, #npcs do
            local u = npcs[i]
            if u and Entity.IsAlive(u) and not Entity.IsDormant(u) then
                if NPC.IsIllusion and NPC.IsIllusion(u) and NPC.IsControllableByPlayer(u, pid) and Entity.GetTeamNum(u) == my_team then
                    local is_not_grim = (NPC.GetUnitName(u) or "") ~= "npc_dota_hero_grimstroke"
                    local has_dp_mod  = NPC.HasModifier and NPC.HasModifier(u, "modifier_grimstroke_dark_portrait")
                    if has_dp_mod or is_not_grim then
                        table.insert(list, u)
                    end
                end
            end
        end

        cache.illusions = list
    end
end

-- ============================================================================
-- Ink Swell Logic
-- ============================================================================
local function ProcessInkSwell(my_hero, my_player)
    if not GetVal(ui_ink_enabled) then return end

    local now = GameRules.GetGameTime()
    if now - last_ink_cast_time < 0.22 then return end

    local ink_ability = NPC.GetAbility(my_hero, "grimstroke_spirit_walk")
    if not ink_ability or not IsAbilityReady(my_hero, ink_ability) then return end

    local cast_range = Ability.GetCastRange(ink_ability)
    if NPC.GetCastRangeBonus then
        cast_range = cast_range + (NPC.GetCastRangeBonus(my_hero) or 0)
    end

    local hero_pos = Entity.GetAbsOrigin(my_hero)
    local max_enemy_dist = GetVal(ui_ink_max_dist) or 650
    local mode = GetVal(ui_ink_mode) or 2

    local best_target = nil
    local best_enemy_dist = math.huge
    local allies = cache.allies

    for i = 1, #allies do
        local node = allies[i]
        local allowed = false

        if mode == 0 then
            allowed = true
        elseif mode == 1 or mode == 2 then
            allowed = node.enabled
        end

        if allowed then
            local dist_to_grim = (node.pos - hero_pos):Length2D()
            if dist_to_grim <= (cast_range + 80) then
                if mode == 1 then
                    if node.enemy_dist < best_enemy_dist then
                        best_enemy_dist = node.enemy_dist
                        best_target = node.ent
                    end
                else
                    if node.enemy_dist <= max_enemy_dist and node.enemy_dist < best_enemy_dist then
                        best_enemy_dist = node.enemy_dist
                        best_target = node.ent
                    end
                end
            end
        end
    end

    if best_target then
        IssueOrder(my_player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, best_target, nil, ink_ability, my_hero)
        last_ink_cast_time = now
    end
end

-- ============================================================================
-- Dark Portrait Logic
-- ============================================================================
local function GetBestTargetForIllusion(my_hero, illu_pos)
    local my_team = Entity.GetTeamNum(my_hero)
    local target_mode = GetVal(ui_dp_target_mode) or 0
    local heroes_only = GetVal(ui_dp_heroes_only)

    local visible_enemy_heroes = {}
    local all_heroes = Heroes.GetAll() or {}

    for i = 1, #all_heroes do
        local e = all_heroes[i]
        if e and Entity.IsAlive(e) and not Entity.IsDormant(e) and Entity.GetTeamNum(e) ~= my_team then
            if not (NPC.IsIllusion and NPC.IsIllusion(e)) then
                table.insert(visible_enemy_heroes, e)
            end
        end
    end

    if #visible_enemy_heroes > 0 then
        local best = nil
        local lowest_metric = math.huge

        for i = 1, #visible_enemy_heroes do
            local e = visible_enemy_heroes[i]
            local metric = Entity.GetHealth(e)
            if target_mode == 1 then
                metric = Entity.GetHealth(e) / Entity.GetMaxHealth(e)
            end

            if metric < lowest_metric then
                lowest_metric = metric
                best = e
            end
        end

        return best
    end

    if heroes_only then return nil end

    local enemies_near = NPCs.InRadius(illu_pos, 1100, my_team, Enum.TeamType.TEAM_ENEMY) or {}
    local closest, closest_dist = nil, math.huge

    for i = 1, #enemies_near do
        local n = enemies_near[i]
        if n and Entity.IsAlive(n) and not Entity.IsDormant(n) then
            local d = (Entity.GetAbsOrigin(n) - illu_pos):Length2D()
            if d < closest_dist then
                closest_dist = d
                closest = n
            end
        end
    end

    return closest
end

local function ProcessDarkPortrait(my_hero, my_player)
    if not GetVal(ui_dp_enabled) then return end

    local illusions = cache.illusions
    if #illusions == 0 then
        cache.illu_target = nil
        return
    end

    local now = GameRules.GetGameTime()
    local fallback_mode = GetVal(ui_dp_fallback) or 0

    for i = 1, #illusions do
        local illu = illusions[i]
        local idx = Entity.GetIndex(illu)
        local u_pos = Entity.GetAbsOrigin(illu)

        local order_data = last_illu_orders[idx] or { t = 0, target = nil, order = -1 }
        local target = GetBestTargetForIllusion(my_hero, u_pos)

        cache.illu_target = target

        if target then
            if (now - order_data.t >= 0.35) or (order_data.target ~= target) then
                IssueOrder(my_player, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, target, nil, nil, illu)
                last_illu_orders[idx] = { t = now, target = target, order = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET }
            end
        else
            if fallback_mode == 0 then
                local dist_to_hero = (Entity.GetAbsOrigin(my_hero) - u_pos):Length2D()
                if dist_to_hero > 350 and (now - order_data.t >= 0.40) then
                    IssueOrder(my_player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET, my_hero, nil, nil, illu)
                    last_illu_orders[idx] = { t = now, target = my_hero, order = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET }
                end
            elseif fallback_mode == 1 then
                if now - order_data.t >= 0.50 then
                    local forward_pos = u_pos + Vector(400, 0, 0)
                    IssueOrder(my_player, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE, nil, forward_pos, nil, illu)
                    last_illu_orders[idx] = { t = now, target = nil, order = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE }
                end
            end
        end
    end
end

-- ============================================================================
-- Main Logic Loop
-- ============================================================================
function GrimHelper.OnUpdate()
    SetupMenu()

    if not Engine.IsInGame() or not GetVal(ui_enabled) then return end

    local my_hero = Heroes.GetLocal()
    if not IsGrimstroke(my_hero) then return end

    local my_player = Players.GetLocal()
    if not my_player then return end

    UpdateThrottledData(my_hero)

    if not panel_active then return end

    if not IsHeroDisabled(my_hero) then
        ProcessInkSwell(my_hero, my_player)
    end

    ProcessDarkPortrait(my_hero, my_player)
end

-- ============================================================================
-- Interactive On-Screen Panel (Animated & High-Performance)
-- ============================================================================
local function HandlePanelMouse(allies)
    local cx, cy = Input.GetCursorPos()
    local p = hud_panel
    local is_lclick = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local now = os.clock()

    if p.dragging then
        if is_lclick then
            p.x = cx - p.drag_off.x
            p.y = cy - p.drag_off.y
        else
            p.dragging = false
        end
    else
        if is_lclick and (now - p.last_click > 0.20) then
            if cx >= p.x and cx <= p.x + p.w and cy >= p.y and cy <= p.y + p.header_h then
                if cx >= p.x + p.w - 38 and cx <= p.x + p.w - 14 then
                    panel_active = not panel_active
                    p.last_click = now
                    return
                elseif (cx >= p.x + p.w - 14 and cx <= p.x + p.w) or (cx >= p.x and cx <= p.x + 22) then
                    p.collapsed = not p.collapsed
                    p.last_click = now
                    return
                else
                    p.dragging = true
                    p.drag_off = Vec2(cx - p.x, cy - p.y)
                end
            end

            if p.anim_progress > 0.8 then
                local list_y = p.y + 42
                for i = 1, #allies do
                    local node = allies[i]
                    local row_y = list_y + (i - 1) * 24
                    if cx >= p.x + 8 and cx <= p.x + p.w - 8 and cy >= row_y and cy <= row_y + 22 then
                        allowed_allies[node.name] = not allowed_allies[node.name]
                        p.last_click = now
                        return
                    end
                end
            end
        end
    end
end

function GrimHelper.OnDraw()
    if not ui_draw_panel or not GetVal(ui_draw_panel) then return end
    if not Engine.IsInGame() or not GetVal(ui_enabled) then return end

    local my_hero = Heroes.GetLocal()
    if not IsGrimstroke(my_hero) then return end

    local p = hud_panel
    local allies = cache.allies

    HandlePanelMouse(allies)

    local dt = 0.016
    if GlobalVars and GlobalVars.GetAbsFrameTime then
        dt = GlobalVars.GetAbsFrameTime() or 0.016
    end

    local target_anim = p.collapsed and 0.0 or 1.0
    p.anim_progress = p.anim_progress + (target_anim - p.anim_progress) * math.min(1.0, dt * 12.0)
    local progress = p.anim_progress * p.anim_progress * (3 - 2 * p.anim_progress)

    local row_h = 24
    local content_h = 18 + (#allies * row_h) + 40
    local current_content_h = math.floor(content_h * progress)
    local total_h = p.header_h + (current_content_h > 2 and current_content_h or 0)

    local tl = Vec2(p.x, p.y)
    local br = Vec2(p.x + p.w, p.y + total_h)

    local accent   = GetAccentColor()
    local c_body   = Color(15, 17, 23, 195)
    local c_border = Color(255, 255, 255, 16)
    local c_plate  = Color(25, 28, 38, 160)
    local c_text   = Color(225, 230, 240, 230)
    local c_muted  = Color(140, 145, 160, 200)
    local c_green  = GetThemeColor("multiselect_item_selected", Color(63, 191, 95, 245))
    local c_red    = GetThemeColor("multiselect_item", Color(224, 50, 45, 245))

    local f_bold = font_bold or Render.LoadFont("Segoe UI", 12, Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
    local f_main = font_main or Render.LoadFont("Segoe UI", 11, Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)

    -- 1. Frosted Glass Body Background
    Render.Blur(tl, br, 2.0, 1.0, 7)
    Render.FilledRect(tl, br, c_body, 7)
    Render.Rect(tl, br, c_border, 7, Enum.DrawFlags.None, 1)

    -- 2. Header Bar
    if font_icon then
        Render.Text(font_icon, 11, "\u{f3c5}", Vec2(p.x + 9, p.y + 6), c_muted)
    else
        Render.FilledRect(Vec2(p.x + 9, p.y + 9), Vec2(p.x + 15, p.y + 15), c_muted, 2)
    end

    local title_str = "Grimstroke Helper"
    Render.Text(f_main, 12, title_str, Vec2(p.x + 68, p.y + 5), c_text)

    -- Miniature Switch Toggle
    local sw_x = p.x + p.w - 36
    local sw_y = p.y + 6
    local sw_bg = panel_active and accent or Color(40, 44, 54, 210)

    Render.FilledRect(Vec2(sw_x, sw_y), Vec2(sw_x + 22, sw_y + 12), sw_bg, 6)
    Render.Rect(Vec2(sw_x, sw_y), Vec2(sw_x + 22, sw_y + 12), Color(255, 255, 255, 20), 6, nil, 1)

    local thumb_x = panel_active and (sw_x + 16) or (sw_x + 6)
    if Render.FilledCircle then
        pcall(Render.FilledCircle, Vec2(thumb_x, sw_y + 6), 4, Color(245, 245, 250, 255))
    else
        Render.FilledRect(Vec2(thumb_x - 3, sw_y + 3), Vec2(thumb_x + 3, sw_y + 9), Color(245, 245, 250, 255), 2)
    end

    -- Chevron Glyph
    local chevron_glyph = p.collapsed and "\u{f078}" or "\u{f077}"
    if font_icon then
        Render.Text(font_icon, 9, chevron_glyph, Vec2(p.x + p.w - 11, p.y + 7), c_muted)
    end

    if progress <= 0.05 then return end

    Render.Line(Vec2(p.x + 8, p.y + p.header_h), Vec2(p.x + p.w - 8, p.y + p.header_h), Color(255, 255, 255, 12), 1)

    -- 3. Subheader: Count of allowed allies
    Render.FilledRect(Vec2(p.x + 10, p.y + 29), Vec2(p.x + 14, p.y + 34), accent, 2)
    Render.Text(f_bold, 11, "Ink Swell Targets", Vec2(p.x + 20, p.y + 26), c_text)

    local count_str = string.format("%d / %d", cache.allowed_count, #allies)
    Render.Text(f_main, 10, count_str, Vec2(p.x + p.w - 40, p.y + 27), c_muted)

    -- 4. Allied Heroes List
    local list_y = p.y + 42
    local cx, cy = Input.GetCursorPos()

    for i = 1, #allies do
        local node = allies[i]
        local row_y = list_y + (i - 1) * row_h

        local is_hover = (cx >= p.x + 8 and cx <= p.x + p.w - 8 and cy >= row_y and cy <= row_y + 22)
        local row_bg = is_hover and Color(40, 44, 58, 180) or c_plate

        Render.FilledRect(Vec2(p.x + 8, row_y), Vec2(p.x + p.w - 8, row_y + 21), row_bg, 4)
        Render.Rect(Vec2(p.x + 8, row_y), Vec2(p.x + p.w - 8, row_y + 21), Color(255, 255, 255, 10), 4, nil, 1)

        local node_col = node.enabled and c_green or c_red
        local pt_c = Vec2(p.x + 18, row_y + 10)

        if Render.FilledCircle then
            pcall(Render.FilledCircle, pt_c, 4.5, Color(16, 18, 24, 230))
            pcall(Render.Circle, pt_c, 4.5, node_col, 1.5)
            if node.enabled then
                pcall(Render.FilledCircle, pt_c, 2.0, Color(255, 255, 255, 255))
            end
        else
            Render.FilledRect(pt_c - Vec2(4, 4), pt_c + Vec2(4, 4), Color(16, 18, 24, 230), 3)
            Render.Rect(pt_c - Vec2(4, 4), pt_c + Vec2(4, 4), node_col, 3, nil, 1.2)
            if node.enabled then
                Render.FilledRect(pt_c - Vec2(1.5, 1.5), pt_c + Vec2(1.5, 1.5), Color(255, 255, 255, 255), 1)
            end
        end

        local txt_col = node.enabled and c_text or c_muted
        Render.Text(f_main, 11, node.display, Vec2(p.x + 28, row_y + 4), txt_col)

        local dist_str = "-"
        local dist_col = c_muted
        if node.enemy_dist < 3000 then
            dist_str = string.format("%.0f", node.enemy_dist)
            if node.enemy_dist <= (GetVal(ui_ink_max_dist) or 650) then
                dist_col = c_green
            end
        end
        Render.Text(f_main, 10, dist_str, Vec2(p.x + p.w - 38, row_y + 4), dist_col)
    end

    -- 5. Footer: Dark Portrait & Status
    local foot_y = list_y + (#allies * row_h) + 3
    Render.FilledRect(Vec2(p.x + 8, foot_y), Vec2(p.x + p.w - 8, foot_y + 35), c_plate, 5)
    Render.Rect(Vec2(p.x + 8, foot_y), Vec2(p.x + p.w - 8, foot_y + 35), Color(255, 255, 255, 10), 5, nil, 1)

    local illu_status = "Illusion: None"
    local illu_col = c_muted

    if not panel_active then
        illu_status = "Automation: PAUSED"
        illu_col = Color(255, 180, 0, 255)
    elseif #cache.illusions > 0 then
        if cache.illu_target then
            local t_name = NPC.GetUnitName(cache.illu_target):gsub("npc_dota_hero_", "")
            t_name = t_name:sub(1, 1):upper() .. t_name:sub(2)
            illu_status = string.format("Focus: %s (%.0f HP)", t_name, Entity.GetHealth(cache.illu_target))
            illu_col = accent
        else
            illu_status = "Illusion: Following"
            illu_col = Color(80, 180, 255, 255)
        end
    end

    Render.Text(f_bold, 10, "Dark Portrait", Vec2(p.x + 14, foot_y + 3), accent)
    Render.Text(f_main, 10, illu_status, Vec2(p.x + 14, foot_y + 18), illu_col)
end

-- ============================================================================
-- Initialization
-- ============================================================================
SetupMenu()

return GrimHelper