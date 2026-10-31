-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Preview = { columnMin = 476 }
ns.SaveRowPreview = Preview

local CAPTION = "Preview: Sentinel and Pain Suppression on you"
local OFF = "The save indicator is off. Turn it on above to use it in game."

local pane, host, row, parts

function Preview.Attach(target)
    pane = target
    host = CreateFrame("Frame", nil, pane.stage)
    pane:SetCaption(CAPTION)
end

function Preview.Refresh()
    if not pane or not pane:IsVisible() then return end
    if not row then
        row = CreateFrame("Frame", nil, host)
        row:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
        parts = ns.SaveCenter.DrawSamples(row)
    end
    local db = ns.db.saveIndicatorRow
    ns.SaveCenter.PaintSamples(parts, db.showTime, db.showDR)
    row:SetScale(db.scale)
    local w, h = row:GetWidth() * db.scale, row:GetHeight() * db.scale
    host:SetSize(w, h)
    pane:SetOff(not ns.IsOn("saveIndicator") and OFF or nil)
    pane:Fit(host, w, h)
end
