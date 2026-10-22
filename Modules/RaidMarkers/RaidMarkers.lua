local addonName, ns = ...

local Rules = ns.MarkerRules

local RaidMarkers = {}

local SIZE, GAP, PAD = 26, 2, 4
local CLEAR_WIDTH = 60
local DIMMED = 0.35
local TARGET_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local WORLD_COLORS = {
    { 4, 149, 255 }, { 15, 155, 12 }, { 168, 14, 192 }, { 167, 20, 13 },
    { 222, 218, 50 }, { 208, 84, 0 }, { 116, 155, 179 }, { 243, 241, 235 },
}

local DEFAULTS = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 220, locked = false, scale = 1, vertical = false, pullLeft = 10, pullRight = 5 }

local active = false
local panel, row1, row2, events, ticker
local targetButtons, worldButtons = {}, {}
local groupButtons = {}
local readyText, readyTint, readyToken
local countdownRunning, countdownToken = false, 0
local bindNext, bindClear

local NEXT_BODY = [[
local n = self:GetAttribute("lt-next") or 1
self:SetAttribute("macrotext", "/wm [@cursor]" .. n)
self:SetAttribute("lt-next", n % 8 + 1)
]]
local CLEAR_BODY = [[self:GetFrameRef("next"):SetAttribute("lt-next", 1)]]

local READY_COLORS = { waiting = { 1, 0.82, 0 }, notready = { 1, 0.2, 0.2 }, ready = { 0.2, 1, 0.2 } }
local WHITE, GREY, RED = { 1, 1, 1 }, { 0.5, 0.5, 0.5 }, { 1, 0.2, 0.2 }
local MRT_ICON = 609902

local function InitializeDb()
    ns.db.raidMarkerPanel = ns.db.raidMarkerPanel or {}
    ns.ApplyDefaults(ns.db.raidMarkerPanel, DEFAULTS)
end

local function NewButton(row, template, width)
    local button = CreateFrame("Button", nil, row, template)
    button:SetSize(width, SIZE)
    button.width = width
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.buttons[#row.buttons + 1] = button
    return button
end

local function Label(button, text)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    return label
end

local function SecureButton(row, width, attributes)
    local button = NewButton(row, "SecureActionButtonTemplate", width)
    button:RegisterForClicks("AnyUp", "AnyDown")
    for key, value in pairs(attributes) do
        button:SetAttribute(key, value)
    end
    return button
end

local function AddGroupButton(row, name, width)
    local button = NewButton(row, nil, width)
    button.label = Label(button, name)
    return button
end

local function HasRank(query)
    local value = query("player")
    return not issecretvalue(value) and value == true
end

local function BlockReason(action)
    return Rules.GroupActionBlock({
        inGroup = IsInGroup(),
        inRaid = IsInRaid(),
        leader = HasRank(UnitIsGroupLeader),
        assistant = HasRank(UnitIsGroupAssistant),
        combat = InCombatLockdown(),
        lockdown = C_ChatInfo.InChatMessagingLockdown(),
        lfg = HasLFGRestrictions(),
    }, action)
end

local function PaintGroupButtons()
    for key, button in pairs(groupButtons) do
        if button.action then
            local reason = BlockReason(button.action)
            local color = reason and GREY or (key == "ready" and readyTint) or WHITE
            button.reason = reason
            button:SetEnabled(not reason)
            button.label:SetTextColor(color[1], color[2], color[3])
            if key == "ready" then
                button.label:SetText(readyText or "Ready")
            end
        end
    end
end

local function ShowTip(button)
    PaintGroupButtons()
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:AddLine(button.title, 1, 1, 1)
    if button.lines then
        for _, line in ipairs(button.lines()) do
            GameTooltip:AddLine(line, 0.8, 0.8, 0.8)
        end
    end
    if button.reason then
        GameTooltip:AddLine(button.reason, RED[1], RED[2], RED[3], true)
    end
    GameTooltip:Show()
end

local function GroupButton(key, text, width, action, title, lines, onClick)
    local button = AddGroupButton(row1, text, width)
    button.action, button.title, button.lines = action, title, lines
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self, mouse)
        if action and BlockReason(action) then
            return
        end
        onClick(self, mouse)
    end)
    groupButtons[key] = button
    return button
