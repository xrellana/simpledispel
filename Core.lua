local addonName, addon = ...

local PREFIX = "|cff4ee6a8SimpleDispel|r:"
local FILTER_HELP = "mine (HARMFUL|RAID), group, all"

addon.buttons = {}
addon.auraContainers = {}
addon.pendingSpellRefresh = false

local function Print(message)
    print(PREFIX, message)
end

addon.Print = Print

local function GetAddonVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown"
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, "Version") or "unknown"
    end
    return "unknown"
end

local function InitializeDatabase()
    if type(SimpleDispelDB) ~= "table" then
        SimpleDispelDB = {}
    end

    SimpleDispelDB.schemaVersion = 1
    SimpleDispelDB.filterMode = SimpleDispelDB.filterMode or "mine"
    addon.db = SimpleDispelDB
end

local function CreatePrototypeUI()
    local root = CreateFrame("Frame", "SimpleDispelPrototype", UIParent)
    root:SetSize(106, 76)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, -180)

    local title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("BOTTOM", root, "TOP", 0, 12)
    title:SetText("SimpleDispel 12.1 Spike")

    local definitions = {
        { unit = "player", name = "SimpleDispelPlayerButton", label = "SELF", x = 0 },
        { unit = "party1", name = "SimpleDispelParty1Button", label = "P1", x = 58 },
    }

    local filterString = addon.AuraDisplay:GetFilter(addon.db.filterMode)
    local auraFailure

    for _, definition in ipairs(definitions) do
        local button = addon.SecureButtons:Create(
            root,
            definition.name,
            definition.unit,
            definition.label
        )
        button:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", definition.x, 0)
        addon.buttons[#addon.buttons + 1] = button

        local container, auraError = addon.AuraDisplay:Create(
            button,
            definition.unit,
            filterString
        )
        if container then
            addon.auraContainers[#addon.auraContainers + 1] = container
        else
            auraFailure = auraFailure or tostring(auraError)
        end
    end

    addon.root = root
    addon.auraError = auraFailure
    if auraFailure then
        Print("AuraContainer prototype unavailable: " .. auraFailure)
    end
end

function addon:RefreshSpell()
    if InCombatLockdown() then
        self.pendingSpellRefresh = true
        return false
    end

    local spell = self.Spells:Resolve()
    for _, button in ipairs(self.buttons) do
        self.SecureButtons:SetSpell(button, spell)
    end

    self.activeSpell = spell
    self.pendingSpellRefresh = false
    return true
end

local function PrintStatus()
    local gameVersion, build, _, tocVersion = GetBuildInfo()
    local supported, supportError = addon.AuraDisplay:IsSupported()
    local spell = addon.activeSpell

    Print(string.format(
        "addon=%s game=%s build=%s toc=%s combat=%s",
        GetAddonVersion(),
        tostring(gameVersion),
        tostring(build),
        tostring(tocVersion),
        tostring(InCombatLockdown())
    ))
    Print(string.format(
        "auraContainer=%s filter=%s",
        supported and "yes" or ("no: " .. tostring(supportError)),
        addon.AuraDisplay:GetFilter(addon.db.filterMode)
    ))

    if spell then
        Print(string.format(
            "spell=%s (%d), source=%s, spellbookKnown=%s",
            spell.name,
            spell.id,
            tostring(spell.source),
            tostring(spell.known)
        ))
    else
        Print("spell=none; use /sd spell <spellID> to set an out-of-combat override")
    end

    if addon.auraError then
        Print("last aura error: " .. addon.auraError)
    end
end

local function PrintHelp()
    Print("/sd status")
    Print("/sd spell auto | /sd spell <spellID>")
    Print("/sd filter <" .. FILTER_HELP .. "> (then /reload)")
end

local function HandleSpellCommand(argument)
    if argument == "auto" then
        addon.db.manualSpellID = nil
        addon:RefreshSpell()
        Print("spell selection set to auto")
        return
    end

    local spellID = tonumber(argument)
    local info = spellID and addon.Spells:GetInfo(spellID)
    if not info then
        Print("unknown spell ID: " .. tostring(argument))
        return
    end

    addon.db.manualSpellID = spellID
    addon:RefreshSpell()
    Print(string.format("manual spell set to %s (%d)", info.name, spellID))
    if InCombatLockdown() then
        Print("secure attributes will update after combat")
    end
end

local function HandleFilterCommand(argument)
    if not addon.AuraDisplay.Filters[argument] then
        Print("filter must be one of: " .. FILTER_HELP)
        return
    end

    addon.db.filterMode = argument
    Print("filter set to " .. addon.AuraDisplay.Filters[argument] .. "; run /reload to rebuild containers")
end

local function HandleSlashCommand(message)
    local command, argument = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    argument = string.lower(argument or "")

    if command == "status" then
        PrintStatus()
    elseif command == "spell" then
        HandleSpellCommand(argument)
    elseif command == "filter" then
        HandleFilterCommand(argument)
    else
        PrintHelp()
    end
end

local function RegisterSlashCommands()
    SLASH_SIMPLEDISPEL1 = "/sd"
    SLASH_SIMPLEDISPEL2 = "/simpledispel"
    SlashCmdList.SIMPLEDISPEL = HandleSlashCommand
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then
            return
        end

        self:UnregisterEvent("ADDON_LOADED")
        InitializeDatabase()
        RegisterSlashCommands()
        CreatePrototypeUI()

        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("TRAIT_CONFIG_UPDATED")
        return
    end

    if event == "PLAYER_LOGIN" then
        addon:RefreshSpell()
        Print("v" .. GetAddonVersion() .. " loaded; use /sd status")
    elseif event == "PLAYER_REGEN_ENABLED" then
        if addon.pendingSpellRefresh then
            addon:RefreshSpell()
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED" then
        addon:RefreshSpell()
    end
end)
