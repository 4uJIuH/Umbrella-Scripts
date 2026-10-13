local fog_enabled = true
local last_apply_time = 0
local apply_interval = 1.0
local initialized = false

local group = Menu.Create(
    "Fog Restorer",
    "World",
    "Fog",
    "Settings",
    "Fog Control"
)

local fog_switch = group:Switch("Restore Fog", true)
local log_btn = group:Button("Log Current Values", function(this)
    log_all_cvars()
    Render.CenteredNotification("Values logged to console", 2.0)
end)
local apply_btn = group:Button("Apply Defaults Now", function(this)
    apply_fog()
    Render.CenteredNotification("Fog: Applied", 2.0)
end)

-- { name, default_int, default_float }
local cvar_list = {

    { name = "fow_client_visibility",        default_int = 0 },
    { name = "fow_client_nofiltering",       default_int = 0 },
    { name = "r_dota_unseen_fow",            default_int = 1 },
    { name = "fow_degree_fade_in_rate1",     default_int = 4 },
    { name = "fow_degree_fade_in_rate2",     default_int = 4 },
    { name = "fow_degree_fade_out_rate1",    default_int = 4 },
    { name = "fow_degree_fade_out_rate2",    default_int = 4 },

    { name = "r_deferred_height_fog",        default_int = 1 },
    { name = "dota_height_fog_scale",        default_int = 1 },

    { name = "fog_enable",                   default_int = 1 },
    { name = "fog_override",                 default_int = 0 },
    { name = "fog_override_enable",           default_int = 0 },
    { name = "fog_override_max_density",     default_int = 0 },
    { name = "fog_override_start",           default_int = 1000 },
    { name = "fog_override_end",             default_int = 3500 },

    { name = "volume_fog_disable",           default_int = 0 },
    { name = "volume_fog_clipmaps_enabled",  default_int = 1 },
    { name = "volume_fog_enable_jitter",     default_int = 1 },

    { name = "r_dota_height_fog_exclusion_radius", default_int = 2200 },
    { name = "r_dota_caustic_fog_exclusion_radius", default_int = 3000 },
}


function log_all_cvars()
    Engine.ConsoleColorPrintf(0, 255, 0, 255, "===== FOG/FOW CVAR DUMP =====")
    for _, c in ipairs(cvar_list) do
        local cv = ConVar.Find(c.name)
        if cv then
            local val = ConVar.GetInt(cv)
            Engine.ConsoleColorPrintf(255, 255, 0, 255,
                string.format("  %s = %d (default: %d) %s",
                    c.name, val, c.default_int,
                    val ~= c.default_int and " <<< CHANGED" or ""
                )
            )
        else
            Engine.ConsoleColorPrintf(150, 150, 150, 255,
                string.format("  %s = (not found)", c.name)
            )
        end
    end
    Engine.ConsoleColorPrintf(0, 255, 0, 255, "===== END DUMP =====")
end

function apply_fog()
    for _, c in ipairs(cvar_list) do
        local cv = ConVar.Find(c.name)
        if cv then
            ConVar.SetInt(cv, c.default_int)
        end
    end
end

local function on_toggle()
    fog_enabled = fog_switch:Get()
    if fog_enabled then
        apply_fog()
        last_apply_time = GameRules.GetGameTime()
        Render.CenteredNotification("Fog: ON", 2.0)
    else
        Render.CenteredNotification("Fog: OFF (values left as-is)", 2.0)
    end
end

fog_switch:SetCallback(on_toggle, true)

return {
    OnScriptsLoaded = function()
        Engine.ConsoleColorPrintf(0, 255, 255, 255, ">>> Fog Restorer: loading, dumping current values...")
        log_all_cvars()

        apply_fog()
        initialized = true
        last_apply_time = GameRules.GetGameTime()

        Engine.ConsoleColorPrintf(0, 255, 255, 255, ">>> Fog Restorer: applied defaults. Check console for dump.")
        Render.CenteredNotification("Fog Restorer: Loaded", 3.0)
    end,

    OnUpdate = function()
        if not fog_enabled then return end
        if not initialized then return end

        local current_time = GameRules.GetGameTime()
        if current_time - last_apply_time >= apply_interval then
            apply_fog()
            last_apply_time = current_time
        end
    end,

    OnGameEnd = function()
        initialized = false
        last_apply_time = 0
    end,
}
