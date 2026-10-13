local KotL = {}

local Menu, Players, Player, NPC, Entity, Ability, Input, GameRules, Enum = Menu, Players, Player, NPC, Entity, Ability, Input, GameRules, Enum

-- Initialize Menu
local root = Menu.Find("Heroes", "Hero List", "Keeper Of The Light", "Main Settings", "Hero Settings")
if not root then
    root = Menu.Create("Heroes", "Hero List", "Keeper Of The Light", "Main Settings", "Hero Settings")
end

local function SetMenuIcon(widget, imagePath)
    if widget and widget.Image then
        pcall(widget.Image, widget, imagePath)
    end
end

-- Layout Tabs
local tabOffense = Menu.Find("Heroes", "Hero List", "Keeper Of The Light", "Main Settings", "Offensive Abilities")
if not tabOffense then
    tabOffense = Menu.Create("Heroes", "Hero List", "Keeper Of The Light", "Main Settings", "Offensive Abilities")
end

local tabSupport = Menu.Find("Heroes", "Hero List", "Keeper Of The Light", "Main Settings", "Support & Saves")
if not tabSupport then
    tabSupport = Menu.Create("Heroes", "Hero List", "Keeper Of The Light", "Main Settings", "Support & Saves")
end

-- Icons
local iconIlluminate = "panorama/images/spellicons/keeper_of_the_light_illuminate_png.vtex_c"
local iconBlinding = "panorama/images/spellicons/keeper_of_the_light_blinding_light_png.vtex_c"
local iconSolar = "panorama/images/spellicons/keeper_of_the_light_radiant_bind_png.vtex_c"
local iconRecall = "panorama/images/spellicons/keeper_of_the_light_recall_png.vtex_c"
local iconChakra = "panorama/images/spellicons/keeper_of_the_light_chakra_magic_png.vtex_c"

-- [Q] Illuminate (Offense)
KotL.AutoRelease = tabOffense:Switch("Auto Early Illuminate for Kill", true)
SetMenuIcon(KotL.AutoRelease, iconIlluminate)

local gear = KotL.AutoRelease:Gear("Illuminate Settings")
KotL.ReleaseOnEscape = gear:Switch("Release if target escapes wave (Any Damage)", true)

KotL.OverkillMargin = gear:Slider("Overkill Margin Damage", 0, 150, 20)
KotL.AutoFarm = gear:Switch("Auto Release to Last Hit Creeps", false)

KotL.MinCreeps = gear:Slider("Min Creeps to Last Hit", 1, 10, 2)
KotL.DebugMode = gear:Switch("Enable Debug Console Logs", false)

-- [W] Blinding Light (Support / Saves)
KotL.AutoBlindingLight = tabSupport:Switch("Auto Blinding Light Saves", true)
SetMenuIcon(KotL.AutoBlindingLight, iconBlinding)

local blGear = KotL.AutoBlindingLight:Gear("Blinding Light Settings")
KotL.BL_HPThreshold = blGear:Slider("Ally HP Threshold %", 1, 100, 30)
KotL.BL_EnemyRange = blGear:Slider("Enemy Threat Range", 100, 1000, 500)

-- [E] Solar Bind (Support)
KotL.AutoSolarBind = tabSupport:Switch("Auto Solar Bind Fleeing Enemies", true)
SetMenuIcon(KotL.AutoSolarBind, iconSolar)

-- [Chakra] Chakra Magic (Support)
KotL.AutoChakra = tabSupport:Switch("Auto Chakra Magic Allies", true)
SetMenuIcon(KotL.AutoChakra, iconChakra)
local chakraGear = KotL.AutoChakra:Gear("Chakra Settings")
KotL.Chakra_ManaThreshold = chakraGear:Slider("Ally Mana Threshold %", 1, 100, 40)
KotL.Chakra_PrioritySelf = chakraGear:Switch("Prioritize Myself if Low Mana", true)

-- [R] Recall (Support / Saves)
KotL.SmartRecall = tabSupport:Switch("Auto Smart Recall Saves", true)
SetMenuIcon(KotL.SmartRecall, iconRecall)

local recallGear = KotL.SmartRecall:Gear("Recall Settings")
KotL.Recall_HPThreshold = recallGear:Slider("Ally HP Threshold %", 1, 100, 20)
KotL.Recall_EnemyThreat = recallGear:Slider("Enemy Threat Radius", 800, 2500, 1500)

