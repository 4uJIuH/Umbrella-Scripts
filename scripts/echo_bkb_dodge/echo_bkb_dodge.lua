-- echo_bkb_dodge 1.2. Blink-triggered protection with fixed conditions.
-- Does not guarantee protection against an instant Blink + Echo combination.
local script = {}
local TRIGGER_RADIUS = 700
local CLUSTER_RADIUS = 700
local MIN_ALLIED_UNITS = 3
local tab = Menu.Create("Scripts", "Other", "echo_bkb_dodge")
local group = tab:Create("Защита"):Create("Echo Slam")
local enabled = group:Switch("Включить защиту", false)

local function read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

local function gameTime()
    return read(GameRules.GetGameTime) or 0
end

local clock = gameTime
local ok, chronos = pcall(require, "chronos")
if ok and type(chronos) == "table" and type(chronos.nanotime) == "function"
        and type(read(chronos.nanotime)) == "number" then
    clock = chronos.nanotime
end

local state = { active = false, errors = {} }

local function console(text)
    if Log and Log.Write then read(Log.Write, "[echo_bkb_dodge] " .. text) end
end

local function valid(entity)
    if not entity then return false end
    if Entities and Entities.Contains then return read(Entities.Contains, entity) == true end
    return true
end

local function hasState(hero, name)
    local value = Enum.ModifierState and Enum.ModifierState[name]
    if value == nil then return nil end
    return read(NPC.HasState, hero, value)
end

local function stop()
    state = { active = false, errors = {} }
end

local function start(hero)
    state = { active = true, hero = hero, startGame = gameTime(), errors = {},
        blinkHistory = {}, blinkParticles = {}, lastEcho = {}, nextAttempt = -math.huge }
end

local function protect(name, handler)
    return function(...)
        local success, err = pcall(handler, ...)
        if not success and not state.errors[name] then
            state.errors[name] = true
            console("CALLBACK ERROR " .. name .. ": " .. tostring(err))
        end
    end
end

enabled:SetCallback(function()
    if not enabled:Get() then stop() end
end)


local blinkItems = { "item_blink", "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink" }

local function position(unit)
    local p = read(Entity.GetAbsOrigin, unit)
    if p then return { x = p.x, y = p.y } end
end

local function distance(a, b)
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

local function enemyShaker(unit)
    return valid(unit) and read(NPC.GetUnitName, unit) == "npc_dota_hero_earthshaker"
        and read(Entity.GetTeamNum, unit) ~= read(Entity.GetTeamNum, state.hero)
        and read(NPC.IsIllusion, unit) == false and read(Entity.IsAlive, unit) == true
end

local function visibleEnemy(unit)
    return enemyShaker(unit)
        and read(Entity.IsDormant, unit) == false and read(NPC.IsVisible, unit) == true
end

local function countAllies(heroPos, shakerPos)
    local count, seen = 0, {}
    local function add(unit)
        if not valid(unit) or read(Entity.IsAlive, unit) ~= true then return end
        local id = read(Entity.GetIndex, unit)
        if not id or seen[id] then return end
        seen[id] = true
        if read(Entity.GetTeamNum, unit) ~= read(Entity.GetTeamNum, state.hero) then return end
        if read(NPC.IsStructure, unit) or read(NPC.IsWard, unit) or read(NPC.IsCourier, unit)
            or read(NPC.IsWaitingToSpawn, unit) then return end
        if hasState(unit, "MODIFIER_STATE_INVULNERABLE") or hasState(unit, "MODIFIER_STATE_OUT_OF_GAME") then return end
        -- Brood spiders need explicit recognition: IsCreep is not reliable for them.
        local name = read(NPC.GetUnitName, unit)
        local spider = name == "npc_dota_broodmother_spiderling" or name == "npc_dota_broodmother_spiderite"
        if unit ~= state.hero and not spider and read(NPC.IsHero, unit) ~= true and read(NPC.IsCreep, unit) ~= true then return end
        local p = position(unit)
        if p and distance(p, heroPos) <= CLUSTER_RADIUS and distance(p, shakerPos) <= TRIGGER_RADIUS then
            count = count + 1
        end
    end
    add(state.hero)
    for _, unit in pairs(read(NPCs.GetAll) or {}) do add(unit) end
    for _, unit in pairs(read(Heroes.GetAll) or {}) do add(unit) end
    return count
end

local function tryBlinkBKB(source, arrivalPos)
    if not enabled:Get() or not state.active or not visibleEnemy(source) then return end
    local now = gameTime()
    if now - state.startGame < 1 then return end
    local id = read(Entity.GetIndex, source)
    if not id then return end
    if state.lastEcho[id] and now - state.lastEcho[id] < 0.5 then return end
    state.lastEcho[id] = now -- Consume this Blink even when a condition fails; no delayed retries.
    local hero = state.hero
    local hp, sp = position(hero), arrivalPos or position(source)
    if not hp or not sp then return end
    local dist = distance(hp, sp)
    local echo = read(NPC.GetAbility, source, "earthshaker_echo_slam")
    local cd = echo and read(Ability.GetCooldown, echo)
    local level = echo and read(Ability.GetLevel, echo)
    local mana = read(NPC.GetMana, source)
    local count = countAllies(hp, sp)
    local reason
    if dist > TRIGGER_RADIUS then reason = "outside_trigger_distance"
    elseif now < state.nextAttempt then reason = "duplicate_command_guard"
    elseif read(Entity.IsAlive, hero) ~= true then reason = "hero_dead"
    elseif not echo or not level or level < 1 then reason = "echo_unlearned_or_unknown"
    elseif not cd or cd > 0 then reason = "echo_cooldown_or_unknown"
    elseif not mana or read(Ability.IsCastable, echo, mana) ~= true then reason = "echo_not_castable"
    end
    if not reason then
        if count < MIN_ALLIED_UNITS then reason = "not_enough_allied_units" end
    end
    if not reason then
        for _, key in ipairs({ "STUNNED", "MUTED", "HEXED", "INVULNERABLE", "OUT_OF_GAME", "DEBUFF_IMMUNE" }) do
            if hasState(hero, "MODIFIER_STATE_" .. key) then reason = key:lower(); break end
        end
    end
    local bkb = read(NPC.GetItem, hero, "item_black_king_bar", true)
    if not reason and not bkb then reason = "no_active_slot_bkb" end
    if not reason and read(Ability.IsCastable, bkb, read(NPC.GetMana, hero) or 0) ~= true then reason = "bkb_not_castable" end
    if reason then return end
    state.nextAttempt = now + 0.5
    -- Fast order priority does not bypass the game's command processing.
    Ability.CastNoTarget(bkb, false, false, true, "echo_bkb_dodge")
