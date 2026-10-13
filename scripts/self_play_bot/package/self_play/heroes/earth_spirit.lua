local earth = {reserved = {earth_spirit_stone_caller = true, earth_spirit_boulder_smash = true,
	earth_spirit_geomagnetic_grip = true, earth_spirit_rolling_boulder = true, earth_spirit_magnetize = true, earth_spirit_petrify = true}}
local common = require("self_play.heroes.common")
local aim = require("self_play.heroes.aim")
local intent = require("self_play.intent")

function earth.locked(ctx)
	return ctx.heroState.stone ~= nil or ctx.heroState.roll ~= nil
end

local function stoneNear(ctx, point)
	for _, unit in ipairs(ctx.worldNPCs) do
		if common.visible(unit) and NPC.GetUnitName(unit) == "npc_dota_earth_spirit_stone" and Entity.GetOwner(unit) == ctx.hero
			and ctx.distance(point, Entity.GetAbsOrigin(unit)) < 160 then return unit end
	end
	return nil
end

local function rolling(ctx, api, ability, enemy, solution)
	ctx.heroState.roll = {ability = ability, target = enemy, started = ctx.now,
		ends = ctx.now + solution.ends + 0.1, origin = ctx.position, delay = common.value(ability, "delay", 0.6)}
	ctx.mode = "Earth Spirit: intercept with Rolling Boulder"
	return api.cast(ctx, ability, "point", nil, solution.position)
end

function earth.duringCast(ctx)
	local task = ctx.heroState.roll
	if not task then return false end
	if ctx.hardRetreat and ctx.now < task.started + task.delay then ctx.heroState.roll = nil; ctx.stop(); return true end
	if ctx.now > task.started + task.delay + 0.35 and ctx.distance(ctx.position, task.origin) < 30
		and not Ability.IsInAbilityPhase(task.ability) then
		ctx.heroState.roll = nil
		return false
	end
	local hit = common.visible(task.target) and NPC.IsStunned(task.target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(task.target)) < 250
	if ctx.now >= task.ends or hit and ctx.now > task.started + task.delay then
		ctx.heroState.roll = nil
		if not ctx.retreating and common.visible(task.target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(task.target)) < 500
			and not ctx.unsafePosition(Entity.GetAbsOrigin(task.target)) then intent.begin(ctx, task.target, "hero", false) end
		return false
	end
	ctx.mode = "Earth Spirit: complete roll before follow-up"
	return true
end

function earth.update(ctx, api, retreat)
	local state, enemy = ctx.heroState, common.enemy(ctx, 1400)
	if state.stone then
		local task = state.stone
		if ctx.now > task.expires or retreat or not common.visible(task.target) then state.stone = nil; return false end
		if stoneNear(ctx, task.position) then
			local ability = common.ability(ctx, api, task.spell)
			state.stone = nil
			if ability then
				if task.spell == "earth_spirit_rolling_boulder" then
					local solution = aim.roll(ctx, ability, task.target, true)
					if solution and solution.stone then return rolling(ctx, api, ability, task.target, solution) end
					return false
				end
				return api.cast(ctx, ability, "point", nil, task.spell == "earth_spirit_geomagnetic_grip" and task.position or ctx.predict(task.target, 0.3))
			end
		end
		return true
	end
	if common.items(ctx, api, enemy, retreat) then return true end
	local roll = common.ability(ctx, api, "earth_spirit_rolling_boulder")
	if retreat and roll then
		local point = ctx.toward(ctx.position, ctx.home, 750)
		if not ctx.unsafePosition(point) then
			return rolling(ctx, api, roll, nil, {position = point, ends = common.value(roll, "delay", 0.6)
				+ Ability.GetLevelSpecialValueFor(roll, "distance") * common.value(roll, "rock_distance_multiplier", 2) / common.value(roll, "rock_speed", 1600)})
		end
	end
	if retreat or not enemy then return false end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	local magnetize = common.ability(ctx, api, "earth_spirit_magnetize")
	if magnetize and distance < 320 then return api.cast(ctx, magnetize, "none") end
	local stone = common.ability(ctx, api, "earth_spirit_stone_caller")
	local magnetized = NPC.GetModifier(enemy, "modifier_earth_spirit_magnetize")
	if stone and magnetized and common.remaining(magnetized, ctx.now) < 1.5 and ctx.now >= (state.nextRefresh or 0) and distance < 1000 then
		state.nextRefresh = ctx.now + 4
		return api.cast(ctx, stone, "point", nil, Entity.GetAbsOrigin(enemy))
	end
	if roll and distance > 350 and ctx.health > 0.65 and ctx.nearEnemies <= ctx.nearAllies
		and ctx.now >= (state.nextRollAim or 0) then
		state.nextRollAim = ctx.now + 0.15
		local basic = aim.roll(ctx, roll, enemy, false)
		local boosted = aim.roll(ctx, roll, enemy, true)
		if boosted and boosted.stone then return rolling(ctx, api, roll, enemy, boosted) end
		if basic and not basic.stone then return rolling(ctx, api, roll, enemy, basic) end
		if boosted and stone and Ability.GetCurrentCharges(stone) >= 2 and ctx.now >= (state.nextStone or 0)
			and (ctx.intent and ctx.intent.target == enemy or NPC.IsStunned(enemy)) then
			local point = ctx.toward(ctx.position, boosted.position, 100)
			if GridNav.IsTraversable(point) then
				state.stone = {position = point, target = enemy, spell = "earth_spirit_rolling_boulder", expires = ctx.now + 1.2}
				state.nextStone = ctx.now + 2
				return api.cast(ctx, stone, "point", nil, point)
			end
		end
	end
	local grip = common.ability(ctx, api, "earth_spirit_geomagnetic_grip")
	local smash = common.ability(ctx, api, "earth_spirit_boulder_smash")
	if stone and (grip or smash) and ctx.now >= (state.nextStone or 0) and not NPC.IsStunned(enemy) then
		local spell = grip and distance > 350 and "earth_spirit_geomagnetic_grip" or smash and "earth_spirit_boulder_smash" or nil
		local point = spell == "earth_spirit_geomagnetic_grip" and ctx.predict(enemy, 0.4) or ctx.toward(ctx.position, Entity.GetAbsOrigin(enemy), 100)
		if spell and ctx.distance(ctx.position, point) <= Ability.GetCastRange(stone) and GridNav.IsTraversable(point) then
			state.stone, state.nextStone = {position = point, target = enemy, spell = spell, expires = ctx.now + 1.2}, ctx.now + 2
			return api.cast(ctx, stone, "point", nil, point)
		end
	end
	return false
end

return earth
