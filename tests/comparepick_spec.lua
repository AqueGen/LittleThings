package.path = "./Modules/Applicants/?.lua;" .. package.path

local ComparePick = require("ComparePick")

local function member(name, role, rating, roles)
  local flags = { TANK = false, HEALER = false, DAMAGER = false }
  for _, r in ipairs(roles or { role }) do flags[r] = true end
  return { name = name, realm = "Silvermoon", class = "MAGE", role = role, rating = rating, roles = flags }
end

local function summary(list)
  local out = {}
  for i, m in ipairs(list) do out[i] = { m.name, m.role, m.app } end
  return out
end

describe("ComparePick.Pick", function()
  it("puts a multi-role applicant into the open role", function()
    local list, dropped = ComparePick.Pick({ { members = { member("Flex", "DAMAGER", 3000, { "TANK", "DAMAGER" }) } } }, { TANK = 1, HEALER = 0, DAMAGER = 0 })
    assert.same({ { "Flex", "TANK", 1 } }, summary(list))
    assert.equals(0, dropped)
  end)

  it("tries the assigned role first when it fits", function()
    local list = ComparePick.Pick({ { members = { member("Flex", "DAMAGER", 3000, { "TANK", "DAMAGER" }) } } }, { TANK = 1, HEALER = 0, DAMAGER = 1 })
    assert.same({ { "Flex", "DAMAGER", 1 } }, summary(list))
  end)

  it("drops a whole party that does not fit the open slots and counts its members", function()
    local list, dropped = ComparePick.Pick({
      { members = { member("Heal1", "HEALER", 3100), member("Heal2", "HEALER", 3100) } },
      { members = { member("Dps", "DAMAGER", 2500) } },
    }, { TANK = 0, HEALER = 1, DAMAGER = 2 })
    assert.same({ { "Dps", "DAMAGER", 1 } }, summary(list))
    assert.equals(2, dropped)
  end)

  it("fits a party by moving a flexible member to another open role", function()
    local list = ComparePick.Pick({
      { members = { member("Heal", "HEALER", 3000), member("Flex", "HEALER", 3000, { "HEALER", "TANK" }) } },
    }, { TANK = 1, HEALER = 1, DAMAGER = 0 })
    assert.same({ { "Heal", "HEALER", 1 }, { "Flex", "TANK", 1 } }, summary(list))
  end)

  it("keeps everyone in their assigned role when the open slots are unknown", function()
    local list, dropped = ComparePick.Pick({ { members = { member("A", "HEALER", 1), member("B", "HEALER", 2) } } }, nil)
    assert.same({ { "A", "HEALER", 1 }, { "B", "HEALER", 1 } }, summary(list))
    assert.equals(0, dropped)
  end)

  it("orders applications by mean rating, best first, game order breaking ties, and renumbers them", function()
    local open = { TANK = 1, HEALER = 1, DAMAGER = 3 }
    local list = ComparePick.Pick({
      { members = { member("Low", "DAMAGER", 2000) } },
      { members = { member("PartyA", "DAMAGER", 3000), member("PartyB", "HEALER", 2600) } },
      { members = { member("High", "DAMAGER", 2900) } },
      { members = { member("Tie", "TANK", 2000) } },
      { members = { member("NoRating", "DAMAGER", nil) } },
    }, open)
    assert.same({ { "High", "DAMAGER", 1 }, { "PartyA", "DAMAGER", 2 }, { "PartyB", "HEALER", 2 }, { "Low", "DAMAGER", 3 }, { "Tie", "TANK", 4 }, { "NoRating", "DAMAGER", 5 } }, summary(list))
  end)

  it("skips applications with no readable member and keeps name, realm, class and rating", function()
    local list = ComparePick.Pick({ { members = {} }, { members = { member("A", "DAMAGER", 2875.6) } } }, { TANK = 0, HEALER = 0, DAMAGER = 1 })
    assert.same({ { name = "A", realm = "Silvermoon", class = "MAGE", role = "DAMAGER", rating = 2875.6, app = 1 } }, list)
  end)
end)
