local addonName, ns = ...

local Rules = ns.FilterRules
local Filter = ns.ApplicantFilter

local WIDTH = 214
local PAD = 10
local ICON, ICON_STEP, PER_ROW = 22, 39, 5
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local ROLE_ATLAS = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}
local BORDER = {
    [Rules.NEED] = { 0.2, 0.9, 0.2 },
    [Rules.EXCLUDE] = { 0.95, 0.15, 0.15 },
}

local panel
local classButtons, roleButtons, boxes, checks = {}, {}, {}, {}

local function S()
    return Filter.Settings()
end

local function Heading(text, y)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", PAD, y)
    fs:SetText(text)
    return y - 18
end

local function PaintClass(button)
    local state = S().classes[button.class]
    local color = BORDER[state]
    button.border:SetShown(color ~= nil)
    if color then button.border:SetColorTexture(color[1], color[2], color[3]) end
    button.icon:SetDesaturated(state == Rules.EXCLUDE)
    button.icon:SetAlpha(state and 1 or 0.55)
end

local function ClassTooltip(button)
    local state = S().classes[button.class]
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.name, button.color.r, button.color.g, button.color.b)
    if state == Rules.NEED then
        GameTooltip:AddLine("Needed: applicants without any needed class fail.", 0.2, 0.9, 0.2, true)
    elseif state == Rules.EXCLUDE then
        GameTooltip:AddLine("Excluded: applicants of this class fail.", 0.95, 0.3, 0.3, true)
    end
    GameTooltip:AddLine("Left-click: neutral, needed, excluded. Right-click: neutral.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

local function ClassClick(button, mouseButton)
    local classes = S().classes
    classes[button.class] = mouseButton ~= "RightButton" and Rules.Next(classes[button.class]) or nil
    PaintClass(button)
    ClassTooltip(button)
    Filter.Changed()
end

local function BuildClasses(y)
    y = Heading("Classes", y)
    local index = 0
    for i = 1, GetNumClasses() do
        local info = C_CreatureInfo.GetClassInfo(i)
        if info and CLASS_ICON_TCOORDS[info.classFile] then
            local column, row = index % PER_ROW, math.floor(index / PER_ROW)
            local button = CreateFrame("Button", nil, panel)
            button:SetSize(ICON, ICON)
            button:SetPoint("TOPLEFT", PAD + 6 + column * ICON_STEP, y - row * 36)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button.border = button:CreateTexture(nil, "BACKGROUND")
            button.border:SetPoint("TOPLEFT", -2, 2)
            button.border:SetPoint("BOTTOMRIGHT", 2, -2)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetAllPoints()
            button.icon:SetTexture(CLASS_CIRCLES)
            button.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[info.classFile]))
            button.count = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.count:SetPoint("TOP", button, "BOTTOM", 0, -1)
            button.class, button.name = info.classFile, info.className
            button.color = RAID_CLASS_COLORS[info.classFile] or NORMAL_FONT_COLOR
            button:SetScript("OnClick", ClassClick)
            button:SetScript("OnEnter", ClassTooltip)
            button:SetScript("OnLeave", GameTooltip_Hide)
            classButtons[#classButtons + 1] = button
            index = index + 1
        end
    end
    return y - math.ceil(index / PER_ROW) * 36 - 4
end

local function Check(key, label, x, y)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", x, y)
    check.text:SetText(label)
    check.text:SetFontObject("GameFontHighlightSmall")
    check:SetScript("OnClick", function(self)
        S()[key] = self:GetChecked() and true or false
        Filter.Changed()
    end)
    checks[key] = check
    return check
end

local function Box(key, label, y)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", PAD, y - 4)
    fs:SetText(label)
    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(54, 18)
    box:SetPoint("TOPRIGHT", -PAD - 4, y)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)
    box:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        S()[key] = Rules.ParseNumber(self:GetText())
        Filter.Changed()
    end)
    box:SetScript("OnEnterPressed", EditBox_ClearFocus)
    box.label = fs
    boxes[key] = box
    return y - 24
end

local function RoleClick(button)
    S().roles[button.role] = not S().roles[button.role]
    button:SetAlpha(S().roles[button.role] and 1 or 0.3)
    Filter.Changed()
end

