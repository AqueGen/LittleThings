local _, ns = ...

local Rows = {}

function Rows.Sort(rows, key)
    table.sort(rows, function(a, b)
        if key ~= "name" and a[key] ~= b[key] then
            return a[key] > b[key]
        end
        return a.name:lower() < b.name:lower()
    end)
    return rows
end

if ns then ns.ProfilerRows = Rows end
return Rows
