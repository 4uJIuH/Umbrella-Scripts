---@diagnostic disable: undefined-global

-- ===========================================================================
--  Windranger Combo Script  |  Umbrella API v2.0
--
--  Features: Fast API Execution, Shackle Geometry, Visual Lock-On Indicator
-- ===========================================================================

-- Cache globals for faster per-frame access
local Menu, Players, Player, NPC, Entity, Ability  = Menu, Players, Player, NPC, Entity, Ability
local Heroes, NPCs, Trees, Input, GameRules, Enum  = Heroes, NPCs, Trees, Input, GameRules, Enum
local Render, math, string, pairs, ipairs          = Render, math, string, pairs, ipairs

local wr = {}

-- ===========================================================================
--  ICONS  (Panorama vtex paths & Unicode Fonts)
-- ===========================================================================
local ICO = {
    Script = "panorama/images/spellicons/windrunner_focusfire_png.vtex_c",
    Q      = "panorama/images/spellicons/windrunner_shackleshot_png.vtex_c",
    W      = "panorama/images/spellicons/windrunner_powershot_png.vtex_c",
    E      = "panorama/images/spellicons/windrunner_windrun_png.vtex_c",
    R      = "panorama/images/spellicons/windrunner_focusfire_png.vtex_c",
    Blink  = "panorama/images/items/blink_png.vtex_c",

    Tab    = "\u{f013}",
    Gear   = "\u{f013}",
    Eye    = "\u{f06e}",
    Key    = "\u{f084}",
}

-- ===========================================================================
--  UI
-- ===========================================================================
local tab = Menu.Create("Heroes", "Hero List", "Windranger", "Windranger Combo")
tab:Icon(ICO.Tab)

local grpMain  = tab:Create("Combo Settings")
local grpSpell = tab:Create("Ability Toggle",  1)
local grpShkl  = tab:Create("Shackle Options", 2)
local grpDraw  = tab:Create("Visuals",         3)

local UI = {
    Enabled        = grpMain:Switch("Enable Script",          true,  ICO.Script),
    ComboKey       = grpMain:Bind(  "Combo Key",              Enum.ButtonCode.KEY_NONE, ICO.Key),
    TargetRadius   = grpMain:Slider("Cursor Target Radius",   100, 1200, 400, "%d units"),
    UseBlink       = grpMain:Switch("Use Blink Dagger",       true,  ICO.Blink),

    UseQ           = grpSpell:Switch("Shackleshot (Q)",       true,  ICO.Q),
    UseR           = grpSpell:Switch("Focus Fire  (R)",       true,  ICO.R),
    UseW           = grpSpell:Switch("Powershot   (W)",       true,  ICO.W),
    UseE           = grpSpell:Switch("Windrun     (E)",       true,  ICO.E),

    AllowCreep     = grpShkl:Switch("Allow Shackle on Creeps",           false, ICO.Q),
    ChkLinkens     = grpShkl:Switch("Skip if Target has Linkens",        true,  ICO.Gear),

    DrawState      = grpDraw:Switch("Show Combo State HUD",              true,  ICO.Eye),
    DrawTarget     = grpDraw:Switch("Draw Target Indicator",             true,  ICO.Eye),
    DrawCone       = grpDraw:Switch("Show Shackle Cone (In Combo)",      false, ICO.Eye),
    AlwaysDrawCone = grpDraw:Switch("Always Show Cone (Hover)",          true,  ICO.Eye),
    ConeColor      = grpDraw:ColorPicker("Cone Color", Color(80,160,255,120),   ICO.Eye),
}

-- ===========================================================================
--  CONSTANTS
-- ===========================================================================
local SHACKLE_RADIUS = 575
local SHACKLE_COS    = 0.906
local SHACKLE_SPEED  = 1650
local BLINK_GAP      = 500
local BLINK_MAX      = 1150

-- ===========================================================================
--  STATE & VARIABLES
-- ===========================================================================
local hero         = nil
local player       = nil
local q_spell      = nil
local w_spell      = nil
local e_spell      = nil
local r_spell      = nil
local blink_item   = nil

local comboState   = 0
local target       = nil
local lastAct      = 0
local blinkArrival = nil

-- Visuals
local target_particle = nil
local particle_target_index = -1
local drawFont = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS)
local lockFont = Render.LoadFont("Arial", 0, 500)

