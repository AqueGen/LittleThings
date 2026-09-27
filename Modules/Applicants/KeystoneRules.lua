local _, ns = ...

local Keys = {}

function Keys.MythicPlusActivity(activities, mapID)
    for _, activity in ipairs(activities) do
        if activity.isMythicPlusActivity and activity.mapID == mapID then
            return activity.id, activity.groupFinderActivityGroupID
        end
    end
    return nil
end

function Keys.Rows(keys, self, members)
    local rows = {}
    for _, name in ipairs(members) do
        local key = keys[name]
        if key and (key.level or 0) > 0 and (key.challengeMapID or 0) > 0 then
            rows[#rows + 1] = { name = name, level = key.level, challengeMapID = key.challengeMapID }
        end
    end
    table.sort(rows, function(a, b)
        if (a.name == self) ~= (b.name == self) then return a.name == self end
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)
    return rows
end

if ns then ns.KeystoneRules = Keys end
return Keys
