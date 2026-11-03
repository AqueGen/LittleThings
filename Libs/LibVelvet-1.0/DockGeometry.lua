-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local lib = LibStub("LibVelvet-1.0")
if not lib.loading then return end

local G = {}
lib.DockGeometry = G

G.GAP = 6
G.SNAP = 16
local TOUCH = 2

local function right(r) return r.x + r.w end
local function bottom(r) return r.y + r.h end

local function closer(best, cand, dist)
    if math.abs(cand) > dist then return best end
    if best and math.abs(best) <= math.abs(cand) then return best end
    return cand
end

function G.SideOf(rect, target, gap)
    gap = gap or G.GAP
    if rect.y < bottom(target) and target.y < bottom(rect) then
        local e = math.abs(rect.x - right(target) - gap)
        if e <= TOUCH then return "Right", rect.y - target.y, e end
        e = math.abs(right(rect) + gap - target.x)
        if e <= TOUCH then return "Left", rect.y - target.y, e end
    end
    if rect.x < right(target) and target.x < right(rect) then
        local e = math.abs(rect.y - bottom(target) - gap)
        if e <= TOUCH then return "Below", rect.x - target.x, e end
        e = math.abs(bottom(rect) + gap - target.y)
        if e <= TOUCH then return "Above", rect.x - target.x, e end
    end
end

function G.Snap(rect, others, gap, dist)
    gap = gap or G.GAP
    dist = dist or G.SNAP
    local dx, dy
    for _, a in ipairs(others) do
        if rect.y - dist < bottom(a) and bottom(rect) + dist > a.y then
            for _, d in ipairs({ right(a) + gap - rect.x, a.x - gap - right(rect), a.x - rect.x, right(a) - right(rect) }) do
                dx = closer(dx, d, dist)
            end
        end
        if rect.x - dist < right(a) and right(rect) + dist > a.x then
            for _, d in ipairs({ bottom(a) + gap - rect.y, a.y - gap - bottom(rect), a.y - rect.y, bottom(a) - bottom(rect) }) do
                dy = closer(dy, d, dist)
            end
        end
    end
    local x, y = rect.x + (dx or 0), rect.y + (dy or 0)
    local snapped = { x = x, y = y, w = rect.w, h = rect.h }
    local best, bestErr, bestSide, bestOffset
    for _, a in ipairs(others) do
        local side, offset, err = G.SideOf(snapped, a, gap)
        if side and a.id ~= nil and (not bestErr or err < bestErr) then
            best, bestErr, bestSide, bestOffset = a.id, err, side, offset
        end
    end
    if best == nil then return x, y end
    return x, y, best, bestSide, bestOffset
end

function G.Group(rects, gap)
    local clusters, seen = {}, {}
    for i = 1, #rects do
        if not seen[i] then
            seen[i] = true
            local cluster, queue = { i }, { i }
            while #queue > 0 do
                local a = table.remove(queue, 1)
                for j = 1, #rects do
                    if not seen[j] and G.SideOf(rects[a], rects[j], gap) then
                        seen[j] = true
                        cluster[#cluster + 1] = j
                        queue[#queue + 1] = j
                    end
                end
            end
            table.sort(cluster)
            clusters[#clusters + 1] = cluster
        end
    end
    return clusters
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

function G.Drop(rects, moving, positions, gap, roots)
    gap = gap or G.GAP
    roots = roots or {}
    local out = {}
    local function posOf(id)
        return out[id] or positions[id]
    end
    for _, id in ipairs(sortedKeys(positions)) do
        local p, r = positions[id], rects[id]
        if not moving[id] and r and p.dockTo and moving[p.dockTo] then
            local target = rects[p.dockTo]
            if not (target and G.SideOf(r, target, gap)) then out[id] = { x = r.x, y = r.y } end
        end
    end
    local function leadsIntoMoving(id)
        local steps = 0
        while id and steps <= 64 do
            if moving[id] then return true end
            local p = posOf(id)
            id = p and p.dockTo
            steps = steps + 1
        end
        return false
    end
    local ids = sortedKeys(rects)
    for _, id in ipairs(ids) do
        if moving[id] then
            local r, p = rects[id], positions[id]
            local pos = { x = r.x, y = r.y }
            local side, offset
            if p and p.dockTo and moving[p.dockTo] and rects[p.dockTo] then
                side, offset = G.SideOf(r, rects[p.dockTo], gap)
                if side then pos.dockTo = p.dockTo end
            end
            if not side and not roots[id] then
                local bestErr
                for _, other in ipairs(ids) do
                    if not moving[other] and not leadsIntoMoving(other) then
                        local s, o, err = G.SideOf(r, rects[other], gap)
                        if s and (not bestErr or err < bestErr) then
                            pos.dockTo, side, offset, bestErr = other, s, o, err
                        end
                    end
                end
            end
            if side then pos.side, pos.offset = side, offset end
            out[id] = pos
        end
    end
    for _, rootId in ipairs(sortedKeys(roots)) do
        local root = roots[rootId] and moving[rootId] and rects[rootId]
        if root then
            for _, id in ipairs(ids) do
                if not moving[id] and not roots[id] then
                    local r, p = rects[id], posOf(id)
                    local held = p and p.dockTo and rects[p.dockTo] and G.SideOf(r, rects[p.dockTo], gap)
                    local side, offset = G.SideOf(r, root, gap)
                    if side and not held and not leadsIntoMoving(id) then
                        out[id] = { x = r.x, y = r.y, dockTo = rootId, side = side, offset = offset }
                    end
                end
            end
        end
    end
    return out
end

function G.Clamp(rect, screen)
    local x = math.min(rect.x, right(screen) - rect.w)
    x = math.max(x, screen.x)
    local y = math.min(rect.y, bottom(screen) - rect.h)
    y = math.max(y, screen.y)
    return x, y
end

local function placed(pos, target, size, gap)
    local x, y
    if pos.side == "Right" then x, y = right(target) + gap, target.y + pos.offset
    elseif pos.side == "Left" then x, y = target.x - gap - size.w, target.y + pos.offset
    elseif pos.side == "Below" then x, y = target.x + pos.offset, bottom(target) + gap
    else x, y = target.x + pos.offset, target.y - gap - size.h end
    return x, y
end

function G.Resolve(positions, sizes, screen, gap)
    gap = gap or G.GAP
    local rects, busy = {}, {}
    local function resolve(id)
        if rects[id] then return rects[id] end
        local pos, size = positions[id], sizes[id]
        if not pos or not size then return nil end
        busy[id] = true
        local x, y = pos.x, pos.y
        if pos.dockTo and not busy[pos.dockTo] then
            local target = resolve(pos.dockTo)
            if target then x, y = placed(pos, target, size, gap) end
        end
        busy[id] = nil
        local r = { x = x, y = y, w = size.w, h = size.h }
        if screen then r.x, r.y = G.Clamp(r, screen) end
        rects[id] = r
        return r
    end
    for id in pairs(positions) do resolve(id) end
    return rects
end
