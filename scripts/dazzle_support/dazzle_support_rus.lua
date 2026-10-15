---@diagnostic disable: undefined-global
--==========================================================
--  Dazzle Party Support Script v4.1 — English Edition
--  Umbrella Platform
--  Auto-support for Dazzle: Grave, Shadow Wave, and items
--==========================================================

local HERO_NAME = "npc_dota_hero_dazzle"

-- ─── Ability names ───────────────────────────────────────
local AB_GRAVE  = "dazzle_shallow_grave"
local AB_WAVE   = "dazzle_shadow_wave"   -- W (Shadow Wave) — bouncing heal
local AB_WAVE2  = "dazzle_mending_salve" -- older version fallback
local AB_WAVE3  = "dazzle_lesser_heal"   -- even older fallback

-- ─── Item names ──────────────────────────────────────────
local IT_LOTUS   = "item_lotus_orb"
local IT_GLIMMER = "item_glimmer_cape"
local IT_EUL     = "item_cyclone"
local IT_PIPE    = "item_pipe"
local IT_URN     = "item_urn_of_shadows"
local IT_VESSEL  = "item_spirit_vessel"
local IT_MEKANS  = "item_mekansm"
local IT_GUARD   = "item_guardian_greaves"

-- ─── Internal cast delay (prevents ability spam) ─────────
local CAST_DELAY = 0.40

local myHero   = nil
local lastCast = {}
local prevHP   = {}

-- ─────────────────────────────────────────────────────────
--  MENU
--  Structure: Menu.Create → tab → tab:Create("group") → items
-- ─────────────────────────────────────────────────────────
local ui = {}
do
    -- Main tab: Heroes > Hero List > Dazzle > Dazzle Support RUS
    local tab = Menu.Create("Heroes", "Hero List", "Dazzle", "Dazzle Support RUS")

    -- ── General ──────────────────────────────────────────
    local gMain = tab:Create("General")
    ui.enable = gMain:Switch("Enable Script", true)
    ui.debug  = gMain:Switch("Debug Logs", false)

    -- ── E — Shallow Grave ────────────────────────────────
    local gGrave = tab:Create("E - Shallow Grave")
    ui.autoGrave   = gGrave:Switch("Auto Grave (E)", true)
    ui.graveHP     = gGrave:Slider("Grave HP порог (%)", 5, 45, 20)
    ui.graveSelf   = gGrave:Switch("Cast on self too", true)
    ui.graveCombat = gGrave:Switch("Cast only in combat", false)

    -- ── W — Shadow Wave ──────────────────────────────────
    local gWave = tab:Create("W - Shadow Wave")
    ui.autoHeal   = gWave:Switch("Авто Shadow Wave (W)", true)
    ui.healHP     = gWave:Slider("Shadow Wave HP порог (%)", 10, 95, 60)
    ui.healSelf   = gWave:Switch("Применять на себя", true)
    ui.healCombat = gWave:Switch("Каст только в комбо", false)

    -- ── Items ─────────────────────────────────────────────
    local gItem = tab:Create("Items")
    ui.autoLotus   = gItem:Switch("Авто Lotus Orb", true)
    ui.lotusHP     = gItem:Slider("  Lotus HP порог (%)", 10, 70, 35)
    ui.autoGlimmer = gItem:Switch("Aвто Glimmer Cape", true)
    ui.glimmerHP   = gItem:Slider("  Glimmer HP порог (%)", 10, 70, 40)
    ui.autoEul     = gItem:Switch("Aвто Eul's Scepter", true)
    ui.eulHP       = gItem:Slider("  Eul HP порог (%)", 5, 40, 15)
    ui.autoPipe    = gItem:Switch("Авто Pipe of Insight", true)
    ui.pipeHP      = gItem:Slider("  Pipe HP порог (%)", 10, 70, 40)
    ui.pipeMin     = gItem:Slider("  Pipe мин. количество раненных союзников", 1, 5, 1)
    ui.autoUrn     = gItem:Switch("Auto Urn / Spirit Vessel", true)
    ui.urnHP       = gItem:Slider("  Urn HP порог (%)", 20, 90, 60)
    ui.autoMekans  = gItem:Switch("Auto Mekansm / Greaves", true)
    ui.mekansHP    = gItem:Slider("  Mekansm HP порог (%)", 10, 70, 50)
    ui.mekansMin   = gItem:Slider("  Mekansm мин. количество раненных союзников", 1, 5, 2)

    -- ── Visuals ───────────────────────────────────────────
    local gVis = tab:Create("Визуалы")
    ui.showPanel = gVis:Switch("Статус Панели", true)
    ui.showGrave = gVis:Switch("Кастовать Grave в радиусе круга", true)
    ui.showWave  = gVis:Switch("Shadow Wave Радиус Круга", false)
    ui.colCircle = gVis:ColorPicker("Цвет Круга", Color(80, 200, 255, 130))
