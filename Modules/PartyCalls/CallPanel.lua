-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.CallRules

local Panel = {}
ns.PartyCallPanel = Panel

local FONTS = {
    small = { font = "GameFontHighlightSmall", height = 12 },
    normal = { font = "GameFontHighlight", height = 14 },
    large = { font = "GameFontHighlightLarge", height = 18 },
}
local LABEL_GAP = 2
local MAX_LABEL_LINES = 2
local DOCK_ID = "partyCalls"

Panel.buttons = {}
Panel.labelLines = 1

local function Db()
    return ns.db.partyCallOptions
end

local function Font()
    return FONTS[Db().labelSize] or FONTS.small
end

local function Lib()
    return LibStub("LibVelvet-1.0")
end

function Panel.Docked()
    return Db().dockTo ~= nil
end

local function MergedRoot()
    local panels = Lib().dock.panels
    local cur, seen = Db().dockTo, {}
    while cur and not seen[cur] do
        seen[cur] = true
        local p = panels[cur]
        if not p then return nil end
        if p.spec.root then return cur end
        cur = p.spec.get().dockTo
    end
end

function Panel.Merged()
    local root = MergedRoot()
    return root ~= nil and Lib().Dock.Merged(root)
end

local function ShownMergedRoot()
    local root = MergedRoot()
    local p = root and Lib().Dock.Merged(root) and Lib().dock.panels[root]
    return p and p.spec.frame:IsShown() and p or nil
end

function Panel.MergedOwner()
    return ShownMergedRoot() and MergedRoot() or nil
end

local function HandleShown()
    return ns.PanelDock.HandleShown(false, ShownMergedRoot() ~= nil)
end

local function Folded()
    local root = ShownMergedRoot()
    return (root and root.spec.get() or Db()).collapsed
end

local function ShowLabels()
    return Db().labels and not Folded()
end

local function CellSize()
    local db = Db()
    if not ShowLabels() then
        return db.iconSize, db.iconSize
    end
    return db.iconSize, db.iconSize + LABEL_GAP + Panel.labelLines * Font().height
end

local function LabelLines(ids)
    if not ShowLabels() then
        return 1
    end
    for _, id in ipairs(ids) do
        local label = Panel.buttons[id].label
        if label:GetUnboundedStringWidth() > label:GetWidth() then
            return MAX_LABEL_LINES
        end
    end
    return 1
end

local function SaveCorner()
    local panel, db = Panel.panel, Db()
    local anchor = Panel.anchor or "TOPLEFT"
    if not panel:GetLeft() then
        return
    end
    local k = panel:GetScale() / db.scale
    db.posX = math.floor((anchor:find("RIGHT") and panel:GetRight() or panel:GetLeft()) * k + 0.5)
    db.posY = math.floor((anchor:find("BOTTOM") and panel:GetBottom() or panel:GetTop()) * k + 0.5)
end

local function Notify(id)
    local p = id and Lib().dock.panels[id]
    if p and p.spec.onChange then
        p.spec.onChange()
    end
end

function Panel.Place()
    local db = Db()
    local panel = Panel.panel
    local was, wasSide = Panel.dockedTo, Panel.dockedSide
    if was and not db.dockTo then
        SaveCorner()
    end
    Panel.dockedTo, Panel.dockedSide = db.dockTo, db.side
    local root = ShownMergedRoot()
    panel:SetScale(root and root.spec.frame:GetScale() or db.scale)
    if not (db.dockTo and InCombatLockdown() and panel:GetNumPoints() > 0) then
        panel:ClearAllPoints()
        if db.posX and db.posY then
            panel:SetPoint(Panel.anchor or "TOPLEFT", UIParent, "BOTTOMLEFT", db.posX, db.posY)
        else
            panel:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        end
        Lib().Dock.Apply(DOCK_ID)
        if db.dockTo and not InCombatLockdown() then
            SaveCorner()
        end
    end
    if was ~= db.dockTo then
        Notify(was)
    end
    if was ~= db.dockTo or wasSide ~= db.side then
        Notify(db.dockTo)
    end
