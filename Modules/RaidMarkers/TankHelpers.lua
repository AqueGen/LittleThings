local addonName, ns = ...

local Rules = ns.MarkerRules
local Shared = ns.RaidMarkerPanel

local PARTY = { "player", "party1", "party2", "party3", "party4" }
local MANA = { 0, 0.44, 0.87 }
local RED = Shared.RED

local manaCurve

local function HealerName(unit)
    local name = UnitName(unit)
    if name == nil or issecretvalue(name) then
        return nil
    end
    local _, classFile = UnitClass(unit)
    if classFile == nil or issecretvalue(classFile) then
        return name
    end
    local color = C_ClassColor.GetClassColor(classFile)
    return color and color:WrapTextInColorCode(name) or name
end

function Shared.RefreshHelpers()
    local manaBar, manaText, downText = Shared.manaBar, Shared.manaText, Shared.downText
    local db = ns.db.raidMarkerPanel
    local party = IsInGroup() and not IsInRaid()
    local healer
    if db.healerMana and party then
        local roles = {}
        for _, unit in ipairs(PARTY) do
            local role = UnitGroupRolesAssigned(unit)
            roles[#roles + 1] = { unit = unit, role = issecretvalue(role) and "secret" or role }
        end
        healer = Rules.HealerUnit(roles)
    end
    manaBar.unit = healer
    if healer then
        local power = UnitPower(healer, Enum.PowerType.Mana)
        manaBar:SetMinMaxValues(0, UnitPowerMax(healer, Enum.PowerType.Mana))
        manaBar:SetValue(power)
        local mode = db.manaText
        local name = mode ~= "none" and HealerName(healer)
        if mode == "value" then
            if name then
                manaText:SetFormattedText("%s %s", name, AbbreviateNumbers(power))
            else
                manaText:SetText(AbbreviateNumbers(power))
            end
        elseif mode == "percent" then
            local percent = UnitPowerPercent(healer, Enum.PowerType.Mana, false, manaCurve)
            if name then
                manaText:SetFormattedText("%s %d%%", name, percent)
            else
                manaText:SetFormattedText("%d%%", percent)
            end
        elseif mode == "both" then
            local percent = UnitPowerPercent(healer, Enum.PowerType.Mana, false, manaCurve)
            if name then
                manaText:SetFormattedText("%s %s  %d%%", name, AbbreviateNumbers(power), percent)
            else
                manaText:SetFormattedText("%s  %d%%", AbbreviateNumbers(power), percent)
            end
        else
            manaText:SetText("")
        end
    end
    manaBar:SetAlpha(healer and 1 or 0)
    local down = 0
    if db.groupDown and party then
        local states = {}
        for _, unit in ipairs(PARTY) do
            if UnitExists(unit) then
                local dead, connected = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
                states[#states + 1] = {
                    dead = issecretvalue(dead) and "secret" or dead,
                    connected = issecretvalue(connected) and "secret" or connected,
                }
            end
        end
        down = Rules.DownCount(states)
    end
    downText:SetText(Rules.DownLabel(down))
    downText:SetAlpha(down > 0 and 1 or 0)
end

function Shared.BuildHelpers()
    local panel = Shared.panel
    local manaBar = CreateFrame("StatusBar", nil, panel)
    Shared.manaBar = manaBar
    manaBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    manaBar:SetStatusBarColor(MANA[1], MANA[2], MANA[3])
    local manaBack = manaBar:CreateTexture(nil, "BACKGROUND")
    manaBack:SetAllPoints()
    manaBack:SetColorTexture(0, 0, 0, 0.6)
    manaBar:SetAlpha(0)
    local icon = manaBar:CreateTexture(nil, "OVERLAY")
    icon:SetAtlas(ns.IconButtons.ROLE_ATLAS.HEALER)
    icon:SetSize(Shared.ICON, Shared.ICON)
    icon:SetPoint("RIGHT", manaBar, "LEFT", -Shared.GAP, 0)
    Shared.manaText = manaBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Shared.manaText:SetPoint("CENTER")
    manaCurve = C_CurveUtil.CreateCurve()
    manaCurve:SetType(Enum.LuaCurveType.Linear)
    manaCurve:AddPoint(0, 0)
    manaCurve:AddPoint(1, 100)
    manaBar.title = "Healer mana"
    manaBar.lines = function()
        local name = manaBar.unit and UnitName(manaBar.unit)
        if issecretvalue(name) then
            return {}
        end
        return { name }
    end
    manaBar:EnableMouse(true)
    manaBar:SetMouseClickEnabled(false)
    manaBar:SetScript("OnEnter", function(self)
        if self.unit then
            Shared.ShowTip(self)
        end
    end)
    manaBar:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local downText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Shared.downText = downText
    downText:SetTextColor(RED[1], RED[2], RED[3])
    downText:SetText(Rules.DownLabel(5))
    downText.cell = math.ceil(downText:GetStringWidth())
    downText:SetText("")
    downText:SetAlpha(0)
end
