package.path = "./Modules/BattleResGuard/?.lua;./Modules/Applicants/?.lua;" .. package.path

local Rules = require("BattleResRules")
local BATTLE_RES = require("FilterRules").BATTLE_RES

local SECRET = {}
local function isSecret(value) return value == SECRET end

describe("Rules.ChargeState", function()
  it("is none without charge info", function()
    assert.equals("none", Rules.ChargeState(nil, isSecret))
  end)
  it("is none when the pool has no charges at all", function()
    assert.equals("none", Rules.ChargeState({ maxCharges = 0, currentCharges = SECRET, isActive = true }, isSecret))
  end)
  it("reads readable charges", function()
    assert.equals("some", Rules.ChargeState({ maxCharges = 5, currentCharges = 2, isActive = true }, isSecret))
    assert.equals("none", Rules.ChargeState({ maxCharges = 5, currentCharges = 0, isActive = true }, isSecret))
  end)
  it("is some when secret and the pool is full", function()
    assert.equals("some", Rules.ChargeState({ maxCharges = 1, currentCharges = SECRET, isActive = false }, isSecret))
  end)
  it("is none when secret, recharging and one charge at most", function()
    assert.equals("none", Rules.ChargeState({ maxCharges = 1, currentCharges = SECRET, isActive = true }, isSecret))
  end)
  it("is unknown when secret, recharging and more than one charge", function()
    assert.equals("unknown", Rules.ChargeState({ maxCharges = 3, currentCharges = SECRET, isActive = true }, isSecret))
  end)
  it("never compares a secret count", function()
    local guarded = setmetatable({}, { __lt = function() error("compared a secret") end, __le = function() error("compared a secret") end })
    local function guardedSecret(value) return value == guarded end
    assert.equals("unknown", Rules.ChargeState({ maxCharges = 2, currentCharges = guarded, isActive = true }, guardedSecret))
  end)
end)

describe("Rules.Casters", function()
  it("keeps alive, connected battle res classes in order", function()
    local members = {
      { name = "Bark", class = "DRUID", dead = false, connected = true },
      { name = "Arrow", class = "HUNTER", dead = false, connected = true },
      { name = "Doom", class = "WARLOCK", dead = false, connected = true },
    }
    assert.same({ "Bark", "Doom" }, Rules.Casters(members, BATTLE_RES))
  end)
  it("drops dead and disconnected casters", function()
    local members = {
      { name = "Bark", class = "DRUID", dead = true, connected = true },
      { name = "Bones", class = "DEATHKNIGHT", dead = false, connected = false },
      { name = "Light", class = "PALADIN", dead = false, connected = true },
    }
    assert.same({ "Light" }, Rules.Casters(members, BATTLE_RES))
  end)
  it("is empty without members", function()
    assert.same({}, Rules.Casters({}, BATTLE_RES))
  end)
end)
