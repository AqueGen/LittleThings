local _, ns = ...

local Rules = {}

function Rules.ChargeState(info, isSecret)
    if info == nil or info.maxCharges == 0 then return "none" end
    if not isSecret(info.currentCharges) then
        return info.currentCharges > 0 and "some" or "none"
    end
    if info.isActive == false then return "some" end
    if info.maxCharges == 1 then return "none" end
    return "unknown"
end

function Rules.Casters(members, classes)
    local names = {}
    for _, member in ipairs(members) do
        if classes[member.class] and not member.dead and member.connected then
            names[#names + 1] = member.name
        end
    end
    return names
end

if ns then ns.BattleResRules = Rules end
return Rules
