local cooldown = {}

local chronos = require("chronos")
local JSON = require("assets.JSON")

local cfg = {
	updateInterval = 0.05,
	handleInterval = 0.25,
	observationInterval = 0.25,
	idleHeartbeatInterval = 0.25,
	retryInterval = 1,
	lastAbilityIndex = 34,
	itemSlots = {0, 1, 2, 3, 4, 5, 6, 7, 8, 15, 16},
	selectionAttribute = "selected_enemy_cooldowns_selection",
	hudPath = {"DotaHud", "Hud"},
}

local ui = {}
local state = {
	panel = nil,
	nextUpdate = 0,
	nextConnect = 0,
	nextHandles = 0,
	nextObservation = 0,
	nextPaint = 0,
	hadRows = false,
	selection = "",
	target = nil,
	handles = {},
	observations = {},
	lastGameTime = nil,
}

local panoramaSource = [=[
(function () {
	var host = $.GetContextPanel();
	if (host.__selectedEnemyCooldowns) host.__selectedEnemyCooldowns.dispose();
	var attribute = "selected_enemy_cooldowns_selection";
	var bindings = [];
	var subscriptions = [];
	var revision = 0;
	var portrait = -1;
	var token = "";
	var lastPaint = Date.now();
	var nextDiscovery = 0;
	var timer = null;
	var disposed = false;

	function hide() {
		for (var i = 0; i < bindings.length; ++i) {
			if (bindings[i].overlay.IsValid()) bindings[i].overlay.visible = false;
		}
	}

	function selectionChanged(force) {
		var current = Players.GetLocalPlayerPortraitUnit();
		if (!force && current === portrait) return;
		portrait = current;
		token = String(current) + ":" + String(++revision);
		host.SetAttributeString(attribute, token);
		nextDiscovery = 0;
		hide();
	}

	function addImage(image, kind, round) {
		for (var i = 0; i < bindings.length; ++i) {
			if (bindings[i].image === image) return;
		}
		var overlay = $.CreatePanel("Panel", image, "");
		overlay.__selectedEnemyCooldownOverlay = true;
		overlay.hittest = false;
		overlay.hittestchildren = false;
		overlay.style.width = "100%";
		overlay.style.height = "100%";
		overlay.style.flowChildren = "none";
		overlay.style.borderRadius = round ? "50%" : "2px";
		overlay.style.overflow = "clip";
		overlay.style.zIndex = 10;
		overlay.visible = false;
		var wedge = $.CreatePanel("Panel", overlay, "");
		wedge.hittest = false;
		wedge.style.width = "100%";
		wedge.style.height = "100%";
		wedge.style.borderRadius = round ? "50%" : "2px";
		var label = $.CreatePanel("Label", overlay, "");
		label.hittest = false;
		label.style.horizontalAlign = "center";
		label.style.verticalAlign = "middle";
		label.style.fontFamily = "Radiance";
		label.style.fontWeight = "bold";
		label.style.textAlign = "center";
		bindings.push({image: image, kind: kind, overlay: overlay, wedge: wedge,
			label: label, text: null, angle: null, theme: null});
	}

	function visit(panel, round) {
		if (panel.__selectedEnemyCooldownOverlay) return;
		round = round || panel.id === "inventory_tpscroll_container"
			|| panel.id === "inventory_neutral_slot_container" || panel.BHasClass("is_fake_item");
		if (panel.id === "AbilityImage" && panel.paneltype === "DOTAAbilityImage") {
			addImage(panel, "ability", round);
			return;
		}
		if (panel.id === "ItemImage" && panel.paneltype === "DOTAItemImage") {
			addImage(panel, "item", round);
			return;
		}
		var children = panel.Children();
		for (var i = 0; i < children.length; ++i) visit(children[i], round);
	}

	function discover() {
		bindings = bindings.filter(function (b) {
			return b.image.IsValid() && b.overlay.IsValid();
		});
		var lowerHud = host.FindChildTraverse("lower_hud");
		if (!lowerHud) return;
		var groups = ["abilities", "inventory_list", "inventory_list2",
			"inventory_backpack_list", "inventory_tpscroll_container", "inventory_neutral_slot_container"];
		for (var i = 0; i < groups.length; ++i) {
			var group = lowerHud.FindChildTraverse(groups[i]);
			if (group) visit(group, false);
		}
		nextDiscovery = Date.now() + 250;
	}

	function applyTheme(binding, theme) {
		var height = binding.image.actuallayoutheight;
		var size = Math.min(theme.size, Math.max(10, height * 0.44));
		var key = theme.key + ":" + size;
		if (binding.theme === key) return;
		binding.theme = key;
		binding.overlay.style.backgroundColor = theme.base;
		binding.wedge.style.backgroundColor = theme.radial;
		binding.label.style.color = theme.text;
		binding.label.style.fontSize = size + "px";
		binding.label.style.textShadow = "1px 1px 2px 2 " + theme.shadow;
	}

	function paint(selection, rows, theme) {
		if (disposed || !host.IsValid()) return;
		lastPaint = Date.now();
		selectionChanged(false);
		if (selection !== token) { hide(); return; }
		if (!rows.length) { hide(); return; }
		if (lastPaint >= nextDiscovery) discover();
		var byEntity = {};
		for (var i = 0; i < rows.length; ++i) byEntity[rows[i].index] = rows[i];
		for (var j = 0; j < bindings.length; ++j) {
			var b = bindings[j];
			if (!b.image.IsValid() || !b.overlay.IsValid()) continue;
			var row = byEntity[b.image.contextEntityIndex];
			if (!row || row.kind !== b.kind || b.image.actuallayoutwidth <= 1
				|| b.image.actuallayoutheight <= 1) {
				b.overlay.visible = false;
				continue;
			}
			applyTheme(b, theme);
			if (b.text !== row.text) { b.text = row.text; b.label.text = row.text; }
			if (b.angle !== row.angle) {
				b.angle = row.angle;
				b.wedge.style.clip = "radial(50% 50%, 0deg, " + (-row.angle) + "deg)";
			}
			b.overlay.visible = true;
		}
	}

	function dispose() {
		if (disposed) return;
		disposed = true;
		if (timer !== null) $.CancelScheduled(timer);
		for (var i = 0; i < subscriptions.length; ++i) GameEvents.Unsubscribe(subscriptions[i]);
		for (var j = 0; j < bindings.length; ++j) {
			if (bindings[j].overlay.IsValid()) {
				bindings[j].overlay.visible = false;
				bindings[j].overlay.DeleteAsync(0);
			}
		}
		bindings = [];
		if (host.IsValid()) {
			host.SetAttributeString(attribute, "");
			delete host.__selectedEnemyCooldowns;
		}
	}

	function watch() {
		if (disposed) return;
		if (!host.IsValid()) { dispose(); return; }
		selectionChanged(false);
		if (Date.now() - lastPaint > 500) hide();
		if (Date.now() - lastPaint > 5000) { dispose(); return; }
		timer = $.Schedule(0.05, watch);
	}

	host.__selectedEnemyCooldowns = {paint: paint, hide: hide, dispose: dispose};
	var events = ["dota_player_update_selected_unit", "dota_player_update_query_unit",
		"dota_player_update_killcam_unit", "dota_portrait_ability_layout_changed",
		"dota_inventory_changed", "dota_inventory_changed_query_unit"];
	for (var i = 0; i < events.length; ++i) {
		subscriptions.push(GameEvents.Subscribe(events[i], function () { selectionChanged(true); }));
	}
	selectionChanged(true);
	watch();
})();
]=]

