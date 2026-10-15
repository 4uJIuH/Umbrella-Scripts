local script = {}

local menu = Menu.Create("Creeps", "Arc moggers", "Arc Warden Rune Control", "arc_warden_rune_control")
local group = menu:Create("Rune Control")
local debugGroup = menu:Create("Debug", 2)
local holdBind = group:Bind("Rune Control Action", Enum.ButtonCode.BUTTON_CODE_INVALID)
local disableAfterMinute = group:Slider("Disable After Minute", 1, 60, 15)
local debugEnabled = debugGroup:Switch("Enable Debug Log", false)
local pinStatusHud = debugGroup:Switch("Pin Status HUD", true)
local statusFont = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
local statusHud = db.arcWardenRuneStatus or {}
db.arcWardenRuneStatus = statusHud
statusHud.x = statusHud.x or 30
statusHud.y = statusHud.y or 300
local statusDragging = false
local statusDragOffset = Vec2(0, 0)

local hero = nil
local lastDoubleCast = -math.huge
local lastOrder = -math.huge
local lastFieldCast = -math.huge
local orderInterval = 0.25
local doubleRetryInterval = 0.5
local lastDebugLog = -math.huge
local debugStatus = "Idle"
local actionActive = false
local runePositions = {}
local runeSpots = {}
local runeSpotsReady = false
local lastRuneTiming = -math.huge
local firstRuneTime = 350
local runeInterval = 120
local runeLeadTime = 8
local runeWindow = 24

local KEY_CTRL = Enum.ButtonCode.KEY_LCONTROL
local KEY_MOUSE1 = Enum.ButtonCode.KEY_MOUSE1

local function now()
	return (GameRules and GameRules.GetGameTime()) or 0
end

local function debugLog(gameTime, message)
	debugStatus = message
	if debugEnabled:Get() and gameTime - lastDebugLog >= 1 then
		Log.Write("[Arc Warden] " .. message)
		lastDebugLog = gameTime
	end
end

