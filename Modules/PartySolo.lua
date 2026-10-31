-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local PartySolo = {}

local hookedFrame = false
local hookedGenerate = false
local pending = false
local events

local function Wanted()
    return ns.IsOn("partySolo") and not IsInGroup() and EditModeManagerFrame:UseRaidStylePartyFrames()
end

local function Apply()
    local frame = CompactPartyFrame
    if not frame then
        return
    end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    if Wanted() then
        if not frame:IsShown() then
            frame:Show()
        end
    elseif frame:IsShown() ~= frame:ShouldShow() then
        frame:SetShown(frame:ShouldShow())
    end
end

local function HookFrame()
    if hookedFrame or not CompactPartyFrame then
        return
    end
    hookedFrame = true
    hooksecurefunc(CompactPartyFrame, "UpdateVisibility", Apply)
end

function PartySolo.Enable()
    if not hookedGenerate then
        hookedGenerate = true
        hooksecurefunc("CompactPartyFrame_Generate", function()
            HookFrame()
            Apply()
        end)
    end
    HookFrame()
    if not events then
        events = CreateFrame("Frame")
        events:RegisterEvent("GROUP_ROSTER_UPDATE")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:SetScript("OnEvent", function(_, event)
            if event ~= "PLAYER_REGEN_ENABLED" or pending then
                Apply()
            end
        end)
    end
    Apply()
end

function PartySolo.OnSwitch(enabled)
    if enabled then
        PartySolo.Enable()
    else
        Apply()
    end
end

PartySolo.key = "partySolo"
ns.RegisterModule("PartySolo", PartySolo)
