local addonName, ns = ...

local CharacterPanel = {}

local SIZE, STEP, LABEL_GAP = 20, 22, 4
local BORDER = "Interface\\ContainerFrame\\UI-Icon-QuestBorder"
local CORNERS = {
    topleft = { "BOTTOMLEFT", "TOPLEFT" },
    topright = { "BOTTOMRIGHT", "TOPRIGHT" },
    bottomleft = { "TOPLEFT", "BOTTOMLEFT" },
    bottomright = { "TOPRIGHT", "BOTTOMRIGHT" },
}

-- Two bars, each placed on its own: specializations and loot specialization.
local BARS = {
    { key = "specBar", label = SPECIALIZATION, defaults = { corner = "bottomleft", x = 8, y = -45, header = "bottom" } },
    { key = "lootBar", label = SELECT_LOOT_SPECIALIZATION, defaults = { corner = "bottomleft", x = 120, y = -45, header = "bottom" } },
}

local bars = {}

local function Edge(frame, point, axis)
    if axis == "x" then
        return point:find("RIGHT") and frame:GetRight() or frame:GetLeft()
    end
    return point:find("TOP") and frame:GetTop() or frame:GetBottom()
end

local function Anchor(bar)
    local db = bar.db
    local points = CORNERS[db.corner] or CORNERS.bottomleft
    bar:ClearAllPoints()
    bar:SetPoint(points[1], CharacterFrame, points[2], db.x, db.y)
end

-- After a drag the bar sits wherever the mouse left it; the saved offsets
-- are that spot measured from the chosen corner, so the sliders on the
-- settings page and the drag describe the same position.
local function SaveDraggedPosition(bar)
    local db = bar.db
    local points = CORNERS[db.corner] or CORNERS.bottomleft
    db.x = math.floor(Edge(bar, points[1], "x") - Edge(CharacterFrame, points[2], "x") + 0.5)
    db.y = math.floor(Edge(bar, points[1], "y") - Edge(CharacterFrame, points[2], "y") + 0.5)
    Anchor(bar)
end

local function NewButton(bar, index)
    local b = bar.buttons[index]
    if b then return b end
    b = CreateFrame("Button", nil, bar)
    b:SetSize(SIZE, SIZE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.overlay = b:CreateTexture(nil, "OVERLAY")
    b.overlay:SetAllPoints()
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", bar.onClick)
    bar.buttons[index] = b
    return b
end

local function SetActive(b, active)
    if active then
        b.overlay:SetTexture(BORDER)
        b.overlay:SetVertexColor(1, 1, 1, 1)
    else
        b.overlay:SetColorTexture(0, 0, 0, 0.65)
    end
end

local function OnSpecClick(self)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
        return
    end
    if self.index ~= C_SpecializationInfo.GetSpecialization() then
        C_SpecializationInfo.SetSpecialization(self.index)
        PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK)
    end
end

local function OnLootClick(self)
    if self.specId ~= GetLootSpecialization() then
        SetLootSpecialization(self.specId)
        PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK)
    end
end

-- Places the label and the icons for the header position, and sizes the
-- bar to fit them. count is how many icons the bar shows.
local function Layout(bar, count)
    local header = bar.db.header
    local iconsWidth = STEP * count - (STEP - SIZE)
    local labelWidth = bar.label:GetStringWidth()
    local x, y = 0, 0

    bar.label:ClearAllPoints()

    if header == "left" then
        bar.label:SetPoint("LEFT", bar, "LEFT", 0, 0)
        x = labelWidth + LABEL_GAP
        bar:SetSize(x + iconsWidth, SIZE)
    elseif header == "top" then
        bar.label:SetPoint("TOP", bar, "TOP", 0, 0)
        y = -(bar.label:GetStringHeight() + 2)
        bar:SetSize(math.max(iconsWidth, labelWidth), SIZE - y)
    else
        bar.label:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
        bar:SetSize(math.max(iconsWidth, labelWidth), SIZE + bar.label:GetStringHeight() + 2)
    end

    if header ~= "left" then
        x = (bar:GetWidth() - iconsWidth) / 2
    end

    for i = 1, count do
        bar.buttons[i - 1]:ClearAllPoints()
        bar.buttons[i - 1]:SetPoint("TOPLEFT", bar, "TOPLEFT", x + STEP * (i - 1), y)
    end
end

local function Refresh()
    local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(select(3, UnitClass("player")))
    local current = C_SpecializationInfo.GetSpecialization()
    local lootSpec = GetLootSpecialization()
    local currentName = current and select(2, C_SpecializationInfo.GetSpecializationInfo(current)) or ""
    local spec, loot = bars.specBar, bars.lootBar

    for i = 1, numSpecs do
        local id, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(i)
        local b = NewButton(spec, i - 1)
        b.index, b.tip = i, name
        b.icon:SetTexture(icon)
        SetActive(b, i == current)
        b:Show()

        local lb = NewButton(loot, i)
        lb.specId, lb.tip = id, name
        lb.icon:SetTexture(icon)
        SetActive(lb, id == lootSpec)
        lb:Show()
    end

    local auto = NewButton(loot, 0)
    auto.specId, auto.tip = 0, LOOT_SPECIALIZATION_DEFAULT:format(currentName)
    auto.icon:SetTexture(current and select(4, C_SpecializationInfo.GetSpecializationInfo(current)))
    SetActive(auto, lootSpec == 0)
    auto:Show()

    Layout(spec, numSpecs)
    Layout(loot, numSpecs + 1)
