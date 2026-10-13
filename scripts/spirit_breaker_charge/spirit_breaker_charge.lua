---@diagnostic disable: undefined-global

local script = {}

local localization = qLocalization.new({
    en = {
        menu = {
            main = "Charge Combo",
            enabled = "Enabled",
            enabled_tip = "Works by itself while Charge of Darkness is running — cast Charge as usual",
            pre = "Before Charge",
            pre_tip = "On your Charge order: Swift Blink in place and Disperser on yourself, then Charge on the same target",
            boosts = "Boosts during the charge",
            boosts_tip = "Each boost is cast so that its buff lasts until the hit; with a short cooldown it is used twice.",
            impact = "Before the hit",
            impact_tip = "BKB, Blade Mail and Shiva in the hit window. Silver Edge / Shadow Blade as soon as nothing else is waiting — any cast after them would break the invisibility",
            window = "Hit window",
            window_tip = "How long before the hit BKB, Blade Mail and Shiva are used",
            margin = "Buff left at the hit",
            margin_tip = "How many seconds of each boost should still remain when you hit. Raise it if buffs still run out before the hit",
            after = "After the hit",
            after_tip = "Debuffs right after the hit. Nether Strike, Hex, Abyssal Blade and Rod of Atos each land as the previous stun ends",
            show_eta = "Show time to hit",
            show_eta_tip = "Estimated seconds until the hit above the Charge target",
        },
        panel = {
            menu_failed = "Spirit Breaker Charge Combo: menu failed",
        },
    },
    ru = {
        menu = {
            main = "Комбо в разгоне",
            enabled = "Включить",
            enabled_tip = "Работает само, пока идёт Charge of Darkness — жми чардж как обычно",
            pre = "Перед чарджем",
            pre_tip = "При нажатии чарджа: Swift Blink под себя и Disperser на себя, затем чардж на ту же цель",
            boosts = "Бусты в разгоне",
            boosts_tip = "Каждый буст жмётся так, чтобы бафф дожил до удара; при коротком кулдауне — дважды.",
            impact = "До удара",
            impact_tip = "BKB, Blade Mail и Shiva — в окне перед ударом. Silver Edge / Shadow Blade — как только больше нечего жать: любой каст после них сбил бы инвиз",
            window = "Окно перед ударом",
            window_tip = "За сколько до удара жмутся BKB, Blade Mail и Shiva",
            margin = "Запас баффа к удару",
            margin_tip = "Сколько секунд каждого буста должно остаться в момент удара. Увеличь, если бафф всё ещё проходит до удара",
            after = "После удара",
            after_tip = "Дебаффы сразу после удара. Nether Strike, Hex, Abyssal Blade и Rod of Atos — каждый ровно к концу предыдущего стана",
            show_eta = "Показывать время до удара",
            show_eta_tip = "Примерное время до столкновения над целью чарджа",
        },
        panel = {
            menu_failed = "Spirit Breaker Charge Combo: меню не создалось",
        },
    },
    cn = {
        menu = {
            main = "冲刺连招",
            enabled = "启用",
            enabled_tip = "暗影冲刺期间自动生效——照常释放冲刺即可",
            pre = "冲刺前",
            pre_tip = "释放冲刺时：先原地使用迅疾闪光并对自己使用散魔之刃，再对同一目标冲刺",
            boosts = "冲刺中的加速",
            boosts_tip = "每个加速在合适时机使用，使增益持续到撞击；冷却短时使用两次",
            impact = "撞击前",
            impact_tip = "BKB、刃甲和希瓦在撞击窗口内使用。银月之晶/隐刀在没有其他待用物品时立即使用——之后的任何施法都会打破隐身",
            window = "撞击窗口",
            window_tip = "撞击前多少秒使用BKB、刃甲和希瓦",
            margin = "撞击时剩余增益",
            margin_tip = "撞击时每个加速增益应剩余的秒数。如果增益仍在撞击前结束，请调高",
            after = "撞击后",
            after_tip = "撞击后立即施加减益。虚无打击、妖术、深渊之刃和阿托斯之棍在上一个眩晕结束时依次生效",
            show_eta = "显示撞击倒计时",
            show_eta_tip = "在冲刺目标上方显示预计撞击倒计时",
        },
        panel = {
            menu_failed = "Spirit Breaker Charge Combo: 菜单创建失败",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local HERO = "npc_dota_hero_spirit_breaker"
local CHARGE = "modifier_spirit_breaker_charge_of_darkness"
local CHARGE_ABILITY = "spirit_breaker_charge_of_darkness"
local CHARGE_MARKS = { "modifier_spirit_breaker_charge_of_darkness_target", "modifier_spirit_breaker_charge_of_darkness_vision" }
local INVIS_BUFFS = { "modifier_item_silver_edge_windwalk", "modifier_item_invisibility_edge_windwalk" }
local CONTACT = 100
local ORDER_GAP = 0.08
local RESEND = 0.5
local TRACK_STEP = 0.2
local MIN_CLOSING = 0.25
local POST_RANGE = 350
local POST_LEASH = 1200
local POST_TIME = 6
local POST_SETTLE = 0.15
local INVIS_WAIT = 1.0
local LAND_WAIT = 0.35
local PING = 0.1
local RANGE_SLACK = 50
local TEMPEST_DOUBLE = "modifier_arc_warden_tempest_double"
local PENDING_TIMEOUT = 1.5
local STEP_WAIT = 0.25

local PRE = {
    { name = "item_swift_blink", point = true },
    { name = "item_disperser" },
}

local BOOSTS = {
    { name = "spirit_breaker_bulldoze", ability = true, buff = "modifier_spirit_breaker_bulldoze", duration = 8 },
    { name = "item_phase_boots", buff = "modifier_item_phase_boots_active", duration = 3 },
    { name = "item_boots_of_bearing", buff = "modifier_item_boots_of_bearing_active", duration = 6 },
    { name = "item_ancient_janggo", buff = "modifier_item_ancient_janggo_active", duration = 6 },
    { name = "item_spider_legs", buff = "modifier_item_spider_legs_active", duration = 12 },
    { name = "item_kobold_cup", buff = "modifier_item_kobold_cup", duration = 6 },
    { name = "item_mask_of_madness", buff = "modifier_item_mask_of_madness_berserk", duration = 6 },
}

local IMPACT = {
    { name = "item_black_king_bar" },
    { name = "item_blade_mail" },
    { name = "item_shivas_guard" },
    { name = "item_silver_edge", invis = true },
    { name = "item_invis_sword", invis = true },
}

local AFTER = {
    { name = "spirit_breaker_nether_strike", ability = true, chain = true, lead = 1.0 },
    { name = "item_sheepstick", chain = true, lead = 0 },
    { name = "item_abyssal_blade", chain = true, lead = 0 },
    { name = "item_rod_of_atos", chain = true, lead = 0.1 },
    { name = "item_bloodthorn" },
    { name = "item_orchid" },
    { name = "item_nullifier" },
    { name = "item_heavens_halberd" },
    { name = "item_diffusal_blade" },
    { name = "item_spirit_vessel", charges = true },
    { name = "item_urn_of_shadows", charges = true },
}

local HAS_ENUM = type(Enum) == "table"
local CAST_READY = HAS_ENUM and type(Enum.AbilityCastResult) == "table" and Enum.AbilityCastResult.READY or -1
local STATES = HAS_ENUM and type(Enum.ModifierState) == "table" and Enum.ModifierState or {}
local STATE_STUN = STATES.MODIFIER_STATE_STUNNED or 5
local STATE_HEX = STATES.MODIFIER_STATE_HEXED or 6

local ui = {}
local ready = false
local g_menu_error = nil
local S = { charging = false, nextOrder = 0, sent = {}, invisDone = false, error = nil, font = nil, orderTarget = nil, etaTarget = nil, eta = nil, track = nil, trackX = 0, trackY = 0, trackTime = 0, away = 0, post = nil, pending = nil }

local function log(level, message, data)
    if type(ai_bridge) ~= "table" or type(ai_bridge.mcp_log) ~= "function" then return end
    pcall(ai_bridge.mcp_log, level, message, data)
end

local function icon(entry)
    if entry.ability then return "panorama/images/spellicons/" .. entry.name .. "_png.vtex_c" end
    return "panorama/images/items/" .. entry.name:gsub("^item_", "") .. "_png.vtex_c"
end

local function rows(list)
    local out = {}
    for i, entry in ipairs(list) do out[i] = { entry.name, icon(entry), true } end
    return out
end

local function seconds(v)
    return string.format("%.1f s", v / 10)
end

local function initialize_menu()
    local side = (HAS_ENUM and Enum.GroupSide) or {}
    local section = Menu.Create("Heroes", "Hero List", "Spirit Breaker", "Charge Combo")
    local group = section:Create("menu.main", side.Left)

    ui.enabled = group:Switch("menu.enabled", true, "\u{f0e7}")
    ui.enabled:ToolTip("menu.enabled_tip")
    ui.pre = group:MultiSelect("menu.pre", rows(PRE), true)
    ui.pre:ToolTip("menu.pre_tip")
    ui.boosts = group:MultiSelect("menu.boosts", rows(BOOSTS), true)
    ui.boosts:ToolTip("menu.boosts_tip")
    ui.impact = group:MultiSelect("menu.impact", rows(IMPACT), true)
    ui.impact:ToolTip("menu.impact_tip")
    ui.after = group:MultiSelect("menu.after", rows(AFTER), true)
    ui.after:ToolTip("menu.after_tip")
    ui.margin = group:Slider("menu.margin", 0, 30, 10, seconds)
    ui.margin:ToolTip("menu.margin_tip")
    ui.window = group:Slider("menu.window", 1, 15, 6, seconds)
    ui.window:ToolTip("menu.window_tip")
    ui.showEta = group:Switch("menu.show_eta", true, "\u{f017}")
    ui.showEta:ToolTip("menu.show_eta_tip")
    return true
end

local function reset()
    S.charging = false
    S.nextOrder = 0
    S.sent = {}
    S.invisDone = false
    S.eta = nil
    S.etaTarget = nil
    S.track = nil
    S.loggedTarget = nil
end

local function has_any(npc, names)
    for _, name in ipairs(names) do
        if NPC.HasModifier(npc, name) then return true end
    end
    return false
end

local function real_hero(unit)
    if unit == nil or not Entity.IsHero(unit) then return false end
    return not NPC.IsIllusion(unit) or NPC.HasModifier(unit, TEMPEST_DOUBLE)
end

local function charge_target(hero, origin)
    local best, bestDist
    for _, h in ipairs(Heroes.GetAll()) do
        if not Entity.IsSameTeam(hero, h) and Entity.IsAlive(h) and real_hero(h) and has_any(h, CHARGE_MARKS) then
            local d = (Entity.GetAbsOrigin(h) - origin):Length()
            if bestDist == nil or d < bestDist then best, bestDist = h, d end
        end
    end
    local t = S.orderTarget
    if best == nil and t ~= nil and Entity.IsAlive(t) then
        best, bestDist = t, (Entity.GetAbsOrigin(t) - origin):Length()
    end
    return best, bestDist
end

local function away_speed(target, tpos, origin, now)
    if Entity.IsDormant(target) then return NPC.GetMoveSpeed(target) end
    if S.track ~= target then
        S.track, S.trackX, S.trackY, S.trackTime, S.away = target, tpos.x, tpos.y, now, 0
        return 0
    end
    local dt = now - S.trackTime
    if dt >= TRACK_STEP then
        local len = math.max(math.sqrt((tpos.x - origin.x) ^ 2 + (tpos.y - origin.y) ^ 2), 1)
        local moved = (tpos.x - S.trackX) * (tpos.x - origin.x) + (tpos.y - S.trackY) * (tpos.y - origin.y)
        S.away = math.max(moved / len / dt, 0)
        S.trackX, S.trackY, S.trackTime = tpos.x, tpos.y, now
    end
    return S.away
end

local function has_bit(mask, bit)
    local p = 1
    for _ = 1, bit do p = p * 2 end
    return mask % (p * 2) >= p
end

local function disable_left(target, now)
    local left = 0
    for _, mod in ipairs(NPC.GetModifiers(target)) do
        local on = Modifier.GetState(mod)
        if type(on) == "number" and (has_bit(on, STATE_STUN) or has_bit(on, STATE_HEX)) then
            left = math.max(left, Modifier.GetDieTime(mod) - now)
        end
    end
    return left
end

local function handle_for(hero, entry)
    if entry.ability then return NPC.GetAbility(hero, entry.name) end
    return NPC.GetItem(hero, entry.name, true)
end

local function castable(h)
    return h ~= nil and Ability.GetLevel(h) > 0 and Ability.IsReady(h) and Ability.CanBeExecuted(h) == CAST_READY
end

local function boost_due(entry, h, eta, margin)
    if eta == nil then return true end
    local lead = eta - math.max(entry.duration - margin, 0)
    if lead <= 0 then return true end
    local cd = Ability.GetCooldownLength(h)
    return type(cd) == "number" and cd > 0 and lead >= cd
end

local function fresh(entry, now)
    return now - (S.sent[entry.name] or -RESEND) >= RESEND
end

local function pick(hero, eta, now)
    local margin = ui.margin:Get() / 10
    local waiting = false
    for _, entry in ipairs(BOOSTS) do
        if ui.boosts:Get(entry.name) and fresh(entry, now) and not NPC.HasModifier(hero, entry.buff) then
            local h = handle_for(hero, entry)
            if castable(h) then
                if boost_due(entry, h, eta, margin) then return entry, h end
                waiting = true
            end
        end
    end
    local inWindow = eta ~= nil and eta <= ui.window:Get() / 10
    for _, entry in ipairs(IMPACT) do
        if not entry.invis and ui.impact:Get(entry.name) and fresh(entry, now) then
            local h = handle_for(hero, entry)
            if castable(h) then
                if inWindow then return entry, h end
                waiting = true
            end
        end
    end
    if waiting then return nil end
    for _, entry in ipairs(IMPACT) do
        if entry.invis and ui.impact:Get(entry.name) and fresh(entry, now) then
            local h = handle_for(hero, entry)
            if castable(h) then return entry, h end
        end
    end
    return nil
end

local function pick_after(hero, dist, left, sent)
    local bonus = NPC.GetCastRangeBonus(hero)
    for pass = 1, 2 do
        for _, entry in ipairs(AFTER) do
            if (pass == 2) == (entry.chain == true) and not sent[entry.name] and ui.after:Get(entry.name) then
                local h = handle_for(hero, entry)
                if castable(h) and dist <= Ability.GetCastRange(h) + bonus + RANGE_SLACK
                    and (not entry.charges or Item.GetCurrentCharges(h) > 0)
                    and (pass == 1 or left <= entry.lead + PING) then
                    return entry, h
                end
            end
        end
    end
    return nil
end

local function start_post(hero, now)
    local t = S.etaTarget
    if t == nil or not Entity.IsAlive(t) then return end
    local dist = (Entity.GetAbsOrigin(t) - Entity.GetAbsOrigin(hero)):Length()
    if dist > POST_RANGE then return end
    S.post = { target = t, start = now, stop = now + POST_TIME, wait = now + POST_SETTLE, sent = {} }
    log("info", "charge hit", { dist = dist })
end

local function update_post(hero, now)
    local p = S.post
    local t = p.target
    if now > p.stop or not Entity.IsAlive(t) or Entity.IsDormant(t) then
        S.post = nil
        return
    end
    if now < p.wait then return end
    if has_any(hero, INVIS_BUFFS) and now - p.start < INVIS_WAIT then return end

    local dist = (Entity.GetAbsOrigin(t) - Entity.GetAbsOrigin(hero)):Length()
    if dist > POST_LEASH then
        S.post = nil
        return
    end
    local left = disable_left(t, now)
    local entry, h = pick_after(hero, dist, left, p.sent)
    if entry == nil then return end

    Ability.CastTarget(h, t)
    p.sent[entry.name] = true
    p.wait = now + (entry.chain and entry.lead + LAND_WAIT or ORDER_GAP)
    log("info", "after hit " .. entry.name, { disable_left = left, dist = dist })
end

local function run_pending(hero, now)
    local p = S.pending
    if now > p.stop or not Entity.IsAlive(p.target) then
        S.pending = nil
        log("info", "pre-charge dropped")
        return
    end
    local step = p.steps[p.i]
    if step == nil then
        S.pending = nil
        if castable(p.charge) then Ability.CastTarget(p.charge, p.target) end
        log("info", "pre-charge done, charge sent")
        return
    end
    if p.sentAt == nil then
        if not castable(step.h) then
            p.i = p.i + 1
            return
        end
        if step.entry.point then
            Ability.CastPosition(step.h, Entity.GetAbsOrigin(hero))
        else
            Ability.CastTarget(step.h, hero)
        end
        p.sentAt = now
    elseif not Ability.IsReady(step.h) or now - p.sentAt > STEP_WAIT then
        p.i, p.sentAt = p.i + 1, nil
    end
end

local function update()
    local hero = Heroes.GetLocal()
    if hero == nil or NPC.GetUnitName(hero) ~= HERO or not Entity.IsAlive(hero) then
        reset()
        S.post = nil
        S.pending = nil
        return
    end

    local now = GameRules.GetGameTime()
    if S.pending ~= nil then
        run_pending(hero, now)
        return
    end
    if not NPC.HasModifier(hero, CHARGE) then
        if S.charging then
            log("info", "charge ended")
            start_post(hero, now)
            reset()
        end
        if S.post ~= nil then update_post(hero, now) end
        return
    end

    if not S.charging then
        S.charging = true
        S.post = nil
    end
    local origin = Entity.GetAbsOrigin(hero)
    local target, dist = charge_target(hero, origin)
    if S.loggedTarget ~= target then
        S.loggedTarget = target
        log("info", "charge target", { target = target and Entity.GetIndex(target), dist = dist, order_target = S.orderTarget and Entity.GetIndex(S.orderTarget) })
    end
    S.etaTarget = target
    S.eta = nil
    if target == nil then return end
    local speed = math.max(NPC.GetMoveSpeed(hero), 100)
    local away = away_speed(target, Entity.GetAbsOrigin(target), origin, now)
    local eta = math.max(dist - CONTACT, 0) / math.max(speed - away, speed * MIN_CLOSING)
    S.eta = eta
    if S.invisDone or now < S.nextOrder or has_any(hero, INVIS_BUFFS) then return end

    local entry, h = pick(hero, eta, now)
    if entry == nil then return end

    Ability.CastNoTarget(h)
    S.sent[entry.name] = now
    S.nextOrder = now + ORDER_GAP
    if entry.invis then S.invisDone = true end
    log("info", "cast " .. entry.name, { eta = eta, dist = dist, speed = NPC.GetMoveSpeed(hero) })
end

local function before_charge(data)
    local hero = Heroes.GetLocal()
    if hero == nil or (data.npc ~= nil and data.npc ~= hero) or NPC.GetUnitName(hero) ~= HERO then return true end
    if data.target == nil or data.ability == nil or Ability.GetName(data.ability) ~= CHARGE_ABILITY then return true end
    S.orderTarget = real_hero(data.target) and not Entity.IsSameTeam(hero, data.target) and data.target or nil
    log("info", "charge order", { target = Entity.GetIndex(data.target), hero = Entity.IsHero(data.target), illusion = NPC.IsIllusion(data.target), tempest = NPC.HasModifier(data.target, TEMPEST_DOUBLE), accepted = S.orderTarget ~= nil, queue = data.queue, issuer = data.orderIssuer })
    if S.orderTarget == nil or data.queue or NPC.HasModifier(hero, CHARGE) or not castable(data.ability) then return true end
    if NPC.HasModifier(data.target, TEMPEST_DOUBLE) then return true end
    if S.pending ~= nil then
        S.pending.target = data.target
        return false
    end

    local steps = {}
    for _, entry in ipairs(PRE) do
        local h = ui.pre:Get(entry.name) and NPC.GetItem(hero, entry.name, true) or nil
        if castable(h) then steps[#steps + 1] = { entry = entry, h = h } end
    end
    if #steps == 0 then return true end

    S.pending = { steps = steps, i = 1, sentAt = nil, charge = data.ability, target = data.target, stop = GameRules.GetGameTime() + PENDING_TIMEOUT }
    log("info", "pre-charge queued", { count = #steps })
    return false
end

function script.OnPrepareUnitOrders(data)
    if not ready or not ui.enabled:Get() then return true end
    local ok, pass = pcall(before_charge, data)
    if not ok then
        S.error = tostring(pass)
        return true
    end
    return pass
end

function script.OnScriptsLoaded()
    local ok, res = pcall(initialize_menu)
    ready = ok and res == true
    if not ready then g_menu_error = ok and "initialize_menu returned false" or tostring(res) end
    S.font = Render.LoadFont("Arial", 0, 500)
    log("info", "spirit_breaker_charge loaded", { menu_ready = ready, error = g_menu_error })
end

function script.OnUpdate()
    if not ready or not ui.enabled:Get() or not Engine.IsInGame() then return end
    local ok, err = pcall(update)
    if not ok then
        reset()
        S.post = nil
        S.pending = nil
        if S.error == nil then log("error", "update failed", { error = tostring(err) }) end
        S.error = tostring(err)
    end
end

function script.OnGameEnd()
    reset()
    S.error = nil
    S.orderTarget = nil
    S.post = nil
    S.pending = nil
end

local function draw_error_banner()
    local title = g_menu_error and localization.Get("panel.menu_failed") or "Spirit Breaker Charge Combo"
    local msg = g_menu_error or S.error
    Render.FilledRect(Vec2(20, 400), Vec2(760, 446), Color(20, 20, 24, 235), 4)
    Render.Text(S.font, 14, title, Vec2(30, 406), Color(224, 50, 45, 245))
    Render.Text(S.font, 12, msg:sub(1, 150), Vec2(30, 426), Color(220, 220, 225, 240))
end

local function draw_eta()
    local target = S.etaTarget
    if target == nil or not Entity.IsAlive(target) then return end
    local pos, visible = Render.WorldToScreen(Entity.GetAbsOrigin(target))
    if not visible then return end
    local text = S.eta and string.format("%.1f s", S.eta) or "?"
    Render.Text(S.font, 18, text, Vec2(pos.x - 14, pos.y - 150), Color(255, 214, 51, 245))
end

function script.OnDraw()
    if g_menu_error ~= nil or S.error ~= nil then pcall(draw_error_banner) end
    if ready and S.charging and ui.showEta:Get() then
        local ok, err = pcall(draw_eta)
        if not ok then S.error = tostring(err) end
    end
end

return script
