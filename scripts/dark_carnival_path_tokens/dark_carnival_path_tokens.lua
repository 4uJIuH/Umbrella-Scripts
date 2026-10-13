---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
local script = {}

local JSON = require("assets.JSON")
local protobuf = require("protobuf")

local MSG_GET_USER_DATA = 8944
local MSG_GET_USER_DATA_NAME = "CMsgClientToGCOverworldGetUserData"
local MSG_GET_USER_DATA_RESPONSE = 8945
local MSG_GET_USER_DATA_RESPONSE_NAME = "CMsgClientToGCOverworldGetUserDataResponse"
local MSG_USER_DATA_UPDATED = 8962
local MSG_USER_DATA_UPDATED_NAME = "CMsgGCToClientOverworldUserDataUpdated"

local OVERWORLD_ID = 11

local OVERWORLD_PAGE_PATH = { "DOTADarkCarnivalOverworldPage" }
local OVERWORLD_MAP_TRAIN_LAYER_PATH = {
    "DOTADarkCarnivalOverworldPage", "Map", "OverworldMapRef", "TrainLayer",
}
local MAX_NODE_SEARCH_DEPTH = 20
local NODE_ID_ATTRIBUTES = { "node-id", "nodeid", "node_id" }
local ROOM_ID_ATTRIBUTES = { "room-id", "roomid", "room_id" }

local POPULATE_DELAY = 3.5
local MAX_PLAN_GAMES = 60

local CONTAINER_OPEN_CLASS = "PathTokensOpen"
local TRAY_CLOSE_CLASS = "PathTokensForceClose"
local BACKDROP_CLOSE_CLASS = "PathTokensBackdropClose"
local MAX_TRAY_HEROES = 16

local TOKEN_CSS_NAME = {
    [1] = "TheFool",
    [2] = "TheMagician",
    [3] = "TheHighPriestess",
    [4] = "TheDevil",
    [5] = "TheEmperor",
    [6] = "TheLovers",
    [7] = "Strength",
    [8] = "TheHermit",
    [9] = "TheStar",
    [10] = "WheelOfFortune",
    [11] = "Death",
    [17] = "MinigameExclusive",
}

local TOKEN_NAME_TO_ID = {
    ["The Fool"] = 1,
    ["The Magician"] = 2,
    ["The High Priestess"] = 3,
    ["The Devil"] = 4,
    ["The Emperor"] = 5,
    ["The Lovers"] = 6,
    ["Strength"] = 7,
    ["The Hermit"] = 8,
    ["The Star"] = 9,
    ["Wheel of Fortune"] = 10,
    ["Death"] = 11,
    ["Minigame Exclusive"] = 17,
}

local TOKEN_DISPLAY_NAME = {}
for name, id in pairs(TOKEN_NAME_TO_ID) do
    TOKEN_DISPLAY_NAME[id] = name
end

