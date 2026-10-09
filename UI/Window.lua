local addonName, ns = ...

local Widgets = ns.Widgets
local MenuModel = ns.MenuModel
local Rules = ns.WidgetRules
local T = Widgets.THEME

local Window = {}

local DEFAULT_W, DEFAULT_H = 860, 560
local MIN_W, MIN_H = 800, 480
local TITLE_H, MENU_W, ENTRY_H, HEADER_H, GAP, PAD = 28, 150, 20, 18, 4, 8
local WINDOWS_KEY = "damageMeterWindows"
local EXTRAS = { { key = WINDOWS_KEY, label = "Meter windows", after = "damageMeter" } }

local frame, menu, scroll, host
local pages, builders, entries, headers = {}, {}, {}, {}
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
        local on = key == current
        entry:SetBackdropColor(unpack(on and T.selected or T.panel))
        entry.label:SetTextColor(unpack(on and T.gold or (entry.enabled and T.text or T.muted)))
        entry.bar:SetShown(on)
    end
end

local function Entry(item)
    local entry = Widgets.Button(menu, item.label, MENU_W - 2 * PAD)
    entry.label:ClearAllPoints()
    entry.label:SetPoint("LEFT", entry, "LEFT", PAD, 0)
    entry.bar = entry:CreateTexture(nil, "OVERLAY")
    entry.bar:SetPoint("TOPLEFT")
    entry.bar:SetPoint("BOTTOMLEFT")
    entry.bar:SetWidth(2)
    entry.bar:SetColorTexture(unpack(T.gold))
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
            header:SetTextColor(unpack(T.gold))
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

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() frame:Hide() end)

    menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", 0, -TITLE_H)
    menu:SetPoint("BOTTOMLEFT")
    menu:SetWidth(MENU_W)
    menu:SetBackdrop(Widgets.FLAT)
    menu:SetBackdropColor(unpack(T.panel))
    menu:SetBackdropBorderColor(unpack(T.border))

    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", menu, "TOPRIGHT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, PAD + 12)
    host = CreateFrame("Frame", nil, scroll)
    host:SetSize(1, 1)
    scroll:SetScrollChild(host)
    scroll:SetScript("OnSizeChanged", function(_, width) host:SetWidth(width) end)

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
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
end

function Window.Show(key)
    if not frame then Build() end
    key = key or current or Model()[1].entries[1].key
    if current and pages[current] and current ~= key then
        pages[current].frame:Hide()
    end
    current = key
    local page = pages[key] or BuildPage(key)
    page.frame:Show()
    frame:Show()
    LayoutMenu()
    page:Refresh()
    scroll:SetVerticalScroll(0)
end

function Window.Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        Window.Show()
    end
end

ns.Window = Window
