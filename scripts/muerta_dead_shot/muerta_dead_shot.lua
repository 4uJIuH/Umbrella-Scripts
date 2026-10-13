local muerta = {}


local a = function (...) return ... end
math.clamp = math.clamp or function (x, min_v, max_v) if x < min_v then return min_v elseif x > max_v then return max_v end return x end

local cfg = {
	hero_name = "npc_dota_hero_muerta",
	ability_name = "muerta_dead_shot",
	mode = {
		cursor = 0,
		best = 1,
	},
	deadshot = {
		cast_range = 1300,
		damage = 160,
		speed = 2000,
		ricochet = 1500,
		radius = 125,
		cast_point = 0.2,
		range_buffer = 45,
	},
	search_radius = 12000,
	prediction = {
		latency_cap = 0.22,
		turn_penalty = 0.93,
		max_lead = 2.65,
	},

	score = {
		hero_anchor = 210,
		prefer_double = 130,
		creep_anchor = 78,
		tree_anchor = 48,
		double_hit = 190,
		target_lethal = 440,
		anchor_lethal = 260,
		direct_lethal = 520,
		far_lethal = 430,
		travel_penalty = 92,
		long_bounce_penalty = 0.22,
	},
	visual = {
		first = Color(120, 180, 255, 230),
		ricochet = Color(255, 190, 90, 240),
		good = Color(90, 255, 140, 245),
		bad = Color(255, 90, 90, 230),
		text = Color(255, 255, 255, 255),
		shadow = Color(0, 0, 0, 180),
	},
}

local ui, render_ctx, state do


	local main = Menu.Create("Heroes", "Hero List", "Muerta", "Main Settings", "Dead Shot")

	local enable = main:Switch("Включить", true, "\u{f00c}")
	local gear = enable:Gear("Индивидуальная настройка", "\u{f013}", true)

	local target_mode = gear:Combo("Цель", {"Ближайшая к курсору", "Лучшая в радиусе"}, cfg.mode.cursor)
	pcall(function () target_mode:Icon("\u{f140}") end)

	local sources = gear:MultiCombo("Предикт от:", {"Герои", "Крипы", "Деревья"}, {"Герои", "Крипы", "Деревья"})
	pcall(function () sources:Icon("\u{f1de}") end)

	ui = {
		enable = enable,
		gear = gear,
		target_mode = target_mode,
		sources = sources,


		min_score = main:Slider("min score", 80, 1000, 230, "%d"),
		min_hit = main:Slider("min hit", 20, 95, 42, "%d%%"),
		min_fear = main:Slider("min fear", 0, 90, 0, "%d%%"),
		fear_weight = main:Slider("fear weight", 50, 450, 220, "%d"),
		prefer_double = main:Switch("double1", true),
		direct_lethal = main:Switch("lethalscsoc", true),
		far_shot = main:Switch("far shot", true),

		think_ms = main:Slider("think ms", 40, 300, 80, "%d"),
		max_candidates = main:Slider("max candidates", 8, 220, 140, "%d"),
		max_targets = main:Slider("max targets", 1, 32, 24, "%d"),
		max_creeps = main:Slider("max creeps", 0, 80, 32, "%d"),
		max_trees = main:Slider("max trees", 0, 220, 150, "%d"),
		line_samples = main:Slider("lines sample", 2, 12, 6, "%d"),
	}


	local function safe_visible(widget, value)
		if not widget then return end
		pcall(function () widget:Visible(value) end)
	end

	local function sync_menu_visibility()
		local enabled = enable:Get()

		safe_visible(gear, enabled)
		safe_visible(ui.target_mode, enabled)
		safe_visible(ui.sources, enabled)


		safe_visible(ui.min_score, false)
		safe_visible(ui.min_hit, false)
		safe_visible(ui.min_fear, false)
		safe_visible(ui.fear_weight, false)
		safe_visible(ui.prefer_double, false)
		safe_visible(ui.direct_lethal, false)
		safe_visible(ui.far_shot, false)
		safe_visible(ui.think_ms, false)
		safe_visible(ui.max_candidates, false)
		safe_visible(ui.max_targets, false)
		safe_visible(ui.max_creeps, false)
		safe_visible(ui.max_trees, false)
		safe_visible(ui.line_samples, false)
	end

	sync_menu_visibility()
	pcall(function () enable:SetCallback(function () sync_menu_visibility() end, true) end)

	render_ctx = {
		font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS),
	}

	state = {
		hero = nil,
		enemy_track = {},
		best_plan = nil,
		plans = {},
		last_think = 0,
		last_cast = 0,
		menu_enabled = nil,
	}
end

local disabled_states = {
	Enum.ModifierState.MODIFIER_STATE_STUNNED,
	Enum.ModifierState.MODIFIER_STATE_ROOTED,
	Enum.ModifierState.MODIFIER_STATE_HEXED,
	Enum.ModifierState.MODIFIER_STATE_NIGHTMARED,
	Enum.ModifierState.MODIFIER_STATE_TAUNTED,
}

local order_cast_target_tree = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET_TREE or 7

local source_names = {
	hero = "Герои",
	creep = "Крипы",
	tree = "Деревья",
}


