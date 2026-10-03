local addonName, ns = ...

local IconButtons = {}

local BORDER = "Interface\\ContainerFrame\\UI-Icon-QuestBorder"

IconButtons.SIZE, IconButtons.GAP = 40, 2

IconButtons.ROLE_ATLAS = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}

function IconButtons.New(bar, index)
    local b = bar.buttons[index]
    if b then return b end
    b = CreateFrame("Button", nil, bar)
    b:SetSize(IconButtons.SIZE, IconButtons.SIZE)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.overlay = b:CreateTexture(nil, "OVERLAY")
    b.overlay:SetAllPoints()
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", bar.onClick)
    bar.buttons[index] = b
    return b
end

function IconButtons.SetActive(b, active)
    if active then
        b.overlay:SetTexture(BORDER)
        b.overlay:SetVertexColor(1, 1, 1, 1)
    else
        b.overlay:SetColorTexture(0, 0, 0, 0.65)
    end
end

function IconButtons.Row(bar, count)
    local size = bar.size or IconButtons.SIZE
    local step = size + IconButtons.GAP
    for i = 0, count - 1 do
        bar.buttons[i]:SetSize(size, size)
        bar.buttons[i]:ClearAllPoints()
        bar.buttons[i]:SetPoint("LEFT", bar, "LEFT", step * i, 0)
    end
    for i = count, #bar.buttons do
        bar.buttons[i]:Hide()
    end
    bar:SetSize(math.max(step * count - (step - size), 1), size)
end

function IconButtons.OnLootClick(self)
    if self.specId ~= GetLootSpecialization() then
        SetLootSpecialization(self.specId)
        PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK)
    end
end

-- New binds bar.onClick at creation, so the bar needs onClick = OnLootClick
-- before the first fill. Without the default button, a loot spec that follows
-- the current specialization frames the current specialization's icon.
function IconButtons.FillLootSpecs(bar, withDefault)
    local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(select(3, UnitClass("player")))
    local current = C_SpecializationInfo.GetSpecialization()
    local lootSpec = GetLootSpecialization()
    local first = withDefault and 1 or 0

    for i = 1, numSpecs do
        local id, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(i)
        local b = IconButtons.New(bar, first + i - 1)
        b.specId, b.tip = id, name
        b.icon:SetTexture(icon)
        IconButtons.SetActive(b, id == lootSpec or (lootSpec == 0 and not withDefault and i == current))
        b:Show()
    end

    if not withDefault then
        return numSpecs
    end

    local _, currentName, _, currentIcon
    if current then
        _, currentName, _, currentIcon = C_SpecializationInfo.GetSpecializationInfo(current)
    end
    local auto = IconButtons.New(bar, 0)
    auto.specId, auto.tip = 0, LOOT_SPECIALIZATION_DEFAULT:format(currentName or "")
    auto.icon:SetTexture(currentIcon)
    IconButtons.SetActive(auto, lootSpec == 0)
    auto:Show()

    return numSpecs + 1
end

ns.IconButtons = IconButtons
