local addonName, ns = ...

local Rules = ns.MarkerRules

local RaidMarkers = {}

local SIZE, GAP, PAD = 26, 2, 4
local CLEAR_WIDTH = 60
local MODE_WIDTH = CLEAR_WIDTH - GAP - SIZE
local CELL_MIN, CELL_PAD = 64, 8
local DOT = 16
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CLEAR_ICON = "common-icon-redx"
local FLAT = ns.Widgets.FLAT
local GOLD, BORDER = { 1, 0.82, 0, 1 }, { 0.4, 0.4, 0.4, 1 }
local TARGET_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local WORLD_COLORS = {
    { 4, 149, 255 }, { 15, 155, 12 }, { 168, 14, 192 }, { 167, 20, 13 },
    { 222, 218, 50 }, { 208, 84, 0 }, { 116, 155, 179 }, { 243, 241, 235 },
}
local WORLD_FOR_TARGET = { 5, 6, 3, 2, 7, 1, 4, 8 }
local TIP_ANCHORS = {
    below = { "TOPLEFT", "BOTTOMLEFT", 0, -4 },
    above = { "BOTTOMLEFT", "TOPLEFT", 0, 4 },
    right = { "TOPLEFT", "TOPRIGHT", 4, 0 },
    left = { "TOPRIGHT", "TOPLEFT", -4, 0 },
}
local ORDINALS ={ "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th" }

local DEFAULTS = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 220, locked = false, scale = 1, vertical = false, pullLeft = 10, pullRight = 5,
    showSolo = false, partyLeaderOnly = false, raidWithoutRank = false, hideInCombat = false }

local active = false
local panel, row1, row2, block, events, ticker, mover, container
local dragging, previewing = false, false
local pending = {}
local targetButtons, worldButtons = {}, {}
local groupButtons = {}
local clearTarget, clearWorld, modeButton
local readyText, readyTint, readyToken, lastStatuses
local countdownRunning, countdownSecret, countdownToken = false, false, 0
local bindNext, bindClear

local NEXT_BODY = [[
if not down then return false end
local n = self:GetAttribute("lt-count") or 0
if n == 0 then return false end
local i = self:GetAttribute("lt-index") or 1
if i > n then i = 1 end
self:SetAttribute("macrotext", "/wm [@cursor]" .. self:GetAttribute("lt-order" .. i))
self:SetAttribute("lt-index", i % n + 1)
]]
local CLEAR_BODY = [[self:GetFrameRef("next"):SetAttribute("lt-index", 1)]]
local MODE_BODY = [[
if not down then return false end
if button == "RightButton" or self:GetAttribute("lt-active") then
    self:ClearBindings()
    self:SetAttribute("lt-active", nil)
elseif self:GetAttribute("lt-allowed") and (self:GetFrameRef("next"):GetAttribute("lt-count") or 0) > 0 then
    self:SetBindingClick(true, "BUTTON1", "LittleThingsWorldMarkerNext", "LeftButton")
    self:SetBindingClick(true, "ESCAPE", self:GetName(), "RightButton")
    self:SetAttribute("lt-active", true)
end
return false
]]
local HIDE_BODY = [[self:ClearBindings() self:SetAttribute("lt-active", nil)]]

local READY_COLORS = { waiting = { 1, 0.82, 0 }, notready = { 1, 0.2, 0.2 }, ready = { 0.2, 1, 0.2 } }
local WHITE, GREY, RED, IDLE = { 1, 1, 1 }, { 0.5, 0.5, 0.5 }, { 1, 0.2, 0.2 }, { 0.8, 0.8, 0.8 }

local function InitializeDb()
    ns.db.raidMarkerPanel = ns.db.raidMarkerPanel or {}
    ns.ApplyDefaults(ns.db.raidMarkerPanel, DEFAULTS)
    ns.db.raidMarkerPanel.order = ns.db.raidMarkerPanel.order or { 1, 2, 3, 4, 5, 6, 7, 8 }
end

local function Ring(button, on)
    local color = on and GOLD or BORDER
    button:SetBackdropBorderColor(color[1], color[2], color[3], color[4])
end

local function NewButton(row, template, width, name)
    local button = CreateFrame("Button", name, row, template and template .. ",BackdropTemplate" or "BackdropTemplate")
    button:SetSize(width, SIZE)
    button.span = width
    button:SetBackdrop(FLAT)
    button:SetBackdropColor(0, 0, 0, 0.5)
    Ring(button, false)
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

