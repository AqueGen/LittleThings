package.path = "./Modules/JournalLoot/?.lua;" .. package.path

local Icons = require("JournalLootIcons")

local WARRIOR = { id = 1, file = "WARRIOR", specs = {
  { id = 71, role = "DAMAGER", icon = "arms" },
  { id = 72, role = "DAMAGER", icon = "fury" },
  { id = 73, role = "TANK", icon = "prot" },
} }
local PALADIN = { id = 2, file = "PALADIN", specs = {
  { id = 65, role = "HEALER", icon = "holy" },
  { id = 66, role = "TANK", icon = "protpala" },
  { id = 70, role = "DAMAGER", icon = "ret" },
} }
local PRIEST = { id = 5, file = "PRIEST", specs = {
  { id = 256, role = "HEALER", icon = "disc" },
  { id = 257, role = "HEALER", icon = "holypriest" },
  { id = 258, role = "DAMAGER", icon = "shadow" },
} }
local ALL = { WARRIOR, PALADIN, PRIEST }

local function set(...)
  local s = {}
  for _, id in ipairs({ ... }) do s[id] = true end
  return s
end

local function describe_entries(entries)
  local out = {}
  for _, e in ipairs(entries) do
    out[#out + 1] = e.kind .. ":" .. tostring(e.role or e.file or e.icon or "")
  end
  return table.concat(out, " ")
end

describe("Icons.For, one class", function()
  it("shows each spec the item drops for, in spec order", function()
    assert.equals("spec:arms spec:fury",describe_entries(Icons.For(set(72, 71), { WARRIOR }, false)))
  end)

  it("folds every spec of the class into the class icon", function()
    assert.equals("class:WARRIOR", describe_entries(Icons.For(set(71, 72, 73), { WARRIOR }, false)))
  end)

  it("never folds into a role or everyone with only one class scanned", function()
    assert.equals("spec:prot", describe_entries(Icons.For(set(73), { WARRIOR }, false)))
  end)

  it("returns nothing for an item no scanned spec gets", function()
    assert.same({}, Icons.For(set(), { WARRIOR }, false))
    assert.same({}, Icons.For(nil, { WARRIOR }, false))
  end)
end)

describe("Icons.For, all classes", function()
  it("shows one icon for an item every spec gets", function()
    assert.equals("everyone:", describe_entries(Icons.For(set(71, 72, 73, 65, 66, 70, 256, 257, 258), ALL, true)))
  end)

  it("folds a complete role into the role icon", function()
    assert.equals("role:HEALER", describe_entries(Icons.For(set(65, 256, 257), ALL, true)))
    assert.equals("role:TANK", describe_entries(Icons.For(set(73, 66), ALL, true)))
  end)

  it("lets a role and a class overlap rather than splitting either", function()
    assert.equals("role:HEALER class:PALADIN", describe_entries(Icons.For(set(65, 66, 70, 256, 257), ALL, true)))
  end)

  it("keeps the specs no role or class covers", function()
    assert.equals("class:WARRIOR spec:shadow", describe_entries(Icons.For(set(71, 72, 73, 258), ALL, true)))
  end)

  it("orders roles tank, healer, damage", function()
    assert.equals("role:TANK role:HEALER", describe_entries(Icons.For(set(73, 66, 65, 256, 257), ALL, true)))
  end)
end)
