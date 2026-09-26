package.path = "./Modules/Applicants/?.lua;" .. package.path

local Rules = require("FilterRules")

local NEED, EXCLUDE = Rules.NEED, Rules.EXCLUDE
local OPEN_GROUP = { open = { TANK = 1, HEALER = 1, DAMAGER = 3 }, hasBloodlust = false, hasBattleRes = false }

local function member(class, fields)
  local m = { class = class, roles = { TANK = false, HEALER = false, DAMAGER = true }, rating = 2500, itemLevel = 290 }
  for k, v in pairs(fields or {}) do m[k] = v end
  return m
end

local function app(...)
  return { members = { ... } }
end

local function settings(fields)
  local s = Rules.Defaults()
  for k, v in pairs(fields or {}) do s[k] = v end
  return s
end

describe("Rules.Next", function()
  it("cycles neutral, need, exclude, neutral", function()
    assert.equals(NEED, Rules.Next(nil))
    assert.equals(EXCLUDE, Rules.Next(NEED))
    assert.is_nil(Rules.Next(EXCLUDE))
  end)
end)

describe("Rules.ParseNumber", function()
  it("reads a whole number", function()
    assert.equals(2500, Rules.ParseNumber("2500"))
    assert.equals(0, Rules.ParseNumber("0"))
  end)

  it("treats empty or non-numeric text as no limit", function()
    assert.is_nil(Rules.ParseNumber(""))
    assert.is_nil(Rules.ParseNumber("abc"))
    assert.is_nil(Rules.ParseNumber(nil))
  end)
end)

describe("Rules.IsActive", function()
  it("is off for the defaults", function()
    assert.is_false(Rules.IsActive(settings()))
  end)

  it("is on for any class pick, role off, minimum or checkbox", function()
    assert.is_true(Rules.IsActive(settings({ classes = { MAGE = NEED } })))
    assert.is_true(Rules.IsActive(settings({ roles = { TANK = false, HEALER = true, DAMAGER = true } })))
    assert.is_true(Rules.IsActive(settings({ minRating = 0 })))
    assert.is_true(Rules.IsActive(settings({ timedOnly = true })))
    assert.is_true(Rules.IsActive(settings({ bloodlustFit = true })))
  end)

  it("ignores the mode", function()
    assert.is_false(Rules.IsActive(settings({ mode = "hide" })))
  end)
end)

describe("Rules.Passes, classes", function()
  it("drops an application with an excluded class in any member", function()
    assert.is_false(Rules.Passes(app(member("MAGE"), member("PALADIN")), OPEN_GROUP, settings({ classes = { PALADIN = EXCLUDE } })))
  end)

  it("keeps an application with any one needed class", function()
    local s = settings({ classes = { SHAMAN = NEED, MAGE = NEED } })
    assert.is_true(Rules.Passes(app(member("WARRIOR"), member("MAGE")), OPEN_GROUP, s))
    assert.is_false(Rules.Passes(app(member("WARRIOR")), OPEN_GROUP, s))
  end)
end)

describe("Rules.Passes, minimums", function()
  it("drops a member below the minimum rating or item level", function()
    assert.is_false(Rules.Passes(app(member("MAGE", { rating = 2400 })), OPEN_GROUP, settings({ minRating = 2500 })))
    assert.is_true(Rules.Passes(app(member("MAGE", { rating = 2500 })), OPEN_GROUP, settings({ minRating = 2500 })))
    assert.is_false(Rules.Passes(app(member("MAGE", { itemLevel = 280 })), OPEN_GROUP, settings({ minItemLevel = 285 })))
  end)

  it("needs every member of a group application to meet the minimums", function()
    local s = settings({ minRating = 2500 })
    assert.is_false(Rules.Passes(app(member("MAGE", { rating = 3000 }), member("PRIEST", { rating = 1200 })), OPEN_GROUP, s))
  end)

  it("lets everyone through a minimum of zero", function()
    assert.is_true(Rules.Passes(app(member("MAGE", { rating = 0 })), OPEN_GROUP, settings({ minRating = 0 })))
  end)

  it("drops a member with no run in this dungeon when a key minimum is set", function()
    local s = settings({ minDungeonLevel = 10 })
    assert.is_false(Rules.Passes(app(member("MAGE")), OPEN_GROUP, s))
    assert.is_true(Rules.Passes(app(member("MAGE", { dungeonLevel = 10 })), OPEN_GROUP, s))
    assert.is_false(Rules.Passes(app(member("MAGE", { dungeonLevel = 9 })), OPEN_GROUP, s))
  end)

  it("drops an untimed best run when timed only is on", function()
    local s = settings({ timedOnly = true })
    assert.is_false(Rules.Passes(app(member("MAGE", { dungeonLevel = 12, dungeonTimed = false })), OPEN_GROUP, s))
    assert.is_true(Rules.Passes(app(member("MAGE", { dungeonLevel = 12, dungeonTimed = true })), OPEN_GROUP, s))
  end)
end)

describe("Rules.Passes, invited applicants", function()
  it("keeps an invited application whatever the filters say", function()
    local invited = app(member("PALADIN", { rating = 100 }))
    invited.pinned = true
    assert.is_true(Rules.Passes(invited, OPEN_GROUP, settings({ minRating = 3000, classes = { PALADIN = EXCLUDE } })))
  end)
end)

