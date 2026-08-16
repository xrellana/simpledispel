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

    function region:SetAlpha()
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

local spell = {
    id = 527,
    name = "Purify",
    icon = 123,
}
local spellOK, spellError = addon.SecureButtons:SetSpell(playerButton, spell)
assert(spellOK, tostring(spellError))
assert(playerButton.attributes.type1 == "spell", "left-click action type is not spell")
assert(playerButton.attributes.spell1 == "Purify", "left-click spell attribute is wrong")

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
    "1",
    96,
    "RIGHT",
    32
)
assert(raidButton.width == 96, "raid button width is wrong")
assert(raidButton.height == 32, "raid button height is wrong")
assert(raidButton.simpleDispelFallbackLabel == "1", "raid fallback label is wrong")
assert(#stateDrivers == 2, "raid button must have its own visibility driver")
assert(stateDrivers[2].conditional == "[@raid1,exists] show; hide", "raid visibility condition is wrong")

print("SimpleDispel secure button action: PASS")
