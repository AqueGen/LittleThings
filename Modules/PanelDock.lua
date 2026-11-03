-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local PanelDock = {}
ns.PanelDock = PanelDock

local TICK = 0.1
local tickers = {}

local function Lib()
    return LibStub("LibVelvet-1.0")
end

function PanelDock.FadeAlpha(hovered, db)
    if not db.fade or hovered then return 1 end
    return db.fadeAlpha or 0
end

local function SetAlpha(id, frame, alpha)
    pcall(frame.SetAlpha, frame, alpha)
    local merged = Lib().Dock.MergeFrame(id)
    if merged then merged:SetAlpha(alpha) end
end

local function Tick(id, frame, db)
    if not frame:IsShown() then return end
    local lib = Lib()
    local hovered
    if lib.dock.panels[id] then hovered = lib.Dock.Hovered(id) else hovered = frame:IsMouseOver() end
    SetAlpha(id, frame, PanelDock.FadeAlpha(hovered, db))
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
