local deward = {}
local vision = require("self_play.vision")
local combat = require("self_play.combat")
local awareness = require("self_play.awareness")
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities
local radius = tonumber(itemKV.item_ward_sentry.AbilityValues.true_sight_range)

local function ward(unit)
	if not unit or not Entity.IsEntity(unit) or not Entity.IsNPC(unit) or not Entity.IsAlive(unit) then return false end
	local name = NPC.GetUnitName(unit)
	return name == "npc_dota_observer_wards" or name == "npc_dota_sentry_wards"
end

local function safe(ctx, point)
	return not ctx.unsafePosition(point) and awareness.risk(ctx, point) < 60 and awareness.forecast(ctx, point) < 60
end

function deward.covered(ctx, position)
	for _, unit in ipairs(ctx.worldNPCs) do
		if ward(unit) and Entity.IsSameTeam(ctx.hero, unit) and NPC.GetUnitName(unit) == "npc_dota_sentry_wards"
			and ctx.distance(position, Entity.GetAbsOrigin(unit)) < radius - 100 then return true end
	end
	for _, entry in ipairs(ctx.dewardPlacements or {}) do
		if ctx.now < entry.expires and ctx.distance(position, entry.position) < radius - 100 then return true end
	end
	return false
end

function deward.find(ctx)
	if not ctx.settings.wards or ctx.retreating or not Entity.IsAlive(ctx.hero) then return nil end
	local best, nearest = nil, ctx.role >= 4 and 1800 or 1200
	local function consider(unit)
		if not ward(unit) or Entity.IsSameTeam(ctx.hero, unit) or Entity.IsDormant(unit) then return end
		local position = Entity.GetAbsOrigin(unit)
		local distance = ctx.distance(ctx.position, position)
		if distance < nearest and safe(ctx, position) and ctx.now >= ((ctx.dewardFailed or {})[Entity.GetIndex(unit)] or 0) then
			best, nearest = {unit = unit, position = position, id = Entity.GetIndex(unit)}, distance
		end
	end
	for _, unit in ipairs(ctx.worldNPCs) do consider(unit) end
	local detection = NPC.GetModifier(ctx.hero, "modifier_truesight")
	local caster = detection and Modifier.GetCaster(detection)
	if caster then consider(caster) end
	if not best and detection and not caster and ctx.now >= (ctx.nextDetectionProbe or 0) and safe(ctx, ctx.position) then
		local nearTower = false
		for _, tower in ipairs(ctx.towers) do
			if Entity.IsAlive(tower) and not Entity.IsSameTeam(ctx.hero, tower) and ctx.distance(ctx.position, Entity.GetAbsOrigin(tower)) < 1100 then nearTower = true end
		end
		if not nearTower and ctx.nearEnemies == 0 and not deward.covered(ctx, ctx.position) then
			best = {position = ctx.position, id = "detection", uncertain = true}
		end
	end
	return best
end

function deward.needed(ctx)
	local request = deward.find(ctx)
	return request and not (request.unit and NPC.IsVisible(request.unit)) and not deward.covered(ctx, request.position)
end

function deward.run(ctx)
	if ctx.intent or ctx.retreating or ctx.laneThreat and ctx.laneThreat.attacked
		or ctx.farmCandidate and ctx.farmCandidate.start < ctx.now + 0.35 then ctx.dewardTask = nil; return false end
	ctx.dewardFailed = ctx.dewardFailed or {}
	for id, expires in pairs(ctx.dewardFailed) do if expires <= ctx.now then ctx.dewardFailed[id] = nil end end
	ctx.dewardPlacements = ctx.dewardPlacements or {}
	for i = #ctx.dewardPlacements, 1, -1 do if ctx.now >= ctx.dewardPlacements[i].expires then table.remove(ctx.dewardPlacements, i) end end
	local task = ctx.dewardTask
	if task and (ctx.now > task.expires or task.unit and not ward(task.unit) or not safe(ctx, task.position)) then
		ctx.dewardFailed[task.id], ctx.dewardTask, task = ctx.now + 20, nil, nil
	end
	if not task then
		if ctx.now < (ctx.nextDewardSearch or 0) then return false end
		task = deward.find(ctx)
		if not task then ctx.nextDewardSearch = ctx.now + 0.3; return false end
		task.expires = ctx.now + 12
		ctx.dewardTask = task
	end
	if task.unit and not Entity.IsDormant(task.unit) and NPC.IsVisible(task.unit) then
		return ctx.attack(task.unit, "Remove enemy ward")
	end
	if deward.covered(ctx, task.position) then
		ctx.dewardTask = nil
		return false
	end
	local item = NPC.GetItem(ctx.hero, "item_ward_sentry", true) or NPC.GetItem(ctx.hero, "item_ward_dispenser", true)
	if not item or vision.sentries(item) <= 0 or not combat.ready(ctx, item, true) then ctx.dewardTask = nil; return false end
	if Ability.GetName(item) == "item_ward_dispenser" and Ability.GetToggleState(item) then
		Ability.Toggle(item, false, false, true)
		ctx.busyUntil = ctx.now + 0.2
		return true
	end
	local position = ctx.toward(task.position, ctx.position, math.min(500, radius * 0.5))
	if not GridNav.IsTraversable(position) or not safe(ctx, position) then ctx.dewardFailed[task.id] = ctx.now + 20; ctx.dewardTask = nil; return false end
	local blocked = false
	for _, tower in ipairs(ctx.towers) do
		if Entity.IsEntity(tower) and Entity.IsAlive(tower) and not Entity.IsSameTeam(ctx.hero, tower)
			and ctx.distance(position, Entity.GetAbsOrigin(tower)) < NPC.GetAttackRange(tower) + 400 then blocked = true end
	end
	if blocked then ctx.dewardFailed[task.id] = ctx.now + 20; ctx.dewardTask = nil; return false end
	local range = Ability.GetCastRange(item)
	if ctx.distance(ctx.position, position) > range - 25 then
		return ctx.move(ctx.toward(position, ctx.position, math.max(100, range - 60)), "Approach detection placement")
	end
	if combat.cast(ctx, item, "point", nil, position) then
		ctx.dewardPlacements[#ctx.dewardPlacements + 1] = {position = position, expires = ctx.now + 4}
		if task.uncertain then ctx.nextDetectionProbe = ctx.now + 120 end
		ctx.mode = "Reveal enemy ward with sentry"
		return true
	end
	return false
end

return deward
