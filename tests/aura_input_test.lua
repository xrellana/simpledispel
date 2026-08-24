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

    function region:SetPoint(...)
        local points = self.points or {}
        points[#points + 1] = { ... }
        self.points = points
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

-- A bottom inset can still leave a wider-than-tall icon area in the general
-- case. Cropping the source art to that aspect keeps the icon recognisable
-- where stretching it into the box would not.
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

-- A real party button covers only the square icon area at the top of the cell,
-- leaving the name band below it out of the aura button entirely, so the icon
-- is square again and must not be cropped at all.
local partyContainer, partyError = addon.AuraDisplay:Create(
    owner,
    "party1",
    "HARMFUL|RAID",
    { width = 48, height = 48, anchor = "TOP", showDuration = true }
)
assert(partyContainer, tostring(partyError))

-- The name band is part of the unit button, not of the aura button, so the
-- duration has to hang below the unit button: anchoring it below the aura
-- button would drop it onto the name whenever the band is shown.
local durationPoint = initializedAuraButton.duration.points[1]
assert(durationPoint[1] == "TOP", "duration text must hang below the cell")
assert(durationPoint[2] == owner, "duration text must be anchored to the unit button")
assert(durationPoint[3] == "BOTTOM", "duration text must be anchored below the unit button")

local partyCoords = initializedAuraButton.icon.texCoord
assert(
    Close(partyCoords[1], 0.07) and Close(partyCoords[2], 0.93)
        and Close(partyCoords[3], 0.07) and Close(partyCoords[4], 0.93),
    "a square party icon area must keep the plain uncropped square"
)
assert(
    Close(partyCoords[4] - partyCoords[3], partyCoords[2] - partyCoords[1]),
    "a square icon area must not stretch or crop the icon's aspect ratio"
)

print("SimpleDispel aura input propagation: PASS")
