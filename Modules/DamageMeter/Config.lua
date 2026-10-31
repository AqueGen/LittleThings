-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

ns.Config = {}
local Config = ns.Config

-- The options are on the page whether the module is running or not, so a
-- change made before the reload that starts it must not reach into modules
-- that were never enabled.
local active = false

local function Wrap(onChange)
    return function()
        if active and onChange then
            onChange()
        end
    end
end

local function Db(key, spec, onChange)
    spec.get = function() return ns.db[key] end
    spec.set = function(value)
        ns.db[key] = value
        Wrap(onChange)()
    end
    return spec
end

local function AddBlizzardCVarCheck(group, cvar, label, tooltip)
    group:Check({
        label = label,
        combatLocked = true,
        tooltip = function()
            local isAvailable, failureReason = C_DamageMeter.IsDamageMeterAvailable()
            local text = tooltip .. "|n|n|cff808080The game's own setting, from Gameplay Enhancements. Shown here so the meter is configured in one place.|r"
            if not isAvailable then
                text = text .. "|n|n" .. failureReason
            end
            return text
        end,
        get = function() return C_CVar.GetCVarBool(cvar) end,
        set = function(value)
            local ok, result = pcall(C_CVar.SetCVar, cvar, value and "1" or "0")
            if not ok or result == false then
                ns.Print("the game refused to change " .. label .. " right now")
            end
        end,
    })
end

local function StrataOptions()
    local list = {}
    for _, strata in ipairs(ns.Presence.STRATA_ORDER) do
        list[#list + 1] = { value = strata, text = strata }
    end
    return list
end

local function BuildBehaviourOptions(page)
    local group = page:Group("Behaviour")

    group:Check(Db("format", { label = "Readable numbers",
        tooltip = "Show 56.72M instead of 56716 K. The percentage is shown only out of combat, because it is the one part that needs arithmetic on values that are Secret in combat." },
        function()
            if not ns.db.format then
                ns.Format.Restore()
            end
        end))

    group:Check(Db("snap", { label = "Snap windows together",
        tooltip = "Dragging a window near another attaches it, and they move and resize together." }))

    group:Slider(Db("snapThreshold", { label = "Snap distance", min = 5, max = 50,
        tooltip = "How close an edge must be, in pixels, before it snaps." }))

    group:Slider(Db("idleAlpha", { label = "Idle transparency", min = 0.1, max = 1, step = 0.05, format = "%.2f",
        tooltip = "How visible the meter is when the mouse is not on it, as a fraction of the Edit Mode transparency. "
            .. "A window set to uninteractable stays at the idle value, because its mouse is disabled." },
        function() ns.Presence.ApplyAlphaToAll() end))

    group:Dropdown({ label = "Layer", default = ns.defaults.strata, options = StrataOptions,
        tooltip = "Which layer the meter draws on. Raise it if another addon covers it.",
        get = function() return ns.Presence.ResolveStrata(ns.db.strata) end,
        set = function(value)
            ns.db.strata = value
            Wrap(ns.Presence.ApplyStrata)()
        end })

    local blizzard = page:Group(DAMAGE_METER_LABEL .. " (Blizzard)")
    AddBlizzardCVarCheck(blizzard, "damageMeterEnabled", ENABLE_DAMAGE_METER, ENABLE_DAMAGE_METER_TOOLTIP)
    AddBlizzardCVarCheck(blizzard, "damageMeterResetOnNewInstance", AUTO_RESET_DAMAGE_METER, AUTO_RESET_DAMAGE_METER_TOOLTIP)
end

function Config.Open()
    ns.OpenSettings("damageMeter")
end

function Config.Enable()
    active = true
end

local UI = LibStub("LibVelvet-1.0")
local T = ns.Widgets.THEME
local LINE_H = 22

local windowPage
local rows = {}

local RefreshWindowPanel

local function Text(parent, width, muted)
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    if width then text:SetWidth(width) end
    text:SetTextColor(unpack(muted and T.muted or T.text))
    return text
end

local function Input(parent, width, letters, onEnter)
    local box = UI.Input(parent, width, 20)
    box:SetNumeric(true)
    box:SetMaxLetters(letters)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        RefreshWindowPanel()
    end)
    box:SetScript("OnEnterPressed", function(self)
        onEnter(self)
        self:ClearFocus()
        RefreshWindowPanel()
    end)
    return box
end

-- Setting the size here deliberately goes through SetSize on the window, so it
-- trips the OnSizeChanged hook and propagates to anything matched to it,
-- exactly as a mouse resize would. The refresh afterwards shows the clamped
-- value rather than what was typed - silently ignoring an out-of-range request
-- would be worse than correcting it in front of the user.
local function SizeBox(parent, index, dimension)
    return Input(parent, 44, 4, function(self)
        if InCombatLockdown() then return end
        local window = ns.Windows.Get(index)
        local value = tonumber(self:GetText())
        if window and value then
            local width = (dimension == "width") and value or window:GetWidth()
            local height = (dimension == "height") and value or window:GetHeight()
            if ns.Windows.SetSize(index, width, height) then
                ns.RequestReload("size")
            end
        end
    end)
