local ADDON_NAME = ...

local NPT = {}
tNameplateTargetAddon = NPT

NPT.defaults = {
    offsetX = 0,
    offsetY = -2,
    fontSize = 12,
    prefix = "",
    hostileOnly = true,
    showThreat = true,
    tankMode = false,
}

local db                -- set to the saved variables on ADDON_LOADED
local labels, pool = {}, {}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

-- Returns true/false, or nil if the value is secret
local function SafeBool(v)
    if isSecret(v) then return nil end
    return v and true or false
end

---------------------------------------------------------------------
-- Label pool: each label has a target line and a threat line
---------------------------------------------------------------------
function NPT.ApplyFont(f)
    f.target:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    f.threat:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
end

function NPT.AcquireLabel()
    local f = table.remove(pool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(1, 1)
        f:SetFrameStrata("MEDIUM")

        f.target = f:CreateFontString(nil, "OVERLAY")
        f.target:SetPoint("TOP", f, "TOP", 0, 0)
        f.target:SetJustifyH("CENTER")

        f.threat = f:CreateFontString(nil, "OVERLAY")
        f.threat:SetPoint("TOP", f.target, "BOTTOM", 0, -1)
        f.threat:SetJustifyH("CENTER")
    end
    NPT.ApplyFont(f)
    return f
end

function NPT.ReleaseLabel(unit)
    local f = labels[unit]
    if f then
        f:Hide()
        f:ClearAllPoints()
        labels[unit] = nil
        pool[#pool + 1] = f
    end
end

function NPT.ReleaseAll()
    for unit in pairs(labels) do
        NPT.ReleaseLabel(unit)
    end
end

---------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------
-- Tank palette: 0 = no lead (bad), 3 = securely tanking (good)
local tankStateColors = {
    [0] = { 1.0, 0.2, 0.2 },   -- red
    [1] = { 1.0, 0.5, 0.1 },   -- orange
    [2] = { 1.0, 0.9, 0.1 },   -- yellow
    [3] = { 0.3, 1.0, 0.3 },   -- green
}

local constantThreatColor = { 1, 1, 1 }   -- used when tank mode is off

function NPT.GetTargetColor(unit)
    -- Class color only when we can positively tell it's a player.
    -- The color values themselves may be secret, which is fine for SetTextColor.
    if SafeBool(UnitIsPlayer(unit)) == true then
        local baseClass = UnitClassBase(unit)
        local c = C_ClassColor.GetClassColor(baseClass)
        if c then return c.r, c.g, c.b end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction and not isSecret(reaction) then
            local c = FACTION_BAR_COLORS[reaction]
            if c then return c.r, c.g, c.b end
        end
    end
    return 1, 1, 1
end

---------------------------------------------------------------------
-- Update logic
---------------------------------------------------------------------
function NPT.UpdateThreat(f, unit)
    if not db.showThreat then
        f.threat:SetText("")
        return
    end

    local _, _, pct = UnitDetailedThreatSituation("player", unit)
    if pct == nil then
        f.threat:SetText("")
        return
    end

    f.threat:SetFormattedText("%d%%", pct)   -- secret number, display only

    local color = constantThreatColor
    if db.tankMode then
        local state = UnitThreatLeadSituation("player", unit)
        if state ~= nil then
            color = tankStateColors[state]
        end
    end
    f.threat:SetTextColor(unpack(color))
end

function NPT.UpdateUnit(unit)
    if not db then return end   -- not loaded yet

    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then
        NPT.ReleaseLabel(unit)
        return
    end

    if db.hostileOnly and SafeBool(UnitCanAttack("player", unit)) == false then
        NPT.ReleaseLabel(unit)
        return
    end

    local targetUnit = unit .. "target"
    if not UnitExists(targetUnit) then
        NPT.ReleaseLabel(unit)
        return
    end

    local f = labels[unit]
    if not f then
        f = NPT.AcquireLabel()
        labels[unit] = f
    end

    f:ClearAllPoints()
    f:SetPoint("TOP", plate, "BOTTOM", db.offsetX, db.offsetY)

    if SafeBool(UnitIsUnit(targetUnit, "player")) then
        f.target:SetText(db.prefix .. "YOU")
        f.target:SetTextColor(1, 0.2, 0.2)
    else
        f.target:SetFormattedText("%s%s", db.prefix, UnitName(targetUnit) or "")
        f.target:SetTextColor(NPT.GetTargetColor(targetUnit))
    end

    NPT.UpdateThreat(f, unit)
    f:Show()
end

function NPT.UpdateAll()
    for unit in pairs(labels) do
        NPT.UpdateUnit(unit)
    end
end

-- Called by the options panel whenever a setting changes
function NPT.Refresh()
    for _, f in pairs(labels) do
        NPT.ApplyFont(f)
    end
    NPT.UpdateAll()
end

---------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------
function NPT.LoadSettings()
    tAggroTargetDB = tAggroTargetDB or {}
    db = tAggroTargetDB

    for k, v in pairs(NPT.defaults) do
        if db[k] == nil then db[k] = v end
    end

    -- migrate old 1/0 settings to booleans
    for _, k in ipairs({ "hostileOnly", "showThreat", "tankMode" }) do
        if type(db[k]) == "number" then db[k] = db[k] ~= 0 end
    end

    NPT.db = db
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
function NPT.OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        NPT.LoadSettings()
        NPT.InitOptions()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        NPT.UpdateUnit(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        NPT.ReleaseLabel(arg1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        NPT.ReleaseAll()
    elseif arg1 and arg1:find("^nameplate") then
        -- UNIT_TARGET and the threat events
        NPT.UpdateUnit(arg1)
    end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
driver:RegisterEvent("UNIT_TARGET")
driver:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
driver:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:SetScript("OnEvent", NPT.OnEvent)

-- Backup polling; the threat events don't always fire per nameplate
C_Timer.NewTicker(0.3, NPT.UpdateAll)

---------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------
SLASH_NAMEPLATETARGET1 = "/npt"
SlashCmdList.NAMEPLATETARGET = function(msg)
    if msg == "" then
        Settings.OpenToCategory(NPT.category:GetID())
        return
    end

    local key, val = msg:match("^(%S+)%s+(%S+)$")
    val = tonumber(val)
    if key and val and type(NPT.defaults[key]) == "number" then
        db[key] = val
        NPT.Refresh()
        print("NameplateTarget:", key, "=", val)
    else
        print("NameplateTarget: /npt (opens settings) or /npt offsetX|offsetY|fontSize <number>")
    end
end