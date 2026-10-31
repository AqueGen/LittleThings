-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.MarkerRules
local Shared = ns.RaidMarkerPanel

local Preview = { columnMin = 476 }
ns.RaidMarkerPreview = Preview

local CAPTION = "Preview: the panel in a party, a skull on your target, two world markers down"
local OFF = "The raid marker panel is off. Turn it on above to use it in game."
local MANA, MANA_MAX, PERCENT, DOWN = 180000, 250000, 72, 1
local TARGET, PLACED = 8, { 1, 2 }

local pane, host, view

local function Cell(row, width)
    local cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
    Shared.Skin(cell, width)
    row.buttons[#row.buttons + 1] = cell
    return cell
end

local function Build()
    local panel = CreateFrame("Frame", nil, host, "BackdropTemplate")
    Shared.PaintPanel(panel)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    view = { panel = panel, row1 = Shared.NewRow(panel), row2 = Shared.NewRow(panel), block = Shared.NewRow(panel) }
    view.targetButtons, view.clearTarget = Shared.TargetCells(view.row1, Cell)
    view.worldButtons, view.modeButton, view.clearWorld = Shared.WorldCells(view.row2, Cell)
    view.groupButtons = Shared.GroupCells(view.block, Cell)
    view.manaBar, view.manaText, view.downText = Shared.HelperParts(panel)

    Shared.Ring(view.targetButtons[TARGET], true)
    for _, i in ipairs(PLACED) do Shared.Ring(view.worldButtons[i], true) end
    for _, button in ipairs(view.worldButtons) do
        button.nextRing:Hide()
        button.nextGap:Hide()
    end
    view.manaBar:SetMinMaxValues(0, MANA_MAX)
    view.manaBar:SetValue(MANA)
    view.manaBar:SetAlpha(1)
    view.downText:SetText(Rules.DownLabel(DOWN))
    view.downText:SetAlpha(1)
    local priest = C_ClassColor.GetClassColor("PRIEST")
    view.healer = priest and priest:WrapTextInColorCode("Healer") or "Healer"
end

function Preview.Attach(target)
    pane = target
    host = CreateFrame("Frame", nil, pane.stage)
    pane:SetCaption(CAPTION)
end

function Preview.Refresh()
    if not pane or not pane:IsVisible() then return end
    if not view then Build() end
    local db = ns.db.raidMarkerPanel
    Shared.Arrange(view)
    local color = Shared.ModeColor(#Rules.Cycle(db.order), true, false)
    view.modeButton.label:SetTextColor(color[1], color[2], color[3])
    Shared.SetManaText(view.manaText, db.manaText, view.healer, MANA, PERCENT)
    view.panel:SetScale(db.scale)
    local w, h = view.panel:GetWidth() * db.scale, view.panel:GetHeight() * db.scale
    host:SetSize(w, h)
    pane:SetOff(not ns.IsOn("raidMarkers") and OFF or nil)
    pane:Fit(host, w, h)
end
