local IceWallOnCursor = {
	wall_distance = 200,
	wall_length = 1200,
	hold_time = 0.22,
	order_interval = 0.08,
	cast_angle = 0.08,
	cast_distance = 200,
}

function IceWallOnCursor:Init()
	self.menu = Menu.Create("Heroes", "Hero List", "Invoker", "Main Settings", "Cast On Cursor")

	self.bind = self.menu:Bind("Ice Wall", Enum.ButtonCode.BUTTON_CODE_INVALID, "panorama/images/spellicons/invoker_ice_wall_png.vtex_c")
	self.bind:ToolTip("Tap to cast Ice Wall through cursor. Hold to preview, release to cast.")
	self.bind:ShowInBindIsland(true)

	self.preview_color = self.bind:ColorPicker("Preview Color", Color(100, 210, 255, 210))
	self.center_color = self.menu:ColorPicker("Cursor Hit Color", Color(255, 255, 255, 230))

	self.hero = nil
	self.ability = nil
	self.ready = false
	self.press_time = 0
	self.was_down = false
	self.active = false
	self.target_pos = nil
	self.next_order_time = 0
end

function IceWallOnCursor:GetAbility(hero)
	return NPC.GetAbility(hero, "invoker_ice_wall")
end

function IceWallOnCursor:UpdateHero()
	local hero = Heroes.GetLocal()
	if hero and Entity.IsAlive(hero) and NPC.GetUnitName(hero) == "npc_dota_hero_invoker" then
		if self.hero ~= hero or not self.ability then
			self.ability = self:GetAbility(hero)
		end

		self.hero = hero
		return true
	end

	self.hero = nil
	self.ability = nil
	self.ready = false
	self.active = false
	self.was_down = false
	return false
end

function IceWallOnCursor:GetCurrentForward(hero)
	local forward = Entity.GetRotation(hero):GetForward()
	forward.z = 0
	return forward:Normalized()
end

function IceWallOnCursor:GetForwardToHit(hero, cursor)
	local origin = Entity.GetAbsOrigin(hero)
	local delta = cursor - origin
	delta.z = 0

	local distance = delta:Length2D()
	if distance < self.wall_distance then
		return nil
	end

	local half_length = self.wall_length * 0.5
	local lateral = math.sqrt(math.max(distance * distance - self.wall_distance * self.wall_distance, 0))
	if lateral > half_length then
		return nil
	end

	local direction = delta:Normalized()
	local angle = math.acos(self.wall_distance / distance)
	local left = direction:Rotated(angle)
	local right = direction:Rotated(-angle)
	local current = self:GetCurrentForward(hero)

	if current:Dot2D(left) > current:Dot2D(right) then
		return left
	end

	return right
end

function IceWallOnCursor:GetStandPosition(hero, cursor, forward)
	local origin = Entity.GetAbsOrigin(hero)
	local delta = cursor - origin
	delta.z = 0

	if delta:Length2D() < self.wall_distance then
		return cursor - forward:Scaled(self.wall_distance)
	end

	return cursor - delta:Normalized():Scaled(self.wall_distance)
end

function IceWallOnCursor:GetPlan(hero, cursor)
	local origin = Entity.GetAbsOrigin(hero)
	local forward = self:GetForwardToHit(hero, cursor)

	if forward then
		return {
			origin = origin,
			forward = forward,
			move = nil,
		}
	end

	local current = self:GetCurrentForward(hero)
	local stand = self:GetStandPosition(hero, cursor, current)
	local stand_delta = cursor - stand
	stand_delta.z = 0
	local stand_forward = stand_delta:Length2D() > 1 and stand_delta:Normalized() or current

	return {
		origin = stand,
		forward = stand_forward,
		move = stand,
	}
end

function IceWallOnCursor:GetWallPoints(plan)
	local center = plan.origin + plan.forward:Scaled(self.wall_distance)
	local side = plan.forward:Rotated(math.pi * 0.5):Normalized()
	local half_length = self.wall_length * 0.5

	return center - side:Scaled(half_length), center + side:Scaled(half_length), center
