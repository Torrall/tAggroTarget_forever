local ADDON_NAME = ...

local defaults = {
    offsetX = 0,
    offsetY = -2,
    fontSize = 12,
    prefix = "",
    hostileOnly = 1,        -- 1 = only attackable units
    fallbackToTarget = 0,   -- 1 = show the mob's target when no threat holder is found
}
local db = defaults

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

-- Returns true/false, or nil if the value is secret
local function SafeBool(v)
    if isSecret(v) then return nil end
    return v and true or false
end

---------------------------------------------------------------------
-- Roster of units that can hold threat (player, pet, party/raid + pets)
---------------------------------------------------------------------
local roster = {}

local function BuildRoster()
    wipe(roster)
    roster[#roster + 1] = "player"
    roster[#roster + 1] = "pet"
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            roster[#roster + 1] = "raid" .. i
            roster[#roster + 1] = "raidpet" .. i
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            roster[#roster + 1] = "party" .. i
            roster[#roster + 1] = "partypet" .. i
        end
    end
end

-- Returns holderUnit (or nil), sawSecret (true if any check was unreadable)
local function FindThreatHolder(mob)
    print("checking threat for ", mob)
    local sawSecret = false
    for i = 1, #roster do
        local u = roster[i]
        if UnitExists(u) then
            local isTanking = UnitDetailedThreatSituation(u, mob)
            local tanking = SafeBool(isTanking)
            if tanking then
                print(u,"istanking",sawSecret)
                return u, sawSecret
            elseif tanking == nil then
                sawSecret = true
            end
        end
    end
    return nil, sawSecret
end

---------------------------------------------------------------------
-- Label pool
---------------------------------------------------------------------
local labels, pool = {}, {}

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

local function GetColor(unit)
    if UnitIsPlayer(unit) then
        local _, classToken = UnitClass(unit)
        if classToken and not isSecret(classToken) then
            local c = RAID_CLASS_COLORS[classToken]
            if c then return c.r, c.g, c.b end
        end
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
local function UpdateUnit(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then
        ReleaseLabel(unit)
        return
    end

    if db.hostileOnly == 1 then
        if SafeBool(UnitCanAttack("player", unit)) == false then
            ReleaseLabel(unit)
            return
        end
    end

    local holder, sawSecret = FindThreatHolder(unit)

    -- Fallback: the mob's current target is usually the threat holder anyway
    if not holder and (sawSecret or db.fallbackToTarget == 1) then
        local t = unit .. "target"
        if UnitExists(t) then holder = t end
    end

    if not holder then
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

    local isMe = SafeBool(UnitIsUnit(holder, "player"))
    if isMe then
        f.text:SetText(db.prefix .. "YOU")
        f.text:SetTextColor(1, 0.2, 0.2)
    else
        f.text:SetFormattedText("%s%s", db.prefix, UnitName(holder) or "")
        f.text:SetTextColor(GetColor(holder))
    end
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
driver:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
driver:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
driver:RegisterEvent("UNIT_TARGET")
driver:RegisterEvent("GROUP_ROSTER_UPDATE")
driver:RegisterEvent("UNIT_PET")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")

driver:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        NameplateTargetDB = NameplateTargetDB or {}
        for k, v in pairs(defaults) do
            if NameplateTargetDB[k] == nil then NameplateTargetDB[k] = v end
        end
        db = NameplateTargetDB
        BuildRoster()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        UpdateUnit(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        ReleaseLabel(arg1)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
        BuildRoster()
    elseif event == "PLAYER_ENTERING_WORLD" then
        BuildRoster()
        for unit in pairs(labels) do ReleaseLabel(unit) end
    else
        -- threat / target events: arg1 is the mob unit
        if arg1 and arg1:find("^nameplate") then UpdateUnit(arg1) end
    end
end)

-- Backup polling in case events don't fire reliably for nameplate units
C_Timer.NewTicker(0.3, UpdateAll)

SLASH_tAGGROTARGET1 = "/agt"
SlashCmdList.tAGGROTARGET = function(msg)
    local key, val = msg:match("^(%S+)%s+(%S+)$")
    val = tonumber(val)
    if key and val and type(defaults[key]) == "number" then
        db[key] = val
        UpdateAll()
        print("tAggroTarget:", key, "=", val)
    else
        print("tAggroTarget: /npt offsetX|offsetY|fontSize|hostileOnly|fallbackToTarget <number>")
    end
end