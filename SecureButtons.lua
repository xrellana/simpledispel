local _, addon = ...

local SecureButtons = {}
addon.SecureButtons = SecureButtons

local BUTTON_SIZE = 48

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

function SecureButtons:Create(parent, globalName, unit, shortLabel)
    local button = CreateFrame("Button", globalName, parent, "SecureActionButtonTemplate")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:RegisterForClicks("AnyUp")

    -- These attributes are static for the lifetime of the prototype button.
    button:SetAttribute("unit", unit)
    button:SetAttribute("type1", nil)
    button:SetAttribute("spell1", nil)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(button)
    background:SetColorTexture(0.035, 0.04, 0.05, 0.92)

    local spellTexture = button:CreateTexture(nil, "ARTWORK")
    spellTexture:SetAllPoints(button)
    spellTexture:SetAlpha(0.28)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(shortLabel)

    local unitLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unitLabel:SetPoint("BOTTOM", button, "TOP", 0, 3)
    unitLabel:SetText(unit)

    AddBorder(button)

    button.simpleDispelSpellTexture = spellTexture
    button.simpleDispelLabel = label
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
