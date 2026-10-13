local excuses = {}

local templates = {
	"превет ребяьта я тока научелся играт в дтоут 2 у меня сломаны наушники и я играю фулл мут не судите строго пж",
	"у меня не работают наушникии,я фулл мут недавно начал играть",
	"даров ребят я еще в доту не научился играть и я кароч фулл мут епт",
	"Своё сообщение (из поля ниже)",
}

local sent = false

function excuses.create(group)
	local section = group:Create("Excuses", Enum.GroupSide.Left)
	local ui = {
		enabled = section:Switch("Send excuse at game start", false),
		template = section:Combo("Excuse template", templates, 0),
		custom = section:Input("Custom excuse", "gl hf, full mute"),
		allChat = section:Switch("All chat excuse", false),
	}
	ui.template:SetCallback(function()
		ui.custom:Disabled(ui.template:Get() ~= #templates - 1)
	end, true)
	return ui
end

function excuses.update(ui)
	if sent or not ui.enabled:Get() then return end
	if not Engine.IsInGame() then return end
	sent = true
	local index = ui.template:Get() or 0
	local text = index == #templates - 1 and ui.custom:Get() or templates[index + 1]
	if text and text ~= "" then
		Engine.ExecuteCommand((ui.allChat:Get() and "say " or "say_team ") .. text)
	end
end

function excuses.reset()
	sent = false
end

return excuses
