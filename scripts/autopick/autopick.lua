---@diagnostic disable: undefined-global

local autopick = {}
local chronos = require('chronos')

local VERSION = "1.0.0"

local HEROES = {
    str = {
        "abyssal_underlord", "alchemist", "axe", "bristleback", "centaur",
        "chaos_knight", "dawnbreaker", "doom_bringer", "dragon_knight",
        "earth_spirit", "earthshaker", "elder_titan", "huskar", "kunkka",
        "largo", "legion_commander", "life_stealer", "lycan", "mars",
        "night_stalker", "ogre_magi", "omniknight", "phoenix", "primal_beast",
        "pudge", "rattletrap", "shredder", "skeleton_king", "slardar",
        "spirit_breaker", "sven", "tidehunter", "tiny", "treant", "tusk",
        "undying",
    },
    agi = {
        "antimage", "bloodseeker", "bounty_hunter", "broodmother", "clinkz",
        "drow_ranger", "ember_spirit", "faceless_void", "gyrocopter",
        "hoodwink", "juggernaut", "kez", "lone_druid", "luna", "medusa",
        "meepo", "mirana", "monkey_king", "morphling", "naga_siren",
        "nevermore", "phantom_assassin", "phantom_lancer", "razor", "riki",
        "slark", "sniper", "spectre", "templar_assassin", "terrorblade",
        "troll_warlord", "ursa", "vengefulspirit", "viper", "weaver",
    },
    int = {
        "ancient_apparition", "chen", "crystal_maiden", "dark_seer",
        "dark_willow", "disruptor", "enchantress", "grimstroke", "invoker",
        "jakiro", "keeper_of_the_light", "leshrac", "lich", "lina", "lion",
        "muerta", "necrolyte", "obsidian_destroyer", "oracle", "puck", "pugna",
        "queenofpain", "ringmaster", "rubick", "shadow_demon", "shadow_shaman",
        "silencer", "skywrath_mage", "storm_spirit", "tinker", "warlock",
        "winter_wyvern", "witch_doctor", "zuus",
    },
    all = {
        "abaddon", "arc_warden", "bane", "batrider", "beastmaster",
        "brewmaster", "dazzle", "death_prophet", "enigma", "furion",
        "magnataur", "marci", "nyx_assassin", "pangolier", "sand_king",
        "snapfire", "techies", "venomancer", "visage", "void_spirit",
        "windrunner", "wisp",
    },
}

local ATTR_ORDER = { "str", "agi", "int", "all" }

local ROLES = {
    { key = "safe", title = "Лёгкая линия",         icon = "LSI__SafeLane",
      labels = { "Safe Lane" } },
    { key = "mid",  title = "Средняя линия",        icon = "LSI__MidLane",
      labels = { "Mid Lane" } },
    { key = "off",  title = "Сложная линия",        icon = "LSI__OffLane",
      labels = { "Off Lane" } },
    { key = "sup",  title = "Поддержка (4)",        icon = "LSI__Support",
      labels = { "Support", "Soft Support" } },
    { key = "hard", title = "Полная поддержка (5)", icon = "LSI__HardSupport",
      labels = { "Hard Support" } },
}

local tab = Menu.Create("Scripts", "Main", "Авто-пик")
tab:Icon("\u{f0e7}")

local main_tab = tab:Create("Основное")
local main_group = main_tab:Create("Авто-пик")

local ui = {}
ui.enabled = main_group:Switch("Включить", false, "\u{f00c}")

local ATTR_TITLES = {
    str = "Сила", agi = "Ловкость", int = "Интеллект", all = "Универсал",
}

local ATTR_BY_TITLE = {}
local HERO_ATTR = {}

for a = 1, #ATTR_ORDER do
    local key = ATTR_ORDER[a]
    ATTR_BY_TITLE[ATTR_TITLES[key]] = key

    local list = HEROES[key]
    for i = 1, #list do
        HERO_ATTR[list[i]] = key
    end
end

local hero_titles = {}
local function hero_title(name)
    local cached = hero_titles[name]
    if cached ~= nil then return cached end

    local title = GameLocalizer.FindNPC("npc_dota_hero_" .. name)
    if title == nil or title == "" then title = name end
    hero_titles[name] = title
    return title
end

local function hero_image(name)
    return "~/heroes_circle/" .. name .. ".png"
end