end

local function PlaceTopLeft(x, y)
    local panel = Panel.panel
    local s = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / s, -y / s)
    SaveCorner()
end

local function Release(mover, deferred)
    if deferred and Db().dockTo then return end
    PlaceTopLeft(mover:GetLeft() - UIParent:GetLeft(), UIParent:GetTop() - mover:GetTop())
end

local function DragDown()
    Panel.drag.MouseDown()
end

local function StartDrag()
    Panel.drag.Start()
end

local function StopDrag(_, hidden)
    Panel.drag.Stop(hidden)
end

function Panel.StopDragging()
    StopDrag()
end

local function Overlaps(a, b)
    local sa, sb = a:GetEffectiveScale(), b:GetEffectiveScale()
    local al, ar, at, ab = a:GetLeft(), a:GetRight(), a:GetTop(), a:GetBottom()
    local bl, br, bt, bb = b:GetLeft(), b:GetRight(), b:GetTop(), b:GetBottom()
    if not al or not bl then
        return false
    end
    return al * sa < br * sb and ar * sa > bl * sb and ab * sa < bt * sb and at * sa > bb * sb
end

function Panel.MoveClearOf(window)
    if Panel.drag.active or Panel.Docked() or not Overlaps(Panel.panel, window) then
        return
    end
    local scale = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local roomLeft = window:GetLeft() * scale
    local roomRight = UIParent:GetWidth() - window:GetRight() * scale
    Panel.panel:ClearAllPoints()
    if roomLeft >= roomRight then
        Panel.panel:SetPoint("TOPRIGHT", window, "TOPLEFT", -8, 0)
    else
        Panel.panel:SetPoint("TOPLEFT", window, "TOPRIGHT", 8, 0)
    end
end

function Panel.ResetPosition()
    local db = Db()
    if db.dockTo then
        Lib().Dock.Undock(DOCK_ID)
    end
    db.posX, db.posY = nil, nil
    Panel.Place()
end

local function ShowTip(button)
    local call = Db().calls[button.id]
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(call.label ~= "" and call.label or "Call", 1, 1, 1)
    local text = (Rules.Text(call) or ""):gsub("{rt(%d)}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t")
    GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

local function Ensure(id)
    local button = Panel.buttons[id]
    if button then
        return button
    end
    button = CreateFrame("Button", nil, Panel.panel)
    button.id = id
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOP")
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.label = button:CreateFontString(nil, "OVERLAY")
    button.label:SetPoint("TOP", button.icon, "BOTTOM", 0, -LABEL_GAP)
    button.label:SetWordWrap(true)
    button.label:SetMaxLines(MAX_LABEL_LINES)
    button.label:SetJustifyV("TOP")
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button.icon)
    highlight:SetColorTexture(1, 1, 1, 0.15)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnMouseDown", DragDown)
    button:SetScript("OnDragStart", StartDrag)
    button:SetScript("OnDragStop", StopDrag)
    button:SetScript("OnClick", function(self) Panel.onClick(self.id) end)
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()
    Panel.buttons[id] = button
    return button
end

