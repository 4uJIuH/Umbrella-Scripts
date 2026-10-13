local invoker = {reserved = {invoker_quas = true, invoker_wex = true, invoker_exort = true, invoker_invoke = true, item_meteor_hammer = true}}
local common = require("self_play.heroes.common")
local spellPolicy = require("self_play.spell_policy")
local intent = require("self_play.intent")
local engagement = require("self_play.engagement")
local awareness = require("self_play.awareness")
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities
local spells = {
	cold_snap = {recipe = {"quas", "quas", "quas"}, kind = "target"},
	ghost_walk = {recipe = {"quas", "quas", "wex"}, kind = "none"},
	ice_wall = {recipe = {"quas", "quas", "exort"}, kind = "none"},
	tornado = {recipe = {"quas", "wex", "wex"}, kind = "point"},
	emp = {recipe = {"wex", "wex", "wex"}, kind = "point", delay = 2.9, key = "delay"},
	alacrity = {recipe = {"wex", "wex", "exort"}, kind = "target"},
	chaos_meteor = {recipe = {"wex", "exort", "exort"}, kind = "point", delay = 1.3, key = "land_time"},
	sun_strike = {recipe = {"exort", "exort", "exort"}, kind = "point", delay = 1.7, key = "delay"},
	forge_spirit = {recipe = {"quas", "exort", "exort"}, kind = "none"},
	deafening_blast = {recipe = {"quas", "wex", "exort"}, kind = "point"},
}
for name in pairs(spells) do invoker.reserved["invoker_" .. name] = true end

function invoker.locked(ctx)
	return ctx.heroState.hammer ~= nil or ctx.heroState.invoke ~= nil or ctx.heroState.request ~= nil or ctx.heroState.pendingCast ~= nil
		or ctx.heroState.combo ~= nil and ctx.heroState.combo.executing
		or ctx.heroState.controlWindow ~= nil and ctx.now < ctx.heroState.controlWindow.expires
end

function invoker.skillPriority(ctx, name)
	if name == "invoker_wex" then return 230 end
	if name == "invoker_quas" then
		local quas = NPC.GetAbility(ctx.hero, name)
		return quas and Ability.GetLevel(quas) < 2 and 250 or 210
	end
	if name == "invoker_exort" then
		local exort = NPC.GetAbility(ctx.hero, name)
		return NPC.GetCurrentLevel(ctx.hero) >= 4 and exort and Ability.GetLevel(exort) == 0 and 350 or 50
	end
	return 0
end

local function active(ability)
	return ability and Ability.IsActivated(ability) and not Ability.IsHidden(ability)
end

local function available(ctx, api, name, target, prepare)
	for _, orbName in ipairs(spells[name].recipe) do
		local orb = NPC.GetAbility(ctx.hero, "invoker_" .. orbName)
		if not orb or Ability.GetLevel(orb) == 0 then return false end
	end
	local ability = NPC.GetAbility(ctx.hero, "invoker_" .. name)
	if not ability or Ability.GetCooldown(ability) > 0 or (ctx.abilityAttempts["invoker_" .. name] or 0) > ctx.now then return false end
	if not prepare and name ~= "ghost_walk" and name ~= "sun_strike" and not spellPolicy.allow(ctx, ability, target or ctx.target) then return false end
	if active(ability) then return api.ready(ctx, ability, false) end
	local invoke = common.ability(ctx, api, "invoker_invoke")
	return invoke ~= nil and NPC.GetMana(ctx.hero) >= Ability.GetManaCost(ability) + Ability.GetManaCost(invoke) + 40
end

local function areaRadius(ability, name)
	if name == "chaos_meteor" then return common.value(ability, "area_of_effect", 275) end
	if name == "emp" then return common.value(ability, "area_of_effect", 675) end
	return 0
end

local function castPosition(ctx, ability, name, point)
	if name == "sun_strike" then return point end
	local range = Ability.GetCastRange(ability)
	local distance = ctx.distance(ctx.position, point)
	if distance <= range then return point end
	if distance <= range + math.max(0, areaRadius(ability, name) - 50) then return ctx.toward(ctx.position, point, range) end
	return nil
end