-- [Illuminate Heal]
KotL.AutoHeal = tabSupport:Switch("Auto Release for Healing (Shard)", true)
SetMenuIcon(KotL.AutoHeal, iconIlluminate)
local healGear = KotL.AutoHeal:Gear("Healing Settings")
KotL.Heal_HPThreshold = healGear:Slider("Ally HP Threshold %", 1, 100, 50)

KotL.CastPos = nil
KotL.CastDir = nil
KotL.ChannelStartTime = nil

function KotL.GetSpecialValue(ability, key)
    if not ability then return 0 end
    if Ability.GetLevelSpecialValueFor then
        local ok, v = pcall(Ability.GetLevelSpecialValueFor, ability, key)
        if ok and v then return v end
    end
    if Ability.GetSpecialValue then
        local ok, v = pcall(Ability.GetSpecialValue, ability, key)
        if ok and v then return v end
    end
    return 0
end

function KotL.GetSpellAmp(hero)
    local amp = 0
    if NPC.GetSpellAmplification then
        local ok, v = pcall(NPC.GetSpellAmplification, hero)
        if ok and v then amp = amp + v end
    else
        local ok, v = pcall(function() return hero:GetSpellAmplification() end)
        if ok and v then amp = amp + v end
    end

    -- Check for Divine Rapier (grants +25% spell amp in current Dota)
    for i = 0, 5 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == "item_rapier" then
            amp = amp + 0.25
        end
    end

    return amp
end

function KotL.HasShard(npc)
    return NPC.HasModifier(npc, "modifier_item_aghanims_shard") or NPC.GetItem(npc, "item_shard", true) ~= nil
end

function KotL.DistancePointToLine(point, lineStart, lineDir)
    local w = point - lineStart
    local proj = w:Dot(lineDir)
    if proj <= 0 then
        return (point - lineStart):Length()
    end
    local vSq = lineDir:LengthSqr()
    if vSq == 0 then return (point - lineStart):Length() end

    local projVec = lineDir:Scaled(proj / vSq)
    return (w - projVec):Length()
end

function KotL.OnPrepareUnitOrders(orders)
    if not orders then return true end

    -- ExecuteOrder log from user: DOTA_UNIT_ORDER_CAST_POSITION = 5
    if orders.order == 5 or orders.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION or
       orders.order == 6 or orders.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET then

        -- orders.ability might be nil in some hook contexts. We can also check player's active abilities.
        local abilityName = orders.ability and orders.ability ~= 0 and Ability.GetName(orders.ability) or ""

        -- Fallback: If ability is nil in the hook, check if the hero is casting illuminate
        if abilityName == "" then
            local myHero = Player.GetAssignedHero(Players.GetLocal())
            if myHero then
                local illu = NPC.GetAbility(myHero, "keeper_of_the_light_illuminate")
                local illuS = NPC.GetAbility(myHero, "keeper_of_the_light_spirit_form_illuminate")
                if (illu and Ability.IsInAbilityPhase(illu)) or (illuS and Ability.IsInAbilityPhase(illuS)) then
                    abilityName = "keeper_of_the_light_illuminate"
                end
            end
        end

        if abilityName == "keeper_of_the_light_illuminate" or abilityName == "keeper_of_the_light_spirit_form_illuminate" then
            local myHero = Player.GetAssignedHero(Players.GetLocal())
            if myHero and Entity.IsAlive(myHero) then
                KotL.CastPos = Entity.GetAbsOrigin(myHero)

                if orders.position and orders.position:Length() > 0 then
                    KotL.CastDir = (orders.position - KotL.CastPos):Normalized()
                else
                    KotL.CastDir = Entity.GetRotation(myHero):GetForward()
                end

                KotL.ChannelStartTime = GameRules.GetGameTime()
            end
        end
    end
    return true
end

