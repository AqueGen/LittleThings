local _, ns = ...

local Order = {}

local function Compare(scoreA, scoreB)
    if scoreA == scoreB then return nil end
    if scoreA == nil then return false end
    if scoreB == nil then return true end
    return scoreA > scoreB
end

function Order.Sort(applicants, keys)
    local position, sorted = {}, {}
    for index, applicantID in ipairs(applicants) do
        position[applicantID] = index
        sorted[index] = applicantID
    end

    table.sort(sorted, function(a, b)
        for _, scores in ipairs(keys) do
            local before = Compare(scores[a], scores[b])
            if before ~= nil then return before end
        end
        return position[a] < position[b]
    end)

    local changed = false
    for index, applicantID in ipairs(sorted) do
        if applicants[index] ~= applicantID then
            changed = true
            break
        end
    end
    if changed then
        for index, applicantID in ipairs(sorted) do
            applicants[index] = applicantID
        end
    end
    return changed
end

if ns then ns.ApplicantOrder = Order end
return Order
