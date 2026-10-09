local addonName, ns = ...

local Order = ns.ApplicantOrder
local Data = ns.ApplicantData
local Pipeline = ns.ApplicantPipeline

local ApplicantSort = {}

local CHOICES = {
    option = "by",
    label = "Mythic+ sort by",
    order = { "rating", "itemLevel", "dungeon" },
    names = {
        rating = "Rating, then item level",
        itemLevel = "Item level, then rating",
        dungeon = "This dungeon, then rating",
    },
    tooltip = "What puts a Mythic+ applicant higher. The second value only decides between applicants who tie on the first. This dungeon is the applicant's rating in the listed dungeon.",
}

ApplicantSort.defaults = { by = "rating" }

local enabled = false
local by

local function Options()
    ns.db.applicantSortOptions = ns.db.applicantSortOptions or {}
    ns.ApplyDefaults(ns.db.applicantSortOptions, ApplicantSort.defaults)
    return ns.db.applicantSortOptions
end

-- 12.x: reordering the applicants table taints the viewer, and its roster update then dies on
-- secret values (LFGList.lua:1699, :1760), restriction or not. Raids change roster all evening,
-- so only Mythic+ listings are sorted.
local function Sort(applicants)
    if not by or Data.Restricted() then return end
    local listing = Data.Listing()
    if not (listing and listing.isMythicPlus) then return end

    local filter = ns.ApplicantFilter
    local failed = ns.IsOn("classFilter") and filter and filter.state.failed or {}
    local passes, rating, itemLevel, dungeon = {}, {}, {}, {}
    for _, applicantID in ipairs(applicants) do
        local application = Data.Application(applicantID, listing)
        if not application then return end
        passes[applicantID] = failed[applicantID] and 0 or 1
        local first = application.members[1]
        if first then
            rating[applicantID] = first.rating
            itemLevel[applicantID] = first.itemLevel
            dungeon[applicantID] = first.dungeonScore
        end
    end

    local keys
    if by == "itemLevel" then
        keys = { passes, itemLevel, rating }
    elseif by == "dungeon" then
        keys = { passes, dungeon, rating }
    else
        keys = { passes, rating, itemLevel }
    end
    Order.Sort(applicants, keys)
end

local function OnRestrictionChange()
    local viewer = LFGListFrame and LFGListFrame.ApplicationViewer
    if by and viewer and viewer:IsVisible() then
        C_LFGList.RefreshApplicants()
    end
end

local function SortOptions()
    local list = {}
    for _, key in ipairs(CHOICES.order) do
        list[#list + 1] = { value = key, text = CHOICES.names[key] }
    end
    return list
end

function ApplicantSort.Pages(page)
    page:Group():Dropdown({ label = CHOICES.label, options = SortOptions, reload = true,
        default = ApplicantSort.defaults.by,
        tooltip = CHOICES.tooltip .. " A group that applies together counts as the player who sent the application.",
        get = function() return Options().by end,
        set = function(value) Options().by = value end })
end

function ApplicantSort.Enable()
    if enabled then return end
    enabled = true
    by = Options().by
    Pipeline.Add(Pipeline.SORT, Sort)
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    events:SetScript("OnEvent", OnRestrictionChange)
end

ApplicantSort.key = "applicantOrder"
ns.ApplicantSort = ApplicantSort
ns.RegisterModule("ApplicantSort", ApplicantSort)