function KotL.OnUpdate()
    if not Engine.IsInGame() then return end

    local myHero = Player.GetAssignedHero(Players.GetLocal())
    if not myHero or NPC.GetUnitName(myHero) ~= "npc_dota_hero_keeper_of_the_light" or not Entity.IsAlive(myHero) then return end

    if KotL.AutoRelease:Get() then
        KotL.ManageIlluminate(myHero)
    end

    if KotL.AutoBlindingLight:Get() then
        KotL.ManageBlindingLight(myHero)
    end

    if KotL.AutoSolarBind:Get() then
        KotL.ManageSolarBind(myHero)
    end

    if KotL.AutoChakra:Get() then
        KotL.ManageChakra(myHero)
    end

    if KotL.SmartRecall:Get() then
        KotL.ManageRecall(myHero)
    end
end

KotL.LastChakraCast = 0
function KotL.ManageChakra(myHero)
    if GameRules.GetGameTime() - KotL.LastChakraCast < 1.0 then return end

    local chakra = NPC.GetAbility(myHero, "keeper_of_the_light_chakra_magic")
    if not chakra or not Ability.IsCastable(chakra, NPC.GetMana(myHero)) then return end

    local castRange = KotL.GetSpecialValue(chakra, "cast_range")
    if castRange <= 0 then castRange = 900 end
    castRange = castRange + 250 -- Buffer for Aether Lens/Talents

    local threshold = KotL.Chakra_ManaThreshold:Get() / 100.0

    -- Priority 1: Self-cast if low mana
    if KotL.Chakra_PrioritySelf:Get() then
        local myMana = NPC.GetMana(myHero)
        local myMaxMana = NPC.GetMaxMana(myHero)
        if myMana / myMaxMana < 0.3 then -- If we are very low, we need mana to keep supporting
            Ability.CastTarget(chakra, myHero)
            KotL.LastChakraCast = GameRules.GetGameTime()
            return
        end
    end

    -- Priority 2: Help allies
    local allies = Entity.GetHeroesInRadius(myHero, castRange, Enum.TeamType.TEAM_FRIEND)
    if not allies then return end

    for _, ally in ipairs(allies) do
        if Entity.IsAlive(ally) and not Entity.IsDormant(ally) and not NPC.IsIllusion(ally) then
            local manaPerc = NPC.GetMana(ally) / NPC.GetMaxMana(ally)
            if manaPerc < threshold then
                Ability.CastTarget(chakra, ally)
                KotL.LastChakraCast = GameRules.GetGameTime()
                if KotL.DebugMode:Get() then
                    Log.Write(string.format("[KotL-Chakra] Restoring mana to %s (%.0f%%)", NPC.GetUnitName(ally), manaPerc * 100))
                end
                return
            end
        end
    end
end

KotL.LastSolarBindCast = 0
function KotL.ManageSolarBind(myHero)
    if GameRules.GetGameTime() - KotL.LastSolarBindCast < 1.0 then return end

    local sbAbility = NPC.GetAbility(myHero, "keeper_of_the_light_radiant_bind")

    if not sbAbility or Ability.GetLevel(sbAbility) == 0 or Ability.IsHidden(sbAbility) then return end
    if not Ability.IsCastable(sbAbility, NPC.GetMana(myHero)) then return end

    local castRange = KotL.GetSpecialValue(sbAbility, "cast_range")
    if castRange <= 0 then castRange = 700 end
    castRange = castRange + 250 -- Add typical buffer for Aether/Talent

    local enemies = Entity.GetHeroesInRadius(myHero, castRange, Enum.TeamType.TEAM_ENEMY, false, true)
    if not enemies then return end

    for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and not NPC.IsIllusion(enemy) then
            if not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) and
               not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
                -- Check if enemy is running away
                if NPC.IsRunning(enemy) then
                    local enemyPos = Entity.GetAbsOrigin(enemy)
                    local myPos = Entity.GetAbsOrigin(myHero)
                    local dirToKotl = (myPos - enemyPos):Normalized()
                    local enemyDir = Entity.GetRotation(enemy):GetForward():Normalized()

                    local isFacingKotl = enemyDir:Dot(dirToKotl) > 0
                    if not isFacingKotl then
                        local moveSpeed = NPC.GetMoveSpeed(enemy)
                        -- If they are moving fast and away, punish them
                        if moveSpeed >= 330 then
                            Ability.CastTarget(sbAbility, enemy)
                            KotL.LastSolarBindCast = GameRules.GetGameTime()
                            if KotL.DebugMode:Get() then
                                Log.Write(string.format("[KotL-Bind] Cast Solar Bind on fleeing %s (MS: %d)", NPC.GetUnitName(enemy), moveSpeed))
                            end
                            return
                        end
                    end
                end
            end
        end
    end
