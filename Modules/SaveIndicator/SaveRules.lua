local _, ns = ...

local Rules = {}

Rules.MIN_DR = 20
-- A bare "%" in a NumericRuleFormatter format leaves the aura button empty in game.
Rules.PERCENT = "%%"
Rules.COLORS = { normal = "ff7dff6a", low = "ffff8a3d" }

function Rules.Buckets(data)
    local byDr = {}
    for id, entry in pairs(data) do
        if not entry.perStack and entry.dr >= Rules.MIN_DR then
            byDr[entry.dr] = byDr[entry.dr] or { dr = entry.dr, ids = {} }
            byDr[entry.dr].ids[id] = true
        end
    end
    local buckets = {}
    for _, bucket in pairs(byDr) do
        buckets[#buckets + 1] = bucket
    end
    table.sort(buckets, function(a, b) return a.dr > b.dr end)
    return buckets
end

function Rules.Stacked(data)
    local list = {}
    for id, entry in pairs(data) do
        if entry.perStack and entry.dr >= Rules.MIN_DR then
            list[#list + 1] = { id = id, dr = entry.dr, perStack = entry.perStack, maxStacks = entry.maxStacks }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Rules.AllIDs(data)
    local ids = {}
    for id, entry in pairs(data) do
        if entry.dr >= Rules.MIN_DR then
            ids[id] = true
        end
    end
    return ids
end

function Rules.CornerIDs(data, isBig)
    local ids = Rules.AllIDs(data)
    for id in pairs(ids) do
        if isBig(id) then
            ids[id] = nil
        end
    end
    return ids
end

function Rules.Label(dr)
    return string.format("-%d%%", dr)
end

function Rules.StackBreakpoints(perStack, maxStacks)
    local breakpoints = {}
    for n = 1, maxStacks do
        local dr = n * perStack
        local color = dr < Rules.MIN_DR and Rules.COLORS.low or Rules.COLORS.normal
        breakpoints[n] = { threshold = n, format = "|c" .. color .. "-" .. dr .. Rules.PERCENT .. "|r" }
    end
    return breakpoints
end

function Rules.Where(state)
    if state.instanceType == "pvp" or state.instanceType == "arena" then
        return false, false
    end
    if state.inRaid then
        return state.raidOn == true, false
    end
    return true, true
end

if ns then ns.SaveRules = Rules end
return Rules
