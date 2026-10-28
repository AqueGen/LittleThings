local _, ns = ...

local Rules = {}

local REPLACE = {
    SAY = true, YELL = true, EMOTE = true,
    PARTY = true, RAID = true, RAID_WARNING = true, INSTANCE_CHAT = true,
    GUILD = true, GUILD_DISCORD = true, OFFICER = true, CHANNEL = true,
}

function Rules.Pick(current, group)
    if not REPLACE[current] then return nil end
    local wanted = "SAY"
    if group.instance then
        wanted = "INSTANCE_CHAT"
    elseif group.raid then
        wanted = "RAID"
    elseif group.party then
        wanted = "PARTY"
    end
    if wanted == current then return nil end
    return wanted
end

if ns then ns.ChatRules = Rules end
return Rules
