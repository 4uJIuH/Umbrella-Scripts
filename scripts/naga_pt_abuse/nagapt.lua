-- Naga PT Abuse v1.0.0
-- Author: zвeзdы уnaлu v лужу (Discord: rarimember)

local VERSION = "1.0.0"

local script = {}

local ENABLED = true
local DELAY_TICKS = 2

local my_hero = nil
local treads = nil
local state = 0
local timer = 0

local function get_treads()
    if not my_hero then return nil end
    return NPC.GetItem(my_hero, "item_power_treads")
end

local function switch_treads(times)
    if not treads then return end
    for i = 1, times do
        if not Ability.IsCastable(treads, NPC.GetMana(my_hero)) then return end
        Ability.CastNoTarget(treads)
    end
end

script.OnPrepareUnitOrders = function(order)
    if not ENABLED then return end
    if not order or not order.ability then return end
    if not my_hero then my_hero = Heroes.GetLocal() end
    if not my_hero then return end

    local ability_name = Ability.GetName(order.ability)
    if ability_name ~= "naga_siren_mirror_image" and ability_name ~= "item_manta" then
        return
    end

    treads = get_treads()
    if not treads then return end

    state = 1
    timer = 0
    switch_treads(2)
end

script.OnUpdate = function()
    if not ENABLED then return end
    if not my_hero then my_hero = Heroes.GetLocal(); return end
    if state == 0 then return end

    timer = timer + 1

    if state == 1 and timer >= DELAY_TICKS then
        treads = get_treads()
        switch_treads(1)
        state = 0
        timer = 0
    end
end

return script