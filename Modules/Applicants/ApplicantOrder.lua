local _, ns = ...

local Order = {}

local function Compare(scoreA, scoreB)
    if scoreA == scoreB then return nil end
    if scoreA == nil then return false end
    if scoreB == nil then return true end
    return scoreA > scoreB
end

function Order.Rank(applicants, keys)
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

    local ranks = {}
    for rank, applicantID in ipairs(sorted) do
        ranks[applicantID] = rank
    end
    return ranks
end

if ns then ns.ApplicantOrder = Order end
return Order
