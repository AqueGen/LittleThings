-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.LowLevelGearRules
local BagMarks = ns.BagMarks
local T = ns.Widgets.THEME

local LowLevelGear = {}

local CORNER_LABEL = "LittleThings: low level gear"
local CORNER_ID = "littlethings_low_level"
local LINE = "LittleThings: low level gear (%s)"

local equipped
local incomplete = false
local installed = false

local function EquippedLevels()
    if equipped then
        return equipped
    end

    local levels, complete = {}, true
    for _, slot in ipairs(Rules.EQUIPPED_SLOTS) do
        local location = ItemLocation:CreateFromEquipmentSlot(slot)
        if C_Item.DoesItemExist(location) then
            local link = C_Item.GetItemLink(location)
            local upgrade = link and C_Item.GetItemUpgradeInfo(link)
            levels[slot] = { level = C_Item.GetCurrentItemLevel(location),
                track = upgrade and upgrade.trackStringID, trackString = upgrade and upgrade.trackString }
            complete = complete and link ~= nil and levels[slot].level ~= nil
        end
    end
    if complete then
        equipped = levels
    else
        incomplete = true
    end
    return levels
end

-- nil means the game has not loaded everything yet; never mark on that.
local function Facts(location)
    if not C_Item.DoesItemExist(location) then
        return {}
    end

    local link = C_Item.GetItemLink(location)
    if not link then
        return nil
    end
    if C_Item.GetItemQuality(location) == Enum.ItemQuality.Poor then
        return {}
    end

    local _, _, _, _, _, _, _, _, equipLoc, _, _, _, _, _, _, setID = C_Item.GetItemInfo(link)
    if not equipLoc then
        return nil
    end
    if not Rules.SLOTS[equipLoc] then
        return { equipLoc = equipLoc }
    end

    local upgrade = C_Item.GetItemUpgradeInfo(link)
    local hasAppearance = C_TransmogCollection.GetItemInfo(link) ~= nil
    return {
        equipLoc = equipLoc,
        setID = setID,
        bound = C_Item.IsBound(location),
        accountUntilEquip = C_Item.IsBoundToAccountUntilEquip(location),
        uncollected = hasAppearance and not C_TransmogCollection.PlayerHasTransmogByItemInfo(link),
        itemLevel = C_Item.GetCurrentItemLevel(location),
        trackStringID = upgrade and upgrade.trackStringID,
        trackString = upgrade and upgrade.trackString,
    }
end

-- Returns nil while item data is still loading.
local function Judge(bag, slot)
    if not ns.IsOn("lowLevelGear") or bag < Enum.BagIndex.Backpack or bag > NUM_TOTAL_EQUIPPED_BAG_SLOTS then
        return false
    end

    local facts = Facts(ItemLocation:CreateFromBagAndSlot(bag, slot))
    if not facts then
        incomplete = true
        return nil
    end
    return Rules.Evaluate(facts, EquippedLevels())
end

local function OnTooltip(tooltip, data)
    if not ns.IsOn("lowLevelGear") or tooltip:IsForbidden() then
        return
    end

    local guid = data and data.guid
    if not guid or issecretvalue(guid) then
        return
    end

    local location = C_Item.GetItemLocation(guid)
    if not (location and location:IsBagAndSlot()) then
        return
    end

    local low, reason = Judge(location:GetBagAndSlot())
    if low then
        tooltip:AddLine(LINE:format(reason), unpack(T.muted))
    end
end

local function OnEvent(_, event)
    if not ns.IsOn("lowLevelGear") then
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if incomplete then
            incomplete = false
            BagMarks.QueueRefresh()
        end
        return
    end
    if event ~= "TRANSMOG_COLLECTION_UPDATED" then
        equipped = nil
    end
    BagMarks.QueueRefresh()
end

local mark = {
    Judge = Judge,
    atlas = "common-icon-redx",
    corner = { label = CORNER_LABEL, id = CORNER_ID, text = "Low", color = { 1, 0.35, 0.1 }, priority = 2 },
}

local function Install()
    if installed then
        return
    end
    installed = true

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:SetScript("OnEvent", OnEvent)
end

function LowLevelGear.Enable()
    Install()
    equipped = nil
    BagMarks.Enable(mark)
end

function LowLevelGear.OnSwitch(enabled)
    if enabled then
        LowLevelGear.Enable()
    elseif installed then
        BagMarks.Refresh()
    end
end

function LowLevelGear.Report()
    equipped = nil
    local levels = EquippedLevels()
    local worn = {}
    for _, slot in ipairs(Rules.EQUIPPED_SLOTS) do
        local piece = levels[slot]
        worn[#worn + 1] = slot .. "=" .. (piece and (tostring(piece.level) .. "/" .. tostring(piece.track)) or "-")
    end
    ns.Print("low level gear " .. (ns.IsOn("lowLevelGear") and "on" or "off") .. ", Baganator corner active: "
        .. tostring(BagMarks.CornerActive(CORNER_ID)) .. ", worn: " .. table.concat(worn, " "))
    for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
            local facts = Facts(location)
            if facts == nil or (facts.equipLoc and Rules.SLOTS[facts.equipLoc]) then
                print(string.format("%s %s ilvl=%s track=%s/%s bound=%s acct=%s uncollected=%s set=%s -> %s",
                    tostring(C_Item.GetItemLink(location)), tostring(facts and facts.equipLoc),
                    tostring(facts and facts.itemLevel),
                    tostring(facts and facts.trackString), tostring(facts and facts.trackStringID),
                    tostring(facts and facts.bound), tostring(facts and facts.accountUntilEquip),
                    tostring(facts and facts.uncollected), tostring(facts and facts.setID),
                    facts and tostring((Rules.Evaluate(facts, levels))) or "not loaded"))
            end
        end
    end
end

function LowLevelGear.Pages(page)
    page:Group("Baganator"):Note("With Baganator, the marker is a corner widget, " .. CORNER_LABEL .. ". It shows \"Low\" in the bottom left corner of the item icon, under the equipment set mark. Move it or turn it off under Icon Corners on the Icons tab of Baganator's settings.")
end

ns.LowLevelGear = LowLevelGear
LowLevelGear.key = "lowLevelGear"
ns.RegisterModule("LowLevelGear", LowLevelGear)