local function build_items(query, attr)
    local items = {}
    local needle = nil
    if query ~= nil and query ~= "" then needle = string.lower(query) end

    for a = 1, #ATTR_ORDER do
        local key = ATTR_ORDER[a]
        if needle ~= nil or attr == nil or attr == key then
            local list = HEROES[key]
            for i = 1, #list do
                local name = list[i]
                local fits = needle == nil
                    or string.find(string.lower(name), needle, 1, true) ~= nil
                    or string.find(string.lower(hero_title(name)), needle, 1, true) ~= nil
                if fits then
                    items[#items + 1] = { name, hero_image(name), false }
                end
            end
        end
    end
    return items
end

local LANE_MASKS = "panorama/images/rank_tier_icons/handicap/"

local SETS = {
    { key = "order_safe",    title = "Лёгкая линия",
      icon = LANE_MASKS .. "safelaneicon_psd.vtex_c",    color = Color(0x73, 0x7D, 0xC4, 255) },
    { key = "order_mid",     title = "Средняя линия",
      icon = LANE_MASKS .. "midlaneicon_psd.vtex_c",     color = Color(0x3F, 0x92, 0x8A, 255) },
    { key = "order_off",     title = "Сложная линия",
      icon = LANE_MASKS .. "offlaneicon_psd.vtex_c",     color = Color(0xD9, 0x7B, 0x0C, 255) },
    { key = "order_sup",     title = "Поддержка (4)",
      icon = LANE_MASKS .. "softsupporticon_psd.vtex_c", color = Color(0xC4, 0x44, 0x4F, 255) },
    { key = "order_hard",    title = "Полная поддержка (5)",
      icon = LANE_MASKS .. "hardsupporticon_psd.vtex_c", color = Color(0x1E, 0x9E, 0x76, 255) },
    { key = "order_reserve", title = "Резерв на любую роль",
      icon = "panorama/images/control_icons/random_dice_psd.vtex_c",
      color = Color(0xC0, 0x4A, 0x9B, 255) },
}

local SET_BY_TITLE = {}
for i = 1, #SETS do
    SET_BY_TITLE[SETS[i].title] = SETS[i].key
end

local ATTR_DIR = "panorama/images/primary_attribute_icons/"
local ATTR_ICONS = {
    str = ATTR_DIR .. "primary_attribute_icon_strength_psd.vtex_c",
    agi = ATTR_DIR .. "primary_attribute_icon_agility_psd.vtex_c",
    int = ATTR_DIR .. "primary_attribute_icon_intelligence_psd.vtex_c",
    all = ATTR_DIR .. "primary_attribute_icon_all_psd.vtex_c",
}

local orders = {}
local active = {}

for i = 1, #SETS do
    local list, on = {}, {}
    for token in string.gmatch(Config.ReadString("autopick", SETS[i].key, ""), "[^,]+") do
        local name, enabled = token, true
        if string.sub(token, 1, 1) == "-" then
            name, enabled = string.sub(token, 2), false
        end
        if HERO_ATTR[name] ~= nil then
            list[#list + 1] = name
            if enabled then on[#on + 1] = name end
        end
    end
    orders[SETS[i].key] = list
    active[SETS[i].key] = on
end

local set_items = {}
for i = 1, #SETS do
    set_items[i] = { SETS[i].title, SETS[i].icon, i == 1 }
end
local set_widget = main_group:MultiSelect("Линия", set_items, true)
set_widget:OneItemSelection(true)
set_widget:DragAllowed(false)

local lane_colors = {}
for i = 1, #SETS do
    lane_colors[SETS[i].title] = SETS[i].color
end
set_widget:UpdateImageColors(lane_colors)

local queue_widget = main_group:MultiSelect("Очередь", {}, true)
queue_widget:DragAllowed(true)

local attr_items = {}
for a = 1, #ATTR_ORDER do
    local key = ATTR_ORDER[a]
    attr_items[a] = { ATTR_TITLES[key], ATTR_ICONS[key], a == 1 }
end
local attr_widget = main_group:MultiSelect("Атрибут", attr_items, true)
attr_widget:OneItemSelection(true)
attr_widget:DragAllowed(false)

local search = main_group:Input("Поиск", "", "\u{f002}")
local grid = main_group:MultiSelect("Герои", build_items(nil, ATTR_ORDER[1]), true)
grid:DragAllowed(false)

local shown_set = nil
local shown_query = nil
local shown_attr = nil
local shown_grid = nil
local shown_queue_list = nil
local shown_queue_on = nil

local function current_key()
    local enabled = set_widget:ListEnabled()
    local key = enabled[1] ~= nil and SET_BY_TITLE[enabled[1]] or nil
    return key or SETS[1].key
end

local function current_attr()
    local enabled = attr_widget:ListEnabled()
    local key = enabled[1] ~= nil and ATTR_BY_TITLE[enabled[1]] or nil
    return key or ATTR_ORDER[1]
end

local function save(key)
    local order = orders[key] or {}
    local on = {}
    local enabled = active[key] or {}
    for i = 1, #enabled do on[enabled[i]] = true end

    local parts = {}
    for i = 1, #order do
        parts[i] = on[order[i]] == true and order[i] or ("-" .. order[i])
    end

    local line = table.concat(parts, ",")
    Config.WriteString("autopick", key, line)
    print("[autopick] набор " .. key .. ": " .. line)
end

local function apply_grid(key)
    local enabled = grid:ListEnabled()
    local on = {}
    for i = 1, #enabled do on[enabled[i]] = true end

    local visible = {}
    local shown = grid:List()
    for i = 1, #shown do visible[shown[i]] = true end

    local was_on = {}
    local prev = active[key] or {}
    for i = 1, #prev do was_on[prev[i]] = true end

    local order = orders[key] or {}
    local kept, have, kept_on = {}, {}, {}
    for i = 1, #order do
        local name = order[i]
        if visible[name] ~= true or on[name] == true then
            kept[#kept + 1] = name
            have[name] = true
            if was_on[name] == true then kept_on[#kept_on + 1] = name end
        end
    end
    for i = 1, #enabled do
        local name = enabled[i]
        if have[name] ~= true then
            kept[#kept + 1] = name
            have[name] = true
            kept_on[#kept_on + 1] = name
        end
    end

    orders[key] = kept
    active[key] = kept_on
    save(key)
end

local function apply_queue(key)
    orders[key] = queue_widget:List()
    active[key] = queue_widget:ListEnabled()
    save(key)
end

local function refresh_queue(key)
    local order = orders[key] or {}

    local items = {}
    for i = 1, #order do
        items[i] = { order[i], hero_image(order[i]), true }
    end
    queue_widget:Visible(#order > 0)
    queue_widget:Update(items, true, false)
    queue_widget:Set(active[key] or {})

    shown_queue_list = table.concat(queue_widget:List(), ",")
    shown_queue_on = table.concat(queue_widget:ListEnabled(), ",")
end

local function refresh_grid(key, query, attr)
    local order = orders[key] or {}
    local chosen = {}
    for i = 1, #order do chosen[order[i]] = true end

    local items = build_items(query, attr)
    local marked = {}
    for i = 1, #items do
        local name = items[i][1]
        if chosen[name] == true then
            items[i][3] = true
            marked[#marked + 1] = name
        end
    end
    grid:Update(items, true, false)
    grid:Set(marked)

    shown_grid = table.concat(grid:ListEnabled(), ",")
end

local function menu_tick()
    local key = current_key()

    if shown_grid ~= nil and table.concat(grid:ListEnabled(), ",") ~= shown_grid then
        apply_grid(key)
        refresh_queue(key)
        shown_grid = table.concat(grid:ListEnabled(), ",")
        return
    end

    if shown_queue_list ~= nil then
        local list = table.concat(queue_widget:List(), ",")
        local on = table.concat(queue_widget:ListEnabled(), ",")
        if list ~= shown_queue_list or on ~= shown_queue_on then
            apply_queue(key)
            shown_queue_list, shown_queue_on = list, on
            return
        end
    end

    local query = search:Get()
    local attr = current_attr()
    if key == shown_set and query == shown_query and attr == shown_attr then
        return
    end

    shown_set, shown_query, shown_attr = key, query, attr
    refresh_grid(key, query, attr)
    refresh_queue(key)
end

local HERO_SELECTION = 2

local STATE_INTERVAL = 0.05
local WORK_INTERVAL = 0.05
local MENU_INTERVAL = 0.2
local PICK_RETRY = 0.05
local BLIND_TRIES = 3
local LOST_CONFIRM = 1.0
local CONTROL_WAIT = 3.0
local ROLE_WAIT = 0.3
local PANEL_RETRY = 1.0

local state = nil
local next_state_poll = 0
local next_work = 0
local next_panel_search = 0

local my_panel = nil
local my_role = nil
local queue = nil
local queue_index = 0
local attempts = 0
local last_attempt_at = 0
local hero_started_at = 0
local phase_started_at = 0
local role_gave_up = false
local finished = false
local hero_confirmed = false
local lost_since = nil

local started_at = chronos.nanotime()

local function log(msg)
    print(string.format("[autopick %7.2f] %s", chronos.nanotime() - started_at, msg))
end

local function panel_type(panel)
    local ok, value = pcall(panel.GetPanelType, panel)
    if not ok then return nil end
    return value
end

local function label_text(panel)
    if panel_type(panel) ~= "Label" then return nil end

    local ok, text = pcall(panel.GetText, panel)
    if not ok or text == nil or text == "" then return nil end
    return text
end

local function image_src(panel)
    local ptype = panel_type(panel)
    if ptype == nil or string.find(ptype, "Image", 1, true) == nil then return nil end

    local ok, src = pcall(panel.GetImageSrc, panel)
    if not ok or src == nil or src == "" then return nil end
    return src
end

local function has_class(panel, class_name)
    local ok, classes = pcall(panel.GetClassList, panel)
    if not ok or type(classes) ~= "table" then return nil end

    for i = 1, #classes do
        if classes[i] == class_name then return true end
    end
    return false
end

local function each_child(panel, visit)
    local ok, count = pcall(panel.GetChildCount, panel)
    if not ok or count == nil then return nil, nil end

    for i = 0, count - 1 do
        local ok_child, child = pcall(panel.GetChild, panel, i)
        if ok_child and child ~= nil then
            local stop = visit(child, i)
            if stop ~= nil then return stop, count end
        end
    end

    return nil, count
end

local function contains_class(panel, class_name, depth, max_depth)
    if panel == nil or depth > max_depth then return false end

    local here = has_class(panel, class_name)
    if here then return true end
    if here == nil then return nil end

    local found, count = each_child(panel, function(child)
        if contains_class(child, class_name, depth + 1, max_depth) then return true end
        return nil
    end)

    if count == nil then return nil end
    return found == true
end

local function my_slot_class()
    local ok_player, player = pcall(Players.GetLocal)
    if not ok_player or player == nil then return nil end

    local ok_slot, slot = pcall(Player.GetPlayerSlot, player)
    if not ok_slot or slot == nil then return nil end

    return "Slot" .. tostring(slot)
end

local function find_panel_by_class(root, class_name)
    local found = nil

    local function walk(panel, depth)
        if found ~= nil or panel == nil or depth > 6 then return end

        if panel_type(panel) == "DOTAHudHeroPickingPlayer" then
            if contains_class(panel, class_name, 0, 3) then
                found = panel
            end
            return
        end

        each_child(panel, function(child) walk(child, depth + 1) end)
    end

    walk(root, 0)
    return found
end

local function find_my_panel()
    local root = Panorama.GetPanelByName("PreGame", false)
    if root == nil then return nil end

    local panel = find_panel_by_class(root, "IsLocalPlayerPawn")
    if panel ~= nil then
        log("панель игрока найдена по IsLocalPlayerPawn")
        return panel
    end

    local slot_class = my_slot_class()
    if slot_class == nil then return nil end

    panel = find_panel_by_class(root, slot_class)
    if panel ~= nil then
        log("панель игрока найдена по " .. slot_class)
    end
    return panel
end

local function role_by_icon(lane)
    local key = each_child(lane, function(child)
        local ok_visible, visible = pcall(child.IsVisible, child)
        if not ok_visible or not visible then return nil end

        for r = 1, #ROLES do
            if has_class(child, ROLES[r].icon) then return ROLES[r].key end
        end
        return nil
    end)

    return key
end

local function read_role(panel)
    local ok_lane, lane = pcall(panel.FindChildTraverse, panel, "LaneSelection")
    if not ok_lane or lane == nil then return nil end

    local by_icon = role_by_icon(lane)
    if by_icon ~= nil then return by_icon end

    local ok_label, label = pcall(lane.FindChildWithClass, lane, "LaneSelectionLabel")
    if not ok_label or label == nil then return nil end

    local text = label_text(label)
    if text == nil then return nil end

    for i = 1, #ROLES do
        local labels = ROLES[i].labels
        for j = 1, #labels do
            if labels[j] == text then return ROLES[i].key end
        end
    end

    log("роль '" .. tostring(text) .. "' в списке не числится")
    return nil
end

local function hero_taken(panel)
    local none = contains_class(panel, "HeroPickNone", 0, 3)
    if none == nil then return true, true end
    if not none then return true, false end

    local ok, name_panel = pcall(panel.FindChildTraverse, panel, "HeroName")
    if not ok or name_panel == nil then return false, false end

    return label_text(name_panel) ~= nil, false
end

local cards = nil

local function card_hero_name(card)
    local ok, image = pcall(card.FindChildTraverse, card, "HeroImage")
    if not ok or image == nil then return nil end

    local src = image_src(image)
    if src == nil then return nil end
    return string.match(src, "npc_dota_hero_([%w_]+)")
end

local function card_busy_mark(card)
    local mark = ""
    if has_class(card, "Banned") == true then mark = mark .. "B" end
    if has_class(card, "AlreadyPicked") == true then mark = mark .. "P" end
    if has_class(card, "Unavailable") == true then mark = mark .. "U" end
    if mark == "" then return "свободен" end
    return mark
end

local function collect_cards()
    local root = Panorama.GetPanelByName("PreGame", false)
    if root == nil then return nil end

    local found = {}
    local count = 0
    local dups = 0
    local conflicts = 0

    local function visit(panel, depth)
        if depth > 14 then return end

        local ok = pcall(panel.IsValid, panel)
        if not ok then return end

        if has_class(panel, "HeroCard") == true then
            local name = card_hero_name(panel)
            if name ~= nil then
                if found[name] ~= nil then
                    dups = dups + 1
                    local before = card_busy_mark(found[name])
                    local now_mark = card_busy_mark(panel)
                    if before ~= now_mark then
                        conflicts = conflicts + 1
                        log("копии " .. name .. " разошлись: было '" .. before
                            .. "', стало '" .. now_mark
                            .. "' — занятость этого героя читается наугад")
                    end
                end
                found[name] = panel
                count = count + 1
            end
            return
        end

        local ok_count, children = pcall(panel.GetChildCount, panel)
        if not ok_count or children == nil then return end
        for i = 0, children - 1 do
            local ok_child, child = pcall(panel.GetChild, panel, i)
            if ok_child and child ~= nil then visit(child, depth + 1) end
        end
    end

    visit(root, 0)
    if count == 0 then return nil end

    log("сетка героев прочитана: карточек " .. count
        .. ", уникальных " .. (count - dups)
        .. (dups > 0 and (", дублей " .. dups) or "")
        .. (conflicts > 0 and (", РАСХОЖДЕНИЙ " .. conflicts) or ""))
    return found
end

local function hero_blocked(name)
    if cards == nil then return nil end

    local card = cards[name]
    if card == nil then return nil end

    if has_class(card, "Banned") == true then return "забанен" end
    if has_class(card, "AlreadyPicked") == true then return "уже взят" end
    if has_class(card, "Unavailable") == true then return "недоступен" end
    return false
end

local function build_queue(role_key)
    local list = {}
    local seen = {}

    local function add(key)
        local order = orders[key]
        if type(order) ~= "table" then return end

        local on = {}
        local enabled = active[key] or {}
        for i = 1, #enabled do on[enabled[i]] = true end

        for i = 1, #order do
            local name = order[i]
            if on[name] == true and seen[name] ~= true then
                seen[name] = true
                list[#list + 1] = name
            end
        end
    end

    if role_key ~= nil then add("order_" .. role_key) end
    add("order_reserve")

    return list
end

local function reset()
    phase_started_at = chronos.nanotime()
    role_gave_up = false
    my_panel = nil
    my_role = nil
    cards = nil
    queue = nil
    queue_index = 0
    attempts = 0
    last_attempt_at = 0
    hero_started_at = 0
    finished = false
    hero_confirmed = false
    lost_since = nil
end

local function next_free_hero(now)
    while true do
        queue_index = queue_index + 1
        hero_started_at = now
        attempts = 0

        local name = queue[queue_index]
        if name == nil then return nil end

        local blocked = hero_blocked(name)
        if blocked == false or blocked == nil then return name end
        log(name .. ": " .. blocked .. ", пропущен")
    end
end

local function send_pick(now, hero)
    attempts = attempts + 1
    last_attempt_at = now

    log(attempts == 1 and ("выбор " .. hero)
        or ("выбор " .. hero .. " (повтор " .. attempts .. ")"))

    Engine.ExecuteCommand("dota_select_hero npc_dota_hero_" .. hero)
end

local function take_next(now)
    local name = next_free_hero(now)
    if name == nil then
        finished = true
        log("свободных героев из набора не осталось")
        return
    end
    send_pick(now, name)
end

local function work(now)
    if finished then return end

    if my_panel == nil then
        if now < next_panel_search then return end
        next_panel_search = now + PANEL_RETRY
        my_panel = find_my_panel()
        if my_panel == nil then
            return
        end
    end

    local taken, unreadable = hero_taken(my_panel)
    if unreadable then
        finished = true
        log("панель игрока не читается, остановка")
        return
    end

    if taken then
        lost_since = nil
        if not hero_confirmed then
            hero_confirmed = true
            log(string.format("герой взят %s, %.2f с от начала фазы",
                queue_index == 0 and "вручную (скрипт не успел ничего попробовать)"
                or "скриптом", now - phase_started_at))
        end
        return
    end

    if hero_confirmed then
        local mine = nil
        if queue ~= nil then mine = queue[queue_index] end

        local mine_blocked = nil
        if mine ~= nil then mine_blocked = hero_blocked(mine) end

        local stolen = mine_blocked ~= nil and mine_blocked ~= false

        if not stolen then
            if lost_since == nil then
                lost_since = now
                return
            end
            if now - lost_since < LOST_CONFIRM then return end
        end

        log(stolen
            and (mine .. ": " .. mine_blocked .. " — героя отняли, следующий")
            or "герой пропал с панели, сетка молчит — возврат к очереди")

        hero_confirmed = false
        lost_since = nil
        cards = nil
        attempts = 0
        last_attempt_at = 0
    end

    if my_role == nil then
        my_role = read_role(my_panel)
        if my_role ~= nil then
            log(string.format("роль: %s (прочитана через %.2f с)",
                my_role, now - phase_started_at))
        elseif now - phase_started_at < ROLE_WAIT then
            return
        elseif not role_gave_up then
            role_gave_up = true
            log("роль не определена, работа по резерву")
        end
    end

    if queue == nil then
        queue = build_queue(my_role)
        log("в очереди героев: " .. #queue .. " — " .. table.concat(queue, ", "))
        if #queue == 0 then
            finished = true
            log(my_role == nil and "резерв пуст"
                or ("набор для роли " .. my_role .. " пуст"))
            return
        end
    end

    if has_class(my_panel, "PlayerInControl") ~= true
        and now - phase_started_at < CONTROL_WAIT then
        return
    end

    if cards == nil then
        cards = collect_cards()
    end

    if queue_index == 0 then
        take_next(now)
        return
    end

    if now - last_attempt_at < PICK_RETRY then return end

    local current = queue[queue_index]
    local blocked = hero_blocked(current)
    if blocked ~= false and blocked ~= nil then
        log(current .. ": " .. blocked .. ", следующий")
        take_next(now)
        return
    end

    if blocked == nil and attempts >= BLIND_TRIES then
        log(current .. ": карточки в сетке нет, а выбор не состоялся — следующий")
        take_next(now)
        return
    end

    send_pick(now, current)
end

local function tick()
    local now = chronos.nanotime()

    if now >= next_state_poll then
        next_state_poll = now + STATE_INTERVAL

        local current = GameRules.GetGameState()
        if current ~= state then
            state = current
            if state == HERO_SELECTION then
                reset()
                log("фаза выбора героев")
            end
        end
    end

    if state ~= HERO_SELECTION then return end
    if not ui.enabled:Get() then
        return
    end

    if now < next_work then return end
    next_work = now + WORK_INTERVAL
    work(now)
end

function autopick.OnScriptsLoaded()
    log("загружен, версия " .. VERSION .. ", героев в списке: " .. #build_items("", nil))

    local parts = {}
    for i = 1, #SETS do
        local key = SETS[i].key
        local order = orders[key] or {}
        if #order > 0 then
            parts[#parts + 1] = key .. "=" .. #order .. " (вкл " .. #(active[key] or {}) .. ")"
        end
    end
    if #parts > 0 then
        log("наборы из конфига: " .. table.concat(parts, ", "))
    else
        log("наборы из конфига: пусто")
    end
end

local next_menu_tick = 0

function autopick.OnFrame()
    tick()

    local now = chronos.nanotime()
    if now >= next_menu_tick then
        next_menu_tick = now + MENU_INTERVAL
        menu_tick()
    end
end

return autopick
