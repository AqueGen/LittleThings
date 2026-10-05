package.path = "./Modules/LogLink/?.lua;./Modules/Applicants/?.lua;" .. package.path

local CompareUrl = require("CompareUrl")

local EU = 3
local BASE = "https://brag-sheet.aquegen.workers.dev"
local ME = { name = "Borshbringer", realm = "Tarren Mill", class = "PALADIN", role = "TANK" }

describe("CompareUrl.Build", function()
  it("lists the group and the applicants with slug, lowercased name, role and class", function()
    local url = CompareUrl.Build(BASE, EU, 15, { ME }, {
      { name = "Ктулху", realm = "Гордунни", class = "MAGE", role = "DAMAGER" },
      { name = "Medvedyk", realm = "Silvermoon", class = "DRUID", role = "HEALER" },
    })
    assert.equals(BASE .. "/compare?key=15&g=eu/tarren-mill/borshbringer/tank/PALADIN&p=eu/gordunni/ктулху/dps/MAGE,eu/silvermoon/medvedyk/healer/DRUID", url)
  end)

  it("leaves out the key when there is none and skips members it cannot place", function()
    local url = CompareUrl.Build(BASE .. "/", EU, nil, {}, {
      { name = "Medvedyk", realm = "Silvermoon", class = "DRUID", role = "NONE" },
      { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER" },
      { name = "Nobody", realm = nil, class = "ROGUE", role = "DAMAGER" },
    })
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/cutlers/dps/ROGUE", url)
  end)

  it("caps the applicants at 30", function()
    local many = {}
    for i = 1, 31 do many[i] = { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER" } end
    local url = CompareUrl.Build(BASE, EU, 15, {}, many)
    local _, commas = string.gsub(url, ",", ",")
    assert.equals(29, commas)
  end)

  it("keeps at most five group members", function()
    local six = {}
    for i = 1, 6 do six[i] = ME end
    local url = CompareUrl.Build(BASE, EU, nil, six, { ME })
    local g = string.match(url, "g=([^&]*)")
    local _, commas = string.gsub(g, ",", ",")
    assert.equals(4, commas)
  end)

  it("fills the 30 slots past members it cannot place", function()
    local many = {}
    for i = 1, 40 do
      many[i] = { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = i <= 10 and "NONE" or "DAMAGER" }
    end
    local url, problem, count = CompareUrl.Build(BASE, EU, nil, {}, many)
    local _, commas = string.gsub(url, ",", ",")
    assert.equals(29, commas)
    assert.is_nil(problem)
    assert.equals(30, count)
  end)

  it("skips a name with a separator in it and a class that is not an upper-case token", function()
    local url = CompareUrl.Build(BASE, EU, nil, {}, {
      { name = "Bad,Name", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER" },
      { name = "Lower", realm = "Tarren Mill", class = "mage", role = "DAMAGER" },
      { name = "Cutlers", realm = "Tarren Mill", class = "ROGUE", role = "DAMAGER" },
    })
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/cutlers/dps/ROGUE", url)
  end)

  it("leaves out a key level that is not a whole number from 1 to 99", function()
    local only = BASE .. "/compare?p=eu/tarren-mill/borshbringer/tank/PALADIN"
    assert.equals(only, CompareUrl.Build(BASE, EU, 15.5, {}, { ME }))
    assert.equals(only, CompareUrl.Build(BASE, EU, 150, {}, { ME }))
  end)

  it("treats a missing group or applicant list as empty", function()
    assert.equals(BASE .. "/compare?p=eu/tarren-mill/borshbringer/tank/PALADIN", CompareUrl.Build(BASE, EU, nil, nil, { ME }))
    assert.same({ nil, "no applicants to compare" }, { CompareUrl.Build(BASE, EU, nil, { ME }, nil) })
  end)

  it("says why there is no link", function()
    assert.same({ nil, "no summary site set" }, { CompareUrl.Build(nil, EU, 15, {}, { ME }) })
    assert.same({ nil, "unknown region" }, { CompareUrl.Build(BASE, 99, 15, {}, { ME }) })
    assert.same({ nil, "no applicants to compare" }, { CompareUrl.Build(BASE, EU, 15, { ME }, {}) })
  end)
end)
