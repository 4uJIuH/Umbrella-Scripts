local vision = {}

function vision.responsible(ctx)
	return ctx.settings.wards and (ctx.role >= 4 or ctx.role == 2)
end

function vision.observers(item)
	if Ability.GetName(item) == "item_ward_observer" then return Item.GetCurrentCharges(item) end
	if Ability.GetName(item) == "item_ward_dispenser" then
		return Ability.GetToggleState(item) and Item.GetCurrentCharges(item) or Item.GetSecondaryCharges(item)
	end
	return 0
end

function vision.sentries(item)
	if Ability.GetName(item) == "item_ward_sentry" then return Item.GetCurrentCharges(item) end
	if Ability.GetName(item) == "item_ward_dispenser" then
		return Ability.GetToggleState(item) and Item.GetSecondaryCharges(item) or Item.GetCurrentCharges(item)
	end
	return 0
end

function vision.midCovered(ctx)
	for _, unit in ipairs(ctx.worldNPCs) do
		if Entity.IsEntity(unit) and Entity.IsAlive(unit) and Entity.IsSameTeam(ctx.hero, unit) and NPC.GetUnitName(unit) == "npc_dota_observer_wards"
			and ctx.distance(Entity.GetAbsOrigin(unit), Vector(0, 0, 0)) < 2200 then return true end
	end
	return false
end

function vision.needed(ctx)
	if not vision.responsible(ctx) or ctx.retreating or ctx.recovering or not Entity.IsAlive(ctx.hero) then return false end
	local anchor = ctx.role == 2 and ctx.clock < 1200 and Vector(0, 0, 0)
		or ctx.teamTask and ctx.teamTask.goal or ctx.waveAnchor or ctx.position
	if ctx.distance(anchor, ctx.home) < 3000 or ctx.distance(ctx.position, anchor) > 2800 then return false end
	for _, unit in ipairs(ctx.worldNPCs) do
		if Entity.IsEntity(unit) and Entity.IsAlive(unit) and Entity.IsSameTeam(ctx.hero, unit) and NPC.GetUnitName(unit) == "npc_dota_observer_wards"
			and ctx.distance(Entity.GetAbsOrigin(unit), anchor) < 1600 then return false end
	end
	for _, ward in ipairs(ctx.placedWards or {}) do
		if ctx.now - ward.time < 330 and ctx.distance(ward.position, anchor) < 1600 then return false end
	end
	return true
end

return vision
