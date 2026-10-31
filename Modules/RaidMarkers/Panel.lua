-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.MarkerRules

ns.RaidMarkerPanel = {}
local Shared = ns.RaidMarkerPanel

local SIZE, GAP, PAD = 26, 2, 4
local BAR_HEIGHT, TEXT_BAR_HEIGHT, DOWN_HEIGHT = 4, 12, 14
local FLAT = ns.Widgets.FLAT
local GOLD, BORDER = { 1, 0.82, 0, 1 }, { 0.4, 0.4, 0.4, 1 }
local WORLD_FOR_TARGET = { 5, 6, 3, 2, 7, 1, 4, 8 }
local TIP_ANCHORS = {
    below = { "TOPLEFT", "BOTTOMLEFT", 0, -4 },
    above = { "BOTTOMLEFT", "TOPLEFT", 0, 4 },
    right = { "TOPLEFT", "TOPRIGHT", 4, 0 },
    left = { "TOPRIGHT", "TOPLEFT", -4, 0 },
}
local GREY, RED = { 0.5, 0.5, 0.5 }, { 1, 0.2, 0.2 }

Shared.SIZE, Shared.GAP, Shared.CELL_PAD, Shared.ICON = SIZE, GAP, 8, 12
Shared.GOLD, Shared.GREY, Shared.RED = GOLD, GREY, RED

Shared.active = false
Shared.previewing = false
Shared.pending = {}

local dragging = false
local ticker

function Shared.Ring(button, on)
    local color = on and GOLD or BORDER
    button:SetBackdropBorderColor(color[1], color[2], color[3], color[4])
end