end

-- ─────────────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────────────

local function Dbg(msg)
    if ui.debug:Get() then print("[DazzleRUS] " .. tostring(msg)) end
end

-- Returns all living, visible, non-illusion allies
local function GetAllies(includeSelf)
    local out = {}
    if not myHero then return out end
    local all = Heroes.GetAll()
    if not all then return out end
    for _, h in pairs(all) do
        if h
            and Entity.IsAlive(h)
            and not Entity.IsDormant(h)
            and not NPC.IsIllusion(h)
            and Entity.IsSameTeam(myHero, h)
        then
            if includeSelf or h ~= myHero then
                table.insert(out, h)
            end
        end
    end
    return out
end

-- HP percentage (0.0 – 1.0)
local function HPPct(unit)
    local mx = Entity.GetMaxHealth(unit)
    if mx <= 0 then return 1.0 end
    return Entity.GetHealth(unit) / mx
end

-- 2D distance between two entities
local function Dist2D(a, b)
    return (Entity.GetAbsOrigin(a) - Entity.GetAbsOrigin(b)):Length2D()
end

-- Returns an ability if it has a level and is castable right now
local function GetAb(name)
    if not myHero then return nil end
    local ab = NPC.GetAbility(myHero, name)
    if not ab then return nil end
    if Ability.GetLevel(ab) <= 0 then return nil end
    if not Ability.IsCastable(ab, NPC.GetMana(myHero)) then return nil end
    return ab
end

-- Returns an item if it exists in inventory and is castable
local function GetIt(name)
    if not myHero then return nil end
    local it = NPC.GetItem(myHero, name, true)
    if not it then return nil end
    if not Ability.IsCastable(it, NPC.GetMana(myHero)) then return nil end
    return it
end

-- Simple per-key cooldown guard
local function CdOk(key)
    return (GameRules.GetGameTime() - (lastCast[key] or 0)) >= CAST_DELAY
end
local function SetCd(key)
    lastCast[key] = GameRules.GetGameTime()
end

-- Effective cast range for abilities and items
local function AbRange(ab)
    return Ability.GetCastRange(ab) + NPC.GetCastRangeBonus(myHero) + 100
end
local function ItRange(it)
    local r = Ability.GetCastRange(it)
    return (r and r > 0) and (r + 100) or 750
end

-- Modifier checks
local function HasGrave(unit)
    return NPC.HasModifier(unit, "modifier_dazzle_shallow_grave")
end
local function HasGlimmer(unit)
    return NPC.HasModifier(unit, "modifier_glimmer_cape_glimmer")
end

-- Combat detection: is there a living enemy hero within 1400 units?
local function IsInCombat()
    if not myHero then return false end
    local enemies = Entity.GetHeroesInRadius(myHero, 1400, Enum.TeamType.TEAM_ENEMY, true)
    if not enemies then return false end
    for _, e in ipairs(enemies) do
        if Entity.IsAlive(e) and not Entity.IsDormant(e) then return true end
    end
    return false
end

-- HP drop detection (unit took damage this frame)
local function IsUnderAttack(unit)
    local idx  = Entity.GetIndex(unit)
    local hp   = Entity.GetHealth(unit)
    local prev = prevHP[idx]
    prevHP[idx] = hp
    return prev ~= nil and hp < prev
end

-- ─────────────────────────────────────────────────────────
--  E — SHALLOW GRAVE
--  Casts on the ally with the lowest HP% below threshold.
--  Skips allies who already have the Grave buff.
-- ─────────────────────────────────────────────────────────
local function AutoGrave()
    if not ui.autoGrave:Get() then return end
    if not CdOk("grave") then return end
    if ui.graveCombat:Get() and not IsInCombat() then return end

    local ab = GetAb(AB_GRAVE)
    if not ab then return end

    local range      = AbRange(ab)
    local thresh     = ui.graveHP:Get() * 0.01
    local best, lowestPct = nil, thresh

    for _, ally in ipairs(GetAllies(ui.graveSelf:Get())) do
        if not HasGrave(ally) then
            local pct = HPPct(ally)
            if pct < lowestPct and Dist2D(myHero, ally) <= range then
                lowestPct = pct
                best      = ally
            end
        end
    end

    if best then
        Ability.CastTarget(ab, best)
        SetCd("grave")
        Dbg(string.format("GRAVE -> %s  HP=%.0f%%", NPC.GetUnitName(best), HPPct(best) * 100))
    end
