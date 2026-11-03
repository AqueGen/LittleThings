-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local PanelMove = {}
ns.PanelMove = PanelMove

local LOCK, TICK, SEAM = 16, 0.1, 1
local GOLD = { 1, 0.82, 0, 1 }

local MODULES = { "raidMarkers", "partyCalls", "saveIndicator" }
local panels, order, unlocked, overlays, seams = {}, {}, {}, {}, {}
local NO_DOCKS = {}
local EDGES = {
    top = { "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", 0, -1 },
    bottom = { "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", 0, 1 },
    left = { "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", 1, 0 },
    right = { "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", -1, 0 },
}
local moving, hoverId = false, nil
local bar, lock, catcher, events

function PanelMove.Draggable(combat, mode, open)
    return not combat and (mode or open) == true
end

function PanelMove.LockSpot(l, t, r, b, screenTop, inset)
    if inset then return "TOPLEFT", l + inset, t end
    if screenTop - t >= LOCK then return "BOTTOMRIGHT", r, t end
    return "TOPRIGHT", r, b
end

function PanelMove.SeamRect(side, m, t)
    if side == "Below" or side == "Above" then
        local c = math.floor(side == "Below" and (t.b + m.t) / 2 or (t.t + m.b) / 2)
        return math.max(m.l, t.l), c + SEAM, math.min(m.r, t.r), c
    end
    local c = math.floor(side == "Right" and (t.r + m.l) / 2 or (t.l + m.r) / 2)
    return c, math.min(m.t, t.t), c + SEAM, math.max(m.b, t.b)
end

local MEMBER_SIDE = { Below = "top", Above = "bottom", Right = "left", Left = "right" }
local TARGET_SIDE = { Below = "bottom", Above = "top", Right = "right", Left = "left" }

function PanelMove.SharedSides(id, docks)
    local shared = {}
    local own = docks[id]
    if own and own.dockTo and MEMBER_SIDE[own.side or ""] then shared[MEMBER_SIDE[own.side]] = true end
    for other, d in pairs(docks) do
        if other ~= id and d.dockTo == id and TARGET_SIDE[d.side or ""] then shared[TARGET_SIDE[d.side]] = true end
    end
    return shared
end

function PanelMove.CanDrag(id)
    return PanelMove.Draggable(InCombatLockdown(), moving, unlocked[id] == true)
end

function PanelMove.Moving()
    return moving
end

function PanelMove.Available(isOn)
    for _, key in ipairs(MODULES) do
        if isOn(key) then return true end
    end
    return false
end

local function Notify()
    if ns.Window then ns.Window.Refresh() end
end

local function Rect(f)
    local l, t, r, b = f:GetLeft(), f:GetTop(), f:GetRight(), f:GetBottom()
    if not (l and t and r and b) then return nil end
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * s, t * s, r * s, b * s, s
end

local function Shown(id)
    local f = panels[id].frame()
    return f and f:IsVisible() and f or nil
end

local function Overlay(id)
    local o = overlays[id]
    if o then return o end
    o = CreateFrame("Frame", "LittleThingsMoveOutline" .. id, UIParent)
    o:SetFrameStrata("FULLSCREEN_DIALOG")
    o.edges = {}
    for side, pts in pairs(EDGES) do
        local e = o:CreateTexture(nil, "OVERLAY")
        e:SetPoint(pts[1], o, pts[1], 0, 0)
        e:SetPoint(pts[2], o, pts[3], pts[4], pts[5])
        e:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], GOLD[4])
        o.edges[side] = e
    end
    o.label = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    o.label:SetText(panels[id].name)
    overlays[id] = o
    return o
end

local function Docks()
    local docks = {}
    local lib = LibStub and LibStub("LibVelvet-1.0", true)
    for id, p in pairs(lib and lib.dock and lib.dock.panels or {}) do
        local pos = p.spec.get and p.spec.get()
        if pos and p.spec.frame then docks[id] = pos end
    end
    return docks, lib
end

local function RectOf(f)
    local l, t, r, b = Rect(f)
    return l and { l = l, t = t, r = r, b = b } or nil
end

local function Seam(id)
    local s = seams[id]
    if s then return s end
    s = CreateFrame("Frame", "LittleThingsMoveSeam" .. id, UIParent)
    s:SetFrameStrata("TOOLTIP")
    local line = s:CreateTexture(nil, "OVERLAY")
    line:SetAllPoints()
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
    seams[id] = s
    return s
end

local function PaintSeams(combat, docks, lib)
    for _, s in pairs(seams) do s.wanted = false end
    if moving and not combat then
        for id, pos in pairs(docks) do
            local target = pos.dockTo and lib.dock.panels[pos.dockTo]
            local mf, tf = lib.dock.panels[id].spec.frame, target and target.spec.frame
            local m, t = mf:IsVisible() and RectOf(mf), tf and tf:IsVisible() and RectOf(tf)
            if m and t and pos.side then
                local l, top, r, b = PanelMove.SeamRect(pos.side, m, t)
                local s = Seam(id)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, top)
                s:SetSize(r - l, top - b)
                s.wanted = true
            end
        end
    end
    for _, s in pairs(seams) do s:SetShown(s.wanted) end
end

