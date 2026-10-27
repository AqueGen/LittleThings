local _, ns = ...

local Rules = {}

Rules.MIN_DR = 20
-- A bare "%" in a NumericRuleFormatter format leaves the aura button empty in game.
Rules.PERCENT = "%%"
Rules.COLORS = { normal = "ff7dff6a", low = "ffff8a3d", other = "ff66ccff" }

local KIND_ORDER = { full = 1, phys = 2, magic = 3, shield = 4 }

local function Kind(entry)
    if entry.shield then return "shield" end
    return entry.school or "full"
end

function Rules.Text(entry)
    local kind = Kind(entry)
    return kind == "full" and Rules.Label(entry.dr) or kind
end

local function Counts(entry)
    return entry.shield == true or (entry.dr ~= nil and entry.dr >= Rules.MIN_DR)
end

function Rules.Buckets(data)
    local byDr = {}
    for id, entry in pairs(data) do
        if Kind(entry) == "full" and not entry.perStack and Counts(entry) then
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
        if entry.perStack and Counts(entry) then
            list[#list + 1] = { id = id, dr = entry.dr, perStack = entry.perStack, maxStacks = entry.maxStacks }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Rules.Row(data)
    local row = {}
    for _, s in ipairs(Rules.Stacked(data)) do
        row[#row + 1] = { kind = "full", ids = { [s.id] = true }, dr = s.dr, perStack = s.perStack, maxStacks = s.maxStacks,
            text = Rules.Label(s.dr), color = Rules.COLORS.normal }
    end
    for _, b in ipairs(Rules.Buckets(data)) do
        row[#row + 1] = { kind = "full", ids = b.ids, dr = b.dr, text = Rules.Label(b.dr), color = Rules.COLORS.normal }
    end
    local other = {}
    for id, entry in pairs(data) do
        local kind = Kind(entry)
        if kind ~= "full" and Counts(entry) then
            other[kind] = other[kind] or { kind = kind, ids = {}, dr = 0, text = kind, color = Rules.COLORS.other }
            other[kind].ids[id] = true
        end
    end
    for _, bucket in pairs(other) do
        row[#row + 1] = bucket
    end
    table.sort(row, function(a, b)
        if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
        if a.dr ~= b.dr then return a.dr > b.dr end
        return a.perStack ~= nil and b.perStack == nil
    end)
    return row
end

function Rules.AllIDs(data)
    local ids = {}
    for id, entry in pairs(data) do
        if Counts(entry) then
            ids[id] = true
        end
    end
    return ids
end

function Rules.Enabled(data, off)
    local on = {}
    for id, entry in pairs(data) do
        if not off[id] then
            on[id] = entry
        end
    end
    return on
end

function Rules.Groups(data, class)
    local groups = { yours = {}, external = {} }
    for id, entry in pairs(data) do
        local list = entry.class == class and groups.yours or entry.external and groups.external
        if list then list[#list + 1] = id end
    end
    for _, list in pairs(groups) do
        table.sort(list, function(a, b) return data[a].name < data[b].name end)
    end
    return groups
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

function Rules.CenterOffset(cx, cy, ux, uy, scale)
    return math.floor(cx - ux / scale + 0.5), math.floor(cy - uy / scale + 0.5)
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
