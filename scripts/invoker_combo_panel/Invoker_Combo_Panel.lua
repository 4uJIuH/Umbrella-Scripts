local InvokerComboPanel = {}

local tab = Menu.Create("Heroes", "Hero List", "Invoker")
local group = tab:Create("Invoker Combo Panel")
local main = group:Create("Main")
local draw = group:Create("Draw")
local switchSlots = group:Create("Switch Slot")
local debugMenu = group:Create("Debug")

local function SecondsFormatter(v)
    return tostring(v) .. "s"
end

local ui = {
    enabled = main:Switch("Enable Invoker Combo Panel", true),
    comboKey = main:Bind("Hold Combo Key", Enum.ButtonCode.KEY_NONE),
    comboMode = main:Combo("Combo Key Mode", { "Hold", "Tap Step" }, 0),
    saveDefaultButton = main:Button("Save Combos As Default", function()
        if SaveCurrentCombosAsDefaults then
            SaveCurrentCombosAsDefaults()
        end
    end),
    tapReset = main:Slider("Tap Step Reset After", 1, 8, 4, SecondsFormatter),
    targetRadius = main:Slider("Cursor Target Radius", 150, 1200, 600, function(v) return tostring(v) end),
    chaseTarget = main:Switch("Move To Target When Out Of Range", true),
    showPanel = draw:Switch("Show Combo Panel", true),
    drawTarget = draw:Switch("Draw Target Lock", true),
    debugEnabled = debugMenu:Switch("Enable Timing Debugger", false),
    debugWriteFile = debugMenu:Switch("Write Debug File", true),
    debugOverlay = debugMenu:Switch("Show Debug Status", true),
    debugModifiers = debugMenu:Switch("Log Target Modifiers", true),
    debugVitals = debugMenu:Switch("Log HP/Mana Deltas", true),
    debugSample = debugMenu:Slider("Sample Interval", 1, 6, 1, SecondsFormatter),
    debugMarkerKey = debugMenu:Bind("Add Debug Marker", Enum.ButtonCode.KEY_NONE),
    debugClearKey = debugMenu:Bind("Clear Debug Log", Enum.ButtonCode.KEY_NONE),
    resetSlotKey = switchSlots:Bind("Slot #D", Enum.ButtonCode.KEY_NONE),
    slotKeys = {
        switchSlots:Bind("Slot #1", Enum.ButtonCode.KEY_NONE),
        switchSlots:Bind("Slot #2", Enum.ButtonCode.KEY_NONE),
        switchSlots:Bind("Slot #3", Enum.ButtonCode.KEY_NONE),
        switchSlots:Bind("Slot #4", Enum.ButtonCode.KEY_NONE),
        switchSlots:Bind("Slot #5", Enum.ButtonCode.KEY_NONE),
    },
}

local DB_KEY = "invoker_combo_panel"

local function InitPersistentDB()
    if not db then db = {} end
    if type(db["x"]) ~= "userdata" then
        db["x"] = {}
    end
    if type(db["x"][DB_KEY]) ~= "userdata" then
        db["x"][DB_KEY] = {}
    end
    return db["x"][DB_KEY]
end

local saved = InitPersistentDB()
if type(db.invoker_combo_panel) == "table" then
    for key, value in pairs(db.invoker_combo_panel) do
        if saved[key] == nil then
            saved[key] = value
        end
    end
end

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local SPELL_FACE_DOT = 0.985
local SPELL_FACE_REISSUE_DELAY = 0.05
local ICE_WALL_SPAWN_DISTANCE = 200
local ICE_WALL_HALF_LENGTH = 600
local ICE_WALL_RADIUS = 105
local ICE_WALL_REACH = math_sqrt((ICE_WALL_SPAWN_DISTANCE * ICE_WALL_SPAWN_DISTANCE) + (ICE_WALL_HALF_LENGTH * ICE_WALL_HALF_LENGTH)) + ICE_WALL_RADIUS
local SUN_STRIKE_IMPACT_DELAY = 1.7
local SUN_STRIKE_BLAST_BUFFER = 0.15
local TORNADO_LIFT_BY_QUAS_LEVEL = { 0.8, 1.1, 1.4, 1.7, 2.0, 2.3, 2.6 }
local TORNADO_MODIFIER_NAMES = {
    "modifier_invoker_tornado",
}
local CYCLONE_MODIFIER_NAMES = {
    "modifier_eul_cyclone",
    "modifier_item_cyclone",
    "modifier_item_wind_waker",
    "modifier_wind_waker",
    "modifier_brewmaster_storm_cyclone",
    "modifier_earthspirit_petrify",
    "modifier_earth_spirit_petrify",
    "modifier_meepo_petrify",
    "modifier_outworld_destroyer_astral_imprisonment_prison",
    "modifier_obsidian_destroyer_astral_imprisonment_prison",
    "modifier_outworld_destroyer_astral_imprisonment",
    "modifier_obsidian_destroyer_astral_imprisonment",
    "modifier_puck_phase_shift",
    "modifier_rubick_telekinesis",
    "modifier_shadow_demon_disruption",
}
local DEFAULT_CYCLONE_DURATION = 2.5

local function Clamp(v, lo, hi)
    return math_max(lo, math_min(hi, v))
end

local MAX_COMBO_ABILITIES = 10

local abilityDefs = {
    cold_snap = {
        label = "Cold Snap", short = "Cold",
        icon = "panorama/images/spellicons/invoker_cold_snap_png.vtex_c",
        kind = "target", recipe = { "q", "q", "q" }, range = 1000, delay = 0.12,
    },
    ghost_walk = {
        label = "Ghost Walk", short = "Ghost",
        icon = "panorama/images/spellicons/invoker_ghost_walk_png.vtex_c",
        kind = "no_target", recipe = { "q", "q", "w" }, delay = 0.18,
    },
    ice_wall = {
        label = "Ice Wall", short = "Wall",
        icon = "panorama/images/spellicons/invoker_ice_wall_png.vtex_c",
        kind = "no_target", recipe = { "q", "q", "e" }, range = ICE_WALL_REACH, delay = 0.14, face = true,
    },
    emp = {
        label = "EMP", short = "EMP",
        icon = "panorama/images/spellicons/invoker_emp_png.vtex_c",
        kind = "position", recipe = { "w", "w", "w" }, range = 950, delay = 0.12, timing = "after_tornado_drop",
    },
    tornado = {
        label = "Tornado", short = "Tornado",
        icon = "panorama/images/spellicons/invoker_tornado_png.vtex_c",
        kind = "position", recipe = { "q", "w", "w" }, range = 2000, delay = 0.12, record = "tornado",
    },
    alacrity = {
        label = "Alacrity", short = "Alac",
        icon = "panorama/images/spellicons/invoker_alacrity_png.vtex_c",
        kind = "self", recipe = { "w", "w", "e" }, range = 650, delay = 0.12,
    },
    sun_strike = {
        label = "Sun Strike", short = "Sun",
        icon = "panorama/images/spellicons/invoker_sun_strike_png.vtex_c",
        kind = "position", recipe = { "e", "e", "e" }, range = 25000, delay = 0.12, timing = "after_tornado_drop",
    },
    cataclysm = {
        label = "Cataclysm", short = "Cata",
        icon = "panorama/images/spellicons/invoker_sun_strike_magus_apex_png.vtex_c",
        icons = {
            "panorama/images/spellicons/invoker_sun_strike_magus_apex_png.vtex_c",
            "panorama/images/spellicons/invoker_sun_strike_dark_artistry_png.vtex_c",
            "panorama/images/spellicons/invoker_sun_strike_ad_png.vtex_c",
            "panorama/images/spellicons/invoker_sun_strike_png.vtex_c",
        },
        kind = "self", recipe = { "e", "e", "e" }, range = 25000, delay = 0.12, timing = "after_tornado_drop", requiresScepter = true,
    },
    forge_spirit = {
        label = "Forge Spirit", short = "Forge",
        icon = "panorama/images/spellicons/invoker_forge_spirit_png.vtex_c",
        kind = "no_target", recipe = { "q", "e", "e" }, delay = 0.20,
    },
    chaos_meteor = {
        label = "Chaos Meteor", short = "Meteor",
        icon = "panorama/images/spellicons/invoker_chaos_meteor_png.vtex_c",
        kind = "position", recipe = { "w", "e", "e" }, range = 700, delay = 0.12, timing = "after_tornado_drop",
    },
    deafening_blast = {
        label = "Deafening Blast", short = "Blast",
        icon = "panorama/images/spellicons/invoker_deafening_blast_png.vtex_c",
        kind = "position", recipe = { "q", "w", "e" }, range = 1000, delay = 0.12, face = true, timing = "after_tornado_drop",
    },
}

local itemDefs = {
    meteor_hammer = {
        label = "Meteor Hammer", short = "M.Hammer",
        icon = "panorama/images/items/meteor_hammer_png.vtex_c",
        item = "item_meteor_hammer", kind = "position", delay = 0.12, timing = "after_tornado_drop", lock = 2.55,
    },
    blink = {
        label = "Blink Dagger", short = "Blink",
        icon = "panorama/images/items/blink_png.vtex_c",
        item = "item_blink", kind = "position", delay = 0.08,
        aliases = { "item_blink", "item_swift_blink", "item_arcane_blink", "item_overwhelming_blink" },
    },
    bkb = {
        label = "Black King Bar", short = "BKB",
        icon = "panorama/images/items/black_king_bar_png.vtex_c",
        item = "item_black_king_bar", kind = "no_target", delay = 0.08,
    },
    refresher = {
        label = "Refresher Orb", short = "Refresh",
        icon = "panorama/images/items/refresher_png.vtex_c",
        item = "item_refresher", kind = "no_target", delay = 0.08,
    },
    rod_of_atos = {
        label = "Rod of Atos", short = "Atos",
        icon = "panorama/images/items/rod_of_atos_png.vtex_c",
        item = "item_rod_of_atos", kind = "target", delay = 0.08, timing = "after_tornado_drop",
    },
    gleipnir = {
        label = "Gleipnir", short = "Gleip",
        icon = "panorama/images/items/gungir_png.vtex_c",
        item = "item_gungir", kind = "position", delay = 0.08, timing = "after_tornado_drop", aimTarget = true,
        aliases = { "item_gungir", "item_gleipnir" },
    },
    shadow_blade = {
        label = "Shadow Blade", short = "Shadow",
        icon = "panorama/images/items/invis_sword_png.vtex_c",
        item = "item_invis_sword", kind = "no_target", delay = 0.08,
    },
    silver_edge = {
        label = "Silver Edge", short = "Silver",
        icon = "panorama/images/items/silver_edge_png.vtex_c",
        item = "item_silver_edge", kind = "no_target", delay = 0.08,
    },
    manta = {
        label = "Manta Style", short = "Manta",
        icon = "panorama/images/items/manta_png.vtex_c",
        item = "item_manta", kind = "no_target", delay = 0.08,
    },
    satanic = {
        label = "Satanic", short = "Satanic",
        icon = "panorama/images/items/satanic_png.vtex_c",
        item = "item_satanic", kind = "no_target", delay = 0.08,
    },
    bloodthorn = {
        label = "Bloodthorn", short = "Blood",
        icon = "panorama/images/items/bloodthorn_png.vtex_c",
        item = "item_bloodthorn", kind = "target", delay = 0.08,
    },
    orchid = {
        label = "Orchid", short = "Orchid",
        icon = "panorama/images/items/orchid_png.vtex_c",
        item = "item_orchid", kind = "target", delay = 0.08,
    },
    sheepstick = {
        label = "Scythe of Vyse", short = "Hex",
        icon = "panorama/images/items/sheepstick_png.vtex_c",
        item = "item_sheepstick", kind = "target", delay = 0.08,
    },
    nullifier = {
        label = "Nullifier", short = "Null",
        icon = "panorama/images/items/nullifier_png.vtex_c",
        item = "item_nullifier", kind = "target", delay = 0.08,
    },
    ethereal = {
        label = "Ethereal Blade", short = "Eblade",
        icon = "panorama/images/items/ethereal_blade_png.vtex_c",
        item = "item_ethereal_blade", kind = "target", delay = 0.08,
    },
    abyssal = {
        label = "Abyssal Blade", short = "Abyssal",
        icon = "panorama/images/items/abyssal_blade_png.vtex_c",
        item = "item_abyssal_blade", kind = "target", delay = 0.08,
    },
    shivas = {
        label = "Shiva's Guard", short = "Shiva",
        icon = "panorama/images/items/shivas_guard_png.vtex_c",
        item = "item_shivas_guard", kind = "no_target", delay = 0.08,
    },
    cyclone = {
        label = "Eul's Scepter", short = "Eul",
        icon = "panorama/images/items/cyclone_png.vtex_c",
        item = "item_cyclone", kind = "target", delay = 0.08, record = "cyclone",
    },
}

local abilityOrder = { "cold_snap", "ghost_walk", "ice_wall", "emp", "tornado", "alacrity", "sun_strike", "cataclysm", "forge_spirit", "chaos_meteor", "deafening_blast" }
local itemOrder = { "meteor_hammer", "rod_of_atos", "gleipnir", "blink", "bkb", "refresher", "sheepstick", "orchid", "bloodthorn", "nullifier", "ethereal", "shivas", "cyclone", "shadow_blade", "silver_edge", "manta", "satanic", "abyssal" }
local SAVE_PATH = "C:\\umbrella\\scripts\\invoker_combo_panel_slots.json"
local DEBUG_LOG_PATH = "C:\\umbrella\\scripts\\invoker_combo_debug.log"
local DEBUG_LATEST_PATH = "C:\\Users\\ChopPY's\\Documents\\New project\\invoker_combo_debug_latest.log"
local stanceChoices = {
    { key = "keep", label = "Keep", short = "-" },
    { key = "q", label = "Quas", short = "Q" },
    { key = "w", label = "Wex", short = "W" },
    { key = "e", label = "Exort", short = "E" },
}
local validEndStances = { keep = true, q = true, w = true, e = true }

local defaultCombos = {
    [0] = { name = "Sun Strike", keys = { "sun_strike" } },
    { name = "Sun Cata Meteor", keys = { "sun_strike", "cataclysm", "chaos_meteor", "deafening_blast" } },
    { name = "Meteor Blast", keys = { "chaos_meteor", "deafening_blast" } },
    { name = "Wall Snap Alac", keys = { "ice_wall", "cold_snap", "alacrity" } },
    { name = "Refresh Cata", keys = { "sun_strike", "cataclysm", "chaos_meteor", "emp", "deafening_blast", "refresher", "sun_strike", "cataclysm", "chaos_meteor", "deafening_blast" } },
    { name = "Full Chain", keys = { "ice_wall", "emp", "sun_strike", "cataclysm", "chaos_meteor", "deafening_blast", "cold_snap", "forge_spirit", "alacrity" } },
}

local combos = {}
local comboSlots = {}
local disabledItems = {}
local endStances = {}
local SavePersistentState = nil

