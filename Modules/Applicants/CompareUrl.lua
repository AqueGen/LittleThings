local _, ns = ...

local Realms = ns and ns.Realms or require("LogLinkRealms")
local Link = ns and ns.Link or require("LogLinkUrl")

local CompareUrl = { MAX = 30 }

local REGIONS = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }
local ROLES = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

local function safe(s)
  return type(s) == "string" and s ~= "" and not string.find(s, "[,/&?#%%]")
end

local function upTo99(n)
  return type(n) == "number" and math.floor(n) == n and n >= 1 and n <= 99
end

local function entry(region, member, numbered)
  local name = type(member.name) == "string" and Realms.Lower(member.name)
  local parts = { region, Realms.SlugFor(member.realm), name, ROLES[member.role], member.class }
  for i = 1, 5 do
    if not safe(parts[i]) then return nil end
  end
  if not string.match(member.class, "^%u+$") then return nil end
  if numbered then
    if not upTo99(member.app) then return nil end
    parts[6] = member.app
  end
  return table.concat(parts, "/")
end

local function list(region, members, max, numbered)
  local out, i = {}, 1
  while i <= #members do
    local app, batch = members[i].app, {}
    repeat
      local e = entry(region, members[i], numbered)
      if e then batch[#batch + 1] = e end
      i = i + 1
    until not numbered or i > #members or members[i].app ~= app
    if #out + #batch > max then break end
    for _, e in ipairs(batch) do out[#out + 1] = e end
  end
  return out
end

function CompareUrl.Build(base, regionID, keyLevel, group, applicants)
  base = Link.HubBase(base)
  if not base then return nil, "no summary site set" end
  local region = REGIONS[regionID or 0]
  if not region then return nil, "unknown region" end
  local p = list(region, applicants or {}, CompareUrl.MAX, true)
  if #p == 0 then return nil, "no applicants to compare" end
  local g = list(region, group or {}, 5)
  local query = {}
  if upTo99(keyLevel) then query[#query + 1] = "key=" .. keyLevel end
  if #g > 0 then query[#query + 1] = "g=" .. table.concat(g, ",") end
  query[#query + 1] = "p=" .. table.concat(p, ",")
  return base .. "/compare?" .. table.concat(query, "&"), nil, #p
end

if ns then ns.CompareUrl = CompareUrl end
return CompareUrl
