local addonName, ns = ...

local Keys = ns.KeystoneRules

local PartyKeys = {}

local WIDTH = 214
local PAD = 10
local ROW_HEIGHT = 20
local MAX_ROWS = 5

local keys = {}
local panel
local rows = {}
local enabled = false

local function Library()
    return LibStub and LibStub("LibKeystone", true)
end

local function Creation()
    return LFGListFrame and LFGListFrame.EntryCreation
end

local function On()
    return ns.IsOn("partyKeys")
end

local function UnitFullName(unit)
    local name, realm = UnitNameUnmodified(unit)
    if not name or issecretvalue(name) then return nil end
    if realm and realm ~= "" and not issecretvalue(realm) then return name .. "-" .. realm end
    return name
end

local function Members()
    local members = { UnitFullName("player") }
    for i = 1, 4 do
        local name = UnitExists("party" .. i) and UnitFullName("party" .. i)
        if name then members[#members + 1] = name end
    end
    return members
end

local function Row(index)
    local text = rows[index]
    if text then return text end
    text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", PAD + 2, -PAD - 22 - (index - 1) * ROW_HEIGHT)
    text:SetPoint("RIGHT", -PAD - 2, 0)
    text:SetHeight(ROW_HEIGHT)
    text:SetJustifyH("LEFT")
    rows[index] = text
    return text
end

local function Refresh()
    if not panel then return end
    local creation = Creation()
    local list = On() and creation:IsVisible() and creation.selectedCategory == GROUP_FINDER_CATEGORY_ID_DUNGEONS
        and Keys.Rows(keys, UnitFullName("player"), Members()) or {}
    local shown = math.min(#list, MAX_ROWS)
    for index = 1, shown do
        local row = list[index]
        local dungeon = C_ChallengeMode.GetMapUIInfo(row.challengeMapID) or "?"
        local text = Row(index)
        text:SetText(("|cffffd100+%d|r %s  |cff999999%s|r"):format(row.level, dungeon, Ambiguate(row.name, "short")))
        text:Show()
    end
    for index = shown + 1, #rows do
        rows[index]:Hide()
    end
    panel:SetHeight(PAD * 2 + 22 + shown * ROW_HEIGHT)
    if ns.ApplicantFilter and ns.ApplicantFilter.PlaceBeside then ns.ApplicantFilter.PlaceBeside(panel) end
    panel:SetShown(shown > 0)
end

local function OnKey(level, challengeMapID, _, name)
    keys[name] = { level = level, challengeMapID = challengeMapID }
    Refresh()
end

local function Request()
    local lib = Library()
    if lib and On() then lib.Request("PARTY") end
end

local function Build()
    local creation = Creation()
    panel = CreateFrame("Frame", nil, creation, "TooltipBackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    local background = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetPoint("TOPLEFT", 3, -3)
    background:SetPoint("BOTTOMRIGHT", -3, 3)
    background:SetColorTexture(0.04, 0.04, 0.06, 0.96)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Group keystones")
    panel:Hide()

    creation:HookScript("OnShow", function()
        Request()
        Refresh()
    end)
    creation:HookScript("OnHide", Refresh)
    hooksecurefunc("LFGListEntryCreation_Select", Refresh)
end

function PartyKeys.Enable()
    if enabled or not Creation() then return end
    local lib = Library()
    if not lib then return end
    enabled = true
    lib.Register(PartyKeys, OnKey)
    Build()

    local events = CreateFrame("Frame")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:SetScript("OnEvent", function()
        if Creation():IsVisible() then Request() end
        Refresh()
    end)
end

function PartyKeys.OnSwitch(on)
    if on then
        PartyKeys.Enable()
        Request()
    end
    Refresh()
end

PartyKeys.key = "partyKeys"
ns.RegisterModule("PartyKeys", PartyKeys)