local function SerializeLuaValue(value)
    local valueType = type(value)
    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end
    if valueType == "string" then
        return string.format("%q", value)
    end
    if valueType ~= "table" then
        return "nil"
    end

    local parts = { "{" }
    for key, child in pairs(value) do
        local keyText
        if type(key) == "number" then
            keyText = "[" .. tostring(key) .. "]"
        else
            keyText = "[" .. string.format("%q", tostring(key)) .. "]"
        end
        parts[#parts + 1] = keyText .. "=" .. SerializeLuaValue(child) .. ","
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end

local function DecodeLuaTable(content)
    if type(content) ~= "string" or content:match("^%s*$") then return nil end

    local loader = load or loadstring
    if not loader then return nil end

    local chunkText = content:match("^%s*return%s+") and content or ("return " .. content)
    local okLoad, chunk = pcall(loader, chunkText)
    if not okLoad or type(chunk) ~= "function" then return nil end

    local okRun, data = pcall(chunk)
    if okRun and type(data) == "table" then
        return data
    end

    return nil
end

local function LoadPersistentState()
    if not io or not io.open then return {} end

    local file = io.open(SAVE_PATH, "r")
    if not file then return {} end

    local content = file:read("*all")
    file:close()
    if not content or content:match("^%s*$") then return {} end

    local luaData = DecodeLuaTable(content)
    if type(luaData) == "table" then
        return luaData
    end

    local okJson, JSON = pcall(require, "assets.JSON")
    if okJson and JSON then
        local ok, data = pcall(JSON.decode, JSON, content)
        if ok and type(data) == "table" then
            return data
        end
        ok, data = pcall(JSON.decode, content)
        if ok and type(data) == "table" then
            return data
        end
    end

    return {}
end

local function HasComboSlots(slots)
    if type(slots) ~= "table" then return false end
    for i = 1, #defaultCombos do
        local keys = slots[i] or slots[tostring(i)]
        if type(keys) == "table" and #keys > 0 then
            return true
        end
    end
    return false
end

local persisted = LoadPersistentState()
local loadedComboSlotsFromFile = false
if HasComboSlots(persisted.defaultComboSlots) then
    saved.defaultComboSlots = persisted.defaultComboSlots
    saved.defaultDisabledItems = persisted.defaultDisabledItems
    saved.defaultEndStances = persisted.defaultEndStances
    saved.comboSlots = persisted.defaultComboSlots
    saved.disabledItems = persisted.defaultDisabledItems
    saved.endStances = persisted.defaultEndStances
    loadedComboSlotsFromFile = true
elseif HasComboSlots(persisted.comboSlots) then
    saved.comboSlots = persisted.comboSlots
    loadedComboSlotsFromFile = true
end
if not loadedComboSlotsFromFile then
    saved.comboSlots = nil
    saved.disabledItems = nil
    saved.endStances = nil
    saved.defaultComboSlots = nil
    saved.defaultDisabledItems = nil
    saved.defaultEndStances = nil
end
if type(saved.selected) ~= "number" and type(persisted.selected) == "number" then
    saved.selected = persisted.selected
end
if type(saved.endStances) ~= "table" and type(persisted.endStances) == "table" then
    saved.endStances = persisted.endStances
end
if type(saved.disabledItems) ~= "table" and type(persisted.disabledItems) == "table" then
    saved.disabledItems = persisted.disabledItems
end
if type(persisted.panel) == "table" then
    if type(persisted.panel.x) == "number" then saved.x = persisted.panel.x end
    if type(persisted.panel.y) == "number" then saved.y = persisted.panel.y end
end
if type(persisted.builder) == "table" then
    if type(persisted.builder.open) == "boolean" then saved.builderOpen = persisted.builder.open end
    if type(persisted.builder.x) == "number" then saved.builderX = persisted.builder.x end
    if type(persisted.builder.y) == "number" then saved.builderY = persisted.builder.y end
end

local function CopyKeys(keys)
    local copy = {}
    if not keys then return copy end
    for _, key in ipairs(keys) do
        copy[#copy + 1] = key
    end
    return copy
end

local function NormalizeAbilityKeys(keys, fallback)
    local result = {}
    if type(keys) == "table" then
        for _, key in ipairs(keys) do
            if (abilityDefs[key] or itemDefs[key]) and #result < MAX_COMBO_ABILITIES then
                result[#result + 1] = key
            end
        end
    end
    if #result == 0 then
        result = CopyKeys(fallback)
    end
    return result
end

local function NormalizeEndStance(value)
    if validEndStances[value] then
        return value
    end
    return "keep"
end

local function NormalizeDisabledItems(values, keys)
    local result = {}
    if type(values) ~= "table" then return result end

    for i = 1, MAX_COMBO_ABILITIES do
        local key = keys and keys[i]
        if (abilityDefs[key] or itemDefs[key]) and (values[i] == true or values[tostring(i)] == true) then
            result[i] = true
        end
    end

    return result
end

function SavedDefaultKeys(index, fallback)
    local slots = saved.defaultComboSlots
    local keys = type(slots) == "table" and (slots[index] or slots[tostring(index)]) or nil
    return NormalizeAbilityKeys(keys, fallback)
end

function SavedDefaultDisabled(index, keys)
    local values = saved.defaultDisabledItems
    local disabled = type(values) == "table" and (values[index] or values[tostring(index)]) or nil
    return NormalizeDisabledItems(disabled, keys)
end

function SavedDefaultEndStance(index)
    local values = saved.defaultEndStances
    local stance = type(values) == "table" and (values[index] or values[tostring(index)]) or nil
    return NormalizeEndStance(stance)
end

local function IsDisabledItem(comboIndex, slotIndex)
    local key = comboSlots[comboIndex] and comboSlots[comboIndex][slotIndex]
    return (abilityDefs[key] ~= nil or itemDefs[key] ~= nil)
        and disabledItems[comboIndex] ~= nil
        and disabledItems[comboIndex][slotIndex] == true
end

local function BuildShortText(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        local def = abilityDefs[key] or itemDefs[key]
        if def then parts[#parts + 1] = def.short end
    end
    if #parts == 0 then return "Attack only" end
    return table.concat(parts, " > ")
end

local function StepFromAbilityKey(key)
    local def = abilityDefs[key]
    if def then
        return {
            source = "ability",
            kind = def.kind,
            ability = key,
            stance = def.stance,
            range = def.range,
            delay = def.delay,
            record = def.record,
            face = def.face,
            timing = def.timing,
            lock = def.lock,
            requiresScepter = def.requiresScepter,
        }
    end

    def = itemDefs[key]
    if not def then return nil end

    return {
        source = "item",
        kind = def.kind,
        item = key,
        range = def.range,
        delay = def.delay,
        record = def.record,
        timing = def.timing,
        lock = def.lock,
        aimTarget = def.aimTarget,
    }
end

local function RebuildCombo(index)
    local combo = combos[index]
    local keys = comboSlots[index] or {}
    if not combo then return end

    combo.steps = {}
    for stepIndex, key in ipairs(keys) do
        local step = StepFromAbilityKey(key)
        if step then
            step.slotIndex = stepIndex
            step.disabled = IsDisabledItem(index, stepIndex)
            combo.steps[#combo.steps + 1] = step
        end
    end
    combo.steps[#combo.steps + 1] = { kind = "attack", delay = 0.22 }
    combo.short = BuildShortText(keys)
end

local function SaveComboSlot(index)
    saved.comboSlots = saved.comboSlots or {}
    saved.comboSlots[index] = CopyKeys(comboSlots[index])
    if SavePersistentState then
        SavePersistentState()
    end
end

local function ResetComboSlot(index)
    comboSlots[index] = SavedDefaultKeys(index, defaultCombos[index].keys)
    disabledItems[index] = SavedDefaultDisabled(index, comboSlots[index])
    endStances[index] = SavedDefaultEndStance(index)
    SaveComboSlot(index)
    RebuildCombo(index)
end

local function ToggleDisabledItem(index, slotIndex)
    local key = comboSlots[index] and comboSlots[index][slotIndex]
    if not abilityDefs[key] and not itemDefs[key] then return end

    disabledItems[index] = disabledItems[index] or {}
    disabledItems[index][slotIndex] = not disabledItems[index][slotIndex]
    if disabledItems[index][slotIndex] == false then
        disabledItems[index][slotIndex] = nil
    end
    RebuildCombo(index)
    if SavePersistentState then
        SavePersistentState()
    end
end

local function SetEndStance(index, stance)
    endStances[index] = NormalizeEndStance(stance)
    if SavePersistentState then
        SavePersistentState()
    end
end

for i, def in ipairs(defaultCombos) do
    local savedSlots = saved.comboSlots or {}
    local savedKeys = savedSlots[i] or savedSlots[tostring(i)]
    comboSlots[i] = NormalizeAbilityKeys(savedKeys, def.keys)
    local savedDisabledItems = saved.disabledItems or {}
    disabledItems[i] = NormalizeDisabledItems(savedDisabledItems[i] or savedDisabledItems[tostring(i)], comboSlots[i])
    local savedEndStances = saved.endStances or {}
    endStances[i] = NormalizeEndStance(savedEndStances[i] or savedEndStances[tostring(i)])
    combos[i] = { name = def.name, short = "", steps = {} }
    RebuildCombo(i)
end
if defaultCombos[0] then
    comboSlots[0] = NormalizeAbilityKeys(saved.comboSlots and (saved.comboSlots[0] or saved.comboSlots["0"]), defaultCombos[0].keys)
    disabledItems[0] = NormalizeDisabledItems(saved.disabledItems and (saved.disabledItems[0] or saved.disabledItems["0"]), comboSlots[0])
    endStances[0] = NormalizeEndStance(saved.endStances and (saved.endStances[0] or saved.endStances["0"]))
    combos[0] = { name = defaultCombos[0].name, short = "", steps = {} }
    RebuildCombo(0)
end

local abilityNames = {
    q = { "invoker_quas" },
    w = { "invoker_wex" },
    e = { "invoker_exort" },
    invoke = { "invoker_invoke" },
    cold_snap = { "invoker_cold_snap" },
    ghost_walk = { "invoker_ghost_walk" },
    ice_wall = { "invoker_ice_wall" },
    emp = { "invoker_emp" },
    tornado = { "invoker_tornado" },
    alacrity = { "invoker_alacrity" },
    sun_strike = { "invoker_sun_strike" },
    cataclysm = { "invoker_sun_strike" },
    forge_spirit = { "invoker_forge_spirit" },
    chaos_meteor = { "invoker_chaos_meteor" },
    deafening_blast = { "invoker_deafening_blast" },
}

local panel = {
    x = type(saved.x) == "number" and saved.x or 520,
    y = type(saved.y) == "number" and saved.y or 360,
    w = 276,
    h = 0,
    dragging = false,
    dx = 0,
    dy = 0,
    hovered = false,
    clickEaten = false,
}

local selectedCombo = type(saved.selected) == "number" and Clamp(math_floor(saved.selected), 0, #combos) or 1
local builder = {
    open = saved.builderOpen == true,
    x = type(saved.builderX) == "number" and saved.builderX or (panel.x + 246),
    y = type(saved.builderY) == "number" and saved.builderY or panel.y,
    w = 286,
    h = 410,
    dragging = false,
    dx = 0,
    dy = 0,
    hovered = false,
    clickEaten = false,
    slot = selectedCombo,
    savedAt = 0,
}

SavePersistentState = function(saveAsDefault)
    local data = {
        version = 1,
        selected = selectedCombo,
        comboSlots = {},
        disabledItems = {},
        endStances = {},
        panel = {
            x = saved.x or panel.x,
            y = saved.y or panel.y,
        },
        builder = {
            open = saved.builderOpen == true,
            x = saved.builderX or builder.x,
            y = saved.builderY or builder.y,
        },
    }

    if combos[0] then
        data.comboSlots[0] = CopyKeys(comboSlots[0])
        data.disabledItems[0] = {}
        for slotIndex = 1, MAX_COMBO_ABILITIES do
            if IsDisabledItem(0, slotIndex) then
                data.disabledItems[0][slotIndex] = true
            end
        end
        data.endStances[0] = NormalizeEndStance(endStances[0])
    end

    for i = 1, #combos do
        data.comboSlots[i] = CopyKeys(comboSlots[i])
        data.disabledItems[i] = {}
        for slotIndex = 1, MAX_COMBO_ABILITIES do
            if IsDisabledItem(i, slotIndex) then
                data.disabledItems[i][slotIndex] = true
            end
        end
        data.endStances[i] = NormalizeEndStance(endStances[i])
    end

    if saveAsDefault == true then
        saved.defaultComboSlots = {}
        saved.defaultDisabledItems = {}
        saved.defaultEndStances = {}
        if combos[0] then
            saved.defaultComboSlots[0] = CopyKeys(comboSlots[0])
            saved.defaultDisabledItems[0] = {}
            for slotIndex = 1, MAX_COMBO_ABILITIES do
                if IsDisabledItem(0, slotIndex) then
                    saved.defaultDisabledItems[0][slotIndex] = true
                end
            end
            saved.defaultEndStances[0] = NormalizeEndStance(endStances[0])
        end
        for i = 1, #combos do
            saved.defaultComboSlots[i] = CopyKeys(comboSlots[i])
            saved.defaultDisabledItems[i] = {}
            for slotIndex = 1, MAX_COMBO_ABILITIES do
                if IsDisabledItem(i, slotIndex) then
                    saved.defaultDisabledItems[i][slotIndex] = true
                end
            end
            saved.defaultEndStances[i] = NormalizeEndStance(endStances[i])
        end
    end

    if HasComboSlots(saved.defaultComboSlots) then
        data.defaultComboSlots = {}
        data.defaultDisabledItems = {}
        data.defaultEndStances = {}
        if defaultCombos[0] then
            data.defaultComboSlots[0] = NormalizeAbilityKeys(saved.defaultComboSlots and (saved.defaultComboSlots[0] or saved.defaultComboSlots["0"]), defaultCombos[0].keys)
            data.defaultDisabledItems[0] = NormalizeDisabledItems(saved.defaultDisabledItems and (saved.defaultDisabledItems[0] or saved.defaultDisabledItems["0"]), data.defaultComboSlots[0])
            data.defaultEndStances[0] = SavedDefaultEndStance(0)
        end
        for i = 1, #combos do
            local defaultKeys = saved.defaultComboSlots[i] or saved.defaultComboSlots[tostring(i)]
            data.defaultComboSlots[i] = NormalizeAbilityKeys(defaultKeys, defaultCombos[i].keys)
            data.defaultDisabledItems[i] = NormalizeDisabledItems(saved.defaultDisabledItems and (saved.defaultDisabledItems[i] or saved.defaultDisabledItems[tostring(i)]), data.defaultComboSlots[i])
            data.defaultEndStances[i] = SavedDefaultEndStance(i)
        end
    end

    saved.selected = data.selected
    saved.comboSlots = data.comboSlots
    saved.disabledItems = data.disabledItems
    saved.endStances = data.endStances
    saved.x = data.panel.x
    saved.y = data.panel.y
    saved.builderOpen = data.builder.open
    saved.builderX = data.builder.x
    saved.builderY = data.builder.y

    if not io or not io.open then return end

    local encoded = "return " .. SerializeLuaValue(data)

    local file = io.open(SAVE_PATH, "w")
    if not file then return end
    file:write(encoded)
    file:close()
end

function SaveCurrentCombosAsDefaults()
    if SavePersistentState then
        SavePersistentState(true)
    end
    if combos[0] then
        RebuildCombo(0)
    end
    for i = 1, #combos do
        RebuildCombo(i)
    end
    builder.savedAt = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
end

local hero = nil
local player = nil
local target = nil
local comboState = 0
local activeCombo = 0
local comboWasHeld = false
local holdComboComplete = false
local tapLastStepTime = 0
local tapPending = false
local tapPendingUntil = 0
local pendingEndStance = nil
local pendingEndStanceUntil = 0
local pendingEndStanceCasts = 0
local lastAction = 0
local lastInvokeAction = 0
local lastEchoFaceOrder = 0
local comboLockUntil = 0
local comboLockAbility = nil
local invokeState = {
    key = nil,
    recipe = nil,
    index = 0,
    invokedAt = 0,
}
local spellState = {}
local debugState = {
    enabled = false,
    lastSample = 0,
    lastLine = "",
    lastTargetIndex = -1,
    lastHp = nil,
    lastMana = nil,
    lastEvents = {},
    particles = {},
    lineCount = 0,
}
local targetParticle = nil
local targetParticleIndex = -1
local slotDrag = {
    active = false,
    source = nil,
    comboIndex = 0,
    fromIndex = 0,
    moved = false,
    startX = 0,
    startY = 0,
    key = nil,
}

local fonts = {
    main = nil,
    small = nil,
    icon = nil,
    abilityIcons = {},
}

local function EnsureFonts()
    if not fonts.main or fonts.main == 0 then
        fonts.main = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
    end
    if not fonts.small or fonts.small == 0 then
        fonts.small = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
    end
    if not fonts.icon or fonts.icon == 0 then
        fonts.icon = Render.LoadImage("panorama/images/heroes/icons/npc_dota_hero_invoker_png.vtex_c")
    end
end

local function GetAbilityIcon(key)
    local def = abilityDefs[key] or itemDefs[key]
    if not def then return nil end
    if not fonts.abilityIcons[key] or fonts.abilityIcons[key] == 0 then
        if type(def.icons) == "table" then
            for _, iconPath in ipairs(def.icons) do
                local image = Render.LoadImage(iconPath)
                if image and image ~= 0 then
                    fonts.abilityIcons[key] = image
                    return fonts.abilityIcons[key]
                end
            end
        end
        fonts.abilityIcons[key] = Render.LoadImage(def.icon)
    end
    return fonts.abilityIcons[key]
end

local function SafeCall(fn, ...)
    if not fn then return false, nil end
    return pcall(fn, ...)
end

local MoveTo

local function IsInvokerPicked(unit)
    if not unit or not NPC or not NPC.GetUnitName then return false end
    local ok, name = SafeCall(NPC.GetUnitName, unit)
    return ok and name == "npc_dota_hero_invoker"
end

local function IsLocalInvokerPicked()
    if not Heroes or not Heroes.GetLocal then return false end
    return IsInvokerPicked(Heroes.GetLocal())
end

local function IsInvoker(unit)
    return unit and Entity.IsAlive(unit) and IsInvokerPicked(unit)
end

local function Dist2D(a, b)
    if not a or not b then return 999999 end
    return (a - b):Length2D()
end

function DebugEnabled()
    return ui.debugEnabled and ui.debugEnabled:Get() == true
end

function DebugFileEnabled()
    return ui.debugWriteFile and ui.debugWriteFile:Get() == true
end

function DebugNumber(value)
    if type(value) ~= "number" then return tostring(value) end
    return string.format("%.3f", value)
end

function DebugPositionText(pos)
    if not pos then return "nil" end
    return string.format("%.0f,%.0f,%.0f", pos.x or 0, pos.y or 0, pos.z or 0)
end

function DebugUnitName(unit)
    if not unit then return "nil" end

    local name = nil
    if NPC and NPC.GetUnitName then
        local ok, value = SafeCall(NPC.GetUnitName, unit)
        if ok then name = value end
    end

    local index = "?"
    if Entity and Entity.GetIndex then
        local okIndex, value = SafeCall(Entity.GetIndex, unit)
        if okIndex and value ~= nil then index = tostring(value) end
    end

    return tostring(name or unit) .. "#" .. index
end

function DebugStepName(step)
    if not step then return "nil" end
    if step.kind == "attack" then return "attack" end

    if step.source == "ability" then
        local def = abilityDefs[step.ability]
        return "ability:" .. tostring(step.ability) .. ":" .. tostring(def and def.short or "?")
    end

    if step.source == "item" then
        local def = itemDefs[step.item]
        return "item:" .. tostring(step.item) .. ":" .. tostring(def and def.short or "?")
    end

    return tostring(step.kind or "unknown")
end

function DebugAbilityName(ability)
    if not ability then return "nil" end
    if Ability and Ability.GetName then
        local ok, name = SafeCall(Ability.GetName, ability)
        if ok and name then return tostring(name) end
    end
    return tostring(ability)
end

function DebugFormatFields(fields)
    local parts = {}
    if type(fields) ~= "table" then return "" end

    for key, value in pairs(fields) do
        parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
    end

    if #parts == 0 then return "" end
    return " | " .. table.concat(parts, " | ")
end

function DebugWriteFile(path, mode, text)
    if not path or not io or not io.open then return false end

    local file = io.open(path, mode)
    if not file then return false end
    file:write(text)
    file:close()
    return true
end

function DebugWriteAll(mode, text)
    DebugWriteFile(DEBUG_LOG_PATH, mode, text)
    if DEBUG_LATEST_PATH ~= DEBUG_LOG_PATH then
        DebugWriteFile(DEBUG_LATEST_PATH, mode, text)
    end
end

DebugLogEvent = function(event, fields, throttleKey, throttleSeconds)
    if not DebugEnabled() then return end

    local now = 0
    if GameRules and GameRules.GetGameTime then
        local ok, value = SafeCall(GameRules.GetGameTime)
        if ok and type(value) == "number" then now = value end
    end

    if throttleKey then
        throttleSeconds = throttleSeconds or 0
        local last = debugState.lastEvents[throttleKey]
        if last and now - last < throttleSeconds then return end
        debugState.lastEvents[throttleKey] = now
    end

    fields = fields or {}
    fields.slot = selectedCombo
    fields.combo_state = comboState
    if combos[selectedCombo] then
        fields.combo = combos[selectedCombo].name
    end

    local line = string.format("[%.3f] %s%s", now, tostring(event), DebugFormatFields(fields))
    debugState.lastLine = line
    debugState.lineCount = debugState.lineCount + 1

    if not DebugFileEnabled() or not io or not io.open then return end
    DebugWriteAll("a", line .. "\n")
end

function DebugClearLog(now)
    debugState.lastEvents = {}
    debugState.lineCount = 0
    debugState.lastLine = "debug log cleared"
    debugState.lastSample = 0
    debugState.lastTargetIndex = -1
    debugState.lastHp = nil
    debugState.lastMana = nil
    debugState.particles = {}

    if not DebugFileEnabled() or not io or not io.open then return end
    local stamp = os and os.date and os.date("%Y-%m-%d %H:%M:%S") or "unknown-time"
    local header = table.concat({
        "Invoker Combo Debug Log",
        "created=" .. tostring(stamp),
        "umbrella_path=" .. DEBUG_LOG_PATH,
        "latest_path=" .. DEBUG_LATEST_PATH,
        "game_time=" .. DebugNumber(now or 0),
    }, "\n") .. "\n"
    DebugWriteAll("w", header)
end

function DebugTargetVitals(unit)
    local hp = nil
    local mana = nil

    if unit and Entity and Entity.GetHealth then
        local okHp, value = SafeCall(Entity.GetHealth, unit)
        if okHp then hp = value end
    end

    if unit and NPC and NPC.GetMana then
        local okMana, value = SafeCall(NPC.GetMana, unit)
        if okMana then mana = value end
    end

    return hp, mana
end

function DebugRelevantFxText(text)
    if not text then return false end
    local value = string.lower(tostring(text))

    return string.find(value, "invoker", 1, true) ~= nil
        or string.find(value, "tornado", 1, true) ~= nil
        or string.find(value, "cyclone", 1, true) ~= nil
        or string.find(value, "eul", 1, true) ~= nil
        or string.find(value, "wind_waker", 1, true) ~= nil
        or string.find(value, "disruption", 1, true) ~= nil
        or string.find(value, "astral_imprisonment", 1, true) ~= nil
        or string.find(value, "telekinesis", 1, true) ~= nil
        or string.find(value, "phase_shift", 1, true) ~= nil
        or string.find(value, "brewmaster", 1, true) ~= nil
        or string.find(value, "earthspirit", 1, true) ~= nil
        or string.find(value, "earth_spirit", 1, true) ~= nil
        or string.find(value, "petrify", 1, true) ~= nil
        or string.find(value, "meepo", 1, true) ~= nil
        or string.find(value, "sun_strike", 1, true) ~= nil
        or string.find(value, "sunstrike", 1, true) ~= nil
        or string.find(value, "cataclysm", 1, true) ~= nil
        or string.find(value, "meteor", 1, true) ~= nil
        or string.find(value, "emp", 1, true) ~= nil
        or string.find(value, "ice_wall", 1, true) ~= nil
        or string.find(value, "icewall", 1, true) ~= nil
        or string.find(value, "deafening", 1, true) ~= nil
end

function DebugParticleText(particle)
    if not particle then return "" end
    return tostring(particle.fullName or "") .. " " .. tostring(particle.name or "")
end

local function IsFacingPoint(point)
    if not hero or not point then return true end

    local heroPos = Entity.GetAbsOrigin(hero)
    local delta = point - heroPos
    local len = delta:Length2D()
    if len < 35 then return true end

    local forward = Entity.GetAbsRotation(hero):GetForward()
    local forwardLen = math_sqrt((forward.x * forward.x) + (forward.y * forward.y))
    if forwardLen <= 0 then return true end

    local dot = ((forward.x * delta.x) + (forward.y * delta.y)) / (len * forwardLen)
    return dot >= SPELL_FACE_DOT
end

local function FacePoint(point, now)
    if IsFacingPoint(point) then return true end

    if now - lastEchoFaceOrder >= SPELL_FACE_REISSUE_DELAY then
        MoveTo(point)
        lastEchoFaceOrder = now
    end

    return false
end

local function CurrentForward2D()
    if not hero then return 1, 0 end

    local forward = Entity.GetAbsRotation(hero):GetForward()
    local len = math_sqrt((forward.x * forward.x) + (forward.y * forward.y))
    if len <= 0 then return 1, 0 end

    return forward.x / len, forward.y / len
end

local function AddIceWallForwardCandidate(candidates, fx, fy)
    local len = math_sqrt((fx * fx) + (fy * fy))
    if len <= 0 then return end

    candidates[#candidates + 1] = {
        x = fx / len,
        y = fy / len,
    }
end

local function PickBestIceWallForward(candidates)
    if #candidates == 0 then return nil end

    local curX, curY = CurrentForward2D()
    local best = candidates[1]
    local bestDot = (best.x * curX) + (best.y * curY)

    for i = 2, #candidates do
        local candidate = candidates[i]
        local dot = (candidate.x * curX) + (candidate.y * curY)
        if dot > bestDot then
            best = candidate
            bestDot = dot
        end
    end

    return best
end

local function IceWallFacePoint(aimPos)
    if not hero or not aimPos then return nil end

    local heroPos = Entity.GetAbsOrigin(hero)
    local vx = aimPos.x - heroPos.x
    local vy = aimPos.y - heroPos.y
    local dist = math_sqrt((vx * vx) + (vy * vy))
    if dist < 1 then return nil end

    local ux = vx / dist
    local uy = vy / dist
    local px = -uy
    local py = ux
    local candidates = {}

    if dist > ICE_WALL_SPAWN_DISTANCE then
        local side = math_sqrt(math_max(0, (dist * dist) - (ICE_WALL_SPAWN_DISTANCE * ICE_WALL_SPAWN_DISTANCE)))

        if side <= ICE_WALL_HALF_LENGTH + ICE_WALL_RADIUS then
            local c = ICE_WALL_SPAWN_DISTANCE / dist
            local s = side / dist
            AddIceWallForwardCandidate(candidates, (ux * c) + (px * s), (uy * c) + (py * s))
            AddIceWallForwardCandidate(candidates, (ux * c) - (px * s), (uy * c) - (py * s))
        else
            local edgeDist = math_sqrt((ICE_WALL_SPAWN_DISTANCE * ICE_WALL_SPAWN_DISTANCE) + (ICE_WALL_HALF_LENGTH * ICE_WALL_HALF_LENGTH))
            local c = ICE_WALL_SPAWN_DISTANCE / edgeDist
            local s = ICE_WALL_HALF_LENGTH / edgeDist
            AddIceWallForwardCandidate(candidates, (ux * c) + (px * s), (uy * c) + (py * s))
            AddIceWallForwardCandidate(candidates, (ux * c) - (px * s), (uy * c) - (py * s))
        end
    else
        AddIceWallForwardCandidate(candidates, ux, uy)
    end

    local forward = PickBestIceWallForward(candidates)
    if not forward then return nil end

    return Vector(heroPos.x + (forward.x * 900), heroPos.y + (forward.y * 900), heroPos.z)
end

local function AbilityName(ability)
    if not ability then return nil end
    local ok, name = SafeCall(Ability.GetName, ability)
    if ok then return name end
    return nil
end

local function FindAbilityByName(unit, name)
    if not unit or not name then return nil end

    local ab = NPC.GetAbility(unit, name)
    if ab then return ab end

    if NPC.GetAbilityByIndex then
        for i = 0, 30 do
            local byIndex = NPC.GetAbilityByIndex(unit, i)
            if byIndex and AbilityName(byIndex) == name then
                return byIndex
            end
        end
    end

    return nil
end

local function IsAbilityHidden(ability)
    if not ability then return false end
    if Ability and Ability.IsHidden then
        local ok, value = SafeCall(Ability.IsHidden, ability)
        if ok and value ~= nil then return value == true end
    end

    local ok, value = pcall(function()
        return ability:IsHidden()
    end)
    if ok and value ~= nil then return value == true end

    return false
end

local function AbilityVisible(unit, names)
    for _, name in ipairs(names) do
        local ab = FindAbilityByName(unit, name)
        if ab and not IsAbilityHidden(ab) then
            return true
        end
    end
    return false
end

local function AbilityActivated(ability)
    if not ability then return false end
    if Ability and Ability.IsActivated then
        local ok, value = SafeCall(Ability.IsActivated, ability)
        if ok and value ~= nil then return value == true end
    end

    local ok, value = pcall(function()
        return ability:IsActivated()
    end)
    if ok and value ~= nil then return value == true end

    return not IsAbilityHidden(ability)
end

local function GetInvokedAbility(unit, name)
    if not unit or not name then return nil end

    if NPC.GetAbilityByIndex then
        for _, index in ipairs({ 4, 5, 3, 6, 7 }) do
            local ab = NPC.GetAbilityByIndex(unit, index)
            if ab and AbilityName(ab) == name and not IsAbilityHidden(ab) and AbilityActivated(ab) then
                return ab
            end
        end
    end

    local ab = FindAbilityByName(unit, name)
    if ab and not IsAbilityHidden(ab) and AbilityActivated(ab) then
        return ab
    end

    return nil
end

local function GetAbility(unit, key)
    local names = abilityNames[key]
    if not names then return nil end

    if abilityDefs[key] then
        for _, name in ipairs(names) do
            local ab = GetInvokedAbility(unit, name)
            if ab then return ab end
        end
        return nil
    end

    for _, name in ipairs(names) do
        local ab = FindAbilityByName(unit, name)
        if ab and not IsAbilityHidden(ab) then
            return ab
        end
    end

    for _, name in ipairs(names) do
        local ab = FindAbilityByName(unit, name)
        if ab then return ab end
    end

    return nil
end

local function GetItem(unit, key)
    local def = itemDefs[key]
    if not def then return nil end

    local names = def.aliases or { def.item }
    for _, name in ipairs(names) do
        local item = NPC.GetItem(unit, name, true)
        if item then
            return item
        end
    end

    return nil
end

function HasAghanimScepter()
    if not hero then return false end

    if NPC and NPC.HasScepter then
        local ok, hasScepter = SafeCall(NPC.HasScepter, hero)
        if ok and hasScepter == true then return true end
    end
    if NPC and NPC.HasAghanimsScepter then
        local ok, hasScepter = SafeCall(NPC.HasAghanimsScepter, hero)
        if ok and hasScepter == true then return true end
    end

    if NPC and NPC.GetItem then
        for _, itemName in ipairs({
            "item_ultimate_scepter",
            "item_ultimate_scepter_2",
            "item_ultimate_scepter_roshan",
        }) do
            local ok, item = SafeCall(NPC.GetItem, hero, itemName, true)
            if ok and item then return true end
        end
    end

    if NPC and NPC.HasModifier then
        for _, modifierName in ipairs({
            "modifier_item_ultimate_scepter",
            "modifier_item_ultimate_scepter_consumed",
            "modifier_item_ultimate_scepter_consumed_alchemist",
            "modifier_item_ultimate_scepter_consumed_roshan",
        }) do
            local ok, hasModifier = SafeCall(NPC.HasModifier, hero, modifierName)
            if ok and hasModifier == true then return true end
        end
    end

    return false
end

local function GetStepObject(key)
    if not hero then return nil, false end
    if itemDefs[key] then
        return GetItem(hero, key), true
    end
    return GetAbility(hero, key), false
end

local function GetCooldownForKey(key)
    local object = GetStepObject(key)
    if not object or not Ability or not Ability.GetCooldown then return 0 end

    local ok, cooldown = SafeCall(Ability.GetCooldown, object)
    if ok and type(cooldown) == "number" and cooldown > 0 then
        return cooldown
    end

    return 0
end

local function FormatCooldown(seconds)
    seconds = math.max(0, math.ceil(seconds or 0))
    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        local secs = seconds - minutes * 60
        return string.format("%d:%02d", minutes, secs)
    end
    return tostring(seconds)
end

local function AbilityLevel(ability)
    if not ability then return 0 end
    if Ability and Ability.GetLevel then
        local ok, value = SafeCall(Ability.GetLevel, ability)
        if ok and value then return value end
    end
    return 1
end

local function GetRawAbility(unit, key)
    local names = abilityNames[key]
    if not unit or not names then return nil end

    for _, name in ipairs(names) do
        local ab = FindAbilityByName(unit, name)
        if ab then return ab end
    end

    return nil
end

local function AbilitySpecial(ability, key, fallback)
    if not ability or not key then return fallback end

    if Ability and Ability.GetSpecialValue then
        local ok, value = SafeCall(Ability.GetSpecialValue, ability, key)
        if ok and value ~= nil then return tonumber(value) or value end
    end

    if Ability and Ability.GetLevelSpecialValueFor then
        local ok, value = SafeCall(Ability.GetLevelSpecialValueFor, ability, key)
        if ok and value ~= nil then return tonumber(value) or value end

        local level = math_max(0, AbilityLevel(ability) - 1)
        ok, value = SafeCall(Ability.GetLevelSpecialValueFor, ability, key, level)
        if ok and value ~= nil then return tonumber(value) or value end
    end

    local ok, value = pcall(function()
        return ability:GetSpecialValue(key)
    end)
    if ok and value ~= nil then return tonumber(value) or value end

    return fallback
end

local function AbilitySpecialAtLevel(ability, key, levelIndex, fallback)
    if not ability or not key then return fallback end

    if Ability and Ability.GetLevelSpecialValueFor then
        local ok, value = SafeCall(Ability.GetLevelSpecialValueFor, ability, key, levelIndex)
        if ok and value ~= nil then return tonumber(value) or value end
    end

    local ok, value = pcall(function()
        return ability:GetLevelSpecialValueFor(key, levelIndex)
    end)
    if ok and value ~= nil then return tonumber(value) or value end

    return fallback
end

local function AbilityCastPoint(ability, fallback)
    if ability and Ability and Ability.GetCastPoint then
        local ok, value = SafeCall(Ability.GetCastPoint, ability)
        if ok and type(value) == "number" then return value end
    end
    return fallback or 0
end

local function AbilityChannelTime(ability, fallback)
    if ability and Ability and Ability.GetChannelTime then
        local ok, value = SafeCall(Ability.GetChannelTime, ability)
        if ok and type(value) == "number" and value > 0 then return value end
    end
    return fallback or 0
end

local function OrbLevel(key)
    local ability = GetRawAbility(hero, key)
    local level = AbilityLevel(ability)
    if level <= 0 then return 1 end
    return Clamp(level, 1, #TORNADO_LIFT_BY_QUAS_LEVEL)
end

local function TornadoLiftDuration()
    local tornado = GetRawAbility(hero, "tornado")
    local quasLevel = OrbLevel("q")
    local value = AbilitySpecialAtLevel(tornado, "lift_duration", quasLevel - 1, nil)
    if type(value) == "number" and value > 0 then return value end

    return TORNADO_LIFT_BY_QUAS_LEVEL[quasLevel] or 1.7
end

local function TornadoTravelSpeed()
    local tornado = GetRawAbility(hero, "tornado")
    local value = AbilitySpecial(tornado, "travel_speed", 1000)
    if type(value) == "number" and value > 0 then return value end
    return 1000
end

local BasicTargetPosition

local function MeteorHammerTotalTime(item)
    local channel = AbilityChannelTime(item, AbilitySpecial(item, "channel_time", nil))
    if type(channel) ~= "number" or channel <= 0 then
        channel = AbilitySpecial(item, "max_duration", 2.0)
    end
    if type(channel) ~= "number" or channel <= 0 then channel = 2.0 end

    local land = AbilitySpecial(item, "land_time", 0.5)
    if type(land) ~= "number" or land < 0 then land = 0.5 end

    return channel + land
end

function CycloneDuration(item)
    local duration = AbilitySpecial(item, "cyclone_duration", nil)
    if type(duration) ~= "number" or duration <= 0 then
        duration = AbilitySpecial(item, "duration", DEFAULT_CYCLONE_DURATION)
    end
    if type(duration) ~= "number" or duration <= 0 then
        duration = DEFAULT_CYCLONE_DURATION
    end
    return duration
end

local function SpellImpactDelay(step, ability)
    if not step or step.source ~= "ability" then return 0 end

    if step.ability == "emp" then
        local value = AbilitySpecial(ability, "delay", 2.9)
        if type(value) == "number" and value > 0 then return AbilityCastPoint(ability, 0.05) + value end
        return AbilityCastPoint(ability, 0.05) + 2.9
    end

    if step.ability == "chaos_meteor" then
        local value = AbilitySpecial(ability, "land_time", nil)
        if type(value) ~= "number" or value <= 0 then
            value = AbilitySpecial(ability, "delay", 1.3)
        end
        if type(value) == "number" and value > 0 then return AbilityCastPoint(ability, 0.05) + value end
        return AbilityCastPoint(ability, 0.05) + 1.3
    end

    if step.ability == "sun_strike" or step.ability == "cataclysm" then
        return SUN_STRIKE_IMPACT_DELAY
    end

    if step.ability == "deafening_blast" then
        local targetPos = BasicTargetPosition and BasicTargetPosition() or nil
        local heroPos = hero and Entity.GetAbsOrigin(hero) or nil
        local travelSpeed = AbilitySpecial(ability, "travel_speed", 1100)
        local travel = 0
        if targetPos and heroPos and type(travelSpeed) == "number" and travelSpeed > 0 then
            travel = Dist2D(heroPos, targetPos) / travelSpeed
        end
        return AbilityCastPoint(ability, 0.05) + travel
    end

    return AbilityCastPoint(ability, 0)
end

local function AbilityInPhase(ability)
    if not ability or not Ability.IsInAbilityPhase then return false end
    local ok, value = SafeCall(Ability.IsInAbilityPhase, ability)
    return ok and value == true
end

local function AbilityChannelling(ability)
    if not ability or not Ability.IsChannelling then return false end
    local ok, value = SafeCall(Ability.IsChannelling, ability)
    return ok and value == true
end

local function ComboOrderLocked(now)
    if not comboLockAbility then return false end

    local locked = now < comboLockUntil
    if locked then return true end

    comboLockAbility = nil
    comboLockUntil = 0
    return false
end

local function StartComboOrderLock(step, now)
    if not step or not step.lock or step.lock <= 0 then return end

    comboLockAbility = step.ability or step.item or "lock"
    comboLockUntil = now + step.lock
end

local function CanCast(ability, isItem)
    if not hero or not ability then return false end
    if not isItem and AbilityLevel(ability) <= 0 then return false end

    local okReady, ready = SafeCall(Ability.IsReady, ability)
    if okReady and ready == false then return false end

    if AbilityInPhase(ability) then return false end

    if Ability.IsCastable then
        local okCastable, castable = SafeCall(Ability.IsCastable, ability, NPC.GetMana(hero))
        if okCastable and castable == false then return false end
    end

    return true
end

local function CastNoTarget(ability, directFirst)
    if directFirst and Ability and Ability.CastNoTarget then
        local okDirect = pcall(Ability.CastNoTarget, ability, false, false, true)
        if okDirect then return true end
    end

    local ok = pcall(function()
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET,
            nil,
            nil,
            ability,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            hero,
            false,
            false
        )
    end)

    if ok then return true end

    if Ability and Ability.CastNoTarget then
        return pcall(Ability.CastNoTarget, ability, false, false, true)
    end

    return false
end

local function CastTarget(ability, unit, directFirst)
    if directFirst and Ability and Ability.CastTarget then
        local okDirect = pcall(Ability.CastTarget, ability, unit, false, false, true)
        if okDirect then return true end
    end

    local ok = pcall(function()
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET,
            unit,
            Vector(0, 0, 0),
            ability,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            hero,
            false,
            false
        )
    end)

    if ok then return true end

    if Ability and Ability.CastTarget then
        return pcall(Ability.CastTarget, ability, unit, false, false, true)
    end

    return false
end

local function CastPosition(ability, pos, directFirst)
    if directFirst and Ability and Ability.CastPosition then
        local okDirect = pcall(Ability.CastPosition, ability, pos, false, false, true)
        if okDirect then return true end
    end

    local ok = pcall(function()
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
            nil,
            pos,
            ability,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            hero,
            false,
            false
        )
    end)

    if ok then return true end

    if Ability and Ability.CastPosition then
        return pcall(Ability.CastPosition, ability, pos, false, false, true)
    end

    return false
end

MoveTo = function(pos)
    if not pos then return end
    if NPC and NPC.MoveTo then
        pcall(NPC.MoveTo, hero, pos, false, false, false, true)
        return
    end

    pcall(function()
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            pos,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            hero,
            false,
            false
        )
    end)
end

local function AttackTarget(unit)
    if not unit then return end
    if Player.AttackTarget then
        pcall(Player.AttackTarget, player, hero, unit, false, false, true)
        return
    end

    pcall(function()
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
            unit,
            Vector(0, 0, 0),
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            hero,
            false,
            false
        )
    end)
end

local function ClearInvokeState()
    invokeState.key = nil
    invokeState.recipe = nil
    invokeState.index = 0
    invokeState.invokedAt = 0
end

local function CastOrb(orbKey, now)
    local orb = GetRawAbility(hero, orbKey)
    if not orb or not CanCast(orb, false) then return false end
    if now - lastInvokeAction < 0.07 then return false end

    CastNoTarget(orb, true)
    lastInvokeAction = now
    return true
end

local function EnsureSpellInvoked(key, now)
    if GetAbility(hero, key) then
        if invokeState.key == key then ClearInvokeState() end
        return true
    end

    local def = abilityDefs[key]
    if not def or type(def.recipe) ~= "table" then return false end

    local invoke = GetRawAbility(hero, "invoke")
    if not invoke or AbilityLevel(invoke) <= 0 then return false end

    if invokeState.key ~= key then
        invokeState.key = key
        invokeState.recipe = def.recipe
        invokeState.index = 1
        invokeState.invokedAt = 0
    end

    local recipe = invokeState.recipe or def.recipe
    if invokeState.index <= #recipe then
        if CastOrb(recipe[invokeState.index], now) then
            invokeState.index = invokeState.index + 1
        end
        return false
    end

    if invokeState.index == #recipe + 1 then
        if now - lastInvokeAction < 0.07 then return false end
        if not CanCast(invoke, false) then return false end

        CastNoTarget(invoke, true)
        lastInvokeAction = now
        invokeState.invokedAt = now
        invokeState.index = invokeState.index + 1
        return false
    end

    if now - (invokeState.invokedAt or 0) < 0.08 then
        return false
    end

    if GetAbility(hero, key) then
        ClearInvokeState()
        return true
    end

    if now - (invokeState.invokedAt or 0) > 0.55 then
        ClearInvokeState()
    end

    return false
end

local function ClearPendingEndOrb()
    pendingEndStance = nil
    pendingEndStanceUntil = 0
    pendingEndStanceCasts = 0
end

local function ApplyEndStance(index, now)
    local wanted = NormalizeEndStance(endStances[index])
    if wanted == "keep" then
        ClearPendingEndOrb()
        return
    end

    pendingEndStance = wanted
    pendingEndStanceUntil = now + 1.25
    pendingEndStanceCasts = 0
end

local function ProcessPendingEndStance(now)
    if not pendingEndStance then return end
    if now > pendingEndStanceUntil then
        ClearPendingEndOrb()
        return
    end

    if pendingEndStanceCasts >= 3 then
        ClearPendingEndOrb()
        return
    end

    if CastOrb(pendingEndStance, now) then
        pendingEndStanceCasts = pendingEndStanceCasts + 1
    end
end

local function TargetValid(unit)
    if not unit or not hero then return false end
    if not Entity.IsAlive(unit) then return false end
    if not NPC.IsHero(unit) then return false end
    if NPC.IsIllusion(unit) then return false end
    if Entity.GetIndex(unit) == Entity.GetIndex(hero) then return false end
    if Entity.IsSameTeam(hero, unit) then return false end

    if NPC.HasState then
        if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then return false end
        if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_NO_TARGET) then return false end
    end

    return true
end

local function TargetAlive(unit)
    if not unit or not hero then return false end
    if not Entity.IsAlive(unit) then return false end
    if Entity.GetIndex(unit) == Entity.GetIndex(hero) then return false end
    if Entity.IsSameTeam(hero, unit) then return false end
    return true
end

local function GroundPosition(pos)
    if not pos then return nil end
    return Vector(pos.x, pos.y, 0)
end

local function CursorGroundPosition()
    return GroundPosition(Input.GetWorldCursorPos())
end

local function IsTornadoModifierName(name)
    if not name then return false end
    local nameLower = string.lower(tostring(name))

    for _, modifierName in ipairs(TORNADO_MODIFIER_NAMES) do
        if nameLower == modifierName then return true end
    end

    return string.find(nameLower, "modifier_invoker_tornado", 1, true) ~= nil
end

function IsCycloneModifierName(name)
    if not name then return false end
    local nameLower = string.lower(tostring(name))

    for _, modifierName in ipairs(CYCLONE_MODIFIER_NAMES) do
        if nameLower == modifierName then return true end
    end

    return string.find(nameLower, "cyclone", 1, true) ~= nil
        and (string.find(nameLower, "eul", 1, true) ~= nil or string.find(nameLower, "wind_waker", 1, true) ~= nil)
end

function SetupSourceFromModifierName(name)
    if not name then return "cyclone" end
    local value = string.lower(tostring(name))

    if string.find(value, "shadow_demon_disruption", 1, true) then return "shadow_demon_disruption" end
    if string.find(value, "astral_imprisonment", 1, true) then return "astral_imprisonment" end
    if string.find(value, "brewmaster_storm_cyclone", 1, true) or string.find(value, "storm_cyclone", 1, true) then return "brewmaster_cyclone" end
    if string.find(value, "earthspirit_petrify", 1, true) or string.find(value, "earth_spirit_petrify", 1, true) then return "earth_spirit_enchant_remnant" end
    if string.find(value, "meepo_petrify", 1, true) then return "meepo_dig" end
    if string.find(value, "rubick_telekinesis", 1, true) then return "rubick_telekinesis" end
    if string.find(value, "puck_phase_shift", 1, true) then return "puck_phase_shift" end
    if string.find(value, "wind_waker", 1, true) then return "wind_waker" end
    if string.find(value, "eul", 1, true) or string.find(value, "item_cyclone", 1, true) then return "euls" end

    return "cyclone"
end

local function FindTornadoModifier(unit)
    if not unit then return nil end

    if NPC.GetModifier then
        for _, modifierName in ipairs(TORNADO_MODIFIER_NAMES) do
            local ok, modifier = SafeCall(NPC.GetModifier, unit, modifierName)
            if ok and modifier then return modifier end
        end
    end

    if NPC.GetModifiers and Modifier and Modifier.GetName then
        local ok, modifiers = SafeCall(NPC.GetModifiers, unit)
        if ok and type(modifiers) == "table" then
            for _, modifier in ipairs(modifiers) do
                local okName, name = SafeCall(Modifier.GetName, modifier)
                if okName and IsTornadoModifierName(name) then
                    return modifier
                end
            end
        end
    end

    if NPC.GetModifierCount and NPC.GetModifierName and NPC.GetModifier then
        local okCount, count = SafeCall(NPC.GetModifierCount, unit)
        if okCount and type(count) == "number" then
            for i = 0, count - 1 do
                local okName, name = SafeCall(NPC.GetModifierName, unit, i)
                if okName and IsTornadoModifierName(name) then
                    local okMod, modifier = SafeCall(NPC.GetModifier, unit, name)
                    if okMod and modifier then return modifier end
                end
            end
        end
    end

    return nil
end

function FindCycloneModifier(unit)
    if not unit then return nil end

    if NPC.GetModifier then
        for _, modifierName in ipairs(CYCLONE_MODIFIER_NAMES) do
            local ok, modifier = SafeCall(NPC.GetModifier, unit, modifierName)
            if ok and modifier then return modifier end
        end
    end

    if NPC.GetModifiers and Modifier and Modifier.GetName then
        local ok, modifiers = SafeCall(NPC.GetModifiers, unit)
        if ok and type(modifiers) == "table" then
            for _, modifier in ipairs(modifiers) do
                local okName, name = SafeCall(Modifier.GetName, modifier)
                if okName and IsCycloneModifierName(name) then
                    return modifier
                end
            end
        end
    end

    if NPC.GetModifierCount and NPC.GetModifierName and NPC.GetModifier then
        local okCount, count = SafeCall(NPC.GetModifierCount, unit)
        if okCount and type(count) == "number" then
            for i = 0, count - 1 do
                local okName, name = SafeCall(NPC.GetModifierName, unit, i)
                if okName and IsCycloneModifierName(name) then
                    local okMod, modifier = SafeCall(NPC.GetModifier, unit, name)
                    if okMod and modifier then return modifier end
                end
            end
        end
    end

    return nil
end

local function ModifierRemainingTime(modifier, now)
    if not modifier then return nil, nil end

    local remaining = nil
    local duration = nil

    if Modifier and Modifier.GetDieTime then
        local ok, dieTime = SafeCall(Modifier.GetDieTime, modifier)
        if ok and type(dieTime) == "number" and dieTime > 0 then
            remaining = math_max(0, dieTime - now)
        end
    end

    if Modifier and Modifier.GetDuration then
        local ok, value = SafeCall(Modifier.GetDuration, modifier)
        if ok and type(value) == "number" and value > 0 then
            duration = value
        end
    end

    return remaining, duration
end

local function TornadoAirborneInfo(unit, now)
    if not TargetAlive(unit) or not NPC.IsHero(unit) or NPC.IsIllusion(unit) then return nil end

    local modifier = FindTornadoModifier(unit)
    if not modifier then return nil end

    local remaining, duration = ModifierRemainingTime(modifier, now)
    duration = duration or TornadoLiftDuration()
    if not remaining then
        remaining = duration
    end

    local pos = GroundPosition(Entity.GetAbsOrigin(unit))
    if not pos then return nil end

    remaining = math_max(0, remaining)
    duration = math_max(duration or remaining, remaining)

    return {
        source = "tornado",
        remaining = remaining,
        duration = duration,
        dropTime = now + remaining,
        hitTime = now + remaining - duration,
        pos = pos,
    }
end

function CycloneAirborneInfo(unit, now)
    if not TargetAlive(unit) or not NPC.IsHero(unit) or NPC.IsIllusion(unit) then return nil end

    local modifier = FindCycloneModifier(unit)
    if not modifier then return nil end

    local source = "cyclone"
    if Modifier and Modifier.GetName then
        local okName, name = SafeCall(Modifier.GetName, modifier)
        if okName then
            source = SetupSourceFromModifierName(name)
        end
    end

    local remaining, duration = ModifierRemainingTime(modifier, now)
    duration = duration or DEFAULT_CYCLONE_DURATION
    if not remaining then
        remaining = duration
    end

    local pos = GroundPosition(Entity.GetAbsOrigin(unit))
    if not pos then return nil end

    remaining = math_max(0, remaining)
    duration = math_max(duration or remaining, remaining)

    return {
        source = source,
        remaining = remaining,
        duration = duration,
        dropTime = now + remaining,
        hitTime = now + remaining - duration,
        pos = pos,
    }
end

function AirborneInfo(unit, now)
    return TornadoAirborneInfo(unit, now) or CycloneAirborneInfo(unit, now)
end

local function ApplyTornadoAirborneInfo(unit, info, now)
    if not unit or not info then return false end

    target = unit
    local state = {
        source = info.source or "tornado",
        castTime = info.hitTime or now,
        hitTime = info.hitTime or now,
        dropTime = info.dropTime or now,
        pos = info.pos or GroundPosition(Entity.GetAbsOrigin(unit)),
        targetIndex = Entity.GetIndex(unit),
    }

    spellState.landing = state
    if state.source == "tornado" then
        spellState.tornado = state
    else
        spellState.cyclone = state
    end

    DebugLogEvent("airborne_detected", {
        source = state.source,
        target = DebugUnitName(unit),
        remaining = DebugNumber((state.dropTime or now) - now),
        drop_time = DebugNumber(state.dropTime or 0),
        pos = DebugPositionText(state.pos),
    }, "airborne_" .. tostring(state.source) .. "_" .. tostring(state.targetIndex or 0), 0.20)

    return true
end

local function FindAirborneTornadoTarget(now)
    if not Heroes or not Heroes.GetAll then return nil end

    local cursorPos = Input.GetWorldCursorPos()
    if not cursorPos then return nil end

    local allHeroes = Heroes.GetAll()
    if type(allHeroes) ~= "table" then return nil end

    local best = nil
    local bestInfo = nil
    local bestDist = ui.targetRadius:Get() + 1

    for _, unit in ipairs(allHeroes) do
        if TargetAlive(unit) and NPC.IsHero(unit) and not NPC.IsIllusion(unit) then
            local pos = Entity.GetAbsOrigin(unit)
            local dist = Dist2D(cursorPos, pos)
            if dist <= bestDist then
                local info = AirborneInfo(unit, now)
                if info then
                    best = unit
                    bestInfo = info
                    bestDist = dist
                end
            end
        end
    end

    return best, bestInfo
end

local function GetTarget()
    local unit = Input.GetNearestHeroToCursor(Enum.TeamType.TEAM_ENEMY)
    if not TargetValid(unit) then return nil end

    local cursorPos = Input.GetWorldCursorPos()
    if Dist2D(cursorPos, Entity.GetAbsOrigin(unit)) > ui.targetRadius:Get() then
        return nil
    end

    return unit
end

local function RefreshAim(now)
    if TargetAlive(target) then
        local info = AirborneInfo(target, now)
        if info then
            ApplyTornadoAirborneInfo(target, info, now)
            return
        end
    end

    local airborne, info = FindAirborneTornadoTarget(now)
    if airborne and info then
        ApplyTornadoAirborneInfo(airborne, info, now)
        return
    end

    if not TargetAlive(target) then
        target = GetTarget()
    end
end

local function DestroyTargetParticle()
    if targetParticle then
        Particle.Destroy(targetParticle)
        targetParticle = nil
        targetParticleIndex = -1
    end
end

local function ManageTargetParticle()
    if not ui.drawTarget:Get() or not target or not TargetAlive(target) then
        DestroyTargetParticle()
        return
    end

    local idx = Entity.GetIndex(target)
    if targetParticleIndex == idx then return end

    DestroyTargetParticle()
    targetParticle = Particle.Create(
        "particles/ui_mouseactions/drag_selected_ring.vpcf",
        Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW,
        target
    )
    Particle.SetControlPoint(targetParticle, 1, Vector(255, 70, 60))
    Particle.SetControlPoint(targetParticle, 2, Vector(120, 255, 255))
    targetParticleIndex = idx
end

local function ResetCombo()
    comboState = 0
    activeCombo = 0
    holdComboComplete = false
    target = nil
    lastAction = 0
    lastEchoFaceOrder = 0
    comboLockUntil = 0
    comboLockAbility = nil
    ClearInvokeState()
    spellState = {}
    DestroyTargetParticle()
end

local function ClearTapPending()
    tapPending = false
    tapPendingUntil = 0
end

local function IsTapStepMode()
    return (ui.comboMode:Get() or 0) == 1
end

local function RangeForStep(step, ability)
    if step.range then return step.range end
    if ability and Ability.GetCastRange then
        local ok, range = SafeCall(Ability.GetCastRange, ability)
        if ok and range and range > 0 then return range end
    end
    return nil
end

local function StepNeedsMove(step, ability)
    if not target or not Entity.IsAlive(target) then return false end
    local range = RangeForStep(step, ability)
    if not range or range <= 0 then return false end
    local dist = Dist2D(Entity.GetAbsOrigin(hero), Entity.GetAbsOrigin(target))
    return dist > range + 50
end

function ActiveLandingState(now)
    now = now or (GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0)

    local state = spellState.landing
    if state and state.pos and state.dropTime and now <= state.dropTime + 0.70 then
        return state
    end

    state = spellState.tornado
    if state and state.pos and state.dropTime and now <= state.dropTime + 0.70 then
        return state
    end

    state = spellState.cyclone
    if state and state.pos and state.dropTime and now <= state.dropTime + 0.70 then
        return state
    end

    return nil
end

function DebugModifierSummary(unit, now)
    if not ui.debugModifiers or ui.debugModifiers:Get() ~= true then return "" end
    if not unit or not NPC or not Modifier then return "" end

    local result = {}

    if NPC.GetModifiers and Modifier.GetName then
        local ok, modifiers = SafeCall(NPC.GetModifiers, unit)
        if ok and type(modifiers) == "table" then
            for _, modifier in ipairs(modifiers) do
                if #result >= 18 then break end
                local okName, name = SafeCall(Modifier.GetName, modifier)
                if okName and name then
                    local remaining = nil
                    if ModifierRemainingTime then
                        remaining = ModifierRemainingTime(modifier, now)
                    end
                    if type(remaining) == "number" then
                        result[#result + 1] = tostring(name) .. ":" .. DebugNumber(remaining)
                    else
                        result[#result + 1] = tostring(name)
                    end
                end
            end
        end
    elseif NPC.GetModifierCount and NPC.GetModifierName then
        local okCount, count = SafeCall(NPC.GetModifierCount, unit)
        if okCount and type(count) == "number" then
            for i = 0, count - 1 do
                if #result >= 18 then break end
                local okName, name = SafeCall(NPC.GetModifierName, unit, i)
                if okName and name then
                    result[#result + 1] = tostring(name)
                end
            end
        end
    end

    return table.concat(result, ",")
end

DebugSampleTarget = function(now)
    if not DebugEnabled() then return end

    local unit = TargetAlive(target) and target or nil
    local index = -1
    if unit and Entity and Entity.GetIndex then
        local okIndex, value = SafeCall(Entity.GetIndex, unit)
        if okIndex and value then index = value end
    end

    local hp, mana = DebugTargetVitals(unit)
    if ui.debugVitals and ui.debugVitals:Get() == true and unit then
        if debugState.lastTargetIndex == index then
            if debugState.lastHp ~= nil and hp ~= nil and hp ~= debugState.lastHp then
                DebugLogEvent("target_hp_delta", {
                    target = DebugUnitName(unit),
                    hp = hp,
                    delta = hp - debugState.lastHp,
                    pos = DebugPositionText(Entity.GetAbsOrigin(unit)),
                })
            end
            if debugState.lastMana ~= nil and mana ~= nil and mana ~= debugState.lastMana then
                DebugLogEvent("target_mana_delta", {
                    target = DebugUnitName(unit),
                    mana = mana,
                    delta = mana - debugState.lastMana,
                })
            end
        end

        debugState.lastTargetIndex = index
        debugState.lastHp = hp
        debugState.lastMana = mana
    elseif not unit then
        debugState.lastTargetIndex = -1
        debugState.lastHp = nil
        debugState.lastMana = nil
    end

    local interval = ui.debugSample and ui.debugSample:Get() or 1
    if now - (debugState.lastSample or 0) < interval then return end
    debugState.lastSample = now

    local landing = ActiveLandingState(now)
    local fields = {
        target = unit and DebugUnitName(unit) or "none",
        hp = hp or "nil",
        mana = mana or "nil",
        hero_pos = DebugPositionText(hero and Entity.GetAbsOrigin(hero) or nil),
        cursor = DebugPositionText(CursorGroundPosition()),
        active_landing = landing and landing.source or "none",
    }

    if unit then
        fields.target_pos = DebugPositionText(Entity.GetAbsOrigin(unit))
        fields.modifiers = DebugModifierSummary(unit, now)
    end

    if landing then
        fields.drop_in = DebugNumber((landing.dropTime or now) - now)
        fields.drop_time = DebugNumber(landing.dropTime or 0)
        fields.landing_pos = DebugPositionText(landing.pos)
    end

    DebugLogEvent("target_sample", fields)
end

DrawDebugOverlay = function()
    if not DebugEnabled() or not ui.debugOverlay or ui.debugOverlay:Get() ~= true then return end
    EnsureFonts()

    local x = panel.x
    local y = panel.y + (panel.h or 0) + 5
    local w = 276
    local h = 42

    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), Color(12, 16, 24, 210), 5, Enum.DrawFlags.RoundCornersAll)
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), Color(83, 218, 205, 160), 5, Enum.DrawFlags.RoundCornersAll, 1.0)
    Render.Text(fonts.main, 12, "Invoker Debug: ON", Vec2(x + 8, y + 5), Color(235, 240, 247, 255))
    Render.Text(fonts.small, 11, "Latest file: invoker_combo_debug_latest.log", Vec2(x + 8, y + 20), Color(170, 185, 205, 240))
end

BasicTargetPosition = function()
    local now = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
    local landing = ActiveLandingState(now)

    if landing and landing.pos then
        return landing.pos
    end

    if TargetAlive(target) then
        return GroundPosition(Entity.GetAbsOrigin(target))
    end

    return CursorGroundPosition()
end

local function StepCastPosition(step, isItem)
    if step and step.timing == "after_tornado_drop" then
        local landing = ActiveLandingState()
        if landing and landing.pos then
            return landing.pos
        end
    end

    if isItem and step.item ~= "meteor_hammer" and not step.aimTarget then
        return CursorGroundPosition()
    end

    return BasicTargetPosition() or CursorGroundPosition()
end

function IceWallAimPosition(now)
    local landing = ActiveLandingState(now)
    if landing and landing.pos then
        return landing.pos
    end

    return CursorGroundPosition() or BasicTargetPosition()
end

local function RecordSpellCast(step, pos, now, ability, castTarget)
    if not step then return end

    DebugLogEvent("cast_order", {
        step = DebugStepName(step),
        kind = step.kind,
        ability_object = DebugAbilityName(ability),
        target = castTarget and DebugUnitName(castTarget) or (TargetAlive(target) and DebugUnitName(target) or "none"),
        pos = DebugPositionText(pos),
        landing = ActiveLandingState(now) and ActiveLandingState(now).source or "none",
    })

    if not step.record then return end
    if not pos then return end

    if step.record == "tornado" then
        local tornado = GetRawAbility(hero, "tornado")
        local heroPos = Entity.GetAbsOrigin(hero)
        local travelTime = Dist2D(heroPos, pos) / TornadoTravelSpeed()
        local hitTime = now + AbilityCastPoint(tornado, 0.05) + travelTime
        local state = {
            source = "tornado",
            castTime = now,
            hitTime = hitTime,
            dropTime = hitTime + TornadoLiftDuration(),
            pos = pos,
        }

        spellState.tornado = state
        spellState.landing = state
        DebugLogEvent("landing_recorded", {
            source = "tornado",
            hit_time = DebugNumber(hitTime),
            drop_time = DebugNumber(state.dropTime),
            lift = DebugNumber(TornadoLiftDuration()),
            travel = DebugNumber(travelTime),
            pos = DebugPositionText(pos),
        })
        return
    end

    if step.record == "cyclone" then
        local unit = castTarget or target
        if not TargetAlive(unit) then return end

        local targetPos = GroundPosition(Entity.GetAbsOrigin(unit)) or GroundPosition(pos)
        if not targetPos then return end

        local hitTime = now + AbilityCastPoint(ability, 0)
        local state = {
            source = "cyclone",
            castTime = now,
            hitTime = hitTime,
            dropTime = hitTime + CycloneDuration(ability),
            pos = targetPos,
            targetIndex = Entity.GetIndex(unit),
        }

        spellState.cyclone = state
        spellState.landing = state
        DebugLogEvent("landing_recorded", {
            source = "cyclone",
            hit_time = DebugNumber(hitTime),
            drop_time = DebugNumber(state.dropTime),
            duration = DebugNumber(CycloneDuration(ability)),
            target = DebugUnitName(unit),
            pos = DebugPositionText(targetPos),
        })
    end
end

local function StepImpactDelay(step, ability, isItem)
    if isItem and step.item == "meteor_hammer" then
        return MeteorHammerTotalTime(ability)
    end

    return SpellImpactDelay(step, ability)
end

local function WaitForSpellAwareStep(step, ability, isItem, now)
    if not step or step.timing ~= "after_tornado_drop" then return false end

    local landing = ActiveLandingState(now)
    if not landing or not landing.dropTime then
        DebugLogEvent("timing_no_landing", {
            step = DebugStepName(step),
            impact_delay = DebugNumber(StepImpactDelay(step, ability, isItem)),
        }, "timing_no_landing_" .. DebugStepName(step), 0.50)
        return false
    end

    local impactDelay = StepImpactDelay(step, ability, isItem)
    local castAt = landing.dropTime - impactDelay
    if now < castAt then
        lastAction = math_min(castAt, now + 0.05)
        if tapPending then
            tapPendingUntil = math_max(tapPendingUntil, castAt + 0.45)
        end
        DebugLogEvent("timing_wait", {
            step = DebugStepName(step),
            source = landing.source,
            drop_time = DebugNumber(landing.dropTime),
            cast_at = DebugNumber(castAt),
            wait = DebugNumber(castAt - now),
            impact_delay = DebugNumber(impactDelay),
            pos = DebugPositionText(landing.pos),
        }, "timing_wait_" .. DebugStepName(step), 0.20)
        return true
    end

    DebugLogEvent("timing_ready", {
        step = DebugStepName(step),
        source = landing.source,
        late_by = DebugNumber(now - castAt),
        impact_delay = DebugNumber(impactDelay),
        pos = DebugPositionText(landing.pos),
    }, "timing_ready_" .. DebugStepName(step), 0.20)

    return false
end

local function RunAbilityStep(step, now)
    if not step then return "skip" end
    if step.disabled then return "skip" end

    local isItem = step.source == "item"
    if not isItem and step.requiresScepter and not HasAghanimScepter() then
        DebugLogEvent("step_skip_missing_scepter", {
            step = DebugStepName(step),
        }, "missing_scepter_" .. DebugStepName(step), 0.50)
        return "skip"
    end
    if not isItem and step.kind == "target" and not TargetAlive(target) then return "wait" end
    if not isItem and not EnsureSpellInvoked(step.ability, now) then return "wait" end

    local ability = isItem and GetItem(hero, step.item) or GetAbility(hero, step.ability)
    if not ability then
        DebugLogEvent("step_skip_missing_object", {
            step = DebugStepName(step),
        }, "missing_" .. DebugStepName(step), 0.50)
        return "skip"
    end
    if AbilityInPhase(ability) then
        DebugLogEvent("step_wait_in_phase", {
            step = DebugStepName(step),
            ability_object = DebugAbilityName(ability),
        }, "phase_" .. DebugStepName(step), 0.25)
        return "wait"
    end
    if not CanCast(ability, isItem) then
        DebugLogEvent("step_skip_not_castable", {
            step = DebugStepName(step),
            ability_object = DebugAbilityName(ability),
        }, "not_castable_" .. DebugStepName(step), 0.50)
        return "skip"
    end
    if WaitForSpellAwareStep(step, ability, isItem, now) then return "wait" end

    if not isItem and step.ability == "deafening_blast" then
        local blockUntil = spellState.sunStrikeNoBlastUntil or 0
        if blockUntil > now then
            if tapPending then
                tapPendingUntil = math_max(tapPendingUntil, blockUntil + 0.35)
            end
            DebugLogEvent("sunstrike_blast_wait", {
                step = DebugStepName(step),
                wait = DebugNumber(blockUntil - now),
                block_until = DebugNumber(blockUntil),
            }, "sunstrike_blast_wait", 0.20)
            return "wait"
        end
    end

    if not isItem and step.ability == "ice_wall" then
        local aimPos = IceWallAimPosition(now)
        local range = RangeForStep(step, ability)

        if aimPos and range and range > 0 and Dist2D(Entity.GetAbsOrigin(hero), aimPos) > range + 50 then
            if ui.chaseTarget:Get() then
                MoveTo(aimPos)
            end
            DebugLogEvent("ice_wall_move_to_aim", {
                aim = DebugPositionText(aimPos),
                range = DebugNumber(range),
                dist = DebugNumber(Dist2D(Entity.GetAbsOrigin(hero), aimPos)),
            }, "ice_wall_move", 0.25)
            return "wait"
        end

        local facePoint = IceWallFacePoint(aimPos)
        if facePoint and not FacePoint(facePoint, now) then
            DebugLogEvent("ice_wall_face_wait", {
                aim = DebugPositionText(aimPos),
                face_point = DebugPositionText(facePoint),
            }, "ice_wall_face", 0.15)
            return "wait"
        end
    elseif not isItem and StepNeedsMove(step, ability) then
        if ui.chaseTarget:Get() then
            MoveTo(Entity.GetAbsOrigin(target))
        end
        DebugLogEvent("step_move_to_target", {
            step = DebugStepName(step),
            target = DebugUnitName(target),
            target_pos = DebugPositionText(Entity.GetAbsOrigin(target)),
        }, "move_" .. DebugStepName(step), 0.25)
        return "wait"
    end

    if not isItem and step.ability ~= "ice_wall" and step.face then
        local facePoint = BasicTargetPosition() or CursorGroundPosition()
        if facePoint and not FacePoint(facePoint, now) then
            DebugLogEvent("step_face_wait", {
                step = DebugStepName(step),
                face_point = DebugPositionText(facePoint),
            }, "face_" .. DebugStepName(step), 0.15)
            return "wait"
        end
    end

    if step.kind == "target" then
        if not TargetValid(target) then
            DebugLogEvent("step_wait_invalid_target", {
                step = DebugStepName(step),
            }, "invalid_target_" .. DebugStepName(step), 0.50)
            return "wait"
        end
        CastTarget(ability, target, isItem)
        RecordSpellCast(step, Entity.GetAbsOrigin(target), now, ability, target)
        return "cast"
    end

    if step.kind == "self" then
        CastTarget(ability, hero, isItem)
        RecordSpellCast(step, Entity.GetAbsOrigin(hero), now, ability, hero)
        return "cast"
    end

    if step.kind == "position" then
        local pos = StepCastPosition(step, isItem)
        if not pos then return "wait" end
        CastPosition(ability, pos, isItem)
        RecordSpellCast(step, pos, now, ability)
        return "cast"
    end

    if step.kind == "no_target" then
        CastNoTarget(ability, isItem)
        RecordSpellCast(step, BasicTargetPosition() or Entity.GetAbsOrigin(hero), now, ability)
        return "cast"
    end

    return "skip"
end

local function RunComboStep(now)
    local combo = combos[selectedCombo]
    if not combo then return "wait" end

    if ComboOrderLocked(now) then
        lastAction = now + 0.05
        return "wait"
    end

    if comboState <= 0 or comboState > #combo.steps then
        comboState = 1
    end

    local step = combo.steps[comboState]
    if not step then
        comboState = 1
        return "complete"
    end

    if step.kind == "attack" then
        if TargetValid(target) then
            AttackTarget(target)
        end
        lastAction = now + (step.delay or 0.20)
        comboState = 1
        return "complete"
    end

    local result = RunAbilityStep(step, now)
    if result == "cast" then
        local delay = step.delay or 0.10
        if step.source == "ability" and (step.ability == "sun_strike" or step.ability == "cataclysm") then
            spellState.sunStrikeNoBlastUntil = math_max(spellState.sunStrikeNoBlastUntil or 0, now + SUN_STRIKE_IMPACT_DELAY + SUN_STRIKE_BLAST_BUFFER)
            DebugLogEvent("sunstrike_blast_guard", {
                step = DebugStepName(step),
                block_until = DebugNumber(spellState.sunStrikeNoBlastUntil),
                delay = DebugNumber(delay),
            }, "sunstrike_blast_guard", 0.50)
        end

        StartComboOrderLock(step, now)
        comboState = comboState + 1
        lastAction = now + delay
    elseif result == "skip" then
        comboState = comboState + 1
        lastAction = now + 0.02
    else
        lastAction = now + 0.08
    end

    return result
end

local function ProcessTapStepMode(now, holdingCombo)
    if tapLastStepTime > 0 and not tapPending and now - tapLastStepTime >= (ui.tapReset:Get() or 4) then
        local releaseSlot = activeCombo > 0 and activeCombo or selectedCombo
        ApplyEndStance(releaseSlot, now)
        comboWasHeld = false
        tapLastStepTime = 0
        ClearTapPending()
        ResetCombo()
    end

    ProcessPendingEndStance(now)

    if tapPending then
        if ComboOrderLocked(now) then
            tapPendingUntil = math_max(tapPendingUntil, now + 0.35)
            return
        end

        if now > tapPendingUntil then
            ClearTapPending()
            tapLastStepTime = now
            return
        end

        if now < lastAction then return end

        RefreshAim(now)
        ManageTargetParticle()
        DebugSampleTarget(now)

        local result = RunComboStep(now)
        if result == "complete" then
            local releaseSlot = activeCombo > 0 and activeCombo or selectedCombo
            ApplyEndStance(releaseSlot, now)
            comboWasHeld = false
            tapLastStepTime = 0
            ClearTapPending()
            ResetCombo()
            ProcessPendingEndStance(now)
            return
        end

        if result == "cast" or result == "skip" then
            tapLastStepTime = now
            ClearTapPending()
            return
        end

        return
    end

    if holdingCombo then
        comboWasHeld = true
        return
    end

    if not comboWasHeld then return end
    comboWasHeld = false

    ClearPendingEndOrb()

    if activeCombo ~= selectedCombo then
        comboState = 0
        lastAction = 0
        target = nil
        activeCombo = selectedCombo
    end

    RefreshAim(now)

    ManageTargetParticle()
    DebugSampleTarget(now)
    tapLastStepTime = now
    tapPending = true
    tapPendingUntil = now + 1.25
    DebugLogEvent("tap_step_pressed", {
        combo = combos[selectedCombo] and combos[selectedCombo].name or "unknown",
        target = TargetAlive(target) and DebugUnitName(target) or "none",
    })
end

local function PointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

local function SelectCombo(index)
    selectedCombo = Clamp(index, 0, #combos)
    builder.slot = selectedCombo
    saved.selected = selectedCombo
    if SavePersistentState then
        SavePersistentState()
    end
    ResetCombo()
end

local function AddAbilityToCombo(index, key)
    if not abilityDefs[key] and not itemDefs[key] then return end
    comboSlots[index] = comboSlots[index] or {}
    if #comboSlots[index] >= MAX_COMBO_ABILITIES then return end

    comboSlots[index][#comboSlots[index] + 1] = key
    SaveComboSlot(index)
    RebuildCombo(index)
    SelectCombo(index)
end

local function RemoveAbilityFromCombo(index, abilityIndex)
    if not comboSlots[index] or not comboSlots[index][abilityIndex] then return end
    table.remove(comboSlots[index], abilityIndex)

    local oldDisabled = disabledItems[index] or {}
    local nextDisabled = {}
    local out = 1
    for i = 1, MAX_COMBO_ABILITIES do
        if i ~= abilityIndex then
            nextDisabled[out] = oldDisabled[i] == true and true or nil
            out = out + 1
        end
    end
    disabledItems[index] = nextDisabled

    SaveComboSlot(index)
    RebuildCombo(index)
    SelectCombo(index)
end

local function MoveComboStep(index, fromIndex, toIndex)
    local keys = comboSlots[index]
    if not keys or not keys[fromIndex] then return end

    local count = #keys
    toIndex = Clamp(toIndex, 1, count)
    if fromIndex == toIndex then return end

    local disabled = disabledItems[index] or {}
    local disabledArray = {}
    for i = 1, count do
        disabledArray[i] = disabled[i] == true
    end

    local key = table.remove(keys, fromIndex)
    local wasDisabled = table.remove(disabledArray, fromIndex)
    table.insert(keys, toIndex, key)
    table.insert(disabledArray, toIndex, wasDisabled == true)

    disabledItems[index] = {}
    for i = 1, #keys do
        if disabledArray[i] and (abilityDefs[keys[i]] or itemDefs[keys[i]]) then
            disabledItems[index][i] = true
        end
    end

    SaveComboSlot(index)
    RebuildCombo(index)
end

local function BindPressed(bind)
    if not bind then return false end

    if bind.Buttons then
        local ok, key1, key2 = pcall(bind.Buttons, bind)
        if ok then
            if not key1 or key1 == Enum.ButtonCode.KEY_NONE then return false end
            if key2 and key2 ~= Enum.ButtonCode.KEY_NONE and not Input.IsKeyDown(key2) then return false end
            return Input.IsKeyDownOnce(key1)
        end
    end

    if bind.IsPressed then
        local ok, pressed = pcall(bind.IsPressed, bind)
        if ok then return pressed == true end
    end

    return false
end

local function ProcessSlotBinds()
    if BindPressed(ui.resetSlotKey) then
        SelectCombo(0)
        return
    end

    for i, bind in ipairs(ui.slotKeys) do
        if BindPressed(bind) then
            SelectCombo(i)
            return
        end
    end
end

DebugProcessControls = function(now)
    local enabled = DebugEnabled()

    if enabled and not debugState.enabled then
        DebugClearLog(now)
        debugState.enabled = true
        DebugLogEvent("debug_enabled", {
            log_path = DEBUG_LOG_PATH,
            selected_combo = combos[selectedCombo] and combos[selectedCombo].name or "unknown",
        })
    elseif not enabled and debugState.enabled then
        DebugLogEvent("debug_disabled", {
            lines = debugState.lineCount,
        })
        debugState.enabled = false
        return
    end

    if not enabled then return end

    if BindPressed(ui.debugClearKey) then
        DebugClearLog(now)
        DebugLogEvent("debug_cleared", {
            selected_combo = combos[selectedCombo] and combos[selectedCombo].name or "unknown",
        })
    end

    if BindPressed(ui.debugMarkerKey) then
        DebugLogEvent("manual_marker", {
            target = TargetAlive(target) and DebugUnitName(target) or "none",
            cursor = DebugPositionText(CursorGroundPosition()),
            hero_pos = DebugPositionText(hero and Entity.GetAbsOrigin(hero) or nil),
        })
    end
end

local function GetBuilderEndStanceRects(x, y, w)
    local buttonW = 54
    local buttonH = 18
    local gap = 6
    local rowW = #stanceChoices * buttonW + (#stanceChoices - 1) * gap
    local startX = x + (w - rowW) * 0.5
    local rowY = y + 356
    local rects = {}

    for i, choice in ipairs(stanceChoices) do
        rects[#rects + 1] = {
            x = startX + (i - 1) * (buttonW + gap),
            y = rowY,
            w = buttonW,
            h = buttonH,
            choice = choice,
        }
    end

    return rects
end

function GetBuilderSaveDefaultRect(x, y, w)
    return {
        x = x + (w - 124) * 0.5,
        y = y + 382,
        w = 124,
        h = 18,
    }
end

local function GetItemGridMetrics(x, y, w)
    local iconSize = 28
    local iconGap = 6
    local cols = 6
    local gridW = cols * iconSize + (cols - 1) * iconGap
    return x + (w - gridW) * 0.5, y + 178, iconSize, iconGap, cols
end

local function GetPanelSlotRow()
    local headerH = 24
    local tabH = 19
    local comboBoxH = 32
    local pad = 7
    local boxX = panel.x + pad
    local boxY = panel.y + headerH + 3 + tabH
    local iconSize = 24
    local iconGap = 1
    return {
        comboIndex = selectedCombo,
        x = boxX + 5,
        y = boxY + 4,
        icon = iconSize,
        gap = iconGap,
        count = #(comboSlots[selectedCombo] or {}),
        source = "panel",
    }
end

local function GetBuilderSlotRow()
    local slotIcon = 24
    local slotGap = 3
    local slotY = builder.y + 307
    local rowW = MAX_COMBO_ABILITIES * slotIcon + (MAX_COMBO_ABILITIES - 1) * slotGap
    return {
        comboIndex = builder.slot,
        x = builder.x + (builder.w - rowW) * 0.5,
        y = slotY,
        icon = slotIcon,
        gap = slotGap,
        count = #(comboSlots[builder.slot] or {}),
        source = "builder",
    }
end

local function SlotIndexAt(mx, my, row, includeEmpty)
    if not row then return nil end
    local maxCount = includeEmpty and MAX_COMBO_ABILITIES or row.count
    if maxCount <= 0 then return nil end

    for i = 1, maxCount do
        local ix = row.x + (i - 1) * (row.icon + row.gap)
        if PointInRect(mx, my, ix, row.y, row.icon, row.icon) then
            return i
        end
    end

    return nil
end

local function DropIndexAt(mx, my, row)
    if not row or row.count <= 0 then return nil end
    local rowW = row.count * row.icon + (row.count - 1) * row.gap
    if my < row.y - 8 or my > row.y + row.icon + 8 then return nil end
    if mx < row.x - 12 or mx > row.x + rowW + 12 then return nil end

    local idx = math.floor((mx - row.x) / (row.icon + row.gap)) + 1
    return Clamp(idx, 1, row.count)
end

local function StartSlotDrag(source, comboIndex, fromIndex, mx, my)
    local keys = comboSlots[comboIndex]
    if not keys or not keys[fromIndex] then return end

    slotDrag.active = true
    slotDrag.source = source
    slotDrag.comboIndex = comboIndex
    slotDrag.fromIndex = fromIndex
    slotDrag.moved = false
    slotDrag.startX = mx
    slotDrag.startY = my
    slotDrag.key = keys[fromIndex]
end

local function FinishSlotDrag(mx, my)
    if not slotDrag.active then return end

    local source = slotDrag.source
    local comboIndex = slotDrag.comboIndex
    local fromIndex = slotDrag.fromIndex
    local moved = slotDrag.moved
    local key = slotDrag.key

    slotDrag.active = false
    slotDrag.source = nil
    slotDrag.comboIndex = 0
    slotDrag.fromIndex = 0
    slotDrag.moved = false
    slotDrag.key = nil

    if moved then
        local row = source == "builder" and GetBuilderSlotRow() or GetPanelSlotRow()
        local toIndex = DropIndexAt(mx, my, row)
        if toIndex then
            MoveComboStep(comboIndex, fromIndex, toIndex)
        end
        return
    end

    if source == "panel" and (abilityDefs[key] or itemDefs[key]) then
        ToggleDisabledItem(comboIndex, fromIndex)
    elseif source == "builder" then
        RemoveAbilityFromCombo(comboIndex, fromIndex)
    end
end

local function ButtonRect(x, y, w, h, active, hovered)
    local bg = active and Color(184, 54, 61, 235) or Color(29, 36, 48, 232)
    if hovered then
        bg = active and Color(212, 66, 74, 245) or Color(43, 52, 68, 245)
    end
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), bg, 4, Enum.DrawFlags.RoundCornersAll)
end

local function DrawAbilityIcon(key, x, y, size, active, opts)
    opts = opts or {}
    local icon = GetAbilityIcon(key)
    local alpha = active == false and 120 or 255
    if opts.disabled then
        alpha = 100
    elseif opts.cooldown and opts.cooldown > 0 then
        alpha = 150
    end
    Render.FilledRect(Vec2(x, y), Vec2(x + size, y + size), Color(13, 16, 22, 230), 4, Enum.DrawFlags.RoundCornersAll)
    if icon and icon ~= 0 then
        Render.Image(icon, Vec2(x, y), Vec2(size, size), Color(255, 255, 255, alpha), 4, Enum.DrawFlags.RoundCornersAll)
    else
        local def = abilityDefs[key] or itemDefs[key]
        local letter = def and string.sub(def.short, 1, 1) or "?"
        local ts = Render.TextSize(fonts.main, 15, letter)
        Render.Text(fonts.main, 15, letter, Vec2(x + (size - ts.x) * 0.5, y + (size - ts.y) * 0.5), Color(235, 240, 247, alpha))
    end
    if key == "sun_strike" then
        Render.FilledRect(Vec2(x, y), Vec2(x + size, y + size), Color(28, 198, 104, 74), 4, Enum.DrawFlags.RoundCornersAll)
        Render.Rect(Vec2(x + 1, y + 1), Vec2(x + size - 1, y + size - 1), Color(79, 255, 151, 210), 4, Enum.DrawFlags.RoundCornersAll, 1.0)
    end
    if active then
        Render.Rect(Vec2(x, y), Vec2(x + size, y + size), Color(83, 218, 205, 235), 4, Enum.DrawFlags.RoundCornersAll, 1.1)
    end
    if opts.cooldown and opts.cooldown > 0 then
        Render.FilledRect(Vec2(x, y), Vec2(x + size, y + size), Color(35, 38, 45, 148), 4, Enum.DrawFlags.RoundCornersAll)
        local cdText = FormatCooldown(opts.cooldown)
        local fontSize = size <= 24 and 9 or 10
        local ts = Render.TextSize(fonts.small, fontSize, cdText)
        Render.Text(fonts.small, fontSize, cdText, Vec2(x + (size - ts.x) * 0.5, y + (size - ts.y) * 0.5), Color(245, 248, 252, 255))
    end
    if opts.disabled then
        Render.FilledRect(Vec2(x, y), Vec2(x + size, y + size), Color(152, 31, 39, 116), 4, Enum.DrawFlags.RoundCornersAll)
        Render.Rect(Vec2(x, y), Vec2(x + size, y + size), Color(235, 69, 78, 240), 4, Enum.DrawFlags.RoundCornersAll, 1.2)
    end
end

local function HandlePanelInput()
    panel.clickEaten = false
    panel.hovered = false
    builder.clickEaten = false
    builder.hovered = false
    if not ui.enabled:Get() or not ui.showPanel:Get() then return end

    local mx, my = Input.GetCursorPos()
    local headerH = 24
    local tabH = 19
    local comboBoxH = 32
    local pad = 7
    local panelH = headerH + tabH + comboBoxH + pad
    panel.h = panelH

    local scr = Render.ScreenSize()
    if scr then
        panel.x = Clamp(panel.x, 0, math_max(0, scr.x - panel.w))
        panel.y = Clamp(panel.y, 0, math_max(0, scr.y - panel.h))
        builder.x = Clamp(builder.x, 0, math_max(0, scr.x - builder.w))
        builder.y = Clamp(builder.y, 0, math_max(0, scr.y - builder.h))
    end

    panel.hovered = PointInRect(mx, my, panel.x, panel.y, panel.w, panel.h)
    builder.hovered = builder.open and PointInRect(mx, my, builder.x, builder.y, builder.w, builder.h)

    if slotDrag.active then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            local dx = mx - slotDrag.startX
            local dy = my - slotDrag.startY
            if dx * dx + dy * dy > 16 then
                slotDrag.moved = true
            end
            if slotDrag.source == "builder" then
                builder.clickEaten = true
            else
                panel.clickEaten = true
            end
        else
            FinishSlotDrag(mx, my)
            panel.clickEaten = true
            builder.clickEaten = true
        end
        return
    end

    if panel.dragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            panel.x = mx - panel.dx
            panel.y = my - panel.dy
            saved.x = panel.x
            saved.y = panel.y
            panel.clickEaten = true
        else
            panel.dragging = false
            if SavePersistentState then
                SavePersistentState()
            end
        end
        return
    end

    if builder.dragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            builder.x = mx - builder.dx
            builder.y = my - builder.dy
            saved.builderX = builder.x
            saved.builderY = builder.y
            builder.clickEaten = true
        else
            builder.dragging = false
            if SavePersistentState then
                SavePersistentState()
            end
        end
        return
    end

    if not panel.hovered or not Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then
        if not builder.hovered or not Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then
            return
        end
    end

    if builder.open and builder.hovered then
        local bx = builder.x
        local by = builder.y
        local bw = builder.w
        local builderHeaderH = 24
        local closeSize = 18
        local closeX = bx + bw - closeSize - 7
        local closeY = by + 3

        if PointInRect(mx, my, closeX, closeY, closeSize, closeSize) then
            builder.open = false
            saved.builderOpen = false
            if SavePersistentState then
                SavePersistentState()
            end
            builder.clickEaten = true
            return
        end

        local tabY = by + builderHeaderH + 6
        local tabX = bx + 12
        local tabW = 30
        local tabGap = 5
        if PointInRect(mx, my, tabX, tabY, tabW, 18) then
            SelectCombo(0)
            builder.clickEaten = true
            return
        end

        for i = 1, #combos do
            local tx = tabX + (i * (tabW + tabGap))
            if PointInRect(mx, my, tx, tabY, tabW, 18) then
                SelectCombo(i)
                builder.slot = i
                builder.clickEaten = true
                return
            end
        end

        local iconSize = 32
        local iconGap = 6
        local abilityCols = 6
        local gridW = abilityCols * iconSize + (abilityCols - 1) * iconGap
        local listX = bx + (bw - gridW) * 0.5
        local listY = by + 78
        for index, key in ipairs(abilityOrder) do
            local col = (index - 1) % abilityCols
            local row = math_floor((index - 1) / abilityCols)
            local ix = listX + col * (iconSize + iconGap)
            local iy = listY + row * (iconSize + iconGap)
            if PointInRect(mx, my, ix, iy, iconSize, iconSize) then
                AddAbilityToCombo(builder.slot, key)
                builder.clickEaten = true
                return
            end
        end

        local itemListX, itemListY, itemIconSize, itemIconGap, itemCols = GetItemGridMetrics(bx, by, bw)
        for index, key in ipairs(itemOrder) do
            local col = (index - 1) % itemCols
            local row = math_floor((index - 1) / itemCols)
            local ix = itemListX + col * (itemIconSize + itemIconGap)
            local iy = itemListY + row * (itemIconSize + itemIconGap)
            if PointInRect(mx, my, ix, iy, itemIconSize, itemIconSize) then
                AddAbilityToCombo(builder.slot, key)
                builder.clickEaten = true
                return
            end
        end

        local slotKeys = comboSlots[builder.slot] or {}
        local slotY = by + 307
        local slotIcon = 24
        local slotGap = 3
        local slotRowW = MAX_COMBO_ABILITIES * slotIcon + (MAX_COMBO_ABILITIES - 1) * slotGap
        local slotStartX = bx + (bw - slotRowW) * 0.5
        for i = 1, #slotKeys do
            local ix = slotStartX + (i - 1) * (slotIcon + slotGap)
            if PointInRect(mx, my, ix, slotY, slotIcon, slotIcon) then
                StartSlotDrag("builder", builder.slot, i, mx, my)
                builder.clickEaten = true
                return
            end
        end

        for _, rect in ipairs(GetBuilderEndStanceRects(bx, by, bw)) do
            if PointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                SetEndStance(builder.slot, rect.choice.key)
                builder.clickEaten = true
                return
            end
        end

        local saveDefaultRect = GetBuilderSaveDefaultRect(bx, by, bw)
        if PointInRect(mx, my, saveDefaultRect.x, saveDefaultRect.y, saveDefaultRect.w, saveDefaultRect.h) then
            SaveCurrentCombosAsDefaults()
            builder.clickEaten = true
            return
        end

        if PointInRect(mx, my, bx, by, bw, builderHeaderH) then
            builder.dragging = true
            builder.dx = mx - bx
            builder.dy = my - by
            builder.clickEaten = true
            return
        end

        builder.clickEaten = true
        return
    end

    if not panel.hovered then return end

    local arrowSize = 20
    local arrowX = panel.x + panel.w - arrowSize - 5
    local arrowY = panel.y + 2
    if PointInRect(mx, my, arrowX, arrowY, arrowSize, arrowSize) then
        builder.open = not builder.open
        builder.slot = selectedCombo
        saved.builderOpen = builder.open
        if SavePersistentState then
            SavePersistentState()
        end
        panel.clickEaten = true
        return
    end

    local tabY = panel.y + headerH + 3
    local tabX = panel.x + pad
    local tabW = 25
    local tabGap = 4
    if PointInRect(mx, my, tabX, tabY, tabW, 17) then
        SelectCombo(0)
        panel.clickEaten = true
        return
    end

    for i = 1, #combos do
        local tx = tabX + i * (tabW + tabGap)
        if PointInRect(mx, my, tx, tabY, tabW, 17) then
            SelectCombo(i)
            panel.clickEaten = true
            return
        end
    end

    local panelRow = GetPanelSlotRow()
    local panelSlotIndex = SlotIndexAt(mx, my, panelRow, false)
    if panelSlotIndex then
        StartSlotDrag("panel", selectedCombo, panelSlotIndex, mx, my)
        panel.clickEaten = true
        return
    end

    if PointInRect(mx, my, panel.x, panel.y, panel.w, headerH) then
        panel.dragging = true
        panel.dx = mx - panel.x
        panel.dy = my - panel.y
        panel.clickEaten = true
        return
    end

    panel.clickEaten = true
end

local function DrawText(font, size, text, x, y, color)
    Render.Text(font, size, text, Vec2(x, y), color)
end

local function DrawPanel()
    if not ui.enabled:Get() or not ui.showPanel:Get() then return end
    EnsureFonts()

    local x = math_floor(panel.x)
    local y = math_floor(panel.y)
    local w = panel.w
    local headerH = 24
    local tabH = 19
    local comboBoxH = 32
    local pad = 7
    local h = headerH + tabH + comboBoxH + pad
    panel.h = h

    local mx, my = Input.GetCursorPos()
    local holding = ui.comboKey:IsDown()

    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), Color(11, 14, 20, 232), 6, Enum.DrawFlags.RoundCornersAll)
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), Color(69, 78, 96, 220), 6, Enum.DrawFlags.RoundCornersAll, 1)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + headerH), Color(27, 30, 40, 245), 6, Enum.DrawFlags.RoundCornersTopLeft)
    Render.FilledRect(Vec2(x + w - 6, y), Vec2(x + w, y + headerH), Color(27, 30, 40, 245), 6, Enum.DrawFlags.RoundCornersTopRight)

    if fonts.icon and fonts.icon ~= 0 then
        Render.Image(fonts.icon, Vec2(x + 7, y + 4), Vec2(16, 16), Color(255, 255, 255, 240), 3, Enum.DrawFlags.RoundCornersAll)
    end

    DrawText(fonts.main, 12, "Slot " .. (selectedCombo == 0 and "D" or tostring(selectedCombo)), x + 30, y + 5, Color(235, 240, 247, 255))

    local tapMode = IsTapStepMode()
    local stateText = tapMode and (holding and "RELEASE" or "TAP STEP") or (holding and "RUNNING" or "HOLD KEY")
    local stateColor = holding and Color(72, 214, 132, 255) or Color(204, 177, 92, 255)
    local stateSize = Render.TextSize(fonts.small, 9, stateText)
    DrawText(fonts.small, 9, stateText, x + w - stateSize.x - 31, y + 7, stateColor)

    local tabY = y + headerH + 3
    local tabX = x + pad
    local tabW = 25
    local tabGap = 4
    local dHovered = PointInRect(mx, my, tabX, tabY, tabW, 17)
    ButtonRect(tabX, tabY, tabW, 17, selectedCombo == 0, dHovered)
    DrawText(fonts.small, 9, "D", tabX + 10, tabY + 3, Color(213, 221, 232, 255))

    for i = 1, #combos do
        local tx = tabX + i * (tabW + tabGap)
        local hovered = PointInRect(mx, my, tx, tabY, tabW, 17)
        ButtonRect(tx, tabY, tabW, 17, i == selectedCombo, hovered)
        DrawText(fonts.small, 9, tostring(i), tx + 10, tabY + 3, Color(237, 242, 248, 255))
    end

    local combo = combos[selectedCombo]
    local boxX = x + pad
    local boxY = tabY + tabH
    local boxW = w - pad * 2
    local boxH = comboBoxH
    Render.FilledRect(Vec2(boxX, boxY), Vec2(boxX + boxW, boxY + boxH), Color(17, 22, 31, 230), 5, Enum.DrawFlags.RoundCornersAll)
    Render.Rect(Vec2(boxX, boxY), Vec2(boxX + boxW, boxY + boxH), Color(55, 76, 96, 230), 5, Enum.DrawFlags.RoundCornersAll, 1)

    local arrowSize = 20
    local arrowX = x + w - arrowSize - 5
    local arrowY = y + 2
    local arrowHovered = PointInRect(mx, my, arrowX, arrowY, arrowSize, arrowSize)
    ButtonRect(arrowX, arrowY, arrowSize, arrowSize, builder.open, arrowHovered)
    DrawText(fonts.main, 15, ">", arrowX + 7, arrowY + 1, Color(235, 240, 247, 255))

    if combo then
        local keys = comboSlots[selectedCombo] or {}
        local iconSize = 24
        local iconGap = 1
        local startX = boxX + 5
        local iconY = boxY + 4
        for i = 1, MAX_COMBO_ABILITIES do
            local key = keys[i]
            local ix = startX + (i - 1) * (iconSize + iconGap)
            if ix + iconSize <= boxX + boxW - 1 then
                if key then
                    DrawAbilityIcon(key, ix, iconY, iconSize, true, {
                        disabled = IsDisabledItem(selectedCombo, i),
                        cooldown = GetCooldownForKey(key),
                    })
                else
                    Render.FilledRect(Vec2(ix, iconY), Vec2(ix + iconSize, iconY + iconSize), Color(19, 24, 32, 190), 4, Enum.DrawFlags.RoundCornersAll)
                    Render.Rect(Vec2(ix, iconY), Vec2(ix + iconSize, iconY + iconSize), Color(42, 50, 64, 190), 4, Enum.DrawFlags.RoundCornersAll, 1)
                end
            end
        end
    end
