local AlacrityPanel = {}

local WEX_ABILITY_NAME = "invoker_wex"
local EXORT_ABILITY_NAME = "invoker_exort"
local INVOKE_ABILITY_NAME = "invoker_invoke"
local ALACRITY_ABILITY_NAME = "invoker_alacrity"
local FORGE_SPIRIT_NAME = "npc_dota_invoker_forged_spirit"
local ALACRITY_CAST_RANGE = 650
local SEQUENCE_TIMEOUT = 5.0
local SLOT_CACHE_TTL = 0.25

local math_ceil, math_floor, math_max, math_min = math.ceil, math.floor, math.max, math.min

local PL = {
    ICON = 30,
    ICON_R = 5,
    CELL_GAP = 3,
    HEADER_H = 24,
    HEADER_PAD_X = 8,
    HDR_ICON = 14,
    HDR_CELL_W = 28,
    HDR_GAP = 18,
    TITLE_SIZE = 15,
    GRID_GAP = 2,
    BORDER_R = 5,
    MAX_COLS = 7,
    MIN_W = 205,
}
local DRAG_THRESHOLD_PX = 6

local function InitializeUI()
    local invokerSection = Menu.Find("Heroes", "Hero List", "Invoker")
    local alacrityTab

    if invokerSection and invokerSection.Create then
        alacrityTab = invokerSection:Create("Alacrity")
    end

    if not alacrityTab or not alacrityTab.Create then
        local tab = Menu.Create("Heroes", "Hero List", "Invoker")
        if tab and tab.Icon then
            tab:Icon("panorama/images/heroes/icons/npc_dota_hero_invoker_png.vtex_c")
        end
        alacrityTab = tab:Create("Alacrity")
    end

    local mainGroup = alacrityTab:Create("Main")
    local ui = {}
    ui.Enabled = mainGroup:Switch("Enable", true)
    ui.Bind = mainGroup:Bind("Alacrity Team", Enum.ButtonCode.KEY_NONE)
    ui.ShowPanel = mainGroup:Switch("Panel", true)
    ui.TargetAllies = mainGroup:Switch("Alacrity on allies", true)
    ui.TargetForge = mainGroup:Switch("Alacrity on Forge Spirit", true)
    ui.TargetSummons = mainGroup:Switch("Alacrity on summons (e.g. Dominator)", true)
    ui.Debug = mainGroup:Switch("Debug (console)", false)
    return ui
end

local UI = InitializeUI()
local s_enable = UI.Enabled
local s_bind = UI.Bind
local s_show_panel = UI.ShowPanel
local s_target_allies = UI.TargetAllies
local s_target_forge = UI.TargetForge
local s_target_summons = UI.TargetSummons
local s_debug = UI.Debug

local invoke_seq = {
    active = false,
    deadline = 0,
}
local enabled_slots = {}
local Res = {
    font = nil,
    fontSmall = nil,
    fontSource = nil,
    alacrityIcon = nil,
    slotImages = {},
    titleSize = nil,
    letterSizes = {},
    lastDrawError = nil,
}
local Panel = {
    x = 18,
    y = 400,
    dragging = false,
    dx = 0,
    dy = 0,
    isHovered = false,
    clickEaten = false,
    w = 0,
    h = 0,
    slotDragIndex = nil,
    slotDragKey = nil,
    slotDragStartX = 0,
    slotDragStartY = 0,
}
local slot_priority_order = {}
local SlotCache = {
    hero = nil,
    refresh_at = 0,
    slots = {},
}
local LayoutCache = {}
local PanelColors = {
    Header = Color(18, 18, 22, 180),
    HeaderDivider = Color(0, 0, 0, 65),
    Text = Color(175, 175, 175, 255),
    Accent = Color(175, 155, 93, 220),
    Slot = Color(5, 6, 9, 225),
    ImageFull = Color(255, 255, 255, 255),
    ImageDisabled = Color(165, 165, 165, 220),
    DisabledOverlay = Color(45, 45, 45, 178),
    DisabledBorder = Color(204, 51, 51, 255),
    Ready = Color(76, 204, 51, 255),
    Dim = Color(112, 118, 132, 185),
    Letter = Color(255, 255, 255, 255),
}

