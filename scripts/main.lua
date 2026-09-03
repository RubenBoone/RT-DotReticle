local MOD_NAME = "RT-DotReticle"

-- Change this value to make the dot larger or smaller.
local DOT_SIZE = 4.0
local updateScheduled = false

local function IsUsableObject(object)
    if not object then
        return false
    end

    local ok, valid = pcall(function()
        return object:IsValid()
    end)

    return ok and valid == true
end

local function ApplyDotReticle()
    local widgets = FindAllOf("WBP_UI_Widget_CrosshairVisuals_C")

    if not widgets then
        return false
    end

    local applied = false

    for _, widget in ipairs(widgets) do
        if IsUsableObject(widget) then
            local ok = pcall(function()
                -- Zeroing the bar geometry removes the lines, while hiding each
                -- directional image also removes its spread indicator/dot.
                widget:SetBarSize(0.0, 0.0)
                widget:SetDotSize(DOT_SIZE)

                local directionalImages = {
                    widget.Image_Top,
                    widget.Image_Right,
                    widget.Image_Bottom,
                    widget.Image_Left,
                }

                for _, image in ipairs(directionalImages) do
                    if IsUsableObject(image) then
                        image:SetRenderOpacity(0.0)
                    end
                end
            end)

            applied = applied or ok
        end
    end

    return applied
end

local function ScheduleDotReticleUpdate()
    if updateScheduled then
        return
    end

    updateScheduled = true

    local scheduled = pcall(function()
        ExecuteInGameThread(function()
            -- UObject lookup, validity checks, property access, and UFunction
            -- calls must all happen on Unreal's game thread.
            pcall(ApplyDotReticle)
            updateScheduled = false
        end)
    end)

    if not scheduled then
        updateScheduled = false
    end
end

-- Reticle widgets are recreated when entering a heist and may be refreshed when
-- HUD settings or weapons change, so periodically schedule a safe game-thread
-- refresh. The guard prevents updates from accumulating in the game-thread queue.
LoopAsync(250, function()
    ScheduleDotReticleUpdate()
    return false
end)

print("[" .. MOD_NAME .. "] Loaded (dot size " .. tostring(DOT_SIZE) .. ")")
