-- Invoker Combo Switcher v1.0.0
-- Author: sataroz (Discord: sataroz)

local VERSION = "1.0.0"

---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

local invoker_combo_switcher = {}

local group = Menu.Create("Heroes", "Hero List", "Invoker", "Panels Settings", "Combo Switch Binds")

local ui = {
    enabled = group:Switch("Enable Combo Scroller", true, "\u{f074}"),
    next_key = group:Bind("Next Combo Key", Enum.ButtonCode.KEY_RIGHT, "\u{f061}"),
    prev_key = group:Bind("Prev Combo Key", Enum.ButtonCode.KEY_LEFT, "\u{f060}"),
    wrap_list = group:Switch("Wrap Around (Loop)", true, "\u{f01e}"),
    hold_delay = group:Slider("Hold Start Delay (ms)", 100, 600, 250, "%d ms"),
    repeat_rate = group:Slider("Hold Scroll Speed (ms)", 50, 400, 160, "%d ms"),
}

if ui.next_key.ShowInBindIsland then
    ui.next_key:ShowInBindIsland(false)
end
if ui.prev_key.ShowInBindIsland then
    ui.prev_key:ShowInBindIsland(false)
end

local slot_names = {
    "Slot #D",
    "Slot #1",
    "Slot #2",
    "Slot #3",
    "Slot #4",
    "Slot #5",
    "Slot #6",
    "Slot #7",
    "Slot #8",
    "Slot #9",
    "Slot #10",
    "Slot #11"
}

local slot_bind_widgets = {}
local combo_slots_widget = nil

local current_slot_idx = 1
local last_applied_next = nil
local last_applied_prev = nil

local next_down = false
local prev_down = false
local next_press_time = 0
local prev_press_time = 0
local next_last_repeat = 0
local prev_last_repeat = 0

local function NormalizeKey(key)
    if not key or key <= 0 then return 0 end
    if key == 319 then return Enum.ButtonCode.KEY_MWHEELUP end
    if key == 320 then return Enum.ButtonCode.KEY_MWHEELDOWN end
    if key == 317 then return Enum.ButtonCode.KEY_MOUSE1 end
    if key == 318 then return Enum.ButtonCode.KEY_MOUSE2 end
    return key
end

local function IsWheel(key)
    local k = NormalizeKey(key)
    return k == Enum.ButtonCode.KEY_MWHEELUP or k == Enum.ButtonCode.KEY_MWHEELDOWN
end

local function GetSlotBind(idx)
    if not slot_bind_widgets[idx] then
        local name = slot_names[idx]
        if name then
            slot_bind_widgets[idx] = Menu.Find("Heroes", "Hero List", "Invoker", "Binds", "Switch Slot", name)
        end
    end
    return slot_bind_widgets[idx]
end

local function GetMaxSlots()
    if not combo_slots_widget then
        combo_slots_widget = Menu.Find("Heroes", "Hero List", "Invoker", "Panels Settings", "Combo Builder", "Combo Slots")
    end
    if combo_slots_widget and combo_slots_widget.Get then
        local val = combo_slots_widget:Get()
        if val == 1 then
            return 12
        end
    end
    return 6
end

local function CalculateAdjacentSlots()
    local total = GetMaxSlots()
    local wrap = ui.wrap_list:Get()

    if current_slot_idx > total then
        current_slot_idx = 1
    end

    local n_idx = nil
    if current_slot_idx < total then
        n_idx = current_slot_idx + 1
    elseif wrap then
        n_idx = 1
    end

    local p_idx = nil
    if current_slot_idx > 1 then
        p_idx = current_slot_idx - 1
    elseif wrap then
        p_idx = total
    end

    if n_idx == p_idx then
        p_idx = nil
    end

    return n_idx, p_idx
end

local function ApplyBindsNow()
    if not ui.enabled:Get() then return end

    local n_key, _ = ui.next_key:Buttons()
    local p_key, _ = ui.prev_key:Buttons()

    local n_idx, p_idx = CalculateAdjacentSlots()

    for i = 1, #slot_names do
        local w = GetSlotBind(i)
        if w then
            if w.ShowInBindIsland then
                w:ShowInBindIsland(false)
            end
            if i ~= n_idx and i ~= p_idx then
                if w.Set then
                    local b1, _ = w:Buttons()
                    if b1 and b1 ~= 0 then
                        w:Set(0, -1)
                    end
                end
                if w.SetToggled then
                    w:SetToggled(false)
                end
            end
        end
    end

    if n_idx and n_key and n_key > 0 then
        local w = GetSlotBind(n_idx)
        if w and w.Set then
            w:Set(n_key, -1)
            if w.ShowInBindIsland then
                w:ShowInBindIsland(false)
            end
            if w.SetToggled then
                w:SetToggled(false)
            end
            last_applied_next = n_idx
        end
    else
        last_applied_next = nil
    end

    if p_idx and p_key and p_key > 0 then
        local w = GetSlotBind(p_idx)
        if w and w.Set then
            w:Set(p_key, -1)
            if w.ShowInBindIsland then
                w:ShowInBindIsland(false)
            end
            if w.SetToggled then
                w:SetToggled(false)
            end
            last_applied_prev = p_idx
        end
    else
        last_applied_prev = nil
    end
end

