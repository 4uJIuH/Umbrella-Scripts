---@diagnostic disable: undefined-global, param-type-mismatch

local CombineLockClick = {
	slots = { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
}

local function find_child_panel(parent_id, child_id)
	local parent = Panorama.GetPanelByName(parent_id, false)
	if not parent then
		return nil
	end

	return parent:FindChildTraverse(child_id) or parent:FindChild(child_id)
end

local function get_panel_rect(panel)
	if not panel or panel:IsVisible() == false then
		return nil
	end

	local bounds = panel:GetBounds(true)
	if type(bounds) == "table" then
		local x = tonumber(bounds.x) or 0
		local y = tonumber(bounds.y) or 0
		local w = tonumber(bounds.w) or 0
		local h = tonumber(bounds.h) or 0

		if w > 1 and h > 1 then
			return { x = x, y = y, w = w, h = h }
		end
	end

	local pos = panel:GetPositionWithinWindow()
	local w = tonumber(panel:GetLayoutWidth() or 0) or 0
	local h = tonumber(panel:GetLayoutHeight() or 0) or 0

	if pos and w > 1 and h > 1 then
		return { x = tonumber(pos.x) or 0, y = tonumber(pos.y) or 0, w = w, h = h }
	end

	return nil
end

local function get_slot_panel(slot)
	if slot >= 0 and slot <= 2 then
		return find_child_panel("inventory_list", ("inventory_slot_%d"):format(slot))
	end

	if slot >= 3 and slot <= 5 then
		return find_child_panel("inventory_list2", ("inventory_slot_%d"):format(slot))
	end

	if slot >= 6 and slot <= 8 then
		return find_child_panel("inventory_backpack_list", ("inventory_slot_%d"):format(slot))
	end

	return nil
end

local function get_slot_under_cursor(slots)
	for i = 1, #slots do
		local slot = slots[i]
		local rect = get_panel_rect(get_slot_panel(slot))
		if rect and Input.IsCursorInRect(rect.x, rect.y, rect.w, rect.h) then
			return slot
		end
	end

	return nil
end

function CombineLockClick:Init()
	self.menu = Menu.Create("General", "Items", "Combine Lock", "Main", "Main")
	self.enable = self.menu:Switch("Enable", true)
end

function CombineLockClick:OnUpdate()
	if not self.enable or not self.enable:Get() then
		return
	end

	if Input.IsInputCaptured() then
		return
	end

	if not Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then
		return
	end

	local hero = Heroes.GetLocal()
	local player = Players.GetLocal()
	if not hero or not player then
		return
	end

	local slot = get_slot_under_cursor(self.slots)
	if slot == nil then
		return
	end

	local item = NPC.GetItemByIndex(hero, slot)
	if not item or Item.IsCombineLocked(item) ~= true then
		return
	end

	Player.PrepareUnitOrders(
		player,
		Enum.UnitOrder.DOTA_UNIT_ORDER_SET_ITEM_COMBINE_LOCK,
		nil,
		Entity.GetAbsOrigin(hero),
		item,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
		hero,
		false,
		false,
		false,
		true,
		"CombineLockClick",
		false
	)
end

return (XHelpers.WrapCallbacks or XHelpers.BaseScript)(CombineLockClick)
