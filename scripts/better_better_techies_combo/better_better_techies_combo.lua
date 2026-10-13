-- Better Better Techies Combo v1.0.0
-- Author: sataroz (Discord: sataroz)

local VERSION = "1.0.0"

--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

local qLocalization = (function()
	local lib = {}

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
			resolve = function(root, path)
				for key in path:gmatch("[^.]+") do
					if type(root) ~= "table" then
						return
					end

					root = root[key]
				end

				return root
			end,

			is_object = function(value)
				return type(value) == "table" or type(value) == "userdata"
			end,

			has_method = function(object, name)
				return helpers.is_object(object) and type(object[name]) == "function"
			end,

			is_menu_object = function(value)
				return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
			end,

			is_list = function(value)
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
				end

				return true
			end,

			is_indexed_list = function(object)
				return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
			end,
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
				get_language = function(language_index)
					if language_index == nil and state.lang then
						language_index = state.lang:Get()
					end

					return localization.languages[language_index] or "en"
				end,

				localize = function(path, language_index)
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end,

				has = function(path)
					if type(path) ~= "string" then
						return false
					end

					return helpers.resolve(localization.translations.en, path) ~= nil
						or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
				end,

				localize_items = function(items, language_index)
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
				end,

				apply = function(object, kind, path, language_index)
					if kind == "label" then
						object:ForceLocalization(methods.localize(path, language_index))
					elseif kind == "tooltip" then
						object:ToolTip(methods.localize(path, language_index))
					elseif kind == "items" then
						local value = object:Get()

						object:Update((methods.localize_items(path, language_index)))
						object:Set(value)
					end
				end,

				track = function(object, kind, path, apply_now)
					local record = localization.objects[object]

					if record == nil then
						record = {}
						localization.objects[object] = record
					end

					record[kind] = path

					if apply_now then
						methods.apply(object, kind, path)
					end
				end,

				register = function(object, path)
					if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
						return
					end

					methods.track(object, "label", path, true)
				end,

				update = function(language_index)
					for object, record in pairs(localization.objects) do
						for kind, path in pairs(record) do
							methods.apply(object, kind, path, language_index)
						end
					end
				end,

				wrap = function(target, bind_self)
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
				end,
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
        tc_group_hero = "Hero Settings",
        tc_group_goods = "Items Settings",
        tc_enable = "Enable",
        tc_enable_tip = "Master switch for Techies combo",
        tc_key = "Combo Key",
        tc_key_tip = "Hold to execute combo on the enemy nearest to cursor",
        tc_mode = "Combo Mode",
        tc_mode_tip = "Aggressive hexes immediately. Max Damage delays hex to chain control after Blast Off.",
        tc_aggressive = "Aggressive",
        tc_maxdmg = "Max Damage",
        tc_abilities = "Abilities",
        tc_detonate = "Detonate Tazer",
        tc_detonate_tip = "Automatically detonate Reactive Tazer when enemy is in radius or after landing",
        tc_draw_target = "Target Indicator",
        tc_draw_target_tip = "Draw circles around the currently locked target",
        tc_draw_blast = "Blast Off Landing",
        tc_draw_blast_tip = "Draw predicted landing area and explosion radius for Blast Off",
        tc_draw_line = "Targeting Line",
        tc_draw_line_tip = "Draw laser beam with chevrons connecting Techies to the target",
        tc_draw_preview = "Preview on Hover",
        tc_draw_preview_tip = "Show targeting line and Blast Off landing circle when hovering near an enemy",
        tc_use_items = "Items Usage",
        tc_breaker = "Linkbreaker Items",
        tc_linken_tip = "Spends the first available item when Linken's Sphere is active. Drag to prioritize.",
        tc_refresher = "Use Refresher",
        tc_refresher_tip = "Refreshes abilities and items after the combo and repeats execution",
        tc_soul_ring = "Use Soul Ring",
        tc_soul_ring_tip = "Automatically uses Soul Ring at the start of combo for bonus mana",
        tc_blink = "Blink Out",
        tc_blink_tip = "Blinks away once the combo is finished. Waits out damage lockout on dagger.",
        tc_gear_blink_out = "Blink Out Settings",
        tc_blink_to = "Blink Destination",
        tc_to_fountain = "Allied Fountain",
        tc_to_ally = "Nearest Ally",
        tc_use_mad = "Aghanim's Shard (M.A.D.)",
        tc_use_mad_tip = "Plants the M.A.D. barrel after main burst and automatically detonates it (D).\n" ..
            "Deals 50 + 40% of max mana (1200+ magic damage).\n\n" ..
            "HOW TO USE:\n" ..
            "- Planting takes 1.0s cast animation, followed by a 1.5s fuse timer after detonation.\n" ..
            "- To prevent enemies from escaping or interrupting Techies, it is cast right after your instant burst while the enemy is disabled in Hex or stunned.\n" ..
            "- Highly recommended to purchase Scythe of Vyse (Hex) when playing with Shard.",
        tc_mad_mode = "M.A.D. Condition",
        tc_mad_mode_tip = "Select when to plant the M.A.D. barrel during combo",
        tc_mad_mode_ctrl = "Under Control Only (Hex/Stun)",
        tc_mad_mode_always = "Always in Combo",
    },
    ru = {
        tc_group_hero = "Настройки героя",
        tc_group_goods = "Настройки предметов",
        tc_enable = "Включить",
        tc_enable_tip = "Главный переключатель комбо на Течиса",
        tc_key = "Клавиша комбо",
        tc_key_tip = "Зажмите для выполнения комбо по врагу у курсора",
        tc_mode = "Режим комбо",
        tc_mode_tip = "Агрессивный жмет хекс сразу. Макс. урон откладывает хекс для продления контроля после Blast Off.",
        tc_aggressive = "Агрессивный",
        tc_maxdmg = "Макс. урон",
        tc_abilities = "Способности",
        tc_detonate = "Взрывать тазер",
        tc_detonate_tip = "Автоматически взрывать Reactive Tazer в радиусе врага или после приземления",
        tc_draw_target = "Индикатор цели",
        tc_draw_target_tip = "Подсвечивать захваченную цель кругом",
        tc_draw_blast = "Точка Blast Off",
        tc_draw_blast_tip = "Отображать точку приземления и радиус Blast Off с упреждением",
        tc_draw_line = "Линия к цели",
        tc_draw_line_tip = "Отображать луч с шевронами от Течиса к цели",
        tc_draw_preview = "Превью при наведении",
        tc_draw_preview_tip = "Показывать линию и радиус Blast Off при наведении курсора на врага",
        tc_use_items = "Использование предметов",
        tc_breaker = "Сбивание Линки",
        tc_linken_tip = "Использует первый доступный предмет при активной Линке. Перетаскивайте для смены приоритета.",
        tc_soul_ring = "Использовать Soul Ring",
        tc_soul_ring_tip = "Автоматически прожимать Soul Ring в начале комбо для бонусной маны",
        tc_refresher = "Использовать Refresher",
        tc_refresher_tip = "Обновляет способности и предметы после первого круга и повторяет комбо",
        tc_blink = "Выход блинком",
        tc_blink_tip = "Уходит блинком сразу после завершения прокаста. Ждет отката даггера после урона.",
        tc_gear_blink_out = "Настройки выхода блинком",
        tc_blink_to = "Куда прыгать",
        tc_to_fountain = "К союзному фонтану",
        tc_to_ally = "К ближайшему союзнику",
        tc_use_mad = "Шард (M.A.D.)",
        tc_use_mad_tip = "Ставит бочку M.A.D. после основного прокаста и сразу взрывает её (D).\n" ..
            "Наносит 50 + 40% от макс. маны (1200+ маг. урона).\n\n" ..
            "КАК ИСПОЛЬЗОВАТЬ С ЭТИМ ШАРДОМ:\n" ..
            "- Установка бочки требует 1.0с замаха (анимации), а после детонации идет 1.5с запал до взрыва.\n" ..
            "- Чтобы враг не сбил каст и не сбежал, бочка ставится сразу после прокаста предметов и мин, пока цель находится в Хексе или стане.\n" ..
            "- Настоятельно рекомендуется собирать Scythe of Vyse (Хекс), чтобы враг гарантированно не успел выйти из радиуса взрыва 400.",
        tc_mad_mode = "Условие M.A.D.",
        tc_mad_mode_tip = "Когда ставить бочку в комбо",
        tc_mad_mode_ctrl = "Только под контролем (Hex/стан)",
        tc_mad_mode_always = "Всегда в комбо",
    },
})

local UI = localization.WrapLibrary(Menu)

local ui = {}
local state = {
    step = 0,
    target = nil,
    committed = false,
    next_at = 0,
    deadline = 0,
    refreshed = false,
    done = {},
    reaims = 0,
    aim_pos = nil,
    land_at = 0,
    miss_r = 0,
    mines_planted = 0,
    planted_positions = {},
    mine_center = nil,
    mine_cang = nil,
    mine_positions = nil,
    mine_pending = false,
    mine_pending_idx = 0,
    mine_charges_before = 0,
    mine_pending_until = 0,
    last_mine_cast_at = 0,
    last_mine_charges = nil,
    mine_timeout = 0,
    step4_deadline = 0,
    step5_deadline = 0,
    leap_start = nil,
    eblade_cast_at = 0,
    item_cast_at = {},
    last_attack_at = 0,
    blink_until = 0,
    tazer_detonate_at = nil,
    did_leap = false,
    fountain = nil,
    draw_error = nil,
    logged_cast_start = nil,
    logged_blast_radius = nil,
    test_active_until = nil,
    test_target = nil,
    completed = false,
    mine_start_charges = nil,
    mines_failed = false,
}

local ITEM_NAMES = {
    Hex = { "item_sheepstick" },
    Nullifier = { "item_nullifier" },
    Orchid = { "item_orchid" },
    Bloodthorn = { "item_bloodthorn" },
    ["Ethereal Blade"] = { "item_ethereal_blade" },
    ["Veil of Discord"] = { "item_veil_of_discord" },
    ["Shiva's Guard"] = { "item_shivas_guard" },
    Dagon = { "item_dagon_5", "item_dagon_4", "item_dagon_3", "item_dagon_2", "item_dagon" },
    ["Spirit Vessel"] = { "item_spirit_vessel" },
    ["Urn of Shadows"] = { "item_urn_of_shadows" },
    ["Rod of Atos"] = { "item_rod_of_atos" },
    Gleipnir = { "item_gungir" },
    ["Diffusal Blade"] = { "item_diffusal_blade" },
    Disperser = { "item_disperser" },
    ["Abyssal Blade"] = { "item_abyssal_blade" },
    ["Heaven's Halberd"] = { "item_heavens_halberd" },
    ["Eul's Scepter"] = { "item_cyclone" },
    ["Wind Waker"] = { "item_wind_waker" },
    ["Force Staff"] = { "item_force_staff" },
    ["Hurricane Pike"] = { "item_hurricane_pike" },
    Harpoon = { "item_harpoon" },
}

local BLINK_NAMES = { "item_blink", "item_swift_blink", "item_arcane_blink", "item_overwhelming_blink" }
local REFRESHER_NAMES = { "item_refresher", "item_refresher_shard" }

local MAGIC_PIERCE_ITEMS = { Nullifier = true }
local NO_TARGET_RADIUS = { ["Shiva's Guard"] = 900, ["Veil of Discord"] = 900 }

