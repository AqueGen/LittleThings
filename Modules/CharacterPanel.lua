local addonName, ns = ...

local Buttons = ns.IconButtons

local CharacterPanel = {}

local LABEL_GAP = 4
local CORNERS = {
    topleft = { "BOTTOMLEFT", "TOPLEFT" },
    topright = { "BOTTOMRIGHT", "TOPRIGHT" },
    bottomleft = { "TOPLEFT", "BOTTOMLEFT" },
    bottomright = { "TOPRIGHT", "BOTTOMRIGHT" },
}

-- Two bars, each placed on its own: specializations and loot specialization.
local BARS = {
    { key = "specBar", label = SPECIALIZATION, defaults = { corner = "bottomleft", x = 8, y = -45, header = "bottom", size = Buttons.SIZE } },
    { key = "lootBar", label = SELECT_LOOT_SPECIALIZATION, defaults = { corner = "bottomleft", x = 190, y = -45, header = "bottom", size = Buttons.SIZE } },
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

-- Places the label and the icons for the header position, and sizes the
-- bar to fit them. count is how many icons the bar shows.
local function Layout(bar, count)
    local header = bar.db.header
    local size = bar.db.size
    local step = size + Buttons.GAP
    local iconsWidth = step * count - Buttons.GAP
    local labelWidth = bar.label:GetStringWidth()
    local x, y = 0, 0

    bar.label:ClearAllPoints()

    if header == "left" then
        bar.label:SetPoint("LEFT", bar, "LEFT", 0, 0)
        x = labelWidth + LABEL_GAP
        bar:SetSize(x + iconsWidth, size)
    elseif header == "right" then
        bar.label:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        bar:SetSize(iconsWidth + LABEL_GAP + labelWidth, size)
    elseif header == "top" then
        bar.label:SetPoint("TOP", bar, "TOP", 0, 0)
        y = -(bar.label:GetStringHeight() + 2)
        bar:SetSize(math.max(iconsWidth, labelWidth), size - y)
    else
        bar.label:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
        bar:SetSize(math.max(iconsWidth, labelWidth), size + bar.label:GetStringHeight() + 2)
    end

    if header == "top" or header == "bottom" then
        x = (bar:GetWidth() - iconsWidth) / 2
    end

    for i = 1, count do
        bar.buttons[i - 1]:SetSize(size, size)
        bar.buttons[i - 1]:ClearAllPoints()
        bar.buttons[i - 1]:SetPoint("TOPLEFT", bar, "TOPLEFT", x + step * (i - 1), y)
    end
end

local function Refresh()
    local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(select(3, UnitClass("player")))
    local current = C_SpecializationInfo.GetSpecialization()
    local spec = bars.specBar

    for i = 1, numSpecs do
        local _, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(i)
        local b = Buttons.New(spec, i - 1)
        b.index, b.tip = i, name
        b.icon:SetTexture(icon)
        Buttons.SetActive(b, i == current)
        b:Show()
    end

    Layout(spec, numSpecs)
    Layout(bars.lootBar, Buttons.FillLootSpecs(bars.lootBar, true))
end

local function RefreshIfShown()
    if bars.specBar and bars.specBar:IsShown() and PaperDollFrame:IsShown() then
        Refresh()
    end
end

local function Bar(bar, key, spec, onChange)
    spec.default = bar.defaults[key]
    spec.get = function() return ns.db[bar.key][key] end
    spec.set = function(value)
        ns.db[bar.key][key] = value
        if bars[bar.key] then
            onChange(bars[bar.key])
        end
    end
    return spec
end

local CORNER_OPTIONS = {
    { value = "bottomleft", text = "Below the panel, left" },
    { value = "bottomright", text = "Below the panel, right" },
    { value = "topleft", text = "Above the panel, left" },
    { value = "topright", text = "Above the panel, right" },
}

local HEADER_OPTIONS = {
    { value = "bottom", text = "Below the icons" },
    { value = "top", text = "Above the icons" },
    { value = "left", text = "Left of the icons" },
    { value = "right", text = "Right of the icons" },
}

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

function CharacterPanel.Pages(page)
    InitializeDb()

    page:Group("Bars"):Check({ label = "Lock bars",
        tooltip = "Drag a bar on the character panel to place it, fine-tune with the offsets below, then lock it so it cannot be dragged.",
        get = function() return ns.db.characterPanelLocked == true end,
        set = function(value) ns.db.characterPanelLocked = value end })

    for _, bar in ipairs(BARS) do
        local group = page:Group(bar.label)
        group:Dropdown(Bar(bar, "header", { label = "Header", options = HEADER_OPTIONS,
            tooltip = "Where the bar's title sits." }, RefreshIfShown))
        group:Dropdown(Bar(bar, "corner", { label = "Anchor corner", options = CORNER_OPTIONS,
            tooltip = "Which corner of the character panel the bar hangs from." }, Anchor))
        for _, key in ipairs({ "x", "y" }) do
            group:Slider(Bar(bar, key, { label = key:upper() .. " offset", min = -400, max = 400,
                tooltip = "Pixels from the chosen corner." }, Anchor))
        end
        group:Slider(Bar(bar, "size", { label = "Icon size", min = 16, max = 48,
            tooltip = "Icon size in pixels." }, RefreshIfShown))
    end
end

local function CreateBar(spec)
    local bar = CreateFrame("Frame", nil, PaperDollFrame)
    bar.key = spec.key
    bar.db = ns.db[spec.key]
    bar.buttons = {}
    bar.onClick = spec.key == "specBar" and OnSpecClick or Buttons.OnLootClick
    bar:SetSize(Buttons.SIZE, Buttons.SIZE)
    -- The item slots sit at level 100 inside the same panel; anything below
    -- that is drawn under them once the bar is dragged over the panel.
    bar:SetFrameLevel(200)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    -- The lock is checked at drag time, not by disabling the mouse: a drag
    -- that starts on an icon is handed up to the bar whether or not the bar
    -- itself listens to the mouse, so only the handler can refuse it.
    bar:SetScript("OnDragStart", function(self)
        if not ns.db.characterPanelLocked then
            self:StartMoving()
        end
    end)
    bar:SetScript("OnDragStop", function(self)
        if self:IsMovable() and not ns.db.characterPanelLocked then
            self:StopMovingOrSizing()
            SaveDraggedPosition(self)
        end
    end)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.db.characterPanelLocked and "Locked (LittleThings settings)" or "Drag to move", 1, 1, 1)
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