local function MarkerTitle(name)
    return name .. ": left click set, right click clear"
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
        local reason = BlockReason(button.action)
        local color = reason and GREY or (key == "ready" and readyTint) or WHITE
        button.reason = reason
        button.label:SetTextColor(color[1], color[2], color[3])
        if key == "ready" then
            button.label:SetText(readyText or "Ready")
        end
    end
end

local function ShowTip(button)
    PaintGroupButtons()
    GameTooltip:SetOwner(panel, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local side = Rules.TipSide(panel:GetLeft() * scale, panel:GetBottom() * scale, panel:GetRight() * scale, panel:GetTop() * scale,
        UIParent:GetWidth(), UIParent:GetHeight(), ns.db.raidMarkerPanel.vertical)
    local anchor = TIP_ANCHORS[side]
    GameTooltip:SetPoint(anchor[1], panel, anchor[2], anchor[3], anchor[4])
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

local function SecureButton(row, width, title, attributes, name)
    local button = NewButton(row, "SecureActionButtonTemplate", width, name)
    button:RegisterForClicks("AnyUp", "AnyDown")
    for key, value in pairs(attributes) do
        button:SetAttribute(key, value)
    end
    button.title = title
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

local function GroupButton(key, text, action, title, lines, onClick)
    local button = AddGroupButton(block, text, CELL_MIN)
    button.action, button.title, button.lines = action, title, lines
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self, mouse)
        if BlockReason(action) then
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
    local statuses = ReadyStatuses()
    local state, ready, total = Rules.ReadyTally(statuses, finished)
    if not finished then
        lastStatuses = statuses
    else
        if total == 0 and lastStatuses then
            state, ready, total = Rules.ReadyTally(lastStatuses, true)
        end
        lastStatuses = nil
    end
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

local function Cell(button, parent, x, y, width)
    button:SetSize(width, SIZE)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
end

local function LayoutRow(row)
    local offset = 0
    for _, button in ipairs(row.buttons) do
        Cell(button, row, offset, 0, button.span)
        offset = offset + button.span + GAP
    end
    row:SetSize(offset - GAP, SIZE)
    return offset - GAP
end

local function LayoutHorizontal()
    local width = LayoutRow(row1)
    LayoutRow(row2)
    local cell = block.cell
    local bw, bh = 2 * cell + GAP, 2 * SIZE + GAP
    Cell(groupButtons.ready, block, 0, 0, cell)
    Cell(groupButtons.pull, block, cell + GAP, 0, cell)
    Cell(groupButtons.role, block, 0, -(SIZE + GAP), bw)
    block:SetSize(bw, bh)
    row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -GAP)
    block:SetPoint("TOPLEFT", row1, "TOPRIGHT", GAP, 0)
    panel:SetSize(width + GAP + bw + 2 * PAD, math.max(2 * SIZE + GAP, bh) + 2 * PAD)
end

local function LayoutVertical()
    local width = math.max(2 * SIZE + GAP, block.cell, clearTarget.cell + GAP + SIZE)
    local inset = math.floor((width - 2 * SIZE - GAP) / 2)
    local step = SIZE + GAP
    for t, button in ipairs(targetButtons) do
        Cell(button, row1, inset, -(t - 1) * step, SIZE)
        Cell(worldButtons[WORLD_FOR_TARGET[t]], row2, inset + step, -(t - 1) * step, SIZE)
    end
    Cell(clearTarget, row1, 0, -8 * step, width - step)
    Cell(clearWorld, row2, width - SIZE, -8 * step, SIZE)
    Cell(modeButton, row2, 0, -9 * step, width)
    local height = 10 * step - GAP
    row1:SetSize(width, height)
    row2:SetSize(width, height)
    Cell(groupButtons.ready, block, 0, 0, width)
    Cell(groupButtons.pull, block, 0, -step, width)
    Cell(groupButtons.role, block, 0, -2 * step, width)
    block:SetSize(width, 3 * step - GAP)
    row2:SetPoint("TOPLEFT", row1, "TOPLEFT", 0, 0)
    block:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -GAP)
    panel:SetSize(width + 2 * PAD, height + GAP + 3 * step - GAP + 2 * PAD)
end

local function Layout()
    row1:ClearAllPoints()
    row1:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    row2:ClearAllPoints()
    block:ClearAllPoints()
    if ns.db.raidMarkerPanel.vertical then
        LayoutVertical()
    else
        LayoutHorizontal()
    end
end

local function Place()
    local db = ns.db.raidMarkerPanel
    panel:ClearAllPoints()
    panel:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    panel:SetScale(db.scale)
end

local function ApplyOutOfCombat(apply)
    if InCombatLockdown() then
        pending[apply] = true
    else
        apply()
    end
end

