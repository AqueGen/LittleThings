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
    if not active then
        Panel.panel:Hide()
        return
    end
    Panel.Update()
    local ids = VisibleIds()
    Panel.Layout(ids)
    local shown = Rules.PanelShown({ party = IsInGroup(), raid = IsInRaid(), preview = previewing,
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
    local editBox = ChatFrameUtil.OpenChat(text)
    if editBox then
        editBox:SetChatType("PARTY")
        editBox:UpdateHeader()
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
        C_ChatInfo.SendChatMessage(text, "PARTY")
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
    CHALLENGE_MODE_RESET = PartyCalls.Refresh,
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

local selected = "lust"

local function Db()
    return ns.db.partyCallOptions
end

local function Selected()
    return Db().calls[selected]
end

local function Option(key, spec)
    spec.default = DEFAULTS[key]
    spec.get = function() return Db()[key] end
    spec.set = function(value)
        Db()[key] = value
        if Panel.panel then
            Panel.Place()
        end
        PartyCalls.Refresh()
    end
    return spec
end

local function Field(key, spec)
    spec.get = function() return Selected()[key] end
    spec.set = function(value)
        Selected()[key] = value
        PartyCalls.Refresh()
    end
    return spec
end

local function CallOptions()
    local options = {}
    for n, id in ipairs(Rules.Order()) do
        local call = Db().calls[id]
        local text = call.label
        if not Rules.IsBuiltin(id) then
            local slot = "Custom " .. (n - #Rules.BUILTIN)
            text = text ~= "" and slot .. ": " .. text or slot
        end
        options[n] = { text = text, value = id }
    end
    return options
end

local function MarkOptions()
    local options = { { text = "None", value = 0 } }
    for n = 1, 8 do
        options[n + 1] = { text = _G["RAID_TARGET_" .. n] or ("Mark " .. n), value = n }
    end
    return options
end

local function RoleSpec(role, label)
    return { label = label,
        get = function() return Selected().roles[role] end,
        set = function(value)
            Selected().roles[role] = value
            PartyCalls.Refresh()
        end }
end

function PartyCalls.Pages(page)
    InitializeDb()
    if page.frame then
        page.frame:HookScript("OnShow", function() PartyCalls.SetPreview(true) end)
        page.frame:HookScript("OnHide", function() PartyCalls.SetPreview(false) end)
    end

    local panel = page:Group("Panel")
    panel:Check(Option("locked", { label = "Lock position",
        tooltip = "Drag the panel to place it, then lock it so it cannot be dragged." }))
    panel:Slider(Option("scale", { label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f",
        tooltip = "Size of the whole panel." }))
    panel:Check(Option("vertical", { label = "Vertical", tooltip = "Buttons in one column." }))
    panel:Dropdown(Option("click", { label = "On click",
        options = { { text = "Send to party", value = "send" }, { text = "Put in chat, Enter sends", value = "chat" },
            { text = "Put in chat while in combat", value = "chatInCombat" } },
        tooltip = "Send posts the call at once. Put in chat opens the chat line on Party with the call typed in; press Enter to send it." }))
    panel:Button({ label = "Reset position", tooltip = "Moves the panel back above the centre of the screen.",
        onClick = function()
            local db = Db()
            db.point, db.relativePoint, db.x, db.y = DEFAULTS.point, DEFAULTS.relativePoint, DEFAULTS.x, DEFAULTS.y
            if Panel.panel then
                Panel.Place()
            end
        end })

    local calls = page:Group("Calls")
    calls:Dropdown({ label = "Call", options = CallOptions,
        tooltip = "Pick a call to edit. The first eight are built in; the custom slots are yours.",
        get = function() return selected end,
        set = function(value)
            local focus = GetCurrentKeyBoardFocus()
            if focus then
                focus:ClearFocus()
            end
            selected = value
        end })
    calls:Check(Field("enabled", { label = "Show this call" }))
    calls:Input(Field("label", { label = "Label", maxBytes = 16, tooltip = "Short text under the icon." }))
    calls:Input(Field("message", { label = "Message", maxBytes = 249, width = 320,
        tooltip = "What goes to party chat. The raid mark is put in front of it." }))
    calls:Input(Field("icon", { label = "Icon", tooltip = "A spell id (for example 2825) or a texture path.",
        icon = function() return Rules.Texture(Selected().icon, C_Spell.GetSpellTexture, GetFileIDFromPath) end }))
    calls:Dropdown(Field("mark", { label = "Raid mark", options = MarkOptions(),
        tooltip = "Shown at the start of the message in everyone's chat." }))
    calls:CheckGrid({ RoleSpec("TANK", "Tank"), RoleSpec("HEALER", "Healer"), RoleSpec("DAMAGER", "Damage") }, 3, 110)
    calls:Dropdown(Field("combat", { label = "When",
        options = { { text = "Always", value = "any" }, { text = "In combat", value = "in" },
            { text = "Out of combat", value = "out" } } }))
    calls:Dropdown(Field("content", { label = "Where",
        options = { { text = "Any group", value = "group" }, { text = "Any dungeon", value = "dungeon" },
            { text = "Mythic+", value = "mplus" } } }))
    calls:Button({ label = "Reset to default", tooltip = "Puts this built-in call back as it shipped.",
        visible = function() return Rules.IsBuiltin(selected) end,
        onClick = function()
            Rules.Reset(Db().calls, selected)
            PartyCalls.Refresh()
        end })
end

PartyCalls.key = "partyCalls"
ns.RegisterModule("PartyCalls", PartyCalls)
