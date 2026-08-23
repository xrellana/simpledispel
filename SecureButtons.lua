local _, addon = ...

local SecureButtons = {}
addon.SecureButtons = SecureButtons

local BUTTON_SIZE = 48
SecureButtons.BUTTON_SIZE = BUTTON_SIZE

local function AddBorder(frame, drawLayer, red, green, blue, alpha)
    local lines = {}

    local function NewLine()
        local line = frame:CreateTexture(nil, drawLayer or "BORDER")
        line:SetColorTexture(red or 0.12, green or 0.12, blue or 0.12, alpha or 1)
        lines[#lines + 1] = line
        return line
    end

    local top = NewLine()
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(1)

    local bottom = NewLine()
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(1)

    local left = NewLine()
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = NewLine()
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)

    return lines
end

local function SetBorderAlpha(lines, alpha)
    for _, line in ipairs(lines) do
        line:SetAlpha(alpha)
    end
end

-- SetColorTexture carries its own alpha channel and SetAlpha is a separate
-- multiplier on top of it, so recolouring a border never disturbs the
-- show/hide alpha that the range and cooldown states drive.
local function SetBorderColor(lines, color)
    for _, line in ipairs(lines) do
        line:SetColorTexture(color[1], color[2], color[3], color[4])
    end
end

local function CreateRangeOverlay(button)
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:EnableMouse(false)

    local shade = overlay:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints(overlay)
    shade:SetColorTexture(0.01, 0.01, 0.015, 1)
    shade:SetAlpha(0)

    local border = AddBorder(overlay, "OVERLAY", 0.95, 0.18, 0.12, 1)
    SetBorderAlpha(border, 0)

    local mark = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mark:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -2, -1)
    mark:SetText("×")
    mark:SetTextColor(1, 0.24, 0.18, 1)
    -- The overlay belongs to a protected action button. Keep every region
    -- created and shown permanently; combat updates only change alpha.
    mark:SetAlpha(0)

    local cooldownMark = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownMark:SetPoint("TOPLEFT", overlay, "TOPLEFT", 2, -1)
    cooldownMark:SetText("CD")
    cooldownMark:SetTextColor(1, 0.78, 0.20, 1)
    cooldownMark:SetAlpha(0)

    button.simpleDispelRangeOverlay = overlay
    button.simpleDispelRangeShade = shade
    button.simpleDispelRangeBorder = border
    button.simpleDispelRangeMark = mark
    button.simpleDispelCooldownMark = cooldownMark
    button.simpleDispelRangeState = "unknown"
    button.simpleDispelCooldownState = "unknown"
end

local function ApplyVisualState(button)
    local colors = addon.Theme:Colors()
    local outOfRange = button.simpleDispelRangeState == "out"
    local onCooldown = button.simpleDispelCooldownState == "cooldown"

    -- Range and cooldown are independent reasons the dispel cannot happen now.
    -- Share one shade so their alpha never compounds into an unreadable icon;
    -- keep both non-color marks visible when both states apply.
    local shadeAlpha = 0
    if outOfRange then
        shadeAlpha = colors.outOfRangeShadeAlpha
    elseif onCooldown then
        shadeAlpha = colors.cooldownShadeAlpha
    end

    button.simpleDispelRangeShade:SetAlpha(shadeAlpha)
    SetBorderAlpha(button.simpleDispelRangeBorder, outOfRange and 1 or 0)
    button.simpleDispelRangeMark:SetAlpha(outOfRange and 1 or 0)
    button.simpleDispelCooldownMark:SetAlpha(onCooldown and 1 or 0)
end

local function ApplyLabelColor(button, colors)
    local color = button.simpleDispelHasSpell and colors.labelReady or colors.labelMissing
    button.simpleDispelLabel:SetTextColor(color[1], color[2], color[3])
end

local function AddUnitTooltip(button)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip or not GameTooltip_SetDefaultAnchor or not GameTooltip.SetUnit then
            return
        end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.simpleDispelUnit)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

