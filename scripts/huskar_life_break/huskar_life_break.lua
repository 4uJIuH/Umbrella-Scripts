---@diagnostic disable: undefined-global

local script = {}

local localization = qLocalization.new({
    en = {
        menu = {
            main = "Life Break Combo",
            enabled = "Enabled",
            enabled_tip = "Cancels the Life Break leap with Blink or Hurricane Pike. The ultimate flies as an invisible projectile, so the damage, the slow and the Aghanim's taunt still land on the target",
            key = "Combo key",
            key_tip = "Press: Life Break on the hero under the cursor, then the leap is broken by the first ready item. Pressed while already leaping, it breaks the leap at once",
            items = "Leap breakers",
            items_tip = "The first ready item in this order is used. Blink stops the leap, Hurricane Pike pushes both of you apart",
            where = "Blink direction",
            where_tip = "Where Blink lands after the leap is broken. Ally and fountain jump the full Blink range, but never past the ally",
            where_back = "Away from the target",
            where_cursor = "To the cursor",
            where_ally = "To the nearest ally",
            where_fountain = "Towards the fountain",
            back = "Blink distance",
            back_tip = "How far back Blink takes you when the direction is away from the target",
            delay = "Delay after the leap starts",
            delay_tip = "Raise it if the ultimate does not land: the item is used this long after the leap begins",
            auto = "Also on a manual ultimate",
            auto_tip = "Break the leap even when Life Break was cast by hand, without the bind",
            stop = "Stop after the hit",
            stop_tip = "On impact Life Break gives Huskar an attack order on the target, so he walks back. This sends one stop order instead. Your own order cancels it",
        },
        panel = {
            menu_failed = "Huskar Life Break: menu failed",
        },
    },
    ru = {
        menu = {
            main = "Комбо на ульте",
            enabled = "Включить",
            enabled_tip = "Сбивает полёт Life Break блинком или пикой. Ульта летит невидимым снарядом, поэтому урон, замедление и провокация с аганима всё равно проходят по цели",
            key = "Клавиша комбо",
            key_tip = "Нажатие: ульта в героя под курсором, затем полёт сбивается первым готовым предметом. Нажатие уже в полёте сбивает его сразу",
            items = "Чем сбивать полёт",
            items_tip = "Используется первый готовый предмет в этом порядке. Блинк останавливает прыжок, Hurricane Pike раскидывает вас в стороны",
            where = "Куда блинк",
            where_tip = "Куда ставить блинк после срыва полёта. К союзнику и к фонтану — на полную дальность блинка, но не дальше самого союзника",
            where_back = "Назад от цели",
            where_cursor = "К курсору",
            where_ally = "К ближайшему союзнику",
            where_fountain = "В сторону фонтана",
            back = "Дальность блинка",
            back_tip = "На сколько отпрыгнуть назад, если выбрано «Назад от цели»",
            delay = "Задержка после начала полёта",
            delay_tip = "Увеличь, если ульта не проходит: предмет жмётся через столько после начала прыжка",
            auto = "И при ручной ульте",
            auto_tip = "Сбивать полёт, даже если Life Break скастован руками, без бинда",
            stop = "Стоп после попадания",
            stop_tip = "В момент попадания ульта выдаёт Хускару приказ атаковать цель, и он бежит назад. Вместо этого шлётся один стоп. Твой собственный приказ его отменяет",
        },
        panel = {
            menu_failed = "Huskar Life Break: меню не создалось",
        },
    },
    cn = {
        menu = {
            main = "燃烧之魂连招",
            enabled = "启用",
            enabled_tip = "用闪烁匕首或飓风长戟打断生命燃烧的跳跃。大招以隐形弹道飞行，因此伤害、减速和阿哈利姆的嘲讽仍会命中目标",
            key = "连招按键",
            key_tip = "按下：对光标下的英雄释放生命燃烧，然后由第一个可用物品打断跳跃。跳跃中按下则立即打断",
            items = "打断跳跃的物品",
            items_tip = "按此顺序使用第一个可用物品。闪烁停止跳跃，飓风长戟将双方推开",
            where = "闪烁方向",
            where_tip = "打断跳跃后闪烁到哪里。队友和泉水方向按闪烁最大距离跳跃，但不会越过队友",
            where_back = "远离目标",
            where_cursor = "到光标",
            where_ally = "到最近的队友",
            where_fountain = "朝向泉水",
            back = "闪烁距离",
            back_tip = "选择远离目标时向后闪烁多远",
            delay = "跳跃开始后的延迟",
            delay_tip = "如果大招没有命中请调高：跳跃开始这么久后使用物品",
            auto = "手动大招时同样生效",
            auto_tip = "即使生命燃烧是手动释放的也打断跳跃",
            stop = "命中后停止",
            stop_tip = "命中时生命燃烧会让哈斯卡攻击目标，于是他会跑回去。改为发送一次停止命令。你自己的命令会取消它",
        },
        panel = {
            menu_failed = "Huskar Life Break: 菜单创建失败",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local HERO = "npc_dota_hero_huskar"
local ULT = "huskar_life_break"
local LEAP = "modifier_huskar_life_break_charge"
local SLOW = "modifier_huskar_life_break_slow"
local TAUNT = "modifier_huskar_life_break_taunt"
local SCEPTER = "modifier_item_ultimate_scepter"
local ARM_TIME = 2.5
local HIT_WAIT = 3.0
local STOP_GAP = 0.25
local MAX_STOPS = 2
local BREAK_RETRY = 0.1
local MAX_TRIES = 20
local HIT_EDGE = 0.05
local RANGE_SLACK = 50
local BLINK_EDGE = 25
local LEAP_LEASH = 2440
local FOUNTAIN_SCAN = 5
local FOUNTAIN_NAME = "^ent_dota_fountain"

local BREAKERS = {
    { name = "item_blink", blink = true },
    { name = "item_swift_blink", blink = true },
    { name = "item_arcane_blink", blink = true },
    { name = "item_overwhelming_blink", blink = true },
    { name = "item_hurricane_pike" },
}

local function api(tbl, name)
    return type(tbl) == "table" and type(tbl[name]) == "function" and tbl[name] or nil
end

local HAS_ENUM = type(Enum) == "table"
local CAST_READY = HAS_ENUM and type(Enum.AbilityCastResult) == "table" and Enum.AbilityCastResult.READY or -1
local TEAM_ENEMY = HAS_ENUM and type(Enum.TeamType) == "table" and Enum.TeamType.TEAM_ENEMY or 0
local KEY_T = HAS_ENUM and type(Enum.ButtonCode) == "table" and Enum.ButtonCode.KEY_T or 30
local ORDERS = HAS_ENUM and type(Enum.UnitOrder) == "table" and Enum.UnitOrder or {}
local ORDER_STOP = ORDERS.DOTA_UNIT_ORDER_STOP or 21
local ISSUERS = HAS_ENUM and type(Enum.PlayerOrderIssuer) == "table" and Enum.PlayerOrderIssuer or {}
local ISSUER_UNIT = ISSUERS.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY or 3
local CURSOR_HERO = api(Input, "GetNearestHeroToCursor")
local CURSOR_POS = api(Input, "GetWorldCursorPos")

local ui = {}
local ready = false
local g_menu_error = nil
local S = { arm = 0, active = false, fountain = nil, nextFountain = 0, leapAt = nil, castAt = 0, target = nil, breaker = nil, entry = nil, tries = 0, nextTry = 0, breakAt = 0, hitAt = nil, stops = 0, nextStop = 0, userOrder = 0, error = nil, font = nil }

local function log(level, message, data)
    if type(ai_bridge) ~= "table" or type(ai_bridge.mcp_log) ~= "function" then return end
    pcall(ai_bridge.mcp_log, level, message, data)
end

local function millis(v)
    return string.format("%d ms", v)
end

local function units(v)
    return string.format("%d", v)
end

local function breaker_rows()
    local out = {}
    for i, e in ipairs(BREAKERS) do
        out[i] = { e.name, "panorama/images/items/" .. e.name:gsub("^item_", "") .. "_png.vtex_c", true }
    end
    return out
end

local function initialize_menu()
    local side = (HAS_ENUM and Enum.GroupSide) or {}
    local section = Menu.Create("Heroes", "Hero List", "Huskar", "Life Break")
    local group = section:Create("menu.main", side.Left)

    ui.enabled = group:Switch("menu.enabled", true, "\u{f0e7}")
    ui.enabled:ToolTip("menu.enabled_tip")
    ui.key = group:Bind("menu.key", KEY_T, "panorama/images/spellicons/huskar_life_break_png.vtex_c")
    ui.key:ToolTip("menu.key_tip")
    ui.items = group:MultiSelect("menu.items", breaker_rows(), true)
    ui.items:ToolTip("menu.items_tip")
    ui.where = group:Combo("menu.where", { "menu.where_back", "menu.where_cursor", "menu.where_ally", "menu.where_fountain" }, 0)
    ui.where:ToolTip("menu.where_tip")
    ui.back = group:Slider("menu.back", 200, 1200, 600, units)
    ui.back:ToolTip("menu.back_tip")
    ui.delay = group:Slider("menu.delay", 0, 500, 0, millis)
    ui.delay:ToolTip("menu.delay_tip")
    ui.auto = group:Switch("menu.auto", false, "\u{f0e7}")
    ui.auto:ToolTip("menu.auto_tip")
    ui.stop = group:Switch("menu.stop", true, "\u{f04d}")
    ui.stop:ToolTip("menu.stop_tip")
    return true
end

local function reset()
    S.arm = 0
    S.active = false
    S.leapAt = nil
    S.breaker = nil
    S.entry = nil
    S.tries = 0
    S.nextTry = 0
    S.hitAt = nil
    S.stops = 0
end

local function castable(h)
    return h ~= nil and Ability.GetLevel(h) > 0 and Ability.IsReady(h) and Ability.CanBeExecuted(h) == CAST_READY
end

local function flat(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

local function valid_enemy(hero, h)
    return h ~= nil and Entity.IsAlive(h) and not Entity.IsSameTeam(hero, h) and not NPC.IsIllusion(h)
end

local function pick_target(hero)
    local t = CURSOR_HERO and CURSOR_HERO(Entity.GetTeamNum(hero), TEAM_ENEMY) or nil
    if valid_enemy(hero, t) then return t end
    local origin = Entity.GetAbsOrigin(hero)
    local cursor = CURSOR_POS and CURSOR_POS() or origin
    local best, bestDist
    for _, h in ipairs(Heroes.GetAll()) do
        if valid_enemy(hero, h) and not Entity.IsDormant(h) then
            local d = flat(Entity.GetAbsOrigin(h), cursor)
            if bestDist == nil or d < bestDist then best, bestDist = h, d end
        end
    end
    return best
end

local function leap_target(hero)
    local origin = Entity.GetAbsOrigin(hero)
    local best, bestDist
    for _, h in ipairs(Heroes.GetAll()) do
        if valid_enemy(hero, h) then
            local d = flat(Entity.GetAbsOrigin(h), origin)
            if d <= LEAP_LEASH and (bestDist == nil or d < bestDist) then best, bestDist = h, d end
        end
    end
    return best
end

local function pick_breaker(hero, target, dist)
    for _, e in ipairs(BREAKERS) do
        if ui.items:Get(e.name) then
            local h = NPC.GetItem(hero, e.name, true)
            if h ~= nil and castable(h) and Item.IsItemEnabled(h) then
                if e.blink then return e, h end
                if target ~= nil and dist <= Ability.GetCastRange(h) + NPC.GetCastRangeBonus(hero) + RANGE_SLACK then
                    return e, h
                end
            end
        end
    end
    return nil
end

local function toward(o, p, range)
    local d = flat(o, p)
    if d <= 1 then return nil end
    local r = math.min(d, range)
    return Vector(o.x + (p.x - o.x) / d * r, o.y + (p.y - o.y) / d * r, o.z)
end

local function nearest_ally(hero, origin)
    local best, bestDist
    for _, h in ipairs(Heroes.GetAll()) do
        if h ~= hero and Entity.IsSameTeam(hero, h) and Entity.IsAlive(h) and not NPC.IsIllusion(h) and not Entity.IsDormant(h) then
            local d = flat(Entity.GetAbsOrigin(h), origin)
            if bestDist == nil or d < bestDist then best, bestDist = h, d end
        end
    end
    return best
end

local function fountain_pos(hero, now)
    if S.fountain ~= nil then return S.fountain end
    if now < S.nextFountain then return nil end
    S.nextFountain = now + FOUNTAIN_SCAN
    local fort
    for _, n in ipairs(NPCs.GetAll()) do
        if Entity.IsSameTeam(hero, n) then
            if string.find(NPC.GetUnitName(n), FOUNTAIN_NAME) ~= nil then
                S.fountain = Entity.GetAbsOrigin(n)
                log("info", "fountain found", { x = S.fountain.x, y = S.fountain.y })
                return S.fountain
            end
            if fort == nil and NPC.IsFort(n) then fort = n end
        end
    end
    if fort ~= nil then
        S.fountain = Entity.GetAbsOrigin(fort)
        log("info", "fountain not in npc list, using fort", { x = S.fountain.x, y = S.fountain.y })
        return S.fountain
    end
    log("info", "no fountain and no fort found")
    return nil
end

local function blink_pos(hero, target, h, now)
    local o = Entity.GetAbsOrigin(hero)
    local range = math.max(Ability.GetCastRange(h) + NPC.GetCastRangeBonus(hero) - BLINK_EDGE, 100)
    local mode = ui.where:Get()
    local pos
    if mode == 1 then
        local c = CURSOR_POS and CURSOR_POS() or nil
        if c ~= nil then pos = toward(o, c, range) end
    elseif mode == 2 then
        local ally = nearest_ally(hero, o)
        if ally ~= nil then pos = toward(o, Entity.GetAbsOrigin(ally), range) end
    elseif mode == 3 then
        local f = fountain_pos(hero, now)
        if f ~= nil then pos = toward(o, f, range) end
    end
    if pos ~= nil then return pos end
    if target ~= nil then
        local p = Entity.GetAbsOrigin(target)
        local d = flat(o, p)
        if d > 1 then
            local r = math.min(ui.back:Get(), range)
            return Vector(o.x + (o.x - p.x) / d * r, o.y + (o.y - p.y) / d * r, o.z)
        end
    end
    return nil
end

local function cast_breaker(hero, e, h, target, now)
    if e.blink then
        local pos = blink_pos(hero, target, h, now)
        if pos == nil then return false end
        Ability.CastPosition(h, pos, false, false, true)
        return true
    end
    if target == nil then return false end
    Ability.CastTarget(h, target, false, false, true)
    return true
end

local function try_break(hero, now)
    local target = S.target
    local dist = 0
    if target ~= nil and Entity.IsAlive(target) then
        dist = flat(Entity.GetAbsOrigin(target), Entity.GetAbsOrigin(hero))
    else
        target = nil
    end

    local e, h
    if S.breaker == nil then
        e, h = pick_breaker(hero, target, dist)
        if e == nil then return end
    else
        e, h = S.entry, NPC.GetItem(hero, S.breaker, true)
        if h == nil or not Ability.IsReady(h) then
            log("info", "breaker went off", { item = S.breaker, tries = S.tries, t = now - S.breakAt })
            S.tries = MAX_TRIES
            return
        end
    end
    if not cast_breaker(hero, e, h, target, now) then return end

    S.tries = S.tries + 1
    S.nextTry = now + BREAK_RETRY
    S.breakAt = now
    if S.breaker == nil then
        S.breaker, S.entry = e.name, e
        S.hitAt = nil
        S.stops = 0
        S.nextStop = 0
        log("info", "breaking leap with " .. e.name, { dist = dist, target = target and Entity.GetIndex(target) })
    end
end

local function fresh_modifier(t, name, since)
    local m = NPC.GetModifier(t, name)
    return m ~= nil and Modifier.GetCreationTime(m) >= since
end

local function watch_hit(hero, now)
    local t = S.target
    if t == nil or now - S.breakAt > HIT_WAIT then
        S.breaker = nil
        return
    end
    if S.hitAt == nil then
        local since = S.castAt - HIT_EDGE
        local taunt = fresh_modifier(t, TAUNT, since)
        if not (taunt or fresh_modifier(t, SLOW, since) or not Entity.IsAlive(t)) then return end
        S.hitAt = now
        log("info", "life break connected", { t = now - S.breakAt, taunt = taunt, scepter = NPC.HasModifier(hero, SCEPTER) })
    end
    if not ui.stop:Get() or S.userOrder > S.breakAt then
        S.breaker = nil
        return
    end
    if now < S.nextStop then return end
    Player.PrepareUnitOrders(Players.GetLocal(), ORDER_STOP, nil, Entity.GetAbsOrigin(hero), nil, ISSUER_UNIT, hero)
    S.stops = S.stops + 1
    S.nextStop = now + STOP_GAP
    if S.stops >= MAX_STOPS then S.breaker = nil end
end

local function press(hero, now)
    if NPC.HasModifier(hero, LEAP) then
        S.arm = now + ARM_TIME
        S.active = true
        S.tries, S.nextTry = 0, 0
        if S.target == nil or not Entity.IsAlive(S.target) then S.target = leap_target(hero) end
        log("info", "armed in flight", { target = S.target and Entity.GetIndex(S.target) })
        return
    end
    local ult = NPC.GetAbility(hero, ULT)
    if not castable(ult) then
        log("info", "life break not ready", { level = ult and Ability.GetLevel(ult), cd = ult and Ability.GetCooldown(ult) })
        return
    end
    local target = pick_target(hero)
    if target == nil then
        log("info", "no target for life break")
        return
    end
    S.target = target
    S.arm = now + ARM_TIME
    Ability.CastTarget(ult, target)
    log("info", "life break cast", { target = Entity.GetIndex(target), dist = flat(Entity.GetAbsOrigin(target), Entity.GetAbsOrigin(hero)) })
end

local function update()
    local hero = Heroes.GetLocal()
    if hero == nil or NPC.GetUnitName(hero) ~= HERO or not Entity.IsAlive(hero) then
        if S.leapAt ~= nil or S.breaker ~= nil then reset() end
        return
    end

    local now = GameRules.GetGameTime()
    if ui.key:IsPressed() then press(hero, now) end

    if NPC.HasModifier(hero, LEAP) then
        if S.leapAt == nil then
            S.leapAt = now
            S.castAt = now
            S.active = now <= S.arm or ui.auto:Get()
            S.breaker, S.entry, S.tries, S.nextTry = nil, nil, 0, 0
            if S.target == nil or not Entity.IsAlive(S.target) then S.target = leap_target(hero) end
            log("info", "leap started", { active = S.active, target = S.target and Entity.GetIndex(S.target) })
        end
        if S.active and S.tries < MAX_TRIES and now >= S.nextTry and now >= S.leapAt + ui.delay:Get() / 1000 then
            try_break(hero, now)
        end
        return
    end

    if S.leapAt ~= nil then
        S.leapAt = nil
        S.active = false
    end
    if S.breaker ~= nil then watch_hit(hero, now) end
end

local function track_order(data)
    local hero = Heroes.GetLocal()
    if hero == nil or (data.npc ~= nil and data.npc ~= hero) then return end
    S.userOrder = GameRules.GetGameTime()
    if data.ability ~= nil and data.target ~= nil and Ability.GetName(data.ability) == ULT then
        S.target = valid_enemy(hero, data.target) and data.target or nil
    end
end

function script.OnPrepareUnitOrders(data)
    if not ready or not ui.enabled:Get() then return true end
    local ok, err = pcall(track_order, data)
    if not ok then S.error = tostring(err) end
    return true
end

function script.OnScriptsLoaded()
    local ok, res = pcall(initialize_menu)
    ready = ok and res == true
    if not ready then g_menu_error = ok and "initialize_menu returned false" or tostring(res) end
    S.font = Render.LoadFont("Arial", 0, 500)
    log("info", "huskar_life_break loaded", { menu_ready = ready, error = g_menu_error, cursor_hero = CURSOR_HERO ~= nil, cursor_pos = CURSOR_POS ~= nil })
end

function script.OnUpdate()
    if not ready or not ui.enabled:Get() or not Engine.IsInGame() then return end
    local ok, err = pcall(update)
    if not ok then
        reset()
        if S.error == nil then log("error", "update failed", { error = tostring(err) }) end
        S.error = tostring(err)
    end
end

function script.OnGameEnd()
    reset()
    S.fountain = nil
    S.nextFountain = 0
    S.target = nil
    S.userOrder = 0
    S.error = nil
end

local function draw_error_banner()
    local title = g_menu_error and localization.Get("panel.menu_failed") or "Huskar Life Break"
    local msg = g_menu_error or S.error
    Render.FilledRect(Vec2(20, 400), Vec2(760, 446), Color(20, 20, 24, 235), 4)
    Render.Text(S.font, 14, title, Vec2(30, 406), Color(224, 50, 45, 245))
    Render.Text(S.font, 12, msg:sub(1, 150), Vec2(30, 426), Color(220, 220, 225, 240))
end

function script.OnDraw()
    if g_menu_error ~= nil or S.error ~= nil then pcall(draw_error_banner) end
end

return script
