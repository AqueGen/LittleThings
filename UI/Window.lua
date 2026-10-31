-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Widgets = ns.Widgets
local MenuModel = ns.MenuModel
local Rules = ns.WidgetRules
local T = Widgets.THEME
local UI = LibStub("LibVelvet-1.0")

local Window = {}

local DEFAULT_W, DEFAULT_H = 1000, 560
-- MIN_W fits the widest fixed-width page (Meter windows, a 600-wide panel); MIN_H keeps the
-- whole side menu above the footer
local MIN_W, MIN_H = 790, 530
local TITLE_H, MENU_W, ENTRY_H, HEADER_H, GAP, PAD = 28, 150, 20, 18, 4, 8
local SCROLLBAR, BOTTOM = 30, PAD + 12
local ZONE_MIN, ZONE_MAX, BAND_H = 260, 380, 150
local WINDOWS_KEY = "damageMeterWindows"
local EXTRAS = { { key = WINDOWS_KEY, label = "Meter windows", after = "damageMeter" } }

local frame, menu, scroll, host
local pages, builders, entries, headers, panes = {}, {}, {}, {}, {}
local current

local function Saved()
    ns.db.window = ns.db.window or {}
    return ns.db.window
end

local function IsOn(key)
    if key == WINDOWS_KEY then
        return ns.IsOn("damageMeter") and ns.IsAvailable()
    end
    return ns.IsOn(key)
end

local function Row(key)
    for _, row in ipairs(ns.MODULES) do
        if row.key == key then return row end
    end
end

local function Model()
    return MenuModel.Build(ns.MODULES, EXTRAS, IsOn)
end

local function SwitchSpec(row)
    return {
        label = row.label,
        tooltip = row.tooltip,
        reload = not row.live,
        combatLocked = true,
        get = function() return ns.db[row.key] == true end,
        set = function(value) ns.SetSwitch(row.key, value) end,
    }
end

local function CallPages(key, page, fallback)
    for _, module in ipairs(ns.ModulesFor(key)) do
        if module.Pages then
            local ok = xpcall(module.Pages, function(err) geterrorhandler()(err) end, page)
            if not ok then
                fallback():Note("This part failed to build. The error is in the error log (BugSack). The switch above and every other page still work.")
            end
        end
    end
end

local function BuildModulePage(page, row)
    local head = page:Group(row.label)
    head:Check(SwitchSpec(row))
    head:Note(row.tooltip)

    page.visible = function() return ns.IsOn(row.key) end

    local section, group
    for _, child in ipairs(ns.MODULES) do
        if child.parent == row.key then
            if child.section ~= section or not group then
                section = child.section
                group = page:Group(section)
            end
            group:Check(SwitchSpec(child))
            local scoped = group:Scoped(function() return ns.IsOn(child.key) end)
            CallPages(child.key, { Group = function() return scoped end }, function() return scoped end)
        end
    end

    CallPages(row.key, page, function()
        return page:Group("This part failed to build")
    end)
end

local function BuildPage(key)
    local page = Widgets.NewPage(host)
    local ok = xpcall(function()
        if builders[key] then
            builders[key](page)
        else
            BuildModulePage(page, Row(key))
        end
    end, function(err) geterrorhandler()(err) end)
    if not ok then page:Fail() end
    pages[key] = page
    return page
end

local function Paint()
    for key, entry in pairs(entries) do
        UI.PaintNav(entry, key == current and "selected" or (entry.enabled and "normal" or "muted"))
    end
end

local function Entry(item)
    local entry = UI.NavEntry(menu, item.label, MENU_W - 2 * PAD, ENTRY_H)
    entry:SetScript("OnClick", function() Window.Show(item.key) end)
    entries[item.key] = entry
    return entry
end

local function LayoutMenu()
    local y = -PAD
    for _, group in ipairs(Model()) do
        local header = headers[group.title]
        if not header then
            header = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetTextColor(unpack(UI.HEADER))
            header:SetText(group.title)
            headers[group.title] = header
        end
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, y)
        y = y - HEADER_H
        for _, item in ipairs(group.entries) do
            local entry = entries[item.key] or Entry(item)
            entry.enabled = item.on
            entry:ClearAllPoints()
            entry:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, y)
            y = y - ENTRY_H - GAP
        end
        y = y - PAD
    end
    Paint()
end

local function PreviewFor(key)
    for _, module in ipairs(ns.ModulesFor(key)) do
        if module.Preview then return module.Preview end
    end
end

local function PaneFor(preview)
    if not panes[preview] then
        local pane = UI.PreviewPane(frame)
        pane:Hide()
        preview.Attach(pane)
        panes[preview] = pane
    end
    return panes[preview]
end