describe("Rules.CountClasses", function()
  it("counts every member of every application", function()
    local counts = Rules.CountClasses({ app(member("MAGE")), app(member("MAGE"), member("PRIEST")) })
    assert.equals(2, counts.MAGE)
    assert.equals(1, counts.PRIEST)
    assert.is_nil(counts.ROGUE)
  end)
end)
describe("Rules.Passes, roles", function()
  local tankOnly = member("WARRIOR", { roles = { TANK = true, HEALER = false, DAMAGER = false } })
  local tankOrDps = member("WARRIOR", { roles = { TANK = true, HEALER = false, DAMAGER = true } })
  local healer = member("PRIEST", { roles = { TANK = false, HEALER = true, DAMAGER = false } })
  local noTank = { open = { TANK = 0, HEALER = 1, DAMAGER = 3 }, hasBloodlust = false, hasBattleRes = false }

  it("drops a member whose every offered role is toggled off", function()
    assert.is_false(Rules.Passes(app(healer), OPEN_GROUP, settings({ roles = { TANK = true, HEALER = false, DAMAGER = true } })))
  end)

  it("hides a role the group already has only when asked to", function()
    assert.is_true(Rules.Passes(app(tankOnly), noTank, settings()))
    assert.is_false(Rules.Passes(app(tankOnly), noTank, settings({ hideFilledRoles = true })))
    assert.is_true(Rules.Passes(app(tankOrDps), noTank, settings({ hideFilledRoles = true })))
  end)

  it("drops a group application that does not fit the open slots", function()
    local oneDps = { open = { TANK = 0, HEALER = 0, DAMAGER = 1 }, hasBloodlust = false, hasBattleRes = false }
    assert.is_false(Rules.Passes(app(member("MAGE"), member("ROGUE")), oneDps, settings({ hideFilledRoles = true })))
  end)

  it("never hides by role when the listing has no role slots", function()
    local raid = { open = nil, hasBloodlust = false, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(tankOnly), raid, settings({ hideFilledRoles = true, bloodlustFit = true, battleResFit = true })))
  end)
end)

describe("Rules.Passes, Bloodlust fit", function()
  local lastDps = { open = { TANK = 0, HEALER = 0, DAMAGER = 1 }, hasBloodlust = false, hasBattleRes = false }
  local s = settings({ bloodlustFit = true })

  it("keeps anyone when the group already has Bloodlust", function()
    local has = { open = lastDps.open, hasBloodlust = true, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(member("ROGUE")), has, s))
  end)

  it("keeps an applicant who brings Bloodlust into the last slot", function()
    assert.is_true(Rules.Passes(app(member("MAGE")), lastDps, s))
  end)

  it("drops a non-Bloodlust applicant taking the last damage or healer slot", function()
    assert.is_false(Rules.Passes(app(member("ROGUE")), lastDps, s))
  end)

  it("keeps a non-Bloodlust applicant when a slot stays open after them", function()
    local twoDps = { open = { TANK = 0, HEALER = 0, DAMAGER = 2 }, hasBloodlust = false, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(member("ROGUE")), twoDps, s))
  end)
end)

describe("Rules.Passes, battle res fit", function()
  local s = settings({ battleResFit = true })
  local lastDps = { open = { TANK = 0, HEALER = 0, DAMAGER = 1 }, hasBloodlust = false, hasBattleRes = false }

  it("drops a non-res applicant taking the last slot and keeps a res class", function()
    assert.is_false(Rules.Passes(app(member("ROGUE")), lastDps, s))
    assert.is_true(Rules.Passes(app(member("DRUID")), lastDps, s))
  end)

  it("counts an open tank slot as room for a res class", function()
    local tankOpen = { open = { TANK = 1, HEALER = 0, DAMAGER = 1 }, hasBloodlust = false, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(member("ROGUE")), tankOpen, s))
  end)
end)
describe("Rules.Apply", function()
  local byId = {
    [1] = app(member("MAGE")),
    [2] = app(member("PALADIN")),
    [3] = app(member("PRIEST")),
    [4] = app(member("PALADIN")),
  }
  local s = settings({ classes = { PALADIN = EXCLUDE } })

  it("moves failing applications below passing ones, keeping both orders", function()
    local ids = { 4, 1, 2, 3 }
    local failed, count = Rules.Apply(ids, byId, OPEN_GROUP, s)
    assert.same({ 1, 3, 4, 2 }, ids)
    assert.equals(2, count)
    assert.is_true(failed[4])
    assert.is_true(failed[2])
    assert.is_nil(failed[1])
  end)

  it("removes failing applications in hide mode", function()
    local ids = { 4, 1, 2, 3 }
    local hide = settings({ classes = { PALADIN = EXCLUDE }, mode = "hide" })
    local _, count = Rules.Apply(ids, byId, OPEN_GROUP, hide)
    assert.same({ 1, 3 }, ids)
    assert.equals(2, count)
  end)
end)

describe("Rules.Migrate", function()
  it("starts from the defaults and adopts the old class picks", function()
    local migrated = Rules.Migrate(nil, { MAGE = NEED })
    assert.equals(NEED, migrated.classes.MAGE)
    assert.equals("down", migrated.mode)
    assert.is_true(migrated.roles.TANK)
  end)

  it("keeps saved settings and fills what a newer version added", function()
    local saved = { classes = { ROGUE = EXCLUDE }, roles = { TANK = false, HEALER = true, DAMAGER = true }, minRating = 2000 }
    local migrated = Rules.Migrate(saved, { MAGE = NEED })
    assert.equals(EXCLUDE, migrated.classes.ROGUE)
    assert.is_nil(migrated.classes.MAGE)
    assert.is_false(migrated.roles.TANK)
    assert.equals(2000, migrated.minRating)
    assert.equals("down", migrated.mode)
    assert.is_false(migrated.timedOnly)
  end)
end)
