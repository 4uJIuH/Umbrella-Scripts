--[[
     ~ qMCP (dota2)
     ~ MCP Lua bridge

     ~ author: qfun (qfun_g9s), nie (internetfanat), oO (internetenemy)
]]
local JSON = require("assets.JSON")
local chronos = require("chronos")

ai_bridge = {}

local a = function(...)
	return ...
end

local cfg = {
	game = "dota2",

	ip = "127.0.0.1",
	port = 4000,

	poll_interval = 1,
	poll_timeout = 20,

	max_per_frame = 4,
	request_timeout = 5,

	register_timeout = 10,
	register_retry = 2,
}

local state
do
	state = {
		last_poll = 0,
		polling = false,

		registering = false,
		register_started = 0,
		next_register = 0,
		dirty = false,
		revision = 0,

		queue = {},
		tools = {},
		order = {},
	}
end

local clock = a(function()
	return chronos.nanotime()
end)

local dump = a(function(value)
	if type(value) ~= "table" then
		return tostring(value)
	end

	return JSON:encode(value)
end)

local helpers
do
	helpers = {
		url = a(function(point, query)
			local address = "http://" .. cfg.ip .. ":" .. cfg.port .. "/" .. point

			return query and (address .. "?" .. query) or address
		end),

		send = a(function(method, address, payload, on_done)
			HTTP.Request(method, address, {
				headers = {
					["Content-Type"] = "application/json",
					["Accept"] = "application/json",
				},
				data = payload and JSON:encode(payload) or "",
				timeout = cfg.request_timeout,
			}, function(response)
				if not on_done then
					return
				end

				if not response or tonumber(response.code) ~= 200 then
					return on_done(nil)
				end

				on_done(JSON:decode(response.response))
			end)
		end),

		log = a(function(level, message, data)
			print("[mcp] level: " .. tostring(level) .. " msg: " .. tostring(message) .. " data: " .. dump(data))

			helpers.send("POST", helpers.url("add-log"), {
				timestamp = os.time(),
				level = level,
				message = message,
				data = data,
			})
		end),

		poll_commands = a(function(on_done)
			helpers.send("GET", helpers.url("poll", "game=" .. cfg.game), nil, on_done)
		end),

		send_manifest = a(function(manifest, on_done)
			helpers.send("POST", helpers.url("register"), manifest, on_done)
		end),

		send_result = a(function(id, ok, result, err, delivered)
			helpers.send("POST", helpers.url("result"), {
				id = id,
				ok = ok,
				result = result,
				error = err,
			}, delivered)
		end),
	}
end

