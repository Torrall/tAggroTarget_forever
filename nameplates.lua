local ADDON_NAME = ...

local defaults = {
    offsetX = 0,
    offsetY = -2,
    fontSize = 12,
    prefix = "→ ",
    hostileOnly = 1,   -- 1 = only attackable units
    showThreat = 1,    -- 1 = show your threat % on the mob
}
local db = defaults

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function SafeBool(v)
    if isSecret(v) then return nil end
    return v and true or false
end

---------------------------------------------------------------------
-- Label pool: each label has a target line and a threat line
---------------------------------------------------------------------
local labels, pool = {}, {}

local function ApplyFont(f)
    f.target:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    f.threat:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
end

local function AcquireLabel()
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
    ApplyFont(f)
    return f
end

local function ReleaseLabel(unit)
    local f = labels[unit]
    if f then
        f:Hide()
        f:ClearAllPoints()
        labels[unit] = nil
        pool[#pool + 1] = f
    end
end

---------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------
local function GetTargetColor(unit)
    -- Only use class color when we can positively tell it's a player
    local reaction = UnitReaction(unit, "player")
    if SafeBool(UnitIsPlayer(unit)) == true then
        local classToken = UnitClassBase(unit)
        local c = C_ClassColor.GetClassColor(classToken)
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

local function GetThreatColor(pct)
    if isSecret(pct) then return 1, 1, 1 end   -- can't compare, so neutral
    if pct >= 100 then return 1, 0.2, 0.2 end
    if pct >= 80 then return 1, 0.8, 0.1 end
    return 0.3, 1, 0.3
end

---------------------------------------------------------------------
-- Update logic
---------------------------------------------------------------------
local function UpdateThreat(f, unit)
    if db.showThreat ~= 1 then
        f.threat:SetText("")
        return
    end

    -- Returns: isTanking, status, scaledPct, rawPct, threatValue
    local _, _, pct = UnitDetailedThreatSituation("player", unit)

    if pct == nil then
        f.threat:SetText("")   -- no threat on this mob
        return
    end

    -- Secret numbers can still be handed to SetFormattedText for display.
    -- pcall guards against the client refusing it.
    local ok = pcall(f.threat.SetFormattedText, f.threat, "%d%%", pct)
    if ok then
        f.threat:SetTextColor(GetThreatColor(pct))
    else
        f.threat:SetText("")
    end
end

local function UpdateUnit(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then
        ReleaseLabel(unit)
        return
    end

    if db.hostileOnly == 1 and SafeBool(UnitCanAttack("player", unit)) == false then
        ReleaseLabel(unit)
        return
    end

    local targetUnit = unit .. "target"
    if not UnitExists(targetUnit) then
        ReleaseLabel(unit)
        return
    end

    local f = labels[unit]
    if not f then
        f = AcquireLabel()
        labels[unit] = f
    end

    f:ClearAllPoints()
    f:SetPoint("TOP", plate, "BOTTOM", db.offsetX, db.offsetY)

    if SafeBool(UnitIsUnit(targetUnit, "player")) then
        f.target:SetText(db.prefix .. "YOU")
        f.target:SetTextColor(1, 0.2, 0.2)
    else
        f.target:SetFormattedText("%s%s", db.prefix, UnitName(targetUnit) or "")
        f.target:SetTextColor(GetTargetColor(targetUnit))
    end

    UpdateThreat(f, unit)
    f:Show()
end

local function UpdateAll()
    for unit in pairs(labels) do UpdateUnit(unit) end
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
driver:RegisterEvent("UNIT_TARGET")
driver:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
driver:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")

driver:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        NameplateTargetDB = NameplateTargetDB or {}
        for k, v in pairs(defaults) do
            if NameplateTargetDB[k] == nil then NameplateTargetDB[k] = v end
        end
        db = NameplateTargetDB
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        UpdateUnit(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        ReleaseLabel(arg1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        for unit in pairs(labels) do ReleaseLabel(unit) end
    else
        if arg1 and arg1:find("^nameplate") then UpdateUnit(arg1) end
    end
end)

-- Backup polling; the threat events don't always fire per nameplate
C_Timer.NewTicker(0.3, UpdateAll)

SLASH_NAMEPLATETARGET1 = "/npt"
SlashCmdList.NAMEPLATETARGET = function(msg)
    local key, val = msg:match("^(%S+)%s+(%S+)$")
    val = tonumber(val)
    if key and val and type(defaults[key]) == "number" then
        db[key] = val
        for _, f in pairs(labels) do ApplyFont(f) end
        UpdateAll()
        print("NameplateTarget:", key, "=", val)
    else
        print("NameplateTarget: /npt offsetX|offsetY|fontSize|hostileOnly|showThreat <number>")
    end
end