--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces
     ~ author: qfun (qfun_g9s)
]]
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

local localization = qLocalization.new({
	en = {
		msa_group_main = "Main",
		msa_group_timing = "Timing",
		msa_enable = "Enable",
		msa_enable_tip = "After Mask of Madness is actually used, automatically rebuilds it into Echo Sabre",
		msa_auto_return = "Return to MoM automatically",
		msa_auto_return_tip = "When the stored Mask of Madness cooldown ends, rebuilds Echo Sabre back into MoM",
		msa_order_delay = "Order delay",
		msa_order_delay_tip = "Delay between inventory orders",
		msa_gear_extra = "Extra",
		msa_debug = "Debug log",
		msa_debug_tip = "Writes state changes and item lock states to debug.log",
	},
	ru = {
		msa_group_main = "Основное",
		msa_group_timing = "Тайминги",
		msa_enable = "Включить",
		msa_enable_tip = "После реального использования Mask of Madness автоматически пересобирает её в Echo Sabre",
		msa_auto_return = "Автовозврат в MoM",
		msa_auto_return_tip = "Когда сохранённый кулдаун Mask of Madness закончится, пересобирает Echo Sabre обратно в MoM",
		msa_order_delay = "Задержка приказов",
		msa_order_delay_tip = "Пауза между приказами инвентарю",
		msa_gear_extra = "Дополнительно",
		msa_debug = "Отладочный лог",
		msa_debug_tip = "Пишет смены состояний и lock-состояния предметов в debug.log",
	},
})

local UI = localization.WrapLibrary(Menu)
local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "MoM Sabre Abuse")
	tab:Icon("\u{f013}")

	local page = tab:Create("Settings")
	local g_main = page:Create("msa_group_main", Enum.GroupSide.Left)
	local g_timing = page:Create("msa_group_timing", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("msa_enable", false, "\u{f011}")
	ui.enable:ToolTip("msa_enable_tip")

	ui.auto_return = g_main:Switch("msa_auto_return", true, "\u{f11b}")
	ui.auto_return:ToolTip("msa_auto_return_tip")

	local g_extra = ui.enable:Gear("msa_gear_extra")
	ui.debug = g_extra:Switch("msa_debug", false, "\u{f188}")
	ui.debug:ToolTip("msa_debug_tip")

	ui.order_delay = g_timing:Slider("msa_order_delay", 0.03, 0.25, 0.08, "%.2f s")
	ui.order_delay:Icon("\u{f1de}")
	ui.order_delay:ToolTip("msa_order_delay_tip")
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.auto_return:Disabled(not on)
	ui.order_delay:Disabled(not on)
	ui.debug:Disabled(not on)
end

ui.enable:SetCallback(refresh_disabled, true)

local K = {
	mom = "item_mask_of_madness",
	echo = "item_echo_sabre",
	broadsword = "item_broadsword",
	morbid = "item_lifesteal",
	ogre = "item_ogre_axe",
	void = "item_void_stone",
}

local state = {
	phase = "idle",
	was_enabled = false,
	armed = false,
	last_mom_cd = 0,
	ready_at = 0,
	next_order_at = 0,
	deadline = 0,
}

local function log(text)
	if ui.debug:Get() then
		Log.Write("[MoM Sabre Abuse] " .. text)
	end
end

local function get_item(hero, name)
	return NPC.GetItem(hero, name, false)
end

local function lock_text(item)
	if not item then
		return "-"
	end
	return Item.IsCombineLocked(item) and "L" or "U"
end

local function inventory_text(hero)
	return "mom=" .. lock_text(get_item(hero, K.mom))
		.. " echo=" .. lock_text(get_item(hero, K.echo))
		.. " morbid=" .. lock_text(get_item(hero, K.morbid))
		.. " broad=" .. lock_text(get_item(hero, K.broadsword))
		.. " ogre=" .. lock_text(get_item(hero, K.ogre))
		.. " void=" .. lock_text(get_item(hero, K.void))
end

local function set_phase(phase, hero, extra)
	state.phase = phase
	if extra then
		log(phase .. " | " .. extra .. " | " .. inventory_text(hero))
	else
		log(phase .. " | " .. inventory_text(hero))
	end
end

local function reset(hero, reason)
	if reason then
		log("reset: " .. reason .. " | " .. inventory_text(hero))
	end
	state.phase = "idle"
	state.ready_at = 0
	state.next_order_at = 0
	state.deadline = 0
	local mom = hero and get_item(hero, K.mom) or nil
	if mom then
		local cd = Ability.GetCooldown(mom)
		state.last_mom_cd = cd
		state.armed = cd <= 0.05
	else
		state.last_mom_cd = 0
		state.armed = false
	end
end

local function issue_item_order(player, hero, order, item)
	Player.PrepareUnitOrders(
		player,
		order,
		nil,
		Vector(0, 0, 0),
		item,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
		hero,
		false,
		false,
		false,
		true,
		nil,
		false
	)
end

local function disassemble(player, hero, item)
	issue_item_order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_DISASSEMBLE_ITEM, item)
