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
local fort_pos = nil
local shop_pos = {}
local debug_units = {}
local debug_second = 0.0
local debug_font = nil
local ORDER_ID = "creep_control"

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

ui.manual_hold = group:Slider("Player order override", 5, 60, 25, function(value)
	return tostring(value) .. "s"
end)
ui.manual_hold:ToolTip("После твоего приказа скрипт не трогает этого юнита. Пока он у тебя выделен — тоже не трогает. Таймер — пауза после снятия выделения")

ui.kite_tower = group:Switch("Dive towers only with allied creeps", true, "\u{f4d8}")
ui.kite_tower:ToolTip("Без своей волны юнит ждёт на границе радиуса вышки, а не лезет под неё")

ui.avoid = group:Switch("Avoid enemy heroes", true, "\u{f70c}")
ui.avoid:ToolTip("Вражеский герой рядом — камп банится на минуту, юнит уходит на другой")

ui.avoid_radius = group:Slider("Avoid radius", 400, 2000, 700, "%d")

ui.retreat = group:Switch("Retreat to fountain on low HP", true, "\u{f004}")
ui.retreat:ToolTip("Юнит уходит на свой фонтан и стоит там, пока HP не станет полным")

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

local function reset_state()
	last_orders = {}
	manual_hold = {}
	last_attack = {}
	assigned = {}
	camp_bans = {}
	camp_empty = {}
	ancient_camp = {}
	escape_until = {}
	next_cast = {}
	retreating = {}
	attack_target = {}
	waiting = {}
	tower_aggro = {}
	push_target = {}
	debug_units = {}
	shop_pos = {}
	next_run = 0.0
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.wait_respawn:Disabled(not on)
	ui.ancients:Disabled(not on)
	ui.abilities:Disabled(not on)
	ui.pushers:Disabled(not on)
	ui.manual_hold:Disabled(not on)
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

ui.toggle_bind:Properties("Creep Control", nil, true)

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

local UPDATE_INTERVAL   = 0.15
local REISSUE_INTERVAL  = 1.20
local REISSUE_JITTER    = 0.60
local POS_EPS           = 120.0
local CAMP_RADIUS       = 420.0
local CAMP_RADIUS_MAX   = 620.0
local CAMP_BOX_MARGIN   = 200.0
local CAMP_MIN_EXTENT   = 250.0
local CAMP_ARRIVE       = 550.0
local CAMP_ENGAGE       = 900.0
local FIGHT_RADIUS      = 600.0
local CAMP_BAN_TIME     = 60.0
local SWITCH_MARGIN     = 600.0
local PASSBY_RADIUS     = 1100.0
local PASSBY_MARGIN     = 200.0
local CAST_INTERVAL     = 0.35
local CAST_RANGE_FALLBACK = 400.0
local ABILITY_MAX_SLOT  = 25
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

local PUSH_PATTERNS = { "forged_spirit", "eidolon", "lycan_wolf", "furion_treant" }

local BACKDOOR_MODS = { modifier_backdoor_protection_active = true }

local BARRACKS_THREAT = 900.0

local BH = Enum.AbilityBehavior
local SKIP_BEHAVIOR =
	BH.DOTA_ABILITY_BEHAVIOR_HIDDEN
	| BH.DOTA_ABILITY_BEHAVIOR_PASSIVE
	| BH.DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE
	| BH.DOTA_ABILITY_BEHAVIOR_CHANNELLED
	| BH.DOTA_ABILITY_BEHAVIOR_ITEM
	| BH.DOTA_ABILITY_BEHAVIOR_TOGGLE
	| BH.DOTA_ABILITY_BEHAVIOR_AURA
	| BH.DOTA_ABILITY_BEHAVIOR_AUTOCAST
	| BH.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING
local UNIT_TARGET_BEHAVIOR = BH.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
local POINT_BEHAVIOR = BH.DOTA_ABILITY_BEHAVIOR_POINT
local NO_TARGET_BEHAVIOR = BH.DOTA_ABILITY_BEHAVIOR_NO_TARGET

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

local TEAM_BOTH = Enum.TeamType.TEAM_BOTH
local TEAM_ENEMY = Enum.TeamType.TEAM_ENEMY
local TEAM_FRIEND = Enum.TeamType.TEAM_FRIEND
local SHOP_HOME = Enum.ShopType.DOTA_SHOP_HOME
local TYPE_SHOP = Enum.UnitTypeFlags.TYPE_SHOP
local STATE = Enum.ModifierState
local CAST_READY = Enum.AbilityCastResult.READY
local TARGET_TYPE = Enum.TargetType
local GAME_IN_PROGRESS = Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS

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

local function ancient_camp_type()
	local types = Enum.ECampType
	if not types then return nil end
	return types.ECampType_ANCIENT
end

