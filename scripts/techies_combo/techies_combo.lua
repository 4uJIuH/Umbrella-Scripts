local script = {}

local localization = qLocalization.new({
    en = {
        combo = {
            linken_tip = "Spends the first available item on the target when its Linken's Sphere is up. Drag to set the order.",
            refresher_tip = "Refreshes after the tazer blast and runs the combo a second time.",
            blink = "Blink Out",
            blink_to = "Blink To",
            blink_tip = "Blinks away once the combo is over. Waits out the damage lockout on the dagger.",
            to_fountain = "Allied Fountain",
            to_ally = "Nearest Ally",
            mode = "Combo Mode",
            mode_tip = "Aggressive hexes on the way in. Max Damage saves the hex to extend the lockdown. Blink dashes in with the dagger and finishes with Blast Off.",
            aggressive = "Aggressive",
            maxdmg = "Max Damage",
            blinkmode = "Blink",
        },
    },
    ru = {
        combo = {
            linken_tip = "Сначала тратит в цель первый доступный предмет, если у неё поднята Линка. Порядок задаётся перетаскиванием.",
            refresher_tip = "После взрыва тазера обновляет предметы и прогоняет комбо второй раз.",
            blink = "Выход блинком",
            blink_to = "Прыгать",
            blink_tip = "Уходит блинком, когда комбо закончилось. Ждёт, пока даггер отпустит после урона.",
            to_fountain = "К союзному фонтану",
            to_ally = "К ближайшему союзнику",
            mode = "Режим комбо",
            mode_tip = "Агрессивный жмёт хекс на заходе. Максимальный дамаг бережёт хекс, чтобы продлить контроль в конце. Блинк заходит даггером и заканчивает прыжком.",
            aggressive = "Агрессивный",
            maxdmg = "Максимальный дамаг",
            blinkmode = "Блинк",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local hero = Menu.Create("Heroes", "Hero List", "Techies", "Combo+", "Hero Settings")
local goods = Menu.Create("Heroes", "Hero List", "Techies", "Combo+", "Items Settings")

local enable = hero:Switch("Enable", false, "\u{f00c}")
local key = hero:Bind("Combo Key", Enum.ButtonCode.KEY_G, "\u{e1c1}")
local mode = hero:Combo("combo.mode", { "combo.aggressive", "combo.maxdmg", "combo.blinkmode" }, 0)
mode:Icon("\u{f0e7}")
mode:ToolTip("combo.mode_tip")
local abilities = hero:MultiSelect("Abilities", {
    { "Blast Off", "panorama/images/spellicons/techies_suicide_png.vtex_c", true },
    { "Sticky Bomb", "panorama/images/spellicons/techies_sticky_bomb_png.vtex_c", true },
    { "Reactive Tazer", "panorama/images/spellicons/techies_reactive_tazer_png.vtex_c", true },
    { "Proximity Mines", "panorama/images/spellicons/techies_land_mines_png.vtex_c", true },
    { "Minefield Sign", "panorama/images/spellicons/techies_minefield_sign_png.vtex_c", true },
}, true)
abilities:Icon("\u{f890}")
local detonate = hero:Switch("Detonate Tazer", true)
detonate:Image("panorama/images/spellicons/techies_reactive_tazer_png.vtex_c")

local use_items = goods:MultiSelect("Items Usage", {
    { "Hex", "panorama/images/items/sheepstick_png.vtex_c", true },
    { "Nullifier", "panorama/images/items/nullifier_png.vtex_c", true },
    { "Orchid", "panorama/images/items/orchid_png.vtex_c", true },
    { "Bloodthorn", "panorama/images/items/bloodthorn_png.vtex_c", true },
    { "Ethereal Blade", "panorama/images/items/ethereal_blade_png.vtex_c", true },
    { "Shiva's Guard", "panorama/images/items/shivas_guard_png.vtex_c", true },
    { "Dagon", "panorama/images/items/dagon_5_png.vtex_c", true },
    { "Spirit Vessel", "panorama/images/items/spirit_vessel_png.vtex_c", true },
    { "Urn of Shadows", "panorama/images/items/urn_of_shadows_png.vtex_c", true },
}, false)
use_items:Icon("\u{e196}")
local breaker = goods:MultiSelect("Linkbreaker Items", {
    { "Hex", "panorama/images/items/sheepstick_png.vtex_c", false },
    { "Nullifier", "panorama/images/items/nullifier_png.vtex_c", false },
    { "Orchid", "panorama/images/items/orchid_png.vtex_c", false },
    { "Bloodthorn", "panorama/images/items/bloodthorn_png.vtex_c", false },
    { "Ethereal Blade", "panorama/images/items/ethereal_blade_png.vtex_c", false },
    { "Dagon", "panorama/images/items/dagon_5_png.vtex_c", false },
    { "Spirit Vessel", "panorama/images/items/spirit_vessel_png.vtex_c", false },
    { "Urn of Shadows", "panorama/images/items/urn_of_shadows_png.vtex_c", false },
    { "Rod of Atos", "panorama/images/items/rod_of_atos_png.vtex_c", true },
    { "Gleipnir", "panorama/images/items/gungir_png.vtex_c", true },
    { "Diffusal Blade", "panorama/images/items/diffusal_blade_png.vtex_c", true },
    { "Disperser", "panorama/images/items/disperser_png.vtex_c", true },
    { "Abyssal Blade", "panorama/images/items/abyssal_blade_png.vtex_c", true },
    { "Heaven's Halberd", "panorama/images/items/heavens_halberd_png.vtex_c", true },
    { "Eul's Scepter", "panorama/images/items/cyclone_png.vtex_c", true },
    { "Wind Waker", "panorama/images/items/wind_waker_png.vtex_c", true },
    { "Force Staff", "panorama/images/items/force_staff_png.vtex_c", true },
    { "Hurricane Pike", "panorama/images/items/hurricane_pike_png.vtex_c", true },
    { "Harpoon", "panorama/images/items/harpoon_png.vtex_c", true },
}, false)
breaker:Image("panorama/images/items/sphere_png.vtex_c")
breaker:ToolTip("combo.linken_tip")
local refresher = goods:Switch("Use Refresher", false)
refresher:Image("panorama/images/items/refresher_png.vtex_c")
refresher:ToolTip("combo.refresher_tip")

local blink_out = goods:Switch("combo.blink", false)
blink_out:Image("panorama/images/items/blink_png.vtex_c")
blink_out:ToolTip("combo.blink_tip")
local blink_to = blink_out:Gear("Blink Out"):Combo("combo.blink_to", { "combo.to_fountain", "combo.to_ally" }, 0)

abilities:DragAllowed(false)
use_items:DragAllowed(false)
breaker:DragAllowed(true)

local GATED = { key, mode, abilities, detonate, use_items, breaker, refresher, blink_out }
enable:SetCallback(function(this)
    for _, w in ipairs(GATED) do w:Disabled(not this:Get()) end
end, true)

local NAMES = {
    Hex = { "item_sheepstick" },
    Nullifier = { "item_nullifier" },
    Orchid = { "item_orchid" },
    Bloodthorn = { "item_bloodthorn" },
    ["Ethereal Blade"] = { "item_ethereal_blade" },
    ["Shiva's Guard"] = { "item_shivas_guard" },
    Dagon = { "item_dagon_5", "item_dagon_4", "item_dagon_3", "item_dagon_2", "item_dagon" },
    ["Spirit Vessel"] = { "item_spirit_vessel" },
    ["Urn of Shadows"] = { "item_urn_of_shadows" },
    ["Rod of Atos"] = { "item_rod_of_atos" },
    Gleipnir = { "item_gungir" },
    ["Diffusal Blade"] = { "item_diffusal_blade" },
    Disperser = { "item_disperser" },
    ["Abyssal Blade"] = { "item_abyssal_blade" },
    ["Heaven's Halberd"] = { "item_heavens_halberd" },
    ["Eul's Scepter"] = { "item_cyclone" },
    ["Wind Waker"] = { "item_wind_waker" },
    ["Force Staff"] = { "item_force_staff" },
    ["Hurricane Pike"] = { "item_hurricane_pike" },
    Harpoon = { "item_harpoon" },
}
local NOTARGET = { ["Shiva's Guard"] = true }
local BURST = { "Nullifier", "Orchid", "Bloodthorn", "Ethereal Blade", "Shiva's Guard",
                "Dagon", "Spirit Vessel", "Urn of Shadows" }
local MINE_TURN = { 0, 0.17, -0.17, 0.35, -0.35, 0.52, -0.52, 0.70, -0.70, 0.87, -0.87, 1.05, -1.05 }
local MINE_R = { 259, 213, 197 }
local MINE_A = { -0.7854, -2.8798, 1.1345 }

local BLINKS = { "item_blink", "item_swift_blink", "item_arcane_blink", "item_overwhelming_blink" }

local step, next_at, deadline, target, refreshed = 0, 0, 0, nil, false
local done, fountain, blink_until = {}, nil, 0
local px, py, pt, vx, vy, sampled = 0, 0, 0, 0, 0, false
local cx, cy, cang = 0, 0, 0
local aim_x, aim_y, land_at, miss_r, reaims = 0, 0, 0, 0, 0

local function stop()
    step, target, refreshed, done = 0, nil, false, {}
    vx, vy, sampled, miss_r, reaims = 0, 0, false, 0, 0
end

local function track(his)
    local now = GameRules.GetGameTime()
    local dt = now - pt
    if dt < 0.1 then return end
    local nx, ny = (his.x - px) / dt, (his.y - py) / dt
    if math.sqrt(nx * nx + ny * ny) > NPC.GetMoveSpeed(target) * 1.6 then nx, ny = 0, 0 end
    px, py, pt, vx, vy, sampled = his.x, his.y, now, nx, ny, true
end

local function lead(his, t, cap)
    local dx, dy = vx * t, vy * t
    local d = math.sqrt(dx * dx + dy * dy)
    if cap and d > cap then dx, dy = dx / d * cap, dy / d * cap end
    return Vector(his.x + dx, his.y + dy, his.z)
end

local function pause(sec)
    next_at = GameRules.GetGameTime() + sec + NetChannel.GetAvgLatency()
end

local function seen()
    return not Entity.IsDormant(target)
end

local function controlled()
    return seen() and (NPC.IsStunned(target) or NPC.HasModifier(target, "modifier_sheepstick_debuff"))
end

local function usable(me, names)
    for _, n in ipairs(names) do
        local a = NPC.GetItem(me, n)
        if a and Ability.IsCastable(a, NPC.GetMana(me)) then return a end
    end
end

local function throw_item(me, id)
    if done[id] or not use_items:Get(id) or (not NOTARGET[id] and not seen()) then return end
    local a = usable(me, NAMES[id])
    if not a then return end
    if NOTARGET[id] then Ability.CastNoTarget(a) else Ability.CastTarget(a, target) end
    done[id] = true
    pause(0.15)
    return true
end

local function control_ends()
    local t = 0
    for _, m in ipairs(NPC.GetModifiers(target)) do
        local n = Modifier.GetName(m)
        if n:find("stun") or n == "modifier_sheepstick_debuff" then
            local e = Modifier.GetDieTime(m)
            if e > t then t = e end
        end
    end
    return t
end

local function blast_tazer(me)
    local a = NPC.GetAbility(me, "techies_reactive_tazer_stop")
    if not detonate:Get() or not a or not NPC.HasModifier(me, "modifier_techies_reactive_tazer") then return end
    Ability.CastNoTarget(a)
    pause(0.15)
end

local function hex(me)
    if controlled() then return end
    throw_item(me, "Hex")
end

local function burst(me)
    for _, id in ipairs(BURST) do
        if throw_item(me, id) then return true end
    end
end

local function spell(me, name, toggle)
    if not abilities:Get(toggle) then return nil end
    local a = NPC.GetAbility(me, name)
    if not a or Ability.GetLevel(a) < 1 or Ability.IsHidden(a) then return nil end
    return Ability.IsCastable(a, NPC.GetMana(me)) and a or nil
end

local function swing(a)
    pause(Ability.GetCastPoint(a) + 0.12)
end

local function tazer(me)
    if done.tazer then return end
    local a = spell(me, "techies_reactive_tazer", "Reactive Tazer")
    if not a then return end
    Ability.CastTarget(a, me)
    done.tazer = true
    swing(a)
end

local function bomb(me, his)
    if done.bomb then return end
    local a = spell(me, "techies_sticky_bomb", "Sticky Bomb")
    if not a then return end
    Ability.CastPosition(a, lead(his, Ability.GetCastPoint(a) + 0.2))
    done.bomb = true
    swing(a)
end

local function sign(me)
    if done.sign then return end
    local a = spell(me, "techies_minefield_sign", "Minefield Sign")
    if not a then return end
    Ability.CastPosition(a, Entity.GetAbsOrigin(me))
    done.sign = true
    swing(a)
end

local function mine_spot(i, o, rng)
    local base, fx, fy = cang + MINE_A[i], nil, nil
    for _, turn in ipairs(MINE_TURN) do
        local x = cx + MINE_R[i] * math.cos(base + turn)
        local y = cy + MINE_R[i] * math.sin(base + turn)
        if GridNav.IsTraversable(Vector(x, y, o.z), 0x1, 0x102) then
            if (x - o.x) ^ 2 + (y - o.y) ^ 2 <= rng * rng then return x, y end
            if not fx then fx, fy = x, y end
        end
    end
    if not fx then fx, fy = cx + MINE_R[i] * math.cos(base), cy + MINE_R[i] * math.sin(base) end
    local dx, dy = fx - o.x, fy - o.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= rng then return fx, fy end
    return o.x + dx / d * rng, o.y + dy / d * rng
end

local function dagger(me)
    for _, n in ipairs(BLINKS) do
        local a = NPC.GetItem(me, n)
        if a and Ability.IsCastable(a, NPC.GetMana(me)) and Item.IsItemEnabled(a) then return a end
    end
end

local function escape_to(me)
    if blink_to:Get() == 1 then
        local mine, best, far = Entity.GetAbsOrigin(me), nil, 1e18
        for _, h in pairs(Heroes.GetAll()) do
            if h ~= me and Entity.GetTeamNum(h) == Entity.GetTeamNum(me)
                and Entity.IsAlive(h) and not Entity.IsDormant(h) then
                local o = Entity.GetAbsOrigin(h)
                local d = (o.x - mine.x) ^ 2 + (o.y - mine.y) ^ 2
                if d < far then best, far = o, d end
            end
        end
        return best
    end
    if fountain then return fountain end
    for _, e in pairs(Entities.GetAll()) do
        if Entity.GetClassName(e) == "C_DOTA_Unit_Fountain" and Entity.GetTeamNum(e) == Entity.GetTeamNum(me) then
            fountain = Entity.GetAbsOrigin(e)
            return fountain
        end
    end
end

function script.OnUpdate()
    local me = Heroes.GetLocal()
    if not enable:Get() or not me then return stop() end

    local down = Input.IsKeyDown(key:Get())
    if not down then
        if step > 0 then stop() end
    elseif step == 0 then
        target = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)
        if target then
            local o = Entity.GetAbsOrigin(target)
            step, next_at, refreshed, done = 1, 0, false, {}
            px, py, pt, vx, vy, sampled = o.x, o.y, GameRules.GetGameTime(), 0, 0, false
        end
    end

    if step == 0 then return end
    if not Entity.IsAlive(me) then return stop() end
    if step < 20 and (not target or not Entity.IsAlive(target)) then
        if not blink_out:Get() then return stop() end
        blink_until, step = GameRules.GetGameTime() + 3.5, 20
    end
    if GameRules.GetGameTime() < next_at then return end

    local mine = Entity.GetAbsOrigin(me)
    local his = target and Entity.GetAbsOrigin(target) or mine
    if target and seen() then track(his) end

    if step == 1 then
        local a = NPC.GetItem(target, "item_sphere")
        if a and Ability.GetCooldown(a) == 0 then
            for _, id in ipairs(breaker:ListEnabled()) do
                local b = usable(me, NAMES[id])
                if b then
                    Ability.CastTarget(b, target)
                    done[id] = true
                    pause(0.15)
                    break
                end
            end
        end
        step = mode:Get() == 2 and 21 or 2
    elseif step == 2 then
        if not sampled and GameRules.GetGameTime() - pt < 0.25 then return end
        local a = spell(me, "techies_suicide", "Blast Off")
        if a then
            local fly = Ability.GetCastPoint(a) + 0.75
            local goal = lead(his, fly, Ability.GetLevelSpecialValueFor(a, "radius"))
            Ability.CastPosition(a, goal)
            aim_x, aim_y = goal.x, goal.y
            land_at = GameRules.GetGameTime() + fly
            miss_r = Ability.GetLevelSpecialValueFor(a, "radius")
        end
        deadline = GameRules.GetGameTime() + (a and 2.5 or 0)
        pause(0.05)
        step = 3
    elseif step == 3 then
        if NPC.HasModifier(me, "modifier_techies_suicide_leap") or GameRules.GetGameTime() > deadline then
            step = 4
            return
        end
        if miss_r <= 0 or not seen() then return end
        local rem = land_at - GameRules.GetGameTime()
        if rem <= 0 then return end
        local dx, dy = his.x + vx * rem - aim_x, his.y + vy * rem - aim_y
        if dx * dx + dy * dy > miss_r * miss_r then
            local a = NPC.GetAbility(me, "techies_suicide")
            if a and Ability.IsInAbilityPhase(a) then
                Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, nil,
                    mine, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
                if reaims >= 3 then return stop() end
                reaims, miss_r, step = reaims + 1, 0, 2
                pause(0.05)
                return
            end
        end
    elseif step == 4 then
        if mode:Get() == 0 then hex(me) else tazer(me) end
        step = 5
    elseif step == 5 then
        if mode:Get() == 0 then throw_item(me, "Ethereal Blade") else bomb(me, his) end
        step = 6
    elseif step == 6 then
        if mode:Get() == 0 then tazer(me) else sign(me) end
        step = 7
    elseif step == 7 then
        if mode:Get() == 1 then hex(me) end
        step = 8
    elseif step == 8 then
        if mode:Get() == 0 then bomb(me, his) else throw_item(me, "Ethereal Blade") end
        step = 9
    elseif step == 9 then
        if not NPC.HasModifier(me, "modifier_techies_suicide_leap") then
            cx, cy = his.x, his.y
            cang = math.atan(mine.y - his.y, mine.x - his.x)
            step = mode:Get() == 2 and 26 or 10
        end
    elseif step < 13 then
        local a = spell(me, "techies_land_mines", "Proximity Mines")
        if a then
            local mx, my = mine_spot(step - 9, mine, Ability.GetCastRange(a) - 25)
            Ability.CastPosition(a, Vector(mx, my, mine.z))
            pause(0.2)
        end
        step = step + 1
    elseif step == 13 then
        if burst(me) then return end
        step = 14
    elseif step == 14 then
        tazer(me)
        step = 15
    elseif step == 15 then
        bomb(me, his)
        step = 16
    elseif step == 16 then
        blast_tazer(me)
        deadline = GameRules.GetGameTime() + 3
        step = 17
    elseif step == 17 then
        if not done.Hex and use_items:Get("Hex") and usable(me, NAMES.Hex) and seen()
            and GameRules.GetGameTime() < deadline
            and control_ends() - GameRules.GetGameTime() > 0.35 then return end
        throw_item(me, "Hex")
        step = 18
    elseif step == 18 then
        if mode:Get() ~= 1 then sign(me) end
        step = 19
    elseif step == 19 then
        local a = not refreshed and refresher:Get()
            and usable(me, { "item_refresher", "item_refresher_shard" }) or nil
        if a then
            Ability.CastNoTarget(a)
            refreshed, done = true, {}
            pause(0.3)
            step = 1
            return
        end
        if not blink_out:Get() then return stop() end
        blink_until = GameRules.GetGameTime() + 3.5
        step = 20
    elseif step == 20 then
        local a = dagger(me)
        if not a then
            if GameRules.GetGameTime() > blink_until then stop() end
            return
        end
        local dst = escape_to(me)
        if not dst then return stop() end
        local dx, dy = dst.x - mine.x, dst.y - mine.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 1 then return stop() end
        local r = math.min(d, Ability.GetCastRange(a) - 25)
        Ability.CastPosition(a, Vector(mine.x + dx / d * r, mine.y + dy / d * r, mine.z))
        stop()
    elseif step == 21 then
        local a = dagger(me)
        local dx, dy = his.x - mine.x, his.y - mine.y
        local d = math.sqrt(dx * dx + dy * dy)
        if a and d > 150 then
            local r = math.min(d - 100, Ability.GetCastRange(a) - 25)
            Ability.CastPosition(a, Vector(mine.x + dx / d * r, mine.y + dy / d * r, mine.z))
            pause(0.2)
        end
        step = 22
    elseif step == 22 then
        hex(me)
        step = 23
    elseif step == 23 then
        local a = spell(me, "techies_suicide", "Blast Off")
        if a then
            Ability.CastPosition(a, lead(his, Ability.GetCastPoint(a) + 0.4,
                Ability.GetLevelSpecialValueFor(a, "radius")))
            swing(a)
        end
        step = 24
    elseif step == 24 then
        bomb(me, his)
        step = 25
    elseif step == 25 then
        tazer(me)
        step = 9
    elseif step == 26 then
        blast_tazer(me)
        step = 10
    end
end

function script.OnGameEnd()
    stop()
    fountain = nil
end

for group, widgets in pairs({
    Main = { "Improved Combo" },
    ["Hero Settings"] = { "Detonate Reactive Tazer", "combo.hold" },
    ["Item Settings"] = { "Items Usage", "Break Linken's", "Use Refresher",
                          "combo.usage", "combo.linken", "combo.refresher" },
    ["combo.hero"] = { "combo.enable", "combo.key", "combo.abilities", "combo.detonate" },
    ["combo.items"] = { "combo.usage", "combo.linken", "combo.refresher" },
}) do
    for _, w in ipairs(widgets) do
        local old = Menu.Find("Heroes", "Hero List", "Techies", "Combo+", group, w)
        if old then old:Visible(false) end
    end
end

return script
