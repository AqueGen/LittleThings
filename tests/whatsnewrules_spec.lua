package.path = "./UI/?.lua;" .. package.path

local Rules = require("WhatsNewRules")

local MODULES = {
  { key = "groupFinder", label = "Group finder" },
  { key = "signUpRoles", parent = "groupFinder", label = "Sign-up roles" },
  { key = "battleResGuard", label = "Battle res guard" },
}

local function keys(rows)
  local list = {}
  for _, row in ipairs(rows) do
    list[#list + 1] = row.key
  end
  return list
end

describe("Rules.NewRows", function()
  it("is empty on a fresh install", function()
    assert.same({}, Rules.NewRows(nil, MODULES))
  end)

  it("is empty when every switch is saved, off ones included", function()
    assert.same({}, Rules.NewRows({ groupFinder = true, signUpRoles = false, battleResGuard = false }, MODULES))
  end)

  it("lists the rows missing from the saved table in module order", function()
    assert.same({ "signUpRoles", "battleResGuard" }, keys(Rules.NewRows({ groupFinder = false }, MODULES)))
  end)

  it("lists a new parent row", function()
    assert.same({ "groupFinder" }, keys(Rules.NewRows({ signUpRoles = true, battleResGuard = true }, MODULES)))
  end)
end)

describe("Rules.Title", function()
  it("is the label of a top row", function()
    assert.equals("Battle res guard", Rules.Title(MODULES[3], MODULES))
  end)

  it("prefixes a child row with its parent", function()
    assert.equals("Group finder: Sign-up roles", Rules.Title(MODULES[2], MODULES))
  end)
end)
