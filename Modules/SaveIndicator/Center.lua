local addonName, ns = ...

local Rules = ns.SaveRules

local Center = {}
ns.SaveCenter = Center

local ICON = 32
local LABEL = 14
local STEP = ICON + 4
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local SAMPLES = { { id = 389539, dr = 24 }, { id = 33206, dr = 40 } }

local row, preview
local containers = {}
local wanted = false

local function Point(frame)
    local db = ns.db.saveIndicatorRow
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    frame:SetScale(db.scale)
end

local function Initializer(entry)
    local db = ns.db.saveIndicatorRow
    local formatter
    if entry.perStack then
        formatter = C_StringUtil.CreateNumericRuleFormatter()
        formatter:SetBreakpoints(Rules.StackBreakpoints(entry.perStack, entry.maxStacks))
    end
    return function(btn)
        btn:SetSize(STEP, ICON + LABEL)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON, ICON)
        icon:SetPoint("TOPLEFT")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn:SetIcon(icon)
        local swipe = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        swipe:SetAllPoints(icon)
        swipe:SetHideCountdownNumbers(true)
        btn:SetDurationCooldown(swipe)
        if db.showTime then
            local text = CreateFrame("Frame", nil, btn)
            text:SetAllPoints(icon)
            text:SetFrameLevel(swipe:GetFrameLevel() + 2)
            local time = text:CreateFontString(nil, "OVERLAY")
            time:SetFont(FONT, 13, "OUTLINE")
            time:SetPoint("CENTER")
            btn:SetDurationText(time, {})
        end
        if db.showDR then
            local dr = btn:CreateFontString(nil, "OVERLAY")
            dr:SetFont(FONT, 12, "OUTLINE")
            dr:SetPoint("TOP", icon, "BOTTOM", 0, -1)
            if formatter then
                btn:SetApplicationCount(dr, { formatter = formatter })
            else
                dr:SetText("|c" .. Rules.COLORS.normal .. Rules.Label(entry.dr) .. "|r")
            end
        end
        if btn.SetHideTooltipInCombat then btn:SetHideTooltipInCombat(true) end
    end
end

local function Container(entry)
    local ok, c = pcall(CreateFrame, "AuraContainer", nil, row, "CustomAuraContainerTemplate")
    if not ok or not c then
        return nil
    end
    if c.SetEditModePreviewEnabled then c:SetEditModePreviewEnabled(false) end
    c:SetFlowLayoutMaximumLineSize(STEP * 4)
    c:SetUnit("player")
    c:AddAuraGroup("saves", "HELPFUL", {
        candidateFilters = { includeSpellIDs = entry.ids },
        initializeFrame = Initializer(entry),
        sortMethod = AuraContainerSortMethod.Expiration,
        maxFrameCount = 4,
        layout = { elementWidth = STEP, elementHeight = ICON + LABEL },
    })
    return c
end

local function Build()
    row = CreateFrame("Frame", "LittleThingsSaveRow", UIParent)
    row:SetSize(STEP * #SAMPLES, ICON + LABEL)
    row:SetFrameStrata("MEDIUM")
    Point(row)
    local prev
    for _, entry in ipairs(Rules.Row(ns.SaveData)) do
        local c = Container(entry)
        if c then
            if prev then
                c:SetPoint("TOPLEFT", prev, "TOPRIGHT", 0, 0)
            else
                c:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            end
            containers[#containers + 1] = c
            prev = c
        end
    end
end

local function ApplyNow()
    if wanted and not row then
        Build()
    end
    if row then
        row:SetShown(wanted)
    end
end

local deferred = {}
local regen = CreateFrame("Frame")
regen:SetScript("OnEvent", function()
    regen:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local run = deferred
    deferred = {}
    for func in pairs(run) do func() end
end)

function ns.SaveDefer(func)
    if InCombatLockdown() then
        deferred[func] = true
        regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        func()
    end
end

function Center.Apply(on)
    wanted = on
    ns.SaveDefer(ApplyNow)
end

function Center.Place()
    if preview then Point(preview) end
    if row then ns.SaveDefer(function() Point(row) end) end
end

local function BuildPreview()
    preview = CreateFrame("Frame", "LittleThingsSaveRowPreview", UIParent)
    preview:SetSize(STEP * #SAMPLES, ICON + LABEL)
    preview:SetFrameStrata("FULLSCREEN_DIALOG")
    preview:SetMovable(true)
    preview:SetClampedToScreen(true)
    preview:EnableMouse(true)
    preview:RegisterForDrag("LeftButton")
    local outline = preview:CreateTexture(nil, "BACKGROUND")
    outline:SetAllPoints()
    outline:SetColorTexture(1, 0.82, 0, 0.25)
    for i, sample in ipairs(SAMPLES) do
        local icon = preview:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON, ICON)
        icon:SetPoint("TOPLEFT", (i - 1) * STEP, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(C_Spell.GetSpellTexture(sample.id))
        local dr = preview:CreateFontString(nil, "OVERLAY")
        dr:SetFont(FONT, 12, "OUTLINE")
        dr:SetPoint("TOP", icon, "BOTTOM", 0, -1)
        dr:SetText("|c" .. Rules.COLORS.normal .. Rules.Label(sample.dr) .. "|r")
    end
    preview:SetScript("OnDragStart", function(self)
        if not ns.db.saveIndicatorRow.locked and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    preview:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local db = ns.db.saveIndicatorRow
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        db.x, db.y = Rules.CenterOffset(cx, cy, ux, uy, db.scale)
        Center.Place()
        if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end
    end)
end

local pageOpen, demo = false, false

local function ShowPreview()
    local on = pageOpen or demo
    if on and not preview then
        BuildPreview()
    end
    if preview then
        Point(preview)
        preview:SetShown(on)
    end
end

function Center.SetPreview(on)
    pageOpen = on
    ShowPreview()
end

function Center.ToggleDemo()
    demo = not demo
    ShowPreview()
    return demo
end
