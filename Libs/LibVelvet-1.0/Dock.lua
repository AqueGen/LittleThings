-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local lib = LibStub("LibVelvet-1.0")
if not lib.loading then return end

local D = lib.DockGeometry
lib.dock = lib.dock or { panels = {} }
local panels = lib.dock.panels
local Dock = {}
lib.Dock = Dock

local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }

local function scaleOf(f)
    return f:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function rectOf(f)
    if not (f:GetLeft() and f:GetTop()) then return nil end
    local s = scaleOf(f)
    return {
        x = f:GetLeft() * s - UIParent:GetLeft(), y = UIParent:GetTop() - f:GetTop() * s,
        w = f:GetWidth() * s, h = f:GetHeight() * s,
    }
end

local function place(f, x, y)
    local s = scaleOf(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / s, -y / s)
end

local function round(v)
    return math.floor(v + 0.5)
end

local function topOf(id)
    local seen = {}
    while panels[id] and not seen[id] do
        seen[id] = true
        local spec = panels[id].spec
        local to = not spec.root and spec.get().dockTo
        if not (to and panels[to]) then return id end
        id = to
    end
    return id
end

local function mergedOf(id)
    local top = panels[topOf(id)]
    return top ~= nil and top.spec.root == true and top.spec.merged ~= nil and top.spec.merged() == true
end

local function gapOf(id)
    return mergedOf(id) and 0 or D.GAP
end

function Dock.Register(id, spec)
    if panels[id] then panels[id].spec = spec else panels[id] = { spec = spec } end
end

function Dock.Unregister(id)
    local p = panels[id]
    if p and p.mergeFrame then p.mergeFrame:Hide() end
    panels[id] = nil
end

