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
        hideFilledRoles = false,
        minRating = nil,
        minItemLevel = nil,
        minDungeonLevel = nil,
        minOverallLevel = nil,
        timedOnly = false,
        bloodlustFit = false,
        battleResFit = false,
        mode = "down",
    }
end

function Rules.Effective(s, isMythicPlus)
    if isMythicPlus then return s end
    local copy = {}
    for key, value in pairs(s) do copy[key] = value end
    copy.minDungeonLevel = nil
    copy.timedOnly = false
    return copy
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

function Rules.IsActive(s)
    if next(s.classes) ~= nil then return true end
    for _, role in ipairs(Rules.ROLES) do
        if not s.roles[role] then return true end
    end
    return s.hideFilledRoles or s.timedOnly or s.bloodlustFit or s.battleResFit
        or s.minRating ~= nil or s.minItemLevel ~= nil or s.minDungeonLevel ~= nil or s.minOverallLevel ~= nil
end

local function MemberPasses(member, s)
    if s.classes[member.class] == Rules.EXCLUDE then return false end
    if s.minRating and (member.rating or 0) < s.minRating then return false end
    if s.minItemLevel and (member.itemLevel or 0) < s.minItemLevel then return false end
    if s.minDungeonLevel and (member.dungeonLevel or 0) < s.minDungeonLevel then return false end
    if s.minOverallLevel and (member.overallLevel or 0) < s.minOverallLevel then return false end
    if s.timedOnly and not member.dungeonTimed then return false end
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

local ALL_ROLES = { TANK = true, HEALER = true, DAMAGER = true }

local function Leftovers(members, open, allowed, index, out)
    index = index or 1
    out = out or {}
    if index > #members then
        out[#out + 1] = { TANK = open.TANK, HEALER = open.HEALER, DAMAGER = open.DAMAGER }
        return out
    end
    for _, role in ipairs(Rules.ROLES) do
        if members[index].roles[role] and allowed[role] and open[role] > 0 then
            open[role] = open[role] - 1
            Leftovers(members, open, allowed, index + 1, out)
            open[role] = open[role] + 1
        end
    end
    return out
end

local function RoomAfter(members, open, roles)
    for _, left in ipairs(Leftovers(members, open, ALL_ROLES)) do
        for _, role in ipairs(roles) do
            if left[role] > 0 then return true end
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

    local open = group.open
    if not open then return true end
    if s.hideFilledRoles and #Leftovers(application.members, open, s.roles) == 0 then return false end
    if s.bloodlustFit and not (group.hasBloodlust or Brings(application, Rules.BLOODLUST))
        and not RoomAfter(application.members, open, { "HEALER", "DAMAGER" }) then
        return false
    end
    if s.battleResFit and not (group.hasBattleRes or Brings(application, Rules.BATTLE_RES))
        and not RoomAfter(application.members, open, Rules.ROLES) then
        return false
    end
    return true
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

function Rules.Apply(ids, byId, group, s)
    local passing, failing, failed = {}, {}, {}
    for _, id in ipairs(ids) do
        if Rules.Passes(byId[id], group, s) then
            passing[#passing + 1] = id
        else
            failing[#failing + 1] = id
            failed[id] = true
        end
    end
    if #failing == 0 then return failed, 0 end

    for index = #ids, 1, -1 do
        ids[index] = nil
    end
    for _, id in ipairs(passing) do
        ids[#ids + 1] = id
    end
    if s.mode ~= "hide" then
        for _, id in ipairs(failing) do
            ids[#ids + 1] = id
        end
    end
    return failed, #failing
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
    return current
end

if ns then ns.FilterRules = Rules end
return Rules