function Panel.Build(onClick, onChange)
    Panel.onClick = onClick
    local panel = CreateFrame("Frame", "LittleThingsPartyCalls", UIParent, "BackdropTemplate")
    Panel.panel = panel
    panel:Hide()
    panel:SetClampedToScreen(true)
    panel:SetDontSavePosition(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnMouseDown", DragDown)
    panel:SetScript("OnDragStart", StartDrag)
    panel:SetScript("OnDragStop", StopDrag)
    panel:SetScript("OnHide", function(self) StopDrag(self, true) end)
    local db = Db()
    Panel.drag = ns.PanelDock.GhostDrag(DOCK_ID, panel, { name = "LittleThingsPartyCallsMover",
        release = Release, snapped = PlaceTopLeft, after = Panel.Place })
    Lib().Dock.Register(DOCK_ID, { frame = panel, root = false, get = Db, set = function() end,
        locked = function() return not ns.PanelMove.CanDrag(DOCK_ID) end, onChange = onChange })
    local handle = CreateFrame("Button", nil, panel)
    Panel.handle, panel.foldHandle = handle, handle
    Panel.glyph = ns.PanelDock.BuildHandle(handle, panel)
    handle:SetIgnoreParentAlpha(true)
    handle:RegisterForClicks("LeftButtonUp")
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnMouseDown", DragDown)
    handle:SetScript("OnDragStart", StartDrag)
    handle:SetScript("OnDragStop", StopDrag)
    handle:SetScript("OnClick", function()
        db.collapsed = not db.collapsed
        onChange()
    end)
    Panel.anchor = select(4, Rules.Grid(0, { grow = db.grow, wrap = db.wrap, perRow = 1, cellW = 0, cellH = 0, gap = 0, pad = 0 }))
    Panel.Place()
end

local function PaintBackground()
    local db, panel = Db(), Panel.panel
    if Lib().Dock.MergeFrame(DOCK_ID) then
        panel:SetBackdrop(nil)
        return
    end
    panel:SetBackdrop(ns.Widgets.FLAT)
    panel:SetBackdropColor(0, 0, 0, db.bgAlpha)
    panel:SetBackdropBorderColor(0.3, 0.3, 0.3, db.border and not ns.PanelMove.Moving() and 1 or 0)
end

function Panel.Update()
    local db = Db()
    local width = CellSize()
    local font = Font()
    PaintBackground()
    Panel.handle:SetShown(HandleShown())
    Panel.glyph:SetText(db.collapsed and "+" or "-")
    for id, call in pairs(db.calls) do
        local button = Ensure(id)
        button.icon:SetSize(db.iconSize, db.iconSize)
        button.icon:SetTexture(Rules.Texture(call.icon, C_Spell.GetSpellTexture, GetFileIDFromPath))
        button.icon:SetDesaturated(call.desaturate and true or false)
        button.label:SetFontObject(font.font)
        button.label:SetWidth(width)
        button.label:SetText(call.label)
        button.label:SetShown(ShowLabels())
    end
end

function Panel.Layout(ids)
    local db = Db()
    Panel.labelLines = LabelLines(ids)
    local width, height = CellSize()
    local cells, panelW, panelH, anchor = Rules.Grid(#ids, { grow = db.grow, wrap = db.wrap, perRow = db.perRow,
        cellW = width, cellH = height, gap = db.gap, pad = db.pad, strip = HandleShown() and ns.PanelDock.STRIP or 0 })
    if anchor ~= Panel.anchor then
        Panel.anchor = anchor
        if db.posX and not Panel.Docked() then
            SaveCorner()
        end
    end
    for _, button in pairs(Panel.buttons) do
        button:Hide()
    end
    for i, id in ipairs(ids) do
        local button = Panel.buttons[id]
        button:SetSize(width, height)
        button:ClearAllPoints()
        button:SetPoint(anchor, Panel.panel, anchor, cells[i].x, cells[i].y)
        button:Show()
    end
    Panel.panel:SetSize(panelW, panelH)
    Panel.glyph:ClearAllPoints()
    Panel.glyph:SetPoint("CENTER", Panel.handle, "CENTER", 0, ns.PanelDock.GlyphOffset(panelH))
    Panel.Place()
end

function Panel.Paint(remaining)
    local any = false
    for id, button in pairs(Panel.buttons) do
        local grey = Db().calls[id] and remaining(id) > 0
        any = any or grey
        local shade = grey and 0.35 or 1
        button.icon:SetVertexColor(shade, shade, shade)
        button.label:SetTextColor(shade, shade, shade)
    end
    return any
end

function Panel.Flash(id)
    local button = Panel.buttons[id]
    button:SetAlpha(0.4)
    C_Timer.After(0.15, function() button:SetAlpha(1) end)
end