end

-- ─────────────────────────────────────────────────────────
--  W — SHADOW WAVE
--  Targets the ally with the lowest raw HP below threshold.
--  Shadow Wave bounces automatically to nearby teammates.
-- ─────────────────────────────────────────────────────────
local function AutoWave()
    if not ui.autoHeal:Get() then return end
    if not CdOk("heal") then return end
    if ui.healCombat:Get() and not IsInCombat() then return end

    local ab = GetAb(AB_WAVE) or GetAb(AB_WAVE2) or GetAb(AB_WAVE3)
    if not ab then return end

    local range      = AbRange(ab)
    local thresh     = ui.healHP:Get() * 0.01
    local best, lowestHP = nil, math.huge

    for _, ally in ipairs(GetAllies(ui.healSelf:Get())) do
        local pct = HPPct(ally)
        local hp  = Entity.GetHealth(ally)
        if pct < thresh and hp < lowestHP and Dist2D(myHero, ally) <= range then
            lowestHP = hp
            best     = ally
        end
    end

    if best then
        Ability.CastTarget(ab, best)
        SetCd("heal")
        Dbg(string.format("SHADOW WAVE -> %s  HP=%.0f%%", NPC.GetUnitName(best), HPPct(best) * 100))
    end
end

-- ─────────────────────────────────────────────────────────
--  LOTUS ORB — dispel + spell reflect
-- ─────────────────────────────────────────────────────────
local function AutoLotus()
    if not ui.autoLotus:Get() then return end
    if not CdOk("lotus") then return end
    local it = GetIt(IT_LOTUS)
    if not it then return end
    local range  = ItRange(it)
    local thresh = ui.lotusHP:Get() * 0.01
    local best, lowestHP = nil, math.huge
    for _, ally in ipairs(GetAllies(true)) do
        local pct = HPPct(ally)
        local hp  = Entity.GetHealth(ally)
        if pct < thresh and hp < lowestHP and Dist2D(myHero, ally) <= range then
            lowestHP = hp
            best     = ally
        end
    end
    if best then
        Ability.CastTarget(it, best)
        SetCd("lotus")
        Dbg("LOTUS -> " .. NPC.GetUnitName(best))
    end
end

-- ─────────────────────────────────────────────────────────
--  GLIMMER CAPE — invisibility + magic resistance
--  Triggers when an ally is actively taking damage OR
--  drops below the configured HP threshold.
-- ─────────────────────────────────────────────────────────
local function AutoGlimmer()
    if not ui.autoGlimmer:Get() then return end
    if not CdOk("glimmer") then return end
    local it = GetIt(IT_GLIMMER)
    if not it then return end
    local range  = ItRange(it)
    local thresh = ui.glimmerHP:Get() * 0.01
    local best, lowestHP = nil, math.huge
    for _, ally in ipairs(GetAllies(true)) do
        if not HasGlimmer(ally) then
            local pct    = HPPct(ally)
            local hp     = Entity.GetHealth(ally)
            local danger = IsUnderAttack(ally) or (pct < thresh)
            if danger and hp < lowestHP and Dist2D(myHero, ally) <= range then
                lowestHP = hp
                best     = ally
            end
        end
    end
    if best then
        Ability.CastTarget(it, best)
        SetCd("glimmer")
        Dbg("GLIMMER -> " .. NPC.GetUnitName(best))
    end
end

-- ─────────────────────────────────────────────────────────
--  EUL'S SCEPTER — emergency cyclone
--  Buys time when an ally is critically low and has no Grave.
-- ─────────────────────────────────────────────────────────
local function AutoEul()
    if not ui.autoEul:Get() then return end
    if not CdOk("eul") then return end
    local it = GetIt(IT_EUL)
    if not it then return end
    local range  = ItRange(it)
    local thresh = ui.eulHP:Get() * 0.01
    local best, lowestPct = nil, thresh
    for _, ally in ipairs(GetAllies(true)) do
        if not HasGrave(ally) then
            local pct = HPPct(ally)
            if pct < lowestPct and Dist2D(myHero, ally) <= range then
                lowestPct = pct
                best      = ally
            end
        end
    end
    if best then
        Ability.CastTarget(it, best)
        SetCd("eul")
        Dbg("EUL -> " .. NPC.GetUnitName(best))
    end
