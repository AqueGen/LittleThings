-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local BagMarks = ns.BagMarks

local WarbandGear = {}

local CORNER_LABEL = "LittleThings: warband gear"

local function Judge(bag, slot)
    if not ns.IsOn("warbandGear") or bag < Enum.BagIndex.Backpack or bag > NUM_TOTAL_EQUIPPED_BAG_SLOTS then
        return false
    end

    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not (C_Item.DoesItemExist(location) and C_Item.IsBoundToAccountUntilEquip(location)) then
        return false
    end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(C_Item.GetItemID(location))
    return classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon
end

local mark = {
    Judge = Judge,
    atlas = "warbands-icon",
    corner = { label = CORNER_LABEL, id = "littlethings_warband_gear", text = "WB", color = { 0, 0.8, 1 }, priority = 3 },
}

function WarbandGear.Enable()
    BagMarks.Enable(mark)
end

function WarbandGear.OnSwitch(enabled)
    if enabled then
        WarbandGear.Enable()
    else
        BagMarks.Refresh()
    end
end

function WarbandGear.Pages(page)
    page:Group("Baganator"):Note("Baganator: the corner widget " .. CORNER_LABEL .. " shows \"WB\" in the bottom left corner of the item icon. Move it or turn it off under Icon Corners on the Icons tab of Baganator's settings.")
end

WarbandGear.key = "warbandGear"
ns.RegisterModule("WarbandGear", WarbandGear)
