local VERSION = "1.0.0"
local script = {}

local ORDER_CAST = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION
local ORDER_STOP = Enum.UnitOrder.DOTA_UNIT_ORDER_STOP
local ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY

local OFFSET = 0.5
local FORWARD_CONE = 20

local SPIRIT_FORM_HERO = "npc_dota_hero_keeper_of_the_light"

local SPELLS = {
	{ "keeper_of_the_light_illuminate", "Keeper of the Light", true },
	{ "pudge_meat_hook",                "Pudge", true },
	{ "lion_impale",                    "Lion", true },
	{ "earthshaker_fissure",            "Earthshaker", true },
	{ "magnataur_shockwave",            "Magnus", true },
	{ "lina_dragon_slave",              "Lina", true },
	{ "dragon_knight_breathe_fire",     "Dragon Knight", true },
	{ "death_prophet_carrion_swarm",    "Death Prophet", true },
	{ "drow_ranger_wave_of_silence",    "Drow Ranger", true },
	{ "nyx_assassin_impale",            "Nyx Assassin", true },
	{ "jakiro_ice_path",                "Jakiro", true },
	{ "jakiro_macropyre",               "Jakiro", true },
	{ "jakiro_dual_breath",             "Jakiro", true },
	{ "invoker_tornado",                "Invoker", true },
	{ "invoker_deafening_blast",        "Invoker", true },
	{ "windrunner_powershot",           "Windranger", true },
	{ "mirana_arrow",                   "Mirana", true },
	{ "snapfire_scatterblast",          "Snapfire", true },
	{ "grimstroke_dark_artistry",       "Grimstroke", true },
	{ "hoodwink_sharpshooter",          "Hoodwink", true },
	{ "mars_spear",                     "Mars", true },
	{ "rattletrap_hookshot",            "Clockwerk", true },
	{ "spectre_spectral_dagger",        "Spectre", true },
	{ "ringmaster_impalement",          "Ringmaster", true },
	{ "queenofpain_sonic_wave",         "Queen of Pain", true },
	{ "vengefulspirit_wave_of_terror",  "Vengeful Spirit", true },
	{ "elder_titan_earth_splitter",     "Elder Titan", true },
	{ "mars_gods_rebuke",               "Mars", true },
	{ "clinkz_burning_barrage",         "Clinkz", true },
	{ "weaver_the_swarm",               "Weaver", true },
	{ "troll_warlord_whirling_axes_ranged", "Troll Warlord", true },
	{ "treant_natures_grasp",           "Treant Protector", true },
	{ "puck_illusory_orb",              "Puck", true },
	{ "primal_beast_onslaught",         "Primal Beast", true },
	{ "ancient_apparition_ice_blast",   "Ancient Apparition", true },
	{ "venomancer_venomous_gale",       "Venomancer", true },
	{ "kunkka_tidal_wave",              "Kunkka", true },
}
local TR = {
	en = { tab = "Back Cast", main = "Main", settings = "Settings",
	       enable = "Enable", spells = "What works", off_after = "Turn off after",
	       never = "Never", minutes = "%d min",
	       off_tip = "Turns the script off at this minute of the game. 0 - never.",
	       work_moving = "Work while moving",
	       resume = "Resume previous action",
	       resume_tip = "After the spell goes off, the hero returns to what he was doing - running, attacking, attack-moving. Only the last order is restored, a shift-queue chain is not.",
	       work_tip = "WARNING: adds a ~0.3-0.5 sec delay before the cast while the hero is moving or busy with an action. Off - while moving the spell is cast normally, with no delay.",
	       use_key = "Work by key",
	       use_key_tip = "Off - the script is always on. On - it only works while the key below says so.",
	       key = "Key", key_mode = "Key mode",
	       mode_hold = "Hold", mode_toggle = "Toggle",
	       key_tip = "Hold - works while the key is held. Toggle - press once to turn on, press again to turn off." },
	ru = { tab = "Скиллы спиной", main = "Главное", settings = "Настройки",
	       enable = "Включить", spells = "Что работает", off_after = "Выключить после",
	       never = "Не выключать", minutes = "%d мин",
	       off_tip = "Выключит скрипт на этой минуте игры. 0 - не выключать.",
	       work_moving = "Работать на бегу",
	       resume = "Продолжать действие",
	       resume_tip = "После срабатывания спелла герой возвращается к тому, что делал - бежал, атаковал, шёл в атаку. Восстанавливается только последний приказ, цепочка через shift - нет.",
	       work_tip = "ВНИМАНИЕ: даёт задержку ~0.3-0.5 сек перед кастом, пока герой бежит или занят действием. Выключено - на бегу скилл уходит обычным образом, без задержки.",
	       use_key = "Работать по клавише",
	       use_key_tip = "Выключено - скрипт работает всегда. Включено - работает только когда скажет клавиша ниже.",
	       key = "Клавиша", key_mode = "Режим клавиши",
	       mode_hold = "Удержание", mode_toggle = "Переключение",
	       key_tip = "Удержание - работает, пока клавиша зажата. Переключение - нажал включил, нажал выключил." },
}

