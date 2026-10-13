local kez = {reserved = {kez_switch_weapons = true, kez_echo_slash = true, kez_grappling_claw = true,
	kez_falcon_rush = true, kez_shodo_sai = true, kez_shodo_sai_parry_cancel = true, kez_ravens_veil = true,
	kez_talon_toss = true, kez_raptor_dance = true, kez_kazurai_katana = true}}
local common = require("self_play.heroes.common")
local intent = require("self_play.intent")

function kez.locked(ctx)
	return ctx.heroState.combo ~= nil or ctx.now < (ctx.heroState.parryUntil or 0) or ctx.now < (ctx.heroState.echoAimUntil or 0)
end

local function aghanimCombo(ctx, api, enemy, retreat)
	local state, combo = ctx.heroState, ctx.heroState.combo
	local rush = NPC.GetAbility(ctx.hero, "kez_falcon_rush")
	if not combo then
		if retreat or not enemy or not NPC.HasScepter(ctx.hero) or ctx.health < 0.6 or ctx.nearEnemies > ctx.nearAllies
			or ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) > 525 or not rush or not Ability.IsHidden(rush)
			or Ability.GetCooldown(rush) > 0 or ctx.now < (state.nextCombo or 0) or not common.ability(ctx, api, "kez_switch_weapons") then return false end
		combo = {target = enemy, stage = "sai", expires = ctx.now + 5}
		state.combo, state.nextCombo = combo, ctx.now + 7
	end
	if retreat or ctx.now > combo.expires or not common.visible(combo.target) or ctx.unsafePosition(Entity.GetAbsOrigin(combo.target)) then state.combo = nil; return false end
	local target = combo.target
	if combo.stage == "sai" or combo.stage == "katana" then
		local desired = combo.stage == "sai" and "kez_falcon_rush" or "kez_echo_slash"
		local ability = NPC.GetAbility(ctx.hero, desired)
		if ability and not Ability.IsHidden(ability) and Ability.IsActivated(ability) then combo.stage = combo.stage == "sai" and "rush" or "echo"
		elseif not combo.switchIssued then
			local switch = common.ability(ctx, api, "kez_switch_weapons")
			if switch then
				api.cast(ctx, switch, "none")
				ctx.abilityAttempts.kez_switch_weapons = ctx.now + 0.15
				combo.switchIssued = true
				combo.switchAt = ctx.now
			else state.combo = nil; return false end
			return true
		else
			if ctx.now > combo.switchAt + 0.65 then state.combo = nil; return false end
			return true
		end
	end
	if combo.stage == "rush" then
		local ability = common.ability(ctx, api, "kez_falcon_rush")
		if not ability then state.combo = nil; return false end
		api.cast(ctx, ability, "none")
		combo.stage, combo.rushAt, combo.switchIssued = "confirmRush", ctx.now, nil
		return true
	end
	if combo.stage == "confirmRush" then
		if NPC.HasModifier(ctx.hero, "modifier_kez_falcon_rush") or Ability.GetCooldown(rush) > 0 then combo.stage = "katana"
		elseif ctx.now > combo.rushAt + 0.6 then state.combo = nil; return false end
		return true
	end
	if combo.stage == "echo" then
		local echo = common.ability(ctx, api, "kez_echo_slash")
		if not echo then state.combo = nil; return false end
		local point = ctx.predict(target, Ability.GetCastPoint(echo))
		local forward = Entity.GetRotation(ctx.hero):GetForward()
		local dx, dy = point.x - ctx.position.x, point.y - ctx.position.y
		if dx * forward.x + dy * forward.y > 0 and math.abs(dx * forward.y - dy * forward.x) < 150
			and ctx.distance(ctx.position, point) < common.value(echo, "katana_distance", 800) then
			state.combo = nil
			api.cast(ctx, echo, "none")
			intent.begin(ctx, target, "hero", true)
			return true
		end
		return common.face(ctx, target, "Kez: align Scepter Echo Slash")
	end
	return true
end

