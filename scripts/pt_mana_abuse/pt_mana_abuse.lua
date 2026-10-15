local script = {}

local menu_tab = Menu.Create("Scripts", "PT Abuse", "Main")
local page = menu_tab:Create("Main")
local group = page:Create("Настройки", 1)

local enabled = group:Switch("Включить", true)
local switch_back = group:Switch("Возвращать атрибут", true)
local toggle_delay = 0.025

local STAT_STR = 0
local STAT_INT = 1
local STAT_AGI = 2

local ABILITY_KEYS = {
    [(Enum.ButtonCode and Enum.ButtonCode.KEY_Q) or 17] = 0,
    [(Enum.ButtonCode and Enum.ButtonCode.KEY_W) or 23] = 1,
    [(Enum.ButtonCode and Enum.ButtonCode.KEY_E) or 5]  = 2,
    [(Enum.ButtonCode and Enum.ButtonCode.KEY_D) or 4]  = 3,
    [(Enum.ButtonCode and Enum.ButtonCode.KEY_F) or 6]  = 4,
    [(Enum.ButtonCode and Enum.ButtonCode.KEY_R) or 18] = 5,
}

local last_ui_update = 0
local can_cast_abilities = {}
local cannot_cast_abilities = {}

local sm_state = "IDLE"
local sm_original_stat = nil
local sm_ability = nil
local sm_slot = nil
local sm_cost = 0
local sm_initial_mana = 0
local sm_next_time = 0
local sm_aim_start_time = 0
local sm_cast_order_issued = false
local sm_cast_order_time = 0
local sm_cancelled = false

local function GetPT(hero)
    for i = 0, 5 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == "item_power_treads" then
            return item
        end
    end
    return nil
end

local function DetectPTStat(hero, pt)
    if pt and PowerTreads and PowerTreads.GetStats then
        local ok, stat = pcall(PowerTreads.GetStats, pt)
        if ok and stat ~= nil then
            if stat == 0 or stat == "DOTA_ATTRIBUTE_STRENGTH" or stat == "STRENGTH" then
                return STAT_STR
            elseif stat == 1 or stat == "DOTA_ATTRIBUTE_AGILITY" or stat == "AGILITY" then
                return STAT_AGI
            elseif stat == 2 or stat == "DOTA_ATTRIBUTE_INTELLECT" or stat == "INTELLECT" or stat == "DOTA_ATTRIBUTE_INTELLIGENCE" or stat == "INTELLIGENCE" then
                return STAT_INT
            end
            if Enum and Enum.Attributes then
                if stat == Enum.Attributes.DOTA_ATTRIBUTE_STRENGTH or stat == Enum.Attributes.STRENGTH then
                    return STAT_STR
                elseif stat == Enum.Attributes.DOTA_ATTRIBUTE_AGILITY or stat == Enum.Attributes.AGILITY then
                    return STAT_AGI
                elseif stat == Enum.Attributes.DOTA_ATTRIBUTE_INTELLECT or stat == Enum.Attributes.INTELLECT or stat == Enum.Attributes.DOTA_ATTRIBUTE_INTELLIGENCE or stat == Enum.Attributes.INTELLIGENCE then
                    return STAT_INT
                end
            end
        end
    end

    if hero and Hero and Hero.GetStrength and Hero.GetStrengthTotal and Hero.GetAgility and Hero.GetAgilityTotal and Hero.GetIntellect and Hero.GetIntellectTotal then
        local bonusStr = Hero.GetStrengthTotal(hero) - Hero.GetStrength(hero)
        local bonusAgi = Hero.GetAgilityTotal(hero) - Hero.GetAgility(hero)
        local bonusInt = Hero.GetIntellectTotal(hero) - Hero.GetIntellect(hero)
        if bonusInt >= 10 and bonusInt >= bonusStr and bonusInt >= bonusAgi then
            return STAT_INT
        elseif bonusStr >= 10 and bonusStr >= bonusAgi then
            return STAT_STR
        else
            return STAT_AGI
        end
    end

    return STAT_AGI
end

local function RunPanorama(js)
    if not Engine or not Engine.RunScript then return end
    local context_names = { "Hud", "DotaHud", "CustomUIRoot" }
    for _, ctx in ipairs(context_names) do
        local ok = pcall(Engine.RunScript, js, ctx)
        if ok then return end
    end
    pcall(Engine.RunScript, js)
end