local L = qLocalization and qLocalization.new(TR) or nil

local function reg(widget, key)
	if L then L.Register(widget, key) end
end

local function tr(key)
	return L and L.Get(key) or TR.en[key]
end

local tab = Menu.Create("General", "Main", TR.en.tab)
tab:Icon("\u{f0e2}")
reg(tab, "tab")

local sub = tab:Create(TR.en.main)
reg(sub, "main")

local group = sub:Create(TR.en.settings)
reg(group, "settings")

local ui = {}

ui.enabled = group:Switch(TR.en.enable, false, "\u{f0e2}")
reg(ui.enabled, "enable")

local items, tips = {}, {}
for i = 1, #SPELLS do
	local name = SPELLS[i][1]
	items[i] = { name, "panorama/images/spellicons/" .. name .. "_png.vtex_c", SPELLS[i][3] == true }
	tips[i] = SPELLS[i][2]
end

ui.spells = group:MultiSelect(TR.en.spells, items, true)
reg(ui.spells, "spells")
pcall(function() ui.spells:UpdateToolTips(tips) end)

ui.off_after = group:Slider(TR.en.off_after, 0, 20, 0, function(value)
	if value == 0 then return tr("never") end
	return tr("minutes")
end)
reg(ui.off_after, "off_after")
pcall(function() ui.off_after:ToolTip(tr("off_tip")) end)

ui.work_moving = group:Switch(TR.en.work_moving, false)
reg(ui.work_moving, "work_moving")
pcall(function() ui.work_moving:ToolTip(tr("work_tip")) end)

ui.resume = group:Switch(TR.en.resume, false)
reg(ui.resume, "resume")
pcall(function() ui.resume:ToolTip(tr("resume_tip")) end)

ui.use_key = group:Switch(TR.en.use_key, false)
reg(ui.use_key, "use_key")
pcall(function() ui.use_key:ToolTip(tr("use_key_tip")) end)

ui.key = group:Bind(TR.en.key, Enum.ButtonCode.KEY_NONE)
reg(ui.key, "key")
pcall(function() ui.key:ToolTip(tr("key_tip")) end)

ui.key_mode = group:Combo(TR.en.key_mode, { tr("mode_hold"), tr("mode_toggle") }, 0)
reg(ui.key_mode, "key_mode")

local function sync_key_mode()
	pcall(function() ui.key:Properties(nil, nil, ui.key_mode:Get() == 1) end)
end

pcall(function() ui.key_mode:SetCallback(sync_key_mode, true) end)

local function sync_visibility()
	local on = ui.enabled:Get()
	local keyed = on and ui.use_key:Get()
	pcall(function() ui.spells:Visible(on) end)
	pcall(function() ui.off_after:Visible(on) end)
	pcall(function() ui.work_moving:Visible(on) end)
	pcall(function() ui.resume:Visible(on and ui.work_moving:Get()) end)
	pcall(function() ui.use_key:Visible(on) end)
	pcall(function() ui.key:Visible(keyed) end)
	pcall(function() ui.key_mode:Visible(keyed) end)
end

pcall(function() ui.enabled:SetCallback(sync_visibility, true) end)
pcall(function() ui.use_key:SetCallback(sync_visibility, true) end)
pcall(function() ui.work_moving:SetCallback(sync_visibility, true) end)

local reissuing = false
local pending = nil
local resuming = nil
local last_order = nil

local RESUMABLE = {
	[Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION] = true,
	[Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE] = true,
	[Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET] = true,
	[Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET] = true,
}

local STILL = 0.05
local STILL_FRAMES = 3
local track = { x = nil, y = nil, still = 0 }

local function track_update(hero)
	local o = Entity.GetAbsOrigin(hero)
	if track.x == nil then
		track.x, track.y, track.still = o.x, o.y, 0
		return
	end
	local mx, my = o.x - track.x, o.y - track.y
	track.x, track.y = o.x, o.y
	if math.sqrt(mx * mx + my * my) < STILL then
		track.still = track.still + 1
	else
		track.still = 0
	end
end

local function cast(hero, ability, dx, dy, queue)
	local o = Entity.GetAbsOrigin(hero)
	local pos = Vector(o.x + dx * OFFSET, o.y + dy * OFFSET, o.z)

	reissuing = true
	Player.PrepareUnitOrders(
		Players.GetLocal(), ORDER_CAST, nil, pos, ability,
		ISSUER, hero, queue, false, false, true, "bc_c3_dm", false
	)
	reissuing = false
end

