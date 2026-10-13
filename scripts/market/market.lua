local market = {}

local json = require("assets.JSON")

-- Configuration
local SCRIPTS_JSON_URL = "https://raw.githubusercontent.com/madonchik123/ScriptIvMarket/refs/heads/main/scripts.json"
local MARKET_UPDATE_URL = "https://raw.githubusercontent.com/madonchik123/ScriptIvMarket/refs/heads/main/market.lua"
local CONFIG_FILE = "market"
local scriptsData = {}
local installedScripts = {}

-- Some simple shit
local function parseJSON(str)
  return json:decode(str)
end

-- Function to save scripts data to config
local function saveScriptsData()
  for scriptName, scriptUrl in pairs(scriptsData) do
    Config.WriteString(CONFIG_FILE, "script_" .. scriptName, scriptUrl)
  end
  local scriptsList = ""
  for scriptName, _ in pairs(scriptsData) do
    if scriptsList == "" then
      scriptsList = scriptName
    else
      scriptsList = scriptsList .. "," .. scriptName
    end
  end
  Config.WriteString(CONFIG_FILE, "Market_Scripts", scriptsList)
end

-- Function to load scripts data from config
local function loadScriptsData()
  scriptsData = {}
  local scriptsList = Config.ReadString(CONFIG_FILE, "Market_Scripts", "")
  if scriptsList ~= "" then
    for scriptName in scriptsList:gmatch("([^,]+)") do
      local scriptUrl = Config.ReadString(CONFIG_FILE, "script_" .. scriptName, "")
      if scriptUrl ~= "" then
        scriptsData[scriptName] = scriptUrl
      end
    end
    local count = 0
    for _ in pairs(scriptsData) do count = count + 1 end
    Log.Write("[Market] Loaded " .. tostring(count) .. " scripts from config")
  end
end

-- Function to save installed scripts to config
local function saveInstalledScripts()
  for scriptName, _ in pairs(installedScripts) do
    Config.WriteString(CONFIG_FILE, "installed_" .. scriptName, "true")
  end
  for scriptName, _ in pairs(scriptsData) do
    if not installedScripts[scriptName] then
      Config.WriteString(CONFIG_FILE, "installed_" .. scriptName, "false")
    end
  end
end

-- Function to load installed scripts from config
local function loadInstalledScripts()
  installedScripts = {}
  for scriptName, _ in pairs(scriptsData) do
    local isInstalled = Config.ReadString(CONFIG_FILE, "installed_" .. scriptName, "false")
    if isInstalled == "true" then
      installedScripts[scriptName] = true
    end
  end
end

-- Function to update the market script itself
local function updateMarket()
  Log.Write("[Market] Updating market script...")
  local headers = {
    ["User-Agent"] = "Umbrella/1.0",
    ['Connection'] = 'Keep-Alive',
  }
  HTTP.Request("GET", MARKET_UPDATE_URL, {
    headers = headers,
  }, function(response)
    if response.code == 200 and response.response then
      local filename = Engine.GetCheatDirectory() .. "/scripts/market.lua"
      local file = io.open(filename, "w")
      if file then
        file:write(response.response)
        file:close()
        Log.Write("[Market] Successfully updated market script!")
        Log.Write("[Market] Reloading script system...")
        Engine.ReloadScriptSystem()
      else
        Log.Write("[Market] Failed to update market script file")
      end
    else
      Log.Write("[Market] Failed to download market update. Status: " .. tostring(response.code))
    end
  end, "update_market")
end

-- Function to update all installed scripts
local function updateAllScripts(calledby)
  Log.Write("[Market] Updating all installed scripts...")
  for scriptName, _ in pairs(installedScripts) do
    if scriptsData[scriptName] then
      local scriptUrl = scriptsData[scriptName]
      Log.Write("[Market] Updating script: " .. scriptName)
      local headers = {
        ["User-Agent"] = "Umbrella/1.0",
        ['Connection'] = 'Keep-Alive',
      }
      HTTP.Request("GET", scriptUrl, {
        headers = headers,
      }, function(response)
        if response.code == 200 and response.response then
          local filename = Engine.GetCheatDirectory() .. "/scripts/" .. scriptName .. ".lua"
          local file = io.open(filename, "w")
          if file then
            file:write(response.response)
            file:close()
            Log.Write("[Market] Successfully updated: " .. scriptName)
          else
            Log.Write("[Market] Failed to update file for: " .. scriptName)
          end
        else
          Log.Write("[Market] Failed to update script: " .. scriptName .. ". Status: " .. tostring(response.code))
        end
      end, "update_" .. scriptName)
    end
  end
  if calledby then
    Engine.ReloadScriptSystem()
  end
end

