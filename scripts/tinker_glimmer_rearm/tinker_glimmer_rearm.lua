local script = {}

-- ============ МЕНЮ (ИСПРАВЛЕНА СТРУКТУРА ДЛЯ UMBRELLA) ============
-- 1. Создаем подвкладку
local mainTab = Menu.Create("Heroes", "Hero List", "Tinker", "Glimmer during Rearm")
-- 2. ОБЯЗАТЕЛЬНО создаем группу (секцию) внутри вкладки, иначе меню будет пустым!
local group = mainTab:Create("Настройки авто-глиммера")

local enabledSwitch = group:Switch("Включить Глиммер при Реарме", true)
local checkManaSwitch = group:Switch("Проверять ману", true)

-- ============ ЗАДЕРЖКА ПРИКАЗОВ ============
local last_order_time = 0
local ORDER_DELAY = 0.2

local function CanOrder()
    local time = GameRules.GetGameTime()
    if time - last_order_time > ORDER_DELAY then
        last_order_time = time
        return true
    end
    return false
end

-- ============ ПОИСК ПРЕДМЕТА И СПОСОБНОСТИ ============
local function FindGlimmer(me)
    return NPC.GetItem(me, "item_glimmer_cape", true)
end

local function GetRearm(me)
    -- Ищем Реарм по имени, если API не находит — берем 6-й слот (индекс 5)
    local rearm = NPC.GetAbility(me, "tinker_rearm")
    if not rearm then
        rearm = NPC.GetAbilityByIndex(me, 5)
    end
    return rearm
end

-- ============ ОСНОВНОЙ ЦИКЛ ============
function script.OnUpdate()
    -- Проверка включения в меню
    if not enabledSwitch:Get() then
        return
    end

    local me = Heroes.GetLocal()
    if not me or not Entity.IsAlive(me) then
        return
    end

    -- 1. Находим способность Rearm
    local rearm = GetRearm(me)
    if not rearm then return end

    -- 2. НАДЕЖНАЯ ПРОВЕРКА КАСТА:
    -- Проверяем, находится ли Реарм в процессе прерываемого каста (Channeling)
    local isRearming = Ability.IsChannelling(rearm)

    -- Если API поддерживает проверку через героя, дублируем для 100% срабатывания
    if not isRearming and NPC.IsChannellingAbility(me) then
        local chanAb = NPC.GetChannellingAbility(me)
        if chanAb and chanAb == rearm then
            isRearming = true
        end
    end

    -- Если прямо сейчас Реарм НЕ кастуется — выходим
    if not isRearming then
        return
    end

    -- 3. Ищем Glimmer Cape в инвентаре
    local glimmer = FindGlimmer(me)
    if not glimmer then
        return
    end

    -- 4. Проверяем перезарядку предмета
    if Ability.GetCooldown(glimmer) > 0 then
        return
    end

    -- 5. Проверяем ману (чтобы не потратить последние гроши, если включено в меню)
    if checkManaSwitch:Get() then
        local manaCost = Ability.GetManaCost(glimmer)
        if NPC.GetMana(me) < manaCost then
            return
        end
    end

    -- 6. Кастуем Глиммер на себя во время Реарма!
    if CanOrder() then
        Ability.CastTarget(glimmer, me)
        print("[Tinker] Glimmer Cape успешно применен во время каста Rearm!")
    end
end

return script