function SecureButtons:Create(parent, globalName, unit, shortLabel, requestedWidth, labelMode, requestedHeight)
    local buttonWidth = tonumber(requestedWidth) or BUTTON_SIZE
    local buttonHeight = tonumber(requestedHeight) or buttonWidth
    local button = CreateFrame("Button", globalName, parent, "SecureActionButtonTemplate")
    button:SetSize(buttonWidth, buttonHeight)
    button:RegisterForClicks("LeftButtonUp", "LeftButtonDown")

    -- These attributes are static for the lifetime of the button.
    button:SetAttribute("unit", unit)
    -- Do not depend on the account-wide ActionButtonUseKeyDown CVar. Register
    -- both directions as required by SecureActionButtonTemplate, then execute
    -- exactly once on mouse release.
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type1", nil)
    button:SetAttribute("spell1", nil)

    -- Party/raid unit tokens are fixed and visibility is driven securely. This
    -- lets group members appear or disappear during combat without insecure code
    -- attempting to show or hide a protected action button.
    if unit ~= "player" and RegisterStateDriver then
        RegisterStateDriver(button, "visibility", "[@" .. unit .. ",exists] show; hide")
    end

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)

    local spellTexture = button:CreateTexture(nil, "ARTWORK")
    if labelMode == "RIGHT" then
        spellTexture:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        spellTexture:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        spellTexture:SetWidth(buttonHeight)
    else
        spellTexture:SetAllPoints(button)
    end

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    if labelMode == "BOTTOM" then
        label:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
        label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        label:SetJustifyH("CENTER")
        label:SetWordWrap(false)
    elseif labelMode == "RIGHT" then
        label:SetPoint("LEFT", button, "LEFT", buttonHeight + 3, 0)
        label:SetPoint("RIGHT", button, "RIGHT", -3, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    else
        label:SetPoint("CENTER")
    end
    label:SetText(shortLabel)

    local border = AddBorder(button)

    button.simpleDispelBackground = background
    button.simpleDispelBorder = border
    button.simpleDispelSpellTexture = spellTexture
    button.simpleDispelLabel = label
    button.simpleDispelFallbackLabel = shortLabel
    button.simpleDispelUnit = unit
    button.simpleDispelHasSpell = false
    CreateRangeOverlay(button)
    AddUnitTooltip(button)
    self:ApplyTheme(button)
    return button
end

-- Every themed property is a colour or an alpha. None of them is protected, so
-- the palette can be swapped mid-combat without touching the secure surface.
function SecureButtons:ApplyTheme(button)
    if not button or not button.simpleDispelBackground then
        return
    end

    local colors = addon.Theme:Colors()
    local background = colors.buttonBackground
    button.simpleDispelBackground:SetColorTexture(
        background[1],
        background[2],
        background[3],
        background[4]
    )
    SetBorderColor(button.simpleDispelBorder, colors.buttonBorder)

    local spellTexture = button.simpleDispelSpellTexture
    spellTexture:SetAlpha(colors.spellTextureAlpha)
    if spellTexture.SetDesaturated then
        pcall(spellTexture.SetDesaturated, spellTexture, colors.spellTextureDesaturated)
    end

    ApplyLabelColor(button, colors)

    local shade = colors.stateShade
    button.simpleDispelRangeShade:SetColorTexture(shade[1], shade[2], shade[3], shade[4])
    SetBorderColor(button.simpleDispelRangeBorder, colors.outOfRangeBorder)

    local rangeMark = colors.outOfRangeMark
    button.simpleDispelRangeMark:SetTextColor(rangeMark[1], rangeMark[2], rangeMark[3], rangeMark[4])

    local cooldownMark = colors.cooldownMark
    button.simpleDispelCooldownMark:SetTextColor(
        cooldownMark[1],
        cooldownMark[2],
        cooldownMark[3],
        cooldownMark[4]
    )

    ApplyVisualState(button)
end

function SecureButtons:RaiseRangeOverlay(button, visualFrame)
    local overlay = button and button.simpleDispelRangeOverlay
    if not overlay or not overlay.SetFrameLevel then
        return
    end

    local level = 0
    if button.GetFrameLevel then
        local ok, buttonLevel = pcall(button.GetFrameLevel, button)
        if ok and type(buttonLevel) == "number" then
            level = buttonLevel
        end
    end
    if visualFrame and visualFrame.GetFrameLevel then
        local ok, visualLevel = pcall(visualFrame.GetFrameLevel, visualFrame)
        if ok and type(visualLevel) == "number" then
            level = math.max(level, visualLevel)
        end
    end

    -- Aura slots may create their own child frames above the container. Keep
    -- the mouse-disabled range layer comfortably above that visual stack.
    overlay:SetFrameLevel(level + 10)
end

function SecureButtons:SetRangeState(button, inRange)
    if not button or not button.simpleDispelRangeShade then
        return
    end

    local state = "unknown"
    if inRange == true then
        state = "in"
    elseif inRange == false then
        state = "out"
    end
    if button.simpleDispelRangeState == state then
        return
    end

    button.simpleDispelRangeState = state
    ApplyVisualState(button)
end

function SecureButtons:SetCooldownState(button, onCooldown)
    if not button or not button.simpleDispelCooldownMark then
        return
    end

    local state = "unknown"
    if onCooldown == true then
        state = "cooldown"
    elseif onCooldown == false then
        state = "ready"
    end
    if button.simpleDispelCooldownState == state then
        return
    end

    button.simpleDispelCooldownState = state
    ApplyVisualState(button)
end

function SecureButtons:SetSpell(button, spell)
    if InCombatLockdown() then
        return false, "combat-lockdown"
    end

    if spell then
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell1", spell.name)
        button.simpleDispelSpellTexture:SetTexture(spell.icon)
        button.simpleDispelSpellTexture:Show()
    else
        button:SetAttribute("type1", nil)
        button:SetAttribute("spell1", nil)
        button.simpleDispelSpellTexture:SetTexture(nil)
        button.simpleDispelSpellTexture:Hide()
    end

    button.simpleDispelHasSpell = spell ~= nil
    ApplyLabelColor(button, addon.Theme:Colors())

    return true
end
