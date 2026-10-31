-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
package.path = "./UI/?.lua;" .. package.path

local Rules = require("WidgetRules")

describe("WidgetRules.Grid", function()
  it("fills rows left to right and reports the height", function()
    local cells, height = Rules.Grid(5, 3, 200, 18)
    assert.same({ x = 0, y = 0 }, cells[1])
    assert.same({ x = 400, y = 0 }, cells[3])
    assert.same({ x = 200, y = 18 }, cells[5])
    assert.equals(36, height)
  end)
  it("is empty with nothing to place", function()
    local cells, height = Rules.Grid(0, 3, 200, 18)
    assert.same({}, cells)
    assert.equals(0, height)
  end)
end)

describe("WidgetRules.Columns", function()
  it("keeps the asked columns when they fit", function()
    assert.equals(3, Rules.Columns(3, 220, 660))
  end)
  it("drops columns until the grid fits the room, never below one", function()
    assert.equals(2, Rules.Columns(3, 220, 659))
    assert.equals(2, Rules.Columns(3, 220, 440))
    assert.equals(1, Rules.Columns(3, 220, 439))
    assert.equals(1, Rules.Columns(3, 220, 100))
  end)
  it("keeps the asked columns before the box has a width", function()
    assert.equals(3, Rules.Columns(3, 220, 0))
  end)
end)

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

describe("WidgetRules.GripSize", function()
  it("grows the window by the cursor's move right and down", function()
    assert.same({ 900, 610 }, { Rules.GripSize(800, 560, 100, 50, 620, 530, 1500, 900) })
  end)

  it("stops at the minimum when dragged past it", function()
    assert.same({ 620, 530 }, { Rules.GripSize(800, 560, -400, -300, 620, 530, 1500, 900) })
  end)

  it("stops at the screen edge when dragged past it", function()
    assert.same({ 1000, 800 }, { Rules.GripSize(800, 560, 2000, 2000, 620, 530, 1000, 800) })
  end)
end)
