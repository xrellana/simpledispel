local addonName, addon = ...

local PREFIX = "|cff4ee6a8SimpleDispel|r:"
local FILTER_HELP = "mine (HARMFUL|RAID), group, all"
local THEME_HELP = table.concat(addon.Theme.Names, " | ")
local PARTY_BUTTON_SIZE = 48
-- SecureButtons.lua loads before Core.lua per SimpleDispel.toc, so this resolves
-- at load time; no fallback value here, because a mismatch should fail loudly.
local PARTY_LABEL_HEIGHT = addon.SecureButtons.LABEL_BAND_HEIGHT
local PARTY_BUTTON_HEIGHT = PARTY_BUTTON_SIZE + PARTY_LABEL_HEIGHT
local RAID_BUTTON_SIZE = 28
local RAID_COLUMNS = 8
local PARTY_GAP = 6
local RAID_GAP = 2
local FRAME_PADDING = 4
-- Floor for the compact raid frame width: below two columns the drag handle
-- and its "SD" title have nowhere to sit without overlapping the buttons.
local RAID_MIN_WIDTH = (RAID_BUTTON_SIZE * 2) + RAID_GAP + (FRAME_PADDING * 2)
local HANDLE_HEIGHT = 22
local RANGE_UPDATE_INTERVAL = 0.25
local EMPTY_STATE_HEIGHT = HANDLE_HEIGHT + (FRAME_PADDING * 2) + 40
local MIN_SCALE = 0.60
local MAX_SCALE = 2.00
local NO_DISPEL_TITLE = "No dispel spell available"
local NO_DISPEL_HINT = "Frames return automatically when one is detected."
local locale = GetLocale and GetLocale()
if locale == "zhCN" then
    NO_DISPEL_TITLE = "当前专精没有可用的驱散技能"
    NO_DISPEL_HINT = "检测到驱散技能后，框体会自动启用。"
elseif locale == "zhTW" then
    NO_DISPEL_TITLE = "目前專精沒有可用的驅散技能"
    NO_DISPEL_HINT = "偵測到驅散技能後，框架會自動啟用。"
end

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }

local DEFAULT_LAYOUTS = {
    party = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -180, scale = 1.00 },
    raid = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -40, scale = 1.00 },
}

addon.buttons = {}
addon.auraContainers = {}
addon.frames = {}
addon.unitButtons = {}
addon.pendingSpellRefresh = false
addon.pendingLayoutRefresh = false
addon.pendingRaidSizeRefresh = false
addon.pendingNameBandRefresh = false
addon.dispelCooldownActive = nil

local PositionRaidButtons
local RefreshRaidFrameSize

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

local function NewDefaultLayout(layoutKey)
    local defaults = DEFAULT_LAYOUTS[layoutKey]
    return {
        position = {
            point = defaults.point,
            relativePoint = defaults.relativePoint,
            x = defaults.x,
            y = defaults.y,
        },
        scale = defaults.scale,
    }
end

local function NormalizeLayout(layoutKey, layout)
    local defaults = DEFAULT_LAYOUTS[layoutKey]
    if type(layout) ~= "table" then
        return NewDefaultLayout(layoutKey)
    end

    if type(layout.position) ~= "table" then
        layout.position = {
            point = defaults.point,
            relativePoint = defaults.relativePoint,
            x = defaults.x,
            y = defaults.y,
        }
    end
    if type(layout.scale) ~= "number" then
        layout.scale = defaults.scale
    end
    return layout
end

local function InitializeDatabase()
    if type(SimpleDispelDB) ~= "table" then
        SimpleDispelDB = {}
    end

    SimpleDispelDB.schemaVersion = 6
    SimpleDispelDB.filterMode = SimpleDispelDB.filterMode or "mine"
    -- Databases written before subgroup-sorted layout existed carry no field,
    -- so they default to "across", which preserves the pre-1.4 wide footprint
    -- instead of silently switching everyone to the taller "down" layout.
    if SimpleDispelDB.raidLayout ~= "across" and SimpleDispelDB.raidLayout ~= "down" then
        SimpleDispelDB.raidLayout = "across"
    end
    -- Databases written before the theme option carry no theme field. Falling
    -- back to the dark default keeps an upgrade visually identical to 1.2.x
    -- until the player opts in with /sd theme light.
    if not addon.Theme:IsValid(SimpleDispelDB.theme) then
        SimpleDispelDB.theme = addon.Theme.DEFAULT
    end
    if type(SimpleDispelDB.locked) ~= "boolean" then
        SimpleDispelDB.locked = false
    end
    -- Databases written before this option carry no field, so party names stay
    -- visible on upgrade until the player hides them with /sd names hide.
    if type(SimpleDispelDB.hidePartyNames) ~= "boolean" then
        SimpleDispelDB.hidePartyNames = false
    end
    if type(SimpleDispelDB.layouts) ~= "table" then
        SimpleDispelDB.layouts = {}
    end

    -- Migrate the original single-layout settings into the party layout.
    if type(SimpleDispelDB.layouts.party) ~= "table" then
        local partyLayout = NewDefaultLayout("party")
        if type(SimpleDispelDB.position) == "table" then
            partyLayout.position = SimpleDispelDB.position
        end
        if type(SimpleDispelDB.scale) == "number" then
            partyLayout.scale = SimpleDispelDB.scale
        end
        SimpleDispelDB.layouts.party = partyLayout
    end

    SimpleDispelDB.layouts.party = NormalizeLayout("party", SimpleDispelDB.layouts.party)
    SimpleDispelDB.layouts.raid = NormalizeLayout("raid", SimpleDispelDB.layouts.raid)
    addon.db = SimpleDispelDB