local helpers = {}

function helpers.clearTarget()
	state.selection = ""
	state.target = nil
	state.handles = {}
	state.nextHandles = 0
end

function helpers.disconnect()
	if state.panel and state.panel:IsValid() then
		Engine.RunScript("(function(){var c=$.GetContextPanel().__selectedEnemyCooldowns;if(c)c.dispose();})();", state.panel)
	end
	state.panel = nil
	state.nextPaint = 0
	state.hadRows = false
	helpers.clearTarget()
end

function helpers.reset()
	helpers.disconnect()
	state.observations = {}
	state.lastGameTime = nil
	state.nextUpdate = 0
	state.nextConnect = 0
	state.nextObservation = 0
end

do
	local menu = Menu.Create("Info Screen", "Main", "Heroes Overlay"):Create("Main")
	local group = menu:Create("Selected Enemy Cooldowns")
	ui.enabled = group:Switch("Enable", true)
	ui.abilities = group:Switch("Abilities", true)
	ui.items = group:Switch("Items", true)
	ui.charges = group:Switch("Charge Restore", true)
	ui.fog = group:Switch("Fog Countdown", true)
	ui.fog:ToolTip("Continue the last observed cooldown in fog. ~ marks an estimate; unseen casts and resets are unknown.")
	ui.charges:ToolTip("Show the next recharge when no charges remain. The radial uses the longest observed remaining recharge in this cycle.")
	ui.customization = group:Label("Customize")
	local gear = ui.customization:Gear("Settings")
	ui.fontSize = gear:Slider("Font Size", 12, 28, 19, "%dpx")
	ui.radial = gear:ColorPicker("Radial Overlay", Color(7, 13, 24, 188))
	ui.base = gear:ColorPicker("Base Tint", Color(44, 74, 118, 52))
	ui.text = gear:ColorPicker("Text", Color(255, 255, 255, 255))
	ui.shadow = gear:ColorPicker("Shadow", Color(0, 0, 0, 240))
	ui.enabled:SetCallback(function(widget)
		local disabled = not widget:Get()
		ui.abilities:Disabled(disabled)
		ui.items:Disabled(disabled)
		ui.charges:Disabled(disabled)
		ui.fog:Disabled(disabled)
		ui.customization:Disabled(disabled)
		if disabled then helpers.reset() end
	end, true)