local function camp_type_name(value)
	local types = Enum.ECampType
	if not types or value == nil then return nil end
	if value == types.ECampType_ANCIENT then return "ancient" end
	if value == types.ECampType_LARGE then return "large" end
	if value == types.ECampType_MEDIUM then return "medium" end
	if value == types.ECampType_SMALL then return "small" end
	return nil
end

local function camp_from_box(box)
	local min, max = box.min, box.max
	local cx = (min:GetX() + max:GetX()) * 0.5
	local cy = (min:GetY() + max:GetY()) * 0.5
	local cz = (min:GetZ() + max:GetZ()) * 0.5
	local extent = math.max(
		math.abs(max:GetX() - min:GetX()),
		math.abs(max:GetY() - min:GetY())
	) * 0.5
	return Vector(cx, cy, cz),
		math.max(extent, CAMP_MIN_EXTENT),
		math.min(CAMP_RADIUS_MAX, math.max(CAMP_RADIUS, extent + CAMP_BOX_MARGIN))
end

local function enrich_camp_from_api(camp)
	if not Camps or not Camps.InRadius or not Camp then return end
	local near = Camps.InRadius(camp.pos, CAMP_RADIUS)
	if not near or #near == 0 then return end
	local best, best_d = nil, math.huge
	for i = 1, #near do
		local ent = near[i]
		local pos = Entity.GetAbsOrigin(ent)
		local d = camp.pos:Distance2D(pos)
		if d < best_d then
			best, best_d = ent, d
		end
	end
	if not best then return end
	local box = Camp.GetCampBox and Camp.GetCampBox(best)
	if box and box.min and box.max then
		local pos, exit, radius = camp_from_box(box)
		camp.pos = pos
		camp.exit = exit
		camp.radius = radius
		camp.min = box.min
		camp.max = box.max
		camp.pos:SetGroundZ()
	end
	if Camp.GetType then
		local kind = Camp.GetType(best)
		local ancientType = ancient_camp_type()
		camp.ancient = ancientType ~= nil and kind == ancientType
		camp.type_name = camp_type_name(kind)
	end
end

local function build_camps_from_data()
	local list = {}
	for i = 1, #RADIANT_CAMP_DATA do
		local c = RADIANT_CAMP_DATA[i]
		list[#list + 1] = {
			pos = Vector(c[1], c[2], c[3]),
			radiant = true,
			radius = CAMP_RADIUS,
		}
	end
	for i = 1, #DIRE_CAMP_DATA do
		local c = DIRE_CAMP_DATA[i]
		list[#list + 1] = {
			pos = Vector(c[1], c[2], c[3]),
			radiant = false,
			radius = CAMP_RADIUS,
		}
	end
	for i = 1, #list do
		enrich_camp_from_api(list[i])
	end
	return list
end

local function ensure_camps()
	if camps then return end
	camps = build_camps_from_data()
	camps_matched = #camps
	camps_refined = true
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
	if not CustomEntities or not CustomEntities.GetSpiritBear then return end
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

local function shop_position(my_team)
	if shop_pos[my_team] then return shop_pos[my_team] end
	local shops = NPCs.GetAll(TYPE_SHOP)
	if not shops then return nil end
	local home = own_fort(my_team)
	local best, best_dist = nil, math.huge
	for i = 1, #shops do
		local shop = shops[i]
		if Entity.GetTeamNum(shop) == my_team then
			local pos = Entity.GetAbsOrigin(shop)
			local dist = home and pos:Distance2D(home) or 0
			if dist < best_dist then
				best, best_dist = pos, dist
			end
		end
	end
	if best then
		shop_pos[my_team] = best
		return best
	end
	return nil
end

local function retreat_point(ctx)
	return shop_position(ctx.my_team) or fountain_position(ctx.my_radiant)
end

local function has_any_state(u, list)
	for i = 1, #list do
		if NPC.HasState(u, list[i]) then return true end
	end
	return false
end

local ORDER_BLOCK_STATES = {
	STATE.MODIFIER_STATE_STUNNED,
	STATE.MODIFIER_STATE_HEXED,
	STATE.MODIFIER_STATE_FEARED,
	STATE.MODIFIER_STATE_FROZEN,
	STATE.MODIFIER_STATE_NIGHTMARED,
	STATE.MODIFIER_STATE_TAUNTED,
	STATE.MODIFIER_STATE_COMMAND_RESTRICTED,
	STATE.MODIFIER_STATE_IGNORING_MOVE_AND_ATTACK_ORDERS,
	STATE.MODIFIER_STATE_OUT_OF_GAME,
}

local MOVE_BLOCK_STATES = {
	STATE.MODIFIER_STATE_ROOTED,
	STATE.MODIFIER_STATE_IGNORING_MOVE_ORDERS,
}

local ATTACK_BLOCK_STATES = {
	STATE.MODIFIER_STATE_DISARMED,
	STATE.MODIFIER_STATE_CANNOT_TARGET_ENEMIES,
}