end

local function GetActiveLayoutKey()
    if IsInRaid and IsInRaid() then
        return "raid"
    end
    return "party"
end

local function SavePosition(layoutKey, root)
    if not root then
        return
    end

    local point, _, relativePoint, x, y = root:GetPoint(1)
    local defaults = DEFAULT_LAYOUTS[layoutKey]
    addon.db.layouts[layoutKey].position = {
        point = point or defaults.point,
        relativePoint = relativePoint or defaults.relativePoint,
        x = tonumber(x) or defaults.x,
        y = tonumber(y) or defaults.y,
    }
end

-- StartMoving() glues the frame to the cursor until it is stopped. A drag that
-- is still running drags the whole button grid under the mouse, so its unit
-- buttons swallow every world click and mouseover and the player cannot retarget.
-- Nothing may leave a drag running, combat included.
local activeDrag = nil

local function StopDrag(layoutKey, root)
    if activeDrag and activeDrag.root == root then
        activeDrag = nil
    end

    -- StopMovingOrSizing is unprotected and the root frame is not secure, so
    -- this is safe to run mid-combat and must never be skipped.
    root:StopMovingOrSizing()
    SavePosition(layoutKey, root)
end

local function StopActiveDrag()
    if activeDrag then
        StopDrag(activeDrag.layoutKey, activeDrag.root)
    end
end

local function UpdateLockState()
    if InCombatLockdown() then
        addon.pendingLayoutRefresh = true
        return
    end

    local canDrag = not addon.db.locked and not InCombatLockdown()
    for layoutKey, frameInfo in pairs(addon.frames) do
        frameInfo.dragHandle:EnableMouse(canDrag)
        if layoutKey == "raid" then
            frameInfo.dragHandle:SetShown(not addon.db.locked)
            frameInfo.title:SetText("SD")
            frameInfo.background:SetShown(not addon.db.locked or not addon.activeSpell)
        else
            frameInfo.dragHandle:SetShown(true)
            frameInfo.dragHandle:SetAlpha(addon.db.locked and 0.72 or 1)
            local title = frameInfo.titleBase
            if not addon.db.locked then
                title = title .. "  |cff" .. addon.Theme.DRAG_HINT_COLOR .. "(drag)|r"
            end
            frameInfo.title:SetText(title)
        end
    end

    if PositionRaidButtons then
        PositionRaidButtons()
    end
    if RefreshRaidFrameSize then
        RefreshRaidFrameSize()
    end
end

local function ApplyFrameSettings(layoutKey)
    local frameInfo = addon.frames[layoutKey]
    if not frameInfo then
        return
    end
    if InCombatLockdown() then
        addon.pendingLayoutRefresh = true
        return
    end

    local defaults = DEFAULT_LAYOUTS[layoutKey]
    local layout = addon.db.layouts[layoutKey]
    local position = layout.position or {}
    frameInfo.root:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, layout.scale or defaults.scale)))
    frameInfo.root:ClearAllPoints()
    frameInfo.root:SetPoint(
        position.point or defaults.point,
        UIParent,
        position.relativePoint or defaults.relativePoint,
        tonumber(position.x) or defaults.x,
        tonumber(position.y) or defaults.y
    )
end

local function ApplyAllFrameSettings()
    if InCombatLockdown() then
        addon.pendingLayoutRefresh = true
        return
    end

    ApplyFrameSettings("party")
    ApplyFrameSettings("raid")
    addon.pendingLayoutRefresh = false
    UpdateLockState()
end

local function ApplyFrameTheme(frameInfo)
    local colors = addon.Theme:Colors()
    local root = colors.rootBackground
    frameInfo.background:SetColorTexture(root[1], root[2], root[3], root[4])
    local handle = colors.handleBackground
    frameInfo.handleBackground:SetColorTexture(handle[1], handle[2], handle[3], handle[4])
    addon.Theme:ApplyText(frameInfo.title, colors.title, colors.titleFont)
    addon.Theme:ApplyText(frameInfo.emptyTitle, colors.emptyTitle, colors.titleFont)
    addon.Theme:ApplyText(frameInfo.emptyHint, colors.emptyHint, colors.hintFont)