local function Layout()
    local preview = PreviewFor(current)
    for owner, pane in pairs(panes) do
        if owner ~= preview then pane:Hide() end
    end
    scroll:ClearAllPoints()
    if not preview then
        scroll:SetPoint("TOPLEFT", menu, "TOPRIGHT", PAD, -PAD)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR, BOTTOM)
        return
    end
    local pane = PaneFor(preview)
    local slots = UI.PreviewLayout(frame:GetWidth() - MENU_W - 2 * PAD - SCROLLBAR, preview.columnMin, ZONE_MIN, ZONE_MAX)
    pane:ClearAllPoints()
    if slots.mode == "side" then
        scroll:SetPoint("TOPLEFT", menu, "TOPRIGHT", PAD, -PAD)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD + slots.zoneW + UI.GAP + SCROLLBAR), BOTTOM)
        pane:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(TITLE_H + PAD))
        pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, BOTTOM)
        pane:SetWidth(slots.zoneW)
    else
        scroll:SetPoint("TOPLEFT", menu, "TOPRIGHT", PAD, -(PAD + BAND_H + UI.GAP))
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR, BOTTOM)
        pane:SetPoint("TOPLEFT", menu, "TOPRIGHT", PAD, -PAD)
        pane:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(TITLE_H + PAD))
        pane:SetHeight(BAND_H)
    end
    pane:Show()
end

local function RefreshPreview()
    local preview = PreviewFor(current)
    if preview then preview.Refresh() end
end

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local saved = Saved()
    saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

local function Build()
    frame = CreateFrame("Frame", "LittleThingsSettings", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "LittleThingsSettings")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop(Widgets.FLAT)
    frame:SetBackdropColor(unpack(T.bg))
    frame:SetBackdropBorderColor(unpack(T.border))
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_W, MIN_H)
    frame:EnableMouse(true)

    local saved = Saved()
    frame:SetSize(Rules.Size(saved.width, saved.height, MIN_W, MIN_H, DEFAULT_W, DEFAULT_H))
    if saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    else
        frame:SetPoint("CENTER")
    end

    local title = CreateFrame("Frame", nil, frame)
    title:SetPoint("TOPLEFT")
    title:SetPoint("TOPRIGHT")
    title:SetHeight(TITLE_H)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() frame:StartMoving() end)
    title:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)
    local name = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", PAD, 0)
    name:SetTextColor(unpack(T.gold))
    name:SetText("LittleThings")

    local close = Widgets.Button(title, "X", 22)
    close:SetPoint("RIGHT", title, "RIGHT", -(TITLE_H - 22) / 2, 0)
    close:SetScript("OnClick", function() frame:Hide() end)

    menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", 0, -TITLE_H)
    menu:SetPoint("BOTTOMLEFT")
    menu:SetWidth(MENU_W)
    menu:SetBackdrop(Widgets.FLAT)
    menu:SetBackdropColor(unpack(T.panel))
    menu:SetBackdropBorderColor(unpack(T.border))

    local signature = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    signature:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", PAD, PAD)
    signature:SetText("|cFF0057B7Made|r |cFFFFD700in Ukraine|r")

    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    host = CreateFrame("Frame", nil, scroll)
    host:SetSize(1, 1)
    scroll:SetScrollChild(host)
    scroll:SetScript("OnSizeChanged", function(_, width)
        host:SetWidth(width)
        -- Notes rewrap to the new width, so the page has to re-stack
        if current and pages[current] then pages[current]:Refresh() end
    end)
    frame:HookScript("OnSizeChanged", function()
        if current then Layout() end
    end)

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    -- The grip sizes the window itself instead of StartSizing, which in CastAhead's identical
    -- window now and then set a size of its own on the first frame and ran off under the cursor.
    -- The top-left corner stays put; the size never passes the screen's right or bottom edge.
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local left, top = frame:GetLeft(), frame:GetTop()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        local scale = frame:GetEffectiveScale()
        local x0, y0 = GetCursorPosition()
        local w0, h0 = frame:GetSize()
        local maxW = UIParent:GetWidth() * UIParent:GetEffectiveScale() / scale - left
        self:SetScript("OnUpdate", function(grabbed)
            if not IsMouseButtonDown("LeftButton") then
                grabbed:GetScript("OnMouseUp")(grabbed)
                return
            end
            local x, y = GetCursorPosition()
            frame:SetSize(Rules.GripSize(w0, h0, (x - x0) / scale, (y0 - y) / scale, MIN_W, MIN_H, maxW, top))
        end)
    end)
    grip:SetScript("OnMouseUp", function(self)
        if not self:GetScript("OnUpdate") then return end
        self:SetScript("OnUpdate", nil)
        local s = Saved()
        s.width, s.height = frame:GetSize()
        SavePosition()
    end)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function() C_Timer.After(0, Window.Refresh) end)

    LayoutMenu()
end

function Window.Register(key, build)
    builders[key] = build
end

function Window.Refresh()
    if not frame or not frame:IsShown() then return end
    LayoutMenu()
    if current and pages[current] then pages[current]:Refresh() end
    RefreshPreview()
end

function Window.Show(key)
    if not frame then Build() end
    key = key or current or Model()[1].entries[1].key
    if current and pages[current] and current ~= key then
        pages[current].frame:Hide()
    end
    current = key
    Layout()
    local page = pages[key] or BuildPage(key)
    page.frame:Show()
    frame:Show()
    LayoutMenu()
    page:Refresh()
    scroll:SetVerticalScroll(0)
    RefreshPreview()
end

function Window.Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        Window.Show()
    end
end

ns.Window = Window