end

local function DrawBuilder()
    if not builder.open or not ui.enabled:Get() or not ui.showPanel:Get() then return end
    EnsureFonts()

    local x = math_floor(builder.x)
    local y = math_floor(builder.y)
    local w = builder.w
    local h = builder.h
    local mx, my = Input.GetCursorPos()

    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), Color(12, 14, 20, 238), 6, Enum.DrawFlags.RoundCornersAll)
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), Color(69, 78, 96, 225), 6, Enum.DrawFlags.RoundCornersAll, 1)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + 24), Color(27, 30, 40, 250), 6, Enum.DrawFlags.RoundCornersTopLeft)
    Render.FilledRect(Vec2(x + w - 6, y), Vec2(x + w, y + 24), Color(27, 30, 40, 250), 6, Enum.DrawFlags.RoundCornersTopRight)
    DrawText(fonts.main, 13, "Invoker Combo Builder", x + 10, y + 5, Color(235, 240, 247, 255))

    local closeSize = 18
    local closeX = x + w - closeSize - 7
    local closeY = y + 3
    ButtonRect(closeX, closeY, closeSize, closeSize, false, PointInRect(mx, my, closeX, closeY, closeSize, closeSize))
    DrawText(fonts.main, 12, "x", closeX + 6, closeY + 1, Color(218, 225, 234, 255))

    local tabY = y + 30
    local tabX = x + 12
    local tabW = 30
    local tabGap = 5
    ButtonRect(tabX, tabY, tabW, 18, builder.slot == 0, PointInRect(mx, my, tabX, tabY, tabW, 18))
    DrawText(fonts.small, 9, "D", tabX + 12, tabY + 3, Color(225, 231, 240, 255))
    for i = 1, #combos do
        local tx = tabX + i * (tabW + tabGap)
        ButtonRect(tx, tabY, tabW, 18, i == builder.slot, PointInRect(mx, my, tx, tabY, tabW, 18))
        DrawText(fonts.small, 9, tostring(i), tx + 12, tabY + 3, Color(238, 243, 249, 255))
    end

    local label = "Abilities List"
    local labelSize = Render.TextSize(fonts.main, 12, label)
    DrawText(fonts.main, 12, label, x + (w - labelSize.x) * 0.5, y + 56, Color(173, 181, 195, 255))

    local iconSize = 32
    local iconGap = 6
    local abilityCols = 6
    local gridW = abilityCols * iconSize + (abilityCols - 1) * iconGap
    local listX = x + (w - gridW) * 0.5
    local listY = y + 78
    for index, key in ipairs(abilityOrder) do
        local col = (index - 1) % abilityCols
        local row = math_floor((index - 1) / abilityCols)
        local ix = listX + col * (iconSize + iconGap)
        local iy = listY + row * (iconSize + iconGap)
        local hovered = PointInRect(mx, my, ix, iy, iconSize, iconSize)
        DrawAbilityIcon(key, ix, iy, iconSize, hovered)
    end

    local itemLabel = "Items List"
    local itemLabelSize = Render.TextSize(fonts.main, 12, itemLabel)
    DrawText(fonts.main, 12, itemLabel, x + (w - itemLabelSize.x) * 0.5, y + 158, Color(173, 181, 195, 255))

    local itemListX, itemListY, itemIconSize, itemIconGap, itemCols = GetItemGridMetrics(x, y, w)
    for index, key in ipairs(itemOrder) do
        local col = (index - 1) % itemCols
        local row = math_floor((index - 1) / itemCols)
        local ix = itemListX + col * (itemIconSize + itemIconGap)
        local iy = itemListY + row * (itemIconSize + itemIconGap)
        local hovered = PointInRect(mx, my, ix, iy, itemIconSize, itemIconSize)
        DrawAbilityIcon(key, ix, iy, itemIconSize, hovered)
    end

    local slotTitle = "Combo Slot " .. (builder.slot == 0 and "D" or tostring(builder.slot))
    local slotTitleSize = Render.TextSize(fonts.main, 12, slotTitle)
    DrawText(fonts.main, 12, slotTitle, x + (w - slotTitleSize.x) * 0.5, y + 284, Color(173, 181, 195, 255))

    local keys = comboSlots[builder.slot] or {}
    local slotIcon = 24
    local slotGap = 3
    local slotY = y + 307
    local rowW = MAX_COMBO_ABILITIES * slotIcon + (MAX_COMBO_ABILITIES - 1) * slotGap
    local startX = x + (w - rowW) * 0.5
    for i = 1, MAX_COMBO_ABILITIES do
        local ix = startX + (i - 1) * (slotIcon + slotGap)
        local key = keys[i]
        if key then
            DrawAbilityIcon(key, ix, slotY, slotIcon, PointInRect(mx, my, ix, slotY, slotIcon, slotIcon), {
                disabled = IsDisabledItem(builder.slot, i),
                cooldown = GetCooldownForKey(key),
            })
        else
            Render.FilledRect(Vec2(ix, slotY), Vec2(ix + slotIcon, slotY + slotIcon), Color(19, 24, 32, 190), 4, Enum.DrawFlags.RoundCornersAll)
            Render.Rect(Vec2(ix, slotY), Vec2(ix + slotIcon, slotY + slotIcon), Color(42, 50, 64, 190), 4, Enum.DrawFlags.RoundCornersAll, 1)
        end
    end

    local stanceLabel = "After Stop Orbs"
    local stanceLabelSize = Render.TextSize(fonts.small, 10, stanceLabel)
    DrawText(fonts.small, 10, stanceLabel, x + (w - stanceLabelSize.x) * 0.5, y + 339, Color(173, 181, 195, 255))

    local chosenStance = NormalizeEndStance(endStances[builder.slot])
    for _, rect in ipairs(GetBuilderEndStanceRects(x, y, w)) do
        local choice = rect.choice
        local hovered = PointInRect(mx, my, rect.x, rect.y, rect.w, rect.h)
        ButtonRect(rect.x, rect.y, rect.w, rect.h, choice.key == chosenStance, hovered)
        local labelSize = Render.TextSize(fonts.small, 9, choice.label)
        DrawText(fonts.small, 9, choice.label, rect.x + (rect.w - labelSize.x) * 0.5, rect.y + 3, Color(238, 243, 249, 255))
    end

    local saveRect = GetBuilderSaveDefaultRect(x, y, w)
    local saveHovered = PointInRect(mx, my, saveRect.x, saveRect.y, saveRect.w, saveRect.h)
    local now = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
    local savedRecently = builder.savedAt and builder.savedAt > 0 and now - builder.savedAt < 1.4
    ButtonRect(saveRect.x, saveRect.y, saveRect.w, saveRect.h, savedRecently, saveHovered)
    local saveLabel = savedRecently and "Saved" or "Save Default"
    local saveLabelSize = Render.TextSize(fonts.small, 9, saveLabel)
    DrawText(fonts.small, 9, saveLabel, saveRect.x + (saveRect.w - saveLabelSize.x) * 0.5, saveRect.y + 3, Color(238, 243, 249, 255))