do
    local hero = UI.Create("Heroes", "Hero List", "Techies", "Better Better Techies Combo", "tc_group_hero")
    local goods = UI.Create("Heroes", "Hero List", "Techies", "Better Better Techies Combo", "tc_group_goods")

    ui.enable = hero:Switch("tc_enable", false, "\u{f011}")
    ui.enable:ToolTip("tc_enable_tip")

    ui.key = hero:Bind("tc_key", Enum.ButtonCode.KEY_G, "\u{f11c}")
    ui.key:ToolTip("tc_key_tip")

    ui.mode = hero:Combo("tc_mode", { "tc_aggressive", "tc_maxdmg" }, 0)
    ui.mode:Icon("\u{f0e7}")
    ui.mode:ToolTip("tc_mode_tip")

    ui.abilities = hero:MultiSelect("tc_abilities", {
        { "Blast Off", "panorama/images/spellicons/techies_suicide_png.vtex_c", true },
        { "Sticky Bomb", "panorama/images/spellicons/techies_sticky_bomb_png.vtex_c", true },
        { "Reactive Tazer", "panorama/images/spellicons/techies_reactive_tazer_png.vtex_c", true },
        { "Proximity Mines", "panorama/images/spellicons/techies_land_mines_png.vtex_c", true },
        { "Minefield Sign", "panorama/images/spellicons/techies_minefield_sign_png.vtex_c", false },
    }, true)
    ui.abilities:Icon("\u{f890}")

    ui.detonate = hero:Switch("tc_detonate", true)
    ui.detonate:Image("panorama/images/spellicons/techies_reactive_tazer_png.vtex_c")
    ui.detonate:ToolTip("tc_detonate_tip")

    ui.use_mad = hero:Switch("tc_use_mad", true)
    ui.use_mad:Image("panorama/images/spellicons/techies_mutually_assured_destruction_png.vtex_c")
    ui.use_mad:ToolTip("tc_use_mad_tip")

    ui.mad_mode = hero:Combo("tc_mad_mode", { "tc_mad_mode_ctrl", "tc_mad_mode_always" }, 0)
    ui.mad_mode:Icon("\u{f06e}")
    ui.mad_mode:ToolTip("tc_mad_mode_tip")

    ui.draw_line = hero:Switch("tc_draw_line", true, "\u{f1fe}")
    ui.draw_line:ToolTip("tc_draw_line_tip")

    ui.draw_blast = hero:Switch("tc_draw_blast", true, "\u{f140}")
    ui.draw_blast:ToolTip("tc_draw_blast_tip")

    ui.draw_target = hero:Switch("tc_draw_target", true, "\u{f05b}")
    ui.draw_target:ToolTip("tc_draw_target_tip")

    ui.draw_preview = hero:Switch("tc_draw_preview", true, "\u{f06e}")
    ui.draw_preview:ToolTip("tc_draw_preview_tip")

    ui.use_items = goods:MultiSelect("tc_use_items", {
        { "Hex", "panorama/images/items/sheepstick_png.vtex_c", true },
        { "Bloodthorn", "panorama/images/items/bloodthorn_png.vtex_c", true },
        { "Orchid", "panorama/images/items/orchid_png.vtex_c", true },
        { "Nullifier", "panorama/images/items/nullifier_png.vtex_c", true },
        { "Ethereal Blade", "panorama/images/items/ethereal_blade_png.vtex_c", true },
        { "Veil of Discord", "panorama/images/items/veil_of_discord_png.vtex_c", true },
        { "Shiva's Guard", "panorama/images/items/shivas_guard_png.vtex_c", true },
        { "Dagon", "panorama/images/items/dagon_5_png.vtex_c", true },
        { "Spirit Vessel", "panorama/images/items/spirit_vessel_png.vtex_c", true },
        { "Urn of Shadows", "panorama/images/items/urn_of_shadows_png.vtex_c", true },
    }, false)
    ui.use_items:Icon("\u{e196}")

    ui.breaker = goods:MultiSelect("tc_breaker", {
        { "Hex", "panorama/images/items/sheepstick_png.vtex_c", false },
        { "Bloodthorn", "panorama/images/items/bloodthorn_png.vtex_c", false },
        { "Orchid", "panorama/images/items/orchid_png.vtex_c", false },
        { "Nullifier", "panorama/images/items/nullifier_png.vtex_c", false },
        { "Ethereal Blade", "panorama/images/items/ethereal_blade_png.vtex_c", false },
        { "Dagon", "panorama/images/items/dagon_5_png.vtex_c", false },
        { "Spirit Vessel", "panorama/images/items/spirit_vessel_png.vtex_c", false },
        { "Urn of Shadows", "panorama/images/items/urn_of_shadows_png.vtex_c", false },
        { "Rod of Atos", "panorama/images/items/rod_of_atos_png.vtex_c", true },
        { "Gleipnir", "panorama/images/items/gungir_png.vtex_c", true },
        { "Diffusal Blade", "panorama/images/items/diffusal_blade_png.vtex_c", true },
        { "Disperser", "panorama/images/items/disperser_png.vtex_c", true },
        { "Abyssal Blade", "panorama/images/items/abyssal_blade_png.vtex_c", true },
        { "Heaven's Halberd", "panorama/images/items/heavens_halberd_png.vtex_c", true },
        { "Eul's Scepter", "panorama/images/items/cyclone_png.vtex_c", false },
        { "Wind Waker", "panorama/images/items/wind_waker_png.vtex_c", false },
        { "Force Staff", "panorama/images/items/force_staff_png.vtex_c", true },
        { "Hurricane Pike", "panorama/images/items/hurricane_pike_png.vtex_c", true },
        { "Harpoon", "panorama/images/items/harpoon_png.vtex_c", true },
    }, false)
    ui.breaker:Image("panorama/images/items/sphere_png.vtex_c")
    ui.breaker:ToolTip("tc_linken_tip")
    ui.breaker:DragAllowed(true)

    ui.soul_ring = goods:Switch("tc_soul_ring", true)
    ui.soul_ring:Image("panorama/images/items/soul_ring_png.vtex_c")
    ui.soul_ring:ToolTip("tc_soul_ring_tip")

    ui.refresher = goods:Switch("tc_refresher", false)
    ui.refresher:Image("panorama/images/items/refresher_png.vtex_c")
    ui.refresher:ToolTip("tc_refresher_tip")

    ui.blink_out = goods:Switch("tc_blink", false)
    ui.blink_out:Image("panorama/images/items/blink_png.vtex_c")
    ui.blink_out:ToolTip("tc_blink_tip")

    local g_blink = ui.blink_out:Gear("tc_gear_blink_out")
    ui.blink_to = g_blink:Combo("tc_blink_to", { "tc_to_fountain", "tc_to_ally" }, 0)

    ui.abilities:DragAllowed(false)
    ui.use_items:DragAllowed(false)

    local function refresh_disabled()
        local on = ui.enable:Get()
        ui.key:Disabled(not on)
        ui.mode:Disabled(not on)
        ui.abilities:Disabled(not on)
        ui.detonate:Disabled(not on)
        ui.use_mad:Disabled(not on)
        ui.mad_mode:Disabled(not on or not ui.use_mad:Get())
        ui.draw_target:Disabled(not on)
        ui.draw_blast:Disabled(not on)
        ui.use_items:Disabled(not on)
        ui.breaker:Disabled(not on)
        ui.soul_ring:Disabled(not on)
        ui.refresher:Disabled(not on)
        ui.blink_out:Disabled(not on)
    end

    ui.enable:SetCallback(refresh_disabled, true)
    ui.use_mad:SetCallback(refresh_disabled, true)
end

local function reset_combo_state(keep_target)
    state.step = 0
    if not keep_target then
        state.target = nil
        state.test_active_until = nil
        state.test_target = nil
    end
    state.committed = false
    state.refreshed = false
    state.done = {}
    state.reaims = 0
    state.aim_pos = nil
    state.land_at = 0
    state.landed_at = nil
    state.miss_r = 0
    state.deadline = 0
    state.cast_start_at = 0
    state.blast_wait_until = nil
    state.step6_start_at = nil
    state.step4_deadline = 0
    state.step5_deadline = 0
    state.leap_start = nil
    state.eblade_cast_at = 0
    state.item_cast_at = {}
    state.mines_planted = 0
    state.planted_positions = {}
    state.mine_center = nil
    state.mine_cang = nil
    state.mine_positions = nil
    state.mine_pending = false
    state.mine_pending_idx = 0
    state.mine_charges_before = 0
    state.mine_pending_until = 0
    state.last_mine_cast_at = 0
    state.last_mine_charges = nil
    state.mine_start_charges = nil
    state.mine_timeout = 0
    state.mines_failed = false
    state.blink_until = 0
    state.tazer_detonate_at = nil
    state.did_leap = false
    state.draw_error = nil
    state.logged_cast_start = nil
    state.logged_blast_radius = nil
    state.mad_cast_at = nil
    local me = Heroes.GetLocal()
    local raw_blast = me and NPC.GetAbility(me, "techies_suicide")
    local is_blast_phasing = raw_blast and Ability.IsInAbilityPhase(raw_blast)
    local in_leap = me and NPC.HasModifier(me, "modifier_techies_suicide_leap")
    if not in_leap and not is_blast_phasing then
        state.manual_blast_pos = nil
        state.manual_blast_order_time = nil
        state.blast_was_casting = false
    end
end

local function stop_combo()
    reset_combo_state(false)
end

local function cancel_hero_orders(me)
    if not me or not Entity.IsAlive(me) then return end
    local p = Players.GetLocal()
    if not p then return end
    local my_pos = Entity.GetAbsOrigin(me)
    if not my_pos then return end
    Player.PrepareUnitOrders(
        p,
        Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
        nil,
        my_pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        me,
        false,
        false,
        false,
        true
    )
end

local function pause_action(sec)
    state.next_at = GameRules.GetGameTime() + sec + NetChannel.GetAvgLatency()
end

local function is_valid_target(t)
    if not t or not Entity.IsAlive(t) or Entity.IsDormant(t) then return false end
    if NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then return false end
    return true
end

local function is_magic_immune(t)
    if not t or not Entity.IsAlive(t) then return false end
    return NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_DEBUFF_IMMUNE)
        or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
end

local function is_linkens_protected(t)
    return NPC.IsLinkensProtected(t) or NPC.IsMirrorProtected(t)
end

local tracker = {
    target = nil,
    pos = nil,
    time = 0,
    vel = Vector(0, 0, 0),
}

local function update_target_tracker(t)
    if not t or not Entity.IsAlive(t) then
        tracker.target = nil
        tracker.pos = nil
        tracker.vel = Vector(0, 0, 0)
        return
    end

    local now = GameRules.GetGameTime()
    local cur_pos = Entity.GetAbsOrigin(t)

    if tracker.target ~= t or not tracker.pos then
        tracker.target = t
        tracker.pos = cur_pos
        tracker.time = now
        tracker.vel = Vector(0, 0, 0)
        return
    end

    local dt = now - tracker.time
    if dt >= 0.03 then
        local dx = cur_pos.x - tracker.pos.x
        local dy = cur_pos.y - tracker.pos.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local ms = NPC.GetMoveSpeed(t) or 350

        if dist > 3 and dist / dt <= ms * 1.6 then
            tracker.vel = Vector(dx / dt, dy / dt, 0)
        elseif dist <= 3 then
            tracker.vel = Vector(0, 0, 0)
        end

        tracker.pos = cur_pos
        tracker.time = now
    end
end

local function get_target_velocity(t)
    if not t or not Entity.IsAlive(t) then return Vector(0, 0, 0) end

    if NPC.IsStunned(t)
        or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_ROOTED)
        or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_HEXED)
        or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_FROZEN) then
        return Vector(0, 0, 0)
    end

    if NPC.IsRunning(t) then
        local rot = Entity.GetRotation(t)
        if rot then
            local f = rot:GetForward()
            if f then
                local dx, dy = f.x, f.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len > 0.001 then
                    local ms = NPC.GetMoveSpeed(t) or 0
                    if ms > 50 then
                        return Vector((dx / len) * ms, (dy / len) * ms, 0)
                    end
                end
            end
        end
    end

    if tracker.target == t and tracker.vel and tracker.vel.Length and tracker.vel:Length() > 25 then
        return tracker.vel
    end

    return Vector(0, 0, 0)
end

local function predict_target_pos(t, time_s)
    local p = Entity.GetAbsOrigin(t)
    local v = get_target_velocity(t)
    local lead_dist = v:Length() * time_s
    local max_lead = (NPC.GetMoveSpeed(t) or 400) * 1.3 * time_s
    if lead_dist > max_lead and lead_dist > 0 then
        v = v:Normalized() * (max_lead / time_s)
    end
    return Vector(p.x + v.x * time_s, p.y + v.y * time_s, p.z)
end

local function predict_blast_pos(t, blast_ab)
    local p = t and Entity.GetAbsOrigin(t)
    if not p then return nil end

    if NPC.IsStunned(t)
        or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_ROOTED)
        or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_HEXED)
        or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_FROZEN) then
        return p
    end

    local v = get_target_velocity(t)
    local v_len = (v and v.Length) and v:Length() or 0
    if v_len < 30 then
        return p
    end

    local lead_dist = math.min(v_len * 0.50, 220.0)
    local dir = v:Normalized()
    return Vector(p.x + dir.x * lead_dist, p.y + dir.y * lead_dist, p.z)
end

local STUN_STATES = {
    [Enum.ModifierState.MODIFIER_STATE_STUNNED] = true,
    [Enum.ModifierState.MODIFIER_STATE_HEXED] = true,
}

local function get_stun_remaining_time(t)
    if not t or not Entity.IsAlive(t) then return 0 end

    if NPC.GetStatesDuration then
        local ok, durations = pcall(NPC.GetStatesDuration, t, STUN_STATES, true)
        if ok and type(durations) == "table" then
            local s = durations[Enum.ModifierState.MODIFIER_STATE_STUNNED] or 0
            local h = durations[Enum.ModifierState.MODIFIER_STATE_HEXED] or 0
            local max_d = math.max(s, h)
            if max_d > 0 then
                return max_d
            end
        end
    end

    local now = GameRules.GetGameTime()
    local max_die_time = 0
    local modifiers = NPC.GetModifiers(t)
    for _, m in ipairs(modifiers) do
        local name = Modifier.GetName(m)
        if name and (name:find("stun") or name:find("hex") or name == "modifier_sheepstick_debuff") then
            local die_t = Modifier.GetDieTime(m)
            if die_t and die_t > max_die_time then
                max_die_time = die_t
            end
        end
    end
    if max_die_time > now then
        return max_die_time - now
    end
    if NPC.IsStunned(t) or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_HEXED) then
        return 0.45
    end
    return 0
end

local function get_ready_item(me, names)
    local mana = NPC.GetMana(me)
    for _, n in ipairs(names) do
        local item = NPC.GetItem(me, n)
        if item and Ability.IsCastable(item, mana) and Item.IsItemEnabled(item) then
            return item
        end
    end
    return nil
end

local function is_item_on_cooldown(me, names)
    if not names then return false end
    for _, n in ipairs(names) do
        local item = NPC.GetItem(me, n)
        if item and Item.IsItemEnabled(item) then
            if Ability.GetCooldown(item) > 0 then
                return true
            end
        end
    end
    return false
end

local function has_item_in_inventory(me, names)
    if not names then return false end
    for _, n in ipairs(names) do
        local item = NPC.GetItem(me, n)
        if item and Item.IsItemEnabled(item) then
            return true
        end
    end
    return false
