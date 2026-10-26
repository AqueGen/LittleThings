local _, ns = ...

local Rules = {}

local SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_CLOAK = { 15 },
}

Rules.SLOTS = SLOTS
Rules.EQUIPPED_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 15 }

function Rules.Evaluate(item, equipped)
    if item.poor then
        return true, "poor quality"
    end

    local slots = SLOTS[item.equipLoc]
    if not slots or item.setID or not item.bound or item.accountUntilEquip or item.uncollected then
        return false
    end

    local worn
    for _, slot in ipairs(slots) do
        local level = equipped[slot]
        if not level then
            return false
        end
        worn = worn and math.min(worn, level) or level
    end

    local max = item.maxItemLevel or item.itemLevel
    if not max or max > worn then
        return false
    end

    return true, string.format("max %d <= equipped %d", max, worn)
end

if ns then ns.BagJunkRules = Rules end
return Rules