local function trace(ctx, message)
	local events = ctx.heroState.invokerEvents or {}
	ctx.heroState.invokerEvents = events
	events[#events + 1] = string.format("%.2f %s", ctx.now, message)
	if #events > 16 then table.remove(events, 1) end
end

local function reject(ctx, reason)
	trace(ctx, (ctx.heroState.request and ctx.heroState.request.name or "combo") .. ": " .. reason)
	ctx.heroState.request, ctx.heroState.invoke = nil, nil
	return false
end

local function landing(target, now)
	local modifier = NPC.GetModifier(target, "modifier_invoker_tornado") or NPC.GetModifier(target, "modifier_eul_cyclone")
	return modifier and common.remaining(modifier, now) or 0
end

local function stunnedFor(ctx, target)
	if not NPC.IsStunned(target) then return 0 end
	local duration = 0
	for _, modifier in ipairs(NPC.GetModifiers(target)) do
		local enabled = Modifier.GetState(modifier)
		if ctx.planner.hasFlag(enabled, 2 ^ Enum.ModifierState.MODIFIER_STATE_STUNNED) then
			duration = math.max(duration, common.remaining(modifier, ctx.now))
		end
	end
	return duration
end

local function channelSafe(ctx, target, duration)
	if ctx.retreating or ctx.health < 0.65 or ctx.unsafePosition(ctx.position)
		or (ctx.creepPressure or 0) > 0 or Hero.GetRecentDamage(ctx.hero) > Entity.GetMaxHealth(ctx.hero) * 0.08 then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1100
			and (enemy ~= target or math.max(landing(enemy, ctx.now), stunnedFor(ctx, enemy)) < duration + 0.15) then return false end
	end
	for _, sighting in pairs(ctx.memory or {}) do
		if ctx.now - sighting.time > 0.3 and ctx.now - sighting.time < 4
			and ctx.distance(ctx.position, sighting.position) < 1200 then return false end
	end
	return true
end

function invoker.duringCast(ctx, api)
	local task = ctx.heroState.hammer
	if not task or not task.issued or not Ability.IsChannelling(task.ability) then return false end
	task.channelStarted = Ability.GetChannelStartTime(task.ability)
	if ctx.hardRetreat or ctx.health < 0.4 or ctx.unsafePosition(ctx.position) then
		ctx.heroState.hammer, ctx.heroState.nextHammer, ctx.busyUntil = nil, ctx.now + 3, ctx.now
		ctx.mode = "Invoker: abandon unsafe Hammer channel"
		return ctx.stop()
	end
	ctx.mode = "Invoker: channel Meteor Hammer"
	return true
end

local function meteorHammer(ctx, api, retreat)
	local state, task = ctx.heroState, ctx.heroState.hammer
	if task and task.issued then
		if task.channelStarted then
			state.hammer, state.nextHammer = nil, ctx.now + 2
			if ctx.now >= task.channelStarted + task.channel - 0.15 and common.visible(task.target) and NPC.IsHero(task.target)
				and not ctx.hardRetreat and not ctx.unsafePosition(Entity.GetAbsOrigin(task.target)) then
				intent.begin(ctx, task.target, "hero", true)
				return true
			end
			return false
		end
		if ctx.now < task.expires then return true end
		state.hammer, state.nextHammer = nil, ctx.now + 3
		return false
	end
	if retreat then state.hammer = nil; return false end
	local hammer = common.ability(ctx, api, "item_meteor_hammer")
	if not hammer or ctx.now < (state.nextHammer or 0) then state.hammer = nil; return false end
	local channel = tonumber(itemKV.item_meteor_hammer.AbilityChannelTime)
	local impact = channel + common.value(hammer, "land_time", 0.5) + Ability.GetCastPoint(hammer) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
	local range, radius = Ability.GetCastRange(hammer), common.value(hammer, "impact_radius", 400)
	if NPC.GetMana(ctx.hero) - Ability.GetManaCost(hammer) < math.max(120, NPC.GetMaxMana(ctx.hero) * 0.25) then state.hammer = nil; return false end
	local target = task and task.target or ctx.target
	local point, label
	if common.visible(target) and NPC.IsHero(target) and not Entity.IsSameTeam(ctx.hero, target) then
		local lifted = landing(target, ctx.now)
		local remaining = math.max(lifted, stunnedFor(ctx, target))
		if ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > range or remaining < impact - 0.15
			or lifted > impact + 0.8 or not channelSafe(ctx, target, channel)
			or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
			or Entity.GetHealth(target) <= NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target) * 2 then
			state.hammer = nil
			return false
		end
		local wait = remaining + 0.08 - impact
		if lifted > 0 and wait > 0.03 then
			state.hammer = task or {target = target, expires = ctx.now + 1}
			if ctx.now > state.hammer.expires then state.hammer = nil; return false end
			ctx.mode = "Invoker: time Hammer after lift"
			return ctx.stop()
		end
		point, label = Entity.GetAbsOrigin(target), "Invoker: Hammer on landing"
	elseif not task and channelSafe(ctx, nil, channel) then
		local structure = ctx.intent and ctx.intent.kind == "structure" and ctx.intent.target
		if common.visible(structure) and ctx.pushSafe(structure)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(structure)) <= range
			and Entity.GetHealth(structure) > NPC.GetTrueDamage(ctx.hero) * 3 then
			local cover = 0
			for _, wave in ipairs(ctx.waves) do
				for _, creep in ipairs(wave) do
					if common.visible(creep) and not NPC.IsRanged(creep) and Entity.GetHealth(creep) > Entity.GetMaxHealth(creep) * 0.5
						and ctx.distance(Entity.GetAbsOrigin(creep), Entity.GetAbsOrigin(structure)) < 650 then cover = cover + 1 end
				end
			end
			if cover >= 3 then target, point, label = structure, Entity.GetAbsOrigin(structure), "Invoker: Hammer protected structure" end
		elseif ctx.clock >= 600 and ctx.role <= 3 and not ctx.intent and not ctx.clearTask and not ctx.teamTask then
			local units = {}
			for _, list in ipairs({ctx.creeps, ctx.neutrals}) do
				for _, creep in ipairs(list) do
					if common.visible(creep) and not Entity.IsSameTeam(ctx.hero, creep) and not NPC.IsAncient(creep)
						and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
						and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
						and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) <= range + radius then
						local history = ctx.history and ctx.history[Entity.GetIndex(creep)]
						local health = Entity.GetHealth(creep) - (history and history.rate or 0) * impact
						if health > 100 then units[#units + 1] = {unit = creep, position = ctx.predict(creep, impact), health = health} end
					end
				end
			end
			local best = 0
			for _, center in ipairs(units) do
				local candidate = ctx.toward(ctx.position, center.position, math.max(0, range - 25))
				local count, health = 0, 0
				for _, entry in ipairs(units) do
					if ctx.distance(candidate, entry.position) < radius - 60 then count, health = count + 1, health + entry.health end
				end
				if count >= 3 and health >= math.max(600, NPC.GetTrueDamage(ctx.hero) * 5)
					and health > best and not ctx.unsafePosition(candidate) then point, best = candidate, health end
			end
			if point then target, label = nil, "Invoker: Hammer creep group" end
		end
	end
	if not point then state.hammer = nil; return false end
	if api.cast(ctx, hammer, "point", nil, point) then
		state.hammer = {ability = hammer, target = target, issued = ctx.now, expires = ctx.now + Ability.GetCastPoint(hammer) + 0.7, channel = channel}
		ctx.mode = label
		return true
	end
	state.hammer = nil
	return false
end

local function request(ctx, name, target)
	ctx.heroState.orbSequence = nil
	ctx.heroState.request = {name = name, target = target, expires = ctx.now + 3.5}
	return true
end

local function sunStrikeWorth(ctx, ability, target, preparation)
	if not common.visible(target) or not NPC.IsHero(target) or NPC.IsIllusion(target)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then return false end
	local delay = common.value(ability, "delay", 1.7) + Ability.GetCastPoint(ability) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) + (preparation or 0)
	local lift = landing(target, ctx.now)
	local control = awareness.control(ctx, target)
	local fixed = math.max(stunnedFor(ctx, target), control[Enum.ModifierState.MODIFIER_STATE_ROOTED] or 0)
	local track = ctx.heroState.sunTracks and ctx.heroState.sunTracks[Entity.GetIndex(target)]
	local stationary = track and ctx.now - track.stillSince >= 1 and not NPC.IsRunning(target) and track.speed < 20
	local running = track and NPC.IsRunning(target) and ctx.now - track.stableSince >= 1.5 and track.speed > 40
	local forward = Entity.GetRotation(target):GetForward()
	if running then
		local measured = math.sqrt(track.dx * track.dx + track.dy * track.dy)
		running = measured > 40 and (track.dx * forward.x + track.dy * forward.y) / measured >= 0.85
	end
	if lift < delay - 0.18 and fixed < delay - 0.18 and not stationary and not running then return false end
	if NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) and lift == 0 then return false end
	local exort = NPC.GetAbility(ctx.hero, "invoker_exort")
	local damage = common.value(ability, "damage", Ability.GetDamage(ability), exort and Ability.GetLevel(exort) or 1)
	local radius = common.value(ability, "area_of_effect", 175)
	local point = Entity.GetAbsOrigin(target)
	if running and math.max(lift, fixed) < delay - 0.18 then
		local speed = math.sqrt(track.dx * track.dx + track.dy * track.dy)
		local scale = math.min(1, NPC.GetMoveSpeed(target) / math.max(1, speed)) * math.max(0, delay - fixed)
		point = Vector(point.x + track.dx * scale, point.y + track.dy * scale, point.z)
		if not GridNav.IsTraversable(point) then return false end
		for step = 1, 3 do
			if not GridNav.IsTraversable(ctx.toward(Entity.GetAbsOrigin(target), point, ctx.distance(Entity.GetAbsOrigin(target), point) * step / 4)) then return false end
		end
	end
	local victims, seen = 1, {[target] = true}
	for _, list in ipairs({ctx.enemies, ctx.worldNPCs or {}, ctx.creeps, ctx.neutrals}) do
		for _, unit in ipairs(list) do
			if not seen[unit] and common.visible(unit) and not Entity.IsSameTeam(ctx.hero, unit)
				and not NPC.IsStructure(unit) and not NPC.IsWard(unit)
				and ctx.distance(ctx.predict(unit, delay), point) < radius then
				seen[unit], victims = true, victims + 1
			end
		end
	end
	local expected = damage / victims
	local barriers = NPC.GetBarriers(target)
	local health = Entity.GetHealth(target) + NPC.GetHealthRegen(target) * delay + (barriers and barriers.all.current or 0)
	local motion = ctx.history and ctx.history[Entity.GetIndex(target)]
	if motion and (motion.rate or 0) * delay > Entity.GetHealth(target) * 0.9 then return false end
	local followup = ctx.intent and ctx.intent.target == target or ctx.heroState.combo and ctx.heroState.combo.target == target and ctx.heroState.combo.executing
		or ctx.heroState.controlWindow and ctx.heroState.controlWindow.target == target and ctx.now < ctx.heroState.controlWindow.expires
	local worth = expected >= health * ((stationary or running) and fixed < delay and lift < delay and 1.12 or 1.05)
		or followup and expected >= health * 0.3 and math.max(lift, fixed) >= delay - 0.18
	return worth, point, expected
