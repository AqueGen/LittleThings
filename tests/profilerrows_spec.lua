package.path = "./Modules/Performance/?.lua;" .. package.path

local Rows = require("ProfilerRows")

local function Names(rows)
  local names = {}
  for index, row in ipairs(rows) do
    names[index] = row.name
  end
  return names
end

describe("Rows.Sort", function()
  local function Sample()
    return {
      { name = "Beta", average = 0.2, hitches = 0 },
      { name = "alpha", average = 0.5, hitches = 3 },
      { name = "Gamma", average = 0.2, hitches = 1 },
    }
  end

  it("puts the highest value first", function()
    assert.same({ "alpha", "Beta", "Gamma" }, Names(Rows.Sort(Sample(), "average")))
    assert.same({ "alpha", "Gamma", "Beta" }, Names(Rows.Sort(Sample(), "hitches")))
  end)

  it("breaks ties by name, ignoring case", function()
    local rows = Rows.Sort(Sample(), "average")
    assert.same({ "Beta", "Gamma" }, { rows[2].name, rows[3].name })
  end)

  it("sorts the name column alphabetically, ignoring case", function()
    assert.same({ "alpha", "Beta", "Gamma" }, Names(Rows.Sort(Sample(), "name")))
  end)
end)
