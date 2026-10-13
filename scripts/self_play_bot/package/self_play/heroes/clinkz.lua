local clinkz = {reserved = {clinkz_strafe = true, clinkz_wind_walk = true, clinkz_death_pact = true,
	clinkz_tar_bomb = true, clinkz_burning_barrage = true, clinkz_burning_army = true}}
local common = require("self_play.heroes.common")
local intent = require("self_play.intent")

function clinkz.update(ctx, api, retreat)
	local enemy = common.enemy(ctx, 1100)
	local walk = common.ability(ctx, api, "clinkz_wind_walk")
	if retreat and walk and not NPC.HasModifier(ctx.hero, "modifier_clinkz_wind_walk") then return api.cast(ctx, walk, "none") end
	if common.items(ctx, api, enemy, retreat) then return true end
	if retreat then return false end
	local pact = common.ability(ctx, api, "clinkz_death_pact")
	if pact and ctx.now >= (ctx.heroState.pactUntil or 0) and (not enemy or ctx.health < 0.6) then
		local candidate, best = nil, -1
		for _, list in ipairs({ctx.neutrals, ctx.creeps}) do
			for _, creep in ipairs(list) do
				if common.visible(creep) and not NPC.IsAncient(creep) and not Entity.IsSameTeam(ctx.hero, creep)
					and NPC.GetCurrentLevel(creep) <= common.value(pact, "creep_level", 4)
					and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) <= Ability.GetCastRange(pact)
					and api.allowed(ctx, pact, creep) and Entity.GetHealth(creep) > best then candidate, best = creep, Entity.GetHealth(creep) end
			end
		end
		if candidate then ctx.heroState.pactUntil = ctx.now + 38; return api.cast(ctx, pact, "target", candidate) end
	end
	if not enemy then return false end
	local tar = common.ability(ctx, api, "clinkz_tar_bomb")
	if tar and not NPC.HasModifier(enemy, "modifier_clinkz_tar_bomb_slow") and common.cast(ctx, api, tar, "target", enemy) then
		intent.begin(ctx, enemy, "hero", true)
		return true
	end
	local strafe = common.ability(ctx, api, "clinkz_strafe")
	if strafe and NPC.IsAttacking(ctx.hero) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= NPC.GetAttackRange(ctx.hero) + 150 then
		return api.cast(ctx, strafe, "none")
	end
	local barrage = common.ability(ctx, api, "clinkz_burning_barrage")
	if barrage and ctx.health > 0.65 and (NPC.IsStunned(enemy) or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED)) then
		local point = ctx.predict(enemy, 0.4)
		if ctx.distance(ctx.position, point) < common.value(barrage, "range", 850) then return api.cast(ctx, barrage, "point", nil, point) end
	end
	local army = common.ability(ctx, api, "clinkz_burning_army")
	if army and ctx.nearEnemies >= 2 and ctx.nearEnemies <= ctx.nearAllies then
		local start = ctx.toward(ctx.position, Entity.GetAbsOrigin(enemy), 350)
		local dx, dy = start.x - ctx.position.x, start.y - ctx.position.y
		return common.vector(ctx, api, army, start, Vector(start.x - dy, start.y + dx, start.z))
	end
	return false
end

return clinkz
