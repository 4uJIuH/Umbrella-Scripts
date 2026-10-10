local DORMAN_HERO_NAME = "hero_doorman"
local COMBO_TARGET_RANGE = 1200
local COMBO_TARGET_FOV = 35
local SKILL3_CONFIRM_DELAY = 0.08
local SKILL3_CONFIRM_TIMEOUT = 1.10
local ULTIMATE_DURATION = 8.5
local SKILL1_FEET_OFFSET = 8
local SKILL2_PREWALL_TIMEOUT = 2.00
local SKILL2_RETRY_INTERVAL = 0.08
local SKILL2_DIRECTION_DELAY = 0.05
local WALL_SEARCH_DISTANCE = 2000
local WALL_DOORWAY_BACK_OFFSET = 0
local DOORWAY_TANGENTIAL_FRACTION = 1.0
local DOORWAY_GEOMETRY_FALLBACK = 100
local TRACKING_INTERVAL = 0.03
local ABILITY_BUTTONS = {
    [0] = InputBitMask_t.IN_ABILITY1,
    [1] = InputBitMask_t.IN_ABILITY2,
    [2] = InputBitMask_t.IN_ABILITY3,
    [3] = InputBitMask_t.IN_ABILITY4,
}

local localization = qLocalization.new({
    en = {
        dorman = {
            general = "General",
            skill1 = "Skill 1",
            skill3 = "Skill 3",
            ultimate = "Ultimate",
            enable = "Enable",
            skill1_aim = "Aim Skill 1",
            cart_door = "Cart into Door",
            ultimate_combo = "Ultimate Combo",
        },
    },
    ru = {
        dorman = {
            general = "Общие",
            skill1 = "1-й скилл",
            skill3 = "3-й скилл",
            ultimate = "Ультимейт",
            enable = "Включить",
            skill1_aim = "Аим 1-го скилла",
            cart_door = "Тележка в дверь",
            ultimate_combo = "Комбо Ултимейт",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local function get_or_create_menu(group_name)
    local menu = Menu.Find(
        "Heroes",
        "Hero List",
        DORMAN_HERO_NAME,
        "Dorman",
        group_name
    )
    if not menu then
        menu = Menu.Create(
            "Heroes",
            "Hero List",
            DORMAN_HERO_NAME,
            "Dorman",
            group_name
        )
    end
    return menu
end

local menu_general = get_or_create_menu("dorman.general")
local menu_skill1 = get_or_create_menu("dorman.skill1")
local menu_skill3 = get_or_create_menu("dorman.skill3")
local menu_ultimate = get_or_create_menu("dorman.ultimate")

local enabled = menu_general:Switch("dorman.enable", true)
local skill1_key = menu_skill1:Bind("dorman.skill1_aim", Enum.ButtonCode.KEY_NONE)
local cart_door_key = menu_skill3:Bind("dorman.cart_door", Enum.ButtonCode.KEY_NONE)
local ultimate_combo_key = menu_ultimate:Bind("dorman.ultimate_combo", Enum.ButtonCode.KEY_NONE)

local state = {
    phase = 0,
    combo_mode = nil,
    target = nil,
    ultimate_deadline = 0,
    skill3 = nil,
    skill3_cast_time = 0,
    skill3_retry_deadline = 0,
    skill3_retry_target = nil,
    skill2_deadline = 0,
    skill2_next_attempt = 0,
    skill2_dispatch_pending = false,
    skill2_dispatch_time = 0,
    skill2_confirmed = false,
    skill2_cast_position = nil,
    skill2_push_direction = nil,
    skill2_dynamic_position = nil,
    skill2_dynamic_direction = nil,
    last_sample_time = 0,
    last_target_position = nil,
    target_velocity = Vector(0, 0, 0),
    skill3_hit_modifier = false,
    skill3_hit_position = nil,
    skill3_hit_velocity = nil,
    skill3_hit_time = 0,
    skill2_ability = nil,
}

local function safe_name(ent)
    if not ent then return "nil" end
    local ok, value = pcall(function() return ent:get_name() end)
    return ok and tostring(value) or "<name-error>"
end

local function vector_length(value)
    return math.sqrt(value.x * value.x + value.y * value.y + value.z * value.z)
end

local function vector_sub(left, right)
    return Vector(left.x - right.x, left.y - right.y, left.z - right.z)
end

local function vector_add(left, right)
    return Vector(left.x + right.x, left.y + right.y, left.z + right.z)
end

local function vector_scale(value, scale)
    return Vector(value.x * scale, value.y * scale, value.z * scale)
end

local function trace_wall(start_pos, direction)
    local flat = Vector(direction.x, direction.y, 0)
    local length = vector_length(flat)
    if length <= 0.1 then return nil end
    flat = vector_scale(flat, 1 / length)

    local start = Vector(start_pos.x, start_pos.y, start_pos.z + 20)
    local finish = Vector(
        start.x + flat.x * WALL_SEARCH_DISTANCE,
        start.y + flat.y * WALL_SEARCH_DISTANCE,
        start.z
    )
    local ok, result = pcall(function()
        return trace.line(start, finish, 0, 0, 0, 0x1C1003, 0, function()
            return false
        end)
    end)
    if not ok or not result then return nil end
    if not result.fraction or result.fraction >= 0.99 then return nil end

    local hit = Vector(
        start.x + (finish.x - start.x) * result.fraction,
        start.y + (finish.y - start.y) * result.fraction,
        start.z + (finish.z - start.z) * result.fraction
    )
    hit = vector_sub(hit, vector_scale(flat, WALL_DOORWAY_BACK_OFFSET))
    local normal = result.normal
    if normal then
        hit = vector_sub(hit, vector_scale(normal, 18))
    end
    return hit
end

local function valid_entity(ent)
    return ent and ent:valid() and ent:is_alive()
end

local function local_pawn()
    local pawn = entity_list.local_pawn()
    if valid_entity(pawn) and pawn:get_name() == DORMAN_HERO_NAME then
        return pawn
    end
    return nil
end

local function find_target(pawn)
    local camera_position = utils.get_camera_pos()
    local camera_angles = utils.get_camera_angles()
    local best_target = nil
    local best_fov = COMBO_TARGET_FOV

    for _, candidate in pairs(entity_list.by_class_name("C_CitadelPlayerPawn") or {}) do
        if valid_entity(candidate)
            and candidate.m_iTeamNum ~= pawn.m_iTeamNum
            and not candidate:has_modifier_state(19)
        then
            local position = candidate:get_bone_pos("spine_2") or candidate:get_origin()
            if position then
                local distance = vector_length(vector_sub(position, camera_position))
                if distance <= COMBO_TARGET_RANGE then
                    local aim_angle = utils.calc_angle(camera_position, position)
                    local fov = utils.get_fov(camera_angles, aim_angle)
                    if fov < best_fov then
                        best_fov = fov
                        best_target = candidate
                    end
                end
            end
        end
    end

    return best_target
end

local function reset_state()
    state.phase = 0
    state.combo_mode = nil
    state.target = nil
    state.ultimate_deadline = 0
    state.skill3 = nil
    state.skill3_cast_time = 0
    state.skill3_retry_deadline = 0
    state.skill3_retry_target = nil
    state.skill2_deadline = 0
    state.skill2_next_attempt = 0
    state.skill2_dispatch_pending = false
    state.skill2_dispatch_time = 0
    state.skill2_confirmed = false
    state.skill2_cast_position = nil
    state.skill2_push_direction = nil
    state.skill2_dynamic_position = nil
    state.skill2_dynamic_direction = nil
    state.last_target_position = nil
    state.target_velocity = Vector(0, 0, 0)
    state.skill3_hit_modifier = false
    state.skill3_hit_position = nil
    state.skill3_hit_velocity = nil
    state.skill3_hit_time = 0
    state.skill2_ability = nil
end

local function update_target_velocity(target, now)
    if not valid_entity(target) then return end
    if not state.last_target_position then
        state.last_target_position = target:get_origin()
        state.last_sample_time = now
        return
    end

    local elapsed = now - state.last_sample_time
    if elapsed < TRACKING_INTERVAL then return end

    local position = target:get_origin()
    state.target_velocity = vector_scale(vector_sub(position, state.last_target_position), 1 / elapsed)
    state.last_target_position = position
    state.last_sample_time = now
end

local function aim_at(cmd, position)
    if cmd:can_psilent_at_pos(position) then
        cmd:set_psilent_at_pos(position)
        return
    end

    local angle = utils.calc_angle(utils.get_camera_pos(), position)
    if angle then cmd.ang_camera_angles = angle end
end

local function get_skill1_aim_position(target)
    local origin = target:get_origin()
    if not origin then return nil end
    return Vector(origin.x, origin.y, origin.z + SKILL1_FEET_OFFSET)
end

local function execute_skill(cmd, pawn, slot, force)
    local ability = pawn:get_ability_by_slot(slot)
    if not ability or not ability:valid() then return nil end
    local execution_state = ability:can_be_executed()
    local cooldown = ability:get_cooldown() or -1

    local allowed = execution_state == 0 or cooldown <= 0.05
    if force and cooldown > 0.05 then
        return nil
    end
    if not allowed and not force then
        return nil
    end
    if execution_state ~= 0 and execution_state ~= 23 and not force then
        return nil
    end
    cmd.execute_ability_indices = (cmd.execute_ability_indices or 0) | (1 << slot)
    local ability_button = ABILITY_BUTTONS[slot]
    if ability_button then
        cmd:add_buttonstate1(ability_button)
        cmd:add_buttonstate2(ability_button)
        pcall(function() cmd:add_buttonstate3(ability_button) end)
        if cmd.set_input then
            pcall(function() cmd:set_input(ability_button, 1) end)
        end
    end
    return ability
end

local function target_was_hit()
    if not valid_entity(state.target) or not state.skill3 then return false end
    local engine_target = state.skill3:get_target()
    if engine_target == state.target then
        return true
    end
    if state.skill3_hit_modifier then
        return true
    end
    return false
end

local function target_is_ulting(target)
    if not valid_entity(target) then return false end
    local ok, result = pcall(function()
        return target:has_modifier_state(286)
    end)
    return ok and result == true
end

local function prepare_skill2_wall(pawn)
    if not valid_entity(state.target) then
        return nil
    end

    local target_position = state.target:get_origin()
    if not state.skill2_cast_position then
        local movement_direction = state.skill3_hit_velocity
        if not movement_direction then
            return nil
        end
        target_position = vector_add(
            state.skill3_hit_position,
            vector_scale(movement_direction, SKILL2_DIRECTION_DELAY)
        )
        local push_direction = vector_length(movement_direction) > 80
            and movement_direction
            or vector_sub(target_position, pawn:get_origin())
        local cast_position = trace_wall(target_position, push_direction)
        if not cast_position then
            return nil
        end
        state.skill2_cast_position = cast_position
        state.skill2_push_direction = push_direction
    end

    local current_position = state.target:get_origin() or target_position
    local current_velocity = state.target_velocity
    local engine_velocity = nil
    pcall(function()
        engine_velocity = state.target:get_velocity()
    end)
    if engine_velocity and vector_length(engine_velocity) > 80 then
        current_velocity = engine_velocity
    end
    local velocity_length = vector_length(current_velocity)
    local wall_delta = vector_sub(state.skill2_cast_position, current_position)
    local distance_to_wall = vector_length(wall_delta)
    local moving_toward_wall = false
    if velocity_length > 80 and distance_to_wall > 0.1 then
        local velocity_direction = vector_scale(current_velocity, 1 / velocity_length)
        local wall_direction = vector_scale(wall_delta, 1 / distance_to_wall)
        moving_toward_wall = velocity_direction.x * wall_direction.x
            + velocity_direction.y * wall_direction.y > 0.15
    end

    -- Re-trace the current trajectory so the doorway follows the actual
    -- post-impact movement instead of the stale third-skill snapshot.
    if moving_toward_wall then
        local dynamic_position = trace_wall(current_position, current_velocity)
        if dynamic_position then
            state.skill2_dynamic_position = dynamic_position
            state.skill2_dynamic_direction = current_velocity
            wall_delta = vector_sub(dynamic_position, current_position)
            distance_to_wall = vector_length(wall_delta)
        end
    else
        state.skill2_dynamic_position = nil
        state.skill2_dynamic_direction = nil
    end

    return true
end

local function cast_skill2_before_wall(cmd, pawn)
    if not prepare_skill2_wall(pawn) then
        return false
    end
    local aim_position = state.skill2_dynamic_position or state.skill2_cast_position
    local push_direction = state.skill2_dynamic_direction or state.skill2_push_direction
    local tangential_offset = 0
    local skill2_ability = state.skill2_ability or pawn:get_ability_by_slot(1)
    if skill2_ability then
        local ok, radius = pcall(function()
            return skill2_ability:get_aoe_radius()
        end)
        if ok and radius and radius > 0 then
            tangential_offset = radius * DOORWAY_TANGENTIAL_FRACTION
        end
        if tangential_offset <= 0 then
            local property_names = {
                "DoorwayWidth",
                "DoorwayLength",
                "AbilityDoorwayWidth",
                "AbilityDoorwayLength",
            }
            for _, property_name in ipairs(property_names) do
                local property_ok, property_value = pcall(function()
                    return skill2_ability:get_scaled_property(property_name)
                end)
                if property_ok and property_value and property_value > 0 then
                    tangential_offset = property_value * 0.5
                    break
                end
            end
        end
    end
    if tangential_offset <= 0 then
        local direction = push_direction
        if direction and math.abs(direction.x) + math.abs(direction.y) > 0.1 then
            -- The doorway VData exposes no usable radius. This bounded
            -- geometry fallback compensates the fixed doorway anchor offset.
            tangential_offset = DOORWAY_GEOMETRY_FALLBACK
        end
    end
    if push_direction and tangential_offset > 0 then
        local flat_length = math.sqrt(
            push_direction.x * push_direction.x
                + push_direction.y * push_direction.y
        )
        if flat_length > 0.1 then
            local tangent = Vector(
                -push_direction.y / flat_length,
                push_direction.x / flat_length,
                0
            )
            aim_position = vector_add(
                aim_position,
                vector_scale(tangent, tangential_offset)
            )
        end
    end
    aim_at(cmd, aim_position)
    local dispatched = execute_skill(cmd, pawn, 1, true) ~= nil
    if dispatched then
        state.skill2_dispatch_pending = true
        state.skill2_dispatch_time = global_vars.curtime()
    end
    return dispatched
end

callback.on_pre_createmove:set(function(cmd)
    local pawn = local_pawn()
    if not enabled:Get() or not pawn then
        reset_state()
        return
    end

    local now = global_vars.curtime()
    local requested_combo = nil
    local requested_skill1 = skill1_key:IsPressed()
    if cart_door_key:IsPressed() then requested_combo = "cart_door" end
    if ultimate_combo_key:IsPressed() then requested_combo = "ultimate" end
    update_target_velocity(state.target, now)

    if (requested_combo or requested_skill1) and state.phase ~= 0 then
        reset_state()
    end

    if state.phase == 0 and requested_skill1 then
        local target = find_target(pawn)
        local aim_position = target and get_skill1_aim_position(target)
        if target and aim_position then
            aim_at(cmd, aim_position)
            execute_skill(cmd, pawn, 0)
        end
    elseif state.phase == 0 and requested_combo then
        local target = find_target(pawn)
        local position = target
            and (target:get_bone_pos("spine_2") or target:get_origin())
        if position then
            aim_at(cmd, position)
            if requested_combo == "cart_door" then
                state.skill3 = execute_skill(cmd, pawn, 2)
                if state.skill3 then
                    state.combo_mode = "cart_door"
                    state.target = target
                    state.skill3_cast_time = now
                    state.last_target_position = target:get_origin()
                    state.last_sample_time = now
                    state.phase = 3
                end
            else
                local ultimate = execute_skill(cmd, pawn, 3)
                if ultimate then
                    state.combo_mode = "ultimate"
                    state.target = target
                    state.ultimate_deadline = now + ULTIMATE_DURATION
                    state.phase = 1
                end
            end
        end
    elseif state.phase == 1 and state.combo_mode == "ultimate" then
        if not valid_entity(state.target) then
            reset_state()
            return
        end
        if now < state.ultimate_deadline or target_is_ulting(state.target) then
            return
        end
        state.skill3_retry_target = state.target
        state.skill3_retry_deadline = now + 0.35
        state.phase = 2
    elseif state.phase == 2 then
        local target = state.skill3_retry_target
        if not valid_entity(target) then
            state.skill3_retry_target = nil
            return
        end
        if now < state.ultimate_deadline then
            return
        end
        if target_is_ulting(target) then
            return
        end
        if state.skill3_retry_deadline == 0 then
            state.skill3_retry_deadline = now + 0.35
        elseif state.skill3_retry_deadline <= now then
            reset_state()
            return
        end
        local position = target:get_bone_pos("spine_2") or target:get_origin()
        if position then
            aim_at(cmd, position)
            state.skill3 = execute_skill(cmd, pawn, 2)
            if state.skill3 then
                state.target = target
                state.skill3_retry_deadline = 0
                state.skill3_retry_target = nil
                state.phase = 3
                state.skill3_cast_time = now
                state.last_target_position = target:get_origin()
                state.last_sample_time = now
            end
        end
    elseif state.phase == 3 then
        update_target_velocity(state.target, now)
        if now - state.skill3_cast_time < SKILL3_CONFIRM_DELAY then return end
        if not target_was_hit() then
            if now - state.skill3_cast_time >= SKILL3_CONFIRM_TIMEOUT then
                reset_state()
            end
            return
        end
        state.phase = 4
        state.skill2_deadline = now + SKILL2_PREWALL_TIMEOUT
        state.skill2_next_attempt = now
        state.skill2_ability = pawn:get_ability_by_slot(1)
    elseif state.phase == 4 then
        if now >= state.skill2_deadline then
            reset_state()
            return
        end

        if now < state.skill3_hit_time + SKILL2_DIRECTION_DELAY then return end
        if now < state.skill2_next_attempt then return end
        if state.skill2_confirmed then
            reset_state()
            return
        end
        if state.skill2_dispatch_pending then
            if now - state.skill2_dispatch_time < 0.25 then
                return
            end
            state.skill2_dispatch_pending = false
        end
        state.skill2_next_attempt = now + SKILL2_RETRY_INTERVAL
        cast_skill2_before_wall(cmd, pawn)
    end
end)

callback.on_add_modifier:set(function(modifier, target, owner)
    if state.phase == 0 then return end
    local modifier_name = safe_name(modifier)
    if state.phase == 4
        and modifier_name == "ability_doorman_doorway/doorway_timer_modifier"
        and safe_name(owner) == DORMAN_HERO_NAME
    then
        state.skill2_confirmed = true
        state.skill2_dispatch_pending = false
    end
    if state.phase == 3
        and valid_entity(state.target)
        and target == state.target
        and safe_name(owner) == DORMAN_HERO_NAME
        and string.find(modifier_name, "ability_doorman_luggage_cart/drag", 1, true)
    then
        state.skill3_hit_modifier = true
        state.skill3_hit_position = target:get_origin()
        state.skill3_hit_velocity = Vector(
            state.target_velocity.x,
            state.target_velocity.y,
            state.target_velocity.z
        )
        state.skill3_hit_time = global_vars.curtime()
    end
end)

callback.on_particle_create:set(function(data)
    if state.phase == 2
        and data
        and tostring(data.name) == "particles/abilities/doorman/doorman_doorway_deploy_spawn.vpcf"
    then
        state.skill2_confirmed = true
        state.skill2_dispatch_pending = false
    end
end)