end

KotL.LastRecallCast = 0
KotL.LastRecallDelay = 6.0

function KotL.ManageRecall(myHero)
    -- Aghanim's Shard grants 2 charges. We MUST wait longer than the maximum teleport delay
    -- before allowing another cast, otherwise both charges are wasted on 1 guy.
    if GameRules.GetGameTime() - KotL.LastRecallCast < (KotL.LastRecallDelay + 0.5) then return end

    local recallAbility = NPC.GetAbility(myHero, "keeper_of_the_light_recall")

    -- In 7.41, Recall is tied to Spirit Form level.
    if not recallAbility or Ability.GetLevel(recallAbility) == 0 then return end

    -- Update the dynamic delay locking (usually 6/5/4 seconds)
    local actualDelay = KotL.GetSpecialValue(recallAbility, "teleport_delay")
    if actualDelay > 0 then
        KotL.LastRecallDelay = actualDelay
    end

    local spiritFormAbility = NPC.GetAbility(myHero, "keeper_of_the_light_spirit_form")

    -- Check if it's theoretically castable based on mana (assuming we might need mana for Spirit Form + Recall)
    if NPC.GetMana(myHero) < Ability.GetManaCost(recallAbility) then return end

    local hpThreshold = KotL.Recall_HPThreshold:Get() / 100.0

    -- Scan the entire map for allies (Global ability)
    for i = 1, Players.Count() do
        local player = Players.Get(i)
        if player then
            local ally = Player.GetAssignedHero(player)
            if ally and ally ~= myHero and Entity.IsSameTeam(ally, myHero) and Entity.IsAlive(ally) and not Entity.IsDormant(ally) and not NPC.IsIllusion(ally) then
                local maxHp = Entity.GetMaxHealth(ally)
                local currentHp = Entity.GetHealth(ally)

                -- Is deeply wounded?
                if maxHp > 0 and (currentHp / maxHp) <= hpThreshold then
                    -- Recall has a 6/5/4s delay and breaks on player damage.
                    -- We should NOT recall someone actively stunned and getting beaten to death.
                    -- We SHOULD recall someone who is low HP, running, and enemies are approaching but haven't engaged yet.

                    local threatRange = KotL.Recall_EnemyThreat:Get()
                    local enemiesNearAlly = Entity.GetHeroesInRadius(ally, threatRange, Enum.TeamType.TEAM_ENEMY, false, true)

                    -- Only recall if there's actually a threat hunting them
                    if enemiesNearAlly and #enemiesNearAlly > 0 then

                        -- Make sure they aren't ALREADY surrounded by melee range enemies (Recall will just break instantly)
                        local enemiesInMelee = Entity.GetHeroesInRadius(ally, 400, Enum.TeamType.TEAM_ENEMY, false, true)
                        if not enemiesInMelee or #enemiesInMelee == 0 then

                            -- Check proximity to KotL. If they are already near KotL, don't recall.
                            local distToKotL = (Entity.GetAbsOrigin(myHero) - Entity.GetAbsOrigin(ally)):Length2D()
                            if distToKotL > 1500 then

                                -- If Recall is hidden, it means we must cast Spirit Form first
                                if Ability.IsHidden(recallAbility) then
                                    if spiritFormAbility and Ability.IsCastable(spiritFormAbility, NPC.GetMana(myHero)) then
                                        Ability.CastNoTarget(spiritFormAbility)
                                        -- The actual Recall cast will happen on the next tick once Un-Hidden
                                        return
                                    else
                                        -- Can't cast Spirit Form, can't cast Recall
                                        return
                                    end
                                end

                                -- We are in Spirit Form (or Recall is otherwise unhidden) and ready to cast
                                -- Only cast if it's off cooldown
                                if Ability.IsCastable(recallAbility, NPC.GetMana(myHero)) then
                                    Ability.CastTarget(recallAbility, ally)
                                    KotL.LastRecallCast = GameRules.GetGameTime()
                                    if KotL.DebugMode:Get() then
                                        Log.Write(string.format("[KotL-Recall] Preemptive Safety Recall on %s (HP: %.0f%%, Enemies Approaching)", NPC.GetUnitName(ally), (currentHp/maxHp)*100))
                                    end
                                end
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

