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

local function applications()
    local list = {}
    local ids = C_LFGList.GetApplicants()
    if not readable(ids) or type(ids) ~= "table" then return list end
    for _, applicantID in ipairs(ids) do
        local info = readable(applicantID) and C_LFGList.GetApplicantInfo(applicantID)
        if info and readable(info) and readable(info.numMembers, info.applicationStatus) and LIVE[info.applicationStatus] then
            local members = {}
            for i = 1, info.numMembers do
                local full, class, _, _, _, _, tank, healer, damage, role, _, rating = C_LFGList.GetApplicantMemberInfo(applicantID, i)
                if readable(full, class, tank, healer, damage, role, rating) and type(full) == "string" then
                    local name, realm = splitName(full)
                    members[#members + 1] = {
                        name = name, realm = realm, class = class, role = role, rating = rating,
                        roles = { TANK = tank == true, HEALER = healer == true, DAMAGER = damage == true },
                    }
                end
            end
            list[#list + 1] = { members = members }
        end
    end
    return list
end

local function wanted()
    if not (ns.db and ns.IsOn("compareButton") and ns.Link.HubBase(ns.db.logLinkHub)) then return false end
    local listing = ns.ApplicantData.Listing()
    return listing ~= nil and listing.isMythicPlus
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
    local group = ns.ApplicantData.Group(ns.ApplicantData.Listing() or {})
    local picked, dropped = ns.ComparePick.Pick(applications(), group.open)
    local url, problem, count = ns.CompareUrl.Build(ns.db.logLinkHub, GetCurrentRegion(), key, group.members, picked)
    if not url and dropped > 0 then problem = "no applicant fits the open roles" end
    local note = dropped > 0 and string.format(", %d dropped: role not needed", dropped) or ""
    ns.CopyLink(url, problem, count and string.format("Compare page for %d of %d applicants%s", count, #picked + dropped, note))
end

local function build()
    local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
    if button or not viewer then return end
    button = CreateFrame("Button", nil, viewer, "UIPanelButtonTemplate")
    button:SetSize(150, 22)
    button:SetPoint("TOPRIGHT", viewer.InfoBackground or viewer, "TOPRIGHT", -8, -8)
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

Compare.applications = applications
ns.RefreshCompareButton = refresh
Compare.key = "compareButton"
ns.RegisterModule("Compare", Compare)
