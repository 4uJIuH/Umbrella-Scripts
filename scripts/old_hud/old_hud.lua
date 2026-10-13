local main = {}

local gMain = Menu.Create("General", "Main", "Profile", "Old HUD", "Main")

if not gMain then
    return {}
end

local Enable = gMain:Switch("Enable", false)
local HideInnate = gMain:Switch("Hide innate / facet", true)
local HudScale = gMain:Slider("HUD scale %", 70, 130, 100, "%d")
local PrintDebug = gMain:Switch("Print debug", false)

local CHECK_INTERVAL = 1.00

local cachedCenter = nil
local cachedInnate = nil

local lastCheck = 0
local dirty = true

local lastScale = nil
local lastHide = nil

local innateOriginalHasNothing = setmetatable({}, { __mode = "k" })

local function safe(fn, default)
    local ok, result = pcall(fn)

    if ok then
        return result
    end

    return default
end

local function is_valid(panel)
    if not panel then
        return false
    end

    return safe(function()
        return panel:IsValid()
    end, false)
end

local function get_panel(id)
    if not Panorama then
        return nil
    end

    return safe(function()
        return Panorama.GetPanelByName(id, false)
    end, nil)
end

local function find_id(root, id)
    if not root or not is_valid(root) then
        return nil
    end

    return safe(function()
        return root:FindChildTraverse(id)
    end, nil)
end

local function has_class(panel, className)
    if not panel or not is_valid(panel) then
        return false
    end

    return safe(function()
        return panel:HasClass(className)
    end, false)
end

local function add_class(panel, className)
    if not panel or not is_valid(panel) then
        return false
    end

    if has_class(panel, className) then
        return true
    end

    return safe(function()
        panel:AddClasses(className)
        return true
    end, false)
end

local function remove_class(panel, className)
    if not panel or not is_valid(panel) then
        return false
    end

    if not has_class(panel, className) then
        return true
    end

    return safe(function()
        panel:RemoveClasses(className)
        return true
    end, false)
end

local function set_style(panel, value)
    if not panel or not is_valid(panel) then
        return false
    end

    return safe(function()
        panel:SetStyle(tostring(value or ""))
        return true
    end, false)
end

local function resolve_panels()
    local rebuilt = false

    if not cachedCenter or not is_valid(cachedCenter) then
        cachedCenter = get_panel("center_block")
        cachedInnate = nil
        lastScale = nil
        lastHide = nil
        rebuilt = true
    end

    if cachedCenter
        and is_valid(cachedCenter)
        and (not cachedInnate or not is_valid(cachedInnate))
    then
        local innateIcon =
            find_id(
                cachedCenter,
                "InnateIcon"
            )

        if innateIcon and is_valid(innateIcon) then
            cachedInnate =
                safe(function()
                    local contents = innateIcon:GetParent()

                    if not contents then
                        return nil
                    end

                    return contents:GetParent()
                end, nil)
        else
            cachedInnate = nil
        end

        if cachedInnate and is_valid(cachedInnate) then
            if innateOriginalHasNothing[cachedInnate] == nil then
                innateOriginalHasNothing[cachedInnate] =
                    has_class(
                        cachedInnate,
                        "HasNothing"
                    )
            end
        end

        lastHide = nil
        rebuilt = true
    end

    return rebuilt
end

local function apply_hide_innate(force)
    if not cachedInnate or not is_valid(cachedInnate) then
        return false
    end

    local wanted =
        safe(function()
            return HideInnate:Get() == true
        end, true)

    if not force
        and lastHide == wanted
    then
        if wanted and has_class(cachedInnate, "HasNothing") then
            return true
        end

        if not wanted then
            return true
        end
    end

    local ok = false

    if wanted then
        ok =
            add_class(
                cachedInnate,
                "HasNothing"
            )
    else
        local originallyHidden =
            innateOriginalHasNothing[cachedInnate] == true

        if originallyHidden then
            ok =
                add_class(
                    cachedInnate,
                    "HasNothing"
                )
        else
            ok =
                remove_class(
                    cachedInnate,
                    "HasNothing"
                )
        end
    end

    lastHide = wanted

    return ok
end

local function apply_scale(force)
    if not cachedCenter or not is_valid(cachedCenter) then
        return false
    end

    local scale =
        safe(function()
            return math.floor(
                tonumber(HudScale:Get())
                or 100
            )
        end, 100)

    if scale < 70 then
        scale = 70
    elseif scale > 130 then
        scale = 130
    end

    if not force
        and lastScale == scale
    then
        return true
    end

    local ok =
        set_style(
            cachedCenter,
            "ui-scale: "
            .. tostring(scale)
            .. "%;"
        )

    if ok then
        lastScale = scale
    end

    return ok
end

local function apply_all(forceDebug, force)
    resolve_panels()

    local hideOK =
        apply_hide_innate(
            force == true
        )

    local scaleOK =
        apply_scale(
            force == true
        )

    if PrintDebug:Get() and forceDebug then
        print(
            "[Old HUD] center="
            .. tostring(
                cachedCenter ~= nil
                and is_valid(cachedCenter)
            )
            .. " innate="
            .. tostring(
                cachedInnate ~= nil
                and is_valid(cachedInnate)
            )
            .. " hideOK="
            .. tostring(hideOK)
            .. " scaleOK="
            .. tostring(scaleOK)
            .. " scale="
            .. tostring(
                safe(function()
                    return HudScale:Get()
                end, 100)
            )
        )
    end

    return hideOK or scaleOK
end

local function restore_all(forceDebug)
    if cachedInnate and is_valid(cachedInnate) then
        local originallyHidden =
            innateOriginalHasNothing[cachedInnate] == true

        if originallyHidden then
            add_class(
                cachedInnate,
                "HasNothing"
            )
        else
            remove_class(
                cachedInnate,
                "HasNothing"
            )
        end
    end

    if cachedCenter and is_valid(cachedCenter) then
        set_style(
            cachedCenter,
            "ui-scale: 100%;"
        )
    end

    lastScale = nil
    lastHide = nil
    dirty = true

    if PrintDebug:Get() and forceDebug then
        print("[Old HUD] restored")
    end
end

local function mark_dirty()
    dirty = true
end

HideInnate:SetCallback(mark_dirty)
HudScale:SetCallback(mark_dirty)

Enable:SetCallback(function()
    dirty = true
    lastCheck = 0

    if not Enable:Get() then
        restore_all(false)
    end
end)

gMain:Button("Apply now", function()
    if Enable:Get() then
        dirty = false
        apply_all(true, true)
    else
        restore_all(true)
    end
end)

function main.OnUpdateEx()
    if not Enable:Get() then
        return
    end

    local now = os.clock()

    if not dirty
        and now - lastCheck < CHECK_INTERVAL
    then
        return
    end

    lastCheck = now

    local rebuilt =
        resolve_panels()

    if dirty or rebuilt then
        apply_all(false, true)
        dirty = false
        return
    end

    apply_hide_innate(false)
end

return main
