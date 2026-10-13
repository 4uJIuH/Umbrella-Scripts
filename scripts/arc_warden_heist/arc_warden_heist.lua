--[[
    Arc Warden's Heist — "Кража века"
    UCZone API v2.0 · https://uczone.gitbook.io/api-v2.0

    Наведи курсор, нажми бинд:

      1. Оригинал выкладывает на землю ОДНУ вещь.
      2. Вызывает Tempest Double.
      3. Клон отходит на предельную для себя дистанцию и бьёт по шмотке.
      4. Снаряд летит, и на полпути оригинал выхватывает вещь из-под него.
      5. Та же вещь, следующий круг.

    Главное правило: шмотка не должна сломаться никогда.

    Шмотки на земле действительно ломаются, поэтому весь порядок фаз построен
    вокруг этого. Клона не подпускают к вещи, пока оригинал не встал вплотную
    и не готов забрать её одним движением. За весь круг клону отдаётся РОВНО
    ОДИН приказ атаки, и кража происходит, пока снаряд ещё в воздухе: подбор
    срабатывает мгновенно, а урон — только в момент попадания.

    Отсюда и дистанция обстрела. Вплотную снаряд долетает за считанные
    мгновения, и окна на кражу почти нет, поэтому дистанция не настраивается:
    клон всегда отходит на предел собственной дальности атаки. Оттуда снаряд
    летит около полусекунды, тычку прекрасно видно, а вещь исчезает у него
    из-под носа на полпути.

    По той же причине вещь всё время одна и та же, а заклинаний в постановке
    нет вовсе: каждая смена предмета — это новая шмотка под ударом, а вирд и
    поле — это area-урон ровно по тому, что повреждать нельзя.

    Сверх этого стоят три подстраховки. Если у предмета хоть на единицу убыло
    здоровья, кража идёт немедленно и вне очереди. Если замах не начался за
    отведённое время, хватаем и без него. А на время подбора клону приказывают
    отойти: приказ атаки по цели не разовый, юнит бьёт сам, пока цель жива, и
    оборвать этот цикл можно только новым приказом движения.

    Отдельное правило для приказов, которые запускают анимацию: их нельзя
    повторять каждый кадр. Новый приказ обрывает начатое, поэтому ульта на
    клона отдаётся раз в секунду, а приказ атаки — один раз за круг.

    Ничего вычисляемого через Enum на уровне файла: если чанк падает при
    загрузке, скрипт не регистрируется вообще и не подаёт признаков жизни.
    Всё, что трогает игровой API, живёт внутри функций, а OnUpdate и OnDraw
    обёрнуты в pcall — ошибка уходит в консоль и на экран, а не съедается.
]]

local VERSION = "1.0.0"
local script = {}

----------------------------------------------------------------------
-- TUNING
----------------------------------------------------------------------

-- Ближе этого к точке — считаем, что юнит дошёл.
local ARRIVE_TOLERANCE = 110

-- Сколько ждём застрявшего юнита, прежде чем плюнуть и идти дальше.
local WALK_TIMEOUT = 6.0

-- Пауза после приказа выбросить предмет: анимация плюс полёт шмотки на землю.
local DROP_SETTLE = 0.5

-- Приказы на ходьбу повторяются не чаще этого: каждый кадр их слать незачем.
local ORDER_INTERVAL = 0.2

-- Сколько ждём появления клона после каста ульты.
local SUMMON_TIMEOUT = 6.0

-- Пауза между попытками каста. Ульту нельзя приказывать каждый кадр: новый
-- приказ прерывает анимацию предыдущего, и каст не доходит до конца никогда.
local CAST_RETRY = 1.0

-- Сколько ждём, что предмет действительно пропал с земли после кражи.
local GRAB_TIMEOUT = 2.0

-- Сколько ждём начала замаха. Клону нужно довернуться к вещи и начать
-- анимацию; полсекунды на это не хватало, и кража срабатывала раньше, чем он
-- успевал поднять руку.
local SWING_WAIT = 1.5

-- Если за это время замах так и не начался, приказ атаки отдаётся повторно:
-- значит, первый где-то потерялся. Раньше этого порога не трогаем, иначе
-- новый приказ сам же и оборвёт начатую анимацию.
local SWING_RETRY = 0.8

-- Запас поверх времени замаха. Дальше ждать нельзя ни при каких условиях:
-- приказ атаки по цели НЕ разовый, юнит продолжает бить сам, пока цель жива,
-- так что каждая лишняя десятая секунды здесь — это лишняя тычка по вещи.
local SHOT_MARGIN = 0.35