local function Clamp(v, lo, hi) return math_max(lo, math_min(hi, v)) end

local function GetSlotImage(slot)
    if not slot or not slot.unitName then return nil end

    local kind = slot.isHero and "hero:" or "unit:"
    local cache_key = kind .. slot.unitName
    if Res.slotImages[cache_key] == nil then
        local path
        if slot.isHero then
            path = "panorama/images/heroes/icons/" .. slot.unitName .. "_png.vtex_c"
        else
            path = "panorama/images/heroes/" .. slot.unitName .. "_png.vtex_c"
        end
        Res.slotImages[cache_key] = Render.LoadImage(path)
    end
    return Res.slotImages[cache_key]
end

local function slot_key(npc)
    if not npc then return nil end
    local idx = Entity.GetIndex(npc)
    if not idx then return nil end
    if NPC.IsHero(npc) then
        local pid = Hero.GetPlayerID(npc)
        return "h_" .. tostring(pid and pid >= 0 and pid or idx)
    end
    return "n_" .. tostring(idx)
end

local function is_slot_enabled(key)
    return key and enabled_slots[key] ~= false
end

local function toggle_slot(key)
    if key then enabled_slots[key] = not is_slot_enabled(key) end
end

local function build_panel_slots(my_hero)
    local slots = {}
    local my_team = Entity.GetTeamNum(my_hero)

    if s_target_allies:Get() then
        for _, hero in ipairs(Heroes.GetAll()) do
            if hero ~= my_hero and Entity.IsAlive(hero) and not NPC.IsIllusion(hero)
                and Entity.GetTeamNum(hero) == my_team then
                local name = NPC.GetUnitName(hero)
                slots[#slots + 1] = {
                    npc = hero, key = slot_key(hero), unitName = name, isHero = true, label = "Ally"
                }
            end
        end
    end

    if s_target_forge:Get() or s_target_summons:Get() then
        local player_id = Hero.GetPlayerID(my_hero)
        if player_id == nil then player_id = -1 end
        local all_npcs = NPCs.GetAll()
        if all_npcs then
            for _, npc in pairs(all_npcs) do
                local valid = npc and Entity.IsNPC(npc) and Entity.IsAlive(npc)
                    and not NPC.IsIllusion(npc) and not NPC.IsCourier(npc)
                if valid then
                    local owner = NPC.GetOwnerNPC(npc)
                    local is_ours = (owner == my_hero)
                        or (Entity.GetTeamNum(npc) == my_team
                            and NPC.IsControllableByPlayer(npc, player_id))
                    if is_ours then
                        local name = NPC.GetUnitName(npc)
                        if name == FORGE_SPIRIT_NAME then
                            if s_target_forge:Get() then
                                slots[#slots + 1] = {
                                    npc = npc, key = slot_key(npc), unitName = name,
                                    isHero = false, label = "Forge"
                                }
                            end
                        elseif not NPC.IsHero(npc) and s_target_summons:Get() then
                            slots[#slots + 1] = {
                                npc = npc, key = slot_key(npc), unitName = name,
                                isHero = false, label = "Summon"
                            }
                        end
                    end
                end
            end
        end
    end

    return slots
end

local function invalidate_slot_cache()
    SlotCache.hero = nil
    SlotCache.refresh_at = 0
    SlotCache.slots = {}
end