-- HUD info per state
local STATE_INFO = {
    [1] = { txt = "\u{25cf} [Q] Shackleshot",  col = Color(80,  200, 255, 255) },
    [2] = { txt = "\u{25cf} [R] Focus Fire",   col = Color(255,  60,  60, 255) },
    [3] = { txt = "\u{25cf} [W] Powershot",    col = Color(255, 160,   0, 255) },
    [4] = { txt = "\u{25cf} [E] Windrun",      col = Color( 80, 255, 120, 255) },
    [5] = { txt = "\u{25cf} Auto-Attacking",   col = Color(255, 240,  80, 255) },
}

-- ===========================================================================
--  MATH HELPERS
-- ===========================================================================
local sqrt = math.sqrt

local function Dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return sqrt(dx*dx + dy*dy)
end

local function Flat(v)   return Vector(v.x, v.y, 0)  end

local function Norm2D(v)
    local len = sqrt(v.x*v.x + v.y*v.y)
    if len < 0.001 then return Vector(0,0,0) end
    return Vector(v.x/len, v.y/len, 0)
end

local function Dot2D(a, b)  return a.x*b.x + a.y*b.y  end

-- ===========================================================================
--  INIT / RESET
-- ===========================================================================
local function IsWR()
    hero   = Heroes.GetLocal()
    player = Players.GetLocal()
    return hero and player
        and Entity.IsAlive(hero)
        and NPC.GetUnitName(hero) == "npc_dota_hero_windrunner"
end

local function LoadSpells()
    q_spell    = NPC.GetAbility(hero, "windrunner_shackleshot")
    w_spell    = NPC.GetAbility(hero, "windrunner_powershot")
    e_spell    = NPC.GetAbility(hero, "windrunner_windrun")
    r_spell    = NPC.GetAbility(hero, "windrunner_focusfire")
    blink_item = nil
    for _, n in ipairs({"item_blink","item_swift_blink","item_arcane_blink","item_overwhelming_blink"}) do
        local it = NPC.GetItem(hero, n, true)
        if it then blink_item = it; break end
    end
end

local function ResetCombo()
    comboState   = 0
    target       = nil
    lastAct      = 0
    blinkArrival = nil

    if target_particle then
        Particle.Destroy(target_particle)
        target_particle = nil
        particle_target_index = -1
    end
end

local function CanCast(ab)
    if not ab then return false end
    return Ability.IsReady(ab) and Ability.IsCastable(ab, NPC.GetMana(hero))
end

local function GetAttackRange()
    return NPC.GetAttackRange(hero) + NPC.GetAttackRangeBonus(hero)
end

-- ===========================================================================
--  STRICT TARGET FILTERING
-- ===========================================================================
local function GetTarget()
    local t = Input.GetNearestHeroToCursor(Enum.TeamType.TEAM_ENEMY)

    if not t                 then return nil end
    if not Entity.IsAlive(t) then return nil end
    if not NPC.IsHero(t)     then return nil end
    if NPC.IsIllusion(t)     then return nil end

    -- Strict Team and Self Checks
    if hero and Entity.GetIndex(t) == Entity.GetIndex(hero) then return nil end
    if hero and Entity.IsSameTeam(hero, t) then return nil end

    if Dist2D(Input.GetWorldCursorPos(), Entity.GetAbsOrigin(t)) > UI.TargetRadius:Get() then
        return nil
    end

    return t
end

-- ===========================================================================
--  VISUAL INDICATOR SYSTEM
-- ===========================================================================
local function ManageTargetParticle()
    if not UI.DrawTarget:Get() or not UI.ComboKey:IsDown() or not target or not Entity.IsAlive(target) then
        if target_particle then
            Particle.Destroy(target_particle)
            target_particle = nil
            particle_target_index = -1
        end
        return
    end

    local current_idx = Entity.GetIndex(target)
    if particle_target_index ~= current_idx then
        if target_particle then Particle.Destroy(target_particle) end

        target_particle = Particle.Create("particles/ui_mouseactions/drag_selected_ring.vpcf", Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW, target)
        Particle.SetControlPoint(target_particle, 1, Vector(255, 50, 50))
        Particle.SetControlPoint(target_particle, 2, Vector(120, 255, 255))
        particle_target_index = current_idx
    end
end

-- ===========================================================================
--  MOTION PREDICTION
-- ===========================================================================
local function PredPos(unit, dt)
    local p = Flat(Entity.GetAbsOrigin(unit))
    if not NPC.IsRunning(unit) then return p end
    local fwd = Norm2D(Flat(Entity.GetAbsRotation(unit):GetForward()))
    local ms  = NPC.GetMoveSpeed(unit)
    return Vector(p.x + fwd.x*ms*dt, p.y + fwd.y*ms*dt, 0)