end

local function trackSunTargets(ctx)
	local state = ctx.heroState
	if state.sunSampleAt == ctx.now then return end
	state.sunSampleAt = ctx.now
	local tracks = state.sunTracks or {}
	state.sunTracks = tracks
	for id, track in pairs(tracks) do if ctx.now - track.seen > 3 then tracks[id] = nil end end
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) then
			local id, position = Entity.GetIndex(enemy), Entity.GetAbsOrigin(enemy)
			local track, speed = tracks[id], NPC.GetMoveSpeed(enemy)
			local dt = track and ctx.now - track.seen or 0
			local gap = not track or dt < 0 or dt > 0.75
				or ctx.distance(track.position, position) > math.max(80, speed * dt * 1.5)
			if gap then
				track = {samples = {}, stillSince = ctx.now, stableSince = ctx.now, vx = 0, vy = 0, speed = 0,
					motionPosition = Vector(position.x, position.y, position.z), motionTime = ctx.now}
				tracks[id] = track
			end
			local motionDt = ctx.now - track.motionTime
			if motionDt > 0.001 and ctx.distance(track.motionPosition, position) > 2 and not gap then
				local vx, vy = (position.x - track.motionPosition.x) / motionDt, (position.y - track.motionPosition.y) / motionDt
				local measured = math.sqrt(vx * vx + vy * vy)
				local moving = NPC.IsRunning(enemy) and measured > 20
				if moving then
					local agreement = track.speed > 20 and (vx * track.vx + vy * track.vy) / (measured * track.speed) or 0
					local ratio = track.speed > 20 and measured / track.speed or 1
					if agreement < 0.94 or ratio < 0.55 or ratio > 1.65 then track.stableSince = ctx.now end
					track.stillSince = ctx.now
				else
					track.stableSince = ctx.now
					if measured > 20 then track.stillSince = ctx.now end
				end
				track.vx, track.vy, track.speed = vx, vy, measured
				track.motionPosition, track.motionTime = Vector(position.x, position.y, position.z), ctx.now
			elseif motionDt > 0.16 then
				track.vx, track.vy, track.speed, track.stableSince = 0, 0, 0, ctx.now
			end
			if NPC.IsRunning(enemy) then track.stillSince = ctx.now end
			track.samples[#track.samples + 1] = {position = Vector(position.x, position.y, position.z), time = ctx.now}
			while #track.samples > 2 and (#track.samples > 18 or ctx.now - track.samples[1].time > 0.7) do table.remove(track.samples, 1) end
			local first = track.samples[1]
			local span = ctx.now - first.time
			track.dx, track.dy = span > 0 and (position.x - first.position.x) / span or 0, span > 0 and (position.y - first.position.y) / span or 0
			track.position, track.seen = Vector(position.x, position.y, position.z), ctx.now
		end
	end
end

function invoker.background(ctx, api)
	trackSunTargets(ctx)
	local state = ctx.heroState
	local moving = NPC.IsRunning(ctx.hero)
	state.walkingSince = moving and (state.walkingSince or ctx.now) or nil
	if invoker.locked(ctx) or NPC.IsChannellingAbility(ctx.hero) or NPC.IsSilenced(ctx.hero) or NPC.IsStunned(ctx.hero)
		or ctx.now < (ctx.busyUntil or 0) then state.orbSequence = nil; return end
	local quas, wex, exort = NPC.GetAbility(ctx.hero, "invoker_quas"), NPC.GetAbility(ctx.hero, "invoker_wex"), NPC.GetAbility(ctx.hero, "invoker_exort")
	local desired = ctx.health <= 0.7 and quas and Ability.GetLevel(quas) > 0 and "quas"
		or NPC.IsAttacking(ctx.hero) and exort and Ability.GetLevel(exort) > 0 and "exort"
		or moving and ctx.now - state.walkingSince >= 0.3 and wex and Ability.GetLevel(wex) > 0 and "wex" or nil
	local orb = desired and NPC.GetAbility(ctx.hero, "invoker_" .. desired)
	if not orb or not api.ready(ctx, orb, false) then state.orbSequence = nil; return end
	local sequence = state.orbSequence
	if sequence and sequence.name ~= desired then sequence = nil; state.orbSequence = nil end
	if not sequence then
		if ctx.now < (state.nextOrbs or 0) then return end
		local count = 0
		for _, modifier in ipairs(NPC.GetModifiers(ctx.hero)) do
			if Modifier.GetName(modifier) == "modifier_invoker_" .. desired .. "_instance" then count = count + 1 end
		end
		if count >= 3 then return end
		sequence = {name = desired, remaining = 3, nextOrder = ctx.now}
		state.orbSequence = sequence
	end
	if ctx.now < sequence.nextOrder then return end
	Ability.CastNoTarget(orb, false, false, true, "self_play_orbs")
	sequence.remaining, sequence.nextOrder = sequence.remaining - 1, ctx.now + 0.04
	if sequence.remaining == 0 then state.orbSequence, state.nextOrbs = nil, ctx.now + 0.75 end
end

local function globalSun(ctx, api)
	local ability = NPC.GetAbility(ctx.hero, "invoker_sun_strike")
	if not ability or not available(ctx, api, "sun_strike") or ctx.health < 0.55
		or ctx.laneThreat and ctx.laneThreat.attacked or ctx.unsafePosition(ctx.position)
		or NPC.GetMana(ctx.hero) - Ability.GetManaCost(ability) < NPC.GetMaxMana(ctx.hero) * 0.2 then return false end
	local preparation = active(ability) and 0 or 0.3 + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
	local best, score
	for _, target in ipairs(ctx.enemies) do
		local worth, _, damage = sunStrikeWorth(ctx, ability, target, preparation)
		if worth then
			local value = damage / math.max(1, Entity.GetHealth(target))
			if not score or value > score then best, score = target, value end
		end
	end
	if not best then return false end
	request(ctx, "sun_strike", best)
	ctx.heroState.request.global = ctx.distance(ctx.position, Entity.GetAbsOrigin(best)) > 1100
	ctx.mode = "Invoker: prepare cross-map Sun Strike"
	return true
end

function invoker.finish(ctx, api)
	local ability = NPC.GetAbility(ctx.hero, "invoker_sun_strike")
	if not ability or not available(ctx, api, "sun_strike") or NPC.IsSilenced(ctx.hero) or NPC.IsStunned(ctx.hero)
		or ctx.health < 0.3 or ctx.unsafePosition(ctx.position) then return nil end
	local preparation = active(ability) and 0 or 0.3 + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
	for _, target in ipairs(ctx.enemies) do
		local worth, point, damage = sunStrikeWorth(ctx, ability, target, preparation)
		if worth and damage >= Entity.GetHealth(target) * 1.1 then
			local delay = common.value(ability, "delay", 1.7) + Ability.GetCastPoint(ability)
			local wait = math.max(0, landing(target, ctx.now) - delay - preparation)
			local issuing = preparation + wait + Ability.GetCastPoint(ability) + 0.3
			local incoming = awareness.damage(ctx, ctx.position, issuing) + awareness.forecast(ctx, ctx.position) * math.min(1, issuing / 4)
			for _, projectile in pairs(ctx.projectiles or {}) do
				if projectile.target == ctx.hero and projectile.impact >= ctx.now and projectile.impact <= ctx.now + issuing then incoming = incoming + projectile.damage end
			end
			if issuing < 2.5 and incoming < Entity.GetHealth(ctx.hero) * 0.35 then return {target = target, position = point, damage = damage, issuing = issuing} end
		end
	end
	return nil
end

function invoker.opportunity(ctx, api)
	if invoker.locked(ctx) or ctx.retreating or api.busy(ctx) or ctx.now < (ctx.heroState.nextGlobalSun or 0) then return false end
	ctx.heroState.nextGlobalSun = ctx.now + 0.15
	trackSunTargets(ctx)
	return globalSun(ctx, api)
end

local function execute(ctx, api, task, retreat)
	local name, state = task.name, ctx.heroState
	local definition, target = spells[name], task.target
	if ctx.now > task.expires or retreat and name ~= "ghost_walk" or not retreat and name == "ghost_walk"
		or not task.prepareOnly and name ~= "ghost_walk" and (not common.visible(target)
			or name ~= "sun_strike" and (ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > 1400
				or ctx.unsafePosition(ctx.position))) then
		state.request, state.invoke = nil, nil
		return false
	end
	local ability = NPC.GetAbility(ctx.hero, "invoker_" .. name)
	if not ability or not task.prepareOnly and name ~= "ghost_walk" and (name ~= "sun_strike" and not spellPolicy.allow(ctx, ability, target)
		or name == "sun_strike" and not sunStrikeWorth(ctx, ability, target, active(ability) and 0 or 0.3)) then
		state.request, state.invoke = nil, nil
		return false
	end
	if not active(ability) then
		local sequence = state.invoke
		if not sequence then
			if not available(ctx, api, name, target, task.prepareOnly) then state.request = nil; return false end
			sequence = {name = name, step = 1, nextOrder = ctx.now, expires = ctx.now + 1.5}
			state.invoke = sequence
		end
		if ctx.now > sequence.expires then
			state.request, state.invoke = nil, nil
			ctx.abilityAttempts["invoker_" .. name] = ctx.now + 2
			return false
		end
		if ctx.now < sequence.nextOrder then return true end
		if sequence.step <= 3 then
			local orb = NPC.GetAbility(ctx.hero, "invoker_" .. definition.recipe[sequence.step])
			if not api.ready(ctx, orb, false) then state.request, state.invoke = nil, nil; return false end
			api.cast(ctx, orb, "none")
			ctx.busyUntil = ctx.now + 0.035
			sequence.step, sequence.nextOrder = sequence.step + 1, ctx.now + 0.035
		elseif sequence.step == 4 then
			local invoke = common.ability(ctx, api, "invoker_invoke")
			if not invoke then state.request, state.invoke = nil, nil; return false end
			api.cast(ctx, invoke, "none")
			sequence.step, sequence.nextOrder, sequence.expires = 5, ctx.now + 0.06, ctx.now + 0.65
		end
		ctx.mode = "Invoker: confirm " .. name
		return true
	end
	state.invoke = nil
	if task.prepareOnly then trace(ctx, name .. ": prepared slot"); state.request = nil; return true end
	if not api.ready(ctx, ability, false) then
		task.readySince = task.readySince or ctx.now
		if ctx.now - task.readySince < 0.3 and Ability.GetCooldown(ability) == 0 then
			ctx.mode = "Invoker: wait for spell activation"
			return true
		end
		return reject(ctx, "not executable after slot activation: " .. Ability.CanBeExecuted(ability))
	end
	local position = target and Entity.GetAbsOrigin(target) or ctx.position
	local distance = ctx.distance(ctx.position, position)
	local delay = definition.delay and common.value(ability, definition.key, definition.delay) or 0
	local latency, castPoint = NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING), Ability.GetCastPoint(ability)
	local lifted = target and landing(target, ctx.now) or 0
	if name == "tornado" or name == "deafening_blast" then
		delay = distance / math.max(1, common.value(ability, "travel_speed", name == "tornado" and 1000 or 1100))
	end
	if lifted > 0 then
		if name == "cold_snap" or name == "tornado" or name == "ice_wall" then state.request = nil; return false end
		if definition.delay or name == "deafening_blast" then
			local wait = lifted + 0.1 - delay - castPoint - latency
			if wait > 0.015 then ctx.mode = "Invoker: synchronize " .. name; return ctx.stop() end
			local margin = areaRadius(ability, name) - math.max(0, distance - Ability.GetCastRange(ability))
			if wait < -0.3 and margin < -wait * NPC.GetMoveSpeed(target) + 60 then return reject(ctx, "landing window expired") end
		end
	elseif target and NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then state.request = nil; return false end
	if name == "ice_wall" then
		if ctx.planner.hasFlag(Ability.GetBehavior(ability), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING) then state.request = nil; return false end
		local predicted = ctx.predict(target, castPoint + latency)
		local forward = Entity.GetRotation(ctx.hero):GetForward()
		local dx, dy = predicted.x - ctx.position.x, predicted.y - ctx.position.y
		local along, lateral = dx * forward.x + dy * forward.y, -dx * forward.y + dy * forward.x
		if math.abs(along - common.value(ability, "wall_place_distance", 200)) > common.value(ability, "wall_width", 105) - 25
			or math.abs(lateral) > common.value(ability, "wall_total_length", 1200) / 2 - 40 then state.request = nil; return false end
	end
	if name == "tornado" and (NPC.IsStunned(target) or NPC.HasModifier(target, "modifier_invoker_chaos_meteor_burn")) then state.request = nil; return false end
	if name == "ghost_walk" and NPC.HasModifier(ctx.hero, "modifier_invoker_ghost_walk_self") then state.request = nil; return false end
	if definition.kind == "point" then
		local predictionTime = delay + castPoint + latency
		if name == "emp" and state.combo then
			local tornado = NPC.GetAbility(ctx.hero, "invoker_tornado")
			predictionTime = math.max(0, predictionTime - common.value(tornado, "lift_duration", 1.2, state.combo.quas) - 0.1)
		end
		if name == "sun_strike" then
			local worth, aim = sunStrikeWorth(ctx, ability, target, 0)
			if not worth then state.request = nil; return false end
			position = aim
		elseif name == "emp" then
			local control = awareness.control(ctx, target)
			local fixed = math.max(stunnedFor(ctx, target), control[Enum.ModifierState.MODIFIER_STATE_ROOTED] or 0)
			local lead = math.min(0.8, math.max(0, predictionTime - fixed))
			if NPC.HasModifier(target, "modifier_invoker_cold_snap") then lead = math.min(lead, 0.35) end
			position = lifted > 0 and position or ctx.toward(position, ctx.predict(target, lead), common.value(ability, "area_of_effect", 675) * 0.45)
		else position = lifted > 0 and position or ctx.predict(target, predictionTime) end
		position = castPosition(ctx, ability, name, position)
		if not position then return reject(ctx, "target outside spell reach") end
	end
	state.request = nil
	if name == "alacrity" then target = ctx.hero end
	local globalCast = task.global
	local savedTarget = ctx.target
	if globalCast then ctx.target = nil end
	local casted = common.cast(ctx, api, ability, definition.kind, target, position)
	ctx.target = savedTarget
	if casted then
		trace(ctx, name .. ": cast at " .. (target and NPC.GetUnitName(target) or "self"))
		state.pendingCast = {name = name, time = ctx.now, target = target, expires = ctx.now + castPoint + 0.6}
		if state.combo then
			if name == "emp" then state.combo.empImpact, state.combo.empPosition = ctx.now + delay + castPoint + latency, position end
			if name == "tornado" then state.combo.tornadoArrival = ctx.now + delay + castPoint + latency end
		end
		if name == "tornado" then
			local quas = NPC.GetAbility(ctx.hero, "invoker_quas")
			local lift = common.value(ability, "lift_duration", 1.2, quas and Ability.GetLevel(quas) or 1)
			state.controlWindow = {target = target, arrival = ctx.now + delay + castPoint + latency, expires = ctx.now + delay + castPoint + latency + lift + 0.5}
		end
		ctx.mode = "Invoker: " .. name
	end
	return casted