local function get_ordered_panel_slots(my_hero)
    local now = GameRules.GetGameTime()
    if SlotCache.hero == my_hero and now < SlotCache.refresh_at then
        return SlotCache.slots
    end

    local raw = build_panel_slots(my_hero)
    local used = {}
    local ordered = {}
    for _, key in ipairs(slot_priority_order) do
        for _, slot in ipairs(raw) do
            if slot.key == key and not used[slot.key] then
                ordered[#ordered + 1] = slot
                used[slot.key] = true
                break
            end
        end
    end
    for _, slot in ipairs(raw) do
        if not used[slot.key] then
            ordered[#ordered + 1] = slot
        end
    end

    SlotCache.hero = my_hero
    SlotCache.refresh_at = now + SLOT_CACHE_TTL
    SlotCache.slots = ordered
    return ordered
end

local function get_alacrity_targets(my_hero)
    local list = {}
    local slots = get_ordered_panel_slots(my_hero)
    for _, slot in ipairs(slots) do
        if slot.npc and slot.key and is_slot_enabled(slot.key) and Entity.IsAlive(slot.npc) then
            list[#list + 1] = slot.npc
        end
    end
    return list
end

local INVOKED_SLOTS = { 3, 4 }
local function get_alacrity_ability(hero)
    for _, idx in ipairs(INVOKED_SLOTS) do
        local ab = NPC.GetAbilityByIndex(hero, idx)
        if ab and Ability.GetName(ab) == ALACRITY_ABILITY_NAME then return ab end
    end
    return nil
end

local function reset_invoke_sequence(reason)
    if reason and s_debug and s_debug:Get() then
        print("[Alacrity] sequence stopped: " .. reason)
    end
    invoke_seq.active = false
    invoke_seq.deadline = 0
end

local function is_castable(my_hero, ability)
    return my_hero ~= nil and ability ~= nil
        and Ability.IsCastable(ability, NPC.GetMana(my_hero))
end

local function cast_alacrity_on_target(my_hero, alacrity_ability, target)
    if not my_hero or not alacrity_ability or not target then return false end
    if not Entity.IsAlive(target) or not is_castable(my_hero, alacrity_ability) then return false end

    if s_debug and s_debug:Get() then
        local canEx = Ability.CanBeExecuted and Ability.CanBeExecuted(alacrity_ability) or "n/a"
        print(string.format("[Alacrity] cast on %s | CanBeExecuted=%s", NPC.GetUnitName(target) or "?", tostring(canEx)))
    end

    Ability.CastTarget(alacrity_ability, target)
    return true
end

local function find_first_target_in_range(my_hero, cast_range)
    cast_range = cast_range or ALACRITY_CAST_RANGE
    local my_pos = Entity.GetAbsOrigin(my_hero)
    if not my_pos then return nil end
    local targets = get_alacrity_targets(my_hero)
    for _, npc in ipairs(targets) do
        if npc and Entity.IsAlive(npc) then
            local pos = Entity.GetAbsOrigin(npc)
            if pos and my_pos:Distance2D(pos) <= cast_range then
                return npc
            end
        end
    end
    return nil
end

local function find_alacrity_target(my_hero, alacrity_ability)
    if not is_castable(my_hero, alacrity_ability) then return nil end
    local cast_range = Ability.GetCastRange(alacrity_ability)
    if not cast_range or cast_range <= 0 then cast_range = ALACRITY_CAST_RANGE end
    return find_first_target_in_range(my_hero, cast_range)
end

local function try_start_alacrity_or_invoke(my_hero)
    local now = GameRules.GetGameTime()
    local alacrity_ability = get_alacrity_ability(my_hero)
    if alacrity_ability then
        if not is_castable(my_hero, alacrity_ability) then return false end
        local target = find_alacrity_target(my_hero, alacrity_ability)
        if target then
            return cast_alacrity_on_target(my_hero, alacrity_ability, target)
        end
        return false
    end


    if not find_first_target_in_range(my_hero, ALACRITY_CAST_RANGE) then return false end

    local wex = NPC.GetAbility(my_hero, WEX_ABILITY_NAME)
    local exort = NPC.GetAbility(my_hero, EXORT_ABILITY_NAME)
    local inv = NPC.GetAbility(my_hero, INVOKE_ABILITY_NAME)
    if not wex or not exort or not inv
        or Ability.GetLevel(wex) == 0
        or Ability.GetLevel(exort) == 0
        or Ability.GetLevel(inv) == 0 then
        return false
    end

    local mana = NPC.GetMana(my_hero)
    if not Ability.IsCastable(wex, mana)
        or not Ability.IsCastable(exort, mana)
        or not Ability.IsCastable(inv, mana) then
        return false
    end

    Ability.CastNoTarget(wex, false)
    Ability.CastNoTarget(wex, true)
    Ability.CastNoTarget(exort, true)
    Ability.CastNoTarget(inv, true)
    if s_debug and s_debug:Get() then
        print("[Alacrity] queued recipe: Wex, Wex, Exort, Invoke")
    end

    invoke_seq.active = true
    invoke_seq.deadline = now + SEQUENCE_TIMEOUT
    return true
end

local function run_invoke_step(my_hero)
    if not invoke_seq.active then return end
    if not Entity.IsAlive(my_hero) then
        reset_invoke_sequence("hero is not alive")
        return
    end

    local now = GameRules.GetGameTime()
    if now >= invoke_seq.deadline then
        if s_debug and s_debug:Get() then
            local names = {}
            for idx = 0, 6 do
                local ability = NPC.GetAbilityByIndex(my_hero, idx)
                names[#names + 1] = tostring(idx) .. "="
                    .. (ability and (Ability.GetName(ability) or "?") or "nil")
            end
            print("[Alacrity] ability slots: " .. table.concat(names, ", "))
        end
        reset_invoke_sequence("timeout")
        return
    end

    local alacrity_ability = get_alacrity_ability(my_hero)
    if not is_castable(my_hero, alacrity_ability) then return end

    local target = find_alacrity_target(my_hero, alacrity_ability)
    if not target then return end

    if cast_alacrity_on_target(my_hero, alacrity_ability, target) then
        reset_invoke_sequence()
    end
end

local function is_valid_font(font)
    return (type(font) == "number" and font ~= 0) or type(font) == "userdata"
end

local function resolve_panel_font()

    local candidates = {
        { "MuseoSansEx", 550 },
        { "Tahoma", 500 },
        { "Arial", 500 },
    }
    for _, candidate in ipairs(candidates) do
        local font = Render.LoadFont(candidate[1], Enum.FontCreate.FONTFLAG_ANTIALIAS, candidate[2])
        if is_valid_font(font) then
            local ok, size = pcall(Render.TextSize, font, PL.TITLE_SIZE, "Alacrity")
            if ok and size and size.x and size.y then
                return font, candidate[1] .. " " .. tostring(candidate[2])
            end
        end
    end
    return 0, "unavailable"
end

local function ensure_resources()
    if not Res.font or Res.font == 0 then
        Res.font, Res.fontSource = resolve_panel_font()
    end
    if not Res.fontSmall or Res.fontSmall == 0 then
        Res.fontSmall = Res.font
    end
    if not Res.alacrityIcon or Res.alacrityIcon == 0 then
        Res.alacrityIcon = Render.LoadImage("panorama/images/spellicons/invoker_alacrity_png.vtex_c")
    end
    if Res.font and Res.font ~= 0 and not Res.titleSize then
        Res.titleSize = Render.TextSize(Res.font, PL.TITLE_SIZE, "Alacrity")
    end
    if Res.fontSmall and Res.fontSmall ~= 0 and not Res.letterSizes.F then
        Res.letterSizes.F = Render.TextSize(Res.fontSmall, 10, "F")
        Res.letterSizes.S = Render.TextSize(Res.fontSmall, 10, "S")
        Res.letterSizes["?"] = Render.TextSize(Res.fontSmall, 10, "?")
    end
end

local function panel_layout(slot_count)
    local cached = LayoutCache[slot_count]
    if cached then return cached end

    local cols = math_min(math_max(slot_count, 1), PL.MAX_COLS)
    local rows = math_max(1, math_ceil(slot_count / cols))
    local grid_w = cols * PL.ICON + math_max(0, cols - 1) * PL.CELL_GAP
    local grid_h = rows * PL.ICON + math_max(0, rows - 1) * PL.CELL_GAP
    local panel_w = math_max(PL.MIN_W, grid_w)

    cached = {
        cols = cols,
        rows = rows,
        gridW = grid_w,
        gridH = grid_h,
        panelW = panel_w,
        panelH = PL.HEADER_H + PL.GRID_GAP + grid_h,
    }
    LayoutCache[slot_count] = cached
    return cached
end

local function slot_rect(index, slot_count, layout, x0, y0)
    local row = math_floor((index - 1) / layout.cols)
    local col = (index - 1) % layout.cols
    local items_in_row = math_min(layout.cols, slot_count - row * layout.cols)
    local row_w = items_in_row * PL.ICON + math_max(0, items_in_row - 1) * PL.CELL_GAP
    local row_x = x0 + math_floor((layout.panelW - row_w) / 2)
    local grid_y = y0 + PL.HEADER_H + PL.GRID_GAP

    return row_x + col * (PL.ICON + PL.CELL_GAP), grid_y + row * (PL.ICON + PL.CELL_GAP)
end

local function draw_panel(my_hero)
    ensure_resources()
    local slots = get_ordered_panel_slots(my_hero)
    local nSlots = #slots
    if nSlots == 0 then
        Panel.w = 0
        Panel.h = 0
        Panel.isHovered = false
        return
    end

    local layout = panel_layout(nSlots)
    local panelW = layout.panelW
    local panelH = layout.panelH

    Panel.w = panelW
    Panel.h = panelH
    local scr = Render.ScreenSize()
    Panel.x = Clamp(Panel.x, 0, math_max(0, scr.x - panelW))
    Panel.y = Clamp(Panel.y, 0, math_max(0, scr.y - panelH))

    local x0 = math_floor(Panel.x)
    local y0 = math_floor(Panel.y)
    local x1 = x0 + panelW

    Render.FilledRect(Vec2(x0, y0), Vec2(x1, y0 + PL.HEADER_H),
        PanelColors.Header, PL.BORDER_R, Enum.DrawFlags.RoundCornersAll)
    Render.Line(Vec2(x0 + PL.HDR_CELL_W, y0 + 1),
        Vec2(x0 + PL.HDR_CELL_W, y0 + PL.HEADER_H - 1), PanelColors.HeaderDivider, 1)

    local hdrX = x0 + PL.HEADER_PAD_X
    local iconY = y0 + math_floor((PL.HEADER_H - PL.HDR_ICON) / 2)
    if Res.alacrityIcon and Res.alacrityIcon ~= 0 then
        Render.Image(Res.alacrityIcon, Vec2(hdrX, iconY), Vec2(PL.HDR_ICON, PL.HDR_ICON),
            PanelColors.ImageFull, 3, Enum.DrawFlags.RoundCornersAll)
    end
    local txtX = hdrX + PL.HDR_ICON + PL.HDR_GAP
    local txtH = (Res.titleSize and Res.titleSize.y) or PL.TITLE_SIZE
    local txtY = y0 + math_floor((PL.HEADER_H - txtH) / 2)
    if Res.font and Res.font ~= 0 then
        Render.Text(Res.font, PL.TITLE_SIZE, "Alacrity", Vec2(txtX, txtY), PanelColors.Text)
    end

    for i, slot in ipairs(slots) do
        local ix, iy = slot_rect(i, nSlots, layout, x0, y0)
        local enabled = is_slot_enabled(slot.key)

        local img = GetSlotImage(slot)
        Render.FilledRect(Vec2(ix, iy), Vec2(ix + PL.ICON, iy + PL.ICON),
            PanelColors.Slot, PL.ICON_R, Enum.DrawFlags.RoundCornersAll)

        if img and img ~= 0 then
            local image_color = enabled and PanelColors.ImageFull or PanelColors.ImageDisabled
            Render.Image(img, Vec2(ix, iy), Vec2(PL.ICON, PL.ICON),
                image_color, PL.ICON_R, Enum.DrawFlags.RoundCornersAll)
        else
            local boxCol = enabled and PanelColors.Accent or PanelColors.Dim
            Render.FilledRect(Vec2(ix, iy), Vec2(ix + PL.ICON, iy + PL.ICON), boxCol, PL.ICON_R, Enum.DrawFlags.RoundCornersAll)
            if Res.fontSmall and Res.fontSmall ~= 0 then
                local short = slot.label == "Forge" and "F" or (slot.label == "Summon" and "S" or "?")
                local ss = Res.letterSizes[short]
                local sx = ix + math_floor((PL.ICON - (ss and ss.x or 0)) / 2)
                local sy = iy + math_floor((PL.ICON - (ss and ss.y or 10)) / 2)
                Render.Text(Res.fontSmall, 10, short, Vec2(sx, sy), PanelColors.Letter)
            end
        end

        if not enabled then
            Render.FilledRect(Vec2(ix, iy), Vec2(ix + PL.ICON, iy + PL.ICON),
                PanelColors.DisabledOverlay, PL.ICON_R, Enum.DrawFlags.RoundCornersAll)
        end

        if enabled then
            Render.Rect(Vec2(ix, iy), Vec2(ix + PL.ICON, iy + PL.ICON),
                PanelColors.Ready, PL.ICON_R, Enum.DrawFlags.RoundCornersAll, 1)
        else
            Render.Rect(Vec2(ix, iy), Vec2(ix + PL.ICON, iy + PL.ICON),
                PanelColors.DisabledBorder, PL.ICON_R, Enum.DrawFlags.RoundCornersAll, 1)
        end
    end
end

local function slot_index_at_cursor(cx, cy, slots, x0, y0, layout)
    if not slots or #slots == 0 then return nil end
    for i = 1, #slots do
        local ix, iy = slot_rect(i, #slots, layout, x0, y0)
        if cx >= ix and cx <= ix + PL.ICON and cy >= iy and cy <= iy + PL.ICON then
            return i
        end
    end
    return nil
end

local function handle_panel_input(my_hero)
    Panel.clickEaten = false
    Panel.isHovered = false
    if not s_show_panel:Get() or not s_enable:Get() then return end

    local slots = my_hero and get_ordered_panel_slots(my_hero) or {}
    if #slots == 0 then
        Panel.w = 0
        Panel.h = 0
        return
    end

    local layout = panel_layout(#slots)
    Panel.w = layout.panelW
    Panel.h = layout.panelH
    local cx, cy = Input.GetCursorPos()
    local x0, y0 = Panel.x, Panel.y
    local x1, y1 = x0 + Panel.w, y0 + Panel.h
    Panel.isHovered = cx >= x0 and cx <= x1 and cy >= y0 and cy <= y1

    if Panel.slotDragIndex and not Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
        local moved = (cx - Panel.slotDragStartX) ^ 2 + (cy - Panel.slotDragStartY) ^ 2 > DRAG_THRESHOLD_PX * DRAG_THRESHOLD_PX
        if moved and #slots > 0 then
            local dropIdx = slot_index_at_cursor(cx, cy, slots, x0, y0, layout)
            if dropIdx and Panel.slotDragKey then
                local keys = {}
                for _, s in ipairs(slots) do keys[#keys + 1] = s.key end
                table.remove(keys, Panel.slotDragIndex)
                table.insert(keys, dropIdx, Panel.slotDragKey)
                slot_priority_order = keys
                invalidate_slot_cache()
            end
        else
            if Panel.slotDragKey then toggle_slot(Panel.slotDragKey) end
        end
        Panel.slotDragIndex = nil
        Panel.slotDragKey = nil
        Panel.clickEaten = true
        return
    end

    if Panel.slotDragIndex and Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
        Panel.clickEaten = true
        return
    end

    local hdrBottom = y0 + PL.HEADER_H
    local onHeader = cx >= x0 and cx <= x1 and cy >= y0 and cy <= hdrBottom

    if onHeader and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) and not Panel.dragging then
        Panel.dragging = true
        Panel.dx = cx - x0
        Panel.dy = cy - y0
        Panel.clickEaten = true
    end

    if Panel.dragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            Panel.x = cx - Panel.dx
            Panel.y = cy - Panel.dy
        else
            Panel.dragging = false
        end
        Panel.clickEaten = true
        return
    end

    if not Panel.isHovered or not Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then return end
    if not slots or #slots == 0 then return end

    for i, slot in ipairs(slots) do
        local ix, iy = slot_rect(i, #slots, layout, x0, y0)
        if cx >= ix and cx <= ix + PL.ICON and cy >= iy and cy <= iy + PL.ICON then
            Panel.slotDragIndex = i
            Panel.slotDragKey = slot.key
            Panel.slotDragStartX = cx
            Panel.slotDragStartY = cy
            Panel.clickEaten = true
            return
        end
    end
end

local function clear_panel_interaction()
    Panel.dragging = false
    Panel.slotDragIndex = nil
    Panel.slotDragKey = nil
    Panel.isHovered = false
    Panel.clickEaten = false
end

local function draw_panel_frame(my_hero)

    handle_panel_input(my_hero)
    draw_panel(my_hero)
end

function AlacrityPanel.OnUpdate()
    local my_hero = Heroes.GetLocal()
    if not my_hero or NPC.GetUnitName(my_hero) ~= "npc_dota_hero_invoker" or not Engine.IsInGame() then
        if invoke_seq.active then reset_invoke_sequence("game or hero unavailable") end
        return
    end
    if not s_enable:Get() then
        if invoke_seq.active then reset_invoke_sequence("disabled") end
        return
    end
    if invoke_seq.active then
        run_invoke_step(my_hero)
        return
    end

    local key1, key2 = s_bind:Buttons()
    if not key1 or key1 == Enum.ButtonCode.KEY_NONE then return end
    if key2 and key2 ~= Enum.ButtonCode.KEY_NONE and not Input.IsKeyDown(key2) then return end
    if not Input.IsKeyDownOnce(key1) then return end
    if not Entity.IsAlive(my_hero) then return end

    try_start_alacrity_or_invoke(my_hero)
end

function AlacrityPanel.OnDraw()
    if not s_enable:Get() or not s_show_panel:Get() then
        clear_panel_interaction()
        return
    end
    local my_hero = Heroes.GetLocal()
    if not my_hero or NPC.GetUnitName(my_hero) ~= "npc_dota_hero_invoker" or not Engine.IsInGame() then
        clear_panel_interaction()
        return
    end

    local ok, err = pcall(draw_panel_frame, my_hero)
    if not ok then
        clear_panel_interaction()
        if Res.lastDrawError ~= tostring(err) then
            Res.lastDrawError = tostring(err)
            print("[Alacrity] panel error: " .. Res.lastDrawError)
        end
        return
    end
    Res.lastDrawError = nil
end

function AlacrityPanel.OnPrepareUnitOrders(data)
    if Panel.clickEaten or Panel.dragging or Panel.slotDragIndex then
        return false
    end
    return true
end

function AlacrityPanel.OnNpcSpawned()
    invalidate_slot_cache()
end

function AlacrityPanel.OnEntityDestroy()
    invalidate_slot_cache()
end

function AlacrityPanel.OnGameEnd()
    reset_invoke_sequence()
    clear_panel_interaction()
    Panel.w = 0
    Panel.h = 0
    enabled_slots = {}
    slot_priority_order = {}
    invalidate_slot_cache()
    Res.slotImages = {}
    Res.lastDrawError = nil
end

return AlacrityPanel