-- Если сборка не отдаёт время замаха, берём это. Обычный attack point героя
-- укладывается в треть секунды.
local FALLBACK_ANIM_POINT = 0.35

-- Как часто повторяется приказ на подбор, если он не прошёл. Две секунды,
-- которые стояли здесь раньше, — это вечность, когда вещь под обстрелом.
local PICKUP_RETRY = 0.25

-- Насколько внутрь своей дальности встаёт клон. Ровно на кромке он норовит
-- шагнуть вперёд перед выстрелом, и весь выигрыш по времени полёта пропадает.
local RANGE_MARGIN = 40

-- Запас, на который клона отгоняют после выстрела — поверх его дальности,
-- чтобы следующий выстрел был физически невозможен без нового сближения.
local BACK_OFF = 250

-- Допуск на позицию обстрела: клон не обязан встать в точку пиксель в пиксель.
local SHOOT_TOLERANCE = 140

-- Дистанция, с которой оригинал уже дотягивается до предмета. Пока он дальше,
-- клона к шмотке не подпускаем вовсе.
local GRAB_RANGE = 200

-- Радиус поиска предмета вокруг его точки, когда entity index недоступен.
local MATCH_RADIUS = 450

local CLONE_MODIFIER = "modifier_arc_warden_tempest_double"
local ARC_WARDEN_UNIT = "npc_dota_hero_arc_warden"

local ABILITY_DOUBLE = "arc_warden_tempest_double"

local PHASE_TITLE = {
    layout   = "ВЫКЛАДЫВАЕМ",
    summon   = "ЗОВЁМ КЛОНА",
    approach = "ЗАНИМАЕМ МЕСТА",
    beat     = "ЗАМАХ",
    grab     = "КРАЖА",
}

----------------------------------------------------------------------
-- SAFETY
----------------------------------------------------------------------

-- Вызов игрового API, которого в этой сборке может не оказаться. Возвращает
-- fallback вместо того, чтобы уронить весь тик.
local function try(fn, fallback, ...)
    if type(fn) ~= "function" then
        return fallback
    end

    local ok, result = pcall(fn, ...)
    if not ok then
        return fallback
    end

    return result
end

local lastError = nil

local function report(err)
    local message = tostring(err)

    if message ~= lastError then
        lastError = message
        print("[arc_warden_heist] " .. message)
    end
end

----------------------------------------------------------------------
-- MENU
----------------------------------------------------------------------

local ui = {}
local menuReady = false

local DEFAULTS = {
    enabled  = true,
    loop     = true,
    windup   = true,
    delay    = 0.25,
    haltHurt = true,
    tp       = false,
    draw     = true,
    status   = true,
}

local function opt(name)
    local widget = ui[name]

    if widget == nil or widget.Get == nil then
        return DEFAULTS[name]
    end

    local ok, value = pcall(widget.Get, widget)
    if not ok then
        return DEFAULTS[name]
    end

    return value
end

local function buildMenu()
    local tab = Menu.Create("Scripts", "Utility", "Arc Warden Heist", "Main")
    if tab == nil or tab.Create == nil then
        return false
    end

    local mainGroup = tab:Create("Основное", Enum.GroupSide.Left)
    local bindGroup = tab:Create("Кнопки", Enum.GroupSide.Left)
    local showGroup = tab:Create("Постановка", Enum.GroupSide.Right)
    local safeGroup = tab:Create("Безопасность", Enum.GroupSide.Right)

    if mainGroup == nil or mainGroup.Switch == nil then
        return false
    end

    ui.enabled = mainGroup:Switch("Включить", true, "\u{f0e7}")
    ui.enabled:ToolTip("Работает с инвентарём твоего героя. Клон нужен только для замаха.")

    ui.loop = mainGroup:Switch("По кругу", true, "\u{f01e}")
    ui.loop:ToolTip("После кражи выкладываем следующую вещь и повторяем.")

    ui.draw = mainGroup:Switch("Рисовать сцену", true, "\u{f06e}")
    ui.draw:ToolTip("Точка, где лежит вещь, и что с ней происходит.")

    ui.status = mainGroup:Switch("Показывать статус", true, "\u{f05a}")
    ui.status:ToolTip("Строчка над героем: что скрипт делает прямо сейчас. Если он молчит — сразу видно почему.")

    ui.start = bindGroup:Bind("Начать / закончить", Enum.ButtonCode.KEY_NONE, "\u{f04b}")
    ui.start:ToolTip("Точка выкладки — под курсором в момент нажатия. Повторное нажатие всё отменяет.")

    ui.rescue = bindGroup:Bind("Забрать вещь с земли", Enum.ButtonCode.KEY_NONE, "\u{f0c1}")
    ui.rescue:ToolTip("Аварийная кнопка: бросить представление и немедленно подобрать шмотку.")

    ui.delay = showGroup:Slider("Дать снаряду лететь", 0.0, 0.6, 0.25, "%.2f s")
    ui.delay:ToolTip("Сколько снаряд летит, прежде чем вещь выхватят. Клон бьёт с предельной для себя дистанции, там полёт занимает около полусекунды, так что 0.25 — примерно половина пути.")

    ui.tp = showGroup:Switch("Выкладывать и телепорт", false, "\u{f0d1}")
    ui.tp:ToolTip("По умолчанию свиток остаётся в инвентаре, чтобы было чем убегать.")

    ui.windup = safeGroup:Switch("Ждать замаха", true, "\u{f253}")
    ui.windup:ToolTip("Красть в момент, когда клон занёс руку — так эффектнее. Урон всё равно приходит только в конце анимации, шмотка к тому времени уже в сумке. Выключи, если хочешь забирать в ту же секунду, без всякого замаха.")

    ui.haltHurt = safeGroup:Switch("Стоп при первой царапине", true, "\u{f071}")
    ui.haltHurt:ToolTip("Если у вещи хоть на единицу убыло здоровья — представление немедленно прекращается. Значит, где-то сошёлся тайминг, и продолжать нельзя.")

    return true
