local addonName, ns = ...

local Rules = ns.SaveRules

local Corners = {}
ns.SaveCorners = Corners

local ICON = 14

local containers = {}
local wanted = false
local hooked = false
local ids

local function IsBig(id)
    local big = C_UnitAuras.AuraIsBigDefensive(id)
    return not issecretvalue(big) and big == true
end

local function Init(btn)
    btn:SetSize(ICON, ICON)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn:SetIcon(icon)
    local swipe = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    swipe:SetAllPoints(icon)
    swipe:SetHideCountdownNumbers(true)
    btn:SetDurationCooldown(swipe)
    if btn.SetHideTooltipInCombat then btn:SetHideTooltipInCombat(true) end
end

local function IsMember(frame)
    if not frame or frame:IsForbidden() then
        return false
    end
    local name = frame:GetName()
    return name ~= nil and name:find("^CompactPartyFrameMember%d$") ~= nil
end

local function ContainerFor(frame)
    local c = containers[frame]
    if c ~= nil then
        return c or nil
    end
    if not ids then
        return nil
    end
    local ok, made = pcall(CreateFrame, "AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    if not ok or not made then
        containers[frame] = false
        return nil
    end
    c = made
    if c.SetEditModePreviewEnabled then c:SetEditModePreviewEnabled(false) end
    c:SetFlowLayoutMaximumLineSize(ICON * 2 + 2)
    c:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    c:AddAuraGroup("saves", "HELPFUL", {
        candidateFilters = { includeSpellIDs = ids },
        initializeFrame = Init,
        sortMethod = AuraContainerSortMethod.Expiration,
        maxFrameCount = 2,
        layout = { elementWidth = ICON, elementHeight = ICON, elementSpacing = 2 },
    })
    containers[frame] = c
    return c
end

local function Sync(frame)
    local unit = frame.unit
    local show = wanted and unit ~= nil and UnitExists(unit)
    local c = show and ContainerFor(frame) or containers[frame]
    if not c then
        return
    end
    if show then
        c:SetUnit(unit)
        c:UpdateAllAuras()
    end
    c:SetShown(show)
end

local function SyncAll()
    for i = 1, MEMBERS_PER_RAID_GROUP do
        local frame = _G["CompactPartyFrameMember" .. i]
        if IsMember(frame) then
            Sync(frame)
        end
    end
end

local function OnSetUnit(frame)
    if IsMember(frame) then
        Sync(frame)
    end
end

function Corners.Apply(on)
    wanted = on
    if not ids and not InCombatLockdown() then
        ids = Rules.CornerIDs(ns.SaveData, IsBig)
    end
    if on and not hooked then
        hooked = true
        hooksecurefunc("CompactUnitFrame_SetUnit", OnSetUnit)
    end
    SyncAll()
end