end

-- A theme is nothing but colours and alphas, none of which are protected, so
-- unlike every other layout change this one does not need a combat guard.
local function ApplyTheme()
    for _, frameInfo in pairs(addon.frames) do
        ApplyFrameTheme(frameInfo)
    end
    for _, button in ipairs(addon.buttons) do
        addon.SecureButtons:ApplyTheme(button)
    end
end

local function CreateRoot(layoutKey, globalName, titleBase, width, height, visibilityDriver, compactHandle)
    local root = CreateFrame("Frame", globalName, UIParent)
    root:SetSize(width, height)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)

    local background = root:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(root)

    local dragHandle = CreateFrame("Frame", nil, root)
    if compactHandle then
        dragHandle:SetPoint("TOPLEFT", root, "TOPLEFT", FRAME_PADDING, 0)
        dragHandle:SetSize(RAID_BUTTON_SIZE, HANDLE_HEIGHT)
    else
        dragHandle:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        dragHandle:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
        dragHandle:SetHeight(HANDLE_HEIGHT)
    end
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        if addon.db.locked or InCombatLockdown() then
            return
        end
        StopActiveDrag()
        activeDrag = { layoutKey = layoutKey, root = root }
        root:StartMoving()
    end)
    dragHandle:SetScript("OnDragStop", function()
        StopDrag(layoutKey, root)
    end)

    -- The visibility driver can hide this frame mid-drag when the group turns
    -- into a raid or back. A hidden frame never receives the mouse release, so
    -- the drag would survive until the frame is shown again, still glued to the
    -- cursor.
    root:SetScript("OnHide", function()
        if activeDrag and activeDrag.root == root then
            StopDrag(layoutKey, root)
        end
    end)

    local handleBackground = dragHandle:CreateTexture(nil, "BACKGROUND")
    handleBackground:SetAllPoints(dragHandle)

    local title = dragHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("CENTER", dragHandle, "CENTER", 0, 0)

    -- Keep protected unit buttons under one parent so the normal dispel UI can
    -- be replaced with an explanatory empty state when no spell is available.
    -- Availability changes are only applied out of combat by RefreshSpell.
    local content = CreateFrame("Frame", nil, root)
    content:SetAllPoints(root)

    local emptyState = CreateFrame("Frame", nil, root)
    emptyState:SetPoint("TOPLEFT", root, "TOPLEFT", FRAME_PADDING, -HANDLE_HEIGHT)
    emptyState:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -FRAME_PADDING, FRAME_PADDING)
    emptyState:EnableMouse(false)

    local emptyTitle = emptyState:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emptyTitle:SetPoint("CENTER", emptyState, "CENTER", 0, 7)
    emptyTitle:SetText(NO_DISPEL_TITLE)

    local emptyHint = emptyState:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyHint:SetPoint("TOP", emptyTitle, "BOTTOM", 0, -2)
    emptyHint:SetText(NO_DISPEL_HINT)

    local frameInfo = {
        root = root,
        background = background,
        dragHandle = dragHandle,
        handleBackground = handleBackground,
        title = title,
        titleBase = titleBase,
        content = content,
        emptyState = emptyState,
        emptyTitle = emptyTitle,
        emptyHint = emptyHint,
    }
    addon.frames[layoutKey] = frameInfo
    ApplyFrameTheme(frameInfo)

    if RegisterStateDriver then
        RegisterStateDriver(root, "visibility", visibilityDriver)
    elseif layoutKey == "raid" then
        root:SetShown(IsInRaid and IsInRaid())
    else
        root:SetShown(not (IsInRaid and IsInRaid()))
    end

    return frameInfo
end

