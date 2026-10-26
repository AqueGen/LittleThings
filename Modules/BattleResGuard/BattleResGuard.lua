local addonName, ns = ...

local Rules = ns.BattleResRules
local BATTLE_RES = ns.FilterRules.BATTLE_RES
local Widgets = ns.Widgets
local T = Widgets.THEME

local BattleResGuard = {}

local REBIRTH = 20484
local INTERVAL = 0.1
local ROLE_DEFAULTS = { TANK = true, HEALER = true, DAMAGER = true }

local driver, overlay, confirm
local elapsed = 0
local charges, casters

local function InitializeDb()
    ns.db.battleResGuardRoles = ns.db.battleResGuardRoles or {}
    ns.ApplyDefaults(ns.db.battleResGuardRoles, ROLE_DEFAULTS)
end

local function RoleOn()
    local spec = GetSpecialization()
    local role = spec and GetSpecializationRole(spec)
    return role ~= nil and ns.db.battleResGuardRoles[role] == true
end

local function Members()
    local raid = IsInRaid()
    local prefix = raid and "raid" or "party"
    local count = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
    local members = {}
    for i = 1, count do
        local unit = prefix .. i
        members[i] = { name = UnitName(unit), class = select(2, UnitClass(unit)),
            dead = UnitIsDeadOrGhost(unit), connected = UnitIsConnected(unit) }
    end
    return members
end

local function HideAll()
    if overlay then
        overlay:Hide()
        confirm:Hide()
    end
end

local function Paint()
    confirm.charges:SetText(string.format("Battle res available: %s", charges.currentCharges))
    confirm.casters:SetText("Can res: " .. table.concat(casters, ", "))
end

local function ShowConfirm()
    local dialog = StaticPopup_FindVisible("DEATH")
    confirm:ClearAllPoints()
    if dialog then
        confirm:SetPoint("BOTTOM", dialog, "TOP", 0, 8)
    else
        confirm:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    end
    Paint()
    confirm:Show()
end

local function Build()
    if overlay then
        return
    end

    overlay = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetBackdrop(Widgets.FLAT)
    overlay:SetBackdropColor(T.gold[1], T.gold[2], T.gold[3], 0.12)
    overlay:SetBackdropBorderColor(T.gold[1], T.gold[2], T.gold[3], 1)
    local hover = overlay:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)
    overlay:SetScript("OnClick", ShowConfirm)
    overlay:Hide()

    confirm = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    confirm:SetFrameStrata("FULLSCREEN_DIALOG")
    confirm:SetSize(320, 96)
    confirm:SetBackdrop(Widgets.FLAT)
    confirm:SetBackdropColor(unpack(T.bg))
    confirm:SetBackdropBorderColor(unpack(T.border))
    confirm:EnableMouse(true)

    confirm.charges = confirm:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    confirm.charges:SetPoint("TOP", 0, -12)
    confirm.charges:SetTextColor(unpack(T.gold))

    confirm.casters = confirm:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    confirm.casters:SetPoint("TOP", confirm.charges, "BOTTOM", 0, -6)
    confirm.casters:SetWidth(296)
    confirm.casters:SetTextColor(unpack(T.text))

    local release = Widgets.Button(confirm, "Release anyway", 130)
    release:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -4, 10)
    release:SetScript("OnClick", function()
        RepopMe()
        confirm:Hide()
    end)

    local wait = Widgets.Button(confirm, "Wait for res", 130)
    wait:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 4, 10)
    wait:SetScript("OnClick", function() confirm:Hide() end)

    confirm:Hide()
end

local function Tick()
    local dialog = StaticPopup_FindVisible("DEATH")
    local button1 = dialog and dialog:GetButton1()
    if not (button1 and button1:IsShown() and button1:IsEnabled() and RoleOn()) then
        HideAll()
        return
    end

    charges = C_Spell.GetSpellCharges(REBIRTH)
    if Rules.ChargeState(charges, issecretvalue) == "none" then
        HideAll()
        return
    end

    casters = Rules.Casters(Members(), BATTLE_RES)
    if #casters == 0 then
        HideAll()
        return
    end

    overlay:ClearAllPoints()
    overlay:SetAllPoints(button1)
    overlay:Show()
    if confirm:IsShown() then
        Paint()
    end
end

local function OnUpdate(_, delta)
    elapsed = elapsed + delta
    if elapsed < INTERVAL then
        return
    end
    elapsed = 0
    Tick()
end

local function Watch()
    if ns.IsOn("battleResGuard") and UnitIsDead("player") then
        driver:SetScript("OnUpdate", OnUpdate)
    else
        driver:SetScript("OnUpdate", nil)
        HideAll()
    end
end

function BattleResGuard.Enable()
    InitializeDb()
    Build()
    if not driver then
        driver = CreateFrame("Frame")
        driver:RegisterEvent("PLAYER_DEAD")
        driver:RegisterEvent("PLAYER_ALIVE")
        driver:RegisterEvent("PLAYER_UNGHOST")
        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
        driver:SetScript("OnEvent", Watch)
    end
    Watch()
end

function BattleResGuard.OnSwitch(enabled)
    if enabled then
        BattleResGuard.Enable()
    elseif driver then
        Watch()
    end
end

local function RoleOption(role, label, tooltip)
    return { label = label, tooltip = tooltip, default = true,
        get = function() return ns.db.battleResGuardRoles[role] end,
        set = function(value) ns.db.battleResGuardRoles[role] = value end }
end

function BattleResGuard.Pages(page)
    InitializeDb()
    local group = page:Group("Ask before release as")
    group:Check(RoleOption("TANK", "Tank", "Release asks first while your current specialization is a tank."))
    group:Check(RoleOption("HEALER", "Healer", "Release asks first while your current specialization is a healer."))
    group:Check(RoleOption("DAMAGER", "Damage", "Release asks first while your current specialization deals damage."))
end

BattleResGuard.key = "battleResGuard"
ns.RegisterModule("BattleResGuard", BattleResGuard)
