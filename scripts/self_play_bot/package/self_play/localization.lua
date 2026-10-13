local localization = {}
local translations = require("self_play.translations")

local state = {language = "en", entries = {}, listeners = {}}

function localization.text(key)
	local entry = translations[key]
	return entry and (entry[state.language] or entry.en) or key
end

local function apply(entry)
	entry.widget:ForceLocalization(localization.text(entry.key))
	if entry.options then
		local selected, options = entry.widget:Get(), {}
		for index, key in ipairs(entry.options) do options[index] = localization.text(key) end
		entry.widget:Update(options, selected)
		entry.widget:Set(selected)
	end
	if entry.tooltip then entry.widget:ToolTip(localization.text(entry.tooltip)) end
end

function localization.bind(widget, key, options, tooltip)
	local entry = {widget = widget, key = key, options = options, tooltip = tooltip}
	state.entries[#state.entries + 1] = entry
	apply(entry)
	return widget
end

function localization.listen(callback)
	state.listeners[#state.listeners + 1] = callback
	callback()
end

function localization.language(code)
	if state.language == code then return end
	state.language = code
	for _, entry in ipairs(state.entries) do apply(entry) end
	for _, callback in ipairs(state.listeners) do callback() end
end

function localization.init()
	if state.languageWidget then return end
	local language = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
	if not language then return end
	state.languageWidget = language
	local function update()
		local name = language:List()[language:Get() + 1]
		local code = name and name:match("%a+")
		localization.language(code and code:lower() or "en")
	end
	language:SetCallback(update)
	update()
end

function localization.group(group)
	local wrapped = {}
	function wrapped:Create(name, ...)
		local child = group:Create(name, ...)
		if child:Type() == Enum.WidgetType.MenuGroup then localization.bind(child, name) end
		return localization.group(child)
	end
	function wrapped:Combo(name, options, ...)
		return localization.bind(group:Combo(name, options, ...), name, options)
	end
	for _, method in ipairs({"Switch", "Bind", "Label", "MultiSelect", "MultiCombo", "Slider", "Button"}) do
		wrapped[method] = function(_, name, ...)
			return localization.bind(group[method](group, name, ...), name)
		end
	end
	function wrapped:Input(name, default)
		return group.Input(group, name, default)
	end
	return wrapped
end

function localization.queue(status)
	local base, seconds = status:match("^(.-) %((%d+)s%)$")
	if base then return localization.queue(base) .. " (" .. seconds .. localization.text("s)") end
	local mode = status:match("^Requesting (.+)$")
	if mode then return localization.text("Requesting ") .. localization.text(mode) end
	local reason = status:match("^Queue rejected: (.-); retry$")
	if reason then return localization.text("Queue rejected: ") .. reason .. localization.text("; retry") end
	return localization.text(status)
end

return localization