local function in_spirit_form(hero)
	local okn, unit = pcall(NPC.GetUnitName, hero)
	if not okn or unit ~= SPIRIT_FORM_HERO then return false end

	local okm, mods = pcall(NPC.GetModifiers, hero)
	if not okm or type(mods) ~= "table" then return false end

	for i = 1, #mods do
		local ok, mname = pcall(Modifier.GetName, mods[i])
		if ok and type(mname) == "string" and mname:find("spirit_form", 1, true) then
			return true
		end
	end
	return false
end

local function key_active()
	if not ui.use_key:Get() then return true end
	if ui.key:Get() == Enum.ButtonCode.KEY_NONE then return true end
	local ok, state
	if ui.key_mode:Get() == 1 then
		ok, state = pcall(function() return ui.key:IsToggled() end)
	else
		ok, state = pcall(function() return ui.key:IsDown() end)
	end
	if not ok then return true end
	return state and true or false
end

local function past_limit()
	local limit = ui.off_after:Get()
	if limit <= 0 then return false end
	local ok, clock = pcall(GameRules.GetDOTATime, false, false)
	return ok and type(clock) == "number" and clock >= limit * 60
end

local function resume_step(hero)
	if resuming == nil then return end

	local now = GameRules.GetGameTime()
	if now - resuming.t > 2 then
		resuming = nil
		return
	end

	local okp, inphase = pcall(Ability.IsInAbilityPhase, resuming.ability)
	if okp and inphase then
		resuming.seen = true
		return
	end
	if not resuming.seen and now - resuming.t < 0.1 then return end

	local oks, safe = pcall(Humanizer.IsSafeToCastOrder)
	if oks and safe == false then return end

	local o = resuming.order
	local pos = Vector(o.x or 0, o.y or 0, o.z or 0)

	reissuing = true
	Player.PrepareUnitOrders(
		Players.GetLocal(), o.order, o.target, pos, nil,
		ISSUER, hero, false, false, false, true, "bc_r3_dm", false
	)
	reissuing = false

	resuming = nil
end

function script.OnPrepareUnitOrders(data)
	if reissuing then return true end

	if RESUMABLE[data.order] then
		last_order = { order = data.order, target = data.target }
		if data.position then
			last_order.x, last_order.y, last_order.z =
				data.position.x, data.position.y, data.position.z
		end
	end

	if not ui.enabled:Get() then return true end
	if past_limit() then return true end
	if not key_active() then return true end
	if data.order ~= ORDER_CAST then return true end
	if data.ability == nil or data.position == nil then return true end

	local hero = Heroes.GetLocal()
	if hero == nil or data.npc == nil then return true end
	if Entity.GetIndex(data.npc) ~= Entity.GetIndex(hero) then return true end

	if in_spirit_form(hero) then return true end

	local name = Ability.GetName(data.ability)
	if name == nil or not ui.spells:Get(name) then return true end

	local o = Entity.GetAbsOrigin(hero)
	local dx, dy = data.position.x - o.x, data.position.y - o.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < 1 then return true end
	dx, dy = dx / dist, dy / dist

	local queue = data.queue and true or false

	local f = Entity.GetRotation(hero):GetForward()
	local fl = math.sqrt(f.x * f.x + f.y * f.y)
	if fl > 0.001 then
		local c = (dx * f.x + dy * f.y) / fl
		if c > 1 then c = 1 elseif c < -1 then c = -1 end
		if math.deg(math.acos(c)) < FORWARD_CONE then return true end
	end

	local running = true
	local okr, r = pcall(NPC.IsRunning, hero)
	if okr then running = r end

	if track.still >= STILL_FRAMES and not running then
		cast(hero, data.ability, dx, dy, queue)
		return false
	end

	if not ui.work_moving:Get() then return true end

	reissuing = true
	Player.PrepareUnitOrders(
		Players.GetLocal(), ORDER_STOP, nil, Vector(0, 0, 0), nil,
		ISSUER, hero, false, false, false, true, "bc_s3_dm", false
	)
	reissuing = false

	pending = { ability = data.ability, dx = dx, dy = dy, queue = queue,
	            t = GameRules.GetGameTime(), resume = last_order }
	track.still = 0
	return false
end

function script.OnUpdate()
	local hero = Heroes.GetLocal()
	if hero == nil then
		pending = nil
		track.x = nil
		return
	end

	track_update(hero)
	resume_step(hero)

	if pending == nil then return end

	local timeout = GameRules.GetGameTime() - pending.t > 0.5
	if track.still < 2 and not timeout then return end

	cast(hero, pending.ability, pending.dx, pending.dy, pending.queue)

	if ui.resume:Get() and pending.resume then
		resuming = { ability = pending.ability, order = pending.resume,
		             t = GameRules.GetGameTime(), seen = false }
	end

	pending = nil
end

function script.OnGameEnd()
	pending = nil
	resuming = nil
	last_order = nil
	track.x = nil
end

return script
