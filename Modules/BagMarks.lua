-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local BagMarks = {}

local MARKER_SIZE = 14
local REFRESH_DELAY = 0.5

local marks = {}
local cornersRegistered = {}
local refreshQueued = false
local installed = false

local function ContainerFrames()
    local frames = { ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES do
        frames[#frames + 1] = _G["ContainerFrame" .. i]
    end
    return frames
end

local function PaintFrame(frame)
    for _, button in frame:EnumerateValidItems() do
        for _, mark in ipairs(marks) do
            local on = mark.Judge(button:GetBagID(), button:GetID()) == true
            local marker = mark.markers[button]
            if on and not marker then
                marker = button:CreateTexture(nil, "OVERLAY", nil, 7)
                marker:SetAtlas(mark.atlas)
                marker:SetSize(MARKER_SIZE, MARKER_SIZE)
                marker:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
                mark.markers[button] = marker
            end
            if marker then
                marker:SetShown(on)
            end
        end
    end
end

function BagMarks.Refresh()
    refreshQueued = false
    if not installed then
        return
    end
    for _, frame in ipairs(ContainerFrames()) do
        if frame:IsShown() then
            PaintFrame(frame)
        end
    end
    if next(cornersRegistered) then
        Baganator.API.RequestItemButtonsRefresh()
    end
end

function BagMarks.QueueRefresh()
    if not refreshQueued then
        refreshQueued = true
        C_Timer.After(REFRESH_DELAY, BagMarks.Refresh)
    end
end

-- Enable runs at PLAYER_LOGIN, after every addon that is not load-on-demand,
-- so Baganator is either loaded by now or not installed.
local function RegisterCorner(mark)
    local corner = mark.corner
    if cornersRegistered[corner.id] or not (Baganator and Baganator.API and Baganator.API.RegisterCornerWidget) then
        return
    end
    cornersRegistered[corner.id] = true
    Baganator.API.RegisterCornerWidget(corner.label, corner.id, function(_, details)
        local location = details.itemLocation
        if not (location and location.bagID and location.slotIndex) then
            return false
        end
        return mark.Judge(location.bagID, location.slotIndex)
    end, function(itemButton)
        local text = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        text:SetText(corner.text)
        text:SetTextColor(unpack(corner.color))
        text.sizeFont = true
        return text
    end, { corner = "bottom_left", priority = corner.priority })
end

function BagMarks.CornerActive(id)
    return cornersRegistered[id] == true and Baganator.API.IsCornerWidgetActive(id)
end

-- mark: Judge(bag, slot) returning true to mark (it checks its own switch),
-- atlas for Blizzard's bags, corner = { label, id, text, color, priority } for Baganator.
function BagMarks.Enable(mark)
    if not mark.markers then
        mark.markers = setmetatable({}, { __mode = "k" })
        marks[#marks + 1] = mark
    end
    if not installed then
        installed = true
        for _, frame in ipairs(ContainerFrames()) do
            ns.HookInstance(frame, "UpdateItems", PaintFrame)
        end
    end
    RegisterCorner(mark)
    BagMarks.Refresh()
end

ns.BagMarks = BagMarks