KotL.LastBlindingLightCast = 0

function KotL.ManageBlindingLight(myHero)
    if GameRules.GetGameTime() - KotL.LastBlindingLightCast < 1.0 then return end

    local blAbility = NPC.GetAbility(myHero, "keeper_of_the_light_blinding_light")
    if not blAbility or Ability.IsHidden(blAbility) or Ability.GetLevel(blAbility) == 0 then return end
    if not Ability.IsCastable(blAbility, NPC.GetMana(myHero)) then return end

    local castRange = KotL.GetSpecialValue(blAbility, "cast_range")
    if castRange <= 0 then castRange = 600 end

    -- Bonus cast range from items/talents (e.g. Aether Lens buffer)
    castRange = castRange + 250

    local hpThreshold = KotL.BL_HPThreshold:Get() / 100.0
    local threatRange = KotL.BL_EnemyRange:Get()

    local allies = Entity.GetHeroesInRadius(myHero, castRange, Enum.TeamType.TEAM_FRIEND)
    if not allies then return end

    for _, ally in ipairs(allies) do
        if Entity.IsAlive(ally) and not Entity.IsDormant(ally) and not NPC.IsIllusion(ally) then
            local maxHp = Entity.GetMaxHealth(ally)
            local currentHp = Entity.GetHealth(ally)

            if maxHp > 0 and (currentHp / maxHp) <= hpThreshold then
                -- Check for enemies near this low-HP ally
                local enemies = Entity.GetHeroesInRadius(ally, threatRange, Enum.TeamType.TEAM_ENEMY, false, true)
                if enemies then
                    for _, enemy in ipairs(enemies) do
                        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and not NPC.IsIllusion(enemy) then
                            -- We found a valid threat. Cast Blinding Light on the ally's position.
                            -- This pushes all melee/close enemies AWAY from the ally.
                            Ability.CastPosition(blAbility, Entity.GetAbsOrigin(ally))
                            KotL.LastBlindingLightCast = GameRules.GetGameTime()

                            if KotL.DebugMode:Get() then
                                Log.Write(string.format("[KotL-BL] Cast Auto-Save on %s (HP: %.0f%%) from %s",
                                    NPC.GetUnitName(ally), (currentHp/maxHp)*100, NPC.GetUnitName(enemy)))
                            end
                            return
                        end
                    end
                end
            end
        end
    end
end

