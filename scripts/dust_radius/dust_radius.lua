---@class DustRadiusParticle
local DustRadiusParticle = {
    dust_radius = XHelpers.XAbility:RParseSpecials("item_dust", "radius"),
    dust_duration = XHelpers.XAbility:RParseSpecials("item_dust", "duration"),
    revealed_modifier = "modifier_item_dustofappearance",
    eye_icon = "\u{f06e}",
    particle_names = table.merge({ "None" }, LIB_HEROES_DATA.particles_for_radius),
}

---@param color Color
---@return Vector
local function color_to_vector(color)
    return Vector(color.r, color.g, color.b)
end

function DustRadiusParticle:Init()
    self.menu_others = Menu.Find("Info Screen", "Main", "Radius", "Main", "Others Settings") --[[@as CMenuGroup]]
    self.enable_radius = Menu.Find("Info Screen", "Main", "Radius", "Main", "Global Settings", "Enable") --[[@as CMenuSwitch]]

    self.enable_dust = self.menu_others:Switch("Dust Indicator (Particle)", false, "\u{f06e}")
    self.enable_dust_gear = self.enable_dust:Gear("Settings")

    self.dust_custom_particle = self.enable_dust_gear:Combo("Custom Particle", self.particle_names, 2)
    self.dust_custom_particle:Icon("\u{f890}")
    self.show_eye_icon = self.enable_dust_gear:Switch("Show Eye Icon", true, self.eye_icon)

    self.enemy_particle_color = self.enable_dust_gear:ColorPicker("Enemy Particle Color", Color(130, 35, 125, 255), "\u{f53f}")
    self.ally_particle_color = self.enable_dust_gear:ColorPicker("Ally Particle Color", Color(35, 110, 150, 255), "\u{f53f}")
    self.revealed_particle_color = self.enable_dust_gear:ColorPicker("Revealed Particle Color", Color(255, 70, 70, 255), "\u{f53f}")
    self.ally_revealed_particle_color = self.enable_dust_gear:ColorPicker("Ally Revealed Particle Color", Color(60, 180, 255, 255), "\u{f53f}")
    self.enemy_eye_color = self.enable_dust_gear:ColorPicker("Enemy Eye Color", Color(160, 55, 155, 210), "\u{f06e}")
    self.ally_eye_color = self.enable_dust_gear:ColorPicker("Ally Eye Color", Color(70, 170, 220, 210), "\u{f06e}")
    self.revealed_eye_color = self.enable_dust_gear:ColorPicker("Revealed Eye Color", Color(255, 70, 70, 230), "\u{f06e}")
    self.ally_revealed_eye_color = self.enable_dust_gear:ColorPicker("Ally Revealed Eye Color", Color(80, 200, 255, 230), "\u{f06e}")

    self.show_eye_icon:SetCallback(function(widget)
        for _, eye_color in pairs({
            self.enemy_eye_color,
            self.ally_eye_color,
            self.revealed_eye_color,
            self.ally_revealed_eye_color,
        }) do
            eye_color:Visible(widget:Get())
        end
    end, true)

    ---@type table<integer, {position: Vector, particle: integer?, expire_time: number, particle_color: Color, icon_color: Color, is_ally: boolean, is_revealed: boolean, revealed_targets: table<CEntity, CModifier>}>
    self.dust_info = {}
    ---@type table<integer, {is_ally: boolean, created: boolean}>
    self.detected_particles = {}
    self.eye_font = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)
    self.eye_icon_size = Render.TextSize(self.eye_font, 30, self.eye_icon)
    self.is_revealed = false

    self.dust_custom_particle:SetCallback(function()
        self:DestroyParticles()
        local particle_name = self:GetSelectedParticle()

        if self:IsEnabled() and particle_name ~= nil then
            for index in pairs(self.dust_info) do
                self:CreateParticle(index, particle_name)
            end
        end
    end, false)

    local update_colors = function()
        self:UpdateAllDustColors()
    end

    for _, color_picker in pairs({
        self.enemy_particle_color,
        self.ally_particle_color,
        self.revealed_particle_color,
        self.ally_revealed_particle_color,
        self.enemy_eye_color,
        self.ally_eye_color,
        self.revealed_eye_color,
        self.ally_revealed_eye_color,
    }) do
        color_picker:SetCallback(update_colors, false)
    end

    self.enable_dust:SetCallback(function(widget)
        self.enable_dust_gear:Visible(widget:Get())

        if not self:IsEnabled() then
            self:DestroyParticles()
        end
    end, true)
end

function DustRadiusParticle:IsEnabled()
    return self.enable_dust:Get() and self.enable_radius:Get() and Menu.VisualsIsEnabled()