end

local function DrawSlotDragPreview()
    if not slotDrag.active or not slotDrag.key then return end
    EnsureFonts()
    local mx, my = Input.GetCursorPos()
    DrawAbilityIcon(slotDrag.key, mx - 12, my - 12, 24, true, {
        disabled = slotDrag.comboIndex > 0 and IsDisabledItem(slotDrag.comboIndex, slotDrag.fromIndex),
    })
end

local function DrawTargetText()
    if not ui.drawTarget:Get() or not target or not TargetAlive(target) then return end
    EnsureFonts()

    local pos = Entity.GetAbsOrigin(target)
    local screen, visible = Render.WorldToScreen(pos)
    if not visible then return end

    local text = combos[selectedCombo] and combos[selectedCombo].name or "Invoker Combo"
    local size = Render.TextSize(fonts.main, 14, text)
    local tx = screen.x - size.x * 0.5
    local ty = screen.y - 78
    Render.Text(fonts.main, 14, text, Vec2(tx + 1, ty + 1), Color(0, 0, 0, 210))
    Render.Text(fonts.main, 14, text, Vec2(tx, ty), Color(255, 82, 72, 255))
end

function InvokerComboPanel.OnUpdate()
    if Engine and Engine.IsInGame and not Engine.IsInGame() then
        comboWasHeld = false
        tapLastStepTime = 0
        ClearTapPending()
        ClearPendingEndOrb()
        ResetCombo()
        return
    end

    hero = Heroes.GetLocal()
    player = Players.GetLocal()
    if not ui.enabled:Get() or not IsLocalInvokerPicked() or not player then
        comboWasHeld = false
        tapLastStepTime = 0
        ClearTapPending()
        ClearPendingEndOrb()
        ResetCombo()
        panel.dragging = false
        panel.hovered = false
        panel.clickEaten = false
        builder.dragging = false
        builder.hovered = false
        builder.clickEaten = false
        slotDrag.active = false
        return
    end

    HandlePanelInput()

    if not IsInvoker(hero) then
        comboWasHeld = false
        tapLastStepTime = 0
        ClearTapPending()
        ClearPendingEndOrb()
        ResetCombo()
        return
    end

    local now = GameRules.GetGameTime()
    DebugProcessControls(now)
    ProcessSlotBinds()

    local holdingCombo = ui.comboKey:IsDown()

    if IsTapStepMode() then
        holdComboComplete = false
        ProcessTapStepMode(now, holdingCombo)
        return
    end

    ClearTapPending()

    if DebugEnabled() and not holdingCombo then
        RefreshAim(now)
        DebugSampleTarget(now)
    end

    if not holdingCombo then
        if comboWasHeld then
            local releaseSlot = activeCombo > 0 and activeCombo or selectedCombo
            DebugLogEvent("combo_release", {
                release_slot = releaseSlot,
                combo = combos[releaseSlot] and combos[releaseSlot].name or "unknown",
                target = TargetAlive(target) and DebugUnitName(target) or "none",
            })
            ApplyEndStance(releaseSlot, now)
        end
        comboWasHeld = false
        ProcessPendingEndStance(now)
        ResetCombo()
        return
    end

    comboWasHeld = true
    tapLastStepTime = 0
    ClearPendingEndOrb()

    if activeCombo ~= selectedCombo then
        comboState = 0
        lastAction = 0
        activeCombo = selectedCombo
        holdComboComplete = false
        DebugLogEvent("combo_start", {
            active_combo = activeCombo,
            combo = combos[activeCombo] and combos[activeCombo].name or "unknown",
            combo_string = combos[activeCombo] and combos[activeCombo].short or "",
        })
    end

    RefreshAim(now)

    ManageTargetParticle()
    DebugSampleTarget(now)

    if holdComboComplete then
        if now >= lastAction then
            AttackTarget(target)
            DebugLogEvent("combo_auto_attack", {
                target = TargetAlive(target) and DebugUnitName(target) or "none",
            }, "combo_auto_attack", 0.35)
            lastAction = now + 0.35
        end
        return
    end

    if now < lastAction then return end

    local result = RunComboStep(now)
    if result == "complete" then
        DebugLogEvent("combo_complete", {
            target = TargetAlive(target) and DebugUnitName(target) or "none",
        })
        holdComboComplete = true
    end
