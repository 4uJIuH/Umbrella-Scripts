local spoofer = {}

local cfg = {
	pages_id = "DashboardPages",
	walk_depth = 35,
	walk_limit = 20000,
}

local ui, state = {}, {
	matches = {},
	items = {},
	history = {},
}

local function utf8_len(str)
	if not str then return 0 end
	local len = 0
	for _ in tostring(str):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		len = len + 1
	end
	return len
end

local function utf8_sub(str, start_char, end_char)
	if not str then return "" end
	local chars = {}
	for char in tostring(str):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		chars[#chars + 1] = char
	end
	local res = {}
	for i = start_char, math.min(end_char, #chars) do
		res[#res + 1] = chars[i]
	end
	return table.concat(res, "")
end

local function get_digits(str)
	if not str then return "" end
	local res = {}
	for digit in tostring(str):gmatch("%d") do
		res[#res + 1] = digit
	end
	return table.concat(res, "")
end

local function safe_text(panel)
	if not panel or not panel:GetPanelType() or not panel:GetPanelType():find("Label") then
		return ""
	end
	return panel:GetText() or ""
end

local function walk(root, fn)
	local visited = 0
	local function step(node, depth)
		if not node or depth > cfg.walk_depth or visited > cfg.walk_limit then
			return
		end
		visited = visited + 1
		if fn(node) == false then
			return
		end

		for i = 0, node:GetChildCount() - 1 do
			step(node:GetChild(i), depth + 1)
		end
	end
	step(root, 0)
end

local function get_root()
	local pages = Panorama.GetPanelByName(cfg.pages_id, false)
	if not pages then return nil end
	local root = pages
	while root:GetParent() do
		root = root:GetParent()
	end
	return root
end

local function is_target_panel(node)
	if not node then return false end
	if node:IsVisible() then return true end

	local parent = node:GetParent()
	local depth = 0
	while parent and depth < 8 do
		local id = parent:GetID() or ""
		if id == "DashboardPages" or id:find("Compendium") or id:find("Fantasy") or id:find("Predictions") then
			return true
		end
		parent = parent:GetParent()
		depth = depth + 1
	end
	return false
end

local function clean_section_tag(sec, full_txt)
	local combined = ((sec or "") .. " " .. (full_txt or "")):upper()

	if combined:find("ГИЛЬД") or combined:find("GUILD") then return "Гильдия" end
	if combined:find("ФЭНТЕЗИ") or combined:find("FANTASY") then return "Фэнтези" end
	if combined:find("ПРОГНОЗ") or combined:find("PREDICT") then return "Прогнозы" end
	if combined:find("EVENT") or combined:find("COMPENDIUM") or combined:find("КОМПЕНД") then return "Комп" end
	if combined:find("ROLE") or combined:find("TOKEN") or combined:find("ЖЕТОН") then return "Жетоны" end
	if combined:find("RANK") or combined:find("LEADERBOARD") or combined:find("MMR") or combined:find("РЕЙТ") then return "Ранк" end
	if combined:find("FRIEND") or combined:find("ДРУЗЬ") then return "Друзья" end

	local clean = sec:gsub("Западная", ""):gsub("Восточная", ""):gsub("Европа", ""):gsub("Америка", ""):gsub("%d+", ""):gsub("^%s*(.-)%s*$", "%1")

	if clean == "" or utf8_len(clean) < 2 then
		return "UI"
	end

	if utf8_len(clean) > 8 then
		return utf8_sub(clean, 1, 6) .. "."
	end
	return clean
end

local function clean_item_text(txt)
	if not txt then return "" end
	local clean = txt:gsub("ПРОЦЕНТИЛЬ", "Проц"):gsub("PERCENTILE", "Perc")
	if utf8_len(clean) > 16 then
		clean = utf8_sub(clean, 1, 14) .. ".."
	end
	return clean
end

local function detect_section(node)
	if not node then return "UI Element" end

	local parent = node:GetParent()
	if parent then
		for i = 0, parent:GetChildCount() - 1 do
			local sib = parent:GetChild(i)
			if sib ~= node then
				local txt = safe_text(sib)
				if txt ~= "" and not txt:match("^%d+$") and #txt < 35 then
					return txt:gsub(":", ""):gsub("^%s*(.-)%s*$", "%1")
				end
			end
		end
	end

	local curr = parent
	local depth = 0
	while curr and depth < 5 do
		local id = curr:GetID()
		if id and id ~= "" and not id:find("^__") and not id:find("^Panel") then
			local clean_id = id:gsub("(%l)(%A)", "%1 %2"):gsub("Panel$", ""):gsub("Container$", "")
			if #clean_id > 2 then
				return clean_id
			end
		end

		for i = 0, curr:GetChildCount() - 1 do
			local child = curr:GetChild(i)
			if child ~= node then
				local txt = safe_text(child)
				if txt ~= "" and not txt:match("^%d+$") and #txt < 30 then
					return txt:gsub(":", ""):gsub("^%s*(.-)%s*$", "%1")
				end
			end
		end

		curr = curr:GetParent()
		depth = depth + 1
	end

	return "General UI"
end

local function scan_matches()
	state.matches = {}
	state.items = {}

	local root = get_root()
	if not root then
		ui.status:ForceLocalization("interface not found")
		return
	end

	local query = ui.search_input:Get()
	if not query or query == "" then
		ui.status:ForceLocalization("enter search query")
		return
	end

	local query_digits = get_digits(query)

	walk(root, function(node)
		if is_target_panel(node) then
			local txt = safe_text(node)
			if txt ~= "" then
				local is_match = false
				if txt:find(query, 1, true) then
					is_match = true
				elseif query_digits ~= "" and get_digits(txt) == query_digits then
					is_match = true
				end

				if is_match then
					local raw_sec = detect_section(node)
					local short_sec = clean_section_tag(raw_sec, txt)
					local short_txt = clean_item_text(txt)

					state.matches[#state.matches + 1] = {
						panel = node,
						text = txt,
						section = raw_sec
					}
					state.items[#state.items + 1] = string.format("[%s] %s", short_sec, short_txt)
				end
			end
		end
	end)

	if #state.items > 0 then
		ui.combo:Update(state.items, 0)
		ui.status:ForceLocalization(string.format("found %d matches across all tabs", #state.items))
	else
		ui.combo:Update({ "No matches found" }, 0)
		ui.status:ForceLocalization("no matches found")
	end
end

local function set_panel_text(panel, new_val)
	if not panel then return false end
	local current_txt = safe_text(panel)
	if current_txt == "" then return false end

	if state.history[panel] == nil then
		state.history[panel] = current_txt
	end

	local ok = pcall(function()
		panel:SetText(new_val)
	end)
	return ok
end

local function apply_selected()
	if #state.matches == 0 then return end
	local idx = ui.combo:Get() + 1
	local match = state.matches[idx]
	if not match or not match.panel then return end

	local new_val = ui.replace_input:Get()
	if set_panel_text(match.panel, new_val) then
		ui.status:ForceLocalization(string.format("applied to: %s", match.section))
	end
end

local function apply_all_matches()
	if #state.matches == 0 then return end
	local new_val = ui.replace_input:Get()
	local count = 0

	for _, match in ipairs(state.matches) do
		if match.panel then
			if set_panel_text(match.panel, new_val) then
				count = count + 1
			end
		end
	end
	ui.status:ForceLocalization(string.format("applied to all %d matches", count))
end

local function apply_nuke_all()
	local root = get_root()
	if not root then
		ui.status:ForceLocalization("interface not found")
		return
	end

	local new_val = ui.replace_input:Get()
	if not new_val or new_val == "" then
		ui.status:ForceLocalization("enter new value")
		return
	end

	local count = 0

	walk(root, function(node)
		if is_target_panel(node) then
			local raw = safe_text(node)
			if raw ~= "" then
				if set_panel_text(node, new_val) then
					count = count + 1
				end
			end
		end
	end)

	ui.status:ForceLocalization(string.format("nuked ALL %d labels on screen!", count))
end

local function reset_history()
	local count = 0
	for panel, original_text in pairs(state.history) do
		if panel then
			pcall(function()
				panel:SetText(original_text)
				count = count + 1
			end)
		end
	end

	state.history = {}
	ui.status:ForceLocalization(string.format("reset %d modified labels", count))
end

local menu = Menu.Create("General", "Visuals", "TXT Spoofer")
menu:Icon("\u{f031}")

local main_tab = menu:Create("Поиск и замена")
local group = main_tab:Create("Подмена", Enum.GroupSide.FullWidth)

ui.search_input = group:Input("Что найти", "ПРОЦЕНТИЛЬ")
ui.search_input:Icon("\u{f002}")

ui.scan = group:Button("Поиск", function()
	scan_matches()
end)
ui.scan:Icon("\u{f002}")

ui.combo = group:Combo("Выбор объекта", { "Нажми 'Поиск'" }, 0)
ui.combo:Icon("\u{f0ca}")

ui.replace_input = group:Input("Новое значение", "0x10ma")
ui.replace_input:Icon("\u{f040}")

ui.apply_selected = group:Button("Заменить выбранное совпадение", function()
	apply_selected()
end)
ui.apply_selected:Icon("\u{f00c}")

ui.apply_all = group:Button("Заменить все совпадения", function()
	apply_all_matches()
end, true)
ui.apply_all:Icon("\u{f00e}")

ui.nuke_all = group:Button("Заменить весь текст", function()
	apply_nuke_all()
end)
ui.nuke_all:Icon("\u{f714}")

ui.reset = group:Button("Сбросить все изменения", function()
	reset_history()
end)
ui.reset:Icon("\u{f0e2}")


return spoofer