local teleports = {}

local function enemy(ctx, unit)
	return unit and Entity.IsEntity(unit) and Entity.IsNPC(unit) and NPC.IsHero(unit)
		and not Entity.IsSameTeam(ctx.hero, unit) and not NPC.IsIllusion(unit)
end

function teleports.create(ctx, data)
	if not data.fullName:find("teleport_end", 1, true) then return end
	local owner = enemy(ctx, data.entityForModifiers) and data.entityForModifiers or enemy(ctx, data.entity) and data.entity
	if not owner and data.entity_for_modifiers_id >= 0 then
		local unit = Entity.Get(data.entity_for_modifiers_id)
		if enemy(ctx, unit) then owner = unit end
	end
	if not owner and data.entity_id >= 0 then
		local unit = Entity.Get(data.entity_id)
		if enemy(ctx, unit) then owner = unit end
	end
	if not owner then return end
	local now = GameRules.GetGameTime()
	ctx.teleportParticles = ctx.teleportParticles or {}
	ctx.teleportParticles[data.index] = {source = owner, created = now, arrival = now + 3, expires = now + 10}
end

function teleports.point(ctx, data)
	local record = ctx.teleportParticles and ctx.teleportParticles[data.index]
	if not record or data.controlPoint ~= 0 and data.controlPoint ~= 5 or data.controlPoint == 5 and record.controlPoint == 0 then return end
	record.position, record.controlPoint = data.position, data.controlPoint
	if data.controlPoint == 0 then record.target = nil end
end

function teleports.attach(ctx, data)
	local record = ctx.teleportParticles and ctx.teleportParticles[data.index]
	if not record or data.controlPoint ~= 5 or record.controlPoint == 0 or not data.entity
		or not Entity.IsEntity(data.entity) or data.entity == record.source or not Entity.IsSameTeam(record.source, data.entity) then return end
	record.target = data.entity
end

function teleports.destroy(ctx, data)
	local record = ctx.teleportParticles and ctx.teleportParticles[data.index]
	if not record then return end
	local now = GameRules.GetGameTime()
	if now < record.arrival - 0.25 then ctx.teleportParticles[data.index] = nil
	else record.expires, record.arrival = now + 1.5, now end
end

function teleports.update(ctx)
	ctx.teleportArrivals, ctx.incomingEnemies = {}, 0
	local seen = {}
	for id, record in pairs(ctx.teleportParticles or {}) do
		if ctx.now > record.expires or not Entity.IsEntity(record.source) or not Entity.IsAlive(record.source) then
			ctx.teleportParticles[id] = nil
		else
			if not Entity.IsDormant(record.source) and NPC.IsVisible(record.source) then
				local modifier = NPC.GetModifier(record.source, "modifier_teleporting")
				if modifier then record.arrival = Modifier.GetDieTime(modifier) end
			end
			if record.target and Entity.IsEntity(record.target) and not Entity.IsDormant(record.target) then
				record.position = Entity.GetAbsOrigin(record.target)
			end
			local owner = Entity.GetIndex(record.source)
			if record.position and not seen[owner] then
				seen[owner] = true
				ctx.teleportArrivals[#ctx.teleportArrivals + 1] = {source = record.source, position = record.position,
					remaining = math.max(0, record.arrival - ctx.now)}
				local alreadyNear = not Entity.IsDormant(record.source) and NPC.IsVisible(record.source)
					and ctx.distance(ctx.position, Entity.GetAbsOrigin(record.source)) < 1400
				if not alreadyNear and ctx.distance(ctx.position, record.position) < 1400 then ctx.incomingEnemies = ctx.incomingEnemies + 1 end
			end
		end
	end
end

return teleports