end

-- ===========================================================================
--  TREE HELPER
-- ===========================================================================
local function NearbyTrees(center, radius)
    local list = {}

    local function TryAdd(ent)
        if not ent then return end
        local tp = Flat(Entity.GetAbsOrigin(ent))
        if Dist2D(tp, center) <= radius then table.insert(list, tp) end
    end

    if Trees then
        local raw = (Trees.InRadius and Trees.InRadius(Vector(center.x, center.y, 0), radius+200, true))
                 or (Trees.GetAll   and Trees.GetAll())
        if raw then for _, t in pairs(raw) do TryAdd(t) end end
    end

    if NPCs and NPCs.GetAll then
        for _, npc in pairs(NPCs.GetAll()) do
            if npc and Entity.IsAlive(npc) then
                local name = NPC.GetUnitName(npc)
                if name == "npc_dota_thinker" or name == "npc_dota_tree" then
                    if NPC.HasModifier(npc, "modifier_item_iron_wood_branch")
                    or NPC.HasModifier(npc, "modifier_furion_sprout_tie")
                    or NPC.HasModifier(npc, "modifier_hoodwink_acorn_shot_tree") then
                        TryAdd(npc)
                    end
                end
            end
        end
    end
    return list
end

-- ===========================================================================
--  ANCHOR FILTER
-- ===========================================================================
local function IsValidAnchor(unit)
    if not unit or unit == hero or unit == target then return false end
    if not Entity.IsAlive(unit)    then return false end
    if NPC.IsStructure(unit)       then return false end
    if Entity.IsSameTeam(hero, unit) then return false end
    if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVISIBLE)    then return false end
    if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then return false end
    if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_NO_TARGET)    then return false end
    local n = string.lower(NPC.GetUnitName(unit) or "")
    if string.find(n,"thinker") or string.find(n,"dummy")
    or string.find(n,"_base")   or string.find(n,"vision") then return false end
    return true
end

-- ===========================================================================
--  SHACKLE GEOMETRY CHECK
-- ===========================================================================
local function CanShackle()
    if not q_spell or not target then return false end

    local castPt = Ability.GetCastPoint(q_spell) or 0.15
    local wrPos  = Flat(Entity.GetAbsOrigin(hero))
    local tPos   = Flat(Entity.GetAbsOrigin(target))
    local dist   = Dist2D(wrPos, tPos)
    if dist < 1 then return false end

    local dt      = castPt + dist / SHACKLE_SPEED
    local predT   = PredPos(target, dt)
    local projDir = Norm2D(Vector(predT.x - wrPos.x, predT.y - wrPos.y, 0))

    if NPCs and NPCs.GetAll then
        for _, unit in pairs(NPCs.GetAll()) do
            if IsValidAnchor(unit) and (NPC.IsHero(unit) or UI.AllowCreep:Get()) then
                local predU = PredPos(unit, dt)
                local toA   = Vector(predU.x - predT.x, predU.y - predT.y, 0)
                local d     = sqrt(toA.x*toA.x + toA.y*toA.y)
                if d > 0 and d <= SHACKLE_RADIUS then
                    if Dot2D(projDir, Norm2D(toA)) >= SHACKLE_COS then return true end
                end
            end
        end
    end

    for _, tp in ipairs(NearbyTrees(predT, SHACKLE_RADIUS)) do
        local toA = Vector(tp.x - predT.x, tp.y - predT.y, 0)
        local d   = sqrt(toA.x*toA.x + toA.y*toA.y)
        if d > 0 and d <= SHACKLE_RADIUS then
            if Dot2D(projDir, Norm2D(toA)) >= SHACKLE_COS then return true end
        end
    end

    return false
end