ai_bridge.tool = a(function(name, description, params, handler, opts)
	if not state.tools[name] then
		state.order[#state.order + 1] = name
	end

	state.tools[name] = {
		name = name,
		description = description,
		params = params,
		handler = handler,
		timeout = opts and opts.timeout,
		delivered = opts and opts.delivered,
	}

	state.revision = state.revision + 1
	state.dirty = true
end)

ai_bridge.remove = a(function(name)
	if not state.tools[name] then
		return
	end

	state.tools[name] = nil

	for index, registered in ipairs(state.order) do
		if registered == name then
			table.remove(state.order, index)
			break
		end
	end

	state.revision = state.revision + 1
	state.dirty = true
end)

local core
do
	core = {
		manifest = a(function()
			local tools = {}

			for _, name in ipairs(state.order) do
				local entry = state.tools[name]

				if entry then
					tools[#tools + 1] = {
						name = entry.name,
						description = entry.description,
						params = entry.params,
						timeout = entry.timeout,
					}
				end
			end

			return { game = cfg.game, tools = tools }
		end),

		execute = a(function(command)
			local entry = state.tools[command.method]
			local handler = entry and entry.handler

			if not handler then
				return helpers.send_result(command.id, false, nil, "unknown method: " .. tostring(command.method))
			end

			local result = handler(command.args or {})

			helpers.send_result(command.id, true, result, nil, entry.delivered)
		end),

		sync = a(function()
			local now = clock()

			if state.registering then
				if now - state.register_started <= cfg.register_timeout then
					return
				end

				state.registering = false
			end

			if not state.dirty or now < state.next_register then
				return
			end

			state.registering = true
			state.register_started = now
			state.next_register = now + cfg.register_retry

			local revision = state.revision

			helpers.send_manifest(core.manifest(), function(body)
				state.registering = false

				if not body or not body.ok then
					return
				end

				if revision == state.revision then
					state.dirty = false
				end

				if body.rejected and #body.rejected > 0 then
					helpers.log("error", "server rejected tools", body.rejected)
				end
			end)
		end),

		poll = a(function()
			local now = clock()

			if state.polling then
				if now - state.last_poll > cfg.poll_timeout then
					state.polling = false
				end

				return
			end

			if now - state.last_poll < cfg.poll_interval then
				return
			end

			state.last_poll = now
			state.polling = true

			helpers.poll_commands(function(body)
				state.polling = false

				if body then
					if body.registered == false then
						state.dirty = true
					end

					for _, command in ipairs(body.commands or {}) do
						state.queue[#state.queue + 1] = command
					end
				end

				core.sync()
			end)
		end),

		process = a(function()
			for _ = 1, cfg.max_per_frame do
				local command = table.remove(state.queue, 1)
				if not command then
					return
				end

				core.execute(command)
			end
		end),

		run = a(function()
			core.sync()
			core.poll()
			core.process()
		end),
	}
end

local utilities
do
	utilities = {
		resolve = a(function(indexes)
			local units = {}

			for _, index in ipairs(indexes or {}) do
				local entity = Entity.Get(index)

				if not entity then
					return
				end

				units[#units + 1] = { index = index, entity = entity }
			end

			return units
		end),

		position = a(function(entity)
			local origin = Entity.GetAbsOrigin(entity)

			return { x = origin.x, y = origin.y, z = origin.z }
		end),
	}
end

ai_bridge.tool(
	"get_entity_list",
	"Returns game indexes of the entities on the map. Without a filter returns all of them.",
	{
		{ "class_name", "string?", "filter by entity class, e.g. C_DOTA_BaseNPC_Hero" },
	},
	a(function(args)
		local result = {}

		for _, entity in pairs(Entities.GetAll()) do
			if not args.class_name or Entity.GetClassName(entity) == args.class_name then
				result[#result + 1] = Entity.GetIndex(entity)
			end
		end

		return result
	end)
)

ai_bridge.tool(
	"get_entities_name",
	"Returns unit and class names of the specified entities.",
	{
		{ "indexes", "number[]", "array of entity indexes" },
	},
	a(function(args)
		local units = utilities.resolve(args.indexes)

		if not units then
			return
		end

		local result = {}

		for _, unit in ipairs(units) do
			result[#result + 1] = {
				index = unit.index,
				name = Entity.GetUnitName(unit.entity),
				class_name = Entity.GetClassName(unit.entity),
			}
		end

		return result
	end)
)

ai_bridge.tool(
	"get_entities_position",
	"Returns positions of the specified entities.",
	{
		{ "indexes", "number[]", "array of entity indexes" },
	},
	a(function(args)
		local units = utilities.resolve(args.indexes)

		if not units then
			return
		end

		local result = {}

		for _, unit in ipairs(units) do
			result[#result + 1] = {
				index = unit.index,
				position = utilities.position(unit.entity),
			}
		end

		return result
	end)
)

ai_bridge.tool(
	"get_heroes",
	"Returns every hero in the game: index, name, team, health, mana, position, whether it is the local one.",
	{},
	a(function()
		local local_hero = Heroes.GetLocal()
		local result = {}

		for _, hero in pairs(Heroes.GetAll()) do
			result[#result + 1] = {
				index = Entity.GetIndex(hero),
				name = Entity.GetUnitName(hero),
				team = Entity.GetTeamNum(hero),
				level = NPC.GetCurrentLevel(hero),
				alive = Entity.IsAlive(hero),
				dormant = Entity.IsDormant(hero),
				health = Entity.GetHealth(hero),
				max_health = Entity.GetMaxHealth(hero),
				mana = NPC.GetMana(hero),
				max_mana = NPC.GetMaxMana(hero),
				position = utilities.position(hero),
				is_local = hero == local_hero,
			}
		end

		return result
	end)
)

ai_bridge.tool(
	"ping",
	"Checks that lua answers: returns current time, frame count and whether a match is running.",
	{},
	a(function()
		return {
			alive = true,
			time = os.time(),
			frame = GlobalVars.GetFrameCount(),
			in_game = Engine.IsInGame(),
		}
	end)
)

ai_bridge.tool(
	"reload_scripts",
	"Reloads every lua script once this answer reaches the server.",
	{},
	a(function()
		return { reloading = true }
	end),
	{ delivered = a(function()
		print("--- SCRIPTS RELOADED ---")
		Engine.ReloadScriptSystem()
	end) }
)

ai_bridge.mcp_log = helpers.log

ai_bridge.OnScriptsLoaded = a(function()
	core.sync()
	print("[mcp] started, tools: " .. #state.order)
end)

ai_bridge.OnFrame = a(function()
	core.run()
end)

return ai_bridge