local function TriggerAbilityNormalCast(slot, ability, hero)
    if not ability or not hero then return end
    local abIdx = (Entity and Entity.GetIndex and Entity.GetIndex(ability)) or 0
    local heroIdx = (Entity and Entity.GetIndex and Entity.GetIndex(hero)) or 0

    local js = string.format([[
        (function() {
            var abEnt = %d;
            var heroEnt = %d;
            var slot = %d;
            
            if (typeof Abilities !== 'undefined' && Abilities.ExecuteAbility && abEnt > 0 && heroEnt > 0) {
                try {
                    Abilities.ExecuteAbility(abEnt, heroEnt, false);
                    return;
                } catch(e) {}
            }
            
            var hud = $.GetContextPanel();
            if (!hud) return;
            var center = hud.FindChildTraverse("center_block") || hud;
            var abilities = center.FindChildTraverse("abilities");
            if (!abilities) return;
            var child = abilities.GetChild(slot);
            if (child) {
                try {
                    $.DispatchEvent("Activated", child, "mouse");
                } catch(e) {}
            }
        })();
    ]], abIdx, heroIdx, slot)

    RunPanorama(js)
end

local function IsRadiusCircleActive()
    local player = Players and Players.GetLocal and Players.GetLocal()
    if player and Player and Player.GetActiveAbility then
        local ok, active = pcall(Player.GetActiveAbility, player)
        if ok and active and Entity.IsAbility(active) then
            return true
        end
    end
    if not Panorama or not Panorama.GetPanelByName then return false end
    local hud = Panorama.GetPanelByName("Hud", false) or Panorama.GetPanelByName("DotaHud", false)
    if hud and hud.IsValid and hud:IsValid() and hud.HasClass then
        return hud:HasClass("pt_aiming_circle_active")
    end
    return false
end

local function UpdatePanorama(canCastMap, cannotCastMap)
    local canCastEntries = {}
    for name, _ in pairs(canCastMap) do
        table.insert(canCastEntries, string.format('"%s":true', name))
    end
    local canCastJson = "{" .. table.concat(canCastEntries, ",") .. "}"

    local cannotCastEntries = {}
    for name, _ in pairs(cannotCastMap) do
        table.insert(cannotCastEntries, string.format('"%s":true', name))
    end
    local cannotCastJson = "{" .. table.concat(cannotCastEntries, ",") .. "}"

    local js = string.format([[
        (function() {
            var hud = $.GetContextPanel();
            if (!hud) return;
            
            var isAiming = false;
            try {
                if (typeof GameUI !== 'undefined' && GameUI.GetClickBehaviors) {
                    var cb = GameUI.GetClickBehaviors();
                    isAiming = (cb === 3 || cb === 9);
                }
            } catch(e) {}
            hud.SetHasClass("pt_aiming_circle_active", isAiming);
            
            var center = hud.FindChildTraverse("center_block") || hud;
            var abilities = center.FindChildTraverse("abilities");
            if (!abilities) return;
            
            var canCast = %s;
            var cannotCast = %s;
            var count = abilities.GetChildCount();
            
            for (var i = 0; i < count; i++) {
                var child = abilities.GetChild(i);
                if (!child) continue;
                
                var img = child.FindChildTraverse("AbilityImage");
                if (!img) continue;
                var name = img.abilityname || (img.GetAttributeString && img.GetAttributeString("abilityname", ""));
                if (!name) continue;
                
                if (canCast[name]) {
                    child.SetHasClass("insufficient_mana", false);
                    child.SetHasClass("no_mana", false);
                    child.SetHasClass("can_cast", true);
                    child.SetHasClass("low_mana", false);

                    img.SetHasClass("insufficient_mana", false);
                    img.SetHasClass("no_mana", false);

                    img.style.washColor = "none";
                    img.style.saturation = "1.0";
                    img.style.brightness = "1.0";
                    img.style.opacity = "1.0";
                    img.style.contrast = "1.0";

                    child.style.opacity = "1.0";
                    child.style.saturation = "1.0";
                    child.style.washColor = "none";

                    var overlay = child.FindChildTraverse("AbilityStatusOverlay") || child.FindChildTraverse("ManaOverlay");
                    if (overlay) overlay.style.visibility = "collapse";

                } else if (cannotCast[name]) {
                    child.SetHasClass("insufficient_mana", true);
                    child.SetHasClass("no_mana", true);
                    child.SetHasClass("can_cast", false);

                    img.SetHasClass("insufficient_mana", true);
                    img.SetHasClass("no_mana", true);

                    img.style.washColor = "#0077ffff";
                    img.style.saturation = "0.1";
                    img.style.brightness = "0.7";
                    img.style.opacity = "0.9";

                    var overlay = child.FindChildTraverse("AbilityStatusOverlay") || child.FindChildTraverse("ManaOverlay");
                    if (overlay) overlay.style.visibility = "visible";

                } else {
                    img.style.washColor = null;
                    img.style.saturation = null;
                    img.style.brightness = null;
                    img.style.opacity = null;
                    img.style.contrast = null;

                    child.style.opacity = null;
                    child.style.saturation = null;
                    child.style.brightness = null;
                    child.style.washColor = null;

                    var overlay = child.FindChildTraverse("AbilityStatusOverlay") || child.FindChildTraverse("ManaOverlay");
                    if (overlay) overlay.style.visibility = null;
                }
            }
        })();
    ]], canCastJson, cannotCastJson)

    RunPanorama(js)
