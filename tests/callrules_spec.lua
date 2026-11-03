-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
package.path = "./Modules/PartyCalls/?.lua;" .. package.path

local Rules = require("CallRules")

local function state(role, combat, dungeon, mplus)
  return { role = role, combat = combat, dungeon = dungeon, mplus = mplus }
end

local function fresh()
  return Rules.Fill({})
end

describe("CallRules", function()
  it("starts with the 8 built-ins in order", function()
    local db = fresh()
    assert.equals(8, #db.order)
    assert.equals("lust", db.order[1])
    assert.equals("brb", db.order[8])
  end)

  it("drops unknown calls and repairs the order", function()
    local db = Rules.Fill({ calls = { custom1 = { message = "x" } }, order = { "oom", "gone", "oom" } })
    assert.is_nil(db.calls.custom1)
    assert.equals("oom", db.order[1])
    assert.equals(8, #db.order)
  end)

  it("adds custom calls at the end, on, for everyone, anywhere", function()
    local db = fresh()
    local a, b = Rules.AddCustom(db), Rules.AddCustom(db)
    assert.are_not.equal(a, b)
    assert.equals(b, db.order[10])
    local call = db.calls[a]
    assert.is_true(call.enabled)
    assert.is_true(call.roles.HEALER)
    assert.equals("any", call.combat)
    assert.equals("group", call.content)
    assert.equals(0, call.mark)
    assert.is_false(Rules.IsBuiltin(a))
    assert.is_true(Rules.IsBuiltin("lust"))
  end)

  it("keeps custom calls after a fill", function()
    local db = fresh()
    local id = Rules.AddCustom(db)
    db.calls[id].message = "Hi"
    Rules.Fill(db)
    assert.equals("Hi", db.calls[id].message)
    assert.equals(id, db.order[9])
  end)

  it("never reuses an id after a delete", function()
    local db = fresh()
    local a = Rules.AddCustom(db)
    assert.is_true(Rules.Remove(db, a))
    assert.are_not.equal(a, Rules.AddCustom(db))
  end)

  it("removes only custom calls", function()
    local db = fresh()
    local id = Rules.AddCustom(db)
    assert.is_false(Rules.Remove(db, "lust"))
    assert.is_true(Rules.Remove(db, id))
    assert.is_nil(db.calls[id])
    assert.equals(8, #db.order)
  end)

  it("moves calls within the order and stops at the ends", function()
    local db = fresh()
    assert.is_true(Rules.Move(db, "lustNext", -1))
    assert.equals("lustNext", db.order[1])
    assert.is_false(Rules.Move(db, "lustNext", -1))
    assert.is_false(Rules.Move(db, "brb", 1))
  end)

  it("prefixes the mark", function()
    assert.equals("{rt7} LUST NOW", Rules.Text({ message = "LUST NOW", mark = 7 }))
    assert.equals("LUST NOW", Rules.Text({ message = "LUST NOW", mark = 0 }))
  end)

  it("sends nothing for an empty or blank message", function()
    assert.is_nil(Rules.Text({ message = "", mark = 3 }))
    assert.is_nil(Rules.Text({ message = "   ", mark = 0 }))
  end)

  it("cuts to 255 bytes on a character boundary", function()
    assert.equals(254, #Rules.Text({ message = string.rep("ж", 200), mark = 1 }))
    assert.equals(254, #Rules.Text({ message = string.rep("ж", 200), mark = 0 }))
    assert.equals(255, #Rules.Text({ message = string.rep("a", 300), mark = 0 }))
  end)

  it("counts a missing role as damage", function()
    assert.equals("DAMAGER", Rules.Role(nil))
    assert.equals("DAMAGER", Rules.Role("NONE"))
    assert.equals("TANK", Rules.Role("TANK"))
  end)

  it("filters by role, combat and content", function()
    local calls = fresh().calls
    assert.is_true(Rules.Visible(calls.skip, state("HEALER", false, true, true)))
    assert.is_false(Rules.Visible(calls.skip, state("HEALER", true, true, true)))
    assert.is_false(Rules.Visible(calls.skip, state("HEALER", false, true, false)))
    assert.is_false(Rules.Visible(calls.oom, state("TANK", false, true, false)))
    assert.is_true(Rules.Visible(calls.oom, state("HEALER", true, true, false)))
    assert.is_false(Rules.Visible(calls.wipe, state("TANK", false, true, false)))
    assert.is_true(Rules.Visible(calls.brb, state("TANK", false, false, false)))
    assert.is_false(Rules.Visible(calls.lust, state("TANK", false, false, false)))
  end)

  it("hides a custom call with no message", function()
    local db = fresh()
    local id = Rules.AddCustom(db)
    assert.is_false(Rules.Visible(db.calls[id], state("TANK", false, false, false)))
    db.calls[id].message = "Hi"
    assert.is_true(Rules.Visible(db.calls[id], state("TANK", false, false, false)))
  end)

  it("shows the panel only in a party with a visible call, or in preview", function()
    assert.is_true(Rules.PanelShown({ party = true, raid = false, preview = false, anyVisible = true }))
    assert.is_false(Rules.PanelShown({ party = true, raid = true, preview = false, anyVisible = true }))
    assert.is_false(Rules.PanelShown({ party = true, raid = false, preview = false, anyVisible = false }))
    assert.is_false(Rules.PanelShown({ party = false, raid = false, preview = false, anyVisible = true }))
    assert.is_true(Rules.PanelShown({ party = false, raid = false, preview = true, anyVisible = false }))
  end)

  it("shows solo only with Show when solo on and a call to show, never in a raid", function()
    assert.is_true(Rules.PanelShown({ party = false, raid = false, showSolo = true, anyVisible = true }))
    assert.is_false(Rules.PanelShown({ party = false, raid = false, showSolo = true, anyVisible = false }))
    assert.is_false(Rules.PanelShown({ party = false, raid = false, showSolo = false, anyVisible = true }))
    assert.is_false(Rules.PanelShown({ party = true, raid = true, showSolo = true, anyVisible = true }))
    assert.is_true(Rules.PanelShown({ party = true, raid = false, showSolo = false, anyVisible = true }))
  end)

  it("throttles 3 s globally and 5 s per call", function()
    assert.equals(0, Rules.Remaining(100, nil, {}, "lust"))
    assert.equals(2, Rules.Remaining(101, 100, { lust = 100 }, "oom"))
    assert.equals(4, Rules.Remaining(101, 100, { lust = 100 }, "lust"))
    assert.equals(0, Rules.Remaining(105, 100, { lust = 100 }, "lust"))
  end)

  it("picks the click path", function()
    assert.equals("send", Rules.ClickPath("send", true))
    assert.equals("chat", Rules.ClickPath("chat", false))
    assert.equals("send", Rules.ClickPath("chatInCombat", false))
    assert.equals("chat", Rules.ClickPath("chatInCombat", true))
  end)

  it("resolves icons", function()
    local tex = function(id) return id == 2825 and 136012 or nil end
    local file = function(path) return path == "Interface\\Icons\\Foo" and 1 or nil end
    assert.equals(136012, Rules.Texture(2825, tex, file))
    assert.equals(136012, Rules.Texture("2825", tex, file))
    assert.equals(Rules.QUESTION, Rules.Texture(999, tex, file))
    assert.equals("Interface\\Icons\\Foo", Rules.Texture("Interface\\Icons\\Foo", tex, file))
    assert.equals(Rules.QUESTION, Rules.Texture("Interface\\Icons\\Missing", tex, file))
    for _, junk in ipairs({ "abc", "", "  " }) do
      assert.equals(Rules.QUESTION, Rules.Texture(junk, tex, file))
    end
    assert.equals(Rules.QUESTION, Rules.Texture(nil, tex, file))
  end)

  it("reset restores a built-in after edits", function()
    local db = fresh()
    db.calls.lust.message = "x"
    db.calls.lust.roles.TANK = false
    Rules.Reset(db.calls, "lust")
    assert.equals("LUST NOW", db.calls.lust.message)
    assert.is_true(db.calls.lust.roles.TANK)
  end)

  it("fills missing fields without sharing the default roles table", function()
    local db = Rules.Fill({ calls = { lust = { message = "Go" } } })
    assert.equals("Go", db.calls.lust.message)
    assert.equals(7, db.calls.lust.mark)
    db.calls.lust.roles.TANK = false
    assert.is_true(fresh().calls.lust.roles.TANK)
  end)
end)

describe("CallRules.Grid", function()
  local base = { cellW = 10, cellH = 20, gap = 2, pad = 1 }
  local function opts(grow, wrap, perRow)
    return { grow = grow, wrap = wrap, perRow = perRow, cellW = base.cellW, cellH = base.cellH, gap = base.gap, pad = base.pad }
  end

  it("grows right and wraps down from the top left", function()
    local cells, w, h, anchor = Rules.Grid(5, opts("right", "down", 3))
    assert.equals("TOPLEFT", anchor)
    assert.same({ x = 1, y = -1 }, cells[1])
    assert.same({ x = 25, y = -1 }, cells[3])
    assert.same({ x = 1, y = -23 }, cells[4])
    assert.equals(3 * 10 + 2 * 2 + 2, w)
    assert.equals(2 * 20 + 2 + 2, h)
  end)

  it("grows left and wraps up from the bottom right", function()
    local cells, _, _, anchor = Rules.Grid(4, opts("left", "up", 3))
    assert.equals("BOTTOMRIGHT", anchor)
    assert.same({ x = -1, y = 1 }, cells[1])
    assert.same({ x = -13, y = 1 }, cells[2])
    assert.same({ x = -1, y = 23 }, cells[4])
  end)

  it("grows down in columns and wraps right", function()
    local cells, w, h, anchor = Rules.Grid(3, opts("down", "right", 2))
    assert.equals("TOPLEFT", anchor)
    assert.same({ x = 1, y = -23 }, cells[2])
    assert.same({ x = 13, y = -1 }, cells[3])
    assert.equals(2 * 10 + 2 + 2, w)
    assert.equals(2 * 20 + 2 + 2, h)
  end)

  it("fixes a wrap on the same axis as the growth", function()
    local _, _, _, anchor = Rules.Grid(3, opts("up", "down", 2))
    assert.equals("BOTTOMLEFT", anchor)
  end)

  it("leaves a left strip for the fold handle in front of the cells", function()
    local o = opts("right", "down", 3)
    o.strip = 12
    local cells, w, h = Rules.Grid(4, o)
    assert.same({ x = 13, y = -1 }, cells[1])
    assert.same({ x = 13, y = -23 }, cells[4])
    assert.same({ 3 * 10 + 2 * 2 + 2 + 12, 2 * 20 + 2 + 2 }, { w, h })
    o = opts("left", "up", 3)
    o.strip = 12
    cells, w = Rules.Grid(2, o)
    assert.same({ x = -1, y = 1 }, cells[1])
    assert.equals(2 * 10 + 2 + 2 + 12, w)
  end)

  it("sizes an empty panel as one cell", function()
    local cells, w, h = Rules.Grid(0, opts("right", "down", 8))
    assert.equals(0, #cells)
    assert.equals(12, w)
    assert.equals(22, h)
  end)
end)
