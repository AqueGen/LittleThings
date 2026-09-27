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
        tooltip = "What puts a raid applicant higher. Progress is the applicant's kills in the listed raid from Raider.IO: any Mythic kills rank above Heroic, Heroic above Normal, then the number of bosses. Without Raider.IO every applicant ties on progress.",
    },
}

ApplicantSort.defaults = { by = "rating", raidBy = "progress" }

local enabled = false

local function Options()
    return ns.db.applicantSortOptions
end

function ApplicantSort.Choices(listing)
    if not listing then return nil end
    if listing.isMythicPlus then return CHOICES.mythicPlus end
    if listing.isRaid then return CHOICES.raid end
    return nil
end

function ApplicantSort.GetBy(choices)
    return Options()[choices.option]
end

function ApplicantSort.SetBy(choices, value)
    Options()[choices.option] = value
    Pipeline.Refresh()
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

local function Sort(applicants)
    if not ns.db.applicantSort then return end
    local listing = Data.Listing()
    local choices = ApplicantSort.Choices(listing)
    if not choices then return end

    local rating, itemLevel, dungeon, progress = {}, {}, {}, {}
    for _, applicantID in ipairs(applicants) do
        local application = Data.Application(applicantID, listing)
        if not application then return end
        local first = application.members[1]
        if first then
            rating[applicantID] = first.rating
            itemLevel[applicantID] = first.itemLevel
            dungeon[applicantID] = first.dungeonScore
        end
        if listing.isRaid then
            progress[applicantID] = Progress.Score(RaidEntries(applicantID, 1), listing.mapID)
        end
    end

    local by = ApplicantSort.GetBy(choices)
    if listing.isRaid then
        if by == "itemLevel" then
            Order.Sort(applicants, { itemLevel, progress })
        else
            Order.Sort(applicants, { progress, itemLevel })
        end
    elseif by == "itemLevel" then
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
local RAID_COLUMN_RIGHT = 201

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
        lines.overall:SetPoint("BOTTOMRIGHT", member, "LEFT", RAID_COLUMN_RIGHT, 0)
        lines.dungeon:SetPoint("TOPRIGHT", member, "LEFT", RAID_COLUMN_RIGHT, 0)
    else
        lines.overall:SetPoint("BOTTOMLEFT", member.Rating, "RIGHT", 3, 0)
        lines.dungeon:SetPoint("TOPLEFT", member.Rating, "RIGHT", 3, 0)
    end
end

local function ProgressText(entry)
    local text = Progress.Text(entry, true)
    local color = entry and DIFFICULTY_COLORS[entry.difficulty]
    return (color and text ~= "") and color:WrapTextInColorCode(text) or text
end

local RAID_LEGEND = DIFFICULTY_COLORS[3]:WrapTextInColorCode("Mythic") .. "|n"
    .. DIFFICULTY_COLORS[2]:WrapTextInColorCode("Heroic") .. "|n"
    .. DIFFICULTY_COLORS[1]:WrapTextInColorCode("Normal")

local function ShowColumnLabel(listing)
    local header = LFGApplicationViewerRatingColumnHeader
    if not header then return end
    local viewer = header:GetParent()
    if not header.ltKeyLabel then
        header.ltKeyLabel = viewer:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        header.ltKeyLabel:SetPoint("LEFT", header, "RIGHT", 3, 0)
        header.ltKeyLabel:SetJustifyH("LEFT")
        header.ltKeyLabel:SetText(OVERALL_COLORS.timed:WrapTextInColorCode("Best") .. "|n" .. DUNGEON_COLORS.timed:WrapTextInColorCode("Here"))
        header.ltRaidLegend = viewer:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
        header.ltRaidLegend:SetPoint("LEFT", viewer.ItemLevelColumnHeader, "RIGHT", 6, 0)
        header.ltRaidLegend:SetJustifyH("LEFT")
        header.ltRaidLegend:SetText(RAID_LEGEND)
    end
    local on = ns.db.applicantSort == true
    local raid = listing ~= nil and listing.isRaid
    header.ltKeyLabel:SetShown(on and not raid)
    header.ltRaidLegend:SetShown(on and raid)
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
    ShowColumnLabel(listing or nil)
    lines.overall:SetText(overallText)
    lines.dungeon:SetText(dungeonText)
end

function ApplicantSort.Pages(page)
    ns.db.applicantSortOptions = ns.db.applicantSortOptions or {}
    ns.ApplyDefaults(ns.db.applicantSortOptions, ApplicantSort.defaults)

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
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", ShowKey)
    ShowColumnLabel(Data.Listing())
end

function ApplicantSort.OnSwitch(on)
    if on then ApplicantSort.Enable() end
    ShowColumnLabel(Data.Listing())
    Pipeline.Refresh()
end

ApplicantSort.key = "applicantSort"
ns.ApplicantSort = ApplicantSort
ns.RegisterModule("ApplicantSort", ApplicantSort)