local VICTIM_BLOCK_STATES = {
	STATE.MODIFIER_STATE_INVULNERABLE,
	STATE.MODIFIER_STATE_UNTARGETABLE,
	STATE.MODIFIER_STATE_UNTARGETABLE_ENEMY,
	STATE.MODIFIER_STATE_ATTACK_IMMUNE,
	STATE.MODIFIER_STATE_UNSELECTABLE,
}

local function orders_blocked(u)
	return has_any_state(u, ORDER_BLOCK_STATES)
end

local function move_blocked(u)
	return orders_blocked(u) or has_any_state(u, MOVE_BLOCK_STATES)
end

local function attack_blocked(u)
	return orders_blocked(u) or has_any_state(u, ATTACK_BLOCK_STATES)
end

local function attackable_enemy(n)
	if not Entity.IsAlive(n) then return false end
	if NPC.IsWaitingToSpawn(n) then return false end
	if not NPC.IsKillable(n) then return false end
	if has_any_state(n, VICTIM_BLOCK_STATES) then return false end
	return true
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
	local dest = safe_offset(camp, home, distance, "wait")
	if dest == camp.pos then
		dest = dest:Clone()
		camp.wait = dest
	end
	dest:SetGroundZ()
	return dest
end

local function unit_speed(u)
	local speed = NPC.GetMoveSpeed and NPC.GetMoveSpeed(u) or nil
	if not speed or speed <= 0 then
		speed = NPC.GetBaseSpeed and NPC.GetBaseSpeed(u) or nil
	end
	if not speed or speed <= 0 then return FALLBACK_SPEED end
	return speed
end

local function path_length(start, dest)
	local straight = start:Distance2D(dest)
	if not GridNav or not GridNav.BuildPath then return straight end
	if GridNav.IsTraversableFromTo and GridNav.IsTraversableFromTo(start, dest, false) == false then
		return math.huge
	end
	local path = GridNav.BuildPath(start, dest, false)
	if not path or #path < 2 then return straight end
	local len = 0.0
	for i = 2, #path do
		len = len + path[i - 1]:Distance2D(path[i])
	end
	if len <= 0 then return straight end
	return len
end

local function game_clock()
	local t = GameRules.GetDOTATime(false, false)
	if not t or t <= 0 then
		t = GameRules.GetGameTime() - (GameRules.GetGameStartTime() or 0)
	end
	if t < 0 then return 0 end
	return t
end

local function in_match()
	if not Engine.IsInGame() then return false end
	if GameRules.IsPaused() then return false end
	local state = GameRules.GetGameState()
	return state == GAME_IN_PROGRESS
end