local function distance(a, b)
	local dx = a.x - b.x
	local dy = a.y - b.y
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function getRunePosition()
	local localHero = Heroes.GetLocal()
	if not localHero then
		return nil
	end

	if not runeSpotsReady and Entities and Entities.GetAll then
		for _, entity in ipairs(Entities.GetAll()) do
			if Entity.GetClassName(entity) == "C_DOTA_Item_RuneSpawner_Powerup" then
				local position = Entity.GetAbsOrigin(entity)
				if position then
					local known = false
					for _, savedPosition in ipairs(runeSpots) do
						if distance(savedPosition, position) < 64 then
							known = true
							break
						end
					end
					if not known then
						runeSpots[#runeSpots + 1] = position
					end
				end
			end
		end
		if #runeSpots >= 2 then
			runeSpotsReady = true
		end
	end

	local origin = Entity.GetAbsOrigin(localHero)
	local nearestPosition = nil
	local nearestDistance = math.huge
	if Runes and Runes.GetAll then
	for _, rune in pairs(Runes.GetAll()) do
		if rune then
			local position = Entity.GetAbsOrigin(rune)
			if position then
				local known = false
				for _, savedPosition in ipairs(runePositions) do
					if distance(savedPosition, position) < 64 then
						known = true
						break
					end
				end
				if not known then
					runePositions[#runePositions + 1] = position
				end
				local currentDistance = distance(origin, position)
				if currentDistance < nearestDistance then
					nearestDistance = currentDistance
					nearestPosition = position
				end
			end
		end
	end
	end
	if not nearestPosition then
		for _, position in ipairs(runeSpots) do
			local currentDistance = distance(origin, position)
			if currentDistance < nearestDistance then
				nearestDistance = currentDistance
				nearestPosition = position
			end
		end
	end
	if not nearestPosition then
		for _, position in ipairs(runePositions) do
			local currentDistance = distance(origin, position)
			if currentDistance < nearestDistance then
				nearestDistance = currentDistance
				nearestPosition = position
			end
		end
	end
	if nearestPosition and FogOfWar and FogOfWar.IsPointVisible then
		local visible = FogOfWar.IsPointVisible(nearestPosition)
		debugStatus = visible and "Rune visible" or "Rune top/bot checked in fog"
	end
	return nearestPosition
end

local function getRuneTiming(gameTime)
	if gameTime < firstRuneTime - runeLeadTime then
		return nil
	end
	local step = math.floor((gameTime - firstRuneTime) / runeInterval)
	local timing = firstRuneTime + (step * runeInterval)
	if gameTime < timing - runeLeadTime or gameTime > timing + runeWindow then
		return nil
	end
	return timing
end

local function drawStatusHud(gameTime)
	if not Render or not pinStatusHud:Get() then
		return
	end

	local limitMinute = disableAfterMinute:Get()
	local minuteSecond = gameTime % 60
	local timing = getRuneTiming(gameTime)
	local stateText = actionActive and "ARC RUNE: ON" or "ARC RUNE: OFF"
	local stateColor = actionActive and Color(70, 220, 120, 235) or Color(220, 100, 100, 235)
	local timingText = timing and string.format("Window: %02d:%02d", math.floor(timing / 60), timing % 60) or "Waiting for timing"
	local limitText = string.format("Limit: %02d:00", limitMinute)
	local width = 190
	local height = 58
	local topLeft = Vec2(statusHud.x, statusHud.y)
	local bottomRight = Vec2(statusHud.x + width, statusHud.y + height)

	local mouseX, mouseY = Input.GetCursorPos()
	if Input.IsKeyDown(KEY_CTRL) and Input.IsKeyDownOnce(KEY_MOUSE1)
		and mouseX >= topLeft.x and mouseX <= bottomRight.x
		and mouseY >= topLeft.y and mouseY <= bottomRight.y then
		statusDragging = true
		statusDragOffset = topLeft - Vec2(mouseX, mouseY)
	end
	if statusDragging and Input.IsKeyDown(KEY_MOUSE1) then
		local currentX, currentY = Input.GetCursorPos()
		statusHud.x = currentX + statusDragOffset.x
		statusHud.y = currentY + statusDragOffset.y
	end
	if statusDragging and not Input.IsKeyDown(KEY_MOUSE1) then
		statusDragging = false
	end

	Render.FilledRect(topLeft, bottomRight, Color(15, 18, 24, 215), 6)
	Render.FilledRect(Vec2(topLeft.x, topLeft.y), Vec2(topLeft.x + 5, bottomRight.y), stateColor, 3)
	Render.Text(statusFont, 15, stateText, Vec2(topLeft.x + 12, topLeft.y + 7), stateColor)
	Render.Text(statusFont, 12, timingText, Vec2(topLeft.x + 12, topLeft.y + 27), Color(235, 235, 235, 235))
	Render.Text(statusFont, 12, limitText, Vec2(topLeft.x + 12, topLeft.y + 42), Color(170, 180, 195, 235))
end

local function findTempestDouble(localHero)
	local localTeam = Entity.GetTeamNum(localHero)
	local closest = nil
	local closestDistance = math.huge
	local origin = Entity.GetAbsOrigin(localHero)
	for _, unit in pairs(NPCs.GetAll()) do
		if unit and Entity.IsAlive(unit)
			and Entity.GetTeamNum(unit) == localTeam
			and (NPC.GetUnitName(unit) == "npc_dota_hero_arc_warden_tempest_double"
				or NPC.GetUnitName(unit) == "npc_dota_hero_arc_warden")
			and unit ~= localHero then
			local owner = NPC.GetOwnerNPC(unit)
			if owner and owner ~= localHero then
				goto continue
			end
			local currentDistance = distance(origin, Entity.GetAbsOrigin(unit))
			if currentDistance < closestDistance then
				closestDistance = currentDistance
				closest = unit
			end
		end
		::continue::
	end
	return closest
end

local function castTempestDouble(localHero, gameTime)
	if gameTime - lastDoubleCast < doubleRetryInterval then
		return
	end
	local ability = NPC.GetAbility(localHero, "arc_warden_tempest_double")
	if not ability then
		for index = 0, 24 do
			local candidate = NPC.GetAbilityByIndex(localHero, index)
			if candidate then
				local name = Ability.GetName(candidate) or ""
				local baseName = Ability.GetBaseName(candidate) or ""
				if name == "arc_warden_tempest_double" or baseName == "arc_warden_tempest_double" then
					ability = candidate
					break
				end
			end
		end
	end
	if not ability then
		debugLog(gameTime, "Tempest Double ability not found")
		lastDoubleCast = gameTime
		return
	end
	if not Ability.IsReady(ability) then
		debugLog(gameTime, "Tempest Double is not ready")
		lastDoubleCast = gameTime
		return
	end
	if not Ability.IsCastable(ability, NPC.GetMana(localHero)) then
		debugLog(gameTime, "Tempest Double is not castable")
		lastDoubleCast = gameTime
		return
	end
	local player = Players.GetLocal()
	if player and Player and Player.PrepareUnitOrders
		and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION
		and Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY then
		Player.PrepareUnitOrders(
			player,
			Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
			nil,
			Entity.GetAbsOrigin(localHero),
			ability,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
			localHero,
			false,
			false,
			false,
			true,
			"rune_control_double",
			false
		)
	else
		Ability.CastPosition(ability, Entity.GetAbsOrigin(localHero), false, false, true, "rune_control_double", true)
	end
	debugLog(gameTime, "Tempest Double cast command sent")
	lastDoubleCast = gameTime
end

local function controlRune(localHero, double, runePosition, gameTime)
	local doublePosition = Entity.GetAbsOrigin(double)
	local distanceToRune = distance(doublePosition, runePosition)
	if gameTime - lastOrder >= orderInterval then
		NPC.MoveTo(double, runePosition, false, false, false, true, "rune_control_move", true)
		lastOrder = gameTime
	end

	local field = NPC.GetAbility(double, "arc_warden_magnetic_field")
	if not field or not Ability.IsReady(field) or not Ability.IsCastable(field, NPC.GetMana(double)) then
		return
	end
	if NPC.HasModifier(double, "modifier_arc_warden_magnetic_field") then
		return
	end
	local castRange = Ability.GetCastRange(field) or 600
	if distanceToRune <= castRange + 100 and gameTime - lastFieldCast >= 0.5 then
		Ability.CastPosition(field, runePosition, false, false, true, "rune_control_field", true)
		lastFieldCast = gameTime
	end
end

function script.OnUpdate()
	local gameTime = now()
	local limitMinute = disableAfterMinute:Get()
	if holdBind:IsPressed() then
		actionActive = not actionActive
		debugLog(gameTime, actionActive and "Action enabled" or "Action disabled")
		if not actionActive then
			lastDoubleCast = -math.huge
			lastOrder = -math.huge
			lastFieldCast = -math.huge
		else
			local actionHero = Heroes.GetLocal()
			if actionHero and Entity.IsAlive(actionHero) and NPC.GetUnitName(actionHero) == "npc_dota_hero_arc_warden" then
				lastDoubleCast = -math.huge
				castTempestDouble(actionHero, gameTime)
			end
		end
	end

	if limitMinute > 0 and gameTime >= (limitMinute * 60) then
		debugLog(gameTime, string.format("Blocked at %.1f minute limit", limitMinute))
		actionActive = false
		return
	end

	if not actionActive then
		return
	end

	hero = Heroes.GetLocal()
	if not hero or not Entity.IsAlive(hero) or NPC.GetUnitName(hero) ~= "npc_dota_hero_arc_warden" then
		debugLog(gameTime, "Arc Warden hero is not available")
		return
	end

	local double = findTempestDouble(hero)
	if not double then
		castTempestDouble(hero, gameTime)
		return
	end

	local runePosition = getRunePosition()
	if not runePosition then
		debugLog(gameTime, "No rune found")
		return
	end
	debugLog(gameTime, "Double found, rune found, controlling double")
	controlRune(hero, double, runePosition, gameTime)
end

function script.OnDraw()
	drawStatusHud(now())
end

return script