local function AddUnitButton(root, definition, buttonWidth, filterString, showDuration, buttonHeight)
    buttonHeight = buttonHeight or buttonWidth
    local button = addon.SecureButtons:Create(
        root,
        definition.name,
        definition.unit,
        definition.label,
        buttonWidth,
        definition.labelMode,
        buttonHeight
    )
    addon.buttons[#addon.buttons + 1] = button
    addon.unitButtons[definition.unit] = button

    local container, auraError = addon.AuraDisplay:Create(
        button,
        definition.unit,
        filterString,
        {
            width = definition.auraWidth or buttonWidth,
            height = definition.auraHeight or buttonHeight,
            anchor = definition.auraAnchor or "CENTER",
            showDuration = showDuration,
            iconBottomInset = definition.iconBottomInset or 0,
        }
    )
    if container then
        addon.auraContainers[#addon.auraContainers + 1] = container
    else
        addon.auraError = addon.auraError or tostring(auraError)
    end
    addon.SecureButtons:RaiseRangeOverlay(button, container)

    return button
end

local function UpdateUnitLabel(unit)
    local button = addon.unitButtons[unit]
    if not button or not button.simpleDispelLabel then
        return
    end

    local unitName = GetUnitName and GetUnitName(unit, false)
    if type(issecretvalue) == "function" and issecretvalue(unitName) then
        -- Secret names may be displayed directly but must not be read,
        -- compared, truncated, concatenated, or used for decisions.
        button.simpleDispelLabel:SetText(unitName)
    elseif type(unitName) == "string" and unitName ~= "" then
        button.simpleDispelLabel:SetText(unitName)
    else
        button.simpleDispelLabel:SetText(button.simpleDispelFallbackLabel)
    end
end

local function UpdateGroupLabels()
    for index = 1, 4 do
        UpdateUnitLabel("party" .. index)
    end
end

local function PartyNamesShown()
    return not (addon.db and addon.db.hidePartyNames)
end

local function GetPartyFrameHeight()
    local bandHeight = PartyNamesShown() and PARTY_LABEL_HEIGHT or 0
    return PARTY_BUTTON_SIZE + bandHeight + HANDLE_HEIGHT + (FRAME_PADDING * 2)
end

-- Hiding the names collapses a band that is part of each party button's own
-- height, and a party button is a protected action button, so this is deferred
-- out of combat like every other layout change. Only the button plate and the
-- frame around it change size: the icon area, and with it the debuff icon and
-- its aura container, occupies the same square either way.
local function ApplyPartyNameBand()
    if InCombatLockdown() then
        addon.pendingNameBandRefresh = true
        return false
    end

    local shown = PartyNamesShown()
    for _, unit in ipairs(PARTY_UNITS) do
        local button = addon.unitButtons[unit]
        if button then
            addon.SecureButtons:SetNameBandShown(button, shown)
        end
    end

    local frameInfo = addon.frames.party
    if frameInfo then
        frameInfo.root:SetHeight(GetPartyFrameHeight())
    end

    addon.pendingNameBandRefresh = false
    return true
end

local function CreatePartyUI(filterString)
    local definitions = {
        { unit = "player", name = "SimpleDispelPlayerButton", label = "YOU", labelMode = "BOTTOM" },
        { unit = "party1", name = "SimpleDispelParty1Button", label = "P1", labelMode = "BOTTOM" },
        { unit = "party2", name = "SimpleDispelParty2Button", label = "P2", labelMode = "BOTTOM" },
        { unit = "party3", name = "SimpleDispelParty3Button", label = "P3", labelMode = "BOTTOM" },
        { unit = "party4", name = "SimpleDispelParty4Button", label = "P4", labelMode = "BOTTOM" },
    }
    -- The aura container covers the square icon area at the top of the button
    -- rather than the whole cell, so the name band underneath it can collapse
    -- without moving a debuff icon whose geometry is fixed at creation time.
    for _, definition in ipairs(definitions) do
        definition.auraHeight = PARTY_BUTTON_SIZE
        definition.auraAnchor = "TOP"
    end
    local width = (PARTY_BUTTON_SIZE * #definitions)
        + (PARTY_GAP * (#definitions - 1))
        + (FRAME_PADDING * 2)
    local height = PARTY_BUTTON_HEIGHT + HANDLE_HEIGHT + (FRAME_PADDING * 2)
    local frameInfo = CreateRoot(
        "party",
        "SimpleDispelPartyFrame",
        "SimpleDispel Party",
        width,
        height,
        "[group:raid] hide; show"
    )

    for index, definition in ipairs(definitions) do
        local button = AddUnitButton(
            frameInfo.content,
            definition,
            PARTY_BUTTON_SIZE,
            filterString,
            true,
            PARTY_BUTTON_HEIGHT
        )
        local x = FRAME_PADDING + ((index - 1) * (PARTY_BUTTON_SIZE + PARTY_GAP))
        button:SetPoint("TOPLEFT", frameInfo.content, "TOPLEFT", x, -(HANDLE_HEIGHT + FRAME_PADDING))
    end

    -- Every party button is built with its name band, so this is what collapses
    -- them again when the saved setting hides the names.
    ApplyPartyNameBand()
end

-- issecretvalue/canaccessvalue are only present on clients that can hand back
-- secret combat-log-style values; every read of a Blizzard API result that
-- feeds a decision must be filtered through this before use.
local function IsAccessibleValue(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then
            return false
        end
    end
    if type(canaccessvalue) == "function" then
        local ok, accessible = pcall(canaccessvalue, value)
        if ok and not accessible then
            return false
        end
    end
    return true
end

-- Subgroup layout is only ever built from a fully valid roster snapshot.
-- Sorting all-or-nothing avoids a partially-sorted grid where one unreadable
-- or malformed subgroup value would scatter that single member across the
-- layout while everyone else lines up normally; the index-order fallback
-- below is deterministic and far less surprising.
local function GetRaidSubgroups()
    if type(GetRaidRosterInfo) ~= "function" then
        return nil
    end
    if not (IsInRaid and IsInRaid()) then
        return nil
    end

    local memberCount = 0
    if GetNumGroupMembers then
        memberCount = tonumber(GetNumGroupMembers()) or 0
    end
    memberCount = math.min(40, memberCount)
    if memberCount <= 0 then
        return nil
    end

    local groups = {}
    for index = 1, memberCount do
        local ok, _, _, subgroup = pcall(GetRaidRosterInfo, index)
        if not ok or not IsAccessibleValue(subgroup)
            or type(subgroup) ~= "number" or subgroup < 1 or subgroup > 8 then
            return nil
        end

        local list = groups[subgroup]
        if not list then
            list = {}
            groups[subgroup] = list
        end
        list[#list + 1] = index
    end

    return groups
end

local function GetRaidTopInset()
    if addon.db and addon.db.locked then
        return 0
    end
    return HANDLE_HEIGHT
end

-- Builds the raid grid once per refresh instead of once per button: every
-- raid index gets a cell so state-driver-hidden buttons still resolve to a
-- deterministic point, but only indices with a real roster slot influence
-- the reported column/row counts.
local function BuildRaidLayoutPlan()
    local memberCount = 0
    if GetNumGroupMembers then
        memberCount = tonumber(GetNumGroupMembers()) or 0
    end

    local cells = {}
    for index = 1, 40 do
        cells[index] = {
            column = (index - 1) % RAID_COLUMNS,
            row = math.floor((index - 1) / RAID_COLUMNS),
        }
    end

    local fallbackColumns = math.min(RAID_COLUMNS, math.max(1, memberCount))
    local fallbackRows = math.ceil(math.max(1, math.min(40, memberCount)) / RAID_COLUMNS)

    local groups = GetRaidSubgroups()
    addon.raidGroupsUnavailable = groups == nil
    if not groups then
        return cells, fallbackColumns, fallbackRows
    end

    local occupiedGroups = {}
    for groupNumber in pairs(groups) do
        occupiedGroups[#occupiedGroups + 1] = groupNumber
    end
    table.sort(occupiedGroups)

    local maxGroupSize = 0
    for _, groupNumber in ipairs(occupiedGroups) do
        maxGroupSize = math.max(maxGroupSize, #groups[groupNumber])
    end

    local orientation = addon.db and addon.db.raidLayout
    for groupSlotIndex, groupNumber in ipairs(occupiedGroups) do
        local groupSlot = groupSlotIndex - 1
        for memberSlotIndex, raidIndex in ipairs(groups[groupNumber]) do
            local memberSlot = memberSlotIndex - 1
            if orientation == "down" then
                cells[raidIndex] = { column = memberSlot, row = groupSlot }
            else
                cells[raidIndex] = { column = groupSlot, row = memberSlot }
            end
        end
    end

    local columns, rows
    if orientation == "down" then
        columns, rows = math.max(1, maxGroupSize), math.max(1, #occupiedGroups)
    else
        columns, rows = math.max(1, #occupiedGroups), math.max(1, maxGroupSize)
    end

    return cells, columns, rows
end

local function GetRaidFrameWidth(columns)
    local width = (RAID_BUTTON_SIZE * columns)
        + (RAID_GAP * (columns - 1))
        + (FRAME_PADDING * 2)
    return math.max(RAID_MIN_WIDTH, width)
end

local function GetRaidFrameHeight(rows)
    return (RAID_BUTTON_SIZE * rows)
        + (RAID_GAP * (rows - 1))
        + GetRaidTopInset()
        + (FRAME_PADDING * 2)
end

PositionRaidButtons = function()
    if InCombatLockdown() then
        addon.pendingLayoutRefresh = true
        return
    end

    local frameInfo = addon.frames.raid
    if not frameInfo then
        return
    end
    local topInset = GetRaidTopInset()
    local cells = BuildRaidLayoutPlan()
    for index = 1, 40 do
        local button = addon.unitButtons["raid" .. index]
        if button then
            local cell = cells[index]
            local x = FRAME_PADDING + (cell.column * (RAID_BUTTON_SIZE + RAID_GAP))
            local y = -(topInset + FRAME_PADDING + (cell.row * (RAID_BUTTON_SIZE + RAID_GAP)))
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", frameInfo.content, "TOPLEFT", x, y)
        end
    end
end

RefreshRaidFrameSize = function()
    local frameInfo = addon.frames.raid
    if not frameInfo then
        return
    end
    if InCombatLockdown() then
        addon.pendingRaidSizeRefresh = true
        return
    end

    local width, height
    if addon.activeSpell then
        local _, columns, rows = BuildRaidLayoutPlan()
        width = GetRaidFrameWidth(columns)
        height = GetRaidFrameHeight(rows)
    else
        -- The empty state only ever shows explanatory text, so it always uses
        -- the full default 8-column width regardless of roster shape.
        width = GetRaidFrameWidth(RAID_COLUMNS)
        height = EMPTY_STATE_HEIGHT
    end
    frameInfo.root:SetWidth(width)
    frameInfo.root:SetHeight(height)
    addon.pendingRaidSizeRefresh = false
end

local function CreateRaidUI(filterString)
    local _, planColumns, planRows = BuildRaidLayoutPlan()
    local width = addon.activeSpell and GetRaidFrameWidth(planColumns) or GetRaidFrameWidth(RAID_COLUMNS)
    local height = addon.activeSpell and GetRaidFrameHeight(planRows) or EMPTY_STATE_HEIGHT
    local frameInfo = CreateRoot(
        "raid",
        "SimpleDispelRaidFrame",
        "SD",
        width,
        height,
        "[group:raid] show; hide",
        true
    )

    for index = 1, 40 do
        local definition = {
            unit = "raid" .. index,
            name = "SimpleDispelRaid" .. index .. "Button",
            label = "",
            auraWidth = RAID_BUTTON_SIZE,
            auraHeight = RAID_BUTTON_SIZE,
            auraAnchor = "CENTER",
        }
        local button = AddUnitButton(
            frameInfo.content,
            definition,
            RAID_BUTTON_SIZE,
            filterString,
            false,
            RAID_BUTTON_SIZE
        )
    end
    PositionRaidButtons()
end

local function UpdateDispelAvailability(spell)
    local hasDispel = spell ~= nil
    for _, frameInfo in pairs(addon.frames) do
        frameInfo.content:SetShown(hasDispel)
        frameInfo.emptyState:SetShown(not hasDispel)
    end
    local raidFrame = addon.frames.raid
    if raidFrame then
        raidFrame.background:SetShown(not addon.db.locked or not hasDispel)
    end
    RefreshRaidFrameSize()
end

local function IsRangeUnitActive(unit, layoutKey)
    if layoutKey == "raid" then
        return string.match(unit, "^raid%d+$") ~= nil
    end
    return unit == "player" or string.match(unit, "^party%d+$") ~= nil
end

function addon:RefreshRangeState()
    local spell = self.activeSpell
    local spellIdentifier = spell and (spell.name or spell.id)
    local canCheckRange = spellIdentifier
        and C_Spell
        and type(C_Spell.IsSpellInRange) == "function"
    local layoutKey = GetActiveLayoutKey()

    for unit, button in pairs(self.unitButtons) do
        local inRange
        local unitActive = IsRangeUnitActive(unit, layoutKey)
        local unitExists = false
        if unitActive then
            unitExists = unit == "player" or not UnitExists or UnitExists(unit)
        end
        if canCheckRange and unitActive and unitExists then
            -- Use the same localized spell name assigned to spell1 so talent
            -- overrides follow the exact action the secure button will cast.
            local ok, result = pcall(C_Spell.IsSpellInRange, spellIdentifier, unit)
            if ok and IsAccessibleValue(result) then
                inRange = result
            end
        end
        self.SecureButtons:SetRangeState(button, inRange)
    end
end

function addon:RefreshCooldownState(fromCooldownEvent)
    local spell = self.activeSpell
    local onCooldown = self.dispelCooldownActive

    if not spell then
        onCooldown = nil
    elseif C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
        -- Match the localized spell name assigned to the secure action so
        -- talent overrides report the cooldown of the action actually cast.
        local spellIdentifier = spell.name or spell.id
        local ok, cooldownInfo = pcall(C_Spell.GetSpellCooldown, spellIdentifier)
        if ok and type(cooldownInfo) == "table" then
            local isActive = cooldownInfo.isActive
            if IsAccessibleValue(isActive) and type(isActive) == "boolean" then
                if not isActive then
                    onCooldown = false
                elseif fromCooldownEvent then
                    -- isOnGCD is documented as reliable while responding to
                    -- SPELL_UPDATE_COOLDOWN. Do not dim the dispel UI for an
                    -- unrelated global cooldown.
                    local isOnGCD = cooldownInfo.isOnGCD
                    if IsAccessibleValue(isOnGCD) and type(isOnGCD) == "boolean" then
                        onCooldown = not isOnGCD
                    end
                -- A non-event active result never establishes a new cooldown:
                -- isOnGCD is not reliable here, so ready/unknown is retained
                -- until SPELL_UPDATE_COOLDOWN supplies the distinction.
                elseif self.dispelCooldownActive == true then
                    -- No event is guaranteed when a normal cooldown reaches
                    -- zero. Poll only to retain/clear an already-known state.
                    onCooldown = true
                end
            end
        end
    end

    self.dispelCooldownActive = onCooldown
    for _, button in ipairs(self.buttons) do
        self.SecureButtons:SetCooldownState(button, onCooldown)
    end
    return onCooldown
end

local function CreateUI()
    local filterString = addon.AuraDisplay:GetFilter(addon.db.filterMode)
    CreatePartyUI(filterString)
    CreateRaidUI(filterString)
    UpdateGroupLabels()
    ApplyAllFrameSettings()
    UpdateDispelAvailability(nil)

    if addon.auraError then
        Print("Aura display unavailable: " .. addon.auraError)
    end
end

function addon:RefreshSpell()
    if InCombatLockdown() then
        self.pendingSpellRefresh = true
        return false
    end

    local previousSpell = self.activeSpell
    local spell = self.Spells:Resolve()
    for _, button in ipairs(self.buttons) do
        self.SecureButtons:SetSpell(button, spell)
    end

    local sameSpell = previousSpell
        and spell
        and previousSpell.id == spell.id
        and previousSpell.name == spell.name
    self.activeSpell = spell
    if not sameSpell then
        self.dispelCooldownActive = nil
    end
    UpdateDispelAvailability(spell)
    self:RefreshRangeState()
    self:RefreshCooldownState(false)
    self.pendingSpellRefresh = false
    return true
end

local function PrintStatus()
    local gameVersion, build, _, tocVersion = GetBuildInfo()
    local supported, supportError = addon.AuraDisplay:IsSupported()
    local spell = addon.activeSpell

    Print(string.format(
        "addon=%s game=%s build=%s toc=%s combat=%s mode=%s",
        GetAddonVersion(),
        tostring(gameVersion),
        tostring(build),
        tostring(tocVersion),
        tostring(InCombatLockdown()),
        GetActiveLayoutKey()
    ))
    Print(string.format(
        "auraContainer=%s filter=%s containers=%d buttons=5+40 locked=%s",
        supported and "yes" or ("no: " .. tostring(supportError)),
        addon.AuraDisplay:GetFilter(addon.db.filterMode),
        #addon.auraContainers,
        tostring(addon.db.locked)
    ))
    Print(string.format(
        "partyScale=%.2f raidScale=%.2f theme=%s partyNames=%s",
        addon.db.layouts.party.scale or 1,
        addon.db.layouts.raid.scale or 1,
        addon.Theme:GetActive(),
        PartyNamesShown() and "shown" or "hidden"
    ))
    Print(string.format(
        "raidLayout=%s raidGroups=%s",
        addon.db.raidLayout,
        addon.raidGroupsUnavailable and "unavailable" or "sorted"
    ))

    if spell then
        local cooldownStatus = "unknown"
        if addon.dispelCooldownActive == true then
            cooldownStatus = "cooldown"
        elseif addon.dispelCooldownActive == false then
            cooldownStatus = "ready"
        end
        Print(string.format(
            "spell=%s (%d), source=%s, spellbookKnown=%s, cooldown=%s",
            spell.name,
            spell.id,
            tostring(spell.source),
            tostring(spell.known),
            cooldownStatus
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
    Print("/sd theme <" .. THEME_HELP .. ">")
    Print("/sd names <show|hide>")
    Print("/sd raidlayout <across|down>")
    Print("/sd lock | /sd unlock")
    Print("/sd scale <0.60-2.00> [party|raid]")
    Print("/sd reset [party|raid|all]")
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
    if not info.known then
        Print("spell is not known by this character: " .. info.name .. " (" .. spellID .. ")")
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

local function HandleThemeCommand(argument)
    if argument == "" then
        Print("theme is " .. addon.Theme:GetActive() .. "; use /sd theme " .. THEME_HELP)
        return
    end
    if not addon.Theme:IsValid(argument) then
        Print("theme must be one of: " .. THEME_HELP)
        return
    end

    addon.db.theme = argument
    ApplyTheme()
    Print("theme set to " .. argument)
end

local function HandleNamesCommand(argument)
    if argument == "" then
        Print("party names are " .. (PartyNamesShown() and "shown" or "hidden")
            .. "; use /sd names <show|hide>")
        return
    end

    local hidden
    if argument == "show" or argument == "on" then
        hidden = false
    elseif argument == "hide" or argument == "off" then
        hidden = true
    else
        Print("usage: /sd names <show|hide>")
        return
    end

    addon.db.hidePartyNames = hidden
    ApplyPartyNameBand()
    Print(hidden
        and "party names hidden; party buttons are square"
        or "party names shown below each party button")
    if InCombatLockdown() then
        Print("layout will update after combat")
    end
end

local function HandleRaidLayoutCommand(argument)
    if argument == "" then
        Print("raid layout is " .. addon.db.raidLayout .. "; use /sd raidlayout <across|down>")
        return
    end

    if argument ~= "across" and argument ~= "down" then
        Print("usage: /sd raidlayout <across|down>")
        return
    end

    addon.db.raidLayout = argument
    PositionRaidButtons()
    RefreshRaidFrameSize()
    Print("raid layout set to " .. argument)
    if InCombatLockdown() then
        Print("layout will update after combat")
    end
end

local function HandleLockCommand(locked)
    addon.db.locked = locked
    ApplyAllFrameSettings()
    Print(locked and "party and raid frames locked" or "frames unlocked; drag the visible handle to move")
    if InCombatLockdown() then
        Print("layout will update after combat")
    end
end

local function ParseScaleArgument(argument)
    local first, second = string.match(argument or "", "^(%S+)%s*(%S*)$")
    local layoutKey = GetActiveLayoutKey()
    local scale

    if first == "party" or first == "raid" then
        layoutKey = first
        scale = tonumber(second)
    else
        scale = tonumber(first)
        if second == "party" or second == "raid" then
            layoutKey = second
        elseif second ~= "" then
            return nil, nil
        end
    end
    return scale, layoutKey
end

local function HandleScaleCommand(argument)
    local scale, layoutKey = ParseScaleArgument(argument)
    if not scale or not layoutKey or scale < MIN_SCALE or scale > MAX_SCALE then
        Print(string.format("usage: /sd scale <%.2f-%.2f> [party|raid]", MIN_SCALE, MAX_SCALE))
        return
    end

    addon.db.layouts[layoutKey].scale = scale
    ApplyFrameSettings(layoutKey)
    Print(string.format("%s scale set to %.2f", layoutKey, scale))
    if InCombatLockdown() then
        Print("layout will update after combat")
    end
end

local function ResetLayout(argument)
    local layoutKey = argument ~= "" and argument or GetActiveLayoutKey()
    if layoutKey ~= "party" and layoutKey ~= "raid" and layoutKey ~= "all" then
        Print("usage: /sd reset [party|raid|all]")
        return
    end

    if layoutKey == "all" then
        addon.db.layouts.party = NewDefaultLayout("party")
        addon.db.layouts.raid = NewDefaultLayout("raid")
        ApplyAllFrameSettings()
    else
        addon.db.layouts[layoutKey] = NewDefaultLayout(layoutKey)
        ApplyFrameSettings(layoutKey)
    end

    Print(layoutKey .. " position and scale reset")
    if InCombatLockdown() then
        Print("layout will update after combat")
    end
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
    elseif command == "theme" then
        HandleThemeCommand(argument)
    elseif command == "names" then
        HandleNamesCommand(argument)
    elseif command == "raidlayout" then
        HandleRaidLayoutCommand(argument)
    elseif command == "lock" then
        HandleLockCommand(true)
    elseif command == "unlock" then
        HandleLockCommand(false)
    elseif command == "scale" then
        HandleScaleCommand(argument)
    elseif command == "reset" then
        ResetLayout(argument)
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
local rangeElapsed = 0
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not addon.activeSpell then
        rangeElapsed = 0
        return
    end

    rangeElapsed = rangeElapsed + (tonumber(elapsed) or 0)
    if rangeElapsed < RANGE_UPDATE_INTERVAL then
        return
    end

    rangeElapsed = rangeElapsed % RANGE_UPDATE_INTERVAL
    addon:RefreshRangeState()
    addon:RefreshCooldownState(false)
end)
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then
            return
        end

        self:UnregisterEvent("ADDON_LOADED")
        InitializeDatabase()
        RegisterSlashCommands()
        CreateUI()

        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("UNIT_NAME_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("TRAIT_CONFIG_UPDATED")
        return
    end

    if event == "PLAYER_LOGIN" then
        addon:RefreshSpell()
        UpdateGroupLabels()
        PositionRaidButtons()
        RefreshRaidFrameSize()
        if addon.activeSpell then
            Print("v" .. GetAddonVersion() .. " loaded; party + raid ready; use /sd status")
        else
            Print("v" .. GetAddonVersion() .. " loaded; no dispel spell available; use /sd status")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Retry after login because the spellbook can finish settling while
        -- the player enters the world.
        addon:RefreshSpell()
        UpdateGroupLabels()
        PositionRaidButtons()
        RefreshRaidFrameSize()
    elseif event == "GROUP_ROSTER_UPDATE" then
        UpdateGroupLabels()
        -- Group membership changes can move members between subgroups, which
        -- changes their cell in the layout, not just which buttons are shown.
        PositionRaidButtons()
        RefreshRaidFrameSize()
        addon:RefreshRangeState()
    elseif event == "UNIT_NAME_UPDATE" then
        UpdateGroupLabels()
    elseif event == "PLAYER_REGEN_DISABLED" then
        StopActiveDrag()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if addon.pendingSpellRefresh then
            addon:RefreshSpell()
        end
        if addon.pendingLayoutRefresh then
            ApplyAllFrameSettings()
        else
            UpdateLockState()
        end
        if addon.pendingRaidSizeRefresh then
            RefreshRaidFrameSize()
        end
        if addon.pendingNameBandRefresh then
            ApplyPartyNameBand()
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        addon:RefreshCooldownState(true)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED" then
        addon:RefreshSpell()
    end
end)
