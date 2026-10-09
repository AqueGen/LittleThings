package.path = "./UI/?.lua;" .. package.path

local Rules = require("WidgetRules")

describe("WidgetRules.Stack", function()
  it("stacks shown items with a gap and reports their height", function()
    local offsets, total = Rules.Stack({ { height = 20 }, { height = 30 } }, 5)
    assert.same({ 0, 25 }, offsets)
    assert.equals(55, total)
  end)

  it("gives a hidden item no offset and no space", function()
    local offsets, total = Rules.Stack({ { height = 20 }, { height = 30, shown = false }, { height = 10 } }, 5)
    assert.same({ [1] = 0, [3] = 25 }, offsets)
    assert.equals(35, total)
  end)

  it("reports zero height when nothing is shown", function()
    local offsets, total = Rules.Stack({ { height = 20, shown = false } }, 5)
    assert.same({}, offsets)
    assert.equals(0, total)
  end)
end)

describe("WidgetRules.Known", function()
  local options = { { value = "a", text = "A" }, { value = "b", text = "B" } }

  it("keeps a value that is among the options", function()
    assert.equals("b", Rules.Known(options, "b", "a"))
  end)

  it("falls back to the default for a value that is not", function()
    assert.equals("a", Rules.Known(options, "gone", "a"))
  end)

  it("falls back to the default for nil", function()
    assert.equals("a", Rules.Known(options, nil, "a"))
  end)
end)

describe("WidgetRules.Size", function()
  it("uses the default size when nothing is saved", function()
    assert.same({ 860, 560 }, { Rules.Size(nil, nil, 800, 480, 860, 560) })
  end)

  it("keeps a saved size above the minimum", function()
    assert.same({ 1000, 700 }, { Rules.Size(1000, 700, 800, 480, 860, 560) })
  end)

  it("raises a saved size below the minimum", function()
    assert.same({ 800, 480 }, { Rules.Size(600, 420, 800, 480, 860, 560) })
  end)
end)
