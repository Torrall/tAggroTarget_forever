local ADDON_NAME = ...

local defaults = {
    offsetX = 20,        -- pixels right of cursor
    offsetY = -20,       -- pixels below cursor
    fontSize = 14,
    prefix = "",
}

-- Midnight: secret values can be shown but not compared or used in math.
local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local frame = CreateFrame("Frame", "AggroTargetFrame", UIParent)
frame:SetSize(1, 1)
frame:SetFrameStrata("TOOLTIP")
frame:Hide()

local text = frame:CreateFontString(nil, "OVERLAY")
text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
text:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
text:SetJustifyH("LEFT")

local db = defaults
local unitToken = "mouseovertarget"

-- Pick a text color for the unit's target. Falls back to white if
-- anything is secret or missing.
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

local function UpdateText()
    if not UnitExists("mouseover") or not UnitExists(unitToken) then
        frame:Hide()
        return
    end

    local name = UnitName(unitToken)
    local isMe = UnitIsUnit(unitToken, "player")

    -- UnitIsUnit may return a secret boolean in some situations.
    if not isSecret(isMe) and isMe then
        name = "YOU"
    end

    -- SetText accepts secret strings, so we can display without inspecting.
    text:SetFormattedText("%s%s", db.prefix, name or "")
    text:SetTextColor(GetColor(unitToken))
    frame:Show()
end

local elapsed = 0
frame:SetScript("OnUpdate", function(self, dt)
    -- Follow the cursor every frame
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            x / scale + db.offsetX, y / scale + db.offsetY)

    -- Refresh the text a few times per second
    elapsed = elapsed + dt
    if elapsed >= 0.05 then
        elapsed = 0
        UpdateText()
    end
end)

-- The OnUpdate only runs while the frame is shown, so use a separate
-- driver to detect when a mouseover starts.
local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
driver:RegisterEvent("UNIT_TARGET")

driver:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        AggroTargetDB = AggroTargetDB or {}
        for k, v in pairs(defaults) do
            if AggroTargetDB[k] == nil then AggroTargetDB[k] = v end
        end
        db = AggroTargetDB
        text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    else
        UpdateText()
    end
end)

-- Hide as soon as the mouse leaves the unit
GameTooltip:HookScript("OnTooltipCleared", function()
    if not UnitExists("mouseover") then frame:Hide() end
end)

SLASH_tAGGROTARGET2 = "/agt"
SlashCmdList.tAGGROTARGET = function(msg)
    local key, val = msg:match("^(%S+)%s+(%S+)$")
    val = tonumber(val)
    if key and val and defaults[key] ~= nil and type(defaults[key]) == "number" then
        db[key] = val
        if key == "fontSize" then
            text:SetFont(STANDARD_TEXT_FONT, val, "OUTLINE")
        end
        print("tAggroTarget:", key, "=", val)
    else
        print("tAggroTarget: /agt offsetX|offsetY|fontSize <number>")
    end
end