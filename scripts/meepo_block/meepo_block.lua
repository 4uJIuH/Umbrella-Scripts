--[[
            ~ meepo blocker • uczone.gitbook.io/api-v2.0/
        ~ t.me/windguild
    ~ У вас новый лог!
]]

local meepo_blocker = {}

-- #region - Definitions

local a = function (...) return ... end
math.clamp = math.clamp or function (x, min_v, max_v) if x < min_v then return min_v elseif x > max_v then return max_v end return x end

local cfg = {
	hero_name = "npc_dota_hero_meepo",
	mode = {
		optimal = 0,
		all_clones = 1,
	},
	status = {
		idle = "цель...",
		blocking = "закрываю",
		blocked = "ЗАКРЫЛ",
	},
	state = {
		blocking = "закрываю",
		attacking = "атакую",
	},
	close_need = 3,
	order_delay = {
		base_ms = 80,
		jitter_ms = 50,
		hold_multiplier = 0.55,
	},
	close = {
		tolerance = 0.28,
		min_radius = 18,
		padding = 0,
		pressure = 12,
		contact_extra = 18,
		slot_angle = 0.72,
		orbit_extra = 140,
		orbit_step = 0.85,
	},
	attack_refresh = 0.35,
	net = {
		ability_name = "meepo_earthbind",
		speed_fallback = 900,
		range_buffer = 25,
		predict_max_time = 1.35,
		pending_buffer = 0.14,
	},
	animations = {
		text_speed = 2,
		text_lift = 4,
	},
}

local ui, render_ctx, state do
	local tab = Menu.Create("General", "Blocker", "Meepo Blocker")
	tab:Icon("\u{f20b}")

	local group = tab:Create("Main"):Create("Настройки")
	ui = {
		enable = group:Switch("Включить", true, "\u{f00c}"),
		key = group:Bind("Бинд", Enum.ButtonCode.KEY_NONE),
		range = group:Slider("Дистанция поиска цели", 400, 5000, 1200),
		block_mode = group:Combo("Режим блока", {"Оптимальный (3)", "Все клоны"}, cfg.mode.optimal),
		auto_net = group:Switch("Авто-сетка", true, "\u{f3ed}"),
		net_far_distance = group:Slider("Сетка если цель дальше", 400, 3000, 1100),
		net_slow_ms = group:Slider("Не кидать сетку при скорости <=", 120, 300, 185),
		net_cooldown_ms = group:Slider("Пауза сетки (мс)", 150, 2000, 550),
	}

	render_ctx = {
		font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS),
		text = Color(255, 255, 255),
		success = Color(90, 255, 120),
		shadow = Color(0, 0, 0),
	}

	state = {
		meepo = nil,
		target = nil,
		status = cfg.status.idle,

		order_timers = {},
		last_positions = {},
		unit_states = {},
		meepo_units = {},
		meepo_all = {},
		meepo_clones = {},
		enemy_track = {},
		last_net_cast = 0,
		net_pending_until = {},
		net_hold_until = {},
		last_attack_order = 0,
		block_angle = nil,
		draw_cache = {},
	}
end

-- #endregion

-- #region - Animations

local animations do
	local animators = setmetatable({}, {__mode = "kv"})
	local frametime, g_speed = 1 / 30, 1
	local last_time = 0

	animations = {
		pulse = 0,
		easings = {
			pow = {
				function (x, p) return 1 - ((1 - x) ^ (p or 3)) end,
				function (x, p) return x ^ (p or 3) end,
				function (x, p) return x < 0.5 and 4 * math.pow(x, p or 3) or 1 - math.pow(-2 * x + 2, p or 3) * 0.5 end,
			}
		},
		lerp = a(function (from, to, speed, threshold)
			local current = from + (to - from) * frametime * (speed or 8) * g_speed
			return math.abs(to - current) < (threshold or 0.005) and to or current
		end),
		condition = a(function (id, condition, speed, ease)
			local ctx = id[1] and id or animators[id]
			if not ctx then animators[id] = { 0, condition }; ctx = animators[id] end

			speed = speed or 4
			local current_speed = speed
			if type(speed) == "table" then current_speed = condition and speed[1] or speed[2] end

			ctx[1] = math.clamp(ctx[1] + (frametime * math.abs(current_speed) * g_speed * (condition and 1 or -1)), 0, 1)

			return (ctx[1] % 1 == 0 or current_speed < 0) and ctx[1] or
			animations.easings.pow[ease and (condition and ease[1][1] or ease[2][1]) or (condition and 1 or 3)](
				ctx[1],
				ease and (condition and ease[1][2] or ease[2][2]) or 3
			)
		end),
		tick = a(function ()
			local now = GameRules.GetGameTime()
			if last_time == 0 then last_time = now end

			frametime = math.max(0.001, now - last_time)
			last_time = now
			animations.pulse = math.abs(now * 1 % 2 - 1)
		end),
	}
