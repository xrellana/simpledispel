local _, addon = ...

local AuraDisplay = {}
addon.AuraDisplay = AuraDisplay

local DEFAULT_AURA_SIZE = 48

AuraDisplay.Filters = {
    mine = "HARMFUL|RAID",
    group = "HARMFUL|RAID_PLAYER_DISPELLABLE",
    all = "HARMFUL|DISPELLABLE",
}

local function CreateAuraButtonInitializer(auraSize, showDuration)
    return function(auraButton)
        -- AuraButton surface methods may become forbidden after this callback.
        -- All setup is intentionally completed inside the initialization window.
        auraButton:SetSize(auraSize, auraSize)

        if auraButton.SetMouseClickEnabled then
            pcall(auraButton.SetMouseClickEnabled, auraButton, false)
        end
        if auraButton.SetMouseMotionEnabled then
            pcall(auraButton.SetMouseMotionEnabled, auraButton, true)
        end

        local icon = auraButton:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(auraButton)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        cooldown:SetAllPoints(auraButton)
        cooldown:EnableMouse(false)

        local count = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
        count:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -2, 2)

        local duration
        if showDuration then
            duration = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
            duration:SetPoint("TOP", auraButton, "BOTTOM", 0, -2)
        end

        auraButton:SetIcon(icon)
        if auraButton.SetDurationCooldown then
            pcall(auraButton.SetDurationCooldown, auraButton, cooldown)
        end

        if auraButton.SetApplicationCount then
            pcall(auraButton.SetApplicationCount, auraButton, count, {})
        end
        if duration and auraButton.SetDurationText then
            -- Duration option schemas changed several times during 12.1 PTR.
            -- A rejected optional binding must not abort the icon-only display.
            pcall(auraButton.SetDurationText, auraButton, duration, {})
        end
    end
end

function AuraDisplay:IsSupported()
    if not C_XMLUtil or not C_XMLUtil.GetTemplateInfo then
        return false, "C_XMLUtil.GetTemplateInfo is unavailable"
    end

    local ok, templateInfo = pcall(C_XMLUtil.GetTemplateInfo, "CustomAuraContainerTemplate")
    if not ok or not templateInfo then
        return false, "CustomAuraContainerTemplate is unavailable"
    end

    return true
end

function AuraDisplay:GetFilter(mode)
    return self.Filters[mode] or self.Filters.mine
end

function AuraDisplay:Create(owner, unit, filterString, options)
    local supported, supportError = self:IsSupported()
    if not supported then
        return nil, supportError
    end

    options = options or {}
    local auraSize = tonumber(options.size) or DEFAULT_AURA_SIZE
    local showDuration = options.showDuration ~= false

    local ok, container = pcall(
        CreateFrame,
        "AuraContainer",
        nil,
        owner,
        "CustomAuraContainerTemplate"
    )
    if not ok then
        return nil, container
    end

    container:SetSize(1, 1)
    container:SetPoint("CENTER", owner, "CENTER")

    local slotOK, auraButton = pcall(container.AddAuraSlot, container, "dispel", filterString, {
        initializeFrame = CreateAuraButtonInitializer(auraSize, showDuration),
    })
    if not slotOK then
        container:Hide()
        return nil, auraButton
    end

    local anchorOK, anchorError = pcall(function()
        auraButton:ClearAllPoints()
        auraButton:SetPoint("CENTER", owner, "CENTER")
    end)
    if not anchorOK then
        container:Hide()
        return nil, anchorError
    end

    -- Unit must be assigned after slots/groups so the container registers for
    -- the appropriate updates. Request one initial refresh after assignment.
    local unitOK, unitError = pcall(container.SetUnit, container, unit)
    if not unitOK then
        container:Hide()
        return nil, unitError
    end

    if container.UpdateAllAuras then
        local refreshOK, refreshError = pcall(container.UpdateAllAuras, container)
        if not refreshOK then
            container:Hide()
            return nil, refreshError
        end
    end

    return container
end