function Dock.Members(rootId)
    local out = {}
    for id in pairs(panels) do
        if id ~= rootId and not panels[id].spec.root then
            local seen, cur = { [id] = true }, panels[id].spec.get().dockTo
            while cur and panels[cur] and not seen[cur] do
                if cur == rootId then
                    out[#out + 1] = id
                    break
                end
                if panels[cur].spec.root then break end
                seen[cur] = true
                cur = panels[cur].spec.get().dockTo
            end
        end
    end
    return out
end

function Dock.CanDrag(id)
    local p = panels[id]
    return p ~= nil and not InCombatLockdown() and not p.spec.locked()
end

local EDGES = {
    Right = function(g, o) return "TOPLEFT", "TOPRIGHT", g, -o end,
    Left = function(g, o) return "TOPRIGHT", "TOPLEFT", -g, -o end,
    Below = function(g, o) return "TOPLEFT", "BOTTOMLEFT", o, -g end,
    Above = function(g, o) return "BOTTOMLEFT", "TOPLEFT", o, g end,
}

function Dock.Apply(id)
    local p = panels[id]
    if not p or p.spec.root or InCombatLockdown() then return end
    local pos = p.spec.get()
    local target, edge = pos.dockTo and panels[pos.dockTo], EDGES[pos.side or ""]
    if not (target and edge and target.spec.frame:IsShown()) then return end
    local seen, cur = { [id] = true }, pos.dockTo
    while cur do
        if seen[cur] then return end
        seen[cur] = true
        cur = panels[cur] and not panels[cur].spec.root and panels[cur].spec.get().dockTo
    end
    local frame, s = p.spec.frame, scaleOf(p.spec.frame)
    local point, relPoint, x, y = edge(gapOf(id) / s, (pos.offset or 0) / s)
    frame:ClearAllPoints()
    frame:SetPoint(point, target.spec.frame, relPoint, x, y)
end

local function movingSet(id)
    local moving = { [id] = true }
    if panels[id].spec.root then
        for _, m in ipairs(Dock.Members(id)) do moving[m] = true end
    end
    return moving
end

local function collect(skip)
    local rects, list = {}, {}
    for id, p in pairs(panels) do
        local r = p.spec.frame:IsShown() and rectOf(p.spec.frame)
        if r then
            rects[id] = r
            if not (skip and skip[id]) then list[#list + 1] = { id = id, x = r.x, y = r.y, w = r.w, h = r.h } end
        end
    end
    return rects, list
end

function Dock.Snap(id)
    local p = panels[id]
    local mine = rectOf(p.spec.frame)
    local skip = movingSet(id)
    for _, m in ipairs(Dock.Members(id)) do skip[m] = true end
    local _, list = collect(skip)
    if p.spec.root then
        if #list == 0 then return mine.x, mine.y end
        local x, y = D.Snap(mine, list, gapOf(id), D.SNAP, false)
        return x, y
    end
    local best
    for _, merged in ipairs({ false, true }) do
        local subset = {}
        for _, o in ipairs(list) do
            if mergedOf(o.id) == merged then subset[#subset + 1] = o end
        end
        if #subset > 0 then
            local x, y, tid = D.Snap(mine, subset, merged and 0 or D.GAP, D.SNAP)
            local disp = math.abs(x - mine.x) + math.abs(y - mine.y)
            if not best or (tid ~= nil and best.tid == nil) or (tid ~= nil) == (best.tid ~= nil) and disp < best.disp then
                best = { x = x, y = y, tid = tid, disp = disp }
            end
        end
    end
    if not best then return mine.x, mine.y end
    return best.x, best.y
end

local function dropOut(id, moving, rects, positions, roots)
    if panels[id].spec.root then
        return D.Drop(rects, moving, positions, gapOf(id), roots)
    end
    for _, gap in ipairs({ D.GAP, 0 }) do
        local out = D.Drop(rects, moving, positions, gap, roots)
        local to = out[id] and out[id].dockTo
        if to and gapOf(to) == gap then return out end
    end
    return D.Drop(rects, moving, positions, D.GAP, roots)
end

function Dock.Drop(id)
    local p = panels[id]
    if not p or InCombatLockdown() then return end
    local moving = movingSet(id)
    local rects = collect()
    local positions, roots = {}, {}
    for pid, q in pairs(panels) do
        if rects[pid] then
            local pos = q.spec.get()
            positions[pid] = { x = rects[pid].x, y = rects[pid].y, dockTo = pos.dockTo, side = pos.side, offset = pos.offset }
            roots[pid] = q.spec.root or nil
        end
    end
    local out = dropOut(id, moving, rects, positions, roots)
    local touched = {}
    for pid, o in pairs(out) do
        local q = panels[pid]
        local pos = q.spec.get()
        local wasDocked = pos.dockTo ~= nil
        local old = positions[pid]
        if moving[pid] and not o.dockTo and old.dockTo and moving[old.dockTo] then
            o.dockTo, o.side, o.offset = old.dockTo, old.side, old.offset
        end
        pos.dockTo, pos.side, pos.offset = o.dockTo, o.side, o.offset and round(o.offset)
        q.spec.set(pos)
        if wasDocked and not o.dockTo and not q.spec.root then place(q.spec.frame, rects[pid].x, rects[pid].y) end
        touched[pid] = true
    end
    for m in pairs(moving) do touched[m] = true end
    for pid in pairs(touched) do Dock.Apply(pid) end
    for pid in pairs(out) do
        if panels[pid].spec.onChange then panels[pid].spec.onChange() end
    end
    for pid, q in pairs(panels) do
        if q.spec.root then Dock.RefreshMerge(pid) end
    end
end

function Dock.Undock(id)
    local p = panels[id]
    if not p or InCombatLockdown() then return end
    local f = p.spec.frame
    local r = rectOf(f)
    local pos = p.spec.get()
    pos.dockTo, pos.side, pos.offset = nil, nil, nil
    p.spec.set(pos)
    if r and not p.spec.root then place(f, r.x, r.y) end
    if p.spec.onChange then p.spec.onChange() end
end

function Dock.Merged(rootId)
    local p = panels[rootId]
    return p ~= nil and p.spec.merged ~= nil and p.spec.merged() == true
end

local function groupOf(rootId)
    local ids = Dock.Members(rootId)
    ids[#ids + 1] = rootId
    return ids
end

function Dock.RefreshMerge(rootId)
    local p = panels[rootId]
    if not p or p.refreshing or InCombatLockdown() then return end
    local ids, shown = groupOf(rootId), {}
    for _, id in ipairs(ids) do
        local f = panels[id].spec.frame
        local r = f:IsShown() and rectOf(f)
        if r then shown[#shown + 1] = { id = id, frame = f, r = r } end
    end
    local on = Dock.Merged(rootId) and #shown > 1
    if on then
        local frame = p.mergeFrame
        if not frame then
            frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            frame:EnableMouse(false)
            frame:SetBackdrop(lib.FLAT)
            frame:SetBackdropColor(unpack(lib.T.bg))
            frame:SetBackdropBorderColor(unpack(lib.T.border))
            p.mergeFrame = frame
        end
        local left, top, right, bottom, low, level = shown[1], shown[1], shown[1], shown[1], 99, 99
        for _, s in ipairs(shown) do
            if s.r.x < left.r.x then left = s end
            if s.r.y < top.r.y then top = s end
            if s.r.x + s.r.w > right.r.x + right.r.w then right = s end
            if s.r.y + s.r.h > bottom.r.y + bottom.r.h then bottom = s end
            level = math.min(level, s.frame:GetFrameLevel())
            for i, name in ipairs(STRATA) do
                if name == s.frame:GetFrameStrata() and i < low then low = i end
            end
        end
        frame:SetFrameStrata(STRATA[math.max(1, low - 1)])
        frame:SetFrameLevel(math.max(0, level - 1))
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", left.frame, "TOPLEFT", 0, left.r.y - top.r.y)
        frame:SetPoint("BOTTOMRIGHT", right.frame, "BOTTOMRIGHT", 0,
            right.r.y + right.r.h - bottom.r.y - bottom.r.h)
        frame:Show()
    elseif p.mergeFrame then
        p.mergeFrame:Hide()
    end
    if p.mergeOn ~= on then
        p.mergeOn = on
        p.refreshing = true
        for _, id in ipairs(ids) do
            local change = panels[id].spec.onChange
            if change then change() end
        end
        p.refreshing = nil
    end
end

function Dock.MergeFrame(id)
    local p = panels[topOf(id)]
    local frame = p and p.mergeFrame
    return frame and frame:IsShown() and frame or nil
end

function Dock.Hovered(id)
    local top = topOf(id)
    local p = panels[top]
    if not p then return false end
    for _, gid in ipairs(groupOf(top)) do
        local f = panels[gid].spec.frame
        if f:IsShown() and f:IsMouseOver() then return true end
    end
    return p.mergeFrame ~= nil and p.mergeFrame:IsShown() and p.mergeFrame:IsMouseOver()
end

function Dock.Arrow(parent, onClick, id)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(14, 14)
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject("GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetTextColor(unpack(lib.T.muted))
    fs:SetText("v")
    b:SetFontString(fs)
    b:SetScript("OnClick", onClick)
    b:Hide()
    function b:SetCollapsed(collapsed)
        fs:SetText(collapsed and ">" or "v")
    end
    parent:HookScript("OnUpdate", function()
        b:SetShown((id ~= nil and Dock.Hovered(id)) or parent:IsMouseOver() or b:IsMouseOver())
    end)
    return b
end
