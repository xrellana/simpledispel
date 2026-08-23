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

local addon = {}
addon.SecureButtons = {
    BUTTON_SIZE = 48,
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
    Resolve = function()
        return resolvedSpell
    end,
    GetInfo = function(_, spellID)
        return { id = spellID, name = "Manual", icon = 1, known = true }
    end,
}

local themeChunk = assert(loadfile("Theme.lua"))
themeChunk("SimpleDispel", addon)

local coreChunk = assert(loadfile("Core.lua"))
coreChunk("SimpleDispel", addon)

local eventFrame
for _, frame in ipairs(createdFrames) do
    if frame.events and frame.events.ADDON_LOADED then
        eventFrame = frame
        break
    end
end
assert(eventFrame, "ADDON_LOADED event frame was not created")

eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "SimpleDispel")

assert(SimpleDispelDB.schemaVersion == 4, "database schema was not upgraded")
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
assert(createdButtons[1].requestedHeight == 48, "party button height is wrong")
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

local partyVisibility
local raidVisibility
local raidRoot
for _, driver in ipairs(stateDrivers) do
    if driver.frame.globalName == "SimpleDispelPartyFrame" then
        partyVisibility = driver.conditional
    elseif driver.frame.globalName == "SimpleDispelRaidFrame" then
        raidVisibility = driver.conditional
        raidRoot = driver.frame
    end
end
assert(partyVisibility == "[group:raid] hide; show", "party visibility driver is wrong")
assert(raidVisibility == "[group:raid] show; hide", "raid visibility driver is wrong")
assert(raidRoot.width == 246, "compact raid frame width is wrong")
assert(addon.frames.raid.dragHandle.width == 28, "raid drag handle must stay compact")
assert(addon.frames.raid.dragHandle.height == 22, "raid drag handle height is wrong")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
assert(addon.activeSpell and addon.activeSpell.id == 527, "spell was not assigned at login")
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
assert(addon.frames.party.content.shown == false, "party buttons must be hidden without a dispel")
assert(addon.frames.party.emptyState.shown == true, "party empty state must explain the missing dispel")
assert(addon.frames.raid.content.shown == false, "raid buttons must be hidden without a dispel")
assert(addon.frames.raid.emptyState.shown == true, "raid empty state must explain the missing dispel")
assert(addon.frames.raid.root.height == 70, "raid empty state must use a compact height")
assert(createdButtons[1].simpleDispelCooldownState == "unknown", "missing dispel must clear cooldown state")
rangeCalls = {}
eventFrame.scripts.OnUpdate(eventFrame, 1)
assert(#rangeCalls == 0, "range refresh must stop without an active dispel")

resolvedSpell = { id = 527, name = "Purify", icon = 1, known = true, source = "auto" }
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
assert(addon.activeSpell and addon.activeSpell.id == 527, "spec change must restore the detected dispel")
assert(addon.frames.party.content.shown == true, "party buttons must return after dispel detection")
assert(addon.frames.party.emptyState.shown == false, "party empty state must clear after dispel detection")

SlashCmdList.SIMPLEDISPEL("scale raid 0.75")
assert(SimpleDispelDB.layouts.raid.scale == 0.75, "explicit raid scale command failed")

inRaid = true
local raidHeightCases = {
    { members = 1, height = 58 },
    { members = 8, height = 58 },
    { members = 9, height = 88 },
    { members = 16, height = 88 },
    { members = 17, height = 118 },
    { members = 25, height = 148 },
    { members = 32, height = 148 },
    { members = 33, height = 178 },
    { members = 40, height = 178 },
    { members = 25, height = 148 },
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
assert(createdButtons[6].point[5] == -4, "locked raid grid must move into the former title space")
SlashCmdList.SIMPLEDISPEL("unlock")
assert(SimpleDispelDB.locked == false, "unlock command did not persist")
assert(addon.frames.raid.dragHandle.shown == true, "unlocked raid handle must be visible")
assert(addon.frames.raid.background.shown == true, "unlocked raid background must be visible")
assert(raidRoot.height == 148, "unlocked 25-player raid height is wrong")
assert(createdButtons[6].point[5] == unlockedRaidY, "unlock must restore the raid grid offset")
SlashCmdList.SIMPLEDISPEL("scale 0.80")
assert(SimpleDispelDB.layouts.raid.scale == 0.80, "active raid scale command failed")

SlashCmdList.SIMPLEDISPEL("reset all")
assert(SimpleDispelDB.layouts.party.scale == 1.00, "party reset failed")
assert(SimpleDispelDB.layouts.raid.scale == 1.00, "raid reset failed")

inCombat = true
groupMemberCount = 40
eventFrame.scripts.OnEvent(eventFrame, "GROUP_ROSTER_UPDATE")
assert(addon.pendingRaidSizeRefresh, "combat raid resize was not deferred")
assert(raidRoot.height == 148, "raid frame resized during combat")
SlashCmdList.SIMPLEDISPEL("scale raid 0.85")
assert(addon.pendingLayoutRefresh, "combat layout update was not deferred")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(not addon.pendingLayoutRefresh, "deferred layout update was not applied")
assert(not addon.pendingRaidSizeRefresh, "deferred raid resize was not applied")
assert(raidRoot.height == 178, "40-player raid frame must use five rows")

assert(eventFrame.events.PLAYER_REGEN_DISABLED, "combat start event was not registered")

-- A drag left running keeps the frame on the cursor, so its unit buttons cover
-- whatever the player points at and targeting stops working entirely.
local partyRoot = addon.frames.party.root
local partyHandle = addon.frames.party.dragHandle
partyHandle.scripts.OnDragStart()
assert(partyRoot.moving == true, "unlocked drag did not start")
inCombat = true
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_DISABLED")
assert(partyRoot.moving == false, "combat start must release an in-flight drag")
partyRoot:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -80)
partyHandle.scripts.OnDragStop()
assert(partyRoot.moving == false, "drag stop must release the frame during combat")
assert(SimpleDispelDB.layouts.party.position.x == 120, "combat drag stop must save the new position")
assert(SimpleDispelDB.layouts.party.position.y == -80, "combat drag stop must save the new position")

-- Dragging cannot begin once combat has started.
partyHandle.scripts.OnDragStart()
assert(partyRoot.moving == false, "combat must block a new drag")

inCombat = false
SlashCmdList.SIMPLEDISPEL("lock")
partyHandle.scripts.OnDragStart()
assert(partyRoot.moving == false, "locked frames must not drag")
SlashCmdList.SIMPLEDISPEL("unlock")

-- The visibility driver hides the party frame when the group becomes a raid.
-- A hidden frame never sees the mouse release, so the drag must end on hide.
partyRoot:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60)
partyHandle.scripts.OnDragStart()
assert(partyRoot.moving == true, "drag did not start")
partyRoot.scripts.OnHide(partyRoot)
assert(partyRoot.moving == false, "hiding a frame mid-drag must release it")
assert(SimpleDispelDB.layouts.party.position.x == 40, "hide during drag must save the position")

-- Hiding a frame that is not being dragged must not rewrite its saved position.
SimpleDispelDB.layouts.party.position.x = 999
partyRoot.scripts.OnHide(partyRoot)
assert(SimpleDispelDB.layouts.party.position.x == 999, "idle hide must not touch the saved position")

print("SimpleDispel mock runtime: PASS")
