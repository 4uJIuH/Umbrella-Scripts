-- by m0rc1

local VERSION = "1.0.0"
local script = {}

local JSON = nil
pcall(function() JSON = require("assets.JSON") end)
if not JSON then pcall(function() JSON = _G.JSON end) end

Menu.Create("Changer", "Main", "Сетки"):Icon("\u{f009}")
local group = Menu.Create("Changer", "Main", "Сетки", "Main", "Сетки")

local ui_file = group:Input("Файл (.json)", "hero_grid_config.json")

local function GetPaths(filename)
    local base = (Engine and Engine.GetCheatDirectory and Engine.GetCheatDirectory()) or ""
    base = base:gsub("[/\\]+$", "")
    return {
        base .. "\\scripts\\hero-grid\\" .. filename,
        base .. "/scripts/hero-grid/" .. filename,
        base .. "\\scripts\\hero_grid\\" .. filename,
        base .. "/scripts/hero_grid/" .. filename,
        base .. "\\scripts\\" .. filename,
        base .. "/scripts/" .. filename,
        "scripts/hero-grid/" .. filename,
        "scripts\\hero-grid\\" .. filename,
        "scripts/" .. filename,
        "scripts\\" .. filename
    }
end

local function LoadGrid(filename)
    if not JSON then return end
    if not filename:find("%.json$") then
        filename = filename .. ".json"
    end

    local f = nil
    for _, p in ipairs(GetPaths(filename)) do
        f = io.open(p, "r")
        if f then break end
    end
    if not f then return end

    local content = f:read("*a")
    f:close()
    if not content or #content == 0 then return end

    local ok, data = pcall(function() return JSON:decode(content) end)
    if not ok or type(data) ~= "table" then return end

    local configs = data.configs or (data.categories and { data }) or {}
    local first_title = nil

    for _, cfg in ipairs(configs) do
        local title = cfg.config_name or "Custom Grid"
        if not first_title then first_title = title end
        local cats = {}
        for _, cat in ipairs(cfg.categories or {}) do
            table.insert(cats, {
                name = cat.category_name or "",
                x = tonumber(cat.x_position) or 0,
                y = tonumber(cat.y_position) or 0,
                width = tonumber(cat.width) or 30,
                height = tonumber(cat.height) or 30,
                hero_ids = cat.hero_ids or {}
            })
        end
        Engine.CreateConfig(title, cats)
    end

    if first_title then
        Engine.SetNewGridConfig(first_title)
    end
end

group:Button("Загрузить сетку", function()
    local name = ui_file and ui_file:Get() or "hero_grid_config.json"
    if not name or #name == 0 then name = "hero_grid_config.json" end
    LoadGrid(name)
end)

return script