local function ClearAllSlotBinds()
    for i = 1, #slot_names do
        local w = GetSlotBind(i)
        if w then
            if w.Set then
                w:Set(0, -1)
            end
            if w.SetToggled then
                w:SetToggled(false)
            end
            if w.ShowInBindIsland then
                w:ShowInBindIsland(false)
            end
        end
    end
    last_applied_next = nil
    last_applied_prev = nil
end

local function SyncSlotFromConfig()
    local real_acs = Config.ReadInt("db", "invoker.acs", -999)
    local total = GetMaxSlots()
    if real_acs >= 0 and real_acs < total then
        local actual_idx = real_acs + 1
        if actual_idx ~= current_slot_idx then
            current_slot_idx = actual_idx
            ApplyBindsNow()
            return true
        end
    end
    return false
end

function invoker_combo_switcher.OnUpdate()
    if not ui.enabled:Get() then return end

    SyncSlotFromConfig()

    local cur_time = GlobalVars.GetCurTime()
    local hold_start = (ui.hold_delay:Get() or 250) / 1000.0
    local rep_interval = (ui.repeat_rate:Get() or 160) / 1000.0

    local n_key, _ = ui.next_key:Buttons()
    local p_key, _ = ui.prev_key:Buttons()

    if not IsWheel(n_key) and n_key and n_key > 0 then
        local real_key = NormalizeKey(n_key)
        if Input.IsKeyDown(real_key) then
            if not next_down then
                next_down = true
                next_press_time = cur_time
                next_last_repeat = cur_time
            elseif cur_time - next_press_time >= hold_start then
                if cur_time - next_last_repeat >= rep_interval then
                    next_last_repeat = cur_time
                    local n_idx, _ = CalculateAdjacentSlots()
                    if n_idx then
                        current_slot_idx = n_idx
                        Config.WriteInt("db", "invoker.acs", n_idx - 1)
                        ApplyBindsNow()
                    end
                end
            end
        else
            next_down = false
        end
    else
        next_down = false
    end

    if not IsWheel(p_key) and p_key and p_key > 0 then
        local real_key = NormalizeKey(p_key)
        if Input.IsKeyDown(real_key) then
            if not prev_down then
                prev_down = true
                prev_press_time = cur_time
                prev_last_repeat = cur_time
            elseif cur_time - prev_press_time >= hold_start then
                if cur_time - prev_last_repeat >= rep_interval then
                    prev_last_repeat = cur_time
                    local _, p_idx = CalculateAdjacentSlots()
                    if p_idx then
                        current_slot_idx = p_idx
                        Config.WriteInt("db", "invoker.acs", p_idx - 1)
                        ApplyBindsNow()
                    end
                end
            end
        else
            prev_down = false
        end
    else
        prev_down = false
    end
end

ui.enabled:SetCallback(function()
    if ui.enabled:Get() then
        SyncSlotFromConfig()
        ApplyBindsNow()
    else
        ClearAllSlotBinds()
    end
end)

ui.next_key:SetCallback(function()
    ApplyBindsNow()
end)

ui.prev_key:SetCallback(function()
    ApplyBindsNow()
end)

ui.wrap_list:SetCallback(function()
    ApplyBindsNow()
end)

local initial_acs = Config.ReadInt("db", "invoker.acs", -999)
if initial_acs >= 0 and initial_acs < GetMaxSlots() then
    current_slot_idx = initial_acs + 1
end
ApplyBindsNow()

if ai_bridge and ai_bridge.tool then
    ai_bridge.tool(
        "invoker_get_switcher_status",
        "Gets current combo switcher status",
        {},
        function()
            local n_idx, p_idx = CalculateAdjacentSlots()
            local n_key, _ = ui.next_key:Buttons()
            local p_key, _ = ui.prev_key:Buttons()
            return {
                enabled = ui.enabled:Get(),
                current_slot = slot_names[current_slot_idx] or "unknown",
                current_slot_idx = current_slot_idx,
                max_slots = GetMaxSlots(),
                next_key = n_key,
                prev_key = p_key,
                next_target = n_idx and slot_names[n_idx] or "none",
                prev_target = p_idx and slot_names[p_idx] or "none",
                wrap = ui.wrap_list:Get(),
                is_wheel_next = IsWheel(n_key),
                is_wheel_prev = IsWheel(p_key),
                acs = Config.ReadInt("db", "invoker.acs", -999)
            }
        end
    )

    ai_bridge.tool(
        "invoker_debug_info",
        "Inspects all invoker slot binds and states",
        {},
        function()
            local slots = {}
            for i = 1, #slot_names do
                local w = GetSlotBind(i)
                if w then
                    local b1, b2 = w:Buttons()
                    local in_island = false
                    if w.ShowInBindIsland then
                        in_island = w:ShowInBindIsland()
                    end
                    table.insert(slots, {
                        idx = i,
                        name = slot_names[i],
                        buttons = {b1, b2},
                        is_down = w:IsDown(),
                        is_pressed = w:IsPressed(),
                        is_toggled = w:IsToggled(),
                        in_island = in_island
                    })
                end
            end
            return {
                acs = Config.ReadInt("db", "invoker.acs", -999),
                current_slot_idx = current_slot_idx,
                slots = slots
            }
        end
    )
end

return invoker_combo_switcher
