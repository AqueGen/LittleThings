local _, ns = ...

local Rules = {}

function Rules.NewRows(savedDb, modules)
    local rows = {}
    if savedDb == nil then return rows end
    for _, row in ipairs(modules) do
        if savedDb[row.key] == nil then
            rows[#rows + 1] = row
        end
    end
    return rows
end

function Rules.Title(row, modules)
    for _, parent in ipairs(modules) do
        if row.parent and parent.key == row.parent then
            return parent.label .. ": " .. row.label
        end
    end
    return row.label
end

if ns then ns.WhatsNewRules = Rules end
return Rules