local function BuildRoles(y)
    y = Heading("Roles", y)
    for index, role in ipairs(Rules.ROLES) do
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(22, 22)
        button:SetPoint("TOPLEFT", PAD + 6 + (index - 1) * 30, y)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetAtlas(ROLE_ATLAS[role])
        button.role = role
        button:SetScript("OnClick", RoleClick)
        roleButtons[role] = button
    end
    Check("hideFilledRoles", "Hide roles already filled", PAD, y - 26)
    return y - 54
end

local function BuildMode(y)
    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", PAD, y)
    dropdown:SetWidth(WIDTH - 2 * PAD)
    dropdown:SetupMenu(function(_, root)
        local function IsSelected(mode) return S().mode == mode end
        local function Select(mode)
            S().mode = mode
            Filter.Changed()
        end
        root:CreateRadio("Failing applicants move down", IsSelected, Select, "down")
        root:CreateRadio("Failing applicants are hidden", IsSelected, Select, "hide")
    end)
    return y - 30
end

local function ResetAll()
    local mode = S().mode
    local fresh = Rules.Defaults()
    for key in pairs(S()) do S()[key] = nil end
    for key, value in pairs(fresh) do S()[key] = value end
    S().mode = mode
    panel:Sync()
    Filter.Changed()
end

local function Sync()
    local s, state = S(), Filter.state
    for _, button in ipairs(classButtons) do
        PaintClass(button)
        local count = state.counts and state.counts[button.class]
        button.count:SetText(count and tostring(count) or "")
    end
    for role, button in pairs(roleButtons) do
        button:SetAlpha(s.roles[role] and 1 or 0.3)
    end
    for key, box in pairs(boxes) do
        if not box:HasFocus() then box:SetText(s[key] and tostring(s[key]) or "") end
    end
    for key, check in pairs(checks) do
        check:SetChecked(s[key] == true)
    end

    local mythicPlus = state.listing ~= nil and state.listing.isMythicPlus
    local dungeonBox = boxes.minDungeonLevel
    dungeonBox:SetEnabled(mythicPlus)
    dungeonBox:SetAlpha(mythicPlus and 1 or 0.4)
    dungeonBox.label:SetAlpha(mythicPlus and 1 or 0.4)
    checks.timedOnly:SetEnabled(mythicPlus)
    checks.timedOnly:SetAlpha(mythicPlus and 1 or 0.4)

    panel.reset:SetEnabled(Rules.IsActive(s))
    if state.paused then
        panel.status:SetText("Filter paused")
    elseif state.count > 0 then
        panel.status:SetText((s.mode == "hide" and "Hidden: " or "Moved down: ") .. state.count)
    else
        panel.status:SetText("")
    end
end

local function Build()
    local viewer = LFGListFrame.ApplicationViewer
    panel = CreateFrame("Frame", nil, viewer, "TooltipBackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetPoint("TOPRIGHT", PVEFrame, "TOPLEFT", -2, 0)
    panel.Sync = Sync

    local y = -PAD
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, y)
    title:SetText("Applicant filter")
    y = y - 26

    y = BuildClasses(y)
    y = BuildRoles(y)
    y = Heading("Minimums", y)
    y = Box("minRating", "Mythic+ rating", y)
    y = Box("minItemLevel", "Item level", y)
    y = Heading("This dungeon", y)
    y = Box("minDungeonLevel", "Best key at least", y)
    Check("timedOnly", "Timed only", PAD, y)
    y = y - 28
    y = Heading("Group utility", y)
    Check("bloodlustFit", "Bloodlust fit", PAD, y)
    Check("battleResFit", "Battle res fit", PAD + 96, y)
    y = y - 30
    y = BuildMode(y)

    panel.reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.reset:SetSize(70, 22)
    panel.reset:SetPoint("TOPLEFT", PAD, y)
    panel.reset:SetText(RESET)
    panel.reset:SetScript("OnClick", ResetAll)

    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.status:SetPoint("LEFT", panel.reset, "RIGHT", 8, 0)
    y = y - 22 - PAD

    panel:SetHeight(-y)
    Filter.panel = panel
    Filter.OnChange(Sync)
    panel:SetScript("OnShow", Sync)
    panel:SetShown(ns.db.classFilter == true)
    Sync()
end

Filter.BuildPanel = function()
    if not panel and LFGListFrame then Build() end
end
