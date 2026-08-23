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

    function region:SetTexCoord(...)
        self.texCoord = { ... }
    end

    function region:SetColorTexture(...)
        self.colorTexture = { ... }
    end

    function region:SetHeight(height)
        self.pixelHeight = height
    end

    function region:SetWidth(width)
        self.pixelWidth = width
    end

    function region:SetFrameLevel(level)
        self.frameLevel = level
    end

    function region:GetFrameLevel()
        return self.frameLevel or 3
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

local function Close(actual, expected)
    return type(actual) == "number" and math.abs(actual - expected) < 1e-9
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

local squareCoords = initializedAuraButton.icon.texCoord
assert(Close(squareCoords[1], 0.07) and Close(squareCoords[2], 0.93), "square icon crop is wrong")
assert(Close(squareCoords[3], 0.07) and Close(squareCoords[4], 0.93), "square icon crop is wrong")

local raidContainer, raidError = addon.AuraDisplay:Create(
    owner,
    "raid1",
    "HARMFUL|RAID",
    { width = 28, height = 28, anchor = "CENTER", showDuration = false }
)
assert(raidContainer, tostring(raidError))
assert(initializedAuraButton.width == 28, "compact raid aura width is wrong")
assert(initializedAuraButton.height == 28, "compact raid aura height is wrong")

-- Party buttons reserve the bottom of the aura button for the unit name, which
-- leaves a wider-than-tall icon area. Cropping the source art to that aspect
-- keeps the icon recognisable where stretching it into the box would not.
local ICON_INSET = 2
local labelledContainer, labelledError = addon.AuraDisplay:Create(
    owner,
    "party1",
    "HARMFUL|RAID",
    { width = 48, height = 48, iconBottomInset = 13, showDuration = true }
)
assert(labelledContainer, tostring(labelledError))

local iconWidth = 48 - (ICON_INSET * 2)
local iconHeight = 48 - 13 - (ICON_INSET * 2)
local coords = initializedAuraButton.icon.texCoord
assert(Close(coords[1], 0.07) and Close(coords[2], 0.93), "a shorter icon area must keep the full icon width")

local expectedHeight = (coords[2] - coords[1]) * (iconHeight / iconWidth)
assert(
    Close(coords[4] - coords[3], expectedHeight),
    "a label inset must crop the icon to its aspect ratio instead of squashing it"
)
assert(
    Close((coords[3] + coords[4]) / 2, 0.5),
    "the icon crop must stay centred on the source art"
)

print("SimpleDispel aura input propagation: PASS")
