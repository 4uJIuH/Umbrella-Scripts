local talents = {}

local function diagnose(ctx, ability, code)
	if ctx.now < (ctx.nextTalentLog or 0) then return false end
	ctx.nextTalentLog = ctx.now + 15
	Log.Write(string.format("[SelfPlay talents] cannot learn %s: %s", Ability.GetName(ability), code))
	return false
end

local function press(button)
	return Engine.RunScript("$.DispatchEvent('Activated', $.GetContextPanel(), 'mouse');", button)
end

local function ready(button, row)
	if button:HasClass("Disabled") then return false, "talent button Disabled" end
	if button:HasClass("BranchChosen") then return false, "talent already BranchChosen" end
	if not row:HasClass("BranchActive") then return false, "row not BranchActive" end
	return true
end

local function sideButton(row, side)
	if not row or not row.IsValid or not row:IsValid() then return nil end
	local count = row:GetChildCount() or 0
	local options = {}
	for i = 0, count - 1 do
		local child = row:GetChild(i)
		if child and child.IsValid and child:IsValid() and child.HasID and child:HasID() then
			local id = child:GetID() or ""
			if id:find("Upgrade", 1, true) then options[#options + 1] = child end
		end
	end
	return options[side]
end

function talents.learn(ctx, ability)
	ctx.talentTries = ctx.talentTries or {}
	local name = Ability.GetName(ability)
	ctx.talentTries[name] = (ctx.talentTries[name] or 0) + 1
	if ctx.talentTries[name] % 2 == 1 then
		Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY, nil, Vector(0, 0, 0), ability,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_talent", false)
		return true
	end
	if talents.train(ctx, ability) then return true end
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY, nil, Vector(0, 0, 0), ability,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_talent_retry", false)
	return true
end

function talents.train(ctx, ability)
	local branch = Panorama.GetPanelByName("DOTAStatBranch", false)
	if not branch then return diagnose(ctx, ability, "DOTAStatBranch panel not found") end
	local index = 0
	for slot = 0, 31 do
		local entry = NPC.GetAbilityByIndex(ctx.hero, slot)
		local name = entry and Ability.GetName(entry)
		if name and name:find("^special_bonus_") and name ~= "special_bonus_attributes" then
			index = index + 1
			if entry == ability then
				local tier, side = math.ceil(index / 2), index % 2 == 1 and 1 or 2
				local row = branch:FindChildTraverse("UpgradeOption" .. tier)
				if not row then return diagnose(ctx, ability, "UpgradeOption row not found") end
				local button = sideButton(row, side) or branch:FindChildTraverse("Upgrade" .. index)
				if not button then return diagnose(ctx, ability, "no button for side " .. side) end
				local ok, reason = ready(button, row)
				if not ok then return diagnose(ctx, ability, reason) end
				return press(button)
			end
		end
	end
	return diagnose(ctx, ability, "talent not present in ability slots")
end

return talents
