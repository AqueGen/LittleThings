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
        timedOnly = false,
        bloodlustFit = false,
        battleResFit = false,
        mode = "down",
    }
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
        or s.minRating ~= nil or s.minItemLevel ~= nil or s.minDungeonLevel ~= nil
end

local function MemberPasses(member, s)
    if s.classes[member.class] == Rules.EXCLUDE then return false end
    if s.minRating and (member.rating or 0) < s.minRating then return false end
    if s.minItemLevel and (member.itemLevel or 0) < s.minItemLevel then return false end
    if s.minDungeonLevel and (member.dungeonLevel or 0) < s.minDungeonLevel then return false end
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

function Rules.Passes(application, group, s)
    if application.pinned then return true end
    for _, member in ipairs(application.members) do
        if not MemberPasses(member, s) then return false end
    end
    return HasNeededClass(application, s)
end

function Rules.CountClasses(applications)
    local counts = {}
    for _, application in ipairs(applications) do
        for _, member in ipairs(application.members) do
            counts[member.class] = (counts[member.class] or 0) + 1
        end
    end
    return counts
end

if ns then ns.FilterRules = Rules end
return Rules
