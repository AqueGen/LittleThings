local _, ns = ...

local Rows = ns.ProfilerRows

local Profiler = {}

local ROW_HEIGHT, HEADER_HEIGHT, REFRESH_SECONDS = 18, 22, 1

local COLUMNS = {
    { key = "name", title = "Addon", width = 220, align = "LEFT" },
    { key = "now", title = "Now", width = 72, metric = "RecentAverageTime", format = "%.2f ms" },
    { key = "average", title = "Average", width = 72, metric = "SessionAverageTime", format = "%.2f ms" },
    { key = "peak", title = "Peak", width = 72, metric = "PeakTime", format = "%.0f ms" },
    { key = "boss", title = "Boss avg", width = 72, metric = "EncounterAverageTime", format = "%.2f ms" },
    { key = "hitches", title = "Hitches", width = 64, metric = "CountTimeOver50Ms", format = "%d" },
    { key = "memory", title = "Memory", width = 72, format = "%.1f MB" },
}

local TABLE_WIDTH = 0
for _, column in ipairs(COLUMNS) do
    TABLE_WIDTH = TABLE_WIDTH + column.width
    column.enum = column.metric and Enum.AddOnProfilerMetric[column.metric]
end

local window, provider
local sortKey = "average"
local memory = {}
local rows, rowsByName = {}, {}

local function LoadedAddOns(func)
    for index = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.IsAddOnLoaded(index) then
            func(index, (C_AddOns.GetAddOnInfo(index)))
        end
    end
end

local function MeasureMemory()
    UpdateAddOnMemoryUsage()
    LoadedAddOns(function(index, name)
        memory[name] = GetAddOnMemoryUsage(index) / 1024
    end)
end

-- Updates the same row tables every second instead of building new ones, and
-- reports whether an addon loaded since the last pass.
local function Collect()
    local added = false
    for index = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.IsAddOnLoaded(index) then
            local name = C_AddOns.GetAddOnInfo(index)
            local row = rowsByName[name]
            if not row then
                row = { name = name, sortName = name:lower() }
                rowsByName[name] = row
                rows[#rows + 1] = row
                added = true
            end
            row.memory = memory[name] or 0
            for _, column in ipairs(COLUMNS) do
                if column.enum then
                    row[column.key] = C_AddOnProfiler.GetAddOnMetric(name, column.enum)
                end
            end
        end
    end
    return added
end

local function Refresh()
    if Collect() or not provider then
        provider = CreateDataProvider(rows)
        window.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
    end
    provider:Sort(Rows.Comparator(sortKey))
    for _, header in ipairs(window.headers) do
        header.Text:SetTextColor((header.key == sortKey and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR):GetRGB())
    end
end

local function Cells(frame, fontObject)
    local cells, x = {}, 0
    for index, column in ipairs(COLUMNS) do
        local cell = frame:CreateFontString(nil, "OVERLAY", fontObject)
        cell:SetPoint("LEFT", frame, "LEFT", x + 4, 0)
        cell:SetWidth(column.width - 8)
        cell:SetJustifyH(column.align or "RIGHT")
        cell:SetWordWrap(false)
        cells[index] = cell
        x = x + column.width
    end
    return cells
end

local function InitRow(frame, row)
    if not frame.cells then
        frame.cells = Cells(frame, "GameFontHighlightSmall")
        frame.hitch = frame:CreateTexture(nil, "BACKGROUND")
        frame.hitch:SetAllPoints()
        frame.hitch:SetColorTexture(1, 0.2, 0.2, 0.18)
    end
    for index, column in ipairs(COLUMNS) do
        local value = row[column.key]
        frame.cells[index]:SetText(column.format and column.format:format(value) or value)
    end
    frame.hitch:SetShown(row.hitches > 0)
end

local function CreateHeaders()
    window.headers = {}
    local x = 0
    for _, column in ipairs(COLUMNS) do
        local header = CreateFrame("Button", nil, window)
        header:SetSize(column.width, HEADER_HEIGHT)
        header:SetPoint("BOTTOMLEFT", window.Inset, "TOPLEFT", 4 + x, 2)
        header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.Text:SetPoint("LEFT", 4, 0)
        header.Text:SetPoint("RIGHT", -4, 0)
        header.Text:SetJustifyH(column.align or "RIGHT")
        header.Text:SetText(column.title)
        header.key = column.key
        header:SetScript("OnClick", function()
            sortKey = column.key
            Refresh()
        end)
        window.headers[#window.headers + 1] = header
        x = x + column.width
    end
end

local function CreateWindow()
    window = CreateFrame("Frame", "LittleThingsAddonPerformance", UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(window)
    window:SetTitle("Addon performance")
    window:SetSize(TABLE_WIDTH + 44, 480)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    table.insert(UISpecialFrames, window:GetName())

    CreateHeaders()

    window.ScrollBox = CreateFrame("Frame", nil, window.Inset, "WowScrollBoxList")
    window.ScrollBox:SetPoint("TOPLEFT", 4, -4)
    window.ScrollBox:SetPoint("BOTTOMRIGHT", -22, 4)
    window.ScrollBar = CreateFrame("EventFrame", nil, window.Inset, "MinimalScrollBar")
    window.ScrollBar:SetPoint("TOPLEFT", window.ScrollBox, "TOPRIGHT", 6, 0)
    window.ScrollBar:SetPoint("BOTTOMLEFT", window.ScrollBox, "BOTTOMRIGHT", 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(window.ScrollBox, window.ScrollBar, view)

    local refresh = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    refresh:SetSize(140, 22)
    refresh:SetPoint("BOTTOMRIGHT", -8, 3)
    refresh:SetText("Refresh memory")
    refresh:SetScript("OnClick", function()
        MeasureMemory()
        Refresh()
    end)

    local note = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 10, 9)
    note:SetText("Times are the game's own measurements since login. Red rows took over 50 ms in a frame.")

    local elapsed = 0
    window:SetScript("OnShow", function()
        MeasureMemory()
        Refresh()
    end)
    window:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= REFRESH_SECONDS then
            elapsed = 0
            Refresh()
        end
    end)
    window:Hide()
end

function Profiler.Toggle()
    if not C_AddOnProfiler.IsEnabled() then
        ns.Print("the game's addon profiler is switched off, there is nothing to show")
        return
    end
    if not window then
        CreateWindow()
    end
    window:SetShown(not window:IsShown())
end

ns.Profiler = Profiler

function Profiler.Pages(page)
    ns.AddHeader(page, "Addons")
    local button = CreateSettingsButtonInitializer("Addon performance", "Show addon CPU", Profiler.Toggle,
        "Opens a table of every loaded addon with the game's own measurements: time per frame now and since login, the slowest frame, the average on the last boss, frames over 50 ms, which show as hitches, and memory. Click a column to sort by it. /lt cpu opens it too, also in combat.", true)
    page.layout:AddInitializer(button)
    ns.AddToPage(page, button)
end

Profiler.key = "performance"
ns.RegisterModule("Profiler", Profiler)