end

function invoker.finishCast(ctx, api)
	local finish = ctx.spellFinish
	if not finish then return false end
	local state = ctx.heroState
	if not state.request or state.request.name ~= "sun_strike" or state.request.target ~= finish.target then
		state.request, state.invoke, state.combo, state.pendingCast = nil, nil, nil, nil
		request(ctx, "sun_strike", finish.target)
		state.request.global = ctx.distance(ctx.position, finish.position) > 1100
	end
	ctx.mode = "Invoker: secure controlled kill before disengaging"
	return execute(ctx, api, state.request, false)
end

local function comboUpdate(ctx, api, enemy)
	local state, combo = ctx.heroState, ctx.heroState.combo
	if not combo then
		if ctx.now < (state.nextCombo or 0) or ctx.health < 0.35
			or NPC.IsStunned(enemy) or NPC.HasModifier(enemy, "modifier_invoker_chaos_meteor_burn") then return false end
		local quas, wex, exort = NPC.GetAbility(ctx.hero, "invoker_quas"), NPC.GetAbility(ctx.hero, "invoker_wex"), NPC.GetAbility(ctx.hero, "invoker_exort")
		local q, w, e = quas and Ability.GetLevel(quas) or 0, wex and Ability.GetLevel(wex) or 0, exort and Ability.GetLevel(exort) or 0
		local tornado, emp = NPC.GetAbility(ctx.hero, "invoker_tornado"), NPC.GetAbility(ctx.hero, "invoker_emp")
		local meteor, sun = NPC.GetAbility(ctx.hero, "invoker_chaos_meteor"), NPC.GetAbility(ctx.hero, "invoker_sun_strike")
		if not tornado or not available(ctx, api, "tornado", enemy) then return false end
		local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
		local latency = NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
		local travel = distance / math.max(1, common.value(tornado, "travel_speed", 1000)) + Ability.GetCastPoint(tornado) + latency
		local lift = common.value(tornado, "lift_duration", 1.2, q)
		local invoke = NPC.GetAbility(ctx.hero, "invoker_invoke")
		local invokeWait = invoke and Ability.GetCooldown(invoke) or math.huge
		local function payloadReady(name, ability)
			if not ability or not available(ctx, api, name, enemy, true)
				or not castPosition(ctx, ability, name, Entity.GetAbsOrigin(enemy)) then return false end
			if active(ability) then return true end
			local prepare = math.max(0.2, invokeWait) + 0.3 + latency
			return active(tornado) and prepare + common.value(ability, spells[name].key, spells[name].delay) + Ability.GetCastPoint(ability) + latency <= travel + lift + 0.05
		end
		local sequence
		local sunDamage = sun and common.value(sun, "damage", Ability.GetDamage(sun), e) or 0
		if q >= 1 and e >= 1 and sunDamage >= Entity.GetHealth(enemy) * 1.1 and payloadReady("sun_strike", sun) then
			sequence = {"tornado", "sun_strike"}
		elseif e >= 2 and q >= 2 and payloadReady("chaos_meteor", meteor) then
			sequence = {"tornado", "chaos_meteor"}
		elseif w >= 2 and q >= 1 and emp and NPC.GetMana(enemy) > 180 and available(ctx, api, "emp", enemy) then
			if active(emp) and active(tornado) then sequence = {"emp", "tornado"}
			elseif payloadReady("emp", emp) then sequence = {"tornado", "emp"} end
		end
		if not sequence or not active(NPC.GetAbility(ctx.hero, "invoker_" .. sequence[1])) then return false end
		local mana = math.max(60, NPC.GetMaxMana(ctx.hero) * 0.12)
		for _, name in ipairs(sequence) do
			local ability = NPC.GetAbility(ctx.hero, "invoker_" .. name)
			mana = mana + Ability.GetManaCost(ability) + (not active(ability) and Ability.GetManaCost(invoke) or 0)
		end
		if NPC.GetMana(ctx.hero) < mana or awareness.damage(ctx, ctx.position, 0.8) > Entity.GetHealth(ctx.hero) * 0.3 then return false end
		combo = {target = enemy, steps = sequence, index = 1, expires = ctx.now + 8, quas = q, executing = true}
		state.combo = combo
	end
	if not common.visible(combo.target) or ctx.now > combo.expires or ctx.distance(ctx.position, Entity.GetAbsOrigin(combo.target)) > 1100 then
		state.combo, state.nextCombo = nil, ctx.now + 3
		return false
	end
	if not combo.executing then
		for _, name in ipairs(combo.steps) do
			local ability = NPC.GetAbility(ctx.hero, "invoker_" .. name)
			if not active(ability) then
				if available(ctx, api, name) then
					request(ctx, name, combo.target)
					state.request.prepareOnly = true
					return true
				end
				return false
			end
			if not api.ready(ctx, ability, false) then state.combo = nil; return false end
		end
		combo.executing = true
	end
	local name = combo.steps[combo.index]
	if not name and not combo.extended then
		combo.extended = true
		local previous = combo.steps[combo.index - 1]
		local followup = previous == "chaos_meteor" and "deafening_blast" or previous == "emp" and "cold_snap" or nil
		if followup and available(ctx, api, followup, combo.target)
			and NPC.GetMana(ctx.hero) - Ability.GetManaCost(NPC.GetAbility(ctx.hero, "invoker_" .. followup)) >= 60 then
			combo.steps[#combo.steps + 1], name = followup, followup
		end
	end
	if not name then state.combo, state.nextCombo = nil, ctx.now + 2; return false end
	if name == "tornado" and combo.empImpact then
		local ability = NPC.GetAbility(ctx.hero, "invoker_tornado")
		local travel = ctx.distance(ctx.position, Entity.GetAbsOrigin(combo.target)) / common.value(ability, "travel_speed", 1000)
		local lift = common.value(ability, "lift_duration", 1.2, combo.quas)
		local at = combo.empImpact - travel - lift - Ability.GetCastPoint(ability) - NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) - 0.1
		local impact = ctx.predict(combo.target, travel + Ability.GetCastPoint(ability))
		if combo.empPosition and ctx.distance(impact, combo.empPosition) > 550 then state.combo, state.nextCombo = nil, ctx.now + 4; return false end
		if ctx.now < at then ctx.mode = "Invoker: synchronize EMP and Tornado"; return ctx.stop() end
		if ctx.now > at + 0.35 then state.combo, state.nextCombo = nil, ctx.now + 4; return false end
	elseif (name == "chaos_meteor" or name == "sun_strike" or name == "emp") and combo.tornadoArrival and landing(combo.target, ctx.now) == 0 then
		if ctx.now < combo.tornadoArrival + 0.4 then
			local ability = NPC.GetAbility(ctx.hero, "invoker_" .. name)
			if not active(ability) and available(ctx, api, name, combo.target, true) then
				request(ctx, name, combo.target)
				state.request.prepareOnly = true
			end
			return true
		end
		trace(ctx, "combo: Tornado did not connect in its flight window")
		state.combo, state.nextCombo = nil, ctx.now + 4
		return false
	end
	if name == "emp" and combo.tornadoArrival then
		local ability = NPC.GetAbility(ctx.hero, "invoker_emp")
		local remaining = landing(combo.target, ctx.now)
		local delay = common.value(ability, "delay", 2.9) + Ability.GetCastPoint(ability) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
		if remaining + 0.2 < delay then state.combo, state.nextCombo = nil, ctx.now + 2; return false end
	end
	return request(ctx, name, combo.target)