end

local function RefreshIfShown()
    if bars.specBar and bars.specBar:IsShown() and PaperDollFrame:IsShown() then
        Refresh()
    end
end

local function Proxy(category, bar, key, varType, label, onChange)
    return Settings.RegisterProxySetting(category, "LT_" .. bar.key .. "_" .. key, varType, label, bar.defaults[key],
        function() return ns.db[bar.key][key] end,
        function(value)
            ns.db[bar.key][key] = value
            if bars[bar.key] then
                onChange(bars[bar.key])
            end
        end)
end

local function CornerOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add("bottomleft", "Below the panel, left")
    container:Add("bottomright", "Below the panel, right")
    container:Add("topleft", "Above the panel, left")
    container:Add("topright", "Above the panel, right")
    return container:GetData()
end

local function HeaderOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add("bottom", "Below the icons")
    container:Add("top", "Above the icons")
    container:Add("left", "Left of the icons")
    return container:GetData()
end

-- The layout of one bar was saved under one table before the bars split;
-- the specialization bar keeps that position.
local function InitializeDb()
    if ns.db.specRowLayout and not ns.db.specBar then
        ns.db.specBar = ns.db.specRowLayout
    end
    ns.db.specRowLayout = nil

    for _, bar in ipairs(BARS) do
        ns.db[bar.key] = ns.db[bar.key] or {}
        ns.ApplyDefaults(ns.db[bar.key], bar.defaults)
    end
end

-- The options exist whether or not the module is on: the page is where the
-- module is switched on, and a page with one checkbox says nothing about
-- what it switches.
function CharacterPanel.Pages(page)
    InitializeDb()

    local category = page.category
    if page.layout and CreateSettingsListSectionHeaderInitializer then
        page.layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Two bars next to the character panel: your specializations, and the loot specialization. One click switches. Drag a bar on the panel to move it; the corner and offsets below are the same position in numbers."))
    end

    -- Locked bars ignore the mouse, so they cannot be dragged off the spot
    -- the sliders put them on; the icons are frames of their own and keep
    -- working.
    local lock = Settings.RegisterProxySetting(category, "LT_characterPanel_locked", Settings.VarType.Boolean,
        "Lock bars", false,
        function() return ns.db.characterPanelLocked == true end,
        function(value)
            ns.db.characterPanelLocked = value
            for _, bar in pairs(bars) do
                bar:EnableMouse(not value)
            end
        end)
    Settings.CreateCheckbox(category, lock, "Stop the bars from being dragged. Place them roughly by dragging, fine-tune with the offsets below, then lock.")

    for _, bar in ipairs(BARS) do
        if page.layout and CreateSettingsListSectionHeaderInitializer then
            page.layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(bar.label))
        end

        Settings.CreateDropdown(category, Proxy(category, bar, "header", Settings.VarType.String, "Header", RefreshIfShown),
            HeaderOptions, "Where the bar's title sits.")
        Settings.CreateDropdown(category, Proxy(category, bar, "corner", Settings.VarType.String, "Anchor corner", Anchor),
            CornerOptions, "Which corner of the character panel the bar hangs from.")

        for _, key in ipairs({ "x", "y" }) do
            local setting = Proxy(category, bar, key, Settings.VarType.Number, key:upper() .. " offset", Anchor)
            local options = Settings.CreateSliderOptions(-400, 400, 1)
            options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
            Settings.CreateSlider(category, setting, options, "Pixels from the chosen corner.")
        end
    end
end

local function CreateBar(spec)
    local bar = CreateFrame("Frame", nil, PaperDollFrame)
    bar.key = spec.key
    bar.db = ns.db[spec.key]
    bar.buttons = {}
    bar.onClick = spec.key == "specBar" and OnSpecClick or OnLootClick
    bar:SetSize(SIZE, SIZE)
    -- The item slots sit at level 100 inside the same panel; anything below
    -- that is drawn under them once the bar is dragged over the panel.
    bar:SetFrameLevel(200)
    bar:SetMovable(true)
    bar:EnableMouse(not ns.db.characterPanelLocked)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveDraggedPosition(self)
    end)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Drag to move", 1, 1, 1)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)

    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.label:SetText(spec.label)

    Anchor(bar)
    return bar
end

function CharacterPanel.Enable()
    if bars.specBar then
        bars.specBar:Show()
        bars.lootBar:Show()
        return
    end

    InitializeDb()
    for _, spec in ipairs(BARS) do
        bars[spec.key] = CreateBar(spec)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    events:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
        RefreshIfShown()
    end)
    PaperDollFrame:HookScript("OnShow", RefreshIfShown)

    RefreshIfShown()
end

-- Nothing here hooks anything of Blizzard's, so the switch works live: on
-- builds the bars (or shows them again), off hides them.
function CharacterPanel.OnSwitch(enabled)
    if enabled then
        CharacterPanel.Enable()
    elseif bars.specBar then
        bars.specBar:Hide()
        bars.lootBar:Hide()
    end
end

CharacterPanel.key = "characterPanel"
ns.RegisterModule("CharacterPanel", CharacterPanel)
