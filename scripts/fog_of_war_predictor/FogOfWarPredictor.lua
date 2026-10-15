--[[
	Fog of War Predictor
	Estimate where unseen enemies went using motion, maphack, vision, and GridNav.
	Script by 花曇り hanagumori / 64qt
--]]

local Script = {}

--#region Constants
local MIN_DIRECTION_LENGTH = 0.001
local MAPHACK_POSITION_EPSILON = 24
local PATH_ENDPOINT_BACKOFF = 96
local ROUTE_RESEED_DELAY = 0.12
local VISION_GRACE_TIME = 0.3
local VISION_SAMPLE_SPACING = 72
local VISION_REJECTION_TIME = 0.3
local CURRENT_VISION_PENALTY = 1.25
local SWEPT_VISION_PENALTY = 0.45
local ACTIVE_ROUTE_BONUS = 0.06
local HIDDEN_ROUTE_BONUS = 0.1
local MAX_ROUTE_CANDIDATES = 24
local MAX_RECOVERY_PARENTS = 2
local MAX_RECOVERY_GENERATIONS = 3
local TELEPORT_DISTANCE_BUFFER = 200
local TELEPORT_SPEED_MULTIPLIER = 1.8
local SAMPLE_WINDOW = 0.8
local MAX_VISIBLE_SAMPLES = 12
local BASE_UNCERTAINTY = 56
local UNCERTAINTY_PER_SECOND = 95
local MAX_UNCERTAINTY = 540
local MAX_HEAT_BLOBS = 10
local HEAT_ALONG_ROUTE_SAMPLES = 3
local ENSEMBLE_TOP_COUNT = 5
local STOPPED_GRACE_TIME = 1.25
local VISION_SNAP_STEPS = 10
local SIGNAL_RESEED_DELAY = 0.05
local IMPLIED_SPEED_BLEND = 0.62
local MODIFIER_STATE_INVISIBLE = 7

-- High-signal particle substrings (teleports / blinks / force-moves).
local SIGNAL_PARTICLE_PATTERNS = {
	"teleport",
	"blink",
	"phantom_strike",
	"reality_rift",
	"ball_lightning",
	"glimpse",
	"relay",
	"time_walk",
	"skeleton_king_reincarnation",
}

local DIRECTION_HYPOTHESES = {
	{ angle = 0, weight = 1 },
	{ angle = math.rad(15), weight = 0.95 },
	{ angle = math.rad(-15), weight = 0.95 },
	{ angle = math.rad(30), weight = 0.88 },
	{ angle = math.rad(-30), weight = 0.88 },
	{ angle = math.rad(50), weight = 0.76 },
	{ angle = math.rad(-50), weight = 0.76 },
	{ angle = math.rad(75), weight = 0.61 },
	{ angle = math.rad(-75), weight = 0.61 },
	{ angle = math.rad(105), weight = 0.43 },
	{ angle = math.rad(-105), weight = 0.43 },
}

local SPEED_HYPOTHESES = {
	{ scale = 1, weight = 1 },
	{ scale = 0.72, weight = 0.68 },
	{ scale = 0.45, weight = 0.4 },
}

local STOPPED_SPEED_HYPOTHESES = {
	{ scale = 0, weight = 1 },
	{ scale = 0.55, weight = 0.45 },
	{ scale = 0.85, weight = 0.25 },
}

local RECOVERY_HYPOTHESES = {
	{ angle = math.rad(45), weight = 0.68 },
	{ angle = math.rad(-45), weight = 0.68 },
	{ angle = math.rad(90), weight = 0.45 },
	{ angle = math.rad(-90), weight = 0.45 },
}
--#endregion

--#region State
---@class FogPredictorUI
---@field menu any
---@field enabled CMenuSwitch|nil
---@field maxFogTime any
---@field updateInterval any
---@field showPath CMenuSwitch|nil
---@field showHeatmap CMenuSwitch|nil
---@field visionAware CMenuSwitch|nil
---@field markerColor any
---@field pathColor any
---@field heatColor any
local UI = {}

local Persistent = {
	---@type integer|nil
	font = nil,
}

local Runtime = {
	heroes = {},
	signalParticles = {},
	nextUpdateTime = -math.huge,
}
--#endregion

--#region Helpers
local function Clamp(value, minimum, maximum)
	return math.min(math.max(value, minimum), maximum)
end

local function ScaledColor(color, alphaScale)
	return Color(color.r, color.g, color.b, math.floor(Clamp(color.a * alphaScale, 0, 255)))
end

local function HorizontalDirection(rotation)
	local direction = rotation:GetForward()
	direction.z = 0
	if direction:Length2D() <= MIN_DIRECTION_LENGTH then
		return nil
	end
	return direction:Normalized()
end

local function GroundPosition(position)
	return Vector(position.x, position.y, World.GetGroundZ(position.x, position.y))
end

local function HeroDisplayName(hero)
	return NPC.GetUnitName(hero):gsub("npc_dota_hero_", "")
end

local function IsSupportedEnemy(hero)
	return Entity.IsAlive(hero)
		and not NPC.IsIllusion(hero)
		and not NPC.IsTempestDouble(hero)
		and not XHelpers.XNPC:IsCommandAuraIllusion(hero)
		and not XHelpers.XNPC:IsMonkeyClone(hero)
		and not XHelpers.XNPC:IsSpiritBear(hero)
end

local function GetMaphackPosition(hero, fallback)
	local position = Hero.GetLastMaphackPos(hero)
	if position then
		return position, true
	end
	return fallback, false
end

local function ResolveHeroPosition(hero, fallback)
	local maphack = Hero.GetLastMaphackPos(hero)
	if maphack then
		return GroundPosition(maphack)
	end
	if fallback then
		return GroundPosition(fallback)
	end
	return GroundPosition(Entity.GetAbsOrigin(hero))
end

local function FindTrackedHero(entity)
	if not entity then
		return nil, nil
	end
	local index = Entity.GetIndex(entity)
	local state = Runtime.heroes[index]
	if not state then
		return nil, nil
	end
	return state, entity
end

local function ClearPrediction(state)
	state.predictedPosition = nil
	state.predictedPath = nil
	state.heatCells = nil
	state.predictionConfidence = 0
end

local function ResetRuntime()
	Runtime.heroes = {}
	Runtime.signalParticles = {}
	Runtime.nextUpdateTime = -math.huge
end

local function EffectiveMoveSpeed(state)
	return state.moveSpeed or 300
end

local function IsSignalParticleName(fullName, name)
	local haystack = string.lower((fullName or "") .. " " .. (name or ""))
	for _, pattern in ipairs(SIGNAL_PARTICLE_PATTERNS) do
		if string.find(haystack, pattern, 1, true) then
			return true
		end
	end
	return false
end

