local courier_route = {}

local a = function(...)
	return ...
end

local config = {
	random_radius = 50,
	order_delay = 0.05,

	routes = {
		-- Radiant
        [2] = {
            Vector(-4106.7158203125, -7491.5947265625, 261.9998779296875),
            Vector(-2533.830078125, -7852.58642578125, 134.0),
            Vector(-783.5977783203125, -8040.8525390625, 134.0),
            Vector(1037.75634765625, -8192.7451171875, 134.0),
            Vector(2693.36474609375, -7910.556640625, 0.0),
            Vector(3761.7060546875, -7517.115234375, 0.0),
        },

		-- Dire
        [3] = {
            Vector(3713.1796875, 7235.42822265625, 262.0),
            Vector(2289.57666015625, 7228.05810546875, 134.0),
            Vector(654.783935546875, 7307.4423828125, 134.0),
            Vector(-747.478759765625, 7535.029296875, 134.0001220703125),
            Vector(-2230.795166015625, 7262.72412109375, 0.0),
		},
	},
}

local ui, state

local helpers
do
	helpers = {
		randomize_position = a(function(position, radius)
			local angle = math.random() * math.pi * 2
			local distance = math.sqrt(math.random()) * radius

			return position + Vector(math.cos(angle) * distance, math.sin(angle) * distance, 0)
		end),

		get_route = a(function(courier)
			local team = Entity.GetTeamNum(courier)

			return config.routes[team]
		end),

		prepare_order = a(function(player, courier, position, identifier)
			Player.PrepareUnitOrders(
				player,
				Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
				nil,
				position or Vector(0, 0, 0),
				nil,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
				courier,
				true,
				true,
				false,
				false,
				identifier,
				true
			)
		end),

		prepare_transfer_order = a(function(player, courier, identifier)
			local ability = NPC.GetAbility(courier, "courier_transfer_items")

			if not ability then
				return false
			end

			Player.PrepareUnitOrders(
				player,
				Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET,
				nil,
				Vector(0, 0, 0),
				ability,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
				courier,
				true,
				true,
				false,
				false,
				identifier or "",
				true
			)

			return true
		end),

		stop = a(function()
			state.is_run = false
			state.player = nil
			state.courier = nil
			state.route = nil
			state.route_index = 1
			state.next_order_time = 0
		end),
	}
end

courier_route.run = a(function()
	local player = Players.GetLocal()
	local courier = Couriers.GetLocal()

	if not player or not courier or state.is_run then
		return false
	end

	local route = helpers.get_route(courier)

	if not route or #route == 0 then
		return false
	end

	state.is_run = true
	state.player = player
	state.courier = courier
	state.route = route
	state.route_index = 1
	state.next_order_time = GlobalVars.GetCurTime()

	return true
end)

courier_route.OnUpdate = a(function()
	if not state or not state.is_run then
		return
	end

	local current_time = GlobalVars.GetCurTime()

	if current_time < state.next_order_time then
		return
	end

	if not state.player or not state.courier or not state.route then
		helpers.stop()
		return
	end

	local position = state.route[state.route_index]

	if position then
		helpers.prepare_order(
			state.player,
			state.courier,
			helpers.randomize_position(position, config.random_radius),
			"courier_route_" .. state.route_index
		)

		state.route_index = state.route_index + 1
		state.next_order_time = current_time + config.order_delay

		return
	end

	helpers.prepare_transfer_order(state.player, state.courier, "courier_transfer_items")

	helpers.stop()
end)

do
	local menu = Menu.Find("Miscellaneous", "In Game", "Courier", "Main", "Courier")
	if not menu then
		return
	end

	ui = {
		route_key = menu:Bind("Send Courier By Route", Enum.ButtonCode.BUTTON_CODE_NONE, "\u{e2ce}"),
	}

	state = {
		is_run = false,
		player = nil,
		courier = nil,
		route = nil,
		route_index = 1,
		next_order_time = 0,
	}

	ui.route_key:SetKeyCallback(function(this, key, event)
		if event ~= Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			return
		end

		courier_route.run()
	end)
end

return courier_route
