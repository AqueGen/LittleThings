local addonName, ns = ...

local Rules = ns.LowLevelGearRules
local T = ns.Widgets.THEME

local LowLevelGear = {}

local CORNER_LABEL = "LittleThings: low level gear"
local CORNER_ID = "littlethings_low_level"
local CORNER_TEXT = "Low"
local CORNER_COLOR = { 1, 0.35, 0.1 }
local LINE = "LittleThings: low level gear (%s)"
local MARKER_ATLAS = "common-icon-redx"
local MARKER_SIZE = 14
local REFRESH_DELAY = 0.5

local markers = setmetatable({}, { __mode = "k" })
local equipped
local incomplete = false
local refreshQueued = false
local installed = false
local baganator = false

local function EquippedLevels()
    if equipped then
        return equipped
    end

    local levels, complete = {}, true
    for _, slot in ipairs(Rules.EQUIPPED_SLOTS) do
        local location = ItemLocation:CreateFromEquipmentSlot(slot)
        if C_Item.DoesItemExist(location) then
            levels[slot] = C_Item.GetCurrentItemLevel(location)
            complete = complete and levels[slot] ~= nil
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
        hasUpgradeInfo = upgrade ~= nil,
        maxItemLevel = upgrade and upgrade.maxItemLevel,
        trackStringID = upgrade and upgrade.trackStringID,
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

local function PaintFrame(frame)
    for _, button in frame:EnumerateValidItems() do
        local low = Judge(button:GetBagID(), button:GetID()) == true
        local marker = markers[button]
        if low and not marker then
            marker = button:CreateTexture(nil, "OVERLAY", nil, 7)
            marker:SetAtlas(MARKER_ATLAS)
            marker:SetSize(MARKER_SIZE, MARKER_SIZE)
            marker:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
            markers[button] = marker
        end
        if marker then
            marker:SetShown(low)
        end
    end
end

local function ContainerFrames()
    local frames = { ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES do
        frames[#frames + 1] = _G["ContainerFrame" .. i]
    end
    return frames
end

local function Refresh()
    refreshQueued = false
    incomplete = false
    for _, frame in ipairs(ContainerFrames()) do
        if frame:IsShown() then
            PaintFrame(frame)
        end
    end
    if baganator then
        Baganator.API.RequestItemButtonsRefresh()
    end
end

local function QueueRefresh()
    if not refreshQueued then
        refreshQueued = true
        C_Timer.After(REFRESH_DELAY, Refresh)
    end
end

local function OnEvent(_, event)
    if not ns.IsOn("lowLevelGear") then
        return
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if incomplete then
            QueueRefresh()
        end
        return
    end
    if event ~= "TRANSMOG_COLLECTION_UPDATED" then
        equipped = nil
    end
    QueueRefresh()
end

local function CornerInit(itemButton)
    local text = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text:SetText(CORNER_TEXT)
    text:SetTextColor(unpack(CORNER_COLOR))
    text.sizeFont = true
    return text
end

local function CornerUpdate(_, details)
    local location = details.itemLocation
    if not (location and location.bagID and location.slotIndex) then
        return false
    end
    return Judge(location.bagID, location.slotIndex)
end

-- Enable runs at PLAYER_LOGIN, after every addon that is not load-on-demand,
-- so Baganator is either loaded by now or not installed.
local function RegisterBaganator()
    if baganator or not (Baganator and Baganator.API and Baganator.API.RegisterCornerWidget) then
        return
    end
    baganator = true
    Baganator.API.RegisterCornerWidget(CORNER_LABEL, CORNER_ID, CornerUpdate, CornerInit,
        { corner = "bottom_left", priority = 2 })
end

local function Install()
    if installed then
        return
    end
    installed = true

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)

    for _, frame in ipairs(ContainerFrames()) do
        ns.HookInstance(frame, "UpdateItems", PaintFrame)
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:SetScript("OnEvent", OnEvent)
end

function LowLevelGear.Enable()
    Install()
    RegisterBaganator()
    equipped = nil
    Refresh()
end

function LowLevelGear.OnSwitch(enabled)
    if enabled then
        LowLevelGear.Enable()
    elseif installed then
        Refresh()
    end
end

function LowLevelGear.Pages(page)
    page:Group("Baganator"):Note("With Baganator, the marker is a corner widget, " .. CORNER_LABEL .. ". It shows \"Low\" in the bottom left corner of the item icon, under the equipment set mark. Move it or turn it off under Icon Corners on the Icons tab of Baganator's settings.")
end

LowLevelGear.key = "lowLevelGear"
ns.RegisterModule("LowLevelGear", LowLevelGear)
