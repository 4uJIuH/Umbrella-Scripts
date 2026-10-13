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

--author: flatixxx
local script = {}

local PATHS = {
    "particles/econ/seasonal/seasonal_ambient_silver.vpcf",
    "particles/econ/seasonal/seasonal_ambient_candy_mint.vpcf",
    "particles/econ/seasonal/seasonal_ambient_snow.vpcf",
    "particles/econ/seasonal/new_bloom/seasonal_ambient_gold_glow.vpcf",
    "particles/econ/seasonal/new_bloom/seasonal_ambient_smoke.vpcf",
    "particles/econ/seasonal/crownfall/seasonal_ambient_screeauk.vpcf",
    "particles/econ/seasonal/crownfall/seasonal_ambient_screeauk_v2.vpcf",
}

local EFFECTS = { "Frostbloom", "Candy Caster", "Snowdrift", "Gold Glow", "Smoke", "Ravenblight", "Featherfall" }

local HEROES = {
    { "Invoker", "npc_dota_hero_invoker", {
        { "Nothern Blight Style", 0, { true, false }, nil, nil, nil, nil, "top" },
        { "Master of the Mystic Phoenix - Head", 0, { false, false } },
    } },
    { "Bloodseeker", "npc_dota_hero_bloodseeker", { { "Blood Raven - Offhand", 0, nil, nil, nil, "side" } } },
    { "Lina", "npc_dota_hero_lina", { { "Imperial Ember - Crown", 0, { true, false } } } },
    { "Legion Commander", "npc_dota_hero_legion_commander", { { "Phalanx Of The Bronze Eagle", 1, nil, true } } },
    { "Nature's Prophet", "npc_dota_hero_furion", { { "Verdantt Swarm - Weapon", 1 } } },
    { "Wraith King", "npc_dota_hero_skeleton_king", {
        { "King Kringle's Tannenkromm", 1 },
        { "Crown of the Condor - Weapon", 4 },
    } },
    { "Crystal Maiden", "npc_dota_hero_crystal_maiden", {
        { "Guardian Snow Angel - Armor", 0, { false, true } },
        { "Spirit of the Frozen Flow - Head", 0, { true, false } },
        { "Roost of the Winter Raven - Head", 3 },
        { "Roost of the Winter Raven - Weapon", 1 },
    } },
    { "Alchemist", "npc_dota_hero_alchemist", {
        { "Lumpo and Rupertus - Weapon", 1 },
        { "Potion Potentate - Weapon", 2, nil, true },
        { "Frostreach Brigands Axes", 2, nil, true },
    } },
    { "Primal Beast", "npc_dota_hero_primal_beast", { { "The Abominable Snowbeast - Legs", 0, nil, nil, nil, "pair" } } },
    { "Ancient Apparition", "npc_dota_hero_ancient_apparition", {
        { "Silent Wight - Arms", 0, { false, true }, nil, nil, nil, nil, 2 },
        { "Silent Wight - Scarf", 0, { false, true } },
        { "Silent Wight - Hood", 0, { true, true } },
        { "Crystalline Crown - Shoulder", 2 },
        { "Crystalline Crown - Head", 4, nil, true },
    } },
    { "Snapfire", "npc_dota_hero_snapfire", { { "Silver Squall - Weapon", 1 } } },
    { "Arc Warden", "npc_dota_hero_arc_warden", { { "Orbuculum Equinox", 0, { false, true }, nil, nil, nil, nil, "right" } } },
    { "Tusk", "npc_dota_hero_tusk", { { "Jingle Fist", 0, { false, true } } } },
    { "Spirit Breaker", "npc_dota_hero_spirit_breaker", { { "Gust of the Surging Wind", 1 } } },
    { "Drow Ranger", "npc_dota_hero_drow_ranger", {
        { "Bow of Zebulon", 0, { true, true } },
        { "Ravencloak - Weapon", 1 },
    } },
    { "Silencer", "npc_dota_hero_silencer", {
        { "Glaive of Eternal Night", 0, { false, false } },
        { "Whispering Wings - Weapon", 1 },
    } },
    { "Ursa", "npc_dota_hero_ursa", { { "Claws of the Crystal Drift", 1 } } },
    { "Lich", "npc_dota_hero_lich", { { "Bracer of Vile Convocation", 0, { true, false } } } },
    { "Tiny", "npc_dota_hero_tiny", { { "Frostmoot Tree", 1, nil, nil, "modifier_tiny_tree_grab" } } },
    { "Puck", "npc_dota_hero_puck", {
        { "Crown of Curious Coldspell", 0, { true, false } },
        { "Mischief of the Winter Moth - Back", 0, { true, false }, nil, nil, nil, nil, 2 },
        { "Vanishing Pearl - Head", 1 },
    } },
    { "Pudge", "npc_dota_hero_pudge", {
        { "Frosty the Sew-Man's Sugary Shiv", 1 },
        { "Hook of the Odobenus One", 0, { false, false } },
        { "Sawtooth of the Odobenus One", 0, { true, false } },
    } },
    { "Batrider", "npc_dota_hero_batrider", { { "Verna", 1 } } },
    { "Sand King", "npc_dota_hero_sand_king", { { "Claws of the Frostbite Dunes", 1 } } },
    { "Keeper of the Light", "npc_dota_hero_keeper_of_the_light", {
        { "Flight of the Gryphon Lord - Weapon", 1 },
        { "Flight of the Gryphon Lord - Head", 0, { true, false }, nil, nil, nil, nil, 1, nil, nil, true },
        { "Light of the Forgotten Renegade", 0, { true, false }, nil, nil, nil, nil, "top" },
    } },
    { "Kunkka", "npc_dota_hero_kunkka", { { "Blade of the Pack-Ice Privateer", 1 } } },
    { "Troll Warlord", "npc_dota_hero_troll_warlord", { { "Axes of the Icewrack Marauder", 2 } } },
    { "Lycan", "npc_dota_hero_lycan", { { "Claws of the Grey Ghost", 0, nil, nil, nil, nil, nil, nil, "attach_attack1", "modifier_lycan_shapeshift" } } },
    { "Techies", "npc_dota_hero_techies", { { "Powdersled Rookery Cannon", 2 } } },
    { "Enchantress", "npc_dota_hero_enchantress", { { "Spear of the First Night", 1 } } },
    { "Death Prophet", "npc_dota_hero_death_prophet", {
        { "Hood of the Long Night", 1 },
        { "Draconic Requiem - Armor", 2 },
    } },
    { "Jakiro", "npc_dota_hero_jakiro", { { "Tines of the Pyrexae - Back", 1, nil, true } } },
    { "Disruptor", "npc_dota_hero_disruptor", { { "Designs of Ancient Druud - Weapon", 5 } } },
    { "Queen of Pain", "npc_dota_hero_queenofpain", {
        { "Raven of Ristul - Weapon", 0, { true, false }, nil, nil, nil, nil, 1, nil, nil, true },
        { "The Rose of Ristul - Weapon", 0, { true, false }, nil, nil, nil, nil, "lonely" },
    } },
    { "Shadow Shaman", "npc_dota_hero_shadow_shaman", { { "Eyes in the Endless Dark - Weapon", 6 } } },
    { "Meepo", "npc_dota_hero_meepo", { { "Mocking Bird - Weapon", 1 } } },
    { "Skywrath Mage", "npc_dota_hero_skywrath_mage", { { "Highborn Heretic - Weapon", 3 } } },
    { "Pugna", "npc_dota_hero_pugna", { { "Keeper of the Nether-Lens - Weapon", 1 } } },
    { "Tinker", "npc_dota_hero_tinker", { { "Twitcher - Weapon", 0, { true, false }, nil, nil, nil, nil, "side" } } },
    { "Hoodwink", "npc_dota_hero_hoodwink", { { "Birdfeed Bandit - Weapon", 1 } } },
    { "Zeus", "npc_dota_hero_zuus", { { "Thunderbird - Back", 2 } } },
    { "Shadow Fiend", "npc_dota_hero_nevermore", { { "Raven Harvest - Arms", 0, { nil, false }, nil, nil, nil, nil, "side" } } },
    { "Bane", "npc_dota_hero_bane", { { "Tome of Infinite Terror - Arms", 4 } } },
    { "Mars", "npc_dota_hero_mars", { { "Mars Gallus - Weapon", 2 } } },
    { "Treant Protector", "npc_dota_hero_treant", { { "Spina Infernalis - Arms", 2 } } },
    { "Timbersaw", "npc_dota_hero_shredder", {
        { "Saw of the Trailblazer", 0, { false, true } },
        { "Claw of the Trailblazer", 0, { false, false } },
    } },
    { "Visage", "npc_dota_hero_visage", { { "Grimfeather the Grotesque - Familiar", 0, nil, nil, nil, nil, "npc_dota_visage_familiar" } } },
    { "Phantom Lancer", "npc_dota_hero_phantom_lancer", { { "Flock of Avilliva - Weapon", 1 } } },
    { "Naga Siren", "npc_dota_hero_naga_siren", { { "Song of the Sea Lotus - Weapon", 0, { false, false }, nil, nil, "alone" } } },
    { "Oracle", "npc_dota_hero_oracle", { { "Prophecies of Pavo - Weapon", 3 } } },
    { "Brewmaster", "npc_dota_hero_brewmaster", { { "Fortified Brew - Weapon", 1 } } },
    { "Morphling", "npc_dota_hero_morphling", { { "Reflection of the Surging Stream - Arms", 3 } } },
    { "Marci", "npc_dota_hero_marci", { { "Bloomjewel Brawler - Back", 3 } } },
    { "Huskar", "npc_dota_hero_huskar", { { "Flashpoint Proselyte - Off-Hand", 0, { false, true }, nil, nil, nil, nil, 2 } } },
}