end

local function get_cast_range(me, ab)
    if not ab then return 0 end
    return Ability.GetCastRange(ab)
end

local function get_ready_ability(me, name, toggle_name)
    if toggle_name and not ui.abilities:Get(toggle_name) then return nil end
    local a = NPC.GetAbility(me, name)
    if not a or Ability.GetLevel(a) < 1 or Ability.IsHidden(a) then return nil end
    if not Ability.IsCastable(a, NPC.GetMana(me)) then return nil end
    return a
end

local function try_use_soul_ring(me)
    if not ui.soul_ring:Get() or state.done.soul_ring then return false end
    local ring = NPC.GetItem(me, "item_soul_ring")
    if not ring or not Ability.IsReady(ring) or not Item.IsItemEnabled(ring) then return false end
    if NPC.HasState(me, Enum.ModifierState.MODIFIER_STATE_MUTED) then return false end
    Ability.CastNoTarget(ring, false, true, false, "tc_soul_ring")
    state.done.soul_ring = true
    return true
end

local function try_cast_veil(me, target, target_pos)
    if state.done["Veil of Discord"] or not ui.use_items:Get("Veil of Discord") then return false end
    local veil = get_ready_item(me, ITEM_NAMES["Veil of Discord"])
    if not veil then return false end
    if target and is_magic_immune(target) then return false end
    local my_pos = Entity.GetAbsOrigin(me)
    local target_p = target_pos or (target and Entity.GetAbsOrigin(target)) or my_pos
    local dx, dy = target_p.x - my_pos.x, target_p.y - my_pos.y
    local beh = Ability.GetBehavior(veil)
    if (beh & Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) ~= 0 then
        if dx * dx + dy * dy > 950 * 950 then return false end
        Ability.CastNoTarget(veil, false, true, false, "tc_veil")
    elseif (beh & Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) ~= 0 then
        local r = get_cast_range(me, veil) + 150
        if dx * dx + dy * dy > r * r then return false end
        Ability.CastPosition(veil, target_p, false, true, false, "tc_veil")
    else
        if not is_valid_target(target) then return false end
        local r = get_cast_range(me, veil) + 150
        if dx * dx + dy * dy > r * r then return false end
        Ability.CastTarget(veil, target, false, true, false, "tc_veil")
    end
    state.committed = true
    state.done["Veil of Discord"] = true
    return true
end

local function try_cast_shiva(me, target_pos)
    if state.done["Shiva's Guard"] or not ui.use_items:Get("Shiva's Guard") then return false end
    local shiva = get_ready_item(me, ITEM_NAMES["Shiva's Guard"])
    if not shiva then return false end
    local my_pos = Entity.GetAbsOrigin(me)
    local target_p = target_pos or my_pos
    local dx, dy = target_p.x - my_pos.x, target_p.y - my_pos.y
    if dx * dx + dy * dy > 900 * 900 then return false end
    Ability.CastNoTarget(shiva, false, true, false, "tc_shiva")
    state.committed = true
    state.done["Shiva's Guard"] = true
    return true
end

local function try_break_linken(me, target)
    if not is_linkens_protected(target) then return false end
    local my_pos = Entity.GetAbsOrigin(me)
    local target_pos = Entity.GetAbsOrigin(target)
    local dist_sq = (my_pos.x - target_pos.x)^2 + (my_pos.y - target_pos.y)^2
    local immune = is_magic_immune(target)

    for _, id in ipairs(ui.breaker:ListEnabled()) do
        local names = ITEM_NAMES[id]
        if names and (MAGIC_PIERCE_ITEMS[id] or not immune) then
            local item = get_ready_item(me, names)
            if item then
                local cast_range = get_cast_range(me, item) + 100
                if dist_sq <= cast_range * cast_range then
                    Ability.CastTarget(item, target, false, true, false, "tc_break_" .. id)
                    state.committed = true
                    state.done[id] = true
                    pause_action(0.06)
                    return true
                end
            end
        end
    end
    return false
end

local function is_target_controlled(t)
    return is_valid_target(t) and (NPC.IsStunned(t) or NPC.HasModifier(t, "modifier_sheepstick_debuff") or NPC.HasState(t, Enum.ModifierState.MODIFIER_STATE_HEXED))
end

local function cast_item_id(me, target, id, no_target)
    if not ui.use_items:Get(id) then return false end
    local names = ITEM_NAMES[id]
    if not names then return false end

    local now = GameRules.GetGameTime()
    if is_item_on_cooldown(me, names) then
        state.done[id] = true
        return false
    end

    if state.done[id] then
        local last_cast = state.item_cast_at and state.item_cast_at[id] or 0
        if last_cast > 0 and (now - last_cast > 0.15) and not is_item_on_cooldown(me, names) then
            if id == "Hex" and is_target_controlled(target) then
                return false
            end
            state.done[id] = nil
        else
            return false
        end
    end

    local item = get_ready_item(me, names)
    if not item then return false end

    if is_magic_immune(target) and not MAGIC_PIERCE_ITEMS[id] then return false end

    local my_pos = Entity.GetAbsOrigin(me)
    local target_pos = target and Entity.GetAbsOrigin(target) or nil

    if no_target then
        local r = NO_TARGET_RADIUS[id]
        if r and target_pos then
            local dx, dy = my_pos.x - target_pos.x, my_pos.y - target_pos.y
            if dx * dx + dy * dy > r * r then return false end
        end
        Ability.CastNoTarget(item, false, true, false, "tc_" .. id)
    else
        if not is_valid_target(target) or not target_pos then return false end
        local cast_range = get_cast_range(me, item) + 50
        local dist_sq = (my_pos.x - target_pos.x)^2 + (my_pos.y - target_pos.y)^2
        if dist_sq > cast_range * cast_range then return false end
        Ability.CastTarget(item, target, false, true, false, "tc_" .. id)
    end

    state.committed = true
    state.done[id] = true
    if state.item_cast_at then
        state.item_cast_at[id] = now
    end
    if id == "Ethereal Blade" then
        state.eblade_cast_at = now
    end
    local in_leap = NPC.HasModifier(me, "modifier_techies_suicide_leap")
    pause_action(in_leap and 0.05 or 0.08)
    return true
end

local function make_ground_pos(x, y, fallback_z)
    local gz = fallback_z
    if World and World.GetGroundZ then
        local ok, z = pcall(World.GetGroundZ, x, y)
        if ok and type(z) == "number" and z > -5000 and z < 5000 then
            gz = z
        end
    end
    return Vector(x, y, gz)
end

local function has_trees_near(pos, r)
    if Trees and Trees.InRadius then
        local ok, tr = pcall(Trees.InRadius, pos, r, true)
        if ok and tr and #tr > 0 then return true end
    end
    if TempTrees and TempTrees.InRadius then
        local ok, ttr = pcall(TempTrees.InRadius, pos, r)
        if ok and ttr and #ttr > 0 then return true end
    end
    return false
end

local function is_tile_traversable(p)
    if not GridNav or not GridNav.IsTraversable then return true end
    local ok, trav = pcall(GridNav.IsTraversable, p, 1, 0x102)
    if ok then return trav end
    local ok2, trav2 = pcall(GridNav.IsTraversable, p)
    if ok2 then return trav2 end
    return true
end

local function is_valid_mine_pos(p, center)
    if not p then return false end
    if center and math.abs(p.z - center.z) > 160 then return false end
    if not is_tile_traversable(p) then return false end
    if has_trees_near(p, 50) then return false end
    return true
end