-- Function to fetch and parse scripts.json from GitHub
local function fetchScriptsData()
  Log.Write("[Market] Fetching scripts data...")
  local headers = {
    ["User-Agent"] = "Umbrella/1.0",
    ['Connection'] = 'Keep-Alive',
  }
  HTTP.Request("GET", SCRIPTS_JSON_URL, {
    headers = headers,
  }, function(response)
    if response.code == 200 and response.response then
      local success, data = pcall(parseJSON, response.response)
      if success and data then
        scriptsData = data
        local count = 0
        for _ in pairs(scriptsData) do count = count + 1 end
        Log.Write("[Market] Successfully fetched " .. tostring(count) .. " scripts")
        saveScriptsData()
        loadInstalledScripts()
        createMarketButtons()
        createInstalledButtons()
        if next(installedScripts) ~= nil then
          local installedCount = 0
          for _ in pairs(installedScripts) do installedCount = installedCount + 1 end
          if Engine.IsInGame() then return end
          Log.Write("[Market] Auto-updating " .. tostring(installedCount) .. " installed scripts...")
          updateAllScripts()
        end
      else
        Log.Write("[Market] Failed to parse JSON data")
      end
    else
      Log.Write("[Market] Failed to fetch scripts data. Status: " .. tostring(response.code))
    end
  end, "fetch_scripts")
end

-- Function to download and install a script
local function installScript(scriptName, scriptUrl)
  Log.Write("[Market] Installing script: " .. scriptName)
  local headers = {
    ["User-Agent"] = "Umbrella/1.0",
    ['Connection'] = 'Keep-Alive',
  }
  HTTP.Request("GET", scriptUrl, {
    headers = headers,
  }, function(response)
    if response.code == 200 and response.response then
      local filename = Engine.GetCheatDirectory() .. "/scripts/" .. scriptName .. ".lua"
      local file = io.open(filename, "w")
      if file then
        file:write(response.response)
        file:close()
        installedScripts[scriptName] = true
        saveInstalledScripts()
        Log.Write("[Market] Successfully installed: " .. scriptName)
        Engine.ReloadScriptSystem()
      else
        Log.Write("[Market] Failed to create file for: " .. scriptName)
      end
    else
      Log.Write("[Market] Failed to download script: " .. scriptName .. ". Status: " .. tostring(response.code))
    end
  end, "install_" .. scriptName)
end

-- Function to delete an installed script
local function deleteScript(scriptName)
  Log.Write("[Market] Deleting script: " .. scriptName)
  local filename = Engine.GetCheatDirectory() .. "/scripts/" .. scriptName .. ".lua"
  local success = os.remove(filename)
  if success then
    installedScripts[scriptName] = nil
    saveInstalledScripts()
    Log.Write("[Market] Successfully deleted: " .. scriptName)
    Engine.ReloadScriptSystem()
    return true
  else
    Log.Write("[Market] Failed to delete: " .. scriptName)
    return false
  end
end

-- Function to check if script is installed
local function isScriptInstalled(scriptName)
  local filename = Engine.GetCheatDirectory() .. "/scripts/" .. scriptName .. ".lua"
  local file = io.open(filename, "r")
  if file then
    file:close()
    return true
  end
  return false
end

-- Create menu structure
local scriptsMenu = Menu.Create("Scripts", "Other", "Market")
scriptsMenu:Icon("\u{f54e}") -- store

local mainMenu = scriptsMenu:Create("Main")
mainMenu:Icon("\u{f0c9}") -- bars (menu)

local Market = mainMenu:Create("Market")
local Installed = mainMenu:Create("Installed Scripts")

-- Create update all button
local updateAllButton = Installed:Button("Update All Scripts", function()
  updateAllScripts(true)
end)
updateAllButton:Icon("\u{f021}") -- sync/refresh

-- Create market update button
local Label = Market:Label("Больше скриптов в тг https://t.me/ScriptIv")
local updateMarketButton = Market:Button("Update Market", function()
  updateMarket()
end)
updateMarketButton:Icon("\u{f062}") -- arrow-up

-- Function to create market install buttons
function createMarketButtons()
  for scriptName, scriptUrl in pairs(scriptsData) do
    if not isScriptInstalled(scriptName) then
      local btn = Market:Button("Install " .. scriptName, function()
        installScript(scriptName, scriptUrl)
      end)
      btn:Icon("\u{f019}")
    end
  end
end

function createInstalledButtons()
  for scriptName, _ in pairs(scriptsData) do
    if isScriptInstalled(scriptName) then
      local btn = Installed:Button("Delete " .. scriptName, function()
        deleteScript(scriptName)
      end)
      btn:Icon("\u{f1f8}")
    end
  end
end

-- OnScriptsLoaded callback - automatically update all scripts
market.OnScriptsLoaded = function()
  Log.Write("[Market] Scripts loaded - loading cached data and updating installed scripts...")
  loadScriptsData()
  loadInstalledScripts()
  fetchScriptsData()
end

createMarketButtons()
createInstalledButtons()

return market