local function PanelScale()
    return panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function StartDrag()
    local scale = PanelScale()
    mover:SetSize(panel:GetWidth() * scale, panel:GetHeight() * scale)
    mover:ClearAllPoints()
    mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", panel:GetLeft() * scale, panel:GetBottom() * scale)
    mover:Show()
    mover:StartMoving()
    dragging = true
end

local function StopDrag()
    dragging = false
    mover:StopMovingOrSizing()
    local scale = PanelScale()
    local db = ns.db.raidMarkerPanel
    db.point, db.relativePoint = "BOTTOMLEFT", "BOTTOMLEFT"
    db.x, db.y = math.floor(mover:GetLeft() / scale + 0.5), math.floor(mover:GetBottom() / scale + 0.5)
    mover:Hide()
    ApplyOutOfCombat(Place)
end

local function RefreshTarget()
    local index = GetRaidTargetIndex("target")
    local secret = issecretvalue(index)
    for i, button in ipairs(targetButtons) do
        Ring(button, not secret and index == i)
    end
end

local function PaintMode()
    local count = bindNext:GetAttribute("lt-count") or 0
    local on = modeButton:GetAttribute("lt-active")
    local index = bindNext:GetAttribute("lt-index") or 1
    if index > count then
        index = 1
    end
    local upcoming = on and bindNext:GetAttribute("lt-order" .. index)
    local allowed = modeButton:GetAttribute("lt-allowed")
    local color = (count == 0 or not allowed) and GREY or on and GOLD or IDLE
    modeButton.reason = not allowed and "Needs lead or assist" or count == 0 and "Placement order is empty" or nil
    modeButton.label:SetText(on and (index .. "/" .. count) or "Place")
    modeButton.label:SetTextColor(color[1], color[2], color[3])
    Ring(modeButton, on)
    for i, button in ipairs(worldButtons) do
        button.nextRing:SetShown(i == upcoming)
        button.nextGap:SetShown(i == upcoming)
    end
end

local function StopMode()
    if modeButton and modeButton:GetAttribute("lt-active") then
        ClearOverrideBindings(modeButton)
        modeButton:SetAttribute("lt-active", nil)
        PaintMode()
    end
end

