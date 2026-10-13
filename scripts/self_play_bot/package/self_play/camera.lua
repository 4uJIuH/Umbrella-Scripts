local camera = {}
local state = {held = false}

function camera.update(enabled)
	local hero = enabled and Engine.IsInGame() and Heroes.GetLocal()
	local hold = hero ~= nil and hero ~= false and Entity.IsEntity(hero) and Entity.IsAlive(hero)
	if state.held == hold then return end
	state.held = hold
	Engine.ExecuteCommand(hold and "+dota_camera_center_on_hero" or "-dota_camera_center_on_hero")
end

function camera.release()
	if not state.held then return end
	state.held = false
	Engine.ExecuteCommand("-dota_camera_center_on_hero")
end

return camera