end

-- #endregion

-- #region - Helpers

local helpers do
	helpers = {
		is_local_meepo = a(function ()
			return state.meepo and Entity.GetUnitName(state.meepo) == cfg.hero_name
		end),

		update_menu_visibility = a(function ()
			local enabled = ui.enable:Get()
			local net_enabled = enabled and ui.auto_net:Get()

			ui.key:Visible(enabled)
			ui.range:Visible(enabled)
			ui.block_mode:Visible(enabled)
			ui.auto_net:Visible(enabled)
			ui.net_far_distance:Visible(net_enabled)
			ui.net_slow_ms:Visible(net_enabled)
			ui.net_cooldown_ms:Visible(net_enabled)
		end),

		find_target = a(function ()
			local enemies = Entity.GetHeroesInRadius(state.meepo, ui.range:Get(), Enum.TeamType.TEAM_ENEMY)
			if not enemies then return nil end

			local best_target, best_distance = nil, 99999
			local meepo_pos = Entity.GetAbsOrigin(state.meepo)

			for _, enemy in ipairs(enemies) do
				if Entity.IsHero(enemy) and Entity.IsAlive(enemy) and not NPC.IsIllusion(enemy) then
					local distance = (meepo_pos - Entity.GetAbsOrigin(enemy)):Length()
					if distance < best_distance then
						best_target, best_distance = enemy, distance
					end
				end
			end

			return best_target
		end),

		update_meepo_units = a(function ()
			local previous_slot = {}
			for index, unit in ipairs(state.meepo_units) do previous_slot[unit] = index end

			state.meepo_units = {}
			state.meepo_all = {}

			local local_player = Players.GetLocal()
			if not local_player then return end

			local local_player_id = Player.GetPlayerID(local_player)
			local meepo_all, meepo_clones = {}, {}

			for _, unit in ipairs(NPCs.GetAll()) do
				if Entity.IsAlive(unit)
					and Entity.IsHero(unit)
					and Entity.IsSameTeam(state.meepo, unit)
					and Entity.GetUnitName(unit) == cfg.hero_name
					and Entity.IsControllableByPlayer(unit, local_player_id)
				then
					meepo_all[#meepo_all + 1] = unit
					if NPC.IsMeepoClone(unit) then
						meepo_clones[#meepo_clones + 1] = unit
					end
				end
			end

			if state.meepo and Entity.IsAlive(state.meepo) then
				local found = false
				for _, unit in ipairs(meepo_all) do
					if unit == state.meepo then found = true; break end
				end
				if not found then meepo_all[#meepo_all + 1] = state.meepo end
			end

			local target_pos = state.target and Entity.GetAbsOrigin(state.target)
			state.meepo_clones = meepo_clones
			state.meepo_all = meepo_all

			table.sort(meepo_all, function (a, b)
				local pa = previous_slot[a] or 999
				local pb = previous_slot[b] or 999
				if pa ~= pb then return pa < pb end
				if target_pos then
					local ad = (Entity.GetAbsOrigin(a) - target_pos):Length2D()
					local bd = (Entity.GetAbsOrigin(b) - target_pos):Length2D()
					if ad ~= bd then return ad < bd end
				end
				return Entity.GetIndex(a) < Entity.GetIndex(b)
			end)

			table.sort(meepo_clones, function (a, b)
				local pa = previous_slot[a] or 999
				local pb = previous_slot[b] or 999
				if target_pos then
					local ad = (Entity.GetAbsOrigin(a) - target_pos):Length2D()
					local bd = (Entity.GetAbsOrigin(b) - target_pos):Length2D()
					if ad ~= bd then return ad < bd end
				end
				if pa ~= pb then return pa < pb end
				return Entity.GetIndex(a) < Entity.GetIndex(b)
			end)

			if #meepo_clones >= cfg.close_need then
				if ui.block_mode:Get() == cfg.mode.all_clones then
					state.meepo_units = meepo_clones
				else
					for i = 1, cfg.close_need do
						state.meepo_units[#state.meepo_units + 1] = meepo_clones[i]
					end
				end
				return
			end

			for _, unit in ipairs(meepo_all) do
				state.meepo_units[#state.meepo_units + 1] = unit
			end
		end),

		clear_target_runtime = a(function (target)
			if not target then return end
			local idx = Entity.GetIndex(target)
			state.net_pending_until[idx] = nil
			state.net_hold_until[idx] = nil
		end),

		reset_block_runtime = a(function ()
			state.order_timers = {}
			state.last_positions = {}
			state.unit_states = {}
			state.last_attack_order = 0
			state.block_angle = nil
		end),

		mark_block_units = a(function (unit_state)
			for _, unit in ipairs(state.meepo_units) do
				state.unit_states[unit] = unit_state
			end
		end),

		all_units_attacking = a(function ()
			for _, unit in ipairs(state.meepo_units) do
				if state.unit_states[unit] ~= cfg.state.attacking then return false end
			end

			return true
		end),

		update_enemy_track = a(function (enemy)
			if not enemy then return end

			local enemy_id = Entity.GetIndex(enemy)
			local now = GameRules.GetGameTime()
			local pos = Entity.GetAbsOrigin(enemy)
			local track = state.enemy_track[enemy_id]

			if not track then
				state.enemy_track[enemy_id] = { pos = pos, time = now, vel = Vector(0, 0, 0) }
				return
			end

			local dt = now - track.time
			if dt > 0 then
				if dt > 0.35 then
					track.vel = Entity.GetRotation(enemy):GetForward() * NPC.GetMoveSpeed(enemy) * 0.6
				else
					local raw_vel = (pos - track.pos) / dt
					local alpha = 0.42
					track.vel = raw_vel * alpha + track.vel * (1 - alpha)
				end
				if not NPC.IsRunning(enemy) then track.vel = track.vel * 0.65 end
			end

			track.pos = pos
			track.time = now
		end),

		is_hard_controlled = a(function (enemy)
			if NPC.IsStunned(enemy) then return true end
			if NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED) then return true end
			if NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_HEXED) then return true end
			if NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_NIGHTMARED) then return true end
			if NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_TAUNTED) then return true end
			if NPC.HasModifier(enemy, "modifier_meepo_earthbind") then return true end
			return false
		end),

		get_target_velocity = a(function (target)
			local move_speed = NPC.GetMoveSpeed(target)
			local forward = Entity.GetRotation(target):GetForward()
			local track = state.enemy_track[Entity.GetIndex(target)]
			local velocity = track and track.vel or Vector(0, 0, 0)

			if velocity:Length2D() > move_speed then
				velocity = velocity:Normalized() * move_speed
			end

			if NPC.IsRunning(target) then
				local run_vel = forward * move_speed
				if velocity:Length2D() < 80 then
					velocity = run_vel * 0.9
				else
					velocity = velocity * 0.7 + run_vel * 0.3
				end
			else
				velocity = velocity * 0.55
			end

			if velocity:Length2D() < 20 then
				velocity = forward * move_speed * 0.55
			end

			return velocity
		end),

		get_surround_angle = a(function (target_pos)
			if state.block_angle then return state.block_angle end

			local best_unit, best_distance = nil, 999999
			for _, unit in ipairs(state.meepo_units) do
				local distance = (Entity.GetAbsOrigin(unit) - target_pos):Length2D()
				if distance < best_distance then
					best_unit, best_distance = unit, distance
				end
			end

			local direction = best_unit and Entity.GetAbsOrigin(best_unit) - target_pos or Entity.GetAbsOrigin(state.meepo) - target_pos
			if direction:Length2D() < 10 then direction = Entity.GetAbsOrigin(state.meepo) - target_pos end
			if direction:Length2D() < 10 then direction = Vector(1, 0, 0) end

			state.block_angle = math.atan(direction.y, direction.x)
			return state.block_angle
		end),

		angle_delta = a(function (a, b)
			local delta = (a - b + math.pi) % (math.pi * 2) - math.pi
			return math.abs(delta)
		end),

		signed_angle_delta = a(function (from, to)
			return (to - from + math.pi) % (math.pi * 2) - math.pi
		end),

		get_slot_assignment = a(function (units, target_pos, slots)
			local best_assignment, best_score = {}, 999999
			local used, current = {}, {}

			local iterate
			iterate = function (index, score)
				if score >= best_score then return end
				if index > #units then
					best_score = score
					best_assignment = {}
					for unit, slot_index in pairs(current) do best_assignment[unit] = slot_index end
					return
				end

				local unit = units[index]
				local direction = Entity.GetAbsOrigin(unit) - target_pos
				local current_angle = direction:Length2D() > 1 and math.atan(direction.y, direction.x) or slots[1].angle

				for slot_index, slot in ipairs(slots) do
					if not used[slot_index] then
						used[slot_index] = true
						current[unit] = slot_index
						iterate(index + 1, score + helpers.angle_delta(current_angle, slot.angle))
						current[unit] = nil
						used[slot_index] = nil
					end
				end
			end

			iterate(1, 0)
			return best_assignment
		end),

		get_surround_positions = a(function (target, target_pos)
			local count = #state.meepo_units
			local positions, slots = {}, {}
			local base_angle = helpers.get_surround_angle(target_pos)
			local step = (math.pi * 2) / count

			for i = 1, count do
				local angle = base_angle + step * (i - 1)
				slots[i] = {
					angle = angle,
					direction = Vector(math.cos(angle), math.sin(angle), 0),
				}
			end

			local assignment = helpers.get_slot_assignment(state.meepo_units, target_pos, slots)
			for _, unit in ipairs(state.meepo_units) do
				local hull_radius = NPC.GetHullRadius(target) + NPC.GetHullRadius(unit)
				local radius = math.max(NPC.GetHullRadius(unit), hull_radius + cfg.close.padding - cfg.close.pressure)
				local slot = slots[assignment[unit]]
				positions[unit] = { target_pos + slot.direction * radius, hull_radius, slot.angle, radius }
			end

			return positions
		end),

		get_orbit_position = a(function (unit, target_pos, slot_angle, radius)
			local direction = Entity.GetAbsOrigin(unit) - target_pos
			if direction:Length2D() <= 1 then return target_pos + Vector(math.cos(slot_angle), math.sin(slot_angle), 0) * radius end

			local current_angle = math.atan(direction.y, direction.x)
			local delta = helpers.signed_angle_delta(current_angle, slot_angle)
			local step = math.min(math.abs(delta), cfg.close.orbit_step)
			local next_angle = current_angle + (delta >= 0 and step or -step)
			local orbit_radius = radius + cfg.close.orbit_extra

			return target_pos + Vector(math.cos(next_angle), math.sin(next_angle), 0) * orbit_radius
		end),

		is_unit_in_slot = a(function (unit, target_pos, slot_angle)
			local direction = Entity.GetAbsOrigin(unit) - target_pos
			if direction:Length2D() <= 1 then return false end

			return helpers.angle_delta(math.atan(direction.y, direction.x), slot_angle) <= cfg.close.slot_angle
		end),

		is_unit_closing_target = a(function (unit, target, target_pos)
			local distance = (Entity.GetAbsOrigin(unit) - target_pos):Length2D()
			local contact_radius = NPC.GetHullRadius(target) + NPC.GetHullRadius(unit) + cfg.close.contact_extra
			return distance <= contact_radius
		end),

		is_effectively_slowed = a(function (enemy)
			local enemy_speed = NPC.GetMoveSpeed(enemy)
			return enemy_speed <= ui.net_slow_ms:Get()
		end),

		is_net_pending = a(function (target)
			local until_time = state.net_pending_until[Entity.GetIndex(target)] or 0
			return until_time > GameRules.GetGameTime()
		end),

		set_net_pending = a(function (target, eta)
			state.net_pending_until[Entity.GetIndex(target)] = GameRules.GetGameTime() + eta + cfg.net.pending_buffer
		end),

		set_net_hold = a(function (target, duration)
			state.net_hold_until[Entity.GetIndex(target)] = GameRules.GetGameTime() + duration
		end),

		is_net_hold_active = a(function (target)
			return (state.net_hold_until[Entity.GetIndex(target)] or 0) > GameRules.GetGameTime()
		end),

		draw_cache_begin = a(function ()
			for _, entry in pairs(state.draw_cache) do
				entry.active = false
			end
		end),

		draw_cache_touch = a(function (entity, text, offset_y, offset_x, cache_key, color)
			if not entity then return end
			if not text then return end

			local key = cache_key or (tostring(Entity.GetIndex(entity)) .. "::" .. tostring(text))
			local entry = state.draw_cache[key]
			if not entry then
				entry = { key = key }
				state.draw_cache[key] = entry
			end

			entry.entity = entity
			entry.text = text
			entry.offset_y = offset_y or 70
			entry.offset_x = offset_x or 0
			entry.color = color or render_ctx.text
			entry.active = true
		end),

		draw_cache_render = a(function ()
			for key, entry in pairs(state.draw_cache) do
				local show = helpers.draw_text_above(entry.entity, entry.text, entry.offset_y, entry.active, key, entry.offset_x, entry.color)
				if not entry.active and show <= 0 then
					state.draw_cache[key] = nil
				end
			end
		end),

		special = a(function (ability, names, fallback)
			for _, name in ipairs(names) do
				local value = Ability.GetLevelSpecialValueFor(ability, name, -1)
				if value and value > 0 then return value end
			end

			return fallback
		end),

		get_earthbind = a(function (unit)
			local ability = NPC.GetAbility(unit, cfg.net.ability_name)
			if not ability then return nil end
			if Ability.IsHidden(ability) or Ability.GetLevel(ability) <= 0 then return nil end
			return ability
		end),

		predict_net_position = a(function (caster, target, ability)
			local cast_point = Ability.GetCastPoint(ability, true) or 0.2
			local speed = helpers.special(ability, {"projectile_speed", "speed", "travel_speed", "bolt_speed", "missile_speed"}, cfg.net.speed_fallback)

			local caster_pos = Entity.GetAbsOrigin(caster)
			local target_pos = Entity.GetAbsOrigin(target)
			local cast_range = Ability.GetCastRange(ability) + NPC.GetCastRangeBonus(caster)
			local velocity = helpers.get_target_velocity(target)

			local dist = (target_pos - caster_pos):Length2D()
			local eta = math.min(cast_point + (dist / math.max(1, speed)), cfg.net.predict_max_time)
			local lead = eta
			if lead > 0.55 then lead = 0.55 + (lead - 0.55) * 0.45 end
			local predicted = target_pos + velocity * lead

			local dist2 = (predicted - caster_pos):Length2D()
			local eta2 = math.min(cast_point + (dist2 / math.max(1, speed)), cfg.net.predict_max_time)
			local lead2 = eta2
			if lead2 > 0.55 then lead2 = 0.55 + (lead2 - 0.55) * 0.45 end
			predicted = target_pos + velocity * lead2

			local to_pred = predicted - caster_pos
			local pred_dist = to_pred:Length2D()
			local max_cast = math.max(0, cast_range - cfg.net.range_buffer)

			if pred_dist > max_cast and pred_dist > 0 then
				predicted = caster_pos + to_pred:Normalized() * max_cast
			end

			return predicted, lead2, cast_range
		end),

		try_cast_net = a(function (target)
			if not ui.auto_net:Get() then return false end
			if helpers.is_hard_controlled(target) then return false end
			if helpers.is_effectively_slowed(target) then return false end
			if helpers.is_net_pending(target) then return false end

			local now = GameRules.GetGameTime()
			local cast_delay = ui.net_cooldown_ms:Get() / 1000
			if now - state.last_net_cast < cast_delay then return false end

			local target_distance = (Entity.GetAbsOrigin(target) - Entity.GetAbsOrigin(state.meepo)):Length2D()
			local need_net = NPC.IsRunning(target) or target_distance >= ui.net_far_distance:Get()
			if not need_net then return false end

			local best_ability, best_pos = nil, nil
			local best_eta = 999

			for _, clone in ipairs(state.meepo_clones) do
				local earthbind = helpers.get_earthbind(clone)
				if earthbind and Ability.IsCastable(earthbind, NPC.GetMana(clone)) then
					local cast_pos, eta, cast_range = helpers.predict_net_position(clone, target, earthbind)
					local cast_dist = (cast_pos - Entity.GetAbsOrigin(clone)):Length2D()
					if cast_dist <= cast_range and eta < best_eta then
						best_ability = earthbind
						best_pos = cast_pos
						best_eta = eta
					end
				end
			end

			if not best_ability then return false end

			Ability.CastPosition(best_ability, best_pos)
			state.last_net_cast = now
			helpers.set_net_pending(target, best_eta)
			helpers.set_net_hold(target, 2.1)
			return true
		end),

		draw_text_above = a(function (entity, text, offset_y, condition, anim_key, offset_x, color)
			local key = anim_key or (tostring(Entity.GetIndex(entity)) .. "::" .. tostring(text))
			local show = animations.condition(key, condition ~= false, cfg.animations.text_speed, {{1, 3}, {2, 3}})
			if show <= 0 then return 0 end

			if not entity or not Entity.IsAlive(entity) then return show end

			local world_pos = Entity.GetAbsOrigin(entity) + Vector(0, 0, NPC.GetHealthBarOffset(entity))
			local screen_pos, is_visible = Render.WorldToScreen(world_pos)
			if not is_visible then return show end

			local text_size = Render.TextSize(render_ctx.font, 18, text)
			local x = screen_pos.x - text_size.x / 2 + (offset_x or 0)
			local y = screen_pos.y - (offset_y or 70) + (1 - show) * cfg.animations.text_lift

			local alpha = math.floor(255 * show)
			local base_col = color or render_ctx.text
			local text_col = Color(base_col.r, base_col.g, base_col.b, alpha)
			local shadow_col = Color(render_ctx.shadow.r, render_ctx.shadow.g, render_ctx.shadow.b, alpha)

			Render.Text(render_ctx.font, 18, text, Vec2(x + 1, y + 1), shadow_col)
			Render.Text(render_ctx.font, 18, text, Vec2(x, y), text_col)

			return show
		end),
	}
end

-- #endregion

-- #region - Core

local core do
	core = {
		run = a(function ()
			if not ui.enable:Get() or not state.meepo or not Entity.IsAlive(state.meepo) or not helpers.is_local_meepo() then return end

			if not Input.IsKeyDown(ui.key:Get()) then
				helpers.clear_target_runtime(state.target)
				helpers.reset_block_runtime()
				state.target = nil
				state.status = cfg.status.idle
				return
			end

			helpers.update_meepo_units()
			if #state.meepo_units == 0 then
				helpers.reset_block_runtime()
				state.status = cfg.status.idle
				return
			end

			local previous_target = state.target
			if not state.target or not Entity.IsAlive(state.target) then
				state.target = helpers.find_target()
			end
			if previous_target ~= state.target then
				helpers.clear_target_runtime(previous_target)
				helpers.reset_block_runtime()
			end

			if not state.target then
				helpers.reset_block_runtime()
				state.status = cfg.status.idle
				return
			end

			helpers.update_enemy_track(state.target)

			local target_pos = Entity.GetAbsOrigin(state.target)
			local surround_positions = helpers.get_surround_positions(state.target, target_pos)
			local current_time = GameRules.GetGameTime()
			local close_count = 0
			local required_close_count = math.max(1, math.min(#state.meepo_units, cfg.close_need))
			local hold_blocker = helpers.is_hard_controlled(state.target) or helpers.is_net_hold_active(state.target)

			for i, unit in ipairs(state.meepo_units) do
				local block_data = surround_positions[unit]
				local block_pos, radius, slot_angle, move_radius = block_data[1], block_data[2], block_data[3], block_data[4]
				local close_radius = math.max(cfg.close.min_radius, radius * cfg.close.tolerance)

				local unit_pos = Entity.GetAbsOrigin(unit)
				local in_slot = helpers.is_unit_in_slot(unit, target_pos, slot_angle)
				local physical_close = helpers.is_unit_closing_target(unit, state.target, target_pos)
				if in_slot and ((unit_pos - block_pos):Length2D() <= close_radius or physical_close) then
					close_count = close_count + 1
				end

				local move_pos = in_slot and block_pos or helpers.get_orbit_position(unit, target_pos, slot_angle, move_radius)
				local last_pos = state.last_positions[unit]
				local needs_new_order = not last_pos or (last_pos - move_pos):Length2D() > 28

				local last_order_time = state.order_timers[unit] or 0
				local delay_ms = cfg.order_delay.base_ms + math.random(0, cfg.order_delay.jitter_ms)
				if hold_blocker then delay_ms = delay_ms * cfg.order_delay.hold_multiplier end
				local delay = delay_ms / 1000

				if current_time - last_order_time > delay then
					if needs_new_order then
						Player.PrepareUnitOrders(
							Players.GetLocal(),
							Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
							nil,
							move_pos,
							nil,
							Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
							unit,
							false,
							false,
							false,
							false
						)

						state.unit_states[unit] = cfg.state.blocking
						state.last_positions[unit] = move_pos
					end

					state.order_timers[unit] = current_time
				end
			end

			if close_count < required_close_count then
				helpers.try_cast_net(state.target)
				helpers.mark_block_units(cfg.state.blocking)
				state.status = cfg.status.blocking
				return
			end

			state.status = cfg.status.blocked
			local attack_refresh_due = (current_time - state.last_attack_order) > cfg.attack_refresh
			if helpers.all_units_attacking() and not attack_refresh_due then return end

			Player.PrepareUnitOrders(
				Players.GetLocal(),
				Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
				state.target,
				nil,
				nil,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ENTITIES,
				state.meepo_units,
				false,
				false,
				false,
				false
			)
			state.last_attack_order = current_time

			helpers.mark_block_units(cfg.state.attacking)
		end),
	}
end

-- #endregion

-- #region - Callbacks

local callbacks do
	local event_mt = {
		__call = function (self, bool, fn)
			local action = bool and self.set or self.unset
			action(self, fn)
		end,
		set = function (self, fn)
			self[2] = fn
		end,
		unset = function (self, fn)
			if not fn or self[2] == fn then self[2] = nil end
		end,
		fire = function (self, ...)
			local fn = self[2]
			if fn then return fn(...) end
		end,
	} event_mt.__index = event_mt

	callbacks = setmetatable({}, {
		__index = function (self, key)
			self[key] = setmetatable({key}, event_mt)
			return self[key]
		end,
	})
end

callbacks.draw:set(a(function ()
	helpers.draw_cache_begin()
	local draw_units = state.meepo_units

	if state.meepo and Input.IsKeyDown(ui.key:Get()) and not state.target then
		helpers.draw_cache_touch(
			state.meepo,
			cfg.status.idle,
			70,
			0,
			"hero_status::" .. tostring(Entity.GetIndex(state.meepo))
		)

		for i, unit in ipairs(draw_units) do
			if Entity.IsAlive(unit) then
				local ox = (i % 2 == 0) and 16 or -16
				local oy = 50 + ((i - 1) % 3) * 12
				helpers.draw_cache_touch(
					unit,
					"[" .. i .. "]" .. cfg.status.idle,
					oy,
					ox,
					"unit_status::" .. tostring(Entity.GetIndex(unit)) .. "::" .. cfg.status.idle
				)
			end
		end
	elseif state.meepo and state.target then
		local target_text = state.status == cfg.status.blocked and "+" or state.status
		local target_color = state.status == cfg.status.blocked and render_ctx.success or render_ctx.text
		helpers.draw_cache_touch(
			state.target,
			target_text,
			70,
			0,
			"target_status::" .. tostring(Entity.GetIndex(state.target)),
			target_color
		)

		local draw_state = state.status == cfg.status.blocked and cfg.state.attacking or cfg.state.blocking
		for i, unit in ipairs(draw_units) do
			if Entity.IsAlive(unit) then
				local ox = (i % 2 == 0) and 16 or -16
				local oy = 50 + ((i - 1) % 3) * 12
				helpers.draw_cache_touch(
					unit,
					"[" .. i .. "]" .. draw_state,
					oy,
					ox,
					"unit_status::" .. tostring(Entity.GetIndex(unit)) .. "::" .. draw_state
				)
			end
		end
	end

	helpers.draw_cache_render()
end))

callbacks.update:set(a(function ()
	animations.tick()
	helpers.update_menu_visibility()

	if not state.meepo then
		state.meepo = Heroes.GetLocal()
		return
	end

	core.run()
end))

function meepo_blocker.OnDraw()
	callbacks.draw:fire()
end

function meepo_blocker.OnUpdate()
	callbacks.update:fire()
end

-- #endregion

return meepo_blocker
