local qLocalization = (function()
	local lib = {}

	local a = function(...)
		return ...
	end

	local state = {
		lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
		instances = {},
	}

	local setters = {
		ToolTip = "tooltip",
	}

	local helpers
	do
		helpers = {
			resolve = a(function(root, path)
				for key in path:gmatch("[^.]+") do
					if type(root) ~= "table" then
						return
					end

					root = root[key]
				end

				return root
			end),

			is_object = a(function(value)
				return type(value) == "table" or type(value) == "userdata"
			end),

			has_method = a(function(object, name)
				return helpers.is_object(object) and type(object[name]) == "function"
			end),

			is_menu_object = a(function(value)
				return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
			end),

			is_list = a(function(value)
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
				end

				return true
			end),

			is_indexed_list = a(function(object)
				return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
			end),
		}
	end

	function lib.new(translations)
		local languages = {}

		for i, name in ipairs(state.lang and state.lang:List() or {}) do
			local code = name:match("%a+")

			if code and translations[code] then
				languages[i - 1] = code
			end
		end

		local localization = {
			translations = translations,
			languages = languages,
			objects = {},
		}

		local methods
		do
			methods = {
				get_language = a(function(language_index)
					if language_index == nil and state.lang then
						language_index = state.lang:Get()
					end

					return localization.languages[language_index] or "en"
				end),

				localize = a(function(path, language_index)
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end),

				has = a(function(path)
					if type(path) ~= "string" then
						return false
					end

					return helpers.resolve(localization.translations.en, path) ~= nil
						or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
				end),

				localize_items = a(function(items, language_index)
					local result, localized = {}, false

					for i = 1, #items do
						local value = items[i]

						if methods.has(value) then
							result[i] = methods.localize(value, language_index)
							localized = true
						else
							result[i] = value
						end
					end

					return result, localized
				end),

				apply = a(function(object, kind, path, language_index)
					if kind == "label" then
						object:ForceLocalization(methods.localize(path, language_index))
					elseif kind == "tooltip" then
						object:ToolTip(methods.localize(path, language_index))
					elseif kind == "items" then
						local value = object:Get()

						object:Update((methods.localize_items(path, language_index)))
						object:Set(value)
					end
				end),

				track = a(function(object, kind, path, apply_now)
					local record = localization.objects[object]

					if record == nil then
						record = {}
						localization.objects[object] = record
					end

					record[kind] = path

					if apply_now then
						methods.apply(object, kind, path)
					end
				end),

				register = a(function(object, path)
					if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
						return
					end

					methods.track(object, "label", path, true)
				end),

				update = a(function(language_index)
					for object, record in pairs(localization.objects) do
						for kind, path in pairs(record) do
							methods.apply(object, kind, path, language_index)
						end
					end
				end),

				wrap = a(function(target, bind_self)
					if not helpers.is_object(target) then
						return target
					end

					local proxy

					proxy = setmetatable({}, {
						__index = function(_, key)
							local member = target[key]

							if type(member) ~= "function" then
								return member
							end

							return function(...)
								local args = table.pack(...)

								if bind_self and args[1] == proxy then
									table.remove(args, 1)
									args.n = args.n - 1
								end

								if key == "Switch" and args.n < 2 then
									args[2] = false
									args.n = 2
								end

								local name_path, item_paths

								if setters[key] then
									if methods.has(args[1]) then
										methods.track(target, setters[key], args[1], false)

										args[1] = methods.localize(args[1])
									end
								else
									local name_index = bind_self and 1 or args.n

									if methods.has(args[name_index]) then
										name_path = args[name_index]
									end

									local items_index

									if key == "Combo" then
										items_index = 2
									elseif key == "Update" and helpers.is_indexed_list(target) then
										items_index = 1
									end

									if items_index ~= nil and helpers.is_list(args[items_index]) then
										local items, localized = methods.localize_items(args[items_index])

										if localized then
											item_paths = args[items_index]
											args[items_index] = items
										end
									end
								end

								local results

								if bind_self then
									results = table.pack(member(target, table.unpack(args, 1, args.n)))
								else
									results = table.pack(member(table.unpack(args, 1, args.n)))
								end

								for i = 1, results.n do
									local result = results[i]

									if helpers.is_menu_object(result) then
										if name_path then
											methods.register(result, name_path)
										end

										if item_paths then
											methods.track(result, "items", item_paths, false)
											item_paths = nil
										end

										results[i] = methods.wrap(result, true)
									end
								end

								if item_paths then
									methods.track(target, "items", item_paths, false)
								end

								return table.unpack(results, 1, results.n)
							end
						end,

						__newindex = function(_, key, value)
							target[key] = value
						end,
					})

					return proxy
				end),
			}
		end

		state.instances[methods] = true

		return {
			GetLanguage = methods.get_language,

			Get = methods.localize,
			Localize = methods.localize,

			Update = methods.update,
			Register = methods.register,

			Wrap = methods.wrap,

			WrapLibrary = function(library)
				return methods.wrap(library, false)
			end,
		}
	end

	if state.lang then
		state.lang:SetCallback(function(this)
			local language_index = this:Get()

			for methods in pairs(state.instances) do
				methods.update(language_index)
			end
		end, true)
	else
		Log.Write("[qLocalization] Language widget not found, using English fallback")
	end

	return lib
end)()

if package and package.loaded then

    for _, m in ipairs({ "lib.map", "lib.farm", "lib.lane",
                         "lib.escape", "lib.hero_value", "lib.geometry", "lib.map_data", "lib.channel_gate",
                         "lib.defense", "lib.item_saves", "lib.target",
                         "lib.timing", "lib.hero_data", "lib.ability_data",
                         "lib.threat_data", "lib.draw" }) do

        package.loaded[m] = nil
    end
end
local Map       = require("lib.map")
local Farm      = require("lib.farm")
local Timing    = require("lib.timing")
local HeroValue = require("lib.hero_value")
local MapData   = require("lib.map_data")
local Lane      = require("lib.lane")

local Escape    = require("lib.escape")
local Geometry  = require("lib.geometry")
local HeroData    = require("lib.hero_data")
local AbilityData = require("lib.ability_data")
local ThreatData  = require("lib.threat_data")
local ChannelGate = require("lib.channel_gate")
local Defense   = require("lib.defense")
local ItemSaves = require("lib.item_saves")
local Target    = require("lib.target")
local Draw      = require("lib.draw")

local UO = Enum.UnitOrder
local HERO_KEY = "tinker"

local State = {}
State.updateSerial = 0

do
    local function cached_list(key, fetch)
        local cache = State.worldCache
        if not cache then cache = {}; State.worldCache = cache end
        local entry = cache[key]
        if entry and entry.serial == State.updateSerial then return entry.value end
        local value = fetch() or {}
        if not entry then entry = {}; cache[key] = entry end
        entry.serial, entry.value = State.updateSerial, value
        return value
    end

    State.world = {
        camps = function() return cached_list("camps", Map.Camps) end,
        neutrals = function() return cached_list("neutrals", Map.AllNeutrals) end,
        heroes = function() return cached_list("heroes", Heroes.GetAll) end,
        structures = function()
            return cached_list("structures", function()
                return NPCs.GetAll(Enum.UnitTypeFlags.TYPE_STRUCTURE)
            end)
        end,
        towers = function()
            return cached_list("towers", function()
                local out = {}
                for _, entity in ipairs(State.world.structures()) do
                    local name = (NPC.GetUnitName and NPC.GetUnitName(entity)) or ""
                    if name:find("_tower", 1, true) then out[#out + 1] = entity end
                end
                return out
            end)
        end,
        lane_creeps = function()
            return cached_list("lane_creeps", function()
                return NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP)
            end)
        end,
    }
    State.world.tower_alive_at = function(pos, team, radius)
        local r2 = radius * radius
        for _, tower in ipairs(State.world.towers()) do
            if Entity.GetTeamNum(tower) == team and Entity.IsAlive(tower) then
                local p = Entity.GetAbsOrigin(tower)
                if p then
                    local dx, dy = p.x - pos.x, p.y - pos.y
                    if dx * dx + dy * dy <= r2 then return true end
                end
            end
        end
        return false
    end
end

local function logline() end
local function tlog() end

local VERSION = "1.0.3"

local K = {
    MARCH_LEN       = 1800, MARCH_HALFWIDTH = 900, MARCH_CAST_RANGE = 300,
    ARRIVE_DIST     = 120,
    MARCHES         = { [0] = 2, [1] = 2, [2] = 2, [3] = 4 },
    SAFE_LANE_WAVE_R = 1400,
    SAFE_LANE_HERO_R = 700,
    SIDE_WAVE_DANGER_R = 1200,
    SIDE_WAVE_DANGER_S = 20,
    SIDE_LANE_THREAT_R = 1300,
    SIDE_LANE_NO_BLINK_R = 800,
    SAFE_LANE_MARCH_CAST_RANGE = 900,
    SAFE_LANE_MARCH_CENTER_OFFSET = 500,
    SAFE_LANE_MAX_W = 2,
    SAFE_LANE_LANE_COOLDOWN_S = 20,
    MARCH_KEEN_MANA_MARGIN = 10,
    MAX_CLEAR_MARCHES = 6,
    PER_MARCH_DMG   = { 13, 22, 31, 40 },
    ROBOTS_EFFECTIVE = 24,
    CAMP_MR         = { [0] = 0.0, [1] = 0.0, [2] = 0.0, [3] = 0.30 },
    REARM_CHANNEL   = { 2.69, 1.93, 1.20 },
    CHANNEL_PAD     = 0.20,
    KEEN_CHANNEL    = 2.93,
    KEEN_LAND_STRUCTURE = 700,
    KEEN_LAND_OUTPOST   = 250,
    KEEN_CREEP_MIN_HP   = 300,
    KEEN_CREEP_DRIFT_S  = 3.5,
    KEEN_WAIT_MARGIN    = 4.0,
    KEEN_CREEP_CLEAR    = 250,
    KEEN_TREE_CLEAR     = 140,
    KEEN_LAND_SAFE_RISK = 0.35,
    KEEN_DEPTH_MARGIN   = 150,
    FOUNTAIN_WALK_IN    = 1200,
    RETURN_RESUME_FRAC  = 0.70,
    ESCAPE_MANA     = 150,
    REFILL_FRAC     = 0.70,
    PANIC_HP        = 0.40, PANIC_ARM = 0.25,
    CONTEST_RADIUS  = 700,
    CONTEST_LANE_R  = 1200,
    HERO_FARM_R     = 600,
    FARMER_DWELL_S  = 4.0,
    FARMER_DWELL_MIN_S = 6.0,
    CONTEST_JUNGLE_R = 2600,
    ARRIVAL_GRACE_S    = 8,
    ARRIVAL_HOLD_T     = 10,
    ARRIVAL_HOLD_MAX_S = 15,
    FARMER_CORE_MARKS  = 2,
    CONTEST_CORE_BASE = 0.55,
    RISK_RADIUS     = 1400, RISK_HARD = 0.34,
    GANK_RADIUS     = 1000,
    GANK_FOG_REACH  = 600,
    TOWER_ALIVE_R     = 300,
    TOWER_DYING_MARGIN_S = 3,
    HELD_CLOSING_MIN     = 80,
    TOWER_RISK_RADIUS = 1050, TOWER_RISK_WEIGHT = 0.7, TOWER_ATTACK_RANGE = 900,
    TOWER_SAFE_MARGIN = 100,
    FOG_MS = 550, FOG_SPREAD = 900, FOG_AGE_CAP = 5,
    FARM_SAFE_RISK  = 0.42,
    STAND_RING      = 250, STAND_STEP = 30,
    PAIR_RADIUS     = 1800,
    CREEP_DISC      = 200,
    CLIP_EXTRA_MARCHES = 2,
    PAIR_MARCH_BLINK_SHIFT = 425,
    CAMP_CACHE_S    = 60,
    MARCH_PAIR_OFFSET = 0,
    CAMP_SPAWN_GRACE_S = 3.0,

    FORCE_PAIRS = {
        { { -769, -7685 }, { -2480, -8400 } },
        { { -4797, -104 }, { -4032, 895 } },
        { { 4099, 63 }, { 3392, -1216 } },
    },
    DISABLED_CAMPS = {
        { 193, -5154 },
        { 1832, -4033 },
    },
    PAIR_STANDS = {
        { camps = { { -769, -7685 }, { -2480, -8400 } }, stand = { -1820.84375, -7768.375, 134 } },
    },
    PREFERRED_PAIR_BONUS = 1000,
    MOVE_TIMEOUT    = 25.0,
    WAVE_HOLD_EPS   = 150,
    WAVE_HOLD_NEXT  = 12.0,
    WAIT_PROTECT_AHEAD = 350,
    WAIT_BACKOFF       = 600,
    WAIT_STEP_BACK     = 200,
    STEP_OUT_LEAD      = 1.5,
    STEP_OUT_PRECAST_S = 6.0,
    DEPTH_POINT_BUDGET = 600,
    DEPTH_KEEN_SHAVE   = 1500,
    WAVE_CAMP_ALT_S    = 30,
    SIDE_STAMP_MAX_S   = 60,
    GONE_BAL_MIN       = 2,
    WALK_DEPTH_MAX     = 1100,
    T1DOWN_LEASH       = 3000,
    ENGAGE_EMPTY_GRACE = 1.2,
    MIN_CASTS_BEFORE_EMPTY = 2,
    KEEN_TRAVEL_MIN = 1600,
    KEEN_GAIN_MIN   = 800,
    RAID_RESID_MAX  = 1200,
    RAID_HOP_CREEP_MAX = 3000,
    DECIDE_GAP      = 0.4, ORDER_GAP = 0.05,
    MOVE_DEDUP_DIST = 75,
    MOVE_DEDUP_S    = 0.5,
    TEST_OVERLAY_SEC = 120,
    AUTO_WAVESCAN_S = 2.0,
    ROUTE_HORIZON_S = 30,
    MAX_CAMP_TRAVEL_S = 20,
    ROUTE_MAX_STEPS = 4,
    ROUTE_STEP_DECAY = 0.6,
    ROUTE_POOL_CAP = 16,
    ROUTE_RISK_WEIGHT = 70,
    HOME_LANE       = "mid",
    WAVE_STANDBACK  = 900,
    ANTICIP_RANGED_REACH = 810,
    STAND_KITE_EPS       = 100,
    WAVE_LEAD       = 150,
    W_LEAD_S        = 4.75,
    W_LEAD_CAP      = 1900,
    W_CLOSING_MIN   = 80,
    W_LEAD_FOG_S    = 3.5,
    MISS_FREE       = 1,
    FOG_FRESH_S     = 1.5,
    FOG_REACH_CAP   = 450,
    W_PRE_MIN_N     = 3,
    W_CAST_REACH    = 700,
    W_WAIT_RELEASE_S = 4.0,
    W_PRE_STAND_R   = 600,
    FIGHT_CONTACT_R     = 300,
    FIGHT_HOLD_S        = 3.0,
    PREARM_CD_FLOOR     = 4.0,
    W_PRE_LEAD_R    = 1100,
    WAVE_MAX_W      = 2,
    LANE_MEET_TTL      = 90,
    LANE_ANCHOR_BACK   = 600,
    INTERCEPT_FWD_R    = 600,
    WAVE_TRACK_RADIUS  = 1600,
    WAVE_ENGAGE_RANGE  = 950,
    DEEP_THIN_EFFHP    = 1150,
    NC_GRACE_S         = 3.0,
    NC_CLOSE_EPS       = 100,
    NC_HOLD_NEAR       = 1600,
    WAVE_VIS_DEBOUNCE_S = 0.7,
    PROT_CLEAR_S        = 2.0,
    W_X_ARM_A          = 45,
    W_X_ARM_B          = -45,
    TETHER_MAX_HOLD_S  = 10.0,
    LIVE_STALL_S       = 15.0,
    TETHER_WALK_MAX_S  = 6.0,
    STUCK_TELEPORT_S   = 4.0,
    STUCK_FROZEN_DIST  = 60,
    STUCK_FAR_DIST     = 400,
    BLINK_RANGE        = 1200,
    BLINK_CLAMP        = 960,
    BLINK_TRAVEL_MIN   = 400,
    BLINK_DEBOUNCE     = 0.5,

    HP_FLOOR_FRAC       = 0.35,
    HP_RISK_DMG         = 600,
    KEEN_MANA_FB        = 75,
    MARCH_MANA_FB       = 120,
    REARM_MANA_FB       = 225,
    REARM_CANCEL_BACKOFF_S = 6,
    CAMP_UNSAFE_SUPPRESS_S = 20,
    CHANNEL_GATE_MARGIN = 500,
    CHANNEL_GATE_HORIZON = 3.0,
    CHANNEL_DEFER_BAIL_S = 4.0,
    TOWER_THREAT_R       = 1100,
    TOWER_THREAT_MINC    = 3,
    CRASH_STICKY_S       = 10.0,
    REARM_STEPBACK_S     = 4.0,
    DISPATCH_HP_MIN     = 0.50,
    LASER_MANA_FB       = 95,
    LASER_DMG           = { 75, 150, 225, 300 },
    MANA_REGEN_FALLBACK = 4.0,
    HP_REGEN_FALLBACK   = 6.0,
    FOUNTAIN_MANA_PCT_S = 0.06, FOUNTAIN_HP_PCT_S = 0.05,

    RISK_HALF_WEIGHT    = 0.75,
    RISK_CONTESTED_BUMP = 0.05,
    RISK_CONTESTED_RADIUS = 700,
    RISK_CONTESTED_CAMPS = { { -4797, -104 }, { 4099, 63 } },

    WAVE_PERIOD         = 30,
    WAVE_PHASE          = 21,
    WAVE_WAIT_GRACE     = 8,
    WAVE_WAIT_GRACE_VIS = 4,

    NO_PROGRESS_S       = 3.0,
    PROGRESS_EPS        = 60,
    SHOVE_STUCK_S       = 6,
    ENGAGE_COVER_DIST   = 450,
    MULTI_W_OFFSET      = 50,
    MARCH_REACH         = 1150,

    BOX_ALONG           = 50,
    BOX_PERP            = 300,

    SHOVE_SAFE_RISK     = 0.35,

    SHOVE_MANA_RESERVE  = 0,
    SHOVE_FAR_TRAVEL    = 12.0,
    SHOVE_MIN_EFFHP     = 400,
    LANE_TRADE_HP       = 0.40,
    SHOVE_THIN_EFFHP    = 400,
    SHOVE_THIN_CREEPS   = 1,
    SHOVE_MIN_CREEPS    = 3,
    WALK_LEG_MIN        = 800,
    THIN_CREEPS_HOLD_S  = 2.0,
    MIN_CAMP_SLACK      = 10.0,
    MIN_FOUNTAIN_SLACK  = 6.0,

    MARCH_DMG_PER_CAST  = 450,
    MARCH_CAST_DUR      = 0.53,
    ROBOT_KILL          = 1.5,
    ROBOT_TAIL          = 1.5,
    SCHED_LEAD          = 1.5,
    BOTTLE_MANA         = 200,
    SOUL_RING_MANA      = 170,
    SR_HP_FRAC_MIN      = 0.55,
    ARCANE_MANA         = 150,
    BOTTLE_HP_FRAC      = 0.55,
    BOTTLE_MANA_PER_CHARGE = 60,
    PATH_RISK_MAX       = 0.42,

    COMMIT_APPROACH_SPEED = 50,
    COMMIT_STAND_S        = 4.0,
    COMMIT_WIDEN_MAX      = 2000,
}

State.fsm          = "DECIDE"
State.laneWaveT    = {}
State.laneMeet     = {}
State.sideLaneDanger = {}
State.enemyBlinkCache = {}
State.shoveLeaveBy = nil
State.schedSlack   = nil
State.marchCasts   = 0
State.nextDecide   = 0
State.nextOrder    = 0
State.panicUntil   = 0
State.channelUntil = 0
State.keenedSpot   = false
State.cyclePark    = nil
State.shoveSuppress = { mid = 0, top = 0, bot = 0 }
State.releaseSuppress = { mid = 0, top = 0, bot = 0 }
State.dumped       = false
State.cleared      = {}
State.campSeen     = {}
State.loneSince    = {}
State.campDwell    = {}
State.safeLane     = nil
State.safeLaneLaneUntil = {}
State.safeLanePriorityDone = false
State.allyFarmers  = {}

local function now()
    if GameRules.GetDOTATime then return GameRules.GetDOTATime(false, false) end
    return (GameRules.GetGameTime and GameRules.GetGameTime()) or 0
end

local TIER_EST = {
    [0] = { gold = 55,  hp = 1400 },
    [1] = { gold = 85,  hp = 1900 },
    [2] = { gold = 105, hp = 2400 },
    [3] = { gold = 160, hp = 3600 },
}
local function next_respawn() return (math.floor(now() / 60) + 1) * 60 end
local function camp_spawn_window()
    local t = now()
    local minute = math.floor(t / 60) * 60
    local grace_end = minute + K.CAMP_SPAWN_GRACE_S
    return t < grace_end, (t < grace_end) and grace_end or (minute + 60)
end
local function is_disabled_camp(center)
    if not center then return false end
    local key = Map.CampKey(center)
    for _, p in ipairs(K.DISABLED_CAMPS or {}) do
        if Map.CampKey({ x = p[1], y = p[2] }) == key then return true end
    end
    return false
end

local function is_cleared(key)
    local t = State.cleared and State.cleared[key]
    return t ~= nil and now() < t
end
local function mark_cleared(key, until_t)
    if key then State.cleared = State.cleared or {}; State.cleared[key] = until_t or next_respawn() end
end

local function mark_spot_cleared(s, until_t)
    if not s then return end
    mark_cleared(s.key, until_t)
    local ss = s.standSpot
    if ss and ss.paired and ss.partner then mark_cleared(Map.CampKey(ss.partner), until_t) end
end

local function marches_for(t)
    return K.MARCHES[t] or 2
end

local function forced_pair(a, b)
    if not (a and b) then return false end
    local ka, kb = Map.CampKey(a), Map.CampKey(b)
    for _, f in ipairs(K.FORCE_PAIRS or {}) do
        local k1 = Map.CampKey({ x = f[1][1], y = f[1][2] })
        local k2 = Map.CampKey({ x = f[2][1], y = f[2][2] })
        if (ka == k1 and kb == k2) or (ka == k2 and kb == k1) then return true end
    end
    return false
end
State.outpostAncientPair = function(a, b)
    local pa, pb = a and (a.center or a), b and (b.center or b)
    return forced_pair(pa, pb) and a and b and (a.type == 3 or b.type == 3) or false
end
State.outpostAncientPairTeam = function(a, b)
    if not State.outpostAncientPair(a, b) then return nil end
    local pa, pb = a.center or a, b.center or b
    local mx, my = (pa.x + pb.x) * 0.5, (pa.y + pb.y) * 0.5
    local bestTeam, bestD2
    for _, outpost in ipairs(MapData.OUTPOSTS or {}) do
        if outpost.pos then
            local dx, dy = mx - outpost.pos[1], my - outpost.pos[2]
            local d2 = dx * dx + dy * dy
            if not bestD2 or d2 < bestD2 then bestTeam, bestD2 = outpost.team, d2 end
        end
    end
    return bestTeam
end

local PAIR_SELECTION_CONFIG = "tinker_farm"
local PAIR_SELECTION_KEY = "double_camp_pairs"
local PAIR_PANEL_FONT = Render.LoadFont(
    "Segoe UI",
    Enum.FontCreate.FONTFLAG_ANTIALIAS,
    Enum.FontWeight.SEMIBOLD
)
local pairPanel = { open = false, rect = nil, pendingClick = false, selectedCamp = nil }

local function pair_selection_key(a, b)
    if not (a and b) then return nil end
    local ka, kb = Map.CampKey(a), Map.CampKey(b)
    if ka > kb then ka, kb = kb, ka end
    return ka .. "~" .. kb
end

local function pair_selection_catalog()
    local camps = {}
    for _, c in ipairs(MapData.CAMPS or {}) do
        local p = c.center
        if p then
            camps[#camps + 1] = {
                x = p[1], y = p[2], z = p[3] or 0, tier = c.tier or 0,
            }
        end
    end
    return camps
end

