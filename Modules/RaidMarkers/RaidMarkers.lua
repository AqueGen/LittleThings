-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.MarkerRules
local Shared = ns.RaidMarkerPanel

local RaidMarkers = {}

local ORDINALS ={ "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th" }

local DEFAULTS = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 220, locked = false, scale = 1, vertical = false, pullLeft = 10, pullRight = 5,
    showSolo = false, partyLeaderOnly = false, raidWithoutRank = false, hideInCombat = false,
    healerMana = false, manaText = "percent", groupDown = false }

local events

local function InitializeDb()
    ns.db.raidMarkerPanel = ns.db.raidMarkerPanel or {}
    ns.ApplyDefaults(ns.db.raidMarkerPanel, DEFAULTS)
    ns.db.raidMarkerPanel.order = ns.db.raidMarkerPanel.order or { 1, 2, 3, 4, 5, 6, 7, 8 }
end

local function RequestVisibility()
    if not Shared.panel or InCombatLockdown() then
        return
    end
    local group = {
        inGroup = IsInGroup(),
        inRaid = IsInRaid(),
        leader = Shared.HasRank(UnitIsGroupLeader),
        assistant = Shared.HasRank(UnitIsGroupAssistant),
        preview = Shared.previewing,
        showSolo = ns.db.raidMarkerPanel.showSolo,
        partyLeaderOnly = ns.db.raidMarkerPanel.partyLeaderOnly,
        raidWithoutRank = ns.db.raidMarkerPanel.raidWithoutRank,
    }
    local allowed = Rules.CanMark(group)
    Shared.modeButton:SetAttribute("lt-allowed", allowed or nil)
    if not allowed then
        Shared.StopMode()
    end
    if Shared.active and Rules.Visible(group) then
        Shared.panel:Show()
    else
        Shared.panel:Hide()
    end
end

local function Build()
    if Shared.panel or not Shared.active or InCombatLockdown() then
        return
    end
    Shared.BuildFrame()
    local header = Shared.BuildBindings()
    Shared.row1, Shared.row2, Shared.block = Shared.NewRow(Shared.panel), Shared.NewRow(Shared.panel), Shared.NewRow(Shared.panel)
    Shared.BuildTargetButtons()
    Shared.BuildGroupButtons()
    Shared.BuildHelpers()
    Shared.BuildWorldButtons(header)
    Shared.ApplyOrder()
    Shared.Layout()
    Shared.Place()
end

local function RolesChanged()
    if Shared.panel then
        Shared.RefreshHelpers()
    end
end

local function Refresh()
    RequestVisibility()
    Shared.PaintGroupButtons()
    RolesChanged()
end

local handlers = {
    GROUP_ROSTER_UPDATE = Refresh,
    PARTY_LEADER_CHANGED = Refresh,
    PLAYER_ENTERING_WORLD = Refresh,
    PLAYER_ROLES_ASSIGNED = RolesChanged,
    PLAYER_REGEN_ENABLED = function()
        if Shared.panel and not InCombatLockdown() then
            local pending = Shared.pending
            if pending[Shared.Layout] then
                Shared.Layout()
            end
            if pending[Shared.Place] then
                Shared.Place()
            end
            if pending[Shared.ApplyStrata] then
                Shared.ApplyStrata()
            end
            if pending[Shared.ApplyCombatHide] then
                Shared.ApplyCombatHide()
            end
            if pending[Shared.ApplyOrder] then
                Shared.ApplyOrder()
            end
            Shared.pending = {}
        end
        Build()
        Shared.SyncBindings()
        Refresh()
    end,
    PLAYER_REGEN_DISABLED = function()
        C_Timer.After(0, Shared.PaintGroupButtons)
    end,
    RAID_TARGET_UPDATE = Shared.RefreshTarget,
    PLAYER_TARGET_CHANGED = Shared.RefreshTarget,
    READY_CHECK = function() Shared.UpdateReady(false) end,
    READY_CHECK_CONFIRM = function() Shared.UpdateReady(false) end,
    READY_CHECK_FINISHED = function() Shared.UpdateReady(true) end,
    START_PLAYER_COUNTDOWN = Shared.StartCountdown,
    CANCEL_PLAYER_COUNTDOWN = Shared.CancelCountdown,
    ADDON_RESTRICTION_STATE_CHANGED = function()
        C_Timer.After(0, Shared.RestrictionChanged)
    end,
}