end

-- Windows.Indices only lists a Blizzard window once it has been shown; the
-- page lists all three slots so a hidden one still has a box saying how to
-- bring it back. RefreshRow already handles a nil window.
local function PanelIndices()
    local present = {}
    for index = 1, ns.Windows.BLIZZARD_WINDOW_COUNT do
        present[index] = true
    end
    return ns.Windows.SortedIndices(present)
end

local function Check(parent, text, onClick)
    local check = UI.Checkbox(parent, 16)
    check.label = Text(check)
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.label:SetText(text)
    check:SetHitRectInsets(0, -(check.label:GetStringWidth() + 6), 0, 0)
    check:SetScript("OnClick", onClick)
    return check
end

local function Paint(control, enabled)
    control:SetEnabled(enabled)
    control.label:SetTextColor(unpack(enabled and T.text or T.muted))
end

local function CreateRow(parent, index)
    local row = {}

    row.sizeLine = CreateFrame("Frame", nil, parent)
    row.sizeLine:SetSize(520, LINE_H)
    row.Size = Text(row.sizeLine, 70)
    row.Size:SetPoint("LEFT")
    row.Width = SizeBox(row.sizeLine, index, "width")
    row.Width:SetPoint("LEFT", row.Size, "RIGHT", 12, 0)
    row.Height = SizeBox(row.sizeLine, index, "height")
    row.Height:SetPoint("LEFT", row.Width, "RIGHT", 8, 0)

    -- Shown, not offered: locking from our stack writes the window's isLocked,
    -- its OnUpdate reads it through CanMoveOrResize and then writes
    -- onUpdateReasons, and every combat start trips over that in
    -- ClearSessionTimer (DamageMeterSessionWindow.lua:232, 267, 930) until a
    -- reload. The gear menu's own Lock window is clean.
    row.Locked = Text(row.sizeLine, 50)
    row.Locked:SetPoint("LEFT", row.Height, "RIGHT", 16, 0)
    row.Note = Text(row.sizeLine, nil, true)
    row.Note:SetPoint("LEFT", row.Locked, "RIGHT", 16, 0)

    row.linkLine = CreateFrame("Frame", nil, parent)
    row.linkLine:SetSize(520, LINE_H)
    row.Link = Text(row.linkLine, 160)
    row.Link:SetPoint("LEFT")
    row.GapLabel = Text(row.linkLine, nil, true)
    row.GapLabel:SetPoint("LEFT", row.Link, "RIGHT", 12, 0)
    row.GapLabel:SetText("gap")
    row.Gap = Input(row.linkLine, 36, 3, function(self)
        local link = ns.charDb.links[index]
        local value = tonumber(self:GetText())
        if link and value then
            link.gap = value
            ns.Snap.ApplyLink(index)
        end
    end)
    row.Gap:SetPoint("LEFT", row.GapLabel, "RIGHT", 8, 0)

    -- The axis the windows are joined across follows through anchors and is
    -- clean; the other one is a one-off copy that needs a reload.
    local function SetMatch(flag, checked)
        local link = ns.charDb.links[index]
        if not link then
            return
        end
        link[flag] = checked
        ns.Snap.ApplyLink(index)
        if checked and ns.Snap.CopyCrossSize(index) then
            ns.RequestReload("size")
        end
        RefreshWindowPanel()
    end

    row.MatchWidth = Check(row.linkLine, "match width", function(self) SetMatch("matchWidth", self:GetChecked()) end)
    row.MatchWidth:SetPoint("LEFT", row.Gap, "RIGHT", 16, 0)
    row.MatchHeight = Check(row.linkLine, "match height", function(self) SetMatch("matchHeight", self:GetChecked()) end)
    row.MatchHeight:SetPoint("LEFT", row.MatchWidth.label, "RIGHT", 16, 0)

    row.buttonLine = CreateFrame("Frame", nil, parent)
    row.buttonLine:SetSize(170, LINE_H)
    row.Detach = ns.Widgets.Button(row.buttonLine, "Detach", 80)
    row.Detach:SetPoint("LEFT")
    row.Detach:SetScript("OnClick", function()
        ns.Snap.ClearLink(index)
        RefreshWindowPanel()
    end)
    row.Remove = ns.Widgets.Button(row.buttonLine, "Hide", 80)
    row.Remove:SetPoint("LEFT", row.Detach, "RIGHT", 8, 0)
    row.Remove:SetScript("OnClick", function()
        ns.Windows.Hide(index)
        RefreshWindowPanel()
    end)

    return row
end