end

local function toggle_lock(player, hero, item, should_lock, now)
	if not item then
		return false
	end

	if Item.IsCombineLocked(item) == should_lock then
		return false
	end

	issue_item_order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_SET_ITEM_COMBINE_LOCK, item)
	state.next_order_at = now + ui.order_delay:Get()
	return true
end

local function requirements_ok(hero)
	return get_item(hero, K.ogre) ~= nil and get_item(hero, K.void) ~= nil
end

local function start_mom_split(player, hero, mom, now)
	if not requirements_ok(hero) then
		state.armed = false
		log("MoM used, but Ogre Axe or Void Stone is missing")
		return
	end

	if not Item.IsDisassemblable(mom) then
		state.armed = false
		log("MoM used, but Item.IsDisassemblable returned false")
		return
	end

	local cooldown = Ability.GetCooldown(mom)
	if cooldown <= 0 then
		cooldown = Ability.GetCooldownLength(mom)
	end

	state.ready_at = now + cooldown
	state.deadline = now + 1.50
	state.next_order_at = now + ui.order_delay:Get()
	state.armed = false

	disassemble(player, hero, mom)
	set_phase("wait_mom_split", hero, string.format("cd=%.2f", cooldown))
end

local function update_idle(player, hero, now)
	local mom = get_item(hero, K.mom)
	if not mom then
		state.armed = false
		state.last_mom_cd = 0
		return
	end

	local cooldown = Ability.GetCooldown(mom)
	local since = Ability.SecondsSinceLastUse(mom)

	if cooldown <= 0.05 then
		state.armed = true
	end

	local just_used = false
	if state.armed and cooldown > 0.20 then
		if since >= 0 and since <= 1.00 then
			just_used = true
		elseif state.last_mom_cd <= 0.05 then
			just_used = true
		end
	end

	state.last_mom_cd = cooldown

	if just_used then
		start_mom_split(player, hero, mom, now)
	end
end

local function update_wait_mom_split(hero, now)
	if not get_item(hero, K.mom) then
		state.deadline = now + 3.00
		state.next_order_at = now + ui.order_delay:Get()
		set_phase("build_echo", hero)
		return
	end

	if now >= state.deadline then
		reset(hero, "MoM did not disassemble")
	end
end

local function update_build_echo(player, hero, now)
	if get_item(hero, K.echo) then
		state.deadline = 0
		state.next_order_at = 0
		set_phase("echo_active", hero)
		return
	end

	if now >= state.deadline then
		reset(hero, "Echo Sabre was not assembled")
		return
	end

	if now < state.next_order_at then
		return
	end

	local morbid = get_item(hero, K.morbid)
	local broadsword = get_item(hero, K.broadsword)
	local ogre = get_item(hero, K.ogre)
	local void = get_item(hero, K.void)

	if not morbid or not broadsword or not ogre or not void then
		return
	end

	if toggle_lock(player, hero, morbid, true, now) then
		return
	end
	if toggle_lock(player, hero, ogre, false, now) then
		return
	end
	if toggle_lock(player, hero, void, false, now) then
		return
	end
	if toggle_lock(player, hero, broadsword, false, now) then
		return
	end
