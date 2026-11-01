-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.MarkerRules
local Shared = ns.RaidMarkerPanel

local CELL_MIN, CELL_PAD = 64, Shared.CELL_PAD
local READY_COLORS = { waiting = { 1, 0.82, 0 }, notready = { 1, 0.2, 0.2 }, ready = { 0.2, 1, 0.2 } }
local WHITE, GREY = { 1, 1, 1 }, Shared.GREY
local GROUP_CELLS = { { "ready", "Ready" }, { "pull", "Pull" }, { "role", "Role" } }

Shared.groupButtons = {}

local readyText, readyTint, readyToken, lastStatuses
local countdownRunning, countdownSecret, countdownToken = false, false, 0

function Shared.HasRank(query)
    local value = query("player")
    return not issecretvalue(value) and value == true
end

local function BlockReason(action)
    return Rules.GroupActionBlock({
        inGroup = IsInGroup(),
        inRaid = IsInRaid(),
        leader = Shared.HasRank(UnitIsGroupLeader),
        assistant = Shared.HasRank(UnitIsGroupAssistant),
        combat = InCombatLockdown(),
        lockdown = C_ChatInfo.InChatMessagingLockdown(),
        lfg = HasLFGRestrictions(),
    }, action)
end

function Shared.PaintGroupButtons()
    for key, button in pairs(Shared.groupButtons) do
        local reason = BlockReason(button.action)
        local color = reason and GREY or (key == "ready" and readyTint) or WHITE
        button.reason = reason
        button.label:SetTextColor(color[1], color[2], color[3])
        if key == "ready" then
            button.label:SetText(readyText or "Ready")
        end
    end
end

function Shared.GroupCells(block, make)
    local cells = {}
    for _, cell in ipairs(GROUP_CELLS) do
        local button = make(block, CELL_MIN)
        button.label = Shared.Label(button, cell[2])
        cells[cell[1]] = button
    end
    cells.ready.label:SetText("Ready 20/20")
    block.cell = math.max(CELL_MIN, math.ceil(cells.ready.label:GetStringWidth()) + CELL_PAD)
    cells.ready.label:SetText("Ready")
    return cells
end

local function GroupButton(button, key, action, title, lines, onClick)
    button.action, button.title, button.lines = action, title, lines
    button:SetScript("OnEnter", Shared.ShowTip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self, mouse)
        if BlockReason(action) then
            return
        end
        onClick(self, mouse)
    end)
    Shared.groupButtons[key] = button
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

function Shared.UpdateReady(finished)
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
    Shared.PaintGroupButtons()
    if finished then
        local token = {}
        readyToken = token
        C_Timer.After(5, function()
            if readyToken == token then
                readyToken, readyText, readyTint = nil, nil, nil
                Shared.PaintGroupButtons()
            end
        end)
    end
end

function Shared.StartCountdown(_, timeRemaining)
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

function Shared.CancelCountdown()
    countdownToken = countdownToken + 1
    countdownRunning, countdownSecret = false, false
end

function Shared.RestrictionChanged()
    if countdownSecret and not C_ChatInfo.InChatMessagingLockdown() then
        countdownToken = countdownToken + 1
        countdownRunning, countdownSecret = false, false
    end
    Shared.PaintGroupButtons()
end

function Shared.BuildGroupButtons()
    local cells = Shared.GroupCells(Shared.block, function(row, width) return Shared.NewButton(row, nil, width) end)
    GroupButton(cells.ready, "ready", "ready", "Ready check", nil, function()
        C_PartyInfo.DoReadyCheck()
    end)
    local pull = GroupButton(cells.pull, "pull", "pull", "Pull countdown", function()
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
    GroupButton(cells.role, "role", "role", "Role check", nil, function()
        InitiateRolePoll()
    end)
    Shared.PaintGroupButtons()
end