local helpers do
	helpers = {
		log = a(function (...)

		end),

		update_menu_visibility = a(function ()
			local enabled = ui.enable:Get()
			if state.menu_enabled == enabled then return end

			state.menu_enabled = enabled

			local function visible(widget, value)
				if not widget then return end
				pcall(function () widget:Visible(value) end)
			end

			visible(ui.gear, enabled)
			visible(ui.target_mode, enabled)
			visible(ui.sources, enabled)


			visible(ui.min_score, false)
			visible(ui.min_hit, false)
			visible(ui.min_fear, false)
			visible(ui.fear_weight, false)
			visible(ui.prefer_double, false)
			visible(ui.direct_lethal, false)
			visible(ui.far_shot, false)
			visible(ui.think_ms, false)
			visible(ui.max_candidates, false)
			visible(ui.max_targets, false)
			visible(ui.max_creeps, false)
			visible(ui.max_trees, false)
			visible(ui.line_samples, false)

		end),

		source_enabled = a(function (kind)
			return ui.sources:Get(source_names[kind])
		end),

		combo_key_down = a(function ()
			local combo_key = Menu.Find("Heroes", "Hero List", "Muerta", "Main Settings", "Hero Settings", "Combo Key")
			if not combo_key then return false end

			local success, down = pcall(function ()
				if combo_key.IsDown then
					return combo_key:IsDown()
				end

				local key_code = combo_key:Get()
				return key_code and key_code ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(key_code)
			end)

			return success and down or false
		end),

		reset_runtime = a(function ()
			state.best_plan = nil
			state.plans = {}
		end),

		is_local_muerta = a(function (hero)
			return hero and Entity.GetUnitName(hero) == cfg.hero_name
		end),

		get_dead_shot = a(function (hero)
			local ability = NPC.GetAbility(hero, cfg.ability_name)
			if ability and not Ability.IsHidden(ability) and Ability.GetLevel(ability) > 0 then return ability end
		end),

		special = a(function (ability, names, fallback)
			for _, name in ipairs(names) do
				local value = Ability.GetLevelSpecialValueFor(ability, name, -1)
				if value and value > 0 then return value end
			end

			return fallback
		end),


		get_params = a(function (hero, ability)
			local cast_range = Ability.GetCastRange(ability)
			if cast_range <= 0 then
				cast_range = helpers.special(ability, {"AbilityCastRange", "cast_range"}, cfg.deadshot.cast_range)
			end
			cast_range = cast_range + NPC.GetCastRangeBonus(hero)

			local damage = Ability.GetDamage(ability) or 0
			if damage <= 0 then
				damage = helpers.special(ability, {"damage", "impact_damage", "ricochet_damage", "bullet_damage"}, cfg.deadshot.damage)
			end

			local speed = helpers.special(ability, {"speed", "projectile_speed", "bullet_speed", "ricochet_speed", "projectile_speed_initial"}, cfg.deadshot.speed)
			local ricochet = helpers.special(ability, {"ricochet_distance", "ricochet_range", "ricochet_max_distance", "bounce_range", "bullet_range", "range", "distance"}, 0)
			local ricochet_multiplier = helpers.special(ability, {"ricochet_distance_multiplier"}, 0)
			if ricochet <= 0 then
				ricochet = ricochet_multiplier > 0 and cast_range * ricochet_multiplier or cfg.deadshot.ricochet
			end
			if ricochet_multiplier <= 0 then ricochet_multiplier = ricochet / math.max(cast_range, 1) end

			return {
				cast_range = cast_range,
				damage = damage,
				speed = speed,
				ricochet = ricochet,
				ricochet_multiplier = ricochet_multiplier,
				radius = helpers.special(ability, {"radius", "ricochet_radius", "ricochet_radius_start", "ricochet_radius_end", "projectile_radius", "impact_radius", "width"}, cfg.deadshot.radius),
				cast_point = Ability.GetCastPoint(ability, true) or cfg.deadshot.cast_point,
				latency = math.clamp(NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING), 0, cfg.prediction.latency_cap),
			}
		end),

		ricochet_length = a(function (first_distance, params)
			return math.clamp(first_distance * params.ricochet_multiplier, params.radius + 120, params.ricochet)
		end),

		is_disabled = a(function (unit)
			if NPC.IsStunned(unit) then return true end
			for _, state_id in ipairs(disabled_states) do
				if NPC.HasState(unit, state_id) then return true end
			end
			return false
		end),

		is_magic_immune = a(function (unit)
			return NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
		end),

		is_valid_unit = a(function (unit)
			return unit and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit) and not NPC.IsIllusion(unit)
		end),

		is_enemy_hero = a(function (unit)
			return helpers.is_valid_unit(unit) and NPC.IsHero(unit) and not helpers.is_magic_immune(unit)
		end),

		is_enemy_creep = a(function (unit)
			return helpers.is_valid_unit(unit) and NPC.IsCreep(unit) and not helpers.is_magic_immune(unit)
		end),

		effective_damage = a(function (target, damage)
			if helpers.is_magic_immune(target) then return 0 end
			return damage * NPC.GetMagicalArmorDamageMultiplier(target)
		end),

		health = a(function (unit)
			local hp = Entity.GetHealth(unit)
			local barriers = NPC.GetBarriers(unit)
			if barriers then
				hp = hp + barriers.magic.current + barriers.all.current
			end
			return hp
		end),

		is_lethal = a(function (target, damage)
			return damage >= helpers.health(target) - 12
		end),

		update_enemy_track = a(function (hero)
			local now = GameRules.GetGameTime()
			local enemies = Entity.GetHeroesInRadius(hero, cfg.search_radius, Enum.TeamType.TEAM_ENEMY, true) or {}

			local update_unit = function (unit)
				local id = Entity.GetIndex(unit)
				local pos = Entity.GetAbsOrigin(unit)
				local track = state.enemy_track[id] or {
					last_pos = pos,
					last_time = now,
					vel = Vector(0, 0, 0),
				}

				local dt = math.max(0.016, now - track.last_time)
				local raw = (pos - track.last_pos) / dt
				track.vel = raw * 0.58 + track.vel * 0.42
				track.last_pos = pos
				track.last_time = now
				track.entity = unit
				state.enemy_track[id] = track
			end

			update_unit(hero)

			for _, enemy in ipairs(enemies) do
				if helpers.is_valid_unit(enemy) then update_unit(enemy) end
			end
		end),

		movement_vector = a(function (unit)
			local track = state.enemy_track[Entity.GetIndex(unit)]
			local vel = track and track.vel or Vector(0, 0, 0)
			local speed = vel:Length2D()
			local move_speed = NPC.GetMoveSpeed(unit)
			local forward = Entity.GetRotation(unit):GetForward():Normalized()
			local run_vel = forward * move_speed

			if speed > move_speed then
				vel = vel:Normalized() * move_speed
				speed = move_speed
			end

			if NPC.IsRunning(unit) then
				if speed > 80 then
					local align = vel:Normalized():Dot2D(forward)
					if align > 0.35 then
						local blend = math.clamp((align - 0.35) / 0.65, 0, 1)
						local blended = vel * (0.45 + blend * 0.2) + run_vel * (0.55 - blend * 0.2)
						return blended, math.min(blended:Length2D(), move_speed)
					end
				end

				return run_vel, move_speed
			end

			if speed > 18 then return vel * 0.35, speed * 0.35 end

			return Vector(0, 0, 0), 0
		end),

		predict_pos = a(function (unit, time)
			local pos = Entity.GetAbsOrigin(unit)
			if time <= 0.02 or helpers.is_disabled(unit) then return pos end

			local vel, speed = helpers.movement_vector(unit)
			if speed <= 10 then return pos end

			return pos + vel:Normalized() * speed * math.min(time, cfg.prediction.max_lead)
		end),

		predict_intercept = a(function (unit, from_pos, base_time, projectile_speed, max_distance)
			local pos = Entity.GetAbsOrigin(unit)
			if helpers.is_disabled(unit) then return pos, base_time + from_pos:Distance2D(pos) / projectile_speed end

			local vel, speed = helpers.movement_vector(unit)
			if speed <= 10 then return pos, base_time + from_pos:Distance2D(pos) / projectile_speed end

			local predicted = helpers.predict_pos(unit, base_time + from_pos:Distance2D(pos) / projectile_speed)
			local total_time = base_time

			for _ = 1, 5 do
				local travel = from_pos:Distance2D(predicted) / projectile_speed
				travel = math.min(travel, max_distance / projectile_speed)
				total_time = base_time + travel
				predicted = helpers.predict_pos(unit, total_time)
			end

			return predicted, total_time
		end),

		caster_position = a(function (hero, params)
			return helpers.predict_pos(hero, params.cast_point + params.latency)
		end),

		prediction_samples = a(function (unit, time)
			local pos = Entity.GetAbsOrigin(unit)
			if time <= 0.02 or helpers.is_disabled(unit) then return {{pos = pos, weight = 1.0}} end

			local vel, speed = helpers.movement_vector(unit)
			if speed <= 10 then return {{pos = pos, weight = 1.0}} end

			local lead = math.min(time, cfg.prediction.max_lead)
			local dir = vel:Normalized()
			local cone = math.rad(13 + math.clamp(lead * 8, 0, 9))
			local back_weight = NPC.IsRunning(unit) and 0.06 or 0.12
			local samples = {
				{pos = pos:Extrapolate(dir, speed * lead), weight = 0.46},
				{pos = pos:Extrapolate(dir:Rotated(cone), speed * lead), weight = 0.16},
				{pos = pos:Extrapolate(dir:Rotated(-cone), speed * lead), weight = 0.16},
				{pos = pos, weight = 0.08},
				{pos = pos:Extrapolate(dir, -speed * lead * 0.34), weight = back_weight},
			}

			local total = 0
			for _, sample in ipairs(samples) do total = total + sample.weight end
			for _, sample in ipairs(samples) do sample.weight = sample.weight / total end

			return samples
		end),

		point_segment_distance = a(function (from, to, point)
			local line = to - from
			local projected = point - from
			local len_sqr = line:Length2DSqr()
			if len_sqr <= 0.001 then return from:Distance2D(point), 0, from end

			local t = math.clamp(projected:Dot2D(line) / len_sqr, 0, 1)
			local closest = from + line * t
			return closest:Distance2D(point), t, closest
		end),

		line_hit_chance = a(function (unit, start_pos, dir, length, first_time, params)
			if helpers.is_disabled(unit) then return 0.98 end

			local chance = 0
			local samples = ui.line_samples:Get()
			local radius = params.radius + NPC.GetHullRadius(unit) + 22
			local vel, speed = helpers.movement_vector(unit)

			for i = 0, samples do
				local step = length * (i / samples)
				local time = first_time + step / params.speed
				local line_pos = start_pos:Extrapolate(dir, step)
				local local_chance = 0

				for _, sample in ipairs(helpers.prediction_samples(unit, time)) do
					local distance = sample.pos:Distance2D(line_pos)
					if distance <= radius then
						local_chance = local_chance + sample.weight * math.clamp(1 - distance / (radius * 1.35), 0.34, 1)
					end
				end

				chance = math.max(chance, local_chance)
			end

			if speed > 10 then
				local target_start = helpers.predict_pos(unit, first_time)
				local projectile_vel = dir * params.speed
				local rel = target_start - start_pos
				local rel_vel = vel - projectile_vel
				local rel_len = rel_vel:Length2DSqr()

				if rel_len > 1 then
					local t = math.clamp(-rel:Dot2D(rel_vel) / rel_len, 0, length / params.speed)
					local bullet_pos = start_pos + projectile_vel * t
					local target_pos = target_start + vel * t
					local distance = bullet_pos:Distance2D(target_pos)

					if distance <= radius + 28 then
						chance = math.max(chance, math.clamp(1 - distance / ((radius + 28) * 1.45), 0.32, 0.96))
					end
				end
			end

			if NPC.IsTurning(unit) then chance = chance * cfg.prediction.turn_penalty end
			return math.clamp(chance, 0, 1)
		end),

		count_line_hits = a(function (enemies, target, start_pos, dir, length, first_time, params)
			local result = {
				heroes = 0,
				damage = 0,
				target_hit = false,
				names = {},
			}

			local end_pos = start_pos:Extrapolate(dir, length)
			local radius = params.radius + 35

			for _, enemy in ipairs(enemies) do
				if helpers.is_enemy_hero(enemy) then
					local predicted = helpers.predict_intercept(enemy, start_pos, first_time, params.speed, length)
					local distance = helpers.point_segment_distance(start_pos, end_pos, predicted)

					if distance <= radius + NPC.GetHullRadius(enemy) then
						result.heroes = result.heroes + 1
						result.damage = result.damage + helpers.effective_damage(enemy, params.damage)
						result.names[#result.names + 1] = NPC.GetUnitName(enemy)
						if enemy == target then result.target_hit = true end
					end
				end
			end

			return result
		end),

		get_enemies = a(function (hero, radius)
			local enemies = Entity.GetHeroesInRadius(hero, radius, Enum.TeamType.TEAM_ENEMY, true) or {}
			local result = {}
			local hero_pos = Entity.GetAbsOrigin(hero)

			for _, enemy in ipairs(enemies) do
				if helpers.is_enemy_hero(enemy) then result[#result + 1] = enemy end
			end

			table.sort(result, function (a, b)
				return Entity.GetAbsOrigin(a):Distance2D(hero_pos) < Entity.GetAbsOrigin(b):Distance2D(hero_pos)
			end)

			return result
		end),

		get_cursor_target = a(function (hero, radius)
			local hero_pos = Entity.GetAbsOrigin(hero)
			local target = Input.GetNearestHeroToCursor(Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY)
			if target and helpers.is_enemy_hero(target) and hero_pos:IsInRange2D(Entity.GetAbsOrigin(target), radius) then
				return target
			end
		end),

		add_anchor = a(function (anchors, hero_pos, entity, kind, pos, priority, params)
			if hero_pos:IsInRange2D(pos, params.cast_range + 80) then
				anchors[#anchors + 1] = {
					entity = entity,
					kind = kind,
					pos = pos,
					priority = priority,
				}
			end
		end),

		build_anchors = a(function (hero, enemies, params)
			local hero_pos = Entity.GetAbsOrigin(hero)
			local anchors = {}

			if helpers.source_enabled("hero") then
				for _, enemy in ipairs(enemies) do
					local pos = Entity.GetAbsOrigin(enemy)
					helpers.add_anchor(anchors, hero_pos, enemy, "hero", pos, 1000 - hero_pos:Distance2D(pos) * 0.1, params)
				end
			end

			if helpers.source_enabled("creep") and ui.max_creeps:Get() > 0 then
				local units = Entity.GetUnitsInRadius(hero, params.cast_range + 120, Enum.TeamType.TEAM_ENEMY, true) or {}
				local creeps = {}

				for _, unit in ipairs(units) do
					if helpers.is_enemy_creep(unit) then
						local pos = Entity.GetAbsOrigin(unit)
						creeps[#creeps + 1] = {
							entity = unit,
							pos = pos,
							dist = hero_pos:Distance2D(pos),
						}
					end
				end

				table.sort(creeps, function (a, b) return a.dist < b.dist end)
				for i = 1, math.min(ui.max_creeps:Get(), #creeps) do
					helpers.add_anchor(anchors, hero_pos, creeps[i].entity, "creep", creeps[i].pos, 420 - creeps[i].dist * 0.04, params)
				end
			end

			if helpers.source_enabled("tree") and ui.max_trees:Get() > 0 then
				local trees = Trees.InRadius(hero_pos, params.cast_range + 120, true) or {}
				local sorted = {}

				for _, tree in ipairs(trees) do
					local pos = Entity.GetAbsOrigin(tree)
					sorted[#sorted + 1] = {
						entity = tree,
						pos = pos,
						dist = hero_pos:Distance2D(pos),
					}
				end

				table.sort(sorted, function (a, b) return a.dist < b.dist end)
				for i = 1, math.min(ui.max_trees:Get(), #sorted) do
					helpers.add_anchor(anchors, hero_pos, sorted[i].entity, "tree", sorted[i].pos, 260 - sorted[i].dist * 0.03, params)
				end
			end

			table.sort(anchors, function (a, b) return a.priority > b.priority end)
			while #anchors > ui.max_candidates:Get() do table.remove(anchors) end

			return anchors
		end),

		choose_direct_direction = a(function (hero_pos, target, target_pos, enemies, first_time, params)
			local best_dir = target_pos:DirectionTo(hero_pos)
			local best_enemy = nil
			local best_score = 0
			local ricochet_len = helpers.ricochet_length(hero_pos:Distance2D(target_pos), params)

			for _, enemy in ipairs(enemies) do
				if enemy ~= target and helpers.is_enemy_hero(enemy) then
					local predicted = helpers.predict_intercept(enemy, target_pos, first_time, params.speed, ricochet_len)
					local distance = target_pos:Distance2D(predicted)

					if distance <= ricochet_len + params.radius then
						local dir = target_pos:DirectionTo(predicted)
						local fear = dir:Dot2D(predicted:DirectionTo(hero_pos))
						local chance = helpers.line_hit_chance(enemy, target_pos, dir, ricochet_len, first_time, params)
						local score = chance * 140 + math.max(0, fear) * 110 - distance * 0.03

						if score > best_score then
							best_dir = dir
							best_enemy = enemy
							best_score = score
						end
					end
				end
			end

			return best_dir, best_enemy, best_score
		end),

		make_plan = a(function (hero, ability, target, cast_entity, cast_pos, dir, params, data)
			data.hero = hero
			data.ability = ability
			data.target = target
			data.cast_entity = cast_entity
			data.cast = cast_pos
			data.ricochet_length = data.ricochet_length or params.ricochet
			data.end_pos = cast_pos:Extrapolate(dir, data.ricochet_length)
			if not data.vector then
				if data.anchor_kind == "target" or data.anchor_kind == "hero" or data.anchor_kind == "creep" then
					data.vector = Entity.GetAbsOrigin(cast_entity):Extrapolate(dir, data.ricochet_length)
				else
					data.vector = data.end_pos
				end
			end
			data.dir = dir
			data.hero_pos = Entity.GetAbsOrigin(hero)
			return data
		end),

		evaluate_direct = a(function (hero, ability, target, enemies, params)
			if not ui.direct_lethal:Get() then return nil end

			local current_hero_pos = Entity.GetAbsOrigin(hero)
			local hero_pos = helpers.caster_position(hero, params)
			local target_pos = Entity.GetAbsOrigin(target)
			local predicted, impact_time = helpers.predict_intercept(target, hero_pos, params.cast_point + params.latency, params.speed, params.cast_range)
			if not current_hero_pos:IsInRange2D(target_pos, params.cast_range + 85) then return nil end

			local damage = helpers.effective_damage(target, params.damage)
			local lethal = helpers.is_lethal(target, damage)
			local hit_chance = helpers.is_disabled(target) and 0.98 or math.clamp(0.91 - impact_time * 0.09, 0.54, 0.94)
			local dir, secondary, secondary_score = helpers.choose_direct_direction(hero_pos, target, predicted, enemies, impact_time, params)
			local ricochet_len = helpers.ricochet_length(hero_pos:Distance2D(predicted), params)

			local hits = helpers.count_line_hits(enemies, target, predicted, dir, ricochet_len, impact_time, params)
			local score = 520 + hit_chance * 250 + secondary_score
			if lethal then score = score + cfg.score.direct_lethal end
			if secondary then score = score + 180 end
			if not lethal and not secondary then score = score - 330 end

			return helpers.make_plan(hero, ability, target, target, predicted, dir, params, {
				score = score,
				hit_chance = hit_chance,
				fear_score = secondary and 1 or 0,
				travel_time = impact_time,
				reason = lethal and "direct lethal" or (secondary and "direct chain" or "direct damage"),
				anchor_kind = "target",
				lethal = lethal,
				damage_only = not lethal and not secondary,
				hits = hits,
				primary_damage = damage,
				ricochet_length = ricochet_len,
			})
		end),

		evaluate_far = a(function (hero, ability, target, enemies, params)
			if not ui.far_shot:Get() then return nil end

			local current_hero_pos = Entity.GetAbsOrigin(hero)
			local hero_pos = helpers.caster_position(hero, params)
			local target_pos = Entity.GetAbsOrigin(target)
			local distance = current_hero_pos:Distance2D(target_pos)
			if distance <= params.cast_range + 85 then return nil end
			if distance > params.cast_range + params.ricochet + params.radius + NPC.GetHullRadius(target) then return nil end

			local dir_to_target = hero_pos:DirectionTo(target_pos)
			local cast_pos = hero_pos:Extrapolate(dir_to_target, math.max(120, params.cast_range - cfg.deadshot.range_buffer))
			local first_time = params.cast_point + params.latency + hero_pos:Distance2D(cast_pos) / params.speed
			local ricochet_len = helpers.ricochet_length(hero_pos:Distance2D(cast_pos), params)
			local predicted, impact_time = helpers.predict_intercept(target, cast_pos, first_time, params.speed, ricochet_len)
			local bounce_dist = cast_pos:Distance2D(predicted)
			if bounce_dist > ricochet_len + params.radius + NPC.GetHullRadius(target) then return nil end

			local dir = cast_pos:DirectionTo(predicted)
			local hit_chance = helpers.line_hit_chance(target, cast_pos, dir, ricochet_len, first_time, params)
			local damage = helpers.effective_damage(target, params.damage)
			local lethal = helpers.is_lethal(target, damage)
			if hit_chance < 0.62 and not lethal then return nil end

			local fear_score = dir:Dot2D(predicted:DirectionTo(hero_pos))
			local hits = helpers.count_line_hits(enemies, target, cast_pos, dir, ricochet_len, first_time, params)
			if not hits.target_hit and not lethal then return nil end

			local score = 260 + hit_chance * 310 + math.max(0, fear_score) * 90
			score = score + math.min(hits.damage * 0.14, 170)
			score = score - impact_time * cfg.score.travel_penalty
			if lethal then score = score + cfg.score.far_lethal end

			return helpers.make_plan(hero, ability, target, target, cast_pos, dir, params, {
				score = score,
				hit_chance = hit_chance,
				fear_score = fear_score,
				travel_time = impact_time,
				reason = "far ricochet",
				anchor_kind = "point",
				lethal = lethal,
				hits = hits,
				primary_damage = damage,
				ricochet_length = ricochet_len,
			})
		end),

		evaluate_anchor = a(function (hero, ability, target, anchor, enemies, params)
			if anchor.entity == target then return nil end

			local current_hero_pos = Entity.GetAbsOrigin(hero)
			local hero_pos = helpers.caster_position(hero, params)
			local anchor_pos = anchor.pos
			local first_time = params.cast_point + params.latency + hero_pos:Distance2D(anchor_pos) / params.speed

			if anchor.kind ~= "tree" then
				for _ = 1, 3 do
					anchor_pos = helpers.predict_pos(anchor.entity, first_time)
					first_time = params.cast_point + params.latency + hero_pos:Distance2D(anchor_pos) / params.speed
				end
			end

			if not current_hero_pos:IsInRange2D(anchor.pos, params.cast_range + 90) then return nil end

			local first_distance = hero_pos:Distance2D(anchor_pos)
			local ricochet_len = helpers.ricochet_length(first_distance, params)
			local predicted, impact_time = helpers.predict_intercept(
				target,
				anchor_pos,
				first_time,
				params.speed,
				ricochet_len
			)
			local bounce_start = anchor_pos

			local bounce_dist = bounce_start:Distance2D(predicted)
			if bounce_dist < 65 or bounce_dist > ricochet_len + params.radius + NPC.GetHullRadius(target) then return nil end

			local dir = bounce_start:DirectionTo(predicted)
			local fear_score = dir:Dot2D(predicted:DirectionTo(hero_pos))
			local damage = helpers.effective_damage(target, params.damage)
			local lethal = helpers.is_lethal(target, damage)
			local damage_only = fear_score < ui.min_fear:Get() * 0.01 and not lethal

			local hit_chance = helpers.line_hit_chance(target, bounce_start, dir, ricochet_len, first_time, params)
			local fear_plan = fear_score > 0.38
			local long_risk = impact_time > 1.12 or bounce_dist > 720
			if fear_plan and long_risk and hit_chance < 0.74 and not lethal then return nil end
			if hit_chance < (damage_only and 0.40 or 0.52) and not lethal then return nil end

			local hits = helpers.count_line_hits(enemies, target, bounce_start, dir, ricochet_len, first_time, params)
			if not hits.target_hit and not lethal then return nil end

			local anchor_damage = 0
			local anchor_lethal = false
			if anchor.kind == "hero" and helpers.is_enemy_hero(anchor.entity) then
				anchor_damage = helpers.effective_damage(anchor.entity, params.damage)
				anchor_lethal = helpers.is_lethal(anchor.entity, anchor_damage)
			end

			local score = hit_chance * 330
			score = score + math.max(0, fear_score) * ui.fear_weight:Get()
			score = score + hits.heroes * 90
			score = score + math.min(hits.damage * 0.18, 220)
			score = score + math.min(anchor_damage * 0.22, 160)
			score = score - impact_time * cfg.score.travel_penalty
			score = score - math.max(0, bounce_dist - 450) * cfg.score.long_bounce_penalty

			if anchor.kind == "hero" then
				score = score + cfg.score.hero_anchor
				if ui.prefer_double:Get() then score = score + cfg.score.prefer_double end
			elseif anchor.kind == "creep" then
				score = score + cfg.score.creep_anchor
			elseif anchor.kind == "tree" then
				score = score + cfg.score.tree_anchor
			end

			if fear_plan then
				local fast_bonus = math.clamp(1.15 - impact_time, 0, 0.75)
				local close_bonus = math.clamp((720 - bounce_dist) / 720, 0, 1)
				score = score + fear_score * hit_chance * 330
				score = score + fast_bonus * 260 + close_bonus * 120
				if anchor.kind == "tree" and impact_time < 0.95 and hit_chance >= 0.68 then score = score + 110 end
			end

			if anchor.kind == "tree" and impact_time > 1.05 and not lethal then score = score - (impact_time - 1.05) * 360 end
			if anchor.kind == "tree" and bounce_dist > 760 and not lethal then score = score - (bounce_dist - 760) * 0.35 end

			if hits.heroes >= 2 then score = score + cfg.score.double_hit end
			if lethal then score = score + cfg.score.target_lethal end
			if anchor_lethal then score = score + cfg.score.anchor_lethal end
			if damage_only and hits.target_hit then score = score + (anchor.kind == "tree" and 150 or 90) end

			local vel, speed = helpers.movement_vector(target)
			if speed > 40 then
				local away = vel:Normalized():Dot2D(hero_pos:DirectionTo(predicted))
				if away > 0.35 and fear_score > 0.35 then score = score + 90 end
			end

			return helpers.make_plan(hero, ability, target, anchor.entity, anchor_pos, dir, params, {
				score = score,
				hit_chance = hit_chance,
				fear_score = fear_score,
				travel_time = impact_time,
				reason = anchor.kind .. " bounce",
				anchor_kind = anchor.kind,
				anchor = anchor.entity,
				fear_plan = fear_plan,
				bounce_dist = bounce_dist,
				lethal = lethal,
				anchor_lethal = anchor_lethal,
				damage_only = damage_only,
				vector = anchor.kind == "tree" and predicted or nil,
				hits = hits,
				primary_damage = damage,
				anchor_damage = anchor_damage,
				ricochet_length = ricochet_len,
			})
		end),

		accept_plan = a(function (plan, manual)
			local min_score = ui.min_score:Get()
			local min_hit = ui.min_hit:Get() * 0.01

			if manual then
				min_score = min_score * 0.78
				min_hit = math.max(0.25, min_hit - 0.12)
			end

			if plan.lethal or plan.anchor_lethal then
				min_score = min_score * 0.65
				min_hit = math.max(0.20, min_hit - 0.18)
			end

			if plan.damage_only then
				min_score = min_score * 0.82
				min_hit = math.max(0.30, min_hit - 0.10)
			end

			return plan.score >= min_score and plan.hit_chance >= min_hit
		end),

		select_best_plan = a(function (hero, ability, preferred, manual)
			local params = helpers.get_params(hero, ability)
			local enemies = helpers.get_enemies(hero, cfg.search_radius)
			local targets = {}

			if preferred and helpers.is_enemy_hero(preferred) then
				targets[1] = preferred
			end

			for _, enemy in ipairs(enemies) do
				if enemy ~= preferred then targets[#targets + 1] = enemy end
			end

			while #targets > ui.max_targets:Get() do table.remove(targets) end

			local anchors = helpers.build_anchors(hero, enemies, params)
			local plans = {}
			local best = nil

			for _, target in ipairs(targets) do
				local direct = helpers.evaluate_direct(hero, ability, target, enemies, params)
				if direct then
					if manual and preferred and target == preferred then
						if direct.lethal and direct.hit_chance >= 0.70 then
							direct.score = direct.score + 360
						elseif direct.hit_chance >= 0.82 and direct.hits and direct.hits.heroes >= 2 then
							direct.score = direct.score + 180
						end
						direct.manual_primary = true
					end
					plans[#plans + 1] = direct
					if not best or direct.score > best.score then best = direct end
				end

				for _, anchor in ipairs(anchors) do
					local plan = helpers.evaluate_anchor(hero, ability, target, anchor, enemies, params)
					if plan then
						if manual and preferred and target == preferred then
							if plan.lethal and plan.hit_chance >= 0.68 then
								plan.score = plan.score + 260
							elseif plan.hit_chance >= 0.82 and plan.hits and plan.hits.heroes >= 2 then
								plan.score = plan.score + 120
							end
							plan.manual_primary = true
						end
						plans[#plans + 1] = plan
						if not best or plan.score > best.score then best = plan end
					end
				end
			end

			table.sort(plans, function (a, b) return a.score > b.score end)
			while #plans > 8 do table.remove(plans) end

			return best, plans
		end),

		cast_plan = a(function (plan)
			local now = GameRules.GetGameTime()
			if now - state.last_cast < 0.28 then return false end

			local player = Players.GetLocal()

			if plan.anchor_kind == "tree" then
				Player.PrepareUnitOrders(
					player,
					Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION,
					nil,
					plan.vector,
					plan.ability,
					Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
					nil,
					false,
					true
				)

				Player.PrepareUnitOrders(
					player,
					order_cast_target_tree,
					plan.cast_entity,
					Vector(0, 0, 0),
					plan.ability,
					Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS,
					nil,
					false,
					true
				)
			else
				Player.PrepareUnitOrders(
					player,
					Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION,
					plan.cast_entity,
					plan.vector,
					plan.ability,
					Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
					plan.hero,
					false,
					true
				)

				Player.PrepareUnitOrders(
					player,
					Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET,
					plan.cast_entity,
					Vector(0, 0, 0),
					plan.ability,
					Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
					plan.hero,
					false,
					true
				)
			end

			state.last_cast = now
			helpers.log(
				"cast",
				plan.reason,
				"score",
				math.floor(plan.score),
				"hit",
				math.floor(plan.hit_chance * 100),
				"fear",
				math.floor(math.max(0, plan.fear_score) * 100)
			)
			return true
		end),

		draw_world_line = a(function (from, to, color, thickness)
			local a_pos, a_visible = Render.WorldToScreen(from)
			local b_pos, b_visible = Render.WorldToScreen(to)
			if a_visible and b_visible then Render.Line(a_pos, b_pos, color, thickness or 1) end
		end),

		draw_world_circle = a(function (pos, radius, color)
			local screen, visible = Render.WorldToScreen(pos)
			if visible then Render.Circle(screen, radius, color) end
		end),

		draw_text = a(function (pos, text, color)
			local screen, visible = Render.WorldToScreen(pos + Vector(0, 0, 120))
			if not visible then return end

			Render.Text(render_ctx.font, 13, text, Vec2(screen.x + 1, screen.y + 1), cfg.visual.shadow)
			Render.Text(render_ctx.font, 13, text, screen, color or cfg.visual.text)
		end),

		draw_plan = a(function (plan, index)
			helpers.draw_world_line(plan.hero_pos, plan.cast, cfg.visual.first, index and 1 or 2)
			helpers.draw_world_line(plan.cast, plan.end_pos, cfg.visual.ricochet, index and 1 or 2.5)
			helpers.draw_world_circle(plan.cast, index and 4 or 7, cfg.visual.ricochet)
			helpers.draw_world_circle(Entity.GetAbsOrigin(plan.target), index and 4 or 6, plan.hit_chance >= ui.min_hit:Get() * 0.01 and cfg.visual.good or cfg.visual.bad)

			if not index then
				helpers.draw_text(plan.cast, string.format(
					"%s | %d score | %d%% hit | %d%% fear",
					plan.reason,
					math.floor(plan.score),
					math.floor(plan.hit_chance * 100),
					math.floor(math.max(0, plan.fear_score) * 100)
				), cfg.visual.text)
			end
		end),
	}
end


local core do
	core = {
		run = a(function ()
			if not ui.enable:Get() then
				helpers.reset_runtime()
				return
			end

			state.hero = Heroes.GetLocal()
			if not helpers.is_local_muerta(state.hero) or not Entity.IsAlive(state.hero) then
				helpers.reset_runtime()
				return
			end

			helpers.update_enemy_track(state.hero)

			local manual = helpers.combo_key_down()
			if not manual then
				helpers.reset_runtime()
				return
			end

			if Input.IsInputCaptured() then return end

			local now = GameRules.GetGameTime()
			if now < state.last_think + ui.think_ms:Get() * 0.001 then return end
			state.last_think = now

			local ability = helpers.get_dead_shot(state.hero)
			if not ability then return end
			if not Ability.IsCastable(ability, NPC.GetMana(state.hero)) then return end
			if Ability.IsInAbilityPhase(ability) then return end

			local preferred = nil

			if manual and ui.target_mode:Get() == cfg.mode.cursor then
				preferred = helpers.get_cursor_target(state.hero, cfg.search_radius)
			end

			local best, plans = helpers.select_best_plan(state.hero, ability, preferred, manual)
			state.best_plan = best
			state.plans = plans

			if best and helpers.accept_plan(best, manual) then
				helpers.cast_plan(best)
			end
		end),
	}
end


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

callbacks.update:set(a(function ()
	core.run()
end))

callbacks.update_ex:set(a(function ()
	helpers.update_menu_visibility()
end))

callbacks.draw:set(a(function ()

end))

callbacks.game_end:set(a(function ()
	state.enemy_track = {}
	state.best_plan = nil
	state.plans = {}
	state.last_think = 0
	state.last_cast = 0
end))

function muerta.OnUpdate()
	callbacks.update:fire()
end

function muerta.OnUpdateEx()
	callbacks.update_ex:fire()
end

function muerta.OnDraw()
	callbacks.draw:fire()
end

function muerta.OnGameEnd()
	callbacks.game_end:fire()
end


return muerta
