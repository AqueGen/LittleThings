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

  it("says why there is no link", function()
    assert.same({ nil, "no summary site set" }, { CompareUrl.Build(nil, EU, 15, {}, { ME }) })
    assert.same({ nil, "unknown region" }, { CompareUrl.Build(BASE, 99, 15, {}, { ME }) })
    assert.same({ nil, "no applicants to compare" }, { CompareUrl.Build(BASE, EU, 15, { ME }, {}) })
  end)
end)
