-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local PanelDock = {}
ns.PanelDock = PanelDock

local TICK = 0.1
local tickers, blocked = {}, {}

local function Dock()
    return LibStub("LibVelvet-1.0").Dock
end

function PanelDock.FadeAlpha(hovered, db)
    if not db.fade or hovered then return 1 end
    return db.fadeAlpha or 0
end

local function Tick(id, frame, db)
    if not frame:IsShown() then return end
    local combat = InCombatLockdown()
    if combat and blocked[frame] then return end
    local ok = pcall(frame.SetAlpha, frame, PanelDock.FadeAlpha(Dock().Hovered(id), db))
    if not ok and combat then blocked[frame] = true end
end

function PanelDock.Fade(id, frame, db)
    if tickers[frame] then
        tickers[frame]:Cancel()
        tickers[frame] = nil
    end
    if not db.fade then
        pcall(frame.SetAlpha, frame, 1)
        return
    end
    tickers[frame] = C_Timer.NewTicker(TICK, function() Tick(id, frame, db) end)
end

function PanelDock.Options(page, db, apply, id)
    local dock = Dock()
    local function Docked()
        return db.dockTo ~= nil
    end
    local group = page:Group("Docking")
    group:Check({ label = "Merge with docked panels", combatLocked = true,
        tooltip = "Draws one shared background behind this panel and the panels docked to it, with no gap between them.",
        get = function() return db.merge and true or false end,
        set = function(value)
            db.merge = value
            apply()
        end,
        enabled = function() return Docked() or #dock.Members(id) > 0 end })
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
