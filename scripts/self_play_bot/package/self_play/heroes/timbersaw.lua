local timber = {reserved = {shredder_timber_chain = true, shredder_chakram = true, shredder_chakram_2 = true,
	shredder_return_chakram = true, shredder_return_chakram_2 = true, shredder_flamethrower = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local aim = require("self_play.heroes.aim")

function timber.update(ctx, api, retreat)
	local enemy = tactics.enemy(ctx, 1500)
	ctx.heroState.chakrams = ctx.heroState.chakrams or {}
	for _, suffix in ipairs({"", "_2"}) do
		local task = ctx.heroState.chakrams[suffix]
		if task then
			local nearby = 0
			for _, unit in ipairs(ctx.enemies) do
				if common.visible(unit) and ctx.distance(task.position, Entity.GetAbsOrigin(unit)) < 260 then nearby = nearby + 1 end
			end
			if ctx.now > task.started + 0.8 and (nearby == 0 or retreat or NPC.GetMana(ctx.hero) < 120) then
				local used, cast = tactics.cast(ctx, api, "shredder_return_chakram" .. suffix, "none")
				if cast or ctx.now > task.started + 15 then ctx.heroState.chakrams[suffix] = nil end
				if used then return true end
			end
		end
	end
	if not enemy or not retreat and not tactics.committed(ctx, enemy) then return false end
	local chain = common.ability(ctx, api, "shredder_timber_chain")
	if chain then
		local range = Ability.GetCastRange(chain)
		local best, score
		for _, tree in ipairs(Trees.InRadius(ctx.position, range, true)) do
			if Tree.IsActive(tree) then
				local point = Entity.GetAbsOrigin(tree)
				local landing = ctx.toward(point, ctx.position, 80)
				local along, miss = aim.segment(ctx.position, point, ctx.predict(enemy, ctx.distance(ctx.position, point) / common.value(chain, "speed", 2200)))
				local useful = retreat and ctx.distance(landing, ctx.home) + 350 < ctx.distance(ctx.position, ctx.home)
					or not retreat and along > 0 and along < 1 and miss < common.value(chain, "radius", 225) - 35
				if useful and not ctx.unsafePosition(landing) and GridNav.IsTraversable(landing)
					and (retreat or tactics.safe(ctx, landing, 1.5)) then
					local value = retreat and ctx.distance(landing, ctx.home) or miss + ctx.distance(landing, Entity.GetAbsOrigin(enemy)) * 0.3
					if not score or value < score then best, score = point, value end
				end
			end
		end
		if best and tactics.cast(ctx, api, "shredder_timber_chain", "point", nil, best) then return true end
	end
	if retreat then return false end
	for _, suffix in ipairs({"", "_2"}) do
		local chakram = NPC.GetAbility(ctx.hero, "shredder_chakram" .. suffix)
		if chakram and not ctx.heroState.chakrams[suffix] then
			local point = tactics.point(ctx, chakram, enemy, common.value(chakram, "speed", 900))
			local used, cast = tactics.cast(ctx, api, "shredder_chakram" .. suffix, "point", nil, point)
			if cast then ctx.heroState.chakrams[suffix] = {position = point, started = ctx.now} end
			if used then return true end
		end
	end
	if ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 380 then
		local forward = Entity.GetRotation(ctx.hero):GetForward()
		local point = Entity.GetAbsOrigin(enemy)
		if (point.x - ctx.position.x) * forward.x + (point.y - ctx.position.y) * forward.y > 0 then
			return tactics.cast(ctx, api, "shredder_flamethrower", "none")
		end
	end
	return false
end

return timber
