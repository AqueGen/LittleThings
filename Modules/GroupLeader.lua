local addonName, ns = ...

local GroupLeader = {}

local LEADER_ATLAS = "UI-HUD-UnitFrame-Player-Group-LeaderIcon"
local ASSISTANT_TEXTURE = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
local SIZE = 12

local frames = setmetatable({}, { __mode = "k" })
local hooked = false

local function IsGroupFrame(frame)
    if frame:IsForbidden() then
        return false
    end
    local name = frame:GetName()
    return name ~= nil and (name:find("^CompactPartyFrameMember") or name:find("^CompactRaid")) ~= nil
end

local function Rank(unit)
    local leader = UnitIsGroupLeader(unit)
    local assistant = IsInRaid() and UnitIsGroupAssistant(unit)
    if issecretvalue(leader) or issecretvalue(assistant) then
        return nil
    end
    if leader then
        return "leader"
    end
    return assistant and "assistant" or "none"
end

local function Paint(frame)
    local rank = "none"
    if ns.IsOn("groupLeader") and frame.unit and UnitExists(frame.unit) then
        rank = Rank(frame.unit)
        if not rank then
            return
        end
    end

    local icon = frame.ltLeaderIcon
    if rank == "none" then
        if icon then
            icon:Hide()
        end
        return
    end

    if not icon then
        icon = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        icon:SetSize(SIZE, SIZE)
        icon:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 2, -4)
        frame.ltLeaderIcon = icon
    end

    if rank == "leader" then
        icon:SetAtlas(LEADER_ATLAS)
    else
        icon:SetTexture(ASSISTANT_TEXTURE)
    end
    icon:Show()
end

local function Track(frame)
    if frame and IsGroupFrame(frame) then
        frames[frame] = true
        Paint(frame)
    end
end

local function PaintAll()
    for frame in pairs(frames) do
        Paint(frame)
    end
end

local function Discover()
    for i = 1, MEMBERS_PER_RAID_GROUP do
        Track(_G["CompactPartyFrameMember" .. i])
    end
    for i = 1, MAX_RAID_MEMBERS do
        Track(_G["CompactRaidFrame" .. i])
    end
    for group = 1, NUM_RAID_GROUPS do
        for i = 1, MEMBERS_PER_RAID_GROUP do
            Track(_G["CompactRaidGroup" .. group .. "Member" .. i])
        end
    end
end

local function Hook()
    if hooked then
        return
    end
    hooked = true

    hooksecurefunc("CompactUnitFrame_UpdateAll", Track)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PARTY_LEADER_CHANGED")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:SetScript("OnEvent", PaintAll)
end

function GroupLeader.Enable()
    Hook()
    Discover()
end

function GroupLeader.OnSwitch(enabled)
    if enabled then
        GroupLeader.Enable()
    else
        PaintAll()
    end
end

GroupLeader.key = "groupLeader"
ns.RegisterModule("GroupLeader", GroupLeader)