end

function IceWallOnCursor:IssueMove(hero, pos)
	local now = GlobalVars.GetCurTime()
	if now < self.next_order_time then
		return
	end

	NPC.MoveTo(hero, pos, false, false, false, true, "", false)
	self.next_order_time = now + self.order_interval
end

function IceWallOnCursor:IssueFace(hero, forward)
	local now = GlobalVars.GetCurTime()
	if now < self.next_order_time then
		return
	end

	local player = Players.GetLocal()
	local origin = Entity.GetAbsOrigin(hero)
	local face_pos = origin + forward:Scaled(180)

	Player.PrepareUnitOrders(
		player,
		Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION,
		nil,
		face_pos,
		nil,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
		hero,
		false,
		false,
		false,
		true,
		"",
		false
	)

	self.next_order_time = now + self.order_interval
end

function IceWallOnCursor:IsFacing(hero, forward)
	local current = self:GetCurrentForward(hero)
	return current:Dot2D(forward) >= math.cos(self.cast_angle)
end

function IceWallOnCursor:StartCast()
	self.target_pos = Input.GetWorldCursorPos()
	self.active = true
	self.next_order_time = 0
end

function IceWallOnCursor:ThinkCast(hero)
	local ability = self.ability
	if not ability or not Ability.IsCastable(ability, NPC.GetMana(hero)) then
		self.active = false
		return
	end

	local plan = self:GetPlan(hero, self.target_pos)
	local origin = Entity.GetAbsOrigin(hero)

	if plan.move and origin:Distance2D(plan.move) > self.cast_distance then
		self:IssueMove(hero, plan.move)
		return
	end

	if not self:IsFacing(hero, plan.forward) then
		self:IssueFace(hero, plan.forward)
		return
	end

	Ability.CastNoTarget(ability, false, false, true)
	self.active = false
end

function IceWallOnCursor:OnUpdate()
	if not self:UpdateHero() or Input.IsInputCaptured() then
		self.ready = false
		self.active = false
		self.was_down = false
		return
	end

	self.ready = true
	local hero = self.hero
	local down = self.bind:IsDown()
	if down and not self.was_down then
		self.press_time = GlobalVars.GetCurTime()
	end

	if self.was_down and not down then
		self:StartCast()
	end

	self.was_down = down

	if self.active then
		self:ThinkCast(hero)
	end
end

function IceWallOnCursor:OnDraw()
	if not self.ready then
		return
	end

	local should_preview = self.bind:IsDown() and GlobalVars.GetCurTime() - self.press_time >= self.hold_time
	if not should_preview and not self.active then
		return
	end

	local cursor = should_preview and Input.GetWorldCursorPos() or self.target_pos
	if not cursor then
		return
	end

	local plan = self:GetPlan(self.hero, cursor)
	local start_pos, end_pos, center = self:GetWallPoints(plan)
	local start_screen, start_visible = start_pos:ToScreen()
	local end_screen, end_visible = end_pos:ToScreen()
	local center_screen, center_visible = center:ToScreen()
	local cursor_screen, cursor_visible = cursor:ToScreen()

	if start_visible and end_visible then
		Render.Line(start_screen, end_screen, self.preview_color:Get(), 4)
		Render.Line(start_screen, end_screen, Color(255, 255, 255, 90), 1)
	end

	if center_visible then
		Render.FilledCircle(center_screen, 5, self.preview_color:Get(), 0, 1, 18)
	end

	if cursor_visible then
		Render.Circle(cursor_screen, 8, self.center_color:Get(), 2, 0, 1, true, 24)
	end

	if plan.move then
		local move_screen, move_visible = plan.move:ToScreen()
		if move_visible and center_visible then
			Render.Line(move_screen, center_screen, Color(255, 255, 255, 120), 1)
			Render.Circle(move_screen, 7, Color(255, 255, 255, 170), 2, 0, 1, true, 20)
		end
	end
end

return (XHelpers.WrapCallbacks or XHelpers.BaseScript)(IceWallOnCursor)
