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
local CONFIG_NAME = "Dark Carnival Best"
local PICK_PHASE_STATES = { [2] = true, [9] = true, [12] = true }

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
}

local TOKEN_INFO = {
    [1]  = { name = "Шут" },
    [2]  = { name = "Маг" },
    [3]  = { name = "Жрица" },
    [4]  = { name = "Дьявол" },
    [5]  = { name = "Император" },
    [6]  = { name = "Влюблённые" },
    [7]  = { name = "Сила" },
    [8]  = { name = "Отшельник" },
    [9]  = { name = "Звезда" },
    [10] = { name = "Колесо" },
    [11] = { name = "Смерть" }
}

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
local maintab = Menu.Create("General", "Main", "Dark Carnival")
local mainMenu = maintab:Create("Main")
maintab:Icon("\u{f521}")

local groupMain = mainMenu:Create("Настройки")
local ui = {}
ui.suggest_heroes = groupMain:Switch("Включить советник по пику", true)
ui.depth = groupMain:Slider("Глубина планирования (Сколько ячеек вперёд)", 1, 10, 1)
ui.refresh = groupMain:Switch("Обновить", false)

ui.suggest_heroes:Icon("\u{f00c}")
ui.depth:Icon("\u{f140}")
ui.refresh:Icon("\u{f2f9}")

local cached_user_data = nil
local suggestions = {}
local in_pick_phase = false
local last_state = nil
local heroIdCache = {}
local prev_grid_config = nil

local function updateUiState()
    local enabled = ui.suggest_heroes:Get()
    ui.depth:Disabled(not enabled)
    ui.refresh:Disabled(not enabled)
end

local function buildHeroCache()
    if next(heroIdCache) then return end
    for id = 1, 200 do
        if Engine and Engine.GetHeroNameByID then
            local unitName = Engine.GetHeroNameByID(id)
            if unitName and unitName ~= "" then
                heroIdCache[string.lower(unitName)] = id
                local cleanName = string.gsub(unitName, "^npc_dota_hero_", "")
                heroIdCache[string.lower(cleanName)] = id
                if Engine.GetDisplayNameByUnitName then
                    local displayName = Engine.GetDisplayNameByUnitName(unitName)
                    if displayName and displayName ~= "" then
                        heroIdCache[string.lower(displayName)] = id
                    end
                end
            end
        end
    end
end

local function parse_inventory(user_data)
    local inventory = {}
    local token_counts = user_data and user_data.token_inventory and user_data.token_inventory.token_counts
    if type(token_counts) ~= "table" then return inventory end
    for _, token in ipairs(token_counts) do
        local token_id = tonumber(token.token_id)
        if token_id then
            inventory[token_id] = tonumber(token.token_count) or 0
        end
    end
    return inventory
end

