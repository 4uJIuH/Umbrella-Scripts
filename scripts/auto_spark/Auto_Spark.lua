local localization = qLocalization.new({
	en = {
		aw_group_main = "Main",
		aw_enable = "Enable",
		aw_enable_tip = "Turns the script on",
		aw_mode = "Operating mode",
		aw_modes_automatic = "Automatic",
		aw_modes_mechanical = "Mechanical",
		aw_mode_tip = "Choose automatic casting or casting while holding a key",
		aw_cast_key = "Cast key",
		aw_cast_key_tip = "Hold this key to cast Spark Wraith in Mechanical mode",
		aw_until = "Stop after minute",
		aw_until_tip = "Stops automatic casts after this game minute",
		aw_group_tuning = "Targeting precision",
		aw_min_distance = "Minimum distance moved",
		aw_min_distance_tip = "Minimum distance the enemy must travel before targeting",
		aw_stable_time = "Stable movement time",
		aw_stable_time_tip = "How long the enemy movement must remain stable",
		aw_direction_variance = "Direction deviation",
		aw_direction_variance_tip = "Maximum allowed movement direction deviation",
		aw_creep_radius = "Creep exclusion radius",
		aw_creep_radius_tip = "Spark Wraith is not cast if an enemy creep is inside this radius",
		aw_standing_time = "Standing time",
		aw_standing_time_tip = "How long the enemy must remain nearly stationary before targeting",
	},
	ru = {
		aw_group_main = "Основное",
		aw_enable = "Включить",
		aw_enable_tip = "Включает скрипт",
		aw_mode = "Режим работы",
		aw_modes_automatic = "Автоматический",
		aw_modes_mechanical = "Механический",
		aw_mode_tip = "Автоматически применять способность или кастовать при удержании клавиши",
		aw_cast_key = "Клавиша каста",
		aw_cast_key_tip = "Удерживайте клавишу для каста Spark Wraith в механическом режиме",
		aw_until = "Работать до минуты",
		aw_until_tip = "Останавливает автоматические касты после этой минуты игры",
		aw_group_tuning = "Точность выбора цели",
		aw_min_distance = "Минимальная пройденная дистанция",
		aw_min_distance_tip = "Минимальная дистанция, которую враг должен пройти перед выбором",
		aw_stable_time = "Время стабильного движения",
		aw_stable_time_tip = "Как долго движение врага должно оставаться стабильным",
		aw_direction_variance = "Отклонение направления",
		aw_direction_variance_tip = "Максимально допустимое отклонение направления движения",
		aw_creep_radius = "Радиус исключения крипов",
		aw_creep_radius_tip = "Spark Wraith не ставится, если вражеский крип находится внутри этого радиуса",
		aw_standing_time = "Время неподвижности",
		aw_standing_time_tip = "Как долго враг должен почти не двигаться перед выбором целью",
	},
})

local UI = localization.WrapLibrary(Menu)

