local ioHero = {reserved = {wisp_tether = true, wisp_tether_break = true, wisp_overcharge = true,
	wisp_relocate = true, wisp_spirits = true, wisp_spirits_in = true, wisp_spirits_out = true}}
local common = require("self_play.heroes.common")

function ioHero.locked(ctx)
	return ctx.heroState.relocate ~= nil
end

function ioHero.update(ctx, api, retreat)
	local state = ctx.heroState
	local trip = state.relocate
	if trip then
		if ctx.now > trip.expires or not trip.arrived and ctx.now > trip.started + 5 then state.relocate = nil; return false end
		if ctx.distance(ctx.position, ctx.home) < 900 then
			trip.arrived = trip.arrived or ctx.now
			if ctx.now > trip.arrived + 10.5 then
				local release = common.ability(ctx, api, "wisp_tether_break")
				if release then return api.cast(ctx, release, "none") end
			end
			ctx.mode = "Io: recover during Relocate"
			return ctx.stop()
		end
		if trip.arrived then state.relocate = nil; return false end
		ctx.mode = "Io: Relocate rescue pending"
		return true
	end
	local breakAbility = common.ability(ctx, api, "wisp_tether_break")
	local partner = breakAbility and common.visible(state.partner) and state.partner or nil
	if not breakAbility then
		local tether = common.ability(ctx, api, "wisp_tether")
		if tether then
			local best, bestScore
			for _, ally in ipairs(ctx.allies) do
				if ally ~= ctx.hero and common.visible(ally) and not NPC.IsIllusion(ally)
					and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) <= Ability.GetCastRange(tether)
					and not ctx.unsafePosition(Entity.GetAbsOrigin(ally)) then
					local score = NPC.GetTrueDamage(ally) + (NPC.IsAttacking(ally) and 100 or 0)
						+ (1 - Entity.GetHealth(ally) / Entity.GetMaxHealth(ally)) * 100
					if not bestScore or score > bestScore then best, bestScore = ally, score end
				end
			end
			if best and common.cast(ctx, api, tether, "target", best) then state.partner = best; return true end
		end
	end
	local relocate = common.ability(ctx, api, "wisp_relocate")
	if relocate and ctx.nearEnemies > 0 and (retreat and ctx.health < 0.28
		or partner and Entity.GetHealth(partner) < Entity.GetMaxHealth(partner) * 0.25)
		and ctx.distance(ctx.position, ctx.home) > 2500 then
		api.cast(ctx, relocate, "point", nil, ctx.home)
		state.relocate = {started = ctx.now, expires = ctx.now + 18}
		return true
	end
	local overcharge = common.ability(ctx, api, "wisp_overcharge")
	if overcharge and partner and (NPC.IsAttacking(partner) or Entity.GetHealth(partner) < Entity.GetMaxHealth(partner) * 0.65) then
		return api.cast(ctx, overcharge, "none")
	end
	local spirits = common.ability(ctx, api, "wisp_spirits")
	if spirits and common.enemy(ctx, 950) and not retreat then return api.cast(ctx, spirits, "none") end
	return false
end

return ioHero