end

----------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------

local state = {
    phase = nil,       -- layout / summon / approach / beat / grab
    point = nil,       -- куда кладём вещь
    loot = {},         -- вся сумка: { item, index, name }
    active = 1,        -- какая вещь сейчас в работе
    spot = nil,        -- точка выкладки этой вещи
    deadline = 0,
    orderClock = {},
    attackOrdered = false,
    attackRetry = 0,
    sawSwing = false,
    shootSpot = nil,
    releaseAt = nil,
    swingStart = nil,
    pickupRetry = 0,
    castIssued = false,
    castRetry = 0,
    grabIssued = false,
    dropIssued = false,
    itemHealth = nil,
    stopping = false,
    rounds = 0,
    saved = 0,
    hurt = 0,
    broken = 0,
    note = nil,
}

local function reset()
    state.phase = nil
    state.loot = {}
    state.active = 1
    state.spot = nil
    state.orderClock = {}
    state.attackOrdered = false
    state.attackRetry = 0
    state.sawSwing = false
    state.shootSpot = nil
    state.releaseAt = nil
    state.swingStart = nil
    state.pickupRetry = 0
    state.castIssued = false
    state.castRetry = 0
    state.grabIssued = false
    state.dropIssued = false
    state.itemHealth = nil
    state.stopping = false
    state.rounds = 0
    state.saved = 0
    state.hurt = 0
    state.broken = 0
end

local function now()
    return GameRules.GetGameTime() or 0
end

local function enter(phase, duration)
    state.phase = phase
    state.deadline = duration and (now() + duration) or 0
    state.orderClock = {}
    state.attackOrdered = false
    state.attackRetry = 0
    state.sawSwing = false
    state.releaseAt = nil
    state.swingStart = nil
    state.pickupRetry = 0
    state.castIssued = false
    state.castRetry = 0
    state.grabIssued = false
    state.dropIssued = false
end

-- Один и тот же приказ, повторяемый пока юнит идёт: редко, но регулярно,
-- чтобы цель могла сдвинуться, а очередь приказов не захлебнулась.
local function repeatOrder(key, issue)
    local moment = now()

    if (state.orderClock[key] or 0) > moment then
        return
    end

    state.orderClock[key] = moment + ORDER_INTERVAL
    issue()
end

----------------------------------------------------------------------
-- ORDERS
----------------------------------------------------------------------

local function order(player, orderType, target, pos, ability, npc)
    Player.PrepareUnitOrders(
        player,
        orderType,
        target,
        pos,
        ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        npc,
        false,
        false
    )
end

local function orderMove(player, npc, pos)
    order(player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, pos, nil, npc)
end

-- Ровно то же, что клавиша A по шмотке на земле: приказ атаки, целью которого
-- выступает сам CPhysicalItem.
local function orderAttackItem(player, npc, physical)
    order(player, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, physical,
        Entity.GetAbsOrigin(physical), nil, npc)
end

local function orderDrop(player, npc, item, pos)
    order(player, Enum.UnitOrder.DOTA_UNIT_ORDER_DROP_ITEM, nil, pos, item, npc)
