---@diagnostic disable: undefined-global
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

local script = {}

local localization = qLocalization.new({
    en = {
        krd_group_main = "Raptor Dance dispel",
        krd_enabled = "Enabled",
        krd_enabled_tip = "When you cast Kazurai Katana yourself, the script casts\nRaptor Dance during the Katana animation\nand switches to the Sai stance right after it.",
        krd_delay = "Stance switch delay (ms)",
        krd_delay_tip = "Extra time between the Raptor Dance order and the stance switch.\n0 = the next tick (the switch never goes in the same tick\nas Raptor Dance, or the ultimate is not cast).",
        krd_panel_error = "Kez Raptor dispel: error",
        krd_panel_menu_failed = "Kez Raptor dispel: menu failed",
    },
    ru = {
        krd_group_main = "Развеивание через Raptor Dance",
        krd_enabled = "Включено",
        krd_enabled_tip = "Когда ты сам кастуешь Kazurai Katana, скрипт во время\nеё анимации кастует Raptor Dance и сразу за ним\nменяет стойку на Sai.",
        krd_delay = "Задержка смены стойки (мс)",
        krd_delay_tip = "Дополнительное время между приказом Raptor Dance\nи сменой стойки. 0: следующий тик (в том же тике\nсмена стойки не идёт, иначе ульта не кастуется).",
        krd_panel_error = "Kez Raptor dispel: ошибка",
        krd_panel_menu_failed = "Kez Raptor dispel: меню не создалось",
    },
})

local Menu = localization.WrapLibrary(Menu)

local C = {
    hero = "npc_dota_hero_kez",
    katana = "kez_kazurai_katana",
    raptor = "kez_raptor_dance",
    switch = "kez_switch_weapons",
    sai = "kez_falcon_rush",
    identifier = "kez_raptor_dispel",
    armWait = 2.0,
    resultAfter = 0.2,
}

local UI = {}
local S = { ready = false, menuError = nil, error = nil, font = nil, step = "idle", at = 0, raptorAt = 0 }
local A = {}

function A.log(message, data)
    if type(ai_bridge) ~= "table" or type(ai_bridge.mcp_log) ~= "function" then return end
    pcall(ai_bridge.mcp_log, "info", message, data)
end

function A.initMenu()
    local side = (type(Enum) == "table" and Enum.GroupSide) or {}
    local section = Menu.Create("Heroes", "Hero List", "Kez", "Raptor Dispel")
    local main = section:Create("krd_group_main", side.Left)
    UI.enabled = main:Switch("krd_enabled", true, "panorama/images/spellicons/kez_raptor_dance_png.vtex_c")
    UI.enabled:ToolTip("krd_enabled_tip")
    UI.delay = main:Slider("krd_delay", 0, 500, 0, "%d")
    UI.delay:ToolTip("krd_delay_tip")
    return true
end

function A.ability(hero, name)
    local ability = NPC.GetAbility(hero, name)
    if ability == nil or Ability.GetLevel(ability) <= 0 then return nil end
    return ability
end

function A.state(hero)
    local switch = A.ability(hero, C.switch)
    local sai = NPC.GetAbility(hero, C.sai)
    local raptor = A.ability(hero, C.raptor)
    return {
        switch_found = switch ~= nil,
        switch_hidden = switch ~= nil and Ability.IsHidden(switch),
        switch_castable = switch ~= nil and Ability.IsCastable(switch, NPC.GetMana(hero)),
        sai = sai ~= nil and not Ability.IsHidden(sai),
        raptor_phase = raptor ~= nil and Ability.IsInAbilityPhase(raptor),
        raptor_cd = raptor ~= nil and math.floor(Ability.GetCooldown(raptor) * 10) / 10 or -1,
    }
end