end

local function update_echo_active(player, hero, now)
	if get_item(hero, K.mom) then
		reset(hero, "MoM already exists")
		return
	end

	if not ui.auto_return:Get() then
		return
	end

	if state.ready_at <= 0 or now < state.ready_at then
		return
	end

	local echo = get_item(hero, K.echo)
	if not echo then
		log("Return time reached, but Echo Sabre is missing")
		state.ready_at = 0
		return
	end

	if not Item.IsDisassemblable(echo) then
		log("Return time reached, but Echo Sabre is not disassemblable")
		state.ready_at = 0
		return
	end

	disassemble(player, hero, echo)
	state.deadline = now + 1.50
	state.next_order_at = now + ui.order_delay:Get()
	set_phase("wait_echo_split", hero)
end

local function update_wait_echo_split(hero, now)
	if not get_item(hero, K.echo) then
		state.deadline = now + 3.00
		state.next_order_at = now + ui.order_delay:Get()
		set_phase("build_mom", hero)
		return
	end

	if now >= state.deadline then
		reset(hero, "Echo Sabre did not disassemble")
	end
end

local function update_build_mom(player, hero, now)
	local mom = get_item(hero, K.mom)
	if mom then
		local cooldown = Ability.GetCooldown(mom)
		state.last_mom_cd = cooldown
		state.armed = cooldown <= 0.05
		state.ready_at = 0
		state.deadline = 0
		state.next_order_at = 0
		set_phase("idle", hero, "MoM assembled")
		return
	end

	if now >= state.deadline then
		reset(hero, "MoM was not assembled")
		return
	end

	if now < state.next_order_at then
		return
	end

	local morbid = get_item(hero, K.morbid)
	local broadsword = get_item(hero, K.broadsword)
	local ogre = get_item(hero, K.ogre)
	local void = get_item(hero, K.void)

	if not morbid or not broadsword or not ogre or not void then
		return
	end

	if toggle_lock(player, hero, ogre, true, now) then
		return
	end
	if toggle_lock(player, hero, void, true, now) then
		return
	end
	if toggle_lock(player, hero, broadsword, false, now) then
		return
	end
	if toggle_lock(player, hero, morbid, false, now) then
		return
	end
end

local script = {}

function script.OnUpdate()
	local enabled = ui.enable:Get()

	if not enabled then
		if state.was_enabled then
			state.was_enabled = false
			local hero = Heroes.GetLocal()
			reset(hero, "disabled")
		end
		return
	end

	local hero = Heroes.GetLocal()
	local player = Players.GetLocal()
	if not hero or not player then
		return
	end

	if not state.was_enabled then
		state.was_enabled = true
		reset(hero, "enabled")
	end

	local now = GameRules.GetGameTime()

	if state.phase == "idle" then
		update_idle(player, hero, now)
	elseif state.phase == "wait_mom_split" then
		update_wait_mom_split(hero, now)
	elseif state.phase == "build_echo" then
		update_build_echo(player, hero, now)
	elseif state.phase == "echo_active" then
		update_echo_active(player, hero, now)
	elseif state.phase == "wait_echo_split" then
		update_wait_echo_split(hero, now)
	elseif state.phase == "build_mom" then
		update_build_mom(player, hero, now)
	else
		reset(hero, "unknown phase")
	end
end

function script.OnGameEnd()
	state.phase = "idle"
	state.was_enabled = false
	state.armed = false
	state.last_mom_cd = 0
	state.ready_at = 0
	state.next_order_at = 0
	state.deadline = 0
end

return script
