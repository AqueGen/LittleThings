-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.CallRules
local Panel = ns.PartyCallPanel

local PartyCalls = {}

local DEFAULTS = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 160, locked = false, scale = 1,
    vertical = false, click = "send" }

local active, previewing, inCombat = false, false, false
local lastAny, lastById = nil, {}
local events, ticker

local function InitializeDb()
    ns.db.partyCallOptions = ns.db.partyCallOptions or {}
    local db = ns.db.partyCallOptions
    ns.ApplyDefaults(db, DEFAULTS)
    db.calls = Rules.Fill(db.calls or {})
end

local function Remaining(id)
    return Rules.Remaining(GetTime(), lastAny, lastById, id)
end

local function CurrentState()
    local spec = GetSpecialization()
    local _, instanceType = IsInInstance()
    return {
        role = Rules.Role(spec and GetSpecializationRole(spec)),
        combat = inCombat,
        dungeon = instanceType == "party",
        mplus = C_ChallengeMode.IsChallengeModeActive() and true or false,
    }
end

local function VisibleIds()
    local calls, state, ids = ns.db.partyCallOptions.calls, CurrentState(), {}
    for _, id in ipairs(Rules.Order()) do
        local call = calls[id]
        if previewing and call.enabled and Rules.Text(call) or not previewing and Rules.Visible(call, state) then
            ids[#ids + 1] = id
        end
    end
    return ids
end

function PartyCalls.Refresh()
    if not Panel.panel then
        return
    end
    Panel.Update()
    local ids = VisibleIds()
    Panel.Layout(ids)
    local shown = active and Rules.PanelShown({ party = IsInGroup(), raid = IsInRaid(), preview = previewing,
        anyVisible = #ids > 0 })
    Panel.panel:SetShown(shown and true or false)
    Panel.panel:SetFrameStrata(previewing and "FULLSCREEN_DIALOG" or "MEDIUM")
end

local function Repaint()
    if not Panel.Paint(Remaining) and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function OpenInChat(text)
    ChatFrameUtil.OpenChat("")
    local editBox = ChatFrameUtil.GetActiveWindow()
    if editBox then
        editBox:SetChatType("PARTY")
        editBox:UpdateHeader()
        editBox:SetText(text)
    end
end

function PartyCalls.Click(id)
    if Remaining(id) > 0 or not IsInGroup() or IsInRaid() then
        return
    end
    local text = Rules.Text(ns.db.partyCallOptions.calls[id])
    if not text then
        return
    end
    if Rules.ClickPath(ns.db.partyCallOptions.click, InCombatLockdown()) == "chat" then
        OpenInChat(text)
    else
        SendChatMessage(text, "PARTY")
    end
    local now = GetTime()
    lastAny, lastById[id] = now, now
    Panel.Flash(id)
    Repaint()
    if not ticker then
        ticker = C_Timer.NewTicker(0.25, Repaint)
    end
end

local handlers = {
    GROUP_ROSTER_UPDATE = PartyCalls.Refresh,
    PLAYER_ENTERING_WORLD = PartyCalls.Refresh,
    ZONE_CHANGED_NEW_AREA = PartyCalls.Refresh,
    PLAYER_SPECIALIZATION_CHANGED = PartyCalls.Refresh,
    CHALLENGE_MODE_START = PartyCalls.Refresh,
    CHALLENGE_MODE_COMPLETED = PartyCalls.Refresh,
    PLAYER_REGEN_DISABLED = function()
        inCombat = true
        PartyCalls.Refresh()
    end,
    PLAYER_REGEN_ENABLED = function()
        inCombat = false
        PartyCalls.Refresh()
    end,
}

function PartyCalls.Enable()
    active = true
    InitializeDb()
    inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    if not Panel.panel then
        Panel.Build(PartyCalls.Click)
    end
    if not events then
        events = CreateFrame("Frame")
        for event in pairs(handlers) do
            if event == "PLAYER_SPECIALIZATION_CHANGED" then
                events:RegisterUnitEvent(event, "player")
            else
                events:RegisterEvent(event)
            end
        end
        events:SetScript("OnEvent", function(_, event) handlers[event]() end)
    end
    PartyCalls.Refresh()
end

function PartyCalls.OnSwitch(enabled)
    if enabled then
        PartyCalls.Enable()
        return
    end
    active = false
    PartyCalls.Refresh()
end

function PartyCalls.SetPreview(shown)
    previewing = shown
    PartyCalls.Refresh()
end

function PartyCalls.Pages(page)
    InitializeDb()
    page:Group("Party calls"):Note("Settings come in the next step.")
end

PartyCalls.key = "partyCalls"
ns.RegisterModule("PartyCalls", PartyCalls)
