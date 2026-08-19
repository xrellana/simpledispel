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

    button.simpleDispelRangeOverlay = overlay
    button.simpleDispelRangeShade = shade
    button.simpleDispelRangeBorder = border
    button.simpleDispelRangeMark = mark
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
    background:SetColorTexture(0.035, 0.04, 0.05, 0.92)

    local spellTexture = button:CreateTexture(nil, "ARTWORK")
    if labelMode == "RIGHT" then
        spellTexture:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        spellTexture:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        spellTexture:SetWidth(buttonHeight)
    else
        spellTexture:SetAllPoints(button)
    end
    spellTexture:SetAlpha(0.28)

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

    AddBorder(button)

    button.simpleDispelSpellTexture = spellTexture
    button.simpleDispelLabel = label
    button.simpleDispelFallbackLabel = shortLabel
    button.simpleDispelUnit = unit
    CreateRangeOverlay(button)
    AddUnitTooltip(button)
    return button
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
    if state == "out" then
        button.simpleDispelRangeShade:SetAlpha(0.52)
        SetBorderAlpha(button.simpleDispelRangeBorder, 1)
        button.simpleDispelRangeMark:SetAlpha(1)
    else
        button.simpleDispelRangeShade:SetAlpha(0)
        SetBorderAlpha(button.simpleDispelRangeBorder, 0)
        button.simpleDispelRangeMark:SetAlpha(0)
    end
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
        button.simpleDispelLabel:SetTextColor(0.82, 1, 0.82)
    else
        button:SetAttribute("type1", nil)
        button:SetAttribute("spell1", nil)
        button.simpleDispelSpellTexture:SetTexture(nil)
        button.simpleDispelSpellTexture:Hide()
        button.simpleDispelLabel:SetTextColor(1, 0.45, 0.45)
    end

    return true
end
