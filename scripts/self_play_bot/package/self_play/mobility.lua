local mobility = {}
local combat = require("self_play.combat")

local function clearPath(ctx, destination, roll)
	local length = ctx.distance(ctx.position, destination)
	for step = 100, length, 100 do
		local point = ctx.toward(ctx.position, destination, step)
		if ctx.unsafePosition(point) or roll and not GridNav.IsTraversable(point) then return false end
	end
	if roll then
		local dx, dy = destination.x - ctx.position.x, destination.y - ctx.position.y
		for _, unit in ipairs(ctx.worldNPCs) do
			if unit ~= ctx.hero and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
				and (NPC.IsHero(unit) or NPC.GetUnitName(unit) == "npc_dota_earth_spirit_stone") then
				local p = Entity.GetAbsOrigin(unit)
				local fraction = ((p.x - ctx.position.x) * dx + (p.y - ctx.position.y) * dy) / math.max(1, length * length)
				if fraction > 0 and fraction < 1.15 then
					local point = Vector(ctx.position.x + dx * fraction, ctx.position.y + dy * fraction, ctx.position.z)
					if ctx.distance(point, p) < 200 then return false end
				end
			end
		end
	end
	return true
end

function mobility.rune(ctx, task, enemyEta)
	if task.travelUntil then
		if ctx.now < task.travelUntil and ctx.distance(ctx.position, task.position) > 140 then
			ctx.mode = "Complete rune mobility"
			return true
		end
		task.travelUntil = nil
	end
	if not ctx.settings.spells or ctx.health < 0.58 or ctx.hardRetreat
		or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) then return false end
	local distance = ctx.distance(ctx.position, task.position)
	if distance < 500 or distance > 1450 then return false end
	local walking = distance / math.max(100, NPC.GetMoveSpeed(ctx.hero))
	if enemyEta == math.huge and walking < 3 then return false end
	if not GridNav.IsTraversable(task.position) or not clearPath(ctx, task.position, false) then return false end
	for _, name in ipairs({"item_blink", "item_arcane_blink", "item_swift_blink", "item_overwhelming_blink", "antimage_blink", "queenofpain_blink", "earth_spirit_rolling_boulder"}) do
		local isItem = name:find("^item_") ~= nil
		local ability = isItem and NPC.GetItem(ctx.hero, name, true) or NPC.GetAbility(ctx.hero, name)
		if ability and combat.ready(ctx, ability, isItem) and (ctx.abilityAttempts[name] or 0) <= ctx.now then
			local roll = name == "earth_spirit_rolling_boulder"
			local duration, landing = Ability.GetCastPoint(ability) + 0.12, task.position
			local legal = distance <= Ability.GetCastRange(ability) - 40
			if roll then
				local reach = Ability.GetLevelSpecialValueFor(ability, "distance")
				local factor = reach / math.max(1, distance)
				landing = Vector(ctx.position.x + (task.position.x - ctx.position.x) * factor,
					ctx.position.y + (task.position.y - ctx.position.y) * factor, task.position.z)
				duration = Ability.GetLevelSpecialValueFor(ability, "delay") + reach / math.max(1, Ability.GetLevelSpecialValueFor(ability, "speed"))
				legal = math.abs(reach - distance) < 130 and GridNav.IsTraversable(landing) and clearPath(ctx, landing, true)
			end
			local arrival = duration + ctx.distance(landing, task.position) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
			if legal and arrival + 0.15 < enemyEta and walking - arrival > 0.65
				and NPC.GetMana(ctx.hero) - Ability.GetManaCost(ability) >= NPC.GetMaxMana(ctx.hero) * 0.25 then
				task.travelUntil = ctx.now + duration
				ctx.mode = "Use mobility to secure rune"
				return combat.cast(ctx, ability, "point", nil, task.position)
			end
		end
	end
	return false
end

return mobility
