local addonName, ns = ...

local Order = ns.ApplicantOrder
local Data = ns.ApplicantData
local Pipeline = ns.ApplicantPipeline
local Progress = ns.RaidProgress

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
    if not listing or not (listing.isMythicPlus or listing.isRaid) then return end

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
    if listing.isRaid or by == "itemLevel" then
        Order.Sort(applicants, { itemLevel, rating })
    elseif by == "dungeon" then
        Order.Sort(applicants, { dungeon, rating })
    else
        Order.Sort(applicants, { rating, itemLevel })
    end
end

local OVERALL_COLORS = { timed = CreateColor(0.35, 0.75, 1), untimed = CreateColor(0.5, 0.55, 0.65) }
local DUNGEON_COLORS = { timed = GREEN_FONT_COLOR, untimed = GRAY_FONT_COLOR }

local function KeyText(best, colors)
    if not best then return "" end
    local color = best.timed and colors.timed or colors.untimed
    return color:WrapTextInColorCode("+" .. best.level)
end

local DIFFICULTY_COLORS = { [1] = CreateColor(0.12, 1, 0), [2] = CreateColor(0, 0.44, 0.87), [3] = CreateColor(0.64, 0.21, 0.93) }
local RAID_COLUMN_X = 200

local function KeyLines(member)
    if not member.ltKeys then
        member.ltKeys = {
            overall = member:CreateFontString(nil, "ARTWORK", "GameFontNormalTiny"),
            dungeon = member:CreateFontString(nil, "ARTWORK", "GameFontNormalTiny"),
        }
    end
    return member.ltKeys
end

local function PlaceLines(member, lines, raid)
    lines.overall:ClearAllPoints()
    lines.dungeon:ClearAllPoints()
    if raid then
        lines.overall:SetPoint("BOTTOMLEFT", member, "LEFT", RAID_COLUMN_X, 0)
        lines.dungeon:SetPoint("TOPLEFT", member, "LEFT", RAID_COLUMN_X, 0)
    else
        lines.overall:SetPoint("BOTTOMLEFT", member.Rating, "RIGHT", 3, 0)
        lines.dungeon:SetPoint("TOPLEFT", member.Rating, "RIGHT", 3, 0)
    end
end

local function RaidEntries(applicantID, memberIndex)
    local rio = _G.RaiderIO
    if type(rio) ~= "table" or type(rio.GetProfile) ~= "function" then return nil end
    local name = C_LFGList.GetApplicantMemberInfo(applicantID, memberIndex)
    if type(name) ~= "string" or issecretvalue(name) then return nil end
    if not name:find("-", 1, true) then
        name = name .. "-" .. GetNormalizedRealmName()
    end
    local ok, profile = pcall(rio.GetProfile, name)
    local raid = ok and type(profile) == "table" and profile.raidProfile
    return raid and raid.progress
end

local function ProgressText(entry)
    local text = Progress.Text(entry)
    local color = entry and DIFFICULTY_COLORS[entry.difficulty]
    return (color and text ~= "") and color:WrapTextInColorCode(text) or text
end

local function ShowKey(member, applicantID, memberIndex)
    local lines = KeyLines(member)
    local overallText, dungeonText = "", ""
    local listing = ns.db.applicantSort and not issecretvalue(applicantID) and Data.Listing()
    if listing and listing.isMythicPlus and member.Rating:IsShown() then
        overallText = KeyText(Data.OverallBest(applicantID, memberIndex) or nil, OVERALL_COLORS)
        dungeonText = KeyText(Data.DungeonBest(applicantID, memberIndex, listing.activityID) or nil, DUNGEON_COLORS)
    elseif listing and listing.isRaid and member.ItemLevel:IsShown() then
        local entries = RaidEntries(applicantID, memberIndex)
        overallText = ProgressText(Progress.Best(entries))
        dungeonText = ProgressText(Progress.For(entries, listing.mapID, listing.raidDifficulty))
    end
    PlaceLines(member, lines, listing and listing.isRaid)
    lines.overall:SetText(overallText)
    lines.dungeon:SetText(dungeonText)
end

local function ShowColumnLabel()
    local header = LFGApplicationViewerRatingColumnHeader
    if not header then return end
    if not header.ltKeyLabel then
        header.ltKeyLabel = header:GetParent():CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        header.ltKeyLabel:SetPoint("LEFT", header, "RIGHT", 3, 0)
        header.ltKeyLabel:SetJustifyH("LEFT")
        header.ltKeyLabel:SetText(OVERALL_COLORS.timed:WrapTextInColorCode("Best") .. "|n" .. DUNGEON_COLORS.timed:WrapTextInColorCode("Here"))
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
        "What puts a Mythic+ applicant higher; raid applicants always go by item level, then Mythic+ rating. The second value only decides between applicants who tie on the first. This dungeon is the applicant's rating in the listed dungeon. A group that applies together counts as the player who sent the application."))
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
