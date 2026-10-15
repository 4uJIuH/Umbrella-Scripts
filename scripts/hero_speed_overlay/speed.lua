local ICON_URL = "https://raw.githubusercontent.com/google/material-design-icons/3.0.1/maps/drawable-mdpi/ic_directions_run_white_48dp.png"
local ICON_URL_SMALL = "https://raw.githubusercontent.com/google/material-design-icons/3.0.1/maps/drawable-mdpi/ic_directions_run_white_24dp.png"

local ui = {}
local state = {
	font = nil,
	img = nil,
	img_small = nil,
	my_speed = 0,
	enemies = {},
	last_update = 0,
	last_draw = nil,
}

local function init_menu()
	local page = Menu.Create("Info Screen", "Main", "Heroes Overlay")
	local tab = page:Create("Main")
	local group = tab:Create("Speed Check")

	ui.enable = group:Switch("Включить", true, "\u{f70c}")
	ui.show_delta = group:Switch("Показывать разницу", true, "\u{f06e}")

	ui.size = group:Slider("Размер", 50, 200, 100, "%d%%")
	ui.size:Icon("\u{f424}")
	ui.offset_x = group:Slider("Сдвиг по X", -200, 200, 0, "%dpx")
	ui.offset_x:Icon("\u{f337}")
	ui.offset_y = group:Slider("Сдвиг по Y", -200, 200, -30, "%dpx")
	ui.offset_y:Icon("\u{f338}")

	ui.color_fast = group:ColorPicker("Я быстрее", Color(96, 230, 130, 255), "\u{f53f}")
	ui.color_slow = group:ColorPicker("Враг быстрее", Color(255, 86, 86, 255), "\u{f53f}")
	ui.color_even = group:ColorPicker("Скорости равны", Color(255, 200, 80, 255), "\u{f53f}")

	ui.glow_width = group:Slider("Ширина свечения", 25, 250, 100, "%d%%")
	ui.glow_width:Icon("\u{f065}")
	ui.glow = group:Slider("Яркость свечения", 0, 100, 100, "%d%%")
	ui.glow:Icon("\u{f185}")

	ui.enable:SetCallback(function(widget)
		local off = not widget:Get()
		local dependents = { ui.show_delta, ui.size, ui.offset_x, ui.offset_y, ui.glow, ui.glow_width, ui.color_fast, ui.color_slow, ui.color_even }
		for _, w in pairs(dependents) do
			w:Disabled(off)
		end
	end, true)
end

local function on_update()
	if not ui.enable:Get() then return end

	local now = os.clock()
	if now - state.last_update < 0.1 then return end
	state.last_update = now

	local me = Heroes.GetLocal()
	if not me then return end

	state.my_speed = NPC.GetMoveSpeed(me) or 0
	local my_team = Entity.GetTeamNum(me)

	for _, hero in pairs(Heroes.GetAll()) do
		if hero ~= me and Entity.GetTeamNum(hero) ~= my_team and not NPC.IsIllusion(hero) then
			local rec = state.enemies[hero]
			if not rec then
				rec = { alpha = 0, smooth = 0, speed = 0, hbo = 0, active = false }
				state.enemies[hero] = rec
			end
			rec.seen = now
			rec.active = Entity.IsAlive(hero) and not Entity.IsDormant(hero) and NPC.IsVisible(hero)
			if rec.active then
				rec.speed = NPC.GetMoveSpeed(hero) or rec.speed
				rec.hbo = NPC.GetHealthBarOffset(hero) or rec.hbo
			end
		end
	end

	for hero, rec in pairs(state.enemies) do
		if rec.seen ~= now then
			state.enemies[hero] = nil
		end
	end
end