end

local function orderPickup(player, npc, physical)
    order(player, Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_ITEM, physical,
        Entity.GetAbsOrigin(physical), nil, npc)
end

local function castNoTarget(player, npc, ability)
    order(player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil,
        Entity.GetAbsOrigin(npc), ability, npc)
end

-- Отменить цикл атаки можно только новым приказом. HoldPosition для этого не
-- годится: юнит остаётся стоять, но начатую атаку доводит до конца. Приказ
-- уйти отменяет её гарантированно, а заодно выглядит как «клон отступил».
local function orderBackOff(player, clone, itemPos, reach)
    local back = itemPos:DirectionTo(Entity.GetAbsOrigin(clone))
    local away = (reach or 0) + BACK_OFF

    orderMove(player, clone, Vector(
        itemPos.x + back.x * away,
        itemPos.y + back.y * away,
        itemPos.z
    ))
end

----------------------------------------------------------------------
-- UNITS AND LOOT
----------------------------------------------------------------------

-- Tempest Double — отдельный юнит-герой под твоим управлением, а не иллюзия,
-- поэтому главный признак это модификатор. Имя юнита оставлено запасным
-- вариантом, но только для своей команды: в деме на карте легко оказывается
-- второй Arc Warden, и без проверки стороны скрипт принимал его за клона.
local function findClone(hero, playerId)
    local fallback = nil

    for _, npc in pairs(NPCs.GetAll()) do
        if npc ~= hero
            and Entity.IsAlive(npc)
            and not Entity.IsDormant(npc)
            and try(NPC.IsControllableByPlayer, false, npc, playerId)
            and try(Entity.IsSameTeam, false, hero, npc)
        then
            if try(NPC.HasModifier, false, npc, CLONE_MODIFIER) then
                return npc
            end

            if fallback == nil and try(NPC.GetUnitName, "", npc) == ARC_WARDEN_UNIT then
                fallback = npc
            end
        end
    end

    return fallback
end

-- Item.IsPermanent сюда не годится: судя по докам и по поведению, это не
-- "неразрушаемый предмет", а внутренний флаг, который false только у
-- стакающихся вещей. У обычного BKB он true, и фильтр по нему выкашивал весь
-- инвентарь подчистую. Отсеиваем только то, что дота и правда не даст бросить.
local BLACKLIST = {
    item_aegis = true,
}

local skipped = 0

local function inventory(hero)
    local items = {}

    skipped = 0

    for slot = 0, 5 do
        local item = NPC.GetItemByIndex(hero, slot)

        if item ~= nil then
            local name = try(Ability.GetName, "", item) or ""
            local isTp = name:find("travel_boots") ~= nil or name:find("tpscroll") ~= nil

            local ok = try(Item.IsDroppable, true, item)
                and not BLACKLIST[name]
                and (opt("tp") or not isTp)

            if ok then
                items[#items + 1] = {
                    item  = item,
                    index = try(Entity.GetIndex, nil, item),
                    name  = name,
                }
            else
                skipped = skipped + 1
            end
        end
    end

    return items
end

-- Вернулась ли вещь в сумку. Единственный способ честно отличить кражу от
-- поражения: с земли шмотка исчезает и в том, и в другом случае.
local function inInventory(hero, entry)
    if entry == nil or entry.index == nil then
        return true
    end

    for slot = 0, 5 do
        local item = NPC.GetItemByIndex(hero, slot)

        if item ~= nil and try(Entity.GetIndex, nil, item) == entry.index then
            return true
        end
    end

    return false
end

-- Предмет на земле — это CPhysicalItem-обёртка; сам CItem при выбрасывании
-- остаётся тем же объектом, поэтому сначала сверяем entity index. Если сборка
-- не даёт индекс предмета, откатываемся на имя плюс близость к точке выкладки.
local function findPhysical(entry)
    if entry == nil or state.spot == nil then
        return nil
    end

    local best, bestDistance = nil, MATCH_RADIUS

    for _, physical in pairs(PhysicalItems.GetAll()) do
        if Entity.IsEntity(physical) and not Entity.IsDormant(physical) then
            local item = PhysicalItem.GetItem(physical)

            if item ~= nil then
                if entry.index ~= nil and try(Entity.GetIndex, nil, item) == entry.index then
                    return physical
                end

                if try(Ability.GetName, "", item) == entry.name then
                    local distance = Entity.GetAbsOrigin(physical):Distance2D(state.spot)

                    if distance < bestDistance then
                        best, bestDistance = physical, distance
                    end
                end
            end
        end
    end

    return best
end