local HeroToToken = {
    ["Oracle"] = { ["The High Priestess"] = 3 },
    ["Outworld Destroyer"] = { ["The High Priestess"] = 2, ["Death"] = 1 },
    ["Void Spirit"] = { ["The High Priestess"] = 2, ["The Hermit"] = 1 },
    ["Dark Seer"] = { ["The High Priestess"] = 2, ["The Hermit"] = 1 },
    ["Nature's Prophet"] = { ["The Magician"] = 1, ["The High Priestess"] = 2 },
    ["Omniknight"] = { ["The High Priestess"] = 2, ["The Emperor"] = 1 },
    ["Bane"] = { ["The High Priestess"] = 2, ["Death"] = 1 },
    ["Chen"] = { ["The High Priestess"] = 2, ["The Emperor"] = 1 },
    ["Shadow Shaman"] = { ["The High Priestess"] = 2, ["The Hermit"] = 1 },
    ["Anti-Mage"] = { ["The Magician"] = 1, ["The High Priestess"] = 1, ["The Emperor"] = 1 },
    ["Bloodseeker"] = { ["The Magician"] = 1, ["The High Priestess"] = 1, ["Wheel of Fortune"] = 1 },
    ["Naga Siren"] = { ["The High Priestess"] = 1, ["The Lovers"] = 2 },
    ["Huskar"] = { ["The High Priestess"] = 1, ["The Devil"] = 1, ["The Hermit"] = 1 },
    ["Queen of Pain"] = { ["The High Priestess"] = 1, ["The Devil"] = 2 },
    ["Templar Assassin"] = { ["The Magician"] = 1, ["The High Priestess"] = 1, ["The Hermit"] = 1 },
    ["Slardar"] = { ["The High Priestess"] = 1, ["Strength"] = 2 },
    ["Dark Willow"] = { ["The High Priestess"] = 1, ["The Devil"] = 1, ["The Lovers"] = 1 },
    ["Enigma"] = { ["The High Priestess"] = 1, ["The Star"] = 2 },
    ["Largo"] = { ["The High Priestess"] = 1, ["The Star"] = 2 },
    ["Alchemist"] = { ["The Devil"] = 1, ["The Lovers"] = 1, ["The Star"] = 1 },
    ["Arc Warden"] = { ["The Lovers"] = 2, ["The Star"] = 1 },
    ["Chaos Knight"] = { ["Wheel of Fortune"] = 3 },
    ["Clinkz"] = { ["The Magician"] = 1, ["Strength"] = 1, ["Death"] = 1 },
    ["Drow Ranger"] = { ["The Magician"] = 2, ["The Hermit"] = 1 },
    ["Faceless Void"] = { ["The Fool"] = 1, ["Strength"] = 1, ["Wheel of Fortune"] = 1 },
    ["Gyrocopter"] = { ["The Fool"] = 1, ["Strength"] = 1, ["The Star"] = 1 },
    ["Juggernaut"] = { ["The Emperor"] = 1, ["Strength"] = 2 },
    ["Lifestealer"] = { ["The Devil"] = 2, ["Death"] = 1 },
    ["Luna"] = { ["The Emperor"] = 1, ["The Lovers"] = 2 },
    ["Lycan"] = { ["Strength"] = 2, ["Wheel of Fortune"] = 1 },
    ["Medusa"] = { ["The Devil"] = 2, ["Death"] = 1 },
    ["Monkey King"] = { ["The Magician"] = 1, ["The Hermit"] = 2 },
    ["Morphling"] = { ["The Hermit"] = 1, ["Wheel of Fortune"] = 2 },
    ["Muerta"] = { ["Death"] = 3 },
    ["Phantom Assassin"] = { ["Strength"] = 1, ["Wheel of Fortune"] = 2 },
    ["Phantom Lancer"] = { ["The Magician"] = 1, ["The Lovers"] = 1, ["Wheel of Fortune"] = 1 },
    ["Razor"] = { ["The Devil"] = 1, ["The Emperor"] = 2 },
    ["Riki"] = { ["The Magician"] = 2, ["The Devil"] = 1 },
    ["Slark"] = { ["The Devil"] = 1, ["Strength"] = 1, ["Wheel of Fortune"] = 1 },
    ["Spectre"] = { ["The Magician"] = 1, ["Strength"] = 2 },
    ["Sven"] = { ["Strength"] = 3 },
    ["Terrorblade"] = { ["The Devil"] = 1, ["Strength"] = 1, ["Death"] = 1 },
    ["Troll Warlord"] = { ["The Devil"] = 1, ["The Emperor"] = 1, ["Strength"] = 1 },
    ["Ursa"] = { ["The Emperor"] = 1, ["The Lovers"] = 1, ["The Star"] = 1 },
    ["Weaver"] = { ["The Magician"] = 1, ["The Star"] = 1, ["Wheel of Fortune"] = 1 },
    ["Wraith King"] = { ["The Emperor"] = 3 },
    ["Broodmother"] = { ["The Lovers"] = 1, ["The Hermit"] = 1, ["Wheel of Fortune"] = 1 },
    ["Death Prophet"] = { ["The Star"] = 1, ["Wheel of Fortune"] = 1, ["Death"] = 1 },
    ["Dragon Knight"] = { ["The Emperor"] = 1, ["Strength"] = 1, ["Death"] = 1 },
    ["Ember Spirit"] = { ["The Magician"] = 1, ["The Lovers"] = 2 },
    ["Invoker"] = { ["The Magician"] = 2, ["The Devil"] = 1 },
    ["Kez"] = { ["The Emperor"] = 1, ["Strength"] = 2 },
    ["Kunkka"] = { ["The Emperor"] = 2, ["Strength"] = 1 },
    ["Leshrac"] = { ["The Magician"] = 1, ["The Devil"] = 2 },
    ["Lina"] = { ["The Magician"] = 2, ["The Devil"] = 1 },
    ["Meepo"] = { ["The Magician"] = 1, ["The Lovers"] = 2 },
    ["Necrophos"] = { ["The Emperor"] = 1, ["Death"] = 2 },
    ["Pangolier"] = { ["The Devil"] = 1, ["Wheel of Fortune"] = 2 },
    ["Puck"] = { ["The Fool"] = 2, ["The Magician"] = 1 },
    ["Pugna"] = { ["The Magician"] = 1, ["The Star"] = 1, ["Death"] = 1 },
    ["Ringmaster"] = { ["The Fool"] = 1, ["The Magician"] = 1, ["Death"] = 1 },
    ["Shadow Fiend"] = { ["The Devil"] = 2, ["Death"] = 1 },
    ["Sniper"] = { ["Strength"] = 1, ["The Hermit"] = 2 },
    ["Storm Spirit"] = { ["The Fool"] = 1, ["The Devil"] = 1, ["The Emperor"] = 1 },
    ["Tinker"] = { ["The Hermit"] = 2, ["The Star"] = 1 },
    ["Tiny"] = { ["The Fool"] = 1, ["The Star"] = 2 },
    ["Viper"] = { ["The Hermit"] = 2, ["Wheel of Fortune"] = 1 },
    ["Windranger"] = { ["Strength"] = 1, ["The Hermit"] = 1, ["The Star"] = 1 },
    ["Zeus"] = { ["The Fool"] = 2, ["The Devil"] = 1 },
    ["Abaddon"] = { ["The Hermit"] = 3 },
    ["Axe"] = { ["Strength"] = 2, ["The Hermit"] = 1 },
    ["Batrider"] = { ["The Lovers"] = 2, ["Wheel of Fortune"] = 1 },
    ["Beastmaster"] = { ["The Devil"] = 1, ["The Lovers"] = 2 },
    ["Brewmaster"] = { ["The Lovers"] = 2, ["Wheel of Fortune"] = 1 },
    ["Bristleback"] = { ["The Devil"] = 1, ["Strength"] = 2 },
    ["Centaur Warrunner"] = { ["The Emperor"] = 1, ["Strength"] = 2 },
    ["Dawnbreaker"] = { ["The Fool"] = 1, ["Strength"] = 1, ["The Star"] = 1 },
    ["Doom"] = { ["The Devil"] = 3 },
    ["Elder Titan"] = { ["Strength"] = 2, ["The Hermit"] = 1 },
    ["Legion Commander"] = { ["The Emperor"] = 2, ["Death"] = 1 },
    ["Lone Druid"] = { ["The Lovers"] = 1, ["The Hermit"] = 2 },
    ["Magnus"] = { ["Strength"] = 2, ["Wheel of Fortune"] = 1 },
    ["Mars"] = { ["The Emperor"] = 2, ["Strength"] = 1 },
    ["Night Stalker"] = { ["The Emperor"] = 2, ["Wheel of Fortune"] = 1 },
    ["Primal Beast"] = { ["The Emperor"] = 1, ["Strength"] = 2 },
    ["Pudge"] = { ["The Fool"] = 1, ["The Devil"] = 2 },
    ["Sand King"] = { ["The Hermit"] = 2, ["The Star"] = 1 },
    ["Spirit Breaker"] = { ["Strength"] = 1, ["Wheel of Fortune"] = 2 },
    ["Tidehunter"] = { ["The Emperor"] = 1, ["The Hermit"] = 2 },
    ["Timbersaw"] = { ["The Fool"] = 2, ["Wheel of Fortune"] = 1 },
    ["Underlord"] = { ["The Devil"] = 2, ["The Emperor"] = 1 },
    ["Visage"] = { ["The Lovers"] = 2, ["Death"] = 1 },
    ["Bounty Hunter"] = { ["The Devil"] = 2, ["The Hermit"] = 1 },
    ["Clockwerk"] = { ["The Hermit"] = 1, ["The Star"] = 2 },
    ["Earth Spirit"] = { ["The Emperor"] = 1, ["The Hermit"] = 2 },
    ["Earthshaker"] = { ["Strength"] = 2, ["The Hermit"] = 1 },
    ["Grimstroke"] = { ["The Devil"] = 2, ["The Lovers"] = 1 },
    ["Hoodwink"] = { ["The Fool"] = 1, ["The Magician"] = 1, ["The Lovers"] = 1 },
    ["Marci"] = { ["Strength"] = 2, ["The Hermit"] = 1 },
    ["Mirana"] = { ["The Emperor"] = 1, ["The Lovers"] = 1, ["The Star"] = 1 },
    ["Nyx Assassin"] = { ["The Hermit"] = 2, ["Wheel of Fortune"] = 1 },
    ["Ogre Magi"] = { ["The Fool"] = 1, ["Wheel of Fortune"] = 2 },
    ["Phoenix"] = { ["The Fool"] = 1, ["Wheel of Fortune"] = 1, ["Death"] = 1 },
    ["Rubick"] = { ["The Magician"] = 3 },
    ["Shadow Demon"] = { ["The Devil"] = 2, ["Death"] = 1 },
    ["Silencer"] = { ["The Magician"] = 1, ["The Emperor"] = 2 },
    ["Snapfire"] = { ["The Fool"] = 1, ["The Lovers"] = 1, ["The Star"] = 1 },
    ["Techies"] = { ["The Fool"] = 2, ["Death"] = 1 },
    ["Tusk"] = { ["Strength"] = 1, ["The Hermit"] = 2 },
    ["Undying"] = { ["The Hermit"] = 1, ["Death"] = 2 },
    ["Vengeful Spirit"] = { ["The Emperor"] = 1, ["The Lovers"] = 1, ["Death"] = 1 },
    ["Ancient Apparition"] = { ["Wheel of Fortune"] = 1, ["Death"] = 2 },
    ["Crystal Maiden"] = { ["The Fool"] = 2, ["The Magician"] = 1 },
    ["Dazzle"] = { ["The Lovers"] = 2, ["The Star"] = 1 },
    ["Disruptor"] = { ["The Fool"] = 1, ["The Star"] = 2 },
    ["Enchantress"] = { ["The Fool"] = 2, ["The Star"] = 1 },
    ["IO"] = { ["The Fool"] = 3 },
    ["Jakiro"] = { ["The Lovers"] = 3 },
    ["Keeper of the Light"] = { ["The Star"] = 3 },
    ["Lich"] = { ["The Magician"] = 1, ["Death"] = 2 },
    ["Lion"] = { ["The Magician"] = 1, ["The Devil"] = 2 },
    ["Skywrath Mage"] = { ["The Magician"] = 2, ["The Lovers"] = 1 },
    ["Treant Protector"] = { ["The Devil"] = 1, ["The Hermit"] = 1, ["The Star"] = 1 },
    ["Venomancer"] = { ["Wheel of Fortune"] = 1, ["Death"] = 2 },
    ["Warlock"] = { ["The Devil"] = 1, ["The Lovers"] = 1, ["The Hermit"] = 1 },
    ["Winter Wyvern"] = { ["The Hermit"] = 1, ["The Star"] = 2 },
    ["Witch Doctor"] = { ["The Hermit"] = 1, ["The Star"] = 1, ["Death"] = 1 },
}