function RaidMarkers.Enable()
    Shared.active = true
    InitializeDb()
    if not events then
        events = CreateFrame("Frame")
        for event in pairs(handlers) do
            events:RegisterEvent(event)
        end
        events:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
    end
    Build()
    Shared.SyncBindings()
    RequestVisibility()
end

function RaidMarkers.OnSwitch(enabled)
    if enabled then
        RaidMarkers.Enable()
        return
    end
    Shared.active = false
    Shared.StopTicker()
    Shared.SyncBindings()
    RequestVisibility()
end

local function Option(key, spec, apply)
    spec.default = DEFAULTS[key]
    spec.get = function() return ns.db.raidMarkerPanel[key] end
    spec.set = function(value)
        ns.db.raidMarkerPanel[key] = value
        if apply and Shared.panel then
            Shared.ApplyOutOfCombat(apply)
        end
        ns.RaidMarkerPreview.Refresh()
    end
    return spec
end

local function Preview(shown)
    Shared.previewing = shown
    if Shared.panel then
        Shared.ApplyOutOfCombat(Shared.ApplyStrata)
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
        tooltip = "Hides the panel while you are in combat. The game hides it, so this is safe in combat." }, Shared.ApplyCombatHide))

    local group = page:Group("Raid marker panel")
    group:Check(Option("locked", { label = "Lock position", combatLocked = true,
        tooltip = "Drag the panel to place it, then lock it so it cannot be dragged." }))
    group:Slider(Option("scale", { label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f", combatLocked = true,
        tooltip = "Size of the whole panel." }, Shared.Place))
    group:Check(Option("vertical", { label = "Vertical", combatLocked = true,
        tooltip = "One column: each target marker next to the world marker of the same symbol, the other buttons below." }, Shared.Layout))
    group:Slider(Option("pullLeft", { label = "Pull, left click (seconds)", min = 3, max = 60,
        tooltip = "Countdown length when the pull button is left-clicked." }))
    group:Slider(Option("pullRight", { label = "Pull, right click (seconds)", min = 3, max = 60,
        tooltip = "Countdown length when the pull button is right-clicked." }))
    group:Button({ label = "Reset position", combatLocked = true,
        tooltip = "Moves the panel back above the centre of the screen.",
        onClick = function()
            local db = ns.db.raidMarkerPanel
            db.point, db.relativePoint, db.x, db.y = DEFAULTS.point, DEFAULTS.relativePoint, DEFAULTS.x, DEFAULTS.y
            if Shared.panel then
                Shared.ApplyOutOfCombat(Shared.Place)
            end
        end })

    local helpers = page:Group("Tank helpers")
    helpers:Check(Option("healerMana", { label = "Healer mana", combatLocked = true,
        tooltip = "A bar under the group buttons with your party healer's mana. Party only." }, Shared.Layout))
    helpers:Dropdown(Option("manaText", { label = "Mana text", combatLocked = true,
        options = { { text = "None", value = "none" }, { text = "Percent", value = "percent" },
            { text = "Value", value = "value" }, { text = "Both", value = "both" } },
        enabled = function() return ns.db.raidMarkerPanel.healerMana end,
        tooltip = "What the healer mana bar shows on top of it. None keeps the bar thin." }, Shared.Layout))
    helpers:Check(Option("groupDown", { label = "Dead or offline count", combatLocked = true,
        tooltip = "A red count next to the group buttons when party members are dead or offline. Party only." }, Shared.Layout))

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
                if Shared.panel then
                    Shared.ApplyOutOfCombat(Shared.ApplyOrder)
                end
                ns.RaidMarkerPreview.Refresh()
            end })
    end
end

RaidMarkers.key = "raidMarkers"
RaidMarkers.Preview = ns.RaidMarkerPreview
ns.RegisterModule("RaidMarkers", RaidMarkers)