function Shared.NewButton(row, template, width, name)
    local button = CreateFrame("Button", name, row, template and template .. ",BackdropTemplate" or "BackdropTemplate")
    button:SetSize(width, SIZE)
    button.span = width
    button:SetBackdrop(FLAT)
    button:SetBackdropColor(0, 0, 0, 0.5)
    Shared.Ring(button, false)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.buttons[#row.buttons + 1] = button
    return button
end

function Shared.Label(button, text)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    return label
end

function Shared.ShowTip(button)
    local panel = Shared.panel
    Shared.PaintGroupButtons()
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

function Shared.SecureButton(row, width, title, attributes, name)
    local button = Shared.NewButton(row, "SecureActionButtonTemplate", width, name)
    button:RegisterForClicks("AnyUp", "AnyDown")
    for key, value in pairs(attributes) do
        button:SetAttribute(key, value)
    end
    button.title = title
    button:SetScript("OnEnter", Shared.ShowTip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function Shared.NewRow()
    local row = CreateFrame("Frame", nil, Shared.panel)
    row.buttons = {}
    return row
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

local function BarHeight()
    return ns.db.raidMarkerPanel.manaText == "none" and BAR_HEIGHT or TEXT_BAR_HEIGHT
end

local function PlaceBar(width)
    local indent = Shared.ICON + GAP
    Shared.manaBar:SetPoint("TOPLEFT", Shared.block, "BOTTOMLEFT", indent, -GAP)
    Shared.manaBar:SetSize(width - indent, BarHeight())
end

local function LayoutHorizontal()
    local row1, row2, block, groupButtons = Shared.row1, Shared.row2, Shared.block, Shared.groupButtons
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
    local db = ns.db.raidMarkerPanel
    if db.healerMana then
        PlaceBar(bw)
        bh = bh + GAP + BarHeight()
    end
    if db.groupDown then
        Shared.downText:SetPoint("LEFT", block, "RIGHT", GAP, 0)
        bw = bw + GAP + Shared.downText.cell
    end
    Shared.panel:SetSize(width + GAP + bw + 2 * PAD, math.max(2 * SIZE + GAP, bh) + 2 * PAD)
end

local function LayoutVertical()
    local row1, row2, block, groupButtons = Shared.row1, Shared.row2, Shared.block, Shared.groupButtons
    local clearTarget, worldButtons = Shared.clearTarget, Shared.worldButtons
    local width = math.max(2 * SIZE + GAP, block.cell, clearTarget.cell + GAP + SIZE)
    local inset = math.floor((width - 2 * SIZE - GAP) / 2)
    local step = SIZE + GAP
    for t, button in ipairs(Shared.targetButtons) do
        Cell(button, row1, inset, -(t - 1) * step, SIZE)
        Cell(worldButtons[WORLD_FOR_TARGET[t]], row2, inset + step, -(t - 1) * step, SIZE)
    end
    Cell(clearTarget, row1, 0, -8 * step, width - step)
    Cell(Shared.clearWorld, row2, width - SIZE, -8 * step, SIZE)
    Cell(Shared.modeButton, row2, 0, -9 * step, width)
    local height = 10 * step - GAP
    row1:SetSize(width, height)
    row2:SetSize(width, height)
    Cell(groupButtons.ready, block, 0, 0, width)
    Cell(groupButtons.pull, block, 0, -step, width)
    Cell(groupButtons.role, block, 0, -2 * step, width)
    block:SetSize(width, 3 * step - GAP)
    row2:SetPoint("TOPLEFT", row1, "TOPLEFT", 0, 0)
    block:SetPoint("TOPLEFT", row1, "BOTTOMLEFT", 0, -GAP)
    local db = ns.db.raidMarkerPanel
    local below, extra = block, 0
    if db.healerMana then
        PlaceBar(width)
        below, extra = Shared.manaBar, GAP + BarHeight()
    end
    if db.groupDown then
        Shared.downText:SetPoint("TOP", below, "BOTTOM", 0, -GAP)
        extra = extra + GAP + DOWN_HEIGHT
    end
    Shared.panel:SetSize(width + 2 * PAD, height + GAP + 3 * step - GAP + extra + 2 * PAD)
end

function Shared.Layout()
    Shared.row1:ClearAllPoints()
    Shared.row1:SetPoint("TOPLEFT", Shared.panel, "TOPLEFT", PAD, -PAD)
    Shared.row2:ClearAllPoints()
    Shared.block:ClearAllPoints()
    Shared.manaBar:ClearAllPoints()
    Shared.downText:ClearAllPoints()
    Shared.manaBar:SetShown(ns.db.raidMarkerPanel.healerMana)
    Shared.manaText:SetShown(ns.db.raidMarkerPanel.manaText ~= "none")
    Shared.downText:SetShown(ns.db.raidMarkerPanel.groupDown)
    if ns.db.raidMarkerPanel.vertical then
        LayoutVertical()
    else
        LayoutHorizontal()
    end
    Shared.RefreshHelpers()
end

function Shared.Place()
    local db = ns.db.raidMarkerPanel
    Shared.panel:ClearAllPoints()
    Shared.panel:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    Shared.panel:SetScale(db.scale)
end

function Shared.ApplyOutOfCombat(apply)
    if InCombatLockdown() then
        Shared.pending[apply] = true
    else
        apply()
    end
end

local function PanelScale()
    return Shared.panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function StartDrag()
    local panel, mover = Shared.panel, Shared.mover
    local scale = PanelScale()
    mover:SetSize(panel:GetWidth() * scale, panel:GetHeight() * scale)
    mover:ClearAllPoints()
    mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", panel:GetLeft() * scale, panel:GetBottom() * scale)
    mover:Show()
    mover:StartMoving()
    dragging = true
end

local function StopDrag()
    local mover = Shared.mover
    dragging = false
    mover:StopMovingOrSizing()
    local scale = PanelScale()
    local db = ns.db.raidMarkerPanel
    db.point, db.relativePoint = "BOTTOMLEFT", "BOTTOMLEFT"
    db.x, db.y = math.floor(mover:GetLeft() / scale + 0.5), math.floor(mover:GetBottom() / scale + 0.5)
    mover:Hide()
    Shared.ApplyOutOfCombat(Shared.Place)
end

local function Tick()
    Shared.RefreshWorld()
    Shared.RefreshHelpers()
end

function Shared.StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

function Shared.ApplyCombatHide()
    if ns.db.raidMarkerPanel.hideInCombat then
        RegisterStateDriver(Shared.container, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(Shared.container, "visibility")
        Shared.container:Show()
    end
end

function Shared.ApplyStrata()
    Shared.panel:SetFrameStrata(Shared.previewing and "FULLSCREEN_DIALOG" or "MEDIUM")
    Shared.mover:SetFrameStrata(Shared.previewing and "TOOLTIP" or "DIALOG")
end

function Shared.BuildFrame()
    local container = CreateFrame("Frame", nil, UIParent)
    Shared.container = container
    container:SetAllPoints(UIParent)
    Shared.ApplyCombatHide()

    local panel = CreateFrame("Frame", "LittleThingsRaidMarkers", container, "BackdropTemplate")
    Shared.panel = panel
    panel:Hide()
    panel:SetClampedToScreen(true)
    panel:SetDontSavePosition(true)
    panel:SetBackdrop(FLAT)
    panel:SetBackdropColor(0, 0, 0, 0.6)
    panel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local mover = CreateFrame("Frame", "LittleThingsRaidMarkersMover", UIParent)
    Shared.mover = mover
    mover:Hide()
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    Shared.ApplyStrata()
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
        Shared.RefreshTarget()
        Shared.RefreshWorld()
        Shared.PaintMode()
        Shared.RefreshHelpers()
        Shared.StopTicker()
        ticker = C_Timer.NewTicker(1, Tick)
    end)
    panel:SetScript("OnHide", function()
        Shared.StopTicker()
        if dragging then
            StopDrag()
        end
    end)
end
