local sniper = {}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local awareness = require("self_play.awareness")

sniper.reserved = {sniper_shrapnel = true, sniper_assassinate = true, sniper_take_aim = true,
	sniper_take_aim_stop = true, sniper_concussive_grenade = true}

local function available(ctx, api, name)
	local ability = NPC.GetAbility(ctx.hero, name)
	return ability and (ctx.abilityAttempts[name] or 0) <= ctx.now and api.ready(ctx, ability, false) and ability or nil
end

local function protected(enemy)
	return NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
end

function sniper.covered(ctx, point, radius)
	local zones = ctx.heroState.shrapnelZones or {}
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if ctx.now >= zone.expires then table.remove(zones, index)
		elseif ctx.distance(point, zone.position) < math.min(radius, zone.radius) * 1.15 then return true end
	end
	return false
end

function sniper.assassinate(ctx, api)
	local ability = available(ctx, api, "sniper_assassinate")
	if not ability or ctx.retreating or ctx.hardRetreat then return false end
	local point = Ability.GetCastPoint(ability)
	if awareness.damage(ctx, ctx.position, point + 0.4) + awareness.forecast(ctx, ctx.position) > Entity.GetHealth(ctx.hero) * 0.18 then return false end
	local best, bestHealth
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.IsIllusion(enemy) and not protected(enemy) and api.allowed(ctx, ability, enemy)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= Ability.GetCastRange(ability) then
			local delay = point + ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) / common.value(ability, "projectile_speed", 2500)
			local damage = common.value(ability, "damage", 0) * NPC.GetMagicalArmorDamageMultiplier(enemy)
			local barriers = NPC.GetBarriers(enemy)
			local health = Entity.GetHealth(enemy) + math.max(0, NPC.GetHealthRegen(enemy)) * delay + 15
			if barriers then health = health + (barriers.magical and barriers.magical.current or 0) + (barriers.all and barriers.all.current or 0) end
			local secured = 0
			for _, shot in pairs(ctx.projectiles or {}) do
				if shot.target == enemy and shot.impact > ctx.now and shot.impact < ctx.now + delay then secured = secured + shot.damage end
			end
			if damage >= health and secured < Entity.GetHealth(enemy) and (not bestHealth or health < bestHealth) then best, bestHealth = enemy, health end
		end
	end
	if best then return tactics.cast(ctx, api, "sniper_assassinate", "target", best) end
	return false
end

function sniper.update(ctx, api, retreat)
	if api.busy(ctx) then return false end
	local enemy = tactics.enemy(ctx, 1800)
	local stop = available(ctx, api, "sniper_take_aim_stop")
	if stop and (retreat or enemy and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 450) then return api.cast(ctx, stop, "none") end
	if not enemy and sniper.assassinate(ctx, api) then return true end
	if not enemy or protected(enemy) then return false end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	local grenade = available(ctx, api, "sniper_concussive_grenade")
	if grenade and distance < 350 and (retreat or ctx.laneThreat and ctx.laneThreat.attacked)
		and not ctx.unsafePosition(ctx.toward(ctx.position, ctx.home, 450)) then
		return tactics.cast(ctx, api, "sniper_concussive_grenade", "point", enemy, Entity.GetAbsOrigin(enemy))
	end
	if sniper.assassinate(ctx, api) then return true end
	local committed = retreat or tactics.committed(ctx, enemy)
	local shrapnel = available(ctx, api, "sniper_shrapnel")
	if committed and shrapnel and ctx.now >= (ctx.heroState.nextShrapnel or 0)
		and NPC.GetMana(ctx.hero) - Ability.GetManaCost(shrapnel) >= NPC.GetMaxMana(ctx.hero) * (ctx.settings.manaReserve or 22) / 100 then
		local delay = Ability.GetCastPoint(shrapnel) + common.value(shrapnel, "damage_delay", 1.2)
		local radius = common.value(shrapnel, "radius", 400)
		local point = ctx.predict(enemy, delay)
		if retreat then point = ctx.toward(point, ctx.position, radius * 0.3) end
		if not sniper.covered(ctx, point, radius) and not NPC.HasModifier(enemy, "modifier_sniper_shrapnel_slow") then
			local acted, casted = tactics.cast(ctx, api, "sniper_shrapnel", "point", enemy, point)
			if casted then
				ctx.heroState.shrapnelZones = ctx.heroState.shrapnelZones or {}
				ctx.heroState.shrapnelZones[#ctx.heroState.shrapnelZones + 1] = {position = point, radius = radius,
					expires = ctx.now + delay + common.value(shrapnel, "duration", 10)}
				ctx.heroState.nextShrapnel = ctx.now + math.max(3, delay + 1)
			end
			if acted then return true end
		end
	end
	local aim = available(ctx, api, "sniper_take_aim")
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	if not retreat and aim and committed and distance > 450 and distance <= range - 30
		and not NPC.HasModifier(ctx.hero, "modifier_sniper_take_aim") and not ctx.unsafePosition(ctx.position)
		and awareness.damage(ctx, ctx.position, 2) < Entity.GetHealth(ctx.hero) * 0.12 then
		return tactics.cast(ctx, api, "sniper_take_aim", "none", enemy)
	end
	return false
end

return sniper
