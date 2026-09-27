local addonName, ns = ...

local Rules = ns.FilterRules
local Data = ns.ApplicantData
local Filter = ns.ApplicantFilter

local WIDTH = 214
local PAD = 10
local TITLE_HEIGHT = 26
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

local SIDES = {
    right = { label = "Right of the group finder", point = "TOPLEFT", relativePoint = "TOPRIGHT", x = 2 },
    left = { label = "Left of the group finder", point = "TOPRIGHT", relativePoint = "TOPLEFT", x = -2 },
}
local SIDE_ORDER = { "right", "left" }
local POSITION_DEFAULTS = { side = "right", x = 0, y = 0 }

local panel
local rows = {}
local classButtons, roleButtons, boxes, checks = {}, {}, {}, {}

local function S()
    return Filter.Settings()
end

local function Row(height, when)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(WIDTH, height)
    row.when = when
    rows[#rows + 1] = row
    return row
end

local function Heading(row, text)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", PAD, 0)
    fs:SetText(text)
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

local function BuildClasses()
    local classes = {}
    for i = 1, GetNumClasses() do
        local info = C_CreatureInfo.GetClassInfo(i)
        if info and CLASS_ICON_TCOORDS[info.classFile] then classes[#classes + 1] = info end
    end

    local row = Row(18 + math.ceil(#classes / PER_ROW) * 36 + 4)
    Heading(row, "Classes")
    for index, info in ipairs(classes) do
        local column, line = (index - 1) % PER_ROW, math.floor((index - 1) / PER_ROW)
        local button = CreateFrame("Button", nil, row)
        button:SetSize(ICON, ICON)
        button:SetPoint("TOPLEFT", PAD + 6 + column * ICON_STEP, -18 - line * 36)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button.border = button:CreateTexture(nil, "BACKGROUND")
        button.border:SetPoint("TOPLEFT", -2, 2)
        button.border:SetPoint("BOTTOMRIGHT", 2, -2)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetTexture(CLASS_CIRCLES)
        button.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[info.classFile]))
        button.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.count:SetPoint("TOP", button, "BOTTOM", 0, -1)
        button.class, button.name = info.classFile, info.className
        button.color = RAID_CLASS_COLORS[info.classFile] or NORMAL_FONT_COLOR
        button:SetScript("OnClick", ClassClick)
        button:SetScript("OnEnter", ClassTooltip)
        button:SetScript("OnLeave", GameTooltip_Hide)
        classButtons[#classButtons + 1] = button
    end
end

local function Check(row, key, label, y)
    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", PAD, y)
    check.text:SetText(label)
    check.text:SetFontObject("GameFontHighlightSmall")
    check:SetScript("OnClick", function(self)
        S()[key] = self:GetChecked() and true or false
        Filter.Changed()
    end)
    checks[key] = check
end

local function Box(row, key, label)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", PAD, -4)
    fs:SetText(label)
    local box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    box:SetSize(54, 18)
    box:SetPoint("TOPRIGHT", -PAD - 4, 0)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(4)
    box:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        S()[key] = Rules.ParseNumber(self:GetText())
        Filter.Changed()
    end)
    box:SetScript("OnEnterPressed", EditBox_ClearFocus)
    boxes[key] = box
end

local function RoleClick(button)
    S().roles[button.role] = not S().roles[button.role]
    button:SetAlpha(S().roles[button.role] and 1 or 0.3)
    Filter.Changed()
end

local function BuildRoles()
    local row = Row(18 + 30)
    Heading(row, "Roles")
    for index, role in ipairs(Rules.ROLES) do
        local button = CreateFrame("Button", nil, row)
        button:SetSize(22, 22)
        button:SetPoint("TOPLEFT", PAD + 6 + (index - 1) * 30, -20)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetAtlas(ROLE_ATLAS[role])
        button.role = role
        button:SetScript("OnClick", RoleClick)
        roleButtons[role] = button
    end
end

local function BuildUtility()
    local row = Row(18 + 24 + 30, "fiveMan")
    Heading(row, "Group utility")
    Check(row, "needBloodlust", "Brings Bloodlust", -18)
    Check(row, "needBattleRes", "Brings battle res", -42)
end

local function BuildSort()
    local row = Row(18 + 30, "sort")
    Heading(row, "Sort")
    local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", PAD, -18)
    dropdown:SetWidth(WIDTH - 2 * PAD)
    dropdown:SetupMenu(function(_, root)
        local sort = ns.ApplicantSort
        local choices = sort.Choices(Data.Listing())
        if not choices then return end
        local function IsSelected(key) return sort.GetBy(choices) == key end
        local function Select(key)
            sort.SetBy(choices, key)
            Filter.Changed()
        end
        for _, key in ipairs(choices.order) do
            root:CreateRadio(choices.names[key], IsSelected, Select, key)
        end
    end)
    panel.sortDropdown = dropdown
end

local function BuildMode()
    local row = Row(30)
    local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", PAD, 0)
    dropdown:SetWidth(WIDTH - 2 * PAD)
    dropdown:SetupMenu(function(_, root)
        local function IsSelected(mode) return S().mode == mode end
        local function Select(mode)
            S().mode = mode
            Filter.Changed()
        end
        root:CreateRadio("Move down", IsSelected, Select, "down")
        root:CreateRadio("Hide", IsSelected, Select, "hide")
    end)
end

local function Visible(row, listing)
    if row.when == "fiveMan" then return listing == nil or listing.fiveMan end
    if row.when == "sort" then
        return ns.db.applicantSort == true and ns.ApplicantSort ~= nil and ns.ApplicantSort.Choices(listing) ~= nil
    end
    return true
end

local function Layout()
    local listing = Data.Listing()
    local y = -PAD - TITLE_HEIGHT
    for _, row in ipairs(rows) do
        local shown = Visible(row, listing)
        row:SetShown(shown)
        if shown then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
            y = y - row:GetHeight()
        end
    end
    panel:SetHeight(-y + PAD)
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
    if panel.sortDropdown:IsVisible() then panel.sortDropdown:GenerateMenu() end
    Layout()

    panel.reset:SetEnabled(Rules.IsActive(s))
    if state.paused then
        panel.status:SetText("Filter paused")
    elseif state.count > 0 then
        panel.status:SetText((s.mode == "hide" and "Hidden: " or "Moved down: ") .. state.count)
    else
        panel.status:SetText("")
    end
end

local function Position()
    return ns.db.applicantPanel
end

function Filter.PlaceBeside(frame)
    local position = Position()
    local side = SIDES[position.side] or SIDES.right
    frame:ClearAllPoints()
    frame:SetPoint(side.point, PVEFrame, side.relativePoint, side.x + position.x, position.y)
end

local function Place()
    if panel then Filter.PlaceBeside(panel) end
end

local OFFSET_LIMIT = 800

local function Clamp(value)
    return math.max(-OFFSET_LIMIT, math.min(OFFSET_LIMIT, Round(value)))
end

local function KeepDraggedPosition(self)
    self:StopMovingOrSizing()
    local position = Position()
    local side = SIDES[position.side] or SIDES.right
    local anchorX = position.side == "left" and PVEFrame:GetLeft() or PVEFrame:GetRight()
    local panelX = position.side == "left" and self:GetRight() or self:GetLeft()
    local top, anchorTop = self:GetTop(), PVEFrame:GetTop()
    if anchorX and panelX and top and anchorTop then
        position.x = Clamp(panelX - anchorX - side.x)
        position.y = Clamp(top - anchorTop)
    end
    Place()
end

local function Build()
    local viewer = LFGListFrame.ApplicationViewer
    panel = CreateFrame("Frame", nil, viewer, "TooltipBackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", KeepDraggedPosition)
    local background = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetPoint("TOPLEFT", 3, -3)
    background:SetPoint("BOTTOMRIGHT", -3, 3)
    background:SetColorTexture(0.04, 0.04, 0.06, 0.96)
    panel.Sync = Sync

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Applicant filter")

    BuildClasses()
    BuildRoles()
    Box(Row(28), "minItemLevel", "Minimum item level")
    BuildUtility()
    BuildSort()
    BuildMode()

    local footer = Row(22)
    panel.reset = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    panel.reset:SetSize(70, 22)
    panel.reset:SetPoint("TOPLEFT", PAD, 0)
    panel.reset:SetText(RESET)
    panel.reset:SetScript("OnClick", ResetAll)

    panel.status = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.status:SetPoint("LEFT", panel.reset, "RIGHT", 8, 0)

    Filter.panel = panel
    Filter.OnChange(Sync)
    panel:SetScript("OnShow", function()
        Place()
        Sync()
    end)
    panel:SetShown(ns.db.classFilter == true)
    Place()
    Sync()
end

local function SideOptions()
    local container = Settings.CreateControlTextContainer()
    for _, key in ipairs(SIDE_ORDER) do
        container:Add(key, SIDES[key].label)
    end
    return container:GetData()
end

function Filter.Pages(page)
    ns.db.applicantFilterOptions = ns.db.applicantFilterOptions or {}
    ns.ApplyDefaults(ns.db.applicantFilterOptions, { removeFinished = true })
    local remove = Settings.RegisterProxySetting(page.category, "LT_applicantFilter_removeFinished", Settings.VarType.Boolean,
        "Remove closed applications", true,
        function() return ns.db.applicantFilterOptions.removeFinished end,
        function(value) ns.db.applicantFilterOptions.removeFinished = value end)
    ns.AddToPage(page, Settings.CreateCheckbox(page.category, remove,
        "Applications that were cancelled, timed out, declined or turned the invite down leave the list at once, as if you clicked their X."))

    ns.db.applicantPanel = ns.db.applicantPanel or {}
    ns.ApplyDefaults(ns.db.applicantPanel, POSITION_DEFAULTS)
    if not SIDES[Position().side] then Position().side = POSITION_DEFAULTS.side end

    local category = page.category
    local function Proxy(key, varType, label)
        return Settings.RegisterProxySetting(category, "LT_applicantPanel_" .. key, varType, label,
            POSITION_DEFAULTS[key],
            function() return Position()[key] end,
            function(value)
                Position()[key] = value
                Place()
            end)
    end

    ns.AddToPage(page, Settings.CreateDropdown(category, Proxy("side", Settings.VarType.String, "Panel side"),
        SideOptions, "Which side of the group finder the applicant filter panel sits on."))
    for _, key in ipairs({ "x", "y" }) do
        local options = Settings.CreateSliderOptions(-800, 800, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        ns.AddToPage(page, Settings.CreateSlider(category, Proxy(key, Settings.VarType.Number, "Panel " .. key:upper() .. " offset"),
            options, "Pixels to move the panel from its side of the group finder. X moves it right, Y moves it up. Dragging the panel sets these for you."))
    end
end

Filter.BuildPanel = function()
    if not panel and LFGListFrame then Build() end
end
