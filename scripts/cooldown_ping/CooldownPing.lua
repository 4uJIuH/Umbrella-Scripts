local protobuf = require("protobuf")
local JSON = require("assets.JSON")

local App = {}

local function safe_call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

local function is_russian()
    if Localizer and Localizer.Get then
        local language = safe_call(Localizer.Get, "Language")
        if language == "Язык" then return true end
        if language == "Language" then return false end
        local general = safe_call(Localizer.Get, "General")
        if general == "Общее" then return true end
        if general == "General" then return false end
    end
    if Steam and Steam.GetGameLanguage then
        local language = safe_call(Steam.GetGameLanguage)
        return type(language) == "string" and language:lower():find("russian", 1, true) ~= nil
    end
    return false
end

local function tr(english, russian)
    return is_russian() and russian or english
end

local menu = Menu.Create("General", "Cooldown Ping", "Cooldown Ping")
menu:Icon("\u{f2f1}")

local main_tab = menu:Create(tr("Main", "Основное"))
local settings = main_tab:Create(tr("Settings", "Настройки"))

local UI = {
    enabled = settings:Switch(tr("Enable Cooldown Ping", "Включить Cooldown Ping"), true, "\u{f06e}"),
    abilities = settings:Switch(tr("Enemy Abilities", "Способности врагов"), true, "\u{f1e2}"),
    items = settings:Switch(tr("Enemy Items", "Предметы врагов"), true, "\u{f54e}"),
}

settings:Label(tr("Replaces the default warning only when cooldown is known", "Заменяет стандартное предупреждение только при известном кулдауне"), "\u{f05a}")
settings:Label(tr("Author: Flutter", "Автор: Flutter"), "\u{f007}")

local last_message = {
    key = "",
    time = -100,
}

local function clock()
    if GlobalVars and GlobalVars.GetRealTime then
        local value = safe_call(GlobalVars.GetRealTime)
        if type(value) == "number" then return value end
    end
    if GlobalVars and GlobalVars.GetCurTime then
        local value = safe_call(GlobalVars.GetCurTime)
        if type(value) == "number" then return value end
    end
    return os.clock()
end

local function entity_from_index(index)
    index = tonumber(index)
    if not index or index < 0 or index == 16777215 then return nil end
    return safe_call(Entity.Get, index)
end

local function ability_id(ability)
    return tonumber(safe_call(Ability.GetAbilityID, ability))
end

local function find_owned_ability(owner, id, item)
    id = tonumber(id)
    if not owner or not id or id < 0 then return nil end
    local getter = item and NPC.GetItemByIndex or NPC.GetAbilityByIndex
    if type(getter) ~= "function" then return nil end
    local maximum = item and 20 or 31
    for index = 0, maximum do
        local ability = safe_call(getter, owner, index)
        if ability and ability_id(ability) == id then return ability end
    end
    return nil
end

local function hero_owner(entity)
    local current = entity
    local fallback = entity
    for _ = 1, 5 do
        if not current then break end
        if NPC and NPC.IsHero and safe_call(NPC.IsHero, current) then return current end
        if Entity and Entity.IsPlayer and safe_call(Entity.IsPlayer, current) and Player and Player.GetAssignedHero then
            local hero = safe_call(Player.GetAssignedHero, current)
            if hero then return hero end
        end
        current = safe_call(Entity.GetOwner, current)
    end
    return fallback
end

local function prettify(name)
    if type(name) ~= "string" then return "" end
    name = name:gsub("^npc_dota_hero_", ""):gsub("^item_", ""):gsub("_", " ")
    return (name:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest
    end))
end

local function localized_owner_name(owner)
    local name = safe_call(NPC.GetUnitName, owner) or safe_call(Entity.GetUnitName, owner) or ""
    if GameLocalizer and GameLocalizer.FindNPC then
        local localized = safe_call(GameLocalizer.FindNPC, name)
        if type(localized) == "string" and localized ~= "" then return localized end
    end
    return prettify(name)
end

local function localized_ability_name(ability, item)
    local name = safe_call(Ability.GetName, ability) or ""
    if GameLocalizer then
        local finder = item and GameLocalizer.FindItem or GameLocalizer.FindAbility
        local localized = safe_call(finder, name)
        if type(localized) == "string" and localized ~= "" then return localized end
    end
    return prettify(name)
end

local function write_log(text)
    if Log and Log.Write then safe_call(Log.Write, "[CooldownPing] " .. tostring(text)) end
end

local function decode_json(encoded)
    if type(encoded) ~= "string" or encoded == "" then return nil end
    local ok, decoded = pcall(function()
        return JSON:decode(encoded)
    end)
    if ok and type(decoded) == "table" then return decoded end
    return nil
end

local function decode_message(message, schema)
    local function decode_object(object)
        if not object then return nil end
        local ok, encoded = pcall(protobuf.decodeToJSONfromObject, object)
        if ok then
            return decode_json(encoded)
        end
        return nil
    end

    local decoded = decode_object(message.msg_object)
        or decode_object(message.message_object)
        or decode_object(message.object)
    if decoded then
        return decoded
    end

    if protobuf.decodeToJSON then
        local function decode_buffer(buffer)
            if not buffer or not message.size then return nil end
            local ok, encoded = pcall(protobuf.decodeToJSON, schema, buffer, message.size)
            if ok then
                return decode_json(encoded)
            end
            return nil
        end

        decoded = decode_buffer(message.buffer)
            or decode_buffer(message.binary_buffer_send)
            or decode_buffer(message.binary_buffer)
        if decoded then
            return decoded
        end
    end

    write_log(("could not decode %s, id=%s, name=%s"):format(
        schema,
        tostring(message.message_id),
        tostring(message.message_name)
    ))
    return nil
