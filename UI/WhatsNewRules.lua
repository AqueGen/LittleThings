-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local _, ns = ...

local Rules = {}

-- Profiles saved before seenModules existed fall back to the switches they carry.
function Rules.NewRows(savedDb, modules)
    local rows = {}
    if savedDb == nil then return rows end
    local seen = savedDb.seenModules
    for _, row in ipairs(modules) do
        local known
        if seen then
            known = seen[row.key]
        else
            known = savedDb[row.key] ~= nil
        end
        if not known then
            rows[#rows + 1] = row
        end
    end
    return rows
end

function Rules.MarkSeen(savedDb, modules)
    savedDb.seenModules = savedDb.seenModules or {}
    for _, row in ipairs(modules) do
        savedDb.seenModules[row.key] = true
    end
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
