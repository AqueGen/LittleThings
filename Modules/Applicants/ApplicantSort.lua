local addonName, ns = ...

local Order = ns.ApplicantOrder
local Data = ns.ApplicantData
local Pipeline = ns.ApplicantPipeline

local ApplicantSort = {}

local KEYS = {
    rating = "Mythic+ rating, then item level",
    itemLevel = "Item level, then Mythic+ rating",
    dungeon = "This dungeon, then Mythic+ rating",
}
local KEY_ORDER = { "rating", "itemLevel", "dungeon" }

ApplicantSort.defaults = { by = "rating" }

local enabled = false

local function Options()
    return ns.db.applicantSortOptions
end

local function Sort(applicants)
    if not ns.db.applicantSort then return end
    local listing = Data.Listing()
    if not listing or not listing.isMythicPlus then return end

    local rating, itemLevel, dungeon = {}, {}, {}
    for _, applicantID in ipairs(applicants) do
        local application = Data.Application(applicantID, listing)
        if not application then return end
        local first = application.members[1]
        if first then
            rating[applicantID] = first.rating
            itemLevel[applicantID] = first.itemLevel
            dungeon[applicantID] = first.dungeonScore
        end
    end

    local by = Options().by
    if by == "itemLevel" then
        Order.Sort(applicants, { itemLevel, rating })
    elseif by == "dungeon" then
        Order.Sort(applicants, { dungeon, rating })
    else
        Order.Sort(applicants, { rating, itemLevel })
    end
end

local function KeyText(best)
    if not best then return "" end
    local color = best.timed and GREEN_FONT_COLOR or GRAY_FONT_COLOR
    return color:WrapTextInColorCode("+" .. best.level)
end

local function KeyLines(member)
    if not member.ltKeys then
        local overall = member:CreateFontString(nil, "ARTWORK", "GameFontNormalTiny")
        overall:SetPoint("BOTTOMLEFT", member.Rating, "RIGHT", 3, 0)
        local dungeon = member:CreateFontString(nil, "ARTWORK", "GameFontNormalTiny")
        dungeon:SetPoint("TOPLEFT", member.Rating, "RIGHT", 3, 0)
        member.ltKeys = { overall = overall, dungeon = dungeon }
    end
    return member.ltKeys
end

local function ShowKey(member, applicantID, memberIndex)
    local lines = KeyLines(member)
    local overallText, dungeonText = "", ""
    local listing = ns.db.applicantSort and member.Rating:IsShown() and not issecretvalue(applicantID) and Data.Listing()
    if listing and listing.isMythicPlus then
        overallText = KeyText(Data.OverallBest(applicantID, memberIndex) or nil)
        dungeonText = KeyText(Data.DungeonBest(applicantID, memberIndex, listing.activityID) or nil)
    end
    lines.overall:SetText(overallText)
    lines.dungeon:SetText(dungeonText)
end

local function ShowColumnLabel()
    local header = LFGApplicationViewerRatingColumnHeader
    if not header then return end
    if not header.ltKeyLabel then
        header.ltKeyLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        header.ltKeyLabel:SetPoint("LEFT", header, "RIGHT", 3, 0)
        header.ltKeyLabel:SetJustifyH("LEFT")
        header.ltKeyLabel:SetText("Best|nHere")
    end
    header.ltKeyLabel:SetShown(ns.db.applicantSort == true)
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
        function(value)
            Options().by = value
            Pipeline.Refresh()
        end)

    local function KeyOptions()
        local container = Settings.CreateControlTextContainer()
        for _, key in ipairs(KEY_ORDER) do
            container:Add(key, KEYS[key])
        end
        return container:GetData()
    end

    ns.AddToPage(page, Settings.CreateDropdown(page.category, setting, KeyOptions,
        "What puts an applicant higher. The second value only decides between applicants who tie on the first. This dungeon is the applicant's rating in the listed dungeon. A group that applies together counts as the player who sent the application."))
end

function ApplicantSort.Enable()
    if enabled then return end
    enabled = true
    Pipeline.Add(Pipeline.SORT, Sort)
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", ShowKey)
    ShowColumnLabel()
end

function ApplicantSort.OnSwitch(on)
    if on then ApplicantSort.Enable() end
    ShowColumnLabel()
    Pipeline.Refresh()
end

ApplicantSort.key = "applicantSort"
ns.RegisterModule("ApplicantSort", ApplicantSort)