end

function script.OnUpdate()
    if not enabled:Get() then return end
    if Engine and Engine.IsInGame and not Engine.IsInGame() then return end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then
        sm_state = "IDLE"
        return
    end

    local pt = GetPT(hero)
    if not pt then
        sm_state = "IDLE"
        return
    end

    local now = os.clock()
    local interval = toggle_delay

    if sm_state == "TO_INT_STEP2" then
        if now >= sm_next_time then
            Ability.CastNoTarget(pt)
            sm_next_time = now + interval
            sm_state = "WAIT_FOR_INT_THEN_EXECUTE"
        end

    elseif sm_state == "WAIT_FOR_INT_THEN_EXECUTE" then
        if now >= sm_next_time then
            sm_state = "EXECUTE_ABILITY"
        end

    elseif sm_state == "EXECUTE_ABILITY" then
        if sm_slot ~= nil and sm_ability and hero then
            TriggerAbilityNormalCast(sm_slot, sm_ability, hero)
        end

        sm_state = "AIMING"
        sm_aim_start_time = now
        sm_cast_order_issued = false
        sm_cancelled = false

    elseif sm_state == "AIMING" then
        local cd = (sm_ability and Entity.IsAbility(sm_ability) and Ability.GetCooldown(sm_ability)) or 0
        local inPhase = (sm_ability and Entity.IsAbility(sm_ability) and Ability.IsInAbilityPhase(sm_ability))
        local curManaNow = NPC.GetMana(hero)
        local manaSpent = (curManaNow < (sm_initial_mana - (sm_cost * 0.5)))
        local aimDuration = now - sm_aim_start_time
        local circleActive = IsRadiusCircleActive()

        if cd > 0 or inPhase or manaSpent or (sm_cast_order_issued and now - sm_cast_order_time > 0.05) then
            sm_state = "WAIT_CAST_COMPLETE"
            sm_next_time = now + 0.12

        elseif aimDuration > 0.40 and not circleActive then
            sm_state = "RESTORE_PT"
            sm_next_time = now

        elseif aimDuration > 0.25 and (sm_cancelled
            or (Input and Input.IsKeyDownOnce and (
                Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE2, true)
                or Input.IsKeyDownOnce(Enum.ButtonCode.KEY_S, true)
                or Input.IsKeyDownOnce(Enum.ButtonCode.KEY_ESCAPE, true)
            ))) then
            sm_state = "RESTORE_PT"
            sm_next_time = now

        elseif aimDuration > 15.0 then
            sm_state = "RESTORE_PT"
            sm_next_time = now
        end

    elseif sm_state == "WAIT_CAST_COMPLETE" then
        local inPhase = (sm_ability and Entity.IsAbility(sm_ability) and Ability.IsInAbilityPhase(sm_ability))
        if not inPhase or (now >= sm_next_time) then
            sm_state = "RESTORE_PT"
            sm_next_time = now
        end

    elseif sm_state == "RESTORE_PT" then
        if switch_back:Get() and sm_original_stat ~= nil and sm_original_stat ~= STAT_INT then
            if sm_original_stat == STAT_AGI then
                Ability.CastNoTarget(pt)
                sm_state = "IDLE"
            elseif sm_original_stat == STAT_STR then
                Ability.CastNoTarget(pt)
                sm_next_time = now + interval
                sm_state = "RESTORE_STEP2"
            else
                sm_state = "IDLE"
            end
        else
            sm_state = "IDLE"
        end

    elseif sm_state == "RESTORE_STEP2" then
        if now >= sm_next_time then
            Ability.CastNoTarget(pt)
            sm_state = "IDLE"
        end
    end

    if now - last_ui_update < 0.02 then return end
    last_ui_update = now

    local curMana = NPC.GetMana(hero)
    local curMaxMana = NPC.GetMaxMana(hero)
    local currentStat = DetectPTStat(hero, pt)

    local newCanCast = {}
    local newCannotCast = {}

    local potentialMana = curMana
    if currentStat ~= STAT_INT and curMaxMana > 0 then
        potentialMana = math.floor(curMana * ((curMaxMana + 120) / curMaxMana))
    end

    for i = 0, 24 do
        local ability = NPC.GetAbilityByIndex(hero, i)
        if ability and Entity.IsAbility(ability) and not Ability.IsPassive(ability) and not Ability.IsHidden(ability) then
            local level = Ability.GetLevel(ability)
            local cd = Ability.GetCooldown(ability)
            local cost = Ability.GetManaCost(ability)

            if level > 0 and cd == 0 and cost > 0 then
                local name = Ability.GetName(ability)
                if name then
                    if curMana < cost then
                        if currentStat ~= STAT_INT and potentialMana >= cost then
                            newCanCast[name] = true
                        else
                            newCannotCast[name] = true
                        end
                    end
                end
            end
        end
    end

    can_cast_abilities = newCanCast
    cannot_cast_abilities = newCannotCast

    UpdatePanorama(newCanCast, newCannotCast)