function A.castSwitch(hero, now)
    local switch = A.ability(hero, C.switch)
    if switch ~= nil then Ability.CastNoTarget(switch, false, false, true, C.identifier) end
    local info = A.state(hero)
    info.after_raptor = math.floor((now - S.raptorAt) * 1000)
    A.log("kez raptor dispel switch", info)
    S.step, S.at = "result", now
end

function A.fire(hero, now)
    local raptor = A.ability(hero, C.raptor)
    if raptor == nil or Ability.IsHidden(raptor) or not Ability.IsCastable(raptor, NPC.GetMana(hero)) then
        A.log("kez raptor dispel skipped", { reason = "raptor not ready" })
        S.step = "idle"
        return
    end
    Ability.CastNoTarget(raptor, false, false, true, C.identifier)
    S.raptorAt = now
    S.step, S.at = "switch", now
end

function A.update()
    local hero = Heroes.GetLocal()
    if hero == nil or not Entity.IsAlive(hero) or NPC.GetUnitName(hero) ~= C.hero or not UI.enabled:Get() then
        S.step = "idle"
        return
    end
    local now = GameRules.GetGameTime()
    if S.step == "armed" then
        local katana = A.ability(hero, C.katana)
        if katana ~= nil and Ability.GetCooldown(katana) > 0 then
            A.fire(hero, now)
        elseif now > S.at + C.armWait then
            A.log("kez raptor dispel skipped", { reason = "katana never started" })
            S.step = "idle"
        end
    elseif S.step == "switch" then
        if now > S.raptorAt and now >= S.raptorAt + UI.delay:Get() / 1000 then A.castSwitch(hero, now) end
    elseif S.step == "result" then
        if now >= S.at + C.resultAfter then
            A.log("kez raptor dispel result", A.state(hero))
            S.step = "idle"
        end
    end
end

function A.onOrder(data)
    local ability = data.ability
    if ability == nil or Ability.GetName(ability) ~= C.katana then return end
    local hero = Heroes.GetLocal()
    local owner = data.npc or Ability.GetOwner(ability)
    if hero == nil or owner == nil or Entity.GetIndex(owner) ~= Entity.GetIndex(hero) then return end
    if S.step ~= "idle" then return end
    S.step, S.at = "armed", GameRules.GetGameTime()
end

function A.drawError()
    local title = S.menuError and localization.Get("krd_panel_menu_failed") or localization.Get("krd_panel_error")
    local message = S.menuError or S.error or "unknown"
    Render.FilledRect(Vec2(20, 370), Vec2(780, 418), Color(20, 20, 24, 235), 4)
    Render.Text(S.font, 14, title, Vec2(30, 377), Color(224, 50, 45, 245))
    Render.Text(S.font, 12, message:sub(1, 160), Vec2(30, 397), Color(220, 220, 225, 240))
end

function script.OnScriptsLoaded()
    local ok, result = pcall(A.initMenu)
    S.ready = ok and result == true
    if not S.ready then S.menuError = ok and "initMenu returned false" or tostring(result) end
    S.font = Render.LoadFont("MuseoSansEx", 0, 500)
    A.log("kez_raptor_dispel loaded", { ready = S.ready, error = S.menuError })
end

function script.OnUpdate()
    if not S.ready or not Engine.IsInGame() then return end
    local ok, err = pcall(A.update)
    if not ok then
        if S.error == nil then A.log("kez raptor dispel failed", { error = tostring(err) }) end
        S.error = tostring(err)
        S.step = "idle"
    end
end

function script.OnPrepareUnitOrders(data)
    if not S.ready or data == nil or UI.enabled == nil or not UI.enabled:Get() then return true end
    local ok, err = pcall(A.onOrder, data)
    if not ok and S.error == nil then S.error = tostring(err) end
    return true
end

function script.OnDraw()
    local ok, err = pcall(function()
        if S.menuError ~= nil or S.error ~= nil then A.drawError() end
    end)
    if not ok and S.error == nil then S.error = tostring(err) end
end

return script
