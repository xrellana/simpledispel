local _, addon = ...

local Options = { settings = {} }
addon.Options = Options

local L = {
    general = "General", party = "Party", raid = "Raid", dispel = "Dispel", tools = "Tools",
    locked = "Lock frames", lockedHelp = "Unlock to drag the hover handle just outside either frame's top-left edge on the left.",
    theme = "Theme", dark = "Dark", light = "Light", themeHelp = "Changes the appearance of both layouts immediately.",
    noDispel = "Show frames without a dispel", noDispelHelp = "Keep an explanatory panel visible when this character has no known friendly dispel.",
    names = "Show party member names", namesHelp = "Hide the name band to make party buttons square.",
    partyScale = "Party scale", raidScale = "Raid scale",
    scaleHelp = "Saved separately for each layout. 100% is the default; the range is 60%–200%.",
    combatHelp = "Layout and spell changes made during combat apply after combat ends.",
    orientation = "Raid subgroup arrangement", across = "Groups side by side", down = "Groups stacked vertically",
    orientationHelp = "Side by side: each group is a column. Stacked vertically: each group is a row.",
    filter = "Aura filter (reload required)", mine = "Default", group = "Group-dispellable", all = "Broad dispellable",
    filterHelp = "The game determines which aura is shown. Changing this setting requires Reload UI below.",
    spell = "Dispel spell", auto = "Automatic detection", unavailable = "Unavailable on this character",
    spellHelp = "Choose a known dispel or let the addon select it. A saved spell unavailable on this character falls back to automatic detection.",
    manual = "Custom spell ID", enterID = "Enter ID…",
    manualHelp = "Override detection with a spell this character knows. Use Automatic detection above to clear the override.",
    spellPrompt = "Enter the ID of a friendly dispel spell this character knows.",
    invalidSpell = "Enter a positive whole-number spell ID known by this character.",
    apply = "Apply", cancel = "Cancel",
    resetParty = "Party position and scale", resetRaid = "Raid position and scale", resetAll = "Both positions and scales",
    reset = "Reset", resetHelp = "Restore the selected layout's default position and 100% scale. Other settings are kept.",
    reload = "Reload UI", reloadHelp = "Reload the interface to apply the selected aura filter.",
    reloadCombat = "Leave combat before reloading the interface.",
    status = "Diagnostics", printStatus = "Print status", statusHelp = "Print addon, layout and spell information in chat.",
    unavailableSettings = "Settings are unavailable; use /sd help for commands.",
}

