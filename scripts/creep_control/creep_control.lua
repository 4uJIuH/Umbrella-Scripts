local tab = Menu.Create("Creeps", "Main", "Creep Control")
tab:Icon("\u{f1bb}")

local main = tab:Create("Main")
local group = main:Create("Settings")
local filters = main:Create("Unit filters")

local next_run = 0.0
local last_orders = {}
local manual_hold = {}
local last_attack = {}
local assigned = {}
local camp_bans = {}
local camp_empty = {}
local ancient_camp = {}
local escape_until = {}
local next_cast = {}
local retreating = {}
local attack_target = {}
local waiting = {}
local tower_aggro = {}
local push_target = {}
local push_bans = {}
local cast_cache = {}
local fort_pos = nil
local debug_units = {}
local debug_second = 0.0
local debug_font = Render.LoadFont("Verdana", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)

local ui = {}

ui.enable = group:Switch("Enable Creep Control", false, "\u{f1bb}")
ui.enable:ToolTip("Доминаты фармят лес, остальные подконтрольные юниты пушат линию")

ui.toggle_bind = group:Bind("Toggle Creep Control", Enum.ButtonCode.KEY_NONE)
ui.toggle_bind:ToolTip("Нажал — ON, нажал ещё раз — OFF")

ui.wait_respawn = group:Slider("Wait for respawn", 0, 30, 12, function(value)
	if value == 0 then return "Off" end
	return tostring(value) .. "s"
end)
ui.wait_respawn:ToolTip("Ждать у кампа, если до респавна меньше N секунд. Сверх этого окна юнит ждёт, только если не успеет дойти до другого кампа раньше респавна. Off — не ждать вообще")

ui.ancients = group:Switch("Skip ancient camps", true, "\u{f6d3}")
ui.ancients:ToolTip("Не отправлять юнитов на ancient-кампы")

ui.abilities = group:Switch("Use abilities", true, "\u{f0e7}")
ui.abilities:ToolTip("Юнит применяет свои скиллы по нейтралам во время фарма")

ui.pushers = group:Switch("Lane role for push summons", true, "\u{f140}")
ui.pushers:ToolTip("Форжи, эйдолоны, волки Люкана и пеньки Фуриона бьют лайновых крипов и пушат вышки вместо леса")

ui.kite_tower = group:Switch("Dive towers only with allied creeps", true, "\u{f4d8}")
ui.kite_tower:ToolTip("Без своей волны юнит ждёт на границе радиуса вышки, а не лезет под неё")

ui.avoid = group:Switch("Avoid enemy heroes", true, "\u{f70c}")
ui.avoid:ToolTip("Вражеский герой рядом — камп или линия банится на минуту, юнит отходит от героя")

ui.avoid_radius = group:Slider("Avoid radius", 400, 2000, 700, "%d")

ui.retreat = group:Switch("Retreat to fountain on low HP", true, "\u{f004}")
ui.retreat:ToolTip("Юнит уходит на свой фонтан, пока не подлечится. Иллюзии не отступают")

ui.retreat_hp = group:Slider("Retreat below HP", 5, 60, 25, "%d%%")

ui.humanizer = group:Switch("Humanizer safe targets", false, "\u{f21b}")
ui.humanizer:ToolTip("Проверять Humanizer.IsSafeTarget перед приказом по цели. Может блокировать приказы вне обзора — включай для теста")

ui.debug = group:Switch("Debug overlay", false, "\u{f188}")
ui.debug:ToolTip("Показывает секунду таймера и состояние юнитов")

ui.filter_illusions = filters:Switch(
	"Illusions",
	true,
	"panorama/images/spellicons/terrorblade_conjure_image_png.vtex_c"
)
ui.filter_summons = filters:Switch(
	"Summons / Dominated creeps",
	true,
	"panorama/images/spellicons/enigma_demonic_conversion_png.vtex_c"
)
ui.filter_spirit_bear = filters:Switch(
	"Spirit Bear",
	true,
	"panorama/images/spellicons/lone_druid_spirit_bear_png.vtex_c"
)

-- Keyed by entity index; tables are cleared in place so these references stay valid.
local PER_UNIT = {
	last_orders, manual_hold, last_attack, assigned, escape_until, next_cast,
	retreating, attack_target, waiting, tower_aggro, push_target, cast_cache,
}

local function clear(t)
	for k in pairs(t) do t[k] = nil end
end

local function reset_state()
	for i = 1, #PER_UNIT do clear(PER_UNIT[i]) end
	clear(camp_bans)
	clear(push_bans)
	clear(camp_empty)
	clear(ancient_camp)
	debug_units = {}
	next_run = 0.0
end

-- Entity indices are reused, so state of gone units must not leak to new ones.
local function purge_gone(alive)
	for i = 1, #PER_UNIT do
		local t = PER_UNIT[i]
		for idx in pairs(t) do
			if not alive[idx] then t[idx] = nil end
		end
	end
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.wait_respawn:Disabled(not on)
	ui.ancients:Disabled(not on)
	ui.abilities:Disabled(not on)
	ui.pushers:Disabled(not on)
	ui.kite_tower:Disabled(not on or not ui.pushers:Get())
	ui.avoid:Disabled(not on)
	ui.avoid_radius:Disabled(not on or not ui.avoid:Get())
	ui.retreat:Disabled(not on)
	ui.retreat_hp:Disabled(not on or not ui.retreat:Get())
	ui.humanizer:Disabled(not on)
	ui.debug:Disabled(not on)
	ui.filter_illusions:Disabled(not on)
	ui.filter_summons:Disabled(not on)
	ui.filter_spirit_bear:Disabled(not on)
end

ui.enable:SetCallback(function()
	refresh_disabled()
	if ui.toggle_bind:IsToggled() ~= ui.enable:Get() then
		ui.toggle_bind:SetToggled(ui.enable:Get())
	end
	if not ui.enable:Get() then
		reset_state()
	end
end, true)

ui.avoid:SetCallback(function() refresh_disabled() end)
ui.retreat:SetCallback(function() refresh_disabled() end)
ui.pushers:SetCallback(function() refresh_disabled() end)

ui.toggle_bind:SetKeyCallback(function(_, _, event)
	if event ~= Enum.EKeyEvent.EKeyEvent_KEY_DOWN then return end
	ui.enable:Set(not ui.enable:Get())
end)

