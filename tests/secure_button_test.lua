local addon = {}
local stateDrivers = {}
local tooltipAnchorCalls = {}

GameTooltip = {
    SetUnit = function(self, unit)
        self.unit = unit
    end,
    Show = function(self)
        self.shown = true
    end,
    Hide = function(self)
        self.shown = false
    end,
}

function GameTooltip_SetDefaultAnchor(tooltip, owner)
    tooltipAnchorCalls[#tooltipAnchorCalls + 1] = {
        tooltip = tooltip,
        owner = owner,
    }
end

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

    function region:SetColorTexture(...)
        self.colorTexture = { ... }
    end

    function region:SetDesaturated(desaturated)
        self.desaturated = desaturated
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

    function region:GetShadowColor()
        return 0, 0, 0, 1
    end

    function region:GetShadowOffset()
        return 1, -1
    end

    function region:SetShadowColor(...)
        self.shadowColor = { ... }
    end

    function region:SetShadowOffset(...)
        self.shadowOffset = { ... }
    end

    function region:SetFontObject(fontObject)
        self.fontObject = fontObject
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

local themeChunk = assert(loadfile("Theme.lua"))
themeChunk("SimpleDispel", addon)

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
assert(playerButton.simpleDispelCooldownMark.alpha == 0, "cooldown marker must start transparent")

playerButton.scripts.OnEnter(playerButton)
assert(#tooltipAnchorCalls == 1, "unit tooltip must use the default game anchor")
assert(tooltipAnchorCalls[1].tooltip == GameTooltip, "unit tooltip anchored the wrong tooltip")
assert(tooltipAnchorCalls[1].owner == playerButton, "unit tooltip owner is wrong")
assert(GameTooltip.unit == "player", "unit tooltip targets the wrong unit")
assert(GameTooltip.shown == true, "unit tooltip was not shown")
playerButton.scripts.OnLeave(playerButton)
assert(GameTooltip.shown == false, "unit tooltip was not hidden on leave")

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

addon.SecureButtons:SetCooldownState(playerButton, true)
assert(playerButton.simpleDispelCooldownState == "cooldown", "active cooldown state is wrong")
assert(playerButton.simpleDispelRangeShade.alpha == 0.32, "cooldown shade is wrong")
assert(playerButton.simpleDispelCooldownMark.alpha == 1, "cooldown marker must be visible")

addon.SecureButtons:SetRangeState(playerButton, false)
assert(playerButton.simpleDispelRangeShade.alpha == 0.52, "range shade must take visual priority")
assert(playerButton.simpleDispelRangeMark.alpha == 1, "range marker must remain visible during cooldown")
assert(playerButton.simpleDispelCooldownMark.alpha == 1, "cooldown marker must coexist with range")

addon.SecureButtons:SetRangeState(playerButton, true)
addon.SecureButtons:SetCooldownState(playerButton, false)
assert(playerButton.simpleDispelCooldownState == "ready", "ready cooldown state is wrong")
assert(playerButton.simpleDispelRangeShade.alpha == 0, "ready in-range button must not be shaded")
assert(playerButton.simpleDispelCooldownMark.alpha == 0, "ready cooldown marker must be transparent")

addon.SecureButtons:SetRangeState(playerButton, nil)
assert(playerButton.simpleDispelRangeState == "unknown", "nil range result must stay unknown")
assert(playerButton.simpleDispelRangeShade.alpha == 0, "unknown range must not be shown as out of range")
assert(playerButton.simpleDispelRangeMark.shown == nil, "combat range refresh must not show or hide protected regions")

addon.SecureButtons:SetCooldownState(playerButton, nil)
assert(playerButton.simpleDispelCooldownState == "unknown", "nil cooldown must stay unknown")
assert(playerButton.simpleDispelCooldownMark.shown == nil, "combat cooldown refresh must not show or hide protected regions")

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

-- The dark palette is the default, so everything above ran against it. The
-- light palette inverts what "unavailable" looks like: it washes a button out
-- toward the plate instead of darkening it away from a light-on-dark UI.
assert(
    playerButton.simpleDispelBackground.colorTexture[1] == 0.035,
    "dark theme button plate is wrong"
)
assert(playerButton.simpleDispelSpellTexture.alpha == 0.28, "dark theme watermark alpha is wrong")

addon.db = { theme = "light" }
addon.SecureButtons:ApplyTheme(playerButton)
assert(
    playerButton.simpleDispelBackground.colorTexture[1] == 0.93,
    "light theme did not repaint the button plate"
)
assert(
    playerButton.simpleDispelBorder[1].colorTexture[1] == 0.30,
    "a light plate needs a border darker than its fill"
)
assert(playerButton.simpleDispelSpellTexture.alpha == 0.08, "light theme watermark alpha is wrong")
assert(
    playerButton.simpleDispelSpellTexture.desaturated == true,
    "the light theme must leave the debuff icon as the only saturated object"
)
assert(
    playerButton.simpleDispelRangeShade.colorTexture[1] == 1,
    "light theme must wash unavailable buttons out, not darken them"
)
assert(
    playerButton.simpleDispelCooldownMark.textColor[1] == 0.60,
    "Blizzard amber is unreadable on a near-white plate"
)

-- A black outline around dark glyphs smears the letterform, and the black drop
-- shadow every default font carries becomes a visible offset copy on a pale
-- plate. Both read as blurred or doubled text.
local label = playerButton.simpleDispelLabel
assert(
    label.fontObject == "GameFontHighlightSmall",
    "the light theme must drop the black outline around dark label text"
)
assert(label.shadowColor[4] == 0, "a black drop shadow doubles dark text on a pale plate")
assert(
    label.shadowOffset[1] == 0 and label.shadowOffset[2] == 0,
    "the light theme must not offset the text shadow"
)
assert(
    playerButton.simpleDispelCooldownMark.shadowColor[4] == 0,
    "unoutlined markers carry the same shadow and need the same treatment"
)

addon.SecureButtons:SetRangeState(playerButton, false)
assert(playerButton.simpleDispelRangeShade.alpha == 0.55, "light out-of-range shade alpha is wrong")
addon.SecureButtons:SetRangeState(playerButton, true)
addon.SecureButtons:SetCooldownState(playerButton, true)
assert(playerButton.simpleDispelRangeShade.alpha == 0.35, "light cooldown shade alpha is wrong")

addon.db.theme = "dark"
addon.SecureButtons:ApplyTheme(playerButton)
assert(
    playerButton.simpleDispelBackground.colorTexture[1] == 0.035,
    "switching back to dark must restore the original plate"
)
assert(
    label.fontObject == "GameFontHighlightSmallOutline",
    "switching back to dark must restore the outlined label font"
)
assert(label.shadowColor[4] == 1, "switching back to dark must restore the text shadow")
assert(
    label.shadowOffset[1] == 1 and label.shadowOffset[2] == -1,
    "switching back to dark must restore the original shadow offset"
)

print("SimpleDispel secure button action: PASS")