end

local function observeBlink()
    local now, seen = gameTime(), {}
    if state.lastGame and now < state.lastGame then
        state.blinkHistory, state.blinkParticles, state.lastEcho, state.startGame, state.nextAttempt = {}, {}, {}, now, -math.huge
    end
    state.lastGame = now
    for _, unit in pairs(read(Heroes.GetAll) or {}) do
        if visibleEnemy(unit) then
            local id, p = read(Entity.GetIndex, unit), position(unit)
            if id and p then
                seen[id] = true
                local previous = state.blinkHistory[id]
                local current = { pos = p, time = now, cds = {}, unit = unit }
                local usedBlink = false
                for _, name in ipairs(blinkItems) do
                    local item = read(NPC.GetItem, unit, name, true)
                    local cd = item and read(Ability.GetCooldown, item)
                    current.cds[name] = cd
                    -- Damage lockout alone is not a Blink. Require a substantial new
                    -- cooldown AND an abrupt displacement on consecutive visible samples.
                    local old = previous and previous.cds[name]
                    if cd and old and old <= 0.1 and cd > 3.1 then usedBlink = true end
                end
                state.blinkHistory[id] = current
                if previous and previous.unit == unit and now > previous.time and now - previous.time <= 0.2
                    and usedBlink and distance(p, previous.pos) >= 300 then
                    tryBlinkBKB(unit)
                end
            end
        end
    end
    for id in pairs(state.blinkHistory) do if not seen[id] then state.blinkHistory[id] = nil end end
end

local function blinkArrival(data)
    local name = tostring(data.fullName or data.name or ""):lower():gsub("\\", "/")
    name = (name:match("([^/]+)$") or name):gsub("%.vpcf_c$", ""):gsub("%.vpcf$", "")
    return name == "blink_dagger_end"
end

local function resolveBlinkSource(event)
    if enemyShaker(event.source) then return event.source end
    for _, unit in pairs(read(Heroes.GetAll) or {}) do
        local id = read(Entity.GetIndex, unit)
        if id and (id == event.entityId or id == event.modifierId) and enemyShaker(unit) then return unit end
    end
end

local function processBlinkParticle(index, fromUpdate)
    local event = state.blinkParticles[index]
    if not event then return end
    local age = clock() - event.created
    if age < 0 or age > 0.15 then
        state.blinkParticles[index] = nil
        return
    end
    local source = resolveBlinkSource(event)
    if not source or not visibleEnemy(source) then return end
    event.source = source
    -- Creation can precede both the entity's new position and its visibility update.
    -- CP0 is the landing effect's world position; never use the old origin at creation.
    if event.arrival then
        state.blinkParticles[index] = nil
        tryBlinkBKB(source, event.arrival)
    elseif fromUpdate then
        local p = position(source)
        if p and ((event.before and distance(p, event.before) >= 32) or not event.wasVisible) then
            state.blinkParticles[index] = nil
            tryBlinkBKB(source)
        end
    end
end

local function observePendingBlinks()
    for index in pairs(state.blinkParticles) do processBlinkParticle(index, true) end
end


script.OnUpdate = protect("OnUpdate", function()
    if not enabled:Get() then
        if state.active then stop() end
        return
    end
    local hero = Heroes.GetLocal()
    if not valid(hero) then stop(); return end
    if state.active and state.hero ~= hero then stop() end
    if not state.active then start(hero) end
    observeBlink()
    observePendingBlinks()
end)

script.OnParticleCreate = protect("OnParticleCreate", function(data)
    if not enabled:Get() or not state.active or not data or not blinkArrival(data) then return end
    local source
    if enemyShaker(data.entityForModifiers) then source = data.entityForModifiers
    elseif enemyShaker(data.entity) then source = data.entity end
    if data.index ~= nil then
        state.blinkParticles[data.index] = { source = source, created = clock(),
            entityId = data.entity_id, modifierId = data.entity_for_modifiers_id,
            before = source and position(source), wasVisible = source and visibleEnemy(source) or false }
    end
end)

local function updateBlinkPoint(data)
    if not enabled:Get() or not state.active or not data or data.controlPoint ~= 0 or not data.position then return end
    local event = state.blinkParticles[data.index]
    if not event then return end
    event.arrival = { x = data.position.x, y = data.position.y }
    processBlinkParticle(data.index, false)
end
script.OnParticleUpdate = protect("OnParticleUpdate", updateBlinkPoint)
script.OnParticleUpdateFallback = protect("OnParticleUpdateFallback", updateBlinkPoint)

script.OnGameEnd = protect("OnGameEnd", stop)
return script
