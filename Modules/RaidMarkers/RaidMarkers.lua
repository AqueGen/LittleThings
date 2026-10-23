local addonName, ns = ...

local Rules = ns.MarkerRules

local RaidMarkers = {}

local SIZE, GAP, PAD = 26, 2, 4
local CLEAR_WIDTH = 60
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

local DEFAULTS = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 220, locked = false, scale = 1, vertical = false, pullLeft = 10, pullRight = 5,
    showSolo = false, partyLeaderOnly = false, raidWithoutRank = false, hideInCombat = false }

local active = false
local panel, row1, row2, block, events, ticker, mover, container
local dragging, previewing = false, false
local pending = {}
local targetButtons, worldButtons = {}, {}
local groupButtons = {}
local readyText, readyTint, readyToken, lastStatuses
local countdownRunning, countdownSecret, countdownToken = false, false, 0
local bindNext, bindClear

local NEXT_BODY = [[
local n = self:GetAttribute("lt-next") or 1
self:SetAttribute("macrotext", "/wm [@cursor]" .. n)
self:SetAttribute("lt-next", n % 8 + 1)
]]
local CLEAR_BODY = [[self:GetFrameRef("next"):SetAttribute("lt-next", 1)]]

local READY_COLORS = { waiting = { 1, 0.82, 0 }, notready = { 1, 0.2, 0.2 }, ready = { 0.2, 1, 0.2 } }
local WHITE, GREY, RED = { 1, 1, 1 }, { 0.5, 0.5, 0.5 }, { 1, 0.2, 0.2 }

local function InitializeDb()
    ns.db.raidMarkerPanel = ns.db.raidMarkerPanel or {}
    ns.ApplyDefaults(ns.db.raidMarkerPanel, DEFAULTS)
end

local function Ring(button, on)
    local color = on and GOLD or BORDER
    button:SetBackdropBorderColor(color[1], color[2], color[3], color[4])
end

local function NewButton(row, template, width)
    local button = CreateFrame("Button", nil, row, template and template .. ",BackdropTemplate" or "BackdropTemplate")
    button:SetSize(width, SIZE)
    button.width = width
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

local function SecureButton(row, width, title, attributes)
    local button = NewButton(row, "SecureActionButtonTemplate", width)
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

local function Cell(button, x, y, width)
    button:SetSize(width, SIZE)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", block, "TOPLEFT", x, y)
end

local function LayoutBlock()
    local cell = block.cell
    local width, height = 2 * cell + GAP, 2 * SIZE + GAP
    Cell(groupButtons.ready, 0, 0, cell)
    Cell(groupButtons.pull, cell + GAP, 0, cell)
    Cell(groupButtons.role, 0, -(SIZE + GAP), width)
    block:SetSize(width, height)
    return width, height
end

local function Layout()
    local vertical = ns.db.raidMarkerPanel.vertical
    local w1, h1 = LayoutRow(row1, vertical)
    local w2, h2 = LayoutRow(row2, vertical)
    local bw, bh = LayoutBlock()
    row1:ClearAllPoints()
    row1:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD)
    row2:ClearAllPoints()
    block:ClearAllPoints()
    if vertical then
        row2:SetPoint("TOPLEFT", row1, "TOPRIGHT", GAP, 0)
        block:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -GAP)
        panel:SetSize(math.max(w1 + GAP + w2, bw) + 2 * PAD, math.max(h1, h2) + GAP + bh + 2 * PAD)
    else
        row2:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -GAP)
        block:SetPoint("TOPLEFT", row1, "TOPRIGHT", GAP, 0)
        panel:SetSize(math.max(w1, w2) + GAP + bw + 2 * PAD, math.max(h1 + GAP + h2, bh) + 2 * PAD)
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
    local shown = active and Rules.Visible({
        inGroup = IsInGroup(),
        inRaid = IsInRaid(),
        leader = HasRank(UnitIsGroupLeader),
        assistant = HasRank(UnitIsGroupAssistant),
        preview = previewing,
        showSolo = ns.db.raidMarkerPanel.showSolo,
        partyLeaderOnly = ns.db.raidMarkerPanel.partyLeaderOnly,
        raidWithoutRank = ns.db.raidMarkerPanel.raidWithoutRank,
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
        StopTicker()
        ticker = C_Timer.NewTicker(1, RefreshWorld)
    end)
    panel:SetScript("OnHide", function()
        StopTicker()
        if dragging then
            StopDrag()
        end
    end)

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
    local clearTarget = SecureButton(row1, CLEAR_WIDTH, "Clear all target markers", { type = "raidtarget", action = "clear-all" })
    clearTarget.label = Label(clearTarget, "Clear all")

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
        local dot = button:CreateTexture(nil, "ARTWORK")
        dot:SetSize(DOT, DOT)
        dot:SetPoint("CENTER")
        dot:SetTexture("Interface\\Buttons\\WHITE8x8")
        dot:SetVertexColor(color[1] / 255, color[2] / 255, color[3] / 255, 1)
        dot:SetMask(CIRCLE_MASK)
        worldButtons[i] = button
    end
    local clearWorld = SecureButton(row2, CLEAR_WIDTH, "Clear all world markers", { type = "worldmarker", action = "clear" })
    local clearIcon = clearWorld:CreateTexture(nil, "ARTWORK")
    clearIcon:SetSize(DOT, DOT)
    clearIcon:SetPoint("CENTER")
    clearIcon:SetAtlas(CLEAR_ICON)

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
        bindClear = BindingButton("LittleThingsWorldMarkerClear", { action = "clear" })
        local header = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
        header:WrapScript(bindNext, "OnClick", NEXT_BODY)
        SecureHandlerSetFrameRef(bindClear, "next", bindNext)
        header:WrapScript(bindClear, "OnClick", CLEAR_BODY)
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
                ApplyOutOfCombat(Place)
            end
        end })
end

RaidMarkers.key = "raidMarkers"
ns.RegisterModule("RaidMarkers", RaidMarkers)