----------------------------------------------------------------------
-- STAGE
----------------------------------------------------------------------

local function flat(point, x, y)
    return Vector(point.x + x, point.y + y, point.z)
end

-- Место, где оригинал караулит: с противоположной от клона стороны вещи,
-- вплотную, чтобы кража была одним движением, а не забегом.
local function ambushSpot(itemPos, clone)
    if clone == nil or not Entity.IsAlive(clone) then
        return flat(itemPos, 90, 0)
    end

    local away = Entity.GetAbsOrigin(clone):DirectionTo(itemPos)
    return flat(itemPos, away.x * 110, away.y * 110)
end

-- Предельная дистанция, с которой клон ещё достаёт до вещи. Чем дальше он
-- стоит, тем дольше летит снаряд и тем больше времени на кражу, поэтому
-- дистанция не настраивается: всегда берётся максимум, который позволяет его
-- собственная дальность атаки вместе с бонусами от предметов.
local function shootReach(clone)
    local reach = try(NPC.GetAttackRange, 0, clone) or 0
    local bonus = try(NPC.GetAttackRangeBonus, 0, clone) or 0

    reach = reach + bonus

    if reach <= 0 then
        return 550
    end

    return math.max(reach - RANGE_MARGIN, 200)
end

-- Точка обстрела: с той стороны, где клон уже находится. Считается один раз за
-- круг и запоминается — иначе точка ползала бы за клоном, и он наматывал бы
-- круги вокруг вещи, так и не встав на позицию.
local function shootSpot(itemPos, clone)
    local back = itemPos:DirectionTo(Entity.GetAbsOrigin(clone))
    local reach = shootReach(clone)

    return flat(itemPos, back.x * reach, back.y * reach)
end

local function arrived(npc, pos, tolerance)
    return Entity.GetAbsOrigin(npc):Distance2D(pos) <= (tolerance or ARRIVE_TOLERANCE)
end

----------------------------------------------------------------------
-- PHASES
----------------------------------------------------------------------

local function activeEntry()
    return state.loot[state.active]
end

-- Круг закончен. Обновляем сумку (индексы вещей после подбора остаются теми
-- же, но состав мог измениться) и берём следующую вещь в работу.
local function nextRound(hero)
    state.rounds = state.rounds + 1

    if not opt("loop") then
        reset()
        state.note = "круг закончен"
        return
    end

    local previous = activeEntry()
    state.loot = inventory(hero)

    if #state.loot == 0 then
        reset()
        state.note = "в сумке пусто"
        return
    end

    -- Работаем с одной и той же вещью круг за кругом. Смена предмета означала
    -- бы, что каждый круг под удар ложится новая шмотка, — лишний риск на
    -- ровном месте.
    state.active = 1

    if previous ~= nil then
        for index, entry in ipairs(state.loot) do
            if entry.index == previous.index then
                state.active = index
                break
            end
        end
    end

    enter("layout", WALK_TIMEOUT)
end

local function startShow(hero)
    local point = Input.GetWorldCursorPos()

    if point == nil then
        state.note = "курсор не над картой"
        return
    end

    local loot = inventory(hero)

    if #loot == 0 then
        state.note = "нечего выкладывать"
        return
    end

    reset()

    state.point = point
    state.loot  = loot
    state.active = 1
    state.note  = nil

    enter("layout", WALK_TIMEOUT)
end

-- Выкладка: на землю отправляется ровно одна вещь. Герой сам идёт к точке и
-- там её бросает — приказ на выброс издалека дота трактует по-своему, поэтому
-- сначала ноги, потом руки.
local function runLayout(player, hero)
    local entry = activeEntry()

    if entry == nil or not Entity.IsEntity(entry.item) then
        nextRound(hero)
        return
    end

    if not state.dropIssued then
        if arrived(hero, state.point) or now() >= state.deadline then
            orderDrop(player, hero, entry.item, state.point)
            state.dropIssued = true
            state.spot = state.point
            state.deadline = now() + DROP_SETTLE
        else
            repeatOrder("hero", function ()
                orderMove(player, hero, state.point)
            end)
        end

        return
    end

    if now() >= state.deadline then
        enter("summon", SUMMON_TIMEOUT)
    end
end

-- Почему ульта не идёт. Нужно не для красоты: «клон не пришёл» без причины
-- ничего не объясняет, а вариантов ровно три и они лечатся по-разному.
local function doubleProblem(hero, double)
    if double == nil then
        return "нет ульты у героя"
    end

    if try(Ability.GetLevel, 1, double) == 0 then
        return "ульта не прокачана"
    end

    local cooldown = try(Ability.GetCooldown, 0, double)
    if cooldown > 0 then
        return string.format("ульта в откате %.0f", cooldown)
    end

    local cost = try(Ability.GetManaCost, 0, double)
    if cost > try(NPC.GetMana, 0, hero) then
        return "не хватает маны"
    end

    return nil
