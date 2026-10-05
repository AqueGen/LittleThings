local _, ns = ...

local Realms = ns and ns.Realms or require("LogLinkRealms")
local Link = ns and ns.Link or require("LogLinkUrl")

local CompareUrl = { MAX = 30 }

local REGIONS = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }
local ROLES = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

local function entry(region, member)
  local role = ROLES[member.role]
  local slug = Realms.SlugFor(member.realm)
  if not role or not slug or type(member.name) ~= "string" or member.name == "" or type(member.class) ~= "string" then return nil end
  return table.concat({ region, slug, Realms.Lower(member.name), role, member.class }, "/")
end

local function list(region, members, max)
  local out = {}
  for _, member in ipairs(members) do
    if #out >= max then break end
    local e = entry(region, member)
    if e then out[#out + 1] = e end
  end
  return out
end

function CompareUrl.Build(base, regionID, keyLevel, group, applicants)
  base = Link.HubBase(base)
  if not base then return nil, "no summary site set" end
  local region = REGIONS[regionID or 0]
  if not region then return nil, "unknown region" end
  local p = list(region, applicants, CompareUrl.MAX)
  if #p == 0 then return nil, "no applicants to compare" end
  local g = list(region, group, 5)
  local query = {}
  if type(keyLevel) == "number" and keyLevel > 0 then query[#query + 1] = "key=" .. keyLevel end
  if #g > 0 then query[#query + 1] = "g=" .. table.concat(g, ",") end
  query[#query + 1] = "p=" .. table.concat(p, ",")
  return base .. "/compare?" .. table.concat(query, "&")
end

if ns then ns.CompareUrl = CompareUrl end
return CompareUrl
