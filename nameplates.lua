local ADDON_NAME = ...

local defaults = {
    offsetX = 0,
    offsetY = -2,
    fontSize = 12,
    prefix = "→ ",
    hostileOnly = 1,   -- 1 = only show on attackable units, 0 = all
}
local db = defaults

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

-- Safely get a non-secret boolean, or nil if unknown
local function SafeBool(v)
    if isSecret(v) then return nil end
    return v and true or false
end

local labels = {}   -- [unitToken] = label frame
local pool = {}

local function AcquireLabel()
    local f = table.remove(pool)
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetSize(1, 1)
        f:SetFrameStrata("MEDIUM")
        f.text = f:CreateFontString(nil, "OVERLAY")
        f.text:SetPoint("TOP", f, "TOP", 0, 0)
        f.text:SetJustifyH("CENTER")
    end
    f.text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
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

local function GetColor(targetUnit)
    if UnitIsPlayer(targetUnit) then
        local _, classToken = UnitClass(targetUnit)
        if classToken and not isSecret(classToken) then
            local c = RAID_CLASS_COLORS[classToken]
            if c then return c.r, c.g, c.b end
        end
    else
        local reaction = UnitReaction(targetUnit, "player")
        if reaction and not isSecret(reaction) then
            local c = FACTION_BAR_COLORS[reaction]
            if c then return c.r, c.g, c.b end
        end
    end
    return 1, 1, 1
end

local function UpdateUnit(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then
        ReleaseLabel(unit)
        return
    end

    -- Optionally skip friendly units
    if db.hostileOnly == 1 then
        local canAttack = SafeBool(UnitCanAttack("player", unit))
        if canAttack == false then
            ReleaseLabel(unit)
            return
        end
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

    local name = UnitName(targetUnit)
    local isMe = SafeBool(UnitIsUnit(targetUnit, "player"))

    if isMe then
        f.text:SetText(db.prefix .. "YOU")
        f.text:SetTextColor(1, 0.2, 0.2)
    else
        -- SetFormattedText accepts secret strings without inspecting them
        f.text:SetFormattedText("%s%s", db.prefix, name or "")
        f.text:SetTextColor(GetColor(targetUnit))
    end
    f:Show()
end

local function UpdateAll()
    for unit in pairs(labels) do
        UpdateUnit(unit)
    end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
driver:RegisterEvent("UNIT_TARGET")
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
    elseif event == "UNIT_TARGET" then
        if arg1 and arg1:find("^nameplate") then
            UpdateUnit(arg1)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        for unit in pairs(labels) do ReleaseLabel(unit) end
    end
end)

-- UNIT_TARGET can be unreliable for nameplates, so poll as a backup
C_Timer.NewTicker(0.2, UpdateAll)

SLASH_NAMEPLATETARGET1 = "/npt"
SlashCmdList.NAMEPLATETARGET = function(msg)
    local key, val = msg:match("^(%S+)%s+(%S+)$")
    val = tonumber(val)
    if key and val and type(defaults[key]) == "number" then
        db[key] = val
        UpdateAll()
        print("NameplateTarget:", key, "=", val)
    else
        print("NameplateTarget: /npt offsetX|offsetY|fontSize|hostileOnly <number>")
    end
end