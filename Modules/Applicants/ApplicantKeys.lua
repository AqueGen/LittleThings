local addonName, ns = ...

local Data = ns.ApplicantData
local Pipeline = ns.ApplicantPipeline
local Progress = ns.RaidProgress

local ApplicantKeys = {}

local enabled = false

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
    local on = ns.IsOn("applicantSort") == true
    local raid = listing ~= nil and listing.isRaid
    header.ltKeyLabel:SetShown(on and listing ~= nil and not raid)
    header.ltRaidLegend:SetShown(on and raid)
end

local function ShowKey(member, applicantID, memberIndex)
    local lines = KeyLines(member)
    local overallText, dungeonText = "", ""
    local listing = ns.IsOn("applicantSort") and not issecretvalue(applicantID) and Data.Listing()
    if listing and listing.isMythicPlus and member.Rating:IsShown() then
        overallText = KeyText(Data.OverallBest(applicantID, memberIndex) or nil, OVERALL_COLORS)
        dungeonText = KeyText(Data.DungeonBest(applicantID, memberIndex, listing.activityID) or nil, DUNGEON_COLORS)
    elseif listing and listing.isRaid and member.ItemLevel:IsShown() then
        local entries = Data.RaidEntries(applicantID, memberIndex)
        overallText = ProgressText(Progress.Best(entries, listing.mapID))
        dungeonText = ProgressText(Progress.For(entries, listing.mapID, listing.raidDifficulty))
    end
    PlaceLines(member, lines, listing and listing.isRaid)
    ShowColumnLabel(listing or nil)
    lines.overall:SetText(overallText)
    lines.dungeon:SetText(dungeonText)
end

function ApplicantKeys.Enable()
    if enabled then return end
    enabled = true
    hooksecurefunc("LFGListApplicationViewer_UpdateApplicantMember", ShowKey)
    ShowColumnLabel(Data.Listing())
end

function ApplicantKeys.OnSwitch(on)
    if on then ApplicantKeys.Enable() end
    ShowColumnLabel(Data.Listing())
    Pipeline.Refresh()
end

ApplicantKeys.key = "applicantSort"
ns.ApplicantKeys = ApplicantKeys
ns.RegisterModule("ApplicantKeys", ApplicantKeys)
