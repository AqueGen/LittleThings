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

function PanelDock.FadeAlpha(hovered, db, moving)
    if not db.fade or hovered or moving then return 1 end
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
    if not lib.dock.panels[id] then return frame:IsMouseOver() or (frame.hoverPart ~= nil and frame.hoverPart:IsMouseOver()) end
    return lib.Dock.Hovered(id)
end

function PanelDock.Align(raw, start, size, own, current, snap, hold)
    if current and math.abs(raw - current) <= snap + hold then return current end
    local best
    for _, c in ipairs({ start, start + size - own, start + (size - own) / 2 }) do
        if math.abs(raw - c) <= snap and (not best or math.abs(raw - c) < math.abs(raw - best)) then best = c end
    end
    return best
end

function PanelDock.Holds(side, x, y, raw, target, snap, hold)
    if side == "Below" or side == "Above" then
        return math.abs(raw.y - y) <= snap + hold and raw.x < target.x + target.w and raw.x + raw.w > target.x
    end
    return math.abs(raw.x - x) <= snap + hold and raw.y < target.y + target.h and raw.y + raw.h > target.y
end

local SNAP, HOLD = 16, 8
local seam
local seamGhost, seamTarget, held = {}, {}, { x = 0, y = 0, w = 0, h = 0 }

local function HeldRect(tid)
    local p = Lib().dock.panels[tid]
    local f = p and p.spec.frame
    if not (f and f:IsVisible() and f:GetLeft()) then return nil end
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    held.x, held.y = f:GetLeft() * s - UIParent:GetLeft(), UIParent:GetTop() - f:GetTop() * s
    held.w, held.h = f:GetWidth() * s, f:GetHeight() * s
    return held
end

local function SeamFrame()
    if seam then return seam end
    seam = CreateFrame("Frame", "LittleThingsDockSeam", UIParent)
    seam:SetFrameStrata("TOOLTIP")
    local line = seam:CreateTexture(nil, "OVERLAY")
    line:SetAllPoints()
    line:SetColorTexture(1, 0.82, 0, 0.8)
    seam:Hide()
    return seam
end

function PanelDock.ShowSeam(tid, side, left, top, w, h)
    local target = tid and side and Lib().dock.panels[tid]
    local f = target and target.spec.frame
    local tl, tt, tr, tb
    if f and f:IsVisible() then tl, tt, tr, tb = f:GetLeft(), f:GetTop(), f:GetRight(), f:GetBottom() end
    if not tl then
        if seam then seam:Hide() end
        return false
    end
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    seamTarget.l, seamTarget.t, seamTarget.r, seamTarget.b = tl * s, tt * s, tr * s, tb * s
    seamGhost.l, seamGhost.t, seamGhost.r, seamGhost.b = left, top, left + w, top - h
    local l, t, r, b = ns.PanelMove.SeamRect(side, seamGhost, seamTarget)
    local line = SeamFrame()
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    line:SetSize(r - l, t - b)
    line:Show()
    return true
end

local function Cursor()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

