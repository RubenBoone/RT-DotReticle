local DotReticle = {}

local MOD_NAME = "RT-DotReticle"

local updateScheduled = false
local sliderPatched = false
local widgetOpacity = {}

local CROSSHAIR_CONSTRUCT =
    "/Game/UI/Widgets/HUD/Generic/WBP_UI_Widget_CrosshairVisuals.WBP_UI_Widget_CrosshairVisuals_C:Construct"
local CROSSHAIR_UPDATE_SETTINGS =
    "/Game/UI/Widgets/HUD/Generic/WBP_UI_Widget_CrosshairVisuals.WBP_UI_Widget_CrosshairVisuals_C:UpdateSettings"

local function IsUsableObject(object)
    if not object then
        return false
    end

    local ok, valid = pcall(function()
        return object:IsValid()
    end)

    return ok and valid == true
end

local function GetCrosshairBarLength()
    local settingsObjects = FindAllOf("SBZGameUserSettings")

    if not settingsObjects then
        return nil
    end

    for _, settings in ipairs(settingsObjects) do
        if IsUsableObject(settings) then
            local ok, length = pcall(function()
                -- The live settings object has a GameInstance; its class default
                -- object does not and must not be used as the player's value.
                if not IsUsableObject(settings.GameInstance) then
                    return nil
                end

                return tonumber(settings.CrosshairsBarLength)
            end)

            if ok and length then
                return length
            end
        end
    end

    return nil
end

local function PatchBarLengthSlider()
    if sliderPatched then
        return true
    end

    local configs = FindAllOf("SBZSettingsMenuConfig")

    if not configs then
        return false
    end

    for _, config in ipairs(configs) do
        if IsUsableObject(config) then
            local patched = false

            local ok = pcall(function()
                config.SettingsCategories:ForEach(function(_, categoryParam)
                    if patched then
                        return true
                    end

                    local category = categoryParam:get()

                    if not category then
                        return
                    end

                    category.SettingsGroups:ForEach(function(_, groupParam)
                        if patched then
                            return true
                        end

                        local group = groupParam:get()

                        if not group then
                            return
                        end

                        group.Settings:ForEach(function(_, settingParam)
                            local setting = settingParam:get()

                            if not setting then
                                return
                            end

                            local name = setting.SetValueFunctionName:ToString()

                            if name == "SetCrosshairsBarLength" then
                                setting.FloatMinValue = 0.0
                                settingParam:set(setting)
                                patched = true
                                return true
                            end
                        end)
                    end)
                end)
            end)

            if ok and patched then
                sliderPatched = true
                print("[" .. MOD_NAME .. "] Crosshairs Bar Length minimum set to 0")
                return true
            end
        end
    end

    return false
end

local function ApplyDotReticle()
    local barLength = GetCrosshairBarLength()

    if not barLength then
        return false
    end

    local directionalOpacity = barLength <= 0.001 and 0.0 or 1.0
    local widgets = FindAllOf("WBP_UI_Widget_CrosshairVisuals_C")

    if not widgets then
        return false
    end

    local applied = false

    for _, widget in ipairs(widgets) do
        if IsUsableObject(widget) then
            local ok = pcall(function()
                local directionalImages = {
                    widget.Image_Top,
                    widget.Image_Right,
                    widget.Image_Bottom,
                    widget.Image_Left,
                }

                for _, image in ipairs(directionalImages) do
                    if IsUsableObject(image) then
                        -- At zero, also hide the residual spread dots left by the
                        -- game's zero-length bar rendering. Positive slider values
                        -- restore the complete native crosshair.
                        image:SetRenderOpacity(directionalOpacity)
                    end
                end
            end)

            applied = applied or ok
        end
    end

    return applied
end

local function ApplyToWidget(widget, barLength)
    if not IsUsableObject(widget) or barLength == nil then
        return false
    end

    local directionalOpacity = barLength <= 0.001 and 0.0 or 1.0

    if widgetOpacity[widget] == directionalOpacity then
        return true
    end

    local ok = pcall(function()
        local directionalImages = {
            widget.Image_Top,
            widget.Image_Right,
            widget.Image_Bottom,
            widget.Image_Left,
        }

        for _, image in ipairs(directionalImages) do
            if IsUsableObject(image) then
                image:SetRenderOpacity(directionalOpacity)
            end
        end
    end)

    if ok then
        widgetOpacity[widget] = directionalOpacity
    end

    return ok
end

local function HandleCrosshairUpdate(context, settingsParam)
    local widget = nil
    local barLength = nil

    pcall(function()
        widget = context:get()
    end)

    pcall(function()
        local settings = settingsParam:get()
        barLength = tonumber(settings.CrosshairsBarLength)
    end)

    ApplyToWidget(widget, barLength)
end

local function ScheduleUpdate()
    if updateScheduled then
        return
    end

    updateScheduled = true

    local scheduled = pcall(function()
        ExecuteInGameThread(function()
            -- UObject lookup, validity checks, property access, and UFunction
            -- calls must all happen on Unreal's game thread.
            pcall(PatchBarLengthSlider)
            pcall(ApplyDotReticle)
            updateScheduled = false
        end)
    end)

    if not scheduled then
        updateScheduled = false
    end
end

function DotReticle.Init()
    -- Update only when Unreal creates or refreshes a crosshair widget.
    local hooksRegistered = pcall(function()
        RegisterHook(CROSSHAIR_CONSTRUCT, function()
            ScheduleUpdate()
        end)

        RegisterHook(CROSSHAIR_UPDATE_SETTINGS, function(context, settingsParam)
            HandleCrosshairUpdate(context, settingsParam)
        end)
    end)

    if not hooksRegistered then
        print("[" .. MOD_NAME .. "] Could not register crosshair update hooks")
    end

    local patchAttempts = 0

    LoopAsync(500, function()
        patchAttempts = patchAttempts + 1

        ExecuteInGameThread(function()
            PatchBarLengthSlider()
        end)

        return sliderPatched or patchAttempts >= 20
    end)

    ScheduleUpdate()

    print("[" .. MOD_NAME .. "] Loaded")
end

return DotReticle