local locale = GetLocale and GetLocale()
local translations = {
    zhCN = {
        general = "通用", party = "小队", raid = "团队", dispel = "驱散", tools = "工具",
        locked = "锁定框体", lockedHelp = "取消锁定后，将鼠标移到框体左上角的左侧外缘，即可使用悬停把手拖动。",
        theme = "外观主题", dark = "深色", light = "浅色", themeHelp = "立即更改小队和团队框体的外观。",
        noDispel = "没有驱散技能时仍显示框体", noDispelHelp = "当前角色没有可用的友方驱散技能时，保留说明面板。",
        names = "显示小队成员名字", namesHelp = "隐藏名字条后，小队按钮变为正方形。",
        partyScale = "小队缩放", raidScale = "团队缩放",
        scaleHelp = "小队和团队分别保存。默认 100%，可调整范围为 60%–200%。",
        combatHelp = "战斗中修改布局或技能，会在脱战后生效。",
        orientation = "团队小组排列", across = "各小组横向并排", down = "各小组纵向排列",
        orientationHelp = "横向并排时，每个小组占一列；纵向排列时，每个小组占一行。",
        filter = "光环过滤方式（重载后生效）", mine = "默认", group = "团队可驱散", all = "广泛可驱散",
        filterHelp = "由游戏决定显示哪个光环。修改后请点击下方的“重载界面”。",
        spell = "驱散技能", auto = "自动检测", unavailable = "当前角色不可用",
        spellHelp = "选择已学会的驱散技能，或交给插件自动检测。若保存的技能当前角色不可用，则回退到自动检测。",
        manual = "自定义技能 ID", enterID = "输入 ID…",
        manualHelp = "用当前角色已学会的技能覆盖自动检测。选择上方的“自动检测”可取消覆盖。",
        spellPrompt = "请输入当前角色已学会的友方驱散技能 ID。",
        invalidSpell = "请输入当前角色已学会的技能 ID，必须为正整数。",
        apply = "应用", cancel = "取消",
        resetParty = "小队位置与缩放", resetRaid = "团队位置与缩放", resetAll = "两个框体的位置与缩放",
        reset = "重置", resetHelp = "恢复所选框体的默认位置和 100% 缩放，保留其他设置。",
        reload = "重载界面", reloadHelp = "重新加载界面，使所选光环过滤方式生效。",
        reloadCombat = "请在脱战后重载界面。",
        status = "诊断信息", printStatus = "输出状态", statusHelp = "在聊天窗口输出插件、布局和技能信息。",
        unavailableSettings = "设置界面不可用；输入 /sd help 查看命令。",
    },
    zhTW = {
        general = "一般", party = "隊伍", raid = "團隊", dispel = "驅散", tools = "工具",
        locked = "鎖定框架", lockedHelp = "解除鎖定後，將滑鼠移到框架左上角的左側外緣，即可使用懸停把手拖曳。",
        theme = "外觀主題", dark = "深色", light = "淺色", themeHelp = "立即變更隊伍和團隊框架的外觀。",
        noDispel = "沒有驅散技能時仍顯示框架", noDispelHelp = "目前角色沒有可用的友方驅散技能時，保留說明面板。",
        names = "顯示隊伍成員名字", namesHelp = "隱藏名字列後，隊伍按鈕會變成正方形。",
        partyScale = "隊伍縮放", raidScale = "團隊縮放",
        scaleHelp = "隊伍和團隊分別儲存。預設 100%，可調整範圍為 60%–200%。",
        combatHelp = "戰鬥中變更配置或技能，會在脫戰後生效。",
        orientation = "團隊小組排列", across = "各小組橫向並排", down = "各小組縱向排列",
        orientationHelp = "橫向並排時，每個小組佔一欄；縱向排列時，每個小組佔一列。",
        filter = "光環過濾方式（重新載入後生效）", mine = "預設", group = "團隊可驅散", all = "廣泛可驅散",
        filterHelp = "由遊戲決定顯示哪個光環。變更後請按下方的「重新載入介面」。",
        spell = "驅散技能", auto = "自動偵測", unavailable = "目前角色無法使用",
        spellHelp = "選擇已學會的驅散技能，或交給插件自動偵測。若儲存的技能目前角色無法使用，則回復自動偵測。",
        manual = "自訂技能 ID", enterID = "輸入 ID…",
        manualHelp = "使用目前角色已學會的技能覆寫自動偵測。選擇上方的「自動偵測」可取消覆寫。",
        spellPrompt = "請輸入目前角色已學會的友方驅散技能 ID。",
        invalidSpell = "請輸入目前角色已學會的技能 ID，必須為正整數。",
        apply = "套用", cancel = "取消",
        resetParty = "隊伍位置與縮放", resetRaid = "團隊位置與縮放", resetAll = "兩個框架的位置與縮放",
        reset = "重設", resetHelp = "恢復所選框架的預設位置和 100% 縮放，保留其他設定。",
        reload = "重新載入介面", reloadHelp = "重新載入介面，讓所選光環過濾方式生效。",
        reloadCombat = "請在脫戰後重新載入介面。",
        status = "診斷資訊", printStatus = "輸出狀態", statusHelp = "在聊天視窗輸出插件、配置和技能資訊。",
        unavailableSettings = "設定介面無法使用；輸入 /sd help 查看指令。",
    },
}
for key, value in pairs(translations[locale] or {}) do
    L[key] = value
end

function Options:Refresh()
    for _, setting in pairs(self.settings) do
        setting:NotifyUpdate()
    end
end

function Options:GetSpellChoices()
    local container = Settings.CreateControlTextContainer()
    container:Add(0, L.auto)
    local seen = {}
    local function AddSpell(id, saved)
        if not id or seen[id] then return end
        local info = addon.Spells:GetInfo(id)
        if info and info.known then
            container:Add(id, info.name .. " (" .. id .. ")")
            seen[id] = true
        elseif saved then
            container:Add(id, (info and info.name or tostring(id)) .. " — " .. L.unavailable)
            seen[id] = true
        end
    end
    local _, class = UnitClass("player")
    for _, id in ipairs(addon.Spells.Candidates[class] or {}) do
        AddSpell(id)
    end
    AddSpell(addon.db.manualSpellID, true)
    return container:GetData()
end

function Options:ApplySpellID(text)
    local id = tonumber(text)
    if not id or id <= 0 or id > 2147483647 or id % 1 ~= 0 then
        addon.Print(L.invalidSpell)
        return false
    end
    local info = addon.Spells:GetInfo(id)
    if not info or not info.known then
        addon.Print(L.invalidSpell)
        return false
    end
    if not addon.Config.SetSpell(tostring(id)) then return false end
    self:Refresh()
    return true
end

local function RegisterSpellPopup()
    StaticPopupDialogs.SIMPLEDISPEL_SPELL_ID = {
        text = L.spellPrompt, button1 = L.apply, button2 = L.cancel,
        hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(dialog)
            local editBox = dialog:GetEditBox()
            editBox:SetText(addon.db.manualSpellID and tostring(addon.db.manualSpellID) or "")
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        OnAccept = function(dialog)
            -- Returning true keeps invalid input available for correction.
            local accepted = Options:ApplySpellID(dialog:GetEditBox():GetText())
            if not accepted then dialog:GetTextFontString():SetText(L.invalidSpell) end
            return not accepted
        end,
        EditBoxOnEnterPressed = function(editBox)
            if Options:ApplySpellID(editBox:GetText()) then
                editBox:GetParent():Hide()
            else
                editBox:GetParent():GetTextFontString():SetText(L.invalidSpell)
            end
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
    }
