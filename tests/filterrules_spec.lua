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
    assert.is_true(Rules.IsActive(settings({ minItemLevel = 0 })))
    assert.is_true(Rules.IsActive(settings({ needBloodlust = true })))
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
  it("drops a member below the minimum item level", function()
    assert.is_false(Rules.Passes(app(member("MAGE", { itemLevel = 280 })), OPEN_GROUP, settings({ minItemLevel = 285 })))
    assert.is_true(Rules.Passes(app(member("MAGE", { itemLevel = 285 })), OPEN_GROUP, settings({ minItemLevel = 285 })))
  end)

  it("needs every member of a group application to meet the minimum", function()
    local s = settings({ minItemLevel = 285 })
    assert.is_false(Rules.Passes(app(member("MAGE", { itemLevel = 300 }), member("PRIEST", { itemLevel = 270 })), OPEN_GROUP, s))
  end)

  it("lets everyone through a minimum of zero", function()
    assert.is_true(Rules.Passes(app(member("MAGE", { itemLevel = 0 })), OPEN_GROUP, settings({ minItemLevel = 0 })))
  end)

end)

describe("Rules.Passes, invited applicants", function()
  it("keeps an invited application whatever the filters say", function()
    local invited = app(member("PALADIN", { rating = 100 }))
    invited.pinned = true
    assert.is_true(Rules.Passes(invited, OPEN_GROUP, settings({ minItemLevel = 400, classes = { PALADIN = EXCLUDE } })))
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
    local saved = { classes = { ROGUE = EXCLUDE }, roles = { TANK = false, HEALER = true, DAMAGER = true }, minItemLevel = 280 }
    local migrated = Rules.Migrate(saved, { MAGE = NEED })
    assert.equals(EXCLUDE, migrated.classes.ROGUE)
    assert.is_nil(migrated.classes.MAGE)
    assert.is_false(migrated.roles.TANK)
    assert.equals(280, migrated.minItemLevel)
    assert.equals("down", migrated.mode)
    assert.is_false(migrated.needBloodlust)
  end)
end)

describe("Rules.CountClasses, members still loading", function()
  it("skips a member whose class has not arrived yet", function()
    local counts = Rules.CountClasses({ app(member("MAGE"), { roles = {} }) })
    assert.equals(1, counts.MAGE)
  end)
end)

describe("Rules.IsFinished", function()
  it("is true for applications that ended without joining", function()
    for _, status in ipairs({ "cancelled", "failed", "timedout", "declined", "declined_full", "declined_delisted", "invitedeclined" }) do
      assert.is_true(Rules.IsFinished(status, nil), status)
    end
  end)

  it("is false for live applications and while a change is pending", function()
    assert.is_false(Rules.IsFinished("applied", nil))
    assert.is_false(Rules.IsFinished("invited", nil))
    assert.is_false(Rules.IsFinished("inviteaccepted", nil))
    assert.is_false(Rules.IsFinished("cancelled", "applied"))
  end)
end)

describe("Rules.Passes, bring Bloodlust and battle res", function()
  local noUtility = { open = { TANK = 1, HEALER = 1, DAMAGER = 3 }, hasBloodlust = false, hasBattleRes = false }

  it("fails applications without Bloodlust while the group has none", function()
    local s = settings({ needBloodlust = true })
    assert.is_false(Rules.Passes(app(member("ROGUE")), noUtility, s))
    assert.is_true(Rules.Passes(app(member("MAGE")), noUtility, s))
    assert.is_true(Rules.Passes(app(member("ROGUE"), member("SHAMAN")), noUtility, s))
  end)

  it("stops asking once the group has Bloodlust", function()
    local has = { open = noUtility.open, hasBloodlust = true, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(member("ROGUE")), has, settings({ needBloodlust = true })))
  end)

  it("needs both when both are asked for", function()
    local s = settings({ needBloodlust = true, needBattleRes = true })
    assert.is_true(Rules.Passes(app(member("SHAMAN"), member("DRUID")), noUtility, s))
    assert.is_false(Rules.Passes(app(member("MAGE")), noUtility, s))
    assert.is_false(Rules.Passes(app(member("DRUID")), noUtility, s))
  end)

  it("asks nothing in a listing without role slots", function()
    local raid = { open = nil, hasBloodlust = false, hasBattleRes = false }
    assert.is_true(Rules.Passes(app(member("ROGUE")), raid, settings({ needBloodlust = true, needBattleRes = true })))
  end)

  it("lifts the ones who bring it in move down mode", function()
    local byId = { [1] = app(member("ROGUE")), [2] = app(member("MAGE")), [3] = app(member("PRIEST")), [4] = app(member("SHAMAN")) }
    local ids = { 1, 2, 3, 4 }
    local _, count = Rules.Apply(ids, byId, noUtility, settings({ needBloodlust = true }))
    assert.same({ 2, 4, 1, 3 }, ids)
    assert.equals(2, count)
  end)
end)