function kez.update(ctx, api, retreat)
	local state = ctx.heroState
	if ctx.now < (state.parryUntil or 0) then
		local cancel = common.ability(ctx, api, "kez_shodo_sai_parry_cancel")
		if ctx.hardRetreat and cancel then state.parryUntil = nil; return api.cast(ctx, cancel, "none") end
		ctx.mode = "Kez: finish parry"
		return true
	end
	local enemy = common.enemy(ctx, 1100)
	if aghanimCombo(ctx, api, enemy, retreat) then return true end
	if common.items(ctx, api, enemy, retreat) then return true end
	local echo = common.ability(ctx, api, "kez_echo_slash")
	local veil = common.ability(ctx, api, "kez_ravens_veil")
	if retreat and veil then return api.cast(ctx, veil, "none") end
	local switch = common.ability(ctx, api, "kez_switch_weapons")
	local hiddenToss = NPC.GetAbility(ctx.hero, "kez_talon_toss")
	local needSai = retreat or enemy and NPC.IsChannellingAbility(enemy)
	if switch and needSai and hiddenToss and Ability.IsHidden(hiddenToss) and Ability.GetCooldown(hiddenToss) <= 0
		and ctx.now >= (state.nextSwitch or 0) then
		state.nextSwitch = ctx.now + 2
		return api.cast(ctx, switch, "none")
	end
	if not enemy then return false end
	local position = Entity.GetAbsOrigin(enemy)
	local distance = ctx.distance(ctx.position, position)
	local toss = common.ability(ctx, api, "kez_talon_toss")
	if toss and not NPC.IsSilenced(enemy) and common.cast(ctx, api, toss, "target", enemy) then return true end
	local dance = common.ability(ctx, api, "kez_raptor_dance")
	if dance and distance < 350 and (ctx.health < 0.6 or ctx.nearEnemies >= 2 or NPC.IsStunned(enemy)) then
		return api.cast(ctx, dance, "none")
	end
	local parry = common.ability(ctx, api, "kez_shodo_sai")
	if parry and NPC.IsAttacking(enemy) and Hero.GetRecentDamage(ctx.hero) > 0 and distance < 600 then
		api.cast(ctx, parry, "point", nil, position)
		state.parryUntil = ctx.now + common.value(parry, "parry_duration", 1.5)
		return true
	end
	if retreat then return false end
	local impale = common.ability(ctx, api, "kez_kazurai_katana")
	if impale and common.cast(ctx, api, impale, "target", enemy) then return true end
	local claw = common.ability(ctx, api, "kez_grappling_claw")
	if claw and distance > 350 and ctx.health > 0.6 and ctx.nearEnemies <= ctx.nearAllies and not ctx.unsafePosition(position)
		and common.cast(ctx, api, claw, "target", enemy) then intent.begin(ctx, enemy, "hero", true); return true end
	local rush = common.ability(ctx, api, "kez_falcon_rush")
	if rush and distance < 700 and ctx.health > 0.55 then
		api.cast(ctx, rush, "none")
		intent.begin(ctx, enemy, "hero", true)
		return true
	end
	if echo and distance < common.value(echo, "katana_distance", 800) then
		local predicted = ctx.predict(enemy, Ability.GetCastPoint(echo))
		local forward = Entity.GetRotation(ctx.hero):GetForward()
		local dx, dy = predicted.x - ctx.position.x, predicted.y - ctx.position.y
		local ahead, lateral = dx * forward.x + dy * forward.y, math.abs(dx * forward.y - dy * forward.x)
		if ahead >= 0 and ahead < 800 and lateral < common.value(echo, "katana_radius", 200) - 35 then return api.cast(ctx, echo, "none") end
		if ctx.now >= (state.nextEchoAim or 0) then state.echoAimUntil, state.nextEchoAim = ctx.now + 0.6, ctx.now + 1.5 end
		if ctx.now < (state.echoAimUntil or 0) then return common.face(ctx, enemy, "Kez: aim Echo Slash") end
	end
	return false
end

return kez