local UPDATE_INTERVAL   = 0.15
local REISSUE_INTERVAL  = 1.20
local REISSUE_JITTER    = 0.60
local POS_EPS           = 120.0
local MANUAL_HOLD       = 5.0
local CAMP_RADIUS       = 420.0
local CAMP_RADIUS_MAX   = 620.0
local CAMP_BOX_MARGIN   = 200.0
local CAMP_MIN_EXTENT   = 250.0
local CURATED_MATCH_RADIUS = 600.0
local CAMP_ARRIVE       = 550.0
local CAMP_ENGAGE       = 900.0
local FIGHT_RADIUS      = 600.0
local CAMP_BAN_TIME     = 60.0
local SWITCH_MARGIN     = 600.0
local PASSBY_RADIUS     = 1100.0
local PASSBY_MARGIN     = 200.0
local CAST_INTERVAL     = 0.35
local CAST_RANGE_FALLBACK = 400.0
local ABILITY_MAX_SLOT  = 24
local CAST_CACHE_TTL    = 2.0
local ESCAPE_GRACE      = 8.0
local ATTACK_IDLE_GRACE = 1.5
local THREAT_NEAR       = 1600.0
local THREAT_NEAR_SQR   = THREAT_NEAR * THREAT_NEAR
local THREAT_PENALTY    = 12000.0
local CAMP_SCAN         = 1400.0
local WAIT_DISTANCE     = 650.0
local WAIT_MARGIN       = 300.0
local PATH_DETOUR       = 1.25
local TRAVEL_SLACK      = 1.5
local FALLBACK_SPEED    = 300.0
local CREEP_SEARCH      = 2000.0
local ALLIED_RADIUS     = 900.0
local TOWER_MARGIN      = 150.0
local KITE_MARGIN       = 60.0
local TOWER_WATCH_EXTRA = 250.0
local DEAGGRO_TIME      = 1.0
local DEAGGRO_EXTRA     = 80.0
local FLEE_DISTANCE     = 800.0
local FLEE_ANGLES       = { 0.0, math.pi / 4, -math.pi / 4, math.pi / 2, -math.pi / 2 }
local LIFETIME_MARGIN   = 5.0

-- Dota modifiers that carry the expiry time of illusions and timed summons.
local LIFETIME_MODS = { "modifier_illusion", "modifier_kill" }

local PUSH_PATTERNS = { "forged_spirit", "eidolon", "lycan_wolf", "furion_treant" }

local BACKDOOR_MODS = { "modifier_backdoor_protection_active" }

local BARRACKS_THREAT = 900.0
local PUSH_PATH_CANDIDATES = 3

