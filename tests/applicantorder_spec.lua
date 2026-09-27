package.path = "./Modules/Applicants/?.lua;" .. package.path

local Order = require("ApplicantOrder")

local function sorted(applicants, ...)
  Order.Sort(applicants, { ... })
  return table.concat(applicants, " ")
end

describe("Order.Sort, one key", function()
  it("puts the highest score first", function()
    assert.equals("2 3 1", sorted({ 1, 2, 3 }, { [1] = 1800, [2] = 3100, [3] = 2500 }))
  end)

  it("keeps Blizzard's order between equal scores", function()
    assert.equals("7 4 9", sorted({ 7, 4, 9 }, { [7] = 2000, [4] = 2000, [9] = 2000 }))
  end)

  it("puts applicants without a score below every scored one, in Blizzard's order", function()
    assert.equals("5 1 8 2", sorted({ 8, 1, 5, 2 }, { [1] = 900, [5] = 2400 }))
  end)

  it("leaves a list with no scores as it was", function()
    assert.equals("3 1 2", sorted({ 3, 1, 2 }, {}))
  end)

  it("ranks a score of zero above no score", function()
    assert.equals("2 1", sorted({ 1, 2 }, { [2] = 0 }))
  end)
end)

describe("Order.Sort, two keys", function()
  local rating = { [1] = 2500, [2] = 2500, [3] = 2800, [4] = 2500 }
  local itemLevel = { [1] = 280, [2] = 291, [3] = 270, [4] = 291 }

  it("breaks a tie on the first key with the second", function()
    assert.equals("3 2 4 1", sorted({ 1, 2, 3, 4 }, rating, itemLevel))
  end)

  it("lets the second key lead when the keys are swapped", function()
    assert.equals("2 4 1 3", sorted({ 1, 2, 3, 4 }, itemLevel, rating))
  end)

  it("falls back to Blizzard's order when both keys tie", function()
    assert.equals("4 2", sorted({ 4, 2 }, { [4] = 2500, [2] = 2500 }, { [4] = 291, [2] = 291 }))
  end)
end)

describe("Order.Sort, dungeon first", function()
  it("orders by the dungeon score and breaks ties with the overall rating", function()
    local dungeon = { [1] = 300, [2] = 310, [3] = 300 }
    local rating = { [1] = 2400, [2] = 2000, [3] = 2600 }
    assert.equals("2 3 1", sorted({ 1, 2, 3 }, dungeon, rating))
  end)
end)

describe("Order.Sort, change report", function()
  it("reports no change and keeps the list when it is already in order", function()
    local applicants = { 2, 1 }
    assert.is_false(Order.Sort(applicants, { { [1] = 10, [2] = 20 } }))
    assert.same({ 2, 1 }, applicants)
  end)

  it("reports a change when the order moves", function()
    local applicants = { 1, 2 }
    assert.is_true(Order.Sort(applicants, { { [1] = 10, [2] = 20 } }))
    assert.same({ 2, 1 }, applicants)
  end)
end)