end

local function runSummon(player, hero, clone)
    if clone ~= nil then
        state.note = nil
        enter("approach", WALK_TIMEOUT)
        return
    end

    local double = NPC.GetAbility(hero, ABILITY_DOUBLE)
    local problem = doubleProblem(hero, double)

    -- Каст отдаётся раз в секунду, а не каждый кадр. Это и была причина, по
    -- которой клон не появлялся вообще: приказ, повторённый на следующем тике,
    -- прерывает анимацию каста, и ульта бесконечно начиналась заново.
    if double ~= nil and problem == nil and now() >= state.castRetry then
        castNoTarget(player, hero, double)
        state.castIssued = true
        state.castRetry = now() + CAST_RETRY
    end

    state.note = problem

    if now() >= state.deadline then
        -- Вещь на земле оставлять нельзя, поэтому просто забираем её обратно.
        state.note = problem or "клон не пришёл"
        enter("grab", GRAB_TIMEOUT)
    end
end

-- Расстановка. Клона не подпускают к вещи, пока оригинал не встал вплотную:
-- иначе он начинает бить, когда красть ещё некому, и спокойно доламывает.
local function runApproach(player, hero, clone)
    local entry = activeEntry()
    local physical = findPhysical(entry)

    if physical == nil then
        if now() >= state.deadline then
            nextRound(hero)
        end

        return
    end

    local itemPos = Entity.GetAbsOrigin(physical)

    repeatOrder("hero", function ()
        orderMove(player, hero, ambushSpot(itemPos, clone))
    end)

    if clone == nil or not Entity.IsAlive(clone) then
        enter("grab", GRAB_TIMEOUT)
        return
    end

    local heroReady = arrived(hero, itemPos, GRAB_RANGE)

    if state.shootSpot == nil then
        state.shootSpot = shootSpot(itemPos, clone)
    end

    repeatOrder("clone", function ()
        orderMove(player, clone, state.shootSpot)
    end)

    local cloneReady = arrived(clone, state.shootSpot, SHOOT_TOLERANCE)

    -- Пока вор не на месте, клон просто идёт на позицию и не бьёт. Таймаут
    -- тоже ждёт вора: начать стрельбу без него — единственный способ потерять
    -- вещь.
    if heroReady and (cloneReady or now() >= state.deadline) then
        enter("beat", SWING_WAIT)
    end
end

-- Замах. Клону отдаётся РОВНО ОДИН приказ атаки за весь круг, и как только он
-- заносит руку, вещь выхватывают. Урон приходит в конце анимации, да ещё и
-- после полёта снаряда, так что к этому моменту хватать уже нечего.
local function runBeat(player, hero, clone)
    local entry = activeEntry()
    local physical = findPhysical(entry)

    if physical == nil then
        nextRound(hero)
        return
    end

    local itemPos = Entity.GetAbsOrigin(physical)
    local health = try(Entity.GetHealth, 0, physical)

    if state.itemHealth == nil then
        state.itemHealth = health
    end

    -- Царапина. Значит, где-то сошёлся тайминг — хватаем вне очереди.
    if health < state.itemHealth then
        state.hurt = state.hurt + 1
        state.itemHealth = health
        enter("grab", GRAB_TIMEOUT)
        return
    end

    if clone ~= nil and Entity.IsAlive(clone) then
        if not state.attackOrdered then
            orderAttackItem(player, clone, physical)
            state.attackOrdered = true
            state.attackRetry = now() + SWING_RETRY
        elseif not state.sawSwing and now() >= state.attackRetry then
            -- Замах так и не начался: первый приказ где-то потерялся. Повтор
            -- безопасен именно здесь — прерывать нечего.
            orderAttackItem(player, clone, physical)
            state.attackRetry = now() + SWING_RETRY
        end
    end

    -- Оригинал держится вплотную всё это время.
    repeatOrder("hero", function ()
        orderMove(player, hero, ambushSpot(itemPos, clone))
    end)

    -- Момент кражи. IsAttacking держится всю анимацию, поэтому её падение
    -- обратно в false и есть выстрел; после него снаряду дают пролететь часть
    -- пути. Но полагаться на один этот признак нельзя: если сборка его не
    -- отдаёт, ждать будет нечего, а клон всё это время продолжает бить сам —
    -- приказ атаки по цели не разовый. Поэтому поверх стоит жёсткий потолок,
    -- посчитанный от времени замаха: после него хватаем в любом случае.
    local moment = now()
    local swinging = clone ~= nil and try(NPC.IsAttacking, false, clone)

    if swinging then
        state.sawSwing = true
        state.swingStart = state.swingStart or moment
    elseif state.sawSwing and state.releaseAt == nil then
        state.releaseAt = moment
    end

    local limit

    if state.releaseAt ~= nil then
        limit = state.releaseAt + opt("delay")
    elseif state.swingStart ~= nil then
        local animPoint = try(NPC.GetAttackAnimPoint, FALLBACK_ANIM_POINT, clone)

        if type(animPoint) ~= "number" or animPoint <= 0 then
            animPoint = FALLBACK_ANIM_POINT
        end

        limit = state.swingStart + animPoint + SHOT_MARGIN
    else
        limit = state.deadline
    end

    if not opt("windup") or moment >= limit or moment >= state.deadline then
        enter("grab", GRAB_TIMEOUT)
    end
