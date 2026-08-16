local createdFrames = {}
local createdButtons = {}
local stateDrivers = {}
local inRaid = false
local inCombat = false

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

function GetBuildInfo()
    return "12.1.0", "12345", "Aug 2026", 120100
end

C_AddOns = {
    GetAddOnMetadata = function(_, field)
        if field == "Version" then
            return "0.10.0-beta.3"
        end
    end,
}

SimpleDispelDB = {
    position = { point = "CENTER", relativePoint = "CENTER", x = 17, y = -25 },
    scale = 0.90,
}

local addon = {}
addon.SecureButtons = {
    BUTTON_SIZE = 48,
    Create = function(_, parent, globalName, unit, label, size)
        local button = CreateFrame("Button", globalName, parent, "SecureActionButtonTemplate")
        button.unit = unit
        button.label = label
        button.requestedSize = size
        createdButtons[#createdButtons + 1] = button
        return button
    end,
    SetSpell = function(_, button, spell)
        button.spell = spell
        return true
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
        return { id = 527, name = "Purify", icon = 1, known = true, source = "auto" }
    end,
    GetInfo = function(_, spellID)
        return { id = spellID, name = "Manual", icon = 1, known = true }
    end,
}

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

assert(SimpleDispelDB.schemaVersion == 3, "database schema was not upgraded")
assert(SimpleDispelDB.layouts.party.scale == 0.90, "party scale migration failed")
assert(SimpleDispelDB.layouts.party.position.x == 17, "party position migration failed")
assert(SimpleDispelDB.layouts.raid.scale == 1.00, "raid default scale is wrong")
assert(#createdButtons == 45, "expected 5 party and 40 raid buttons")
assert(createdButtons[1].unit == "player", "first party unit must be player")
assert(createdButtons[5].unit == "party4", "fifth party unit must be party4")
assert(createdButtons[6].unit == "raid1", "first raid unit must be raid1")
assert(createdButtons[45].unit == "raid40", "last raid unit must be raid40")
assert(createdButtons[1].requestedSize == 48, "party button size is wrong")
assert(createdButtons[6].requestedSize == 32, "raid button size is wrong")
assert(#addon.auraContainers == 45, "every unit must get one aura container")

local partyVisibility
local raidVisibility
for _, driver in ipairs(stateDrivers) do
    if driver.frame.globalName == "SimpleDispelPartyFrame" then
        partyVisibility = driver.conditional
    elseif driver.frame.globalName == "SimpleDispelRaidFrame" then
        raidVisibility = driver.conditional
    end
end
assert(partyVisibility == "[group:raid] hide; show", "party visibility driver is wrong")
assert(raidVisibility == "[group:raid] show; hide", "raid visibility driver is wrong")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
assert(addon.activeSpell and addon.activeSpell.id == 527, "spell was not assigned at login")
assert(createdButtons[45].spell and createdButtons[45].spell.id == 527, "raid spell assignment failed")

SlashCmdList.SIMPLEDISPEL("scale raid 0.75")
assert(SimpleDispelDB.layouts.raid.scale == 0.75, "explicit raid scale command failed")

inRaid = true
SlashCmdList.SIMPLEDISPEL("scale 0.80")
assert(SimpleDispelDB.layouts.raid.scale == 0.80, "active raid scale command failed")

SlashCmdList.SIMPLEDISPEL("reset all")
assert(SimpleDispelDB.layouts.party.scale == 1.00, "party reset failed")
assert(SimpleDispelDB.layouts.raid.scale == 1.00, "raid reset failed")

inCombat = true
SlashCmdList.SIMPLEDISPEL("scale raid 0.85")
assert(addon.pendingLayoutRefresh, "combat layout update was not deferred")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(not addon.pendingLayoutRefresh, "deferred layout update was not applied")

print("SimpleDispel mock runtime: PASS")
