package.path = "./Modules/LogLink/?.lua;./Modules/Applicants/?.lua;" .. package.path

local CompareUrl = require("CompareUrl")

local EU = 3
local BASE = "https://brag-sheet.aquegen.workers.dev"
local ME = { name = "Borshbringer", realm = "Tarren Mill", class = "PALADIN", role = "TANK" }
local MINE = { name = "Borshbringer", realm = "Tarren Mill", class = "PALADIN", role = "TANK", app = 1 }

describe("CompareUrl.Build", function()
  it("lists the group and the applicants with slug, lowercased name, role and class", function()
    local url = CompareUrl.Build(EU, 15, { ME }, {
      { name = "Ктулху", realm = "Гордунни", class = "MAGE", role = "DAMAGER", app = 1 },
      { name = "Medvedyk", realm = "Silvermoon", class = "DRUID", role = "HEALER", app = 2 },
    })
    assert.equals(BASE .. "/compare?key=15&g=eu/tarren-mill/borshbringer/tank/PALADIN&p=eu/gordunni/ктулху/dps/MAGE/1,eu/silvermoon/medvedyk/healer/DRUID/2", url)
  end)

  it("leaves out the key when there is none and skips members it cannot place", function()
    local url = CompareUrl.Build(EU, nil, {}, {
      { name = "Medvedyk", realm = "Silvermoon", class = "DRUID", role = "NONE", app = 1 },
      { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 2 },
      { name = "Nobody", realm = nil, class = "ROGUE", role = "DAMAGER", app = 3 },
    })
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/cutlers/dps/ROGUE/2", url)
  end)

  it("caps the applicants at 30", function()
    local many = {}
    for i = 1, 31 do many[i] = { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = i } end
    local url = CompareUrl.Build(EU, 15, {}, many)
    local _, commas = string.gsub(url, ",", ",")
    assert.equals(29, commas)
  end)

  it("keeps at most five group members", function()
    local six = {}
    for i = 1, 6 do six[i] = ME end
    local url = CompareUrl.Build(EU, nil, six, { { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 1 } })
    local g = string.match(url, "g=([^&]*)")
    local _, commas = string.gsub(g, ",", ",")
    assert.equals(4, commas)
  end)

  it("fills the 30 slots past members it cannot place", function()
    local many = {}
    for i = 1, 40 do
      many[i] = { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = i <= 10 and "NONE" or "DAMAGER", app = i }
    end
    local url, problem, count = CompareUrl.Build(EU, nil, {}, many)
    local _, commas = string.gsub(url, ",", ",")
    assert.equals(29, commas)
    assert.is_nil(problem)
    assert.equals(30, count)
  end)

  it("skips a name with a separator in it and a class that is not an upper-case token", function()
    local url = CompareUrl.Build(EU, nil, {}, {
      { name = "Bad,Name", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 1 },
      { name = "Lower", realm = "Tarren Mill", class = "mage", role = "DAMAGER", app = 2 },
      { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 3 },
    })
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/cutlers/dps/ROGUE/3", url)
  end)

  it("writes a whole rating up to 9999 after the application number and leaves out anything else", function()
    local url = CompareUrl.Build(EU, nil, {}, {
      { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 1, rating = 2875.6 },
      { name = "None", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 2 },
      { name = "Huge", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 3, rating = 10000 },
    })
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/cutlers/dps/ROGUE/1/2875,eu/tarren-mill/none/dps/ROGUE/2,eu/tarren-mill/huge/dps/ROGUE/3", url)
  end)

  it("gives the members of one application the same number", function()
    local url = CompareUrl.Build(EU, nil, {}, {
      { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 1 },
      { name = "Medvedyk", realm = "Silvermoon", class = "DRUID", role = "HEALER", app = 1 },
      { name = "Ктулху", realm = "Гордунни", class = "MAGE", role = "DAMAGER", app = 2 },
    })
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/cutlers/dps/ROGUE/1,eu/silvermoon/medvedyk/healer/DRUID/1,eu/gordunni/ктулху/dps/MAGE/2", url)
  end)

  it("skips an applicant whose application number is not a whole number from 1 to 99", function()
    local url = CompareUrl.Build(EU, nil, {}, {
      { name = "None", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER" },
      { name = "Zero", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 0 },
      { name = "Half", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 1.5 },
      { name = "Big", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 100 },
      { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = 99 },
    })
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/cutlers/dps/ROGUE/99", url)
  end)

  it("stops before an application that would cross the cap", function()
    local many = {}
    for i = 1, 28 do many[i] = { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER", app = i } end
    for i = 29, 31 do many[i] = { name = "Trio", realm = "Tarren Mill", class = "MAGE", role = "DAMAGER", app = 29 } end
    many[32] = { name = "Solo", realm = "Tarren Mill", class = "MAGE", role = "DAMAGER", app = 30 }
    local url, _, count = CompareUrl.Build(EU, nil, {}, many)
    assert.equals(28, count)
    assert.is_nil(string.find(url, "trio"))
  end)

  it("leaves out a key level that is not a whole number from 1 to 99", function()
    local only = BASE .. "/compare?p=eu/tarren-mill/borshbringer/tank/PALADIN/1"
    assert.equals(only, CompareUrl.Build(EU, 15.5, {}, { MINE }))
    assert.equals(only, CompareUrl.Build(EU, 150, {}, { MINE }))
  end)

  it("treats a missing group or applicant list as empty", function()
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/borshbringer/tank/PALADIN/1", CompareUrl.Build(EU, nil, nil, { MINE }))
    assert.same({ nil, "no applicants to compare" }, { CompareUrl.Build(EU, nil, { ME }, nil) })
  end)

  it("says why there is no link", function()
    assert.same({ nil, "unknown region" }, { CompareUrl.Build(99, 15, {}, { MINE }) })
    assert.same({ nil, "no applicants to compare" }, { CompareUrl.Build(EU, 15, { ME }, {}) })
  end)
end)