local function save_pair_selection()
    local keys = {}
    for key, enabled in pairs(State.pairSelection or {}) do
        if enabled then keys[#keys + 1] = key end
    end
    table.sort(keys)
    Config.WriteString(PAIR_SELECTION_CONFIG, PAIR_SELECTION_KEY, table.concat(keys, ";"))
    Config.WriteInt(PAIR_SELECTION_CONFIG, PAIR_SELECTION_KEY .. "_initialized", 1)
end

local function initialize_pair_selection()
    if State.pairSelection then return end
    State.pairSelection = {}
    local catalog = pair_selection_catalog()
    local initialized = Config.ReadInt(PAIR_SELECTION_CONFIG, PAIR_SELECTION_KEY .. "_initialized", 0) == 1
    if initialized then
        for key in string.gmatch(
            Config.ReadString(PAIR_SELECTION_CONFIG, PAIR_SELECTION_KEY, ""),
            "[^;]+"
        ) do
            State.pairSelection[key] = true
        end
        return
    end

    local points = {}
    for i, camp in ipairs(catalog) do points[i] = { x = camp.x, y = camp.y } end
    local pair_max = math.min(K.PAIR_RADIUS, K.MARCH_LEN - 2 * math.abs(K.MARCH_PAIR_OFFSET))
    local function allow(i, j) return forced_pair(catalog[i], catalog[j]) end
    for _, group in ipairs(Farm.GreedyPairs(points, pair_max, nil, allow)) do
        if group.b then
            State.pairSelection[pair_selection_key(catalog[group.a], catalog[group.b])] = true
        end
    end
    save_pair_selection()
end

local function is_pair_selected(a, b)
    initialize_pair_selection()
    return State.pairSelection[pair_selection_key(a, b)] == true or forced_pair(a, b)
end

local function toggle_pair_selection(a, b)
    local key = pair_selection_key(a, b)
    if not key then return end
    initialize_pair_selection()
    if State.pairSelection[key] then
        State.pairSelection[key] = nil
    else
        local ka, kb = Map.CampKey(a), Map.CampKey(b)
        local conflicts = {}
        for existing in pairs(State.pairSelection) do
            local first, second = existing:match("^([^~]+)~([^~]+)$")
            if first == ka or second == ka or first == kb or second == kb then
                conflicts[#conflicts + 1] = existing
            end
        end
        for _, conflict in ipairs(conflicts) do State.pairSelection[conflict] = nil end
        State.pairSelection[key] = true
    end
    pairPanel.selectedCamp = nil
    save_pair_selection()
end

local function select_pair_camp(camp)
    if not pairPanel.selectedCamp then
        pairPanel.selectedCamp = camp
        return
    end

    local first = pairPanel.selectedCamp
    if Map.CampKey(first) == Map.CampKey(camp) then
        pairPanel.selectedCamp = nil
        return
    end

    local dx, dy = first.x - camp.x, first.y - camp.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local pair_max = math.min(K.PAIR_RADIUS, K.MARCH_LEN - 2 * math.abs(K.MARCH_PAIR_OFFSET))
    if distance > 200 and (distance <= pair_max or forced_pair(first, camp)) then
        toggle_pair_selection(first, camp)
    else
        pairPanel.selectedCamp = camp
    end
end

local function configured_pair_stand(a, b)
    if not (a and b) then return nil end
    local ka, kb = Map.CampKey(a), Map.CampKey(b)
    for _, entry in ipairs(K.PAIR_STANDS or {}) do
        local p = entry.camps
        local k1 = p and p[1] and Map.CampKey({ x = p[1][1], y = p[1][2] })
        local k2 = p and p[2] and Map.CampKey({ x = p[2][1], y = p[2][2] })
        if k1 and k2 and ((ka == k1 and kb == k2) or (ka == k2 and kb == k1)) then
            local s = entry.stand
            if s then return Vector(s[1], s[2], s[3] or a.z or 0) end
        end
    end
    return nil
end

local function refresh_handles(h)
    State.march = NPC.GetAbility(h, "tinker_march_of_the_machines")
    State.rearm = NPC.GetAbility(h, "tinker_rearm")
    State.keen  = NPC.GetAbility(h, "tinker_keen_teleport")
    State.laser = NPC.GetAbility(h, "tinker_laser")
end

local function ready(ab) return ab and Ability.CanBeExecuted(ab) == -1 end
local function mana() return NPC.GetMana(State.hero) or 0 end

local function effective_mana()
    local h = State.hero
    local bt = NPC.GetItem(h, "item_bottle", true)
    local ch = (bt and Item.GetCurrentCharges and Item.GetCurrentCharges(bt)) or 0
    local m = mana() + ch * K.BOTTLE_MANA_PER_CHARGE

    local ab = NPC.GetItem(h, "item_arcane_boots", true)
    if ab and Ability.CanBeExecuted(ab) == -1 then m = m + K.ARCANE_MANA end
    local sr = NPC.GetItem(h, "item_soul_ring", true)
    if sr and Ability.CanBeExecuted(sr) == -1
       and (Entity.GetHealth(h) or 0) >= (Entity.GetMaxHealth(h) or 1) * K.SR_HP_FRAC_MIN then
        m = m + K.SOUL_RING_MANA
    end
    return m
end

local function total_gold()
    local ok, g = pcall(function() return Player.GetTotalGold and Player.GetTotalGold(State.player) end)
    return (ok and type(g) == "number") and g or nil
end

local function gold_tick()
    local g = total_gold()
    if g == nil then return end
    if State.goldPrev == nil then State.goldPrev = g; State.gpmT0 = now() end
    local delta = g - State.goldPrev
    State.goldPrev = g
    if delta > 0 then State.earned = (State.earned or 0) + delta end
end

local function gpm()
    local mins = (now() - (State.gpmT0 or now())) / 60
    return (mins > 0.05) and ((State.earned or 0) / mins) or 0
end
local function origin(e) return Entity.GetAbsOrigin(e) end

local function cd_remaining(ab)
    if not ab then return 0 end
    local ok, cd = pcall(function() return Ability.GetCooldownTimeRemaining and Ability.GetCooldownTimeRemaining(ab) end)
    if ok and type(cd) == "number" and cd > 0 then return cd end
    return ready(ab) and 0 or 0.1
end

-- реальный КД без подмены "0.1" (cd_remaining подставляет 0.1, когда способность просто
-- не готова из-за силенса/стана/маны - из-за этого несработавший каст считался выполненным).
-- Всё в одной таблице, чтобы не упереться в лимит локальных переменных Lua (200 на chunk).
local MC = {}
function MC.real_cd(ab)
    if not ab then return nil end
    local ok, cd = pcall(function() return Ability.GetCooldownTimeRemaining and Ability.GetCooldownTimeRemaining(ab) end)
    if ok and type(cd) == "number" then return cd end
    return nil
end

function MC.now_cd()
    local c = MC.real_cd(State.march)
    if c ~= nil then return c end
    return cd_remaining(State.march)
end

-- каст W выполнен только если у него реально пошёл кулдаун
function MC.fired(mp)
    if not mp then return false end
    local c = MC.real_cd(State.march)
    if c ~= nil then return c > (mp.cdBefore or 0) + 0.3 end
    return (not ready(State.march)) or cd_remaining(State.march) > (mp.cdBefore or 0) + 0.05
end

local function is_channeling()
    if NPC.IsChannellingAbility and NPC.IsChannellingAbility(State.hero) then return true end

    local kp = State.keenPending
    if kp then

        local okm, me = pcall(origin, State.hero)
        if not okm then me = nil end
        if me and kp.land and me:Distance(kp.land) < 600 then
            State.keenPending = nil
        elseif now() < (kp.due or 0) then
            return true
        end
    end

    local rp = State.rearmPending
    if rp then
        if (rp.mcd and rp.mcd > 4 and cd_remaining(State.march) < 0.5)
           or (rp.kcd and rp.kcd > 4 and cd_remaining(State.keen) < 0.5) then
            State.rearmPending = nil
        elseif now() < (rp.due or 0) then
            return true
        end
    end
    return now() < (State.channelUntil or 0)
end

local function verify_cast(name, ab, extra)
    State.pendingVerify = { name = name, ab = ab, baseCD = cd_remaining(ab), expire = now() + 0.6, extra = extra }
end
local function process_verify()
    local v = State.pendingVerify
    if not v then return end
    if (not ready(v.ab)) or cd_remaining(v.ab) > v.baseCD + 0.05 then
        logline(v.name .. " FIRED" .. (v.extra or "")); State.pendingVerify = nil
    elseif now() > v.expire then
        logline(v.name .. " issued_NOT_fired"); State.pendingVerify = nil

        if (v.name == "keen" or v.name == "keen_home" or v.name == "rearm")
           and not (NPC.IsChannellingAbility and NPC.IsChannellingAbility(State.hero)) then
            State.channelUntil = 0
            if v.name == "rearm" then State.rearmPending = nil else State.keenPending = nil end
        end
    end
end

local function issue_def(order, ability, target, pos)
    Player.PrepareUnitOrders(State.player, order, target, pos, ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, State.hero,
        false, false, false, true, false, false)
    State.nextOrder = now() + K.ORDER_GAP
    return true
end

local function issue(order, ability, target, pos)
    if now() < State.nextOrder then return false end
    return issue_def(order, ability, target, pos)
end

local function move_to(pos, src)
    local lm = State.lastMove
    if lm and now() - lm.t < K.MOVE_DEDUP_S then
        local dx, dy = pos.x - lm.x, pos.y - lm.y
        if dx * dx + dy * dy <= K.MOVE_DEDUP_DIST * K.MOVE_DEDUP_DIST then return true end
    end
    if issue(UO.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, nil, pos) then

        State.lastMove = { x = pos.x, y = pos.y, t = now(), src = src }
        return true
    end
    return false
end
local function cast_pos(ab, pos) return issue(UO.DOTA_UNIT_ORDER_CAST_POSITION, ab, nil, pos) end
local function cast_no_target(ab) return issue(UO.DOTA_UNIT_ORDER_CAST_NO_TARGET, ab, nil, nil) end
local function cast_target(ab, ent) return issue(UO.DOTA_UNIT_ORDER_CAST_TARGET, ab, ent, nil) end

local function friendly_fountain_pos()
    for _, f in ipairs(MapData.FOUNTAINS or {}) do
        if f.team == State.team and f.pos then return Vector(f.pos[1], f.pos[2], f.pos[3]) end
    end
    return nil
end
local function enemy_fountain_pos()
    for _, f in ipairs(MapData.FOUNTAINS or {}) do
        if f.team ~= State.team and f.pos then return { x = f.pos[1], y = f.pos[2] } end
    end
    return nil
end

local function stand_depth(pos, lane)
    if not pos then return 0 end
    State.depthRuler = State.depthRuler or (State.team and Lane.DepthRuler(MapData.TOWERS, MapData.FOUNTAINS, State.team)) or nil
    if not State.depthRuler then return 0 end
    return Lane.Depth(State.depthRuler, pos, lane)
end

local function clamp_intercept(cp, fwd, lane)
    if not cp then return cp end

    if (fwd or 0) ~= 0 then
        local fp0, ep0 = friendly_fountain_pos(), enemy_fountain_pos()
        if fp0 and ep0 then
            local fx, fy = ep0.x - fp0.x, ep0.y - fp0.y
            local fl = math.sqrt(fx * fx + fy * fy)
            if fl > 1 then cp = { x = cp.x + fx / fl * fwd, y = cp.y + fy / fl * fwd } end
        end
    end
    local d = stand_depth(cp, lane)
    local target = (d < -K.LANE_ANCHOR_BACK and -K.LANE_ANCHOR_BACK)
                or (d > K.WALK_DEPTH_MAX and K.WALK_DEPTH_MAX) or nil
    if not target then return cp end
    local fp, ep = friendly_fountain_pos(), enemy_fountain_pos()
    if not (fp and ep) then return cp end
    local ux, uy = ep.x - fp.x, ep.y - fp.y
    local ul = math.sqrt(ux * ux + uy * uy)
    if ul <= 1 then return cp end
    local pull = target - d
    return { x = cp.x + ux / ul * pull, y = cp.y + uy / ul * pull }
end

local function risk_opts()
    local of, ef = friendly_fountain_pos(), enemy_fountain_pos()

    local zones = {}
    for _, c in ipairs(K.RISK_CONTESTED_CAMPS or {}) do
        zones[#zones + 1] = { x = c[1], y = c[2], radius = K.RISK_CONTESTED_RADIUS, bump = K.RISK_CONTESTED_BUMP }
    end
    return { our_fountain = of and { x = of.x, y = of.y } or nil, enemy_fountain = ef,
             half_weight = K.RISK_HALF_WEIGHT, zones = zones }
end

local function keen_home(purpose)
    local fp = friendly_fountain_pos()
    if not fp then return false end
    if cast_pos(State.keen, fp) then
        State.channelUntil = now() + K.KEEN_CHANNEL + K.CHANNEL_PAD

        local me = State.hero and origin(State.hero)
        verify_cast("keen_home", State.keen, string.format(" purpose=%s from=(%.0f,%.0f) mana=%.0f",
            purpose or "?", me and me.x or 0, me and me.y or 0, mana()))
        return true
    end
    return false
end

local channel_threat_near

local function near_fountain()
    local fp = friendly_fountain_pos()
    local me = State.hero and origin(State.hero)
    return (fp and me and me:Distance(Vector(fp.x, fp.y, me.z)) < 1200) and true or false
end

local function try_rearm()
    if not ready(State.rearm) then return false end

    if State.rearmCancelT and now() - State.rearmCancelT < K.REARM_CANCEL_BACKOFF_S
       and not near_fountain() then return false end

    if channel_threat_near and not near_fountain() then
        local thr = channel_threat_near(origin(State.hero))
        if thr then

            State.chanDeferSince = State.chanDeferSince or now()
            if now() - (State.chanDeferLogT or 0) > 2.0 then
                State.chanDeferLogT = now()
                logline("channel_defer rearm threat=" .. thr)
            end
            return false
        end
        State.chanDeferSince = nil
    end
    local rcost = (Ability.GetManaCost and Ability.GetManaCost(State.rearm)) or K.REARM_MANA_FB

    local need = K.ESCAPE_MANA + rcost
    if mana() < need then

        State.rearmNoFundT, State.rearmNoFundGap = now(), need - mana()
        if now() - (State.rearmNoFundLogT or 0) > 1.0 then
            State.rearmNoFundLogT = now()
            logline(string.format("rearm_nofund raw=%.0f eff=%.0f need=%.0f rcost=%.0f gap=%.0f fsm=%s",
                mana(), effective_mana(), need, rcost, need - mana(), tostring(State.fsm)))
        end
        return false
    end
    if not cast_no_target(State.rearm) then return false end
    local lvl = (Ability.GetLevel and Ability.GetLevel(State.rearm)) or 1
    State.channelUntil = now() + (K.REARM_CHANNEL[lvl] or K.REARM_CHANNEL[1]) + K.CHANNEL_PAD
    verify_cast("rearm", State.rearm)

    State.rearmPending = { due = State.channelUntil + 0.2,
                           mcd = cd_remaining(State.march), kcd = cd_remaining(State.keen) }
    return true
end

local function enemy_snapshot()
    if State.enemySnapshot and State.enemySnapshotSerial == State.updateSerial then
        return State.enemySnapshot
    end
    local snap = Escape.FogSnapshot(State.hero, { max_ms = K.FOG_MS, now = now })

    if now() - (State.fogProbeT or -99) >= 2.0 then
        State.fogProbeT = now()
        local cur = (GlobalVars and GlobalVars.GetCurTime and GlobalVars.GetCurTime()) or -1
        local vis, fog = 0, 0
        for i = 1, #snap.heroes do
            if snap.heroes[i].visible then vis = vis + 1 else fog = fog + 1 end
        end

        local vs = Escape.Vision.Stats()
        local tks = {}
        for k, n in pairs(vs.types) do tks[#tks + 1] = k .. ":" .. n end
        table.sort(tks)
        logline(string.format("fog_probe t=%.1f off=%.1f vis=%d fog=%d vtrack=%d vev=%d vtypes=%s vsh=%d",
            now(), cur - now(), vis, fog, vs.tracked, vs.events,
            (#tks > 0) and table.concat(tks, ",") or "-", (vs.tracked_sh or 0)))
        local me = origin(State.hero)
        for i = 1, #snap.heroes do
            local h = snap.heroes[i]
            if not h.visible then
                local raw
                if Hero.GetLastVisibleTime and h.entity then
                    local ok, v = pcall(Hero.GetLastVisibleTime, h.entity)
                    if ok and type(v) == "number" then raw = v end
                end
                local d = -1
                if me and h.pos then
                    local dx, dy = me.x - h.pos.x, me.y - h.pos.y
                    d = math.sqrt(dx * dx + dy * dy)
                end
                local nm = "?"
                if h.entity and NPC.GetUnitName then
                    local ok2, n2 = pcall(NPC.GetUnitName, h.entity)
                    if ok2 and type(n2) == "string" then nm = n2 end
                end

                local ash = Escape.Vision.AgeShadow(h.entity)
                logline(string.format("fog_hero raw=%s age_now=%s age_real=%s d=%.0f name=%s",
                    raw and string.format("%.1f", raw) or "nil",
                    raw and string.format("%.1f", now() - raw) or "nil",
                    ash and string.format("%.1f", ash) or "nil",
                    d, nm))
            end
        end
    end
    State.enemySnapshot, State.enemySnapshotSerial = snap, State.updateSerial
    return snap
end

local function kill_threat_w(h)
    local ok, name = pcall(function() return NPC.GetUnitName and NPC.GetUnitName(h.entity) end)
    if not (ok and name) then return 1 end
    return HeroValue.KillThreat(name)
end

local function enemy_breakers(name)
    local c = State.disableRange; if not c then c = {}; State.disableRange = c end
    local v = c[name]
    if v == nil then
        local hd = HeroData.Get and HeroData.Get(name)
        v = ChannelGate.Breakers(hd and hd.abilities, AbilityData, ThreatData) or false
        c[name] = v
    end
    return v
end
do

    local function read_breaker(ent, ability)
        local ok, lvl, cd = pcall(function()
            local h = NPC.GetAbility and NPC.GetAbility(ent, ability)
            if not h then return nil, nil end
            return Ability.GetLevel and Ability.GetLevel(h),
                   Ability.GetCooldown and Ability.GetCooldown(h)
        end)
        if not ok then return nil, nil end
        lvl = (type(lvl) == "number") and lvl or nil
        cd = (type(cd) == "number") and cd or nil
        if lvl and not State.enLvlProbeOk then State.enLvlProbeOk = true; logline("en_lvl_probe ok") end
        if cd then if not State.enCdProbeOk then State.enCdProbeOk = true; logline("en_cd_probe ok") end
        elseif not State.enCdProbeNil then State.enCdProbeNil = true; logline("en_cd_probe nil") end
        return lvl, cd
    end
    channel_threat_near = function(pt)
        if not pt then return nil end
        local snap = State.fog or enemy_snapshot()

        for _, h in ipairs((snap and snap.heroes) or {}) do
            local ok, name = pcall(function() return NPC.GetUnitName and NPC.GetUnitName(h.entity) end)
            local br = ok and name and enemy_breakers(name)
            if br and h.pos then
                State.enObs = State.enObs or {}
                local obs = State.enObs[name]; if not obs then obs = { abil = {} }; State.enObs[name] = obs end
                if h.visible then
                    local ok2, hl = pcall(function() return NPC.GetCurrentLevel and NPC.GetCurrentLevel(h.entity) end)
                    if ok2 and type(hl) == "number" and hl > 0 then obs.hero = { lvl = hl, t = now() } end
                end
                local dx, dy = h.pos.x - pt.x, h.pos.y - pt.y
                local d = math.sqrt(dx * dx + dy * dy)
                for _, b in ipairs(br) do
                    local cd
                    if h.visible then
                        local lvl
                        lvl, cd = read_breaker(h.entity, b.ability)
                        if lvl then obs.abil[b.ability] = { lvl = lvl, t = now() } end
                    end

                    if not ChannelGate.LevelCleared({ ability = b.ability, ult = b.ult },
                                                    { abil = obs.abil[b.ability], hero = obs.hero }, now())
                       and not (cd and cd > K.CHANNEL_GATE_HORIZON)
                       and d <= b.range + K.CHANNEL_GATE_MARGIN
                               + (((h.age or 0) <= K.FOG_AGE_CAP) and (h.probable_radius or 0) or 0)
                       and ChannelGate.ReadyAt(State.castStamps or {}, name, b.ability, now() + K.CHANNEL_GATE_HORIZON) then
                        return name, h.pos
                    end
                end
            end
        end
        return nil
    end
end

local function enemy_risk_at(pt, widen, shadow)
    if not pt then return 0 end
    local snap = State.fog or enemy_snapshot()
    if shadow then

        if State.fogShSrc ~= snap then
            State.fogShSrc, State.fogSh = snap, Escape.Vision.ShadowAges(snap)
        end
        snap = State.fogSh
    end

    local p = Vector(pt.x, pt.y, 0)
    return Escape.FogProximityRisk(snap, p, {
        risk_radius = K.RISK_RADIUS + (widen or 0), fog_ms = K.FOG_MS,
        fog_spread = K.FOG_SPREAD, age_cap = K.FOG_AGE_CAP, now = now,
        weight_fn = kill_threat_w })
end

local function enemy_tower_risk(pos)
    local R, rng = K.TOWER_RISK_RADIUS, K.TOWER_ATTACK_RANGE
    local best = 0
    local p = Vector(pos.x, pos.y, 0)
    for _, t in ipairs(Map.TowersInRadius(p, R) or {}) do
        if Entity.GetTeamNum(t) ~= State.team and Entity.IsAlive(t) then
            local d = origin(t):Distance(p)
            local f = (d <= rng) and 1 or (d < R and (R - d) / (R - rng) or 0)
            if f > best then best = f end
        end
    end
    return best * K.TOWER_RISK_WEIGHT
end

local function enemy_lane_t1(lane)
    local pos
    local key = "tower1_" .. (lane or K.HOME_LANE)
    for _, t in ipairs(MapData.TOWERS or {}) do
        if t.team ~= State.team and t.pos and t.name and t.name:find(key, 1, true) then
            pos = { x = t.pos[1], y = t.pos[2] }; break
        end
    end
    if not pos then return nil, false end
    for _, t in ipairs(Map.TowersInRadius(Vector(pos.x, pos.y, 0), K.TOWER_ALIVE_R) or {}) do
        if Entity.GetTeamNum(t) ~= State.team and Entity.IsAlive(t) then return pos, true end
    end
    return pos, false
end

local function tower_key_near(pos)
    if not pos then return nil end
    local best, bd
    for _, t in ipairs(MapData.TOWERS or {}) do
        if t.pos then
            local dx, dy = t.pos[1] - pos.x, t.pos[2] - pos.y
            local d = dx * dx + dy * dy
            if d <= K.TOWER_ALIVE_R * K.TOWER_ALIVE_R and (not bd or d < bd) then
                bd, best = d, t.name .. "@" .. tostring(t.team)
            end
        end
    end
    return best
end

local function lane_leash_ok(pos, slop, lane)
    lane = lane or K.HOME_LANE
    local _, t1alive = enemy_lane_t1(lane)
    if t1alive then return true end
    local anchor
    for _, nm in ipairs({ "tower1_" .. lane, "tower2_" .. lane, "tower3_" .. lane }) do
        for _, t in ipairs(MapData.TOWERS or {}) do
            if t.team == State.team and t.pos and t.name and t.name:find(nm, 1, true) then
                for _, e in ipairs(Map.TowersInRadius(Vector(t.pos[1], t.pos[2], 0), K.TOWER_ALIVE_R) or {}) do
                    if Entity.GetTeamNum(e) == State.team and Entity.IsAlive(e) then
                        anchor = { x = t.pos[1], y = t.pos[2] }; break
                    end
                end
            end
            if anchor then break end
        end
        if anchor then break end
    end
    if not anchor then return true end
    if stand_depth(pos) <= stand_depth(anchor) then return true end
    local dx, dy = pos.x - anchor.x, pos.y - anchor.y
    local r = K.T1DOWN_LEASH + (slop or 0)
    return dx * dx + dy * dy <= r * r
end

local function suppress_shove(lane, untilT, why)
    lane = lane or K.HOME_LANE
    State.shoveSuppress[lane] = untilT

    logline(string.format("shove_suppress ln=%s why=%s for=%.1f", lane, why or "?", untilT - now()))
end
local function shove_suppressed(lane)
    return now() < (State.shoveSuppress[lane or K.HOME_LANE] or 0)
end

local function enemy_t1_points_info(pos)
    local best, bd, others_up, best_alive = nil, nil, 0, false
    for _, t in ipairs(MapData.TOWERS or {}) do
        if t.team ~= State.team and t.pos and t.name and t.name:find("tower1_", 1, true) then
            local alive = false
            for _, e in ipairs(Map.TowersInRadius(Vector(t.pos[1], t.pos[2], 0), K.TOWER_ALIVE_R) or {}) do
                if Entity.GetTeamNum(e) ~= State.team and Entity.IsAlive(e) then alive = true; break end
            end
            local dx, dy = t.pos[1] - pos.x, t.pos[2] - pos.y
            local d = dx * dx + dy * dy
            if not bd or d < bd then
                if best and best_alive then others_up = others_up + 1 end
                bd, best, best_alive = d, { x = t.pos[1], y = t.pos[2] }, alive
            elseif alive then
                others_up = others_up + 1
            end
        end
    end
    if not best then return nil end
    return { depth_past = stand_depth(pos) - stand_depth(best), line_alive = best_alive, others_up = others_up }
end

local can_bail
local function lane_unsafe(pos, opts)
    local p = Vector(pos.x, pos.y, 0)

    local function cr(br, v1, r0, r1, chg, ne, nh)
        if not (opts and opts.commit) then return end

        r0, r1, chg, ne, nh = r0 or -1, r1 or -1, chg or -1, ne or -1, nh or -1
        local site, w = opts.site or "?", opts.commit
        State.crT = State.crT or {}

        local key, iv = site .. "/" .. br, 10.0
        if br == "widen" then key, iv = site .. ((chg == 1) and "!" or ""), (chg == 1) and 2.0 or 10.0 end
        if Escape.DiagGate(State.crT, key, now(), iv) then

            if type(ne) == "table" then

                ne, nh = Escape.NearestEnemyEdge(ne, p, { fog_ms = K.FOG_MS, age_cap = K.FOG_AGE_CAP }), #(ne.heroes or {})
            end
            logline(string.format(

                "commit_risk t=%.1f site=%s br=%s exp=%.1f st=%.1f wd=%.0f wcap=%d ap=%g wmax=%g " ..
                "r0=%.2f r1=%.2f g=%.2f v1=%d chg=%d ne=%.0f nh=%d",
                now(), site, br, (opts.travel or 0) + K.COMMIT_STAND_S, K.COMMIT_STAND_S, w,
                (w >= K.COMMIT_WIDEN_MAX) and 1 or 0, K.COMMIT_APPROACH_SPEED, K.COMMIT_WIDEN_MAX,
                r0, r1, K.SHOVE_SAFE_RISK, v1, chg, ne, nh))
        end
    end
    if enemy_tower_risk(p) >= K.SHOVE_SAFE_RISK then
        cr("tower", 1)
        return true
    end

    local snap = State.fog or enemy_snapshot()

    local nv = 0
    for _, h in ipairs(snap.heroes or {}) do
        if h.pos and h.visible then
            local dx, dy = h.pos.x - p.x, h.pos.y - p.y
            if math.sqrt(dx * dx + dy * dy) <= K.GANK_RADIUS then nv = nv + 1 end
        end
    end
    if nv >= 2 then
        cr("nv2", 1)
        return true
    end
    local rf = Escape.ReachableFog(snap, { x = p.x, y = p.y },
        { radius = K.GANK_RADIUS, reach_cap = K.FOG_REACH_CAP, fresh_s = K.FOG_FRESH_S })
    if nv >= 1 and nv + rf >= 2 then
        local bail = (opts and opts.bail) and can_bail()
        if (opts and opts.bail) and now() - (State.fogGateLogT or -9) > 2 then
            State.fogGateLogT = now()
            logline(string.format("fog_gate nv=%d rf=%d bail=%s -> %s", nv, rf,
                tostring(bail), bail and "shove" or "abort"))
        end
        cr("fog", bail and 0 or 1)
        return not bail
    end
    if nv == 1 then
        local h0 = State.hero
        local hpf = (Entity.GetHealth(h0) or 1) / math.max(1, Entity.GetMaxHealth(h0) or 1)
        cr("trade", (hpf < K.LANE_TRADE_HP) and 1 or 0)
        return hpf < K.LANE_TRADE_HP
    end

    local w = (opts and opts.commit) or 0
    local r1 = enemy_risk_at(p, w)
    local unsafe = r1 >= K.SHOVE_SAFE_RISK

    if opts and opts.commit then
        local r0 = enemy_risk_at(p)
        local chg = unsafe ~= (r0 >= K.SHOVE_SAFE_RISK)

        cr("widen", unsafe and 1 or 0, r0, r1, chg and 1 or 0, snap)
    end
    return unsafe
end

local function tower_safe(pos)
    if not pos then return false end
    local rr = K.TOWER_ATTACK_RANGE + K.TOWER_SAFE_MARGIN
    local p = Vector(pos.x, pos.y, 0)
    for _, t in ipairs(Map.TowersInRadius(p, rr + 100) or {}) do
        if Entity.GetTeamNum(t) ~= State.team and Entity.IsAlive(t) and origin(t):Distance(p) < rr then
            return false
        end
    end
    return true
end

local function safe_rearm()
    if lane_unsafe(origin(State.hero)) then return false end
    return try_rearm()
end

local function blink_item() return NPC.GetItem(State.hero, "item_blink", true) end

local function blink_broken()
    if not (Damage and Damage.GetRecentDamage) then return false end
    local ok, d = pcall(Damage.GetRecentDamage, State.hero, 3.0)
    return ok and type(d) == "number" and d > 0
end

local function can_blink(kind, interrupt, force)
    local sw = (kind == "travel") and State.menu.blinkTravel or State.menu.blinkEscape
    if not force and not (sw and sw:Get()) then return false end
    local it = blink_item()
    if not (it and ready(it)) then return false end
    if blink_broken() or (is_channeling() and not interrupt) then return false end
    if now() - (State.lastBlinkT or -99) < K.BLINK_DEBOUNCE then return false end
    return true
end

can_bail = function()
    local h = State.hero
    local hpf = (Entity.GetHealth(h) or 1) / math.max(1, Entity.GetMaxHealth(h) or 1)
    if hpf < K.LANE_TRADE_HP then return false end
    return can_blink("bail") or ready(State.keen)
end

local function can_bail_raid()
    local h = State.hero
    local hpf = (Entity.GetHealth(h) or 1) / math.max(1, Entity.GetMaxHealth(h) or 1)
    return hpf >= K.LANE_TRADE_HP and can_blink("bail")
end

local function raid_gank_ok(dest)
    local rf = Escape.ReachableFog(State.fog or enemy_snapshot(), dest,
        { radius = K.GANK_RADIUS, reach_cap = K.FOG_REACH_CAP, fresh_s = K.FOG_FRESH_S })
    if rf == 0 then return true end
    local bail = can_bail_raid()
    if now() - (State.raidGateLogT or -9) > 2 then
        State.raidGateLogT = now()
        logline(string.format("raid_gate rf=%d bail=%s -> %s", rf, tostring(bail), bail and "ok" or "veto"))
    end
    return bail
end

local function do_blink(dest)
    local it = blink_item(); if not (it and dest) then return false end
    local me = origin(State.hero)
    local dx, dy = dest.x - me.x, dest.y - me.y
    local d = math.sqrt(dx * dx + dy * dy)
    local maxr = K.BLINK_RANGE - 50
    local tgt = (d > maxr) and Vector(me.x + dx / d * maxr, me.y + dy / d * maxr, me.z) or Vector(dest.x, dest.y, me.z)
    if cast_pos(it, tgt) then State.lastBlinkT = now(); return true end
    return false
end

local function try_escape_blink()

    local function skip(why)
        if now() - (State.lastEscSkipLog or -99) > 2.0 then
            State.lastEscSkipLog = now()
            logline("esc_skip why=" .. why)
        end
        return false
    end
    if not can_blink("escape") then
        local it = blink_item()

        return skip((not (State.menu.blinkEscape and State.menu.blinkEscape:Get())) and "menu_off"
            or (not it) and "no_item"
            or (not ready(it)) and "item_cd"
            or blink_broken() and "broken_damage"
            or is_channeling() and "channeling"
            or "debounce")
    end
    State.fog = State.fog or enemy_snapshot()
    local me = origin(State.hero)
    local threat, bestd
    for _, h in ipairs((State.fog and State.fog.heroes) or {}) do
        if h.pos then
            local d = me:Distance(Vector(h.pos.x, h.pos.y, me.z))
            if not bestd or d < bestd then bestd, threat = d, { x = h.pos.x, y = h.pos.y } end
        end
    end

    if not threat then return skip("no_threat") end
    if bestd > K.RISK_RADIUS then return skip("threat_far") end
    local trees = {}
    for _, t in ipairs(Map.TreesInRadius(me, K.BLINK_CLAMP) or {}) do
        local tp = Entity.GetAbsOrigin(t)
        if tp then trees[#trees + 1] = { x = tp.x, y = tp.y } end
    end
    local hide = Map.Nav.TreeHideSpot(trees, { x = me.x, y = me.y }, threat, { blink_max = K.BLINK_CLAMP })
    if hide then
        hide = Map.SnapWalkable(hide, { x = me.x, y = me.y })

        if do_blink(Vector(hide.x, hide.y, me.z)) then
            logline(string.format("blink_escape tree dest=(%.0f,%.0f)", hide.x, hide.y))
            return true
        end
    end
    local dest = Escape.SafestSpotNear(State.hero, K.BLINK_CLAMP, { snapshot = State.fog, now = now })
    if dest and do_blink(dest) then
        logline(string.format("blink_escape dest=(%.0f,%.0f)", dest.x, dest.y))
        return true
    end

    return skip((not hide) and string.format("no_cluster trees=%d", #trees)
        or (not dest) and "no_spot"
        or "cast_failed")
end

local function try_travel_blink(aim)

    local function skip(why)
        if now() - (State.lastBlinkSkipLog or -99) > 2.0 then
            State.lastBlinkSkipLog = now()
            logline("blink_skip why=" .. why)
        end
        return false
    end
    if not aim then return false end

    if not can_blink("travel") then
        local it = blink_item()
        local why = (not (State.menu.blinkTravel and State.menu.blinkTravel:Get())) and "menu_off"
            or (not it) and "no_item"
            or (not ready(it)) and "item_cd"
            or blink_broken() and "broken_damage"
            or is_channeling() and "channeling"
            or "debounce"
        return skip(why)
    end

    if enemy_risk_at(origin(State.hero)) >= K.SHOVE_SAFE_RISK then return skip("risk_me") end
    local me = origin(State.hero)
    local d = me:Distance(aim)

    if d < K.BLINK_TRAVEL_MIN then return false end

    local dest = Vector(aim.x, aim.y, me.z)

    local dx, dy = dest.x - me.x, dest.y - me.y
    local dl = math.sqrt(dx * dx + dy * dy)
    local maxr = K.BLINK_RANGE - 50
    local land = (dl > maxr) and { x = me.x + dx / dl * maxr, y = me.y + dy / dl * maxr }
                              or { x = dest.x, y = dest.y }
    if Map.Walkable and Map.GroundPos then
        local ok, walk = pcall(function() return Map.Walkable(Map.GroundPos(land.x, land.y)) end)
        if ok and not walk then

            land = Map.SnapWalkable(land, { x = me.x, y = me.y })
            local ok2, walk2 = pcall(function() return Map.Walkable(Map.GroundPos(land.x, land.y)) end)
            if not (ok2 and walk2) then return skip("land_unwalkable") end
        end
    end

    if enemy_risk_at(Vector(land.x, land.y, 0)) >= K.KEEN_LAND_SAFE_RISK then
        return skip("land_risk")
    end

    if do_blink(Vector(land.x, land.y, me.z)) then
        logline(string.format("blink_travel d=%.0f dest=(%.0f,%.0f)", d, land.x, land.y))
        return true
    end
    return false
end

local function def_uname(u)
    local ok, n = pcall(function() return NPC.GetUnitName and NPC.GetUnitName(u) end)
    return (ok and n) or "?"
end

local SAVE_CFG = {
    self_npc        = function() return State.hero end,
    item            = function(n) if not State.hero then return nil end return NPC.GetItem(State.hero, n, true) end,
    issue_self      = function(intent, it) return issue_def(UO.DOTA_UNIT_ORDER_CAST_TARGET, it, State.hero) end,
    issue_target    = function(intent, it, t) return issue_def(UO.DOTA_UNIT_ORDER_CAST_TARGET, it, t) end,
    issue_position  = function(intent, it, p) return issue_def(UO.DOTA_UNIT_ORDER_CAST_POSITION, it, nil, p) end,
    issue_no_target = function(intent, it) return issue_def(UO.DOTA_UNIT_ORDER_CAST_NO_TARGET, it) end,
    uname           = def_uname,
    dist_to         = function(u)
        local okm, me = pcall(origin, State.hero)
        local oku, p  = pcall(origin, u)
        if not (okm and me and oku and p) then return 1e9 end
        return me:Distance(p)
    end,
    compute_safe_dest = function(caster, dist)

        local okm, me = pcall(origin, State.hero)
        if not (okm and me) then return nil, nil end
        local ok, cp = pcall(origin, caster)
        local dirx, diry = 0, 0
        if ok and cp then
            local dx, dy = me.x - cp.x, me.y - cp.y
            local dl = math.sqrt(dx * dx + dy * dy)
            if dl > 1 then dirx, diry = dx / dl, dy / dl end
        end
        if dirx == 0 and diry == 0 then return nil, nil end
        local d = dist or 600

        local pt = Map.Nav.SafeDest({ x = me.x + dirx * d, y = me.y + diry * d },
                                { x = -dirx, y = -diry }, tower_safe,
                                { max_steps = math.floor(d / 100) - 1 })
        if not (pt and tower_safe(pt)) then return nil, nil end
        return Vector(dirx, diry, 0), Vector(pt.x, pt.y, 0)
    end,
    recent_damage   = function(s)
        if Damage and Damage.GetRecentDamage then
            local ok, d = pcall(Damage.GetRecentDamage, State.hero, s)
            if ok and type(d) == "number" then return d end
        end
        return 0
    end,
}
local SAVE_FIRE = ItemSaves.build(SAVE_CFG)

local function save_is_ready(save_name)

    if not State.hero then return false end
    local n = (save_name == "item_ethereal_blade_self") and "item_ethereal_blade" or save_name
    local it = NPC.GetItem(State.hero, n, true)
    return (it and ready(it)) and true or false
end

local function save_is_owned(save_name)
    if not State.hero then return false end
    local n = (save_name == "item_ethereal_blade_self") and "item_ethereal_blade" or save_name
    return NPC.GetItem(State.hero, n, true) and true or false
end
local function self_can_cast_abilities()

    local me = State.hero
    if not me then return false end
    if NPC.IsSilenced and NPC.IsSilenced(me) then return false end
    return true
end

local DEFAULT_SAVE_CHAIN = {
    "item_wind_waker", "item_cyclone", "item_lotus_orb", "item_manta",
    "item_glimmer_cape", "item_invis_sword", "item_silver_edge",
    "item_hurricane_pike", "item_force_staff",
    "item_black_king_bar",
}

local defense_dispatcher = Defense.New {
    anim_save_overrides     = {},
    hero_save_overrides     = {},

    patched_recommended     = ThreatData.RECOMMENDED_SAVES,
    category_chains         = ThreatData.CATEGORY_CHAINS,
    default_chain           = DEFAULT_SAVE_CHAIN,
    save_fire               = SAVE_FIRE,
    ability_saves           = {},
    self_displacement_saves = { item_force_staff = true, item_hurricane_pike = true },
    save_is_ready           = save_is_ready,
    save_is_owned           = save_is_owned,
    self_can_cast_abilities = self_can_cast_abilities,
    TD                      = ThreatData,
    threats_on_self         = ThreatData.THREATS_ON_SELF,
    reaction_window         = 0.1,
    reserve_skip_floor      = -20,
    concurrent_penalty      = 15,
    throttle_state          = State,
    armed_threats           = {},
    now                     = now,
    dist_to                 = SAVE_CFG.dist_to,
    defense_enabled         = function()
        return true
    end,
    canonicalize_mod        = ThreatData.CanonicalMod,
    eta_resolver            = {},
    eta_resolver_default    = Defense.MakeGenericEtaResolver(ThreatData),
    lock_buffer_s           = 0.3,
    fallback_lock_ttl_s     = 2.0,

    self_npc                = SAVE_CFG.self_npc,

    entity_index            = function(ent)
        if not ent then return nil end
        if Entity.IsEntity and not Entity.IsEntity(ent) then return nil end
        local ok, idx = pcall(Entity.GetIndex, ent)
        if ok and type(idx) == "number" then return idx end
        return nil
    end,
    ability_handle          = function(ability_name)
        if not ability_name or not State.hero then return nil end
        local ok, h = pcall(NPC.GetAbility, State.hero, ability_name)
        if ok then return h end
        return nil
    end,
}

local function creep_eff_hp(c, camp_type)
    local hp = Entity.GetMaxHealth(c) or 0
    local mult
    if NPC.GetMagicalArmorDamageMultiplier then
        local ok, m = pcall(NPC.GetMagicalArmorDamageMultiplier, c)
        if ok and type(m) == "number" and m > 0 then mult = m end
    end
    if not mult then mult = 1 - (K.CAMP_MR[camp_type] or 0) end
    return hp / math.max(0.05, mult)
end

local function camp_creep_list(camp, camp_type, neutrals)
    local out = {}
    for _, c in ipairs(Map.CampCreeps(camp, neutrals)) do
        out[#out + 1] = { entity = c, pos = origin(c),
                          hp = creep_eff_hp(c, camp_type), gold = NPC.GetGoldBountyMax(c) or 0 }
    end
    return out
end

local function effective_march_dmg()
    local lvl = (State.march and Ability.GetLevel(State.march)) or 0
    if lvl < 1 then return 0 end
    local per = K.PER_MARCH_DMG[lvl] or 0

    local okv, live = pcall(function()
        return Ability.GetLevelSpecialValueFor and Ability.GetLevelSpecialValueFor(State.march, "damage", -1)
    end)
    if okv and type(live) == "number" and live > 0 then per = live end
    if State.marchPerLogged ~= per then
        State.marchPerLogged = per
        logline(string.format("march_per_dmg per=%d src=%s lvl=%d", per,
            (okv and type(live) == "number" and live > 0) and "live" or "table", lvl))
    end
    local d = per * K.ROBOTS_EFFECTIVE

    local ok, amp = pcall(function() return NPC.GetBaseSpellAmp and NPC.GetBaseSpellAmp(State.hero) end)
    if ok and type(amp) == "number" and amp > 0 then
        d = d * (1 + (amp > 1 and amp / 100 or amp))
    end
    return d
end

local function clear_marches(camp_type, ehp, stacks)
    local m = marches_for(camp_type)
    if (stacks or 1) >= 2 then
        local emd = effective_march_dmg()
        if emd > 0 and (ehp or 0) > m * emd then m = math.ceil(ehp / emd) end
    end
    return math.min(K.MAX_CLEAR_MARCHES, m)
end

local function camp_clearable(ehp)
    local emd = effective_march_dmg()
    return emd <= 0 or (ehp or 0) <= emd * K.MAX_CLEAR_MARCHES
end

local function rearm_channel()
    local lvl = (State.rearm and Ability.GetLevel and Ability.GetLevel(State.rearm)) or 0
    return K.REARM_CHANNEL[lvl] or K.REARM_CHANNEL[1] or 1.25
end

local function keen_tp()
    local kl = (State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0
    if kl < 1 then return { channel = 1e9 } end
    if ready(State.keen) then return { channel = K.KEEN_CHANNEL } end
    local rl = (State.rearm and Ability.GetLevel and Ability.GetLevel(State.rearm)) or 0
    if rl >= 1 and ready(State.rearm) then return { channel = rearm_channel() + K.KEEN_CHANNEL } end

    local kcd = (Ability.GetCooldown and Ability.GetCooldown(State.keen)) or 5
    local wait = kcd
    if rl >= 1 then
        local rcd = (Ability.GetCooldown and Ability.GetCooldown(State.rearm)) or 5
        wait = math.min(kcd, rcd + rearm_channel())
    end
    return { channel = wait + K.KEEN_CHANNEL }
end

local function refill_wait()
    local h = State.hero
    local mmax = (NPC.GetMaxMana and NPC.GetMaxMana(h)) or 1
    local hmax = Entity.GetMaxHealth(h) or 1
    local tm = math.max(0, K.REFILL_FRAC * mmax - mana()) / math.max(1, K.FOUNTAIN_MANA_PCT_S * mmax)
    local th = math.max(0, K.REFILL_FRAC * hmax - (Entity.GetHealth(h) or 0)) / math.max(1, K.FOUNTAIN_HP_PCT_S * hmax)
    return math.max(tm, th) + rearm_channel()
end
local function camp_visible(center)
    if not (FogOfWar and FogOfWar.IsPointVisible) then return false end
    local ok, v = pcall(FogOfWar.IsPointVisible, Vector(center.x, center.y, center.z or 0))
    return ok and v == true
end

local function camp_stacks(gold, ctype)
    local base = (TIER_EST[ctype] or TIER_EST[1]).gold or 1
    local n = math.floor((gold or 0) / base + 0.5)
    return (n < 1) and 1 or n
end

local function gather_candidates()
    local cands = {}
    local total, vis, est, seen, cleared = 0, 0, 0, 0, 0
    if not State.menu.kindJungle:Get() then State.funnel = {}; return cands end
    local neutrals = State.world.neutrals()

    if now() < 58 then State.funnel = { total = 28, prespawn = true }; return cands end
    for _, cd in ipairs(State.world.camps()) do
        total = total + 1
        local key = Map.CampKey(cd.center)
        if is_disabled_camp(cd.center) then
            cleared = cleared + 1
        elseif is_cleared(key) then
            cleared = cleared + 1
        else
            local creeps = camp_creep_list(cd.camp, cd.type, neutrals)
            if #creeps == 0 and camp_visible(cd.center) then
                if not camp_spawn_window() then
                    mark_cleared(key); State.campSeen[key] = nil
                end
                cleared = cleared + 1
            else
                local gold, ehp, estimated, source
                if #creeps > 0 then
                    vis = vis + 1; estimated, source = false, "live"
                    gold, ehp = Farm.GoldValue(creeps), Farm.EffectiveHP(creeps)
                    State.campSeen[key] = { gold = gold, ehp = ehp, seen_at = now() }
                else
                    local c = State.campSeen[key]
                    if c and (now() - c.seen_at) < K.CAMP_CACHE_S then
                        gold, ehp, estimated, source = c.gold, c.ehp, true, "seen"; seen = seen + 1
                    else
                        local e = TIER_EST[cd.type] or TIER_EST[1]
                        gold, ehp, estimated, source = e.gold, e.hp, true, "est"; est = est + 1
                    end
                end
                if camp_clearable(ehp) then
                    cands[#cands + 1] = { camp = cd.camp, center = cd.center, type = cd.type, box = cd.box,
                                          creeps = creeps, gold = gold, ehp = ehp, key = key,
                                          estimated = estimated, source = source }
                end
            end
        end
    end
    State.funnel = { total = total, vis = vis, est = est, seen = seen, cleared = cleared, cands = #cands }
    return cands
end

local function safe_stand_for(meeting, forward, deep_ok, lane)
    local fp = friendly_fountain_pos()
    if not (fp and meeting) then return nil, false, false end
    local dx, dy = fp.x - meeting.x, fp.y - meeting.y
    local dl = math.sqrt(dx * dx + dy * dy); if dl < 1 then return nil, false, false end

    local back = forward and K.ANTICIP_RANGED_REACH or K.WAVE_STANDBACK
    local g = Farm.CrashCast(meeting, nil, { standback = back, fountain = { x = fp.x, y = fp.y } })

    local stand = Map.Nav.SafeDest(g.stand, { x = dx / dl, y = dy / dl }, tower_safe)
    stand = Map.SnapWalkable(stand, meeting)
    local reach  = (K.MARCH_CAST_RANGE or 300) + (K.MARCH_HALFWIDTH or 900)

    local raid_safe = deep_ok and not lane_unsafe(stand) and enemy_risk_at(stand) < K.SHOVE_SAFE_RISK

    local covers, cwhy = false, nil
    if not tower_safe(stand) then cwhy = "tower"
    elseif not Farm.MarchCovers(stand, meeting, reach) then cwhy = "cover"
    elseif not (deep_ok or stand_depth(stand, lane) <= K.WALK_DEPTH_MAX) then cwhy = "depth"
    elseif not (lane_leash_ok(stand, nil, lane) or raid_safe) then cwhy = "leash"
    else covers = true end
    return stand, covers, (not lane_unsafe(stand)), cwhy
end

local function protected_wait_spot(stand)

    local best, bestd
    for _, e in ipairs(State.world.structures()) do
        if Entity.GetTeamNum(e) == State.team and Entity.IsAlive(e) then
            local p = Entity.GetAbsOrigin(e)
            if p then
                local d = p:Distance(Vector(stand.x, stand.y, p.z))
                if not bestd or d < bestd then best, bestd = p, d end
            end
        end
    end
    if best then
        local dx, dy = stand.x - best.x, stand.y - best.y
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl > 1 then
            return Map.SnapWalkable({ x = best.x + dx / dl * K.WAIT_PROTECT_AHEAD,
                                       y = best.y + dy / dl * K.WAIT_PROTECT_AHEAD },
                                     { x = stand.x, y = stand.y })
        end
        return { x = best.x, y = best.y }
    end
    local fp = friendly_fountain_pos()
    if fp then
        local dx, dy = fp.x - stand.x, fp.y - stand.y
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl > 1 then
            return Map.SnapWalkable({ x = stand.x + dx / dl * K.WAIT_BACKOFF,
                                       y = stand.y + dy / dl * K.WAIT_BACKOFF },
                                     { x = stand.x, y = stand.y })
        end
    end
    return { x = stand.x, y = stand.y }
end

local function idle_wait_spot(stand)
    local anchor = stand
    if not anchor then local m = origin(State.hero); anchor = { x = m.x, y = m.y } end
    if channel_threat_near(anchor) then State.idleProtUntil = now() + K.PROT_CLEAR_S end
    if State.idleProtUntil and now() < State.idleProtUntil then
        return protected_wait_spot(anchor)
    end
    if not stand then return nil end
    local fp = friendly_fountain_pos()
    if not fp then return { x = stand.x, y = stand.y } end
    local wx, wy = Geometry.DiscReachPoint(stand.x, stand.y, K.WAIT_STEP_BACK, fp.x, fp.y)
    return Map.SnapWalkable({ x = wx, y = wy }, { x = stand.x, y = stand.y })
end

local function anchor_candidates(include_creeps)
    local out = {}
    for _, e in ipairs(State.world.structures()) do
        if Entity.GetTeamNum(e) == State.team and Entity.IsAlive(e) then
            local p = Entity.GetAbsOrigin(e)
            if p then out[#out + 1] = { pos = p, r = K.KEEN_LAND_STRUCTURE, name = "bldg" } end
        end
    end
    for _, o in ipairs(MapData.OUTPOSTS or {}) do
        if o.team == State.team and o.pos then
            out[#out + 1] = { pos = Vector(o.pos[1], o.pos[2], o.pos[3]),
                              r = K.KEEN_LAND_OUTPOST, name = o.name or "outpost" }
        end
    end

    if include_creeps then
        State.creepExcl = 0

        local rear, melee = {}, {}
        for _, c in ipairs(State.world.lane_creeps()) do
            if Entity.GetTeamNum(c) == State.team and Entity.IsAlive(c) and not Entity.IsDormant(c)
               and (Entity.GetHealth(c) or 0) >= K.KEEN_CREEP_MIN_HP then
                local p = Entity.GetAbsOrigin(c)

                if p then
                    local spd = 325
                    local scan = State.laneScan and State.laneScan[Lane._assign_lane({ x = p.x, y = p.y })]
                    local aw = scan and scan.ally_wave
                    if aw then
                        local s2 = aw.speed_measured or aw.speed
                        if not s2 then
                            for _, cc in ipairs(aw.creeps or {}) do
                                if cc.speed and (not s2 or cc.speed > s2) then s2 = cc.speed end
                            end
                        end
                        if s2 then spd = math.max(100, s2) end
                    end
                    local r = K.TOWER_RISK_RADIUS + spd * K.KEEN_CREEP_DRIFT_S
                    for _, tw in ipairs(Map.TowersInRadius(Vector(p.x, p.y, 0), r) or {}) do
                        if Entity.GetTeamNum(tw) ~= State.team and Entity.IsAlive(tw) then
                            State.creepExcl = (State.creepExcl or 0) + 1
                            p = nil; break
                        end
                    end
                end
                if p then
                    local nm = (NPC.GetUnitName and NPC.GetUnitName(c)) or ""
                    local a = { pos = p, r = K.KEEN_LAND_STRUCTURE, name = "creep" }
                    if nm:find("ranged", 1, true) or nm:find("siege", 1, true) then
                        rear[#rear + 1] = a
                    else
                        melee[#melee + 1] = a
                    end
                end
            end
        end
        local pick = (#rear > 0) and rear or melee
        for i = 1, #pick do out[#out + 1] = pick[i] end
    end
    return out
end

local function allied_lane_creep_near(x, y, r)
    local r2 = r * r
    for _, c in ipairs(State.world.lane_creeps()) do
        if Entity.GetTeamNum(c) == State.team and Entity.IsAlive(c) and not Entity.IsDormant(c) then
            local p = Entity.GetAbsOrigin(c)
            if p then local dx, dy = p.x - x, p.y - y; if dx * dx + dy * dy <= r2 then return true end end
        end
    end
    return false
end

local function clear_landing(lx, ly, ax, ay, avoid_creeps)
    for i = 0, 6 do
        local f = i / 6
        local x, y = lx + (ax - lx) * f, ly + (ay - ly) * f
        if Map.WalkablePt(x, y)
           and not (avoid_creeps and allied_lane_creep_near(x, y, K.KEEN_CREEP_CLEAR)) then
            local ok, trees = pcall(function() return Map.TreesInRadius(Map.GroundPos(x, y), K.KEEN_TREE_CLEAR) end)
            if (not ok) or (not trees) or #trees == 0 then return { x = x, y = y } end
        end
    end
    return nil
end

local function abil_mana(abil, fb)
    local ok, c = pcall(function() return Ability.GetManaCost and Ability.GetManaCost(abil) end)
    return (ok and type(c) == "number" and c > 0) and c or fb
end

local function keen_to_anchor(stand, include_creeps)
    local anchors = anchor_candidates(include_creeps)
    local me = origin(State.hero)
    local sdepth = stand_depth(stand)

    local kl = (State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0
    local avoid_creeps = (not include_creeps) and kl >= 2

    local rej = { clear = 0, unsafe = 0, tower = 0, overshoot = 0, walklaw = 0 }
    local accept = function(lx, ly, a)
        local cl = clear_landing(lx, ly, a.pos.x, a.pos.y, avoid_creeps)
        if not cl then rej.clear = rej.clear + 1; return false end
        local land = Vector(cl.x, cl.y, 0)

        if lane_unsafe({ x = cl.x, y = cl.y }) then rej.unsafe = rej.unsafe + 1; return false end
        if not tower_safe({ x = cl.x, y = cl.y }) then rej.tower = rej.tower + 1; return false end
        if stand_depth(land) > 0 and stand_depth(land) > sdepth + K.KEEN_DEPTH_MARGIN then rej.overshoot = rej.overshoot + 1; return false end
        if not include_creeps and stand_depth(land) > K.WALK_DEPTH_MAX then rej.walklaw = rej.walklaw + 1; return false end
        a._land = cl
        return true
    end
    local function keen_skip(why, extra)
        logline(string.format("keen_skip why=%s anchors=%d cexcl=%d rej=clear:%d,unsafe:%d,tower:%d,over:%d,walklaw:%d%s",
            why, #anchors, State.creepExcl or 0, rej.clear, rej.unsafe, rej.tower, rej.overshoot, rej.walklaw, extra or ""))
        return false, why
    end

    if channel_threat_near then
        local thr = channel_threat_near({ x = me.x, y = me.y })
        if thr then

            if now() - (State.kSkipDisLogT or 0) > 2 then
                State.kSkipDisLogT = now()
                return keen_skip("disabler", " threat=" .. thr)
            end
            return false, "disabler"
        end
    end

    do
        local kc = abil_mana(State.keen, K.KEEN_MANA_FB)
        local mc = abil_mana(State.march, K.MARCH_MANA_FB)

        local rlv = (State.rearm and Ability.GetLevel and Ability.GetLevel(State.rearm)) or 0
        local chain
        if not include_creeps and rlv < 1 then
            chain = mc
        else
            local rc = abil_mana(State.rearm, K.REARM_MANA_FB)
            local reserve = K.ESCAPE_MANA
            chain = ready(State.march) and mc or math.max(reserve + rc, rc + mc)
        end
        local short = chain - (mana() - kc)
        if short > 0 then
            local bt = NPC.GetItem(State.hero, "item_bottle", true)
            local ch = (bt and Ability.CanBeExecuted(bt) == -1 and Item.GetCurrentCharges
                        and Item.GetCurrentCharges(bt)) or 0
            if ch * K.BOTTLE_MANA_PER_CHARGE >= short then
                State.keenNoFundT, State.keenNoFundGap = now(), short
                logline(string.format("keen_defer why=mana%s raw=%.0f chain=%.0f short=%.0f ch=%d",
                    include_creeps and " raid=y" or "", mana(), chain, short, ch))
                return false, "mana_defer"
            elseif include_creeps then
                return false, "raid_broke"
            end
        end
    end
    local best = Geometry.BestReachLanding(anchors, { x = stand.x, y = stand.y }, { accept = accept })
    if not best then return keen_skip("no_landing") end
    local cl = best.anchor._land or { x = best.lx, y = best.ly }
    local resid = math.sqrt((cl.x - stand.x) ^ 2 + (cl.y - stand.y) ^ 2)

    if include_creeps and best.anchor.name ~= "creep" and resid > K.RAID_RESID_MAX then
        return keen_skip("raid_far", string.format(" resid=%.0f", resid))
    end

    if me:Distance(Vector(stand.x, stand.y, me.z)) - resid < K.KEEN_GAIN_MIN then
        return keen_skip("gain", string.format(" d=%.0f resid=%.0f", me:Distance(Vector(stand.x, stand.y, me.z)), resid))
    end
    local finalPos = Vector(cl.x, cl.y, stand.z or me.z)
    if cast_pos(State.keen, finalPos) then
        State.channelUntil = now() + K.KEEN_CHANNEL + K.CHANNEL_PAD

        State.keenPending = { land = finalPos, origin = { x = me.x, y = me.y },
                              due = now() + K.KEEN_CHANNEL + K.CHANNEL_PAD + 0.3 }
        verify_cast("keen", State.keen)
        if not State.anchorsLogged then
            State.anchorsLogged = true
            local nb, no = 0, 0
            for _, a in ipairs(anchors) do if a.name == "bldg" then nb = nb + 1 else no = no + 1 end end
            logline(string.format("anchors buildings=%d outposts=%d", nb, no))
        end

        logline(string.format("keen_to_anchor anchor=%s target=(%.0f,%.0f) land=(%.0f,%.0f) residual=%.0f cexcl=%d jump=%.0f mana=%.0f",
            best.anchor.name, stand.x, stand.y, cl.x, cl.y, resid,
            State.creepExcl or 0, me:Distance(finalPos), mana()))

        do
            local sp = State.spot
            State.keenInvest = { t = now(), resid = resid,
                                 lane = sp and sp.lane, kind = sp and sp.kind,
                                 asrc = sp and sp.waveAsrc }
        end
        return true
    end

    return keen_skip("cast_failed")
end

local function raid_hop_ok(target)
    if not target then return false end
    for _, a in ipairs(anchor_candidates(true)) do
        local d = math.sqrt((a.pos.x - target.x) ^ 2 + (a.pos.y - target.y) ^ 2)
        if a.name == "creep" then
            if d <= K.RAID_HOP_CREEP_MAX then return true end
        elseif d <= K.RAID_RESID_MAX + K.WAVE_STANDBACK then return true end
    end
    return false
end

local function pair_spot_for(cand)
    State.pairSkip = nil
    local A = cand.center
    if not A then State.pairSkip = "no_center"; return nil end

    local pair_max = math.min(K.PAIR_RADIUS, K.MARCH_LEN - 2 * math.abs(K.MARCH_PAIR_OFFSET))
    local partner, pd = nil, math.huge
    for _, cd in ipairs(State.world.camps()) do
        if cd.camp ~= cand.camp and cd.center then
            local d = A:Distance(cd.center)
            if d > 200 and (d <= pair_max or forced_pair(A, cd.center))
               and is_pair_selected(A, cd.center)
               and not is_cleared(Map.CampKey(cd.center)) and d < pd then
                partner, pd = cd, d
            end
        end
    end
    if not partner then State.pairSkip = "no_partner"; return nil end
    local B = partner.center
    local pc = Farm.PairClearClass(pd, { march_len = K.MARCH_LEN, disc = K.CREEP_DISC })

    local mid = Vector((A.x + B.x) / 2, (A.y + B.y) / 2, A.z)
    if enemy_risk_at(mid) >= K.RISK_HARD then
        State.pairSkip = string.format("risk pd=%.0f pcamp=(%.0f,%.0f)", pd, B.x, B.y); return nil
    end
    return { stand = mid, aim = mid, paired = true, partner = B,
             partnerCamp = partner.camp, partnerType = partner.type, clear = pc.class, pd = pd }
end

local function best_stand_spot(cand)
    local center = cand.center
    local best = nil
    for _, ring in ipairs({ K.STAND_RING, K.STAND_RING + 50, K.STAND_RING - 60 }) do
        for ang = 0, 360 - K.STAND_STEP, K.STAND_STEP do
            local rad = math.rad(ang)
            local s = Vector(center.x + ring * math.cos(rad),
                             center.y + ring * math.sin(rad), center.z)
            if Map.Walkable(s) then
                local score = -enemy_risk_at(s) * 5
                if not best or score > best.score then
                    best = { stand = s, aim = center, score = score }
                end
            end
        end
    end
    return best
end

local function march_cast_point_multi(s)
    local ss = s.standSpot
    local me = origin(State.hero)
    local aim = ss.aim or s.center

    local ux, uy
    if ss.paired and ss.partner then
        ux, uy = ss.partner.x - aim.x, ss.partner.y - aim.y
    else
        ux, uy = aim.x - me.x, aim.y - me.y
    end
    local ul = math.sqrt(ux * ux + uy * uy)
    if ul < 1 then ux, uy = 1, 0 else ux, uy = ux / ul, uy / ul end

    local okc, creeps = pcall(function()
        local neutrals = State.world.neutrals()
        local out, seen = {}, {}
        local function add_camp(camp)
            if not camp or seen[camp] then return end
            seen[camp] = true
            for _, c in ipairs(Map.CampCreeps(camp, neutrals) or {}) do
                local p = origin(c)
                if p then
                    out[#out + 1] = {
                        pos = { x = p.x, y = p.y },
                        hp = (Entity.GetHealth and Entity.GetHealth(c)) or 0,
                    }
                end
            end
        end
        add_camp(s.camp)
        if ss.paired and ss.partnerCamp then add_camp(ss.partnerCamp) end
        return out
    end)
    if okc and creeps and #creeps > 0 then
        local marchReach = K.MARCH_LEN + (K.MARCH_CAST_RANGE or 300) - 20
        local bestAim = Farm.BestLineAim(
            { x = me.x, y = me.y, z = me.z }, creeps, marchReach, K.MARCH_HALFWIDTH)
        if bestAim then
            ux, uy = bestAim.x - me.x, bestAim.y - me.y
            local bestLen = math.sqrt(ux * ux + uy * uy)
            if bestLen > 1 then ux, uy = ux / bestLen, uy / bestLen end
        end
    end

    local target = Vector(me.x + ux * K.MULTI_W_OFFSET, me.y + uy * K.MULTI_W_OFFSET, aim.z)
    local maxr = (K.MARCH_CAST_RANGE or 300) - 20
    if me:Distance(target) > maxr then return me + (target - me):Normalized() * maxr end
    return target
end

local function keen_allowed_kinds()
    local lvl = (State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0
    local kinds = { "building", "outpost" }
    if lvl >= 2 then kinds[#kinds + 1] = "creep" end
    if lvl >= 3 then kinds[#kinds + 1] = "ally" end
    return kinds
end

local function static_anchors()
    if State.staticAnchors and State.staticAnchorsSerial == State.updateSerial then
        return State.staticAnchors
    end
    local out = {}
    for _, e in ipairs(State.world.structures()) do
        if Entity.GetTeamNum(e) == State.team and Entity.IsAlive(e) then
            local p = Entity.GetAbsOrigin(e)
            if p then out[#out + 1] = { pos = { x = p.x, y = p.y }, ready = true, kind = "building" } end
        end
    end
    for _, o in ipairs(MapData.OUTPOSTS or {}) do
        if o.team == State.team and o.pos then
            out[#out + 1] = { pos = { x = o.pos[1], y = o.pos[2] }, ready = true, kind = "outpost" }
        end
    end
    State.staticAnchors, State.staticAnchorsSerial = out, State.updateSerial
    return out
end
local function recover_round_trip(target, fallback)
    local me = origin(State.hero)
    local fp = friendly_fountain_pos()
    if not (me and fp and target) then
        return refill_wait() + 2 * K.KEEN_CHANNEL + (fallback or 0)
    end

    local ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
    local dx, dy = me.x - fp.x, me.y - fp.y
    local home_dist = math.sqrt(dx * dx + dy * dy)
    local home_eta
    if home_dist <= K.FOUNTAIN_WALK_IN then
        home_eta = home_dist / math.max(150, ms)
    elseif ready(State.keen) then
        home_eta = K.KEEN_CHANNEL
    elseif ready(State.rearm)
       and ((State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0) >= 1 then
        home_eta = rearm_channel() + K.KEEN_CHANNEL
    else
        home_eta = home_dist / math.max(150, ms)
    end

    local keen_level = (State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0
    local tp = { channel = keen_level >= 1 and K.KEEN_CHANNEL or 1e9 }
    local back = Lane.InterceptETA(
        { x = fp.x, y = fp.y }, static_anchors(), ms, tp, target, nil)
    return home_eta + refill_wait() + back.eta
end

local function lane_push_dirs()
    local ours, theirs
    for _, f in ipairs(MapData.FOUNTAINS or {}) do
        if f.team == State.team then ours = f.pos else theirs = f.pos end
    end
    if not (ours and theirs) then return { x = 1, y = 1 }, { x = -1, y = -1 } end
    local ally_push  = { x = theirs[1] - ours[1], y = theirs[2] - ours[2] }
    local enemy_push = { x = ours[1] - theirs[1], y = ours[2] - theirs[2] }
    return enemy_push, ally_push
end

local function lane_paths()
    State.lanePaths = State.lanePaths or Lane.BuildLanePaths(MapData.TOWERS, MapData.SPAWNS)
    return State.lanePaths
end

local function annotate_measured(lanes)
    if not lanes then return lanes end
    for _, ln in ipairs({ "top", "mid", "bot" }) do
        local s = lanes[ln]
        if s then
            for side, w in pairs({ enemy = s.enemy_wave, ally = s.ally_wave }) do
                if w and w.front and not w.estimated then
                    local spd
                    State.frontTrack, spd = Lane.TrackFrontSpeed(State.frontTrack, ln .. ":" .. side, w.front, now())
                    if spd then
                        local stat = w.speed
                        if not stat then
                            for _, cc in ipairs(w.creeps or {}) do if cc.speed and (not stat or cc.speed > stat) then stat = cc.speed end end
                        end
                        w.speed_measured = math.min(spd, stat or 325)
                    end
                end
            end
        end
    end
    return lanes
end

local function run_lane_scan()
    local enemy_push, ally_push = lane_push_dirs()
    local me = origin(State.hero)
    local lanes = Lane.ScanLanes({
        team = State.team, enemy_push = enemy_push, ally_push = ally_push,
        anchors = static_anchors(), allowed_kinds = keen_allowed_kinds(),
        hero_pos = { x = me.x, y = me.y },
        move_speed = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320,
        tp = keen_tp(),
        game_time = now(),
        paths = lane_paths(),
    })
    annotate_measured(lanes)
    State.laneScan = lanes
    State.laneScanSerial = State.updateSerial

    do
        local samples = {}
        local towers = State.world.towers()
        for _, t in ipairs(MapData.TOWERS or {}) do
            if t.pos and t.name and t.team then
                local key = t.name .. "@" .. tostring(t.team)
                local ent
                local r2 = K.TOWER_ALIVE_R * K.TOWER_ALIVE_R
                for _, e in ipairs(towers) do
                    if Entity.GetTeamNum(e) == t.team and Entity.IsAlive(e) then
                        local p = Entity.GetAbsOrigin(e)
                        if p then
                            local dx, dy = p.x - t.pos[1], p.y - t.pos[2]
                            if dx * dx + dy * dy <= r2 then ent = e; break end
                        end
                    end
                end
                if ent then
                    samples[#samples + 1] = { key = key, hp = Entity.GetHealth(ent), alive = true }
                elseif Map.Towers.Alive(State.towerTrack, key) then
                    samples[#samples + 1] = { key = key, alive = false }
                end
            end
        end
        State.towerTrack = Map.Towers.Track(State.towerTrack, samples, now())
    end

    local pred = Lane.Schedule.NextWaveArrival(now(), K.WAVE_PERIOD, K.WAVE_PHASE, State.laneWaveT.mid)

    local kpred = -1
    do
        local s = lanes.mid
        local ew, aw = s.enemy_wave, s.ally_wave
        local espd, aspd = Lane.WaveSpeed(ew), Lane.WaveSpeed(aw)
        if ew and ew.front and aw and aw.front and espd and aspd then
            local pm = Lane.PredictMeeting({ pos = ew.front, speed = espd }, { pos = aw.front, speed = aspd })
            if pm then kpred = now() + pm.eta end
        end
    end
    logline(string.format("wavescan SCAN t=%.1f wave=%d pred=%.1f kpred=%.1f lastw=%s",
        now(), math.floor(now() / 30) + 1, pred or -1, kpred,
        State.laneWaveT.mid and string.format("%.1f", State.laneWaveT.mid) or "-"))
    local function pt(p) return p and string.format("%.0f;%.0f", p.x, p.y) or "-" end
    for _, ln in ipairs({ "top", "mid", "bot" }) do
        local s = lanes[ln]
        local ew, aw = s.enemy_wave, s.ally_wave

        if ew and not ew.estimated and (ew.count or 0) > 0
           and (ew.count or 0) <= K.SHOVE_THIN_CREEPS then
            State.loneSince[ln] = State.loneSince[ln] or now()
        else
            State.loneSince[ln] = nil
        end
        local comp = (ew and ew.estimated)
            and string.format("m%dr%ds%df%d", ew.melee or 0, ew.ranged or 0, ew.siege or 0, ew.flagbearer or 0)
            or "-"
        local push = s.clash and (s.clash.pushing .. (s.clash.moving and "" or "/hold")) or "none"
        local crash = "-"

        if s.clash and s.clash.crashing and s.clash.crash_tower and not s.clash.estimated then
            crash = (s.clash.crash_tower.team == State.team) and "allyTwr" or "enemyTwr"

            if crash == "allyTwr" then
                State.crashSeen = State.crashSeen or {}
                State.crashSeen[ln] = now()
            end
        end

        if ln == K.HOME_LANE and K.TOWER_THREAT_R > 0 and ew and not ew.estimated and ew.front
           and (ew.count or 0) >= K.TOWER_THREAT_MINC
           and (ew.hp or 0) >= K.SHOVE_THIN_EFFHP
           and not (s.clash and s.clash.pushing == "ally") then
            for _, t in ipairs(MapData.TOWERS or {}) do
                if t.team == State.team and t.pos and t.name and t.name:find("_" .. ln, 1, true) then
                    local dx, dy = t.pos[1] - ew.front.x, t.pos[2] - ew.front.y
                    if dx * dx + dy * dy <= K.TOWER_THREAT_R * K.TOWER_THREAT_R then

                        local allyNear = false
                        for _, hh in ipairs(State.world.heroes()) do
                            if hh ~= State.hero and Entity.IsAlive(hh)
                               and Entity.GetTeamNum(hh) == State.team
                               and (not NPC.IsIllusion or not NPC.IsIllusion(hh)) then
                                local hp2 = (not Entity.IsDormant(hh)) and Entity.GetAbsOrigin(hh)
                                            or (Hero.GetLastMaphackPos and Hero.GetLastMaphackPos(hh))
                                if hp2 then
                                    local ax, ay = hp2.x - t.pos[1], hp2.y - t.pos[2]
                                    if ax * ax + ay * ay <= K.TOWER_THREAT_R * K.TOWER_THREAT_R then
                                        allyNear = true; break
                                    end
                                end
                            end
                        end
                        local live = not allyNear
                        if not allyNear then
                            live = false
                            for _, te in ipairs(Map.TowersInRadius(Vector(t.pos[1], t.pos[2], 0), K.TOWER_ALIVE_R) or {}) do
                                if Entity.GetTeamNum(te) == State.team and Entity.IsAlive(te) then live = true; break end
                            end
                        end
                        if live then
                            State.crashSeen = State.crashSeen or {}
                            State.crashSeen[ln] = now()

                            do

                                local oldg = (s.ally_heroes or 0) == 0
                                logline(string.format(
                                    "tower_threat ln=%s e=%d hp=%d d=%.0f twr=%s modelcrash=%s alH=%d oldgate=%s differ=%d",
                                    ln, ew.count or 0, math.floor(ew.hp or 0),
                                    math.sqrt(dx * dx + dy * dy), t.name, crash,
                                    s.ally_heroes or -1, tostring(oldg), oldg and 0 or 1))
                            end
                            break
                        end
                    end
                end
            end
        end

        local bal, peta = "-", "-"

        State.fightSeen = State.fightSeen or {}
        State.fightSeen[ln] = nil
        if ew and aw then
            local pf = Lane.PushForecast(aw, ew, { cycle = math.min(30, math.floor(now() / 450)),
                                                   game_time = now(), rounds = 1 })
            bal  = string.format("%d", pf.bal or 0)
            peta = string.format("%.1f", now() + (pf.first_t or 0))

            if not ew.estimated and ew.front and aw.front
               and (ew.front.x - aw.front.x) ^ 2 + (ew.front.y - aw.front.y) ^ 2
                   <= K.FIGHT_CONTACT_R * K.FIGHT_CONTACT_R
               and (pf.first_t or 0) > K.W_LEAD_S then
                State.fightSeen[ln] = now()
            end
        end

        local ctp, ctd, ctr = "-", "-", "-"
        local ct = s.clash and s.clash.crash_tower
        if ct and ct.pos then
            ctp = pt(ct.pos)
            ctr = string.format("%.0f", ct.range or 0)
            local cpt = s.clash.contact
            if cpt then
                local dx, dy = ct.pos.x - cpt.x, ct.pos.y - cpt.y
                ctd = string.format("%.0f", math.sqrt(dx * dx + dy * dy))
            end
        end
        logline(string.format(
            "wavescan ln=%s e=%d est=%s src=%s comp=%s a=%d hp=%d gold=%d push=%s crash=%s ctp=%s ctd=%s ctr=%s bal=%s peta=%s eta=%s reach=%s enH=%d alH=%d ef=%s af=%s meet=%s",
            ln, ew and ew.count or 0, (ew and ew.estimated) and "y" or "n",
            (ew and ew.est_src) or "-", comp,
            aw and aw.count or 0, math.floor((ew and ew.hp) or 0), math.floor(s.gold or 0), push, crash, ctp, ctd, ctr, bal, peta,
            s.intercept and string.format("%.1f", s.intercept.eta) or "-",
            tostring(s.intercept and s.intercept.reachable), s.enemy_heroes, s.ally_heroes,
            pt(ew and ew.front), pt(aw and aw.front), pt(s.meeting)))
    end
end

local function hop_mana_cost(full_clear)
    local c = abil_mana(State.keen, K.KEEN_MANA_FB) + abil_mana(State.march, K.MARCH_MANA_FB)

    if (State.march and not ready(State.march)) or (State.keen and not ready(State.keen)) then
        c = c + abil_mana(State.rearm, K.REARM_MANA_FB)
    end

    local rlvl = (Ability.GetLevel and State.rearm and Ability.GetLevel(State.rearm)) or 0
    if full_clear and rlvl >= 1 then

        if State.eraT ~= now() then

            local _, t1alive = enemy_lane_t1(K.HOME_LANE)
            State.eraT, State.eraLane = now(), (t1alive == true)
        end
        if State.eraLane then
            local mcost = abil_mana(State.march, K.MARCH_MANA_FB)
            local rcost = abil_mana(State.rearm, K.REARM_MANA_FB)

            local rearms = 1 + ((((State.march and not ready(State.march))
                                  or (State.keen and not ready(State.keen))) and 1) or 0)
            local full = abil_mana(State.keen, K.KEEN_MANA_FB) + 2 * mcost + rearms * rcost

            local mmax = (NPC.GetMaxMana and NPC.GetMaxMana(State.hero)) or 0
            if mmax >= full + K.SHOVE_MANA_RESERVE and full > c then c = full end
        end
    end
    return c
end
local function mana_regen_read()
    local ok, v = pcall(function() return NPC.GetManaRegen and NPC.GetManaRegen(State.hero) end)
    return (ok and type(v) == "number" and v > 0) and v or K.MANA_REGEN_FALLBACK
end
local function hp_regen_read()
    local ok, v = pcall(function() return NPC.GetHealthRegen and NPC.GetHealthRegen(State.hero) end)
    return (ok and type(v) == "number" and v > 0) and v or K.HP_REGEN_FALLBACK
end

local function route_hero_state()
    local me = origin(State.hero)
    local h  = State.hero
    return {
        pos = { x = me.x, y = me.y },
        move_speed = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320,
        tp = keen_tp(),
        anchors = static_anchors(),

        mana = effective_mana(),
        max_mana = (NPC.GetMaxMana(h) or 1) + math.max(0, effective_mana() - mana()),
        hp = Entity.GetHealth(h) or 1, max_hp = Entity.GetMaxHealth(h) or 1,
        mana_regen = mana_regen_read(), hp_regen = hp_regen_read(),
        reserve_mana = abil_mana(State.keen, K.KEEN_MANA_FB),
        hp_floor = (Entity.GetMaxHealth(h) or 1) * K.HP_FLOOR_FRAC,
    }
end

local function route_opts()
    return { now = now(), horizon_s = K.ROUTE_HORIZON_S, max_steps = K.ROUTE_MAX_STEPS,
             risk_weight = K.ROUTE_RISK_WEIGHT, risk_hard = K.RISK_HARD, refill_frac = K.REFILL_FRAC,
             pool_cap = K.ROUTE_POOL_CAP,
             step_decay = K.ROUTE_STEP_DECAY,
             max_leg_s = K.MAX_CAMP_TRAVEL_S }
end

local function our_farm_priority()
    local peers = State.world.heroes()
    local v = HeroValue.of(State.hero, peers)
    return HeroValue.FarmPriority({ role = nil, value = v })
end

local function pos_probe()
    if State.posProbed then return end
    State.posProbed = true
    local ok, err = pcall(function()
        for _, p in ipairs((Players and Players.GetAll and Players.GetAll()) or {}) do
            local h  = Player.GetAssignedHero and Player.GetAssignedHero(p)
            local nm = h and NPC.GetUnitName and NPC.GetUnitName(h) or "-"
            local tp = Player.GetTeamPlayer and Player.GetTeamPlayer(p)
            logline(string.format("apos_probe hero=%s team=%s sp=%s lh=%s nw=%s",
                tostring(nm),
                tostring(h and Entity.GetTeamNum and Entity.GetTeamNum(h) or "-"),
                tostring(tp and tp.starting_position or "nil"),
                tostring(tp and tp.lasthit_count or "nil"),
                tostring(tp and tp.networth or "nil")))

            local sp = tonumber(tp and tp.starting_position)
            if nm ~= "-" and sp and sp >= 1 and sp <= 5 then
                State.posEngine = State.posEngine or {}
                State.posEngine[nm] = sp
            end
        end
    end)
    if not ok then logline("apos_probe FAILED err=" .. tostring(err)) end
end

local function pos_commit(src, bits)
    State.posFinal = State.posFinal or {}
    local parts = {}
    for n, v in pairs(bits) do
        if State.posFinal[n] == nil then
            State.posFinal[n] = v
            parts[#parts + 1] = n .. "=" .. tostring(v)
        end
    end
    if #parts == 0 then return end
    table.sort(parts)
    logline(string.format("pos_commit src=%s n=%d %s", src, #parts, table.concat(parts, " ")))
end

local function ally_farm_priorities()
    local out, peers = {}, State.world.heroes()
    for _, e in ipairs(peers) do
        if e ~= State.hero and Entity.GetTeamNum(e) == State.team and Entity.IsAlive(e) then
            local p = (not Entity.IsDormant(e)) and origin(e) or Hero.GetLastMaphackPos(e)
            if p then
                local name = (NPC.GetUnitName and NPC.GetUnitName(e)) or nil

                local pc = State.posFinal and State.posFinal[name]
                if pc == nil then pc = HeroValue.IsCore(e, name, K.CONTEST_CORE_BASE) end
                out[#out + 1] = {
                    pos = p,
                    value = HeroValue.FarmPriority({ role = HeroValue.role(e), value = HeroValue.of(e, peers) }),

                    core = pc or ((State.allyFarmers[name] or 0) >= K.FARMER_CORE_MARKS),
                }
                out[#out].name = name

                if name and now() >= 60 and now() <= 300 then
                    State.posLaneTally = State.posLaneTally or {}
                    local h = State.posLaneTally[name] or { top = 0, mid = 0, bot = 0, n = 0 }
                    local ln = Lane._assign_lane({ x = p.x, y = p.y }, { mid_band = 2500 })
                    if h[ln] then h[ln] = h[ln] + 1; h.n = h.n + 1 end
                    State.posLaneTally[name] = h
                end
            end
        end
    end

    if State.posT and now() < State.posT - 30 then
        State.posFinal, State.posLogged = nil, nil
        State.posEngine, State.posLaneTally, State.posProbed = nil, nil, nil

        State.crashSeen = nil
        State.rearmNoFundT, State.rearmNoFundGap, State.rearmNoFundLogT = nil, nil, nil
        State.keenNoFundT, State.keenNoFundGap = nil, nil
        State.fightSeen = nil
        logline("pos_reset new_match")
    end
    State.posT = now()
    local stage = ((not State.posLogged) and now() >= 30) and 1
                  or ((State.posLogged == 1 and now() >= 300) and 2 or nil)
    if stage then
        local names = {}
        for _, a in ipairs(out) do if a.name then names[#names + 1] = a.name end end
        if #names >= 4 or now() >= 180 then
            State.posLogged = stage
            if stage == 1 then pos_probe() end

            if stage == 1 and State.posEngine then
                local bits, n = {}, 0
                for _, nm in ipairs(names) do
                    local sp = State.posEngine[nm]
                    if sp then bits[nm] = (sp <= 3); n = n + 1 end
                end
                if n >= #names then pos_commit("engine", bits) end
            end
            local resid = Map.Positions.Shadow(names)
            if stage == 2 then

                for _, nm in ipairs(names) do
                    local h = (State.posLaneTally or {})[nm]
                    local ln, share = Map.Positions.ObservedLane(h)
                    logline(string.format("pos_lane name=%s top=%d mid=%d bot=%d n=%d obs=%s share=%.2f",
                        nm, (h and h.top) or 0, (h and h.mid) or 0, (h and h.bot) or 0,
                        (h and h.n) or 0, tostring(ln), share or 0))
                    if ln and resid[nm] then
                        local slots = Map.Positions.LaneSlots(ln, State.team)
                        for v in pairs(resid[nm]) do if not slots[v] then resid[nm][v] = nil end end
                    end
                end
            end
            local commitBits = {}
            for _, a in ipairs(out) do
                if a.name then
                    local raw, rs = Map.Positions.Of(a.name), {}
                    for v in pairs(resid[a.name] or {}) do rs[#rs + 1] = v end
                    table.sort(rs)

                    local hasC, hasS = false, false
                    for _, v in ipairs(rs) do if v <= 3 then hasC = true else hasS = true end end
                    local bit
                    if #rs == 0 then bit = nil
                    elseif hasC and not hasS then bit = true
                    elseif hasS and not hasC then bit = false
                    else bit = nil end

                    local pol
                    if bit ~= nil then pol = bit
                    elseif #rs > 0 then pol = true
                    else pol = nil end
                    logline(string.format(
                        "pos_shadow stage=%d name=%s set=%s resid=%s bit=%s pol=%s today=%s differ=%d n=%d",
                        stage, a.name, table.concat(raw, "/"), (#rs > 0) and table.concat(rs, "/") or "-",
                        tostring(bit), tostring(pol), tostring(a.core and true or false),
                        ((pol and true or false) ~= (a.core and true or false)) and 1 or 0, #names))

                    if stage == 1 then
                        if bit ~= nil then commitBits[a.name] = bit end
                    elseif pol ~= nil then
                        commitBits[a.name] = pol
                    end
                end
            end
            pos_commit(stage == 1 and "draft" or "observed", commitBits)
        end
    end
    return out
end

local function gather_route_targets(allies, our_pri)
    local out = {}
    local ropts = risk_opts()
    local camp_cands = gather_candidates()

    local function eff_gold(c) return c.gold or 0 end
    local function marches_life(tier, ehp, gold) return clear_marches(tier, ehp, camp_stacks(gold, tier)) end

    local function clear_time(marches)

        return marches * K.MARCH_CAST_DUR + math.max(0, marches - 1) * rearm_channel() + K.ROBOT_TAIL
    end
    local function mana_for(marches)

        marches = math.max(2, marches or 0)
        local keen_level = (State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0
        local march_level = (State.march and Ability.GetLevel and Ability.GetLevel(State.march)) or 0
        local needs_initial_rearm = ready(State.rearm)
            and ((keen_level > 0 and not ready(State.keen))
                 or (march_level > 0 and not ready(State.march)))
        local initial_rearm = needs_initial_rearm and abil_mana(State.rearm, K.REARM_MANA_FB) or 0
        return abil_mana(State.keen, K.KEEN_MANA_FB) + initial_rearm
               + marches * abil_mana(State.march, K.MARCH_MANA_FB)
               + math.max(0, marches - 1) * abil_mana(State.rearm, K.REARM_MANA_FB)
    end
    local function emit_single(c)
        local marches = marches_life(c.type, c.ehp, c.gold)
        local sr = Farm.StructuralRisk({ x = c.center.x, y = c.center.y }, ropts)
        local crisk = math.min(1, enemy_risk_at(c.center) + sr)
        local crisk_sh = math.min(1, enemy_risk_at(c.center, nil, true) + sr)
        out[#out + 1] = {
            kind = "camp", lane = "jungle", pos = { x = c.center.x, y = c.center.y },
            value = eff_gold(c), clear_t = clear_time(marches), risk = crisk, risk_sh = crisk_sh,
            contested = Farm.IsContestedByAlly(c.center, allies, { radius = K.CONTEST_RADIUS, min_value = our_pri }),
            ref = c, mana_cost = mana_for(marches), hp_cost = crisk * K.HP_RISK_DMG,
        }
    end

    local pair_max = math.min(K.PAIR_RADIUS, K.MARCH_LEN - 2 * math.abs(K.MARCH_PAIR_OFFSET))
    local groups, paired = {}, {}
    for i, a in ipairs(camp_cands) do
        if not paired[i] then
            for j = i + 1, #camp_cands do
                local b = camp_cands[j]
                if not paired[j] and State.outpostAncientPair(a, b) then
                    local dx, dy = a.center.x - b.center.x, a.center.y - b.center.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    groups[#groups + 1] = { a = i, b = j, d = distance }
                    paired[i], paired[j] = true, true
                    break
                end
            end
        end
    end
    for i, a in ipairs(camp_cands) do
        if not paired[i] then
            for j = i + 1, #camp_cands do
                local b = camp_cands[j]
                local dx, dy = a.center.x - b.center.x, a.center.y - b.center.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if not paired[j] and is_pair_selected(a.center, b.center)
                    and (distance <= pair_max or forced_pair(a.center, b.center)) then
                    groups[#groups + 1] = { a = i, b = j, d = distance }
                    paired[i], paired[j] = true, true
                    break
                end
            end
        end
    end
    for _, g in ipairs(groups) do
        local a = camp_cands[g.a]
        local b = g.b and camp_cands[g.b] or nil
        local midv = b and Vector((a.center.x + b.center.x) / 2, (a.center.y + b.center.y) / 2, a.center.z) or nil
        local er = midv and enemy_risk_at(midv) or 1
        local er_sh = midv and enemy_risk_at(midv, nil, true) or 1

        if b and er < K.RISK_HARD then
            local mid = { x = midv.x, y = midv.y }
            local marches = math.max(marches_life(a.type, a.ehp, a.gold), marches_life(b.type, b.ehp, b.gold))
            local sr = Farm.StructuralRisk(mid, ropts)
            local crisk = math.min(1, er + sr)
            local crisk_sh = math.min(1, er_sh + sr)
            local pc = Farm.PairClearClass(g.d, { march_len = K.MARCH_LEN, disc = K.CREEP_DISC })
            local preferred = forced_pair(a.center, b.center)
            out[#out + 1] = {
                kind = "camp", lane = "jungle", pos = mid,
                preferredPair = preferred,
                outpostAncient = State.outpostAncientPair(a, b),
                outpostTeam = State.outpostAncientPairTeam(a, b),
                value = eff_gold(a) + eff_gold(b) + (preferred and K.PREFERRED_PAIR_BONUS or 0),
                clear_t = clear_time(marches), risk = crisk, risk_sh = crisk_sh,
                contested = Farm.IsContestedByAlly(mid, allies, { radius = K.CONTEST_RADIUS, min_value = our_pri }),
                ref = a, partnerRef = b, pairClass = pc.class, pairPd = g.d,
                mana_cost = mana_for(marches), hp_cost = crisk * K.HP_RISK_DMG,
            }
        elseif b then

        end
    end

    do
        local specialTarget
        for _, target in ipairs(out) do
            if target.outpostAncient and target.outpostTeam == State.team then
                specialTarget = target
                break
            end
        end
        if not specialTarget then
            for _, pair in ipairs(K.FORCE_PAIRS or {}) do
                local p1 = { x = pair[1][1], y = pair[1][2] }
                local p2 = { x = pair[2][1], y = pair[2][2] }
                local mx, my = (p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5
                local pairTeam, nearest
                for _, outpost in ipairs(MapData.OUTPOSTS or {}) do
                    if outpost.pos then
                        local dx, dy = mx - outpost.pos[1], my - outpost.pos[2]
                        local d2 = dx * dx + dy * dy
                        if not nearest or d2 < nearest then
                            pairTeam, nearest = outpost.team, d2
                        end
                    end
                end
                if pairTeam == State.team then
                    local key1, key2 = Map.CampKey(p1), Map.CampKey(p2)
                    local a, b
                    for _, cand in ipairs(camp_cands) do
                        if cand.key == key1 then a = cand
                        elseif cand.key == key2 then b = cand end
                    end
                    if a or b then
                        for _, desc in ipairs(State.world.camps()) do
                            local key = Map.CampKey(desc.center)
                            if key == key1 and not a then
                                a = { camp = desc.camp, center = desc.center, type = desc.type,
                                      creeps = {}, gold = 0, ehp = 0, key = key1 }
                            elseif key == key2 and not b then
                                b = { camp = desc.camp, center = desc.center, type = desc.type,
                                      creeps = {}, gold = 0, ehp = 0, key = key2 }
                            end
                        end
                    end
                    if a and b and (a.type == 3 or b.type == 3) then
                        local active = ((a.gold or 0) + (a.ehp or 0) >=
                            (b.gold or 0) + (b.ehp or 0)) and a or b
                        local mid = { x = (a.center.x + b.center.x) * 0.5,
                                      y = (a.center.y + b.center.y) * 0.5 }
                        local er = enemy_risk_at(mid)
                        if er < K.RISK_HARD then
                            local marches = marches_life(active.type, active.ehp, active.gold)
                            local sr = Farm.StructuralRisk(mid, ropts)
                            local crisk = math.min(1, er + sr)
                            local dx, dy = a.center.x - b.center.x, a.center.y - b.center.y
                            local distance = math.sqrt(dx * dx + dy * dy)
                            local pc = Farm.PairClearClass(distance,
                                { march_len = K.MARCH_LEN, disc = K.CREEP_DISC })
                            out[#out + 1] = {
                                kind = "camp", lane = "jungle", pos = mid,
                                preferredPair = true, outpostAncient = true,
                                outpostTeam = pairTeam,
                                value = eff_gold(a) + eff_gold(b) + K.PREFERRED_PAIR_BONUS,
                                clear_t = clear_time(marches), risk = crisk,
                                contested = Farm.IsContestedByAlly(mid, allies,
                                    { radius = K.CONTEST_RADIUS, min_value = our_pri }),
                                ref = a, partnerRef = b, pairClass = pc.class, pairPd = distance,
                                mana_cost = mana_for(marches), hp_cost = crisk * K.HP_RISK_DMG,
                            }
                        end
                    end
                end
            end
        end
    end

    local fpos = friendly_fountain_pos()
    if fpos then
        out[#out + 1] = { kind = "refill", lane = "base", pos = { x = fpos.x, y = fpos.y },
                          value = 0, clear_t = refill_wait(), risk = 0, restore = true }
    end
    return out
end

local function enemy_lane_creeps_near(pos, radius)
    local out, r2 = {}, radius * radius
    for _, n in ipairs(State.world.lane_creeps()) do
        if Entity.GetTeamNum(n) ~= State.team and Entity.IsAlive(n) and not Entity.IsDormant(n)
           and not (NPC.IsWaitingToSpawn and NPC.IsWaitingToSpawn(n)) then
            local p = Entity.GetAbsOrigin(n)
            local name = (NPC.GetUnitName and NPC.GetUnitName(n)) or ""
            if p and not name:find("siege", 1, true) then
                local dx, dy = p.x - pos.x, p.y - pos.y
                if dx * dx + dy * dy <= r2 then out[#out + 1] = { pos = p } end
            end
        end
    end
    if #out < 3 then return {} end
    return out
end

local function mark_engage_result()
    local s = State.spot
    if s and s.kind == "camp" and (State.marchCasts or 0) > 0 then
        local real = State.engageMana and math.max(0, State.engageMana - mana()) or -1
        logline(string.format("camp_value key=%s gold=%d casts=%d plan=%d real=%d",
            tostring(s.key), math.floor(s.gold or 0), State.marchCasts or 0,
            math.floor(s.planCost or -1), math.floor(real)))

        if State.keenInvest then State.keenInvest.spent = true end
        State.marchCasts = 0

    end
end

local function go_return()
    mark_engage_result()

    State.keenInvest = nil
    State.fsm = "RETURN"
end

local function cast_march(pos)
    local marchCost = abil_mana(State.march, K.MARCH_MANA_FB)
    local keenCost = abil_mana(State.keen, K.KEEN_MANA_FB)
    local required = marchCost + keenCost + K.MARCH_KEEN_MANA_MARGIN
    if mana() < required then
        State.refillNeed = math.max(State.refillNeed or 0, required)
        State.spot = nil
        State.safeLane = nil
        State.marchCasts = 0
        State.marchPending = nil
        State.keenInvest = nil
        State.shoveLeaveBy = nil
        State.emptySince = nil
        State.moveSince = nil
        State.fsm = "RETURN"
        logline(string.format("march_skip mana=%.0f need=%.0f w=%.0f keen=%.0f margin=%.0f -> return",
            mana(), required, marchCost, keenCost, K.MARCH_KEEN_MANA_MARGIN))
        return nil
    end
    return cast_pos(State.march, pos)
end

local function engage_replan()
    mark_engage_result()
    State.spot = nil
    State.fsm  = "DECIDE"
end

local E2 = {

    FLEE_ROLES = { hard_disable = true, channel_on_me = true, line_projectile = true },

    EXTRA_THREATS = { modifier_stunned = { role = "hard_disable", extra = true } },

    THREAT_TO_ABILITY = {},
}
do

    local function min_cd(ab) return tonumber(AbilityData.Cooldown and AbilityData.Cooldown(ab, 1)) or math.huge end
    for ab, mod in pairs(ThreatData.ABILITY_TO_THREAT or {}) do
        local prev = E2.THREAT_TO_ABILITY[mod]
        if not prev or min_cd(ab) < min_cd(prev)
           or (min_cd(ab) == min_cd(prev) and ab < prev) then
            E2.THREAT_TO_ABILITY[mod] = ab
        end
    end
end
State.castStamps = State.castStamps or {}

function E2.defense_flee(threat_mod, caster)
    if now() - (State.lastFleeT or -10) < 1.0 then return end
    State.lastFleeT = now()
    State.fog = enemy_snapshot()
    try_escape_blink()
    if State.spot then
        suppress_shove(State.spot.lane, now() + K.SHOVE_STUCK_S, "defense_flee")
        mark_engage_result()
    end
    State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
    logline(string.format("defense_flee mod=%s caster=%s", tostring(threat_mod), def_uname(caster)))
end

function E2.on_save_fired(intent, save_short, threat_mod, threat_caster)
    defense_dispatcher:MarkFired(threat_caster)

    if save_short and tostring(save_short):find("blink", 1, true) then State.lastBlinkT = now() end
    E2.defense_flee(threat_mod, threat_caster)
end

function E2.stamp_enemy_cast(mod_name, caster)
    local ab = E2.THREAT_TO_ABILITY[mod_name]
    if not ab then return end
    local cname = def_uname(caster)
    if cname == "?" then return end

    local cd = math.huge
    for lvl = 1, 4 do
        local c = tonumber(AbilityData.Cooldown and AbilityData.Cooldown(ab, lvl))
        if c and c > 0 and c < cd then cd = c end
    end
    if cd == math.huge then return end
    ChannelGate.Stamp(State.castStamps, cname, ab, now(), cd)
end

local function handle_panic()
    local h = State.hero
    local frac = (Entity.GetHealth(h) or 1) / math.max(1, Entity.GetMaxHealth(h) or 1)
    if frac < K.PANIC_HP then
        State.lowHpSince = State.lowHpSince or now()
        if now() - State.lowHpSince >= K.PANIC_ARM then
            State.panicUntil = now() + 1.0
            State.fog = enemy_snapshot()
            try_escape_blink()
            go_return()
            return true
        end
    else
        State.lowHpSince = nil
    end
    return now() < State.panicUntil
end

local function schedule_ctx(lanes)
    local s = lanes and lanes[K.HOME_LANE]
    if not s then return nil end
    local cl = s.clash or {}
    local ew = s.enemy_wave
    local visible = (ew and not ew.estimated and ew.centroid) and true or false

    local awv = s.ally_wave
    local pm
    do
        local espd, aspd = Lane.WaveSpeed(ew), Lane.WaveSpeed(awv)
        if ew and ew.front and awv and awv.front and espd and aspd then
            pm = Lane.PredictMeeting({ pos = ew.front, speed = espd }, { pos = awv.front, speed = aspd })
        end
    end

    local t1m, t1malive = enemy_lane_t1(K.HOME_LANE)
    local deep_era = not t1malive
    local crash_pos
    if not visible and not deep_era then
        local lm = State.laneMeet[K.HOME_LANE]
        local lm_obs = lm and (now() - lm.t) <= K.LANE_MEET_TTL and lm.src == "obs"
        crash_pos = (lm and (now() - lm.t) <= K.LANE_MEET_TTL and { x = lm.x, y = lm.y })
                    or s.meeting

        crash_pos = clamp_intercept(crash_pos, lm_obs and 0 or K.INTERCEPT_FWD_R)
    else
        crash_pos = (pm and pm.point) or s.meeting
    end
    if not crash_pos then return nil end

    local crashTwrPos
    if t1malive and t1m and stand_depth(crash_pos) > stand_depth(t1m) then
        crash_pos = { x = t1m.x, y = t1m.y }
        crashTwrPos = t1m
    end
    local eff_hp = (ew and ew.hp) or 0

    local ecount = (ew and ew.count) or 0

    if ew and not ew.estimated and ecount > 0 and ecount <= K.SHOVE_THIN_CREEPS then
        State.loneSince[K.HOME_LANE] = State.loneSince[K.HOME_LANE] or now()
    else
        State.loneSince[K.HOME_LANE] = nil
    end
    local lsince = State.loneSince[K.HOME_LANE]
    local lone   = (lsince and (now() - lsince) >= K.THIN_CREEPS_HOLD_S) and true or false
    local few    = (visible and ecount < K.SHOVE_MIN_CREEPS) and true or false
    local present = visible

    local arrival, asrc
    if pm and visible then
        arrival, asrc = now() + pm.eta, "kin"

        if (Lane.WaveSpeed(ew) or 325) <= K.HELD_CLOSING_MIN then asrc = "held" end
    elseif visible then
        arrival, asrc = now(), "vis"
    elseif State.laneWaveT.mid then

        arrival, asrc = Lane.Schedule.NextWaveArrival(now(), K.WAVE_PERIOD, K.WAVE_PHASE, State.laneWaveT.mid), "stamp"
    elseif pm and deep_era then
        arrival, asrc = now() + pm.eta, "kinest"
    else
        arrival, asrc = Lane.Schedule.NextWaveArrival(now(), K.WAVE_PERIOD, K.WAVE_PHASE, State.laneWaveT.mid), "grid"
    end

    local bal, gone_fight_rel
    if awv and ew and not ew.estimated then
        local pf = Lane.PushForecast(awv, ew, { cycle = math.min(30, math.floor(now() / 450)),
                                                game_time = now(), rounds = 1 })
        bal = pf and pf.bal

        if bal and bal < 0 and pf.first_t and not (s.intercept and s.intercept.reachable) then
            local fight_end = now() + math.max(0, (pm and pm.eta) or 0) + pf.first_t
            if fight_end > arrival then arrival, asrc = fight_end, "sim" end
        end

        if bal and bal >= K.GONE_BAL_MIN and pf.first_t and pm then
            gone_fight_rel = pm.eta + pf.first_t
        end
    end

    local me = origin(State.hero)
    local ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
    local itc = Lane.InterceptETA({ x = me.x, y = me.y }, static_anchors(), ms,
                                  { channel = K.KEEN_CHANNEL }, crash_pos, nil)
    local travel_to_mid = (itc and itc.eta) or (me:Distance(Vector(crash_pos.x, crash_pos.y, me.z)) / math.max(150, ms))

    local raidcap = ((State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0) >= 2
                    and (ready(State.keen) or ready(State.rearm)) and awv and (awv.count or 0) > 0
                    and raid_gank_ok(crash_pos)
                    and raid_hop_ok(crash_pos)
    if raidcap then
        local transit = (ready(State.keen) and 0 or rearm_channel()) + K.KEEN_CHANNEL + 1.5
        travel_to_mid = math.min(travel_to_mid, transit)
    end

    local stand, covers, cwhy
    do

        local fwd = not lane_unsafe({ x = crash_pos.x, y = crash_pos.y })
        local _safe
        stand, covers, _safe, cwhy = safe_stand_for(crash_pos, fwd, raidcap, K.HOME_LANE)
        if not stand then stand = Map.SnapWalkable({ x = crash_pos.x, y = crash_pos.y }, crash_pos) end
    end

    local dpts = 0
    do
        local info = stand and enemy_t1_points_info(stand)
        if info then
            local kl = (State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0
            dpts = Farm.DepthPoints(info.depth_past, {
                line_alive = info.line_alive, side_t1_up = info.others_up,
                shave = (kl >= 2 and ready(State.keen)) and K.DEPTH_KEEN_SHAVE or 0,
            })
            if dpts > K.DEPTH_POINT_BUDGET then covers = false; cwhy = "dpts" end
        end
    end

    if not visible and not deep_era and stand then covers, cwhy = true, nil end

    local gone = (gone_fight_rel and not (covers and travel_to_mid < gone_fight_rel)) and true or false

    if not crashTwrPos and cl and cl.crashing and not cl.estimated and cl.crash_tower and cl.crash_tower.team ~= State.team then
        crashTwrPos = { x = cl.crash_tower.pos.x, y = cl.crash_tower.pos.y }
    end
    local crash_twr_key = tower_key_near(crashTwrPos)
    if crash_twr_key and covers
       and Map.Towers.DeathEta(State.towerTrack, crash_twr_key, now()) < travel_to_mid + K.TOWER_DYING_MARGIN_S then
        covers, cwhy = false, "tower_dying"
    end

    local srisk = enemy_risk_at(Vector(stand.x, stand.y, 0)) + enemy_tower_risk(stand)
    if srisk > 1 then srisk = 1 end

    local prisk = Farm.PathRisk({ x = me.x, y = me.y }, stand,
        function(pt) return enemy_risk_at(Vector(pt.x, pt.y, 0)) end)

    local prisk_sh = Farm.PathRisk({ x = me.x, y = me.y }, stand,
        function(pt) return enemy_risk_at(Vector(pt.x, pt.y, 0), nil, true) end)

    local shove_safe = (not lane_unsafe(stand, { bail = true, site = "mid", travel = travel_to_mid,
        commit = Escape.CommitWiden(travel_to_mid, K.COMMIT_STAND_S, K.COMMIT_APPROACH_SPEED, K.COMMIT_WIDEN_MAX) }))
        and prisk < K.PATH_RISK_MAX
    local emd = effective_march_dmg()
    local cal = { march_dmg_per_cast = (emd > 0 and emd) or K.MARCH_DMG_PER_CAST, cast_dur = K.MARCH_CAST_DUR,
                  robot_kill = K.ROBOT_KILL, rearm_channel = rearm_channel(), lead = K.SCHED_LEAD }

    local hh = State.hero
    local hpf  = (Entity.GetHealth(hh) or 1) / math.max(1, Entity.GetMaxHealth(hh) or 1)
    local mmax = (NPC.GetMaxMana and NPC.GetMaxMana(hh)) or 0
    local mpf  = (mmax > 0) and (mana() / mmax) or 1
    local covers_ctx = (covers == true)
    return {
        plan = { now = now(),
                 wave = { arrival = arrival, eff_hp = eff_hp, present = present, visible = visible },
                 cal = cal, travel_to_mid = travel_to_mid,
                 mana = effective_mana(), shove_cost = hop_mana_cost() + K.SHOVE_MANA_RESERVE,

                 shove_cost_full = hop_mana_cost(true) + K.SHOVE_MANA_RESERVE,
                 safe = shove_safe,
                 mana_regen = mana_regen_read(),
                 recover_s = recover_round_trip(crash_pos, travel_to_mid),
                 far_travel_s = K.SHOVE_FAR_TRAVEL, min_wave_ehp = K.SHOVE_MIN_EFFHP,
                 camp_alt_s = K.WAVE_CAMP_ALT_S,
                 gone = gone,

                 thin_ehp = ((lone or few) and math.huge)
                            or ((deep_era and stand_depth(crash_pos) > K.WALK_DEPTH_MAX)
                                and K.DEEP_THIN_EFFHP or K.SHOVE_THIN_EFFHP),
                 covers = covers_ctx,

                 defend_crash = (((cl.crashing and not cl.estimated and cl.crash_tower
                                   and cl.crash_tower.team == State.team)
                                  or (State.crashSeen and now() - (State.crashSeen[K.HOME_LANE] or -1e9) < K.CRASH_STICKY_S))
                                 and dpts == 0) and true or false,
                 suppressed = shove_suppressed(K.HOME_LANE),

                 hp_frac = hpf, min_hp_frac = K.DISPATCH_HP_MIN,
                 filler = { min_camp_slack = K.MIN_CAMP_SLACK, min_fountain_slack = K.MIN_FOUNTAIN_SLACK,
                            need_recharge = hpf < K.REFILL_FRAC or mpf < K.REFILL_FRAC } },
        crash_pos = crash_pos, stand = stand, aim = crash_pos, visible = visible, risk = srisk,
        deep_era = deep_era,
        dpts = dpts,
        thin1 = lone or nil,
        path_risk = prisk,
        path_risk_sh = prisk_sh,
        bal = bal,
        covers = covers,
        cwhy = cwhy,
        wave_eta = arrival, asrc = asrc,

        meet_eta = (pm and (bal or 0) >= 0) and (now() + math.max(0, pm.eta)) or nil,
        clash = cl,
        crash_tower_key = crash_twr_key,
    }
end

local function side_wave_ctx(lane, s)
    if not s then return nil, "off" end
    if shove_suppressed(lane) then return nil, "suppressed" end
    local ew, awv = s.enemy_wave, s.ally_wave
    local visible = (ew and not ew.estimated and ew.centroid) and true or false
    local pm
    do
        local espd, aspd = Lane.WaveSpeed(ew), Lane.WaveSpeed(awv)
        if ew and ew.front and awv and awv.front and espd and aspd then
            pm = Lane.PredictMeeting({ pos = ew.front, speed = espd }, { pos = awv.front, speed = aspd })
        end
    end

    local stampT = State.laneWaveT[lane]
    local stamp_fresh = (stampT and (now() - stampT) <= K.SIDE_STAMP_MAX_S) and true or false
    if not (visible or pm or stamp_fresh) then
        return nil, (stampT and "stale" or "fogged")
    end

    local st1, st1alive = enemy_lane_t1(lane)
    local crash_pos
    if not visible and st1alive then
        local lm = State.laneMeet[lane]
        crash_pos = (lm and (now() - lm.t) <= K.LANE_MEET_TTL and { x = lm.x, y = lm.y })
                    or s.meeting
        crash_pos = clamp_intercept(crash_pos, nil, lane)
    else
        crash_pos = (pm and pm.point) or s.meeting
    end
    if not crash_pos then return nil, "fogged" end
    local crashTwrPos
    if st1alive and st1 and stand_depth(crash_pos, lane) > stand_depth(st1, lane) then
        crash_pos = { x = st1.x, y = st1.y }
        crashTwrPos = st1
    end
    local eff_hp = (ew and ew.hp) or 0

    local ecount = (ew and ew.count) or 0

    if ew and not ew.estimated and ecount > 0 and ecount <= K.SHOVE_THIN_CREEPS then
        State.loneSince[lane] = State.loneSince[lane] or now()
    else
        State.loneSince[lane] = nil
    end
    local lsince = State.loneSince[lane]
    local lone   = (lsince and (now() - lsince) >= K.THIN_CREEPS_HOLD_S) and true or false

    if visible and (lone or ecount < K.SHOVE_MIN_CREEPS or eff_hp < K.SHOVE_THIN_EFFHP) then
        return nil, lone and "thin1" or "thin"
    end
    local arrival, asrc
    if pm and visible then
        arrival, asrc = now() + pm.eta, ((Lane.WaveSpeed(ew) or 325) <= K.HELD_CLOSING_MIN) and "held" or "kin"
    elseif visible then arrival, asrc = now(), "vis"
    elseif stamp_fresh then
        arrival, asrc = Lane.Schedule.NextWaveArrival(now(), K.WAVE_PERIOD, K.WAVE_PHASE, stampT), "stamp"
    elseif not st1alive then arrival, asrc = now() + pm.eta, "kinest"
    else arrival, asrc = Lane.Schedule.NextWaveArrival(now(), K.WAVE_PERIOD, K.WAVE_PHASE, stampT), "grid" end
    local bal, gone_fight_rel
    if awv and ew and not ew.estimated then
        local pf = Lane.PushForecast(awv, ew, { cycle = math.min(30, math.floor(now() / 450)),
                                                game_time = now(), rounds = 1 })
        bal = pf and pf.bal

        if bal and bal < 0 and pf.first_t and not (s.intercept and s.intercept.reachable) then
            local fight_end = now() + math.max(0, (pm and pm.eta) or 0) + pf.first_t
            if fight_end > arrival then arrival, asrc = fight_end, "sim" end
        end
        if bal and bal >= K.GONE_BAL_MIN and pf.first_t and pm then
            gone_fight_rel = pm.eta + pf.first_t
        end
    end

    local me = origin(State.hero)
    local ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
    local itc = Lane.InterceptETA({ x = me.x, y = me.y }, static_anchors(), ms,
                                  { channel = K.KEEN_CHANNEL }, crash_pos, nil)
    local travel = (itc and itc.eta) or (me:Distance(Vector(crash_pos.x, crash_pos.y, me.z)) / math.max(150, ms))
    local raidcap = ((State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0) >= 2
                    and (ready(State.keen) or ready(State.rearm)) and awv and (awv.count or 0) > 0
                    and raid_gank_ok(crash_pos)
                    and raid_hop_ok(crash_pos)
    if raidcap then
        local transit = (ready(State.keen) and 0 or rearm_channel()) + K.KEEN_CHANNEL + 1.5
        travel = math.min(travel, transit)
    end

    if not crashTwrPos and s.clash and s.clash.crashing and not s.clash.estimated and s.clash.crash_tower
       and s.clash.crash_tower.team ~= State.team then
        crashTwrPos = { x = s.clash.crash_tower.pos.x, y = s.clash.crash_tower.pos.y }
    end
    local crash_twr_key = tower_key_near(crashTwrPos)
    if crash_twr_key
       and Map.Towers.DeathEta(State.towerTrack, crash_twr_key, now()) < travel + K.TOWER_DYING_MARGIN_S then
        return nil, "tower_dying"
    end

    local fwd = not lane_unsafe({ x = crash_pos.x, y = crash_pos.y })
    local stand, covers, _safe, cwhy = safe_stand_for(crash_pos, fwd, raidcap, lane)
    if not stand then return nil, "no_stand" end
    if not visible and st1alive then covers, cwhy = true, nil end
    local dpts = 0
    do
        local info = enemy_t1_points_info(stand)
        if info then
            local kl = (State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0
            dpts = Farm.DepthPoints(info.depth_past, {
                line_alive = info.line_alive, side_t1_up = info.others_up,
                shave = (kl >= 2 and ready(State.keen)) and K.DEPTH_KEEN_SHAVE or 0,
            })
            if dpts > K.DEPTH_POINT_BUDGET and not (not visible and st1alive) then covers = false; cwhy = "dpts" end
        end
    end
    local gone = (gone_fight_rel and not (covers and travel < gone_fight_rel)) and true or false
    local srisk = enemy_risk_at(Vector(stand.x, stand.y, 0)) + enemy_tower_risk(stand)
    if srisk > 1 then srisk = 1 end
    local prisk = Farm.PathRisk({ x = me.x, y = me.y }, stand,
        function(pt) return enemy_risk_at(Vector(pt.x, pt.y, 0)) end)

    local shove_safe = (not lane_unsafe(stand, { bail = true, site = lane, travel = travel,
        commit = Escape.CommitWiden(travel, K.COMMIT_STAND_S, K.COMMIT_APPROACH_SPEED, K.COMMIT_WIDEN_MAX) }))
        and prisk < K.PATH_RISK_MAX
    local emd = effective_march_dmg()
    local cal = { march_dmg_per_cast = (emd > 0 and emd) or K.MARCH_DMG_PER_CAST, cast_dur = K.MARCH_CAST_DUR,
                  robot_kill = K.ROBOT_KILL, rearm_channel = rearm_channel(), lead = K.SCHED_LEAD }
    return {
        plan = { now = now(),
                 wave = { arrival = arrival, eff_hp = eff_hp, present = visible, visible = visible },
                 cal = cal, travel_to_mid = travel,
                 mana = effective_mana(), shove_cost = hop_mana_cost() + K.SHOVE_MANA_RESERVE,

                 shove_cost_full = hop_mana_cost(true) + K.SHOVE_MANA_RESERVE,
                 safe = shove_safe,
                 mana_regen = mana_regen_read(),
                 recover_s = recover_round_trip(crash_pos, travel),
                 far_travel_s = K.SHOVE_FAR_TRAVEL, min_wave_ehp = K.SHOVE_MIN_EFFHP,
                 camp_alt_s = K.WAVE_CAMP_ALT_S,
                 gone = gone,
                 thin_ehp = K.SHOVE_THIN_EFFHP,
                 covers = (covers == true),

                 defend_crash = (((s.clash and s.clash.crashing and not s.clash.estimated
                                   and s.clash.crash_tower
                                   and s.clash.crash_tower.team == State.team)
                                  or (State.crashSeen and now() - (State.crashSeen[lane] or -1e9) < K.CRASH_STICKY_S))
                                 and dpts == 0) and true or false,

               },
        crash_pos = crash_pos, stand = stand, aim = crash_pos, visible = visible,
        risk = srisk, dpts = dpts, wave_eta = arrival, asrc = asrc,
        meet_eta = (pm and (bal or 0) >= 0) and (now() + math.max(0, pm.eta)) or nil,
        travel = travel, gold = (ew and ew.gold) or 0, cwhy = cwhy,
        defend = (((s.clash and s.clash.crashing and not s.clash.estimated
                    and s.clash.crash_tower
                    and s.clash.crash_tower.team == State.team)
                   or (State.crashSeen and now() - (State.crashSeen[lane] or -1e9) < K.CRASH_STICKY_S))
                  and dpts == 0) and true or false,
        crash_tower_key = crash_twr_key,
    }
end

local function dispatch_shove(lane, sc, casts, ref)
    local z = origin(State.hero).z
    State.spot = {
        kind = "wave", shove = true, lane = lane, ref = ref,
        center = Vector(sc.aim.x, sc.aim.y, z), refPoint = Vector(sc.aim.x, sc.aim.y, z),
        standSpot = { stand = Vector(sc.stand.x, sc.stand.y, z),
                      aim = Vector(sc.aim.x, sc.aim.y, z), paired = false },
        shoveCasts = casts,
        waveEta = sc.wave_eta,
        meetEta = sc.meet_eta,
        waveAsrc = sc.asrc,
        crashTowerKey = sc.crash_tower_key,
    }
    if (lane or K.HOME_LANE) == K.HOME_LANE then
        State.lastWaveStand = { x = sc.stand.x, y = sc.stand.y, t = now() }
    end
    State.marchCasts, State.fsm = 0, "MOVE"
    State.keenedSpot = false
    State.moveSince = now(); State.moveTrack = nil
    State.keenedSpot = false; State.marchPending = nil; State.emptySince = nil
    State.rearmStepback = nil; State.chanDeferSince = nil
end

local function eval_side_lanes(lanes, allies, window, ft)
    local t = now()
    local dangers = State.sideLaneDanger or {}
    State.sideLaneDanger = dangers
    for i = #dangers, 1, -1 do
        if t >= (dangers[i].expires or 0) then table.remove(dangers, i) end
    end
    local function wave_ids(wave)
        local ids = {}
        for _, creep in ipairs((wave and wave.creeps) or {}) do
            if creep.index then ids[creep.index] = true end
        end
        return ids
    end
    local function overlaps(a, b)
        for id in pairs(a or {}) do if b and b[id] then return true end end
        return false
    end
    local function danger_entry(lane, ids)
        for _, danger in ipairs(dangers) do
            if danger.lane == lane and overlaps(danger.ids, ids) then return danger end
        end
        return nil
    end
    for _, ln in ipairs({ "top", "bot" }) do
        local wave = lanes[ln] and lanes[ln].enemy_wave
        if wave and not wave.estimated and wave.creeps then
            local ids = wave_ids(wave)
            if next(ids) then
                local spotted = false
                for _, enemy in ipairs((State.fog and State.fog.heroes) or {}) do
                    if enemy.pos and (enemy.visible or (enemy.age or math.huge) <= K.SIDE_WAVE_DANGER_S) then
                        for _, creep in ipairs(wave.creeps) do
                            local dx, dy = enemy.pos.x - creep.pos.x, enemy.pos.y - creep.pos.y
                            if dx * dx + dy * dy <= K.SIDE_WAVE_DANGER_R * K.SIDE_WAVE_DANGER_R then
                                spotted = true
                                break
                            end
                        end
                        if spotted then break end
                    end
                end
                if spotted then
                    local danger = danger_entry(ln, ids)
                    if danger then
                        danger.expires = t + K.SIDE_WAVE_DANGER_S
                    else
                        dangers[#dangers + 1] = {
                            lane = ln, ids = ids, expires = t + K.SIDE_WAVE_DANGER_S,
                        }
                    end
                end
            end
        end
    end
    local core_allies = {}
    for _, a in ipairs(allies or {}) do if a.core then core_allies[#core_allies + 1] = a end end

    local camp_centers = {}
    for _, cd in ipairs(State.world.camps()) do if cd.center then camp_centers[#camp_centers + 1] = cd.center end end
    local best, bestCtx = nil, nil
    local sw = { top = { v = "off", r = -1 }, bot = { v = "off", r = -1 } }
    for _, ln in ipairs({ "top", "bot" }) do
        local verdict
        local wave = lanes[ln] and lanes[ln].enemy_wave
        local blocked = danger_entry(ln, wave_ids(wave)) ~= nil
        if not blocked and wave and wave.estimated then
            for _, danger in ipairs(dangers) do
                if danger.lane == ln then blocked = true; break end
            end
        end
        local sctx, why
        if blocked then why = "danger" else sctx, why = side_wave_ctx(ln, lanes[ln]) end
        local cj, cwhy = false, nil
        if sctx then
            cj, cwhy = Farm.IsContestedByAlly(sctx.crash_pos, core_allies,
                { radius = K.CONTEST_LANE_R, camps = camp_centers, camp_r = K.HERO_FARM_R, jungle_r = K.CONTEST_JUNGLE_R })
        end
        if not sctx then verdict = why

        elseif cj then verdict = (cwhy == "jungle") and "contested_j" or "contested"
        else
            local sd = Lane.Schedule.Plan(sctx.plan)
            if sd.action ~= "shove" then
                verdict = (sd.reason == "far_wave" and "far")
                       or (sd.reason == "gone_by_arrival" and "gone")
                       or (sd.reason == "thin_wave" and "thin")
                       or (sd.reason == "no_safe_stand" and "no_stand")
                       or sd.reason
            else

                local ret = Lane.InterceptETA(sctx.stand, static_anchors(),
                    (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320,
                    keen_tp(),
                    State.shoveReturnPos or sctx.stand, nil)
                local trip = sctx.travel + (sd.t_clear or 0) + ((ret and ret.eta) or 0)

                if trip > window and sd.reason ~= "defend_crash" then verdict = "no_fit"
                elseif best and best.risk <= sctx.risk
                       and not (best.risk == sctx.risk and sctx.gold > best.gold) then
                    verdict = "risk_lost"
                else
                    if best then sw[best.lane].v = "risk_lost" end
                    best, bestCtx, verdict = { lane = ln, risk = sctx.risk, gold = sctx.gold,
                                               casts = sd.casts }, sctx,
                                             (sd.reason == "defend_crash") and "defend" or "ok"
                end
            end
        end
        sw[ln] = { v = verdict, r = (sctx and sctx.risk) or -1 }
    end
    ft.swtop = string.format("%s:%.2f", sw.top.v, sw.top.r)
    ft.swbot = string.format("%s:%.2f", sw.bot.v, sw.bot.r)
    return best, bestCtx
end

local function fsm_decide()
    if now() < State.nextDecide then return end
    State.nextDecide = now() + K.DECIDE_GAP

    if State.keenInvest then
        local ki = State.keenInvest

        if (State.marchCasts or 0) == 0 and not ki.spent then

            logline(string.format("keen_waste lane=%s kind=%s asrc=%s resid=%.0f held=%.1f%s",
                tostring(ki.lane or "-"), tostring(ki.kind or "-"),
                tostring(ki.asrc or "-"), ki.resid or -1,
                now() - ki.t - (ki.excluded or 0), ki.excluded and " tko=1" or ""))
        end
        State.keenInvest = nil
    end
    State.fog = enemy_snapshot()
    State.refillNeed = nil

    State.missN = Escape.MissingCount(State.fog)

    local ft = { t = string.format("%.1f", now()), miss = State.missN }
    local function emit_farm() end

    local stuckWindow = false

    local function crash_fresh_any()
        if not State.crashSeen then return false end
        for _, ln in ipairs({ "mid", "top", "bot" }) do
            if now() - (State.crashSeen[ln] or -1e9) < K.CRASH_STICKY_S then return true end
        end
        return false
    end

    local allies  = ally_farm_priorities()
    local our_pri = our_farm_priority()
    State.schedSlack, State.shoveLeaveBy, State.shoveTravel = nil, nil, nil
    if State.menu.kindLane:Get()
       and not (State.menu.kindJungle:Get() and State.menu.safeLaneFarm:Get()) then
        local me0 = origin(State.hero)
        local enemy_push, ally_push = lane_push_dirs()
        local lanes
        if State.laneScan and State.laneScanSerial == State.updateSerial then
            lanes = State.laneScan
        else
            lanes = Lane.ScanLanes({
                team = State.team, enemy_push = enemy_push, ally_push = ally_push,
                anchors = static_anchors(), allowed_kinds = keen_allowed_kinds(),
                hero_pos = { x = me0.x, y = me0.y },
                move_speed = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320,
                tp = keen_tp(), game_time = now(),
                paths = lane_paths(),
            })
            annotate_measured(lanes)
        end
        State.laneScan, State.laneScanSerial = lanes, State.updateSerial
        local sc = schedule_ctx(lanes)
        local d = sc and Lane.Schedule.Plan(sc.plan) or nil

        if State.cyclePark then
            if now() >= State.cyclePark.untilT or not d or d.action ~= "jungle" or crash_fresh_any() then
                State.cyclePark = nil
            else

                local w = idle_wait_spot({ x = State.cyclePark.x, y = State.cyclePark.y })
                local pv = Vector(w.x, w.y, me0.z)
                if me0:Distance(pv) > K.WAVE_HOLD_EPS then move_to(pv, "cycle_park") end
                State.waitInfo = { why = "cycle park", t = now() }
                return
            end
        end

        if d and d.action == "shove" and (d.reason ~= "due" or sc.visible) and shove_suppressed(K.HOME_LANE) then

            d.action, d.reason = "recover", "shove_stuck"
        end

        do
            local s = lanes[K.HOME_LANE]
            local ew, aw, cl = s and s.enemy_wave, s and s.ally_wave, s and s.clash
            local push = "none"
            if cl then
                push = cl.pushing .. (cl.moving and "" or "/hold")
                if cl.crashing and cl.crash_tower then
                    push = push .. (cl.crash_tower.team == State.team and ">allyTwr" or ">enemyTwr")
                end
            end
            ft.e, ft.a = ew and ew.count or 0, aw and aw.count or 0
            ft.push, ft.enH, ft.alH = push, s and s.enemy_heroes or 0, s and s.ally_heroes or 0
            ft.mana = string.format("%.0f", mana())
            ft.gpm  = string.format("%.0f", gpm())
            ft.klvl = (State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0
            if d then
                ft.act, ft.reason = d.action, d.reason
                ft.slack   = string.format("%.1f", d.slack)
                ft.leaveby = string.format("%.0f", d.leave_by)
                ft.dl      = string.format("%.0f", d.deadline)
                ft.casts   = d.casts
                ft.eff_hp  = string.format("%.0f", sc.plan.wave.eff_hp)
                ft.dmg     = string.format("%.0f", (sc.plan.cal and sc.plan.cal.march_dmg_per_cast) or 0)
                ft.travel  = string.format("%.1f", sc.plan.travel_to_mid)
                ft.vis     = sc.visible and "y" or "n"
                ft.asrc    = sc.asrc or "-"
                ft.risk    = string.format("%.2f", sc.risk)
                ft.dpts    = string.format("%.0f", sc.dpts or 0)
                ft.cwhy    = sc.cwhy
                ft.deep    = sc.deep_era and 1 or 0
                ft.scfull  = sc.plan and sc.plan.shove_cost_full and string.format("%.0f", sc.plan.shove_cost_full) or nil
                ft.thin1   = sc.thin1 and K.HOME_LANE or nil
                ft.recfits = d.recover_fits and "y" or "n"
                ft.prisk   = string.format("%.2f", sc.path_risk or 0)
                ft.prisk_sh = sc.path_risk_sh and string.format("%.2f", sc.path_risk_sh) or nil
                if sc.bal then ft.bal = string.format("%d", sc.bal) end
            end
        end

        if d and d.action == "shove" then

            if sc.deep_era and d.reason ~= "defend_crash" then
                local best, bestCtx = eval_side_lanes(lanes, allies, K.ROUTE_HORIZON_S, ft)
                local mid_gold = (lanes[K.HOME_LANE] and lanes[K.HOME_LANE].enemy_wave
                                  and lanes[K.HOME_LANE].enemy_wave.gold) or 0
                if best and (best.risk < sc.risk
                             or (best.risk == sc.risk and best.gold > mid_gold)) then
                    dispatch_shove(best.lane, bestCtx, math.min(best.casts or 2, 2), lanes[best.lane])
                    ft.lane, ft.dpick = best.lane, string.format("%s:%.2f", best.lane, best.risk)
                    ft.seff, ft.sgold, ft.ssrc = string.format("%.0f", bestCtx.plan.wave.eff_hp or 0), string.format("%.0f", bestCtx.gold or 0), bestCtx.asrc or "?"
                    ft.sx, ft.sy = string.format("%.0f", bestCtx.stand.x), string.format("%.0f", bestCtx.stand.y)
                    ft.ax, ft.ay = string.format("%.0f", bestCtx.aim.x), string.format("%.0f", bestCtx.aim.y)
                    emit_farm("shove")
                    return
                end
                if best or ft.swtop then ft.dpick = string.format("mid:%.2f", sc.risk) end
            end
            dispatch_shove(K.HOME_LANE, sc, d.casts, lanes[K.HOME_LANE])
            ft.lane = K.HOME_LANE
            ft.sx, ft.sy = string.format("%.0f", sc.stand.x), string.format("%.0f", sc.stand.y)
            ft.ax, ft.ay = string.format("%.0f", sc.aim.x), string.format("%.0f", sc.aim.y)
            emit_farm("shove")
            return
        elseif d and d.action == "recover" and d.reason ~= "unsafe" and d.reason ~= "shove_stuck" then
            State.spot = nil; State.fsm = "RETURN"
            emit_farm("recover")
            return
        end

        if d and d.action == "recover" then
            State.schedSlack, State.shoveLeaveBy, State.shoveTravel, State.shoveReturnPos = nil, nil, nil, nil
            stuckWindow = (d.reason == "shove_stuck")

        else

            State.schedSlack   = (d and d.reason == "slack") and d.slack or nil

            State.shoveLeaveBy = (d and d.reason == "slack") and d.leave_by or nil
            State.shoveTravel  = d and sc.plan.travel_to_mid or nil
            State.shoveReturnPos = sc and sc.crash_pos or nil

            local deep = sc and sc.deep_era or false
            local window = (not deep and State.shoveLeaveBy and (State.shoveLeaveBy - now()))
                           or K.ROUTE_HORIZON_S
            local best, bestCtx = eval_side_lanes(lanes, allies, window, ft)
            if best then
                dispatch_shove(best.lane, bestCtx, math.min(best.casts or 2, 2), lanes[best.lane])
                if deep then State.shoveLeaveBy = nil end
                ft.lane = best.lane
                ft.seff, ft.sgold, ft.ssrc = string.format("%.0f", bestCtx.plan.wave.eff_hp or 0), string.format("%.0f", bestCtx.gold or 0), bestCtx.asrc or "?"
                ft.sx, ft.sy = string.format("%.0f", bestCtx.stand.x), string.format("%.0f", bestCtx.stand.y)
                ft.ax, ft.ay = string.format("%.0f", bestCtx.aim.x), string.format("%.0f", bestCtx.aim.y)
                emit_farm("shove")
                return
            end
        end
    end

    local targets = gather_route_targets(allies, our_pri)
    local ropts = route_opts()
    if stuckWindow then

        local win = math.max(K.SHOVE_STUCK_S, (State.shoveSuppress[K.HOME_LANE] or 0) - now())
        ropts.horizon_s = math.min(ropts.horizon_s, win)
    end
    if State.schedSlack and State.schedSlack > 0 then

        local horizon = State.schedSlack + (State.shoveTravel or 0)
        ropts.horizon_s = math.min(ropts.horizon_s, math.max(0, horizon))
        if State.shoveReturnPos then
            ropts.return_pos     = State.shoveReturnPos
            ropts.return_anchors = static_anchors()
            ropts.return_speed   = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
            ropts.return_tp      = keen_tp()
        end
        ft.reserve = string.format("%.1f", State.shoveTravel or 0)
        ft.horizon = string.format("%.1f", ropts.horizon_s)
    end
    local heroState = route_hero_state()
    local priorityTarget
    if State.menu.kindJungle:Get() and State.menu.safeLaneFarm:Get() then
        for _, target in ipairs(targets) do
            if target.outpostAncient and target.outpostTeam == State.team and not target.contested
               and (target.risk or 0) < (ropts.risk_hard or K.RISK_HARD)
            then
                local eta = Lane.Route._leg_time(heroState.pos, target, heroState)
                local hpAtArrival = math.min(heroState.max_hp or math.huge,
                    heroState.hp + (heroState.hp_regen or 0) * eta)
                if hpAtArrival - (target.hp_cost or 0) >= (heroState.hp_floor or 0) then
                    priorityTarget = target
                    break
                end
            end
        end
    end
    if priorityTarget then
        local leg = Lane.Route._leg_time(heroState.pos, priorityTarget, heroState)
        local required = (priorityTarget.mana_cost or 0) + (heroState.reserve_mana or 0)
        local manaAtArrival = heroState.mana + (heroState.mana_regen or 0) * leg
        if required <= heroState.max_mana and manaAtArrival < required then
            State.refillNeed = math.max(State.refillNeed or 0, required)
            State.spot = nil
            State.fsm = "RETURN"
            emit_farm("refill_outpost_pair")
            return
        end
        if required <= heroState.max_mana then
            State.routePlan = { steps = { priorityTarget }, gold = priorityTarget.value or 0,
                                time = leg + (priorityTarget.clear_t or 0), score = priorityTarget.value or 0 }
            logline(string.format("farm_priority target=outpost_ancient eta=%.1f mana=%.0f need=%.0f",
                leg, heroState.mana, required))
        else
            State.routePlan = Lane.Route.Plan(targets, heroState, ropts)
        end
    else
        State.routePlan = Lane.Route.Plan(targets, heroState, ropts)
    end

    do
        local hs = heroState
        local nC, nR, nL, nA, nF, nFp, need = 0, 0, 0, 0, 0, 0, nil
        for _, tg in ipairs(targets) do
            if tg.kind == "camp" then
                if tg.contested then nC = nC + 1
                elseif (tg.risk or 0) >= K.RISK_HARD then nR = nR + 1
                elseif K.MAX_CAMP_TRAVEL_S and Lane.Route._leg_time(hs.pos, tg, hs) > K.MAX_CAMP_TRAVEL_S then nL = nL + 1
                else

                    local price = (tg.mana_cost or 0) + (hs.reserve_mana or 0)
                    if not need or price < need then need = price end
                    if hs.mana < price then nA = nA + 1
                    else
                        nF = nF + 1
                        if tg.partnerRef then nFp = nFp + 1 end
                    end
                end
            end
        end
        ft.rej = string.format("c%d/r%d/l%d/a%d/ok%d", nC, nR, nL, nA, nF)
        ft.okp = string.format("%d", nFp)
        ft.need = need and string.format("%.0f", need) or nil
        ft.pm   = string.format("%.0f", hs.mana)
        ft.cap  = string.format("%.0f", hs.max_mana)
    end
    local cfill
    if #State.routePlan.steps == 0 then

        local h = State.hero
        local mmax = (NPC.GetMaxMana and NPC.GetMaxMana(h)) or 1
        local hmax = Entity.GetMaxHealth(h) or 1
        local ccost = Lane.Schedule.WaveCycleCost({
            w = abil_mana(State.march, K.MARCH_MANA_FB),
            rearm = abil_mana(State.rearm, K.REARM_MANA_FB),
            keen = abil_mana(State.keen, K.KEEN_MANA_FB),
        })
        cfill = Lane.Schedule.CycleFill({
            pool = effective_mana(),
            max_pool = mmax,
            cycle_cost = ccost,
            broke_bar = hop_mana_cost() + K.SHOVE_MANA_RESERVE,
        })
        if cfill.fill == "fountain" or (Entity.GetHealth(h) or hmax) < hmax * K.REFILL_FRAC then
            if cfill.fill == "fountain" then
                State.refillNeed = cfill.need
                logline(string.format("cycle_fill fill=fountain window=%.1f need=%.0f cost=%.0f pool=%.0f",
                    State.schedSlack or -1, cfill.need or 0, ccost, effective_mana()))
            end
            State.spot = nil
            State.fsm  = "RETURN"
            emit_farm("refill")
            return
        end
    end

    local camps = {}
    for _, t in ipairs(targets) do if t.kind == "camp" then camps[#camps + 1] = t.ref end end
    State.cands = camps
    local f = State.funnel or {}
    ft.total, ft.fvis, ft.est, ft.fseen, ft.fcleared = f.total, f.vis, f.est, f.seen, f.cleared
    ft.plan, ft.gpm = #State.routePlan.steps, string.format("%.0f", gpm())

    for i = 1, 2 do
        local st = State.routePlan.steps[i]
        ft["p" .. i] = st and string.format("%s:%.0f:%s", st.kind, st.value or 0,
                                            st.partnerRef and "y" or "n") or nil
    end

    local first
    for _, step in ipairs(State.routePlan.steps) do
        first = step
        break
    end
    if not first then

        if stuckWindow and shove_suppressed(K.HOME_LANE)
           and now() < (State.releaseSuppress[K.HOME_LANE] or 0) then
            State.shoveSuppress[K.HOME_LANE] = 0
            State.releaseSuppress[K.HOME_LANE] = 0
            State.releaseBlockUntil = now() + K.TETHER_MAX_HOLD_S
            logline("release_cancel empty_window -> re-tether")
            State.spot = nil; emit_farm("none"); return
        end

        if not stuckWindow and cfill and cfill.fill == "park" and not crash_fresh_any() then
            local lw = State.lastWaveStand
            if lw and (now() - (lw.t or 0)) < 60 and State.schedSlack and State.schedSlack > 0 then
                State.cyclePark = { untilT = math.min(now() + math.min(State.schedSlack, K.WAVE_PERIOD),
                                                       select(2, camp_spawn_window())),
                                    x = lw.x, y = lw.y }
                logline(string.format("cycle_fill fill=park window=%.1f pool=%.0f",
                    State.schedSlack, effective_mana()))
            end
        end

        local me = origin(State.hero)
        local lw = State.lastWaveStand
        local lwFresh = lw and (now() - (lw.t or 0)) < 60
        local w = idle_wait_spot(lwFresh and lw or nil)
        if w then
            local wv = Vector(w.x, w.y, me.z)
            if me:Distance(wv) > K.WAVE_HOLD_EPS then move_to(wv, "idle_wait") end
        end

        State.waitInfo = { why = stuckWindow and "suppressed" or "window", t = now() }
        State.spot = nil; emit_farm("none"); return
    end

    if first.restore then

        local nxt = State.routePlan.steps[2]
        State.refillNeed = (nxt and not nxt.restore and nxt.mana_cost)
            and (nxt.mana_cost + abil_mana(State.keen, K.KEEN_MANA_FB)) or nil
        if State.refillNeed then ft.rneed = string.format("%.0f", State.refillNeed) end
        State.spot = nil
        State.fsm  = "RETURN"
        emit_farm("refill")
        return
    end

    local c = first.ref
    if first.partnerRef then
        local A, B = c.center, first.partnerRef.center
        local midpoint = Vector((A.x + B.x) / 2, (A.y + B.y) / 2, A.z)
        local stand = configured_pair_stand(A, B) or midpoint
        local travelAnchor
        if first.outpostAncient then
            for _, outpost in ipairs(MapData.OUTPOSTS or {}) do
                if outpost.team == State.team and outpost.pos then
                    travelAnchor = Vector(outpost.pos[1], outpost.pos[2], outpost.pos[3])
                    break
                end
            end
        end
        c.standSpot = { stand = stand,
                        aim   = midpoint,
                        travelAnchor = travelAnchor,
                        outpostPair = first.outpostAncient,
                        paired = true, partner = B,
                        partnerCamp = first.partnerRef.camp, partnerType = first.partnerRef.type,
                        clear = first.pairClass, pd = first.pairPd }
    else
        c.standSpot = best_stand_spot(c)

        local nnd
        for _, o in ipairs(State.cands or {}) do
            if o ~= c and o.center then
                local d = c.center:Distance(o.center)
                if not nnd or d < nnd then nnd = d end
            end
        end
        ft.nnd = nnd and string.format("%.0f", nnd) or "-"
    end
    if not c.standSpot then State.spot = nil; emit_farm("none"); return end
    c.kind = "camp"
    c.clearEst = first.clear_t or 0
    c.planCost = first.mana_cost or 0
    local spot = c

    State.spot, State.marchCasts, State.fsm = spot, 0, "MOVE"
    State.keenedSpot = false
    State.moveSince = now()
    State.moveTrack = nil
    State.rearmStepback = nil
    State.keenedSpot = false
    State.marchPending = nil
    State.emptySince = nil

    local ss = spot.standSpot
    ft.ctype, ft.cgold, ft.cstk = spot.type, math.floor(spot.gold or 0), camp_stacks(spot.gold, spot.type)
    ft.csrc, ft.cval = spot.source or "est", math.floor(first.value or 0)
    ft.crisk = string.format("%.2f", first.risk or 0)
    ft.crisk_sh = first.risk_sh and string.format("%.2f", first.risk_sh) or nil
    ft.ncreep, ft.paired = #(spot.creeps or {}), tostring(ss.paired or false)
    ft.cx, ft.cy = math.floor(spot.center.x), math.floor(spot.center.y)
    ft.sx, ft.sy = math.floor(ss.stand.x), math.floor(ss.stand.y)
    if ss.partner then ft.pcx, ft.pcy = math.floor(ss.partner.x), math.floor(ss.partner.y)
    elseif State.pairSkip then ft.pairskip = State.pairSkip end
    emit_farm("camp")
end

local function update_wave_spot(s)
    local creeps = enemy_lane_creeps_near(s.refPoint, K.WAVE_TRACK_RADIUS)
    if #creeps == 0 then return nil end
    local cx, cy = 0, 0
    for _, c in ipairs(creeps) do cx = cx + c.pos.x; cy = cy + c.pos.y end
    cx, cy = cx / #creeps, cy / #creeps
    local z = origin(State.hero).z
    s.refPoint = Vector(cx, cy, z)

    do
        local fp0 = friendly_fountain_pos()
        local ranged, bestd = nil, -1
        if fp0 then
            for _, c in ipairs(creeps) do
                local dx, dy = c.pos.x - fp0.x, c.pos.y - fp0.y
                local dd = dx * dx + dy * dy
                if dd > bestd then bestd, ranged = dd, c.pos end
            end
        end
        if ranged then

            local dok = s.shove and ((State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0) >= 2

            local st, cov = safe_stand_for(ranged, true, dok, s.lane)
            if st and cov then
                s.standSpot.aim = Vector(ranged.x, ranged.y, z)
                s.standSpot.stand = Vector(st.x, st.y, z)
                return { cx = cx, cy = cy, n = #creeps }
            end
        end

    end

    local fp = friendly_fountain_pos()
    local ax, ay = 0, 0
    if fp then
        local dx, dy = fp.x - cx, fp.y - cy
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl > 1 then ax, ay = dx / dl, dy / dl end
    end

    local pts = {}
    for _, c in ipairs(creeps) do pts[#pts + 1] = { x = c.pos.x, y = c.pos.y } end
    local aimc = ((ax ~= 0 or ay ~= 0) and Farm.WaveAimCenter(pts, ax, ay)) or { x = cx, y = cy }
    if (ax ~= 0 or ay ~= 0) and K.WAVE_LEAD ~= 0 then
        aimc = { x = aimc.x - ax * K.WAVE_LEAD, y = aimc.y - ay * K.WAVE_LEAD }
    end
    s.standSpot.aim = Vector(aimc.x, aimc.y, z)

    local st, cov = safe_stand_for({ x = aimc.x, y = aimc.y }, false,
        s.shove and ((State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0) >= 2, s.lane)

    if st and cov then s.standSpot.stand = Vector(st.x, st.y, z) end
    return { cx = cx, cy = cy, n = #creeps, nocover = (st and not cov) or nil }
end

local function no_progress(d)
    local stuck
    State.moveTrack, stuck = Map.Nav.Stuck(State.moveTrack, d, now(),
        { eps = K.PROGRESS_EPS, window = K.NO_PROGRESS_S })
    return stuck
end

local function keen_cancel_check()
    local kp = State.keenPending
    if not kp or now() < kp.due then return end
    State.keenPending = nil

    if now() > kp.due + 1.5 then return end

    local me = origin(State.hero)
    if kp.origin and me:Distance(Vector(kp.origin.x, kp.origin.y, me.z)) < 600 then
        State.keenedSpot = false
        logline("keen_canceled -> re-ladder")
    end
end

local function log_walk_leg(dist, why)

    if dist <= K.WALK_LEG_MIN or now() - (State.walkLegLogT or 0) < 2 then return end
    State.walkLegLogT = now()

    local kcd = (State.keen and Ability.GetCooldown and Ability.GetCooldown(State.keen)) or -1
    local ms  = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
    logline(string.format("walk_leg d=%.0f why=%s kcd=%.1f kr=%d walk=%.1f",
        dist, why, kcd, ready(State.keen) and 1 or 0, dist / math.max(150, ms)))
end

local function lane_go(dest, raid)
    if not dest then return nil end
    local me = origin(State.hero)
    local fp = friendly_fountain_pos()
    local retreat = { x = 0, y = 0 }
    if fp then
        local dx, dy = fp.x - dest.x, fp.y - dest.y
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl > 1 then retreat = { x = dx / dl, y = dy / dl } end
    end

    if not raid and (stand_depth(dest, State.spot and State.spot.lane) > K.WALK_DEPTH_MAX + 50 or not lane_leash_ok(dest, 50, State.spot and State.spot.lane)) then
        logline(string.format("lane_go deep_reject (%.0f,%.0f) depth=%.0f -> redecide (UPSTREAM BUG)",
            dest.x, dest.y, stand_depth(dest)))
        suppress_shove(State.spot and State.spot.lane, now() + K.SHOVE_STUCK_S, "deep_reject")
        State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
        return nil
    end
    local sdest, clamped = Map.Nav.SafeDest({ x = dest.x, y = dest.y }, retreat, tower_safe)
    if clamped then
        logline(string.format("lane_go clamp (%.0f,%.0f) -> (%.0f,%.0f)", dest.x, dest.y, sdest.x, sdest.y))
    end
    sdest = Map.SnapWalkable(sdest, dest)
    local sv = Vector(sdest.x, sdest.y, me.z)

    local function blink_ok()
        return State.keenedSpot
            or (((State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0) < 1)
            or me:Distance(sv) <= K.KEEN_TRAVEL_MIN
    end

    local kfail
    local function walk_or_wait()
        if not State.keenedSpot and State.keen and not ready(State.keen)
           and ((Ability.GetLevel and Ability.GetLevel(State.keen)) or 0) >= 1 then
            local kcd = (Ability.GetCooldownTimeRemaining and Ability.GetCooldownTimeRemaining(State.keen)) or 0
            local ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
            local walk_s = me:Distance(sv) / math.max(150, ms)
            if kcd > 0 and kcd + K.KEEN_CHANNEL + K.KEEN_WAIT_MARGIN < walk_s then
                State.waitInfo = { why = string.format("keen cd %ds", math.ceil(kcd)), t = now() }
                State.moveSince = now(); State.moveTrack = nil
                if now() - (State.waitKeenLogT or 0) > 2 then
                    State.waitKeenLogT = now()
                    logline(string.format("lane_go wait_keen cd=%.1f walk=%.0fs", kcd, walk_s))
                end
                return "wait_keen"
            end
        end

        local wd = me:Distance(sv)
        if wd <= K.WAVE_HOLD_EPS then return "walk" end
        log_walk_leg(wd, raid and "raid"
            or (kfail == "no_landing" and "no_anchor") or (kfail == "disabler" and "safety") or kfail
            or (State.keenedSpot and "latched")
            or (wd <= K.KEEN_TRAVEL_MIN and "short") or "no_keen")
        move_to(sv, "lane_walk"); return "walk"
    end
    local rungs = Map.Nav.Ladder(me:Distance(sv), {
        keened = State.keenedSpot, keen_ready = ready(State.keen), keen_min_gain = K.KEEN_TRAVEL_MIN,
    })
    for _, r in ipairs(rungs) do
        if r == "keen" then
            local kok, kwhy = keen_to_anchor(sv, raid)
            if kok then State.keenedSpot = true; logline(raid and "lane_go keen raid" or "lane_go keen"); return "keen" end

            if kwhy == "raid_far" or kwhy == "raid_broke" then
                local tag = kwhy == "raid_far" and "raid_reject" or "raid_broke"
                logline(string.format("lane_go %s (%.0f,%.0f) -> redecide", tag, dest.x, dest.y))
                suppress_shove(State.spot and State.spot.lane, now() + K.SHOVE_STUCK_S, tag)
                State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                return nil
            end

            if kwhy ~= "cast_failed" and kwhy ~= "disabler" and kwhy ~= "mana_defer" then State.keenedSpot = true end
            kfail = kwhy
        elseif r == "rearm" then

            if blink_ok() and (not raid or me:Distance(sv) >= 800) and try_travel_blink(sv) then logline(string.format("lane_go blink d=%.0f latched=%s", me:Distance(sv), tostring(State.keenedSpot))); return "blink" end
            if safe_rearm() then logline("lane_go rearm_reset_keen"); return "rearm" end
        else

            if blink_ok() and (not raid or me:Distance(sv) >= 800) and try_travel_blink(sv) then logline(string.format("lane_go blink d=%.0f latched=%s", me:Distance(sv), tostring(State.keenedSpot))); return "blink" end
            return walk_or_wait()
        end
    end
    if blink_ok() and (not raid or me:Distance(sv) >= 800) and try_travel_blink(sv) then logline(string.format("lane_go blink d=%.0f latched=%s", me:Distance(sv), tostring(State.keenedSpot))); return "blink" end
    return walk_or_wait()
end

local function march_cross_target(me, aim)
    local maxr = (K.MARCH_CAST_RANGE or 300) - 20
    local theta = (State.wArm == 2) and K.W_X_ARM_B or K.W_X_ARM_A
    local dx, dy = aim.x - me.x, aim.y - me.y
    local dl = math.sqrt(dx * dx + dy * dy)
    local tgt
    if dl > 1 then
        local th = math.rad(theta)
        local ct, st = math.cos(th), math.sin(th)
        local ux, uy = dx / dl, dy / dl
        local d = math.min(maxr, dl)
        tgt = Vector(me.x + (ux * ct - uy * st) * d, me.y + (ux * st + uy * ct) * d, aim.z)
    else
        tgt = Vector(aim.x, aim.y, aim.z)
    end
    return (me:Distance(tgt) > maxr) and (me + (tgt - me):Normalized() * maxr) or tgt, theta
end

local function fsm_move_wave(s)
    keen_cancel_check()
    State.fog = enemy_snapshot()

    if s.crashTowerKey and Map.Towers.Alive(State.towerTrack, s.crashTowerKey) == false then
        logline("tower_died -> redecide lane=" .. tostring(s.lane or K.HOME_LANE))
        State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
        return
    end

    local hrisk = enemy_risk_at(origin(State.hero))

    if lane_unsafe(origin(State.hero), { bail = true }) then
        try_escape_blink()
        suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "wave_move_unsafe")
        State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
        logline(string.format("wave_move abort reason=unsafe risk=%.2f", hrisk)); return
    end

    if s.shove and s.lane and s.lane ~= K.HOME_LANE
       and (State.marchCasts or 0) == 0 and not State.marchPending
       and now() - (s.contestT or 0) >= 1.0 then
        s.contestT = now()
        local cores = {}
        for _, a in ipairs(ally_farm_priorities()) do
            if a.core then cores[#cores + 1] = a end
        end
        local ground = s.refPoint or (s.standSpot and s.standSpot.aim)

        local acc = {}
        for _, cd in ipairs(State.world.camps()) do if cd.center then acc[#acc + 1] = cd.center end end
        local cj, cwhy = false, nil
        if #cores > 0 and ground then
            cj, cwhy = Farm.IsContestedByAlly({ x = ground.x, y = ground.y }, cores,
                { radius = K.CONTEST_LANE_R, camps = acc, camp_r = K.HERO_FARM_R, jungle_r = K.CONTEST_JUNGLE_R })
        end
        if cj then
            logline(string.format("contest_abandon lane=%s why=%s", tostring(s.lane), tostring(cwhy)))
            suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "contest_abandon")
            State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
            State.marchPending = nil
            return
        end
    end
    local live = update_wave_spot(s)

    do
        local rawLive = live and true or false
        if s.visState == nil then s.visState = rawLive end
        if rawLive ~= s.visState then
            s.visPendT = s.visPendT or now()
            if now() - s.visPendT < K.WAVE_VIS_DEBOUNCE_S then return end
            s.visState, s.visPendT = rawLive, nil
        else
            s.visPendT = nil
        end
    end

    if live and State.emptySince and not s.waveLiveT then s.waveLiveT = now() end

    local raidok = s.shove and ((State.keen and Ability.GetLevel and Ability.GetLevel(State.keen)) or 0) >= 2

    do
        local mp = State.marchPending
        if mp and MC.fired(mp) then
            State.marchCasts = (State.marchCasts or 0) + 1; State.marchPending = nil
            logline("march cast=" .. State.marchCasts)
        elseif mp and now() > mp.expire then
            State.marchPending = nil
        end
        local me1 = origin(State.hero)

        if (State.marchCasts or 0) <= 1 and not State.marchPending and not ready(State.march)
           and ((State.marchCasts or 0) == 1 or cd_remaining(State.march) > K.PREARM_CD_FLOOR)
           and (me1:Distance(s.standSpot.stand) <= K.W_PRE_LEAD_R
                or channel_threat_near({ x = s.standSpot.stand.x, y = s.standSpot.stand.y }))
           and effective_mana() >= abil_mana(State.rearm, K.REARM_MANA_FB) + abil_mana(State.march, K.MARCH_MANA_FB)
           and safe_rearm() then
            logline("prearm_w2"); return
        end
    end

    if s.waveEta and s.standSpot and (State.marchCasts or 0) == 0 and not State.marchPending then
        s.arrivalPromise0 = s.arrivalPromise0 or math.max(s.waveEta, now())
        local me0 = origin(State.hero)
        local at_stand = me0:Distance(s.standSpot.stand) <= K.WAVE_ENGAGE_RANGE
        do
            local sc = State.laneScan and State.laneScan[s.lane or K.HOME_LANE]
            local scan = sc and {
                est = (sc.enemy_wave and sc.enemy_wave.estimated) and true or false,
                reach = (sc.intercept and sc.intercept.reachable) and true or false,
                eta = sc.intercept and sc.intercept.eta or nil } or nil

            local kk = at_stand
                and { grace = K.ARRIVAL_GRACE_S,    hold_t = K.ARRIVAL_HOLD_T, hold_max = K.ARRIVAL_HOLD_MAX_S }
                or  { grace = K.ARRIVAL_HOLD_MAX_S, hold_t = K.ARRIVAL_HOLD_T, hold_max = K.ARRIVAL_HOLD_MAX_S }
            local verdict, why, held = Timing.ArrivalWatchdog(now(), s.arrivalPromise0, scan, kk)
            if verdict == "release" then
                logline(string.format("arrival_release lane=%s why=%s held=%.1f at_stand=%s",
                    tostring(s.lane or K.HOME_LANE), tostring(why), held, at_stand and "y" or "n"))

                if s.shove then
                    suppress_shove(s.lane, now() + ((why == "flicker") and K.SHOVE_STUCK_S or K.LIVE_STALL_S),
                                   "arrival_release")
                end
                State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                State.marchPending = nil
                return
            end
        end
    end
    if not live then

        local me0 = origin(State.hero)
        local d0 = me0:Distance(s.standSpot.stand)

        if s.shove and not s.reanchored and not s.arrived and (State.marchCasts or 0) == 0 and not State.marchPending then
            local scn = State.laneScan and State.laneScan[s.lane or K.HOME_LANE]
            local ew2 = scn and scn.enemy_wave
            if ew2 and not ew2.estimated and ew2.front then
                local rdx, rdy = ew2.front.x - s.refPoint.x, ew2.front.y - s.refPoint.y
                local dRe = math.sqrt(rdx * rdx + rdy * rdy)
                if dRe > K.WAVE_TRACK_RADIUS then

                    s.reanchored = true
                    if me0:Distance(Vector(ew2.front.x, ew2.front.y, me0.z)) <= K.WAVE_TRACK_RADIUS then
                        s.refPoint = Vector(ew2.front.x, ew2.front.y, me0.z)
                        s.standSpot.aim = Vector(ew2.front.x, ew2.front.y, me0.z)
                        State.moveTrack = nil
                        State.emptySince = nil
                        logline(string.format("reanchor d=%.0f -> aim", dRe))
                        return
                    else
                        logline(string.format("reanchor d=%.0f -> redecide", dRe))
                        State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                        State.marchPending = nil
                        return
                    end
                end
            end
        end
        State.emptySince = State.emptySince or now()

        local grace = (d0 <= K.WAVE_ENGAGE_RANGE) and K.WAVE_WAIT_GRACE_VIS or K.WAVE_WAIT_GRACE
        local due = (s.waveEta and (s.waveEta + grace)) or (State.emptySince + K.WAVE_WAIT_GRACE)
        if now() > due then

            if d0 <= K.WAVE_ENGAGE_RANGE then
                logline(string.format("overdue_convert lane=%s over=%.1f", tostring(s.lane or K.HOME_LANE),
                    now() - (s.waveEta or State.emptySince or now())))
                if s.shove then suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "overdue_convert") end
                State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                State.marchPending = nil
                return
            end
            local nxt = Lane.Schedule.NextWaveArrival(now(), K.WAVE_PERIOD, K.WAVE_PHASE, State.laneWaveT[s.lane or K.HOME_LANE])
            if nxt and (nxt - now()) <= K.WAVE_HOLD_NEXT then
                s.waveEta = nxt
                logline(string.format("wave_wait extend eta=%.1f", nxt))
            else
                State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                State.marchPending = nil
                logline("shove_move no_wave -> redecide"); return
            end
        end

        if not s.steppedOut then
            local eta_live = State.laneWaveT[s.lane or K.HOME_LANE]
                and Lane.Schedule.NextWaveArrival(now(), K.WAVE_PERIOD, K.WAVE_PHASE, State.laneWaveT[s.lane or K.HOME_LANE]) or nil

            if s.meetEta and (raidok or not eta_live) then eta_live = eta_live and math.min(eta_live, s.meetEta) or s.meetEta end
            local ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
            local walk_s = d0 / math.max(150, ms)

            local tr = ready(State.keen) and (K.KEEN_CHANNEL + 1.0)
                       or (ready(State.rearm) and rearm_channel() + K.KEEN_CHANNEL + 1.0 or nil)
            if tr then walk_s = math.min(walk_s, tr) end
            if d0 <= K.WAVE_ENGAGE_RANGE then
                s.steppedOut = true
            elseif eta_live and now() >= eta_live - walk_s - K.STEP_OUT_PRECAST_S then
                s.steppedOut = true
                State.keenedSpot = false
                logline(string.format("step_out eta=%.1f walk=%.1f d=%.0f", eta_live, walk_s, d0))
            else

                local wait_s = eta_live and (eta_live - now() - walk_s - K.STEP_OUT_PRECAST_S) or nil
                if wait_s and wait_s > K.TETHER_MAX_HOLD_S and now() >= (State.releaseBlockUntil or 0) then
                    suppress_shove(s.lane, now() + math.min(wait_s - 2, 25), "tether_release")
                    State.releaseSuppress[s.lane or K.HOME_LANE] = State.shoveSuppress[s.lane or K.HOME_LANE]
                    State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                    logline(string.format("tether release wait=%.1f -> jungle window", wait_s))
                    return
                end

                if not s.tetherSpot then

                    s.tetherSpot = channel_threat_near({ x = s.standSpot.stand.x, y = s.standSpot.stand.y })
                                   and protected_wait_spot({ x = s.standSpot.stand.x, y = s.standSpot.stand.y })
                                   or { x = s.standSpot.stand.x, y = s.standSpot.stand.y }

                    local msT = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
                    if raidok and me0:Distance(Vector(s.tetherSpot.x, s.tetherSpot.y, me0.z))
                                  / math.max(150, msT) > K.TETHER_WALK_MAX_S then
                        s.tetherSpot = protected_wait_spot({ x = me0.x, y = me0.y })
                    end
                end
                local hv = Vector(s.tetherSpot.x, s.tetherSpot.y, me0.z)
                if not s.tetherLogged then
                    s.tetherLogged = true
                    logline(string.format("tether hold=(%.0f,%.0f) d=%.0f eta=%s", s.tetherSpot.x, s.tetherSpot.y, d0,
                        eta_live and string.format("%.1f", eta_live) or "-"))
                end
                State.waitInfo = { why = string.format("tether %s", eta_live
                    and string.format("%ds", math.max(0, math.floor(eta_live - now()))) or "wave?"), t = now() }

                if raidok and not ready(State.keen) and safe_rearm() then
                    logline("tether prearm_rearm"); return
                end

                if me0:Distance(hv) > K.WAVE_HOLD_EPS then

                    if raidok then move_to(hv, "tether_hold") else lane_go(hv) end
                end
                return
            end
        end

        if channel_threat_near({ x = s.standSpot.stand.x, y = s.standSpot.stand.y }) then
            s.protUntil = now() + K.PROT_CLEAR_S
        end
        if s.protUntil and now() < s.protUntil then
            local w = protected_wait_spot({ x = s.standSpot.stand.x, y = s.standSpot.stand.y })
            local hv = Vector(w.x, w.y, me0.z)
            State.waitInfo = { why = string.format("wave %ds @tower", math.max(0, math.floor((s.waveEta or now()) - now()))), t = now() }
            if (State.marchCasts or 0) <= 1 and not State.marchPending and not ready(State.march)
               and ((State.marchCasts or 0) == 1 or cd_remaining(State.march) > K.PREARM_CD_FLOOR)
               and me0:Distance(hv) <= K.WAVE_HOLD_EPS
               and effective_mana() >= abil_mana(State.rearm, K.REARM_MANA_FB) + abil_mana(State.march, K.MARCH_MANA_FB)
               and safe_rearm() then
                logline("prearm_w2"); return
            end

            if me0:Distance(hv) > K.WAVE_HOLD_EPS then lane_go(hv, raidok) end
            return
        end
        if d0 > K.WAVE_ENGAGE_RANGE then
            if no_progress(d0) then
                suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "move_stuck")
                State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                logline(string.format("shove_move stuck d=%.0f -> recover (suppress shove %ds)", d0, K.SHOVE_STUCK_S)); return
            end
            lane_go(s.standSpot.stand, raidok); return
        end

        local hold = s.standSpot.stand
        local prot = false

        State.waitInfo = { why = string.format("wave %ds%s", math.max(0, math.floor((s.waveEta or now()) - now())),
                                               prot and " @tower" or ""), t = now() }

        if me0:Distance(hold) > (prot and K.WAVE_HOLD_EPS or K.W_PRE_STAND_R) then lane_go(hold, raidok) end
        return
    end
    local me = origin(State.hero)
    local dWave = me:Distance(s.refPoint)

    if live.nocover then
        if not s.ncT then s.ncT, s.ncD = now(), dWave
        elseif dWave < s.ncD - K.NC_CLOSE_EPS then s.ncT, s.ncD = now(), dWave
        elseif now() - s.ncT > K.NC_GRACE_S then

            local receding = dWave > (s.ncD or dWave) + K.NC_CLOSE_EPS
            local fundable = effective_mana() >= abil_mana(State.march, K.MARCH_MANA_FB)
                                                 + abil_mana(State.rearm, K.REARM_MANA_FB)
            if receding or dWave > K.NC_HOLD_NEAR or not fundable then
                suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "nocover")
                State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                logline("wave_move abort reason=nocover"); return
            end
            if not s.ncHeld then
                s.ncHeld = true
                logline(string.format("nocover_hold dWave=%.0f", dWave))
            end
            State.waitInfo = { why = "nocover hold", t = now() }
        end
    else
        s.ncT, s.ncD = nil, nil
    end

    local eref = s.standSpot.aim
    local dref = me:Distance(eref)

    if s.wgHx and (math.abs(me.x - s.wgHx) + math.abs(me.y - s.wgHy)) > 30 then
        s.wgD, s.wgClose, s.wgN = nil, nil, nil
    end
    s.wgHx, s.wgHy = me.x, me.y
    if s.wgD and s.wgT and now() > s.wgT then
        local rate = (s.wgD - dref) / (now() - s.wgT)

        if math.abs(rate) <= 450 then
            s.wgClose = s.wgClose and (s.wgClose * 0.6 + rate * 0.4) or rate
            s.wgN = (s.wgN or 0) + 1
        end
    end
    s.wgD, s.wgT = dref, now()

    if (State.marchCasts or 0) == 1 and not State.marchPending and ready(State.march)
       and effective_mana() >= abil_mana(State.march, K.MARCH_MANA_FB) then

        if dref <= K.MARCH_REACH then
            local cp, theta = march_cross_target(me, eref)
            local fired = cast_march(cp)
            if fired == nil then return end
            if fired then
                State.marchPending = { cdBefore = MC.now_cd(), expire = now() + 1.5 }
                State.wArm = (State.wArm == 2) and 1 or 2
                logline(string.format("march_aim src=shove_w2 pat=x%d lane=%s cast=(%.0f,%.0f) dref=%.0f",
                    theta, tostring(s.lane), cp.x, cp.y, dref))
            end
        end
    end

    do
        local ds = (s.standSpot and s.standSpot.stand) and me:Distance(s.standSpot.stand) or -1
        local cl = s.wgClose or 0

        local tarr_d = (cl >= K.W_CLOSING_MIN) and ((dref - K.ANTICIP_RANGED_REACH) / cl) or -1
        local why
        if (State.marchCasts or 0) ~= 0 then why = "cast_done"
        elseif State.marchPending then why = "pending"
        elseif not ready(State.march) then why = "march_cd"
        elseif (live.n or 0) < K.W_PRE_MIN_N then why = "thin"
        elseif dref <= K.WAVE_ENGAGE_RANGE then why = "inside_engage"
        elseif dref > K.W_LEAD_CAP then why = "cap"
        elseif cl < K.W_CLOSING_MIN then why = "slow"
        elseif (s.wgN or 0) < 2 then why = "wg_cold"
        elseif ds < 0 then why = "no_stand"
        elseif ds > K.W_PRE_LEAD_R then why = "stand_far"
        elseif effective_mana() < abil_mana(State.march, K.MARCH_MANA_FB) + abil_mana(State.rearm, K.REARM_MANA_FB) then why = "mana"
        elseif State.fightSeen and State.fightSeen[s.lane] and now() - State.fightSeen[s.lane] <= K.FIGHT_HOLD_S then why = "fight"
        elseif tarr_d > K.W_LEAD_S then why = "lead_bar"
        end

        if why and (now() >= (State.wLeadLogT or 0) or (s.wgN or 0) == 2) then
            State.wLeadLogT = now() + 1.0
            logline(string.format(
                "w_lead_reject why=%s ln=%s tarr=%.2f eff=%.2f dref=%.0f close=%.3f dstand=%.0f n=%d wgn=%d",
                why, tostring(s.lane), tarr_d, tarr_d, dref, cl, ds, live.n or 0, s.wgN or 0))
        end
    end
    if (State.marchCasts or 0) == 0 and not State.marchPending and ready(State.march)
       and live.n >= K.W_PRE_MIN_N
       and dref > K.WAVE_ENGAGE_RANGE and dref <= K.W_LEAD_CAP
       and (s.wgClose or 0) >= K.W_CLOSING_MIN and (s.wgN or 0) >= 2
       and me:Distance(s.standSpot.stand) <= K.W_PRE_LEAD_R
       and effective_mana() >= abil_mana(State.march, K.MARCH_MANA_FB) + abil_mana(State.rearm, K.REARM_MANA_FB)

       and not (State.fightSeen and State.fightSeen[s.lane] and now() - State.fightSeen[s.lane] <= K.FIGHT_HOLD_S) then

        local tarr = (dref - K.ANTICIP_RANGED_REACH) / s.wgClose
        if tarr <= K.W_LEAD_S then
            local cp, theta = march_cross_target(me, eref)
            local fired = cast_march(cp)
            if fired == nil then return end
            if fired then
                State.marchPending = { cdBefore = MC.now_cd(), expire = now() + 1.5 }
                State.wArm = (State.wArm == 2) and 1 or 2

                logline(string.format("march_aim src=shove_pre pat=x%d lane=%s tarr=%.1f close=%.0f cast=(%.0f,%.0f) dWave=%.0f dref=%.0f dstand=%.0f",
                    theta, tostring(s.lane), tarr, s.wgClose, cp.x, cp.y, dWave, dref, me:Distance(s.standSpot.stand)))
            end
        end
    end

    local timed = s.waveEta and now() >= s.waveEta - K.MARCH_CAST_DUR
                  and now() <= s.waveEta + 2.0
                  and me:Distance(s.standSpot.stand) <= K.W_PRE_STAND_R
                  and dWave <= K.MARCH_REACH
    if dref <= K.WAVE_ENGAGE_RANGE or timed then
        State.fsm = "ENGAGE"; State.moveSince = nil; State.emptySince = nil

        local ln = s.lane or K.HOME_LANE

        State.laneWaveT[ln] = Lane.Schedule.NextOnGrid(now(), K.WAVE_PERIOD, K.WAVE_PHASE) - K.WAVE_PERIOD

        local lmx, lmy, lmsrc = eref.x, eref.y, "aim"
        if live and live.cx then lmx, lmy, lmsrc = live.cx, live.cy, "obs" end
        State.laneMeet[ln] = { x = lmx, y = lmy, t = now(), src = lmsrc }

        if s.waveEta then
            local drift = math.max(0, math.min(6, now() - s.waveEta))
            State.etaDrift = State.etaDrift or {}
            State.etaDrift[ln] = State.etaDrift[ln] and (State.etaDrift[ln] * 0.5 + drift * 0.5) or drift
        end

        if live.n >= 2 and (s.shoveCasts or 2) < 2 then s.shoveCasts = 2 end
        s.arrived = true

        logline(string.format("wave_engage_arrived dWave=%.0f dref=%.0f creeps=%d trig=%s eta_err=%s lm=%s lmd=%.0f",
            dWave, dref, live.n, timed and "time" or "dist",
            s.waveEta and string.format("%+.1f", now() - s.waveEta) or "-",
            lmsrc, math.sqrt((lmx - eref.x) ^ 2 + (lmy - eref.y) ^ 2))); return
    end

    if dref > K.WAVE_ENGAGE_RANGE and ((s.wgClose or 0) < K.W_CLOSING_MIN or (s.wgN or 0) < 2) then
        s.stallT = s.stallT or now()
        if now() - s.stallT > K.LIVE_STALL_S then
            logline(string.format("stall_release lane=%s dref=%.0f close=%s casts=%d held=%.1f",
                tostring(s.lane or K.HOME_LANE), dref, tostring(s.wgClose), State.marchCasts or 0,
                now() - s.stallT))
            if s.shove then suppress_shove(s.lane, now() + K.LIVE_STALL_S, "stall_release") end
            State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
            State.marchPending = nil
            return
        end
    else
        s.stallT = nil
    end
    if State.moveSince and now() - State.moveSince > K.MOVE_TIMEOUT then

        local eta = (not s.steppedOut) and s.tetherSpot and s.waveEta or nil
        local cap = State.moveSince + K.MOVE_TIMEOUT + K.WAVE_PERIOD
        if not (eta and now() < math.min(eta + K.WAVE_WAIT_GRACE, cap)) then
            State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
            logline("wave_move timeout -> redecide"); return
        end
    end

    if not s.steppedOut then
        local ms0 = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
        local walk_s = me:Distance(s.standSpot.stand) / math.max(150, ms0)

        if raidok then
            local tr = ready(State.keen) and (K.KEEN_CHANNEL + 1.0)
                       or (ready(State.rearm) and rearm_channel() + K.KEEN_CHANNEL + 1.0 or nil)
            if tr then walk_s = math.min(walk_s, tr) end
        end

        local close_s = math.max(0, dref - K.WAVE_ENGAGE_RANGE) / 325

        local meet_s = s.meetEta and math.max(0, s.meetEta - now()) or nil

        local sim_s = (s.waveAsrc == "sim" or s.waveAsrc == "kin" or s.waveAsrc == "held")
                      and s.waveEta and math.max(0, s.waveEta - now()) or nil
        local eff_s = math.min(close_s, meet_s or math.huge, sim_s or math.huge)
        if eff_s > walk_s + K.STEP_OUT_LEAD then

            local wait_s = eff_s - walk_s - K.STEP_OUT_LEAD
            if wait_s > K.TETHER_MAX_HOLD_S and now() >= (State.releaseBlockUntil or 0) then
                suppress_shove(s.lane, now() + math.min(wait_s - 2, 25), "tether_release")
                State.releaseSuppress[s.lane or K.HOME_LANE] = State.shoveSuppress[s.lane or K.HOME_LANE]
                State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
                logline(string.format("tether release wait=%.1f -> jungle window", wait_s))
                return
            end

            if not s.tetherSpot then
                s.tetherSpot = channel_threat_near({ x = s.standSpot.stand.x, y = s.standSpot.stand.y })
                               and protected_wait_spot({ x = s.standSpot.stand.x, y = s.standSpot.stand.y })
                               or { x = s.standSpot.stand.x, y = s.standSpot.stand.y }

                local msT = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(State.hero)) or 320
                if raidok and me:Distance(Vector(s.tetherSpot.x, s.tetherSpot.y, me.z))
                              / math.max(150, msT) > K.TETHER_WALK_MAX_S then
                    s.tetherSpot = protected_wait_spot({ x = me.x, y = me.y })
                end
            end
            local hv = Vector(s.tetherSpot.x, s.tetherSpot.y, me.z)
            if not s.tetherLogged then
                s.tetherLogged = true
                logline(string.format("tether hold=(%.0f,%.0f) d=%.0f eta=live+%.1f", s.tetherSpot.x, s.tetherSpot.y,
                    me:Distance(s.standSpot.stand), close_s))
            end

            State.waitInfo = { why = string.format("tether %ds", math.floor(eff_s)), t = now() }

            if raidok and not ready(State.keen) and safe_rearm() then
                logline("tether prearm_rearm"); return
            end

            if me:Distance(hv) > K.WAVE_HOLD_EPS then

                if raidok then move_to(hv, "tether_hold_live") else lane_go(hv) end
            end
            return
        end
        s.steppedOut = true
        State.keenedSpot = false
        logline(string.format("step_out live close=%.1f meet=%s sim=%s walk=%.1f", close_s,
            meet_s and string.format("%.1f", meet_s) or "-",
            sim_s and string.format("%.1f", sim_s) or "-", walk_s))
    end

    if not s.walkIn and dref > K.WAVE_ENGAGE_RANGE
       and ((s.waveAsrc == "held")
            or ((s.wgClose or math.huge) < K.W_CLOSING_MIN
                and (s.wgClose or -math.huge) > -K.W_CLOSING_MIN))
       and enemy_tower_risk(s.standSpot.aim) <= 0 then
        s.walkIn = true
        logline(string.format("wave_walkin dref=%.0f asrc=%s close=%s", dref, tostring(s.waveAsrc),
            s.wgClose and string.format("%.0f", s.wgClose) or "-"))
    end

    if (State.marchCasts or 0) >= 1 and not State.marchPending then
        if not ready(State.march) then
            local thr, tpos = channel_threat_near(origin(State.hero))
            if thr and tpos
               and effective_mana() >= abil_mana(State.rearm, K.REARM_MANA_FB) + abil_mana(State.march, K.MARCH_MANA_FB) then

                local dx, dy = me.x - tpos.x, me.y - tpos.y
                local dl = math.sqrt(dx * dx + dy * dy)
                if dl > 1 then
                    move_to(Vector(me.x + dx / dl * 300, me.y + dy / dl * 300, me.z), "rearm_stepback")
                end
            end
        elseif dref > K.MARCH_REACH and me:Distance(s.standSpot.stand) > K.WAVE_HOLD_EPS then

            lane_go(s.standSpot.stand, raidok)
        end
        return
    end
    if (State.marchCasts or 0) == 0 and not State.marchPending
       and me:Distance(s.standSpot.stand) > (s.walkIn and K.WAVE_HOLD_EPS or K.W_PRE_STAND_R) then

        lane_go(s.standSpot.stand, raidok)
    else
        State.waitInfo = { why = string.format("wave closing %d", math.floor(dref)), t = now() }
    end
end

local function camp_unsafe_abort(s, where)
    local ss = s.standSpot
    local pt = (ss and ss.stand) or s.center
    if not pt then return false end
    State.fog = enemy_snapshot()
    local r = enemy_risk_at(pt)
    if r >= K.FARM_SAFE_RISK then
        try_escape_blink()

        mark_spot_cleared(s, now() + K.CAMP_UNSAFE_SUPPRESS_S); go_return()
        logline(string.format("%s abort reason=unsafe risk=%.2f (suppress %ds)", where, r, K.CAMP_UNSAFE_SUPPRESS_S))
        return true
    end
    return false
end

local function fsm_move()
    keen_cancel_check()
    local s = State.spot
    if not s then State.fsm = "DECIDE"; State.moveSince = nil; return end
    if s.kind == "wave" then return fsm_move_wave(s) end
    if camp_unsafe_abort(s, "move") then return end
    local ss = s.standSpot
    local stand = ss.stand
    local me0 = origin(State.hero)
    local d = me0:Distance(stand)
    local aim = ss.aim or s.center
    local dCast = me0:Distance(aim)

    if ss.travelAnchor and not ss.travelReached then
        local outpost = ss.travelAnchor
        local outpostDist = me0:Distance(outpost)
        if outpostDist <= K.KEEN_LAND_OUTPOST + K.TOWER_SAFE_MARGIN then
            ss.travelReached = true
            logline(string.format("move reached_outpost d=%.0f", outpostDist))
        elseif not lane_unsafe(outpost) and enemy_risk_at(outpost) < K.FARM_SAFE_RISK then
            if outpostDist > K.KEEN_TRAVEL_MIN and not ss.travelKeenAttempted then
                if ready(State.keen) then
                    local kok, kwhy = keen_to_anchor(outpost)
                    ss.travelKeenAttempted = true
                    if kok then
                        State.keenedSpot = true
                        logline("move keen_to_outpost")
                        return
                    end
                    if kwhy == "mana_defer" or kwhy == "disabler" then
                        ss.travelKeenAttempted = false
                    end
                elseif try_travel_blink(outpost) then
                    ss.travelKeenAttempted = true
                    return
                elseif safe_rearm() then
                    return
                end
            end
            if try_travel_blink(outpost) then return end
            move_to(outpost, "move_outpost")
            return
        else
            ss.travelReached = true
            logline("move skip_outpost unsafe")
        end
    end

    local engage_ok
    if ss.paired and ss.partner then

        local ux, uy = ss.partner.x - s.center.x, ss.partner.y - s.center.y
        local ul = math.sqrt(ux * ux + uy * uy); if ul < 1 then ul = 1 end
        ux, uy = ux / ul, uy / ul
        local ox, oy = me0.x - aim.x, me0.y - aim.y
        local along = math.abs(ox * ux + oy * uy)
        local perp  = math.abs(-ox * uy + oy * ux)
        engage_ok = d <= K.ARRIVE_DIST or (along <= K.BOX_ALONG and perp <= K.BOX_PERP)
    else
        engage_ok = d <= K.ARRIVE_DIST or dCast <= K.ENGAGE_COVER_DIST
    end
    if engage_ok then
        State.fsm = "ENGAGE"; State.moveSince = nil
        State.emptySince = nil
        State.engageStart = now()
        State.engageMana  = mana()
        logline(string.format("engage_arrived t=%.1f d=%.0f dCast=%.0f", now(), d, dCast)); return
    end

    if no_progress(d) then
        mark_spot_cleared(s)
        State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil
        logline(string.format("move stuck d=%.0f -> redecide+cleared", d)); return
    end
    if State.moveSince and now() - State.moveSince > K.MOVE_TIMEOUT then
        State.spot = nil; State.fsm = "DECIDE"; State.moveSince = nil; return
    end

    local kfail
    if d > K.KEEN_TRAVEL_MIN and not State.keenedSpot and not ss.travelAnchor then
        if ready(State.keen) then
            local kok, kwhy = keen_to_anchor(ss.travelAnchor or stand)
            if kok then
                State.keenedSpot = true
                logline(ss.travelAnchor and "move keen_to_outpost" or "move keen_to_anchor")
                return
            end

            if kwhy ~= "cast_failed" and kwhy ~= "disabler" and kwhy ~= "mana_defer" then State.keenedSpot = true end
            kfail = kwhy
        elseif try_travel_blink(stand) then

            return
        elseif safe_rearm() then
            logline("move rearm_reset_keen"); return
        end
    end
    if try_travel_blink(stand) then return end
    if origin(State.hero):Distance(stand) <= K.WAVE_HOLD_EPS then return end
    log_walk_leg(d, (kfail == "no_landing" and "no_anchor") or (kfail == "disabler" and "safety") or kfail
        or (State.keenedSpot and "latched")
        or (d <= K.KEEN_TRAVEL_MIN and "short") or "no_keen")
    move_to(stand, "move_stand")
end

local function fsm_engage_wave(s)
    State.fog = enemy_snapshot()
    local live = update_wave_spot(s)
    if not live then

        local mp0 = State.marchPending
        if mp0 then
            if MC.fired(mp0) then
                State.marchCasts = State.marchCasts + 1; State.marchPending = nil
                logline("march cast=" .. State.marchCasts)
            else
                local me0 = origin(State.hero)
                if issue(UO.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, nil, me0) then
                    State.marchPending = nil
                    logline("march_cancel reason=empty src=wave")
                end
            end
        end
        State.emptySince = State.emptySince or now()
        if now() - State.emptySince > K.ENGAGE_EMPTY_GRACE then

            local ssrc = "gridtick"
            if s.shove then State.laneWaveT[s.lane or K.HOME_LANE] = Lane.Schedule.NextOnGrid(now(), K.WAVE_PERIOD, K.WAVE_PHASE) - K.WAVE_PERIOD end
            logline("engage_done reason=wave_clear casts=" .. tostring(State.marchCasts)
                    .. (s.shove and (" stampsrc=" .. ssrc) or ""))
            engage_replan()
            return
        end
        return
    end
    State.emptySince = nil
    local me = origin(State.hero)

    local erisk = enemy_risk_at(me)

    if lane_unsafe(me) then
        logline(string.format("wave_engage abort reason=unsafe risk=%.2f", erisk))
        try_escape_blink()
        if s.shove then suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "engage_unsafe") end
        go_return(); return
    end

    do
        local sb = State.rearmStepback
        if sb then
            if now() > sb.deadline or ready(State.march) then
                State.rearmStepback = nil
            elseif safe_rearm() then
                State.rearmStepback = nil
                logline("rearm_stepback fired"); return
            else
                move_to(sb.spot, "rearm_stepback")
                State.moveSince = now()
                return
            end
        end
    end
    if me:Distance(s.refPoint) > K.WAVE_ENGAGE_RANGE + 250 then
        State.fsm = "MOVE"; State.moveSince = now(); State.keenedSpot = false
        logline("wave_engage reposition dWave=" .. math.floor(me:Distance(s.refPoint))); return
    end
    if mana() < K.ESCAPE_MANA then
        logline("engage_bail reason=mana mana=" .. math.floor(mana())); go_return(); return
    end

    if State.chanDeferSince and now() - State.chanDeferSince > K.CHANNEL_DEFER_BAIL_S
       and not State.rearmStepback and not ready(State.march) then
        logline("engage_bail reason=channel_defer")
        suppress_shove(State.spot and State.spot.lane, now() + K.SHOVE_STUCK_S, "channel_defer")
        State.chanDeferSince = nil
        engage_replan(); return
    end
    local mp = State.marchPending
    if mp then
        if MC.fired(mp) then
            State.marchCasts = State.marchCasts + 1; State.marchPending = nil
            logline("march cast=" .. State.marchCasts)
        elseif now() > mp.expire then
            State.marchPending = nil; logline("march issued_NOT_fired_retry")
        else
            return
        end
    end

    local maxw = K.WAVE_MAX_W

    local wbudget = math.min(s.shoveCasts or maxw, maxw, 2)
    if State.marchCasts >= wbudget then

        if s.shove then State.laneWaveT[s.lane or K.HOME_LANE] = Lane.Schedule.NextOnGrid(now(), K.WAVE_PERIOD, K.WAVE_PHASE) - K.WAVE_PERIOD end

        if s.shove then suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "budget_delivery") end

        logline(string.format("engage_done reason=budget casts=%d lane=%s shove%s",
            State.marchCasts, tostring(s.lane),
            s.shove and " stampsrc=gridtick" or ""))
        engage_replan()
        return
    end

    do
        local wwRef = me:Distance(s.standSpot.aim)
        if (State.marchCasts or 0) == 0 and (wwRef > K.W_CAST_REACH or live.n < 2) then
            s.wwT = s.wwT or now()
            if now() - s.wwT > K.W_WAIT_RELEASE_S then
                if s.shove then suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "w_wait") end
                logline(string.format("engage_release reason=w_wait dref=%.0f n=%d casts=%d", wwRef, live.n, State.marchCasts or 0))
                engage_replan(); return
            end
        end
    end
    if ready(State.march) then

        do
            local dref0 = me:Distance(s.standSpot.aim)

            if (State.marchCasts or 0) == 0 and (dref0 > K.W_CAST_REACH or live.n < 2) then
                s.wwD = math.min(s.wwD or dref0, dref0)
                if dref0 > K.W_CAST_REACH and live.n >= 2 and dref0 <= (s.wwD or dref0) + 100 then
                    local sdx, sdy = s.standSpot.aim.x - me.x, s.standSpot.aim.y - me.y
                    local sdl = math.sqrt(sdx * sdx + sdy * sdy)
                    if sdl > 1 then
                        local step = dref0 - K.W_CAST_REACH + 30
                        local tgt = Vector(me.x + sdx / sdl * step, me.y + sdy / sdl * step, me.z)

                        local sits = tower_safe({ x = tgt.x, y = tgt.y })
                        if sits and stand_depth({ x = tgt.x, y = tgt.y }) <= K.WALK_DEPTH_MAX + 50 then
                            move_to(tgt, "w_stepin")
                        elseif now() - (State.stepInVetoLogT or 0) > 2 then
                            State.stepInVetoLogT = now()
                            logline(string.format("step_in_veto why=%s d=%.0f", sits and "depth" or "tower", dref0))
                        end
                    end
                end

                State.waitInfo = { why = string.format("W wait %d n=%d c=%d", math.floor(dref0), live.n, State.marchCasts or 0), t = now() }
                return
            end
            s.wwT, s.wwD = nil, nil
        end
        local cp, theta = march_cross_target(me, s.standSpot.aim)
        local fired = cast_march(cp)
        if fired == nil then return end
        if fired then
            State.marchPending = { cdBefore = MC.now_cd(), expire = now() + 1.5 }
            State.wArm = (State.wArm == 2) and 1 or 2
            logline(string.format("march_aim src=shove pat=x%d lane=%s wave=(%.0f,%.0f) cast=(%.0f,%.0f) creeps=%d dWave=%.0f",
                theta, tostring(s.lane), live.cx, live.cy, cp.x, cp.y, live.n, me:Distance(s.refPoint)))
        end
    elseif effective_mana() < abil_mana(State.rearm, K.REARM_MANA_FB) + abil_mana(State.march, K.MARCH_MANA_FB) then

        logline(string.format("engage_bail reason=rearm_unfundable mana=%.0f", effective_mana()))
        if s.shove then suppress_shove(s.lane, now() + K.SHOVE_STUCK_S, "rearm_unfundable") end
        go_return()
    elseif safe_rearm() then
        logline("rearm")
    elseif not State.rearmStepback then

        local thr, tpos = channel_threat_near(me)
        if thr and tpos then
            local dx, dy = me.x - tpos.x, me.y - tpos.y
            local dl = math.sqrt(dx * dx + dy * dy)
            if dl > 1 then
                for _, step in ipairs({ 500, 800, 1100 }) do
                    local cand = Map.SnapWalkable({ x = me.x + dx / dl * step, y = me.y + dy / dl * step }, me)
                    if cand and not channel_threat_near(cand) then
                        State.rearmStepback = { spot = Vector(cand.x, cand.y, 0), deadline = now() + K.REARM_STEPBACK_S }
                        logline(string.format("rearm_stepback out d=%d threat=%s", step, thr))
                        break
                    end
                end
            end
        end

        if not State.rearmStepback and not State.marchPending
           and me:Distance(s.standSpot.aim) < K.ANTICIP_RANGED_REACH - K.STAND_KITE_EPS then
            move_to(s.standSpot.stand, "wave_kite")
        end
    end
end

local function live_camp_ehp(s, neutrals)
    local e = Farm.EffectiveHP(camp_creep_list(s.camp, s.type, neutrals))
    local ss = s.standSpot
    if ss and ss.paired and ss.partnerCamp then

        local ep = Farm.EffectiveHP(camp_creep_list(ss.partnerCamp, ss.partnerType or s.type, neutrals))
        e = math.max(e, ep)
    end
    return e
end

local function ancient_engage(s)
    if s.type == 3 then return true end
    local ss = s.standSpot
    return ss and ss.paired and ss.partnerType == 3 or false
end

local function laser_lasthit_target(s, neutrals, killhp)
    local best, bestmax = nil, -1
    local function scan(camp)
        for _, c in ipairs(Map.CampCreeps(camp, neutrals) or {}) do
            local hp = (Entity.GetHealth and Entity.GetHealth(c)) or 0
            local mhp = (Entity.GetMaxHealth and Entity.GetMaxHealth(c)) or 0
            if hp > 0 and mhp > bestmax then bestmax, best = mhp, c end
        end
    end
    if s.type == 3 then scan(s.camp) end
    if s.standSpot.paired and s.standSpot.partnerType == 3 and s.standSpot.partnerCamp then
        scan(s.standSpot.partnerCamp)
    end
    local hp = best and ((Entity.GetHealth and Entity.GetHealth(best)) or 0) or 0
    return (best and hp > 0 and hp <= killhp) and best or nil
end

local function fsm_engage()
    local s = State.spot
    if not s then go_return(); return end
    if s.kind == "wave" then return fsm_engage_wave(s) end

    if camp_unsafe_abort(s, "engage") then return end

    local neutrals = State.world.neutrals()

    local function refresh_value(camp, ctype, center)
        local list = camp_creep_list(camp, ctype, neutrals)
        State.campSeen[Map.CampKey(center)] = { gold = Farm.GoldValue(list), ehp = Farm.EffectiveHP(list), seen_at = now() }
    end
    refresh_value(s.camp, s.type, s.center)
    if s.standSpot.paired and s.standSpot.partnerCamp then
        refresh_value(s.standSpot.partnerCamp, s.standSpot.partnerType or s.type, s.standSpot.partner)
    end
    local occupied = #Map.CampCreeps(s.camp, neutrals) > 0
    if s.standSpot.paired and s.standSpot.partnerCamp then
        occupied = occupied or #Map.CampCreeps(s.standSpot.partnerCamp, neutrals) > 0
    end
    if not occupied and camp_spawn_window() then
        State.emptySince = nil
        State.waitInfo = { why = "camp respawn", t = now() }
        return
    end
    if occupied then
        State.emptySince = nil
        s.campEhp = s.campEhp or live_camp_ehp(s, neutrals)
    else
        State.emptySince = State.emptySince or now()

        if (State.marchCasts or 0) == 0 and not State.marchPending then
            local ve = camp_visible(s.center)
            if ve and s.standSpot.paired and s.standSpot.partner then
                ve = camp_visible(s.standSpot.partner)
            end
            if ve then
                if now() - State.emptySince > K.ENGAGE_EMPTY_GRACE then
                    mark_spot_cleared(s)
                    logline(string.format("engage_done reason=empty casts=0 dur=%.1f est=%.1f arrive_empty",
                        now() - (State.engageStart or now()), s.clearEst or 0)); engage_replan(); return
                end
                return
            end
        end

        local mp0 = State.marchPending
        if mp0 and (State.marchCasts or 0) >= K.MIN_CASTS_BEFORE_EMPTY then
            if MC.fired(mp0) then
                State.marchCasts = State.marchCasts + 1; State.marchPending = nil
                logline(string.format("march cast=%d t=%.1f", State.marchCasts or 0, now()))
            else
                local me0 = origin(State.hero)
                if issue(UO.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, nil, me0) then
                    State.marchPending = nil
                    logline("march_cancel reason=empty src=camp")
                end
            end
        end

        if now() - State.emptySince > K.ENGAGE_EMPTY_GRACE and (State.marchCasts or 0) >= K.MIN_CASTS_BEFORE_EMPTY then
            mark_spot_cleared(s)
            logline(string.format("engage_done reason=empty casts=%d dur=%.1f est=%.1f", State.marchCasts or 0,
                now() - (State.engageStart or now()), s.clearEst or 0)); engage_replan(); return
        end
    end
    if mana() < K.ESCAPE_MANA then
        logline("engage_bail reason=mana mana=" .. math.floor(mana())); go_return(); return
    end

    local mp = State.marchPending
    if mp then
        if MC.fired(mp) then
            State.marchCasts = State.marchCasts + 1
            State.marchPending = nil
            logline(string.format("march cast=%d t=%.1f", State.marchCasts or 0, now()))

        elseif now() > mp.expire then
            State.marchPending = nil
            logline("march issued_NOT_fired_retry")
        else
            return
        end
    end

    local btype = s.type
    if s.standSpot.paired and s.standSpot.partnerType and s.standSpot.partnerType > btype then
        btype = s.standSpot.partnerType
    end
    local base = marches_for(btype)
    if s.standSpot.paired and s.standSpot.clear == "clip" then
        base = base + K.CLIP_EXTRA_MARCHES
    end

    local budget = math.min(K.MAX_CLEAR_MARCHES + K.CLIP_EXTRA_MARCHES,
        Farm.ClearBudget(base, s.campEhp or 0, effective_march_dmg(),
            K.MIN_CASTS_BEFORE_EMPTY))
    if State.marchCasts >= budget then
        mark_spot_cleared(s)
        logline(string.format("engage_done reason=budget casts=%d budget=%d dur=%.1f est=%.1f%s", State.marchCasts, budget,
            now() - (State.engageStart or now()), s.clearEst or 0,
            (s.standSpot.paired and (" pair=" .. tostring(s.standSpot.clear))) or "")); engage_replan(); return
    end

    if ancient_engage(s) and ready(State.laser)
       and mana() >= K.ESCAPE_MANA + abil_mana(State.laser, K.LASER_MANA_FB) then
        local killhp = K.LASER_DMG[(State.laser and Ability.GetLevel(State.laser)) or 0] or 0

        local okv, lv = pcall(function()
            return Ability.GetLevelSpecialValueFor and Ability.GetLevelSpecialValueFor(State.laser, "laser_damage", -1)
        end)
        if okv and type(lv) == "number" and lv > 0 then killhp = lv end
        local tgt = killhp > 0 and laser_lasthit_target(s, neutrals, killhp) or nil
        if tgt and cast_target(State.laser, tgt) then
            logline(string.format("laser lasthit hp=%.0f", (Entity.GetHealth and Entity.GetHealth(tgt)) or 0)); return
        end
    end
    if s.standSpot.outpostPair and (State.marchCasts or 0) == 1
       and not s.standSpot.pairMarchBlinkTried and ready(State.march)
       and s.standSpot.partner then
        s.standSpot.pairMarchBlinkTried = true
        local me = origin(State.hero)
        local primaryDx, primaryDy = s.center.x - me.x, s.center.y - me.y
        local partnerDx, partnerDy = s.standSpot.partner.x - me.x, s.standSpot.partner.y - me.y
        local primaryD2 = primaryDx * primaryDx + primaryDy * primaryDy
        local partnerD2 = partnerDx * partnerDx + partnerDy * partnerDy
        local dx, dy = partnerDx, partnerDy
        if primaryD2 > partnerD2 then dx, dy = primaryDx, primaryDy end
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl > 1 then
            local shift = K.PAIR_MARCH_BLINK_SHIFT
            local dest = Map.SnapWalkable({
                x = me.x + dx / dl * shift,
                y = me.y + dy / dl * shift,
            }, { x = me.x, y = me.y })
            if math.sqrt((dest.x - me.x) ^ 2 + (dest.y - me.y) ^ 2) >= K.BLINK_TRAVEL_MIN
               and try_travel_blink(Vector(dest.x, dest.y, me.z)) then
                logline(string.format("pair_march_blink shift=%.0f dest=(%.0f,%.0f)",
                    shift, dest.x, dest.y))
                return
            end
            logline("pair_march_blink skipped")
        end
    end
    if ready(State.march) then
        local cp = march_cast_point_multi(s)
        local fired = cast_march(cp)
        if fired == nil then return end
        if fired then
            State.marchPending = { cdBefore = MC.now_cd(), expire = now() + 1.5 }
            local me = origin(State.hero)
            logline(string.format("march_aim src=%s stand=(%.0f,%.0f) cast=(%.0f,%.0f) hero=(%.0f,%.0f) camp=(%.0f,%.0f)%s",
                (s.standSpot.paired and "pair" or "single"),
                s.standSpot.stand.x, s.standSpot.stand.y, cp.x, cp.y, me.x, me.y, s.center.x, s.center.y,
                s.standSpot.partner and string.format(" pcamp=(%.0f,%.0f)", s.standSpot.partner.x, s.standSpot.partner.y) or ""))
        end
    elseif try_rearm() then
        logline("rearm")
    end
end

local function has_fountain_buff()
    local m = NPC.GetModifier(State.hero, "modifier_fountain_aura_buff")
    return m ~= nil
end

local function rearm_cancel_check()
    local p = State.rearmPending
    if not p or now() < p.due then return end
    State.rearmPending = nil
    if now() > p.due + 1.5 then return end
    local canceled = false
    if p.mcd and p.mcd > 4 then canceled = cd_remaining(State.march) > 0.5
    elseif p.kcd and p.kcd > 4 then canceled = cd_remaining(State.keen) > 0.5 end
    if canceled then
        State.rearmCancelT = now()
        logline(string.format("rearm_canceled mana=%.0f -> backoff %ds", mana(), K.REARM_CANCEL_BACKOFF_S))
    end
end

local function fsm_return()
    local h = State.hero
    State.fog = enemy_snapshot()
    if has_fountain_buff() then

        if not ready(State.keen) and (State.fountainRearms or 0) < 2 then
            if try_rearm() then
                State.fountainRearms = (State.fountainRearms or 0) + 1
                return
            end
        end
        local mmax = NPC.GetMaxMana(h) or 1

        local esc = K.ESCAPE_MANA

        local mthresh = math.min(mmax, math.max(mmax * K.REFILL_FRAC, esc, State.refillNeed or 0))
        local hpFull = (Entity.GetHealth(h) or 0) >= (Entity.GetMaxHealth(h) or 1) * K.REFILL_FRAC
        local mpFull = mana() >= mthresh
        if hpFull and mpFull then
            State.fsm = "DECIDE"; State.refillNeed = nil; State.fountainRearms = nil
            State.emergencyReturn = nil
            logline("refill_done")
        end
        return
    end
    State.fountainRearms = nil

    local mmax, hpmax = NPC.GetMaxMana(h) or 1, Entity.GetMaxHealth(h) or 1

    if not State.emergencyReturn
       and (not State.refillNeed or State.refillNeed <= mmax * K.RETURN_RESUME_FRAC)
       and mana() >= mmax * K.RETURN_RESUME_FRAC
       and (Entity.GetHealth(h) or 0) >= hpmax * K.RETURN_RESUME_FRAC
       and enemy_risk_at(origin(h)) < K.FARM_SAFE_RISK then
        State.fsm, State.spot = "DECIDE", nil
        if now() - (State.lastResumeLog or -99) > 2.0 then State.lastResumeLog = now(); logline("return resume mana_ok") end
        return
    end
    local fpf = friendly_fountain_pos()

    if fpf and origin(h):Distance2D(fpf) <= K.FOUNTAIN_WALK_IN then
        move_to(Vector(fpf.x, fpf.y, origin(h).z), "fountain_walkin")
        if now() - (State.lastWalkHomeLog or -99) > 2.0 then State.lastWalkHomeLog = now(); logline("return walk_in_fountain") end
        return
    end

    local mepos = origin(h)
    local pressured = not State.emergencyReturn
                      and (lane_unsafe(mepos)
                           or (channel_threat_near and channel_threat_near(mepos) ~= nil))
    if pressured and now() - (State.pressuredLogT or 0) > 2.0 then
        State.pressuredLogT = now(); logline("return pressured -> walk")
    end
    if not pressured and ready(State.keen) then
        if keen_home("return") then logline("return keen_base") end
    elseif not pressured and try_rearm() then
        logline("return rearm_reset_keen")
    else

        local fp = friendly_fountain_pos()
        if fp then

            if not try_travel_blink(Vector(fp.x, fp.y, origin(h).z)) then
                move_to(Vector(fp.x, fp.y, origin(h).z), "walk_home")
            end
            if now() - (State.lastWalkHomeLog or -99) > 2.0 then
                State.lastWalkHomeLog = now()

                local bt = NPC.GetItem(State.hero, "item_bottle", true)
                local bch = (bt and Item.GetCurrentCharges and Item.GetCurrentCharges(bt)) or -1
                logline(string.format("return walk_home mana=%.0f bottle=%d risk=%.2f", mana(), bch,
                    enemy_risk_at(origin(h))))
            end
        end
    end
end

local function bottle_tick()
    local bottle = NPC.GetItem(State.hero, "item_bottle", true)
    if not bottle or Ability.CanBeExecuted(bottle) ~= -1 or Item.GetCurrentCharges(bottle) <= 0 then return end
    if NPC.HasModifier(State.hero, "modifier_bottle_regeneration") then return end
    if is_channeling() then return end
    local h = State.hero

    if has_fountain_buff() then
        local needm = mana() < ((NPC.GetMaxMana and NPC.GetMaxMana(h)) or 1) - 5
        local needh = (Entity.GetHealth(h) or 0) < (Entity.GetMaxHealth(h) or 1) - 5
        if (needm or needh) and cast_no_target(bottle) then logline("bottle drink fountain") end
        return
    end
    local lowm = mana() < K.BOTTLE_MANA
    local lowh = (Entity.GetHealth(h) or 1) < (Entity.GetMaxHealth(h) or 1) * K.BOTTLE_HP_FRAC

    local ch = (Item.GetCurrentCharges and Item.GetCurrentCharges(bottle)) or 0

    local rnfAge = State.rearmNoFundT and (now() - State.rearmNoFundT) or nil

    local wantRearm = rnfAge ~= nil and rnfAge >= 0 and rnfAge < 1.0
                      and (State.rearmNoFundGap or math.huge) <= ch * K.BOTTLE_MANA_PER_CHARGE

    local knfAge = State.keenNoFundT and (now() - State.keenNoFundT) or nil
    local wantKeen = knfAge ~= nil and knfAge >= 0 and knfAge < 1.0
                     and (State.keenNoFundGap or math.huge) <= ch * K.BOTTLE_MANA_PER_CHARGE
    if not (lowm or lowh or wantRearm or wantKeen) then return end
    if enemy_risk_at(origin(State.hero)) >= K.SHOVE_SAFE_RISK then return end

    if cast_no_target(bottle) then
        logline(string.format("bottle drink why=%s raw=%.0f ch=%d gap=%s",
            (lowm and "lowm") or (lowh and "lowh") or (wantRearm and "rearm") or "keen", mana(), ch,
            (wantRearm and string.format("%.0f", State.rearmNoFundGap or 0))
                or (wantKeen and string.format("%.0f", State.keenNoFundGap or 0)) or "-"))
    end
end

local function mana_items_tick()
    local h = State.hero
    if is_channeling() then return end
    local mmax = NPC.GetMaxMana(h) or 0
    local deficit = mmax - mana()
    if deficit >= K.ARCANE_MANA then
        local ab = NPC.GetItem(h, "item_arcane_boots", true)
        if ab and Ability.CanBeExecuted(ab) == -1 then
            if cast_no_target(ab) then logline("arcane replenish"); return end
        end
    end
    if State.fsm == "ENGAGE" and deficit >= K.SOUL_RING_MANA
       and (Entity.GetHealth(h) or 0) >= (Entity.GetMaxHealth(h) or 1) * K.SR_HP_FRAC_MIN then
        local sr = NPC.GetItem(h, "item_soul_ring", true)
        if sr and Ability.CanBeExecuted(sr) == -1 then
            if cast_no_target(sr) then logline("soul_ring sacrifice") end
        end
    end
end

local function safe_lane_target()
    local t = now()
    local me = origin(State.hero)
    local cached = State.safeLaneTargetCache
    if cached and me and t - cached.t < 0.5
       and me:Distance(Vector(cached.x, cached.y, me.z)) < 500 then
        return cached.target
    end

    local best
    local candidates = {}
    for _, td in ipairs(MapData.TOWERS or {}) do
        if td.team == State.team and td.name and td.name:find("tower") then
            local tp = Vector(td.pos[1], td.pos[2], td.pos[3] or 256)
            local alive = State.world.tower_alive_at(tp, State.team, K.TOWER_ALIVE_R)
            if alive then
                candidates[#candidates + 1] = {
                    pos = tp, lane = td.name:match("tower%d+_(%w+)") or td.name,
                }
            end
        end
    end

    if now() >= (State.safeLaneBarracksScanAt or 0) then
        State.safeLaneBarracksScanAt = now() + 2
        State.safeLaneBarracks = {}
        for _, entity in ipairs(Entities.GetAll() or {}) do
            if Entity.GetClassName(entity) == "C_DOTA_BaseNPC_Barracks"
               and Entity.GetTeamNum(entity) == State.team then
                local name = Entity.GetUnitName(entity) or ""
                local lane = name:match("rax_%w+_(%w+)")
                local pos = origin(entity)
                if lane and pos then
                    State.safeLaneBarracks[#State.safeLaneBarracks + 1] = {
                        entity = entity, pos = pos, lane = lane,
                    }
                end
            end
        end
    end
    for _, barracks in ipairs(State.safeLaneBarracks or {}) do
        if Entity.IsAlive(barracks.entity) then
            candidates[#candidates + 1] = barracks
        end
    end

    for _, candidate in ipairs(candidates) do
        local tp, lane = candidate.pos, candidate.lane
        local blocked = false
        for _, h in ipairs(State.world.heroes()) do
            if h ~= State.hero and Entity.GetTeamNum(h) ~= State.team and Entity.IsAlive(h) and not Entity.IsDormant(h) then
                local hp = origin(h)
                if hp and hp:Distance(tp) <= K.SAFE_LANE_HERO_R then blocked = true; break end
            end
        end
        local creeps = enemy_lane_creeps_near(tp, K.SAFE_LANE_WAVE_R)
        if not blocked and #creeps > 0 and now() >= (State.safeLaneLaneUntil[lane] or 0) then
            local cx, cy = 0, 0
            for _, c in ipairs(creeps) do cx, cy = cx + c.pos.x, cy + c.pos.y end
            cx, cy = cx / #creeps, cy / #creeps
            local dx, dy = cx - tp.x, cy - tp.y
            local dl = math.sqrt(dx * dx + dy * dy)
            if dl < 1 then dl = 1 end
            local key = Map.CampKey({ x = cx, y = cy })
            local offset = math.min(K.SAFE_LANE_MARCH_CENTER_OFFSET,
                math.max(0, dl - K.SAFE_LANE_MARCH_CAST_RANGE))
            local aim = Vector(cx - dx / dl * offset, cy - dy / dl * offset, tp.z)
            local d = me:Distance(tp)
            if not best or d < best.dist then
                best = {
                    tower = tp, stand = tp, aim = aim, dist = d,
                    creeps = #creeps, key = key, lane = lane,
                }
            end
        end
    end
    if me then
        State.safeLaneTargetCache = { t = t, x = me.x, y = me.y, target = best }
    end
    return best
end

local function safe_lane_position_safe(pos, widen)
    return pos ~= nil
        and not lane_unsafe(pos)
        and enemy_risk_at(pos, widen) < K.KEEN_LAND_SAFE_RISK
end

local function safe_lane_task_safe(task, widen)
    if not task then return false end
    if not safe_lane_position_safe(task.tower, widen) then return false end
    if task.stand and (task.stand.x ~= task.tower.x or task.stand.y ~= task.tower.y)
       and not safe_lane_position_safe(task.stand, widen) then
        return false
    end
    if task.aim and not safe_lane_position_safe(task.aim, widen) then return false end
    return true
end

local function abort_safe_lane_task()
    State.safeLane = nil
    State.spot = nil
    State.fsm = "RETURN"
    State.emergencyReturn = true
    State.nextDecide = 0
end

local function safe_lane_farm_tick()
    local m = State.menu
    if not (m and m.enable and m.enable:IsToggled() and m.safeLaneFarm and m.safeLaneFarm:Get()) then
        State.safeLane = nil
        State.safeLanePriorityDone = false
        return false
    end
    local prioritizeSafeLane = m.kindJungle and m.kindJungle:Get()
    if not prioritizeSafeLane then State.safeLanePriorityDone = false end
    if prioritizeSafeLane and State.safeLanePriorityDone and not State.safeLane then return false end
    local t = now()
    if State.enemyThreatActive then
        if State.safeLane then abort_safe_lane_task() end
        return false
    end
    local s = State.safeLane
    if s and (t - s.started > 18 or (s.phase == "done" and t - s.doneAt > 2)) then State.safeLane = nil; s = nil end
    local target = safe_lane_target()
    local safeLaneWiden = math.min(K.COMMIT_WIDEN_MAX,
        K.COMMIT_APPROACH_SPEED * (K.KEEN_CHANNEL + K.COMMIT_STAND_S))
    if target and not safe_lane_task_safe(target, safeLaneWiden) then target = nil end
    if prioritizeSafeLane and not s and not target then
        State.safeLanePriorityDone = true
        logline("safe_lane_priority_done reason=no_safe_wave")
        return false
    end
    if not s and target then
        local spot = State.spot
        if (spot and spot.kind == "camp" and not prioritizeSafeLane)
           or State.fsm == "RETURN" then
            return false
        end
        local extraRearm = ready(State.keen) and 0 or 1
        local rearmCost = abil_mana(State.rearm, K.REARM_MANA_FB)
        local manaRequired = 2 * abil_mana(State.keen, K.KEEN_MANA_FB)
            + 2 * abil_mana(State.march, K.MARCH_MANA_FB)
            + (1 + extraRearm) * rearmCost
            + (extraRearm > 0 and K.ESCAPE_MANA or 0)
        local maxMana = NPC.GetMaxMana(State.hero) or 0
        if manaRequired > maxMana then
            logline(string.format("safe_lane_skip mana_budget_unreachable need=%.0f max=%.0f",
                manaRequired, maxMana))
            if prioritizeSafeLane then State.safeLanePriorityDone = true end
            return false
        end
        if mana() < manaRequired then
            State.refillNeed = math.max(State.refillNeed or 0, manaRequired)
            State.fsm = "RETURN"
            logline(string.format("safe_lane_mana_return mana=%.0f need=%.0f",
                mana(), manaRequired))
            return true
        end
    end
    if s then
        for _, h in ipairs(State.world.heroes()) do
            if h ~= State.hero and Entity.GetTeamNum(h) ~= State.team and Entity.IsAlive(h) and not Entity.IsDormant(h) then
                local hp = origin(h)
                if hp and hp:Distance(s.tower) <= K.SAFE_LANE_HERO_R then
                    abort_safe_lane_task()
                    return false
                end
            end
        end
    elseif target then
        State.spot = nil
        State.shoveLeaveBy = nil
        State.keenedSpot = false
        State.marchCasts = 0
        State.marchPending = nil
        State.fsm = "DECIDE"
        s = {
            tower = target.tower, stand = target.stand, aim = target.aim,
            key = target.key, lane = target.lane, phase = "travel",
            started = t, casts = 0,
        }
        State.safeLane = s
        logline(string.format("safe_lane_priority tower=(%.0f,%.0f) creeps=%d", target.tower.x, target.tower.y, target.creeps))
    else
        return false
    end
    if s and not safe_lane_task_safe(s, safeLaneWiden) then
        abort_safe_lane_task()
        return false
    end
    local me = origin(State.hero)
    if me and not s.arrivedAt and me:Distance(s.stand) <= 600 then
        s.arrivedAt = t
        State.safeLaneLaneUntil[s.lane] = t + K.SAFE_LANE_LANE_COOLDOWN_S
        logline(string.format("safe_lane_lane_cooldown lane=%s duration=%.0f",
            tostring(s.lane), K.SAFE_LANE_LANE_COOLDOWN_S))
    end
    if is_channeling() then return true end
    if s.phase == "travel" then
        if me:Distance(s.stand) > K.ARRIVE_DIST then
            if ready(State.keen) then
                if not safe_lane_task_safe(s, safeLaneWiden) then
                    abort_safe_lane_task()
                    return false
                end
                if cast_pos(State.keen, s.tower) then
                    local cast_cd = cd_remaining(State.keen)
                    local due = t + K.KEEN_CHANNEL + K.CHANNEL_PAD
                    s.phase = "travel_keen_pending"
                    s.keenPending = { cdBefore = cast_cd, expire = due + 1.5 }
                    State.channelUntil = due
                    State.keenPending = {
                        land = s.tower,
                        origin = { x = me.x, y = me.y },
                        due = due + 0.3,
                    }
                    verify_cast("keen", State.keen)
                    logline("safe_lane_keen_issue")
                end
            elseif ready(State.rearm) and try_rearm() then
                s.phase = "travel_rearm_pending"
                s.rearmExpire = t + 5.0
                logline("safe_lane_rearm_for_keen")
            end
            return true
        end
        s.phase = "cast"
    end
    if s.phase == "travel_keen_pending" then
        local pending = s.keenPending
        if pending and ((not ready(State.keen)) or cd_remaining(State.keen) > pending.cdBefore + 0.05) then
            s.keenPending = nil
            s.phase = "cast"
            logline("safe_lane_keen_fired")
        elseif not pending or t > pending.expire then
            s.keenPending = nil
            s.phase = "travel"
            logline("safe_lane_keen_not_fired")
        end
        return true
    end
    if s.phase == "travel_rearm_pending" then
        if ready(State.keen) then
            s.phase = "travel"
        elseif t > (s.rearmExpire or t) then
            s.phase = "travel"
            logline("safe_lane_rearm_for_keen_not_fired")
        end
        return true
    end
    if s.phase == "cast" then
        if s.casts >= K.SAFE_LANE_MAX_W then
            s.phase = "blink_home"
            s.blinkAt = t
            return true
        end
        if not ready(State.march) then
            s.phase = "rearm"
            return true
        end
        local fired = cast_march(s.aim)
        if fired == nil then return true end
        if fired then
            s.marchPending = { cdBefore = MC.now_cd(), expire = t + 1.5 }
            s.phase = "march_pending"
        end
        return true
    end
    if s.phase == "march_pending" then
        local pending = s.marchPending
        if pending and ((not ready(State.march)) or cd_remaining(State.march) > pending.cdBefore + 0.05) then
            s.marchPending = nil
            s.casts = s.casts + 1
            if s.casts < K.SAFE_LANE_MAX_W then
                s.phase = "rearm"
            else
                local cast_point = Ability.GetCastPoint and Ability.GetCastPoint(State.march)
                s.phase = "blink_home"
                s.blinkAt = t + ((type(cast_point) == "number" and cast_point) or 0.53) + K.CHANNEL_PAD
            end
        elseif not pending or t > pending.expire then
            s.marchPending = nil
            s.phase = "cast"
            logline("safe_lane_march_not_fired")
        end
        return true
    end
    if s.phase == "rearm" then
        if ready(State.march) then
            s.phase = "cast"
        elseif ready(State.rearm) and cast_no_target(State.rearm) then
            s.phase = "rearm_pending"
            s.rearmExpire = t + 4.0
        end
        return true
    end
    if s.phase == "rearm_pending" then
        if ready(State.march) then
            s.phase = "cast"
        elseif t > (s.rearmExpire or t) then
            s.phase = "rearm"
            logline("safe_lane_rearm_not_fired")
        end
        return true
    end
    if s.phase == "blink_home" then
        if t < (s.blinkAt or t) then return true end
        local fp = friendly_fountain_pos()
        if fp and try_travel_blink(fp) then
            logline("safe_lane_blink_home")
        end
        s.phase, s.doneAt = "done", t
        return true
    end
    if s.phase == "done" then
        if t - (s.doneAt or t) < 2 then return true end
        if prioritizeSafeLane then State.safeLanePriorityDone = true end
        State.safeLane = nil
        State.nextDecide = 0
        logline(string.format("safe_lane_done key=%s", tostring(s.key)))
    end
    return false
end

local function tick()
    process_verify()
    local snap = enemy_snapshot()
    State.fog = snap
    local me = origin(State.hero)
    State.sideLaneBlinkAbilities = State.sideLaneBlinkAbilities or {
        antimage_blink = true,
        queenofpain_blink = true,
        phantom_assassin_phantom_strike = true,
        riki_blink_strike = true,
        puck_ethereal_jaunt = true,
    }
    local function enemy_has_blink(enemy)
        if not enemy then return false end
        local cache = State.enemyBlinkCache
        local cached = cache[enemy]
        if cached and now() - cached.t < 1.0 then return cached.value end
        local found = false
        for i = 0, 31 do
            local ability = NPC.GetAbilityByIndex(enemy, i)
            local name = ability and Ability.GetName(ability) or ""
            if State.sideLaneBlinkAbilities[name] then found = true; break end
        end
        if not found then
            for i = 0, 16 do
                local item = NPC.GetItemByIndex(enemy, i)
                local name = item and Ability.GetName(item) or ""
                if name:sub(1, 5) == "item_" and name:find("blink", 1, true) then
                    found = true
                    break
                end
            end
        end
        cache[enemy] = { t = now(), value = found }
        return found
    end
    local threat, threat_edge
    for _, h in ipairs((snap and snap.heroes) or {}) do
        if h.pos then
            local dx, dy = h.pos.x - me.x, h.pos.y - me.y
            local d = math.sqrt(dx * dx + dy * dy)
            local hasBlink = enemy_has_blink(h.entity)
            local threatRadius = hasBlink and K.SIDE_LANE_THREAT_R or K.SIDE_LANE_NO_BLINK_R
            local known = h.visible or (h.age or math.huge) <= K.FOG_FRESH_S
            if known and d <= threatRadius and (not threat_edge or d < threat_edge) then
                threat, threat_edge = h, d
            end
        end
    end
    State.enemyThreatActive = threat ~= nil
    if not threat then
        State.enemyBlinkHandled = false
    elseif not State.enemyBlinkHandled then
        local fp = friendly_fountain_pos()
        local blinked = false
        local dest
        if fp and can_blink("escape", true, true) then
            local dx, dy = fp.x - me.x, fp.y - me.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 1 then
                local step = math.min(K.BLINK_RANGE - 50, d)
                dest = Map.SnapWalkable({
                    x = me.x + dx / d * step,
                    y = me.y + dy / d * step,
                }, { x = fp.x, y = fp.y })
                local progress = (dest.x - me.x) * dx / d + (dest.y - me.y) * dy / d
                if progress > 200 then blinked = do_blink(Vector(dest.x, dest.y, me.z)) end
            end
        end
        State.enemyBlinkHandled = true
        State.safeLane = nil
        State.spot = nil
        State.keenedSpot = false
        State.marchPending = nil
        State.rearmPending = nil
        State.rearmStepback = nil
        State.marchCasts = 0
        State.waitInfo = nil
        State.lastMove = nil
        State.moveSince = nil
        State.emergencyReturn = true
        State.fsm = "RETURN"
        State.nextDecide = 0
        logline(string.format("enemy_threat_return blink=%s edge=%.0f radius=%d dest=(%.0f,%.0f)",
            tostring(blinked), threat_edge or 0,
            enemy_has_blink(threat.entity) and K.SIDE_LANE_THREAT_R or K.SIDE_LANE_NO_BLINK_R,
            dest and dest.x or 0, dest and dest.y or 0))
        return
    end
    if safe_lane_farm_tick() then return end
    gold_tick()
    rearm_cancel_check()
    if handle_panic() then
        if has_fountain_buff() then State.panicUntil = 0 end

        if not is_channeling() and not has_fountain_buff() then
            if ready(State.keen) then
                keen_home("panic")
            else

                local fp = friendly_fountain_pos()
                local me = origin(State.hero)
                if fp and me then move_to(Vector(fp.x, fp.y, me.z), "panic_walk") end
            end
        end
        return
    end
    if is_channeling() then

        State.moveSince = now(); State.moveTrack = nil
        return
    end

    local deliberate_wait = State.waitInfo and now() - (State.waitInfo.t or 0) < 1.0
    if (State.fsm == "MOVE" or State.fsm == "RETURN") and not has_fountain_buff()
       and not deliberate_wait then
        local p = origin(State.hero)
        local tgt = (State.fsm == "RETURN") and friendly_fountain_pos()
                    or (State.spot and State.spot.standSpot and State.spot.standSpot.stand)
        local dist = tgt and p:Distance(Vector(tgt.x, tgt.y, p.z))
        if dist and dist > K.STUCK_FAR_DIST then
            local stuck
            State.stuckTrack, stuck = Map.Nav.Stuck(State.stuckTrack, dist, now(),
                { eps = K.STUCK_FROZEN_DIST, window = K.STUCK_TELEPORT_S })
            if stuck then

                local lm = State.lastMove
                local dox, doy = lm and (p.x - lm.x) or 0, lm and (p.y - lm.y) or 0
                logline(string.format(
                    "STUCK at (%.0f,%.0f) d=%.0f fsm=%s tgt=(%.0f,%.0f) ord=%s osrc=%s oage=%s dord=%s -> teleport unstick",
                    p.x, p.y, dist, tostring(State.fsm), tgt.x, tgt.y,
                    lm and string.format("(%.0f,%.0f)", lm.x, lm.y) or "nil",
                    lm and tostring(lm.src) or "nil",
                    lm and string.format("%.1f", now() - lm.t) or "nil",

                    lm and string.format("%.1f", math.sqrt(dox * dox + doy * doy)) or "nil"))

                if not lane_unsafe(p) then
                    if ready(State.keen) then keen_home("unstick") elseif ready(State.rearm) then try_rearm() end
                end
                State.spot = nil; State.fsm = "DECIDE"; State.nextDecide = 0; State.stuckTrack = nil
            end
        else
            State.stuckTrack = nil
        end
    else
        State.stuckTrack = nil
    end
    bottle_tick()
    mana_items_tick()
    if mana() < K.ESCAPE_MANA and State.fsm ~= "RETURN" then go_return() end
    if     State.fsm == "DECIDE" then fsm_decide()
    elseif State.fsm == "MOVE"   then fsm_move()
    elseif State.fsm == "ENGAGE" then fsm_engage()
    elseif State.fsm == "RETURN" then fsm_return() end
end

local farmerScanAt = 0
local function track_observed_farmers()
    local t = now()
    if t < farmerScanAt + 2.0 then return end
    farmerScanAt = t
    local all = State.world.camps()
    local neutrals = State.world.neutrals()
    local hpts, cands = {}, {}
    for _, e in ipairs(State.world.heroes()) do
        if e ~= State.hero and Entity.IsAlive(e) and not Entity.IsDormant(e) then
            local p = origin(e)
            if p then hpts[#hpts + 1] = { x = p.x, y = p.y, e = e } end
        end
    end
    if #hpts == 0 then return end
    for _, cd in ipairs(all) do
        if cd.center then
            local key = Map.CampKey(cd.center)
            if not is_cleared(key) then
                cands[#cands + 1] = { key = key, cx = cd.center.x, cy = cd.center.y }
            end
        end
    end
    for _, key in ipairs(Farm.ObservedFarmers(hpts, cands, State.campDwell,
            { radius = K.HERO_FARM_R, window = K.FARMER_DWELL_S,
              min_dwell = K.FARMER_DWELL_MIN_S, now = t })) do
        mark_cleared(key)
        for _, cnd in ipairs(cands) do
            if cnd.key == key then
                local r2 = K.HERO_FARM_R * K.HERO_FARM_R
                for _, h in ipairs(hpts) do
                    if h.e and Entity.GetTeamNum(h.e) == State.team
                       and (not NPC.IsIllusion or not NPC.IsIllusion(h.e)) then
                        local dx, dy = h.x - cnd.cx, h.y - cnd.cy
                        if dx * dx + dy * dy <= r2 then
                            local nm = (NPC.GetUnitName and NPC.GetUnitName(h.e)) or "?"
                            State.allyFarmers[nm] = (State.allyFarmers[nm] or 0) + 1
                        end
                    end
                end
                break
            end
        end
    end
end
local function setup_menu()
    local m = {}
    local localization = qLocalization.new({
        en = {
            menu_farm = "Farm",
            auto_farm = "Auto farm", farm_jungle = "Farm jungle camps", farm_lane = "Farm lane (shove)",
            blink_escape = "Use Blink: escape", blink_travel = "Use Blink: travel",
            safe_lane_farm = "Safe lane farm under allied towers",
            pair_map_bind = "Double-camp map",
            pair_map_title = "Double-camp selection",
            pair_map_instruction = "Click two camps to enable or disable a pair",
            pair_map_legend = "Green: selected pair   Red: not selected",
            pair_map_count = "Selected pairs: ",
        },
        ru = {
            menu_farm = "Фарм",
            auto_farm = "Автофарм", farm_jungle = "Фарм кемпов", farm_lane = "Фарм линии",
            blink_escape = "Использовать Blink для отхода", blink_travel = "Использовать Blink для перемещения",
            safe_lane_farm = "Сейвовый фарм линии под своими таверами",
            pair_map_bind = "Карта двойных кемпов",
            pair_map_title = "Выбор парных кемпов",
            pair_map_instruction = "Нажми на два лагеря, чтобы включить или отключить пару",
            pair_map_legend = "Зелёные — выбранные пары   Красные — не выбраны",
            pair_map_count = "Активных пар: ",
        },
    })
    local UI = localization.WrapLibrary(Menu)

    local tab = UI.Find("Scripts", "Scripts", "Tinker")
        or UI.Create("Scripts", "Scripts", "Tinker")
    local page = tab:Find("Settings") or tab:Create("Settings")
    local gFarm = page:Find("menu_farm") or page:Create("menu_farm")

    m.enable     = gFarm:Bind("auto_farm", Enum.ButtonCode.BUTTON_CODE_NONE, "\u{f11c}")
    m.kindJungle = gFarm:Switch("farm_jungle", true, "\u{f1bb}")
    m.kindLane   = gFarm:Switch("farm_lane", true, "\u{f0e7}")

    m.blinkEscape= gFarm:Switch("blink_escape", true, "\u{f0e7}")
    m.blinkTravel= gFarm:Switch("blink_travel", true, "\u{f124}")
    m.safeLaneFarm = gFarm:Switch("safe_lane_farm", false)
    m.pairMapBind = gFarm:Bind("pair_map_bind", Enum.ButtonCode.BUTTON_CODE_NONE)
    m.pairMapBind:Properties(nil, nil, true)

    State.menu = m
    State.pairMapLocalization = localization
    initialize_pair_selection()
    return m
end

local function draw_pair_map()
    if not pairPanel.open then
        pairPanel.rect = nil
        return
    end

    local screen = Render.ScreenSize()
    local width, height = math.min(680, screen.x - 24), math.min(520, screen.y - 24)
    if width < 360 or height < 300 then
        pairPanel.rect = nil
        return
    end
    local x, y = (screen.x - width) / 2, (screen.y - height) / 2
    local mapX, mapY = x + 22, y + 58
    local mapW, mapH = width - 44, height - 112
    local closeX, closeY = x + width - 28, y + 12
    local cursorX, cursorY = Input.GetCursorPos()
    local pressed = pairPanel.pendingClick
    pairPanel.pendingClick = false
    pairPanel.rect = { x, y, width, height }
    initialize_pair_selection()

    Render.FilledRect(Vec2(x, y), Vec2(x + width, y + height), Color(18, 22, 27, 245), 9)
    Render.Rect(Vec2(x, y), Vec2(x + width, y + height), Color(90, 105, 116, 230), 9, Enum.DrawFlags.None, 1)
    local localize = State.pairMapLocalization and State.pairMapLocalization.Get
    local function text(key, fallback)
        return localize and localize(key) or fallback
    end
    Render.Text(PAIR_PANEL_FONT, 16, text("pair_map_title", "Double-camp selection"), Vec2(x + 18, y + 14), Color(235, 240, 242, 255))
    Render.Text(PAIR_PANEL_FONT, 11, text("pair_map_instruction", "Click two camps to enable or disable a pair"), Vec2(x + 18, y + 36), Color(164, 177, 185, 255))
    Render.FilledRect(Vec2(closeX, closeY), Vec2(closeX + 16, closeY + 16), Color(82, 92, 99, 220), 4)
    Render.Text(PAIR_PANEL_FONT, 12, "x", Vec2(closeX + 4, closeY - 1), Color(235, 240, 242, 255))

    Render.FilledRect(Vec2(mapX, mapY), Vec2(mapX + mapW, mapY + mapH), Color(29, 43, 44, 255), 5)
    Render.Rect(Vec2(mapX, mapY), Vec2(mapX + mapW, mapY + mapH), Color(70, 92, 88, 255), 5, Enum.DrawFlags.None, 1)
    local function map_pos(camp)
        return Vec2(
            mapX + (camp.x + 9000) / 18000 * mapW,
            mapY + (9000 - camp.y) / 18000 * mapH
        )
    end
    local function map_key(a, b)
        return pair_selection_key(a, b)
    end

    local topLeft = map_pos({ x = -9000, y = 9000 })
    local bottomRight = map_pos({ x = 9000, y = -9000 })
    local riverA = map_pos({ x = -5000, y = 2500 })
    local riverB = map_pos({ x = 2500, y = -5000 })
    Render.Line(topLeft, bottomRight, Color(75, 93, 73, 110), 8)
    Render.Line(riverA, riverB, Color(49, 82, 100, 210), 13)
    Render.Line(map_pos({ x = -8200, y = -7100 }), map_pos({ x = 7600, y = 7400 }), Color(124, 111, 73, 105), 3)
    Render.Line(map_pos({ x = -8000, y = 7400 }), map_pos({ x = 7700, y = -7200 }), Color(124, 111, 73, 105), 3)

    local camps = pair_selection_catalog()
    local pairCount = 0
    local markerHits = {}
    for i = 1, #camps do
        local a = camps[i]
        for j = i + 1, #camps do
            local b = camps[j]
            if State.pairSelection[map_key(a, b)] then
                pairCount = pairCount + 1
                Render.Line(map_pos(a), map_pos(b), Color(86, 205, 139, 180), 2)
            end
        end
    end

    for index, camp in ipairs(camps) do
        local pos = map_pos(camp)
        local radius = camp.tier == 3 and 7 or (camp.tier == 2 and 6 or 5)
        local selected = pairPanel.selectedCamp and Map.CampKey(pairPanel.selectedCamp) == Map.CampKey(camp)
        local hasPair = false
        for _, other in ipairs(camps) do
            if other ~= camp and State.pairSelection[map_key(camp, other)] then
                hasPair = true
                break
            end
        end
        Render.FilledCircle(pos, radius + (selected and 4 or 2), Color(7, 13, 14, 245), 0, 1, 20)
        Render.FilledCircle(
            pos,
            radius,
            selected and Color(255, 209, 86, 255)
                or (hasPair and Color(90, 219, 145, 255) or Color(220, 93, 82, 255)),
            0,
            1,
            20
        )
        markerHits[#markerHits + 1] = { index = index, x = pos.x - 10, y = pos.y - 10, w = 20, h = 20 }
    end

    Render.Text(PAIR_PANEL_FONT, 11, text("pair_map_legend", "Green: selected pair   Red: not selected"), Vec2(x + 18, y + height - 42), Color(180, 192, 197, 255))
    Render.Text(PAIR_PANEL_FONT, 11, text("pair_map_count", "Selected pairs: ") .. tostring(pairCount), Vec2(x + 18, y + height - 24), Color(180, 192, 197, 255))

    if pressed then
        if Input.IsCursorInRect(closeX, closeY, 18, 18) then
            pairPanel.open = false
            pairPanel.selectedCamp = nil
            pairPanel.rect = nil
        else
            for _, hit in ipairs(markerHits) do
                if Input.IsCursorInRect(hit.x, hit.y, hit.w, hit.h) then
                    local camp = camps[hit.index]
                    select_pair_camp(camp)
                    break
                end
            end
        end
    end
end

local callbacks = {}

function callbacks.OnDraw()
    draw_pair_map()
end

function callbacks.OnKeyEvent(data)
    if not pairPanel.open or not data then return true end
    local key = data.key
    if key ~= Enum.ButtonCode.KEY_MOUSE1 then return true end

    local rect = pairPanel.rect
    local over = rect and Input.IsCursorInRect(rect[1], rect[2], rect[3], rect[4])
    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN and over then
        pairPanel.pendingClick = true
        pairPanel.mouseDown = true
        return false
    end
    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP and pairPanel.mouseDown then
        pairPanel.mouseDown = false
        return false
    end
    return true
end

function callbacks.OnUpdateEx()
    if not (State.menu and State.menu.enable and State.menu.enable:IsToggled()) then
        return
    end

    State.updateSerial = State.updateSerial + 1
    State.frame_t = now()

    if not Engine.IsInGame() then return end
    if State.menu and State.menu.pairMapBind and State.menu.pairMapBind:IsPressed() then
        pairPanel.open = not pairPanel.open
        pairPanel.selectedCamp = nil
        pairPanel.rect = nil
    end
    if not State.hero then
        local h = Heroes.GetLocal()
        if h then
            State.hero = h
            State.player = Players.GetLocal()
            State.team = Entity.GetTeamNum(h)
        end
    end
    if not State.hero then return end
    if not (State.march and State.rearm and State.keen and State.laser) then
        refresh_handles(State.hero)
    end

    track_observed_farmers()
    if now() >= (State.nextAutoScan or 0) then
        State.nextAutoScan = now() + K.AUTO_WAVESCAN_S
        run_lane_scan()
    end

    local alive = Entity.IsAlive(State.hero)
    if State.wasAlive == nil then State.wasAlive = alive end
    if alive ~= State.wasAlive then
        State.wasAlive = alive
        if not alive then
            State.deathT = now()
            local saves = {}
            local okp, p = pcall(origin, State.hero)

            local function up_or_cd(ab)
                local okr, r = pcall(ready, ab)
                if not okr then return ":?" end
                return r and ":up" or ":cd"
            end
            for _, n in ipairs(DEFAULT_SAVE_CHAIN) do
                local it = NPC.GetItem(State.hero, n, true)
                if it then saves[#saves + 1] = n:gsub("^item_", "") .. up_or_cd(it) end
            end

            local okb, bl = pcall(blink_item)
            if okb and bl then saves[#saves + 1] = "blink" .. up_or_cd(bl) end
            logline(string.format("DEATH t=%.1f fsm=%s spot=%s mana=%.0f pos=%s saves=%s",
                now(), tostring(State.fsm), tostring(State.spot and State.spot.kind), mana(),
                (okp and p) and string.format("(%.0f,%.0f)", p.x, p.y) or "?",
                (#saves > 0) and table.concat(saves, ",") or "NONE_OWNED"))
        else
            logline(string.format("RESPAWN t=%.1f down=%.1fs", now(), now() - (State.deathT or now())))
        end
    end

    if not alive then State.fsm = "RETURN"; State.spot = nil; return end
    tick()
end

function callbacks.OnModifierCreate(npc, modifier)
    if not (State.menu and State.menu.enable and State.menu.enable:IsToggled()) then
        return
    end
    if not State.hero or not modifier then return end
    local mod_name = Modifier.GetName(modifier)
    if not mod_name then return end
    if mod_name:find("modifier_tinker_", 1, true) == 1 then return end
    local canon = (ThreatData.CanonicalMod and ThreatData.CanonicalMod(mod_name)) or mod_name
    local entry = ThreatData.THREATS_ON_SELF[canon] or E2.EXTRA_THREATS[canon]
    local is_self = (npc == State.hero)
    if not entry and not is_self then return end

    local caster = Modifier.GetCaster(modifier)
    if caster == State.hero then return end
    if entry then
        E2.stamp_enemy_cast(canon, caster)
        if is_self then
            if not entry.extra then
                defense_dispatcher:TrySaveSelf("threat_on_self", canon, caster,
                                               nil, E2.THREAT_TO_ABILITY[canon], E2.on_save_fired)
            end
            if E2.FLEE_ROLES[entry.role] then E2.defense_flee(canon, caster) end
        end
    else

        local okh, eh = pcall(function()
            return caster and Entity.IsEntity(caster) and Target.IsEnemyHero(caster, State.hero)
        end)
        if not (okh and eh) then return end
        State.harvestLogT = State.harvestLogT or {}
        if now() - (State.harvestLogT[mod_name] or -10) > 2 then
            State.harvestLogT[mod_name] = now()
        end
    end
end

setup_menu()

State.is_our_hero = function()
    local h = Heroes.GetLocal()
    if not h or not Entity.IsEntity(h) or not Entity.IsNPC(h) then return false end
    return NPC.GetUnitName(h) == "npc_dota_hero_" .. HERO_KEY
end

local function update_automation_state()
    local active = State.menu
        and State.menu.enable
        and State.menu.enable:IsToggled()
        or false
    if State.lastEnableState == active then
        return active
    end

    local wasActive = State.lastEnableState
    State.lastEnableState = active
    logline(string.format("autofarm %s fsm=%s spot=%s",
        active and "ON" or "OFF",
        tostring(State.fsm),
        tostring(State.spot and State.spot.kind)))

    local investment = State.keenInvest
    if investment then
        if not active then
            investment.offT = now()
        elseif investment.offT then
            investment.excluded = (investment.excluded or 0)
                + (now() - investment.offT)
            investment.offT = nil
        end
    end

    if wasActive and not active then
        pairPanel.open = false
        pairPanel.rect = nil
        pairPanel.pendingClick = false
        pairPanel.mouseDown = false
        pairPanel.selectedCamp = nil

        if Engine.IsInGame()
            and State.is_our_hero()
            and State.hero
            and Entity.IsAlive(State.hero)
            and not is_channeling()
        then
            local player = Players.GetLocal()
            if player then
                Player.PrepareUnitOrders(
                    player,
                    UO.DOTA_UNIT_ORDER_STOP,
                    nil,
                    nil,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
                    State.hero,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false
                )
            end
        end

        State.fsm = "DECIDE"
        State.spot = nil
        State.safeLane = nil
        State.emergencyReturn = nil
        State.pendingVerify = nil
        State.marchPending = nil
        State.rearmPending = nil
        State.keenPending = nil
        State.waitInfo = nil
        State.lastMove = nil
        State.moveSince = nil
        State.moveTrack = nil
        State.stuckTrack = nil
        State.marchCasts = 0
        State.nextDecide = 0
        State.nextOrder = 0
    end

    return active
end

Escape.Vision.Init()
Escape.Vision.Wire(callbacks)

for cb_name, cb_fn in pairs(callbacks) do
    local callbackName = cb_name
    local callbackFunction = cb_fn
    callbacks[callbackName] = function(...)
        if not update_automation_state() then
            if callbackName == "OnKeyEvent"
                or callbackName == "OnPrepareUnitOrders"
            then
                return true
            end
            return
        end
        if not State.is_our_hero() then
            if callbackName == "OnKeyEvent"
                or callbackName == "OnPrepareUnitOrders"
            then
                return true
            end
            return
        end
        return callbackFunction(...)
    end
end

return callbacks
