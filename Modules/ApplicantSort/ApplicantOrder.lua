local _, ns = ...

local Order = {}

local function Compare(scoreA, scoreB)
    if scoreA == scoreB then return nil end
    if scoreA == nil then return false end
    if scoreB == nil then return true end
    return scoreA > scoreB
end

function Order.Sort(applicants, keys)
    local position = {}
    for index, applicantID in ipairs(applicants) do
        position[applicantID] = index
    end

    table.sort(applicants, function(a, b)
        for _, scores in ipairs(keys) do
            local before = Compare(scores[a], scores[b])
            if before ~= nil then return before end
        end
        return position[a] < position[b]
    end)
end

if ns then ns.ApplicantOrder = Order end
return Order
