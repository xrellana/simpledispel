local _, addon = ...

local AuraDisplay = {}
addon.AuraDisplay = AuraDisplay

local DEFAULT_AURA_SIZE = 48

AuraDisplay.Filters = {
    mine = "HARMFUL|RAID",
    group = "HARMFUL|RAID_PLAYER_DISPELLABLE",
    all = "HARMFUL|DISPELLABLE",
}

-- Blizzard icon art bakes a border into the outer edge of the texture, so the
-- visible artwork starts a little inside it.
local ICON_EDGE_CROP = 0.07
-- A margin of untouched button plate around the debuff icon isolates it from
-- the cell border. On the light theme that margin is what turns the plate into
-- a matte around the only saturated object in the frame.
local ICON_INSET = 2
-- A hard dark edge keeps pale debuff art readable on the light plate, and is
-- invisible against the dark theme's background, so one colour serves both.
-- Pale icon art composites to barely 1.3:1 against the light plate, so this
-- edge is what separates it, not a nicety.
local ICON_CONTOUR = { 0.06, 0.06, 0.08, 0.85 }
-- Draw the contour just outside the icon, inside the margin, so the edge costs
-- the artwork no pixels of its own.
local ICON_CONTOUR_OUTSET = 1

-- The icon area is not square whenever a label reserves space at the bottom.
-- Crop the source texture down to that aspect instead of stretching it into it:
-- a squashed icon is harder to recognise at a glance, which is the one job this
-- display has.
local function GetIconTexCoords(width, height)
    local low, high = ICON_EDGE_CROP, 1 - ICON_EDGE_CROP
    if type(width) ~= "number" or type(height) ~= "number" then
        return low, high, low, high
    end
    if width <= 0 or height <= 0 or width == height then
        return low, high, low, high
    end

    local span = high - low
    if width > height then
        local keep = span * (height / width)
        return low, high, 0.5 - (keep / 2), 0.5 + (keep / 2)
    end

    local keep = span * (width / height)
    return 0.5 - (keep / 2), 0.5 + (keep / 2), low, high
end

local function AnchorToIconArea(region, auraButton, iconBottomInset, outset)
    local inset = ICON_INSET - (outset or 0)
    region:SetPoint("TOPLEFT", auraButton, "TOPLEFT", inset, -inset)
    region:SetPoint(
        "BOTTOMRIGHT",
        auraButton,
        "BOTTOMRIGHT",
        -inset,
        iconBottomInset + inset
    )
end

local function AddIconContour(auraButton, cooldown, iconBottomInset)
    -- The cooldown swipe is a child frame and therefore draws over every texture
    -- owned by the aura button. Give the contour a frame of its own above it so
    -- the icon keeps a hard edge for the whole duration of the debuff.
    local ok, contour = pcall(CreateFrame, "Frame", nil, auraButton)
    if not ok or not contour then
        return
    end

    AnchorToIconArea(contour, auraButton, iconBottomInset, ICON_CONTOUR_OUTSET)
    if contour.EnableMouse then
        pcall(contour.EnableMouse, contour, false)
    end
    if cooldown and cooldown.GetFrameLevel and contour.SetFrameLevel then
        local levelOK, cooldownLevel = pcall(cooldown.GetFrameLevel, cooldown)
        if levelOK and type(cooldownLevel) == "number" then
            pcall(contour.SetFrameLevel, contour, cooldownLevel + 1)
        end
    end

    local function NewEdge()
        local edge = contour:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(
            ICON_CONTOUR[1],
            ICON_CONTOUR[2],
            ICON_CONTOUR[3],
            ICON_CONTOUR[4]
        )
        return edge
    end

    local top = NewEdge()
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)

    local bottom = NewEdge()
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    local left = NewEdge()
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = NewEdge()
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)

    return contour
end

local function CreateAuraButtonInitializer(auraWidth, auraHeight, showDuration, iconBottomInset)
    return function(auraButton)
        -- AuraButton surface methods may become forbidden after this callback.
        -- All setup is intentionally completed inside the initialization window.
        auraButton:SetSize(auraWidth, auraHeight)

        -- AuraButton is visually above the secure unit button. Disabling its
        -- click handling does not guarantee that the event reaches the frame
        -- below it. Explicit click propagation keeps the native aura tooltip
        -- while forwarding LeftButton down/up to the secure action button.
        local clickPropagationEnabled = false
        if auraButton.SetMouseClickEnabled and auraButton.SetPropagateMouseClicks then
            local clickOK = pcall(auraButton.SetMouseClickEnabled, auraButton, true)
            local propagationOK = pcall(auraButton.SetPropagateMouseClicks, auraButton, true)
            clickPropagationEnabled = clickOK and propagationOK
        end
        if not clickPropagationEnabled and auraButton.SetPassThroughButtons then
            clickPropagationEnabled = pcall(
                auraButton.SetPassThroughButtons,
                auraButton,
                "LeftButton"
            )
        end
        if not clickPropagationEnabled and auraButton.SetMouseClickEnabled then
            pcall(auraButton.SetMouseClickEnabled, auraButton, false)
        end
        if auraButton.SetMouseMotionEnabled then
            pcall(auraButton.SetMouseMotionEnabled, auraButton, true)
        end

        local icon = auraButton:CreateTexture(nil, "ARTWORK")
        AnchorToIconArea(icon, auraButton, iconBottomInset)
        icon:SetTexCoord(GetIconTexCoords(
            auraWidth - (ICON_INSET * 2),
            auraHeight - iconBottomInset - (ICON_INSET * 2)
        ))

        local cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        AnchorToIconArea(cooldown, auraButton, iconBottomInset)
        cooldown:EnableMouse(false)

        AddIconContour(auraButton, cooldown, iconBottomInset)

        local count = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
        count:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -2, iconBottomInset + 2)

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
    local auraWidth = tonumber(options.width) or tonumber(options.size) or DEFAULT_AURA_SIZE
    local auraHeight = tonumber(options.height) or tonumber(options.size) or DEFAULT_AURA_SIZE
    local anchor = options.anchor or "CENTER"
    local showDuration = options.showDuration ~= false
    local iconBottomInset = tonumber(options.iconBottomInset) or 0

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
    container:SetPoint(anchor, owner, anchor)

    local slotOK, auraButton = pcall(container.AddAuraSlot, container, "dispel", filterString, {
        initializeFrame = CreateAuraButtonInitializer(auraWidth, auraHeight, showDuration, iconBottomInset),
    })
    if not slotOK then
        container:Hide()
        return nil, auraButton
    end

    local anchorOK, anchorError = pcall(function()
        auraButton:ClearAllPoints()
        auraButton:SetPoint(anchor, owner, anchor)
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
