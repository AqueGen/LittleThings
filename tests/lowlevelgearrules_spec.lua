package.path = "./Modules/LowLevelGear/?.lua;" .. package.path

local Rules = require("LowLevelGearRules")

local function item(fields)
  local base = { equipLoc = "INVTYPE_HEAD", bound = true, accountUntilEquip = false,
    uncollected = false, itemLevel = 619 }
  for k, v in pairs(fields or {}) do base[k] = v end
  return base
end

local WORN = { [1] = 636, [2] = 636, [3] = 636, [5] = 636, [6] = 636, [7] = 636, [8] = 636,
  [9] = 636, [10] = 636, [11] = 640, [12] = 626, [15] = 636 }

describe("LowLevelGearRules.Evaluate", function()
  it("marks bound armor whose max is below the worn piece, with the reason", function()
    local junk, reason = Rules.Evaluate(item({ hasUpgradeInfo = true, maxItemLevel = 619 }), WORN)
    assert.is_true(junk)
    assert.equals("max 619 <= equipped 636", reason)
  end)

  it("counts an equal level as low", function()
    assert.is_true((Rules.Evaluate(item({ hasUpgradeInfo = true, maxItemLevel = 636 }), WORN)))
  end)

  it("keeps an item that upgrades above the worn piece", function()
    assert.is_false((Rules.Evaluate(item({ itemLevel = 610, hasUpgradeInfo = true, maxItemLevel = 639 }), WORN)))
  end)

  it("falls back to the current level without an upgrade track", function()
    assert.is_true((Rules.Evaluate(item({ itemLevel = 630 }), WORN)))
    assert.is_false((Rules.Evaluate(item({ itemLevel = 640 }), WORN)))
  end)

  it("never marks a tracked item whose max level is 0 or missing", function()
    assert.is_false((Rules.Evaluate(item({ itemLevel = 334, hasUpgradeInfo = true, maxItemLevel = 0 }), WORN)))
    assert.is_false((Rules.Evaluate(item({ itemLevel = 334, hasUpgradeInfo = true }), WORN)))
  end)

  it("never marks an item on a track in the never set", function()
    local never = { [9999] = true }
    assert.is_false((Rules.Evaluate(item({ hasUpgradeInfo = true, maxItemLevel = 619, trackStringID = 9999 }), WORN, never)))
    assert.is_true((Rules.Evaluate(item({ hasUpgradeInfo = true, maxItemLevel = 619, trackStringID = 9998 }), WORN, never)))
  end)

  it("never marks without a level", function()
    local unknown = item()
    unknown.itemLevel = nil
    assert.is_false((Rules.Evaluate(unknown, WORN)))
  end)

  it("never marks an uncollected appearance", function()
    assert.is_false((Rules.Evaluate(item({ uncollected = true }), WORN)))
  end)

  it("never marks a tier set piece", function()
    assert.is_false((Rules.Evaluate(item({ setID = 1234 }), WORN)))
  end)

  it("never marks unbound or warbound-until-equip items", function()
    assert.is_false((Rules.Evaluate(item({ bound = false }), WORN)))
    assert.is_false((Rules.Evaluate(item({ accountUntilEquip = true }), WORN)))
  end)

  it("never marks trinkets, weapons, off-hands, shields or ranged", function()
    for _, loc in ipairs({ "INVTYPE_TRINKET", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON", "INVTYPE_WEAPONMAINHAND",
      "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" }) do
      assert.is_false((Rules.Evaluate(item({ equipLoc = loc }), WORN)), loc)
    end
  end)

  it("never marks non-equippable or unknown types", function()
    assert.is_false((Rules.Evaluate(item({ equipLoc = "" }), WORN)))
    assert.is_false((Rules.Evaluate(item({ equipLoc = "INVTYPE_TABARD" }), WORN)))
  end)

  it("never marks when the matching slot is empty", function()
    assert.is_false((Rules.Evaluate(item(), { [5] = 636 })))
  end)

  it("compares a robe with the chest slot", function()
    local junk, reason = Rules.Evaluate(item({ equipLoc = "INVTYPE_ROBE", itemLevel = 600 }), WORN)
    assert.is_true(junk)
    assert.equals("max 600 <= equipped 636", reason)
  end)

  it("compares a ring with the lower of the two rings", function()
    local junk, reason = Rules.Evaluate(item({ equipLoc = "INVTYPE_FINGER", itemLevel = 626 }), WORN)
    assert.is_true(junk)
    assert.equals("max 626 <= equipped 626", reason)
    assert.is_false((Rules.Evaluate(item({ equipLoc = "INVTYPE_FINGER", itemLevel = 630 }), WORN)))
  end)

  it("never marks a ring when either ring slot is empty", function()
    assert.is_false((Rules.Evaluate(item({ equipLoc = "INVTYPE_FINGER", itemLevel = 500 }), { [11] = 640 })))
    assert.is_false((Rules.Evaluate(item({ equipLoc = "INVTYPE_FINGER", itemLevel = 500 }), { [12] = 640 })))
  end)

  it("maps every armor and jewelry type to its slot", function()
    local expected = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
      INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_CLOAK = 15 }
    for loc, slot in pairs(expected) do
      assert.is_true((Rules.Evaluate(item({ equipLoc = loc }), { [slot] = 619 })), loc)
      assert.is_false((Rules.Evaluate(item({ equipLoc = loc }), { [slot == 1 and 2 or 1] = 619 })), loc)
    end
  end)
end)