end

-- Кража: клону сначала командуют «стоять», иначе он спокойно доводит начатое
-- до конца, пока оригинал тянет руки. Приказ на подбор идёт один раз, дальше
-- ждём факта — вещь исчезла с земли.
local function runGrab(player, hero, clone)
    local entry = activeEntry()
    local physical = findPhysical(entry)

    -- Первым делом обрываем клону цикл атаки, и только потом занимаемся
    -- подбором. Порядок здесь важен: пока приказ атаки висит, каждая
    -- следующая секунда — это ещё одна тычка по вещи.
    if clone ~= nil and Entity.IsAlive(clone) and physical ~= nil then
        repeatOrder("clone", function ()
            orderBackOff(player, clone, Entity.GetAbsOrigin(physical), shootReach(clone))
        end)
    end

    if physical == nil then
        -- Вещь пропала. Единственный честный вопрос: она у нас в сумке или
        -- клон всё-таки её доломал.
        if entry ~= nil then
            if inInventory(hero, entry) then
                state.saved = state.saved + 1
            else
                state.broken = state.broken + 1
                reset()
                state.note = "вещь сломана, представление остановлено"
                return
            end
        end

        if state.stopping then
            reset()
            state.note = "представление закончено"
            return
        end

        if state.hurt > 0 and opt("haltHurt") then
            local hurt = state.hurt
            reset()
            state.hurt = hurt
            state.note = "вещь задело, представление остановлено"
            return
        end

        nextRound(hero)
        return
    end

    -- Приказ на подбор повторяется часто: он не запускает анимацию, обрывать
    -- ему нечего, а вещь всё это время лежит под ударом.
    if now() >= state.pickupRetry then
        orderPickup(player, hero, physical)
        state.grabIssued = true
        state.pickupRetry = now() + PICKUP_RETRY
    end

    -- Подбор не идёт совсем: герой далеко, оглушён или сумка полна. Подходим
    -- вплотную сами, вместо того чтобы стоять и смотреть.
    if now() >= state.deadline then
        repeatOrder("hero", function ()
            orderMove(player, hero, Entity.GetAbsOrigin(physical))
        end)
    end
end

-- Аварийная кнопка и вообще любая остановка: забираем вещь с земли и на этом
-- заканчиваем. Флаг обязателен — без него фаза кражи, отработав, послушно
-- уходит на следующий круг, и представление не кончается никогда.
local function startRescue()
    if activeEntry() == nil then
        state.note = "нечего забирать"
        return
    end

    enter("grab", GRAB_TIMEOUT)
    state.stopping = true
end

----------------------------------------------------------------------
-- CALLBACKS
----------------------------------------------------------------------

local font = nil
local clone = nil

function script.OnScriptsLoaded()
    local ok, result = pcall(buildMenu)
    menuReady = ok and result == true

    if not ok then
        report("menu: " .. tostring(result))
    end

    font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
        or Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)

    print("[arc_warden_heist] loaded, menu=" .. tostring(menuReady))

    if ai_bridge ~= nil and ai_bridge.mcp_log ~= nil then
        ai_bridge.mcp_log("info", "arc_warden_heist loaded", {
            menu_ready = menuReady,
            error = (not ok) and tostring(result) or nil,
        })
    end
end

