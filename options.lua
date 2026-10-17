local ADDON_NAME = ...
local NPT = NameplateTargetAddon   -- created in the main file (see step 3)

function NPT.InitOptions()
    local db = NPT.db
    local defaults = NPT.defaults

    local category, layout = Settings.RegisterVerticalLayoutCategory("Nameplate Target")

    -- Helper: bind a setting to db[key]
    local function Bind(key, varType, label)
        local variable = "NPT_" .. key
        local setting = Settings.RegisterAddOnSetting(
                category, variable, key, db, varType, label, defaults[key])
        Settings.SetOnValueChangedCallback(variable, NPT.Refresh)
        return setting
    end

    local function Header(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function Slider(key, label, tooltip, min, max, step)
        local setting = Bind(key, Settings.VarType.Number, label)
        local options = Settings.CreateSliderOptions(min, max, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, setting, options, tooltip)
    end

    local function Checkbox(key, label, tooltip)
        local setting = Bind(key, Settings.VarType.Boolean, label)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    ---------------------------------------------------------------
    Header("Appearance")

    Slider("fontSize", "Font size", "Size of the text under each nameplate.", 8, 24, 1)
    Slider("offsetX", "Horizontal offset", "Moves the label left or right.", -100, 100, 1)
    Slider("offsetY", "Vertical offset", "Moves the label up or down.", -100, 100, 1)

    local prefixSetting = Bind("prefix", Settings.VarType.String, "Target prefix")
    local function PrefixOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("→ ", "Arrow")
        container:Add("⚔ ", "Swords")
        container:Add("> ", "Chevron")
        container:Add("• ", "Dot")
        return container:GetData()
    end
    Settings.CreateDropdown(category, prefixSetting, PrefixOptions,
            "Symbol shown before the target's name.")

    ---------------------------------------------------------------
    Header("Behavior")

    Checkbox("hostileOnly", "Hostile units only",
            "Only show labels on units you can attack.")

    ---------------------------------------------------------------
    Header("Threat")

    Checkbox("showThreat", "Show threat percentage",
            "Shows your threat percentage on each mob.")
    Checkbox("tankMode", "Tank mode",
            "Colors the threat line by lead state (red = no lead, green = securely tanking). When off, the color is constant.")

    Settings.RegisterAddOnCategory(category)
    NPT.category = category
end