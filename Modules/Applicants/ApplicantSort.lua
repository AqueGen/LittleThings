local addonName, ns = ...

local Order = ns.ApplicantOrder
local Data = ns.ApplicantData
local Pipeline = ns.ApplicantPipeline
local Progress = ns.RaidProgress

local ApplicantSort = {}

local CHOICES = {
    mythicPlus = {
        option = "by",
        label = "Mythic+ sort by",
        order = { "rating", "itemLevel", "dungeon" },
        names = {
            rating = "Rating, then item level",
            itemLevel = "Item level, then rating",
            dungeon = "This dungeon, then rating",
        },
        short = { rating = "Rating", itemLevel = "Item level", dungeon = "This dungeon" },
        tooltip = "What puts a Mythic+ applicant higher. The second value only decides between applicants who tie on the first. This dungeon is the applicant's rating in the listed dungeon.",
    },
    raid = {
        option = "raidBy",
        label = "Raid sort by",
        order = { "progress", "itemLevel" },
        names = {
            progress = "Progress, then item level",
            itemLevel = "Item level, then progress",
        },
        short = { progress = "Progress", itemLevel = "Item level" },
        tooltip = "What puts a raid applicant higher. Progress is the applicant's kills in the listed raid from Raider.IO: any Mythic kills rank above Heroic, Heroic above Normal, then the number of bosses. Without Raider.IO every applicant ties on progress.",
    },
}

ApplicantSort.defaults = { by = "rating", raidBy = "progress" }

local enabled = false

local function Options()
    ns.db.applicantSortOptions = ns.db.applicantSortOptions or {}
    ns.ApplyDefaults(ns.db.applicantSortOptions, ApplicantSort.defaults)
    return ns.db.applicantSortOptions
end

local function Choices(listing)
    if not listing then return nil end
    if listing.isMythicPlus then return CHOICES.mythicPlus end
    if listing.isRaid then return CHOICES.raid end
    return nil
end

ApplicantSort.Choices = Choices

function ApplicantSort.GetBy(choices)
    return Options()[choices.option]
end

function ApplicantSort.SetBy(choices, value)
    Options()[choices.option] = value
    Pipeline.Refresh()
end

-- 12.x: reordering the applicants table taints the viewer, and its roster update then dies on
-- secret values (LFGList.lua:1699, :1760). Secrets only appear under addon restrictions, so the
-- list is never sorted while one is active.
local function Sort(applicants)
    if not ns.IsOn("applicantOrder") or Data.Restricted() then return end
    local listing = Data.Listing()
    local choices = Choices(listing)
    if not choices then return end

    local filter = ns.ApplicantFilter
    local failed = ns.IsOn("classFilter") and filter and filter.state.failed or {}
    local passes, rating, itemLevel, dungeon, progress = {}, {}, {}, {}, {}
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
        if listing.isRaid then
            progress[applicantID] = Progress.Score(Data.RaidEntries(applicantID, 1), listing.mapID)
        end
    end

    local by = ApplicantSort.GetBy(choices)
    local keys
    if listing.isRaid then
        keys = by == "itemLevel" and { passes, itemLevel, progress } or { passes, progress, itemLevel }
    elseif by == "itemLevel" then
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
    if ns.IsOn("applicantOrder") and viewer and viewer:IsVisible() then
        C_LFGList.RefreshApplicants()
    end
end

function ApplicantSort.Pages(page)
    for _, kind in ipairs({ "mythicPlus", "raid" }) do
        local choices = CHOICES[kind]
        local default = ApplicantSort.defaults[choices.option]
        if not choices.names[Options()[choices.option]] then
            Options()[choices.option] = default
        end

        local setting = Settings.RegisterProxySetting(page.category, "LT_applicantSort_" .. choices.option, Settings.VarType.String,
            choices.label, default,
            function() return ApplicantSort.GetBy(choices) end,
            function(value) ApplicantSort.SetBy(choices, value) end)

        local function Names()
            local container = Settings.CreateControlTextContainer()
            for _, key in ipairs(choices.order) do
                container:Add(key, choices.names[key])
            end
            return container:GetData()
        end

        ns.AddToPage(page, Settings.CreateDropdown(page.category, setting, Names,
            choices.tooltip .. " A group that applies together counts as the player who sent the application."))
    end
end

function ApplicantSort.Enable()
    if enabled then return end
    enabled = true
    Pipeline.Add(Pipeline.SORT, Sort)
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    events:SetScript("OnEvent", OnRestrictionChange)
end

function ApplicantSort.OnSwitch(on)
    if on then ApplicantSort.Enable() end
    Pipeline.Refresh()
end

ApplicantSort.key = "applicantOrder"
ns.ApplicantSort = ApplicantSort
ns.RegisterModule("ApplicantSort", ApplicantSort)
