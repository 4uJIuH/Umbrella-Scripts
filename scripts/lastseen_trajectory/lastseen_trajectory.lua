local script = {}

local cfg = {
	arrow_len = 200,
	mini_len = 1200,
	min_dist = 12,
	map_interval = 0.2,
	shadow_col = Color(12, 12, 12, 205),
}

local ui = {}
local cached_state = {
	cache = {},
	last_map = 0,
	native_parent = nil,
	color_widget = nil,
	duration_widget = nil,
	size_widget = nil,
}

local function vec_clone(v)
	return Vector(v.x, v.y, v.z)
end

local function is_illusion(hero)
	return NPC.IsIllusion(hero)
end

local function get_color()
	if cached_state.color_widget then
		if type(cached_state.color_widget.Get) == "function" then
			local col = cached_state.color_widget:Get()
			if col then return col end
		elseif cached_state.color_widget.r ~= nil then
			return cached_state.color_widget
		end
	end

	if type(Menu.Style) == "function" then
		local style_col = Menu.Style("active_widgets_text")
		if style_col and style_col.r ~= nil then
			return style_col
		end
	end
end

local function get_duration()
	if cached_state.duration_widget and type(cached_state.duration_widget.Get) == "function" then
		local dur = cached_state.duration_widget:Get()
		if type(dur) == "number" then return dur end
	end
	return math.huge
end

local function get_radius()
	if cached_state.size_widget and type(cached_state.size_widget.Get) == "function" then
		local sz = cached_state.size_widget:Get()
		if type(sz) == "number" then return math.max(8, sz * 0.5) end
	end
	return 20
end

local function update_enemy(hero, time)
	local eid = Entity.GetIndex(hero)
	local pos = Entity.GetAbsOrigin(hero)
	local info = cached_state.cache[eid]

	if not info then
		cached_state.cache[eid] = {
			pos = vec_clone(pos),
			dir = nil,
			last_seen = time
		}
		return
	end

	info.last_seen = time
	local dx = pos.x - info.pos.x
	local dy = pos.y - info.pos.y
	local distance = math.sqrt(dx * dx + dy * dy)

	if distance >= cfg.min_dist then
		info.pos = vec_clone(pos)
		info.dir = Vector(dx / distance, dy / distance, 0)
	end
end

local function render_arrow(pos, dir, col)
	local screen_pos, visible = Render.WorldToScreen(pos)
	if not visible then return end

	local ahead = Vector(pos.x + dir.x * 100, pos.y + dir.y * 100, pos.z)
	local ahead_screen, ahead_visible = Render.WorldToScreen(ahead)
	if not ahead_visible then return end

	local dx = ahead_screen.x - screen_pos.x
	local dy = ahead_screen.y - screen_pos.y
	local len = math.sqrt(dx * dx + dy * dy)

	if len < 1 then return end

	dx = dx / len
	dy = dy / len

	local rad = get_radius()
	local arrow_tip = rad + 28
	local arrow_base = rad + 10
	local arrow_wing = math.max(7, rad * 0.48)

	local tip = Vec2(screen_pos.x + dx * arrow_tip, screen_pos.y + dy * arrow_tip)
	local base = Vec2(screen_pos.x + dx * arrow_base, screen_pos.y + dy * arrow_base)
	local left_wing = Vec2(base.x - dy * arrow_wing, base.y + dx * arrow_wing)
	local right_wing = Vec2(base.x + dy * arrow_wing, base.y - dx * arrow_wing)

	Render.Line(left_wing, tip, cfg.shadow_col, 6.0)
	Render.Line(right_wing, tip, cfg.shadow_col, 6.0)
	Render.Line(left_wing, tip, col, 2.6)
	Render.Line(right_wing, tip, col, 2.6)
end

