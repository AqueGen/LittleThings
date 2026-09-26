local addonName, ns = ...

local Order = ns.ApplicantOrder

local ApplicantSort = {}

local KEYS = {
    rating = "Mythic+ rating, then item level",
    itemLevel = "Item level, then Mythic+ rating",
}
local KEY_ORDER = { "rating", "itemLevel" }

ApplicantSort.defaults = { by = "rating" }

local hooked = false

local function Options()
    return ns.db.applicantSortOptions
end

local function IsMythicPlusListing()
    local entry = C_LFGList.GetActiveEntryInfo()
    local activityID = entry and entry.activityIDs and entry.activityIDs[1]
    local activity = activityID and C_LFGList.GetActivityInfoTable(activityID)
    return activity ~= nil and activity.isMythicPlusActivity
end

local function Scores(applicants)
    local rating, itemLevel = {}, {}
    for _, applicantID in ipairs(applicants) do
        if issecretvalue(applicantID) then return nil end
        local _, _, _, _, level, _, _, _, _, _, _, score = C_LFGList.GetApplicantMemberInfo(applicantID, 1)
        if issecretvalue(score) or issecretvalue(level) then return nil end
        if type(score) == "number" then rating[applicantID] = score end
        if type(level) == "number" then itemLevel[applicantID] = level end
    end
    return { rating = rating, itemLevel = itemLevel }
end

local function SortApplicants(applicants)
    if not ns.db.applicantSort or type(applicants) ~= "table" or not IsMythicPlusListing() then return end
    local scores = Scores(applicants)
    if not scores then return end
    if Options().by == "itemLevel" then
        Order.Sort(applicants, { scores.itemLevel, scores.rating })
    else
        Order.Sort(applicants, { scores.rating, scores.itemLevel })
    end
end

function ApplicantSort.Pages(page)
    ns.db.applicantSortOptions = ns.db.applicantSortOptions or {}
    ns.ApplyDefaults(ns.db.applicantSortOptions, ApplicantSort.defaults)
    if not KEYS[Options().by] then
        Options().by = ApplicantSort.defaults.by
    end

    local setting = Settings.RegisterProxySetting(page.category, "LT_applicantSort_by", Settings.VarType.String,
        "Sort by", ApplicantSort.defaults.by,
        function() return Options().by end,
        function(value) Options().by = value end)

    local function KeyOptions()
        local container = Settings.CreateControlTextContainer()
        for _, key in ipairs(KEY_ORDER) do
            container:Add(key, KEYS[key])
        end
        return container:GetData()
    end

    ns.AddToPage(page, Settings.CreateDropdown(page.category, setting, KeyOptions,
        "What puts an applicant higher. The second value only decides between applicants who tie on the first. A group that applies together counts as the player who sent the application."))
end

function ApplicantSort.Enable()
    if hooked then return end
    hooked = true
    hooksecurefunc("LFGListUtil_SortApplicants", SortApplicants)
end

function ApplicantSort.OnSwitch(enabled)
    if enabled then
        ApplicantSort.Enable()
    end
end

ApplicantSort.key = "applicantSort"
ns.RegisterModule("ApplicantSort", ApplicantSort)
