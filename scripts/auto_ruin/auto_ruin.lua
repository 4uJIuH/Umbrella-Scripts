--start of script (xd)
--script made by flatixxx
--idea by man from chat (thx)
---@diagnostic disable-next-line: param-type-mismatch;disable-next-line: missing-parameter;disable-next-line: missing-parameter;disable-next-line: cast-local-type
local GameRuiner = {}

--cfg system (mb)
local config_path = "game_ruiner_config.ini"

local function SavePos(x, y)
    local file = io.open(config_path, "w")
    if file then
        file:write(string.format("x=%d\ny=%d", x, y))
        file:close()
    end
end

local function LoadPos()
    local x, y = 200, 100
    local file = io.open(config_path, "r")
    if file then
        for line in file:lines() do
            local k, v = line:match("([^=]+)=(%d+)")
            if k == "x" then x = tonumber(v) end
            if k == "y" then y = tonumber(v) end
        end
        file:close()
    end
    return x, y
end

-- [[ 2. STATE ]]
local State = {
    LastMoveTime = 0,
    LastSpamTime = 0,
    LastObsTime = 0,
    LastSmokeTime = 0,
    EnemyFountainPos = nil,

    PosX = 200,
    PosY = 100,
    IsDragging = false,
    DragOffset = {x=0, y=0},

    NextBuyTime = 0,
    SpamStateInfo = "IDLE"
}

State.PosX, State.PosY = LoadPos()

--create script in menu
local root_path = {"Miscellaneous", "Other", "Авто-Руин"}

local g_main = Menu.Create(root_path[1], root_path[2], root_path[3], "Main", "Главная")
if g_main and g_main:Parent() and g_main:Parent():Parent() then
    g_main:Parent():Parent():Icon("\u{f071}")
end
local UI = {}

UI.EnableFeed = g_main:Switch("Включить Авто-Руин", false)
UI.EnableFeed:Icon("\u{f021}")

local feed_gear = UI.EnableFeed:Gear("Настройки", "\u{f013}")

UI.MoveToFountain = feed_gear:Switch("Идти на вражеский фонтан", true, "panorama/images/items/boots_png.vtex_c")

UI.BuySmoke = feed_gear:Switch("Скупать Смоки", false, "panorama/images/items/smoke_of_deceit_png.vtex_c")
UI.BuyObserver = feed_gear:Switch("Скупать Обсы", false, "panorama/images/items/ward_observer_png.vtex_c")
UI.SpamDust = feed_gear:Switch("Спам Дастов", false, "panorama/images/items/dust_png.vtex_c")

local g_settings = Menu.Create(root_path[1], root_path[2], root_path[3], "Main", "Settings", "Доп. Настройки")

UI.FeedDelay = g_settings:Slider("Задержка ордеров на движение", 100, 1000, 100, "%d")
UI.FeedDelay:Icon("\u{f252}")

UI.SpamSpeed = g_settings:Slider("Скорость спама (мс)", 50, 1000, 50, "%d")
UI.SpamSpeed:Icon("\u{f0e7}")

UI.KeepGold = g_settings:Slider("Оставлять золота", 0, 5000, 0, "%d")
UI.KeepGold:Icon("\u{f51e}")

UI.LockPos = g_settings:Switch("Заблокировать панель", false)
UI.LockPos:Icon("\u{f023}")

UI.ResetPos = g_settings:Button("Сбросить позицию панели", function()
    State.PosX = 200
    State.PosY = 100
    SavePos(200, 100)
end)
UI.ResetPos:Icon("\u{f0e2}")

local FOUNTAIN_RADIANT = Vector(-7149, -6696, 520)
local FOUNTAIN_DIRE    = Vector(7034, 6458, 512)

local ID_OBSERVER = 42
local ID_DUST     = 40
local ID_SMOKE    = 188


local function GetMyGold()
    local player = Players.GetLocal()
    if not player then return 0 end

    if Player.GetTotalGold then
        return Player.GetTotalGold(player)
    end

    if Player.GetTeamPlayer then
        local data = Player.GetTeamPlayer(player)
        if data then
            return (data.reliable_gold or 0) + (data.unreliable_gold or 0)
        end
    end

    return 0
end

local function GetEnemyFountainPos(myHero)
    if State.EnemyFountainPos then return State.EnemyFountainPos end
    local myTeam = Entity.GetTeamNum(myHero)
    if myTeam == 2 then State.EnemyFountainPos = FOUNTAIN_DIRE
    else State.EnemyFountainPos = FOUNTAIN_RADIANT end
    return State.EnemyFountainPos
end

local function BuyItem(id)
    Player.PrepareUnitOrders(
        Players.GetLocal(),
        Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM,
        nil,
        Vector(0,0,0),
        id,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY
    )
end

local function SellItemEntity(item)
    if not item then return end
    Player.PrepareUnitOrders(
        Players.GetLocal(),
        Enum.UnitOrder.DOTA_UNIT_ORDER_SELL_ITEM,
        nil,
        Vector(0,0,0),
        item,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY
    )
end

local function IsNearShop(myHero)
    if NPC.HasModifier(myHero, "modifier_shopkeeper_presence") then return true end

    local pos = Entity.GetAbsOrigin(myHero)
    if pos then
        if pos:Distance(Vector(-7232, -6728, 520)) < 1200 then return true end -- Radiant
        if pos:Distance(Vector(7168, 6592, 520)) < 1200 then return true end   -- Dire
    end

    return false
end

--logic

local function ProcessObsLogic(myHero)
    BuyItem(ID_OBSERVER)