end

function script.OnPrepareUnitOrders(data)
    if not enabled:Get() or not data then return true end

    local hero = Heroes.GetLocal()
    if not hero or data.npc ~= hero then return true end

    if sm_state == "AIMING" then
        local order = data.order
        if order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION
            or order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
            or order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET_TREE
            or order == Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGETING then
            sm_cast_order_issued = true
            sm_cast_order_time = os.clock()

        elseif order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
            or order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET
            or order == Enum.UnitOrder.DOTA_UNIT_ORDER_STOP
            or order == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION then
            if os.clock() - sm_aim_start_time > 0.25 then
                sm_cancelled = true
            end
        end
    end

    return true
end

function script.OnKeyEvent(data)
    if not enabled:Get() or not data then return true end

    local isDown = (Enum.EKeyEvent and data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN) or (data.event == 0)
    if not isDown then return true end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then return true end

    local pt = GetPT(hero)
    if not pt then return true end

    local slot = ABILITY_KEYS[data.key]
    if slot == nil then return true end

    local ability = NPC.GetAbilityByIndex(hero, slot)
    if not ability or not Entity.IsAbility(ability) then return true end
    if Ability.IsPassive(ability) or Ability.IsHidden(ability) or Ability.GetLevel(ability) == 0 or Ability.GetCooldown(ability) > 0 then
        return true
    end

    local cost = Ability.GetManaCost(ability)
    if cost <= 0 then return true end

    local curMana = NPC.GetMana(hero)
    local curMaxMana = NPC.GetMaxMana(hero)
    local currentStat = DetectPTStat(hero, pt)

    local potentialManaWithINT = curMana
    if currentStat ~= STAT_INT and curMaxMana > 0 then
        potentialManaWithINT = math.floor(curMana * ((curMaxMana + 120) / curMaxMana))
    end

    if curMana >= cost then
        return true
    end

    if potentialManaWithINT < cost or currentStat == STAT_INT then
        return true
    end

    if sm_state == "AIMING" and sm_slot == slot then
        return true
    end

    local now = os.clock()
    local interval = toggle_delay

    sm_original_stat = currentStat
    sm_ability = ability
    sm_slot = slot
    sm_cost = cost
    sm_initial_mana = curMana
    sm_cast_order_issued = false
    sm_cancelled = false

    if currentStat == STAT_STR then
        Ability.CastNoTarget(pt)
        sm_next_time = now + interval
        sm_state = "WAIT_FOR_INT_THEN_EXECUTE"
    elseif currentStat == STAT_AGI then
        Ability.CastNoTarget(pt)
        sm_next_time = now + interval
        sm_state = "TO_INT_STEP2"
    end

    return false
end

return script
