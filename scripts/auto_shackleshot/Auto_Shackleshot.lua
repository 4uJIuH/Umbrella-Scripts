local VERSION = "1.0.0"

local localization = qLocalization.new({
	en = {
		wsa_group_main = "Main",
		wsa_group_behavior = "Behavior",
		wsa_enable = "Enable",
		wsa_enable_tip = "Cast Shackleshot only for a long stun",
		wsa_automatic = "Automatic mode",
		wsa_automatic_tip = "Cast automatically without holding a key",
		wsa_key = "Cast key",
		wsa_key_tip = "Hold this key to use Shackleshot",
		wsa_range = "Search range",
		wsa_range_tip = "Maximum distance to an enemy",
		wsa_start_minute = "Works from minute",
		wsa_start_minute_tip = "Automatic casting starts from this game minute",
	},
	ru = {
		wsa_group_main = "Основное",
		wsa_group_behavior = "Поведение",
		wsa_enable = "Включить",
		wsa_enable_tip = "Применять Shackleshot только для долгого оглушения",
		wsa_automatic = "Автоматический режим",
		wsa_automatic_tip = "Применять способность без удержания кнопки",
		wsa_key = "Кнопка каста",
		wsa_key_tip = "Удерживайте эту кнопку для применения Shackleshot",
		wsa_range = "Дальность поиска",
		wsa_range_tip = "Максимальная дистанция до врага",
		wsa_start_minute = "Работает с минуты",
		wsa_start_minute_tip = "Автоматическое применение начинается с указанной минуты игры",
	},
})
local UI = localization.WrapLibrary(Menu)
local ui, state = {}, {
	next_scan = 0,
	cast_block_until = 0,
}
local K = {
	ability = "windrunner_shackleshot",
	modifier = "modifier_windrunner_shackleshot",
	anchor_radius = 575,
	angle_cos = 0.92,
	scan_interval = 0.03,
}
do
	local tab = UI.Create("Scripts", "Scripts", "Auto Shackleshot")
	tab:Icon("\u{f0c1}")
	local page = tab:Create("Settings")
	local main = page:Create("wsa_group_main", Enum.GroupSide.Left)
	local behavior = page:Create("wsa_group_behavior", Enum.GroupSide.Right)
	ui.enable = main:Switch("wsa_enable", false, "\u{f011}")
	ui.enable:ToolTip("wsa_enable_tip")
	ui.automatic = main:Switch("wsa_automatic", true, "\u{f1d8}")
	ui.automatic:ToolTip("wsa_automatic_tip")
	ui.key = main:Bind("wsa_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("wsa_key_tip")
	ui.range = behavior:Slider("wsa_range", 400, 1200, 800, "%d")
	ui.range:Icon("\u{f05b}")
	ui.range:ToolTip("wsa_range_tip")
	ui.start_minute = behavior:Slider("wsa_start_minute", 0, 60, 0, "%d")
	ui.start_minute:Icon("\u{f017}")
	ui.start_minute:ToolTip("wsa_start_minute_tip")
end
local function refresh_disabled()
	local on = ui.enable:Get()
	local automatic = ui.automatic:Get()
	ui.automatic:Disabled(not on)
	ui.key:Disabled(not on or automatic)
	ui.range:Disabled(not on)
	ui.start_minute:Disabled(not on)
end
ui.enable:SetCallback(refresh_disabled, true)
ui.automatic:SetCallback(refresh_disabled)
local function dist_sqr(a, b)
	local x, y = a.x - b.x, a.y - b.y
	return x * x + y * y
end
local function has_anchor(target, caster)
	local tp, cp = Entity.GetAbsOrigin(target), Entity.GetAbsOrigin(caster)
	local d = tp - cp
	local length = math.sqrt(d.x * d.x + d.y * d.y)
	if length < 0.01 then return false end
	d = Vector(d.x / length, d.y / length, 0)
	local target_team = Entity.GetTeamNum(target)
	for _, anchor in ipairs(NPCs.GetAll()) do
		if anchor ~= target
			and Entity.IsAlive(anchor)
			and not Entity.IsDormant(anchor)
			and not NPC.IsWard(anchor)
			and Entity.GetTeamNum(anchor) == target_team
		then
			local a = Entity.GetAbsOrigin(anchor) - tp
			local al = math.sqrt(a.x * a.x + a.y * a.y)
			local hull = NPC.GetHullRadius(anchor) or 24
			if al <= K.anchor_radius
				and al > hull
				and (a.x * d.x + a.y * d.y) / al >= K.angle_cos
			then
				return true
			end
		end
	end
	for _, tree in ipairs(Entity.GetTreesInRadius(target, K.anchor_radius, true)) do
		if Tree.IsActive(tree) then
			local a = Entity.GetAbsOrigin(tree) - tp
			local al = math.sqrt(a.x * a.x + a.y * a.y)
			if al > 25 and (a.x * d.x + a.y * d.y) / al >= K.angle_cos then return true end
		end
	end
	return false
end
local function find_target(hero, ability)
	local range = math.min(Ability.GetCastRange(ability) + 100, ui.range:Get())
	local origin = Entity.GetAbsOrigin(hero)
	local best, best_dist
	for _, enemy in ipairs(Entity.GetHeroesInRadius(hero, range, Enum.TeamType.TEAM_ENEMY, true, true)) do
		if Entity.IsAlive(enemy) and not NPC.HasModifier(enemy, K.modifier) and has_anchor(enemy, hero) then
			local distance = dist_sqr(origin, Entity.GetAbsOrigin(enemy))
			if not best_dist or distance < best_dist then best, best_dist = enemy, distance end
		end
	end
	return best
end
local script = {}
function script.OnUpdate()
	if not ui.enable:Get() then return end
	local now = GameRules.GetGameTime()
	if now < state.next_scan then return end
	state.next_scan = now + K.scan_interval
	if now < state.cast_block_until then return end
	if now < ui.start_minute:Get() * 60 then return end
	if not ui.automatic:Get()
		and (not ui.key:IsDown() or Input.IsInputCaptured())
	then
		return
	end
	local hero = Heroes.GetLocal()
	if not hero or NPC.GetUnitName(hero) ~= "npc_dota_hero_windrunner" or not Entity.IsAlive(hero) then return end
	local ability = NPC.GetAbility(hero, K.ability)
	if not ability
		or not Ability.IsReady(ability)
		or not Ability.IsCastable(ability, NPC.GetMana(hero))
	then
		return
	end
	local target = find_target(hero, ability)
	if target then
		Ability.CastTarget(ability, target, false, false, true, "wsa_long_shackle")
		state.cast_block_until = now + 0.6
	end
end
return script
