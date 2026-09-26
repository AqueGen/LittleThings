local addonName, ns = ...

local Rules = ns.ClassFilterRules

local ClassFilter = {}

local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local SIZE, STEP = 20, 23
local TEXT_WIDTH = 64
local COUNT_HEIGHT = 12
local BELOW_TABS = -34
local BORDER = {
    [Rules.NEED] = { 0.2, 0.9, 0.2 },
    [Rules.EXCLUDE] = { 0.95, 0.15, 0.15 },
}

local bar
local buttons = {}
local hooked = false
local hidden = 0
local counts

local function States()
    return ns.charDb.classFilter
end

local function Viewer()
    return LFGListFrame.ApplicationViewer
end

local function ApplicantClasses(applicantID)
    if issecretvalue(applicantID) then return nil end
    local info = C_LFGList.GetApplicantInfo(applicantID)
    if not info or issecretvalue(info.numMembers) then return nil end
    local classes = {}
    for i = 1, info.numMembers or 0 do
        local _, class = C_LFGList.GetApplicantMemberInfo(applicantID, i)
        if issecretvalue(class) then return nil end
        if class then table.insert(classes, class) end
    end
    return classes
end

local function CountClasses(applicants)
    local result = {}
    for _, applicantID in ipairs(applicants) do
        local classes = ApplicantClasses(applicantID)
        if classes == nil then return nil end
        for _, class in ipairs(classes) do
            result[class] = (result[class] or 0) + 1
        end
    end
    return result
end

local function UpdateText()
    if not bar then return end
    bar.hiddenText:SetText(hidden > 0 and ("Hidden: " .. hidden) or "")
    bar.reset:SetEnabled(Rules.IsActive(States()))
    for _, button in ipairs(buttons) do
        local count = counts and counts[button.class]
        button.count:SetText(count and tostring(count) or "")
    end
end

local function FilterApplicants(applicants)
    if not ns.db.classFilter or type(applicants) ~= "table" then return end
    local before = #applicants
    hidden = 0
    counts = CountClasses(applicants)
    if Rules.IsActive(States()) and Rules.Filter(applicants, ApplicantClasses, States()) then
        hidden = before - #applicants
    end
    UpdateText()
end

local function RefreshList()
    if Viewer():IsVisible() then
        LFGListApplicationViewer_UpdateResultList(Viewer())
        LFGListApplicationViewer_UpdateResults(Viewer())
    else
        hidden = 0
        UpdateText()
    end
end

local function Paint(button)
    local state = States()[button.class]
    local color = BORDER[state]
    button.border:SetShown(color ~= nil)
    if color then button.border:SetColorTexture(color[1], color[2], color[3]) end
    button.icon:SetDesaturated(state == Rules.EXCLUDE)
    button.icon:SetAlpha(state and 1 or 0.55)
end

local function ResetAll()
    wipe(States())
    for _, button in ipairs(buttons) do
        Paint(button)
    end
    RefreshList()
end

local function ShowTooltip(button)
    local state = States()[button.class]
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.name, button.color.r, button.color.g, button.color.b)
    if state == Rules.NEED then
        GameTooltip:AddLine("Needed: applicants without any needed class are hidden.", 0.2, 0.9, 0.2, true)
    elseif state == Rules.EXCLUDE then
        GameTooltip:AddLine("Excluded: applicants of this class are hidden.", 0.95, 0.3, 0.3, true)
    end
    GameTooltip:AddLine("Left-click: neutral, needed, excluded. Right-click: neutral.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function OnClick(button, mouseButton)
    local states = States()
    if mouseButton == "RightButton" then
        states[button.class] = nil
    else
        states[button.class] = Rules.Next(states[button.class])
    end
    Paint(button)
    ShowTooltip(button)
    RefreshList()
end

local function CreateButton(parent, classInfo, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SIZE, SIZE)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", TEXT_WIDTH + (index - 1) * STEP, -4)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetPoint("TOPLEFT", -2, 2)
    button.border:SetPoint("BOTTOMRIGHT", 2, -2)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexture(CLASS_CIRCLES)
    button.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classInfo.classFile]))

    button.count = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.count:SetPoint("TOP", button, "BOTTOM", 0, -1)

    button.class = classInfo.classFile
    button.name = classInfo.className
    button.color = RAID_CLASS_COLORS[classInfo.classFile] or NORMAL_FONT_COLOR

    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    Paint(button)
    table.insert(buttons, button)
end

local function BuildBar()
    local classes = {}
    for i = 1, GetNumClasses() do
        local info = C_CreatureInfo.GetClassInfo(i)
        if info and CLASS_ICON_TCOORDS[info.classFile] then table.insert(classes, info) end
    end

    bar = CreateFrame("Frame", nil, Viewer())
    bar:SetSize(TEXT_WIDTH + #classes * STEP + 2, SIZE + 8 + COUNT_HEIGHT)
    bar:SetPoint("TOPRIGHT", PVEFrame, "BOTTOMRIGHT", 0, BELOW_TABS)

    local background = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.65)

    bar.reset = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    bar.reset:SetSize(TEXT_WIDTH - 10, 18)
    bar.reset:SetPoint("TOPLEFT", bar, "TOPLEFT", 5, -4)
    bar.reset:SetText(RESET)
    bar.reset:SetScript("OnClick", ResetAll)

    bar.hiddenText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.hiddenText:SetPoint("TOP", bar.reset, "BOTTOM", 0, -2)

    for index, info in ipairs(classes) do
        CreateButton(bar, info, index)
    end
    UpdateText()
end

function ClassFilter.Enable()
    if not LFGListFrame then return end
    if not bar then BuildBar() end
    bar:Show()
    if not hooked then
        hooked = true
        hooksecurefunc("LFGListUtil_SortApplicants", FilterApplicants)
    end
end

function ClassFilter.OnSwitch(enabled)
    if enabled then
        ClassFilter.Enable()
    elseif bar then
        bar:Hide()
    end
    if LFGListFrame then RefreshList() end
end

ClassFilter.key = "classFilter"
ns.RegisterModule("ClassFilter", ClassFilter)
