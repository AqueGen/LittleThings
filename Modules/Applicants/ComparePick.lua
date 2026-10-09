local _, ns = ...

local ComparePick = {}

local ORDER = { "TANK", "HEALER", "DAMAGER" }

local function choices(member)
  local out = {}
  if member.roles[member.role] then out[1] = member.role end
  for _, role in ipairs(ORDER) do
    if member.roles[role] and role ~= member.role then out[#out + 1] = role end
  end
  return out
end

local function assign(members, open, i, used, roles)
  if i > #members then return true end
  for _, role in ipairs(choices(members[i])) do
    if (used[role] or 0) < (open[role] or 0) then
      used[role] = (used[role] or 0) + 1
      roles[i] = role
      if assign(members, open, i + 1, used, roles) then return true end
      used[role] = used[role] - 1
    end
  end
  return false
end

local function mean(members)
  local sum = 0
  for _, m in ipairs(members) do sum = sum + (m.rating or 0) end
  return sum / #members
end

local function offered(member, open)
  local out = {}
  for _, role in ipairs(choices(member)) do
    if not open or (open[role] or 0) > 0 then out[#out + 1] = role end
  end
  return out
end

function ComparePick.Pick(applications, open)
  local kept, dropped = {}, 0
  for n, application in ipairs(applications) do
    local members = application.members
    if #members > 0 then
      if not open or assign(members, open, 1, {}, {}) then
        kept[#kept + 1] = { members = members, rating = mean(members), n = n }
      else
        dropped = dropped + #members
      end
    end
  end
  table.sort(kept, function(a, b)
    if a.rating ~= b.rating then return a.rating > b.rating end
    return a.n < b.n
  end)
  local list = {}
  for app, k in ipairs(kept) do
    for _, m in ipairs(k.members) do
      list[#list + 1] = { name = m.name, realm = m.realm, class = m.class, roles = offered(m, open), spec = m.spec, rating = m.rating, app = app }
    end
  end
  return list, dropped
end

if ns then ns.ComparePick = ComparePick end
return ComparePick