local function get_next_incomplete_paths(user_data, count_limit)
    local paths = user_data and user_data.overworld_paths
    local result = {}
    if type(paths) ~= "table" then return result end

    local incomplete = {}
    for _, path in ipairs(paths) do
        if path.path_state == "k_eOverworldPathState_Incomplete" then
            table.insert(incomplete, path)
        end
    end

    table.sort(incomplete, function(a, b)
        return (tonumber(a.path_id) or 0) < (tonumber(b.path_id) or 0)
    end)

    for i = 1, math.min(count_limit or 1, #incomplete) do
        table.insert(result, incomplete[i])
    end
    return result
end

local function build_missing_requirements(paths, inventory)
    local missing = {}
    for id = 1, 30 do missing[id] = 0 end

    for _, path in ipairs(paths) do
        local token_counts = path and path.path_cost and path.path_cost.token_counts
        if type(token_counts) == "table" then
            for _, token in ipairs(token_counts) do
                local token_id = tonumber(token.token_id)
                local needed = tonumber(token.token_count) or 0
                if token_id and needed > 0 then
                    local own = tonumber(inventory[token_id]) or 0
                    local deficit = math.max(0, needed - own)
                    missing[token_id] = (missing[token_id] or 0) + deficit
                end
            end
        end
    end
    return missing
end

local function reward_count_for_token(rewards, token_id)
    for token_name, count in pairs(rewards) do
        if TOKEN_NAME_TO_ID[token_name] == token_id then
            return tonumber(count) or 0
        end
    end
    return 0
end

local function score_heroes(missing)
    local scored = {}
    for hero_name, rewards in pairs(HeroToToken) do
        local total_matches = 0
        for token_id, deficit in pairs(missing) do
            if deficit > 0 then
                local reward_count = reward_count_for_token(rewards, token_id)
                if reward_count > 0 then
                    total_matches = total_matches + math.min(reward_count, deficit)
                end
            end
        end

        if total_matches > 0 then
            scored[#scored + 1] = {
                hero = hero_name,
                matches = total_matches
            }
        end
    end

    table.sort(scored, function(a, b)
        if a.matches == b.matches then
            return a.hero < b.hero
        end
        return a.matches > b.matches
    end)

    return scored
end

local function decode_gc_message(proto_name, buffer, size)
    if not buffer then return nil end
    local decoded_json = protobuf.decodeToJSON(proto_name, buffer, size)
    if not decoded_json then return nil end
    return JSON:decode(decoded_json)
end

local function request_user_data()
    local encoded = protobuf.encodeFromJSON(MSG_GET_USER_DATA_NAME, JSON:encode({ overworld_id = OVERWORLD_ID }))
    if not encoded or not encoded.binary or not encoded.size then return end
    GC.SendMessage(encoded.binary, MSG_GET_USER_DATA, encoded.size)
    print("Запрос данных инвентаря отправлен на сервер Valve.")
end

local function update_dota_hero_grid()
    if not ui.suggest_heroes:Get() or not Engine or not Engine.CreateConfig or not Engine.SetNewGridConfig then return end
    buildHeroCache()

    local ids_3 = {}
    local ids_2 = {}
    local ids_1 = {}

    for _, rec in ipairs(suggestions) do
        local hName = string.lower(tostring(rec.hero or ""))
        local hId = heroIdCache[hName]
        if hId then
            if rec.matches >= 3 then
                table.insert(ids_3, hId)
            elseif rec.matches == 2 then
                table.insert(ids_2, hId)
            elseif rec.matches == 1 then
                table.insert(ids_1, hId)
            end
        end
    end

    if #ids_3 == 0 and #ids_2 == 0 and #ids_1 == 0 then return end

    local categories = {}

    if #ids_3 > 0 then
        table.insert(categories, {
            name = "3 ЖЕТОНА (Идеальный выбор)",
            hero_ids = ids_3,
            x = 0.0,
            y = 0.0,
            width = 1000.0,
            height = 200.0
        })
    end

    if #ids_2 > 0 then
        table.insert(categories, {
            name = "2 ЖЕТОНА (Отличный выбор)",
            hero_ids = ids_2,
            x = 0.0,
            y = 210.0,
            width = 1000.0,
            height = 190.0
        })
    end

    if #ids_1 > 0 then
        table.insert(categories, {
            name = "1 ЖЕТОН (Полезные герои)",
            hero_ids = ids_1,
            x = 0.0,
            y = 420,
            width = 1000.0,
            height = 180.0
        })
    end

    pcall(Engine.CreateConfig, CONFIG_NAME, categories)
    pcall(Engine.SetNewGridConfig, CONFIG_NAME)
    print("Сетка героев в Доте обновлена: 3 жетона (" .. #ids_3 .. "), 2 жетона (" .. #ids_2 .. "), 1 жетон (" .. #ids_1 .. ").")
end

local function compute_suggestions()
    suggestions = {}
    if not cached_user_data then return end

    local depth = ui.depth:Get() or 1
    local paths = get_next_incomplete_paths(cached_user_data, depth)
    local inventory = parse_inventory(cached_user_data)

    print(string.format("АНАЛИЗ БЛИЖАЙШИХ %d ЯЧЕЕК (ПЛАН НА %d ВПЕРЁД):", #paths, depth))
    for i, path in ipairs(paths) do
        local pId = tonumber(path.path_id) or i
        local costStr = ""
        local token_counts = path and path.path_cost and path.path_cost.token_counts
        if type(token_counts) == "table" then
            for _, token in ipairs(token_counts) do
                local tId = tonumber(token.token_id)
                local needed = tonumber(token.token_count) or 0
                if tId and needed > 0 then
                    local tInfo = TOKEN_INFO[tId]
                    local tName = tInfo and tInfo.name or ("Токен #" .. tId)
                    local own = tonumber(inventory[tId]) or 0
                    costStr = costStr .. string.format("[%s: нужно %d, есть %d] ", tName, needed, own)
                end
            end
        end
        print(string.format("  Ячейка #%d (Path ID: %d): %s", i, pId, costStr))
    end

    local missing = build_missing_requirements(paths, inventory)
    suggestions = score_heroes(missing)
    update_dota_hero_grid()
end

ui.suggest_heroes:SetCallback(function(this)
    updateUiState()
    if not this:Get() then
        if prev_grid_config and prev_grid_config ~= CONFIG_NAME and Engine and Engine.SetNewGridConfig then
            pcall(Engine.SetNewGridConfig, prev_grid_config)
            print("Восстановлена предыдущая сетка героев: " .. tostring(prev_grid_config))
        end
        return
    end
    cached_user_data = nil
    suggestions = {}
    request_user_data()
end, true)

ui.refresh:SetCallback(function(this)
    if this:Get() then
        cached_user_data = nil
        suggestions = {}
        request_user_data()
        this:Set(false)
    end
end)

ui.depth:SetCallback(function()
    if ui.suggest_heroes:Get() then
        if cached_user_data then
            compute_suggestions()
        else
            request_user_data()
        end
    end
end)

function script.OnScriptsLoaded()
    buildHeroCache()
    updateUiState()
    if ui.suggest_heroes:Get() then
        if Engine and Engine.GetCurrentConfigName then
            prev_grid_config = Engine.GetCurrentConfigName()
        end
        request_user_data()
    end
end

function script.OnGameRulesStateChange(data)
    local new_state = tonumber(data and data.new_state)
    if new_state == nil or new_state == last_state then return end
    last_state = new_state
    local was_pick_phase = in_pick_phase
    in_pick_phase = PICK_PHASE_STATES[new_state] == true
    if not ui.suggest_heroes:Get() then return end
    if in_pick_phase and not was_pick_phase then
        cached_user_data = nil
        suggestions = {}
        request_user_data()
    elseif not in_pick_phase and was_pick_phase then
        suggestions = {}
    end
end

function script.OnGCMessage(data)
    if not ui.suggest_heroes:Get() then return end
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
    if not user_data then return end
    cached_user_data = user_data
    compute_suggestions()
    print("Данные успешно получены от Game Coordinator.")
end

function script.OnGameEnd()
    cached_user_data = nil
    suggestions = {}
    in_pick_phase = false
    last_state = nil
end

return script
