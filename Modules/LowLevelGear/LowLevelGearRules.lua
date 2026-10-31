-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
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

-- trackStringID from C_Item.GetItemUpgradeInfo, read in game on 2026-10-26 (Midnight season);
-- maxItemLevel came back 0 for every item, so tracks are the only upgrade ceiling we have.
-- An id missing here (Explorer, a new season) means the item is never marked.
Rules.TRACK_RANK = { [971] = 1, [972] = 2, [973] = 3, [974] = 4, [978] = 5 }

local function Worse(a, b)
    local rankA, rankB = Rules.TRACK_RANK[a.track], Rules.TRACK_RANK[b.track]
    if rankA ~= rankB then
        return rankA < rankB and a or b
    end
    return a.level <= b.level and a or b
end

function Rules.Evaluate(item, equipped)
    local slots = SLOTS[item.equipLoc]
    local rank = Rules.TRACK_RANK[item.trackStringID]
    if not slots or not rank or not item.itemLevel or item.setID or not item.bound or item.accountUntilEquip
        or item.uncollected then
        return false
    end

    local worn
    for _, slot in ipairs(slots) do
        local piece = equipped[slot]
        if not (piece and piece.level and Rules.TRACK_RANK[piece.track]) then
            return false
        end
        worn = worn and Worse(worn, piece) or piece
    end

    if rank >= Rules.TRACK_RANK[worn.track] then
        return false
    end

    return true, string.format("%s %d, worn %s %d", tostring(item.trackString), item.itemLevel,
        tostring(worn.trackString), worn.level)
end

if ns then ns.LowLevelGearRules = Rules end
return Rules