end

-- ─────────────────────────────────────────────────────────
--  PIPE OF INSIGHT — AOE magic barrier
-- ─────────────────────────────────────────────────────────
local function AutoPipe()
    if not ui.autoPipe:Get() then return end
    if not CdOk("pipe") then return end
    local it = GetIt(IT_PIPE)
    if not it then return end
    local thresh = ui.pipeHP:Get() * 0.01
    local count  = 0
    for _, ally in ipairs(GetAllies(true)) do
        if Dist2D(myHero, ally) <= 1200 and HPPct(ally) < thresh then
            count = count + 1
        end
    end
    if count >= ui.pipeMin:Get() then
        Ability.CastNoTarget(it)
        SetCd("pipe")
        Dbg("PIPE активировать — раненных союзников: " .. count)
    end
end

-- ─────────────────────────────────────────────────────────
--  URN OF SHADOWS / SPIRIT VESSEL
-- ─────────────────────────────────────────────────────────
local function AutoUrn()
    if not ui.autoUrn:Get() then return end
    if not CdOk("urn") then return end
    local it = GetIt(IT_VESSEL) or GetIt(IT_URN)
    if not it then return end
    local range  = ItRange(it)
    local thresh = ui.urnHP:Get() * 0.01
    local best, lowestHP = nil, math.huge
    for _, ally in ipairs(GetAllies(true)) do
        local pct = HPPct(ally)
        local hp  = Entity.GetHealth(ally)
        if pct < thresh and hp < lowestHP and Dist2D(myHero, ally) <= range then
            lowestHP = hp
            best     = ally
        end
    end
    if best then
        Ability.CastTarget(it, best)
        SetCd("urn")
        Dbg("URN/VESSEL -> " .. NPC.GetUnitName(best))
    end
end

-- ─────────────────────────────────────────────────────────
--  MEKANSM / GUARDIAN GREAVES — AOE heal
-- ─────────────────────────────────────────────────────────
local function AutoMekans()
    if not ui.autoMekans:Get() then return end
    if not CdOk("mekans") then return end
    local it = GetIt(IT_GUARD) or GetIt(IT_MEKANS)
    if not it then return end
    local thresh = ui.mekansHP:Get() * 0.01
    local count  = 0
    for _, ally in ipairs(GetAllies(true)) do
        if Dist2D(myHero, ally) <= 1200 and HPPct(ally) < thresh then
            count = count + 1
        end
    end
    if count >= ui.mekansMin:Get() then
        Ability.CastNoTarget(it)
        SetCd("mekans")
        Dbg("MEKANSM/GREAVES активироать — раненных союзников: " .. count)
    end
end

-- ─────────────────────────────────────────────────────────
--  DRAW
-- ─────────────────────────────────────────────────────────
local function DrawCircle(center, radius, col, segs)
    segs = segs or 60
    local step = (2 * math.pi) / segs
    local pts  = {}
    for i = 0, segs - 1 do
        local a  = i * step
        local wp = Vector(
            center.x + radius * math.cos(a),
            center.y + radius * math.sin(a),
            center.z)
        local sp, ok = Render.WorldToScreen(wp)
        pts[i + 1] = ok and sp or nil
    end
    for i = 1, segs do
        local a = pts[i]
        local b = pts[(i % segs) + 1]
        if a and b then Render.Line(a, b, col) end
    end
end