-- ===========================================================================
--  FIND BLINK POSITION FOR SHACKLE ALIGNMENT
-- ===========================================================================
local function FindBlinkPos()
    if not q_spell or not target then return nil end

    local castPt  = Ability.GetCastPoint(q_spell) or 0.15
    local dt      = castPt + BLINK_GAP / SHACKLE_SPEED + 0.07

    local tCurr   = Entity.GetAbsOrigin(target)
    local tPred   = PredPos(target, dt)
    local wrPos   = Flat(Entity.GetAbsOrigin(hero))

    local hA, tA, cA = {}, {}, {}

    if NPCs and NPCs.GetAll then
        for _, unit in pairs(NPCs.GetAll()) do
            if IsValidAnchor(unit) then
                local uPred = PredPos(unit, dt)
                local d = Dist2D(uPred, tPred)
                if d > 0 and d <= SHACKLE_RADIUS then
                    if     NPC.IsHero(unit)       then table.insert(hA, uPred)
                    elseif UI.AllowCreep:Get()    then table.insert(cA, uPred)
                    end
                end
            end
        end
    end

    for _, tp in ipairs(NearbyTrees(tPred, SHACKLE_RADIUS)) do
        table.insert(tA, tp)
    end

    local function Best(list)
        local bestPos, bestD = nil, math.huge
        for _, anchor in ipairs(list) do
            local dx  = tPred.x - anchor.x
            local dy  = tPred.y - anchor.y
            local len = sqrt(dx*dx + dy*dy)
            if len > 1 then
                local ux, uy = dx/len, dy/len
                local bx = tPred.x + ux * BLINK_GAP
                local by = tPred.y + uy * BLINK_GAP
                local d  = Dist2D(Vector(bx, by, 0), wrPos)
                if d <= BLINK_MAX and d < bestD then
                    bestD   = d
                    bestPos = Vector(bx, by, tCurr.z)
                end
            end
        end
        return bestPos
    end

    return Best(hA) or Best(tA) or Best(cA)
end

-- ===========================================================================
--  ON UPDATE
-- ===========================================================================
function wr.OnUpdate()
    if not UI.Enabled:Get() then ResetCombo(); return end
    if not IsWR()           then ResetCombo(); return end

    LoadSpells()

    local now = GameRules.GetGameTime()

    if w_spell and Ability.IsChannelling(w_spell) then return end

    if not UI.ComboKey:IsDown() then ResetCombo(); return end

    if not target or not Entity.IsAlive(target) then
        target = GetTarget()
    end

    ManageTargetParticle()

    if not target then
        if now >= lastAct then
            NPC.MoveTo(hero, Input.GetWorldCursorPos(), false, false, false, true)
            lastAct = now + 0.1
        end
        return
    end

    if now < lastAct then return end

    if comboState == 0 then comboState = 1 end

    --------------------------------------------------------------------------
    -- STATE 1 : Shackleshot (Q)
    --------------------------------------------------------------------------
    if comboState == 1 then
        if UI.UseQ:Get() and CanCast(q_spell) then

            if UI.ChkLinkens:Get() and NPC.IsLinkensProtected(target) then
                comboState = 2; return
            end

            local qRange = Ability.GetCastRange(q_spell)
            local hPos   = Entity.GetAbsOrigin(hero)
            local tPos   = Entity.GetAbsOrigin(target)
            local dist   = Dist2D(hPos, tPos)

            if blinkArrival then
                local arrived = Dist2D(Flat(hPos), Flat(blinkArrival)) < 150
                blinkArrival  = nil
                if arrived then
                    Ability.CastTarget(q_spell, target, false, false, true)
                    lastAct = now + 0.2
                    return
                end
            end

            local angleOk = CanShackle()
            local inRange  = dist <= qRange + 50

            if angleOk and inRange then
                Ability.CastTarget(q_spell, target, false, false, true)
                lastAct = now + 0.2

            elseif UI.UseBlink:Get() and blink_item and CanCast(blink_item) then
                local bp = FindBlinkPos()
                if bp then
                    Ability.CastPosition(blink_item, bp, false, false, true)
                    blinkArrival = bp
                    lastAct      = now + 0.05
                    return
                end
                if angleOk then
                    NPC.MoveTo(hero, tPos, false, false, false, true)
                    lastAct = now + 0.1
                else
                    comboState = 2
                end

            elseif angleOk then
                NPC.MoveTo(hero, tPos, false, false, false, true)
                lastAct = now + 0.1

            else
                comboState = 2
                lastAct    = now
            end

        else
            comboState   = 2
            lastAct      = 0
            blinkArrival = nil
        end
        return
    end

    --------------------------------------------------------------------------
    -- STATE 2 : Focus Fire (R)
    --------------------------------------------------------------------------
    if comboState == 2 then
        if UI.UseR:Get() and CanCast(r_spell) then
            local tPos = Entity.GetAbsOrigin(target)
            local dist = Dist2D(Entity.GetAbsOrigin(hero), tPos)
            if dist <= GetAttackRange() then
                Ability.CastTarget(r_spell, target, false, false, true)
                lastAct    = now + 0.15
                comboState = 3
            else
                NPC.MoveTo(hero, tPos, false, false, false, true)
                lastAct = now + 0.1
            end
        else
            comboState = 3
        end
        return
    end

    --------------------------------------------------------------------------
    -- STATE 3 : Powershot (W)
    --------------------------------------------------------------------------
    if comboState == 3 then
        if UI.UseW:Get() and CanCast(w_spell) then
            local tPos = Entity.GetAbsOrigin(target)
            if Dist2D(Entity.GetAbsOrigin(hero), tPos) <= Ability.GetCastRange(w_spell) + 50 then
                Ability.CastPosition(w_spell, tPos, false, false, true)
                lastAct = now + 0.1
            end
        end
        comboState = 4
        return
    end

    --------------------------------------------------------------------------
    -- STATE 4 : Windrun (E)
    --------------------------------------------------------------------------
    if comboState == 4 then
        if UI.UseE:Get() and CanCast(e_spell) then
            Ability.CastNoTarget(e_spell, false, false, true)
            lastAct = now + 0.05
        end
        comboState = 5
        return
    end

    --------------------------------------------------------------------------
    -- STATE 5 : Auto-attack loop
    --------------------------------------------------------------------------
    if comboState == 5 then
        Player.AttackTarget(player, hero, target, false, false, true)
        lastAct = now + 0.2

        if CanCast(q_spell) or CanCast(r_spell) or CanCast(w_spell) then
            comboState = 1
        end
    end