local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "Auto Spark")
	tab:Icon("\u{f013}")

	local page = tab:Create("Settings")
	local g_main = page:Create("aw_group_main", Enum.GroupSide.Left)
	local g_tuning = page:Create("aw_group_tuning", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("aw_enable", false, "\u{f011}")
	ui.enable:ToolTip("aw_enable_tip")
	ui.mode = g_main:Combo(
		"aw_mode",
		{ "aw_modes_automatic", "aw_modes_mechanical" },
		0
	)
	ui.mode:ToolTip("aw_mode_tip")
	ui.cast_key = g_main:Bind("aw_cast_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.cast_key:ToolTip("aw_cast_key_tip")
	ui.until_minute = g_main:Slider("aw_until", 1, 30, 10, "%d")
	ui.until_minute:Icon("\u{f11e}")
	ui.until_minute:ToolTip("aw_until_tip")

	ui.min_distance = g_tuning:Slider("aw_min_distance", 0, 300, 40, "%d")
	ui.min_distance:Icon("\u{f337}")
	ui.min_distance:ToolTip("aw_min_distance_tip")
	ui.stable_time = g_tuning:Slider("aw_stable_time", 0.1, 2.0, 0.35, "%.2f s")
	ui.stable_time:Icon("\u{f017}")
	ui.stable_time:ToolTip("aw_stable_time_tip")
	ui.direction_variance = g_tuning:Slider("aw_direction_variance", 0, 50, 30, "%d%%")
	ui.direction_variance:Icon("\u{f1de}")
	ui.direction_variance:ToolTip("aw_direction_variance_tip")
	ui.creep_radius = g_tuning:Slider("aw_creep_radius", 375, 600, 375, "%d")
	ui.creep_radius:Icon("\u{f1ce}")
	ui.creep_radius:ToolTip("aw_creep_radius_tip")
	ui.standing_time = g_tuning:Slider("aw_standing_time", 0.1, 2.0, 0.35, "%.2f s")
	ui.standing_time:Icon("\u{f04d}")
	ui.standing_time:ToolTip("aw_standing_time_tip")
end

local function refresh_disabled()
	local on = ui.enable:Get()
	local mechanical = ui.mode:Get() == 1
	ui.mode:Disabled(not on)
	ui.cast_key:Disabled(not on or not mechanical)
	ui.until_minute:Disabled(not on)
	ui.min_distance:Disabled(not on)
	ui.stable_time:Disabled(not on)
	ui.direction_variance:Disabled(not on)
	ui.creep_radius:Disabled(not on)
	ui.standing_time:Disabled(not on)
end

ui.enable:SetCallback(refresh_disabled, true)
ui.mode:SetCallback(refresh_disabled)

local K = {
	HERO_NAME = "npc_dota_hero_arc_warden",
	ABILITY_NAME = "arc_warden_spark_wraith",
	DEFAULT_ACTIVATION_DELAY = 1.5,
	DEFAULT_RADIUS = 375.0,
	SAFETY_MARGIN = 50.0,
	UPDATE_INTERVAL = 0.08,
	CAST_LOCK = 0.25,
	HISTORY_CLEANUP = 5.0,
}

local state = {
	next_update = 0,
	next_cast = 0,
	target_history = {},
	next_cleanup = 0,
}

local function get_game_time()
	return math.max(0, GameRules.GetDOTATime(false, false))
end

local function is_local_arc_warden(hero)
	return hero
		and Entity.IsAlive(hero)
		and NPC.GetUnitName(hero) == K.HERO_NAME
end

local function get_special_value(ability, name, fallback)
	local value = Ability.GetLevelSpecialValueFor(ability, name)
	if value and value > 0 then
		return value
	end
	return fallback
end

local function is_valid_enemy(hero, local_hero)
	return hero
		and hero ~= local_hero
		and Entity.IsAlive(hero)
		and not Entity.IsDormant(hero)
		and NPC.IsHero(hero)
		and not NPC.IsIllusion(hero)
		and NPC.IsVisible(hero)
		and not Entity.IsSameTeam(hero, local_hero)
end

local function update_target_history(target, now)
	local target_id = Entity.GetIndex(target)
	local pos = Entity.GetAbsOrigin(target)
	local history = state.target_history[target_id]

	if not history then
		history = { positions = {}, times = {}, last_update = now }
		state.target_history[target_id] = history
	end

	table.insert(history.positions, pos)
	table.insert(history.times, now)
	history.last_update = now

	while #history.positions > 15 do
		table.remove(history.positions, 1)
		table.remove(history.times, 1)
	end
end

local function is_stable_movement(target, now)
	local target_id = Entity.GetIndex(target)
	local history = state.target_history[target_id]

	if not history or #history.positions < 3 then
		return false
	end

	local oldest_time = history.times[1]
	local movement_duration = now - oldest_time

	if movement_duration < ui.stable_time:Get() then
		return false
	end

	local oldest_pos = history.positions[1]
	local current_pos = history.positions[#history.positions]
	local total_distance = oldest_pos:Distance2D(current_pos)

	if total_distance < ui.min_distance:Get() then
		return false
	end

	local directions = {}
	for i = 1, #history.positions - 1 do
		local dir = (history.positions[i + 1] - history.positions[i]):Normalized()
		table.insert(directions, dir)
	end

	if #directions < 2 then
		return false
	end

	local avg_direction = Vector(0, 0, 0)
	for _, dir in ipairs(directions) do
		avg_direction = avg_direction + dir
	end
	avg_direction = avg_direction:Scaled(1.0 / #directions):Normalized()

	for _, dir in ipairs(directions) do
		if dir:Dot2D(avg_direction) < (1.0 - ui.direction_variance:Get() / 100.0) then
			return false
		end
	end

	return true, avg_direction
end

local function is_stationary(target, now)
	local target_id = Entity.GetIndex(target)
	local history = state.target_history[target_id]

	if not history or #history.positions < 3 then
		return false
	end

	if now - history.times[1] < ui.standing_time:Get() then
		return false
	end

	local first_position = history.positions[1]
	local current_position = history.positions[#history.positions]
	return first_position:Distance2D(current_position) < ui.min_distance:Get()
end

local function get_target_position(local_hero, target, ability, now)
	local local_pos = Entity.GetAbsOrigin(local_hero)
	local target_pos = Entity.GetAbsOrigin(target)
	local cast_range = Ability.GetCastRange(ability)
	local activation_delay = get_special_value(ability, "base_activation_delay", K.DEFAULT_ACTIVATION_DELAY)
	local radius = get_special_value(ability, "radius", K.DEFAULT_RADIUS)
	local total_delay = math.max(0, Ability.GetCastPoint(ability)) + activation_delay
	local target_speed = math.max(0, NPC.GetMoveSpeed(target))

	local is_stable, stable_direction = is_stable_movement(target, now)
	if is_stable and stable_direction and target_speed > 0 then
		local cast_position = target_pos + stable_direction:Scaled(target_speed * total_delay)
		local prediction_error = target_speed * 0.08

		return prediction_error + K.SAFETY_MARGIN <= radius
			and local_pos:Distance2D(cast_position) <= cast_range
			and cast_position
	end

	if is_stationary(target, now) then
		return local_pos:Distance2D(target_pos) <= cast_range and target_pos
	end

	return nil
end

local function has_nearby_enemy_creep(local_hero, position, radius)
	local check_radius = math.max(radius, ui.creep_radius:Get())

	for _, npc in ipairs(NPCs.GetAll()) do
		if npc
			and Entity.IsAlive(npc)
			and not Entity.IsDormant(npc)
			and NPC.IsCreep(npc)
			and not Entity.IsSameTeam(npc, local_hero)
			and Entity.GetAbsOrigin(npc):Distance2D(position) <= check_radius
		then
			return true
		end
	end

	return false
end

local function find_target(local_hero, ability, now)
	local best_target = nil
	local best_target_position = nil
	local best_distance = math.huge
	local local_pos = Entity.GetAbsOrigin(local_hero)
	local radius = get_special_value(ability, "radius", K.DEFAULT_RADIUS)

	for _, hero in ipairs(Heroes.GetAll()) do
		if is_valid_enemy(hero, local_hero) then
			update_target_history(hero, now)
			local cast_position = get_target_position(local_hero, hero, ability, now)
			local distance = cast_position and local_pos:Distance2D(cast_position) or math.huge
			if cast_position
				and not has_nearby_enemy_creep(local_hero, cast_position, radius)
				and distance < best_distance
			then
				best_target = hero
				best_distance = distance
				best_target_position = cast_position
			end
		end
	end

	return best_target, best_target_position
end

local script = {}

function script.OnUpdate()
	if not ui.enable:Get() then return end
	if ui.mode:Get() == 1
		and (
			not ui.cast_key:IsDown()
			or Input.IsInputCaptured()
			or Input.IsPopupOpen()
		)
	then
		return
	end
	local now = get_game_time()
	if now < state.next_update then return end
	state.next_update = now + K.UPDATE_INTERVAL
	if now >= ui.until_minute:Get() * 60 or now < 0 or GameRules.IsPaused() then return end

	if now >= state.next_cleanup then
		for target_id, history in pairs(state.target_history) do
			if now - history.last_update > K.HISTORY_CLEANUP then
				state.target_history[target_id] = nil
			end
		end
		state.next_cleanup = now + K.HISTORY_CLEANUP
	end

	local local_hero = Heroes.GetLocal()
	if not is_local_arc_warden(local_hero) or now < state.next_cast then return end

	local ability = NPC.GetAbility(local_hero, K.ABILITY_NAME)
	if not ability or not Ability.IsReady(ability) or not Ability.IsCastable(ability, NPC.GetMana(local_hero)) then
		return
	end

	local target, cast_position = find_target(local_hero, ability, now)
	if target and cast_position then
		Ability.CastPosition(ability, cast_position, false, false, true, "arc_warden_spark_wraith")
		state.next_cast = now + K.CAST_LOCK
	end
end

return script