Menu.Create("Changer", "Main", "Unusual Changer"):Icon("\u{f3a5}")
local localization = qLocalization.new({
    en = {
        unu_groups_unusual = "Unusual",
        unu_groups_test = "Test",
        unu_groups_preview = "Preview",
        unu_menu_enable = "Enable",
        unu_menu_hero = "Hero",
        unu_menu_effect = "Effect",
        unu_menu_settings = "Settings",
        unu_menu_test = "Test on any hero",
        unu_menu_preview = "Test in menu",
        unu_menu_slot = "Item number (0 = all)",
        unu_menu_all_heroes = "On every hero on the map",
        unu_menu_wide = "Include hidden items",
    },
    ru = {
        unu_groups_unusual = "Unusual",
        unu_groups_test = "Тест",
        unu_groups_preview = "Превью",
        unu_menu_enable = "Включить",
        unu_menu_hero = "Герой",
        unu_menu_effect = "Эффект",
        unu_menu_settings = "Настройки",
        unu_menu_test = "Тест на любом герое",
        unu_menu_preview = "Тест в меню",
        unu_menu_slot = "Номер вещи (0 = все)",
        unu_menu_all_heroes = "На всех героях на карте",
        unu_menu_wide = "Включая спрятанные вещи",
    },
})

local Menu = localization.WrapLibrary(Menu)

