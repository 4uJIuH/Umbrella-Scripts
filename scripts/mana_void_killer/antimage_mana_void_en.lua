--[[
    Anti-Mage — Mana Void Killer (English build)
    UCZone API v2.0 · https://uczone.gitbook.io/api-v2.0

    Same logic as mana_void_killer.lua, only the interface language and the menu
    path differ. Run one of the two, not both, or every kill gets ordered twice.

    Mana Void deals (target's missing mana × damage per mana) to every enemy
    inside the radius around the target. That single fact drives both modes:

      SOLO   — the target itself dies and stands alone, so it is a free pickoff.
      COMBO  — a drained enemy is used as a bomb: its huge missing-mana pool
               nukes everyone standing next to it. Fires once enough of them die.

    On top of that it draws, above every enemy, how many more autoattacks are
    needed before Mana Void becomes lethal — Mana Break burn and its bonus
    damage included.
]]

local VERSION = "1.0.0"
local script = {}

local HERO       = "npc_dota_hero_antimage"
local ULTIMATE   = "antimage_mana_void"
local MANA_BREAK = "antimage_mana_break"

-- Straight out of assets/data/npc_abilities.json, used only if the live KV read
-- fails. Mana Void is 1.0 damage per mana with a 400/450/500 radius.
local FALLBACK_DAMAGE_PER_MANA = 1.0
local FALLBACK_RADIUS          = 500
local FALLBACK_BURN_DAMAGE_PCT = 50

-- Require slightly more than the raw pool: regen and damage ticks can otherwise
-- leave a target alive at exactly zero.
local LETHAL_MARGIN = 1.03

-- No point simulating a whole minute of autoattacks.
local MAX_SIMULATED_HITS = 25

-- Buffs that keep a hero alive no matter the damage.
local SURVIVES_ANYTHING = {
    "modifier_dazzle_shallow_grave",
    "modifier_abaddon_borrowed_time",
    "modifier_oracle_false_promise_timer",
    "modifier_item_aeon_disk_buff",
    "modifier_troll_warlord_battle_trance",
}

----------------------------------------------------------------------
-- LOGGING
----------------------------------------------------------------------

local function log(level, message, data)
    if ai_bridge ~= nil and ai_bridge.mcp_log ~= nil then
        ai_bridge.mcp_log(level, message, data)
    end
end

----------------------------------------------------------------------
-- MENU
----------------------------------------------------------------------

local ui = {}

-- Every setting is read through this. If the menu ever fails to build, the
-- script keeps killing on sane defaults instead of going silently dead.
local DEFAULTS = {
    enabled     = true,
    castDelay   = 200,
    solo        = true,
    soloRadius  = 1200,
    combo       = true,
    comboKills  = 2,
    drawTarget  = true,
    showHits    = true,
    hintRadius  = 1600,
    hintOffset  = 14,
    showNumbers = false,
    debugLog    = false,
}

local function opt(name)
    local widget = ui[name]
    if widget == nil then
        return DEFAULTS[name]
    end

    return widget:Get()
end

local function buildMenu()
    -- Deliberately a different menu path from the Russian build, so both can sit
    -- in the scripts folder without fighting over the same widgets.
    local tab = Menu.Create("Scripts", "Utility", "Anti-Mage", "Main")
    if tab == nil or tab.Create == nil then
        return false
    end

    local mainGroup  = tab:Create("General", Enum.GroupSide.Left)
    local soloGroup  = tab:Create("Solo kill", Enum.GroupSide.Left)
    local comboGroup = tab:Create("Low-mana combo", Enum.GroupSide.Left)
    local hintGroup  = tab:Create("Hints", Enum.GroupSide.Right)
    local drawGroup  = tab:Create("Drawing", Enum.GroupSide.Right)

    if mainGroup == nil or mainGroup.Switch == nil then
        return false
    end

    ui.enabled = mainGroup:Switch("Enable", true, "\u{f0e7}")
    ui.enabled:ToolTip("Automatically cast Mana Void for the kill.")

    local gear = ui.enabled:Gear("Settings")
    ui.castDelay = gear:Slider("Cast cooldown", 50, 1000, 200, "%d ms")
    ui.castDelay:ToolTip("Guards against spamming orders.")

    ui.solo = soloGroup:Switch("Finish off loners", true, "\u{f05b}")
    ui.solo:ToolTip("Casts when the target dies and has no other enemies near it.")

    ui.soloRadius = soloGroup:Slider("Isolation radius", 400, 2500, 1200, "%d")
    ui.soloRadius:ToolTip("If another living enemy stands within this radius of the target, the solo kill is skipped.")

    ui.combo = comboGroup:Switch("Detonate low-mana target", true, "\u{f1e2}")
    ui.combo:ToolTip("Casts into an enemy missing a lot of mana so the area damage finishes everyone next to them.")

    ui.comboKills = comboGroup:Slider("Minimum kills", 1, 5, 2, "%d")
    ui.comboKills:ToolTip("How many enemies must be guaranteed to die from the blast before the ultimate is pressed.")

    ui.showHits = hintGroup:Switch("Hits until kill", true, "\u{f0e4}")
    ui.showHits:ToolTip("How many autoattacks are needed before Mana Void finishes the target. Accounts for mana burn, Mana Break damage, armor and magic resistance.")

    ui.hintRadius = hintGroup:Slider("Hint radius", 600, 3000, 1600, "%d")
    ui.hintRadius:ToolTip("Hints are drawn only for enemies within this radius of you.")

    ui.hintOffset = hintGroup:Slider("Offset above health bar", 0, 60, 14, "%d px")
    ui.hintOffset:ToolTip("Raises the panel further above the health bar if it still gets in the way.")

    ui.showNumbers = hintGroup:Switch("Show damage", false, "\u{f1ec}")
    ui.showNumbers:ToolTip("Adds an \"ultimate damage / effective hp\" line for the current moment.")

    ui.drawTarget = drawGroup:Switch("Show target", true, "\u{f06e}")
    ui.drawTarget:ToolTip("Draws the blast radius and the kill count above the chosen target.")

    ui.debugLog = drawGroup:Switch("MCP logging", false, "\u{f188}")
    ui.debugLog:ToolTip("Sends damage calculations to qMCP for debugging.")

    return true
end

----------------------------------------------------------------------
-- ABILITY DATA
----------------------------------------------------------------------

-- The docs ship GetLevelSpecialValueFor flagged as "WRONG API FIX ME IT MUST BE
-- GetSpecialValueFor" and never document the replacement, so neither name can be
-- trusted blindly. Probe both once, keep whichever answers.
local specialValueReader = nil

local function specialValue(ability, name, fallback)
    if ability == nil then
        return fallback
    end

    -- Appended one by one rather than written as a table literal: a missing name
    -- would leave a nil hole and ipairs would stop before the second reader.
    local candidates = {}
    local function offer(reader)
        if type(reader) == "function" then
            candidates[#candidates + 1] = reader
        end
    end

    if specialValueReader ~= nil then
        offer(specialValueReader)
    else
        offer(Ability.GetSpecialValueFor)
        offer(Ability.GetLevelSpecialValueFor)
    end

    for _, reader in ipairs(candidates) do
        local ok, value = pcall(reader, ability, name)
        if ok and type(value) == "number" and value ~= 0 then
            specialValueReader = reader
            return value
        end
    end

    return fallback
end

-- Talent bonuses are encoded inside the ability's own AbilityValues as
-- special_bonus_* keys, so the engine already folds them into the returned
-- value. Adding them again here would double-count and overestimate damage.
local function damagePerMana(ult)
    return specialValue(ult, "mana_void_damage_per_mana", FALLBACK_DAMAGE_PER_MANA)
end

local function blastRadius(ult)
    return specialValue(ult, "mana_void_aoe_radius", FALLBACK_RADIUS)
end

----------------------------------------------------------------------
-- DAMAGE MODEL
----------------------------------------------------------------------

local function canBeDamaged(unit)
    if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then return false end
    if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then return false end
    if not NPC.IsKillable(unit) then return false end

    for _, modifier in ipairs(SURVIVES_ANYTHING) do
        if NPC.HasModifier(unit, modifier) then
            return false
        end
    end

    return true
end

-- Extra checks that only matter for the unit the spell is actually aimed at.
local function canBeTargeted(unit)
    return canBeDamaged(unit)
        and not NPC.IsLinkensProtected(unit)
        and not NPC.HasModifier(unit, "modifier_item_lotus_orb_active")
end

local function effectiveHealth(unit)
    local health = Entity.GetHealth(unit) or 0
    local barriers = NPC.GetBarriers(unit)

    if barriers ~= nil then
        health = health
            + (barriers.magic and barriers.magic.current or 0)
            + (barriers.all and barriers.all.current or 0)
    end

    return health
end

-- Spell amplification is deliberately left out: the API exposes only the base
-- value, so counting it would overestimate damage and cost us failed kills.
-- Underestimating just means we fire slightly later, which is the safe side.
local function damageTaken(unit, rawDamage)
    if rawDamage <= 0 or not canBeDamaged(unit) then
        return 0
    end

    return rawDamage * (NPC.GetMagicalArmorDamageMultiplier(unit) or 1)
end

local function missingMana(unit)
    return math.max(0, (NPC.GetMaxMana(unit) or 0) - (NPC.GetMana(unit) or 0))
end

local function voidDamageAgainst(unit, perMana)
    return damageTaken(unit, missingMana(unit) * perMana)
end

local function diesTo(unit, rawDamage)
    local damage = damageTaken(unit, rawDamage)
    return damage > 0 and damage >= effectiveHealth(unit) * LETHAL_MARGIN
end

----------------------------------------------------------------------
-- AUTOATTACK SIMULATION
----------------------------------------------------------------------

-- Mana Break burns a flat amount plus a share of the target's max mana, and
-- turns part of whatever it burned into physical damage. All three numbers scale
-- with the ability level, which the KV read already accounts for. They are the
-- same for every target, so this is read once per tick rather than per enemy.
local function attackProfile(me)
    local minimum = NPC.GetTrueDamage(me) or 0
    local maximum = NPC.GetTrueMaximumDamage(me) or minimum

    local profile = {
        attack  = (minimum + math.max(minimum, maximum)) / 2,
        flat    = 0,
        percent = 0,
        share   = 0,
    }

    local ability = NPC.GetAbility(me, MANA_BREAK)
    if ability ~= nil
        and Ability.GetLevel(ability) >= 1
        and not NPC.HasState(me, Enum.ModifierState.MODIFIER_STATE_PASSIVES_DISABLED)
    then
        profile.flat    = specialValue(ability, "mana_per_hit", 0)
        profile.percent = specialValue(ability, "mana_per_hit_pct", 0)
        profile.share   = specialValue(ability, "percent_damage_per_burn", FALLBACK_BURN_DAMAGE_PCT) / 100
    end

    return profile
end

-- Walks the fight forward one autoattack at a time and reports how many are
-- needed before Mana Void finishes the target. Returns nil when it never gets
-- there within MAX_SIMULATED_HITS.
local function hitsUntilLethal(target, perMana, profile)
    if not canBeDamaged(target) then
        return nil
    end

    local maxMana = NPC.GetMaxMana(target) or 0
    if maxMana <= 0 then
        return nil
    end

    local burn = profile.flat + maxMana * profile.percent / 100

    -- Nothing would ever change: no burn to grow the void and no damage to chip.
    if burn <= 0 and profile.attack <= 0 then
        return nil
    end

    local magicMult = NPC.GetMagicalArmorDamageMultiplier(target) or 1
    local physMult  = NPC.GetArmorDamageMultiplier(target) or 1

    local mana   = NPC.GetMana(target) or 0
    local health = effectiveHealth(target)

    for hits = 0, MAX_SIMULATED_HITS do
        if (maxMana - mana) * perMana * magicMult >= health * LETHAL_MARGIN then
            return hits
        end

        local burned = math.min(burn, mana)
        mana = mana - burned
        health = health - (profile.attack + burned * profile.share) * physMult
    end

    return nil
end

----------------------------------------------------------------------
-- TARGETING
----------------------------------------------------------------------

local function visibleEnemies(me)
    local myTeam = Entity.GetTeamNum(me)
    local result = {}

    for _, hero in pairs(Heroes.GetAll()) do
        if Entity.GetTeamNum(hero) ~= myTeam
            and Entity.IsAlive(hero)
            and not Entity.IsDormant(hero)
            and not NPC.IsIllusion(hero)
        then
            result[#result + 1] = { unit = hero, pos = Entity.GetAbsOrigin(hero) }
        end
    end

    return result
end

-- Scores every reachable enemy as a potential blast centre and returns the one
-- that satisfies either mode, preferring the bigger multi-kill.
local function pickTarget(me, ult, enemies)
    local myPos     = Entity.GetAbsOrigin(me)
    local castRange = Ability.GetCastRange(ult) + (NPC.GetCastRangeBonus(me) or 0)
    local radius    = blastRadius(ult)
    local perMana   = damagePerMana(ult)

    local soloEnabled   = opt("solo")
    local comboEnabled  = opt("combo")
    local soloRadius    = opt("soloRadius")
    local requiredKills = opt("comboKills")

    local best = nil

    for _, candidate in ipairs(enemies) do
        if myPos:Distance2D(candidate.pos) <= castRange and canBeTargeted(candidate.unit) then
            local rawDamage = missingMana(candidate.unit) * perMana
            local kills, neighbours = 0, 0

            for _, other in ipairs(enemies) do
                local distance = candidate.pos:Distance2D(other.pos)

                if distance <= radius and diesTo(other.unit, rawDamage) then
                    kills = kills + 1
                end

                if other.unit ~= candidate.unit and distance <= soloRadius then
                    neighbours = neighbours + 1
                end
            end

            local mode = nil
            if comboEnabled and kills >= requiredKills then
                mode = "combo"
            elseif soloEnabled and kills >= 1 and neighbours == 0 then
                mode = "solo"
            end

            if mode ~= nil and (best == nil or kills > best.kills) then
                best = {
                    unit   = candidate.unit,
                    kills  = kills,
                    damage = rawDamage,
                    radius = radius,
                    mode   = mode,
                }
            end
        end
    end

    return best
end

local function buildHints(me, ult, enemies)
    local myPos   = Entity.GetAbsOrigin(me)
    local reach   = opt("hintRadius")
    local perMana = damagePerMana(ult)
    local profile = attackProfile(me)
    local hints   = {}

    for _, enemy in ipairs(enemies) do
        if myPos:Distance2D(enemy.pos) <= reach then
            local hits = hitsUntilLethal(enemy.unit, perMana, profile)

            if hits ~= nil then
                hints[#hints + 1] = {
                    unit   = enemy.unit,
                    hits   = hits,
                    damage = voidDamageAgainst(enemy.unit, perMana),
                    health = effectiveHealth(enemy.unit),
                }
            end
        end
    end

    return hints
end

----------------------------------------------------------------------
-- THEME
----------------------------------------------------------------------

-- Colours are pulled from the cheat's own style vars, so the overlay follows
-- whatever Umbrella theme is active instead of hardcoding a palette next to it.
local theme = {}

local function refreshTheme()
    local function style(name, fallback)
        local ok, color = pcall(Menu.Style, name)
        if ok and color ~= nil and color.r ~= nil then
            return color
        end

        return fallback
    end

    theme.panel   = style("group_background", Color(37, 37, 42, 238))
    theme.outline = style("outline", Color(52, 52, 60, 200))
    theme.accent  = style("primary", Color(224, 62, 54, 255))
    theme.text    = style("primary_widgets_text", Color(236, 236, 240, 255))
    theme.muted   = style("third_tab_text", Color(150, 150, 160, 235))
    theme.ready   = style("multiselect_item_selected", Color(80, 200, 110, 255))
    theme.shadow  = Color(0, 0, 0, 165)
end

local function fade(color, alpha)
    return Color(color.r, color.g, color.b, math.floor(alpha))
end

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------

local LINE_SIZE   = 14
local SMALL_SIZE  = 12
local STRIP_WIDTH = 3
local PAD_X       = 7
local PAD_Y       = 4
local ROUNDING    = 4

local font = nil

local function plural(count, word)
    return count == 1 and word or word .. "s"
end

local function run(text, color, size)
    return { text = text, color = color, size = size or LINE_SIZE }
end

-- Anchors the panel just above the unit's health bar rather than at a guessed
-- height, so it never covers the hp/mana bars.
local function anchorAboveHealthBar(unit, gap)
    local offset = NPC.GetHealthBarOffset(unit) or 180
    local screen, visible = Render.WorldToScreen(Entity.GetAbsOrigin(unit) + Vector(0, 0, offset))

    if not visible then
        return nil
    end

    return screen.x, screen.y - gap
end

-- lines is a list of rows, each row a list of coloured runs.
local function drawPanel(centerX, bottomY, lines, accent)
    local widths, heights = {}, {}
    local contentWidth, contentHeight = 0, 0

    for index, line in ipairs(lines) do
        local width, height = 0, 0

        for _, piece in ipairs(line) do
            local size = Render.TextSize(font, piece.size, piece.text)
            width = width + size.x
            height = math.max(height, size.y)
        end

        widths[index], heights[index] = width, height
        contentWidth = math.max(contentWidth, width)
        contentHeight = contentHeight + height
    end

    local boxWidth  = contentWidth + PAD_X * 2 + STRIP_WIDTH
    local boxHeight = contentHeight + PAD_Y * 2

    local left   = math.floor(centerX - boxWidth / 2)
    local top    = math.floor(bottomY - boxHeight)
    local start  = Vec2(left, top)
    local finish = Vec2(left + boxWidth, top + boxHeight)

    Render.Shadow(start, finish, theme.shadow, 12, ROUNDING)
    Render.FilledRect(start, finish, theme.panel, ROUNDING)
    Render.Rect(start, finish, fade(theme.outline, 200), ROUNDING, Enum.DrawFlags.None, 1)

    -- The accent strip on the left edge is the same cue Umbrella uses to mark
    -- an active group in its own panels.
    Render.FilledRect(
        Vec2(left + 1, top + 2),
        Vec2(left + 1 + STRIP_WIDTH, top + boxHeight - 2),
        accent,
        2
    )

    local cursorY = top + PAD_Y
    local textLeft = left + STRIP_WIDTH + PAD_X

    for index, line in ipairs(lines) do
        local cursorX = textLeft + (contentWidth - widths[index]) / 2

        for _, piece in ipairs(line) do
            Render.Text(
                font,
                piece.size,
                piece.text,
                Vec2(math.floor(cursorX), math.floor(cursorY)),
                piece.color
            )
            cursorX = cursorX + Render.TextSize(font, piece.size, piece.text).x
        end

        cursorY = cursorY + heights[index]
    end
end

local function drawBlastRing(unit, radius, accent)
    local center = Entity.GetAbsOrigin(unit)
    local previous, previousVisible = nil, false

    for index = 0, 48 do
        local angle = index * math.pi * 2 / 48
        local point = Vector(
            center.x + math.cos(angle) * radius,
            center.y + math.sin(angle) * radius,
            center.z + 15
        )
        local screen, visible = Render.WorldToScreen(point)

        if previous ~= nil and previousVisible and visible then
            Render.Line(previous, screen, fade(accent, 190), 1.4)
        end

        previous, previousVisible = screen, visible
    end
end

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------

local lastCast = 0
local plan     = nil
local hints    = nil

local function localAntiMage()
    local me = Heroes.GetLocal()

    if me == nil
        or NPC.GetUnitName(me) ~= HERO
        or not Entity.IsAlive(me)
    then
        return nil
    end

    return me
end

local function ultimateIsReady(me, ult)
    return not Ability.IsHidden(ult)
        and not Ability.IsInAbilityPhase(ult)
        and Ability.IsCastable(ult, NPC.GetMana(me))
        and not NPC.IsSilenced(me)
        and not NPC.IsStunned(me)
end

----------------------------------------------------------------------
-- CALLBACKS
----------------------------------------------------------------------

function script.OnScriptsLoaded()
    local ok, result = pcall(buildMenu)

    font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
        or Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)

    refreshTheme()

    log("info", "antimage_mana_void_en loaded", {
        menu_ready = ok and result == true,
        error = (not ok) and tostring(result) or nil,
    })
end

function script.OnUpdate()
    plan, hints = nil, nil

    if not opt("enabled") then
        return
    end

    refreshTheme()

    local me = localAntiMage()
    if me == nil then
        return
    end

    local ult = NPC.GetAbility(me, ULTIMATE)
    if ult == nil or Ability.GetLevel(ult) < 1 then
        return
    end

    local enemies = visibleEnemies(me)
    if #enemies == 0 then
        return
    end

    -- Hints stay useful while the ultimate is on cooldown, so they are built
    -- before the castability gate.
    if opt("showHits") then
        hints = buildHints(me, ult, enemies)
    end

    if not ultimateIsReady(me, ult) then
        return
    end

    plan = pickTarget(me, ult, enemies)
    if plan == nil then
        return
    end

    local now = GameRules.GetGameTime()
    if now - lastCast < opt("castDelay") / 1000 then
        return
    end

    lastCast = now

    -- execute_fast puts the order at the front of the queue so the kill is not
    -- stuck behind whatever the player was already doing.
    Ability.CastTarget(ult, plan.unit, false, false, true, "antimage_mana_void_en")

    if opt("debugLog") then
        log("info", "mana void cast", {
            mode            = plan.mode,
            target          = NPC.GetUnitName(plan.unit),
            kills           = plan.kills,
            damage          = math.floor(plan.damage),
            damage_per_mana = damagePerMana(ult),
            radius          = plan.radius,
        })
    end
end

-- Builds the rows for one enemy. Returns nil when there is nothing to show.
local function panelFor(hint, isTarget, withNumbers)
    local lines = {}
    local accent = theme.accent

    if hint ~= nil then
        if hint.hits == 0 then
            accent = theme.ready
            lines[#lines + 1] = { run("KILL", theme.ready) }
        else
            lines[#lines + 1] = {
                run(tostring(hint.hits) .. " ", theme.accent),
                run(plural(hint.hits, "hit"), theme.text),
            }
        end

        if withNumbers then
            lines[#lines + 1] = {
                run(
                    string.format("%d / %d", math.floor(hint.damage), math.floor(hint.health)),
                    theme.muted,
                    SMALL_SIZE
                ),
            }
        end
    end

    if isTarget then
        table.insert(lines, 1, {
            run(plan.mode == "combo" and "COMBO" or "SOLO", theme.accent),
            run(
                string.format(" · %d %s", plan.kills, plural(plan.kills, "kill")),
                theme.text
            ),
        })
        accent = theme.accent
    end

    if #lines == 0 then
        return nil
    end

    return lines, accent
end

function script.OnDraw()
    if font == nil or not opt("enabled") then
        return
    end

    local showHits    = opt("showHits")
    local withNumbers = opt("showNumbers")
    local gap         = opt("hintOffset")
    local targetUnit  = plan ~= nil and opt("drawTarget") and plan.unit or nil

    if targetUnit ~= nil and Entity.IsAlive(targetUnit) then
        drawBlastRing(targetUnit, plan.radius, theme.accent)
    end

    local drawn = {}

    if showHits and hints ~= nil then
        for _, hint in ipairs(hints) do
            if Entity.IsAlive(hint.unit) then
                local isTarget = hint.unit == targetUnit
                local lines, accent = panelFor(hint, isTarget, withNumbers)

                if lines ~= nil then
                    local x, y = anchorAboveHealthBar(hint.unit, gap)
                    if x ~= nil then
                        drawPanel(x, y, lines, accent)
                    end
                end

                drawn[hint.unit] = true
            end
        end
    end

    -- The cast target can sit outside the hint radius, so it still gets a panel.
    if targetUnit ~= nil and not drawn[targetUnit] and Entity.IsAlive(targetUnit) then
        local lines, accent = panelFor(nil, true, false)

        if lines ~= nil then
            local x, y = anchorAboveHealthBar(targetUnit, gap)
            if x ~= nil then
                drawPanel(x, y, lines, accent)
            end
        end
    end
end

return script