end

function InvokerComboPanel.OnDraw()
    if Engine and Engine.IsInGame and not Engine.IsInGame() then return end
    if not ui.enabled:Get() or not IsLocalInvokerPicked() then return end
    DrawPanel()
    DrawBuilder()
    DrawSlotDragPreview()
    DrawTargetText()
    DrawDebugOverlay()
end

function InvokerComboPanel.OnProjectile(proj)
    if not DebugEnabled() then return end
    if not proj then return end
    if Heroes and Heroes.GetLocal and not IsInvoker(Heroes.GetLocal()) then return end

    local abilityName = DebugAbilityName(proj.ability)
    local fxText = tostring(proj.name or "") .. " " .. tostring(proj.fullName or "") .. " " .. abilityName
    if not DebugRelevantFxText(fxText) then return end

    DebugLogEvent("projectile", {
        name = tostring(proj.name or "nil"),
        full_name = tostring(proj.fullName or "nil"),
        ability = abilityName,
        source = proj.source and DebugUnitName(proj.source) or "nil",
        target = proj.target and DebugUnitName(proj.target) or "nil",
        target_loc = DebugPositionText(proj.target_loc),
        speed = DebugNumber(tonumber(proj.moveSpeed) or 0),
        expire = DebugNumber(tonumber(proj.expireTime) or 0),
        max_impact = DebugNumber(tonumber(proj.maxImpactTime) or 0),
    }, "projectile_" .. tostring(proj.handle or proj.name or abilityName), 0.05)
