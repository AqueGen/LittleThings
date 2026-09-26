local _, ns = ...

local Rules = {}

Rules.NEED = "need"
Rules.EXCLUDE = "exclude"

function Rules.Next(state)
    if state == nil then return Rules.NEED end
    if state == Rules.NEED then return Rules.EXCLUDE end
    return nil
end

function Rules.IsActive(states)
    return next(states) ~= nil
end

function Rules.Passes(classes, states)
    local wantsAny, hasWanted = false, false
    for _, state in pairs(states) do
        if state == Rules.NEED then
            wantsAny = true
            break
        end
    end

    for _, class in ipairs(classes) do
        local state = states[class]
        if state == Rules.EXCLUDE then return false end
        if state == Rules.NEED then hasWanted = true end
    end

    return hasWanted or not wantsAny
end

function Rules.Filter(results, classesOf, states)
    local groups = {}
    for index = 1, #results do
        groups[index] = classesOf(results[index])
        if groups[index] == nil then return false end
    end

    local kept = 0
    for index = 1, #groups do
        if Rules.Passes(groups[index], states) then
            kept = kept + 1
            results[kept] = results[index]
        end
    end
    for index = #results, kept + 1, -1 do
        results[index] = nil
    end
    return true
end

if ns then ns.ClassFilterRules = Rules end
return Rules
