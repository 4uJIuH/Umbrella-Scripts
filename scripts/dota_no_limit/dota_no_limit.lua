local E,M,C,R,V,G,P,cn,eb,gb,pa=Engine,Menu,Color,Render,Vec2,GameLocalizer,pcall,CustomNetTables,Engine.GetHeroIDByName,GameRules.GetBannedHeroes,Panorama

local t=M.Create("Scripts","Item Eater","Eater")
local p=t:Create("Main")
local s=p:Create("Eater Settings",1)

local enabled=s:Switch("Включить Eater",false)
local auto_eat=s:Switch("Авто-поедание",false)

local inventory_selector=s:MultiSelect("Инвентарь (Клик для поедания)",{},true)
inventory_selector:OneItemSelection(true)
inventory_selector:Visible(false)

local empty_label=s:Label("Инвентарь пуст")
empty_label:Visible(true)

local stats_group=p:Create("Статистика",2)
local total_stats_label=stats_group:Label("Всего съедено: 0")
local last_eaten_label=stats_group:Label("Последний предмет: Нет")

local IGNORED_ITEMS={
    ["item_armlet"]=true,
    ["item_ward_observer"]=true,
    ["item_ward_sentry"]=true,
    ["item_ward_dispenser"]=true,
    ["item_hand_of_midas"]=true,
    ["item_hand_of_midas_custom"]=true,
    ["item_infused_raindrop"]=true,
    ["item_aeon_disk"]=true,
    ["item_tpscroll"]=true,
    ["item_smoke_of_deceit"]=true,
    ["item_clarity"]=true,
    ["item_enchanted_mango"]=true,
    ["item_flask"]=true,
    ["item_dust"]=true,
    ["item_famango"]=true,
    ["item_great_famango"]=true,
    ["item_greater_famango"]=true,
    ["item_tango"]=true,
    ["item_blood_grenade"]=true,
    ["item_sphere"]=true,
    ["item_greater_crit_lua"]=true,
    ["item_lesser_crit_lua"]=true,
    ["item_echo_sabre"]=true,
    ["item_gem"]=true,
    ["item_basher_lua"]=true,
    ["item_basher_bloodthorn_monkey_king_bar"]=true,
    ["item_moon_shard_lua"]=true,
    ["item_greater_recipe"]=true,
    ["item_radiance_lua"]=true,
    ["item_madstone_bundle"]=true,
    ["item_aegis"]=true,
    ["item_shopkeeper_aegis"]=true,
    ["item_shopkeeper_cyclone"]=true,
    ["item_shopkeeper_cheese"]=true,
    ["item_shopkeeper_octarine_core"]=true,
    ["item_shopkeeper_sheepstick"]=true,
    ["item_shopkeeper_force_staff"]=true,
    ["item_shopkeeper_krekker"]=true,
    ["item_cheese"]=true,
    ["item_rapier"]=true,
    ["item_faerie_fire"]=true,
    ["item_royale_with_cheese"]=true,
    ["item_bottle"]=true,
    ["item_tango_single"]=true,
    ["item_refresher_shard"]=true,
    ["item_ultimate_scepter"]=true,
    ["item_blink"]=true,
    ["item_arcane_blink"]=true,
    ["item_swift_blink"]=true,
    ["item_overwhelming_blink"]=true,
    ["item_magic_stick"]=true,
    ["item_cyclone"]=true
}

local last_eat_time=0
local eat_delay=0.1
local last_ui_update_time=0
local ui_update_delay=0.2

local eat_queue={}
local total_eaten_count=0
local eaten_counts_map={}
local currently_scanned_items={}
local last_inventory_state={}

local function _A1(cm,items,force_custom)
    local bg_cols,img_cols={},{}
    for _,item in ipairs(items) do
        local is_cust=force_custom or item[1]:find("%(")
        table.insert(bg_cols,is_cust and"#c800ff"or"#505050")
        table.insert(img_cols,is_cust and"#f0bfff"or"#ffffff")
    end
    P(cm.UpdateBackgroundColors,cm,bg_cols)
    P(cm.UpdateImageColors,cm,img_cols)
end

local function getIndex(ent)
    if type(ent)=="number" then return ent end
    if Entity and Entity.GetIndex then return Entity.GetIndex(ent) end
    return ent
end

local function getMapName()
    if GameRules and GameRules.GetMapName then
        local status,result=pcall(GameRules.GetMapName)
        if status then return result end
    end
    if Engine and Engine.GetMapName then
        local status,result=pcall(Engine.GetMapName)
        if status then return result end
    end
    return "custom"
end

local function isInCustomGame()
    if not E.IsInGame() then return false end
    local map=getMapName()
    if map=="background"or map=="" then
        return false
    end
    return true
end