local function update()
    if not opt("enabled") then
        state.phase = nil
        return
    end

    local hero   = Heroes.GetLocal()
    local player = Players.GetLocal()

    if hero == nil or player == nil or not Entity.IsAlive(hero) then
        state.phase = nil
        return
    end

    clone = findClone(hero, Player.GetPlayerID(player))

    if ui.rescue ~= nil and ui.rescue:IsPressed() then
        startRescue()
        return
    end

    if ui.start ~= nil and ui.start:IsPressed() then
        if state.phase ~= nil then
            -- Останавливаемся не на полпути: если вещь сейчас на земле, сперва
            -- забираем её, и только потом сворачиваемся.
            if findPhysical(activeEntry()) ~= nil then
                startRescue()
            else
                reset()
                Player.HoldPosition(player, hero, false, false, false, "arc_heist_stop")
            end
        else
            startShow(hero)
        end

        return
    end

    if state.phase == "layout" then
        runLayout(player, hero)
    elseif state.phase == "summon" then
        runSummon(player, hero, clone)
    elseif state.phase == "approach" then
        runApproach(player, hero, clone)
    elseif state.phase == "beat" then
        runBeat(player, hero, clone)
    elseif state.phase == "grab" then
        runGrab(player, hero, clone)
    end
end

function script.OnUpdate()
    local ok, err = pcall(update)

    if not ok then
        report(err)
    end
end

----------------------------------------------------------------------
-- DRAWING
----------------------------------------------------------------------

local ACCENT = Color(255, 190, 70, 235)
local HOT    = Color(255, 90, 90, 240)
local CALM   = Color(120, 220, 255, 220)
local BAD    = Color(255, 120, 120, 240)

local function text(size, value, pos, color)
    Render.Text(font, size, value, Vec2(pos.x + 1, pos.y + 1), Color(0, 0, 0, 200))
    Render.Text(font, size, value, pos, color)
end

-- Строчка над героем. Рисуется даже когда скрипт стоит: главный вопрос к
-- такому скрипту — «он вообще живой?», и ответ должен быть на экране, а не в
-- догадках.
local function drawStatus(hero)
    local line

    if lastError ~= nil then
        line = "HEIST: ошибка, смотри консоль"
    elseif not menuReady then
        line = "HEIST: меню не построилось"
    elseif state.phase == nil then
        local count = #inventory(hero)

        line = string.format("HEIST: жду бинд · в сумке %d%s · клон %s",
            count,
            skipped > 0 and string.format(" (отсеяно %d)", skipped) or "",
            clone ~= nil and "есть" or "нет")
    else
        local entry = state.loot[state.active]

        line = string.format("HEIST: %s · %s · спасено %d",
            PHASE_TITLE[state.phase] or "?",
            entry ~= nil and (entry.name:gsub("^item_", "")) or "?",
            state.saved)

        if state.phase == "beat" then
            if state.releaseAt ~= nil then
                line = line .. " · снаряд в полёте"
            elseif state.sawSwing then
                line = line .. " · замах пошёл"
            else
                line = line .. " · ждём замах"
            end
        end

        if state.hurt > 0 then
            line = line .. string.format(" · задето %d", state.hurt)
        end

        if state.broken > 0 then
            line = line .. string.format(" · СЛОМАНО %d", state.broken)
        end
    end

    if state.note ~= nil then
        line = line .. " · " .. state.note
    end

    local screen, visible = Render.WorldToScreen(Entity.GetAbsOrigin(hero) + Vector(0, 0, 320))

    if visible then
        local color = CALM

        if lastError ~= nil or state.broken > 0 then
            color = BAD
        elseif state.hurt > 0 then
            color = ACCENT
        end

        text(14, line, screen, color)
    end
end

local function draw()
    if font == nil or not opt("enabled") then
        return
    end

    local hero = Heroes.GetLocal()
    if hero == nil or not Entity.IsAlive(hero) then
        return
    end

    if opt("status") then
        drawStatus(hero)
    end

    if not opt("draw") or state.phase == nil or state.spot == nil then
        return
    end

    local screen, visible = Render.WorldToScreen(state.spot)

    if visible then
        local hot = state.phase == "beat" or state.phase == "grab"
        Render.FilledCircle(screen, hot and 7 or 5, hot and HOT or CALM)

        local entry = state.loot[state.active]
        local label = PHASE_TITLE[state.phase] or "?"

        if entry ~= nil and entry.name ~= "" then
            label = string.format("%s · %s", label, (entry.name:gsub("^item_", "")))
        end

        text(15, label, Vec2(screen.x + 12, screen.y - 10), hot and HOT or ACCENT)
    end
end

function script.OnDraw()
    local ok, err = pcall(draw)

    if not ok then
        report(err)
    end
end

return script
