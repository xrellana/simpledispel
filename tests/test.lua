local createdFrames = {}
local createdButtons = {}
local stateDrivers = {}
local inRaid = false
local inCombat = false
local groupMemberCount = 0
local resolvedSpell = { id = 527, name = "Purify", icon = 1, known = true, source = "auto" }
local rangeByUnit = {
    player = true,
    party1 = false,
    party2 = nil,
    party3 = true,
    party4 = true,
    raid1 = false,
}
local rangeCalls = {}
local cooldownInfo = {
    isActive = false,
    isOnGCD = false,
}
local cooldownCalls = {}

local objectMethods = {}

function objectMethods:SetPoint(...)
    self.point = { ... }
end

function objectMethods:GetPoint()
    if not self.point then
        return nil
    end
    return table.unpack(self.point)
end

function objectMethods:ClearAllPoints()
    self.point = nil
end

function objectMethods:SetScale(scale)
    self.scale = scale
end

function objectMethods:SetSize(width, height)
    self.width = width
    self.height = height
end

function objectMethods:SetHeight(height)
    self.height = height
end

function objectMethods:SetWidth(width)
    self.width = width
end

function objectMethods:SetShown(shown)
    self.shown = shown
end

function objectMethods:Show()
    self.shown = true
end

function objectMethods:Hide()
    self.shown = false
end

function objectMethods:EnableMouse(enabled)
    self.mouseEnabled = enabled
end

function objectMethods:StartMoving()
    self.moving = true
end

function objectMethods:StopMovingOrSizing()
    self.moving = false
end

function objectMethods:SetAlpha(alpha)
    self.alpha = alpha
end

function objectMethods:SetScript(scriptName, callback)
    local scripts = rawget(self, "scripts") or {}
    rawset(self, "scripts", scripts)
    scripts[scriptName] = callback
end

function objectMethods:RegisterEvent(event)
    local events = rawget(self, "events") or {}
    rawset(self, "events", events)
    events[event] = true
end

function objectMethods:UnregisterEvent(event)
    if self.events then
        self.events[event] = nil
    end
end

function objectMethods:CreateTexture()
    return setmetatable({}, getmetatable(self))
end

function objectMethods:CreateFontString()
    return setmetatable({}, getmetatable(self))
end

local objectMeta = {
    __index = function(object, key)
        local method = objectMethods[key]
        if method then
            return method
        end

        method = function(self, ...)
            local calls = rawget(self, "calls") or {}
            rawset(self, "calls", calls)
            calls[key] = { ... }
        end
        objectMethods[key] = method
        return method
    end,
}

UIParent = setmetatable({}, objectMeta)
SlashCmdList = {}