-- Pull a visible prediction back to the first fog cell along the anchor ray.
local function SnapBehindVision(position, anchor)
	if not position or not FogOfWar.IsPointVisible(position) then
		return position
	end
	if not anchor then
		return position
	end

	local offset = anchor - position
	offset.z = 0
	local length = offset:Length2D()
	if length <= MIN_DIRECTION_LENGTH then
		return position
	end

	local direction = offset:Normalized()
	local lo = 0
	local hi = length
	for _ = 1, VISION_SNAP_STEPS do
		local mid = (lo + hi) * 0.5
		local sample = GroundPosition(position + direction:Scaled(mid))
		if FogOfWar.IsPointVisible(sample) then
			lo = mid
		else
			hi = mid
		end
	end
	return GroundPosition(position + direction:Scaled(hi))
end

local function InvalidateRoutes(state)
	state.routeCandidates = nil
	state.routeMaxFogTime = nil
	state.lastCandidateEvaluationTime = nil
	state.activeCandidateKey = nil
	state.recoveryGeneration = 0
	state.nextCandidateKey = 200
end

local function ApplySignalReanchor(state, hero, position, now, facingTarget)
	if not state or not position then
		return
	end
	if state.lastSignalTime and now - state.lastSignalTime < 0.08 then
		return
	end
	state.lastSignalTime = now

	position = GroundPosition(position)
	state.hasObservation = true
	state.wasVisible = false
	state.projectionOrigin = position
	state.projectionStartTime = now
	state.acceptedMaphackPosition = position
	state.acceptedMaphackTime = now
	state.rejectedMaphackPosition = nil
	if hero then
		state.baseMoveSpeed = NPC.GetMoveSpeed(hero)
		state.moveSpeed = state.baseMoveSpeed
	end
	state.motionConfidence = math.max(state.motionConfidence or 0, 0.92)
	state.predictionConfidence = math.max(state.predictionConfidence or 0, 0.8)
	state.stoppedGraceUntil = nil
	state.deferRouteUntil = now + SIGNAL_RESEED_DELAY

	if facingTarget then
		local direction = facingTarget - position
		direction.z = 0
		if direction:Length2D() > MIN_DIRECTION_LENGTH then
			state.direction = direction:Normalized()
			state.wasMoving = true
		end
	elseif hero then
		state.direction = HorizontalDirection(Entity.GetRotation(hero)) or state.direction
	end

	if not state.direction and hero then
		state.direction = HorizontalDirection(Entity.GetRotation(hero))
	end
	state.hasObservation = state.direction ~= nil

	InvalidateRoutes(state)
	state.predictedPosition = position
	state.predictedPath = { position }
	state.heatCells = {
		{ position = position, weight = 1, radius = BASE_UNCERTAINTY * 0.65 },
	}
end

local function SetMenuDisabled(disabled)
	UI.maxFogTime:Disabled(disabled)
	UI.updateInterval:Disabled(disabled)
	UI.showPath:Disabled(disabled)
	UI.showHeatmap:Disabled(disabled)
	UI.visionAware:Disabled(disabled)
	UI.markerColor:Disabled(disabled)
	UI.pathColor:Disabled(disabled)
	UI.heatColor:Disabled(disabled)
end
--#endregion

--#region Routes
local function FindTraversableEndpoint(origin, direction, distance)
	local candidateDistance = distance
	while candidateDistance > 0 do
		local candidate = GroundPosition(origin + direction:Scaled(candidateDistance))
		if GridNav.IsTraversable(candidate) then
			return candidate
		end
		candidateDistance = candidateDistance - PATH_ENDPOINT_BACKOFF
	end
	return origin
end