local function PaintOverlays(combat)
    local docks, lib = NO_DOCKS, nil
    if not combat and (moving or next(unlocked)) then docks, lib = Docks() end
    PaintSeams(combat, docks, lib)
    for _, id in ipairs(order) do
        local f = not combat and (moving or unlocked[id]) and Shown(id)
        local l, t, r, b
        if f then l, t, r, b = Rect(f) end
        if l then
            local o = Overlay(id)
            local shared = PanelMove.SharedSides(id, docks)
            for side, e in pairs(o.edges) do e:SetShown(not shared[side]) end
            o.label:ClearAllPoints()
            if not shared.top then
                o.label:SetPoint("BOTTOMLEFT", o, "TOPLEFT", 0, 2)
            else
                o.label:SetPoint("TOPLEFT", o, "BOTTOMLEFT", 0, -2)
            end
            o:ClearAllPoints()
            o:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
            o:SetSize(r - l, t - b)
            o:Show()
        elseif overlays[id] then
            overlays[id]:Hide()
        end
    end
end

local function BuildLock()
    lock = CreateFrame("Button", "LittleThingsMoveLock", UIParent)
    lock:SetSize(LOCK, LOCK)
    lock:SetFrameStrata("FULLSCREEN_DIALOG")
    lock.icon = lock:CreateTexture(nil, "ARTWORK")
    lock.icon:SetAllPoints()
    lock.icon:SetAtlas("QuestSharing-Padlock")
    lock:RegisterForClicks("LeftButtonUp")
    lock:SetScript("OnClick", function()
        if hoverId then PanelMove.SetUnlocked(hoverId, not unlocked[hoverId]) end
    end)
    lock:Hide()
end

local function Owner(id)
    local owner = panels[id].owner and panels[id].owner()
    return owner and panels[owner] and owner or id
end

local function Hovered()
    if lock and lock:IsShown() and lock:IsMouseOver() then return hoverId end
    for _, id in ipairs(order) do
        local f = Shown(id)
        if f and f:IsMouseOver() then return Owner(id) end
    end
end

local function PaintLock(combat)
    local id = not combat and not moving and Hovered()
    local f = id and Shown(id)
    local l, t, r, b, s
    if f then l, t, r, b, s = Rect(f) end
    hoverId = l and id or nil
    if not hoverId then
        if lock then lock:Hide() end
        return
    end
    if not lock then BuildLock() end
    local strip = panels[hoverId].strip
    local size = strip and LOCK * s or LOCK
    lock:SetSize(size, size)
    lock:ClearAllPoints()
    local point, x, y = PanelMove.LockSpot(l, t, r, b, UIParent:GetTop(), strip and (strip - LOCK) / 2 * s)
    lock:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
    local color = unlocked[hoverId] and GOLD or { 1, 1, 1 }
    lock.icon:SetVertexColor(color[1], color[2], color[3])
    lock:Show()
end

local function Tick()
    local combat = InCombatLockdown()
    PaintLock(combat)
    PaintOverlays(combat)
end

local function BuildCatcher()
    catcher = CreateFrame("Frame", "LittleThingsPanelUnlock", UIParent)
    catcher:Hide()
    catcher:SetScript("OnHide", function() PanelMove.LockAll() end)
    tinsert(UISpecialFrames, "LittleThingsPanelUnlock")
end

local function BarButton(text, x, onClick)
    local b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    b:SetSize(130, 22)
    b:SetPoint("BOTTOM", bar, "BOTTOM", x, 8)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
end

local function BuildBar()
    bar = CreateFrame("Frame", "LittleThingsMovePanels", UIParent, "BackdropTemplate")
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:SetPoint("TOP", UIParent, "TOP", 0, -40)
    bar:SetSize(300, 60)
    bar:SetBackdrop(ns.Widgets.FLAT)
    bar:SetBackdropColor(0, 0, 0, 0.85)
    bar:SetBackdropBorderColor(unpack(GOLD))
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOP", bar, "TOP", 0, -8)
    text:SetText("Moving LittleThings panels")
    BarButton("Reset positions", -68, function() PanelMove.ResetAll() end)
    BarButton("Done", 68, function() PanelMove.Stop() end)
    bar:Hide()
    bar:SetScript("OnHide", function() PanelMove.Stop() end)
    tinsert(UISpecialFrames, "LittleThingsMovePanels")
    if not catcher then BuildCatcher() end
end

function PanelMove.SetUnlocked(id, on)
    if not panels[id] then return end
    if not on then panels[id].stopDrag() end
    unlocked[id] = on or nil
    if not catcher then BuildCatcher() end
    catcher:SetShown(next(unlocked) ~= nil)
    Tick()
end

function PanelMove.LockAll()
    for id in pairs(unlocked) do panels[id].stopDrag() end
    unlocked = {}
    if catcher then catcher:Hide() end
    Tick()
end

function PanelMove.Start()
    if moving then return end
    if InCombatLockdown() then
        ns.Print("Move panels is available out of combat only.")
        return
    end
    moving = true
    if not bar then BuildBar() end
    bar:Show()
    for _, id in ipairs(order) do panels[id].setMoving(true) end
    Tick()
    Notify()
end

function PanelMove.Stop()
    if not moving then return end
    moving = false
    for _, id in ipairs(order) do
        panels[id].stopDrag()
        panels[id].setMoving(false)
    end
    bar:Hide()
    Tick()
    Notify()
end

function PanelMove.Toggle()
    if moving then PanelMove.Stop() else PanelMove.Start() end
end

function PanelMove.ResetAll()
    for _, id in ipairs(order) do panels[id].reset() end
    Tick()
end

function PanelMove.Register(id, spec)
    if not panels[id] then order[#order + 1] = id end
    panels[id] = spec
    if events then return end
    events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function()
        PanelMove.Stop()
        PanelMove.LockAll()
    end)
    C_Timer.NewTicker(TICK, Tick)
end