function PanelDock.GhostDrag(id, panel, opts)
    local mover = CreateFrame("Frame", opts.name, UIParent)
    mover:Hide()
    mover:SetClampedToScreen(true)
    mover:SetFrameStrata("TOOLTIP")
    local outline = mover:CreateTexture(nil, "OVERLAY")
    outline:SetAllPoints()
    outline:SetColorTexture(1, 0.82, 0, 0.3)
    local drag = { mover = mover, active = false }
    local rect = { x = 0, y = 0, w = 0, h = 0 }
    local stick = {}
    local grabX, grabY, lastX, lastY

    local function Stick()
        local t = stick.tid and HeldRect(stick.tid)
        if t and not PanelDock.Holds(stick.side, stick.x, stick.y, rect, t, SNAP, HOLD) then t = nil end
        local x, y = rect.x, rect.y
        if not t then
            stick.tid, stick.align = nil, nil
            local tid, side
            x, y, tid, side = Lib().Dock.Snap(id, rect)
            t = tid and HeldRect(tid)
            if not t then return x, y end
            stick.tid, stick.side, stick.x, stick.y = tid, side, x, y
        end
        if stick.side == "Below" or stick.side == "Above" then
            stick.align = PanelDock.Align(rect.x, t.x, t.w, rect.w, stick.align, SNAP, HOLD)
            return stick.align or rect.x, stick.y
        end
        stick.align = PanelDock.Align(rect.y, t.y, t.h, rect.h, stick.align, SNAP, HOLD)
        return stick.x, stick.align or rect.y
    end

    function drag.Follow()
        if not IsMouseButtonDown("LeftButton") then
            drag.Stop()
            return
        end
        local cx, cy = Cursor()
        if cx == lastX and cy == lastY then return end
        lastX, lastY = cx, cy
        local left, top = cx - grabX, cy - grabY
        if opts.snapped then
            rect.x, rect.y = left - UIParent:GetLeft(), UIParent:GetTop() - top
            local x, y = Stick()
            left, top = x + UIParent:GetLeft(), UIParent:GetTop() - y
        end
        mover:ClearAllPoints()
        mover:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        PanelDock.ShowSeam(stick.tid, stick.side, left, top, rect.w, rect.h)
    end
    function drag.Start()
        if drag.active or not ns.PanelMove.CanDrag(id) or not panel:GetLeft() then return end
        local s = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
        rect.w, rect.h = panel:GetWidth() * s, panel:GetHeight() * s
        mover:SetSize(rect.w, rect.h)
        mover:ClearAllPoints()
        mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", panel:GetLeft() * s, panel:GetBottom() * s)
        local cx, cy = Cursor()
        grabX, grabY, lastX, lastY = cx - panel:GetLeft() * s, cy - panel:GetTop() * s, cx, cy
        stick.tid, stick.align = nil, nil
        mover:Show()
        mover:SetScript("OnUpdate", drag.Follow)
        drag.active = true
    end
    function drag.Stop(hidden)
        if not drag.active then return end
        drag.active = false
        mover:SetScript("OnUpdate", nil)
        if seam then seam:Hide() end
        local deferred = hidden == true or InCombatLockdown()
        opts.release(mover, deferred)
        mover:Hide()
        if not deferred and opts.snapped then
            if not stick.tid then opts.snapped(Lib().Dock.Snap(id)) end
            Lib().Dock.Drop(id)
        end
        stick.tid, stick.align = nil, nil
        if opts.after then opts.after() end
    end
    return drag
end

local function Tick(id, frame, db)
    if not frame:IsShown() then return end
    SetAlpha(id, frame, PanelDock.FadeAlpha(PanelDock.Hovered(id, frame), db, ns.PanelMove and ns.PanelMove.Moving()))
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

function PanelDock.FadeOptions(group, db, apply)
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
end

function PanelDock.Options(page, db, apply, id)
    assert(id, "PanelDock.Options needs a dock id")
    local dock = Lib().Dock
    local function Docked()
        return db.dockTo ~= nil
    end
    local function GroupDb()
        local panels, cur, seen = Lib().dock.panels, db.dockTo, {}
        while cur and panels[cur] and not seen[cur] do
            seen[cur] = true
            local spec = panels[cur].spec
            if spec.root then return spec.get() end
            cur = spec.get().dockTo
        end
        return db
    end
    local function InGroup()
        return (Docked() and Lib().dock.panels[db.dockTo] ~= nil) or #dock.Members(id) > 0
    end
    local group = page:Group("Docking")
    group:Check({ label = "Merge with docked panels", combatLocked = true,
        tooltip = function()
            local text = "Draws one shared background behind the docked panels, with no gap between them. One setting for the whole group, on either panel's page."
            if not InGroup() then text = text .. "\nDock this panel to another one first." end
            return text
        end,
        get = function() return GroupDb().merge and true or false end,
        set = function(value)
            GroupDb().merge = value
            apply()
        end,
        enabled = InGroup })
    group:Button({ label = "Undock", combatLocked = true,
        tooltip = "Detaches this panel from the panel it is docked to.",
        onClick = function()
            dock.Undock(id)
            apply()
        end,
        visible = Docked })
end