end

---@return string?
function DustRadiusParticle:GetSelectedParticle()
    local name = self.particle_names[self.dust_custom_particle:Get() + 1]

    if name == "None" then
        return nil
    end

    return LIB_HEROES_DATA.particles_path_for_radius[name] or name
end

function DustRadiusParticle:OnUpdate()
    if not self:IsEnabled() then
        self:DestroyParticles()
        return
    end

    local time = GameRules.GetGameTime()
    local particle_name = self:GetSelectedParticle()
    local local_hero = Heroes.GetLocal()
    local is_revealed = local_hero ~= nil and NPC.HasModifier(local_hero, self.revealed_modifier)

    if self.is_revealed ~= is_revealed then
        self.is_revealed = is_revealed
        self:UpdateAllDustColors()
    end

    for index, data in pairs(self.dust_info) do
        if time > data.expire_time then
            self:RemoveDust(index)
        else
            if data.particle == nil and particle_name ~= nil then
                self:CreateParticle(index, particle_name)
            end

            if data.is_ally then
                self:FindRevealedTargets(data)
            end

            local revealed = self:IsDustRevealed(index, data.is_ally)
            if data.is_revealed ~= revealed then
                self:UpdateDustColor(index)
            end
        end
    end
end

function DustRadiusParticle:OnDraw()
    if not self:IsEnabled() or not self.show_eye_icon:Get() then
        return
    end

    for _, data in pairs(self.dust_info) do
        local xy, visible = Render.WorldToScreen(data.position)

        if visible then
            Render.Text(self.eye_font, 30, self.eye_icon, Vec2(xy.x, xy.y - 40) - (self.eye_icon_size / 2), data.icon_color)
        end
    end
end

---@param particle ParticleCreateData
function DustRadiusParticle:OnParticleCreate(particle)
    local name = particle["name"] or ""
    local full_name = particle["fullName"] or ""

    if name ~= "dust_of_appearance" and not string.find(full_name, "dust_of_appearance", 1, true) then
        return
    end

    local owner = particle["entityForModifiers"]
    if owner == nil or not Entity.IsEntity(owner) then
        owner = particle["entity"]
    end

    if owner ~= nil and Entity.IsEntity(owner) then
        owner = Entity.RecursiveGetOwner(owner) or owner
    else
        owner = nil
    end

    self.detected_particles[particle["index"]] = {
        is_ally = owner ~= nil and Entity.GetTeamNum(owner) == LIB_HEROES_DATA.my_hero.team,
        created = false,
    }
end

---@param particle ParticleUpdateData
function DustRadiusParticle:OnParticleUpdate(particle)
    self:UpdateDetectedParticle(particle)
end

---@param particle ParticleUpdateData
function DustRadiusParticle:OnParticleUpdateFallback(particle)
    self:UpdateDetectedParticle(particle)
end

---@param particle ParticleUpdateEntityData
function DustRadiusParticle:OnParticleUpdateEntity(particle)
    self:UpdateDetectedParticle(particle)
end

---@param particle ParticleUpdateData|ParticleUpdateEntityData
function DustRadiusParticle:UpdateDetectedParticle(particle)
    local detected = self.detected_particles[particle["index"]]

    if detected == nil or particle["controlPoint"] ~= 0 then
        return
    end

    if detected.created and self.dust_info[particle["index"]] == nil then
        return
    end

    self:AddDust(particle["index"], particle["position"], detected.is_ally)
    detected.created = true
end

---@param particle ParticleDestroyData
function DustRadiusParticle:OnParticleDestroy(particle)
    self.detected_particles[particle["index"]] = nil
end

---@param entity CEntity
---@param modifier CModifier
function DustRadiusParticle:OnModifierCreate(entity, modifier)
    if Modifier.GetName(modifier) == self.revealed_modifier then
        self:AddRevealedTarget(entity, modifier)
    end
end

---@param entity CEntity
---@param modifier CModifier
function DustRadiusParticle:OnModifierDestroy(entity, modifier)
    if Modifier.GetName(modifier) ~= self.revealed_modifier then
        return
    end

    for index, data in pairs(self.dust_info) do
        if data.revealed_targets[entity] == modifier then
            data.revealed_targets[entity] = nil
            self:UpdateDustColor(index)
        end
    end
end

