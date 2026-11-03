-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local PanelDock = {}
ns.PanelDock = PanelDock

local TICK, ARROW_GAP = 0.1, 2
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

local function ArrowOver(frame)
    return frame.dockArrow ~= nil and frame.dockArrow:IsMouseOver()
end

local function Group(lib, id)
    local panels, cur, seen = lib.dock.panels, id, {}
    while not panels[cur].spec.root and not seen[cur] do
        seen[cur] = true
        local to = panels[cur].spec.get().dockTo
        if not (to and panels[to]) then break end
        cur = to
    end
    local ids = lib.Dock.Members(cur)
    ids[#ids + 1] = cur
    return ids
end

function PanelDock.Hovered(id, frame)
    local lib = Lib()
    if not lib.dock.panels[id] then return frame:IsMouseOver() or ArrowOver(frame) end
    if lib.Dock.Hovered(id) then return true end
    for _, gid in ipairs(Group(lib, id)) do
        local f = lib.dock.panels[gid].spec.frame
        if f:IsShown() and ArrowOver(f) then return true end
    end
    return false
end

local SIDES = { "above", "below", "right", "left" }
local OWN_EDGE = { Right = "left", Left = "right", Below = "above", Above = "below" }
local TARGET_EDGE = { Right = "right", Left = "left", Below = "below", Above = "above" }

function PanelDock.ArrowSide(blocked, room)
    for _, side in ipairs(SIDES) do
        if not blocked[side] and room[side] then return side end
    end
end

function PanelDock.Blocked(id)
    local panels, blocked = Lib().dock.panels, {}
    local p = panels[id]
    if not p then return blocked end
    local pos = p.spec.get()
    if not p.spec.root and pos.dockTo and panels[pos.dockTo] and OWN_EDGE[pos.side or ""] then
        blocked[OWN_EDGE[pos.side]] = true
    end
    for other, q in pairs(panels) do
        local o = other ~= id and not q.spec.root and q.spec.get()
        if o and o.dockTo == id and TARGET_EDGE[o.side or ""] then blocked[TARGET_EDGE[o.side]] = true end
    end
    return blocked
end

local function GroupBounds(id, top, bottom)
    local lib = Lib()
    if not lib.dock.panels[id] then return top, bottom end
    for _, gid in ipairs(Group(lib, id)) do
        local f = lib.dock.panels[gid].spec.frame
        local t, b = f:IsShown() and f:GetTop(), f:GetBottom()
        if t and b then
            local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
            top, bottom = math.max(top, t * s), math.min(bottom, b * s)
        end
    end
    return top, bottom
end

function PanelDock.PlaceArrow(arrow, panel, id, fullW, fullH)
    local scale = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local w, h = fullW or panel:GetWidth(), fullH or panel:GetHeight()
    local left, top = panel:GetLeft(), panel:GetTop()
    local side, extra = "above", 0
    if left and top then
        local l, t = left * scale, top * scale
        local r, b = l + w * scale, t - h * scale
        local up, across = (arrow:GetHeight() + ARROW_GAP) * scale, (arrow:GetWidth() + ARROW_GAP) * scale
        side = PanelDock.ArrowSide(PanelDock.Blocked(id), {
            above = UIParent:GetTop() - t >= up, below = b - UIParent:GetBottom() >= up,
            right = UIParent:GetRight() - r >= across, left = l - UIParent:GetLeft() >= across })
        if not side then
            local gt, gb = GroupBounds(id, t, b)
            if UIParent:GetTop() - gt >= up then
                side, extra = "above", (gt - t) / scale
            else
                side, extra = "below", (b - gb) / scale
            end
        end
    end
    arrow:ClearAllPoints()
    if side == "below" then
        arrow:SetPoint("TOPRIGHT", panel, "TOPLEFT", w, -(h + ARROW_GAP + extra))
    elseif side == "right" then
        arrow:SetPoint("TOPLEFT", panel, "TOPLEFT", w + ARROW_GAP, 0)
    elseif side == "left" then
        arrow:SetPoint("TOPRIGHT", panel, "TOPLEFT", -ARROW_GAP, 0)
    else
        arrow:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", w, ARROW_GAP + extra)
    end
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
