local addonName, ns = ...

local CharacterPanel = {}

local SIZE, STEP, GAP = 20, 22, 10
local BORDER = "Interface\\ContainerFrame\\UI-Icon-QuestBorder"
local DEFAULTS = { corner = "bottomleft", x = 8, y = -45 }
local CORNERS = {
    topleft = { "BOTTOMLEFT", "TOPLEFT" },
    topright = { "BOTTOMRIGHT", "TOPRIGHT" },
    bottomleft = { "TOPLEFT", "BOTTOMLEFT" },
    bottomright = { "TOPRIGHT", "BOTTOMRIGHT" },
}

local db
local row
local specLabel, lootLabel
local specButtons, lootButtons = {}, {}

local function Anchor()
    local points = CORNERS[db.corner] or CORNERS.bottomleft
    row:ClearAllPoints()
    row:SetPoint(points[1], CharacterFrame, points[2], db.x, db.y)
end

local function NewButton(list, index)
    local b = list[index]
    if b then return b end
    b = CreateFrame("Button", nil, row)
    b:SetSize(SIZE, SIZE)
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
    list[index] = b
    return b
end

local function SetActive(b, active)
    if active then
        b.overlay:SetTexture(BORDER)
        b.overlay:SetVertexColor(1, 1, 1, 1)
    else
        b.overlay:SetColorTexture(0, 0, 0, 0.65)
    end
end

local function OnSpecClick(self)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1)
        return
    end
    if self.index ~= C_SpecializationInfo.GetSpecialization() then
        C_SpecializationInfo.SetSpecialization(self.index)
        PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK)
    end
end

local function OnLootClick(self)
    if self.specId ~= GetLootSpecialization() then
        SetLootSpecialization(self.specId)
        PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK)
    end
end

local function Refresh()
    local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(select(3, UnitClass("player")))
    local current = C_SpecializationInfo.GetSpecialization()
    local lootSpec = GetLootSpecialization()
    local currentName = current and select(2, C_SpecializationInfo.GetSpecializationInfo(current)) or ""
    local lootStart = STEP * numSpecs + GAP

    for i = 1, numSpecs do
        local id, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(i)
        local b = NewButton(specButtons, i)
        b.index, b.tip = i, name
        b.icon:SetTexture(icon)
        b:SetPoint("TOPLEFT", STEP * (i - 1), 0)
        b:SetScript("OnClick", OnSpecClick)
        SetActive(b, i == current)
        b:Show()

        local lb = NewButton(lootButtons, i)
        lb.specId, lb.tip = id, name
        lb.icon:SetTexture(icon)
        lb:SetPoint("TOPLEFT", lootStart + STEP * i, 0)
        lb:SetScript("OnClick", OnLootClick)
        SetActive(lb, id == lootSpec)
        lb:Show()
    end

    local auto = NewButton(lootButtons, 0)
    auto.specId, auto.tip = 0, LOOT_SPECIALIZATION_DEFAULT:format(currentName)
    auto.icon:SetTexture(current and select(4, C_SpecializationInfo.GetSpecializationInfo(current)))
    auto:SetPoint("TOPLEFT", lootStart, 0)
    auto:SetScript("OnClick", OnLootClick)
    SetActive(auto, lootSpec == 0)
    auto:Show()

    local width = lootStart + STEP * (numSpecs + 1) - (STEP - SIZE)
    row:SetWidth(width)
    specLabel:SetPoint("TOP", row, "TOPLEFT", (STEP * numSpecs - (STEP - SIZE)) / 2, -SIZE - 2)
    lootLabel:SetPoint("TOP", row, "TOPLEFT", (lootStart + width) / 2, -SIZE - 2)
end

local function Proxy(category, key, varType, label)
    return Settings.RegisterProxySetting(category, "LT_specRow_" .. key, varType, label, DEFAULTS[key],
        function() return db[key] end,
        function(value)
            db[key] = value
            Anchor()
        end)
end

local function RegisterSettings()
    local category = ns.pages.characterPanel.category

    local corner = Proxy(category, "corner", Settings.VarType.String, "Anchor corner")
    Settings.CreateDropdown(category, corner, function()
        local container = Settings.CreateControlTextContainer()
        container:Add("bottomleft", "Below the panel, left")
        container:Add("bottomright", "Below the panel, right")
        container:Add("topleft", "Above the panel, left")
        container:Add("topright", "Above the panel, right")
        return container:GetData()
    end, "Which corner of the character panel the row hangs from.")

    for _, key in ipairs({ "x", "y" }) do
        local setting = Proxy(category, key, Settings.VarType.Number, key:upper() .. " offset")
        local options = Settings.CreateSliderOptions(-400, 400, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, setting, options, "Pixels from the chosen corner.")
    end
end

function CharacterPanel.Enable()
    ns.db.specRowLayout = ns.db.specRowLayout or {}
    db = ns.db.specRowLayout
    ns.ApplyDefaults(db, DEFAULTS)

    row = CreateFrame("Frame", nil, PaperDollFrame)
    row:SetHeight(SIZE + 12)

    specLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specLabel:SetText(SPECIALIZATION)
    lootLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lootLabel:SetText(SELECT_LOOT_SPECIALIZATION)

    Anchor()
    RegisterSettings()

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    events:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
        if PaperDollFrame:IsShown() then Refresh() end
    end)
    PaperDollFrame:HookScript("OnShow", Refresh)
end

CharacterPanel.key = "characterPanel"
ns.RegisterModule("CharacterPanel", CharacterPanel)