local function render_minimap(pos, dir)
	local tip_pos = Vector(pos.x + dir.x * cfg.mini_len, pos.y + dir.y * cfg.mini_len, pos.z)
	local base_pos = Vector(tip_pos.x - dir.x * 175, tip_pos.y - dir.y * 175, tip_pos.z)
	local left_pos = Vector(base_pos.x - dir.y * 105, base_pos.y + dir.x * 105, base_pos.z)
	local right_pos = Vector(base_pos.x + dir.y * 105, base_pos.y - dir.x * 105, base_pos.z)

	for _, offset in ipairs({-22, 0, 22}) do
		local offset_vec = Vector(-dir.y * offset, dir.x * offset, 0)
		MiniMap.SendLine(pos + offset_vec, true, true)
		MiniMap.SendLine(tip_pos + offset_vec, false, true)
	end

	MiniMap.SendLine(left_pos, true, true)
	MiniMap.SendLine(tip_pos, false, true)
	MiniMap.SendLine(right_pos, true, true)
	MiniMap.SendLine(tip_pos, false, true)
end

function script.OnScriptsLoaded()
	local root = Menu.Find("Info Screen", "Main", "Show Me More", "Main", "Maphack")
	if not root then return end

	cached_state.native_parent = root
	cached_state.color_widget = Menu.Find("Colors", "active_widgets_text")
	cached_state.duration_widget = Menu.Find("Info Screen", "Main", "Show Me More", "Main", "Maphack", "Last Seen Position", "Last Seen Position", "Duration")
	cached_state.size_widget = Menu.Find("Info Screen", "Main", "Show Me More", "Main", "Maphack", "Enable", "MapHack", "Image Size")

	ui.enabled = root:Switch("Показывать направление", false, "\u{f061}")
	ui.show_map = root:Switch("Линия на карте", true, "\u{f279}")
	ui.show_world = root:Switch("Линия в мире", true, "\u{f06e}")

	ui.enabled:SetCallback(function()
		local is_on = ui.enabled:Get()
		ui.show_map:Visible(is_on)
		ui.show_world:Visible(is_on)
	end, true)
end

function script.OnUpdate()
	if not ui.enabled or not ui.enabled:Get() then return end

	local my_hero = Heroes.GetLocal()
	if not my_hero then return end

	local my_team = Entity.GetTeamNum(my_hero)
	local now = GameRules.GetGameTime()

	for _, hero in ipairs(Heroes.GetAll()) do
		if Entity.GetTeamNum(hero) ~= my_team and not Entity.IsDormant(hero) and not is_illusion(hero) then
			update_enemy(hero, now)
		end
	end
end

function script.OnDraw()
	if not ui.enabled or not ui.enabled:Get() then return end

	local my_hero = Heroes.GetLocal()
	if not my_hero then return end

	local my_team = Entity.GetTeamNum(my_hero)
	local now = GameRules.GetGameTime()
	local should_draw_map = ui.show_map:Get() and (now - cached_state.last_map) >= cfg.map_interval
	if should_draw_map then
		cached_state.last_map = now
	end

	for _, hero in ipairs(Heroes.GetAll()) do
		if Entity.GetTeamNum(hero) ~= my_team and Entity.IsDormant(hero) and not is_illusion(hero) then
			local eid = Entity.GetIndex(hero)
			local info = cached_state.cache[eid]
			if not info then
				local rot = Entity.GetRotation(hero):GetForward():Normalized()
				info = {
					pos = Hero.GetLastMaphackPos(hero) or Entity.GetAbsOrigin(hero),
					dir = Vector(rot.x, rot.y, 0),
					last_seen = now
				}
				cached_state.cache[eid] = info
			end
			local duration = get_duration()
			if info.dir and (now - info.last_seen) <= duration then
				local draw_pos = Hero.GetLastMaphackPos(hero) or info.pos
				if ui.show_world:Get() then
					render_arrow(draw_pos, info.dir, get_color())
				end
				if should_draw_map then
					render_minimap(draw_pos, info.dir)
				end
			end
		end
	end
end

function script.OnEntityDestroy(entity)
	cached_state.cache[Entity.GetIndex(entity)] = nil
end

return script