end

local function ProcessSmokeLogic(myHero)
    BuyItem(ID_SMOKE)
end

local function ProcessDustSpamLogic(myHero)
    local now = os.clock()
    if now < State.NextBuyTime then return end

    local nearShop = IsNearShop(myHero) or Engine.IsShopOpen()

    --check stash
    local dustInStash = nil
    for i = 9, 14 do
        local item = NPC.GetItemByIndex(myHero, i)
        if item then
            local name = Ability.GetName(item)
            if name == "item_dust" or name == "item_dust_of_appearance" then
                dustInStash = item
                break
            end
        end
    end

    if dustInStash then
        SellItemEntity(dustInStash)
        State.SpamStateInfo = "SELLING (STASH)"
        State.NextBuyTime = now + 0.15
        return
    end

    --check inv
    local dustInInv = nil
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(myHero, i)
        if item then
            local name = Ability.GetName(item)
            if name == "item_dust" or name == "item_dust_of_appearance" then
                dustInInv = item
                break
            end
        end
    end

    if dustInInv and nearShop then
        SellItemEntity(dustInInv)
        State.SpamStateInfo = "SELLING (INV)"
        State.NextBuyTime = now + 0.15
        return
    end

    local gold = GetMyGold()
    local keep = UI.KeepGold:Get()
    local cost = 80

    if gold >= (keep + cost) then
        BuyItem(ID_DUST)
        State.SpamStateInfo = "BUYING"
        State.NextBuyTime = now + 0.25
    else
        State.SpamStateInfo = "NO GOLD"
    end
end

function GameRuiner.OnUpdate()
    local myHero = Heroes.GetLocal()
    if not myHero or not Entity.IsAlive(myHero) then
        State.EnemyFountainPos = nil
        return
    end

    if not UI.EnableFeed:Get() then return end

    local now = os.clock() * 1000

    local isMoving = UI.MoveToFountain:Get()

    UI.SpamDust:Visible(not isMoving)
    UI.BuySmoke:Visible(true)
    UI.BuyObserver:Visible(true)

    if isMoving then
        if now - State.LastMoveTime > UI.FeedDelay:Get() then
            local targetPos = GetEnemyFountainPos(myHero)
            Player.PrepareUnitOrders(
                Players.GetLocal(),
                Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil,
                targetPos,
                nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY
            )
            State.LastMoveTime = now
        end
    end

    --obs logic
    if UI.BuyObserver:Get() then
        if now - State.LastObsTime > 250 then
            ProcessObsLogic(myHero)
            State.LastObsTime = now
        end
    end

    --smoke logic (like obs logic)
    if UI.BuySmoke:Get() then
        if now - State.LastSmokeTime > 250 then
            ProcessSmokeLogic(myHero)
            State.LastSmokeTime = now
        end
    end

    --dust logic
    if UI.SpamDust:Get() and not isMoving then
        if now - State.LastSpamTime > UI.SpamSpeed:Get() then
            ProcessDustSpamLogic(myHero)
            State.LastSpamTime = now
        end
    end
end

--render panel
local Font = nil

function GameRuiner.OnDraw()
    if not UI.EnableFeed:Get() then return end

    if not Font then
        Font = Render.LoadFont("Tahoma", 16, Enum.FontWeight.BOLD, Enum.FontCreate.FONTFLAG_OUTLINE)
    end

    local cx, cy = Input.GetCursorPos()
    local x, y = State.PosX, State.PosY
    local w, h = 220, 120

    if not UI.LockPos:Get() then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            if not State.IsDragging and cx >= x and cx <= x + w and cy >= y and cy <= y + h then
                State.IsDragging = true
                State.DragOffset = {x = cx - x, y = cy - y}
            end
            if State.IsDragging then
                State.PosX = cx - State.DragOffset.x
                State.PosY = cy - State.DragOffset.y
            end
        else
            if State.IsDragging then SavePos(State.PosX, State.PosY) end
            State.IsDragging = false
        end
    end

    local currentY = State.PosY

    Render.Text(Font, 16, "GAME RUINER: ON", Vec2(State.PosX, currentY), Color(255, 50, 50, 255))
    currentY = currentY + 22

    local isMoving = UI.MoveToFountain:Get()

    if isMoving then
        Render.Text(Font, 14, "-> Moving to Fountain", Vec2(State.PosX, currentY), Color(255, 255, 255, 255))
        currentY = currentY + 18
    end

    if UI.BuyObserver:Get() then
        Render.Text(Font, 14, "-> Buying Observers", Vec2(State.PosX, currentY), Color(255, 255, 100, 255))
        currentY = currentY + 18
    end

    if UI.BuySmoke:Get() then
        Render.Text(Font, 14, "-> Buying Smokes", Vec2(State.PosX, currentY), Color(150, 150, 255, 255))
        currentY = currentY + 18
    end

    if UI.SpamDust:Get() and not isMoving then
        local color = Color(100, 255, 100, 255)
        if State.SpamStateInfo == "SELLING (INV)" or State.SpamStateInfo == "SELLING (STASH)" then
            color = Color(255, 100, 100, 255)
        elseif State.SpamStateInfo == "WAITING SHOP" then
            color = Color(255, 165, 0, 255)
        elseif State.SpamStateInfo == "NO GOLD" then
            color = Color(150, 150, 150, 255)
        end

        Render.Text(Font, 14, "-> Dust Spam: " .. State.SpamStateInfo, Vec2(State.PosX, currentY), color)
    end
end

return GameRuiner
-- end of script (xd)