local function onItemEaten(itemName)
    total_eaten_count=total_eaten_count+1
    eaten_counts_map[itemName]=(eaten_counts_map[itemName]or 0)+1
    local localizedName=(G and G.FindAbility and G.FindAbility(itemName))or itemName
    total_stats_label:Name("Всего съедено: "..total_eaten_count)
    last_eaten_label:Name("Последний предмет: "..localizedName.." (x"..eaten_counts_map[itemName]..")")
end

local function scanInventory(hero)
    local items={}
    for slot=0,8 do
        local item=NPC.GetItemByIndex(hero,slot)
        if item then
            local name=Ability.GetName(item)
            if name and name~=""and not IGNORED_ITEMS[name] then
                table.insert(items,{item=item,name=name})
            end
        end
    end
    return items
end

local function eatItem(hero,item,name)
    local localPlayer=Players.GetLocal()
    if not localPlayer then return end
    local itemIndex=getIndex(item)
    E.RunScript(string.format('GameEvents.SendCustomGameEventToServer("event_send_item_to_backpack", {PlayerID: Players.GetLocalPlayer(), item_index: %d, backpack_slot: 1})',itemIndex),"Hud")
    Player.PrepareUnitOrders(localPlayer,Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM,6,Vector(0,0,0),item,Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,hero)
    onItemEaten(name)
end

local function queueContainsItem(item)
    for _,queued in ipairs(eat_queue) do
        if queued.item==item then
            return true
        end
    end
    return false
end

local function hasInventoryChanged(eatable)
    if #eatable~=#last_inventory_state then return true end
    for i,itemData in ipairs(eatable) do
        if last_inventory_state[i]~=itemData.item then
            return true
        end
    end
    return false
end

local function updateInventoryUi(my_hero,now,force)
    local eatable=scanInventory(my_hero)
    if not force and not hasInventoryChanged(eatable) then
        return
    end
    last_inventory_state={}
    for i,itemData in ipairs(eatable) do
        table.insert(last_inventory_state,itemData.item)
    end
    if #eatable==0 then
        inventory_selector:Visible(false)
        empty_label:Name("Инвентарь пуст")
        empty_label:Visible(true)
        return
    end
    inventory_selector:Visible(true)
    empty_label:Visible(false)
    local menu_items={}
    currently_scanned_items={}
    for _,itemData in ipairs(eatable) do
        local cleanName=itemData.name:gsub("^item_",""):gsub("_lua$",""):gsub("_custom$","")
        local imgPath="panorama/images/items/"..cleanName.."_png.vtex_c"
        local localizedName=(G and G.FindAbility and G.FindAbility(itemData.name))or itemData.name
        currently_scanned_items[localizedName]=itemData
        table.insert(menu_items,{localizedName,imgPath,false})
    end
    inventory_selector:Update(menu_items,true)
    _A1(inventory_selector,menu_items,false)
end

inventory_selector:SetCallback(function(self)
    local enabled_items=self:ListEnabled()
    if enabled_items and enabled_items[1] then
        local target=currently_scanned_items[enabled_items[1]]
        if target then
            local my_hero=Heroes.GetLocal()
            if my_hero then
                eatItem(my_hero,target.item,target.name)
                updateInventoryUi(my_hero,GameRules.GetGameTime(),true)
            end
        end
    end
end)

s:Button("Съесть все",function()
    if not E.IsInGame() or not isInCustomGame() then return end
    local my_hero=Heroes.GetLocal()
    if not my_hero or not Entity.IsAlive(my_hero) then return end
    local eatable=scanInventory(my_hero)
    for _,itemData in ipairs(eatable) do
        if not queueContainsItem(itemData.item) then
            table.insert(eat_queue,itemData)
        end
    end
end)

local script={}

script.OnUpdate=function()
    if not E.IsInGame() then
        eat_queue={}
        currently_scanned_items={}
        last_inventory_state={}
        inventory_selector:Visible(false)
        empty_label:Visible(true)
        return
    end
    if not enabled:Get() then return end
    local my_hero=Heroes.GetLocal()
    if not my_hero or not Entity.IsAlive(my_hero) then return end
    local now=GameRules.GetGameTime()
    updateInventoryUi(my_hero,now,false)
    if not isInCustomGame() then
        eat_queue={}
        return
    end
    if #eat_queue>0 then
        if now-last_eat_time>=eat_delay then
            local target=table.remove(eat_queue,1)
            if target then
                eatItem(my_hero,target.item,target.name)
                last_eat_time=now
            end
        end
        return
    end
    if auto_eat:Get() then
        if now-last_eat_time>=eat_delay then
            local eatable=scanInventory(my_hero)
            if #eatable>0 then
                table.insert(eat_queue,eatable[1])
            end
        end
    end
end

return script