-- The four pairs Snap.FindSnap produces, named the way the player sees them.
local SIDE_NAMES = {
    ["TOPLEFT|BOTTOMLEFT"] = "below",
    ["BOTTOMLEFT|TOPLEFT"] = "above",
    ["TOPLEFT|TOPRIGHT"] = "right of",
    ["TOPRIGHT|TOPLEFT"] = "left of",
}

local function RefreshRow(row, index)
    local window = ns.Windows.Get(index)
    local isPrimary = index == 1
    local link = ns.charDb.links[index]
    local shown = window ~= nil and window:IsShown()
    local fighting = InCombatLockdown()

    if shown then
        row.Size:SetText(("%d x %d"):format(window:GetWidth(), window:GetHeight()))
    else
        row.Size:SetText("hidden")
    end

    -- Window 1 gets the size boxes too: Windows.SetSize routes it through
    -- Edit Mode. A locked window keeps them, greyed out, so the page says
    -- why the edit is refused instead of swallowing it.
    local resizable = shown and (index == 1 or window:CanMoveOrResize())
    row.Width:SetEnabled(resizable and not fighting)
    row.Height:SetEnabled(resizable and not fighting)

    -- Never overwrite a box the user is typing in; the throttled refresh below
    -- runs while the page is open, and hiding the window from this same row is
    -- enough to take the shown branch out from under a half-typed number.
    if not row.Width:HasFocus() then
        row.Width:SetText(shown and math.floor(window:GetWidth() + 0.5) or "")
    end
    if not row.Height:HasFocus() then
        row.Height:SetText(shown and math.floor(window:GetHeight() + 0.5) or "")
    end

    row.Locked:SetText((shown and not isPrimary and window:IsLocked()) and "locked" or "")

    if isPrimary then
        row.Note:SetText("Size comes from Edit Mode.")
    elseif not shown then
        row.Note:SetText("Show new window in a meter's gear menu brings it back.")
    else
        row.Note:SetText("")
    end

    if link then
        local side = SIDE_NAMES[tostring(link.point) .. "|" .. tostring(link.relPoint)]
        row.Link:SetText(("attached %s window %s"):format(side or "to", link.to))
    else
        row.Link:SetText("not attached")
    end
    row.Gap:SetEnabled(link ~= nil and not isPrimary)
    if not row.Gap:HasFocus() then
        row.Gap:SetText(link and (link.gap or 0) or "")
    end

    row.MatchWidth:SetChecked(link and link.matchWidth or false)
    Paint(row.MatchWidth, link ~= nil and not isPrimary and not fighting)
    row.MatchHeight:SetChecked(link and link.matchHeight or false)
    Paint(row.MatchHeight, link ~= nil and not isPrimary and not fighting)
    Paint(row.Detach, link ~= nil and not isPrimary)

    -- Hiding is the only direction that is clean from addon code; see Windows.Hide.
    Paint(row.Remove, not isPrimary and shown)
end

function RefreshWindowPanel()
    if not windowPage or not windowPage:IsShown() then
        return
    end
    for index, row in pairs(rows) do
        RefreshRow(row, index)
    end
end

-- The page deliberately offers no way to attach a window: snapping is a drag
-- gesture, and a control duplicating it would be a second way to do the same
-- thing. The page shows the link, its gap, its match flags and a Detach button.
function Config.Pages(page)
    BuildBehaviourOptions(page)
end

local function BuildWindowsPage(page)
    if not ns.db.damageMeter or not ns.IsAvailable() then
        page:Group("Meter windows"):Note("Switch the Damage meter module on and reload to manage its windows here.")
        return
    end

    page:Group("Meter windows"):Note("The size boxes, and match height on stacked windows (match width on side-by-side ones) go through Blizzard's code and need a /reload afterwards - the addon offers one. Until then the meter can log errors in combat. Sizes stay as set after the reload. Dragging, snapping, the gap and the other match are always safe.")

    for _, index in ipairs(PanelIndices()) do
        local group = page:Group(index == 1 and "Window 1 (primary)" or ("Window " .. index))
        local row = CreateRow(group.frame, index)
        rows[index] = row
        group:Add(row.sizeLine, LINE_H, function() RefreshRow(row, index) end)
        group:Add(row.linkLine, LINE_H)
        group:Add(row.buttonLine, LINE_H)
    end

    windowPage = page.frame
    windowPage:HookScript("OnShow", RefreshWindowPanel)

    -- Everything shown here can change from outside the page: the keybinds,
    -- Blizzard's own Hide, a mouse resize. Polling twice a second is cheaper
    -- than hooking all of them.
    local sinceRefresh = 0
    windowPage:HookScript("OnUpdate", function(_, elapsed)
        sinceRefresh = sinceRefresh + elapsed
        if sinceRefresh >= 0.5 then
            sinceRefresh = 0
            RefreshWindowPanel()
        end
    end)
end

ns.Window.Register("damageMeterWindows", BuildWindowsPage)

Config.key = "damageMeter"
ns.RegisterModule("Config", Config)
