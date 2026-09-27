-- Minimal mock of the Retail Settings API used by SimpleDispel's options
-- panel.  The mock intentionally keeps proxy settings live: GetValue reads
-- through the registered getter and SetValue invokes the registered setter.
-- NotifyUpdate only records the notification.  Calling a setter from
-- NotifyUpdate would hide stale-getter bugs in an options implementation.

Settings = {
    VarType = {
        Boolean = "boolean",
        Number = "number",
        String = "string",
    },
    categories = {},
    registeredCategories = {},
    openedCategory = nil,
}

MinimalSliderWithSteppersMixin = {
    Label = { Right = "right" },
}

local nextCategoryID = 0

local function NewInitializer(kind, ...)
    return {
        kind = kind,
        arguments = { ... },
    }
end

local categoryMethods = {}

function categoryMethods:GetID()
    return self.id
end

function categoryMethods:AddInitializer(initializer)
    self.initializers[#self.initializers + 1] = initializer
    return initializer
end

local settingMethods = {}

function settingMethods:GetValue()
    return self.getter()
end

function settingMethods:SetValue(value)
    self.setCalls = self.setCalls + 1
    local result = self.setter(value)
    self.lastSetValue = value
    self.lastSetResult = result
    return result
end

function settingMethods:NotifyUpdate()
    self.notifyCount = self.notifyCount + 1
    self.lastNotifiedValue = self.getter()
end

function settingMethods:GetDefaultValue()
    return self.defaultValue
end

function settingMethods:GetVariable()
    return self.variable
end

function settingMethods:GetName()
    return self.label
end

local function AddControl(category, controlType, setting, ...)
    assert(category and category.settings, "a Settings control needs a category")
    assert(setting and setting.variable, "a Settings control needs a proxy setting")
    local control = {
        type = controlType,
        setting = setting,
        arguments = { ... },
    }
    category.controls[#category.controls + 1] = control
    setting.control = control
    return control
end

function Settings.RegisterVerticalLayoutCategory(name)
    nextCategoryID = nextCategoryID + 1
    local category = setmetatable({
        name = name,
        id = "SimpleDispelCategory" .. nextCategoryID,
        creationIndex = nextCategoryID,
        settings = {},
        controls = {},
        initializers = {},
    }, { __index = categoryMethods })
    Settings.categories[#Settings.categories + 1] = category
    -- Retail returns the category and its vertical layout.  The category is
    -- itself sufficient for this mock's AddInitializer implementation, so a
    -- second reference models the separate return value without introducing
    -- another object that would hide initializers from test inspection.
    return category, category
end

function Settings.RegisterAddOnCategory(category)
    assert(category and category.id, "cannot register an invalid Settings category")
    Settings.registeredCategories[#Settings.registeredCategories + 1] = category
    category.registered = true
    return category
end

function Settings.OpenToCategory(categoryID)
    Settings.openedCategory = categoryID
    Settings.openCount = (Settings.openCount or 0) + 1
end

function Settings.RegisterProxySetting(category, variable, variableType, label, defaultValue, getter, setter)
    assert(category and category.settings, "a proxy setting needs a category")
    assert(type(variable) == "string" and variable ~= "", "a proxy setting needs a variable name")
    assert(type(getter) == "function", "a proxy setting needs a getter")
    assert(type(setter) == "function", "a proxy setting needs a setter")

    local setting = setmetatable({
        category = category,
        variable = variable,
        variableType = variableType,
        label = label,
        defaultValue = defaultValue,
        getter = getter,
        setter = setter,
        setCalls = 0,
        notifyCount = 0,
    }, { __index = settingMethods })
    category.settings[#category.settings + 1] = setting
    category.settingsByVariable = category.settingsByVariable or {}
    category.settingsByVariable[variable] = setting
    Settings.proxySettings = Settings.proxySettings or {}
    Settings.proxySettings[variable] = setting
    return setting
end

function Settings.CreateCheckbox(category, setting, ...)
    return AddControl(category, "checkbox", setting, ...)
end

function Settings.CreateSlider(category, setting, ...)
    return AddControl(category, "slider", setting, ...)
end

function Settings.CreateDropdown(category, setting, ...)
    return AddControl(category, "dropdown", setting, ...)
end

-- Some implementations use the native text-container helper to populate a
-- dropdown.  Keeping it here costs little and lets the mock accept either
-- the direct table form or the native container form.
function Settings.CreateControlTextContainer()
    local container = { values = {}, labels = {} }
    function container:Add(value, label)
        self.values[#self.values + 1] = value
        self.labels[value] = label
    end
    function container:GetData()
        local data = {}
        for index, value in ipairs(self.values) do
            local label = self.labels[value]
            data[index] = {
                value = value,
                label = label,
                text = label,
                controlType = "dropdown",
            }
        end
        return data
    end
    return container
end

function Settings.CreateSliderOptions(minimum, maximum, step)
    local options = {
        minimumValue = minimum,
        maximumValue = maximum,
        valueStep = step,
    }
    function options:SetLabelFormatter(mixin, formatter)
        self.labelMixin = mixin
        self.labelFormatter = formatter
    end
    return options
end

function CreateSettingsButtonInitializer(label, buttonText, callback, tooltip, addSearchTags)
    assert(addSearchTags ~= nil, "button initializers must provide addSearchTags")
    return NewInitializer("button", label, buttonText, callback, tooltip, addSearchTags)
end

function CreateSettingsListSectionHeaderInitializer(label)
    return NewInitializer("section-header", label)
end

StaticPopupDialogs = {}

local function NewPopupDialog(definition)
    local dialog = {
        definition = definition,
        shown = true,
    }
    local editBox = {
        text = "",
        parent = dialog,
    }
    function editBox:SetText(text)
        self.text = text
    end
    function editBox:GetText()
        return self.text
    end
    function editBox:SetFocus()
        self.focused = true
    end
    function editBox:HighlightText()
        self.highlighted = true
    end
    function editBox:GetParent()
        return self.parent
    end
    function dialog:GetEditBox()
        return editBox
    end
    function dialog:Hide()
        self.shown = false
    end
    function dialog:GetTextFontString()
        local fontString = self.textFontString
        if not fontString then
            fontString = { text = "" }
            function fontString:SetText(text)
                self.text = text
            end
            self.textFontString = fontString
        end
        return fontString
    end
    dialog.editBox = editBox
    if definition.OnShow then
        definition.OnShow(dialog)
    end
    return dialog
end

function StaticPopup_Show(name)
    local definition = StaticPopupDialogs[name]
    assert(definition, "unknown StaticPopup dialog: " .. tostring(name))
    local dialog = NewPopupDialog(definition)
    StaticPopupDialogs.lastShown = dialog
    StaticPopupDialogs.lastName = name
    return dialog
end

function ReloadUI()
    Settings.reloadCount = (Settings.reloadCount or 0) + 1
end

-- These aliases are useful to tests and make it easy to inspect all controls
-- without depending on implementation-specific category fields.
function Settings.GetCategory(name)
    for _, category in ipairs(Settings.categories) do
        if category.name == name then
            return category
        end
    end
end

function Settings.ResetMock()
    Settings.categories = {}
    Settings.registeredCategories = {}
    Settings.proxySettings = nil
    Settings.openedCategory = nil
    Settings.openCount = 0
    nextCategoryID = 0
end
