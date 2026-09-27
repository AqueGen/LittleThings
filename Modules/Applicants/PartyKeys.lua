local addonName, ns = ...

local Keys = ns.KeystoneRules

local PartyKeys = {}

local WIDTH = 214
local PAD = 10
local ROW_HEIGHT = 20
local MAX_ROWS = 5

local keys = {}
local panel
local buttons = {}
local enabled = false

local function Library()
    return LibStub and LibStub("LibKeystone", true)
end

local function Creation()
    return LFGListFrame and LFGListFrame.EntryCreation
end

local function On()
    return ns.db.defaultPlaystyle and ns.DefaultPlaystyle.Options().partyKeys
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

local function DungeonActivities()
    local infos = {}
    for _, id in ipairs(C_LFGList.GetAvailableActivities(GROUP_FINDER_CATEGORY_ID_DUNGEONS) or {}) do
        local info = C_LFGList.GetActivityInfoTable(id)
        if info then
            info.id = id
            infos[#infos + 1] = info
        end
    end
    return infos
end

local function ChooseKey(button)
    local creation = Creation()
    local _, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(button.challengeMapID)
    local activityID, groupID = Keys.MythicPlusActivity(DungeonActivities(), mapID)
    if not activityID then
        ns.Print("no Mythic+ listing found for that keystone's dungeon.")
        return
    end
    LFGListEntryCreation_Select(creation, creation.selectedFilters, GROUP_FINDER_CATEGORY_ID_DUNGEONS, groupID, activityID)
    if creation.Name then pcall(creation.Name.SetFocus, creation.Name) end
end

local function Row(index)
    local button = buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, panel)
    button:SetSize(WIDTH - 2 * PAD, ROW_HEIGHT)
    button:SetPoint("TOPLEFT", PAD, -PAD - 22 - (index - 1) * ROW_HEIGHT)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.text:SetPoint("LEFT", 2, 0)
    button.text:SetPoint("RIGHT", -2, 0)
    button.text:SetJustifyH("LEFT")
    button:SetScript("OnClick", ChooseKey)
    buttons[index] = button
    return button
end

local function Refresh()
    if not panel then return end
    local creation = Creation()
    local rows = On() and creation:IsVisible() and creation.selectedCategory == GROUP_FINDER_CATEGORY_ID_DUNGEONS
        and Keys.Rows(keys, UnitFullName("player"), Members()) or {}
    local shown = math.min(#rows, MAX_ROWS)
    for index = 1, shown do
        local row = rows[index]
        local button = Row(index)
        local dungeon = C_ChallengeMode.GetMapUIInfo(row.challengeMapID) or "?"
        button.challengeMapID = row.challengeMapID
        button.text:SetText(("|cffffd100+%d|r %s  |cff999999%s|r"):format(row.level, dungeon, Ambiguate(row.name, "short")))
        button:Show()
    end
    for index = shown + 1, #buttons do
        buttons[index]:Hide()
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

function PartyKeys.Pages(page)
    local options = ns.DefaultPlaystyle.Options()
    local setting = Settings.RegisterProxySetting(page.category, "LT_defaultPlaystyle_partyKeys", Settings.VarType.Boolean,
        "Show the group's keystones", true,
        function() return options.partyKeys end,
        function(value)
            options.partyKeys = value
            Request()
            Refresh()
        end)
    ns.AddToPage(page, Settings.CreateCheckbox(page.category, setting,
        "A list beside the group creation screen with the keystones your group shares (yours first), for players running DBM, BigWigs or another addon with LibKeystone. Click one to pick its dungeon at Mythic+ and put the cursor in the title, ready for you to type the level: the game does not let addons write the title."))
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
        Request()
        Refresh()
    end)
end

function PartyKeys.OnSwitch(on)
    if on then PartyKeys.Enable() end
    Refresh()
end

PartyKeys.key = "defaultPlaystyle"
ns.RegisterModule("PartyKeys", PartyKeys)
