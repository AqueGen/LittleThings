local addonName, ns = ...

local Buttons = ns.IconButtons

local SignUpRoles = {}

local ROLES = { "TANK", "HEALER", "DAMAGER" }
local LABELS = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }

local bar

local function Roles()
    local leader, tank, healer, dps = GetLFGRoles()
    return leader, { TANK = tank, HEALER = healer, DAMAGER = dps }
end

local function OnClick(self)
    local leader, checked = Roles()
    checked[self.role] = not checked[self.role]
    SetLFGRoles(leader, checked.TANK, checked.HEALER, checked.DAMAGER)
    PlaySound(checked[self.role] and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

local function Refresh()
    if not bar:IsVisible() then return end
    local available = { C_LFGList.GetAvailableRoles() }
    local _, checked = Roles()
    local count = 0
    for i, role in ipairs(ROLES) do
        if available[i] then
            local b = Buttons.New(bar, count)
            b.role, b.tip = role, LABELS[role] .. " - sign up as"
            b.icon:SetAtlas(Buttons.ROLE_ATLAS[role])
            Buttons.SetActive(b, checked[role])
            b:Show()
            count = count + 1
        end
    end
    Buttons.Row(bar, count)
end

local function OnEvent(_, event, blockedAddon, blockedFunction)
    if event == "LFG_ROLE_UPDATE" then
        Refresh()
    elseif ns.IsOn("signUpRoles") and blockedAddon == addonName
        and type(blockedFunction) == "string" and blockedFunction:find("SetLFGRoles", 1, true) then
        ns.SetSwitch("signUpRoles", false)
        ns.Print("the game does not let addons change your group finder roles, so the role icons on the search panel are now off. Pick roles in the Dungeon Finder instead.")
    end
end

function SignUpRoles.Enable()
    if not bar then
        local panel = LFGListFrame.SearchPanel
        bar = CreateFrame("Frame", nil, panel)
        bar.buttons = {}
        bar.size = 20
        bar.onClick = OnClick
        -- ponytail: fixed spot left of PGF's top-right checkbox, an offset option if it collides with another addon
        bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -100, -31)
        bar:SetScript("OnShow", Refresh)

        local events = CreateFrame("Frame")
        events:RegisterEvent("LFG_ROLE_UPDATE")
        events:RegisterEvent("ADDON_ACTION_BLOCKED")
        events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
        events:SetScript("OnEvent", OnEvent)
    end
    bar:Show()
    Refresh()
end

function SignUpRoles.OnSwitch(on)
    if on then
        SignUpRoles.Enable()
    elseif bar then
        bar:Hide()
    end
end

SignUpRoles.key = "signUpRoles"
ns.RegisterModule("SignUpRoles", SignUpRoles)
