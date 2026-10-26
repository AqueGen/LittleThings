local addonName, ns = ...

local Rules = ns.BagJunkRules
local T = ns.Widgets.THEME

local BagJunk = {}

local PLUGIN_LABEL = "LittleThings: gear you will not wear"
local PLUGIN_ID = "littlethings_never_wear"
local LINE = "LittleThings: you will not wear this (%s)"
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
    local quality = C_Item.GetItemQuality(location)
    if not link or not quality then
        return nil
    end
    if quality == Enum.ItemQuality.Poor then
        return { poor = true }
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
        maxItemLevel = upgrade and upgrade.maxItemLevel,
    }
end

-- Greys count only for Baganator, whose junk source we replace; our own marker
-- and tooltip line are for gear.
local function Judge(bag, slot, withPoor)
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not ns.IsOn("bagJunk") then
        return withPoor and C_Item.DoesItemExist(location) and C_Item.GetItemQuality(location) == Enum.ItemQuality.Poor
    end

    local facts = Facts(location)
    if not facts then
        incomplete = true
        return false
    end
    if facts.poor and not withPoor then
        return false
    end
    return Rules.Evaluate(facts, EquippedLevels())
end

local function OnTooltip(tooltip, data)
    if not ns.IsOn("bagJunk") or tooltip:IsForbidden() then
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

    local bag, slot = location:GetBagAndSlot()
    if bag < Enum.BagIndex.Backpack or bag > NUM_TOTAL_EQUIPPED_BAG_SLOTS then
        return
    end

    local junk, reason = Judge(bag, slot)
    if junk then
        tooltip:AddLine(LINE:format(reason), unpack(T.muted))
    end
end

local function PaintFrame(frame)
    for _, button in frame:EnumerateValidItems() do
        local junk = Judge(button:GetBagID(), button:GetID())
        local marker = markers[button]
        if junk and not marker then
            marker = button:CreateTexture(nil, "OVERLAY", nil, 7)
            marker:SetAtlas(MARKER_ATLAS)
            marker:SetSize(MARKER_SIZE, MARKER_SIZE)
            marker:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
            markers[button] = marker
        end
        if marker then
            marker:SetShown(junk)
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
    if not ns.IsOn("bagJunk") then
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

-- Enable runs at PLAYER_LOGIN, after every addon that is not load-on-demand,
-- so Baganator is either loaded by now or not installed.
local function RegisterBaganator()
    if baganator or not (Baganator and Baganator.API and Baganator.API.RegisterJunkPlugin) then
        return
    end
    baganator = true
    Baganator.API.RegisterJunkPlugin(PLUGIN_LABEL, PLUGIN_ID, function(bag, slot)
        return Judge(bag, slot, true) == true
    end)
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

function BagJunk.Enable()
    Install()
    RegisterBaganator()
    equipped = nil
    Refresh()
end

function BagJunk.OnSwitch(enabled)
    if enabled then
        BagJunk.Enable()
    elseif installed then
        Refresh()
    end
end

function BagJunk.Pages(page)
    page:Group("Baganator"):Note("With Baganator, pick " .. PLUGIN_LABEL .. " under Junk detection on the General tab of Baganator's settings. Baganator picks it by itself while Junk detection is still on its default, Poor quality. Grey items keep their junk coin with it.")
end

BagJunk.key = "bagJunk"
ns.RegisterModule("BagJunk", BagJunk)