end

function Options:Register()
    if self.category then return true end
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return false end
    local category, layout = Settings.RegisterVerticalLayoutCategory("SimpleDispel")
    self.category = category
    local function Section(label)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(label))
    end
    local function Proxy(key, label, default, getter, setter)
        local setting = Settings.RegisterProxySetting(category, "SimpleDispel_" .. key,
            type(default), label, default, getter, setter)
        self.settings[key] = setting
        return setting
    end
    local function Checkbox(key, label, default, getter, setter, help)
        Settings.CreateCheckbox(category, Proxy(key, label, default, getter, setter), help)
    end
    local function Dropdown(key, label, default, getter, setter, choices, help)
        local getChoices = choices
        if type(choices) == "table" then
            getChoices = function()
                local container = Settings.CreateControlTextContainer()
                for _, choice in ipairs(choices) do container:Add(choice[1], choice[2]) end
                return container:GetData()
            end
        end
        Settings.CreateDropdown(category, Proxy(key, label, default, getter, setter), getChoices, help)
    end
    local function Button(label, text, callback, help)
        layout:AddInitializer(CreateSettingsButtonInitializer(label, text, callback, help, true))
    end
    local function Scale(key, label, layoutKey)
        local setting = Proxy(key, label, 100,
            function() return addon.db.layouts[layoutKey].scale * 100 end,
            function(value) addon.Config.SetScale(layoutKey, value / 100) end)
        local options = Settings.CreateSliderOptions(60, 200, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return string.format("%.0f%%", value) end)
        Settings.CreateSlider(category, setting, options, L.scaleHelp .. " " .. L.combatHelp)
    end
    local function Reset(layoutKey)
        addon.Config.ResetLayout(layoutKey)
        self:Refresh()
    end

    Section(L.general)
    Checkbox("Locked", L.locked, false, function() return addon.db.locked end,
        addon.Config.SetLocked, L.lockedHelp)
    Dropdown("Theme", L.theme, "dark", function() return addon.db.theme end,
        addon.Config.SetTheme, {{"dark", L.dark}, {"light", L.light}}, L.themeHelp)
    Checkbox("ShowWithoutDispel", L.noDispel, false, function() return addon.db.showWithoutDispel end,
        function(value) addon.Config.SetNoDispel(value and "show" or "hide") end,
        L.noDispelHelp .. " " .. L.combatHelp)

    Section(L.party)
    Checkbox("PartyNames", L.names, true, function() return not addon.db.hidePartyNames end,
        function(value) addon.Config.SetNames(value and "show" or "hide") end, L.namesHelp .. " " .. L.combatHelp)
    Scale("PartyScale", L.partyScale, "party")
    Button(L.resetParty, L.reset, function() Reset("party") end, L.resetHelp .. " " .. L.combatHelp)

    Section(L.raid)
    Scale("RaidScale", L.raidScale, "raid")
    Dropdown("RaidLayout", L.orientation, "across", function() return addon.db.raidLayout end,
        addon.Config.SetRaidLayout, {{"across", L.across}, {"down", L.down}}, L.orientationHelp .. " " .. L.combatHelp)
    Button(L.resetRaid, L.reset, function() Reset("raid") end, L.resetHelp .. " " .. L.combatHelp)

    Section(L.dispel)
    Dropdown("SpellID", L.spell, 0, function() return addon.db.manualSpellID or 0 end,
        function(value) addon.Config.SetSpell(value == 0 and "auto" or tostring(value)) end,
        function() return self:GetSpellChoices() end, L.spellHelp .. " " .. L.combatHelp)
    RegisterSpellPopup()
    Button(L.manual, L.enterID, function() StaticPopup_Show("SIMPLEDISPEL_SPELL_ID") end, L.manualHelp)
    Dropdown("FilterMode", L.filter, "mine", function() return addon.db.filterMode end,
        addon.Config.SetFilter, {{"mine", L.mine}, {"group", L.group}, {"all", L.all}}, L.filterHelp)
    Button(L.reload, L.reload, function()
        if InCombatLockdown() then
            addon.Print(L.reloadCombat)
        else
            ReloadUI()
        end
    end, L.reloadHelp)

    Section(L.tools)
    Button(L.resetAll, L.reset, function() Reset("all") end, L.resetHelp .. " " .. L.combatHelp)
    Button(L.status, L.printStatus, addon.Config.PrintStatus, L.statusHelp)
    Settings.RegisterAddOnCategory(category)
    return true
end

function Options:Open()
    if not self:Register() then
        addon.Print(L.unavailableSettings)
        return
    end
    self:Refresh()
    Settings.OpenToCategory(self.category:GetID())
end