function KotL.ManageIlluminate(myHero)

    local illuminate = NPC.GetAbility(myHero, "keeper_of_the_light_illuminate")
    local illuminateSpirit = NPC.GetAbility(myHero, "keeper_of_the_light_spirit_form_illuminate")

    local hasModifier = NPC.HasModifier(myHero, "modifier_keeper_of_the_light_illuminate") or NPC.HasModifier(myHero, "modifier_keeper_of_the_light_spirit_form_illuminate")

    local channeler = nil

    if hasModifier then
        channeler = myHero
    else
        local units = Entity.GetUnitsInRadius(myHero, 2000, Enum.TeamType.TEAM_FRIEND)
        if units then
            for _, unit in ipairs(units) do
                if NPC.HasModifier(unit, "modifier_keeper_of_the_light_spirit_form_illuminate") or NPC.HasModifier(unit, "modifier_keeper_of_the_light_illuminate") then
                    channeler = unit
                    break
                end
            end
        end
    end

    if not channeler then
        if KotL.DebugMode:Get() and KotL.ChannelStartTime then
            if GameRules.GetGameTime() - KotL.ChannelStartTime < 0.5 then
                Log.Write("[KotL-Spirit] Cast captured, but no channeler or modifier found yet...")
            end
        end
        return
    end

    local modifier = NPC.GetModifier(channeler, "modifier_keeper_of_the_light_spirit_form_illuminate")
    if not modifier then
        modifier = NPC.GetModifier(channeler, "modifier_keeper_of_the_light_illuminate")
    end
    if not modifier then
        if KotL.DebugMode:Get() then Log.Write("[KotL-Spirit] No illuminate modifier found on channeler: " .. NPC.GetUnitName(channeler)) end
        return
    end

    local activeIlluminate = illuminateSpirit
    if not activeIlluminate or Ability.GetLevel(activeIlluminate) == 0 then
        activeIlluminate = illuminate
    end
    if not activeIlluminate then
        if KotL.DebugMode:Get() then Log.Write("[KotL-Spirit] activeIlluminate is nil.") end
        return
    end

    local maxDamage = KotL.GetSpecialValue(activeIlluminate, "total_damage")
    local maxChannelTime = KotL.GetSpecialValue(activeIlluminate, "max_channel_time")

    if maxDamage <= 0 or maxChannelTime <= 0 then return end

    local creationTime = 0
    if Modifier.GetCreationTime then
        local ok, v = pcall(Modifier.GetCreationTime, modifier)
        if ok and v then creationTime = v end
    end

    if creationTime == 0 then
        if KotL.ChannelStartTime then
            creationTime = KotL.ChannelStartTime
        else
            return
        end
    end

    local currentDamageTime = GameRules.GetGameTime() - creationTime
    if currentDamageTime > maxChannelTime then currentDamageTime = maxChannelTime end
    if currentDamageTime < 0 then currentDamageTime = 0 end

    local currentDamage = (currentDamageTime / maxChannelTime) * maxDamage

    local endSpell = nil
    local endSpellOwner = nil

    for i = 0, 30 do
        local ab = NPC.GetAbilityByIndex(channeler, i)
        if ab then
            local abName = Ability.GetName(ab)
            if string.find(abName, "illuminate_end") then
                endSpell = ab
                endSpellOwner = channeler
                break
            end
        end
    end

    -- In Spirit form, KotL himself often holds the cancel ability even if the dummy channels it
    if not endSpell and channeler ~= myHero then
        for i = 0, 30 do
            local ab = NPC.GetAbilityByIndex(myHero, i)
            if ab then
                local abName = Ability.GetName(ab)
                if string.find(abName, "illuminate_end") then
                    endSpell = ab
                    endSpellOwner = myHero
                    break
                end
            end
        end
    end

    -- Also try direct generic lookups just in case
    if not endSpell then
        endSpell = NPC.GetAbility(myHero, "keeper_of_the_light_spirit_form_illuminate_end") or NPC.GetAbility(myHero, "keeper_of_the_light_illuminate_end")
        if endSpell then endSpellOwner = myHero end
    end

    if not endSpell then
        if KotL.DebugMode:Get() then Log.Write("[KotL-Spirit] NO END SPELL FOUND.") end
        return
    end
    local origDir = KotL.CastDir
    if not origDir then
        origDir = Entity.GetRotation(channeler):GetForward():Normalized()
    end

    local castDir = origDir
    local castPos = KotL.CastPos
    if not castPos then
        castPos = Entity.GetAbsOrigin(channeler)
    end
    local radius = KotL.GetSpecialValue(activeIlluminate, "radius")
    if radius == 0 then radius = 375 end

    local range = KotL.GetSpecialValue(activeIlluminate, "range")
    if range == 0 then range = 1550 end

    local enemies = Entity.GetHeroesInRadius(channeler, range + radius, Enum.TeamType.TEAM_ENEMY, false, true)
    -- Check if we should release for killing enemies
    if enemies then
        for _, enemy in ipairs(enemies) do
            if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and not NPC.IsIllusion(enemy) then
                -- Skip magic immune or invulnerable targets
                if not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then

                    local enemyPos = Entity.GetAbsOrigin(enemy)

                    local w = enemyPos - castPos
                    local proj = w:Dot(castDir)
                    if proj > -radius and proj < (range + radius) then
                        local dist = KotL.DistancePointToLine(enemyPos, castPos, castDir)

                        -- Check if they are currently inside
                        local isInside = (dist <= radius and proj > 0 and proj < range)

                        -- Predict their future position
                        local enemySpeed = 0
                        local dir = Vector(0,0,0)
                        if NPC.IsRunning(enemy) then
                            enemySpeed = NPC.GetMoveSpeed(enemy)
                            dir = Entity.GetRotation(enemy):GetForward():Normalized()
                        end

                        local speed = 900 -- Illuminate projectile speed
                        -- Longitudinal velocity component of enemy along the beam direction
                        local v_y = dir:GetX() * castDir:GetX() + dir:GetY() * castDir:GetY()
                        v_y = v_y * enemySpeed

                        local timeToReach = 0
                        if proj > 0 then
                            local relativeSpeed = speed - v_y
                            if relativeSpeed > 10 then -- Avoid division by zero or near-zero if enemy outruns beam
                                timeToReach = proj / relativeSpeed
                            else
                                timeToReach = 9999 -- Enemy is outrunning the beam or moving parallel at same speed
                            end
                        else -- Enemy is behind or at the cast point (proj <= 0)
                            timeToReach = 0
                        end

                        local expectedPos = enemyPos + (dir:Scaled(enemySpeed * timeToReach))

                        local expectedW = expectedPos - castPos
                        local expectedProj = expectedW:Dot(castDir)
                        local expectedDist = KotL.DistancePointToLine(expectedPos, castPos, castDir)

                        -- Time-to-escape interception math
                        local willMiss = false
                        local isEscaping = false
                        local escapeBuffer = 0.1 -- 100ms safe margin before edge to guarantee hit

                        if proj > -radius then
                            -- Lateral Escape
                            if expectedDist > dist then
                                -- Time it takes for them to hit the wave edge at their current outward velocity
                                local t_esc_lat = (radius - dist) * timeToReach / (expectedDist - dist)
                                if timeToReach > t_esc_lat then
                                    willMiss = true -- It will take longer for the wave to reach them, than for them to leave. Guaranteed miss.
                                elseif (t_esc_lat - timeToReach) <= escapeBuffer then
                                    isEscaping = true -- They will escape very soon, drop it now!
                                end
                            end

                            -- Longitudinal Escape (outrunning the end of the beam)
                            if v_y > 0 and proj < range then
                                local t_esc_long = (range - proj) / v_y
                                if timeToReach > t_esc_long then
                                    willMiss = true
                                elseif (t_esc_long - timeToReach) <= escapeBuffer then
                                    isEscaping = true
                                end
                            end
                        end

                        if expectedProj < -radius then
                            willMiss = true
                        end

                        -- Always calculate damage for debug logs whether they are inside or not
                        local magicResist = NPC.GetMagicalArmorDamageMultiplier(enemy)
                        local spellAmp = KotL.GetSpellAmp(myHero)
                        local actualDamage = currentDamage * (1 + spellAmp) * magicResist

                        local requiredDamage = Entity.GetHealth(enemy) + KotL.OverkillMargin:Get()

                        if NPC.GetBarriers then
                            local ok, barriers = pcall(NPC.GetBarriers, enemy)
                            if ok and barriers then
                                if barriers.magic and barriers.magic.current > 0 then
                                    requiredDamage = requiredDamage + barriers.magic.current
                                end
                                if barriers.all and barriers.all.current > 0 then
                                    requiredDamage = requiredDamage + barriers.all.current
                                end
                            end
                        end

                        if KotL.DebugMode:Get() then
                            Log.Write(string.format("[KotL] [%s] IN: %s | MISS: %s | ESC: %s | D: %.0f->%.0f | P: %.0f->%.0f | T: %.2fs | DMG: %.0f/%.0f",
                                NPC.GetUnitName(enemy),
                                tostring(isInside), tostring(willMiss), tostring(isEscaping), dist, expectedDist, proj, expectedProj, timeToReach, actualDamage, requiredDamage
                            ))
                        end

                        -- We only care if they are currently inside and NOT mathematically impossible to hit
                        if isInside and not willMiss then
                            if isEscaping then
                                -- Check if we should drop it for lethal damage OR just because they are escaping based on settings
                                if actualDamage >= requiredDamage then
                                    Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, endSpellOwner, Vector(), endSpell, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, endSpellOwner)
                                    KotL.ChannelStartTime = nil
                                    return
                                elseif KotL.ReleaseOnEscape:Get() then
                                    local channelDuration = GameRules.GetGameTime() - (KotL.ChannelStartTime or 0)
                                    if channelDuration > 0.75 then
                                        Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, endSpellOwner, Vector(), endSpell, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, endSpellOwner)
                                        KotL.ChannelStartTime = nil
                                        return
                                    end
                                end
                            elseif actualDamage >= requiredDamage then
                                Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, endSpellOwner, Vector(), endSpell, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, endSpellOwner)
                                KotL.ChannelStartTime = nil
                                return
                            end
                        end
                    end
                end
            end
        end
    end

    -- Check if we should release for HEALING allies (Aghanim's Shard)
    if KotL.AutoHeal:Get() and KotL.HasShard(myHero) and NPC.HasModifier(myHero, "modifier_keeper_of_the_light_spirit_form") then
        local healThreshold = KotL.Heal_HPThreshold:Get() / 100.0
        local healPercent = KotL.GetSpecialValue(activeIlluminate, "heal_percent") / 100.0
        if healPercent <= 0 then healPercent = 0.40 end -- Default fallback for Shard heal factor

        local currentHeal = currentDamage * healPercent

        local allies = Entity.GetHeroesInRadius(channeler, range + radius, Enum.TeamType.TEAM_FRIEND)
        if allies then
            for _, ally in ipairs(allies) do
                if Entity.IsAlive(ally) and not Entity.IsDormant(ally) and not NPC.IsIllusion(ally) then
                    local allyPos = Entity.GetAbsOrigin(ally)
                    local w = allyPos - castPos
                    local proj = w:Dot(castDir)

                    if proj > -radius and proj < (range + radius) then
                        local dist = KotL.DistancePointToLine(allyPos, castPos, castDir)
                        if dist <= radius and proj > 0 and proj < range then
                            local hpPerc = Entity.GetHealth(ally) / Entity.GetMaxHealth(ally)
                            if hpPerc < healThreshold then
                                -- If healing can significantly help them (more than 10% of their MAX health) or they are krit-low
                                if currentHeal > (Entity.GetMaxHealth(ally) * 0.1) or hpPerc < 0.2 then
                                    if KotL.DebugMode:Get() then
                                        Log.Write(string.format("[KotL-Heal] Releasing for ally %s (HP: %.0f%%, Heal: %.0f)", NPC.GetUnitName(ally), hpPerc*100, currentHeal))
                                    end
                                    Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, endSpellOwner, Vector(), endSpell, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, endSpellOwner)
                                    KotL.ChannelStartTime = nil
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Creep Auto Farm Logic
    if KotL.AutoFarm:Get() then
        local killableCreeps = 0
        local minCreeps = KotL.MinCreeps:Get()

        -- Get all units in range, then filter for creeps
        local units = Entity.GetUnitsInRadius(channeler, range + radius, Enum.TeamType.TEAM_ENEMY)
        if units then
            for _, creep in ipairs(units) do
                if Entity.IsAlive(creep) and not Entity.IsDormant(creep) and NPC.IsCreep(creep) then
                    if not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) and
                       not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then

                        local creepPos = Entity.GetAbsOrigin(creep)
                        local w = creepPos - castPos
                        local proj = w:Dot(castDir)

                        -- Check if they are inside the longitudinal reach of the beam
                        if proj > -radius and proj < (range + radius) then
                            local dist = KotL.DistancePointToLine(creepPos, castPos, castDir)

                            -- Check if they are currently inside the lateral width
                            if dist <= radius and proj > 0 and proj < range then
                                -- Calculate damage
                                local magicResist = NPC.GetMagicalArmorDamageMultiplier(creep)
                                local spellAmp = KotL.GetSpellAmp(myHero)
                                local actualDamage = currentDamage * (1 + spellAmp) * magicResist

                                local requiredDamage = Entity.GetHealth(creep)

                                if NPC.GetBarriers then
                                    local ok, barriers = pcall(NPC.GetBarriers, creep)
                                    if ok and barriers then
                                        if barriers.magic and barriers.magic.current > 0 then
                                            requiredDamage = requiredDamage + barriers.magic.current
                                        end
                                        if barriers.all and barriers.all.current > 0 then
                                            requiredDamage = requiredDamage + barriers.all.current
                                        end
                                    end
                                end

                                -- No overkill margin for creeps, just flat lethal check
                                if actualDamage >= requiredDamage then
                                    killableCreeps = killableCreeps + 1
                                end
                            end
                        end
                    end
                end
            end
        end

        if killableCreeps >= minCreeps then
            Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, endSpellOwner, Vector(), endSpell, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, endSpellOwner)
            KotL.ChannelStartTime = nil
        end
    end
end

return KotL