end

-- ===========================================================================
--  ON DRAW  — state HUD + Visual Lock-On Indicator + Cone
-- ===========================================================================
function wr.OnDraw()
    if not UI.Enabled:Get()                 then return end
    if not hero or not Entity.IsAlive(hero) then return end

    if UI.DrawState:Get() and comboState > 0 then
        local info = STATE_INFO[comboState]
        if info then
            local sp, ok = Render.WorldToScreen(Entity.GetAbsOrigin(hero))
            if ok then
                local x, y = sp.x, sp.y - 88
                Render.Text(drawFont, 14, info.txt, Vec2(x-1, y+1), Color(0,0,0,220))
                Render.Text(drawFont, 14, info.txt, Vec2(x,   y  ), info.col)
            end
        end
    end

    -- Visual Lock-on Text
    if UI.DrawTarget:Get() and UI.ComboKey:IsDown() and target and Entity.IsAlive(target) then
        local pos = Entity.GetAbsOrigin(target)
        local render_pos, pos_is_visible = Render.WorldToScreen(pos)

        if pos_is_visible then
            local text = "LOCKED"
            local x = render_pos.x
            local y = render_pos.y - 70

            local text_size = Render.TextSize(lockFont, 20, text)
            x = x - (text_size.x / 2)

            Render.Text(lockFont, 20, text, Vec2(x + 1, y + 1), Color(0, 0, 0, 255))
            Render.Text(lockFont, 20, text, Vec2(x, y), Color(255, 50, 50, 255))
        end
    end

    -- DYNAMIC TARGET FOR CONE RENDERING (Hover or Combo Target)
    local renderTarget = target
    if UI.AlwaysDrawCone:Get() and not renderTarget then
        renderTarget = GetTarget()
    end

    if (UI.DrawCone:Get() or UI.AlwaysDrawCone:Get()) and q_spell and renderTarget and Entity.IsAlive(renderTarget) then
        local hPos = Entity.GetAbsOrigin(hero)
        local tPos = Entity.GetAbsOrigin(renderTarget)
        local dx, dy = tPos.x - hPos.x, tPos.y - hPos.y
        local len = sqrt(dx*dx + dy*dy)
        if len > 1 then
            local ux, uy = dx/len, dy/len
            local ang    = math.acos(SHACKLE_COS)
            local ca, sa = math.cos(ang), math.sin(ang)
            local lx = ux*ca - uy*sa;  local ly = ux*sa + uy*ca
            local rx = ux*ca + uy*sa;  local ry = -ux*sa + uy*ca

            local col  = UI.ConeColor:Get()
            local cLen = SHACKLE_RADIUS
            local base = Vector(tPos.x, tPos.y, tPos.z + 60)
            local e1   = Vector(base.x + lx*cLen, base.y + ly*cLen, base.z)
            local e2   = Vector(base.x + rx*cLen, base.y + ry*cLen, base.z)

            local s0, ok0 = Render.WorldToScreen(base)
            local s1, ok1 = Render.WorldToScreen(e1)
            local s2, ok2 = Render.WorldToScreen(e2)

            if ok0 and ok1 then Render.Line(s0, s1, col) end
            if ok0 and ok2 then Render.Line(s0, s2, col) end
            if ok1 and ok2 then Render.Line(s1, s2, col) end
        end
    end
end

return wr