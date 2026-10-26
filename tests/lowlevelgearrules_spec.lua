package.path = "./Modules/LowLevelGear/?.lua;" .. package.path

local Rules = require("LowLevelGearRules")

local VETERAN, CHAMPION, HERO, MYTH = 972, 973, 974, 978
local NAMES = { [VETERAN] = "Veteran", [CHAMPION] = "Champion", [HERO] = "Hero", [MYTH] = "Myth" }

local function item(fields)
  local base = { equipLoc = "INVTYPE_HEAD", bound = true, accountUntilEquip = false,
    uncollected = false, itemLevel = 311, trackStringID = HERO }
  for k, v in pairs(fields or {}) do base[k] = v end
  base.trackString = NAMES[base.trackStringID]
  return base
end

local function piece(level, track)
  return { level = level, track = track, trackString = NAMES[track] }
end

local function wornAll(level, track)
  local worn = {}
  for _, slot in ipairs(Rules.EQUIPPED_SLOTS) do worn[slot] = piece(level, track) end
  return worn
end

local WORN = wornAll(321, HERO)

describe("LowLevelGearRules.Evaluate", function()
  it("marks a lower track than the worn piece, with the reason", function()
    local low, reason = Rules.Evaluate(item({ trackStringID = CHAMPION, itemLevel = 298 }), WORN)
    assert.is_true(low)
    assert.equals("Champion 298, worn Hero 321", reason)
  end)

  it("marks a lower track even at a higher item level", function()
    assert.is_true((Rules.Evaluate(item({ trackStringID = CHAMPION, itemLevel = 325 }), WORN)))
  end)

  it("marks the same track below the worn level", function()
    local low, reason = Rules.Evaluate(item({ itemLevel = 311 }), WORN)
    assert.is_true(low)
    assert.equals("Hero 311, worn Hero 321", reason)
  end)

  it("keeps the same track at or above the worn level", function()
    assert.is_false((Rules.Evaluate(item({ itemLevel = 321 }), WORN)))
    assert.is_false((Rules.Evaluate(item({ itemLevel = 324 }), WORN)))
  end)

  it("keeps a higher track", function()
    assert.is_false((Rules.Evaluate(item({ trackStringID = HERO, itemLevel = 300 }), wornAll(321, CHAMPION))))
  end)

  it("never marks Myth, even below a worn Myth piece", function()
    assert.is_false((Rules.Evaluate(item({ trackStringID = MYTH, itemLevel = 318 }), wornAll(334, MYTH))))
  end)

  it("never marks an item or a worn piece on an unknown track", function()
    assert.is_false((Rules.Evaluate(item({ trackStringID = 9999, itemLevel = 200 }), WORN)))
    local untracked = item({ itemLevel = 200 })
    untracked.trackStringID = nil
    assert.is_false((Rules.Evaluate(untracked, WORN)))
    assert.is_false((Rules.Evaluate(item({ trackStringID = CHAMPION }), wornAll(321, nil))))
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
    assert.is_false((Rules.Evaluate(item({ setID = 2062 }), WORN)))
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
    assert.is_false((Rules.Evaluate(item(), { [5] = piece(321, HERO) })))
  end)

  it("compares a robe with the chest slot", function()
    assert.is_true((Rules.Evaluate(item({ equipLoc = "INVTYPE_ROBE" }), { [5] = piece(321, HERO) })))
  end)

  it("compares a ring with the worse of the two rings", function()
    local rings = { [11] = piece(334, MYTH), [12] = piece(311, HERO) }
    local low, reason = Rules.Evaluate(item({ equipLoc = "INVTYPE_FINGER", itemLevel = 305 }), rings)
    assert.is_true(low)
    assert.equals("Hero 305, worn Hero 311", reason)
    assert.is_false((Rules.Evaluate(item({ equipLoc = "INVTYPE_FINGER", itemLevel = 311 }), rings)))
  end)

  it("never marks a ring when either ring slot is empty", function()
    assert.is_false((Rules.Evaluate(item({ equipLoc = "INVTYPE_FINGER", itemLevel = 200 }), { [11] = piece(321, HERO) })))
    assert.is_false((Rules.Evaluate(item({ equipLoc = "INVTYPE_FINGER", itemLevel = 200 }), { [12] = piece(321, HERO) })))
  end)

  it("maps every armor and jewelry type to its slot", function()
    local expected = { INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
      INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_CLOAK = 15 }
    for loc, slot in pairs(expected) do
      assert.is_true((Rules.Evaluate(item({ equipLoc = loc }), { [slot] = piece(321, HERO) })), loc)
      assert.is_false((Rules.Evaluate(item({ equipLoc = loc }), { [slot == 1 and 2 or 1] = piece(321, HERO) })), loc)
    end
  end)
end)
