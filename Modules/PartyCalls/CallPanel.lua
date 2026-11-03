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

local function ShowLabels()
    local db = Db()
    return db.labels and not db.collapsed
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
    db.posX = math.floor((anchor:find("RIGHT") and panel:GetRight() or panel:GetLeft()) + 0.5)
    db.posY = math.floor((anchor:find("BOTTOM") and panel:GetBottom() or panel:GetTop()) + 0.5)
end

function Panel.Place()
    local db = Db()
    local panel = Panel.panel
    if Panel.wasDocked and not db.dockTo then
        SaveCorner()
    end
    Panel.wasDocked = db.dockTo ~= nil
    local root = MergedRoot()
    local rootPanel = root and Lib().Dock.Merged(root) and Lib().dock.panels[root]
    panel:SetScale(rootPanel and rootPanel.spec.frame:GetScale() or db.scale)
    if db.dockTo and InCombatLockdown() then
        return
    end
    panel:ClearAllPoints()
    if db.posX and db.posY then
        panel:SetPoint(Panel.anchor or "TOPLEFT", UIParent, "BOTTOMLEFT", db.posX, db.posY)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    end
    Lib().Dock.Apply(DOCK_ID)
    ns.PanelDock.PlaceArrow(Panel.arrow, panel)
end

local function Cursor()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

local StopDrag

local function DragStep()
    if not IsMouseButtonDown("LeftButton") then
        StopDrag()
        return
    end
    local panel, grab = Panel.panel, Panel.grab
    local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local cx, cy = Cursor()
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (cx - grab.x - UIParent:GetLeft()) / scale,
        (cy - grab.y - UIParent:GetTop()) / scale)
    local x, y = Lib().Dock.Snap(DOCK_ID)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / scale, -y / scale)
end

local function StartDrag()
    local panel = Panel.panel
    if Panel.dragging or not Lib().Dock.CanDrag(DOCK_ID) or not panel:GetLeft() then
        return
    end
    local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local cx, cy = Cursor()
    Panel.grab = { x = cx - panel:GetLeft() * scale, y = cy - panel:GetTop() * scale }
    Panel.dragging = true
    Panel.dragger:SetScript("OnUpdate", DragStep)
end

function StopDrag(_, hidden)
    if not Panel.dragging then
        return
    end
    Panel.dragging = false
    Panel.dragger:SetScript("OnUpdate", nil)
    SaveCorner()
    if not hidden then
        Lib().Dock.Drop(DOCK_ID)
    end
    Panel.Place()
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
    if Panel.dragging or Panel.Docked() or not Overlaps(Panel.panel, window) then
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
    Panel.dragger = CreateFrame("Frame")
    panel:Hide()
    panel:SetClampedToScreen(true)
    panel:SetDontSavePosition(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", StartDrag)
    panel:SetScript("OnDragStop", StopDrag)
    panel:SetScript("OnHide", function(self) StopDrag(self, true) end)
    local db = Db()
    Lib().Dock.Register(DOCK_ID, { frame = panel, root = false, get = Db, set = function() end,
        locked = function() return Db().locked end, onChange = onChange })
    Panel.arrow = Lib().Dock.Arrow(panel, function()
        db.collapsed = not db.collapsed
        onChange()
    end, DOCK_ID)
    Panel.arrow:SetFrameLevel(panel:GetFrameLevel() + 10)
    panel.dockArrow = Panel.arrow
    Panel.arrow:SetCollapsed(db.collapsed)
    Panel.anchor = select(4, Rules.Grid(0, { grow = db.grow, wrap = db.wrap, perRow = 1, cellW = 0, cellH = 0, gap = 0, pad = 0 }))
    Panel.Place()
end

local function PaintBackground()
    local db, panel = Db(), Panel.panel
    if Panel.Merged() then
        panel:SetBackdrop(nil)
        return
    end
    panel:SetBackdrop(ns.Widgets.FLAT)
    panel:SetBackdropColor(0, 0, 0, db.bgAlpha)
    panel:SetBackdropBorderColor(0.3, 0.3, 0.3, db.border and 1 or 0)
end

function Panel.Update()
    local db = Db()
    local width = CellSize()
    local font = Font()
    PaintBackground()
    Panel.arrow:SetCollapsed(db.collapsed)
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
        cellW = width, cellH = height, gap = db.gap, pad = db.pad })
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