local group = Menu.Create("Changer", "Main", "Unusual Changer", "Main", "unu_groups_unusual")
local enable = group:Switch("unu_menu_enable", false, "\u{f011}")

local options, by_unit, unit_by_label = {}, {}, {}
for index, hero in ipairs(HEROES) do
    by_unit[hero[2]] = hero
    unit_by_label[hero[1]] = hero[2]
    options[index] = { hero[1], "panorama/images/heroes/icons/" .. hero[2] .. "_png.vtex_c", hero[1] == "Invoker" }
end
local hero_widget = group:MultiSelect("unu_menu_hero", options, true)
hero_widget:OneItemSelection(true)

local items = {}
for _, hero in ipairs(HEROES) do
    for _, item in ipairs(hero[3]) do
        local switch = group:Switch(item[1], false, "\u{f553}")
        items[#items + 1] = {
            unit = hero[2],
            position = item[2],
            marks = item[3],
            wide = item[4],
            gate = item[5],
            pick = item[6],
            npc = item[7],
            rank = item[8],
            attach = item[9],
            block = item[10],
            stuck = item[11],
            switch = switch,
            effect = switch:Gear("unu_menu_effect"):Combo("unu_menu_effect", EFFECTS, 0),
        }
    end
end

local test_group = Menu.Create("Changer", "Main", "Unusual Changer", "Main", "unu_groups_test")
local test_enable = test_group:Switch("unu_menu_test", false, "\u{f0ad}")
local test_gear = test_enable:Gear("unu_menu_settings")
local test_slot = test_gear:Slider("unu_menu_slot", 0, 12, 1)
local test_effect = test_gear:Combo("unu_menu_effect", EFFECTS, 0)
local test_all = test_gear:Switch("unu_menu_all_heroes", false, "\u{f0c0}")
local test_wide = test_gear:Switch("unu_menu_wide", false, "\u{f070}")

