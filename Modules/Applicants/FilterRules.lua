local _, ns = ...

local Rules = {}

Rules.NEED = "need"
Rules.EXCLUDE = "exclude"
Rules.ROLES = { "TANK", "HEALER", "DAMAGER" }
Rules.BLOODLUST = { SHAMAN = true, MAGE = true, HUNTER = true, EVOKER = true }
Rules.BATTLE_RES = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true, PALADIN = true }

function Rules.Defaults()
    return {
        classes = {},
        roles = { TANK = true, HEALER = true, DAMAGER = true },
        onlyMissingRoles = true,
        minItemLevel = nil,
        needBloodlust = false,
        needBattleRes = false,
    }
end

local FINISHED = {
    cancelled = true, failed = true, timedout = true, invitedeclined = true,
    declined = true, declined_full = true, declined_delisted = true,
}

function Rules.IsFinished(status, pendingStatus)
    return pendingStatus == nil and FINISHED[status] == true
end

function Rules.Next(state)
    if state == nil then return Rules.NEED end
    if state == Rules.NEED then return Rules.EXCLUDE end
    return nil
end

function Rules.ParseNumber(text)
    local value = tonumber(text)
    if value then return math.floor(value) end
    return nil
end

function Rules.IsDefault(s)
    if next(s.classes) ~= nil then return false end
    for _, role in ipairs(Rules.ROLES) do
        if not s.roles[role] then return false end
    end
    return s.onlyMissingRoles == true and not s.needBloodlust and not s.needBattleRes and s.minItemLevel == nil
end

local function MemberPasses(member, s)
    if s.classes[member.class] == Rules.EXCLUDE then return false end
    if s.minItemLevel and (member.itemLevel or 0) < s.minItemLevel then return false end
    for _, role in ipairs(Rules.ROLES) do
        if member.roles[role] and s.roles[role] then return true end
    end
    return false
end

local function HasNeededClass(application, s)
    local wantsAny = false
    for _, state in pairs(s.classes) do
        if state == Rules.NEED then wantsAny = true break end
    end
    if not wantsAny then return true end
    for _, member in ipairs(application.members) do
        if s.classes[member.class] == Rules.NEED then return true end
    end
    return false
end

local function Fits(members, open, allowed, index)
    index = index or 1
    local member = members[index]
    if not member then return true end
    for _, role in ipairs(Rules.ROLES) do
        if member.roles[role] and allowed[role] and open[role] > 0 then
            open[role] = open[role] - 1
            local fits = Fits(members, open, allowed, index + 1)
            open[role] = open[role] + 1
            if fits then return true end
        end
    end
    return false
end

local function Brings(application, classes)
    for _, member in ipairs(application.members) do
        if classes[member.class] then return true end
    end
    return false
end

function Rules.Passes(application, group, s)
    if application.pinned then return true end
    for _, member in ipairs(application.members) do
        if not MemberPasses(member, s) then return false end
    end
    if not HasNeededClass(application, s) then return false end

    if not group.open then return true end
    if s.onlyMissingRoles and not Fits(application.members, group.open, s.roles) then return false end
    local wantsLust = s.needBloodlust and not group.hasBloodlust
    local wantsRes = s.needBattleRes and not group.hasBattleRes
    if not wantsLust and not wantsRes then return true end
    return (wantsLust and Brings(application, Rules.BLOODLUST))
        or (wantsRes and Brings(application, Rules.BATTLE_RES))
        or false
end

function Rules.CountClasses(applications)
    local counts = {}
    for _, application in ipairs(applications) do
        for _, member in ipairs(application.members) do
            if member.class then
                counts[member.class] = (counts[member.class] or 0) + 1
            end
        end
    end
    return counts
end

function Rules.Failing(ids, byId, group, s)
    local failed, count = {}, 0
    for _, id in ipairs(ids) do
        if not Rules.Passes(byId[id], group, s) then
            failed[id] = true
            count = count + 1
        end
    end
    return failed, count
end

function Rules.Migrate(current, oldClassPicks)
    local defaults = Rules.Defaults()
    if current == nil then
        current = defaults
        for class, state in pairs(oldClassPicks or {}) do
            current.classes[class] = state
        end
        return current
    end
    for key, value in pairs(defaults) do
        if current[key] == nil then current[key] = value end
    end
    current.mode = nil
    return current
end

if ns then ns.FilterRules = Rules end
return Rules