end

local function ReadyStatuses()
    local statuses = {}
    local units = {}
    local count = GetNumGroupMembers()
    if IsInRaid() then
        for i = 1, count do
            units[#units + 1] = "raid" .. i
        end
    else
        units[1] = "player"
        for i = 1, count - 1 do
            units[#units + 1] = "party" .. i
        end
    end
    for _, unit in ipairs(units) do
        local status = GetReadyCheckStatus(unit)
        statuses[#statuses + 1] = (issecretvalue(status) or status == nil) and "unknown" or status
    end
    return statuses
end

local function UpdateReady(finished)
    readyToken = nil
    local state, ready, total = Rules.ReadyTally(ReadyStatuses(), finished)
    readyText, readyTint = Rules.ReadyLabel(ready, total), READY_COLORS[state]
    PaintGroupButtons()
    if finished then
        local token = {}
        readyToken = token
        C_Timer.After(5, function()
            if readyToken == token then
                readyToken, readyText, readyTint = nil, nil, nil
                PaintGroupButtons()
            end
        end)
    end
end

local function LayoutRow(row, vertical)
    local offset, across = 0, 0
    for _, button in ipairs(row.buttons) do
        button:ClearAllPoints()
        if vertical then
            button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -offset)
            offset = offset + SIZE + GAP
            across = math.max(across, button.width)
        else
            button:SetPoint("TOPLEFT", row, "TOPLEFT", offset, 0)
            offset = offset + button.width + GAP
            across = SIZE
        end
    end
    if vertical then
        row:SetSize(across, offset - GAP)
        return across, offset - GAP
    end
    row:SetSize(offset - GAP, across)
    return offset - GAP, across
end

local function Layout()
    local vertical = ns.db.raidMarkerPanel.vertical
    local w1, h1 = LayoutRow(row1, vertical)
    local w2, h2 = LayoutRow(row2, vertical)
    row1:ClearAllPoints()
    row1:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    row2:ClearAllPoints()
    if vertical then
        row2:SetPoint("TOPLEFT", row1, "TOPRIGHT", GAP, 0)
        panel:SetSize(w1 + GAP + w2 + 2 * PAD, math.max(h1, h2) + 2 * PAD)
    else
        row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -GAP)
        panel:SetSize(math.max(w1, w2) + 2 * PAD, h1 + GAP + h2 + 2 * PAD)
    end
end

local function Place()
    local db = ns.db.raidMarkerPanel
    panel:ClearAllPoints()
    panel:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    panel:SetScale(db.scale)
end

local function RefreshTarget()
    local index = GetRaidTargetIndex("target")
    if issecretvalue(index) then
        return
    end
    for i, button in ipairs(targetButtons) do
        button.selected:SetShown(index == i)
    end
end

local function RefreshWorld()
    for i, button in ipairs(worldButtons) do
        local placed = IsRaidMarkerActive(i)
        if not issecretvalue(placed) then
            button:SetAlpha(placed and 1 or DIMMED)
        end
    end
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function RequestVisibility()
    if not panel or InCombatLockdown() then
        return
    end
    local shown = active and Rules.Visible({
        inGroup = IsInGroup(),
        inRaid = IsInRaid(),
        leader = HasRank(UnitIsGroupLeader),
        assistant = HasRank(UnitIsGroupAssistant),
    })
    if shown then
        panel:Show()
    else
        panel:Hide()
    end
end

local function NewRow()
    local row = CreateFrame("Frame", nil, panel)
    row.buttons = {}
    return row
end

-- Secure buttons take their attributes only out of combat, so the panel is
-- built on the first chance outside it.
local function Build()
    if panel or not active or InCombatLockdown() then
        return
    end

    panel = CreateFrame("Frame", "LittleThingsRaidMarkers", UIParent)
    panel:Hide()
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetDontSavePosition(true)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.4)

    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        if not ns.db.raidMarkerPanel.locked and not InCombatLockdown() then
            self.moving = true
            self:StartMoving()
        end
    end)
    panel:SetScript("OnDragStop", function(self)
        if not self.moving then
            return
        end
        self.moving = false
        self:StopMovingOrSizing()
        local db = ns.db.raidMarkerPanel
        local point, _, relativePoint, x, y = self:GetPoint()
        db.point, db.relativePoint = point, relativePoint
        db.x, db.y = math.floor(x + 0.5), math.floor(y + 0.5)
        Place()
    end)
    panel:SetScript("OnShow", function()
        RefreshTarget()
        RefreshWorld()
        StopTicker()
        ticker = C_Timer.NewTicker(1, RefreshWorld)
    end)
    panel:SetScript("OnHide", StopTicker)

    row1, row2 = NewRow(), NewRow()

    for i = 1, 8 do
        local button = SecureButton(row1, SIZE, { type = "raidtarget", marker = i, action1 = "set", action2 = "clear", unit = "target" })
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(TARGET_ICONS)
        SetRaidTargetIconTexture(icon, i)
        button.selected = button:CreateTexture(nil, "OVERLAY")
        button.selected:SetAllPoints()
        button.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        button.selected:SetBlendMode("ADD")
        button.selected:Hide()
        targetButtons[i] = button
    end
    Label(SecureButton(row1, CLEAR_WIDTH, { type = "raidtarget", action = "clear-all" }), "Clear all")

    GroupButton("ready", "Ready", CLEAR_WIDTH, "ready", "Ready check", nil, function()
        C_PartyInfo.DoReadyCheck()
    end)
    local pull = GroupButton("pull", "Pull", 40, "pull", "Pull countdown", function()
        local db = ns.db.raidMarkerPanel
        return {
            "Left click: start " .. Rules.PullSeconds(db, "LeftButton") .. " s",
            "Right click: start " .. Rules.PullSeconds(db, "RightButton") .. " s",
            "Click while counting: cancel",
        }
    end, function(_, mouse)
        if countdownRunning then
            C_PartyInfo.DoCountdown(0)
        else
            C_PartyInfo.DoCountdown(Rules.PullSeconds(ns.db.raidMarkerPanel, mouse))
        end
    end)
    pull:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    GroupButton("role", "Role", 40, "role", "Role check", nil, function()
        InitiateRolePoll()
    end)
    if C_AddOns.IsAddOnLoaded("MRT") and ExRT and ExRT.A and ExRT.A.RaidCheck and ExRT.A.RaidCheck.ReadyCheckWindow then
        local rc = GroupButton("rc", "", SIZE, nil, "MRT Raid Check", nil, function()
            pcall(ExRT.A.RaidCheck.ReadyCheckWindow, ExRT.A.RaidCheck, nil, nil, true)
        end)
        local icon = rc:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(MRT_ICON)
    end
    PaintGroupButtons()

    for i, color in ipairs(WORLD_COLORS) do
        local button = SecureButton(row2, SIZE, { type = "worldmarker", marker = i, action1 = "set", action2 = "clear" })
        local swatch = button:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("TOPLEFT", 3, -3)
        swatch:SetPoint("BOTTOMRIGHT", -3, 3)
        swatch:SetColorTexture(color[1] / 255, color[2] / 255, color[3] / 255)
        worldButtons[i] = button
    end
    Label(SecureButton(row2, CLEAR_WIDTH, { type = "worldmarker", action = "clear" }), "Clear all")

    Layout()
    Place()
