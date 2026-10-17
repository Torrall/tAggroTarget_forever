local NPT = tNameplateTargetAddon

local function Msg(text)
    print("|cff33ccfftAggroTarget:|r " .. text)
end

function NPT.OpenOptions()
    if InCombatLockdown() then
        Msg("Can't open the settings in combat.")
        return
    end
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
    Msg("Tank mode " .. (NPT.db.tankMode and "|cff4dff4dON|r" or "|cffaaaaaaOFF|r"))
end

function NPT.InitBroker()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    NPT.broker = LDB:NewDataObject("tAggroTarget", {
        type = "data source",
        label = "tAggroTarget",
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
            tooltip:AddLine("tAggroTarget")
            tooltip:AddLine("|cffffffffLeft-click|r to open settings")
            tooltip:AddLine("|cffffffffRight-click|r to toggle tank mode")
            tooltip:AddLine(" ")
            tooltip:AddLine("Tank mode: " .. (NPT.db.tankMode and "On" or "Off"))
        end,
    })
end