local preview_group = Menu.Create("Changer", "Main", "Unusual Changer", "Main", "unu_groups_preview")
local preview_enable = preview_group:Switch("unu_menu_preview", false, "\u{f03e}")
local preview_gear = preview_enable:Gear("unu_menu_settings")
local preview_slot = preview_gear:Slider("unu_menu_slot", 0, 12, 0)
local preview_effect = preview_gear:Combo("unu_menu_effect", EFFECTS, 0)
local preview_wide = preview_gear:Switch("unu_menu_wide", false, "\u{f070}")

for _, name in ipairs({ "Вещь (0 = все)", "Вещь", "Эффект", "Поиск вещи (0 = выкл)" }) do
    local stale = Menu.Find("Changer", "Main", "Unusual", "Main", "Unusual", "Unusual эффект", "Настройки", name)
    if stale then stale:Visible(false) end
end
for _, name in ipairs({ "Northern Blight", "Lina - голова" }) do
    local renamed = Menu.Find("Changer", "Main", "Unusual", "Main", "Unusual", name)
    if renamed then renamed:Visible(false) end
end
local old_slot = Menu.Find("Changer", "Main", "Unusual", "Main", "Тест", "Тест на любом герое", "Настройки", "Номер вещи")
if old_slot then old_slot:Visible(false) end
local old_shot = Menu.Find("Changer", "Main", "Unusual Changer", "Main", "Тычка", "Летящая тычка")
if old_shot then old_shot:Visible(false) end

local active, next_scan, last_unit = {}, 0, ""
local menu_fx, menu_scan, menu_stamp = {}, 0, ""
local last_enabled

local function sync_enabled()
    local on = enable:Get()
    if on == last_enabled then return end
    last_enabled = on
    hero_widget:Disabled(not on)
    for _, item in ipairs(items) do item.switch:Disabled(not on) end
end