local function dist_sq_2d(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
end

local MIN_MINE_DIST_SQ = 355.0 * 355.0

local function get_or_create_mine_positions(target)
    local cur_target_pos = target and Entity.IsAlive(target) and Entity.GetAbsOrigin(target)

    if cur_target_pos and state.mine_center then
        if dist_sq_2d(cur_target_pos, state.mine_center) > 65.0 * 65.0 then
            state.mine_positions = nil
            state.mine_center = nil
        end
    end

    if state.mine_positions and #state.mine_positions >= 3 then
        return state.mine_positions
    end

    local c = cur_target_pos or state.aim_pos or state.mine_center
    if not c then return nil end

    local base_ang = 0
    local me = Heroes.GetLocal()
    if me then
        local my_pos = Entity.GetAbsOrigin(me)
        local dx = my_pos.x - c.x
        local dy = my_pos.y - c.y
        if dx * dx + dy * dy > 25 then
            base_ang = math.atan2(dy, dx)
        end
    end

    local function is_valid_cand(p)
        if not is_valid_mine_pos(p, c) then return false end
        if state.planted_positions then
            for _, prev in ipairs(state.planted_positions) do
                if dist_sq_2d(p, prev) < MIN_MINE_DIST_SQ then
                    return false
                end
            end
        end
        return true
    end

    local R = 230.0
    local a_step = 2.094395
    local test_rotations = {
        0,
        0.2618, -0.2618,
        0.5236, -0.5236,
        0.7854, -0.7854,
        1.0472, -1.0472,
        1.3090, -1.3090,
        1.5708, -1.5708,
        1.8326, -1.8326,
        2.0944
    }

    for _, rot in ipairs(test_rotations) do
        local a1 = base_ang + rot
        local a2 = a1 + a_step
        local a3 = a1 - a_step

        local p1 = make_ground_pos(c.x + R * math.cos(a1), c.y + R * math.sin(a1), c.z)
        local p2 = make_ground_pos(c.x + R * math.cos(a2), c.y + R * math.sin(a2), c.z)
        local p3 = make_ground_pos(c.x + R * math.cos(a3), c.y + R * math.sin(a3), c.z)

        if is_valid_cand(p1) and is_valid_cand(p2) and is_valid_cand(p3) then
            state.mine_positions = { p1, p2, p3 }
            state.mine_center = c
            return state.mine_positions
        end
    end

    local radii = { 0, 180, 240, 300, 360 }
    local num_angles = 16
    local candidates = {}

    for _, r in ipairs(radii) do
        if r == 0 then
            local cp = make_ground_pos(c.x, c.y, c.z)
            if is_valid_cand(cp) then
                table.insert(candidates, cp)
            end
        else
            for i = 0, num_angles - 1 do
                local ang = base_ang + i * (6.283185 / num_angles)
                local cp = make_ground_pos(c.x + r * math.cos(ang), c.y + r * math.sin(ang), c.z)
                if is_valid_cand(cp) then
                    table.insert(candidates, cp)
                end
            end
        end
    end

    local n = #candidates
    local best_set = nil
    local best_score = 99999999

    for i = 1, n do
        local cp1 = candidates[i]
        local d1 = dist_sq_2d(cp1, c)
        if d1 < best_score then
            for j = i + 1, n do
                local cp2 = candidates[j]
                local d12 = d1 + dist_sq_2d(cp2, c)
                if d12 < best_score and dist_sq_2d(cp1, cp2) >= MIN_MINE_DIST_SQ then
                    for k = j + 1, n do
                        local cp3 = candidates[k]
                        local score = d12 + dist_sq_2d(cp3, c)
                        if score < best_score then
                            if dist_sq_2d(cp1, cp3) >= MIN_MINE_DIST_SQ and dist_sq_2d(cp2, cp3) >= MIN_MINE_DIST_SQ then
                                best_score = score
                                best_set = { cp1, cp2, cp3 }
                            end
                        end
                    end
                end
            end
        end
    end

    if best_set then
        state.mine_positions = best_set
        state.mine_center = c
        return state.mine_positions
    end

    for i = 1, n do
        for j = i + 1, n do
            if dist_sq_2d(candidates[i], candidates[j]) >= MIN_MINE_DIST_SQ then
                state.mine_positions = { candidates[i], candidates[j] }
                state.mine_center = c
                return state.mine_positions
            end
        end
    end

    local default_p = make_ground_pos(c.x, c.y, c.z)
    state.mine_positions = { default_p }
    state.mine_center = c
    return state.mine_positions
end

local function find_fallback_mine_pos(me, target, next_idx, raw_cast_range, hero_pos_override)
    local my_pos = hero_pos_override or Entity.GetAbsOrigin(me)
    if not my_pos then return nil end

    local tp = (target and Entity.IsAlive(target)) and Entity.GetAbsOrigin(target) or state.mine_center or my_pos
    local max_hero_dist = raw_cast_range + 25
    local max_hero_dist_sq = max_hero_dist * max_hero_dist

    local positions = state.mine_positions or {}

    local function is_pos_valid_with_others(cp)
        if state.planted_positions then
            for _, prev in ipairs(state.planted_positions) do
                if dist_sq_2d(cp, prev) < MIN_MINE_DIST_SQ then
                    return false
                end
            end
        end
        for i = 1, next_idx - 1 do
            local other = positions[i]
            if other and dist_sq_2d(cp, other) < MIN_MINE_DIST_SQ then
                return false
            end
        end
        return true
    end

    local base_ang = 0
    local dx = my_pos.x - tp.x
    local dy = my_pos.y - tp.y
    if dx * dx + dy * dy > 25 then
        base_ang = math.atan2(dy, dx)
    end

    local radii = { 0, 80, 150, 220, 280, 340, 390 }
    local num_angles = 24
    local best_all = nil
    local best_all_score = 99999999

    for _, r in ipairs(radii) do
        local n_pts = (r == 0) and 1 or num_angles
        for a = 0, n_pts - 1 do
            local ang = base_ang + a * (6.2831853 / num_angles)
            local cp = (r == 0) and make_ground_pos(tp.x, tp.y, tp.z)
                or make_ground_pos(tp.x + r * math.cos(ang), tp.y + r * math.sin(ang), tp.z)

            if dist_sq_2d(cp, my_pos) <= max_hero_dist_sq
                and (r == 0 or dist_sq_2d(cp, tp) <= 420.0 * 420.0)
                and is_pos_valid_with_others(cp)
                and is_valid_mine_pos(cp, tp) then
                local score = dist_sq_2d(cp, tp)
                if score < best_all_score then
                    best_all_score = score
                    best_all = cp
                end
            end
        end
    end

    return best_all
end

local function plant_mine(me, target)
    if not ui.abilities:Get("Proximity Mines") or state.mines_failed then return false end
    local mine_ab = NPC.GetAbility(me, "techies_land_mines")
    if not mine_ab or Ability.GetLevel(mine_ab) < 1 or Ability.IsHidden(mine_ab) then return false end

    local now = GameRules.GetGameTime()

    local charges = Ability.GetCurrentCharges(mine_ab)
    if not state.mine_start_charges then
        state.mine_start_charges = charges
    end
    local spent = state.mine_start_charges - charges
    if spent > state.mines_planted then
        state.mines_planted = spent
    end

    if state.mine_pending then
        if charges < state.mine_charges_before then
            state.mines_planted = math.max(state.mines_planted, state.mine_pending_idx)
            if Log and Log.Write then
                Log.Write(string.format("[Techies Mines] #%d CONFIRMED charges %d -> %d (planted=%d)", state.mine_pending_idx, state.mine_charges_before, charges, state.mines_planted))
            end
            state.mine_pending = false
            state.last_mine_cast_at = now
        elseif now < state.mine_pending_until then
            return true
        else
            if Log and Log.Write then
                Log.Write(string.format("[Techies Mines] #%d TIMEOUT without charge decrement, retrying", state.mine_pending_idx))
            end
            state.mine_pending = false
            if state.planted_positions and #state.planted_positions > 0 then
                table.remove(state.planted_positions)
            end
        end
    end

    if state.mines_planted >= 3 then return false end

    charges = Ability.GetCurrentCharges(mine_ab)
    if charges <= 0 then return false end

    local mana = NPC.GetMana(me)
    if mana < Ability.GetManaCost(mine_ab) then return false end

    local positions = get_or_create_mine_positions(target)
    if not positions or #positions == 0 then
        return false
    end

    local target_mines = 3
    if state.mines_planted >= target_mines then return false end

    local next_idx = state.mines_planted + 1
    if next_idx > target_mines then return false end

    local my_pos = Entity.GetAbsOrigin(me)
    local raw_cast_range = get_cast_range(me, mine_ab)
    local cast_range = raw_cast_range + 25

    local p = positions and positions[next_idx]
    if not p then
        p = find_fallback_mine_pos(me, target, next_idx, raw_cast_range)
        if not p then return false end
        if positions then positions[next_idx] = p end
    end

    local dx = p.x - my_pos.x
    local dy = p.y - my_pos.y
    local dist_sq = dx * dx + dy * dy

    local tp = target and Entity.IsAlive(target) and Entity.GetAbsOrigin(target)

    local needs_recalc = false
    local recalc_reason = nil
    if dist_sq > cast_range * cast_range then
        needs_recalc = true
        recalc_reason = "out of cast range"
    elseif tp and dist_sq_2d(p, tp) > 280.0 * 280.0 then
        needs_recalc = true
        recalc_reason = "target moved too far from mine pos"
    else
        for i = 1, next_idx - 1 do
            local prev_p = positions and positions[i]
            if prev_p and dist_sq_2d(p, prev_p) < MIN_MINE_DIST_SQ then
                needs_recalc = true
                recalc_reason = "too close to planted mine"
                break
            end
        end
    end

    if not needs_recalc then
        if Log and Log.Write then
            local leap_str = ""
            if state.leap_start and state.leap_start > 0 then
                local el = now - state.leap_start
                leap_str = string.format(" [Leap +%.3fs, rem %.3fs]", el, math.max(0, 0.9 - el))
            end
            Log.Write(string.format("[Techies Mines] #%d pos=(%.1f, %.1f) dist=%.1f range=%.1f charges=%d%s",
                next_idx, p.x, p.y, math.sqrt(dist_sq), cast_range, charges, leap_str))
        end
        state.mine_pending = true
        state.mine_pending_idx = next_idx
        state.mine_charges_before = charges
        state.mine_pending_until = now + 0.25
        state.last_mine_cast_at = now
        state.committed = true
        table.insert(state.planted_positions, p)
        Ability.CastPosition(mine_ab, p, false, true, false, "tc_mine")
        pause_action(0.04)
        return true
    end

    local new_p = find_fallback_mine_pos(me, target, next_idx, raw_cast_range)
    if new_p then
        if positions then positions[next_idx] = new_p end
        p = new_p
        local n_dx, n_dy = p.x - my_pos.x, p.y - my_pos.y
        local n_dist_sq = n_dx * n_dx + n_dy * n_dy

        if Log and Log.Write then
            Log.Write(string.format("[Techies Mines] #%d pos=(%.1f, %.1f) dist=%.1f range=%.1f charges=%d [recalculated: %s]",
                next_idx, p.x, p.y, math.sqrt(n_dist_sq), cast_range, charges, recalc_reason or "out of range"))
        end
        state.mine_pending = true
        state.mine_pending_idx = next_idx
        state.mine_charges_before = charges
        state.mine_pending_until = now + 0.25
        state.last_mine_cast_at = now
        state.committed = true
        table.insert(state.planted_positions, p)
        Ability.CastPosition(mine_ab, p, false, true, false, "tc_mine")
        pause_action(0.04)
        return true
    else
        local in_leap = NPC.HasModifier(me, "modifier_techies_suicide_leap")
        if not in_leap and not state.did_leap then
            NPC.MoveTo(me, p)
            pause_action(0.04)
            return true
        end
        return false
    end

    return false
end

local function cast_tazer(me)
    if state.done.tazer then return false end
    local tazer_ab = get_ready_ability(me, "techies_reactive_tazer", "Reactive Tazer")
    if not tazer_ab then return false end
    local beh = Ability.GetBehavior(tazer_ab)
    if (beh & Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) ~= 0 then
        Ability.CastTarget(tazer_ab, me, false, true, false, "tc_tazer")
    else
        Ability.CastNoTarget(tazer_ab, false, true, false, "tc_tazer")
    end
    state.committed = true
    state.done.tazer = true
    pause_action(0.04)
    return true
end

local function cast_bomb(me, target)
    if state.done.bomb or not is_valid_target(target) then return false end
    local bomb_ab = get_ready_ability(me, "techies_sticky_bomb", "Sticky Bomb")
    if not bomb_ab then return false end
    local my_pos = Entity.GetAbsOrigin(me)
    local target_pos = Entity.GetAbsOrigin(target)
    local dx, dy = target_pos.x - my_pos.x, target_pos.y - my_pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local cast_r = get_cast_range(me, bomb_ab) + 100
    if dist > cast_r then return false end
    local speed = Ability.GetLevelSpecialValueFor(bomb_ab, "speed")
    if speed <= 0 then speed = Ability.GetLevelSpecialValueFor(bomb_ab, "projectile_speed") end
    if speed <= 0 then speed = 1400 end
    local cp = Ability.GetCastPoint(bomb_ab) or 0.2
    if cp <= 0 then cp = 0.2 end
    local travel_time = cp + math.max(dist / speed, 0.25)
    Ability.CastPosition(bomb_ab, predict_target_pos(target, travel_time), false, true, false, "tc_bomb")
    state.committed = true
    state.done.bomb = true
    local in_leap = NPC.HasModifier(me, "modifier_techies_suicide_leap")
    pause_action(in_leap and 0.05 or (cp + 0.04))
    return true
end

local function detonate_tazer(me, target_pos)
    if not ui.detonate:Get() or state.done.detonate then return false end
    if not NPC.HasModifier(me, "modifier_techies_reactive_tazer") then return false end
    local det_ab = NPC.GetAbility(me, "techies_reactive_tazer_stop")
    if not det_ab or Ability.IsHidden(det_ab) then return false end
    local raw_tazer = NPC.GetAbility(me, "techies_reactive_tazer")
    local tazer_r = raw_tazer and Ability.GetLevelSpecialValueFor(raw_tazer, "radius") or 475
    if tazer_r <= 0 then tazer_r = 475 end
    local my_pos = Entity.GetAbsOrigin(me)
    local target_p = target_pos or my_pos
    local d_sq = (my_pos.x - target_p.x)^2 + (my_pos.y - target_p.y)^2
    if d_sq > tazer_r * tazer_r then return false end
    Ability.CastNoTarget(det_ab, false, true, false, "tc_tazer_stop")
    state.committed = true
    state.done.detonate = true
    state.tazer_detonate_at = GameRules.GetGameTime()
    pause_action(0.06)
    return true
end

local function try_detonate_mad(me)
    if state.done.mad_detonate then return false end
    local det_ab = NPC.GetAbility(me, "techies_focused_detonate")
    if not det_ab or Ability.IsHidden(det_ab) or not Ability.IsReady(det_ab) then return false end

    Ability.CastNoTarget(det_ab, false, true, true, "tc_mad_det")
    state.done.mad_detonate = true
    pause_action(0.04)
    return true
end

local function try_cast_mad(me, target, target_pos)
    if not ui.use_mad:Get() or state.done.mad then return false end
    if not is_valid_target(target) then return false end

    local mad_ab = NPC.GetAbility(me, "techies_mutually_assured_destruction")
    if not mad_ab or Ability.IsHidden(mad_ab) or Ability.IsPassive(mad_ab) then return false end
    if Ability.GetLevel(mad_ab) == 0 or Ability.GetCooldown(mad_ab) > 0 then return false end
    if NPC.GetMana(me) < Ability.GetManaCost(mad_ab) then return false end

    local now = GameRules.GetGameTime()
    if ui.mad_mode:Get() == 0 then
        local is_controlled = is_target_controlled(target)
            or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ROOTED)
            or (get_stun_remaining_time(target) > 0.1)
            or (state.did_leap and (not state.landed_at or now - state.landed_at < 2.5))
        if not is_controlled then return false end
    end

    local my_pos = Entity.GetAbsOrigin(me)
    local cast_r = get_cast_range(me, mad_ab)
    local tpos = target_pos or Entity.GetAbsOrigin(target)
    local dx, dy = tpos.x - my_pos.x, tpos.y - my_pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local plant_pos = tpos
    if dist > cast_r then
        if dist > cast_r + 350 then return false end
        local factor = (cast_r - 20) / dist
        plant_pos = Vector(my_pos.x + dx * factor, my_pos.y + dy * factor, tpos.z)
    end

    Ability.CastPosition(mad_ab, plant_pos, false, true, true, "tc_mad")
    state.committed = true
    state.done.mad = true
    state.mad_cast_at = now
    pause_action(0.08)
    return true
end

local function try_auto_attack(me, target)
    if not is_valid_target(target) then return false end
    if NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE) then return false end
    if NPC.HasModifier(target, "modifier_item_ethereal_blade_ethereal") then return false end
    if NPC.HasState(me, Enum.ModifierState.MODIFIER_STATE_DISARMED) or NPC.IsStunned(me) or NPC.HasModifier(me, "modifier_techies_suicide_leap") then return false end

    local now = GameRules.GetGameTime()
    local mad_ab = NPC.GetAbility(me, "techies_mutually_assured_destruction")
    if mad_ab and Ability.IsInAbilityPhase(mad_ab) then return false end
    if state.mad_cast_at and (now - state.mad_cast_at < 0.25) then return false end
    if now - state.last_attack_at < 0.25 then return false end

    local my_pos = Entity.GetAbsOrigin(me)
    local target_pos = Entity.GetAbsOrigin(target)
    local atk_range = NPC.GetAttackRange(me) + 150
    local dist_sq = (my_pos.x - target_pos.x)^2 + (my_pos.y - target_pos.y)^2
    if dist_sq <= atk_range * atk_range then
        Player.AttackTarget(Players.GetLocal(), me, target)
        state.last_attack_at = now
        return true
    end
    return false
end

local function get_escape_pos(me)
    if ui.blink_to:Get() == 1 then
        local my_pos = Entity.GetAbsOrigin(me)
        local best, best_d = nil, 1e18
        for _, h in pairs(Heroes.GetAll()) do
            if h ~= me and Entity.GetTeamNum(h) == Entity.GetTeamNum(me)
                and Entity.IsAlive(h) and not Entity.IsDormant(h) then
                local o = Entity.GetAbsOrigin(h)
                local d = (o.x - my_pos.x)^2 + (o.y - my_pos.y)^2
                if d < best_d then best, best_d = o, d end
            end
        end
        if best then return best end
    end
    if state.fountain then return state.fountain end
    for _, e in pairs(Entities.GetAll()) do
        if Entity.GetClassName(e) == "C_DOTA_Unit_Fountain" and Entity.GetTeamNum(e) == Entity.GetTeamNum(me) then
            state.fountain = Entity.GetAbsOrigin(e)
            return state.fountain
        end
    end
    local team = Entity.GetTeamNum(me)
    if team == 2 then
        return Vector(-7200, -6700, 270)
    elseif team == 3 then
        return Vector(7100, 6500, 390)
    end
    return Vector(0, 0, 0)
end