local function RouteFromPoints(points, intendedDirection, endpoint)
	local filtered = { points[1] }
	for index = 2, #points do
		if filtered[#filtered]:Distance2D(points[index]) > MIN_DIRECTION_LENGTH then
			table.insert(filtered, points[index])
		end
	end
	points = filtered
	if #points < 2 then
		return nil
	end

	local cumulativeDistance = { 0 }
	local totalDistance = 0
	for index = 2, #points do
		local segmentLength = points[index - 1]:Distance2D(points[index])
		totalDistance = totalDistance + segmentLength
		cumulativeDistance[index] = totalDistance
	end

	local initialDirection = points[2] - points[1]
	initialDirection.z = 0
	local alignment = intendedDirection:Dot2D(initialDirection:Normalized())
	local directDistance = math.max(points[1]:Distance2D(endpoint), MIN_DIRECTION_LENGTH)
	local detourRatio = totalDistance / directDistance
	local alignmentQuality = 0.35 + 0.65 * ((alignment + 1) * 0.5)
	local detourQuality = 1 / (1 + math.max(0, detourRatio - 1) * 1.5)

	return {
		points = points,
		cumulativeDistance = cumulativeDistance,
		totalDistance = totalDistance,
		quality = alignmentQuality * detourQuality,
	}
end

local function BuildRouteToEndpoint(origin, endpoint, intendedDirection)
	local rawPath = GridNav.BuildPath(origin, endpoint, false)
	if not rawPath or #rawPath == 0 then
		return nil
	end

	local points = { origin }
	local previous = origin
	for _, node in ipairs(rawPath) do
		if previous:Distance2D(node) > MIN_DIRECTION_LENGTH then
			table.insert(points, node)
			previous = node
		end
	end
	return RouteFromPoints(points, intendedDirection, endpoint)
end

local function BuildRoute(origin, direction, distance)
	if distance <= MIN_DIRECTION_LENGTH then
		return nil
	end
	local endpoint = FindTraversableEndpoint(origin, direction, distance)
	if endpoint:Distance2D(origin) <= MIN_DIRECTION_LENGTH then
		return nil
	end
	return BuildRouteToEndpoint(origin, endpoint, direction)
end

local function StationaryRoute(origin)
	return {
		points = { origin },
		cumulativeDistance = { 0 },
		totalDistance = 0,
		quality = 1,
	}
end

local function PositionAlongRoute(route, distance)
	local clampedDistance = Clamp(distance, 0, route.totalDistance)
	for index = 2, #route.points do
		local segmentEnd = route.cumulativeDistance[index]
		if segmentEnd >= clampedDistance then
			local segmentStart = route.cumulativeDistance[index - 1]
			local segmentLength = segmentEnd - segmentStart
			local alpha = (clampedDistance - segmentStart) / segmentLength
			return route.points[index - 1] + (route.points[index] - route.points[index - 1]):Scaled(alpha)
		end
	end
	return route.points[#route.points]
end

local function RouteTangent(route, distance)
	local clampedDistance = Clamp(distance, 0, route.totalDistance)
	for index = 2, #route.points do
		if route.cumulativeDistance[index] >= clampedDistance then
			local direction = route.points[index] - route.points[index - 1]
			direction.z = 0
			return direction:Normalized()
		end
	end
	local direction = route.points[#route.points] - route.points[#route.points - 1]
	direction.z = 0
	return direction:Normalized()
end

local function PathPrefix(route, distance)
	local clampedDistance = Clamp(distance, 0, route.totalDistance)
	local path = { route.points[1] }
	if clampedDistance <= MIN_DIRECTION_LENGTH then
		return path
	end
	for index = 2, #route.points do
		if route.cumulativeDistance[index] < clampedDistance then
			table.insert(path, route.points[index])
		else
			table.insert(path, PositionAlongRoute(route, clampedDistance))
			break
		end
	end
	return path
end

local function CombineRoutes(parentRoute, branchDistance, suffixRoute)
	local points = PathPrefix(parentRoute, branchDistance)
	for index = 2, #suffixRoute.points do
		table.insert(points, suffixRoute.points[index])
	end
	local endpoint = points[#points]
	local direction = points[2] - points[1]
	direction.z = 0
	return RouteFromPoints(points, direction:Normalized(), endpoint)
end
--#endregion

--#region Candidates
local function TrimCandidates(candidates)
	table.sort(candidates, function(left, right)
		return left.prior > right.prior
	end)
	for index = #candidates, MAX_ROUTE_CANDIDATES + 1, -1 do
		candidates[index] = nil
	end
end

local function NewCandidate(key, route, speedScale, turnDistance, prior, previousDistance)
	return {
		key = key,
		route = route,
		speedScale = speedScale,
		turnDistance = turnDistance,
		prior = prior,
		previousDistance = previousDistance or 0,
		contradictionTime = 0,
		rejected = false,
	}
end

local function AddSpeedCandidates(candidates, route, routeKey, prior, turnDistance, speedHypotheses)
	for speedIndex, speedHypothesis in ipairs(speedHypotheses) do
		table.insert(
			candidates,
			NewCandidate(routeKey * 10 + speedIndex, route, speedHypothesis.scale, turnDistance, prior * speedHypothesis.weight)
		)
	end
end

local function BuildRouteCandidates(hero, state, distance, speedHypotheses)
	local candidates = {}
	local origin = state.projectionOrigin
	local moveSpeed = EffectiveMoveSpeed(state)
	local motionConfidence = state.motionConfidence or 0.5
	local entryTurnDistance = state.entryTurnDistance or 0

	for directionIndex, directionHypothesis in ipairs(DIRECTION_HYPOTHESES) do
		local candidateDirection = state.direction:Rotated(directionHypothesis.angle):Normalized()
		local route = BuildRoute(origin, candidateDirection, distance)
		if route then
			local turnTime = Clamp(NPC.GetTimeToFacePosition(hero, route.points[2]), 0, 1)
			local broadWeight = 0.72 + 0.28 * directionHypothesis.weight
			local directionWeight = directionHypothesis.weight * motionConfidence + broadWeight * (1 - motionConfidence)
			AddSpeedCandidates(
				candidates,
				route,
				directionIndex,
				directionWeight * route.quality,
				entryTurnDistance + moveSpeed * turnTime,
				speedHypotheses
			)
		end
	end

	if #candidates == 0 then
		AddSpeedCandidates(candidates, StationaryRoute(origin), 1, 1, 0, { STOPPED_SPEED_HYPOTHESES[1] })
	end

	TrimCandidates(candidates)
	return candidates
end

local function RouteTouchesVisibleGround(candidate, currentDistance)
	local previousDistance = math.min(candidate.previousDistance, currentDistance)
	local sampleDistance = previousDistance + VISION_SAMPLE_SPACING
	local sweptVisible = false

	while sampleDistance < currentDistance do
		if FogOfWar.IsPointVisible(PositionAlongRoute(candidate.route, sampleDistance)) then
			sweptVisible = true
			break
		end
		sampleDistance = sampleDistance + VISION_SAMPLE_SPACING
	end

	local position = PositionAlongRoute(candidate.route, currentDistance)
	local currentVisible = FogOfWar.IsPointVisible(position)
	candidate.previousDistance = currentDistance
	if not currentVisible then
		candidate.lastFogDistance = currentDistance
	end
	return position, currentVisible, sweptVisible
end

local function AddRecoveryCandidates(hero, state, rejectedCandidates)
	local seenRoutes = {}
	local parentsUsed = 0

	table.sort(rejectedCandidates, function(left, right)
		return left.prior > right.prior
	end)

	for _, parent in ipairs(rejectedCandidates) do
		if parentsUsed >= MAX_RECOVERY_PARENTS then
			break
		end
		if not seenRoutes[parent.route] then
			seenRoutes[parent.route] = true
			parentsUsed = parentsUsed + 1

			local branchDistance = Clamp(parent.lastFogDistance or 0, 0, parent.route.totalDistance)
			local branchPosition = PositionAlongRoute(parent.route, branchDistance)
			local tangent = parent.route.totalDistance > MIN_DIRECTION_LENGTH
					and RouteTangent(parent.route, branchDistance)
				or state.direction
			local remainingDistance = math.max(
				PATH_ENDPOINT_BACKOFF,
				(state.routeSearchDistance or parent.route.totalDistance) - branchDistance
			)

			for _, recoveryHypothesis in ipairs(RECOVERY_HYPOTHESES) do
				local recoveryDirection = tangent:Rotated(recoveryHypothesis.angle):Normalized()
				local suffix = BuildRoute(branchPosition, recoveryDirection, remainingDistance)
				if suffix then
					local route = CombineRoutes(parent.route, branchDistance, suffix)
					if route then
						local turnTime = Clamp(NPC.GetTimeToFacePosition(hero, suffix.points[2]), 0, 0.75)
						state.nextCandidateKey = state.nextCandidateKey + 1
						local candidate = NewCandidate(
							state.nextCandidateKey,
							route,
							parent.speedScale,
							parent.turnDistance + EffectiveMoveSpeed(state) * turnTime,
							parent.prior * recoveryHypothesis.weight,
							branchDistance
						)
						candidate.minimumDistance = branchDistance
						candidate.lastFogDistance = branchDistance
						table.insert(state.routeCandidates, candidate)
					end
				end
			end
		end
	end

	TrimCandidates(state.routeCandidates)
end

local function ScoreCandidate(candidate, state, useVisionEvidence, hasHiddenCandidate)
	local score = candidate.prior
	if useVisionEvidence and hasHiddenCandidate then
		if candidate.currentVisible then
			score = score - CURRENT_VISION_PENALTY
		elseif candidate.sweptVisible then
			score = score - SWEPT_VISION_PENALTY
		else
			score = score + HIDDEN_ROUTE_BONUS
		end
		score = score - candidate.contradictionTime
	elseif not candidate.currentVisible then
		score = score + HIDDEN_ROUTE_BONUS * 0.5
	end
	if candidate.key == state.activeCandidateKey then
		score = score + ACTIVE_ROUTE_BONUS
	end
	if candidate.currentDistance > candidate.route.totalDistance + PATH_ENDPOINT_BACKOFF then
		score = score - 0.5
	end
	return score
end

local function EvaluateCandidatePosition(candidate, distance, useVisionEvidence)
	local candidateDistance = math.max(
		candidate.minimumDistance or 0,
		math.max(0, distance - candidate.turnDistance) * candidate.speedScale
	)

	local position, currentVisible, sweptVisible
	if useVisionEvidence then
		position, currentVisible, sweptVisible = RouteTouchesVisibleGround(candidate, candidateDistance)
	else
		position = PositionAlongRoute(candidate.route, candidateDistance)
		candidate.previousDistance = candidateDistance
		currentVisible = false
		sweptVisible = false
		if not FogOfWar.IsPointVisible(position) then
			candidate.lastFogDistance = candidateDistance
		end
	end

	candidate.currentDistance = candidateDistance
	candidate.currentPosition = position
	candidate.currentVisible = currentVisible
	candidate.sweptVisible = sweptVisible
	return position, currentVisible
end

local function UpdateVisionContradiction(candidate, evaluationDelta, hasHiddenCandidate, newlyRejected, forcedRecoveryParents)
	if hasHiddenCandidate then
		if candidate.currentVisible then
			candidate.contradictionTime = candidate.contradictionTime + evaluationDelta
		elseif candidate.sweptVisible then
			candidate.contradictionTime = candidate.contradictionTime + evaluationDelta * 0.5
		else
			candidate.contradictionTime = math.max(0, candidate.contradictionTime - evaluationDelta * 0.25)
		end
		if not candidate.rejected and candidate.contradictionTime >= VISION_REJECTION_TIME then
			candidate.rejected = true
			table.insert(newlyRejected, candidate)
		end
	elseif candidate.currentVisible and not candidate.rejected then
		candidate.contradictionTime = candidate.contradictionTime + evaluationDelta
		if candidate.contradictionTime >= VISION_REJECTION_TIME then
			table.insert(forcedRecoveryParents, candidate)
		end
	end
end

local function BlendPredictedPosition(bestCandidate, scoredEntries, state)
	local bestPosition = bestCandidate.currentPosition
	if #scoredEntries < 2 then
		return bestPosition
	end

	local weightSum = 0
	local sumX = 0
	local sumY = 0
	local topCount = math.min(ENSEMBLE_TOP_COUNT, #scoredEntries)
	for index = 1, topCount do
		local entry = scoredEntries[index]
		weightSum = weightSum + entry.weight
		sumX = sumX + entry.position.x * entry.weight
		sumY = sumY + entry.position.y * entry.weight
	end
	if weightSum <= MIN_DIRECTION_LENGTH then
		return bestPosition
	end

	local ensemble = GroundPosition(Vector(sumX / weightSum, sumY / weightSum, bestPosition.z))
	local dominance = scoredEntries[1].weight / weightSum
	local blend = Clamp((1 - dominance) * 0.85, 0.12, 0.48)
	blend = blend * (1 - Clamp((state.motionConfidence or 0.5) * 0.35, 0, 0.35))
	return GroundPosition(bestPosition + (ensemble - bestPosition):Scaled(blend))
end

local function BuildHeatmap(state, scoredEntries, bestCandidate)
	local heatCells = {}
	local count = math.min(MAX_HEAT_BLOBS, #scoredEntries)
	local weightSum = 0
	for index = 1, count do
		weightSum = weightSum + scoredEntries[index].weight
	end

	if weightSum > MIN_DIRECTION_LENGTH then
		for index = 1, count do
			local entry = scoredEntries[index]
			local weight = entry.weight / weightSum
			table.insert(heatCells, {
				position = entry.position,
				weight = weight,
				radius = BASE_UNCERTAINTY * (0.7 + (1 - weight) * 0.9),
			})
		end
	end

	if bestCandidate and bestCandidate.route and bestCandidate.currentDistance then
		local route = bestCandidate.route
		local centerDistance = bestCandidate.currentDistance
		local spread = math.max(80, (state.uncertaintyRadius or BASE_UNCERTAINTY) * 0.45)
		for sampleIndex = 1, HEAT_ALONG_ROUTE_SAMPLES do
			local offset = (sampleIndex - (HEAT_ALONG_ROUTE_SAMPLES + 1) * 0.5) * (spread / HEAT_ALONG_ROUTE_SAMPLES)
			local sampleDistance = Clamp(centerDistance + offset, 0, route.totalDistance)
			local falloff = 1 - math.abs(offset) / (spread + 1)
			table.insert(heatCells, {
				position = PositionAlongRoute(route, sampleDistance),
				weight = math.max(0.08, (state.predictionConfidence or 0.4) * 0.35 * falloff),
				radius = BASE_UNCERTAINTY * (0.55 + (1 - falloff) * 0.5),
			})
		end
	elseif bestCandidate and bestCandidate.currentPosition then
		table.insert(heatCells, {
			position = bestCandidate.currentPosition,
			weight = 1,
			radius = BASE_UNCERTAINTY,
		})
	end

	state.heatCells = heatCells
end

local function ComputeUncertainty(state, maximumFogTime)
	local motionConfidence = state.motionConfidence or 0.5
	local fogDuration = state.fogDuration or 0
	local recovery = state.recoveryGeneration or 0
	local ageFactor = 1.2 - 0.55 * motionConfidence
	local radius = BASE_UNCERTAINTY
		+ fogDuration * UNCERTAINTY_PER_SECOND * ageFactor
		+ recovery * 42
		+ (1 - (state.predictionConfidence or 0.5)) * 80
	local fogCap = BASE_UNCERTAINTY + maximumFogTime * UNCERTAINTY_PER_SECOND
	state.uncertaintyRadius = Clamp(radius, BASE_UNCERTAINTY, math.min(MAX_UNCERTAINTY, fogCap))
end

local function SelectBestCandidate(hero, state, distance, now, useVisionEvidence, allowRecovery)
	local candidates = state.routeCandidates
	if not candidates or #candidates == 0 then
		ClearPrediction(state)
		return nil
	end

	local evaluationDelta = math.max(0, now - (state.lastCandidateEvaluationTime or now))
	state.lastCandidateEvaluationTime = now
	local hasHiddenCandidate = false

	for _, candidate in ipairs(candidates) do
		if not useVisionEvidence then
			candidate.contradictionTime = 0
			candidate.rejected = false
		end
		local _, currentVisible = EvaluateCandidatePosition(candidate, distance, useVisionEvidence)
		if not currentVisible and not candidate.rejected then
			hasHiddenCandidate = true
		end
	end

	local bestCandidate = nil
	local bestScore = -math.huge
	local viableCount = 0
	local newlyRejected = {}
	local forcedRecoveryParents = {}
	local scoredEntries = {}

	for _, candidate in ipairs(candidates) do
		if useVisionEvidence then
			UpdateVisionContradiction(candidate, evaluationDelta, hasHiddenCandidate, newlyRejected, forcedRecoveryParents)
		end

		if not candidate.rejected and candidate.currentPosition then
			viableCount = viableCount + 1
			local score = ScoreCandidate(candidate, state, useVisionEvidence, hasHiddenCandidate)
			if score > bestScore then
				bestScore = score
				bestCandidate = candidate
			end
			if not candidate.currentVisible or not useVisionEvidence then
				table.insert(scoredEntries, {
					position = candidate.currentPosition,
					weight = math.max(score, 0.05),
				})
			end
		end
	end

	local recoveryParents = #newlyRejected > 0 and newlyRejected or forcedRecoveryParents
	if allowRecovery and state.recoveryGeneration < MAX_RECOVERY_GENERATIONS and #recoveryParents > 0 then
		state.recoveryGeneration = state.recoveryGeneration + 1
		AddRecoveryCandidates(hero, state, recoveryParents)
		return SelectBestCandidate(hero, state, distance, now, useVisionEvidence, false)
	end

	if not bestCandidate then
		ClearPrediction(state)
		return nil
	end

	table.sort(scoredEntries, function(left, right)
		return left.weight > right.weight
	end)

	state.activeCandidateKey = bestCandidate.key
	local priorStrength = Clamp(bestCandidate.prior / 1.35, 0.15, 1)
	local contradictionPenalty = Clamp(bestCandidate.contradictionTime / 1.2, 0, 0.55)
	local diversityPenalty = viableCount > 1 and Clamp((viableCount - 1) * 0.04, 0, 0.25) or 0
	local stoppedPenalty = bestCandidate.speedScale <= MIN_DIRECTION_LENGTH and 0.12 or 0
	state.predictionConfidence =
		Clamp(priorStrength * (1 - contradictionPenalty) * (1 - diversityPenalty) - stoppedPenalty, 0.08, 1)

	local predictedPosition = BlendPredictedPosition(bestCandidate, scoredEntries, state)
	if useVisionEvidence then
		predictedPosition = SnapBehindVision(predictedPosition, state.projectionOrigin)
		for _, entry in ipairs(scoredEntries) do
			entry.position = SnapBehindVision(entry.position, state.projectionOrigin)
		end
	end
	local predictedPath = PathPrefix(bestCandidate.route, bestCandidate.currentDistance)
	return predictedPosition, predictedPath, scoredEntries, bestCandidate
end
--#endregion

--#region Motion
local function UpdateVisibleSamples(state, position, now)
	if not state.wasVisible then
		state.visibleSamples = {}
	end

	local samples = state.visibleSamples
	local lastSample = samples[#samples]
	if not lastSample or now - lastSample.time >= 0.04 then
		table.insert(samples, { time = now, position = position })
	end
	while #samples > MAX_VISIBLE_SAMPLES or (#samples > 1 and now - samples[1].time > SAMPLE_WINDOW) do
		table.remove(samples, 1)
	end
end

local function EstimateMotion(hero, samples, rotationDirection)
	if #samples < 2 then
		return rotationDirection, false, 0.2
	end

	local meanTime = 0
	local meanX = 0
	local meanY = 0
	for _, sample in ipairs(samples) do
		meanTime = meanTime + sample.time
		meanX = meanX + sample.position.x
		meanY = meanY + sample.position.y
	end
	meanTime = meanTime / #samples
	meanX = meanX / #samples
	meanY = meanY / #samples

	local timeVariance = 0
	local covarianceX = 0
	local covarianceY = 0
	for _, sample in ipairs(samples) do
		local timeDelta = sample.time - meanTime
		timeVariance = timeVariance + timeDelta * timeDelta
		covarianceX = covarianceX + timeDelta * (sample.position.x - meanX)
		covarianceY = covarianceY + timeDelta * (sample.position.y - meanY)
	end
	if timeVariance <= MIN_DIRECTION_LENGTH then
		return rotationDirection, false, 0.2
	end

	local velocity = Vector(covarianceX / timeVariance, covarianceY / timeVariance, 0)
	local speed = velocity:Length2D()
	if speed <= 30 then
		return rotationDirection, false, 0.25
	end

	local previousDirection = nil
	local consistencyTotal = 0
	local consistencySamples = 0
	for index = 2, #samples do
		local displacement = samples[index].position - samples[index - 1].position
		displacement.z = 0
		if displacement:Length2D() > 5 then
			local sampleDirection = displacement:Normalized()
			if previousDirection then
				consistencyTotal = consistencyTotal + (previousDirection:Dot2D(sampleDirection) + 1) * 0.5
				consistencySamples = consistencySamples + 1
			end
			previousDirection = sampleDirection
		end
	end

	local consistency = consistencySamples > 0 and consistencyTotal / consistencySamples or 0.65
	local sampleConfidence = math.min(1, (#samples - 1) / 4)
	local speedConfidence = Clamp((speed - 30) / 220, 0.15, 1)
	local confidence = consistency * sampleConfidence * (0.55 + 0.45 * speedConfidence)
	if NPC.IsTurning(hero) then
		confidence = confidence * 0.55
	end
	confidence = confidence * (1 - Clamp(math.abs(NPC.GetAngleDiff(hero)) / 180, 0, 1) * 0.4)
	confidence = Clamp(confidence, 0.1, 1)

	local velocityDirection = velocity:Normalized()
	if not rotationDirection then
		return velocityDirection, true, confidence
	end

	local facingWeight = 1 - confidence
	if NPC.IsTurning(hero) then
		facingWeight = math.max(facingWeight, 0.55)
	end
	local blended = Vector(
		velocityDirection.x * (1 - facingWeight) + rotationDirection.x * facingWeight,
		velocityDirection.y * (1 - facingWeight) + rotationDirection.y * facingWeight,
		0
	)
	if blended:Length2D() <= MIN_DIRECTION_LENGTH then
		return velocityDirection, true, confidence
	end
	return blended:Normalized(), true, confidence
end

local function ResetVisibleState(state, hero, now)
	local position = Entity.GetAbsOrigin(hero)
	local rotationDirection = HorizontalDirection(Entity.GetRotation(hero))
	UpdateVisibleSamples(state, position, now)
	local direction, observedMovement, motionConfidence = EstimateMotion(hero, state.visibleSamples, rotationDirection)

	state.heroName = HeroDisplayName(hero)
	state.wasVisible = true
	state.hasObservation = direction ~= nil
	state.lastVisibleTime = now
	state.lastSeenPosition = position

	local maphackPosition, hasMaphackPosition = GetMaphackPosition(hero, position)
	local maphackMatchesVisible = hasMaphackPosition
		and position:Distance2D(maphackPosition) <= MAPHACK_POSITION_EPSILON
	state.acceptedMaphackPosition = maphackMatchesVisible and maphackPosition or nil
	state.acceptedMaphackTime = maphackMatchesVisible and now or nil
	state.rejectedMaphackPosition = hasMaphackPosition and not maphackMatchesVisible and maphackPosition or nil

	state.projectionOrigin = position
	state.projectionStartTime = now
	state.direction = direction
	state.motionConfidence = motionConfidence
	state.baseMoveSpeed = NPC.GetMoveSpeed(hero)
	state.moveSpeed = state.baseMoveSpeed
	state.wasMoving = NPC.IsRunning(hero) or observedMovement
	state.wasInvisible = NPC.HasState(hero, MODIFIER_STATE_INVISIBLE)
	state.entryTurnDistance = 0
	if direction then
		local facePoint = position + direction:Scaled(220)
		local turnTime = Clamp(NPC.GetTimeToFacePosition(hero, facePoint), 0, 0.85)
		if NPC.IsTurning(hero) or math.abs(NPC.GetAngleDiff(hero)) > 12 then
			state.entryTurnDistance = state.moveSpeed * turnTime
		end
	end
	state.stoppedGraceUntil = nil
	state.deferRouteUntil = nil
	state.fogTransitionTime = nil
	state.fogStartTime = nil
	state.fogDuration = 0
	state.uncertaintyRadius = BASE_UNCERTAINTY
	ClearPrediction(state)
	state.predictionConfidence = 1
	InvalidateRoutes(state)
end

local function UpdateMaphackAnchor(state, hero, maphackPosition, hasMaphackPosition, now)
	if state.wasVisible then
		local maphackMatchesVisible = hasMaphackPosition
			and state.lastSeenPosition:Distance2D(maphackPosition) <= MAPHACK_POSITION_EPSILON
		state.projectionOrigin = maphackMatchesVisible and maphackPosition or state.lastSeenPosition
		state.fogStartTime = state.fogTransitionTime or Hero.GetLastVisibleTime(hero) or state.lastVisibleTime
		state.projectionStartTime = state.fogStartTime
		state.acceptedMaphackPosition = maphackMatchesVisible and maphackPosition or nil
		state.acceptedMaphackTime = maphackMatchesVisible and state.fogStartTime or nil
		state.rejectedMaphackPosition = hasMaphackPosition and not maphackMatchesVisible and maphackPosition or nil
		if not state.wasMoving then
			state.stoppedGraceUntil = (state.fogStartTime or now) + STOPPED_GRACE_TIME
		else
			state.stoppedGraceUntil = nil
		end
		return true
	end

	if hasMaphackPosition and not state.acceptedMaphackPosition then
		local rejectedSampleChanged = not state.rejectedMaphackPosition
			or state.rejectedMaphackPosition:Distance2D(maphackPosition) > MAPHACK_POSITION_EPSILON
		if not rejectedSampleChanged then
			return false
		end
		state.acceptedMaphackPosition = maphackPosition
		state.acceptedMaphackTime = now
		state.rejectedMaphackPosition = nil
		state.projectionOrigin = maphackPosition
		state.projectionStartTime = now
		state.motionConfidence = math.max(state.motionConfidence or 0, 0.55)
		state.deferRouteUntil = now + ROUTE_RESEED_DELAY
		return true
	end

	if not hasMaphackPosition or not state.acceptedMaphackPosition then
		return false
	end

	local displacement = maphackPosition - state.acceptedMaphackPosition
	displacement.z = 0
	local displacementLength = displacement:Length2D()
	if displacementLength <= MAPHACK_POSITION_EPSILON then
		return false
	end

	local sampleTime = math.max(MIN_DIRECTION_LENGTH, now - (state.acceptedMaphackTime or now))
	local nominalSpeed = state.baseMoveSpeed or state.moveSpeed or NPC.GetMoveSpeed(hero)
	local maximumWalkingDistance = nominalSpeed * sampleTime * TELEPORT_SPEED_MULTIPLIER + TELEPORT_DISTANCE_BUFFER
	if displacementLength <= maximumWalkingDistance then
		state.direction = displacement:Normalized()
		state.wasMoving = true
		state.motionConfidence = math.max(state.motionConfidence or 0, 0.82)
		state.stoppedGraceUntil = nil
		local impliedSpeed = displacementLength / sampleTime
		if impliedSpeed > 45 then
			local blended = nominalSpeed * (1 - IMPLIED_SPEED_BLEND) + impliedSpeed * IMPLIED_SPEED_BLEND
			state.moveSpeed = Clamp(blended, nominalSpeed * 0.5, nominalSpeed * 1.5)
		end
	else
		state.direction = HorizontalDirection(Entity.GetRotation(hero)) or state.direction
		state.wasMoving = false
		state.motionConfidence = 0.15
		state.moveSpeed = nominalSpeed
	end

	state.acceptedMaphackPosition = maphackPosition
	state.acceptedMaphackTime = now
	state.rejectedMaphackPosition = nil
	state.projectionOrigin = maphackPosition
	state.projectionStartTime = now
	state.deferRouteUntil = now + ROUTE_RESEED_DELAY
	return true
end

local function UpdateHiddenState(state, hero, now, maximumFogTime)
	if not state.hasObservation then
		return
	end

	local maphackPosition, hasMaphackPosition = GetMaphackPosition(hero, state.lastSeenPosition)
	local routeNeedsRefresh = state.routeCandidates == nil or state.routeMaxFogTime ~= maximumFogTime
	if UpdateMaphackAnchor(state, hero, maphackPosition, hasMaphackPosition, now) then
		routeNeedsRefresh = true
	end

	state.wasVisible = false
	if not state.fogStartTime then
		state.fogStartTime = state.fogTransitionTime or Hero.GetLastVisibleTime(hero) or state.lastVisibleTime
	end
	state.fogDuration = math.max(0, now - state.fogStartTime)

	if routeNeedsRefresh then
		InvalidateRoutes(state)
	end

	if state.fogDuration > maximumFogTime then
		ClearPrediction(state)
		state.uncertaintyRadius = MAX_UNCERTAINTY
		return
	end

	local movementTime = math.max(0, now - state.projectionStartTime)
	local moveSpeed = EffectiveMoveSpeed(state)
	local distance = moveSpeed * movementTime

	if routeNeedsRefresh and state.deferRouteUntil and now < state.deferRouteUntil then
		state.predictedPosition = state.projectionOrigin
		state.predictedPath = { state.projectionOrigin }
		state.heatCells = {
			{ position = state.projectionOrigin, weight = 1, radius = BASE_UNCERTAINTY },
		}
		state.predictionConfidence = math.max(state.predictionConfidence or 0.4, 0.45)
		ComputeUncertainty(state, maximumFogTime)
		return
	end

	if routeNeedsRefresh then
		local remainingFogTime = math.max(0, maximumFogTime - state.fogDuration)
		state.routeSearchDistance = moveSpeed * (movementTime + remainingFogTime) + NPC.GetHullRadius(hero)
		local forceStopped = state.stoppedGraceUntil and now < state.stoppedGraceUntil
		local speedHypotheses = (state.wasMoving and not forceStopped) and SPEED_HYPOTHESES or STOPPED_SPEED_HYPOTHESES
		state.routeCandidates = BuildRouteCandidates(hero, state, state.routeSearchDistance, speedHypotheses)
		state.routeMaxFogTime = maximumFogTime
		state.lastCandidateEvaluationTime = now
		state.deferRouteUntil = nil
	end

	local useVisionEvidence = UI.visionAware:Get()
		and Entity.IsDormant(hero)
		and not state.wasInvisible
		and not NPC.HasState(hero, MODIFIER_STATE_INVISIBLE)
		and state.fogDuration >= VISION_GRACE_TIME

	local predictedPosition, predictedPath, scoredEntries, bestCandidate =
		SelectBestCandidate(hero, state, distance, now, useVisionEvidence, true)
	state.predictedPosition = predictedPosition
	state.predictedPath = predictedPath
	ComputeUncertainty(state, maximumFogTime)
	if bestCandidate then
		BuildHeatmap(state, scoredEntries or {}, bestCandidate)
		if useVisionEvidence and state.heatCells then
			for _, cell in ipairs(state.heatCells) do
				cell.position = SnapBehindVision(cell.position, state.projectionOrigin)
			end
		end
	end
end
--#endregion

--#region Rendering
local function WorldRadiusToScreen(center, worldRadius)
	local edge = Vector(center.x + worldRadius, center.y, center.z)
	local centerScreen, centerVisible = Render.WorldToScreen(center)
	local edgeScreen, edgeVisible = Render.WorldToScreen(edge)
	if not centerVisible or not edgeVisible then
		return nil, centerScreen, centerVisible
	end
	local dx = edgeScreen.x - centerScreen.x
	local dy = edgeScreen.y - centerScreen.y
	return math.sqrt(dx * dx + dy * dy), centerScreen, centerVisible
end

local function DrawHeatmap(heatCells, color, alphaScale)
	if not heatCells then
		return
	end
	for _, cell in ipairs(heatCells) do
		local screenRadius, screenPosition, visible = WorldRadiusToScreen(cell.position, cell.radius)
		if visible and screenPosition then
			local radius = screenRadius or (18 + cell.weight * 22)
			local weightAlpha = alphaScale * (0.2 + cell.weight * 0.8)
			Render.CircleGradient(
				screenPosition,
				radius,
				ScaledColor(color, weightAlpha * 0.04),
				ScaledColor(color, weightAlpha * 0.55),
				0,
				1
			)
		end
	end
end

local function DrawFadedPath(path, color, alphaScale)
	if not path or #path < 2 then
		return
	end

	local previousScreen = nil
	local previousVisible = false
	local segmentCount = #path - 1
	for index = 2, #path do
		local screenPosition, visible = Render.WorldToScreen(path[index])
		if previousScreen and previousVisible and visible then
			local t = (index - 1) / segmentCount
			local fade = 0.12 + 0.88 * (t * t)
			local thickness = 1.1 + t * 0.9
			Render.Line(previousScreen, screenPosition, ScaledColor(color, alphaScale * fade * 0.55), thickness + 1.6)
			Render.Line(previousScreen, screenPosition, ScaledColor(color, alphaScale * fade), thickness)
		end
		previousScreen = screenPosition
		previousVisible = visible
	end
end

local function DrawSoftMarker(screenPosition, color, alphaScale, pulse)
	local glowRadius = 14 + pulse * 2.5
	local coreRadius = 5.5 + pulse * 0.6
	Render.CircleGradient(
		screenPosition,
		glowRadius,
		ScaledColor(color, alphaScale * 0.02),
		ScaledColor(color, alphaScale * 0.28),
		0,
		1
	)
	Render.CircleGradient(
		screenPosition,
		coreRadius + 5,
		ScaledColor(color, alphaScale * 0.05),
		ScaledColor(color, alphaScale * 0.62),
		0,
		1
	)
	Render.Circle(screenPosition, coreRadius + 1.5, ScaledColor(color, alphaScale * 0.85), 1.4, 0, 1, true, 28)
	Render.FilledCircle(screenPosition, 2.2, ScaledColor(color, alphaScale), 0, 1, 16)
end

local function DrawPredictionLabel(state, screenPosition, color, alphaScale)
	local label = string.format("~ %s  %.1fs", state.heroName, state.fogDuration)
	local textSize = Render.TextSize(Persistent.font, 13, label)
	local textPosition = Vec2(screenPosition.x - textSize.x * 0.5, screenPosition.y - 22 - textSize.y)
	Render.Text(Persistent.font, 13, label, textPosition + Vec2(1, 1), Color(0, 0, 0, math.floor(210 * alphaScale)))
	Render.Text(Persistent.font, 13, label, textPosition, ScaledColor(color, alphaScale))
end
--#endregion

--#region Menu
function Script.OnScriptsLoaded()
	local page = Menu.Create("Info Screen", "Main", "Heroes Overlay")
	UI.menu = page:Create("Main"):Create("Fog Prediction")
	UI.enabled = UI.menu:Switch("Enable", true, "\u{f06e}")
	UI.maxFogTime = UI.menu:Slider("Maximum Fog Time", 1, 15, 5, "%ds")
	UI.updateInterval = UI.menu:Slider("Update Interval", 0.05, 0.5, 0.1, function(value)
		return string.format("%.2fs", value)
	end)
	UI.showPath = UI.menu:Switch("Show Predicted Path", true, "\u{f542}")
	UI.showHeatmap = UI.menu:Switch("Show Probability Heatmap", true, "\u{f06e}")
	UI.visionAware = UI.menu:Switch("Vision-Aware Branching", true, "\u{f5fd}")
	UI.markerColor = UI.menu:ColorPicker("Marker Color", Color(255, 155, 55, 235), "\u{f111}")
	UI.pathColor = UI.menu:ColorPicker("Path Color", Color(255, 190, 90, 145), "\u{f542}")
	UI.heatColor = UI.menu:ColorPicker("Heatmap Color", Color(255, 120, 40, 110), "\u{f06e}")

	UI.enabled:ToolTip("Estimate unseen enemy positions from movement, map-hack, vision, and navigation.")
	UI.maxFogTime:ToolTip("Hide estimates after the enemy has been unseen this long.")
	UI.updateInterval:ToolTip("How often prediction state is evaluated.")
	UI.visionAware:ToolTip("Reject routes that place a dormant enemy on currently visible ground.")
	UI.showPath:ToolTip("Draw a soft fading path toward the predicted position.")
	UI.showHeatmap:ToolTip("Soft probability blobs from competing route hypotheses.")

	UI.enabled:SetCallback(function(widget)
		local disabled = not widget:Get()
		SetMenuDisabled(disabled)
		if disabled then
			ResetRuntime()
		end
	end, true)

	Persistent.font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
	ResetRuntime()
end
--#endregion

--#region Lifecycle
function Script.OnUpdate()
	if not UI.enabled or not UI.enabled:Get() then
		return
	end

	local now = GameRules.GetGameTime()
	if now < Runtime.nextUpdateTime then
		return
	end
	Runtime.nextUpdateTime = now + UI.updateInterval:Get()

	local activeHeroes = {}
	local maximumFogTime = UI.maxFogTime:Get()
	for _, hero in pairs(LIB_HEROES_DATA.enemies) do
		if IsSupportedEnemy(hero) then
			local index = Entity.GetIndex(hero)
			activeHeroes[index] = true
			local state = Runtime.heroes[index]
			if not state then
				state = {
					hero = hero,
					heroName = HeroDisplayName(hero),
					wasVisible = false,
					hasObservation = false,
					visibleSamples = {},
					uncertaintyRadius = BASE_UNCERTAINTY,
					predictionConfidence = 0,
				}
				Runtime.heroes[index] = state
			end
			state.hero = hero

			if NPC.IsVisible(hero) and not Entity.IsDormant(hero) then
				ResetVisibleState(state, hero, now)
			else
				UpdateHiddenState(state, hero, now, maximumFogTime)
			end
		end
	end

	for index in pairs(Runtime.heroes) do
		if not activeHeroes[index] then
			Runtime.heroes[index] = nil
		end
	end
end

function Script.OnDraw()
	if not UI.enabled or not UI.enabled:Get() or Menu.VisualsIsEnabled() ~= true then
		return
	end

	local markerColor = UI.markerColor:Get()
	local pathColor = UI.pathColor:Get()
	local heatColor = UI.heatColor:Get()
	local showPath = UI.showPath:Get()
	local showHeatmap = UI.showHeatmap:Get()
	local maximumFogTime = math.max(UI.maxFogTime:Get(), 1)
	local pulse = 0.5 + 0.5 * math.sin(GameRules.GetGameTime() * 3.4)

	for _, state in pairs(Runtime.heroes) do
		local position = state.predictedPosition
		if position then
			local confidence = state.predictionConfidence or 0.5
			local ageFade = 1 - Clamp(state.fogDuration / maximumFogTime, 0, 1) * 0.55
			local alphaScale = ageFade * (0.4 + 0.6 * confidence)

			if showHeatmap then
				DrawHeatmap(state.heatCells, heatColor, alphaScale * 0.85)
			end

			local screenPosition, visible = Render.WorldToScreen(position)
			if visible then
				if showPath then
					DrawFadedPath(state.predictedPath, pathColor, alphaScale)
				end
				DrawSoftMarker(screenPosition, markerColor, alphaScale, pulse)
				DrawPredictionLabel(state, screenPosition, markerColor, alphaScale)
			end
		end
	end
end

function Script.OnSetDormant(npc, dormancyType)
	local state = Runtime.heroes[Entity.GetIndex(npc)]
	if state and state.wasVisible and dormancyType ~= Enum.DormancyType.ENTITY_NOT_DORMANT then
		state.fogTransitionTime = GameRules.GetGameTime()
	end
end

function Script.OnProjectile(
	_data,
	source,
	target,
	_ability,
	_moveSpeed,
	_sourceAttachment,
	_particleSystemHandle,
	_dodgeable,
	_isAttack,
	_expireTime,
	_maxImpactTime,
	_launchTick,
	_colorGemColor,
	_fullName,
	_name,
	_handle,
	targetLoc,
	_originalMoveSpeed
)
	if not UI.enabled or not UI.enabled:Get() then
		return
	end
	local state, hero = FindTrackedHero(source)
	if not state or state.wasVisible then
		return
	end
	local now = GameRules.GetGameTime()
	local position = ResolveHeroPosition(hero, state.predictedPosition or state.projectionOrigin)
	local facing = targetLoc
	if (not facing or facing:Length2D() <= MIN_DIRECTION_LENGTH) and target then
		facing = Entity.GetAbsOrigin(target)
	end
	ApplySignalReanchor(state, hero, position, now, facing)
end

function Script.OnLinearProjectileCreate(
	_data,
	source,
	origin,
	velocity,
	_particleIndex,
	_handle,
	_acceleration,
	_maxSpeed,
	_fowRadius,
	_distance,
	_colorGemColor,
	_fullName,
	_name
)
	if not UI.enabled or not UI.enabled:Get() then
		return
	end
	local state, hero = FindTrackedHero(source)
	if not state or state.wasVisible then
		return
	end
	local now = GameRules.GetGameTime()
	local position = origin and GroundPosition(origin) or ResolveHeroPosition(hero, state.predictedPosition)
	local facing = nil
	if velocity then
		local direction = Vector(velocity.x, velocity.y, 0)
		if direction:Length2D() > MIN_DIRECTION_LENGTH then
			facing = position + direction:Normalized():Scaled(240)
		end
	end
	ApplySignalReanchor(state, hero, position, now, facing)
end

function Script.OnParticleCreate(
	_data,
	index,
	entity,
	_entityId,
	entityForModifiers,
	_entityForModifiersId,
	_attachType,
	fullName,
	name,
	_hash,
	_particleNameIndex
)
	if not UI.enabled or not UI.enabled:Get() then
		return
	end
	if not IsSignalParticleName(fullName, name) then
		return
	end

	local owner = entity or entityForModifiers
	local state, hero = FindTrackedHero(owner)
	if not state then
		return
	end

	Runtime.signalParticles[index] = Entity.GetIndex(hero)
	if state.wasVisible then
		return
	end

	local now = GameRules.GetGameTime()
	local position = ResolveHeroPosition(hero, state.predictedPosition or state.projectionOrigin)
	ApplySignalReanchor(state, hero, position, now, nil)
end

function Script.OnParticleUpdate(_data, index, controlPoint, position)
	if controlPoint ~= 0 or not position then
		return
	end
	if not UI.enabled or not UI.enabled:Get() then
		return
	end

	local ownerIndex = Runtime.signalParticles[index]
	if not ownerIndex then
		return
	end
	local state = Runtime.heroes[ownerIndex]
	if not state or state.wasVisible or not state.hero then
		return
	end

	ApplySignalReanchor(state, state.hero, position, GameRules.GetGameTime(), nil)
end

function Script.OnParticleDestroy(_data, index, _destroyImmediately)
	Runtime.signalParticles[index] = nil
end

function Script.OnEntityDestroy(entity)
	local index = Entity.GetIndex(entity)
	Runtime.heroes[index] = nil
	for particleIndex, ownerIndex in pairs(Runtime.signalParticles) do
		if ownerIndex == index then
			Runtime.signalParticles[particleIndex] = nil
		end
	end
end

function Script.OnGameEnd()
	ResetRuntime()
end
--#endregion

return Script
