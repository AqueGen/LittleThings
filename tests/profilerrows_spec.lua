package.path = "./Modules/Performance/?.lua;" .. package.path

local Rows = require("ProfilerRows")

local function Names(rows)
  local names = {}
  for index, row in ipairs(rows) do
    names[index] = row.name
  end
  return names
end

describe("Rows.Comparator", function()
  local function Sorted(key)
    local rows = {
      { name = "Beta", sortName = "beta", average = 0.2, hitches = 0 },
      { name = "alpha", sortName = "alpha", average = 0.5, hitches = 3 },
      { name = "Gamma", sortName = "gamma", average = 0.2, hitches = 1 },
    }
    table.sort(rows, Rows.Comparator(key))
    return rows
  end

  it("puts the highest value first", function()
    assert.same({ "alpha", "Beta", "Gamma" }, Names(Sorted("average")))
    assert.same({ "alpha", "Gamma", "Beta" }, Names(Sorted("hitches")))
  end)

  it("breaks ties by name, ignoring case", function()
    local rows = Sorted("average")
    assert.same({ "Beta", "Gamma" }, { rows[2].name, rows[3].name })
  end)

  it("sorts the name column alphabetically, ignoring case", function()
    assert.same({ "alpha", "Beta", "Gamma" }, Names(Sorted("name")))
  end)
end)