local function neutrals_near(pos, radius, my_team)
	local found = {}
	local list = NPCs.InRadius(pos, radius, my_team, TEAM_BOTH, true, false)
	for i = 1, #list do
		local n = list[i]
		if NPC.IsNeutral(n)
			and Entity.GetTeamNum(n) ~= my_team
			and (Entity.IsAlive(n) or NPC.IsWaitingToSpawn(n))
			and not NPC.IsRoshan(n) then
			found[#found + 1] = n
		end
	end
	return found
end

local function ready_units(list)
	local ready = {}
	if not list then return ready end
	for i = 1, #list do
		if attackable_enemy(list[i]) then
			ready[#ready + 1] = list[i]
		end
	end
	return ready
end

local function in_camp_box(pos, camp)
	if camp.min and camp.max then
		local x, y = pos:GetX(), pos:GetY()
		local m = CAMP_BOX_MARGIN
		return x >= camp.min:GetX() - m and x <= camp.max:GetX() + m
			and y >= camp.min:GetY() - m and y <= camp.max:GetY() + m
	end
	return pos:IsInRange2D(camp.pos, camp.radius or CAMP_RADIUS)
end

local function camp_neutrals(camp, my_team)
	local reach = camp.radius or CAMP_RADIUS
	if camp.min and camp.max then
		local dx = (camp.max:GetX() - camp.min:GetX()) * 0.5 + CAMP_BOX_MARGIN
		local dy = (camp.max:GetY() - camp.min:GetY()) * 0.5 + CAMP_BOX_MARGIN
		reach = math.max(reach, math.sqrt(dx * dx + dy * dy))
	end
	local found = neutrals_near(camp.pos, reach, my_team)
	if not camp.min then return found end
	local inside = {}
	for i = 1, #found do
		if in_camp_box(Entity.GetAbsOrigin(found[i]), camp) then
			inside[#inside + 1] = found[i]
		end
	end
	return inside
end

local function scan_live_camps(my_team)
	local live = {}
	for id = 1, #camps do
		if #camp_neutrals(camps[id], my_team) > 0 then
			camp_empty[id] = nil
			live[id] = true
		end
	end
	return live
end

local function nearest_of(list, pos)
	if not list or #list == 0 then return nil end
	local best = pos:ClosestToPoint(list)
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

local function pick_camp(ctx, u_pos, relaxed, skip_id)
	local now = ctx.now
	local live = ctx.live
	local any_live = false
	if live then
		for id = 1, #camps do
			if id ~= skip_id
				and live[id]
				and camps[id].radiant == ctx.my_radiant
				and not (ctx.skip_ancients and camp_is_ancient(id))
				and (camp_bans[id] or 0) <= now then
				any_live = true
				break
			end
		end
	end
	local best, best_score = nil, math.huge
	for id = 1, #camps do
		local camp = camps[id]
		if id ~= skip_id and camp.radiant == ctx.my_radiant then
			local usable
			if ctx.skip_ancients and camp_is_ancient(id) then
				usable = false
			elseif relaxed then
				usable = (camp_bans[id] or 0) <= now
			else
				usable = camp_open(id, now) and (ctx.load[id] or 0) < ctx.limit
			end
			if usable and not relaxed and any_live and not live[id] then
				usable = false
			end
			if usable then
				local score = path_length(u_pos, camp.pos)
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

local function nearest_live_camp(ctx, u_pos, current_id, load)
	local now = ctx.now
	local live = ctx.live
	local current_len = current_id and path_length(u_pos, camps[current_id].pos) or math.huge
	local best, best_len = nil, math.huge
	for id = 1, #camps do
		if id ~= current_id
			and camps[id].radiant == ctx.my_radiant
			and (camp_bans[id] or 0) <= now
			and (load[id] or 0) == 0
			and not (ctx.skip_ancients and camp_is_ancient(id))
			and (not live or live[id]) then
			local len = path_length(u_pos, camps[id].pos)
			if len < best_len then
				best, best_len = id, len
			end
		end
	end
	if best and best_len + PASSBY_MARGIN < current_len then
		return best
	end
	return nil
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

local function building_lane(building)
	local name = NPC.GetUnitName(building)
	if not name then return nil end
	return name:match("_tower%d_(%a+)") or name:match("_rax_(%a+)")
end

local function building_tier(building)
	local name = NPC.GetUnitName(building)
	if not name then return 99 end
	return tonumber(name:match("_tower(%d)") or "") or 99
end

local function enemy_lane_creeps(my_team)
	local found = {}
	local list = NPCs.GetAll(UT.TYPE_LANE_CREEP)
	if not list then return found end
	local e_team = enemy_team(my_team)
	for i = 1, #list do
		local n = list[i]
		if NPC.IsLaneCreep(n)
			and not NPC.IsNeutral(n)
			and Entity.GetTeamNum(n) == e_team
			and (Entity.IsAlive(n) or NPC.IsWaitingToSpawn(n)) then
			found[#found + 1] = n
		end
	end
	return found
end

local function landmark_lane(pos, towers, raxes)
	local best_lane, best_d = nil, math.huge
	local function consider(entry)
		if not entry or not entry.lane or not entry.pos then return end
		local d = pos:DistanceSqr2D(entry.pos)
		if d < best_d then
			best_d, best_lane = d, entry.lane
		end
	end
	for i = 1, #towers do
		consider(towers[i])
	end
	if raxes then
		for i = 1, #raxes do
			consider(raxes[i])
		end
	end
	return best_lane
end

local function creeps_for_lane(creeps, entry, u_pos, towers, raxes)
	if not entry or not entry.lane then
		return creeps
	end
	local found = {}
	for i = 1, #creeps do
		local n = creeps[i]
		local pos = Entity.GetAbsOrigin(n)
		local lane = landmark_lane(pos, towers, raxes)
		if lane == entry.lane
			or pos:IsInRange2D(u_pos, CREEP_SEARCH)
			or pos:IsInRange2D(entry.pos, CREEP_SEARCH) then
			found[#found + 1] = n
		end
	end
	return found
end

local function front_victim(idx, list, enemy_home)
	if not list or #list == 0 then return nil end
	local previous = attack_target[idx]
	if previous then
		for i = 1, #list do
			if Entity.GetIndex(list[i]) == previous then
				return list[i]
			end
		end
	end
	local victim = nil
	if enemy_home then
		local best_d = math.huge
		for i = 1, #list do
			local d = Entity.GetAbsOrigin(list[i]):DistanceSqr2D(enemy_home)
			if d < best_d then
				victim, best_d = list[i], d
			end
		end
	else
		victim = list[1]
	end
	attack_target[idx] = victim and Entity.GetIndex(victim) or nil
	return victim
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
				lane = building_lane(tower),
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
			local lane = building_lane(rax)
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
		local tier = building_tier(entry.tower)
		local lane = entry.lane or "base"
		local current = lanes[lane]
		if not current or tier < current.tier then
			lanes[lane] = {
				tower = entry.tower,
				tier = tier,
				lane = lane,
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

local function choose_push_target(list, u_pos)
	if #list == 0 then return nil end
	local best, best_dist = nil, math.huge
	for i = 1, #list do
		local dist = list[i].pos:DistanceSqr2D(u_pos)
		if dist < best_dist then
			best, best_dist = list[i], dist
		end
	end
	return best
end

local function pinned_push_target(idx, list)
	local pinned = push_target[idx]
	if not pinned then return nil end
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
	if not ui.humanizer:Get() then return true end
	if not Humanizer or not Humanizer.IsSafeTarget or not entity then return true end
	local ok = Humanizer.IsSafeTarget(entity)
	if ok == nil then return true end
	return ok == true
end

local function can_issue()
	if not Humanizer or not Humanizer.OrdersCanBeCastedThisTick then return true end
	return Humanizer.OrdersCanBeCastedThisTick() > 0
end

local function matches_target_type(ability, victim)
	local tt = Ability.GetTargetType(ability) or 0
	if tt == 0 then return false end
	if (tt & TARGET_TYPE.DOTA_UNIT_TARGET_CUSTOM) ~= 0 then return true end
	if NPC.IsHero(victim) or NPC.IsConsideredHero(victim) then
		if (tt & TARGET_TYPE.DOTA_UNIT_TARGET_HERO) ~= 0 then return true end
	end
	if NPC.IsStructure(victim) or NPC.IsTower(victim) or NPC.IsBarracks(victim) or NPC.IsFort(victim) then
		if (tt & TARGET_TYPE.DOTA_UNIT_TARGET_BUILDING) ~= 0 then return true end
	end
	if NPC.IsCreep(victim) or NPC.IsLaneCreep(victim) or NPC.IsNeutral(victim) then
		if (tt & TARGET_TYPE.DOTA_UNIT_TARGET_CREEP) ~= 0 then return true end
		if (tt & TARGET_TYPE.DOTA_UNIT_TARGET_BASIC) ~= 0 then return true end
		if (tt & TARGET_TYPE.DOTA_UNIT_TARGET_OTHER) ~= 0 then return true end
	end
	return false
end

local function can_send(u, mode, victim)
	if orders_blocked(u) then return false end
	if mode == "attack" then
		return not attack_blocked(u) and victim ~= nil and attackable_enemy(victim)
	end
	if mode == "farm" or mode == "push" then
		return not move_blocked(u) and not attack_blocked(u)
	end
	if mode == "hold" then
		return not orders_blocked(u)
	end
	return not move_blocked(u)
end

local function order_move(unit, dest)
	if not can_issue() then return false end
	NPC.MoveTo(unit, dest, false, false, false, false, ORDER_ID)
	return true
end

local function order_attack_move(player, unit, pos)
	if not can_issue() then return false end
	Player.PrepareUnitOrders(
		player, ORDER_ATTACK_MOVE, nil, pos, nil, ISSUER_PASSED_UNIT, unit,
		false, false, false, false, ORDER_ID
	)
	return true
end

local function order_attack_target(player, unit, target)
	if not can_issue() then return false end
	Player.AttackTarget(player, unit, target, false, false, false, ORDER_ID)
	return true
end

local function order_hold(player, unit)
	if not can_issue() then return false end
	Player.HoldPosition(player, unit, false, false, false, ORDER_ID)
	return true
end

local function order_cast(_, __, order, target, pos, ability)
	if not can_issue() then return false end
	if order == ORDER_CAST_TARGET then
		Ability.CastTarget(ability, target, false, false, false, ORDER_ID)
	elseif order == ORDER_CAST_POSITION then
		Ability.CastPosition(ability, pos, false, false, false, ORDER_ID)
	else
		Ability.CastNoTarget(ability, false, false, false, ORDER_ID)
	end
	return true
end

local function ability_denied(name)
	if name == "" then return true end
	for i = 1, #ABILITY_DENY_PATTERNS do
		if name:find(ABILITY_DENY_PATTERNS[i]) then return true end
	end
	return false
end

local function try_cast(player, unit, idx, u_pos, neutrals, now)
	if (next_cast[idx] or 0) > now then return false end
	if orders_blocked(unit)
		or NPC.HasState(unit, STATE.MODIFIER_STATE_SILENCED)
		or NPC.IsChannellingAbility(unit) then
		return false
	end

	local victim = nearest_of(neutrals, u_pos)
	if not victim then return false end
	local victim_pos = Entity.GetAbsOrigin(victim)
	local victim_dist = victim_pos:Distance2D(u_pos)
	local mana = NPC.GetMana(unit)

	for slot = 0, ABILITY_MAX_SLOT do
		local ability = NPC.GetAbilityByIndex(unit, slot)
		if ability
			and Ability.GetLevel(ability) > 0
			and not Ability.IsHidden(ability)
			and not Ability.IsPassive(ability)
			and not Ability.IsInAbilityPhase(ability)
			and Ability.IsActivated(ability)
			and Ability.CanBeExecuted(ability) == CAST_READY
			and Ability.IsCastable(ability, mana)
			and not ability_denied(Ability.GetName(ability) or "") then
			local behavior = Ability.GetBehavior(ability) or 0
			if (behavior & SKIP_BEHAVIOR) == 0 then
				local range = Ability.GetCastRange(ability) or 0
				if range <= 0 then range = CAST_RANGE_FALLBACK end
				local order, target, pos = nil, nil, nil
				if (behavior & UNIT_TARGET_BEHAVIOR) ~= 0 then
					if CASTABLE_TARGET_TEAM[Ability.GetTargetTeam(ability)]
						and matches_target_type(ability, victim)
						and victim_dist <= range
						and safe_to_target(victim) then
						order, target = ORDER_CAST_TARGET, victim
					end
				elseif (behavior & POINT_BEHAVIOR) ~= 0 then
					if victim_dist <= range then
						order, pos = ORDER_CAST_POSITION, victim_pos
					end
				elseif (behavior & NO_TARGET_BEHAVIOR) ~= 0 then
					if victim_dist <= range then
						order = ORDER_CAST_NO_TARGET
					end
				end
				if order and order_cast(player, unit, order, target, pos, ability) then
					next_cast[idx] = now + CAST_INTERVAL
					return true
				end
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
	local dest = retreat_point(ctx)
	local at_shop = NPC.IsInRangeOfShop(u, SHOP_HOME, false)
	local mode = at_shop and "hold" or "home"
	if can_send(u, mode, nil) and need_reissue(u, idx, mode, dest, nil, ctx.now) then
		local sent = at_shop and order_hold(ctx.player, u) or order_move(u, dest)
		if sent then
			remember(idx, mode, dest, nil, ctx.now)
		end
	end
	if ctx.debug_on then
		debug_units[#debug_units + 1] = {
			pos = u_pos,
			text = string.format("%s | hp %.0f%%", mode, health_pct),
		}
	end
end

local function tick_pusher(ctx, u, idx, u_pos)
	local now = ctx.now
	release(idx, ctx.load)
	waiting[idx] = nil

	local mode, dest, target, victim = nil, nil, nil, nil
	local casted = false
	local all_creeps = ctx.enemy_creeps
	local targets = ctx.target_list()
	local entry = pinned_push_target(idx, targets)
	if not entry then
		entry = choose_push_target(targets, u_pos)
		if entry then
			push_target[idx] = Entity.GetIndex(entry.tower)
		end
	end
	local creeps = creeps_for_lane(all_creeps, entry, u_pos, ctx.tower_list(), ctx.rax_list())

	local aggro = tower_deaggro(ctx, u, idx, u_pos)
	local threat_near = false
	if ctx.avoid_on then
		local near = Entity.GetHeroesInRadius(u, ctx.avoid_radius, TEAM_ENEMY, true, true)
		threat_near = #near > 0
	end

	if threat_near then
		attack_target[idx] = nil
		mode = "flee"
		dest = retreat_point(ctx)
	elseif aggro then
		attack_target[idx] = nil
		mode = "deaggro"
		dest = aggro.dest
	elseif #creeps > 0 then
		local ready = ready_units(creeps)
		if #ready > 0 then
			victim = front_victim(idx, ready, ctx.enemy_home)
			if victim then
				mode = "attack"
				target = attack_target[idx]
				dest = Entity.GetAbsOrigin(victim)
			end
		else
			attack_target[idx] = nil
			local spawning = front_victim(idx, creeps, ctx.enemy_home)
			mode = "push"
			dest = spawning and Entity.GetAbsOrigin(spawning) or u_pos
		end
	elseif entry then
		attack_target[idx] = nil
		mode = "push"
		dest = entry.pos
	else
		attack_target[idx] = nil
	end

	if ctx.kite_on and entry and dest and mode and mode ~= "deaggro" and mode ~= "flee" then
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

	if ctx.use_abilities and mode == "attack" then
		local ready = ready_units(creeps)
		if #ready > 0 then
			casted = try_cast(ctx.player, u, idx, u_pos, ready, now)
		end
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

	if mode and not casted and can_send(u, mode, victim) and need_reissue(u, idx, mode, dest, target, now) then
		local sent = false
		if mode == "attack" then
			if victim and NPC.IsLaneCreep(victim) and not NPC.IsNeutral(victim) then
				sent = order_attack_target(ctx.player, u, victim)
			end
		elseif mode == "push" and entry and dest == entry.pos then
			local range = (NPC.GetAttackRange(u) or 0) + (NPC.GetAttackRangeBonus(u) or 0)
			if range < 100 then range = 100 end
			if NPC.IsEntityInRange(u, entry.tower, range) then
				sent = order_attack_target(ctx.player, u, entry.tower)
			else
				sent = order_move(u, dest)
			end
		elseif mode == "kite" or mode == "deaggro" or mode == "flee" then
			sent = order_move(u, dest)
		else
			sent = order_move(u, dest)
		end
		if sent then
			remember(idx, mode, dest, target, now)
		end
	end
end

local function tick_farmer(ctx, u, idx, u_pos)
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
		id = pick_camp(ctx, u_pos, false) or pick_camp(ctx, u_pos, true)
		if id then
			assigned[idx] = id
			load[id] = (load[id] or 0) + 1
		end
	elseif not escaping and not fighting and u_pos:Distance2D(camps[id].pos) > CAMP_ARRIVE then
		local better = nearest_live_camp(ctx, u_pos, id, load)
		if better then
			release(idx, load)
			assigned[idx] = better
			load[better] = (load[better] or 0) + 1
			id = better
		end
	end

	if not id then
		if escaping then
			local dest = retreat_point(ctx)
			if can_send(u, "flee", nil) and need_reissue(u, idx, "flee", dest, nil, now) then
				if order_move(u, dest) then
					remember(idx, "flee", dest, nil, now)
				end
			end
		end
		return
	end

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
		dest = id and camps[id].pos or retreat_point(ctx)
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
			local ready = ready_units(neutrals)
			if #ready > 0 then
				victim = sticky_victim(idx, ready, u_pos)
				if victim then
					mode = "attack"
					target = attack_target[idx]
					dest = Entity.GetAbsOrigin(victim)
				end
				if ctx.use_abilities then
					casted = try_cast(ctx.player, u, idx, u_pos, ready, now)
				end
			else
				attack_target[idx] = nil
				mode = "farm"
				dest = camp.pos
			end
		elseif camp_dist < CAMP_ARRIVE or waiting[idx] == id then
			attack_target[idx] = nil
			waiting[idx] = nil
			if ctx.live then ctx.live[id] = nil end
			release(idx, load)
			local next_id = pick_camp(ctx, u_pos, false, id) or pick_camp(ctx, u_pos, true, id)
			if next_id then
				assigned[idx] = next_id
				load[next_id] = (load[next_id] or 0) + 1
				id = next_id
				camp = camps[id]
				camp_dist = u_pos:Distance2D(camp.pos)
				mode = "travel"
				dest = camp.pos
			else
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

	if mode and not casted and can_send(u, mode, victim) and need_reissue(u, idx, mode, dest, target, now) then
		local sent = false
		if mode == "attack" then
			sent = order_attack_target(ctx.player, u, victim)
		elseif mode == "farm" then
			sent = order_attack_move(ctx.player, u, dest)
		else
			sent = order_move(u, dest)
		end
		if sent then
			remember(idx, mode, dest, target, now)
		end
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
	local live_camps = scan_live_camps(my_team)
	local clock = game_clock()
	local second = clock % 60

	local avoid_on = ui.avoid:Get()
	local avoid_radius = ui.avoid_radius:Get()
	local skip_ancients = ui.ancients:Get()
	local use_abilities = ui.abilities:Get()
	local retreat_on = ui.retreat:Get()
	local retreat_hp = ui.retreat_hp:Get()
	local wait_window = ui.wait_respawn:Get()
	local pushers_on = ui.pushers:Get()
	local kite_on = ui.kite_tower:Get()
	local debug_on = ui.debug:Get()

	debug_second = second
	if debug_on then
		debug_units = {}
	end

	local scanned = NPCs.GetAll(UNIT_SCAN_FLAGS)
	if not scanned or #scanned == 0 then
		scanned = NPCs.GetAll()
	end

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

	if #units == 0 then
		assigned = {}
		waiting = {}
		return
	end

	for idx in pairs(assigned) do
		if not alive[idx] then
			assigned[idx] = nil
			waiting[idx] = nil
			tower_aggro[idx] = nil
			push_target[idx] = nil
		end
	end

	local open_count = 0
	for id = 1, #camps do
		if camps[id].radiant == my_radiant and (camp_bans[id] or 0) <= now then
			open_count = open_count + 1
		end
	end
	local limit = 1
	if open_count > 0 then
		limit = math.max(1, math.ceil(#units / open_count))
	end

	local load = {}
	for _, id in pairs(assigned) do
		load[id] = (load[id] or 0) + 1
	end

	local selected_now = {}
	local selected_units = Player.GetSelectedUnits(player)
	if selected_units then
		for i = 1, #selected_units do
			local sidx = Entity.GetIndex(selected_units[i])
			if sidx then selected_now[sidx] = true end
		end
	end

	local threats = visible_threats(my_team)

	local e_team = enemy_team(my_team)
	local enemy_home = nil
	local forts = NPCs.GetAll(UT.TYPE_FORT)
	if forts then
		for i = 1, #forts do
			if Entity.GetTeamNum(forts[i]) == e_team then
				enemy_home = Entity.GetAbsOrigin(forts[i])
				break
			end
		end
	end
	if not enemy_home then
		enemy_home = fountain_position(not my_radiant)
	end
	local enemy_creeps = enemy_lane_creeps(my_team)

	local enemy_towers = nil
	local function enemy_tower_list()
		if not enemy_towers then
			enemy_towers = build_enemy_towers(e_team)
		end
		return enemy_towers
	end

	local enemy_raxes = nil
	local function enemy_rax_list()
		if not enemy_raxes then
			enemy_raxes = build_enemy_barracks(e_team)
		end
		return enemy_raxes
	end

	local push_targets = nil
	local function push_target_list()
		if not push_targets then
			push_targets = build_push_targets(enemy_tower_list(), enemy_rax_list())
		end
		return push_targets
	end

	local allied_cache = {}
	local function allied_creeps_near(entry)
		local key = Entity.GetIndex(entry.tower)
		local cached = allied_cache[key]
		if cached ~= nil then return cached end
		local found = false
		local list = NPCs.InRadius(entry.pos, ALLIED_RADIUS, my_team, TEAM_FRIEND, true, false)
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
		rax_list = enemy_rax_list,
		target_list = push_target_list,
		allied_near = allied_creeps_near,
		enemy_home = enemy_home,
		enemy_creeps = enemy_creeps,
		live = live_camps,
	}

	for i = 1, #units do
		local u = units[i]
		local idx = Entity.GetIndex(u)
		local u_pos = Entity.GetAbsOrigin(u)

		if NPC.IsAttacking(u) then
			last_attack[idx] = now
		end

		local hold = manual_hold[idx]
		local held = false
		if hold then
			if selected_now[idx] then
				held = true
			elseif hold > now then
				held = true
			else
				manual_hold[idx] = nil
				last_orders[idx] = nil
			end
		end

		local pushing = pushers_on and is_pusher(u)

		local health_pct = 100.0
		local going_home = false
		if not retreat_on then
			retreating[idx] = nil
		elseif not held then
			local health = Entity.GetHealth(u) or 0
			local max_health = Entity.GetMaxHealth(u) or 0
			if max_health > 0 then
				health_pct = health / max_health * 100.0
			end
			if retreating[idx] then
				if max_health > 0 and health >= max_health then
					retreating[idx] = nil
				end
			elseif health_pct <= retreat_hp then
				retreating[idx] = true
			end
			going_home = retreating[idx] == true
		end

		if held then
			if debug_on then
				debug_units[#debug_units + 1] = { pos = u_pos, text = "manual" }
			end
		elseif not orders_blocked(u) then
			if going_home then
				tick_retreat(ctx, u, idx, u_pos, health_pct)
			elseif pushing then
				tick_pusher(ctx, u, idx, u_pos)
			else
				tick_farmer(ctx, u, idx, u_pos)
			end
		end

	end
end

local script = {}

function script.OnUpdate()
	if ui.toggle_bind:Get() ~= Enum.ButtonCode.KEY_NONE
		and ui.toggle_bind:IsToggled() ~= ui.enable:Get() then
		ui.enable:Set(ui.toggle_bind:IsToggled())
	end

	if not ui.enable:Get() then return end
	if not in_match() then return end

	local now = GameRules.GetGameTime()
	if now < next_run then return end
	next_run = now + UPDATE_INTERVAL

	process()
end

function script.OnNpcSpawned(npc)
	if not ui.enable:Get() then return end
	next_run = 0.0
	if not npc or not camps then return end
	if not NPC.IsNeutral(npc) then return end
	local pos = Entity.GetAbsOrigin(npc)
	for id = 1, #camps do
		local camp = camps[id]
		if pos:Distance2D(camp.pos) <= (camp.radius or CAMP_RADIUS) then
			camp_empty[id] = nil
		end
	end
end

function script.OnDraw()
	if not ui.enable:Get() or not ui.debug:Get() then return end
	if not Engine.IsInGame() then return end

	if not debug_font then
		debug_font = Render.LoadFont("Verdana", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
	end

	Render.Text(debug_font, 16, string.format("CreepControl | second %.1f | route %d",
		debug_second, camps and #camps or 0),
		Vec2(40, 240), Color(255, 220, 120, 255))

	for i = 1, #debug_units do
		local entry = debug_units[i]
		local screen, visible = Render.WorldToScreen(entry.pos)
		if visible then
			Render.Text(debug_font, 14, entry.text, Vec2(screen:GetX() - 60, screen:GetY() - 40),
				Color(120, 255, 160, 255))
		end
	end
end

function script.OnPrepareUnitOrders(data)
	if not ui.enable:Get() then return true end
	if not data or not data.npc then return true end
	if data.identifier == ORDER_ID then return true end

	local player = Players.GetLocal()
	if not player or data.player ~= player then return true end

	local my_id = Player.GetPlayerID(player)
	if my_id < 0 then return true end

	local hero = Heroes.GetLocal()
	local until_t = GameRules.GetGameTime() + ui.manual_hold:Get()

	local function mark(unit)
		if not unit or unit == hero then return end
		if not controllable_by_me(unit, my_id) then return end
		local idx = Entity.GetIndex(unit)
		manual_hold[idx] = until_t
		last_orders[idx] = nil
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
	shop_pos = {}
	camps = nil
	camps_refined = false
	camps_matched = 0
	fountains = nil
end

return script
