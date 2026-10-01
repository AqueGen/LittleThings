local _, ns = ...

local Rows = {}

local key

local function Compare(a, b)
    if key ~= "name" and a[key] ~= b[key] then
        return a[key] > b[key]
    end
    return a.sortName < b.sortName
end

function Rows.Comparator(sortKey)
    key = sortKey
    return Compare
end

if ns then ns.ProfilerRows = Rows end
return Rows