local HERO_REWARDS_BY_ID = {}
for hero_name, rewards in pairs(HeroToToken) do
    local by_id = {}
    for token_name, count in pairs(rewards) do
        local token_id = TOKEN_NAME_TO_ID[token_name]
        if token_id then
            by_id[token_id] = count
        end
    end
    HERO_REWARDS_BY_ID[hero_name] = by_id
end

local function requirement_key(requirement)
    local parts = {}
    for token_id, count in pairs(requirement) do
        parts[#parts + 1] = token_id .. ":" .. count
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

local function compute_node_hero_matches(requirement)
    local full_clear = {}
    local partial = {}

    for hero_name, rewards in pairs(HERO_REWARDS_BY_ID) do
        local covers_all = true
        local contributes = false
        local partial_score = 0

        for token_id, needed in pairs(requirement) do
            local given = rewards[token_id] or 0
            if given > 0 then
                contributes = true
                partial_score = partial_score + math.min(given, needed)
            end
            if given < needed then
                covers_all = false
            end
        end

        if contributes then
            if covers_all then
                full_clear[#full_clear + 1] = hero_name
            else
                partial[#partial + 1] = { hero = hero_name, score = partial_score }
            end
        end
    end

    table.sort(full_clear)
    table.sort(partial, function(left, right)
        if left.score == right.score then
            return left.hero < right.hero
        end
        return left.score > right.score
    end)

    return full_clear, partial
end

local group = Menu.Create("General", "Main", "Dark Carnival", "Main", "General")
local ui = {}
ui.show_path_tokens = group:Switch("Show Path Tokens", false)
ui.show_path_tokens:ToolTip("On the Dark Carnival overworld map, reveals the token cost of every path and lets you hover/click a token to see which heroes grant it.")

local cached_user_data = nil
local path_token_index = {}
local path_token_data_requested = false
local was_on_overworld_map = false
local map_open_time = 0
local tokens_populated = false
local hero_plan = {}
local hero_dota_name_cache = {}
local node_room = {}
local room_order = {}
local room_label_of = {}
local token_container_markers = {}
local trays = {}
local open_tray_key = nil
local backdrop = nil
local room_badges = {}
local MAX_BADGE_HEROES = 3
local hero_plan_dirty = false

local function now_seconds()
    if os and os.clock then
        return os.clock()
    end
    return GlobalVars.GetCurTime()
end

local function decode_gc_message(proto_name, buffer, size)
    if not buffer then
        return nil
    end

    local decoded_json = protobuf.decodeToJSON(proto_name, buffer, size)
    if not decoded_json then
        return nil
    end

    return JSON:decode(decoded_json)
end

local function request_user_data()
    local encoded = protobuf.encodeFromJSON(MSG_GET_USER_DATA_NAME, JSON:encode({ overworld_id = OVERWORLD_ID }))
    if not encoded or not encoded.binary or not encoded.size then
        return
    end

    GC.SendMessage(encoded.binary, MSG_GET_USER_DATA, encoded.size)
end

local function is_overworld_map_open()
    local page = Panorama.GetPanelByPath(OVERWORLD_PAGE_PATH)
    return page ~= nil and page:IsValid() and page:IsVisible()
end

local function get_attribute_number(panel, candidates)
    for _, key in ipairs(candidates) do
        local value = tonumber(panel:GetAttribute(key, ""))
        if value then
            return value
        end
    end
    return nil
end

local function path_cost_by_id(path_id)
    local paths = cached_user_data and cached_user_data.overworld_paths
    if type(paths) ~= "table" then
        return nil
    end

    for _, path in ipairs(paths) do
        if tonumber(path.path_id) == path_id and path.path_state == "k_eOverworldPathState_Incomplete" then
            local token_counts = path.path_cost and path.path_cost.token_counts
            if type(token_counts) == "table" and #token_counts > 0 then
                return token_counts
            end
        end
    end

    return nil
end

local function js_string_literal(text)
    return '"' .. tostring(text):gsub('[\\"]', '\\%0') .. '"'
end

local panel_uid_counter = 0
local panel_marker_ids = setmetatable({}, { __mode = "k" })
local function ensure_panel_marker_id(panel)
    local cached = panel_marker_ids[panel]
    if cached then
        return cached
    end

    panel_uid_counter = panel_uid_counter + 1
    local marker_id = "PathTokensMarker" .. panel_uid_counter
    Panorama.CreatePanel("Panel", marker_id, panel, nil,
        "width: 0px; height: 0px; margin: 0px; visibility: collapse;")
    panel_marker_ids[panel] = marker_id
    return marker_id
end

local function run_on_panel(panel, js_function_body)
    if not panel or not panel:IsValid() then
        return
    end

    local marker_id = ensure_panel_marker_id(panel)
    local js = ([[
        (function() {
            let marker = $.GetContextPanel().FindChildTraverse(%s);
            if (!marker) {
                return;
            }
            let panel = marker.GetParent();
            if (!panel) {
                return;
            }
            (%s)(panel);
        })();
    ]]):format(js_string_literal(marker_id), js_function_body)
    Engine.RunScript(js, panel)
end

local function ensure_hittable(panel)
    run_on_panel(panel, [[
        function(panel) {
            panel.hittest = true;
            panel.hittestchildren = true;
            for (let p = panel.GetParent(); p; p = p.GetParent()) {
                p.hittestchildren = true;
                p.acceptsinput = true;
            }
        }
    ]])
end

local function hero_icon_style(dota_name)
    return ('background-size: cover; background-image: url("s2r://panorama/images/heroes/icons/%s_png.vtex");')
        :format(dota_name)
end

local function wire_hover_brightness(panel, hover_brightness, active_brightness)
    run_on_panel(panel, ([[
        function(panel) {
            panel.style.transitionProperty = "brightness";
            panel.style.transitionDuration = "0.12s";
            panel.SetPanelEvent("onmouseover", function() {
                panel.style.brightness = "%s";
            });
            panel.SetPanelEvent("onmouseout", function() {
                panel.style.brightness = "1.0";
            });
            panel.SetPanelEvent("onactivate", function() {
                panel.style.brightness = "%s";
            });
        }
    ]]):format(tostring(hover_brightness), tostring(active_brightness)))
end

local function wire_room_badge_events(panel, hover_brightness, attribute_name)
    run_on_panel(panel, ([[
        function(panel) {
            panel.style.transitionProperty = "brightness";
            panel.style.transitionDuration = "0.12s";
            panel.SetPanelEvent("onmouseover", function() {
                panel.style.brightness = "%s";
                let text = panel.GetAttributeString(%s, "");
                if (text.length > 0) {
                    $.DispatchEvent("UIShowTextTooltipStyled", panel, text, "TokenTooltip");
                }
            });
            panel.SetPanelEvent("onmouseout", function() {
                panel.style.brightness = "1.0";
                $.DispatchEvent("UIHideTextTooltip", panel);
            });
        }
    ]]):format(tostring(hover_brightness), js_string_literal(attribute_name)))
end

local function dota_name_for_hero(hero_name)
    if hero_dota_name_cache[hero_name] ~= nil then
        return hero_dota_name_cache[hero_name] or nil
    end

    local map = type(LIB_HEROES_DATA) == "table" and LIB_HEROES_DATA.menu_name_to_dota_name
    local result = nil
    if type(map) == "table" then
        result = map[hero_name]
        if not result then
            local target = hero_name:lower():gsub("%A", "")
            for menu_name, dota_name in pairs(map) do
                if menu_name:lower():gsub("%A", "") == target then
                    result = dota_name
                    break
                end
            end
        end
    end

    hero_dota_name_cache[hero_name] = result or false
    return result
end

local function wire_container_events(container, tooltip_text)
    run_on_panel(container, ([[
        function(panel) {
            panel.SetPanelEvent("onmouseover", function() {
                $.DispatchEvent("UIShowTextTooltipStyled", panel, %s, "TokenTooltip");
            });
            panel.SetPanelEvent("onmouseout", function() {
                $.DispatchEvent("UIHideTextTooltip", panel);
            });
            panel.SetPanelEvent("onactivate", function() {
                if (panel.BHasClass(%s)) {
                    panel.RemoveClass(%s);
                } else {
                    panel.AddClass(%s);
                }
            });
        }
    ]]):format(js_string_literal(tooltip_text), js_string_literal(CONTAINER_OPEN_CLASS),
        js_string_literal(CONTAINER_OPEN_CLASS), js_string_literal(CONTAINER_OPEN_CLASS)))
end

local function build_hero_portraits(hero_block, heroes)
    for _, hero_name in ipairs(heroes) do
        local dota_name = dota_name_for_hero(hero_name)
        if dota_name then
            local image = Panorama.CreatePanel("Panel", nil, hero_block, nil,
                "width: 42px; height: 42px; margin: 3px; border-radius: 3px; " .. hero_icon_style(dota_name))
            ensure_hittable(image)
            wire_hover_brightness(image, 1.4, 0.7, "tray hero portrait (" .. hero_name .. ")")
        end
    end
end

local function get_or_build_tray(key, requirement, title_text)
    local tray = trays[key]
    if tray and tray:IsValid() then
        return tray
    end

    local full_clear, partial = compute_node_hero_matches(requirement)
    local heroes, status_text
    if #full_clear > 0 then
        heroes, status_text = full_clear, "Clears this in one game:"
    elseif #partial > 0 then
        local names = {}
        for _, entry in ipairs(partial) do
            names[#names + 1] = entry.hero
        end
        heroes, status_text = names, "No single hero clears this -- best partial progress:"
    else
        return nil
    end

    if #heroes > MAX_TRAY_HEROES then
        local capped = {}
        for i = 1, MAX_TRAY_HEROES do
            capped[i] = heroes[i]
        end
        heroes = capped
    end

    local root = Panorama.GetPanelByPath(OVERWORLD_PAGE_PATH)
    if not root then
        return nil
    end

    tray = Panorama.CreatePanel("Panel", nil, root, nil,
        "horizontal-align: left; vertical-align: center; width: 280px; padding: 18px; " ..
        "flow-children: down; background-color: gradient( linear, 0% 0%, 0% 100%, from( rgb(61, 42, 33) ), to( rgb(31, 20, 15) ) ); " ..
        "border: 1px solid rgba(255, 215, 140, 0.5); border-radius: 6px; z-index: 50; " ..
        "box-shadow: 0px 8px 32px -4px rgba(0, 0, 0, 0.7);")
    ensure_hittable(tray)

    local title = Panorama.CreatePanel("Label", nil, tray, nil,
        "horizontal-align: center; color: gold1; font-size: 16px; font-weight: bold; " ..
        "margin-bottom: 8px; text-shadow: 0px 2px 6px rgba(0, 0, 0, 0.8);")
    title:SetText(title_text or "")

    local token_row = Panorama.CreatePanel("Panel", nil, tray, nil,
        "horizontal-align: center; flow-children: right; margin-bottom: 10px;")
    for token_id, count in pairs(requirement) do
        for _ = 1, count do
            Panorama.CreatePanel("DOTADarkCarnivalToken", nil, token_row,
                "TokenName_" .. (TOKEN_CSS_NAME[token_id] or ""), "ui-scale: 60%; margin: -8px;")
        end
    end

    local status_label = Panorama.CreatePanel("Label", nil, tray, nil,
        "horizontal-align: center; color: rgba(230, 220, 255, 0.75); font-size: 12px; " ..
        "margin-bottom: 8px; text-align: center;")
    status_label:SetText(status_text)

    local options = Panorama.CreatePanel("Panel", nil, tray, nil,
        "width: 100%; flow-children: down; padding: 8px; " ..
        "background-color: rgba(0, 0, 0, 0.25); border-radius: 4px;")
    local hero_block = Panorama.CreatePanel("Panel", "HeroBlock", options, nil,
        "flow-children: right-wrap; horizontal-align: center; width: 100%;")
    build_hero_portraits(hero_block, heroes)

    local close_button = Panorama.CreatePanel("Panel", "TrayCloseButton", tray, nil,
        "horizontal-align: right; vertical-align: top; width: 26px; height: 26px; " ..
        "background-color: rgba(0, 0, 0, 0.6); border: 1px solid rgba(255, 255, 255, 0.3); " ..
        "border-radius: 13px; margin: -10px;")
    local close_label = Panorama.CreatePanel("Label", nil, close_button, nil,
        "horizontal-align: center; vertical-align: center; color: white; font-size: 15px;")
    close_label:SetText("x")
    ensure_hittable(close_button)

    run_on_panel(close_button, ([[
        function(panel) {
            let tray = panel.GetParent();
            panel.style.transitionProperty = "brightness";
            panel.style.transitionDuration = "0.12s";
            panel.SetPanelEvent("onmouseover", function() {
                panel.style.brightness = "1.6";
            });
            panel.SetPanelEvent("onmouseout", function() {
                panel.style.brightness = "1.0";
            });
            panel.SetPanelEvent("onactivate", function() {
                panel.style.brightness = "0.6";
                tray.AddClass(%s);
            });
        }
    ]]):format(js_string_literal(TRAY_CLOSE_CLASS)))

    tray:SetVisible(false)
    trays[key] = tray
    return tray
end

local function ensure_backdrop()
    if backdrop and backdrop:IsValid() then
        return backdrop
    end

    local root = Panorama.GetPanelByPath(OVERWORLD_PAGE_PATH)
    if not root then
        return nil
    end

    backdrop = Panorama.CreatePanel("Panel", nil, root, nil, "width: 100%; height: 100%; z-index: 40;")
    ensure_hittable(backdrop)
    run_on_panel(backdrop, ([[
        function(panel) {
            panel.SetPanelEvent("onactivate", function() {
                panel.AddClass(%s);
            });
        }
    ]]):format(js_string_literal(BACKDROP_CLOSE_CLASS)))

    backdrop:SetVisible(false)
    return backdrop
end

local function update_tray_visibility()
    local target_key = nil
    for i = #token_container_markers, 1, -1 do
        local marker = token_container_markers[i]
        if not marker.container:IsValid() then
            table.remove(token_container_markers, i)
        elseif marker.container:HasClass(CONTAINER_OPEN_CLASS) then
            target_key = marker.key
        end
    end

    local current_tray = open_tray_key and trays[open_tray_key]
    local force_close = false

    if current_tray and current_tray:IsValid() and current_tray:HasClass(TRAY_CLOSE_CLASS) then
        current_tray:RemoveClasses(TRAY_CLOSE_CLASS)
        force_close = true
    end
    if backdrop and backdrop:IsValid() and backdrop:HasClass(BACKDROP_CLOSE_CLASS) then
        backdrop:RemoveClasses(BACKDROP_CLOSE_CLASS)
        force_close = true
    end

    if force_close then
        for _, marker in ipairs(token_container_markers) do
            if marker.key == open_tray_key then
                marker.container:RemoveClasses(CONTAINER_OPEN_CLASS)
            end
        end
        target_key = nil
    end

    if target_key ~= open_tray_key then
        if current_tray and current_tray:IsValid() then
            current_tray:SetVisible(false)
        end
        open_tray_key = target_key

        if open_tray_key then
            local marker
            for _, m in ipairs(token_container_markers) do
                if m.key == open_tray_key then
                    marker = m
                    break
                end
            end

            local tray = marker and get_or_build_tray(open_tray_key, marker.requirement, marker.tooltip_text)
            if tray then
                tray:SetVisible(true)
                local bg = ensure_backdrop()
                if bg then
                    bg:SetVisible(true)
                end
            else
                open_tray_key = nil
            end
        end

        if not open_tray_key and backdrop and backdrop:IsValid() then
            backdrop:SetVisible(false)
        end
    end
end

local function populate_node_tokens(node_panel)
    local node_id = get_attribute_number(node_panel, NODE_ID_ATTRIBUTES)
    if not node_id or path_token_index[node_id] then
        return
    end

    -- A "path" is recorded under the id of the node you LEAVE, not the one you arrive at -- the
    -- cost of path_id=X unlocks node X+1, not node X (confirmed live: a minigame node with no
    -- cost of its own was showing the cost that actually belongs to the node right after it).
    -- So the cost that belongs on THIS node was recorded one id lower.
    local token_counts = path_cost_by_id(node_id - 1)
    if not token_counts then
        return
    end

    local container = node_panel:FindChildTraverse("TokenContainer")
    if not container then
        return
    end

    local already_populated = container:GetChildCount() > 0

    local unlock_container = container:GetParent()
    if unlock_container and not already_populated then
        unlock_container:SetStyle("visibility: visible;")
    end

    local tooltip_parts = {}
    local requirement = {}
    local has_tokens = false

    for _, token in ipairs(token_counts) do
        local token_id = tonumber(token.token_id)
        local count = tonumber(token.token_count) or 0
        local token_name = TOKEN_CSS_NAME[token_id]
        local display_name = TOKEN_DISPLAY_NAME[token_id]
        if token_name and count > 0 then
            has_tokens = true
            requirement[token_id] = count
            if display_name then
                tooltip_parts[#tooltip_parts + 1] = ("%dx %s"):format(count, display_name)
            end
            if not already_populated then
                for _ = 1, count do
                    Panorama.CreatePanel("DOTADarkCarnivalToken", nil, container, "TokenName_" .. token_name .. " TokenUnowned", nil)
                end
            end
        end
    end

    if has_tokens and #tooltip_parts > 0 then
        -- TEMPORARY diagnostic: shows which node this cost is attached to, right in the tooltip
        -- you're already hovering, so we can confirm (or rule out) an off-by-one between
        -- path_id and node_id without needing a console. Safe to remove once confirmed.
        local tooltip_text = "Need " .. table.concat(tooltip_parts, ", ") .. (" (node %d)"):format(node_id)
        ensure_hittable(container)
        wire_container_events(container, tooltip_text)
        token_container_markers[#token_container_markers + 1] = {
            container = container,
            key = requirement_key(requirement),
            requirement = requirement,
            tooltip_text = tooltip_text,
        }
    end

    path_token_index[node_id] = unlock_container or container
end

local function collect_nodes(panel, depth)
    if not panel or depth > MAX_NODE_SEARCH_DEPTH then
        return
    end

    if panel:HasClass("Node") then
        populate_node_tokens(panel)
        return
    end

    for i = 0, panel:GetChildCount() - 1 do
        collect_nodes(panel:GetChild(i), depth + 1)
    end
end

local function build_path_token_index()
    local train_layer = Panorama.GetPanelByPath(OVERWORLD_MAP_TRAIN_LAYER_PATH)
    if not train_layer then
        return
    end

    collect_nodes(train_layer, 0)
end

local function reset_path_token_index()
    path_token_index = {}
    path_token_data_requested = false
    tokens_populated = false
    token_container_markers = {}
    if open_tray_key and trays[open_tray_key] and trays[open_tray_key]:IsValid() then
        trays[open_tray_key]:SetVisible(false)
    end
    open_tray_key = nil
    if backdrop and backdrop:IsValid() then
        backdrop:SetVisible(false)
    end
    room_badges = {}
end

local function collect_room_map(panel, depth, current_room_key)
    if not panel or depth > MAX_NODE_SEARCH_DEPTH then
        return
    end

    if panel:HasClass("Room") then
        current_room_key = panel
        if not room_label_of[current_room_key] then
            local numeric = get_attribute_number(panel, ROOM_ID_ATTRIBUTES)
            room_order[#room_order + 1] = current_room_key
            room_label_of[current_room_key] = numeric and ("Room " .. numeric) or ("Room " .. #room_order)
        end
    end

    if panel:HasClass("Node") then
        local node_id = get_attribute_number(panel, NODE_ID_ATTRIBUTES)
        if node_id and current_room_key then
            node_room[node_id] = current_room_key
        end
        return
    end

    for i = 0, panel:GetChildCount() - 1 do
        collect_room_map(panel:GetChild(i), depth + 1, current_room_key)
    end
end

local function build_room_map()
    node_room = {}
    room_order = {}
    room_label_of = {}

    local train_layer = Panorama.GetPanelByPath(OVERWORLD_MAP_TRAIN_LAYER_PATH)
    if not train_layer then
        return
    end

    collect_room_map(train_layer, 0, nil)
end

local function parse_inventory(user_data)
    local inventory = {}
    local token_counts = user_data and user_data.token_inventory and user_data.token_inventory.token_counts
    if type(token_counts) ~= "table" then
        return inventory
    end

    for _, token in ipairs(token_counts) do
        local token_id = tonumber(token.token_id)
        if token_id then
            inventory[token_id] = tonumber(token.token_count) or 0
        end
    end

    return inventory
end

local function compute_greedy_plan(missing)
    local plan_counts = {}
    for _ = 1, MAX_PLAN_GAMES do
        if next(missing) == nil then
            break
        end

        local best_hero, best_score = nil, 0
        for hero, rewards in pairs(HeroToToken) do
            local score = 0
            for token_name, reward_count in pairs(rewards) do
                local token_id = TOKEN_NAME_TO_ID[token_name]
                local deficit = token_id and missing[token_id]
                if deficit then
                    score = score + math.min(reward_count, deficit)
                end
            end
            if score > best_score or (score == best_score and score > 0 and hero < best_hero) then
                best_hero, best_score = hero, score
            end
        end

        if not best_hero then
            break
        end

        plan_counts[best_hero] = (plan_counts[best_hero] or 0) + 1
        for token_name, reward_count in pairs(HeroToToken[best_hero]) do
            local token_id = TOKEN_NAME_TO_ID[token_name]
            if token_id and missing[token_id] then
                missing[token_id] = missing[token_id] - reward_count
                if missing[token_id] <= 0 then
                    missing[token_id] = nil
                end
            end
        end
    end
    return plan_counts
end

local function compute_hero_plan()
    hero_plan = {}
    if not cached_user_data then
        return
    end

    local paths = cached_user_data.overworld_paths
    if type(paths) ~= "table" then
        return
    end

    build_room_map()
    if next(node_room) == nil then
        return
    end

    local inventory = parse_inventory(cached_user_data)
    local room_required = {}

    for _, path in ipairs(paths) do
        if path.path_state == "k_eOverworldPathState_Incomplete" then
            local path_id = tonumber(path.path_id)
            -- Same shift as path_cost_by_id: path_id's cost belongs to node path_id+1, so that's
            -- the node (and therefore room) it should be attributed to.
            local room_key = path_id and node_room[path_id + 1]
            if room_key then
                local token_counts = path.path_cost and path.path_cost.token_counts
                if type(token_counts) == "table" then
                    room_required[room_key] = room_required[room_key] or {}
                    for _, token in ipairs(token_counts) do
                        local token_id = tonumber(token.token_id)
                        local count = tonumber(token.token_count) or 0
                        if token_id and count > 0 then
                            room_required[room_key][token_id] = (room_required[room_key][token_id] or 0) + count
                        end
                    end
                end
            end
        end
    end

    for _, room_key in ipairs(room_order) do
        local required = room_required[room_key]
        if required then
            local missing = {}
            for token_id, needed in pairs(required) do
                local deficit = needed - (tonumber(inventory[token_id]) or 0)
                if deficit > 0 and TOKEN_DISPLAY_NAME[token_id] then
                    missing[token_id] = deficit
                end
            end

            if next(missing) then
                local plan_counts = compute_greedy_plan(missing)
                local heroes = {}
                for hero, games in pairs(plan_counts) do
                    heroes[#heroes + 1] = { hero = hero, games = games }
                end
                table.sort(heroes, function(left, right)
                    if left.games == right.games then
                        return left.hero < right.hero
                    end
                    return left.games > right.games
                end)
                if #heroes > 0 then
                    hero_plan[#hero_plan + 1] = { room_panel = room_key, room = room_label_of[room_key], heroes = heroes }
                end
            end
        end
    end

    hero_plan_dirty = true
end

local ROOM_BADGE_TOOLTIP_ATTR = "path_tokens_room_plan"

local function ensure_room_badge(room_panel)
    local badge = room_badges[room_panel]
    if badge and badge.container:IsValid() then
        return badge
    end

    local anchor = room_panel:FindChildTraverse("RoomContents") or room_panel

    local container = Panorama.CreatePanel("Panel", nil, anchor, nil,
        "visibility: visible; flow-children: right; " ..
        "horizontal-align: center; vertical-align: top; margin-top: 26px; padding: 4px 8px; " ..
        "background-color: rgba(10, 8, 14, 0.85); border: 1px solid rgba(255, 215, 140, 0.35); " ..
        "border-radius: 4px; z-index: 5;")
    ensure_hittable(container)
    wire_room_badge_events(container, 1.6, ROOM_BADGE_TOOLTIP_ATTR)

    local slots = {}
    for i = 1, MAX_BADGE_HEROES do
        local slot = Panorama.CreatePanel("Panel", nil, container, nil,
            "flow-children: down; horizontal-align: center; margin: 0px 4px; visibility: collapse;")
        local icon = Panorama.CreatePanel("Panel", nil, slot, nil,
            "width: 36px; height: 36px; horizontal-align: center; border-radius: 3px;")
        local count = Panorama.CreatePanel("Label", nil, slot, nil,
            "horizontal-align: center; color: gold1; font-weight: bold; font-size: 13px; " ..
            "text-shadow: 0px 1px 4px black;")
        slots[i] = { slot = slot, icon = icon, count = count }
    end

    badge = { container = container, slots = slots }
    room_badges[room_panel] = badge
    return badge
end

local function update_room_badge(entry)
    local room_panel = entry.room_panel
    if not room_panel or not room_panel:IsValid() then
        return
    end

    local badge = ensure_room_badge(room_panel)
    local tooltip_parts = {}

    for i, slot in ipairs(badge.slots) do
        local plan_entry = entry.heroes[i]
        local dota_name = plan_entry and dota_name_for_hero(plan_entry.hero)

        if plan_entry and dota_name then
            slot.icon:SetStyle(hero_icon_style(dota_name))
            slot.count:SetText("x" .. plan_entry.games)
            slot.slot:SetStyle("visibility: visible;")
            tooltip_parts[#tooltip_parts + 1] = ("%s x%d"):format(plan_entry.hero, plan_entry.games)
        else
            slot.slot:SetStyle("visibility: collapse;")
        end
    end

    for i = MAX_BADGE_HEROES + 1, #entry.heroes do
        local extra = entry.heroes[i]
        tooltip_parts[#tooltip_parts + 1] = ("%s x%d"):format(extra.hero, extra.games)
    end

    badge.container:SetAttribute(ROOM_BADGE_TOOLTIP_ATTR, "Play: " .. table.concat(tooltip_parts, ", "))
end

local function build_room_hero_badges()
    for _, entry in ipairs(hero_plan) do
        update_room_badge(entry)
    end
end

function script.OnGCMessage(data)
    if not ui.show_path_tokens:Get() then
        return
    end

    local msg_type = tonumber(data and data.msg_type)
    local proto_name = nil
    if msg_type == MSG_USER_DATA_UPDATED then
        proto_name = MSG_USER_DATA_UPDATED_NAME
    elseif msg_type == MSG_GET_USER_DATA_RESPONSE then
        proto_name = MSG_GET_USER_DATA_RESPONSE_NAME
    else
        return
    end

    local decoded = decode_gc_message(proto_name, data.binary_buffer_recv or data.binary_buffer_send, data.size)
    local user_data = decoded and decoded.user_data
    if not user_data then
        return
    end

    cached_user_data = user_data
    compute_hero_plan()
end

function script.OnFrame()
    if not ui.show_path_tokens:Get() then
        return
    end

    local on_overworld_map = is_overworld_map_open()

    if not on_overworld_map then
        if was_on_overworld_map then
            reset_path_token_index()
        end
        was_on_overworld_map = false
        return
    end

    if not was_on_overworld_map then
        map_open_time = now_seconds()
        if cached_user_data then
            compute_hero_plan()
        end
    end
    was_on_overworld_map = true

    if not cached_user_data and not path_token_data_requested then
        path_token_data_requested = true
        request_user_data()
    end

    if cached_user_data and now_seconds() - map_open_time >= POPULATE_DELAY then
        if not tokens_populated then
            tokens_populated = true
            build_path_token_index()
            compute_hero_plan()
        else
            local stale = false
            for node_id, container in pairs(path_token_index) do
                if not container:IsValid() then
                    path_token_index[node_id] = nil
                    stale = true
                end
            end
            if stale then
                build_path_token_index()
            end
        end
        if hero_plan_dirty then
            hero_plan_dirty = false
            build_room_hero_badges()
        end
    end

    update_tray_visibility()
end

function script.OnGameEnd()
    cached_user_data = nil
    was_on_overworld_map = false
    reset_path_token_index()
end

return script