end

local function BindingButton(name, attributes)
    local button = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyDown")
    button:SetAttribute("useOnKeyDown", true)
    for key, value in pairs(attributes) do
        button:SetAttribute(key, value)
    end
    return button
end

local function SyncBindings()
    if InCombatLockdown() or not (bindNext or active) then
        return
    end
    if not bindNext then
        bindNext = BindingButton("LittleThingsWorldMarkerNext", { ["lt-next"] = 1 })
        bindClear = BindingButton("LittleThingsWorldMarkerClear", { macrotext = "/cwm all" })
        local header = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
        header:WrapScript(bindNext, "OnClick", NEXT_BODY)
        SecureHandlerSetFrameRef(bindClear, "next", bindNext)
        header:WrapScript(bindClear, "OnClick", CLEAR_BODY)
    end
    local kind = active and "macro" or nil
    bindNext:SetAttribute("type", kind)
    bindClear:SetAttribute("type", kind)
end

local function Refresh()
    RequestVisibility()
    PaintGroupButtons()
end

local function StartCountdown(_, timeRemaining)
    countdownRunning = true
    countdownToken = countdownToken + 1
    local token = countdownToken
    if not issecretvalue(timeRemaining) and type(timeRemaining) == "number" then
        C_Timer.After(timeRemaining, function()
            if countdownToken == token then
                countdownRunning = false
            end
        end)
    end