function script.OnUpdate()
    local me = Heroes.GetLocal()
    if not ui.enable:Get() or not me or not Entity.IsAlive(me) or NPC.GetUnitName(me) ~= "npc_dota_hero_techies" then
        if state.step > 0 then
            cancel_hero_orders(me)
            stop_combo()
        end
        return
    end

    local is_testing = state.test_active_until and GameRules.GetGameTime() < state.test_active_until
    local key_down = Input.IsKeyDown(ui.key:Get()) or is_testing
    if not key_down then
        state.completed = false
        if state.step > 0 then
            cancel_hero_orders(me)
            stop_combo()
        end
        return
    end

    if state.completed then
        return
    end

    local my_pos = Entity.GetAbsOrigin(me)

    if state.step == 0 then
        if is_testing and state.test_target and is_valid_target(state.test_target) then
            state.target = state.test_target
        else
            state.target = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)
        end
        if not is_valid_target(state.target) then
            state.target = nil
            return
        end
        local target_pos = Entity.GetAbsOrigin(state.target)
        local in_leap = NPC.HasModifier(me, "modifier_techies_suicide_leap")
        local check_pos = in_leap and (state.manual_blast_pos or my_pos) or my_pos
        if (check_pos.x - target_pos.x)^2 + (check_pos.y - target_pos.y)^2 > 2000 * 2000 then
            state.target = nil
            return
        end

        local saved_test_until = state.test_active_until
        local saved_test_tgt = state.test_target
        reset_combo_state(true)
        state.test_active_until = saved_test_until
        state.test_target = saved_test_tgt
        state.step = 1
        state.next_at = 0
    end

    local target = state.target
    if target and Entity.IsAlive(target) then
        update_target_tracker(target)
    elseif state.step <= 1 then
        local cursor_target = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)
        if is_valid_target(cursor_target) then
            local tp = Entity.GetAbsOrigin(cursor_target)
            if (my_pos.x - tp.x)^2 + (my_pos.y - tp.y)^2 <= 1600 * 1600 then
                state.target = cursor_target
                target = cursor_target
                update_target_tracker(target)
            end
        end
    end

    if state.step < 10 and not is_valid_target(target) then
        if state.step ~= 2 and state.step ~= 3 then
            if state.committed and (state.step == 4 or state.step == 5 or state.step == 6) and ui.blink_out:Get() then
                state.blink_until = GameRules.GetGameTime() + 3.5
                state.step = 10
                return
            else
                cancel_hero_orders(me)
                return stop_combo()
            end
        end
    end

    local now = GameRules.GetGameTime()
    if now < state.next_at then return end

    local mad_ab = NPC.GetAbility(me, "techies_mutually_assured_destruction")
    if mad_ab and Ability.IsInAbilityPhase(mad_ab) then
        pause_action(0.04)
        return
    end

    local bomb_ab = NPC.GetAbility(me, "techies_sticky_bomb")
    if bomb_ab and Ability.IsInAbilityPhase(bomb_ab) then
        pause_action(0.04)
        return
    end

    local det_ab = NPC.GetAbility(me, "techies_focused_detonate")
    local det_hidden = not det_ab or Ability.IsHidden(det_ab)
    if state.done.mad and not state.done.mad_detonate and state.mad_cast_at and (now - state.mad_cast_at > 1.2) then
        if mad_ab and not Ability.IsHidden(mad_ab) and Ability.GetCooldown(mad_ab) == 0 and not Ability.IsInAbilityPhase(mad_ab) and det_hidden then
            state.done.mad = nil
        end
    end

    local target_pos = target and Entity.GetAbsOrigin(target) or my_pos
    local combo_mode = ui.mode:Get()

    if state.step == 1 then
        local in_leap = NPC.HasModifier(me, "modifier_techies_suicide_leap")
        if in_leap then
            state.committed = true
            state.did_leap = true
            if not state.leap_start then
                state.leap_start = now
            end
            local mod = NPC.GetModifier(me, "modifier_techies_suicide_leap")
            if mod then
                local die_time = Modifier.GetDieTime(mod)
                if die_time and die_time > now then
                    state.land_at = die_time
                end
            end
            state.aim_pos = target_pos or state.manual_blast_pos or my_pos
            state.mine_center = target_pos or state.manual_blast_pos or my_pos
            state.step = 3
            return
        end

        local raw_blast = NPC.GetAbility(me, "techies_suicide")
        if raw_blast and Ability.IsInAbilityPhase(raw_blast) then
            state.committed = true
            state.did_leap = true
            state.aim_pos = target_pos or state.manual_blast_pos or my_pos
            state.mine_center = target_pos or state.manual_blast_pos or my_pos
            state.deadline = now + 1.5
            state.step = 2
            pause_action(0.06)
            return
        end
        local blast_range = raw_blast and get_cast_range(me, raw_blast) or 1000
        local dist_to_target = math.sqrt((target_pos.x - my_pos.x)^2 + (target_pos.y - my_pos.y)^2)

        if dist_to_target <= blast_range + 250 then
            try_use_soul_ring(me)
        end

        local blast_ab = get_ready_ability(me, "techies_suicide", "Blast Off")
        local raw_level = raw_blast and Ability.GetLevel(raw_blast) or 0
        local raw_cd = raw_blast and Ability.GetCooldown(raw_blast) or 0
        local want_blast = ui.abilities:Get("Blast Off") and raw_blast and raw_level > 0 and raw_cd == 0 and not Ability.IsHidden(raw_blast)

        if want_blast and not blast_ab and state.done.soul_ring then
            if not state.blast_wait_until then
                state.blast_wait_until = now + 0.35
            end
            if now < state.blast_wait_until then
                pause_action(0.06)
                return
            end
            state.step = 6
            return
        end

        if blast_ab then
            local cast_point = Ability.GetCastPoint(blast_ab)
            local fly_duration = 0.90
            local total_time = cast_point + fly_duration
            local predicted = predict_blast_pos(target, blast_ab) or target_pos

            local dx, dy = predicted.x - my_pos.x, predicted.y - my_pos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local max_r = get_cast_range(me, blast_ab)
            local blast_radius = Ability.GetLevelSpecialValueFor and Ability.GetLevelSpecialValueFor(blast_ab, "radius") or 400
            if Log and Log.Write and not state.logged_blast_radius then
                state.logged_blast_radius = true
                Log.Write(string.format("[Techies Radius] Ability.GetLevelSpecialValueFor(blast_ab, 'radius') = %s", tostring(blast_radius)))
            end
            if blast_radius <= 0 then blast_radius = 400 end

            if dist > max_r then
                NPC.MoveTo(me, predicted)
                state.reaims = 0
                pause_action(0.06)
                return
            end

            local goal = predicted

            try_use_soul_ring(me)
            Ability.CastPosition(blast_ab, goal, false, true, false, "tc_blast")
            state.committed = true
            state.did_leap = true
            state.aim_pos = goal
            state.mine_center = target_pos
            state.land_at = now + total_time
            state.cast_start_at = now
            state.miss_r = blast_radius * 0.9
            state.deadline = now + cast_point + 2.0
            pause_action(0.06)
            state.step = 2
        else
            if raw_cd > 0 then
                state.committed = true
                state.did_leap = true
                if not state.landed_at then
                    state.landed_at = now
                end
            end
            local dist_to_tgt = math.sqrt((target_pos.x - my_pos.x)^2 + (target_pos.y - my_pos.y)^2)
            if dist_to_tgt <= 900 and raw_cd > 0 then
                state.step = 4
            else
                state.step = 6
            end
        end
    elseif state.step == 2 then
        if NPC.HasModifier(me, "modifier_techies_suicide_leap") then
            if not state.leap_start then
                state.leap_start = now
            end
            state.step = 3
            return
        end

        if now > state.deadline then
            state.step = 1
            return
        end

        local blast_ab = NPC.GetAbility(me, "techies_suicide")
        if blast_ab and Ability.IsInAbilityPhase(blast_ab) and Log and Log.Write then
            local cast_start = Ability.GetCastStartTime(blast_ab)
            if cast_start and cast_start > 0 and not state.logged_cast_start then
                state.logged_cast_start = true
                Log.Write(string.format("[Techies Blast] cast_start=%.3f, land_at=%.3f, diff=%.3f",
                    cast_start, state.land_at, (cast_start + 0.9) - state.land_at))
            end
        end

    elseif state.step == 3 then
        if not NPC.HasModifier(me, "modifier_techies_suicide_leap") then
            if not state.landed_at then
                state.landed_at = now
            end
            state.step = 4
            return
        end

        try_use_soul_ring(me)
        try_cast_veil(me, target, target_pos)
        try_cast_shiva(me, target_pos)

        if try_break_linken(me, target) then return end

        if combo_mode == 0 then
            if cast_item_id(me, target, "Hex") then return end
            if cast_item_id(me, target, "Ethereal Blade") then return end

            local has_eblade = ui.use_items:Get("Ethereal Blade")
                and has_item_in_inventory(me, ITEM_NAMES["Ethereal Blade"])
                and not is_item_on_cooldown(me, ITEM_NAMES["Ethereal Blade"])
            local target_ethereal = NPC.HasModifier(target, "modifier_item_ethereal_blade_ethereal")
            if not is_item_on_cooldown(me, ITEM_NAMES.Dagon) and ui.use_items:Get("Dagon") then
                if not has_eblade or target_ethereal or (state.eblade_cast_at and now - state.eblade_cast_at > 0.18) then
                    if cast_item_id(me, target, "Dagon") then return end
                end
            end

            local hex_ready = ui.use_items:Get("Hex")
                and not state.done.Hex
                and get_ready_item(me, ITEM_NAMES.Hex)

            if not hex_ready or state.done.Hex then
                if cast_bomb(me, target) then return end
                if cast_tazer(me) then return end
            end
        end

        local mine_ab = NPC.GetAbility(me, "techies_land_mines")
        local mine_charges = mine_ab and Ability.GetCurrentCharges(mine_ab) or 0
        local can_mine = ui.abilities:Get("Proximity Mines")
            and mine_ab
            and Ability.GetLevel(mine_ab) > 0
            and not Ability.IsHidden(mine_ab)
            and (mine_charges > 0 or state.mine_pending)
            and NPC.GetMana(me) >= Ability.GetManaCost(mine_ab)

        local positions = get_or_create_mine_positions(target)
        local target_mines = positions and math.min(3, #positions) or 3
        if not state.mines_failed and (state.mines_planted < target_mines or state.mine_pending) and can_mine then
            if plant_mine(me, target) then return end
        end

        if combo_mode == 0 then
            if cast_tazer(me) then return end
        end

        if not NPC.HasModifier(me, "modifier_techies_suicide_leap") then
            if not state.landed_at then
                state.landed_at = now
            end
            state.step = 4
            return
        end
    elseif state.step == 4 then
        if state.mine_timeout == 0 then
            state.mine_timeout = now + 2.5
        end
        if not state.step4_deadline or state.step4_deadline == 0 then
            state.step4_deadline = now + 3.0
        end

        try_cast_veil(me, target, target_pos)
        try_cast_shiva(me, target_pos)

        if try_break_linken(me, target) then return end

        if combo_mode == 0 then
            if cast_item_id(me, target, "Hex") then return end
        end

        if cast_item_id(me, target, "Ethereal Blade") then return end

        local has_ethereal = NPC.HasModifier(target, "modifier_item_ethereal_blade_ethereal")
        local eblade_flying = state.eblade_cast_at and (now - state.eblade_cast_at < 0.20) and not has_ethereal
        if eblade_flying then
            pause_action(0.04)
            return
        end

        if not is_item_on_cooldown(me, ITEM_NAMES.Dagon) and ui.use_items:Get("Dagon") then
            if cast_item_id(me, target, "Dagon") then return end
        end

        if cast_item_id(me, target, "Bloodthorn") or cast_item_id(me, target, "Orchid") then return end
        if cast_item_id(me, target, "Nullifier") then return end

        if detonate_tazer(me, target_pos) then return end

        if cast_bomb(me, target) then return end

        if try_detonate_mad(me) then return end
        if try_cast_mad(me, target, target_pos) then return end

        local mine_ab = NPC.GetAbility(me, "techies_land_mines")
        local mine_charges = mine_ab and Ability.GetCurrentCharges(mine_ab) or 0
        local can_mine = ui.abilities:Get("Proximity Mines")
            and mine_ab
            and Ability.GetLevel(mine_ab) > 0
            and not Ability.IsHidden(mine_ab)
            and (mine_charges > 0 or state.mine_pending)
            and NPC.GetMana(me) >= Ability.GetManaCost(mine_ab)

        local positions = get_or_create_mine_positions(target)
        local target_mines = positions and math.min(3, #positions) or 3

        if not state.mines_failed and (state.mines_planted < target_mines or state.mine_pending) and can_mine and now < state.mine_timeout then
            if plant_mine(me, target) then return end
        end

        if cast_tazer(me) then return end
        if detonate_tazer(me, target_pos) then return end

        if cast_item_id(me, target, "Spirit Vessel") then return end
        if cast_item_id(me, target, "Urn of Shadows") then return end

        if not ui.blink_out:Get() and not state.done.sign and state.mines_planted >= target_mines then
            local sign_ab = get_ready_ability(me, "techies_minefield_sign", "Minefield Sign")
            if sign_ab then
                Ability.CastPosition(sign_ab, my_pos)
                state.done.sign = true
                pause_action(0.08)
                return
            end
        end

        if try_detonate_mad(me) then return end

        if combo_mode == 1 then
            local stun_rem = get_stun_remaining_time(target)
            local just_landed = state.did_leap and state.landed_at and (now - state.landed_at < 0.35)
            if stun_rem <= 0.35 then
                if not (just_landed and stun_rem == 0 and not is_magic_immune(target)) then
                    if cast_item_id(me, target, "Hex") then return end
                end
            end
        end

        local dagon_done = not ui.use_items:Get("Dagon")
            or not has_item_in_inventory(me, ITEM_NAMES.Dagon)
            or is_item_on_cooldown(me, ITEM_NAMES.Dagon)
            or is_magic_immune(target)

        local eblade_done = not ui.use_items:Get("Ethereal Blade")
            or not has_item_in_inventory(me, ITEM_NAMES["Ethereal Blade"])
            or is_item_on_cooldown(me, ITEM_NAMES["Ethereal Blade"])
            or is_magic_immune(target)

        local mines_done = state.mines_planted >= target_mines
            or state.mines_failed
            or not can_mine
            or now >= state.mine_timeout

        local bomb_done = state.done.bomb
            or not ui.abilities:Get("Sticky Bomb")
            or not get_ready_ability(me, "techies_sticky_bomb", "Sticky Bomb")

        local mad_ab_s4 = NPC.GetAbility(me, "techies_mutually_assured_destruction")
        local mad_ctrl_ok = ui.mad_mode:Get() == 1
            or is_target_controlled(target)
            or (get_stun_remaining_time(target) > 0.1)
            or (state.did_leap and (not state.landed_at or now - state.landed_at < 2.5))
        local mad_done = not ui.use_mad:Get()
            or state.done.mad
            or not mad_ab_s4
            or Ability.IsHidden(mad_ab_s4)
            or not Ability.IsReady(mad_ab_s4)
            or not mad_ctrl_ok

        if (dagon_done and eblade_done and mines_done and bomb_done and mad_done) or (now >= state.step4_deadline) then
            state.step = 5
        end
    elseif state.step == 5 then
        if not state.step5_deadline or state.step5_deadline == 0 then
            state.step5_deadline = now + (ui.use_mad:Get() and 4.5 or 3.0)
        end

        if ui.refresher:Get() and not state.refreshed then
            local ref = get_ready_item(me, REFRESHER_NAMES)
            if ref then
                Ability.CastNoTarget(ref)
                reset_combo_state(true)
                state.refreshed = true
                state.committed = true
                pause_action(0.15)
                state.step = 1
                return
            end
        end

        try_cast_veil(me, target, target_pos)
        try_cast_shiva(me, target_pos)

        if not state.done.Hex and ui.use_items:Get("Hex") and is_valid_target(target) then
            if combo_mode == 0 then
                if cast_item_id(me, target, "Hex") then return end
            elseif combo_mode == 1 then
                local stun_rem = get_stun_remaining_time(target)
                local just_landed = state.did_leap and state.landed_at and (now - state.landed_at < 0.35)
                if stun_rem <= 0.35 then
                    if not (just_landed and stun_rem == 0 and not is_magic_immune(target)) then
                        if cast_item_id(me, target, "Hex") then return end
                    end
                end
            end
        end

        if detonate_tazer(me, target_pos) then return end

        if not state.done["Ethereal Blade"] and ui.use_items:Get("Ethereal Blade") and is_valid_target(target) then
            if cast_item_id(me, target, "Ethereal Blade") then return end
        end

        if not is_item_on_cooldown(me, ITEM_NAMES.Dagon) and ui.use_items:Get("Dagon") and is_valid_target(target) then
            if cast_item_id(me, target, "Dagon") then return end
        end

        local mine_ab = NPC.GetAbility(me, "techies_land_mines")
        local mine_charges = mine_ab and Ability.GetCurrentCharges(mine_ab) or 0
        local can_mine = ui.abilities:Get("Proximity Mines")
            and mine_ab
            and Ability.GetLevel(mine_ab) > 0
            and not Ability.IsHidden(mine_ab)
            and (mine_charges > 0 or state.mine_pending)
            and NPC.GetMana(me) >= Ability.GetManaCost(mine_ab)

        local positions = get_or_create_mine_positions(target)
        local target_mines = positions and math.min(3, #positions) or 3

        if not state.mines_failed and (state.mines_planted < target_mines or state.mine_pending) and can_mine and now < state.mine_timeout then
            if plant_mine(me, target) then return end
        end

        if not state.done.bomb and is_valid_target(target) then
            if cast_bomb(me, target) then return end
        end

        if try_detonate_mad(me) then return end
        if try_cast_mad(me, target, target_pos) then return end

        if ui.blink_out:Get() then
            local hex_pending = ui.use_items:Get("Hex")
                and has_item_in_inventory(me, ITEM_NAMES.Hex)
                and not is_item_on_cooldown(me, ITEM_NAMES.Hex)
                and is_valid_target(target)
                and Entity.IsAlive(target)

            local eblade_pending = ui.use_items:Get("Ethereal Blade")
                and has_item_in_inventory(me, ITEM_NAMES["Ethereal Blade"])
                and not is_item_on_cooldown(me, ITEM_NAMES["Ethereal Blade"])
                and is_valid_target(target)
                and Entity.IsAlive(target)

            local dagon_pending = ui.use_items:Get("Dagon")
                and has_item_in_inventory(me, ITEM_NAMES.Dagon)
                and not is_item_on_cooldown(me, ITEM_NAMES.Dagon)
                and is_valid_target(target)
                and Entity.IsAlive(target)

            local tazer_in_range = false
            if target and Entity.IsAlive(target) then
                local tp = Entity.GetAbsOrigin(target)
                local d_sq = (my_pos.x - tp.x)^2 + (my_pos.y - tp.y)^2
                tazer_in_range = d_sq <= 500 * 500
            end

            local tazer_pending = ui.detonate:Get()
                and NPC.HasModifier(me, "modifier_techies_reactive_tazer")
                and is_valid_target(target)
                and Entity.IsAlive(target)
                and (not state.done.detonate and tazer_in_range or (state.done.detonate and state.tazer_detonate_at and (now - state.tazer_detonate_at < 0.20)))

            local mines_pending = not state.mines_failed
                and (state.mine_pending or state.mines_planted < target_mines)
                and can_mine
                and (now < state.mine_timeout)
                and is_valid_target(target)
                and Entity.IsAlive(target)

            local det_ab = NPC.GetAbility(me, "techies_focused_detonate")
            local mad_ctrl_ok = ui.mad_mode:Get() == 1
                or is_target_controlled(target)
                or (get_stun_remaining_time(target) > 0.1)
                or (state.did_leap and (not state.landed_at or now - state.landed_at < 2.5))
            local mad_can_cast = ui.use_mad:Get() and not state.done.mad
                and mad_ab and not Ability.IsHidden(mad_ab) and Ability.IsReady(mad_ab)
                and NPC.GetMana(me) >= Ability.GetManaCost(mad_ab)
                and is_valid_target(target) and Entity.IsAlive(target)
                and mad_ctrl_ok

            local mad_in_phase = mad_ab and Ability.IsInAbilityPhase(mad_ab)
            local mad_waiting_detonate = state.done.mad and not state.done.mad_detonate and state.mad_cast_at and (now - state.mad_cast_at < 2.0)
            local mad_needs_detonate = not state.done.mad_detonate and det_ab and not Ability.IsHidden(det_ab)
            local mad_pending = mad_can_cast or mad_in_phase or mad_waiting_detonate or mad_needs_detonate

            local sil_item_ready = get_ready_item(me, ITEM_NAMES.Bloodthorn) or get_ready_item(me, ITEM_NAMES.Orchid)
            local sil_id_ready = get_ready_item(me, ITEM_NAMES.Bloodthorn) and "Bloodthorn" or "Orchid"
            local sil_pending = not state.done[sil_id_ready] and ui.use_items:Get(sil_id_ready) and sil_item_ready ~= nil

            local bomb_pending = not state.done.bomb
                and ui.abilities:Get("Sticky Bomb")
                and get_ready_ability(me, "techies_sticky_bomb", "Sticky Bomb") ~= nil

            if (not hex_pending and not eblade_pending and not dagon_pending and not sil_pending and not tazer_pending and not bomb_pending and not mines_pending and not state.mine_pending and not mad_pending) or (now >= state.step5_deadline) then
                state.blink_until = now + 3.5
                state.step = 10
                return
            end
        end

        try_detonate_mad(me)
        if not is_valid_target(target) or not Entity.IsAlive(target) then
            if state.committed and ui.blink_out:Get() then
                state.blink_until = now + 3.5
                state.step = 10
                return
            end
            if state.committed then
                state.completed = true
            end
            return stop_combo()
        end

        try_auto_attack(me, target)
    elseif state.step == 6 then
        if NPC.HasModifier(me, "modifier_techies_suicide_leap") then
            state.committed = true
            state.did_leap = true
            if not state.leap_start then
                state.leap_start = now
            end
            local mod = NPC.GetModifier(me, "modifier_techies_suicide_leap")
            if mod then
                local die_time = Modifier.GetDieTime(mod)
                if die_time and die_time > now then
                    state.land_at = die_time
                end
            end
            state.aim_pos = target_pos or state.manual_blast_pos or my_pos
            state.mine_center = target_pos or state.manual_blast_pos or my_pos
            state.step = 3
            return
        end
        try_detonate_mad(me)
        if not is_valid_target(target) or not Entity.IsAlive(target) then
            if state.committed and ui.blink_out:Get() then
                state.blink_until = now + 3.5
                state.step = 10
                return
            end
            if state.committed then
                state.completed = true
            end
            return stop_combo()
        end

        if not state.step6_start_at then
            state.step6_start_at = now
        end
        if state.mine_timeout == 0 then
            state.mine_timeout = now + 2.5
        end

        if now - state.step6_start_at > 5.0 then
            if state.committed then
                state.completed = true
            end
            return stop_combo()
        end

        local target_pos = Entity.GetAbsOrigin(target)
        local dx, dy = target_pos.x - my_pos.x, target_pos.y - my_pos.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > 1600 then
            if state.committed then
                state.completed = true
            end
            return stop_combo()
        end

        if dist <= 900 then
            try_use_soul_ring(me)
        end

        if is_linkens_protected(target) then
            if try_break_linken(me, target) then return end
            local immune = is_magic_immune(target)
            for _, id in ipairs(ui.breaker:ListEnabled()) do
                local names = ITEM_NAMES[id]
                if names and (MAGIC_PIERCE_ITEMS[id] or not immune) and get_ready_item(me, names) then
                    NPC.MoveTo(me, target_pos)
                    pause_action(0.06)
                    return
                end
            end
        end

        if not state.done.Hex and ui.use_items:Get("Hex") and is_valid_target(target) then
            local hex_item = get_ready_item(me, ITEM_NAMES.Hex)
            if hex_item then
                local hex_r = get_cast_range(me, hex_item) + 150
                local should_hex = false
                if combo_mode == 0 then
                    should_hex = true
                elseif combo_mode == 1 then
                    local stun_rem = get_stun_remaining_time(target)
                    local just_landed = state.did_leap and state.landed_at and (now - state.landed_at < 0.35)
                    if stun_rem <= 0.35 then
                        if not (just_landed and stun_rem == 0 and not is_magic_immune(target)) then
                            should_hex = true
                        end
                    end
                end

                if should_hex then
                    if dist <= hex_r then
                        if cast_item_id(me, target, "Hex") then return end
                    else
                        NPC.MoveTo(me, target_pos)
                        pause_action(0.06)
                        return
                    end
                end
            end
        end

        local sil_item = get_ready_item(me, ITEM_NAMES.Bloodthorn) or get_ready_item(me, ITEM_NAMES.Orchid)
        local sil_id = get_ready_item(me, ITEM_NAMES.Bloodthorn) and "Bloodthorn" or "Orchid"
        if not state.done[sil_id] and ui.use_items:Get(sil_id) and sil_item then
            local sil_r = get_cast_range(me, sil_item) + 150
            if dist <= sil_r then
                if cast_item_id(me, target, sil_id) then return end
            else
                NPC.MoveTo(me, target_pos)
                pause_action(0.06)
                return
            end
        end

        if cast_item_id(me, target, "Nullifier") then return end
        if cast_item_id(me, target, "Ethereal Blade") then return end

        local has_ethereal = NPC.HasModifier(target, "modifier_item_ethereal_blade_ethereal")
        local eblade_flying = state.eblade_cast_at and (now - state.eblade_cast_at < 0.25) and not has_ethereal
        if eblade_flying then
            pause_action(0.04)
            return
        end

        if not is_item_on_cooldown(me, ITEM_NAMES.Dagon) and ui.use_items:Get("Dagon") then
            if cast_item_id(me, target, "Dagon") then return end
        end

        try_cast_veil(me, target, target_pos)
        try_cast_shiva(me, target_pos)

        if cast_tazer(me) then return end

        local bomb_ab = get_ready_ability(me, "techies_sticky_bomb", "Sticky Bomb")
        if not state.done.bomb and bomb_ab then
            local bomb_r = get_cast_range(me, bomb_ab) + 100
            if dist <= bomb_r then
                if cast_bomb(me, target) then return end
            else
                NPC.MoveTo(me, target_pos)
                pause_action(0.06)
                return
            end
        end

        if try_detonate_mad(me) then return end
        if try_cast_mad(me, target, target_pos) then return end

        local mine_ab = NPC.GetAbility(me, "techies_land_mines")
        local mine_charges = mine_ab and Ability.GetCurrentCharges(mine_ab) or 0
        local positions = get_or_create_mine_positions(target)
        local target_mines = positions and math.min(3, #positions) or 3
        if mine_ab and mine_charges > 0 and state.mines_planted < target_mines and now < state.mine_timeout then
            if plant_mine(me, target) then return end
            local mine_r = get_cast_range(me, mine_ab) + 25
            if dist > mine_r then
                NPC.MoveTo(me, target_pos)
                pause_action(0.06)
                return
            end
        end

        if detonate_tazer(me, target_pos) then return end

        if cast_item_id(me, target, "Spirit Vessel") then return end
        if cast_item_id(me, target, "Urn of Shadows") then return end

        if not ui.blink_out:Get() and not state.done.sign and state.mines_planted >= target_mines then
            local sign_ab = get_ready_ability(me, "techies_minefield_sign", "Minefield Sign")
            if sign_ab then
                Ability.CastPosition(sign_ab, my_pos)
                state.done.sign = true
                pause_action(0.08)
                return
            end
        end

        if try_detonate_mad(me) then return end

        if ui.refresher:Get() and not state.refreshed then
            local ref = get_ready_item(me, REFRESHER_NAMES)
            if ref then
                Ability.CastNoTarget(ref)
                reset_combo_state(true)
                state.refreshed = true
                state.committed = true
                pause_action(0.15)
                state.step = 1
                return
            end
        end

        try_auto_attack(me, target)

        if not NPC.IsAttacking(me) and dist > NPC.GetAttackRange(me) + 50 then
            NPC.MoveTo(me, target_pos)
        end

        if ui.blink_out:Get() then
            local hex_pending = ui.use_items:Get("Hex")
                and has_item_in_inventory(me, ITEM_NAMES.Hex)
                and not is_item_on_cooldown(me, ITEM_NAMES.Hex)
                and is_valid_target(target)
                and Entity.IsAlive(target)

            local eblade_pending = ui.use_items:Get("Ethereal Blade")
                and has_item_in_inventory(me, ITEM_NAMES["Ethereal Blade"])
                and not is_item_on_cooldown(me, ITEM_NAMES["Ethereal Blade"])
                and is_valid_target(target)
                and Entity.IsAlive(target)

            local dagon_pending = ui.use_items:Get("Dagon")
                and has_item_in_inventory(me, ITEM_NAMES.Dagon)
                and not is_item_on_cooldown(me, ITEM_NAMES.Dagon)
                and is_valid_target(target)
                and Entity.IsAlive(target)

            local sil_item_ready = get_ready_item(me, ITEM_NAMES.Bloodthorn) or get_ready_item(me, ITEM_NAMES.Orchid)
            local sil_id_ready = get_ready_item(me, ITEM_NAMES.Bloodthorn) and "Bloodthorn" or "Orchid"
            local sil_pending = not state.done[sil_id_ready] and ui.use_items:Get(sil_id_ready) and sil_item_ready ~= nil

            local tazer_in_range = dist <= 500
            local tazer_pending = ui.detonate:Get()
                and NPC.HasModifier(me, "modifier_techies_reactive_tazer")
                and is_valid_target(target)
                and Entity.IsAlive(target)
                and (not state.done.detonate and tazer_in_range or (state.done.detonate and state.tazer_detonate_at and (now - state.tazer_detonate_at < 0.20)))

            local bomb_pending = not state.done.bomb
                and ui.abilities:Get("Sticky Bomb")
                and get_ready_ability(me, "techies_sticky_bomb", "Sticky Bomb") ~= nil

            local can_mine = ui.abilities:Get("Proximity Mines")
                and mine_ab
                and Ability.GetLevel(mine_ab) > 0
                and not Ability.IsHidden(mine_ab)
                and (Ability.GetCurrentCharges(mine_ab) > 0 or state.mine_pending)
                and NPC.GetMana(me) >= Ability.GetManaCost(mine_ab)

            local mines_pending = not state.mines_failed
                and (state.mines_planted < target_mines or state.mine_pending)
                and can_mine
                and (now < state.mine_timeout)

            local det_ab = NPC.GetAbility(me, "techies_focused_detonate")
            local mad_ctrl_ok = ui.mad_mode:Get() == 1
                or is_target_controlled(target)
                or (get_stun_remaining_time(target) > 0.1)
                or (state.did_leap and (not state.landed_at or now - state.landed_at < 2.5))
            local mad_can_cast = ui.use_mad:Get() and not state.done.mad
                and mad_ab and not Ability.IsHidden(mad_ab) and Ability.IsReady(mad_ab)
                and NPC.GetMana(me) >= Ability.GetManaCost(mad_ab)
                and is_valid_target(target) and Entity.IsAlive(target)
                and mad_ctrl_ok

            local mad_in_phase = mad_ab and Ability.IsInAbilityPhase(mad_ab)
            local mad_waiting_detonate = state.done.mad and not state.done.mad_detonate and state.mad_cast_at and (now - state.mad_cast_at < 2.0)
            local mad_needs_detonate = not state.done.mad_detonate and det_ab and not Ability.IsHidden(det_ab)
            local mad_pending = mad_can_cast or mad_in_phase or mad_waiting_detonate or mad_needs_detonate

            local all_actions_done = not hex_pending and not eblade_pending and not dagon_pending and not sil_pending and not tazer_pending and not bomb_pending and not mines_pending and not state.mine_pending and not mad_pending
            local step6_timeout = state.step6_start_at and (now - state.step6_start_at >= (ui.use_mad:Get() and 4.5 or 3.0))

            if all_actions_done or step6_timeout then
                state.blink_until = now + 3.5
                state.step = 10
                return
            end
        end
    elseif state.step == 10 then
        try_detonate_mad(me)

        if not has_item_in_inventory(me, BLINK_NAMES) then
            state.completed = true
            stop_combo()
            return
        end

        local dst = get_escape_pos(me)
        local dagger = get_ready_item(me, BLINK_NAMES)
        if dagger and dst then
            local dx, dy = dst.x - my_pos.x, dst.y - my_pos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 20 then
                local max_range = Ability.GetCastRange(dagger)
                local blink_dist = math.min(dist, max_range > 0 and (max_range - 25) or 1175)
                local bx = my_pos.x + dx / dist * blink_dist
                local by = my_pos.y + dy / dist * blink_dist
                local blink_pos = make_ground_pos(bx, by, my_pos.z)
                Ability.CastPosition(dagger, blink_pos, false, true, false, "tc_blink")
                state.completed = true
                stop_combo()
                return
            end
        end

        if now > state.blink_until then
            state.completed = true
            stop_combo()
            return
        end

        if dst then
            NPC.MoveTo(me, dst)
            pause_action(0.05)
        elseif is_valid_target(target) and Entity.IsAlive(target) then
            try_auto_attack(me, target)
        end
    end
end

local function draw_ground_circle(center, radius, color, thickness, segments)
    segments = segments or 48
    thickness = thickness or 1.5
    local step = (math.pi * 2) / segments
    local prev_sp, prev_vis
    for i = 0, segments do
        local a = i * step
        local wx = center.x + math.cos(a) * radius
        local wy = center.y + math.sin(a) * radius
        local gz = World.GetGroundZ and World.GetGroundZ(wx, wy)
        local wz = (gz and gz > -5000 and gz or center.z) + 4
        local sp, vis = Render.WorldToScreen(Vector(wx, wy, wz))
        if i > 0 and prev_vis and vis then
            Render.Line(prev_sp, sp, color, thickness)
        end
        prev_sp, prev_vis = sp, vis
    end
end

local function draw_target_indicator(target, is_locked)
    local target_pos = Entity.GetAbsOrigin(target)
    if not target_pos then return end

    local col = is_locked and Color(245, 75, 45, 210) or Color(245, 140, 35, 150)
    local r = 65

    draw_ground_circle(target_pos, r, col, 1.5, 36)

    for _, angle in ipairs({ 0.785398, 2.356194, 3.926991, 5.497787 }) do
        local ca, sa = math.cos(angle), math.sin(angle)
        local x1 = target_pos.x + ca * r
        local y1 = target_pos.y + sa * r
        local gz1 = World.GetGroundZ and World.GetGroundZ(x1, y1)
        local z1 = (gz1 and gz1 > -5000 and gz1 or target_pos.z) + 4
        local sp1, vis1 = Render.WorldToScreen(Vector(x1, y1, z1))

        local x2 = target_pos.x + ca * (r + 14)
        local y2 = target_pos.y + sa * (r + 14)
        local gz2 = World.GetGroundZ and World.GetGroundZ(x2, y2)
        local z2 = (gz2 and gz2 > -5000 and gz2 or target_pos.z) + 4
        local sp2, vis2 = Render.WorldToScreen(Vector(x2, y2, z2))

        if vis1 and vis2 then
            Render.Line(sp1, sp2, col, 1.8)
        end
    end
end

local function is_blast_key_down(me)
    if not me then return false end
    local raw_blast = NPC.GetAbility(me, "techies_suicide")
    if not raw_blast or Ability.GetLevel(raw_blast) == 0 then return false end
    if not Ability.IsCastable(raw_blast) then return false end
    if NPC.IsSilenced(me) or NPC.IsStunned(me) then return false end
    local kb = Ability.GetKeybind(raw_blast)
    if not kb or kb == "" then return false end
    local upper_kb = kb:upper()
    local code = Enum.ButtonCode[upper_kb] or Enum.ButtonCode["KEY_" .. upper_kb]
    return (code and Input.IsKeyDown(code)) or false
end

local function draw_hero_ring(my_pos, is_locked)
    if not my_pos then return end
    local r = 75
    local col_glow = is_locked and Color(0, 220, 255, 85) or Color(0, 195, 240, 55)
    local col_ring = is_locked and Color(0, 240, 255, 220) or Color(0, 215, 255, 175)

    draw_ground_circle(my_pos, r, col_glow, 3.2, 40)
    draw_ground_circle(my_pos, r, col_ring, 1.6, 40)
end

local function draw_targeting_line(from_pos, to_pos, is_locked, is_in_range)
    if not from_pos or not to_pos then return end

    local gz_from = World.GetGroundZ and World.GetGroundZ(from_pos.x, from_pos.y)
    local wz_from = (gz_from and gz_from > -5000 and gz_from or from_pos.z) + 24
    local sp_from, vis_from = Render.WorldToScreen(Vector(from_pos.x, from_pos.y, wz_from))

    local gz_to = World.GetGroundZ and World.GetGroundZ(to_pos.x, to_pos.y)
    local wz_to = (gz_to and gz_to > -5000 and gz_to or to_pos.z) + 24
    local sp_to, vis_to = Render.WorldToScreen(Vector(to_pos.x, to_pos.y, wz_to))

    if not vis_from and not vis_to then return end

    local dx = sp_to.x - sp_from.x
    local dy = sp_to.y - sp_from.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 24 then return end

    local nx = dx / len
    local ny = dy / len
    local px = -ny
    local py = nx

    local col_glow, col_core, col_arrow
    if is_locked then
        col_glow  = Color(255, 45, 75, 55)
        col_core  = Color(255, 65, 95, 215)
        col_arrow = Color(255, 195, 205, 240)
    elseif is_in_range then
        col_glow  = Color(245, 60, 90, 45)
        col_core  = Color(250, 80, 105, 185)
        col_arrow = Color(255, 185, 195, 220)
    else
        col_glow  = Color(230, 90, 60, 35)
        col_core  = Color(240, 110, 70, 150)
        col_arrow = Color(255, 190, 170, 190)
    end

    Render.Line(sp_from, sp_to, col_glow, 6.0)
    Render.Line(sp_from, sp_to, col_core, 2.2)

    local now = GameRules.GetGameTime()
    local step_dist = 28.0
    local anim_offset = (now * 35.0) % step_dist
    local cur_dist = 20.0 + anim_offset
    local end_dist = len - 18.0

    while cur_dist < end_dist do
        local cx = sp_from.x + nx * cur_dist
        local cy = sp_from.y + ny * cur_dist

        local tip = Vec2(cx + nx * 5, cy + ny * 5)
        local w1  = Vec2(cx - nx * 5 + px * 4.5, cy - ny * 5 + py * 4.5)
        local w2  = Vec2(cx - nx * 5 - px * 4.5, cy - ny * 5 - py * 4.5)

        Render.Line(w1, tip, col_arrow, 1.6)
        Render.Line(w2, tip, col_arrow, 1.6)

        cur_dist = cur_dist + step_dist
    end
end

local function draw_blast_indicator(aim_pos, is_locked, me)
    if not aim_pos then return end

    local blast_ab = NPC.GetAbility(me, "techies_suicide")
    local blast_radius = (blast_ab and Ability.GetLevelSpecialValueFor(blast_ab, "radius")) or 400
    if blast_radius <= 0 then blast_radius = 400 end

    local col_ring = is_locked and Color(255, 70, 95, 230) or Color(245, 80, 105, 190)
    local col_glow = is_locked and Color(255, 50, 80, 85)  or Color(240, 60, 90, 60)

    draw_ground_circle(aim_pos, blast_radius, col_glow, 3.6, 60)
    draw_ground_circle(aim_pos, blast_radius, col_ring, 1.8, 60)
end

local cached_barrel_positions = {}
local last_barrel_scan = 0

local function update_cached_barrels(me, now)
    if not ui.use_mad:Get() then
        cached_barrel_positions = {}
        return
    end
    if now - last_barrel_scan < 0.20 then
        return
    end
    last_barrel_scan = now
    cached_barrel_positions = {}
    local my_team = Entity.GetTeamNum(me)
    for _, npc in ipairs(NPCs.GetAll()) do
        local uname = NPC.GetUnitName(npc)
        if Entity.IsAlive(npc) and (uname == "npc_dota_techies_remote_mine" or uname == "npc_dota_techies_innate_mine") and Entity.GetTeamNum(npc) == my_team then
            local b_pos = Entity.GetAbsOrigin(npc)
            if b_pos then
                cached_barrel_positions[#cached_barrel_positions + 1] = b_pos
            end
        end
    end
end

local function draw_all(me)
    local my_pos = Entity.GetAbsOrigin(me)
    if not my_pos then return end

    local now = GameRules.GetGameTime()
    local raw_blast = NPC.GetAbility(me, "techies_suicide")
    local in_leap = NPC.HasModifier(me, "modifier_techies_suicide_leap")
    local is_casting_blast = raw_blast and Ability.IsInAbilityPhase(raw_blast)

    local is_aiming = is_blast_key_down(me)
    local manual_pos = state.manual_blast_pos
    local has_manual_pos = (manual_pos ~= nil)

    local target = state.target
    local is_locked = (state.step > 0 and is_valid_target(target))
    local is_key_down = Input.IsKeyDown(ui.key:Get())
    local is_test_active = state.test_active_until and now < state.test_active_until
    local show_preview = ui.draw_preview:Get()
    local combo_active = is_key_down or is_test_active or is_locked

    local blast_drawn = false
    if ui.draw_blast:Get() and (has_manual_pos or is_aiming) then
        local blast_pos = manual_pos or Input.GetWorldCursorPos()
        if blast_pos then
            draw_blast_indicator(blast_pos, is_locked, me)
            blast_drawn = true
        end
    end

    if ui.use_mad:Get() then
        for _, b_pos in ipairs(cached_barrel_positions) do
            draw_ground_circle(b_pos, 400, Color(255, 90, 30, 160), 1.5, 36)
            local sp, vis = Render.WorldToScreen(b_pos)
            if vis then
                Render.FilledCircle(sp, 4, Color(255, 120, 40, 220))
            end
        end
    end

    if not combo_active and not show_preview then
        return
    end

    if not is_locked then
        local hover = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)
        if is_valid_target(hover) then
            local hp = Entity.GetAbsOrigin(hover)
            local dx, dy = my_pos.x - hp.x, my_pos.y - hp.y
            if dx * dx + dy * dy <= 1600 * 1600 then
                target = hover
            end
        end
    end

    if not is_valid_target(target) then return end

    local target_pos = Entity.GetAbsOrigin(target)
    if not target_pos then return end

    local blast_range = raw_blast and get_cast_range(me, raw_blast) or 1000
    local dist_to_tgt = math.sqrt((target_pos.x - my_pos.x)^2 + (target_pos.y - my_pos.y)^2)
    local is_in_range = dist_to_tgt <= blast_range + 50

    local aim_pos = state.aim_pos
    if not aim_pos then
        if manual_pos and in_leap then
            aim_pos = manual_pos
        elseif raw_blast and Ability.GetLevel(raw_blast) > 0 then
            local cast_point = Ability.GetCastPoint(raw_blast)
            local total_time = cast_point + 0.90
            aim_pos = predict_blast_pos(target, raw_blast) or predict_target_pos(target, total_time)
        else
            aim_pos = target_pos
        end
    end

    if ui.draw_line:Get() or ui.draw_blast:Get() then
        draw_hero_ring(my_pos, is_locked)
    end

    if ui.draw_line:Get() then
        draw_targeting_line(my_pos, aim_pos, is_locked, is_in_range)
    end

    local blast_ready = raw_blast
        and Ability.GetLevel(raw_blast) > 0
        and Ability.GetCooldown(raw_blast) == 0
        and ui.abilities:Get("Blast Off")

    local want_blast_draw = ui.draw_blast:Get()
        and not blast_drawn
        and (in_leap or is_casting_blast or (combo_active and state.step <= 2 and blast_ready) or (show_preview and blast_ready))

    if want_blast_draw then
        draw_blast_indicator(aim_pos, is_locked, me)
    end

    if ui.draw_target:Get() then
        draw_target_indicator(target, is_locked)
    end

    if state.mine_positions and state.step >= 3 and state.step <= 6 then
        for _, mp in ipairs(state.mine_positions) do
            draw_ground_circle(mp, 20, Color(255, 140, 20, 180), 1.5, 20)
            local sp, vis = Render.WorldToScreen(mp)
            if vis then
                Render.FilledCircle(sp, 3, Color(255, 180, 50, 220))
            end
        end
    end
end

local ORDER_NAMES = {}
if Enum and Enum.UnitOrder then
    for k, v in pairs(Enum.UnitOrder) do
        ORDER_NAMES[v] = k:gsub("^DOTA_UNIT_ORDER_", "")
    end
end

function script.OnPrepareUnitOrders(data)
    if not data then return true end
    if not ui.enable:Get() then return true end
    local me = Heroes.GetLocal()
    if not me then return true end
    if data.npc and data.npc ~= me then return true end

    local ab_name = data.ability and Ability.GetName(data.ability)
    if ab_name == "techies_suicide" then
        local pos = data.position
        if not pos and data.target then
            pos = Entity.GetAbsOrigin(data.target)
        end
        if pos then
            state.manual_blast_pos = pos
            state.manual_blast_order_time = GameRules.GetGameTime()
            state.blast_was_casting = false
        end
    elseif (data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_STOP or data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION) and not NPC.HasModifier(me, "modifier_techies_suicide_leap") then
        state.manual_blast_pos = nil
        state.manual_blast_order_time = nil
        state.blast_was_casting = false
    end

    if state.step > 0 and Log and Log.Write then
        local order_str = ORDER_NAMES[data.order] or tostring(data.order)
        local ident = data.identifier or "-"
        Log.Write(string.format("[Techies Order] step=%d order=%s ab=%s id=%s q=%s",
            state.step, order_str, ab_name or "none", tostring(ident), tostring(data.queue)))
    end

    return true
end

function script.OnModifierCreate(entity, modifier)
    if not ui.enable:Get() then return end
    local me = Heroes.GetLocal()
    if not me or entity ~= me then return end

    local name = Modifier.GetName(modifier)
    if name == "modifier_techies_suicide_leap" then
        local now = GameRules.GetGameTime()
        state.leap_start = now
        state.did_leap = true
        if state.manual_blast_pos then
            state.aim_pos = state.manual_blast_pos
            state.mine_center = (state.target and Entity.IsAlive(state.target) and Entity.GetAbsOrigin(state.target)) or state.manual_blast_pos
        end
        local blast_ab = NPC.GetAbility(me, "techies_suicide")
        local cast_point = blast_ab and Ability.GetCastPoint(blast_ab) or 0
        local die_time = Modifier.GetDieTime and Modifier.GetDieTime(modifier)
        local dur = Modifier.GetDuration and Modifier.GetDuration(modifier)
        local rem_str = (die_time and die_time > now) and string.format("%.3f", die_time - now) or "nil"
        if Log and Log.Write then
            Log.Write(string.format("[Techies Leap] Started at %.3f (step=%d) CastPoint=%.3f DieTime=%s Dur=%s rem=%s",
                now, state.step, cast_point, tostring(die_time), tostring(dur), rem_str))
        end
        if die_time and die_time > now then
            state.land_at = die_time
        end
        if state.step == 2 or state.step == 6 then
            state.step = 3
        end
    end
end

function script.OnModifierDestroy(entity, modifier)
    if not ui.enable:Get() then return end
    local me = Heroes.GetLocal()
    if not me or entity ~= me then return end

    local name = Modifier.GetName(modifier)
    if name == "modifier_techies_suicide_leap" then
        state.manual_blast_pos = nil
        state.manual_blast_order_time = nil
        state.blast_was_casting = false
        local now = GameRules.GetGameTime()
        local dur = (state.leap_start and state.leap_start > 0) and (now - state.leap_start) or 0
        local my_pos = Entity.GetAbsOrigin(me)
        state.landed_at = now
        if Log and Log.Write then
            local goal_dist_str = "none"
            if state.aim_pos and my_pos then
                goal_dist_str = string.format("%.1f", math.sqrt(dist_sq_2d(my_pos, state.aim_pos)))
            end
            local unplanted_str = ""
            if state.mine_positions then
                for i = state.mines_planted + 1, #state.mine_positions do
                    local pt = state.mine_positions[i]
                    if pt and my_pos then
                        local d = math.sqrt(dist_sq_2d(my_pos, pt))
                        unplanted_str = unplanted_str .. string.format(" [#%d dist=%.1f]", i, d)
                    end
                end
            end
            Log.Write(string.format("[Techies Leap] Ended at %.3f (duration: %.3fs, mines: %d, dist_to_goal: %s, unplanted:%s, step=%d)",
                now, dur, state.mines_planted, goal_dist_str, unplanted_str == "" and " none" or unplanted_str, state.step))
        end
        if state.step == 3 then
            state.step = 4
        end
    end
end

function script.OnDraw()
    if not ui.enable:Get() then return end
    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= "npc_dota_hero_techies" or not Entity.IsAlive(me) then return end

    local now = GameRules.GetGameTime()
    local is_key_down = Input.IsKeyDown(ui.key:Get())
    local is_test_active = state.test_active_until and now < state.test_active_until
    local show_preview = ui.draw_preview:Get()

    local raw_blast = NPC.GetAbility(me, "techies_suicide")
    local in_leap = NPC.HasModifier(me, "modifier_techies_suicide_leap")
    local is_casting_blast = raw_blast and Ability.IsInAbilityPhase(raw_blast)

    local is_aiming = is_blast_key_down(me)
    local has_manual_pos = (state.manual_blast_pos ~= nil)
    local manual_blast_active = ui.draw_blast:Get() and (has_manual_pos or is_aiming)

    update_cached_barrels(me, now)
    local has_barrel = #cached_barrel_positions > 0

    if not is_key_down and not is_test_active and not show_preview and not manual_blast_active and not has_barrel then
        return
    end

    local ok, err = pcall(draw_all, me)
    if not ok and err ~= state.draw_error then
        state.draw_error = err
        Log.Write("[Techies] draw: " .. tostring(err))
    end
end

function script.OnGameEnd()
    stop_combo()
    state.completed = false
    state.fountain = nil
    state.draw_error = nil
    state.leap_start = nil
    cached_barrel_positions = {}
    last_barrel_scan = 0
end

function techies_trigger(target, dur, ground_mode, mad_mode, blink_out, combo_mode)
    ui.enable:Set(true)
    if ground_mode ~= nil then
        ui.abilities:Set("Blast Off", not ground_mode)
    end
    if mad_mode ~= nil then
        ui.mad_mode:Set(mad_mode)
    end
    if blink_out ~= nil then
        ui.blink_out:Set(blink_out)
    end
    if combo_mode ~= nil then
        ui.mode:Set(combo_mode)
    end
    local now = GameRules.GetGameTime()
    state.test_active_until = now + (dur or 3.5)
    state.test_target = target
end

function techies_get_state()
    return {
        step = state.step,
        mode = ui.mode and ui.mode:Get() or -1,
        use_hex = ui.use_items and ui.use_items:Get("Hex") or false,
        use_bomb = ui.abilities and ui.abilities:Get("Sticky Bomb") or false,
        committed = state.committed,
        completed = state.completed,
        did_leap = state.did_leap,
        landed_at = state.landed_at,
        mines_planted = state.mines_planted,
        mine_pending = state.mine_pending,
        done = state.done,
        blink_until = state.blink_until,
        mines_failed = state.mines_failed,
    }
end

function techies_test_recalc(raw_cast_range_override, target, next_idx, mock_planted, hero_pos_override)
    local me = Heroes.GetLocal()
    if not me then return { error = "no local hero" } end
    local mine_ab = NPC.GetAbility(me, "techies_land_mines")
    local raw_cast_range = raw_cast_range_override or get_cast_range(me, mine_ab)
    if mock_planted then
        state.mine_positions = mock_planted
    end
    local my_pos = hero_pos_override or Entity.GetAbsOrigin(me)
    local tp = target and Entity.GetAbsOrigin(target) or state.mine_center or my_pos
    local res = find_fallback_mine_pos(me, target, next_idx or 3, raw_cast_range, hero_pos_override)
    if not res then
        return {
            found = false,
            dist_to_target = math.sqrt(dist_sq_2d(my_pos, tp)),
            cast_range = raw_cast_range,
        }
    end
    local d_hero = math.sqrt(dist_sq_2d(my_pos, res))
    local d_target = math.sqrt(dist_sq_2d(tp, res))
    local min_prev_dist = 99999
    if state.mine_positions then
        for i = 1, (next_idx or 3) - 1 do
            local prev = state.mine_positions[i]
            if prev then
                local d = math.sqrt(dist_sq_2d(res, prev))
                if d < min_prev_dist then min_prev_dist = d end
            end
        end
    end
    return {
        found = true,
        pos = { x = res.x, y = res.y, z = res.z },
        dist_to_hero = d_hero,
        dist_to_target = d_target,
        min_dist_to_prev = min_prev_dist,
        within_hero_range = d_hero <= (raw_cast_range + 25),
        within_target_radius = d_target <= 400.0,
        valid_prev_dist = min_prev_dist >= 355.0,
        is_traversable = is_tile_traversable(res),
        has_trees = has_trees_near(res, 50),
    }
end

return script