local function OnDraw()
    if not ui.enable:Get() then return end
    if not myHero or not Entity.IsAlive(myHero) then return end

    local pos = Entity.GetAbsOrigin(myHero)
    local col = ui.colCircle:Get()

    -- Grave cast range circle
    if ui.showGrave:Get() then
        local ab = NPC.GetAbility(myHero, AB_GRAVE)
        if ab and Ability.GetLevel(ab) > 0 then
            DrawCircle(pos, Ability.GetCastRange(ab) + NPC.GetCastRangeBonus(myHero), col, 60)
        end
    end

    -- Shadow Wave range circle
    if ui.showWave:Get() then
        local ab = NPC.GetAbility(myHero, AB_WAVE) or NPC.GetAbility(myHero, AB_WAVE2)
        if ab and Ability.GetLevel(ab) > 0 then
            DrawCircle(pos, Ability.GetCastRange(ab) + NPC.GetCastRangeBonus(myHero),
                       Color(100, 255, 120, 100), 60)
        end
    end

    if not ui.showPanel:Get() then return end
    if not Render.GetScreenSize then return end

    local sw, sh = Render.GetScreenSize()
    local px, py = 12, math.floor(sh * 0.34)
    local lines  = {}

    -- Header + combat state
    local inCombat = IsInCombat()
    table.insert(lines, { txt = "=== Dazzle Support ===",
                          col = Color(120, 210, 255, 255) })
    table.insert(lines, { txt = inCombat and "[ В КОМБО ]" or "[ Calm ]",
                          col = inCombat and Color(255, 90, 90, 255) or Color(90, 220, 90, 255) })

    -- Ability cooldown lines
    local function AbLine(label, n1, n2)
        local ab = NPC.GetAbility(myHero, n1) or (n2 and NPC.GetAbility(myHero, n2))
        if not ab or Ability.GetLevel(ab) <= 0 then return end
        local cd  = Ability.GetCooldownTimeRemaining(ab)
        local txt = cd > 0 and string.format("%s: %.1fs", label, cd) or label .. ": ГОТОВ"
        table.insert(lines, { txt = txt, col = cd > 0 and Color(220,90,90,255) or Color(90,230,90,255) })
    end

    -- Item cooldown lines
    local function ItLine(label, name)
        local it = NPC.GetItem(myHero, name, true)
        if not it then return end
        local cd  = Ability.GetCooldownTimeRemaining(it)
        local txt = cd > 0 and string.format("%s: %.1fs", label, cd) or label .. ": ГОТОВ"
        table.insert(lines, { txt = txt, col = cd > 0 and Color(210,160,50,255) or Color(90,230,90,255) })
    end

    AbLine("E Grave",  AB_GRAVE)
    AbLine("W Wave",   AB_WAVE, AB_WAVE2)
    ItLine("Lotus",    IT_LOTUS)
    ItLine("Glimmer",  IT_GLIMMER)
    ItLine("Eul",      IT_EUL)
    ItLine("Pipe",     IT_PIPE)
    ItLine("Vessel",   IT_VESSEL)
    ItLine("Urn",      IT_URN)
    ItLine("Greaves",  IT_GUARD)
    ItLine("Mekansm",  IT_MEKANS)

    -- Live party HP bars
    table.insert(lines, { txt = "----- Party HP ------", col = Color(160, 160, 160, 200) })
    for _, ally in ipairs(GetAllies(true)) do
        local pct   = HPPct(ally)
        local short = (NPC.GetUnitName(ally):match("npc_dota_hero_(.+)") or "?"):sub(1, 12)
        local bars  = math.floor(pct * 10 + 0.5)
        local txt   = string.format("%-12s [%s%s] %3.0f%%",
                        short,
                        string.rep("|", bars),
                        string.rep(".", 10 - bars),
                        pct * 100)
        local r = math.floor((1 - pct) * 220)
        local g = math.floor(pct * 200)
        table.insert(lines, { txt = txt, col = Color(r, g, 60, 255) })
    end

    -- Render panel background and text
    local lh = 17
    local pw = 250
    local ph = #lines * lh + 10
    Render.FilledRect(Vec2(px - 4, py - 5), Vec2(pw, ph), Color(0, 0, 0, 170))
    Render.Rect(Vec2(px - 4, py - 5), Vec2(pw, ph), Color(120, 210, 255, 70))
    for i, line in ipairs(lines) do
        Render.Text(line.txt, Vec2(px, py + (i - 1) * lh), line.col, Enum.FontCreate.FONTFLAG_ANTIALIAS)
    end
end

-- ─────────────────────────────────────────────────────────
--  ON UPDATE
-- ─────────────────────────────────────────────────────────
local function OnUpdate()
    if not ui.enable:Get() then return end
    if not Engine.IsInGame() then return end

    if not myHero then myHero = Heroes.GetLocal() end
    if not myHero or not Entity.IsAlive(myHero) then return end
    if NPC.GetUnitName(myHero) ~= HERO_NAME then return end

    -- Priority order: life-saving first, utility second, healing last
    AutoGrave()     -- 1. immortality
    AutoEul()       -- 2. emergency cyclone
    AutoLotus()     -- 3. dispel + reflect
    AutoGlimmer()   -- 4. damage mitigation
    AutoPipe()      -- 5. AOE magic shield
    AutoMekans()    -- 6. AOE heal
    AutoWave()      -- 7. Shadow Wave heal
    AutoUrn()       -- 8. secondary heal
end

-- ─────────────────────────────────────────────────────────
return {
    OnUpdate = OnUpdate,
    OnDraw   = OnDraw,
}
