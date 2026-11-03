-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.CallRules
local Panel = ns.PartyCallPanel

local PartyCalls = {}

local DEFAULTS = { scale = 1, click = "send", bgAlpha = 0.6, border = true, pad = 4, iconSize = 32,
    gap = 4, labels = true, labelSize = "small", grow = "right", perRow = 8, wrap = "down", merge = false, fade = false, fadeAlpha = 0, collapsed = false,
    showSolo = false }

local active, previewing, moving, inCombat = false, false, false, false
local previewWindow
local lastAny, lastById = nil, {}
local events, ticker

local function InitializeDb()
    ns.db.partyCallOptions = ns.db.partyCallOptions or {}
    local db = ns.db.partyCallOptions
    ns.ApplyDefaults(db, DEFAULTS)
    Rules.Fill(db)
end

local function Remaining(id)
    return Rules.Remaining(GetTime(), lastAny, lastById, id)
end

local function Grey(id)
    if not IsInGroup() and not previewing and not moving then return 1 end
    return Remaining(id)
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
    for _, id in ipairs(ns.db.partyCallOptions.order) do
        local call = calls[id]
        local sample = previewing or moving
        if sample and call.enabled and Rules.Text(call) or not sample and Rules.Visible(call, state) then
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
    if previewing and previewWindow then
        Panel.MoveClearOf(previewWindow)
    end
    local shown = Rules.PanelShown({ party = IsInGroup(), raid = IsInRaid(), preview = previewing or moving,
        showSolo = ns.db.partyCallOptions.showSolo, anyVisible = #ids > 0 })
    Panel.Paint(Grey)
    Panel.panel:SetShown(shown and true or false)
    Panel.panel:SetFrameStrata(previewing and "FULLSCREEN_DIALOG" or "MEDIUM")
    local lib = LibStub("LibVelvet-1.0")
    for id, p in pairs(lib.dock.panels) do
        if p.spec.root then lib.Dock.RefreshMerge(id) end
    end
end

local function ApplyDock()
    PartyCalls.Refresh()
    if Panel.panel then
        ns.PanelDock.Fade("partyCalls", Panel.panel, ns.db.partyCallOptions)
    end
end

local function Repaint()
    if (not Panel.Paint(Grey) or not IsInGroup()) and ticker then
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
        Panel.Build(PartyCalls.Click, PartyCalls.Refresh)
        ns.PanelMove.Register("partyCalls", { name = "Party calls", frame = function() return Panel.panel end,
            strip = ns.PanelDock.STRIP, owner = Panel.MergedOwner,
            setMoving = function(on)
                moving = on
                PartyCalls.Refresh()
            end,
            reset = Panel.ResetPosition, stopDrag = Panel.StopDragging })
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
    ns.PanelDock.Fade("partyCalls", Panel.panel, ns.db.partyCallOptions)
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

local function CallItems()
    local items = {}
    for n, id in ipairs(Db().order) do
        local call = Db().calls[id]
        items[n] = { id = id, text = call.label ~= "" and call.label or "(no label)",
            icon = Rules.Texture(call.icon, C_Spell.GetSpellTexture, GetFileIDFromPath),
            desaturate = call.desaturate, dim = not call.enabled or not Rules.Text(call) }
    end
    return items
end

local function MarkOptions()
    local options = { { text = "None", value = 0 } }
    for n = 1, 8 do
        options[n + 1] = { text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. n .. ":16|t "
            .. (_G["RAID_TARGET_" .. n] or ("Mark " .. n)), value = n }
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

local HORIZONTAL = { right = true, left = true }

local function WrapOptions()
    if HORIZONTAL[Db().grow] then
        return { { text = "Down", value = "down" }, { text = "Up", value = "up" } }
    end
    return { { text = "Right", value = "right" }, { text = "Left", value = "left" } }
end

local function GrowSet(value)
    local db = Db()
    db.grow = value
    if HORIZONTAL[value] == HORIZONTAL[db.wrap] then
        db.wrap = HORIZONTAL[value] and "down" or "right"
    end
    PartyCalls.Refresh()
end

local function Look(page)
    local look = page:Group("Appearance")
    look:Slider(Option("bgAlpha", { label = "Background opacity", min = 0, max = 1, step = 0.05, format = "%.2f",
        hint = "Opacity of the panel background", tooltip = "Opacity of the panel background. 0 hides it." }))
    look:Check(Option("border", { label = "Border", hint = "A thin line around the panel", tooltip = "A thin line around the panel." }))
    look:Slider(Option("pad", { label = "Edge margin", min = 0, max = 12, hint = "Space between the edge and the buttons", tooltip = "Space between the edge and the buttons." }))
    look:Slider(Option("iconSize", { label = "Icon size", min = 20, max = 56, hint = "Size of each icon", tooltip = "Size of each icon." }))
    look:Slider(Option("gap", { label = "Button gap", min = 0, max = 20, hint = "Space between buttons", tooltip = "Space between buttons." }))
    look:Check(Option("labels", { label = "Button labels", hint = "Short text under each icon", tooltip = "The short text under each icon." }))
    look:Dropdown(Option("labelSize", { label = "Label size", hint = "Size of the text under each icon",
        options = { { text = "Small", value = "small" }, { text = "Normal", value = "normal" }, { text = "Large", value = "large" } },
        enabled = function() return Db().labels end }))
    look:Dropdown({ label = "Button direction", default = DEFAULTS.grow,
        options = { { text = "Right", value = "right" }, { text = "Left", value = "left" },
            { text = "Down", value = "down" }, { text = "Up", value = "up" } },
        hint = "Direction a row of buttons grows", tooltip = "Where a row of buttons goes from the panel's corner. That corner stays in place when buttons show or hide.",
        get = function() return Db().grow end, set = GrowSet })
    look:Slider(Option("perRow", { label = "Buttons per row", min = 1, max = 20,
        hint = "Buttons in a row before a new one starts", tooltip = "After this many buttons the next one starts a new row." }))
    look:Dropdown(Option("wrap", { label = "Next row goes", options = WrapOptions,
        hint = "Where the next row starts", tooltip = "Where the next row starts." }))
end

function PartyCalls.Pages(page)
    InitializeDb()
    if page.frame then
        previewWindow = page.frame
        while previewWindow:GetParent() and previewWindow:GetParent() ~= UIParent do
            previewWindow = previewWindow:GetParent()
        end
        page.frame:HookScript("OnShow", function() PartyCalls.SetPreview(true) end)
        page.frame:HookScript("OnHide", function() PartyCalls.SetPreview(false) end)
    end

    local panel = page:Group("Panel behaviour")
    panel:Check(Option("showSolo", { label = "Show when solo",
        hint = "Show the panel outside a group too", tooltip = "Shows the panel outside a group too. The buttons do nothing there." }))
    panel:Slider(Option("scale", { label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f",
        hint = "Size of the whole panel", tooltip = "Size of the whole panel.",
        enabled = function() return not Panel.Merged() end }))
    panel:Dropdown(Option("click", { label = "Click action",
        options = { { text = "Send to party", value = "send" }, { text = "Put in chat, Enter sends", value = "chat" },
            { text = "Put in chat while in combat", value = "chatInCombat" } },
        hint = "Send at once, or put the call in the chat line", tooltip = "Send posts the call at once. Put in chat opens the chat line on Party with the call typed in; press Enter to send it." }))
    ns.PanelDock.FadeOptions(panel, Db(), ApplyDock)
    panel:Button({ label = "Reset position", hint = "Puts the panel back at its default place", tooltip = "Moves the panel back above the centre of the screen.",
        onClick = function()
            if Panel.panel then
                Panel.ResetPosition()
            end
        end })

    Look(page)
    ns.PanelDock.Options(page, Db(), ApplyDock, "partyCalls")

    local calls = page:Group("Calls")
    calls:List({ items = CallItems,
        selected = function() return selected end,
        select = function(id) selected = id end,
        move = function(id, delta)
            Rules.Move(Db(), id, delta)
            PartyCalls.Refresh()
        end })
    calls:Button({ label = "Add call", hint = "Adds a call of your own to the list", tooltip = "A new call of your own at the end of the list.",
        onClick = function()
            selected = Rules.AddCustom(Db())
            PartyCalls.Refresh()
        end })
    calls:Check(Field("enabled", { label = "Show this call", hint = "Hide a call without deleting it" }))
    calls:Input(Field("label", { label = "Call label", maxBytes = 16, hint = "Short text under the icon", tooltip = "Short text under the icon." }))
    calls:Input(Field("message", { label = "Message", maxBytes = 249, width = 320,
        hint = "What goes to party chat", tooltip = "What goes to party chat. The raid mark is put in front of it." }))
    calls:Input(Field("icon", { label = "Icon", hint = "A spell id or a texture path", tooltip = "A spell id (for example 2825) or a texture path.",
        icon = function() return Rules.Texture(Selected().icon, C_Spell.GetSpellTexture, GetFileIDFromPath) end }))
    calls:Dropdown(Field("mark", { label = "Raid mark", options = MarkOptions(),
        hint = "Mark shown at the start of the message", tooltip = "Shown at the start of the message in everyone's chat." }))
    calls:CheckGrid({ RoleSpec("TANK", "Tank"), RoleSpec("HEALER", "Healer"), RoleSpec("DAMAGER", "Damage dealer") }, 3, 110)
    calls:Dropdown(Field("combat", { label = "Show during", hint = "Show the call always, or only in or out of combat",
        options = { { text = "Always", value = "any" }, { text = "In combat", value = "in" },
            { text = "Out of combat", value = "out" } } }))
    calls:Dropdown(Field("content", { label = "Show in", hint = "Limit the call to dungeons or Mythic+",
        options = { { text = "Any group", value = "group" }, { text = "Any dungeon", value = "dungeon" },
            { text = "Mythic+", value = "mplus" } } }))
    calls:Button({ label = "Reset to default", hint = "Restores this call to its shipped state", tooltip = "Puts this built-in call back as it shipped.",
        visible = function() return Rules.IsBuiltin(selected) end,
        onClick = function()
            Rules.Reset(Db().calls, selected)
            PartyCalls.Refresh()
        end })
    calls:Button({ label = "Delete call", hint = "Removes this call", tooltip = "Removes this call of your own.",
        visible = function() return not Rules.IsBuiltin(selected) end,
        onClick = function()
            local index
            for i, id in ipairs(Db().order) do
                if id == selected then index = i end
            end
            Rules.Remove(Db(), selected)
            selected = Db().order[math.min(index or 1, #Db().order)]
            PartyCalls.Refresh()
        end })
end

PartyCalls.key = "partyCalls"
ns.RegisterModule("PartyCalls", PartyCalls)