---@param index integer
---@param position Vector
---@param is_ally boolean
function DustRadiusParticle:AddDust(index, position, is_ally)
    local data = self.dust_info[index]

    if data ~= nil then
        data.position = position

        if data.particle ~= nil then
            Particle.SetControlPoint(data.particle, 0, position)
        end

        return
    end

    local particle_color, icon_color = self:GetDustColors(is_ally, false)

    self.dust_info[index] = {
        position = position,
        particle = nil,
        expire_time = GameRules.GetGameTime() + self.dust_duration,
        particle_color = particle_color,
        icon_color = icon_color,
        is_ally = is_ally,
        is_revealed = false,
        revealed_targets = {},
    }

    local particle_name = self:GetSelectedParticle()

    if self:IsEnabled() and particle_name ~= nil then
        self:CreateParticle(index, particle_name)
    end
end

---@param is_ally boolean
---@param is_revealed boolean
function DustRadiusParticle:GetDustColors(is_ally, is_revealed)
    if is_revealed then
        if is_ally then
            return self.ally_revealed_particle_color:Get(), self.ally_revealed_eye_color:Get()
        end

        return self.revealed_particle_color:Get(), self.revealed_eye_color:Get()
    end

    if is_ally then
        return self.ally_particle_color:Get(), self.ally_eye_color:Get()
    end

    return self.enemy_particle_color:Get(), self.enemy_eye_color:Get()
end

---@param index integer
---@param is_ally boolean
function DustRadiusParticle:IsDustRevealed(index, is_ally)
    if not is_ally then
        return self.is_revealed
    end

    return next(self.dust_info[index].revealed_targets) ~= nil
end

---@param data table
function DustRadiusParticle:FindRevealedTargets(data)
    local enemies = Heroes.InRadius(data.position, self.dust_radius, LIB_HEROES_DATA.my_hero.team,
        Enum.TeamType.TEAM_ENEMY, true, false)

    for _, enemy in pairs(enemies) do
        local modifiers = LIB_HEROES_DATA.modifier[enemy]
        local revealed = modifiers ~= nil and modifiers[self.revealed_modifier]
            or NPC.GetModifier(enemy, self.revealed_modifier)

        if revealed ~= nil then
            data.revealed_targets[enemy] = revealed
        end
    end
end

---@param target CEntity
---@param modifier CModifier
function DustRadiusParticle:AddRevealedTarget(target, modifier)
    if Entity.GetTeamNum(target) == LIB_HEROES_DATA.my_hero.team then
        return
    end

    local target_position = Entity.GetAbsOrigin(target)

    for index, data in pairs(self.dust_info) do
        if data.is_ally and (data.position - target_position):Length2D() <= self.dust_radius then
            data.revealed_targets[target] = modifier
            self:UpdateDustColor(index)
        end
    end
end

---@param index integer
function DustRadiusParticle:UpdateDustColor(index)
    local data = self.dust_info[index]
    local is_revealed = self:IsDustRevealed(index, data.is_ally)
    local particle_color, icon_color = self:GetDustColors(data.is_ally, is_revealed)
    data.particle_color = particle_color
    data.icon_color = icon_color
    data.is_revealed = is_revealed

    if data.particle ~= nil then
        Particle.SetControlPoint(data.particle, 1, color_to_vector(particle_color))
        Particle.SetControlPoint(data.particle, 2, Vector(self.dust_radius, particle_color.a, 0))
    end
end

function DustRadiusParticle:UpdateAllDustColors()
    for index in pairs(self.dust_info) do
        self:UpdateDustColor(index)
    end
end

---@param entity CEntity
function DustRadiusParticle:OnEntityDestroy(entity)
    for index, data in pairs(self.dust_info) do
        if data.revealed_targets[entity] ~= nil then
            data.revealed_targets[entity] = nil
            self:UpdateDustColor(index)
        end
    end
end

---@param index integer
function DustRadiusParticle:RemoveDust(index)
    local data = self.dust_info[index]

    if data.particle ~= nil then
        Particle.Destroy(data.particle)
    end

    self.dust_info[index] = nil
end

---@param index integer
---@param particle_name string
function DustRadiusParticle:CreateParticle(index, particle_name)
    local data = self.dust_info[index]

    if data.particle ~= nil then
        Particle.Destroy(data.particle)
    end

    local fx = Particle.Create(particle_name, Enum.ParticleAttachment.PATTACH_WORLDORIGIN)
    Particle.SetControlPoint(fx, 0, data.position)
    Particle.SetControlPoint(fx, 1, color_to_vector(data.particle_color))
    Particle.SetControlPoint(fx, 2, Vector(self.dust_radius, data.particle_color.a, 0))
    Particle.SetControlPoint(fx, 3, Vector(1, 0, 0))
    data.particle = fx
end

function DustRadiusParticle:DestroyParticles()
    for _, data in pairs(self.dust_info) do
        if data.particle ~= nil then
            Particle.Destroy(data.particle)
            data.particle = nil
        end
    end
end

return XHelpers.WrapCallbacks(DustRadiusParticle)
