package.path = "./Modules/ClassFilter/?.lua;" .. package.path

local Rules = require("ClassFilterRules")

local NEED, EXCLUDE = Rules.NEED, Rules.EXCLUDE

describe("Rules.Next", function()
  it("cycles neutral, need, exclude, neutral", function()
    assert.equals(NEED, Rules.Next(nil))
    assert.equals(EXCLUDE, Rules.Next(NEED))
    assert.is_nil(Rules.Next(EXCLUDE))
  end)
end)

describe("Rules.Passes", function()
  it("lets every group through with nothing picked", function()
    assert.is_true(Rules.Passes({ "MAGE", "PRIEST" }, {}))
  end)

  it("drops a group that has an excluded class", function()
    assert.is_false(Rules.Passes({ "MAGE", "PALADIN" }, { PALADIN = EXCLUDE }))
    assert.is_true(Rules.Passes({ "MAGE", "PRIEST" }, { PALADIN = EXCLUDE }))
  end)

  it("keeps a group with any one of the needed classes", function()
    local bloodlust = { SHAMAN = NEED, MAGE = NEED, HUNTER = NEED, EVOKER = NEED }
    assert.is_true(Rules.Passes({ "WARRIOR", "HUNTER" }, bloodlust))
    assert.is_false(Rules.Passes({ "WARRIOR", "PRIEST" }, bloodlust))
  end)

  it("lets an exclusion win over a need in the same group", function()
    assert.is_false(Rules.Passes({ "MAGE", "PALADIN" }, { MAGE = NEED, PALADIN = EXCLUDE }))
  end)

  it("drops an empty group when a class is needed", function()
    assert.is_false(Rules.Passes({}, { MAGE = NEED }))
  end)
end)

describe("Rules.Filter", function()
  local members = { [1] = { "MAGE" }, [2] = { "PALADIN" }, [3] = { "MAGE", "PRIEST" }, [4] = { "ROGUE" } }
  local function classesOf(id) return members[id] end

  it("keeps passing results in their order", function()
    local results = { 4, 3, 2, 1 }
    assert.is_true(Rules.Filter(results, classesOf, { MAGE = NEED }))
    assert.same({ 3, 1 }, results)
  end)

  it("leaves the list untouched when any group cannot be read", function()
    local results = { 1, 2, 99, 4 }
    assert.is_false(Rules.Filter(results, classesOf, { PALADIN = EXCLUDE }))
    assert.same({ 1, 2, 99, 4 }, results)
  end)
end)
