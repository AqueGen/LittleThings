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

function Rows.Sort(rows, sortKey)
    for _, row in ipairs(rows) do
        row.sortName = row.sortName or row.name:lower()
    end
    table.sort(rows, Rows.Comparator(sortKey))
    return rows
end

if ns then ns.ProfilerRows = Rows end
return Rows
