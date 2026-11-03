-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local PanelDock = {}
ns.PanelDock = PanelDock

local TICK, HANDLE_FLOOR = 0.1, 0.35
local tickers = {}

PanelDock.STRIP = 12

local function Lib()
    return LibStub("LibVelvet-1.0")
end

function PanelDock.BuildHandle(handle, panel)
    local T = Lib().T
    handle:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    handle:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", PanelDock.STRIP, 0)
    local line = handle:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", handle, "TOPRIGHT", -1, 0)
    line:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(unpack(T.divider))
    local glyph = handle:CreateFontString(nil, "OVERLAY")
    glyph:SetFontObject("GameFontNormalSmall")
    glyph:SetPoint("CENTER", handle, "CENTER", 0, 0)
    glyph:SetTextColor(unpack(T.muted))
    glyph:SetText("-")
    handle:SetScript("OnEnter", function() glyph:SetTextColor(unpack(Lib().T.gold)) end)
    handle:SetScript("OnLeave", function() glyph:SetTextColor(unpack(Lib().T.muted)) end)
    return glyph
end

function PanelDock.FadeAlpha(hovered, db)
    if not db.fade or hovered then return 1 end
    return db.fadeAlpha or 0
end

function PanelDock.HandleAlpha(alpha)
    return math.max(alpha, HANDLE_FLOOR)
end

function PanelDock.HandleShown(root, merged)
    return root or not merged
end

local function SetAlpha(id, frame, alpha)
    pcall(frame.SetAlpha, frame, alpha)
    if frame.foldHandle then
        pcall(frame.foldHandle.SetAlpha, frame.foldHandle, PanelDock.HandleAlpha(alpha))
    end
    local merged = Lib().Dock.MergeFrame(id)
    if merged then merged:SetAlpha(alpha) end
end

function PanelDock.Hovered(id, frame)
    local lib = Lib()
    if not lib.dock.panels[id] then return frame:IsMouseOver() end
    return lib.Dock.Hovered(id)
end

local function Tick(id, frame, db)
    if not frame:IsShown() then return end
    SetAlpha(id, frame, PanelDock.FadeAlpha(PanelDock.Hovered(id, frame), db))
end

function PanelDock.Fade(id, frame, db)
    if tickers[frame] then
        tickers[frame]:Cancel()
        tickers[frame] = nil
    end
    if not db.fade then
        SetAlpha(id, frame, 1)
        return
    end
    tickers[frame] = C_Timer.NewTicker(TICK, function() Tick(id, frame, db) end)
    Tick(id, frame, db)
end

function PanelDock.Options(page, db, apply, id)
    assert(id, "PanelDock.Options needs a dock id")
    local dock = Lib().Dock
    local function Docked()
        return db.dockTo ~= nil
    end
    local group = page:Group("Docking")
    group:Check({ label = "Merge with docked panels", combatLocked = true,
        tooltip = function()
            local text = "Draws one shared background behind this panel and the panels docked to it, with no gap between them."
            if Docked() then text = text .. "\nSet on the panel this one is docked to." end
            if not Docked() and #dock.Members(id) == 0 then text = text .. "\nDock another panel to this one first." end
            return text
        end,
        get = function() return db.merge and true or false end,
        set = function(value)
            db.merge = value
            apply()
        end,
        enabled = function() return not Docked() and #dock.Members(id) > 0 end })
    group:Check({ label = "Show on mouse-over",
        tooltip = "Fades the panel and the panels docked to it until the mouse is over any of them.",
        get = function() return db.fade and true or false end,
        set = function(value)
            db.fade = value
            apply()
        end })
    group:Slider({ label = "Faded opacity", min = 0, max = 1, step = 0.05, format = "%.2f",
        tooltip = "How visible the panel stays while the mouse is away.",
        get = function() return db.fadeAlpha or 0 end,
        set = function(value)
            db.fadeAlpha = value
            apply()
        end,
        enabled = function() return db.fade and true or false end })
    group:Button({ label = "Undock", combatLocked = true,
        tooltip = "Detaches this panel from the panel it is docked to.",
        onClick = function()
            dock.Undock(id)
            apply()
        end,
        visible = Docked })
end
