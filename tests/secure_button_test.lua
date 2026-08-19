local addon = {}
local stateDrivers = {}

local function NewRegion()
    local region = {
        attributes = {},
    }

    function region:SetSize(width, height)
        self.width = width
        self.height = height
    end

    function region:RegisterForClicks(...)
        self.registeredClicks = { ... }
    end

    function region:SetAttribute(name, value)
        self.attributes[name] = value
    end

    function region:CreateTexture()
        return NewRegion()
    end

    function region:CreateFontString()
        return NewRegion()
    end

    function region:SetPoint()
    end

    function region:SetJustifyH()
    end

    function region:SetWordWrap()
    end

    function region:SetHeight()
    end

    function region:SetWidth()
    end

    function region:SetAllPoints()
    end

    function region:SetColorTexture()
    end

    function region:SetAlpha(alpha)
        self.alpha = alpha
    end

    function region:EnableMouse(enabled)
        self.mouseEnabled = enabled
    end

    function region:SetScript(scriptName, callback)
        self.scripts = self.scripts or {}
        self.scripts[scriptName] = callback
    end

    function region:SetFrameLevel(level)
        self.frameLevel = level
    end

    function region:GetFrameLevel()
        return self.frameLevel or 1
    end

    function region:SetText(text)
        self.text = text
    end

    function region:SetTexture(texture)
        self.texture = texture
    end

    function region:Show()
        self.shown = true
    end

    function region:Hide()
        self.shown = false
    end

    function region:SetTextColor(...)
        self.textColor = { ... }
    end

    return region
end

function CreateFrame()
    return NewRegion()
end

function RegisterStateDriver(frame, state, conditional)
    stateDrivers[#stateDrivers + 1] = {
        frame = frame,
        state = state,
        conditional = conditional,
    }
end

function InCombatLockdown()
    return false
end

local secureChunk = assert(loadfile("SecureButtons.lua"))
secureChunk("SimpleDispel", addon)

local playerButton = addon.SecureButtons:Create(
    NewRegion(),
    "SimpleDispelTestPlayerButton",
    "player",
    "YOU",
    48
)

assert(#playerButton.registeredClicks == 2, "both mouse directions must be registered")
assert(playerButton.registeredClicks[1] == "LeftButtonUp", "mouse-up registration is missing")
assert(playerButton.registeredClicks[2] == "LeftButtonDown", "mouse-down registration is missing")
assert(playerButton.attributes.unit == "player", "fixed player unit is missing")
assert(playerButton.attributes.useOnKeyDown == false, "click timing must not depend on the CVar")
assert(playerButton.simpleDispelRangeOverlay.mouseEnabled == false, "range overlay must not intercept clicks")

addon.SecureButtons:SetRangeState(playerButton, false)
assert(playerButton.simpleDispelRangeState == "out", "false range result must be out of range")
assert(playerButton.simpleDispelRangeShade.alpha == 0.52, "out-of-range shade is wrong")
assert(playerButton.simpleDispelRangeMark.alpha == 1, "out-of-range non-color marker is missing")
for _, line in ipairs(playerButton.simpleDispelRangeBorder) do
    assert(line.alpha == 1, "out-of-range border must be visible")
end

addon.SecureButtons:SetRangeState(playerButton, true)
assert(playerButton.simpleDispelRangeState == "in", "true range result must be in range")
assert(playerButton.simpleDispelRangeShade.alpha == 0, "in-range button must not be shaded")
assert(playerButton.simpleDispelRangeMark.alpha == 0, "in-range marker must be transparent")

addon.SecureButtons:SetRangeState(playerButton, nil)
assert(playerButton.simpleDispelRangeState == "unknown", "nil range result must stay unknown")
assert(playerButton.simpleDispelRangeShade.alpha == 0, "unknown range must not be shown as out of range")
assert(playerButton.simpleDispelRangeMark.shown == nil, "combat range refresh must not show or hide protected regions")

local topFrame = NewRegion()
topFrame.frameLevel = 7
addon.SecureButtons:RaiseRangeOverlay(playerButton, topFrame)
assert(playerButton.simpleDispelRangeOverlay.frameLevel == 17, "range overlay must stay above the aura frame")

local spell = {
    id = 527,
    name = "Purify",
    icon = 123,
}
local spellOK, spellError = addon.SecureButtons:SetSpell(playerButton, spell)
assert(spellOK, tostring(spellError))
assert(playerButton.attributes.type1 == "spell", "left-click action type is not spell")
assert(playerButton.attributes.spell1 == "Purify", "left-click spell attribute is wrong")

local clearOK, clearError = addon.SecureButtons:SetSpell(playerButton, nil)
assert(clearOK, tostring(clearError))
assert(playerButton.attributes.type1 == nil, "missing dispel must clear the action type")
assert(playerButton.attributes.spell1 == nil, "missing dispel must clear the spell attribute")
assert(playerButton.simpleDispelSpellTexture.texture == nil, "missing dispel must clear the spell texture")
assert(playerButton.simpleDispelSpellTexture.shown == false, "missing dispel must hide the spell texture")

local partyButton = addon.SecureButtons:Create(
    NewRegion(),
    "SimpleDispelTestPartyButton",
    "party1",
    "P1",
    48
)
assert(#stateDrivers == 1, "party button must have one visibility driver")
assert(stateDrivers[1].frame == partyButton, "visibility driver targets the wrong button")
assert(stateDrivers[1].conditional == "[@party1,exists] show; hide", "visibility condition is wrong")

local raidButton = addon.SecureButtons:Create(
    NewRegion(),
    "SimpleDispelTestRaidButton",
    "raid1",
    "",
    28,
    nil,
    28
)
assert(raidButton.width == 28, "raid button width is wrong")
assert(raidButton.height == 28, "raid button height is wrong")
assert(raidButton.simpleDispelFallbackLabel == "", "raid button must not keep a permanent label")
assert(#stateDrivers == 2, "raid button must have its own visibility driver")
assert(stateDrivers[2].conditional == "[@raid1,exists] show; hide", "raid visibility condition is wrong")

print("SimpleDispel secure button action: PASS")
