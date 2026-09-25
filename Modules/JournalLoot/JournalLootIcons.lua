local _, ns = ...

local Icons = {}

local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }

local function coversAll(itemSpecs, specs)
  for _, spec in ipairs(specs) do
    if not itemSpecs[spec.id] then return false end
  end
  return #specs > 0
end

function Icons.For(itemSpecs, classes, allClasses)
  local entries = {}
  if not itemSpecs or next(itemSpecs) == nil then return entries end

  local covered = {}
  local function cover(specs)
    for _, spec in ipairs(specs) do covered[spec.id] = true end
  end

  if allClasses then
    local everySpec, byRole = {}, {}
    for _, class in ipairs(classes) do
      for _, spec in ipairs(class.specs) do
        everySpec[#everySpec + 1] = spec
        byRole[spec.role] = byRole[spec.role] or {}
        table.insert(byRole[spec.role], spec)
      end
    end

    if coversAll(itemSpecs, everySpec) then
      return { { kind = "everyone" } }
    end

    for _, role in ipairs(ROLE_ORDER) do
      if byRole[role] and coversAll(itemSpecs, byRole[role]) then
        entries[#entries + 1] = { kind = "role", role = role }
        cover(byRole[role])
      end
    end
  end

  for _, class in ipairs(classes) do
    if coversAll(itemSpecs, class.specs) then
      entries[#entries + 1] = { kind = "class", file = class.file }
      cover(class.specs)
    end
  end

  for _, class in ipairs(classes) do
    for _, spec in ipairs(class.specs) do
      if itemSpecs[spec.id] and not covered[spec.id] then
        entries[#entries + 1] = { kind = "spec", icon = spec.icon }
      end
    end
  end

  return entries
end

if ns then ns.JournalLootIcons = Icons end
return Icons
