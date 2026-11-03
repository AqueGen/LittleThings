-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.CallRules

local Panel = {}
ns.PartyCallPanel = Panel

local CELL, ICON, LABEL_H, GAP, PAD = 56, 32, 12, 2, 4
local CELL_H = ICON + LABEL_H + GAP

Panel.buttons = {}

local function Db()
    return ns.db.partyCallOptions
end

function Panel.Place()
    local db = Db()
    local panel = Panel.panel
    panel:ClearAllPoints()
    panel:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    panel:SetScale(db.scale)
end

local function StartDrag()
    if not Db().locked then
        Panel.panel:StartMoving()
        Panel.dragging = true
    end
end

local function StopDrag()
    if not Panel.dragging then
        return
    end
    Panel.dragging = false
    local panel = Panel.panel
    panel:StopMovingOrSizing()
    local db = Db()
    db.point, db.relativePoint = "BOTTOMLEFT", "BOTTOMLEFT"
    db.x, db.y = math.floor(panel:GetLeft() + 0.5), math.floor(panel:GetBottom() + 0.5)
    Panel.Place()
end

local function ShowTip(button)
    local call = Db().calls[button.id]
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(call.label ~= "" and call.label or button.id, 1, 1, 1)
    GameTooltip:AddLine(Rules.Text(call) or "", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

local function NewButton(id, onClick)
    local button = CreateFrame("Button", nil, Panel.panel)
    button.id = id
    button:SetSize(CELL, CELL_H)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON, ICON)
    button.icon:SetPoint("TOP")
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("TOP", button.icon, "BOTTOM", 0, -GAP)
    button.label:SetWidth(CELL)
    button.label:SetWordWrap(false)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button.icon)
    highlight:SetColorTexture(1, 1, 1, 0.15)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", StartDrag)
    button:SetScript("OnDragStop", StopDrag)
    button:SetScript("OnClick", function(self) onClick(self.id) end)
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:Hide()
    return button
end

function Panel.Build(onClick)
    local panel = CreateFrame("Frame", "LittleThingsPartyCalls", UIParent, "BackdropTemplate")
    Panel.panel = panel
    panel:Hide()
    panel:SetClampedToScreen(true)
    panel:SetDontSavePosition(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", StartDrag)
    panel:SetScript("OnDragStop", StopDrag)
    panel:SetScript("OnHide", StopDrag)
    panel:SetBackdrop(ns.Widgets.FLAT)
    panel:SetBackdropColor(0, 0, 0, 0.6)
    panel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    for _, id in ipairs(Rules.Order()) do
        Panel.buttons[id] = NewButton(id, onClick)
    end
    Panel.Place()
end

function Panel.Update()
    for id, button in pairs(Panel.buttons) do
        local call = Db().calls[id]
        button.icon:SetTexture(Rules.Texture(call.icon, C_Spell.GetSpellTexture, GetFileIDFromPath))
        button.icon:SetDesaturated(call.desaturate and true or false)
        button.label:SetText(call.label)
    end
end

function Panel.Layout(ids)
    local vertical = Db().vertical
    for _, button in pairs(Panel.buttons) do
        button:Hide()
    end
    for i, id in ipairs(ids) do
        local button = Panel.buttons[id]
        local offset = (i - 1) * ((vertical and CELL_H or CELL) + GAP)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", Panel.panel, "TOPLEFT", PAD + (vertical and 0 or offset), -PAD - (vertical and offset or 0))
        button:Show()
    end
    local count = math.max(#ids, 1)
    local along = count * ((vertical and CELL_H or CELL) + GAP) - GAP
    if vertical then
        Panel.panel:SetSize(CELL + 2 * PAD, along + 2 * PAD)
    else
        Panel.panel:SetSize(along + 2 * PAD, CELL_H + 2 * PAD)
    end
end

function Panel.Paint(remaining)
    local any = false
    for id, button in pairs(Panel.buttons) do
        local grey = remaining(id) > 0
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
