local _, ns = ...

local Compare = {}
local button

local LIVE = { applied = true, invited = true }

local function readable(...)
    for i = 1, select("#", ...) do
        if issecretvalue(select(i, ...)) then return false end
    end
    return true
end

local function splitName(full)
    local name, realm = string.match(full, "^(.-)%-(.+)$")
    if name then return name, realm end
    return full, GetNormalizedRealmName()
end

local function applicants()
    local list = {}
    local ids = C_LFGList.GetApplicants()
    if not readable(ids) or type(ids) ~= "table" then return list end
    for _, applicantID in ipairs(ids) do
        local info = readable(applicantID) and C_LFGList.GetApplicantInfo(applicantID)
        if info and readable(info) and readable(info.numMembers, info.applicationStatus) and LIVE[info.applicationStatus] then
            for i = 1, info.numMembers do
                local full, class, _, _, _, _, _, _, _, role = C_LFGList.GetApplicantMemberInfo(applicantID, i)
                if readable(full, class, role) and type(full) == "string" then
                    local name, realm = splitName(full)
                    list[#list + 1] = { name = name, realm = realm, class = class, role = role }
                end
            end
        end
    end
    return list
end

local function group()
    local list = {}
    local units = { "player" }
    for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    for _, unit in ipairs(units) do
        local name, realm = UnitName(unit)
        local _, class = UnitClass(unit)
        local role = UnitGroupRolesAssigned(unit)
        if readable(name, realm, class, role) and type(name) == "string" then
            if unit == "player" and role == "NONE" then
                local spec = GetSpecialization()
                role = spec and GetSpecializationRole(spec) or role
            end
            list[#list + 1] = { name = name, realm = (realm and realm ~= "") and realm or GetNormalizedRealmName(), class = class, role = role }
        end
    end
    return list
end

local function wanted()
    return ns.db and ns.IsOn("compareButton") and ns.Link.HubBase(ns.db.logLinkHub) ~= nil
end

local function refresh()
    if button then button:SetShown(wanted() and true or false) end
end

local function onClick()
    if ns.ApplicantData.Restricted() then
        ns.Print("the game is restricting addons right now; try again in a moment")
        return
    end
    local key = C_MythicPlus.GetOwnedKeystoneLevel()
    ns.CopyLink(ns.CompareUrl.Build(ns.db.logLinkHub, GetCurrentRegion(), key, group(), applicants()))
end

local function build()
    local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
    if button or not viewer then return end
    button = CreateFrame("Button", nil, viewer, "UIPanelButtonTemplate")
    button:SetSize(150, 22)
    button:SetPoint("BOTTOM", viewer, "BOTTOM", 0, 4)
    button:SetText("Compare applicants")
    button:SetScript("OnClick", onClick)
    viewer:HookScript("OnShow", refresh)
    refresh()
end

function Compare.Enable()
    build()
end

function Compare.OnSwitch()
    build()
    refresh()
end

Compare.key = "compareButton"
ns.RegisterModule("Compare", Compare)
