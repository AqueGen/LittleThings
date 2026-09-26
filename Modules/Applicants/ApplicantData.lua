local _, ns = ...

local Rules = ns and ns.FilterRules or require("FilterRules")

local Data = {}

local function AnySecret(...)
    for i = 1, select("#", ...) do
        if issecretvalue(select(i, ...)) then return true end
    end
    return false
end

function Data.Listing()
    local entry = C_LFGList.GetActiveEntryInfo()
    local activityID = entry and entry.activityIDs and entry.activityIDs[1]
    local activity = activityID and C_LFGList.GetActivityInfoTable(activityID)
    if not activity then return nil end
    return {
        activityID = activityID,
        isMythicPlus = activity.isMythicPlusActivity == true,
        fiveMan = activity.maxNumPlayers == 5,
    }
end

function Data.DungeonBest(applicantID, memberIndex, activityID)
    local best = C_LFGList.GetApplicantDungeonScoreForListing(applicantID, memberIndex, activityID)
    if not best then return nil end
    if AnySecret(best.bestRunLevel, best.finishedSuccess, best.mapScore) then return false end
    if (best.bestRunLevel or 0) <= 0 then return nil end
    return { level = best.bestRunLevel, timed = best.finishedSuccess == true, score = best.mapScore }
end

function Data.Application(applicantID, listing)
    if issecretvalue(applicantID) then return nil end
    local info = C_LFGList.GetApplicantInfo(applicantID)
    if not info or AnySecret(info.numMembers, info.applicationStatus) then return nil end

    local status = info.applicationStatus
    local application = { members = {}, pinned = status == "invited" or status == "inviteaccepted" }
    for i = 1, info.numMembers or 0 do
        local _, class, _, _, itemLevel, _, tank, healer, damage, _, _, rating = C_LFGList.GetApplicantMemberInfo(applicantID, i)
        if AnySecret(class, itemLevel, tank, healer, damage, rating) then return nil end
        local member = {
            class = class,
            itemLevel = itemLevel,
            rating = rating,
            roles = { TANK = tank == true, HEALER = healer == true, DAMAGER = damage == true },
        }
        if listing.isMythicPlus then
            local best = Data.DungeonBest(applicantID, i, listing.activityID)
            if best == false then return nil end
            if best then
                member.dungeonLevel, member.dungeonTimed, member.dungeonScore = best.level, best.timed, best.score
            end
        end
        application.members[i] = member
    end
    return application
end

local UNITS = { "player", "party1", "party2", "party3", "party4" }

function Data.Group(listing)
    local group = { hasBloodlust = false, hasBattleRes = false }
    if listing.fiveMan then
        group.open = { TANK = 1, HEALER = 1, DAMAGER = 3 }
    end
    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            local class = UnitClassBase(unit)
            if Rules.BLOODLUST[class] then group.hasBloodlust = true end
            if Rules.BATTLE_RES[class] then group.hasBattleRes = true end
            local role = UnitGroupRolesAssigned(unit)
            if group.open and group.open[role] then
                group.open[role] = math.max(0, group.open[role] - 1)
            end
        end
    end
    return group
end

if ns then ns.ApplicantData = Data end
return Data