end

local function prepare(ctx, api)
	if ctx.clock < 15 or ctx.health < 0.55 or ctx.retreating or ctx.laneThreat and ctx.laneThreat.attacked
		or ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.8 then return false end
	local exort = NPC.GetAbility(ctx.hero, "invoker_exort")
	local names = exort and Ability.GetLevel(exort) > 0 and {"sun_strike", "tornado"} or {"tornado", "emp"}
	for _, name in ipairs(names) do
		local ability = NPC.GetAbility(ctx.hero, "invoker_" .. name)
		if ability and not active(ability) and available(ctx, api, name, nil, true) then
			request(ctx, name)
			ctx.heroState.request.prepareOnly = true
			ctx.mode = "Invoker: prepare useful spell slot"
			return true
		end
	end
	return false
end

function invoker.update(ctx, api, retreat)
	local state = ctx.heroState
	trackSunTargets(ctx)
	local window = state.controlWindow
	if window and (retreat or ctx.now > window.expires or not common.visible(window.target)) then state.controlWindow, window = nil, nil end
	if state.hammer and meteorHammer(ctx, api, retreat) then return true end
	local pending = state.pendingCast
	if pending then
		local ability = NPC.GetAbility(ctx.hero, "invoker_" .. pending.name)
		if ability and (Ability.GetCooldown(ability) > 0 or Ability.SecondsSinceLastUse(ability) < ctx.now - pending.time + 0.1) then
			state.pendingCast = nil
			if state.combo and state.combo.steps[state.combo.index] == pending.name then state.combo.index = state.combo.index + 1 end
		elseif ctx.now <= pending.expires and not retreat then return true
		else state.pendingCast, state.combo = nil, nil; ctx.abilityAttempts["invoker_" .. pending.name] = ctx.now + 1 end
	end
	if state.request then
		local acted = execute(ctx, api, state.request, retreat)
		if not acted and not state.request then state.combo, state.nextCombo = nil, ctx.now + 3 end
		return acted
	end
	if retreat then
		state.combo = nil
		if not NPC.HasModifier(ctx.hero, "modifier_invoker_ghost_walk_self") and available(ctx, api, "ghost_walk") then return request(ctx, "ghost_walk") end
		return false
	end
	if not state.combo and globalSun(ctx, api) then return true end
	if not state.combo and meteorHammer(ctx, api, false) then return true end
	local target = state.combo and state.combo.target or window and window.target or ctx.target
	if not common.visible(target) or not NPC.IsHero(target) or Entity.IsSameTeam(ctx.hero, target) or ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > 1100
		or ctx.unsafePosition(ctx.position) or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then state.combo = nil; return prepare(ctx, api) end
	if not state.combo and common.items(ctx, api, target, false) then return true end
	if comboUpdate(ctx, api, target) then return true end
	if state.combo then return false end
	local lifted = landing(target, ctx.now)
	local control = awareness.control(ctx, target)
	local fixed = math.max(stunnedFor(ctx, target), control[Enum.ModifierState.MODIFIER_STATE_ROOTED] or 0)
	local controlled = lifted > 0 or fixed > 0.5 or NPC.HasModifier(target, "modifier_invoker_cold_snap")
	local cluster = 0
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), Entity.GetAbsOrigin(target)) < 350 then cluster = cluster + 1 end
	end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(target))
	local best, bestScore = nil, 0
	for _, name in ipairs({"cold_snap", "tornado", "emp", "chaos_meteor", "sun_strike", "deafening_blast", "alacrity", "forge_spirit", "ice_wall"}) do
		if available(ctx, api, name) then
			local ability, score = NPC.GetAbility(ctx.hero, "invoker_" .. name), 0
			if name == "cold_snap" and lifted == 0 and not NPC.HasModifier(target, "modifier_invoker_cold_snap") then score = 70
			elseif name == "tornado" and lifted == 0 and not controlled and not NPC.HasModifier(target, "modifier_invoker_chaos_meteor_burn") then
				if NPC.IsChannellingAbility(target) then score = 140
				elseif NPC.IsAttacking(target) and ctx.laneThreat and ctx.laneThreat.attacked then score = 110
				elseif ctx.intent and ctx.intent.kind == "hero" and (cluster >= 2 or NPC.IsRunning(target)) then score = 80 end
			elseif name == "emp" and NPC.GetMana(target) > 150 and (lifted > 1.6 or fixed > 2.4 or cluster >= 2 and not NPC.IsRunning(target)) then score = 85
			elseif name == "chaos_meteor" and (lifted > 1.2 or fixed > 1.2 or controlled and cluster >= 2) then score = 90
			elseif name == "sun_strike" and sunStrikeWorth(ctx, ability, target) then score = lifted > 0 and 180 or 80
			elseif name == "deafening_blast" and lifted == 0 and (NPC.IsAttacking(target) or NPC.IsChannellingAbility(target)
				or NPC.HasModifier(target, "modifier_invoker_chaos_meteor_burn")) then score = 75
			elseif name == "alacrity" and NPC.IsAttacking(ctx.hero) and not NPC.HasModifier(ctx.hero, "modifier_invoker_alacrity") then score = 45
			elseif name == "forge_spirit" and #ctx.summons == 0 and distance < 800 then score = 40
			elseif name == "ice_wall" and lifted == 0 and distance < 350 and active(ability) then score = 35 end
			if name ~= "alacrity" and spells[name].kind ~= "none" and not castPosition(ctx, ability, name, Entity.GetAbsOrigin(target)) then score = 0 end
			if spells[name].delay then
				local delay = common.value(ability, spells[name].key, spells[name].delay) + Ability.GetCastPoint(ability)
				local preparation = active(ability) and 0 or 0.35 + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
				if lifted > 0 and name ~= "emp" and lifted + 0.25 < delay + preparation then score = 0 end
			end
			if score > 0 and active(ability) then score = score + 8 end
			if score > bestScore then best, bestScore = name, score end
		end
	end
	if best then return request(ctx, best, target) end
	if window and (ctx.now < window.arrival + 0.3 or lifted > 0) then
		ctx.mode = "Invoker: retain target through Tornado control"
		return ctx.stop()
	end
	state.controlWindow = nil
	return false
end

return invoker
