local _, ns = ...

local Preset = {}

local function Diff(targets, get, wanted)
    local changes = {}
    for _, target in ipairs(targets) do
        local from, to = get(target.cvar), wanted(target)
        if from ~= nil and to ~= nil and from ~= to then
            changes[#changes + 1] = { cvar = target.cvar, from = from, to = to }
        end
    end
    return changes
end

function Preset.Changes(targets, get)
    return Diff(targets, get, function(target) return target.value end)
end

function Preset.Remember(backup, targets, get)
    backup = backup or {}
    for _, target in ipairs(targets) do
        if backup[target.cvar] == nil then
            backup[target.cvar] = get(target.cvar)
        end
    end
    return backup
end

function Preset.Restores(backup, targets, get)
    if not backup then
        return {}
    end
    return Diff(targets, get, function(target) return backup[target.cvar] end)
end

if ns then ns.GraphicsPreset = Preset end
return Preset