end

local handlers = {
    GROUP_ROSTER_UPDATE = Refresh,
    PARTY_LEADER_CHANGED = Refresh,
    PLAYER_ENTERING_WORLD = Refresh,
    PLAYER_REGEN_ENABLED = function()
        Build()
        SyncBindings()
        Refresh()
    end,
    PLAYER_REGEN_DISABLED = function()
        C_Timer.After(0, PaintGroupButtons)
    end,
    RAID_TARGET_UPDATE = RefreshTarget,
    PLAYER_TARGET_CHANGED = RefreshTarget,
    READY_CHECK = function() UpdateReady(false) end,
    READY_CHECK_CONFIRM = function() UpdateReady(false) end,
    READY_CHECK_FINISHED = function() UpdateReady(true) end,
    START_PLAYER_COUNTDOWN = StartCountdown,
    CANCEL_PLAYER_COUNTDOWN = function()
        countdownToken = countdownToken + 1
        countdownRunning = false
    end,
}

function RaidMarkers.Enable()
    active = true
    InitializeDb()
    if not events then
        events = CreateFrame("Frame")
        for event in pairs(handlers) do
            events:RegisterEvent(event)
        end
        events:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
    end
    Build()
    SyncBindings()
    RequestVisibility()
end

function RaidMarkers.OnSwitch(enabled)
    if enabled then
        RaidMarkers.Enable()
        return
    end
    active = false
    StopTicker()
    SyncBindings()
    RequestVisibility()
end

local function Option(key, spec, apply)
    spec.default = DEFAULTS[key]
    spec.get = function() return ns.db.raidMarkerPanel[key] end
    spec.set = function(value)
        ns.db.raidMarkerPanel[key] = value
        if apply and panel then
            apply()
        end
    end
    return spec
end

function RaidMarkers.Pages(page)
    InitializeDb()

    local group = page:Group("Raid marker panel")
    group:Check(Option("locked", { label = "Lock position", combatLocked = true,
        tooltip = "Drag the panel to place it, then lock it so it cannot be dragged." }))
    group:Slider(Option("scale", { label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f", combatLocked = true,
        tooltip = "Size of the whole panel." }, Place))
    group:Check(Option("vertical", { label = "Vertical", combatLocked = true,
        tooltip = "Each row becomes a column: target markers on the left, world markers on the right." }, Layout))
    group:Slider(Option("pullLeft", { label = "Pull, left click (seconds)", min = 3, max = 60,
        tooltip = "Countdown length when the pull button is left-clicked." }))
    group:Slider(Option("pullRight", { label = "Pull, right click (seconds)", min = 3, max = 60,
        tooltip = "Countdown length when the pull button is right-clicked." }))
    group:Button({ label = "Reset position", combatLocked = true,
        tooltip = "Moves the panel back above the centre of the screen.",
        onClick = function()
            local db = ns.db.raidMarkerPanel
            db.point, db.relativePoint, db.x, db.y = DEFAULTS.point, DEFAULTS.relativePoint, DEFAULTS.x, DEFAULTS.y
            if panel then
                Place()
            end
        end })
end

RaidMarkers.key = "raidMarkers"
ns.RegisterModule("RaidMarkers", RaidMarkers)