function CreateFrame(frameType, globalName, parent, template)
    local frame = setmetatable({
        frameType = frameType,
        globalName = globalName,
        parent = parent,
        template = template,
    }, objectMeta)
    createdFrames[#createdFrames + 1] = frame
    return frame
end

function RegisterStateDriver(frame, state, conditional)
    stateDrivers[#stateDrivers + 1] = {
        frame = frame,
        state = state,
        conditional = conditional,
    }
end

function InCombatLockdown()
    return inCombat
end

function IsInRaid()
    return inRaid
end

function GetNumGroupMembers()
    return groupMemberCount
end

-- Configured per-scenario via raidRosterInfo[index] = subgroup. An index with
-- no entry reports a nil subgroup, which the addon must treat the same as a
-- malformed one: the whole layout falls back to index order.
local raidRosterInfo = {}

function GetRaidRosterInfo(index)
    local subgroup = raidRosterInfo[index]
    return "RaidMember" .. index, "MEMBER", subgroup
end

function UnitExists(unit)
    if unit == "player" then
        return true
    end
    local partyIndex = string.match(unit, "^party(%d+)$")
    if partyIndex then
        return tonumber(partyIndex) <= 4
    end
    local raidIndex = string.match(unit, "^raid(%d+)$")
    if raidIndex then
        return inRaid and tonumber(raidIndex) <= groupMemberCount
    end
    return false
end

function GetBuildInfo()
    return "12.1.0", "12345", "Aug 2026", 120100
end

C_AddOns = {
    GetAddOnMetadata = function(_, field)
        if field == "Version" then
            return "1.0.0"
        end
    end,
}

C_Spell = {
    IsSpellInRange = function(spellIdentifier, unit)
        rangeCalls[#rangeCalls + 1] = { spellIdentifier = spellIdentifier, unit = unit }
        return rangeByUnit[unit]
    end,
    GetSpellCooldown = function(spellIdentifier)
        cooldownCalls[#cooldownCalls + 1] = spellIdentifier
        return cooldownInfo
    end,
}

SimpleDispelDB = {
    position = { point = "CENTER", relativePoint = "CENTER", x = 17, y = -25 },
    scale = 0.90,
}

local unitNames = {
    party1 = "Alice",
    party2 = "Bob",
    party3 = "Chen",
    party4 = "Dora",
    raid1 = "RaidAlice",
    raid40 = "RaidZed",
}

function GetUnitName(unit)
    return unitNames[unit]
end

function issecretvalue()
    return false
end

-- The most recent visibility conditional registered for a root frame, which is
-- the one the secure state driver is currently evaluating.
local function CurrentVisibility(globalName)
    local conditional
    local frame
    for _, driver in ipairs(stateDrivers) do
        if driver.frame.globalName == globalName and driver.state == "visibility" then
            conditional = driver.conditional
            frame = driver.frame
        end
    end
    return conditional, frame
end

local addon = {}
addon.SecureButtons = {
    BUTTON_SIZE = 48,
    LABEL_BAND_HEIGHT = 14,
    Create = function(_, parent, globalName, unit, label, width, labelMode, height)
        local button = CreateFrame("Button", globalName, parent, "SecureActionButtonTemplate")
        button.unit = unit
        button.label = label
        button.requestedWidth = width
        button.requestedHeight = height or width
        button.labelMode = labelMode
        button.simpleDispelFallbackLabel = label
        button.simpleDispelLabel = {
            text = label,
            SetText = function(self, text)
                self.text = text
            end,
        }
        createdButtons[#createdButtons + 1] = button
        return button
    end,
    SetNameBandShown = function(_, button, shown)
        if InCombatLockdown() then
            return false, "combat-lockdown"
        end
        button.nameBandShown = shown
        button:SetHeight(button.requestedHeight - (shown and 0 or 14))
        return true
    end,
    RaiseRangeOverlay = function(_, button)
        button.rangeOverlayRaised = true
    end,
    SetRangeState = function(_, button, inRange)
        if inRange == true then
            button.simpleDispelRangeState = "in"
        elseif inRange == false then
            button.simpleDispelRangeState = "out"
        else
            button.simpleDispelRangeState = "unknown"
        end
    end,
    SetCooldownState = function(_, button, onCooldown)
        if onCooldown == true then
            button.simpleDispelCooldownState = "cooldown"
        elseif onCooldown == false then
            button.simpleDispelCooldownState = "ready"
        else
            button.simpleDispelCooldownState = "unknown"
        end
    end,
    SetSpell = function(_, button, spell)
        button.spell = spell
        return true
    end,
    ApplyTheme = function(_, button)
        rawset(button, "themeApplications", (rawget(button, "themeApplications") or 0) + 1)
    end,
}

addon.AuraDisplay = {
    Filters = {
        mine = "HARMFUL|RAID",
        group = "HARMFUL|RAID_PLAYER_DISPELLABLE",
        all = "HARMFUL|DISPELLABLE",
    },
    GetFilter = function(self, mode)
        return self.Filters[mode] or self.Filters.mine
    end,
    IsSupported = function()
        return true
    end,
    Create = function(_, button, unit, filter, options)
        return {
            button = button,
            unit = unit,
            filter = filter,
            options = options,
        }
    end,
}

addon.Spells = {
    Candidates = {
        PRIEST = { 527 },
    },
    Resolve = function()
        return resolvedSpell
    end,
    GetInfo = function(_, spellID)
        if spellID ~= 527 then
            return nil
        end
        return { id = spellID, name = "Purify", icon = 1, known = true }
    end,
}

function UnitClass()
    return "PRIEST", "PRIEST"
end

local settingsMockChunk = assert(loadfile("tests/settings_mock.lua"))
settingsMockChunk()

local themeChunk = assert(loadfile("Theme.lua"))
themeChunk("SimpleDispel", addon)

local coreChunk = assert(loadfile("Core.lua"))
coreChunk("SimpleDispel", addon)

local optionsChunk = assert(loadfile("Options.lua"))
optionsChunk("SimpleDispel", addon)

local eventFrame
for _, frame in ipairs(createdFrames) do
    if frame.events and frame.events.ADDON_LOADED then
        eventFrame = frame
        break
    end
end
assert(eventFrame, "ADDON_LOADED event frame was not created")

eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "SimpleDispel")

-- The options module registers one native Settings category during the same
-- ADDON_LOADED transaction as Core.  Registering again must be idempotent so
-- opening the panel or a reload cannot create duplicate categories.
local options = addon.Options
assert(options and options.settings, "options module did not attach to the addon")
local optionsCategory = Settings.GetCategory("SimpleDispel")
assert(optionsCategory, "SimpleDispel Settings category was not created")
assert(#Settings.categories == 1, "options must create exactly one Settings category")
assert(#Settings.registeredCategories == 1, "options category was not registered")
assert(optionsCategory.registered == true, "options category was not registered as an addon category")
local registeredCategoryCount = #Settings.registeredCategories
local categoryCount = #Settings.categories
assert(options:Register() == true, "re-registering options should succeed")
assert(#Settings.categories == categoryCount, "options re-registration duplicated the category")
assert(#Settings.registeredCategories == registeredCategoryCount, "options re-registration duplicated registration")

local function OptionSetting(key)
    local setting = options.settings[key]
    assert(setting, "missing options setting: " .. key)
    return setting
end

local function OptionValue(key)
    return OptionSetting(key):GetValue()
end

assert(OptionValue("Locked") == false, "locked option did not read the migrated default")
assert(OptionValue("Theme") == "dark", "theme option did not read the migrated default")
assert(OptionValue("PartyNames") == true, "party names option did not read the migrated default")
assert(OptionValue("ShowWithoutDispel") == false, "no-dispel option did not read the migrated default")
assert(OptionValue("PartyScale") == 90, "party scale option did not read the migrated legacy scale")
assert(OptionValue("RaidScale") == 100, "raid scale option did not read its default")
assert(OptionValue("RaidLayout") == "across", "raid layout option did not read its migrated default")
assert(OptionValue("FilterMode") == "mine", "filter option did not read its default")
assert(OptionValue("SpellID") == 0, "spell option did not represent automatic detection as zero")

local partyScaleControl = OptionSetting("PartyScale").control
local partyScaleOptions = partyScaleControl.arguments[1]
assert(partyScaleControl.type == "slider", "party scale must use a slider control")
assert(partyScaleOptions.minimumValue == 60, "party scale minimum is wrong")
assert(partyScaleOptions.maximumValue == 200, "party scale maximum is wrong")
assert(partyScaleOptions.valueStep == 1, "party scale step is wrong")
assert(OptionSetting("Locked").control.type == "checkbox", "locked must use a checkbox")
assert(OptionSetting("Theme").control.type == "dropdown", "theme must use a dropdown")
assert(OptionSetting("RaidLayout").control.type == "dropdown", "raid layout must use a dropdown")
assert(OptionSetting("SpellID").control.type == "dropdown", "spell selection must use a dropdown")

local spellChoices = options:GetSpellChoices()
assert(spellChoices[1].value == 0, "spell choices must put automatic detection first")
assert(spellChoices[2].value == 527, "spell choices must include the known candidate spell")

local notifyBeforeOpen = OptionSetting("Theme").notifyCount
SlashCmdList.SIMPLEDISPEL("options")
assert(Settings.openedCategory == optionsCategory:GetID(), "options command opened the wrong category")
assert(OptionSetting("Theme").notifyCount > notifyBeforeOpen, "opening options must refresh setting values")
local notifyAfterOptions = OptionSetting("Theme").notifyCount
local setCallsBeforeOpen = OptionSetting("Theme").setCalls
SlashCmdList.SIMPLEDISPEL("")
assert(Settings.openedCategory == optionsCategory:GetID(), "bare slash command must open the options category")
assert(OptionSetting("Theme").notifyCount > notifyAfterOptions, "bare slash command must refresh settings")
assert(OptionSetting("Theme").setCalls == setCallsBeforeOpen, "refresh must not call option setters")

assert(SimpleDispelDB.schemaVersion == 7, "database schema was not upgraded")
assert(SimpleDispelDB.showWithoutDispel == false, "a database without the option must hide frames without a dispel")
assert(SimpleDispelDB.raidLayout == "across", "a database without a raid layout must default to across")
assert(SimpleDispelDB.theme == "dark", "a database without a theme must upgrade to dark")
assert(addon.Theme:GetActive() == "dark", "dark must be the default theme")
assert(
    addon.frames.party.background.calls.SetColorTexture[1] == 0.015,
    "party frame did not receive the dark root background"
)
assert(
    rawget(createdButtons[1], "themeApplications") == nil,
    "building the frames must not go through the frame-wide theme pass"
)

SlashCmdList.SIMPLEDISPEL("theme light")
assert(SimpleDispelDB.theme == "light", "theme command did not persist")
assert(
    addon.frames.party.background.calls.SetColorTexture[1] == 0.88,
    "light theme did not repaint the party root background"
)
assert(
    addon.frames.raid.background.calls.SetColorTexture[1] == 0.88,
    "a theme switch must repaint every frame, not only the active one"
)

local themedBefore = rawget(createdButtons[1], "themeApplications")
SlashCmdList.SIMPLEDISPEL("theme neon")
assert(SimpleDispelDB.theme == "light", "an unknown theme name must not be stored")
assert(themedBefore == 1, "the theme command must repaint every unit button")
assert(
    rawget(createdButtons[1], "themeApplications") == themedBefore,
    "a rejected theme must not repaint the buttons"
)

-- Every themed property is a colour or an alpha, so unlike the layout commands
-- this one must not defer its work until combat ends.
inCombat = true
SlashCmdList.SIMPLEDISPEL("theme dark")
inCombat = false
assert(SimpleDispelDB.theme == "dark", "theme must switch during combat")
assert(
    addon.frames.party.background.calls.SetColorTexture[1] == 0.015,
    "in-combat theme switch did not repaint the root background"
)
assert(
    addon.pendingLayoutRefresh == false,
    "a theme switch must not queue a deferred layout refresh"
)
assert(SimpleDispelDB.layouts.party.scale == 0.90, "party scale migration failed")
assert(SimpleDispelDB.layouts.party.position.x == 17, "party position migration failed")
assert(SimpleDispelDB.layouts.raid.scale == 1.00, "raid default scale is wrong")
assert(eventFrame.events.SPELL_UPDATE_COOLDOWN, "spell cooldown event was not registered")
assert(#createdButtons == 45, "expected 5 party and 40 raid buttons")
assert(createdButtons[1].unit == "player", "first party unit must be player")
assert(createdButtons[5].unit == "party4", "fifth party unit must be party4")
assert(createdButtons[6].unit == "raid1", "first raid unit must be raid1")
assert(createdButtons[45].unit == "raid40", "last raid unit must be raid40")
assert(createdButtons[1].requestedWidth == 48, "party button width is wrong")
assert(createdButtons[1].requestedHeight == 62, "party button height is wrong")
assert(createdButtons[6].requestedWidth == 28, "raid button width is wrong")
assert(createdButtons[6].requestedHeight == 28, "raid button height is wrong")
assert(#addon.auraContainers == 45, "every unit must get one aura container")
assert(createdButtons[2].simpleDispelLabel.text == "Alice", "party1 name label was not updated")
assert(createdButtons[5].simpleDispelLabel.text == "Dora", "party4 name label was not updated")
assert(createdButtons[6].simpleDispelLabel.text == "", "raid1 must not keep a permanent name")
assert(createdButtons[45].simpleDispelLabel.text == "", "raid40 must not keep a permanent name")
assert(rawget(createdButtons[6], "labelMode") == nil, "compact raid button must not reserve a name area")
assert(addon.auraContainers[6].options.width == 28, "raid aura width is wrong")
assert(addon.auraContainers[6].options.height == 28, "raid aura height is wrong")
assert(addon.auraContainers[6].options.anchor == "CENTER", "raid aura must fill the compact square")
-- The party aura covers the square icon area at the top of the button instead
-- of the whole cell, so the name band below it can be collapsed without moving
-- a debuff icon whose geometry is fixed when the aura button is created.
assert(addon.auraContainers[1].options.height == 48, "party aura must cover the icon square only")
assert(addon.auraContainers[1].options.anchor == "TOP", "party aura must sit at the top of the button")
assert(
    (addon.auraContainers[1].options.iconBottomInset or 0) == 0,
    "a top-anchored party aura reserves no band inside its own icon area"
)
assert(createdButtons[6].rangeOverlayRaised, "range overlay must be raised above the aura")

local raid1Point = createdButtons[6].point
local raid8Point = createdButtons[13].point
local raid9Point = createdButtons[14].point
local raid40Point = createdButtons[45].point
assert(raid1Point[5] == raid8Point[5], "raid1 through raid8 must stay in the first row")
assert(raid1Point[4] == raid9Point[4], "raid9 must return to the first column")
assert(raid9Point[5] < raid1Point[5], "raid9 must start the second row")
assert(raid40Point[4] == raid8Point[4], "raid40 must stay in the eighth column")
assert(raid40Point[5] < raid9Point[5], "raid40 must stay in the fifth row")

-- No spell is resolved until PLAYER_LOGIN, so the roots start hidden and a
-- character without a dispel never flashes an empty frame on login.
local partyVisibility = CurrentVisibility("SimpleDispelPartyFrame")
local raidVisibility, raidRoot = CurrentVisibility("SimpleDispelRaidFrame")
assert(partyVisibility == "hide", "party frame must start hidden before a dispel is resolved")
assert(raidVisibility == "hide", "raid frame must start hidden before a dispel is resolved")
assert(#stateDrivers == 2, "each root must register exactly one visibility driver while it is built")
assert(raidRoot.width == 246, "compact raid frame width is wrong")
assert(addon.frames.party.root.height == 70, "party frame must fit the name band without a title bar")
assert(createdButtons[1].point[5] == -4, "party grid must not reserve title space")

-- Party names are shown by default, so an upgrade keeps the 1.3.x appearance.
assert(SimpleDispelDB.hidePartyNames == false, "party names must be shown by default")
assert(createdButtons[1].nameBandShown == true, "party buttons must be built with their name band")

SlashCmdList.SIMPLEDISPEL("names hide")
assert(SimpleDispelDB.hidePartyNames == true, "names command did not persist")
assert(createdButtons[1].nameBandShown == false, "hiding names did not collapse the player band")
assert(createdButtons[5].nameBandShown == false, "hiding names did not collapse the party4 band")
assert(createdButtons[1].height == 48, "a party button without its name band must be square")
assert(addon.frames.party.root.height == 56, "the party frame must shrink with the collapsed band")
assert(
    rawget(createdButtons[6], "nameBandShown") == nil,
    "raid squares carry no name band and must not be resized"
)

SlashCmdList.SIMPLEDISPEL("names show")
assert(SimpleDispelDB.hidePartyNames == false, "showing names again did not persist")
assert(createdButtons[1].height == 62, "restoring the band must restore the button height")
assert(addon.frames.party.root.height == 70, "restoring the band must restore the frame height")

SlashCmdList.SIMPLEDISPEL("names sideways")
assert(SimpleDispelDB.hidePartyNames == false, "an unrecognised names argument must change nothing")

-- Collapsing the band resizes protected action buttons, so unlike a theme
-- switch it has to wait for combat to end.
inCombat = true
SlashCmdList.SIMPLEDISPEL("names hide")
assert(addon.pendingNameBandRefresh == true, "combat name band change was not deferred")
assert(addon.frames.party.root.height == 70, "party frame resized during combat")
assert(createdButtons[1].height == 62, "party button resized during combat")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(addon.pendingNameBandRefresh == false, "deferred name band change was not applied")
assert(addon.frames.party.root.height == 56, "deferred name band change did not resize the frame")
SlashCmdList.SIMPLEDISPEL("names show")
assert(addon.frames.raid.dragHandle.width == 16, "raid drag handle must stay narrow")
assert(addon.frames.raid.dragHandle.height == 28, "raid drag handle height is wrong")
assert(addon.frames.raid.dragHandle.point[1] == "TOPRIGHT" and addon.frames.raid.dragHandle.point[3] == "TOPLEFT", "raid handle must sit outside the grid")
assert(raidRoot.calls.SetClampRectInsets[1] == -16, "screen clamping must include the external handle")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
assert(addon.activeSpell and addon.activeSpell.id == 527, "spell was not assigned at login")
assert(
    CurrentVisibility("SimpleDispelPartyFrame") == "[group:raid] hide; show",
    "party visibility driver is wrong"
)
assert(
    CurrentVisibility("SimpleDispelRaidFrame") == "[group:raid] show; hide",
    "raid visibility driver is wrong"
)
local driversAfterLogin = #stateDrivers
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_ENTERING_WORLD")
assert(#stateDrivers == driversAfterLogin, "an unchanged dispel must not re-register the visibility drivers")
assert(createdButtons[45].spell and createdButtons[45].spell.id == 527, "raid spell assignment failed")
assert(addon.frames.party.content.shown == true, "party buttons must be shown when a dispel is available")
assert(addon.frames.party.emptyState.shown == false, "party empty state must be hidden when a dispel is available")
assert(addon.frames.raid.content.shown == true, "raid buttons must be shown when a dispel is available")
assert(addon.frames.raid.emptyState.shown == false, "raid empty state must be hidden when a dispel is available")
assert(createdButtons[1].simpleDispelRangeState == "in", "player range state is wrong")
assert(createdButtons[2].simpleDispelRangeState == "out", "party1 range state is wrong")
assert(createdButtons[3].simpleDispelRangeState == "unknown", "nil range must stay unknown")
assert(createdButtons[1].simpleDispelCooldownState == "ready", "dispel must start ready")

cooldownInfo = { isActive = true, isOnGCD = true }
addon.dispelCooldownActive = nil
addon:RefreshCooldownState(false)
assert(createdButtons[1].simpleDispelCooldownState == "unknown", "non-event GCD state must remain unknown")
eventFrame.scripts.OnEvent(eventFrame, "SPELL_UPDATE_COOLDOWN", 61304)
assert(createdButtons[1].simpleDispelCooldownState == "ready", "global cooldown must not dim dispels")

cooldownInfo = { isActive = true, isOnGCD = false }
inCombat = true
eventFrame.scripts.OnEvent(eventFrame, "SPELL_UPDATE_COOLDOWN", 527)
assert(createdButtons[1].simpleDispelCooldownState == "cooldown", "real dispel cooldown was not shown")
assert(createdButtons[45].simpleDispelCooldownState == "cooldown", "raid cooldown state was not synchronized")
assert(addon.frames.party.content.shown == true, "cooldown must not hide dispellable units")
assert(cooldownCalls[#cooldownCalls] == "Purify", "cooldown query must use the secure dispel spell")
inCombat = false

cooldownInfo = nil
rangeCalls = {}
rangeByUnit.party1 = true
eventFrame.scripts.OnUpdate(eventFrame, 0.24)
assert(#rangeCalls == 0, "range refresh ran before 0.25 seconds")
eventFrame.scripts.OnUpdate(eventFrame, 0.01)
assert(#rangeCalls == 5, "party range refresh must query five existing units")
assert(rangeCalls[1].spellIdentifier == "Purify", "range check must use the secure button's actual spell")
assert(createdButtons[2].simpleDispelRangeState == "in", "periodic range refresh did not update party1")
assert(createdButtons[1].simpleDispelCooldownState == "cooldown", "unknown cooldown result must preserve confirmed state")

cooldownInfo = { isActive = false, isOnGCD = false }
eventFrame.scripts.OnUpdate(eventFrame, 0.24)
assert(createdButtons[1].simpleDispelCooldownState == "cooldown", "cooldown cleared before the polling interval")
eventFrame.scripts.OnUpdate(eventFrame, 0.01)
assert(createdButtons[1].simpleDispelCooldownState == "ready", "cooldown polling did not restore readiness")

resolvedSpell = nil
inCombat = true
eventFrame.scripts.OnEvent(eventFrame, "SPELLS_CHANGED")
assert(addon.pendingSpellRefresh == true, "combat spell change must defer availability updates")
assert(addon.frames.party.content.shown == true, "party buttons must not be hidden during combat")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(addon.activeSpell == nil, "missing dispel must clear the active spell")
assert(addon.pendingVisibilityRefresh == false, "the deferred spell refresh must also apply visibility")
assert(CurrentVisibility("SimpleDispelPartyFrame") == "hide", "party frame must be hidden without a dispel")
assert(CurrentVisibility("SimpleDispelRaidFrame") == "hide", "raid frame must be hidden without a dispel")
assert(addon.frames.party.content.shown == false, "party buttons must be hidden without a dispel")
assert(addon.frames.raid.content.shown == false, "raid buttons must be hidden without a dispel")
assert(createdButtons[1].simpleDispelCooldownState == "unknown", "missing dispel must clear cooldown state")
rangeCalls = {}
eventFrame.scripts.OnUpdate(eventFrame, 1)
assert(#rangeCalls == 0, "range refresh must stop without an active dispel")

-- /sd nodispel show brings back the explanatory empty state from 1.5.x.
SlashCmdList.SIMPLEDISPEL("nodispel show")
assert(SimpleDispelDB.showWithoutDispel == true, "nodispel show did not persist")
assert(
    CurrentVisibility("SimpleDispelPartyFrame") == "[group:raid] hide; show",
    "nodispel show must restore the party group driver"
)
assert(
    CurrentVisibility("SimpleDispelRaidFrame") == "[group:raid] show; hide",
    "nodispel show must restore the raid group driver"
)
assert(addon.frames.party.emptyState.shown == true, "party empty state must explain the missing dispel")
assert(addon.frames.raid.emptyState.shown == true, "raid empty state must explain the missing dispel")
assert(addon.frames.raid.root.height == 70, "raid empty state must use a compact height")

SlashCmdList.SIMPLEDISPEL("nodispel sideways")
assert(SimpleDispelDB.showWithoutDispel == true, "an unrecognised nodispel argument must change nothing")

-- Re-registering a driver on a root that parents protected buttons is blocked
-- in combat, so the switch waits for combat to end.
inCombat = true
SlashCmdList.SIMPLEDISPEL("nodispel hide")
assert(SimpleDispelDB.showWithoutDispel == false, "the setting is stored immediately even in combat")
assert(addon.pendingVisibilityRefresh == true, "a combat visibility change must be deferred")
assert(
    CurrentVisibility("SimpleDispelPartyFrame") == "[group:raid] hide; show",
    "the party driver must not change during combat"
)
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(addon.pendingVisibilityRefresh == false, "deferred visibility change was not applied")
assert(CurrentVisibility("SimpleDispelPartyFrame") == "hide", "deferred nodispel hide did not hide the party frame")
assert(CurrentVisibility("SimpleDispelRaidFrame") == "hide", "deferred nodispel hide did not hide the raid frame")

resolvedSpell = { id = 527, name = "Purify", icon = 1, known = true, source = "auto" }
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
assert(addon.activeSpell and addon.activeSpell.id == 527, "spec change must restore the detected dispel")
assert(addon.frames.party.content.shown == true, "party buttons must return after dispel detection")
assert(addon.frames.party.emptyState.shown == false, "party empty state must clear after dispel detection")
assert(
    CurrentVisibility("SimpleDispelPartyFrame") == "[group:raid] hide; show",
    "a newly detected dispel must bring the party frame back"
)
assert(
    CurrentVisibility("SimpleDispelRaidFrame") == "[group:raid] show; hide",
    "a newly detected dispel must bring the raid frame back"
)

-- With a dispel available the option changes nothing that is on screen.
local driversWithDispel = #stateDrivers
SlashCmdList.SIMPLEDISPEL("nodispel show")
SlashCmdList.SIMPLEDISPEL("nodispel hide")
assert(#stateDrivers == driversWithDispel, "nodispel must not touch frames while a dispel is available")

SlashCmdList.SIMPLEDISPEL("scale raid 0.75")
assert(SimpleDispelDB.layouts.raid.scale == 0.75, "explicit raid scale command failed")

inRaid = true
local raidHeightCases = {
    { members = 1, height = 36 },
    { members = 8, height = 36 },
    { members = 9, height = 66 },
    { members = 16, height = 66 },
    { members = 17, height = 96 },
    { members = 25, height = 126 },
    { members = 32, height = 126 },
    { members = 33, height = 156 },
    { members = 40, height = 156 },
    { members = 25, height = 126 },
}
for _, case in ipairs(raidHeightCases) do
    groupMemberCount = case.members
    eventFrame.scripts.OnEvent(eventFrame, "GROUP_ROSTER_UPDATE")
    assert(raidRoot.height == case.height, case.members .. "-player raid frame height is wrong")
end
assert(createdButtons[6].simpleDispelRangeState == "out", "raid1 range state was not refreshed")
assert(createdButtons[31].simpleDispelRangeState == "unknown", "missing raid units must not keep a stale range state")

local unlockedRaidY = createdButtons[6].point[5]
SlashCmdList.SIMPLEDISPEL("lock")
assert(SimpleDispelDB.locked == true, "lock command did not persist")
assert(addon.frames.raid.dragHandle.shown == false, "locked raid handle must be hidden")
assert(addon.frames.raid.background.shown == false, "locked raid background must be hidden")
assert(raidRoot.height == 126, "locked 25-player raid height is wrong")
assert(createdButtons[6].point[5] == -4, "raid grid must have no title space")
SlashCmdList.SIMPLEDISPEL("unlock")
assert(SimpleDispelDB.locked == false, "unlock command did not persist")
assert(addon.frames.raid.dragHandle.shown == true, "unlocked raid handle must accept hover")
assert(addon.frames.raid.background.shown == false, "unlocked raid background must stay hidden")
assert(raidRoot.height == 126, "unlock must not add title space")
assert(createdButtons[6].point[5] == unlockedRaidY, "unlock must not shift the raid grid")
SlashCmdList.SIMPLEDISPEL("scale 0.80")
assert(SimpleDispelDB.layouts.raid.scale == 0.80, "active raid scale command failed")

SlashCmdList.SIMPLEDISPEL("reset all")
assert(SimpleDispelDB.layouts.party.scale == 1.00, "party reset failed")
assert(SimpleDispelDB.layouts.raid.scale == 1.00, "raid reset failed")

inCombat = true
groupMemberCount = 40
eventFrame.scripts.OnEvent(eventFrame, "GROUP_ROSTER_UPDATE")
assert(addon.pendingRaidSizeRefresh, "combat raid resize was not deferred")
assert(raidRoot.height == 126, "raid frame resized during combat")
SlashCmdList.SIMPLEDISPEL("scale raid 0.85")
assert(addon.pendingLayoutRefresh, "combat layout update was not deferred")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(not addon.pendingLayoutRefresh, "deferred layout update was not applied")
assert(not addon.pendingRaidSizeRefresh, "deferred raid resize was not applied")
assert(raidRoot.height == 156, "40-player raid frame must use five rows")

assert(eventFrame.events.PLAYER_REGEN_DISABLED, "combat start event was not registered")

-- Subgroup-sorted raid layout -------------------------------------------------
-- raid1 is createdButtons[6] (five party buttons come first); this indexes
-- straight into the raid roster position for a given raid unit index.
local function RaidPoint(raidIndex)
    return createdButtons[5 + raidIndex].point
end

-- Scenario 1: three full groups of five, "across" (the default orientation).
raidRosterInfo = {}
for i = 1, 5 do raidRosterInfo[i] = 1 end
for i = 6, 10 do raidRosterInfo[i] = 2 end
for i = 11, 15 do raidRosterInfo[i] = 3 end
groupMemberCount = 15
SlashCmdList.SIMPLEDISPEL("raidlayout across")

assert(addon.raidGroupsUnavailable == false, "a fully valid roster must not report subgroups unavailable")
assert(RaidPoint(1)[4] == RaidPoint(5)[4], "raid1 through raid5 must share a column in across mode")
assert(RaidPoint(1)[5] ~= RaidPoint(2)[5], "members within a group occupy distinct rows")
assert(RaidPoint(6)[4] ~= RaidPoint(1)[4], "raid6 must start the next occupied column")
assert(RaidPoint(6)[5] == RaidPoint(1)[5], "the first member of every group starts at row 0")
assert(raidRoot.width == 96, "three occupied groups across must produce a three-column frame")
assert(raidRoot.height == 156, "a five-member group must produce a five-row frame")

-- Scenario 2: the same roster transposed with "down".
SlashCmdList.SIMPLEDISPEL("raidlayout down")
assert(RaidPoint(1)[5] == RaidPoint(2)[5], "down mode holds the first member of every group on row 0")
assert(RaidPoint(1)[4] ~= RaidPoint(2)[4], "down mode spreads a group's members across columns")
assert(RaidPoint(6)[5] ~= RaidPoint(1)[5], "down mode starts the next occupied group on its own row")
assert(RaidPoint(6)[4] == RaidPoint(1)[4], "down mode returns every group to column 0")
assert(raidRoot.width == 156, "down mode sizes columns to the largest group")
assert(raidRoot.height == 96, "down mode sizes rows to the occupied group count")

-- Scenario 3: compression. Groups 1, 2 and 5 are occupied; group 5 must land
-- in the third column, not the fifth, and groups 3/4 leave no gap behind.
SlashCmdList.SIMPLEDISPEL("raidlayout across")
raidRosterInfo = {}
for i = 1, 5 do raidRosterInfo[i] = 1 end
for i = 6, 10 do raidRosterInfo[i] = 2 end
raidRosterInfo[11] = 5
groupMemberCount = 11
eventFrame.scripts.OnEvent(eventFrame, "GROUP_ROSTER_UPDATE")

assert(RaidPoint(1)[4] == 4, "group 1 must anchor at column 0")
assert(RaidPoint(6)[4] == 34, "group 2 must anchor at column 1")
assert(RaidPoint(11)[4] == 64, "group 5 must compress into column 2 instead of column 4")
assert(raidRoot.width == 96, "compression must still only report three occupied columns")
assert(raidRoot.height == 156, "the largest occupied group still drives the row count")

-- Scenario 4: a non-full group leaves its trailing rows empty and must not
-- pull the next group's members up into them.
raidRosterInfo = {}
for i = 1, 3 do raidRosterInfo[i] = 1 end
for i = 4, 8 do raidRosterInfo[i] = 2 end
groupMemberCount = 8
eventFrame.scripts.OnEvent(eventFrame, "GROUP_ROSTER_UPDATE")

assert(RaidPoint(4)[4] ~= RaidPoint(1)[4], "group 2 must occupy its own column")
assert(RaidPoint(4)[5] == RaidPoint(1)[5], "group 2 still starts at row 0 regardless of group 1's size")
assert(
    RaidPoint(1)[5] ~= RaidPoint(2)[5] and RaidPoint(2)[5] ~= RaidPoint(3)[5],
    "the short group's three members occupy three consecutive rows"
)
assert(raidRoot.width == 66, "two occupied groups must use two columns")
assert(raidRoot.height == 156, "the larger group still drives the row count")

raidRosterInfo = { [1] = 1 }
groupMemberCount = 1
eventFrame.scripts.OnEvent(eventFrame, "GROUP_ROSTER_UPDATE")
assert(raidRoot.width == 36, "one occupied group must not reserve a second column for the old title")

-- Scenario 5: fallback. One malformed subgroup value must restore the old
-- index-order grid for the entire roster, not just the bad entry.
raidRosterInfo = { [1] = 1, [2] = 2, [3] = 9, [4] = 1, [5] = 2 }
groupMemberCount = 5
eventFrame.scripts.OnEvent(eventFrame, "GROUP_ROSTER_UPDATE")

assert(addon.raidGroupsUnavailable == true, "an out-of-range subgroup must fall back to index order")
assert(RaidPoint(1)[5] == RaidPoint(2)[5], "the index-order fallback keeps a small roster on row 0")
assert(RaidPoint(1)[4] ~= RaidPoint(2)[4], "the index-order fallback still spreads members across columns")
assert(raidRoot.width == 156, "the fallback grid still sizes width from the member count")
assert(raidRoot.height == 36, "the fallback grid still sizes height from the member count")

local layoutBeforeInvalidArgument = addon.db.raidLayout
SlashCmdList.SIMPLEDISPEL("raidlayout sideways")
assert(addon.db.raidLayout == layoutBeforeInvalidArgument, "an invalid raidlayout argument must not change the setting")

inCombat = true
SlashCmdList.SIMPLEDISPEL("raidlayout down")
assert(addon.db.raidLayout == "down", "the setting is stored immediately even though the layout is deferred")
assert(addon.pendingLayoutRefresh == true, "a raid layout change during combat must defer the reposition")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(not addon.pendingLayoutRefresh, "deferred raid layout change must apply once combat ends")

-- The side handle appears on hover, stays visible through a drag, and never
-- leaves a drag or stale highlight running through lock, hide, or combat.
local raidInfo = addon.frames.raid
local raidHandle = raidInfo.dragHandle
assert(raidInfo.handleBackground.alpha == 0 and raidInfo.title.alpha == 0, "idle handle artwork must be invisible")
assert(raidHandle.mouseEnabled == true, "idle unlocked handle must receive hover")
raidHandle.scripts.OnEnter()
assert(raidInfo.handleBackground.alpha == 1 and raidInfo.title.alpha == 1, "hover must reveal the handle")
raidHandle.scripts.OnLeave()
assert(raidInfo.handleBackground.alpha == 0, "leaving an idle handle must hide its artwork")
raidHandle.scripts.OnEnter()
raidHandle.scripts.OnDragStart()
raidHandle.scripts.OnLeave()
assert(raidRoot.moving == true and raidInfo.handleBackground.alpha == 1, "drag must remain visible after leaving the handle")
raidRoot:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 140, -90)
raidHandle.scripts.OnDragStop()
assert(raidRoot.moving == false and raidInfo.handleBackground.alpha == 0, "release outside must stop and hide the handle")
assert(SimpleDispelDB.layouts.raid.position.x == 140, "raid drag must save position")
raidHandle.scripts.OnEnter()
raidHandle.scripts.OnDragStart()
raidHandle.scripts.OnDragStop()
assert(raidInfo.handleBackground.alpha == 1, "release while hovered must keep the handle visible")
raidHandle.scripts.OnDragStart()
SlashCmdList.SIMPLEDISPEL("lock")
assert(raidRoot.moving == false and raidHandle.mouseEnabled == false, "lock mid-drag must stop movement and disable the handle")
raidHandle.scripts.OnDragStart()
assert(raidRoot.moving == false, "locked raid cannot start a drag")
SlashCmdList.SIMPLEDISPEL("unlock")
raidHandle.scripts.OnDragStart()
inCombat = true
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_DISABLED")
assert(raidRoot.moving == false and raidInfo.handleBackground.alpha == 0, "combat entry must stop dragging and hide artwork")
assert(raidHandle.mouseEnabled == false, "combat handle must not intercept mouse input")
raidHandle.scripts.OnDragStart()
assert(raidRoot.moving == false, "combat must block raid dragging")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(raidHandle.mouseEnabled == true, "combat exit must restore hover")
raidHandle.scripts.OnEnter()
raidHandle.scripts.OnDragStart()
raidRoot.scripts.OnHide()
assert(raidRoot.moving == false and raidInfo.handleBackground.alpha == 0, "root hide must stop drag and clear hover")
raidHandle.scripts.OnEnter()
raidHandle.scripts.OnDragStart()
raidHandle.scripts.OnHide()
assert(raidRoot.moving == false and raidInfo.handleBackground.alpha == 0, "handle hide must stop drag and clear hover")

-- A drag left running keeps the frame on the cursor, so its unit buttons cover
-- whatever the player points at and targeting stops working entirely.
local partyRoot = addon.frames.party.root
local partyHandle = addon.frames.party.dragHandle
local partyInfo = addon.frames.party
assert(partyHandle.width == 16 and partyHandle.height == 28, "party handle must match the compact raid handle")
assert(partyHandle.point[1] == "TOPRIGHT" and partyHandle.point[3] == "TOPLEFT", "party handle must sit outside the grid")
assert(partyRoot.calls.SetClampRectInsets[1] == -16, "party screen clamping must include the handle")
assert(partyInfo.handleBackground.alpha == 0 and partyInfo.title.alpha == 0, "party handle must start invisible")
assert(partyInfo.background.shown == false, "normal party layout must have no large background")
partyHandle.scripts.OnEnter()
assert(partyInfo.handleBackground.alpha == 1 and partyInfo.title.alpha == 1, "party hover must reveal handle artwork")
assert(raidInfo.handleBackground.alpha == 0, "party hover must not reveal the raid handle")
partyHandle.scripts.OnLeave()
assert(partyInfo.handleBackground.alpha == 0, "party pointer leave must hide idle artwork")
partyHandle.scripts.OnEnter()
partyHandle.scripts.OnDragStart()
partyHandle.scripts.OnLeave()
assert(partyRoot.moving == true and partyInfo.handleBackground.alpha == 1, "party handle must remain visible during drag")
partyHandle.scripts.OnDragStop()
assert(partyRoot.moving == false and partyInfo.handleBackground.alpha == 0, "party release outside must stop and hide the handle")
partyHandle.scripts.OnEnter()
partyHandle.scripts.OnDragStart()
partyHandle.scripts.OnDragStop()
assert(partyInfo.handleBackground.alpha == 1, "party release under pointer must preserve hover")
partyHandle.scripts.OnDragStart()
assert(partyRoot.moving == true, "unlocked drag did not start")
inCombat = true
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_DISABLED")
assert(partyRoot.moving == false, "combat start must release an in-flight drag")
assert(partyInfo.handleBackground.alpha == 0 and partyHandle.mouseEnabled == false, "combat must hide and disable party handle")
partyRoot:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
partyHandle.scripts.OnDragStop()
assert(partyRoot.moving == false, "drag stop must release the frame during combat")
assert(SimpleDispelDB.layouts.party.position.x == 120, "combat drag stop must save the new position")
assert(SimpleDispelDB.layouts.party.position.y == -80, "combat drag stop must save the new position")

-- Dragging cannot begin once combat has started.
partyHandle.scripts.OnDragStart()
assert(partyRoot.moving == false, "combat must block a new drag")

inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(partyHandle.mouseEnabled == true and partyInfo.handleBackground.alpha == 0, "combat exit must restore party hover without a stale highlight")
partyHandle.scripts.OnEnter()
partyHandle.scripts.OnDragStart()
SlashCmdList.SIMPLEDISPEL("lock")
assert(partyRoot.moving == false, "lock must stop a party drag in progress")
assert(partyHandle.shown == false and partyHandle.mouseEnabled == false, "lock must hide and disable party handle")
assert(partyRoot.height == 70 and createdButtons[1].point[5] == -4, "lock must not alter party geometry")
partyHandle.scripts.OnDragStart()
assert(partyRoot.moving == false, "locked frames must not drag")
SlashCmdList.SIMPLEDISPEL("unlock")
assert(partyHandle.shown == true and partyHandle.mouseEnabled == true, "unlock must restore the party hover area")
assert(partyRoot.height == 70 and createdButtons[1].point[5] == -4, "unlock must not alter party geometry")

-- The visibility driver hides the party frame when the group becomes a raid.
-- A hidden frame never sees the mouse release, so the drag must end on hide.
partyRoot:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60)
partyHandle.scripts.OnEnter()
partyHandle.scripts.OnDragStart()
assert(partyRoot.moving == true, "drag did not start")
partyRoot.scripts.OnHide(partyRoot)
assert(partyRoot.moving == false, "hiding a frame mid-drag must release it")
assert(partyInfo.handleBackground.alpha == 0, "party hide must clear hover artwork")
assert(SimpleDispelDB.layouts.party.position.x == 40, "hide during drag must save the position")

-- Hiding a frame that is not being dragged must not rewrite its saved position.
SimpleDispelDB.layouts.party.position.x = 999
partyRoot.scripts.OnHide(partyRoot)
assert(SimpleDispelDB.layouts.party.position.x == 999, "idle hide must not touch the saved position")

partyHandle.scripts.OnEnter()
partyHandle.scripts.OnDragStart()
partyHandle.scripts.OnHide()
assert(partyRoot.moving == false and partyInfo.handleBackground.alpha == 0, "hiding the party handle must stop movement and clear hover")

-- Options integration --------------------------------------------------------
-- Each proxy writes through Core.Config, so the same saved-variable and frame
-- behavior must be observable whether a value came from Settings or /sd.
local function SetOption(key, value)
    return OptionSetting(key):SetValue(value)
end

SetOption("Locked", true)
assert(SimpleDispelDB.locked == true, "locked option did not persist")
assert(addon.frames.party.dragHandle.shown == false, "locked option did not hide the party handle")
assert(addon.frames.raid.dragHandle.shown == false, "locked option did not hide the raid handle")
SetOption("Locked", false)
assert(SimpleDispelDB.locked == false, "unlock option did not persist")
assert(addon.frames.party.dragHandle.shown == true, "unlock option did not restore the party handle")

SetOption("Theme", "light")
assert(SimpleDispelDB.theme == "light", "theme option did not persist")
assert(addon.frames.party.background.calls.SetColorTexture[1] == 0.88, "theme option did not repaint party")
assert(addon.frames.raid.background.calls.SetColorTexture[1] == 0.88, "theme option did not repaint raid")
SetOption("Theme", "dark")

SetOption("PartyNames", false)
assert(SimpleDispelDB.hidePartyNames == true, "party names option did not persist hide")
assert(createdButtons[1].height == 48, "party names option did not collapse the name band")
assert(partyRoot.height == 56, "party names option did not resize the party frame")
SetOption("PartyNames", true)
assert(SimpleDispelDB.hidePartyNames == false, "party names option did not persist show")
assert(createdButtons[1].height == 62, "party names option did not restore the name band")
assert(partyRoot.height == 70, "party names option did not restore the party frame")

-- Sliders expose percentages while Core stores decimal scales.  Test both
-- endpoints and rejected values for each independent layout.
SetOption("PartyScale", 60)
assert(SimpleDispelDB.layouts.party.scale == 0.60, "party scale minimum was not applied")
assert(partyRoot.scale == 0.60, "party frame did not receive the minimum scale")
SetOption("PartyScale", 200)
assert(SimpleDispelDB.layouts.party.scale == 2.00, "party scale maximum was not applied")
assert(partyRoot.scale == 2.00, "party frame did not receive the maximum scale")
SetOption("PartyScale", 201)
assert(SimpleDispelDB.layouts.party.scale == 2.00, "out-of-range party scale must be rejected")
SetOption("RaidScale", 60)
assert(SimpleDispelDB.layouts.raid.scale == 0.60, "raid scale minimum was not applied")
assert(raidRoot.scale == 0.60, "raid frame did not receive the minimum scale")
SetOption("RaidScale", 200)
assert(SimpleDispelDB.layouts.raid.scale == 2.00, "raid scale maximum was not applied")
assert(raidRoot.scale == 2.00, "raid frame did not receive the maximum scale")
SetOption("RaidScale", 59)
assert(SimpleDispelDB.layouts.raid.scale == 2.00, "out-of-range raid scale must be rejected")

-- The filter is deliberately saved without rebuilding existing AuraContainers;
-- users apply it by reloading the interface.
local existingAuraFilter = addon.auraContainers[1].filter
SetOption("FilterMode", "all")
assert(SimpleDispelDB.filterMode == "all", "filter option did not persist")
assert(addon.auraContainers[1].filter == existingAuraFilter, "filter option must wait for reload")

SetOption("RaidLayout", "across")
assert(SimpleDispelDB.raidLayout == "across", "raid layout option did not persist")
assert(RaidPoint(1)[4] == 4, "raid layout option did not reposition the raid grid")
SetOption("RaidLayout", "down")
assert(SimpleDispelDB.raidLayout == "down", "raid layout option did not restore down mode")

-- Slash commands refresh native settings, and Refresh must use live getters
-- after Core replaces a layout table during reset.
local themeNotifyBeforeSlash = OptionSetting("Theme").notifyCount
local themeSetCallsBeforeSlash = OptionSetting("Theme").setCalls
SlashCmdList.SIMPLEDISPEL("theme light")
assert(OptionValue("Theme") == "light", "theme slash command left a stale options value")
assert(OptionSetting("Theme").notifyCount > themeNotifyBeforeSlash, "slash command did not refresh options")
assert(OptionSetting("Theme").setCalls == themeSetCallsBeforeSlash, "slash refresh called a setting setter")
SlashCmdList.SIMPLEDISPEL("scale raid 0.90")
assert(OptionValue("RaidScale") == 90, "scale slash command left a stale percentage getter")

local oldPartyLayout = SimpleDispelDB.layouts.party
SetOption("PartyScale", 80)
assert(OptionValue("PartyScale") == 80, "party scale getter did not reflect the option setter")
local resetPartyInitializer
for _, initializer in ipairs(optionsCategory.initializers) do
    if initializer.kind == "button" and initializer.arguments[1] == "Party position and scale" then
        resetPartyInitializer = initializer
        break
    end
end
assert(resetPartyInitializer, "party reset button was not added to the category")
resetPartyInitializer.arguments[3]()
assert(SimpleDispelDB.layouts.party ~= oldPartyLayout, "party reset must replace the layout table")
assert(OptionValue("PartyScale") == 100, "party scale getter retained a stale reset layout")
assert(partyRoot.scale == 1.00, "party reset did not apply the default scale")

-- Spell choices and manual-ID validation use the same known-spell boundary as
-- Core's command path.  Zero is the Settings representation of auto mode.
SetOption("SpellID", 527)
assert(SimpleDispelDB.manualSpellID == 527, "manual spell option did not persist")
assert(OptionValue("SpellID") == 527, "manual spell getter did not expose the saved ID")
local spellBeforeInvalid = SimpleDispelDB.manualSpellID
SetOption("SpellID", 9999)
assert(SimpleDispelDB.manualSpellID == spellBeforeInvalid, "unknown spell option changed the saved spell")
assert(options:ApplySpellID("0") == false, "popup spell validation must reject zero")
assert(options:ApplySpellID("2147483648") == false, "popup spell validation must reject oversized IDs")
assert(options:ApplySpellID("527") == true, "popup spell validation rejected a known spell")
SetOption("SpellID", 0)
assert(SimpleDispelDB.manualSpellID == nil, "spell auto option did not clear the override")
assert(OptionValue("SpellID") == 0, "spell auto getter did not return zero")

local popup = StaticPopup_Show("SIMPLEDISPEL_SPELL_ID")
assert(popup.editBox.text == "", "spell popup did not initialize from automatic mode")
popup.editBox:SetText("9999")
local keepPopupOpen = StaticPopupDialogs.SIMPLEDISPEL_SPELL_ID.OnAccept(popup)
assert(keepPopupOpen == true and popup.shown == true, "invalid popup input must remain open")
assert(popup:GetTextFontString().text ~= "", "invalid popup input did not show validation text")
popup.editBox:SetText("527")
StaticPopupDialogs.SIMPLEDISPEL_SPELL_ID.EditBoxOnEnterPressed(popup.editBox)
assert(popup.shown == false, "valid popup input must close the popup")
assert(SimpleDispelDB.manualSpellID == 527, "valid popup input did not persist the spell")

-- Settings changes that touch protected button geometry are saved during
-- combat but applied only after PLAYER_REGEN_ENABLED.
SetOption("PartyScale", 100)
SetOption("RaidScale", 100)
SetOption("PartyNames", true)
SetOption("RaidLayout", "down")
raidRosterInfo = {}
for i = 1, 5 do raidRosterInfo[i] = 1 end
groupMemberCount = 5
eventFrame.scripts.OnEvent(eventFrame, "GROUP_ROSTER_UPDATE")
local partyScaleBeforeCombat = partyRoot.scale
local partyHeightBeforeCombat = partyRoot.height
local partyButtonHeightBeforeCombat = createdButtons[1].height
local raidPointBeforeCombat = { RaidPoint(2)[4], RaidPoint(2)[5] }
inCombat = true
SetOption("PartyScale", 80)
assert(SimpleDispelDB.layouts.party.scale == 0.80, "combat party scale was not saved")
assert(partyRoot.scale == partyScaleBeforeCombat, "party scale applied protected layout during combat")
assert(addon.pendingLayoutRefresh == true, "combat party scale did not defer layout")
SetOption("PartyNames", false)
assert(SimpleDispelDB.hidePartyNames == true, "combat party names change was not saved")
assert(partyRoot.height == partyHeightBeforeCombat, "party frame resized during combat")
assert(createdButtons[1].height == partyButtonHeightBeforeCombat, "party button resized during combat")
assert(addon.pendingNameBandRefresh == true, "combat party names change did not defer geometry")
SetOption("RaidLayout", "across")
assert(SimpleDispelDB.raidLayout == "across", "combat raid layout was not saved")
assert(RaidPoint(2)[4] == raidPointBeforeCombat[1] and RaidPoint(2)[5] == raidPointBeforeCombat[2],
    "raid layout moved protected buttons during combat")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(addon.pendingLayoutRefresh == false, "combat layout changes did not flush")
assert(addon.pendingNameBandRefresh == false, "combat party names change did not flush")
assert(partyRoot.scale == 0.80, "deferred party scale was not applied")
assert(partyRoot.height == 56 and createdButtons[1].height == 48, "deferred party names change was not applied")
assert(SimpleDispelDB.raidLayout == "across", "deferred raid layout was lost")
assert(RaidPoint(2)[4] ~= raidPointBeforeCombat[1] or RaidPoint(2)[5] ~= raidPointBeforeCombat[2],
    "deferred raid layout did not reposition the grid")

-- ShowWithoutDispel is a visibility setting, so exercise its empty-state
-- frame path as well as persistence.
resolvedSpell = nil
eventFrame.scripts.OnEvent(eventFrame, "SPELLS_CHANGED")
assert(addon.activeSpell == nil, "test setup did not clear the active spell")
SetOption("ShowWithoutDispel", true)
assert(SimpleDispelDB.showWithoutDispel == true, "show-without-dispel option did not persist")
assert(addon.frames.raid.emptyState.shown == true, "show-without-dispel option did not show the empty state")
SetOption("ShowWithoutDispel", false)
assert(SimpleDispelDB.showWithoutDispel == false, "hide-without-dispel option did not persist")
assert(CurrentVisibility("SimpleDispelRaidFrame") == "hide", "hide-without-dispel option did not hide raid")
resolvedSpell = { id = 527, name = "Purify", icon = 1, known = true, source = "auto" }
eventFrame.scripts.OnEvent(eventFrame, "SPELLS_CHANGED")
assert(addon.activeSpell and addon.activeSpell.id == 527, "automatic spell detection was not restored")

local notifySnapshot = {}
local setterSnapshot = {}
for key, setting in pairs(options.settings) do
    notifySnapshot[key] = setting.notifyCount
    setterSnapshot[key] = setting.setCalls
end
options:Refresh()
for key, setting in pairs(options.settings) do
    assert(setting.notifyCount == notifySnapshot[key] + 1, key .. " did not receive a refresh notification")
    assert(setting.setCalls == setterSnapshot[key], key .. " refresh unexpectedly called its setter")
end

print("SimpleDispel mock runtime: PASS")
