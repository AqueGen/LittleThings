local _, ns = ...

local Progress = {}

local SUFFIX = { [1] = "N", [2] = "H", [3] = "M" }
local RAID_DIFFICULTY_IDS = { [14] = 1, [15] = 2, [16] = 3 }

local function HasKills(entry)
    return entry ~= nil and (entry.progressCount or 0) > 0
end

function Progress.Best(entries, mapId)
    local best
    for _, entry in ipairs(entries or {}) do
        if HasKills(entry) and entry.raid and entry.raid.mapId == mapId and (not best
            or entry.difficulty > best.difficulty
            or (entry.difficulty == best.difficulty and entry.progressCount > best.progressCount)) then
            best = entry
        end
    end
    return best
end

function Progress.For(entries, mapId, difficulty)
    for _, entry in ipairs(entries or {}) do
        if HasKills(entry) and entry.raid and entry.raid.mapId == mapId and entry.difficulty == difficulty then
            return entry
        end
    end
    return nil
end

function Progress.Score(entries, mapId)
    local best
    for _, entry in ipairs(entries or {}) do
        if HasKills(entry) and entry.raid and entry.raid.mapId == mapId then
            local score = entry.difficulty * 100 + entry.progressCount
            if not best or score > best then best = score end
        end
    end
    return best
end

function Progress.Text(entry, compact)
    if not HasKills(entry) then return "" end
    local text = entry.progressCount .. "/" .. (entry.raid and entry.raid.bossCount or "?")
    if compact then return text end
    return text .. " " .. (SUFFIX[entry.difficulty] or "")
end

function Progress.Difficulty(activity)
    if activity.isMythicActivity then return 3 end
    if activity.isHeroicActivity then return 2 end
    if activity.isNormalActivity then return 1 end
    return RAID_DIFFICULTY_IDS[activity.difficultyID]
end

if ns then ns.RaidProgress = Progress end
return Progress
