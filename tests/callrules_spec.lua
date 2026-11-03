-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
package.path = "./Modules/PartyCalls/?.lua;" .. package.path

local Rules = require("CallRules")

local function state(role, combat, dungeon, mplus)
  return { role = role, combat = combat, dungeon = dungeon, mplus = mplus }
end

describe("CallRules", function()
  it("lists 8 built-ins then 6 custom slots", function()
    local order = Rules.Order()
    assert.equals(14, #order)
    assert.equals("lust", order[1])
    assert.equals("brb", order[8])
    assert.equals("custom6", order[14])
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
    local calls = Rules.Fill({})
    assert.is_true(Rules.Visible(calls.skip, state("HEALER", false, true, true)))
    assert.is_false(Rules.Visible(calls.skip, state("HEALER", true, true, true)))
    assert.is_false(Rules.Visible(calls.skip, state("HEALER", false, true, false)))
    assert.is_false(Rules.Visible(calls.oom, state("TANK", false, true, false)))
    assert.is_true(Rules.Visible(calls.oom, state("HEALER", true, true, false)))
    assert.is_false(Rules.Visible(calls.wipe, state("TANK", false, true, false)))
    assert.is_true(Rules.Visible(calls.brb, state("TANK", false, false, false)))
    assert.is_false(Rules.Visible(calls.lust, state("TANK", false, false, false)))
  end)

  it("hides an enabled custom slot with no message", function()
    local calls = Rules.Fill({})
    calls.custom1.enabled = true
    assert.is_false(Rules.Visible(calls.custom1, state("TANK", false, false, false)))
    calls.custom1.message = "Hi"
    assert.is_true(Rules.Visible(calls.custom1, state("TANK", false, false, false)))
  end)

  it("keeps custom slots off by default", function()
    local calls = Rules.Fill({})
    assert.is_false(calls.custom3.enabled)
    assert.is_true(calls.custom3.roles.HEALER)
    assert.equals("any", calls.custom3.combat)
    assert.equals("group", calls.custom3.content)
  end)

  it("shows the panel only in a party with a visible call, or in preview", function()
    assert.is_true(Rules.PanelShown({ party = true, raid = false, preview = false, anyVisible = true }))
    assert.is_false(Rules.PanelShown({ party = true, raid = true, preview = false, anyVisible = true }))
    assert.is_false(Rules.PanelShown({ party = true, raid = false, preview = false, anyVisible = false }))
    assert.is_false(Rules.PanelShown({ party = false, raid = false, preview = false, anyVisible = true }))
    assert.is_true(Rules.PanelShown({ party = false, raid = false, preview = true, anyVisible = false }))
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
    assert.equals(136012, Rules.Texture(2825, tex))
    assert.equals(136012, Rules.Texture("2825", tex))
    assert.equals(Rules.QUESTION, Rules.Texture(999, tex))
    assert.equals("Interface\\Icons\\Foo", Rules.Texture("Interface\\Icons\\Foo", tex))
    for _, junk in ipairs({ "abc", "", "  " }) do
      assert.equals(Rules.QUESTION, Rules.Texture(junk, tex))
    end
    assert.equals(Rules.QUESTION, Rules.Texture(nil, tex))
  end)

  it("reset restores a built-in after edits", function()
    local calls = Rules.Fill({})
    calls.lust.message = "x"
    calls.lust.roles.TANK = false
    Rules.Reset(calls, "lust")
    assert.equals("LUST NOW", calls.lust.message)
    assert.is_true(calls.lust.roles.TANK)
  end)

  it("fills missing fields without sharing the default roles table", function()
    local calls = Rules.Fill({ lust = { message = "Go" } })
    assert.equals("Go", calls.lust.message)
    assert.equals(7, calls.lust.mark)
    calls.lust.roles.TANK = false
    assert.is_true(Rules.Fill({}).lust.roles.TANK)
  end)
end)