end

function helpers.connect(now)
	if state.panel and state.panel:IsValid()
		and state.panel:GetAttribute(cfg.selectionAttribute, "") ~= "" then
		return true
	end
	if now < state.nextConnect then return false end
	state.nextConnect = now + cfg.retryInterval
	helpers.disconnect()
	local panel = Panorama.GetPanelByPath(cfg.hudPath)
	if not panel or not panel:IsValid() then return false end
	if not Engine.RunScript(panoramaSource, panel) then return false end
	state.panel = panel
	return panel:GetAttribute(cfg.selectionAttribute, "") ~= ""
end

function helpers.getHandles(unit)
	local handles = {}
	local function add(ability, kind)
		if ability and Entity.IsAbility(ability) and not Ability.IsAttributes(ability)
			and (kind == "item" or not Ability.IsHidden(ability)) then
			handles[#handles + 1] = {ability = ability, index = Entity.GetIndex(ability), kind = kind}
		end
	end
	if ui.abilities:Get() then
		for i = 0, cfg.lastAbilityIndex do add(NPC.GetAbilityByIndex(unit, i), "ability") end
	end
	if ui.items:Get() then
		for _, slot in ipairs(cfg.itemSlots) do
			local item = NPC.GetItemByIndex(unit, slot)
			if item and not Item.IsRecipe(item) then add(item, "item") end
		end
	end
	return handles
end

function helpers.refreshHandles(unit, now)
	state.handles = helpers.getHandles(unit)
	state.nextHandles = now + cfg.handleInterval
end

function helpers.observe(handle, unit, now)
	local ability = handle.ability
	local previous = state.observations[handle.index]
	local remaining = Ability.GetCooldown(ability)
	local length = Ability.GetCooldownLength(ability)
	local mode = "cooldown"
	if Ability.IsInIndefinateCooldown(ability) then
		mode = "indefinite"
		remaining, length = 0, 1
	elseif remaining <= 0 and ui.charges:Get() and Ability.GetCurrentCharges(ability) <= 0 then
		remaining = Ability.ChargeRestoreTimeRemaining(ability)
		mode = "charge"
		length = remaining
		if previous and previous.mode == mode and previous.ability == ability
			and remaining <= previous.remaining + 0.01 then
			length = math.max(previous.length, remaining)
		end
	end
	if mode ~= "indefinite" and remaining <= 0 then
		state.observations[handle.index] = nil
		return nil
	end
	local record = previous or {}
	record.ability = ability
	record.unit = unit
	record.mode = mode
	record.length = math.max(length, remaining, 0.01)
	record.remaining = remaining
	record.endsAt = now + remaining
	state.observations[handle.index] = record
	return record
end

function helpers.makeRow(handle, record, now, estimated)
	if record.mode == "charge" and not ui.charges:Get() then return nil end
	if estimated and record.mode == "indefinite" then return nil end
	local remaining = math.max(0, record.endsAt - now)
	if remaining <= 0 and record.mode ~= "indefinite" then return nil end
	local text = "inf"
	local angle = 360
	if record.mode ~= "indefinite" then
		text = remaining >= 10 and tostring(math.ceil(remaining))
			or string.format("%.1f", math.max(0.1, remaining))
		angle = math.max(1, math.min(360, math.ceil(360 * remaining / record.length)))
	end
	if estimated then text = "~" .. text end
	return {index = handle.index, kind = handle.kind, text = text, angle = angle}
end

function helpers.observeVisibleEnemies(clockTime, gameTime, localHero)
	if not ui.fog:Get() or not localHero or clockTime < state.nextObservation then return end
	state.nextObservation = clockTime + cfg.observationInterval
	for _, unit in ipairs(Heroes.GetAll()) do
		if unit ~= state.target and not Entity.IsSameTeam(unit, localHero) and Entity.IsAlive(unit)
			and NPC.IsVisible(unit) and not Entity.IsDormant(unit) then
			for _, handle in ipairs(helpers.getHandles(unit)) do
				if Ability.GetOwner(handle.ability) == unit then helpers.observe(handle, unit, gameTime) end
			end
		end
	end
end

function helpers.collect(unit, now)
	local rows = {}
	local visible = NPC.IsVisible(unit) and not Entity.IsDormant(unit)
	for _, handle in ipairs(state.handles) do
		local enabled = handle.kind == "ability" and ui.abilities:Get() or handle.kind == "item" and ui.items:Get()
		if enabled and Entity.IsAbility(handle.ability) and Ability.GetOwner(handle.ability) == unit then
			local record
			if visible then
				record = helpers.observe(handle, unit, now)
			elseif ui.fog:Get() then
				record = state.observations[handle.index]
			end
			if record and record.ability == handle.ability and record.unit == unit then
				local row = helpers.makeRow(handle, record, now, not visible)
				if row then rows[#rows + 1] = row end
			end
		end
	end
	return rows
end

function helpers.prune(now)
	for index, record in pairs(state.observations) do
		if not Entity.IsAbility(record.ability) or not Entity.IsNPC(record.unit)
			or (record.mode ~= "indefinite" and record.endsAt <= now)
			or (record.mode == "indefinite" and record.unit ~= state.target) then
			state.observations[index] = nil
		end
	end
end

function helpers.theme()
	local function cssColor(widget)
		local color = widget:Get()
		return string.format("#%02x%02x%02x%02x", math.floor(color.r + 0.5), math.floor(color.g + 0.5),
			math.floor(color.b + 0.5), math.floor(color.a + 0.5))
	end
	local theme = {size = ui.fontSize:Get(), radial = cssColor(ui.radial), base = cssColor(ui.base),
		text = cssColor(ui.text), shadow = cssColor(ui.shadow)}
	theme.key = table.concat({theme.size, theme.radial, theme.base, theme.text, theme.shadow}, ":")
	return theme
end

function cooldown.OnUpdate()
	if not ui.enabled:Get() or not Menu.VisualsIsEnabled() or not (ui.abilities:Get() or ui.items:Get()) then
		if state.panel then helpers.disconnect() end
		return
	end
	local clockTime = chronos.nanotime()
	if clockTime < state.nextUpdate then return end
	state.nextUpdate = clockTime + cfg.updateInterval
	local gameTime = GameRules.GetGameTime()
	if state.lastGameTime and gameTime < state.lastGameTime then helpers.reset() end
	state.lastGameTime = gameTime
	local localHero = Heroes.GetLocal()
	helpers.observeVisibleEnemies(clockTime, gameTime, localHero)
	if not helpers.connect(clockTime) then return end

	local selection = state.panel:GetAttribute(cfg.selectionAttribute, "")
	local index = tonumber(selection:match("^(%-?%d+):"))
	local unit = index and index > 0 and Entity.Get(index) or nil
	if not localHero or not unit or not Entity.IsNPC(unit) or Entity.IsSameTeam(unit, localHero)
		or not Entity.IsAlive(unit) then
		helpers.clearTarget()
		unit = nil
	elseif state.selection ~= selection or state.target ~= unit then
		helpers.clearTarget()
		state.selection = selection
		state.target = unit
	end

	if unit and clockTime >= state.nextHandles then helpers.refreshHandles(unit, clockTime) end
	helpers.prune(gameTime)
	local rows = unit and helpers.collect(unit, gameTime) or {}
	if #rows == 0 and not state.hadRows and clockTime < state.nextPaint then return end
	state.hadRows = #rows > 0
	state.nextPaint = clockTime + (#rows > 0 and cfg.updateInterval or cfg.idleHeartbeatInterval)
	local encodedRows = #rows > 0 and JSON:encode(rows) or "[]"
	local source = "(function(){var c=$.GetContextPanel().__selectedEnemyCooldowns;if(c)c.paint("
		.. JSON:encode(selection) .. "," .. encodedRows .. "," .. JSON:encode(helpers.theme()) .. ");})();"
	if not Engine.RunScript(source, state.panel) then helpers.disconnect() end
end

function cooldown.OnEntityDestroy(entity)
	if entity == state.target then
		if state.panel and state.panel:IsValid() then
			Engine.RunScript("(function(){var c=$.GetContextPanel().__selectedEnemyCooldowns;if(c)c.hide();})();", state.panel)
		end
		helpers.clearTarget()
	end
	for index, record in pairs(state.observations) do
		if record.ability == entity or record.unit == entity then state.observations[index] = nil end
	end
	for _, handle in ipairs(state.handles) do
		if handle.ability == entity then
			state.nextHandles = 0
			break
		end
	end
end

function cooldown.OnGameEnd()
	helpers.reset()
end

return cooldown
