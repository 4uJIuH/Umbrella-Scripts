local axe = {reserved = {axe_berserkers_call = true, axe_culling_blade = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function axe.locked(ctx)
	return ctx.heroState.initiation and ctx.now < ctx.heroState.initiation.expires or false
end

function axe.update(ctx, api, retreat)
	local enemy = tactics.enemy(ctx, 1400)
	if not enemy then return false end
	local blade = NPC.GetAbility(ctx.hero, "axe_culling_blade")
	if blade and Entity.GetHealth(enemy) <= common.value(blade, "damage", 275) - 15
		and tactics.cast(ctx, api, "axe_culling_blade", "target", enemy) then return true end
	local call = NPC.GetAbility(ctx.hero, "axe_berserkers_call")
	if not call then return false end
	local radius = common.value(call, "radius", 315)
	local point = ctx.predict(enemy, Ability.GetCastPoint(call))
	if ctx.distance(ctx.position, point) < radius - 35 and not NPC.IsStunned(enemy)
		and (retreat or tactics.committed(ctx, enemy)) then
		if tactics.cast(ctx, api, "axe_berserkers_call", "none") then ctx.heroState.initiation = nil; return true end
	end
	if not retreat and tactics.committed(ctx, enemy) then
		ctx.target = enemy
		return tactics.blink(ctx, api, point, "axe_berserkers_call", radius - 35)
	end
	return false
end

return axe