local BH = Enum.AbilityBehavior
local SKIP_BEHAVIOR = math.floor(
	BH.DOTA_ABILITY_BEHAVIOR_HIDDEN
	| BH.DOTA_ABILITY_BEHAVIOR_PASSIVE
	| BH.DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE
	| BH.DOTA_ABILITY_BEHAVIOR_CHANNELLED
	| BH.DOTA_ABILITY_BEHAVIOR_ITEM
	| BH.DOTA_ABILITY_BEHAVIOR_TOGGLE
	| BH.DOTA_ABILITY_BEHAVIOR_AURA
	| BH.DOTA_ABILITY_BEHAVIOR_AUTOCAST
	| BH.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING
)
local UNIT_TARGET_BEHAVIOR = math.floor(BH.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
local POINT_BEHAVIOR = math.floor(BH.DOTA_ABILITY_BEHAVIOR_POINT)
local NO_TARGET_BEHAVIOR = math.floor(BH.DOTA_ABILITY_BEHAVIOR_NO_TARGET)

local TT = Enum.TargetTeam
local CASTABLE_TARGET_TEAM = {
	[TT.DOTA_UNIT_TARGET_TEAM_ENEMY] = true,
	[TT.DOTA_UNIT_TARGET_TEAM_BOTH] = true,
	[TT.DOTA_UNIT_TARGET_TEAM_CUSTOM] = true,
}

local ORDER_ATTACK_MOVE = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE
local ORDER_ATTACK_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
local ORDER_CAST_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local ORDER_CAST_POSITION = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION
local ORDER_CAST_NO_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
local ISSUER_PASSED_UNIT = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY
local UT = Enum.UnitTypeFlags
local UNIT_SCAN_FLAGS = UT.TYPE_HERO | UT.TYPE_CONSIDERED_HERO | UT.TYPE_CREEP | UT.TYPE_LANE_CREEP

local CT = Enum.ECampType
local CAMP_TYPE_NAME = {
	[CT.ECampType_SMALL] = "small",
	[CT.ECampType_MEDIUM] = "medium",
	[CT.ECampType_LARGE] = "large",
	[CT.ECampType_ANCIENT] = "ancient",
}

local TEAM_BOTH = Enum.TeamType.TEAM_BOTH
local TEAM_ENEMY = Enum.TeamType.TEAM_ENEMY
local TEAM_FRIEND = Enum.TeamType.TEAM_FRIEND

local ABILITY_DENY_PATTERNS = {
	"_return$",
	"stone_form",
	"savage_roar",
	"invisibility",
	"_teleport",
	"phase_shift",
}

local RADIANT_CAMP_DATA = {
	{ -4005.7, 919.4, 256.0 },
	{ -4961.1, -96.8, 256.0 },
	{ -2019.3, -4785.8, 128.0 },
	{ -1464.0, -3328.2, 128.0 },
	{ 299.8, -5123.4, 134.0 },
	{ 1867.4, -4108.4, 256.0 },
	{ 4012.7, -5092.2, 128.0 },
	{ 4711.1, -3764.4, 128.0 },
	{ 4441.3, -8298.8, 0.0 },
	{ 2753.8, -8273.6, 0.0 },
	{ -725.0, -7686.8, 134.0 },
	{ -2439.7, -8378.8, 128.0 },
	{ -8055.5, -1747.1, 256.0 },
	{ -8316.3, -549.0, 256.0 },
}

local DIRE_CAMP_DATA = {
	{ 8533.5, 1316.6, 256.0 },
	{ 8008.8, -36.1, 256.0 },
	{ 4213.9, 53.0, 256.0 },
	{ 3398.2, -1310.3, 256.0 },
	{ 1039.3, 2596.9, 128.0 },
	{ 1339.3, 4212.8, 128.0 },
	{ -819.1, 4844.6, 134.0 },
	{ -2677.6, 3829.5, 256.0 },
	{ -3885.8, 4947.7, 128.0 },
	{ -3007.5, 7442.9, 0.0 },
	{ -4180.4, 8270.2, 0.0 },
	{ 430.9, 7682.1, 134.0 },
	{ 2022.9, 7878.1, 128.0 },
}

local FOUNTAIN_DATA = {
	radiant = { -6675.2, -6239.6, 384.0 },
	dire = { 6638.6, 6033.3, 384.0 },
}

local fountains = nil

local function fountain_position(my_radiant)
	if not fountains then
		fountains = {
			radiant = Vector(FOUNTAIN_DATA.radiant[1], FOUNTAIN_DATA.radiant[2], FOUNTAIN_DATA.radiant[3]),
			dire = Vector(FOUNTAIN_DATA.dire[1], FOUNTAIN_DATA.dire[2], FOUNTAIN_DATA.dire[3]),
		}
	end
	return my_radiant and fountains.radiant or fountains.dire
end

local camps = nil
local camps_refined = false
local camps_matched = 0

local function refine_camps_from_api()
	local raw = Camps.GetAll()
	if not raw or #raw == 0 then return false end
	local matched = 0
	for i = 1, #raw do
		local box = Camp.GetCampBox(raw[i])
		if box and box.min and box.max then
			local cx = (box.min:GetX() + box.max:GetX()) * 0.5
			local cy = (box.min:GetY() + box.max:GetY()) * 0.5
			local cz = (box.min:GetZ() + box.max:GetZ()) * 0.5
			local extent = math.max(
				math.abs(box.max:GetX() - box.min:GetX()),
				math.abs(box.max:GetY() - box.min:GetY())
			) * 0.5
			local best, best_dist = nil, CURATED_MATCH_RADIUS * CURATED_MATCH_RADIUS
			for id = 1, #camps do
				local dx = camps[id].pos:GetX() - cx
				local dy = camps[id].pos:GetY() - cy
				local dist = dx * dx + dy * dy
				if dist < best_dist then best, best_dist = camps[id], dist end
			end
			if best and (best.matched_dist == nil or best_dist < best.matched_dist) then
				best.matched_dist = best_dist
				best.pos = Vector(cx, cy, cz)
				best.exit = math.max(extent, CAMP_MIN_EXTENT)
				best.radius = math.min(CAMP_RADIUS_MAX, math.max(CAMP_RADIUS, extent + CAMP_BOX_MARGIN))
				local kind = Camp.GetType(raw[i])
				best.type_name = CAMP_TYPE_NAME[kind]
				best.ancient = kind == CT.ECampType_ANCIENT
				matched = matched + 1
			end
		end
	end
	camps_matched = matched
	return matched > 0
end

local function ensure_camps()
	if not camps then
		camps = {}
		for i = 1, #RADIANT_CAMP_DATA do
			local c = RADIANT_CAMP_DATA[i]
			camps[#camps + 1] = { pos = Vector(c[1], c[2], c[3]), radiant = true, radius = CAMP_RADIUS }
		end
		for i = 1, #DIRE_CAMP_DATA do
			local c = DIRE_CAMP_DATA[i]
			camps[#camps + 1] = { pos = Vector(c[1], c[2], c[3]), radiant = false, radius = CAMP_RADIUS }
		end
	end
	if not camps_refined then
		camps_refined = refine_camps_from_api()
	end
end

local function camp_is_ancient(id)
	return camps[id].ancient == true or ancient_camp[id] == true
end

local function controllable_by_me(u, my_id)
	return Entity.IsControllableByPlayer(u, my_id) == true
end

local function is_eligible(u, my_id, my_hero)
	if u == my_hero then return false end
	if not controllable_by_me(u, my_id) then return false end
	if not Entity.IsAlive(u) then return false end
	if NPC.IsHero(u) and not NPC.IsIllusion(u) then return false end
	if NPC.IsCourier(u) then return false end
	if NPC.IsWard(u) then return false end
	if NPC.IsStructure(u) or NPC.IsTower(u) or NPC.IsBarracks(u) or NPC.IsFort(u) then return false end
	if NPC.IsWaitingToSpawn(u) then return false end
	return true
end

local function unit_category(u)
	if NPC.IsIllusion(u) then return "illusions" end
	local name = NPC.GetUnitName(u)
	if name and (name:find("lone_druid_bear") or name:find("spirit_bear")) then
		return "spirit_bear"
	end
	return "summons"
end

local FILTER_SWITCH = {
	illusions   = function() return ui.filter_illusions:Get() end,
	summons     = function() return ui.filter_summons:Get() end,
	spirit_bear = function() return ui.filter_spirit_bear:Get() end,
}

local function passes_filter(u)
	local fn = FILTER_SWITCH[unit_category(u)]
	return fn and fn() or false
end

local function append_spirit_bears(units, known, my_id, my_team, my_hero)
	local heroes = Heroes.GetAll()
	for i = 1, #heroes do
		local hero = heroes[i]
		if Entity.GetTeamNum(hero) == my_team then
			local summon = NPC.GetAbility(hero, "lone_druid_spirit_bear")
			local bear = summon and CustomEntities.GetSpiritBear(summon)
			if bear and bear ~= my_hero then
				local idx = Entity.GetIndex(bear)
				if idx and not known[idx]
					and Entity.IsAlive(bear)
					and Entity.IsDormant(bear) ~= true
					and not NPC.IsWaitingToSpawn(bear)
					and controllable_by_me(bear, my_id)
					and passes_filter(bear) then
					units[#units + 1] = bear
					known[idx] = true
				end
			end
		end
	end
end

local function own_fort(my_team)
	if fort_pos then return fort_pos end
	local forts = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_FORT)
	for i = 1, #forts do
		if Entity.GetTeamNum(forts[i]) == my_team then
			fort_pos = Entity.GetAbsOrigin(forts[i])
			return fort_pos
		end
	end
	return nil
end

local function safe_offset(camp, home, distance, key)
	if camp[key] then return camp[key] end
	local pos = camp.pos
	if home then
		local direct = pos:Extend2D(home, distance)
		if GridNav.IsTraversable(direct) then
			camp[key] = direct
			return direct
		end
	end
	local best, best_score = nil, -math.huge
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local candidate = Vector(
			pos:GetX() + math.cos(angle) * distance,
			pos:GetY() + math.sin(angle) * distance,
			pos:GetZ()
		)
		if GridNav.IsTraversable(candidate) then
			local score = home and -candidate:Distance2D(home) or 0
			if score > best_score then best, best_score = candidate, score end
		end
	end
	camp[key] = best or pos
	return camp[key]
end

local function wait_position(camp, home)
	local distance = camp.exit and (camp.exit + WAIT_MARGIN) or WAIT_DISTANCE
	return safe_offset(camp, home, distance, "wait")
end

local function unit_speed(u)
	local speed = NPC.GetMoveSpeed(u)
	if not speed or speed <= 0 then
		speed = NPC.GetBaseSpeed(u)
	end
	if not speed or speed <= 0 then return FALLBACK_SPEED end
	return speed
end

-- How far the unit can walk before it expires; math.huge for permanent units.
local function reach_distance(u, now)
	local left = math.huge
	for i = 1, #LIFETIME_MODS do
		local mod = NPC.GetModifier(u, LIFETIME_MODS[i])
		if mod then
			local die = Modifier.GetDieTime(mod)
			if die and die > now then left = math.min(left, die - now) end
		end
	end
	if left == math.huge then return math.huge end
	return math.max(0.0, left - LIFETIME_MARGIN) * unit_speed(u)
end

-- Walkable point away from the nearest visible threat, or nil if none is close.
local function flee_point(u_pos, threats)
	local ux, uy = u_pos:GetX(), u_pos:GetY()
	local nearest, best = nil, THREAT_NEAR_SQR
	for i = 1, #threats do
		local d = threats[i]:DistanceSqr2D(u_pos)
		if d < best then nearest, best = threats[i], d end
	end
	if not nearest then return nil end
	local base = math.atan(uy - nearest:GetY(), ux - nearest:GetX())
	for i = 1, #FLEE_ANGLES do
		local a = base + FLEE_ANGLES[i]
		local p = Vector(ux + math.cos(a) * FLEE_DISTANCE, uy + math.sin(a) * FLEE_DISTANCE, u_pos:GetZ())
		if GridNav.IsTraversable(p) then return p end
	end
	return nil
end

local function game_clock()
	local t = GameRules.GetGameTime() - GameRules.GetGameStartTime()
	if t <= 0 then
		t = GameRules.GetDOTATime(false, false) or 0
	end
	if t < 0 then return 0 end
	return t
end

local function neutrals_near(pos, radius, my_team)
	local found = {}
	local list = NPCs.InRadius(pos, radius, my_team, TEAM_BOTH, true, true)
	for i = 1, #list do
		local n = list[i]
		if NPC.IsNeutral(n)
			and Entity.GetTeamNum(n) ~= my_team
			and Entity.IsAlive(n)
			and not NPC.IsRoshan(n)
			and not NPC.IsWaitingToSpawn(n) then
			found[#found + 1] = n
		end
	end
	return found
end

local function camp_neutrals(camp, my_team)
	return neutrals_near(camp.pos, camp.radius or CAMP_RADIUS, my_team)
end

local function nearest_of(list, pos)
	local px, py = pos:GetX(), pos:GetY()
	local best, best_d = nil, math.huge
	for i = 1, #list do
		local x, y = Entity.GetAbsOriginXYZ(list[i])
		local dx, dy = x - px, y - py
		local d = dx * dx + dy * dy
		if d < best_d then best, best_d = list[i], d end
	end
	return best
end

local function sticky_victim(idx, list, pos)
	local previous = attack_target[idx]
	if previous then
		for i = 1, #list do
			if Entity.GetIndex(list[i]) == previous then
				return list[i]
			end
		end
	end
	local victim = nearest_of(list, pos)
	attack_target[idx] = victim and Entity.GetIndex(victim) or nil
	return victim
end

local function has_ancient(list)
	if not list then return false end
	for i = 1, #list do
		if NPC.IsAncient(list[i]) then return true end
	end
	return false
end

local function visible_threats(my_team)
	local found = {}
	local heroes = Heroes.GetAll()
	for i = 1, #heroes do
		local h = heroes[i]
		if Entity.GetTeamNum(h) ~= my_team
			and Entity.IsAlive(h)
			and NPC.IsVisible(h)
			and not NPC.IsIllusion(h) then
			found[#found + 1] = Entity.GetAbsOrigin(h)
		end
	end
	return found
end

local function camp_open(id, now)
	if (camp_bans[id] or 0) > now then return false end
	if (camp_empty[id] or 0) > now then return false end
	return true
end

local function pick_camp(ctx, u_pos, relaxed, reach)
	local now = ctx.now
	local best, best_score = nil, math.huge
	for id = 1, #camps do
		local camp = camps[id]
		if camp.radiant == ctx.my_radiant then
			local usable
			if ctx.skip_ancients and camp_is_ancient(id) then
				usable = false
			elseif relaxed then
				usable = (camp_bans[id] or 0) <= now
			else
				usable = camp_open(id, now) and (ctx.load[id] or 0) < ctx.limit
			end
			local score = usable and camp.pos:Distance2D(u_pos) or 0
			if usable and reach and score * PATH_DETOUR > reach then usable = false end
			if usable then
				for i = 1, #ctx.threats do
					if camp.pos:DistanceSqr2D(ctx.threats[i]) < THREAT_NEAR_SQR then
						score = score + THREAT_PENALTY
						break
					end
				end
				if score < best_score then best, best_score = id, score end
			end
		end
	end
	return best
end

local function nearest_live_camp(u_pos, my_team, my_radiant, now, skip_ancients, current_id, load)
	local current_dist = current_id and camps[current_id].pos:Distance2D(u_pos) or math.huge
	local best, best_dist = nil, math.huge
	for id = 1, #camps do
		if id ~= current_id
			and camps[id].radiant == my_radiant
			and (camp_bans[id] or 0) <= now
			and (load[id] or 0) == 0
			and not (skip_ancients and camp_is_ancient(id)) then
			local dist = camps[id].pos:Distance2D(u_pos)
			if dist < best_dist then
				if dist < PASSBY_RADIUS and dist + PASSBY_MARGIN < current_dist then
					local neutrals = camp_neutrals(camps[id], my_team)
					if #neutrals > 0 then
						camp_empty[id] = nil
						if has_ancient(neutrals) then
							ancient_camp[id] = true
						end
						if not (skip_ancients and camp_is_ancient(id)) then
							best, best_dist = id, dist
						end
					end
				elseif dist + SWITCH_MARGIN < current_dist and (camp_empty[id] or 0) <= now then
					best, best_dist = id, dist
				end
			end
		end
	end
	return best
end

local function nearest_other_camp_distance(u_pos, my_radiant, now, load, skip_ancients, current_id)
	local best = math.huge
	for id = 1, #camps do
		if id ~= current_id
			and camps[id].radiant == my_radiant
			and (camp_bans[id] or 0) <= now
			and (camp_empty[id] or 0) <= now
			and (load[id] or 0) == 0
			and not (skip_ancients and camp_is_ancient(id)) then
			local dist = camps[id].pos:Distance2D(u_pos)
			if dist < best then best = dist end
		end
	end
	return best
end

local function enemy_team(my_team)
	if my_team == Enum.TeamNum.TEAM_RADIANT then
		return Enum.TeamNum.TEAM_DIRE
	end
	return Enum.TeamNum.TEAM_RADIANT
end

local function is_pusher(u)
	local name = NPC.GetUnitName(u)
	if not name then return false end
	for i = 1, #PUSH_PATTERNS do
		if name:find(PUSH_PATTERNS[i]) then return true end
	end
	return false
end

local function enemy_lane_creeps(u)
	local found = {}
	local list = Entity.GetUnitsInRadius(u, CREEP_SEARCH, TEAM_ENEMY, true, true)
	for i = 1, #list do
		local n = list[i]
		if NPC.IsLaneCreep(n) and Entity.IsAlive(n) and not NPC.IsWaitingToSpawn(n) then
			found[#found + 1] = n
		end
	end
	return found
end

local function build_enemy_towers(e_team)
	local list = {}
	local towers = Towers.GetAll()
	for i = 1, #towers do
		local tower = towers[i]
		if Entity.GetTeamNum(tower) == e_team and Entity.IsAlive(tower) then
			list[#list + 1] = {
				tower = tower,
				pos = Entity.GetAbsOrigin(tower),
				threat = (NPC.GetAttackRange(tower) or 700.0) + TOWER_MARGIN,
			}
		end
	end
	return list
end

local function build_enemy_barracks(e_team)
	local list = {}
	local raxes = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_BARRACKS)
	for i = 1, #raxes do
		local rax = raxes[i]
		if Entity.GetTeamNum(rax) == e_team and Entity.IsAlive(rax) then
			local name = NPC.GetUnitName(rax)
			local lane = name and name:match("_rax_(%a+)")
			if lane then
				list[#list + 1] = {
					tower = rax,
					tier = 99,
					lane = lane,
					pos = Entity.GetAbsOrigin(rax),
					threat = BARRACKS_THREAT,
				}
			end
		end
	end
	return list
end

local function build_push_targets(tower_list, rax_list)
	local lanes = {}
	for i = 1, #tower_list do
		local entry = tower_list[i]
		local name = NPC.GetUnitName(entry.tower)
		local tier = tonumber(name and name:match("_tower(%d)") or "") or 99
		local lane = (name and name:match("_tower%d_(%a+)")) or "base"
		local current = lanes[lane]
		if not current or tier < current.tier then
			lanes[lane] = {
				tower = entry.tower,
				tier = tier,
				pos = entry.pos,
				threat = entry.threat,
			}
		end
	end
	local list = {}
	for _, entry in pairs(lanes) do
		list[#list + 1] = entry
	end
	for i = 1, #rax_list do
		local entry = rax_list[i]
		if not lanes[entry.lane] then
			list[#list + 1] = entry
		end
	end
	return list
end

local function tower_shooting_at(unit, u_pos, tower_list)
	for i = 1, #tower_list do
		local entry = tower_list[i]
		local watch = entry.threat + TOWER_WATCH_EXTRA
		if entry.pos:DistanceSqr2D(u_pos) < watch * watch then
			if Tower.GetAttackTarget(entry.tower) == unit then
				return entry
			end
		end
	end
	return nil
end

local function tower_deaggro(ctx, u, idx, u_pos)
	local aggro = tower_aggro[idx]
	if aggro and aggro.until_t <= ctx.now then
		tower_aggro[idx] = nil
		aggro = nil
	end
	local shooter = tower_shooting_at(u, u_pos, ctx.tower_list())
	if shooter then
		local ring = shooter.threat + KITE_MARGIN + DEAGGRO_EXTRA
		if shooter.pos:DistanceSqr2D(u_pos) < ring * ring then
			aggro = {
				until_t = ctx.now + DEAGGRO_TIME,
				dest = shooter.pos:Extend2D(u_pos, ring),
			}
			tower_aggro[idx] = aggro
		end
	end
	return aggro
end

local function backdoor_active(building)
	return NPC.HasAnyModifier(building, BACKDOOR_MODS) == true
end

local function path_length(from, to)
	local path = GridNav.BuildPath(from, to, true)
	if not path or #path < 2 then
		return from:Distance2D(to)
	end
	local total = 0.0
	for i = 2, #path do
		total = total + path[i]:Distance2D(path[i - 1])
	end
	return total
end

local function push_banned(tower, now)
	return (push_bans[Entity.GetIndex(tower)] or 0) > now
end

local function choose_push_target(list, u_pos, reach, now)
	local ranked = {}
	for i = 1, #list do
		if not push_banned(list[i].tower, now) then
			ranked[#ranked + 1] = { entry = list[i], dist = list[i].pos:DistanceSqr2D(u_pos) }
		end
	end
	if #ranked == 0 then return nil end
	table.sort(ranked, function(a, b) return a.dist < b.dist end)
	local best, best_cost = nil, math.huge
	local limit = math.min(#ranked, PUSH_PATH_CANDIDATES)
	for i = 1, limit do
		local cost = path_length(u_pos, ranked[i].entry.pos)
		if cost <= reach and cost < best_cost then
			best, best_cost = ranked[i].entry, cost
		end
	end
	return best
end

local function pinned_push_target(idx, list, now)
	local pinned = push_target[idx]
	if not pinned then return nil end
	if (push_bans[pinned] or 0) > now then
		push_target[idx] = nil
		return nil
	end
	for i = 1, #list do
		if Entity.GetIndex(list[i].tower) == pinned then
			return list[i]
		end
	end
	push_target[idx] = nil
	return nil
end

local function need_reissue(u, idx, mode, pos, target, now)
	local prev = last_orders[idx]
	if not prev then return true end
	if mode == "farm" or mode == "attack" or mode == "push" then
		if NPC.IsAttacking(u) or NPC.IsTurning(u) then return false end
		if now - (last_attack[idx] or 0) < ATTACK_IDLE_GRACE then return false end
	end
	if prev.mode ~= mode then return true end
	if prev.target ~= target then return true end
	if math.abs(prev.x - pos:GetX()) > POS_EPS then return true end
	if math.abs(prev.y - pos:GetY()) > POS_EPS then return true end
	if now - prev.t < prev.ttl then return false end
	return true
end

local function remember(idx, mode, pos, target, now)
	local ttl = REISSUE_INTERVAL + math.random() * REISSUE_JITTER
	local prev = last_orders[idx]
	if prev then
		prev.mode, prev.x, prev.y, prev.target, prev.t, prev.ttl =
			mode, pos:GetX(), pos:GetY(), target, now, ttl
	else
		last_orders[idx] = {
			mode = mode,
			x = pos:GetX(),
			y = pos:GetY(),
			target = target,
			t = now,
			ttl = ttl,
		}
	end
end

local function safe_to_target(entity)
	if not ui.humanizer:Get() or not entity then return true end
	return Humanizer.IsSafeTarget(entity) ~= false
end

local function order_attack_move(player, unit, pos)
	Player.PrepareUnitOrders(player, ORDER_ATTACK_MOVE, nil, pos, nil, ISSUER_PASSED_UNIT, unit)
end

local function order_attack_target(player, unit, target)
	Player.PrepareUnitOrders(player, ORDER_ATTACK_TARGET, target, nil, nil, ISSUER_PASSED_UNIT, unit)
end

local function order_cast(player, unit, order, target, pos, ability)
	Player.PrepareUnitOrders(player, order, target, pos, ability, ISSUER_PASSED_UNIT, unit)
end

local function ability_denied(name)
	if name == "" then return true end
	for i = 1, #ABILITY_DENY_PATTERNS do
		if name:find(ABILITY_DENY_PATTERNS[i]) then return true end
	end
	return false
end

-- Name, behavior and target team are static per ability, so they are scanned once per TTL.
local function cast_candidates(unit, idx, now)
	local cached = cast_cache[idx]
	if cached and cached.until_t > now then return cached.list end
	local list = {}
	for slot = 0, ABILITY_MAX_SLOT do
		local ability = NPC.GetAbilityByIndex(unit, slot)
		if ability
			and not Ability.IsPassive(ability)
			and not ability_denied(Ability.GetName(ability) or "") then
			local behavior = math.floor(Ability.GetBehavior(ability) or 0)
			if (behavior & SKIP_BEHAVIOR) == 0 then
				local order = nil
				if (behavior & UNIT_TARGET_BEHAVIOR) ~= 0 then
					if CASTABLE_TARGET_TEAM[Ability.GetTargetTeam(ability)] then
						order = ORDER_CAST_TARGET
					end
				elseif (behavior & POINT_BEHAVIOR) ~= 0 then
					order = ORDER_CAST_POSITION
				elseif (behavior & NO_TARGET_BEHAVIOR) ~= 0 then
					order = ORDER_CAST_NO_TARGET
				end
				if order then
					list[#list + 1] = { ability = ability, order = order }
				end
			end
		end
	end
	cast_cache[idx] = { until_t = now + CAST_CACHE_TTL, list = list }
	return list
end

local function try_cast(player, unit, idx, u_pos, neutrals, now)
	if (next_cast[idx] or 0) > now then return false end
	local candidates = cast_candidates(unit, idx, now)
	if #candidates == 0 then return false end
	if NPC.IsSilenced(unit) or NPC.IsStunned(unit) or NPC.IsChannellingAbility(unit) then return false end

	local victim = nearest_of(neutrals, u_pos)
	if not victim then return false end
	local victim_pos = Entity.GetAbsOrigin(victim)
	local victim_dist = victim_pos:Distance2D(u_pos)
	local mana = NPC.GetMana(unit)

	for i = 1, #candidates do
		local ability, order = candidates[i].ability, candidates[i].order
		if Ability.GetLevel(ability) > 0
			and not Ability.IsHidden(ability)
			and not Ability.IsInAbilityPhase(ability)
			and Ability.IsCastable(ability, mana) then
			local range = Ability.GetCastRange(ability) or 0
			if range <= 0 then range = CAST_RANGE_FALLBACK end
			if victim_dist <= range
				and (order ~= ORDER_CAST_TARGET or safe_to_target(victim)) then
				local target = order == ORDER_CAST_TARGET and victim or nil
				local pos = order == ORDER_CAST_POSITION and victim_pos or nil
				order_cast(player, unit, order, target, pos, ability)
				next_cast[idx] = now + CAST_INTERVAL
				return true
			end
		end
	end
	return false
end

local function release(idx, load)
	local id = assigned[idx]
	if id then
		load[id] = math.max(0, (load[id] or 1) - 1)
		assigned[idx] = nil
	end
	waiting[idx] = nil
end

local function tick_retreat(ctx, u, idx, u_pos, health_pct)
	release(idx, ctx.load)
	local dest = fountain_position(ctx.my_radiant)
	if need_reissue(u, idx, "home", dest, nil, ctx.now) then
		NPC.MoveTo(u, dest)
		remember(idx, "home", dest, nil, ctx.now)
	end
	if ctx.debug_on then
		debug_units[#debug_units + 1] = {
			pos = u_pos,
			text = string.format("home | hp %.0f%%", health_pct),
		}
	end
end

local tick_farmer

local function tick_pusher(ctx, u, idx, u_pos, reach)
	local now = ctx.now

	local escaping = ctx.avoid_on and (escape_until[idx] or 0) > now
	if ctx.avoid_on and not escaping then
		local near = Entity.GetHeroesInRadius(u, ctx.avoid_radius, TEAM_ENEMY, true, true)
		if #near > 0 then
			if push_target[idx] then
				push_bans[push_target[idx]] = now + CAMP_BAN_TIME
				push_target[idx] = nil
			end
			escape_until[idx] = now + ESCAPE_GRACE
			escaping = true
		end
	end

	local creeps = enemy_lane_creeps(u)
	local targets = ctx.target_list()
	local entry = pinned_push_target(idx, targets, now)
	if not entry then
		entry = choose_push_target(targets, u_pos, reach, now)
		if entry then
			push_target[idx] = Entity.GetIndex(entry.tower)
		end
	end

	if not escaping and not entry and #creeps == 0 then
		return tick_farmer(ctx, u, idx, u_pos, reach)
	end

	release(idx, ctx.load)
	waiting[idx] = nil

	local mode, dest, target, victim = nil, nil, nil, nil
	local casted = false
	local aggro = tower_deaggro(ctx, u, idx, u_pos)

	if escaping then
		attack_target[idx] = nil
		mode = "flee"
		dest = flee_point(u_pos, ctx.threats) or fountain_position(ctx.my_radiant)
	elseif aggro then
		attack_target[idx] = nil
		mode = "deaggro"
		dest = aggro.dest
	elseif #creeps > 0 then
		victim = sticky_victim(idx, creeps, u_pos)
		if victim then
			mode = "attack"
			target = attack_target[idx]
			dest = Entity.GetAbsOrigin(victim)
		end
	elseif entry then
		attack_target[idx] = nil
		mode = "push"
		dest = entry.pos
	else
		attack_target[idx] = nil
	end

	if ctx.kite_on and entry and mode and mode ~= "deaggro" and mode ~= "flee" then
		local threat = entry.threat or ((NPC.GetAttackRange(entry.tower) or 700.0) + TOWER_MARGIN)
		if dest:DistanceSqr2D(entry.pos) < threat * threat
			and (not ctx.allied_near(entry) or backdoor_active(entry.tower)) then
			mode = "kite"
			dest = entry.pos:Extend2D(u_pos, threat + KITE_MARGIN)
			target = nil
			victim = nil
			attack_target[idx] = nil
		end
	end

	if ctx.use_abilities and mode == "attack" and #creeps > 0 then
		casted = try_cast(ctx.player, u, idx, u_pos, creeps, now)
	end

	if ctx.debug_on then
		debug_units[#debug_units + 1] = {
			pos = u_pos,
			text = string.format("%s | creeps %d", mode or "idle", #creeps),
		}
	end

	if mode == "attack" and not safe_to_target(victim) then
		return
	end

	if mode and not casted and need_reissue(u, idx, mode, dest, target, now) then
		if mode == "attack" then
			order_attack_target(ctx.player, u, victim)
		elseif mode == "kite" or mode == "deaggro" or mode == "flee" then
			NPC.MoveTo(u, dest)
		else
			order_attack_move(ctx.player, u, dest)
		end
		remember(idx, mode, dest, target, now)
	end
end

function tick_farmer(ctx, u, idx, u_pos, reach)
	local now = ctx.now
	local load = ctx.load
	local near_creeps = neutrals_near(u_pos, FIGHT_RADIUS, ctx.my_team)
	local fighting = #near_creeps > 0

	local id = assigned[idx]
	if id and (camps[id].radiant ~= ctx.my_radiant
		or (camp_bans[id] or 0) > now
		or ((camp_empty[id] or 0) > now and not fighting)) then
		release(idx, load)
		id = nil
	end

	local escaping = ctx.avoid_on and (escape_until[idx] or 0) > now

	if ctx.avoid_on and not escaping then
		local near = Entity.GetHeroesInRadius(u, ctx.avoid_radius, TEAM_ENEMY, true, true)
		if #near > 0 then
			if id then
				camp_bans[id] = now + CAMP_BAN_TIME
				release(idx, load)
				id = nil
			end
			escape_until[idx] = now + ESCAPE_GRACE
			escaping = true
		end
	end

	if not id then
		id = pick_camp(ctx, u_pos, false, reach)
			or pick_camp(ctx, u_pos, true, reach)
			or pick_camp(ctx, u_pos, true)
		if id then
			assigned[idx] = id
			load[id] = (load[id] or 0) + 1
		end
	elseif not escaping and not fighting and u_pos:Distance2D(camps[id].pos) > CAMP_ARRIVE then
		local better =
			nearest_live_camp(u_pos, ctx.my_team, ctx.my_radiant, now, ctx.skip_ancients, id, load)
		if better then
			release(idx, load)
			assigned[idx] = better
			load[better] = (load[better] or 0) + 1
			id = better
		end
	end

	if not id then return end

	local camp = camps[id]
	local camp_dist = u_pos:Distance2D(camp.pos)
	local mode, dest, target = "farm", camp.pos, nil
	local victim = nil
	local casted = false

	local neutrals = nil
	local from_camp = false
	if camp_dist < CAMP_SCAN then
		neutrals = camp_neutrals(camp, ctx.my_team)
		if #neutrals > 0 then
			from_camp = true
			camp_empty[id] = nil
		else
			neutrals = near_creeps
		end
	end
	local creeps_alive = neutrals ~= nil and #neutrals > 0

	local aggro = tower_deaggro(ctx, u, idx, u_pos)

	if escaping then
		mode = "flee"
		dest = flee_point(u_pos, ctx.threats) or dest
	elseif aggro then
		attack_target[idx] = nil
		mode = "deaggro"
		dest = aggro.dest
	else
		if from_camp and has_ancient(neutrals) then
			ancient_camp[id] = true
		end
		if creeps_alive and ctx.skip_ancients and camp_is_ancient(id) then
			release(idx, load)
			mode = nil
		elseif creeps_alive then
			waiting[idx] = nil
			victim = sticky_victim(idx, neutrals, u_pos)
			if victim then
				mode = "attack"
				target = attack_target[idx]
				dest = Entity.GetAbsOrigin(victim)
			end
			if ctx.use_abilities then
				casted = try_cast(ctx.player, u, idx, u_pos, neutrals, now)
			end
		elseif camp_dist < CAMP_ARRIVE or waiting[idx] == id then
			attack_target[idx] = nil
			local to_spawn = 60.0 - ctx.second
			local hold_here = false
			if ctx.wait_window > 0 then
				hold_here = to_spawn <= ctx.wait_window
				if not hold_here then
					local other = nearest_other_camp_distance(
						u_pos, ctx.my_radiant, now, load, ctx.skip_ancients, id)
					if other == math.huge then
						hold_here = true
					else
						hold_here = other * PATH_DETOUR / unit_speed(u) + TRAVEL_SLACK >= to_spawn
					end
				end
			end
			if hold_here then
				waiting[idx] = id
				mode = "wait"
				dest = wait_position(camp, ctx.home)
			else
				waiting[idx] = nil
				camp_empty[id] = now + to_spawn + 1.0
				release(idx, load)
				mode = nil
			end
		else
			attack_target[idx] = nil
		end
	end

	if mode == "farm" and camp_dist > CAMP_ENGAGE then
		mode = "travel"
	end

	if ctx.debug_on then
		debug_units[#debug_units + 1] = {
			pos = u_pos,
			text = string.format("%s | camp %d %s | d %.0f | creeps %d",
				mode or "idle", id, camp.type_name or "?", camp_dist,
				neutrals and #neutrals or 0),
		}
	end

	if mode == "attack" and not safe_to_target(victim) then
		return
	end

	if mode and not casted and need_reissue(u, idx, mode, dest, target, now) then
		if mode == "attack" then
			order_attack_target(ctx.player, u, victim)
		elseif mode == "farm" then
			order_attack_move(ctx.player, u, dest)
		else
			NPC.MoveTo(u, dest)
		end
		remember(idx, mode, dest, target, now)
	end
end

local function process()
	local hero = Heroes.GetLocal()
	if not hero then return end
	local player = Players.GetLocal()
	if not player then return end

	local my_id = Player.GetPlayerID(player)
	if my_id < 0 then return end

	ensure_camps()

	local my_team = Entity.GetTeamNum(hero)
	local my_radiant = my_team == Enum.TeamNum.TEAM_RADIANT
	local home = own_fort(my_team)

	local now = GameRules.GetGameTime()
	local clock = game_clock()
	local second = clock % 60

	local avoid_on = ui.avoid:Get()
	local avoid_radius = ui.avoid_radius:Get()
	local skip_ancients = ui.ancients:Get()
	local use_abilities = ui.abilities:Get()
	local retreat_on = ui.retreat:Get()
	local retreat_hp = ui.retreat_hp:Get()
	local retreat_resume = math.min(95.0, retreat_hp + 30.0)
	local wait_window = ui.wait_respawn:Get()
	local pushers_on = ui.pushers:Get()
	local kite_on = ui.kite_tower:Get()
	local debug_on = ui.debug:Get()

	debug_second = second
	if debug_on then
		debug_units = {}
	end

	local scanned = NPCs.GetAll(UNIT_SCAN_FLAGS)

	local units = {}
	for i = 1, #scanned do
		local u = scanned[i]
		if is_eligible(u, my_id, hero) and passes_filter(u) then
			units[#units + 1] = u
		end
	end

	local alive = {}
	for i = 1, #units do
		alive[Entity.GetIndex(units[i])] = true
	end
	append_spirit_bears(units, alive, my_id, my_team, hero)
	purge_gone(alive)

	if #units == 0 then return end

	local open_count = 0
	for id = 1, #camps do
		if camps[id].radiant == my_radiant and (camp_bans[id] or 0) <= now then
			open_count = open_count + 1
		end
	end
	local pusher_flags = {}
	local farmers = 0
	for i = 1, #units do
		local u = units[i]
		pusher_flags[i] = pushers_on and is_pusher(u)
		if not pusher_flags[i] and not retreating[Entity.GetIndex(u)] then
			farmers = farmers + 1
		end
	end

	local limit = 1
	if open_count > 0 then
		limit = math.max(1, math.ceil(farmers / open_count))
	end

	local load = {}
	for _, id in pairs(assigned) do
		load[id] = (load[id] or 0) + 1
	end

	local threats = visible_threats(my_team)

	local enemy_towers = nil
	local function enemy_tower_list()
		if not enemy_towers then
			enemy_towers = build_enemy_towers(enemy_team(my_team))
		end
		return enemy_towers
	end

	local push_targets = nil
	local function push_target_list()
		if not push_targets then
			push_targets = build_push_targets(enemy_tower_list(), build_enemy_barracks(enemy_team(my_team)))
		end
		return push_targets
	end

	local allied_cache = {}
	local function allied_creeps_near(entry)
		local key = Entity.GetIndex(entry.tower)
		local cached = allied_cache[key]
		if cached ~= nil then return cached end
		local found = false
		local list = NPCs.InRadius(entry.pos, ALLIED_RADIUS, my_team, TEAM_FRIEND, true, true)
		for i = 1, #list do
			if NPC.IsLaneCreep(list[i]) then
				found = true
				break
			end
		end
		allied_cache[key] = found
		return found
	end

	local ctx = {
		player = player,
		my_team = my_team,
		my_radiant = my_radiant,
		home = home,
		now = now,
		second = second,
		load = load,
		limit = limit,
		threats = threats,
		avoid_on = avoid_on,
		avoid_radius = avoid_radius,
		skip_ancients = skip_ancients,
		use_abilities = use_abilities,
		wait_window = wait_window,
		kite_on = kite_on,
		debug_on = debug_on,
		tower_list = enemy_tower_list,
		target_list = push_target_list,
		allied_near = allied_creeps_near,
	}

	for i = 1, #units do
		local u = units[i]
		local idx = Entity.GetIndex(u)
		local u_pos = Entity.GetAbsOrigin(u)

		if NPC.IsAttacking(u) then
			last_attack[idx] = now
		end

		local hold = manual_hold[idx]
		local held = hold ~= nil and hold > now
		if hold and not held then
			manual_hold[idx] = nil
			last_orders[idx] = nil
		end

		local pushing = pusher_flags[i]

		local health_pct = 100.0
		local going_home = false
		if not retreat_on or pushing or NPC.IsIllusion(u) then
			retreating[idx] = nil
		elseif not held then
			local max_health = Entity.GetMaxHealth(u) or 0
			if max_health > 0 then
				health_pct = (Entity.GetHealth(u) or 0) / max_health * 100.0
			end
			if retreating[idx] then
				if health_pct >= retreat_resume then retreating[idx] = nil end
			elseif health_pct <= retreat_hp then
				retreating[idx] = true
			end
			going_home = retreating[idx] == true
		end

		if going_home then
			tick_retreat(ctx, u, idx, u_pos, health_pct)
		elseif not held and pushing then
			tick_pusher(ctx, u, idx, u_pos, reach_distance(u, now))
		elseif not held then
			tick_farmer(ctx, u, idx, u_pos, reach_distance(u, now))
		end

	end
end

local DEBUG_TITLE_POS = Vec2(40, 240)
local DEBUG_TITLE_COLOR = Color(255, 220, 120, 255)
local DEBUG_UNIT_COLOR = Color(120, 255, 160, 255)

local script = {}

function script.OnUpdate()
	if not ui.enable:Get() then return end
	if not Engine.IsInGame() then return end

	local now = GameRules.GetGameTime()
	if now < next_run then return end
	next_run = now + UPDATE_INTERVAL

	process()
end

function script.OnNpcSpawned()
	if not ui.enable:Get() then return end
	next_run = 0.0
end

function script.OnDraw()
	if not ui.enable:Get() or not ui.debug:Get() then return end
	if not Engine.IsInGame() then return end

	Render.Text(debug_font, 16, string.format("CreepControl | second %.1f | camps live %d/%d",
		debug_second, camps_matched, camps and #camps or 0),
		DEBUG_TITLE_POS, DEBUG_TITLE_COLOR)

	for i = 1, #debug_units do
		local entry = debug_units[i]
		local screen, visible = Render.WorldToScreen(entry.pos)
		if visible then
			Render.Text(debug_font, 14, entry.text, Vec2(screen:GetX() - 60, screen:GetY() - 40),
				DEBUG_UNIT_COLOR)
		end
	end
end

function script.OnPrepareUnitOrders(data)
	if not ui.enable:Get() then return true end
	if not data or not data.npc then return true end

	local player = Players.GetLocal()
	if not player or data.player ~= player then return true end

	local my_id = Player.GetPlayerID(player)
	if my_id < 0 then return true end

	local hero = Heroes.GetLocal()
	local until_t = GameRules.GetGameTime() + MANUAL_HOLD

	local function mark(unit)
		if not unit or unit == hero then return end
		if not controllable_by_me(unit, my_id) then return end
		manual_hold[Entity.GetIndex(unit)] = until_t
	end

	mark(data.npc)
	if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
		local selected = Player.GetSelectedUnits(player)
		if selected then
			for i = 1, #selected do
				mark(selected[i])
			end
		end
	end
	return true
end

function script.OnGameEnd()
	reset_state()
	fort_pos = nil
	camps = nil
	camps_refined = false
	camps_matched = 0
	fountains = nil
end

return script