local function on_draw()
	if not ui.enable:Get() then return end

	local now = os.clock()
	local dt = math.min(now - (state.last_draw or now), 0.05)
	state.last_draw = now

	local scale = ui.size:Get() / 100
	local off_x, off_y = ui.offset_x:Get(), ui.offset_y:Get()
	local show_delta = ui.show_delta:Get()
	local glow_k = ui.glow:Get() / 100
	local glow_w = ui.glow_width:Get() / 100
	local col_fast, col_slow, col_even = ui.color_fast:Get(), ui.color_slow:Get(), ui.color_even:Get()

	local h = math.max(14, math.floor(22 * scale + 0.5))

	local img_big_ok = state.img ~= nil and state.img ~= 0
	local img_small_ok = state.img_small ~= nil and state.img_small ~= 0
	local img
	if math.floor(h * 0.72 + 0.5) < 20 then
		img = img_small_ok and state.img_small or (img_big_ok and state.img or nil)
	else
		img = img_big_ok and state.img or (img_small_ok and state.img_small or nil)
	end
	local img_ok = img ~= nil
	local font_text = math.max(10, math.floor(h * 0.52 + 0.5))
	local pad = math.floor(h * 0.34 + 0.5)
	local gap = math.floor(h * 0.18 + 0.5)
	local rounding = math.floor(h / 2)

	for hero, rec in pairs(state.enemies) do
		local target = rec.active and 1 or 0
		rec.alpha = rec.alpha + (target - rec.alpha) * math.min(1, dt * 12)

		if rec.alpha > 0.03 then
			local origin = Entity.GetAbsOrigin(hero)
			if origin then
				local screen, on_screen = Render.WorldToScreen(origin + Vector(0, 0, rec.hbo))
				if on_screen then
					local delta = state.my_speed - rec.speed
					rec.smooth = rec.smooth + (delta - rec.smooth) * math.min(1, dt * 8)
					local shown = math.floor(rec.smooth + 0.5)

					local status
					if shown > 2 then
						status = col_fast
					elseif shown < -2 then
						status = col_slow
					else
						status = col_even
					end

					local a = rec.alpha
					local icon_w = math.floor(h * 0.72 + 0.5)
					local text = show_delta and string.format("%+d", -shown) or nil
					local text_sz = text and Render.TextSize(state.font, font_text, text) or nil

					local w = pad + icon_w + (text_sz and (gap + text_sz.x) or 0) + pad
					local x = math.floor(screen.x - w / 2 + off_x + 0.5)
					local y = math.floor(screen.y + off_y - h + 0.5)
					local p1, p2 = Vec2(x, y), Vec2(x + w, y + h)

					local pulse = 0
					if shown < -2 then
						pulse = (math.sin(now * 6) + 1) * 0.5
					end

					local hot_r = status.r + math.floor((255 - status.r) * 0.35 * glow_k)
					local hot_g = status.g + math.floor((255 - status.g) * 0.35 * glow_k)
					local hot_b = status.b + math.floor((255 - status.b) * 0.35 * glow_k)
					local glow_peak = math.min(255, 55 + 125 * glow_k + 60 * pulse)
					local sigma = math.max(2, h * 0.24 * glow_w)
					for i = 1, math.min(60, math.floor(sigma * 2.6 + 0.5)) do
						local fall = math.exp(-(i * i) / (2 * sigma * sigma))
						local ga = math.floor(glow_peak * fall * a)
						if ga < 1 then break end
						Render.Rect(Vec2(x - i, y - i), Vec2(x + w + i, y + h + i), Color(hot_r, hot_g, hot_b, ga), rounding + i, Enum.DrawFlags.None, 1)
					end
					Render.FilledRect(p1, p2, Color(13, 16, 22, math.floor((205 + 20 * pulse) * a)), rounding)
					Render.Rect(p1, p2, Color(hot_r, hot_g, hot_b, math.floor(math.min(255, 50 + 110 * glow_k + 70 * pulse) * a)), rounding, Enum.DrawFlags.None, 1)

					local ix = x + pad
					if img_ok then
						local iy = y + math.floor((h - icon_w) / 2 + 0.5)
						if icon_w >= 16 then
							Render.Image(img, Vec2(ix + 1, iy + 1), Vec2(icon_w, icon_w), Color(0, 0, 0, math.floor(110 * a)))
						end
						Render.Image(img, Vec2(ix, iy), Vec2(icon_w, icon_w), Color(status.r, status.g, status.b, math.floor(255 * a)))
					end

					if text then
						local tx = ix + icon_w + gap
						local ty = y + math.floor((h - text_sz.y) / 2 + 0.5)
						Render.Text(state.font, font_text, text, Vec2(tx + 1, ty + 1), Color(0, 0, 0, math.floor(120 * a)))
						Render.Text(state.font, font_text, text, Vec2(tx, ty), Color(235, 240, 245, math.floor(255 * a)))
					end
				end
			end
		elseif not rec.active then
			state.enemies[hero] = nil
		end
	end
end

local function on_game_end()
	state.enemies = {}
	state.my_speed = 0
	state.last_draw = nil
end

local function on_scripts_loaded()
	state.img = Render.LoadImage(ICON_URL)
	state.img_small = Render.LoadImage(ICON_URL_SMALL)
end

init_menu()
state.font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS)

return {
	OnScriptsLoaded = on_scripts_loaded,
	OnUpdate = on_update,
	OnDraw = on_draw,
	OnGameEnd = on_game_end,
}
