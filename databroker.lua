local NPT = tNameplateTargetAddon

function NPT.OpenOptions()
    Settings.OpenToCategory(NPT.category:GetID())
end

local function StatusText()
    if NPT.db.tankMode then
        return "|cff4dff4dTank mode|r"
    end
    return "|cffaaaaaaTank mode off|r"
end

-- Called from Refresh so the text also follows changes made in the options panel
function NPT.UpdateBroker()
    if NPT.broker then
        NPT.broker.text = StatusText()
    end
end

function NPT.ToggleTankMode()
    NPT.db.tankMode = not NPT.db.tankMode
    NPT.Refresh()   -- redraws labels and updates the broker text
end

function NPT.InitBroker()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    NPT.broker = LDB:NewDataObject("NameplateTarget", {
        type = "data source",
        label = "Nameplate Target",
        icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        text = StatusText(),

        OnClick = function(_, button)
            if button == "LeftButton" then
                NPT.OpenOptions()
            elseif button == "RightButton" then
                NPT.ToggleTankMode()
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Nameplate Target")
            tooltip:AddLine("|cffffffffLeft-click|r to open settings")
            tooltip:AddLine("|cffffffffRight-click|r to toggle tank mode")
            tooltip:AddLine(" ")
            tooltip:AddLine("Tank mode: " .. (NPT.db.tankMode and "On" or "Off"))
        end,
    })
end