end

function InvokerComboPanel.OnParticleCreate(particle)
    if not DebugEnabled() then return end
    if not particle then return end
    if Heroes and Heroes.GetLocal and not IsInvoker(Heroes.GetLocal()) then return end

    local text = DebugParticleText(particle)
    if not DebugRelevantFxText(text) then return end

    local now = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
    debugState.particles[particle.index] = {
        created = now,
        name = tostring(particle.name or ""),
        fullName = tostring(particle.fullName or ""),
    }

    DebugLogEvent("particle_create", {
        index = tostring(particle.index),
        name = tostring(particle.name or "nil"),
        full_name = tostring(particle.fullName or "nil"),
        entity = particle.entity and DebugUnitName(particle.entity) or "nil",
        entity_mod = particle.entityForModifiers and DebugUnitName(particle.entityForModifiers) or "nil",
    })
end

function InvokerComboPanel.OnParticleUpdate(particle)
    if not DebugEnabled() then return end
    if not particle or not debugState.particles[particle.index] then return end
    if Heroes and Heroes.GetLocal and not IsInvoker(Heroes.GetLocal()) then return end

    DebugLogEvent("particle_update", {
        index = tostring(particle.index),
        cp = tostring(particle.controlPoint or "nil"),
        pos = DebugPositionText(particle.position),
    }, "particle_update_" .. tostring(particle.index) .. "_" .. tostring(particle.controlPoint or 0), 0.15)
