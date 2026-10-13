local hoodwink = {reserved = {hoodwink_acorn_shot = true, hoodwink_bushwhack = true,
	hoodwink_sharpshooter = true, hoodwink_sharpshooter_release = true, hoodwink_scurry = true}}
local common = require("self_play.heroes.common")

function hoodwink.treeAt(position, radius)
	for _, tree in ipairs(Trees.InRadius(position, radius, true)) do if Tree.IsActive(tree) then return tree end end
	for _, tree in ipairs(TempTrees.GetAll()) do
		if Entity.IsEntity(tree) and Tree.IsActive(tree) then
			local point = Entity.GetAbsOrigin(tree)
			if (point.x - position.x) ^ 2 + (point.y - position.y) ^ 2 <= radius ^ 2 then return tree end
		end
	end
	return nil
end

function hoodwink.locked(ctx)
	return ctx.heroState.shot ~= nil or ctx.heroState.treeSetup ~= nil
end

function hoodwink.update(ctx, api, retreat)
	local state, enemy = ctx.heroState, common.enemy(ctx, 1800)
	if state.shot then
		local shot = state.shot
		local release = common.ability(ctx, api, "hoodwink_sharpshooter_release")
		if ctx.now > shot.expires or not common.visible(shot.target) then state.shot = nil; return false end
		local point = ctx.predict(shot.target, ctx.distance(ctx.position, Entity.GetAbsOrigin(shot.target)) / 2200)
		local forward = Entity.GetRotation(ctx.hero):GetForward()
		local dx, dy = point.x - ctx.position.x, point.y - ctx.position.y
		local aligned = dx * forward.x + dy * forward.y > 0 and math.abs(dx * forward.y - dy * forward.x) < 90
		if release and aligned and (retreat or ctx.now >= shot.releaseAt) then state.shot = nil; return api.cast(ctx, release, "none") end
		return common.face(ctx, shot.target, "Hoodwink: aim charged shot")
	end
	if retreat then
		state.treeSetup = nil
		local scurry = common.ability(ctx, api, "hoodwink_scurry")
		return scurry and api.cast(ctx, scurry, "none") or false
	end
	if not enemy then state.treeSetup = nil; return false end
	if common.items(ctx, api, enemy, false) then return true end
	local bush = common.ability(ctx, api, "hoodwink_bushwhack")
	local acorn = common.ability(ctx, api, "hoodwink_acorn_shot")
	if bush then
		local delay = Ability.GetCastPoint(bush) + ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) / common.value(bush, "projectile_speed", 1300)
		local point = ctx.predict(enemy, delay)
		if ctx.distance(ctx.position, point) <= Ability.GetCastRange(bush) and not NPC.IsStunned(enemy) then
			if hoodwink.treeAt(point, common.value(bush, "trap_radius", 265) - 40) then
				state.treeSetup = nil
				return api.cast(ctx, bush, "point", nil, point)
			end
			if state.treeSetup and ctx.now < state.treeSetup.expires then ctx.mode = "Hoodwink: confirm Acorn tree"; return true end
			state.treeSetup = nil
			if acorn and ctx.distance(ctx.position, point) <= Ability.GetCastRange(acorn) then
				state.treeSetup = {expires = ctx.now + 1}
				return api.cast(ctx, acorn, "point", nil, point)
			end
		end
	end
	local shot = common.ability(ctx, api, "hoodwink_sharpshooter")
	if shot and ctx.nearEnemies <= ctx.nearAllies and ctx.health > 0.6 and NPC.IsStunned(enemy)
		and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) > 450 then
		local damage = common.value(shot, "max_damage", 600)
		local charge = common.value(shot, "max_charge_time", 3)
		local needed = math.min(charge, math.max(0.6, Entity.GetHealth(enemy) / math.max(1, damage * 0.7) * charge))
		state.shot = {target = enemy, releaseAt = ctx.now + needed, expires = ctx.now + charge + 1}
		return api.cast(ctx, shot, "point", nil, ctx.predict(enemy, needed))
	end
	return acorn and common.cast(ctx, api, acorn, "target", enemy) or false
end

return hoodwink