local function ApplyOrder()
    local cycle = Rules.Cycle(ns.db.raidMarkerPanel.order)
    bindNext:SetAttribute("lt-count", #cycle)
    for i, marker in ipairs(cycle) do
        bindNext:SetAttribute("lt-order" .. i, marker)
    end
    bindNext:SetAttribute("lt-index", 1)
    if #cycle == 0 then
        StopMode()
    end
    PaintMode()
end

local function RefreshWorld()
    for i, button in ipairs(worldButtons) do
        local placed = IsRaidMarkerActive(i)
        if not issecretvalue(placed) then
            Ring(button, placed)
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
    local group = {
        inGroup = IsInGroup(),
        inRaid = IsInRaid(),
        leader = HasRank(UnitIsGroupLeader),
        assistant = HasRank(UnitIsGroupAssistant),
        preview = previewing,
        showSolo = ns.db.raidMarkerPanel.showSolo,
        partyLeaderOnly = ns.db.raidMarkerPanel.partyLeaderOnly,
        raidWithoutRank = ns.db.raidMarkerPanel.raidWithoutRank,
    }
    local allowed = Rules.CanMark(group)
    modeButton:SetAttribute("lt-allowed", allowed or nil)
    if not allowed then
        StopMode()
    end
    if active and Rules.Visible(group) then
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

local function Circle(button, layer, size, r, g, b)
    local texture = button:CreateTexture(nil, layer)
    texture:SetSize(size, size)
    texture:SetPoint("CENTER")
    texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    texture:SetVertexColor(r, g, b, 1)
    local mask = button:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return texture
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

local function ApplyCombatHide()
    if ns.db.raidMarkerPanel.hideInCombat then
        RegisterStateDriver(container, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(container, "visibility")
        container:Show()
    end
end

local function ApplyStrata()
    panel:SetFrameStrata(previewing and "FULLSCREEN_DIALOG" or "MEDIUM")
    mover:SetFrameStrata(previewing and "TOOLTIP" or "DIALOG")
end

local function Build()
    if panel or not active or InCombatLockdown() then
        return
    end

    container = CreateFrame("Frame", nil, UIParent)
    container:SetAllPoints(UIParent)
    ApplyCombatHide()

    panel = CreateFrame("Frame", "LittleThingsRaidMarkers", container, "BackdropTemplate")
    panel:Hide()
    panel:SetClampedToScreen(true)
    panel:SetDontSavePosition(true)
    panel:SetBackdrop(FLAT)
    panel:SetBackdropColor(0, 0, 0, 0.6)
    panel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    mover = CreateFrame("Frame", "LittleThingsRaidMarkersMover", UIParent)
    mover:Hide()
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    ApplyStrata()
    local outline = mover:CreateTexture(nil, "OVERLAY")
    outline:SetAllPoints()
    outline:SetColorTexture(1, 0.82, 0, 0.3)

    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function()
        if not ns.db.raidMarkerPanel.locked and not InCombatLockdown() then
            StartDrag()
        end
    end)
    panel:SetScript("OnDragStop", function()
        if dragging then
            StopDrag()
        end
    end)
    panel:SetScript("OnShow", function()
        RefreshTarget()
        RefreshWorld()
        PaintMode()
        StopTicker()
        ticker = C_Timer.NewTicker(1, RefreshWorld)
    end)
    panel:SetScript("OnHide", function()
        StopTicker()
        if dragging then
            StopDrag()
        end
    end)

    bindNext = BindingButton("LittleThingsWorldMarkerNext", {})
    bindClear = BindingButton("LittleThingsWorldMarkerClear", { action = "clear" })
    local header = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
    header:WrapScript(bindNext, "OnClick", NEXT_BODY)
    SecureHandlerSetFrameRef(bindClear, "next", bindNext)
    header:WrapScript(bindClear, "OnClick", CLEAR_BODY)

    row1, row2, block = NewRow(), NewRow(), NewRow()

    for i = 1, 8 do
        local button = SecureButton(row1, SIZE, MarkerTitle(_G["RAID_TARGET_" .. i] or ("Target marker " .. i)),
            { type = "raidtarget", marker = i, action1 = "set", action2 = "clear", unit = "target" })
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexture(TARGET_ICONS)
        SetRaidTargetIconTexture(icon, i)
        targetButtons[i] = button
    end
    clearTarget = SecureButton(row1, CLEAR_WIDTH, "Clear all target markers", { type = "raidtarget", action = "clear-all" })
    clearTarget.label = Label(clearTarget, "Clear all")
    clearTarget.cell = math.ceil(clearTarget.label:GetStringWidth()) + CELL_PAD

    local ready = GroupButton("ready", "Ready", "ready", "Ready check", nil, function()
        C_PartyInfo.DoReadyCheck()
    end)
    ready.label:SetText("Ready 20/20")
    block.cell = math.max(CELL_MIN, math.ceil(ready.label:GetStringWidth()) + CELL_PAD)
    local pull = GroupButton("pull", "Pull", "pull", "Pull countdown", function()
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
    GroupButton("role", "Role", "role", "Role check", nil, function()
        InitiateRolePoll()
    end)
    PaintGroupButtons()

    for i, color in ipairs(WORLD_COLORS) do
        local button = SecureButton(row2, SIZE, MarkerTitle(_G["WORLD_MARKER" .. i] or ("World marker " .. i)),
            { type = "worldmarker", marker = i, action1 = "set", action2 = "clear" })
        Circle(button, "ARTWORK", DOT, color[1] / 255, color[2] / 255, color[3] / 255)
        button.nextRing = Circle(button, "BACKGROUND", DOT + 6, 1, 1, 1)
        button.nextGap = Circle(button, "BORDER", DOT + 2, 0, 0, 0)
        worldButtons[i] = button
    end
    modeButton = SecureButton(row2, MODE_WIDTH, "Placement mode: left click on the ground places the next world marker. Right click or Esc to stop.",
        {}, "LittleThingsWorldMarkerMode")
    modeButton:RegisterForClicks("AnyDown")
    modeButton.label = Label(modeButton, "Place")
    modeButton.lines = function()
        return { "Left-clicks on the world do not target or turn the camera while it is on." }
    end
    SecureHandlerSetFrameRef(modeButton, "next", bindNext)
    header:WrapScript(modeButton, "OnClick", MODE_BODY)
    header:WrapScript(modeButton, "OnHide", HIDE_BODY)

    clearWorld = SecureButton(row2, SIZE, "Clear all world markers", { type = "worldmarker", action = "clear" })
    SecureHandlerSetFrameRef(clearWorld, "next", bindNext)
    header:WrapScript(clearWorld, "OnClick", CLEAR_BODY)
    local clearIcon = clearWorld:CreateTexture(nil, "ARTWORK")
    clearIcon:SetSize(DOT, DOT)
    clearIcon:SetPoint("CENTER")
    clearIcon:SetAtlas(CLEAR_ICON)

    modeButton:SetScript("OnAttributeChanged", PaintMode)
    bindNext:SetScript("OnAttributeChanged", PaintMode)
    ApplyOrder()
    Layout()
    Place()
end

local function SyncBindings()
    if not bindNext or InCombatLockdown() then
        return
    end
    bindNext:SetAttribute("type", active and "macro" or nil)
    bindClear:SetAttribute("type", active and "worldmarker" or nil)
end

local function Refresh()
    RequestVisibility()
    PaintGroupButtons()
end

local function StartCountdown(_, timeRemaining)
    countdownRunning = true
    countdownToken = countdownToken + 1
    local token = countdownToken
    countdownSecret = issecretvalue(timeRemaining)
    if not countdownSecret and type(timeRemaining) == "number" then
        C_Timer.After(timeRemaining, function()
            if countdownToken == token then
                countdownRunning = false
            end
        end)
    end
end

local function RestrictionChanged()
    if countdownSecret and not C_ChatInfo.InChatMessagingLockdown() then
        countdownToken = countdownToken + 1
        countdownRunning, countdownSecret = false, false
    end
    PaintGroupButtons()
end

local handlers = {
    GROUP_ROSTER_UPDATE = Refresh,
    PARTY_LEADER_CHANGED = Refresh,
    PLAYER_ENTERING_WORLD = Refresh,
    PLAYER_REGEN_ENABLED = function()
        if panel and not InCombatLockdown() then
            if pending[Layout] then
                Layout()
            end
            if pending[Place] then
                Place()
            end
            if pending[ApplyStrata] then
                ApplyStrata()
            end
            if pending[ApplyCombatHide] then
                ApplyCombatHide()
            end
            if pending[ApplyOrder] then
                ApplyOrder()
            end
            pending = {}
        end
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
        countdownRunning, countdownSecret = false, false
    end,
    ADDON_RESTRICTION_STATE_CHANGED = function()
        C_Timer.After(0, RestrictionChanged)
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
            ApplyOutOfCombat(apply)
        end
    end
    return spec
end

local function Preview(shown)
    previewing = shown
    if panel then
        ApplyOutOfCombat(ApplyStrata)
    end
    RequestVisibility()
end

function RaidMarkers.Pages(page)
    InitializeDb()
    if page.frame then
        page.frame:HookScript("OnShow", function() Preview(true) end)
        page.frame:HookScript("OnHide", function() Preview(false) end)
    end

    local visibility = page:Group("Visibility")
    visibility:Check(Option("showSolo", { label = "Show when solo",
        tooltip = "Shows the panel outside a group too. Markers and group buttons do nothing there." }, RequestVisibility))
    visibility:Check(Option("partyLeaderOnly", { label = "In a party, only as leader",
        tooltip = "In a party the panel shows only while you lead the group." }, RequestVisibility))
    visibility:Check(Option("raidWithoutRank", { label = "In a raid, also without lead or assist",
        tooltip = "In a raid the panel shows to everyone; markers and group buttons work only with lead or assist." }, RequestVisibility))
    visibility:Check(Option("hideInCombat", { label = "Hide in combat", combatLocked = true,
        tooltip = "Hides the panel while you are in combat. The game hides it, so this is safe in combat." }, ApplyCombatHide))

    local group = page:Group("Raid marker panel")
    group:Check(Option("locked", { label = "Lock position", combatLocked = true,
        tooltip = "Drag the panel to place it, then lock it so it cannot be dragged." }))
    group:Slider(Option("scale", { label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f", combatLocked = true,
        tooltip = "Size of the whole panel." }, Place))
    group:Check(Option("vertical", { label = "Vertical", combatLocked = true,
        tooltip = "One column: each target marker next to the world marker of the same symbol, the other buttons below." }, Layout))
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
                ApplyOutOfCombat(Place)
            end
        end })

    local options = { { text = "None", value = 0 } }
    for n = 1, 8 do
        options[n + 1] = { text = _G["WORLD_MARKER" .. n] or ("World marker " .. n), value = n }
    end
    local placement = page:Group("Placement order")
    for i, label in ipairs(ORDINALS) do
        placement:Dropdown({ label = label, options = options, default = i, combatLocked = true,
            tooltip = "World marker placed at this step by the placement mode and the next world marker key. None skips the step.",
            get = function() return ns.db.raidMarkerPanel.order[i] end,
            set = function(value)
                ns.db.raidMarkerPanel.order[i] = value
                if panel then
                    ApplyOutOfCombat(ApplyOrder)
                end
            end })
    end
end

RaidMarkers.key = "raidMarkers"
ns.RegisterModule("RaidMarkers", RaidMarkers)