local function wearables_by_owner()
    local found = {}
    for _, e in pairs(Entities.GetAll()) do
        if Entity.GetClassName(e) == "C_DOTAWearableItem" then
            local owner = Entity.GetOwner(e)
            if owner then
                local key = Entity.GetIndex(owner)
                found[key] = found[key] or {}
                found[key][#found[key] + 1] = e
            end
        end
    end
    return found
end

local function owned_npcs(hero, unit_name)
    local hero_index, found = Entity.GetIndex(hero), {}
    for _, e in pairs(Entities.GetAll()) do
        if Entity.IsNPC(e) and Entity.GetUnitName(e) == unit_name then
            local owner = Entity.GetOwner(e)
            if owner and Entity.GetIndex(owner) == hero_index then found[#found + 1] = e end
        end
    end
    return found
end

local function worn(list)
    if not list then return {} end
    local crowd, place = {}, {}
    for _, e in ipairs(list) do
        local spot = Entity.GetAbsOrigin(e)
        place[e] = string.format("%.1f,%.1f,%.1f", spot.x, spot.y, spot.z)
        crowd[place[e]] = (crowd[place[e]] or 0) + 1
    end
    local kept = {}
    for _, e in ipairs(list) do
        if crowd[place[e]] <= 4
            or Entity.GetField(e, "m_bHiddenByCombiner", false)
            or Entity.GetField(e, "m_bParticleSystemsCreated", false)
        then
            kept[#kept + 1] = e
        end
    end
    return kept
end

local stats, cache = {}, {}

local function ordered(unit, list, wide)
    if #list == 0 then return {} end
    local origin = Entity.GetAbsOrigin(unit)
    local _, yaw = Entity.GetRotationPYR(unit)
    local sideways, forward = math.sin(math.rad(yaw)), math.cos(math.rad(yaw))
    local indices, settled = {}, 100000
    for _, e in ipairs(list) do
        local index = Entity.GetIndex(e)
        local spot = Entity.GetAbsOrigin(e)
        local box = stats[index]
        if not box then
            box = { samples = 0, height = 0, range = 0, motion = 0, side = 0 }
            stats[index] = box
        end
        local dx, dy, dz = spot.x - origin.x, spot.y - origin.y, spot.z - origin.z
        box.samples = box.samples + 1
        local w = 1 / math.min(box.samples, 20)
        if box.dx then
            local mx, my, mz = dx - box.dx, dy - box.dy, dz - box.dz
            local step = math.sqrt(mx * mx + my * my + mz * mz)
            box.motion = box.motion + (step - box.motion) * w
        end
        if box.wx and (box.wx ~= spot.x or box.wy ~= spot.y or box.wz ~= spot.z) then box.moved = true end
        box.wx, box.wy, box.wz = spot.x, spot.y, spot.z
        box.dx, box.dy, box.dz = dx, dy, dz
        box.height = box.height + (dz - box.height) * w
        box.range = box.range + (spot:Distance(origin) - box.range) * w
        box.side = box.side + (dx * sideways - dy * forward - box.side) * w
        if box.samples < settled then settled = box.samples end
        indices[#indices + 1] = index
    end
    table.sort(indices)
    local stamp = table.concat(indices, ",") .. tostring(wide)
    local done = settled >= 6
    local previous = cache[Entity.GetIndex(unit)]
    if previous and previous.stamp == stamp and (previous.done or not done) and previous.age < 10 then
        previous.age = previous.age + 1
        return previous.list
    end

    local nearest = 100000
    for _, index in ipairs(indices) do
        local mean = stats[index].range
        if mean < nearest then nearest = mean end
    end
    local keep = {}
    for _, e in ipairs(list) do
        local box = stats[Entity.GetIndex(e)]
        if wide or box.range <= nearest + 250 then keep[#keep + 1] = e end
    end
    table.sort(keep, function(a, b)
        local left, right = stats[Entity.GetIndex(a)], stats[Entity.GetIndex(b)]
        if left.height ~= right.height then return left.height > right.height end
        if left.side ~= right.side then return left.side > right.side end
        return Entity.GetIndex(a) < Entity.GetIndex(b)
    end)

    local groups = {}
    for _, e in ipairs(keep) do
        local box = stats[Entity.GetIndex(e)]
        local height, range = box.height, box.range
        local side = box.side
        local last = groups[#groups]
        if last and math.abs(last.height - height) <= 1.5 and math.abs(last.range - range) <= 1.5
            and math.abs(last.side - side) <= 1.5
        then
            last[#last + 1] = e
        else
            groups[#groups + 1] = { e, height = height, range = range, side = side }
        end
    end
    cache[Entity.GetIndex(unit)] = { stamp = stamp, list = groups, done = done, age = 0 }
    return groups
end

local function chosen_targets(item, raw, list)
    if item.pick == "side" then
        local best, high = nil, -math.huge
        for _, e in ipairs(raw) do
            local s = stats[Entity.GetIndex(e)].side
            if s > high then best, high = e, s end
        end
        return best and { best } or {}
    end
    if item.pick == "alone" then
        local single
        for _, e in ipairs(raw) do
            if Entity.GetField(e, "m_bHiddenByCombiner", false) == item.marks[1]
                and Entity.GetField(e, "m_bParticleSystemsCreated", false) == item.marks[2]
            then
                local spot, shared = Entity.GetAbsOrigin(e), false
                for _, other in ipairs(raw) do
                    if other ~= e and Entity.GetAbsOrigin(other):Distance(spot) < 1 then shared = true end
                end
                if not shared then single = e end
            end
        end
        return single and { single } or {}
    end
    if item.pick == "pair" then
        local groups = {}
        for _, e in ipairs(raw) do
            local spot = Entity.GetAbsOrigin(e)
            local key = string.format("%.0f,%.0f,%.0f", spot.x, spot.y, spot.z)
            groups[key] = groups[key] or {}
            groups[key][#groups[key] + 1] = e
        end
        for _, g in pairs(groups) do
            if #g >= 2 then
                table.sort(g, function(a, b) return Entity.GetIndex(a) < Entity.GetIndex(b) end)
                return { g[1] }
            end
        end
        return {}
    end
    if not item.marks then return list[item.position] or {} end
    local hits = {}
    for _, e in ipairs(raw) do
        if (item.marks[1] == nil or Entity.GetField(e, "m_bHiddenByCombiner", false) == item.marks[1])
            and (item.marks[2] == nil or Entity.GetField(e, "m_bParticleSystemsCreated", false) == item.marks[2])
        then
            local spot = Entity.GetAbsOrigin(e)
            if spot.x ~= -6700.0 or spot.y ~= -6700.0 or spot.z ~= 384.0 then
                hits[#hits + 1] = e
            end
        end
    end
    if #hits <= 1 then
        item.confirmed = hits[1]
        return hits
    end
    for _, e in ipairs(hits) do
        if e == item.confirmed then return { e } end
    end
    if item.stuck then
        local still, seen = {}, false
        for _, e in ipairs(raw) do
            if stats[Entity.GetIndex(e)].moved then seen = true end
        end
        for _, e in ipairs(hits) do
            if (stats[Entity.GetIndex(e)].moved == true) == (item.stuck == "moves") then still[#still + 1] = e end
        end
        if not seen or #still == 0 then return {} end
        table.sort(still, function(a, b)
            return stats[Entity.GetIndex(a)].height < stats[Entity.GetIndex(b)].height
        end)
        item.confirmed = still[math.min(item.rank or 1, #still)]
        return { item.confirmed }
    end
    if item.rank == "lonely" then
        local best, far = hits[1], -1
        for _, e in ipairs(hits) do
            local spot, near = Entity.GetAbsOrigin(e), math.huge
            for _, other in ipairs(hits) do
                if other ~= e then near = math.min(near, Entity.GetAbsOrigin(other):Distance(spot)) end
            end
            if near > far then best, far = e, near end
        end
        item.confirmed = best
        return { best }
    end
    if item.rank == "side" or item.rank == "left" or item.rank == "right" then
        local best, high = hits[1], -math.huge
        for _, e in ipairs(hits) do
            local offset = stats[Entity.GetIndex(e)].side
            if item.rank == "side" then offset = math.abs(offset) elseif item.rank == "left" then offset = -offset end
            if offset > high then best, high = e, offset end
        end
        item.confirmed = best
        return { best }
    end
    if item.rank ~= "top" then
        local grounded = {}
        for _, e in ipairs(hits) do
            if math.abs(stats[Entity.GetIndex(e)].height) > 5 then grounded[#grounded + 1] = e end
        end
        if #grounded > 0 then hits = grounded end
    end
    table.sort(hits, function(a, b)
        return stats[Entity.GetIndex(a)].height < stats[Entity.GetIndex(b)].height
    end)
    item.confirmed = hits[item.rank == "top" and #hits or math.min(item.rank or 1, #hits)]
    return { item.confirmed }
end

local function clear()
    for key, record in pairs(active) do
        Particle.Destroy(record.id)
        active[key] = nil
    end
end

function script.OnUpdate()
    local now = GlobalVars.GetCurTime()
    if now < next_scan then return end
    next_scan = now + 0.5
    sync_enabled()

    local hero = Heroes.GetLocal()
    local unit = hero and Entity.GetUnitName(hero) or ""
    local entry = by_unit[unit]

    if unit ~= last_unit then
        last_unit = unit
        for _, item in ipairs(items) do item.switch:Visible(item.unit == unit) end
    end
    local chosen = hero_widget:ListEnabled()
    if (chosen and chosen[1] or nil) ~= (entry and entry[1] or nil) then
        hero_widget:Set(entry and { entry[1] } or {})
    end

    local testing = test_enable:Get()
    if not hero or (not testing and (not enable:Get() or not entry)) then
        clear()
        return
    end

    local found = wearables_by_owner()
    local wanted = {}
    if testing then
        local units = test_all:Get() and Heroes.GetAll() or { hero }
        for _, target_unit in ipairs(units) do
            if Entity.IsAlive(target_unit) and not Entity.IsDormant(target_unit) then
                local list = ordered(target_unit, worn(found[Entity.GetIndex(target_unit)]), test_wide:Get())
                local pick = test_slot:Get()
                for index, gathering in ipairs(list) do
                    if pick == 0 or pick == index then
                        for _, target in ipairs(gathering) do wanted[#wanted + 1] = { target, test_effect:Get() + 1 } end
                    end
                end
            end
        end
    else
        local raw = worn(found[Entity.GetIndex(hero)])
        local list = ordered(hero, raw)
        for _, item in ipairs(items) do
            if item.unit == unit and item.switch:Get() and (not item.gate or NPC.HasModifier(hero, item.gate))
                and not (item.block and NPC.HasModifier(hero, item.block))
            then
                if item.attach then
                    wanted[#wanted + 1] = { hero, item.effect:Get() + 1, item.attach }
                elseif item.npc then
                    for _, target in ipairs(owned_npcs(hero, item.npc)) do
                        wanted[#wanted + 1] = { target, item.effect:Get() + 1 }
                    end
                else
                    for _, target in ipairs(chosen_targets(item, raw, item.wide and ordered(hero, raw, true) or list)) do
                        wanted[#wanted + 1] = { target, item.effect:Get() + 1 }
                    end
                end
            end
        end
    end

    local desired = {}
    for _, pair in ipairs(wanted) do desired[Entity.GetIndex(pair[1])] = pair end

    for key, record in pairs(active) do
        if not desired[key] or desired[key][2] ~= record.effect then
            Particle.Destroy(record.id)
            active[key] = nil
        end
    end

    for key, pair in pairs(desired) do
        if not active[key] then
            local id = Particle.Create(PATHS[pair[2]], pair[3] and Enum.ParticleAttachment.PATTACH_POINT_FOLLOW or Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW, pair[1])
            if pair[3] then
                Particle.SetControlPointEnt(id, 0, pair[1], Enum.ParticleAttachment.PATTACH_POINT_FOLLOW, pair[3], Vector(0, 0, 0), true)
            end
            active[key] = { id = id, effect = pair[2] }
        end
    end
end

function script.OnUpdateEx()
    if #Heroes.GetAll() > 0 then
        for _, id in ipairs(menu_fx) do Particle.Destroy(id) end
        menu_fx, menu_stamp = {}, ""
        return
    end
    local chosen = hero_widget:ListEnabled()
    local picked_unit = unit_by_label[chosen and chosen[1]] or ""
    if picked_unit ~= last_unit then
        last_unit = picked_unit
        for _, item in ipairs(items) do item.switch:Visible(item.unit == picked_unit) end
    end

    local now = GlobalVars.GetCurTime()
    if now < menu_scan then return end
    menu_scan = now + 0.5
    sync_enabled()

    local units = {}
    for _, e in pairs(Entities.GetAll()) do
        if Entity.GetClassName(e) == "C_PortraitWorldUnit" then units[#units + 1] = e end
    end
    local wanted = {}
    if preview_enable:Get() then
        local pick, effect, found = preview_slot:Get(), preview_effect:Get() + 1, wearables_by_owner()
        for _, unit in ipairs(units) do
            local list = ordered(unit, worn(found[Entity.GetIndex(unit)]), preview_wide:Get())
            for index, gathering in ipairs(list) do
                if pick == 0 or pick == index then
                    for _, target in ipairs(gathering) do wanted[#wanted + 1] = { target, effect } end
                end
            end
        end
    end

    local stamp = ""
    for _, pair in ipairs(wanted) do stamp = stamp .. Entity.GetIndex(pair[1]) .. ":" .. pair[2] .. "|" end
    if stamp == menu_stamp then return end
    menu_stamp = stamp

    for _, id in ipairs(menu_fx) do Particle.Destroy(id) end
    menu_fx = {}
    for _, pair in ipairs(wanted) do
        menu_fx[#menu_fx + 1] = Particle.Create(PATHS[pair[2]], Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW, pair[1])
    end
end

function script.OnScriptsLoaded()
    if not ai_bridge then return end
    ai_bridge.tool("unusual_debug", "State of the unusual script.", {}, function()
        local hero = Heroes.GetLocal()
        if not hero then return "no hero, last_unit=" .. tostring(last_unit) end
        local found = wearables_by_owner()
        local raw = worn(found[Entity.GetIndex(hero)])
        local list = ordered(hero, raw)
        local out = { "raw=" .. #raw .. " list=" .. #list .. " test=" .. tostring(test_enable:Get()) .. " pick=" .. test_slot:Get() .. " on=" .. tostring(enable:Get()) }
        for index, gathering in ipairs(list) do
            local names = {}
            for _, e in ipairs(gathering) do names[#names + 1] = Entity.GetIndex(e) end
            out[#out + 1] = index .. ") idx=" .. table.concat(names, "+")
                .. " h=" .. string.format("%.1f", gathering.height)
                .. " r=" .. string.format("%.1f", gathering.range)
                .. " s=" .. string.format("%.1f", gathering.side)
                .. " m=" .. string.format("%.1f", stats[Entity.GetIndex(gathering[1])].motion)
        end
        return table.concat(out, " | ")
    end)
    ai_bridge.tool("unusual_raw", "Per-entity stats for the local hero's raw wearables.", {}, function()
        local hero = Heroes.GetLocal()
        if not hero then return "no hero" end
        local found = wearables_by_owner()
        local raw = worn(found[Entity.GetIndex(hero)])
        ordered(hero, raw)
        local out = {}
        for _, e in ipairs(raw) do
            local index = Entity.GetIndex(e)
            local box = stats[index]
            out[#out + 1] = index .. ") h=" .. string.format("%.1f", box.height)
                .. " r=" .. string.format("%.1f", box.range)
                .. " s=" .. string.format("%.1f", box.side)
                .. " m=" .. string.format("%.2f", box.motion)
                .. " n=" .. box.samples
        end
        return table.concat(out, " | ")
    end)
end

return script
