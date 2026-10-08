local _, ns = ...

local Realms = ns and ns.Realms or require("LogLinkRealms")

local Link = {}

-- The Mythic+ zone the link should land on. Warcraft Logs numbers its zones, and
-- a character page without one opens on the raid tab - which is the whole reason
-- this addon exists, because both Archon and Raider.IO already copy a link and
-- both land there.
--
-- One number per season, changed by hand. There is no API call that maps "the
-- current Mythic+ season" to a Warcraft Logs zone id, and guessing it wrong sends
-- the reader to an empty page rather than to no page.
Link.ZONE = 55
Link.ZONE_NAME = "Mythic+ Season 2"

-- Blizzard's region ids against the site's own path segment. GetCurrentRegion
-- returns the number; the site wants the letters.
local REGIONS = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }
Link.REGIONS = REGIONS

local function parts(name, realm, regionID)
  if type(name) ~= "string" or name == "" then return nil, "no character name" end

  local slug = Realms.SlugFor(realm)
  if not slug then return nil, "no realm for " .. name end

  local region = REGIONS[regionID or 0]
  if not region then return nil, "unknown region" end

  return string.format("%s/%s/%s", region, slug, Realms.Lower(name))
end

---@param name string
---@param realm string
---@param regionID number|nil @defaults to the client's own region
---@param zone number|nil @defaults to Link.ZONE, false for no zone at all
---@return string|nil url
---@return string|nil problem @why there is no url
function Link.For(name, realm, regionID, zone)
  local path, problem = parts(name, realm, regionID)
  if not path then return nil, problem end

  local url = "https://www.warcraftlogs.com/character/" .. path
  if zone == false then return url end
  return url .. "?zone=" .. tostring(zone or Link.ZONE)
end

Link.HUB = "https://brag-sheet.aquegen.workers.dev"

function Link.Hub(name, realm, regionID)
  local path, problem = parts(name, realm, regionID)
  if not path then return nil, problem end
  return Link.HUB .. "/" .. path
end

if ns then ns.Link = Link end
return Link