end

local function seconds_word(seconds)
    if not is_russian() then
        return seconds == 1 and "second" or "seconds"
    end
    local last_two = seconds % 100
    if last_two >= 11 and last_two <= 14 then return "секунд" end
    local last = seconds % 10
    if last == 1 then return "секунда" end
    if last >= 2 and last <= 4 then return "секунды" end
    return "секунд"
end

local function build_message(ability_name, owner_name, seconds)
    if is_russian() then
        return ("%s у врага %s на перезарядке: %d %s!"):format(
            ability_name,
            owner_name,
            seconds,
            seconds_word(seconds)
        )
    end
    return ("%s on enemy %s is on cooldown: %d %s!"):format(
        ability_name,
        owner_name,
        seconds,
        seconds_word(seconds)
    )
end

local function escape_command(text)
    return text:gsub("[\r\n]", " "):gsub("\\", "\\\\"):gsub('"', '\\"')
end

local function send_team_message(text)
    if Engine and Engine.ExecuteCommand then
        return pcall(Engine.ExecuteCommand, 'say_team "' .. escape_command(text) .. '"')
    end
    if Chat and Chat.Say then
        local channel = "Team"
        local channels = safe_call(Chat.GetChannels)
        if type(channels) == "table" then
            for _, candidate in pairs(channels) do
                if type(candidate) == "string" and candidate:lower():find("team", 1, true) then
                    channel = candidate
                    break
                end
            end
        end
        return pcall(Chat.Say, channel, text)
    end
    return false
end

local function find_enemy_owner_and_ability(id, item)
    if not Heroes or not Heroes.GetAll then return nil, nil end
    local me = Heroes.GetLocal and safe_call(Heroes.GetLocal)
    local heroes = safe_call(Heroes.GetAll)
    if type(heroes) ~= "table" then return nil, nil end
    for _, hero in pairs(heroes) do
        if hero and (not me or not safe_call(Entity.IsSameTeam, me, hero)) then
            local ability = find_owned_ability(hero, id, item)
            if ability then return hero, ability end
        end
    end
    return nil, nil
end

local function replace_alert(data, item)
    local item_entindex = data.item_entindex or data.itemEntindex
    local ability_entindex = data.ability_entindex or data.abilityEntindex
    local owner_entindex = data.owner_entindex or data.ownerEntindex
    local message_ability_id = data.ability_id or data.abilityId
    local entity_index = item and item_entindex or ability_entindex
    local ability = entity_from_index(entity_index)
    local owner = entity_from_index(owner_entindex)

    if not owner and ability then owner = safe_call(Ability.GetOwner, ability) end
    if not ability and owner then ability = find_owned_ability(owner, message_ability_id, item) end
    if not ability or not owner then
        local fallback_owner, fallback_ability = find_enemy_owner_and_ability(message_ability_id, item)
        owner = owner or fallback_owner
        ability = ability or fallback_ability
    end

    local display_owner = hero_owner(owner)
    if not ability or not display_owner then
        write_log(("ability lookup failed: item=%s entindex=%s owner=%s ability_id=%s"):format(
            tostring(item),
            tostring(entity_index),
            tostring(owner_entindex),
            tostring(message_ability_id)
        ))
        return true
    end

    local me = Heroes and Heroes.GetLocal and safe_call(Heroes.GetLocal)
    if me and safe_call(Entity.IsSameTeam, me, display_owner) then return true end

    local cooldown = tonumber(safe_call(Ability.GetCooldown, ability))
    if not cooldown or cooldown <= 0.05 then
        write_log(("cooldown unavailable: %s value=%s"):format(
            tostring(safe_call(Ability.GetName, ability)),
            tostring(cooldown)
        ))
        return true
    end

    local ability_name = localized_ability_name(ability, item)
    local owner_name = localized_owner_name(display_owner)
    if ability_name == "" or owner_name == "" then return true end

    local seconds = math.max(1, math.ceil(cooldown - 0.001))
    local key = table.concat({
        tostring(safe_call(Entity.GetIndex, ability) or entity_index or message_ability_id or ""),
        tostring(safe_call(Entity.GetIndex, display_owner) or owner_entindex or ""),
        tostring(seconds),
    }, ":")
    local now = clock()

    if last_message.key == key and now - last_message.time < 0.65 then return false end

    local text = build_message(ability_name, owner_name, seconds)
    if not send_team_message(text) then
        write_log("team chat send failed")
        return true
    end

    last_message.key = key
    last_message.time = now
    write_log("replaced alert: " .. text)
    return false
end

function App.OnSendNetMessage(message)
    if not UI.enabled:Get() or not message then return true end

    local raw_id = tonumber(message.message_id)
    local id = raw_id and raw_id % 2147483648 or nil
    local name = tostring(message.message_name or "")
    local normalized_name = name:lower()
    local ability_alert = id == 805
        or id == 806
        or normalized_name:find("abilityalert", 1, true) ~= nil
    local item_alert = id == 330
        or normalized_name:find("enemyitemalert", 1, true) ~= nil

    if id and ((id >= 800 and id <= 810) or id == 330) then
        write_log(("outgoing id=%s normalized=%s name=%s"):format(
            tostring(raw_id),
            tostring(id),
            name
        ))
    end

    if ability_alert and UI.abilities:Get() then
        local data = decode_message(message, "CDOTAClientMsg_AbilityAlert")
        if data then return replace_alert(data, false) end
    elseif item_alert and UI.items:Get() then
        local data = decode_message(message, "CDOTAClientMsg_EnemyItemAlert")
        if data then return replace_alert(data, true) end
    end

    return true
end

function App.OnGameEnd()
    last_message.key = ""
    last_message.time = -100
end

return App