end

function InvokerComboPanel.OnParticleDestroy(particle)
    if not DebugEnabled() then return end
    if not particle or not debugState.particles[particle.index] then return end
    if Heroes and Heroes.GetLocal and not IsInvoker(Heroes.GetLocal()) then return end

    local now = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
    local data = debugState.particles[particle.index]

    DebugLogEvent("particle_destroy", {
        index = tostring(particle.index),
        name = data.name,
        full_name = data.fullName,
        lifetime = DebugNumber(now - (data.created or now)),
        destroy_immediate = tostring(particle.destroyImmediately),
    })

    debugState.particles[particle.index] = nil
end

function InvokerComboPanel.OnPrepareUnitOrders()
    if not IsLocalInvokerPicked() then return true end
    if slotDrag.active or panel.hovered or panel.clickEaten or builder.hovered or builder.clickEaten then
        return false
    end
    return true
end

function InvokerComboPanel.OnGameEnd()
    DebugLogEvent("game_end", {
        lines = debugState.lineCount,
    })
    comboWasHeld = false
    tapLastStepTime = 0
    ClearTapPending()
    ClearPendingEndOrb()
    ResetCombo()
    panel.dragging = false
    panel.hovered = false
    panel.clickEaten = false
    builder.dragging = false
    builder.hovered = false
    builder.clickEaten = false
    slotDrag.active = false
    slotDrag.source = nil
    slotDrag.comboIndex = 0
    slotDrag.fromIndex = 0
    slotDrag.key = nil
end

return InvokerComboPanel
