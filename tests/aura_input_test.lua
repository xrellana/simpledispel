local addon = {}
local initializedAuraButton

C_XMLUtil = {
    GetTemplateInfo = function()
        return {}
    end,
}

local function NewRegion()
    local region = {}

    function region:SetSize(width, height)
        self.width = width
        self.height = height
    end

    function region:SetMouseClickEnabled(enabled)
        self.mouseClickEnabled = enabled
    end

    function region:SetPropagateMouseClicks(enabled)
        self.propagateMouseClicks = enabled
    end

    function region:SetPassThroughButtons(...)
        self.passThroughButtons = { ... }
    end

    function region:SetMouseMotionEnabled(enabled)
        self.mouseMotionEnabled = enabled
    end

    function region:CreateTexture()
        return NewRegion()
    end

    function region:CreateFontString()
        return NewRegion()
    end

    function region:SetAllPoints()
    end

    function region:SetPoint()
    end

    function region:ClearAllPoints()
    end

    function region:SetTexCoord()
    end

    function region:EnableMouse()
    end

    function region:SetIcon(icon)
        self.icon = icon
    end

    function region:SetDurationCooldown(cooldown)
        self.cooldown = cooldown
    end

    function region:SetApplicationCount(count)
        self.count = count
    end

    function region:SetDurationText(duration)
        self.duration = duration
    end

    return region
end

local function NewAuraContainer()
    local container = NewRegion()

    function container:AddAuraSlot(_, _, options)
        initializedAuraButton = NewRegion()
        options.initializeFrame(initializedAuraButton)
        return initializedAuraButton
    end

    function container:SetUnit(unit)
        self.unit = unit
    end

    function container:UpdateAllAuras()
        self.updated = true
    end

    function container:Hide()
        self.hidden = true
    end

    return container
end

function CreateFrame(frameType)
    if frameType == "AuraContainer" then
        return NewAuraContainer()
    end
    return NewRegion()
end

local auraChunk = assert(loadfile("AuraDisplay.lua"))
auraChunk("SimpleDispel", addon)

local owner = NewRegion()
local container, errorMessage = addon.AuraDisplay:Create(
    owner,
    "player",
    "HARMFUL|RAID",
    { size = 48, showDuration = true }
)

assert(container, tostring(errorMessage))
assert(initializedAuraButton, "Aura Button initializer did not run")
assert(initializedAuraButton.width == 48, "legacy square aura width is wrong")
assert(initializedAuraButton.height == 48, "legacy square aura height is wrong")
assert(initializedAuraButton.mouseClickEnabled == true, "Aura Button clicks were not enabled")
assert(initializedAuraButton.propagateMouseClicks == true, "mouse click propagation was not enabled")
assert(initializedAuraButton.mouseMotionEnabled == true, "native aura hover was not preserved")
assert(not initializedAuraButton.passThroughButtons, "fallback should not run when propagation succeeds")

local raidContainer, raidError = addon.AuraDisplay:Create(
    owner,
    "raid1",
    "HARMFUL|RAID",
    { width = 28, height = 28, anchor = "CENTER", showDuration = false }
)
assert(raidContainer, tostring(raidError))
assert(initializedAuraButton.width == 28, "compact raid aura width is wrong")
assert(initializedAuraButton.height == 28, "compact raid aura height is wrong")

print("SimpleDispel aura input propagation: PASS")
