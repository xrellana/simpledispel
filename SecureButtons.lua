local _, addon = ...

local SecureButtons = {}
addon.SecureButtons = SecureButtons

local BUTTON_SIZE = 48
SecureButtons.BUTTON_SIZE = BUTTON_SIZE

local function AddBorder(frame)
    local function NewLine()
        local line = frame:CreateTexture(nil, "BORDER")
        line:SetColorTexture(0.12, 0.12, 0.12, 1)
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
    return button
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
