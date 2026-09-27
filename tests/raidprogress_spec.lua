package.path = "./Modules/Applicants/?.lua;" .. package.path

local Progress = require("RaidProgress")

local ABYSS = { mapId = 2900, bossCount = 9 }
local GROTTO = { mapId = 2901, bossCount = 1 }

local function entry(raid, difficulty, kills)
  return { raid = raid, difficulty = difficulty, progressCount = kills }
end

describe("Progress.Best", function()
  it("picks the highest difficulty, then the most kills", function()
    local best = Progress.Best({ entry(ABYSS, 1, 9), entry(ABYSS, 2, 6), entry(GROTTO, 2, 1) })
    assert.equals(6, best.progressCount)
    assert.equals(2, best.difficulty)
  end)

  it("returns nothing for no progress", function()
    assert.is_nil(Progress.Best({}))
    assert.is_nil(Progress.Best(nil))
    assert.is_nil(Progress.Best({ entry(ABYSS, 2, 0) }))
  end)
end)

describe("Progress.For", function()
  it("finds the listed raid at the listed difficulty", function()
    local found = Progress.For({ entry(ABYSS, 1, 9), entry(ABYSS, 2, 6) }, 2900, 2)
    assert.equals(6, found.progressCount)
  end)

  it("returns nothing when the player has no kills there", function()
    assert.is_nil(Progress.For({ entry(ABYSS, 1, 9) }, 2900, 2))
    assert.is_nil(Progress.For({ entry(ABYSS, 2, 0) }, 2900, 2))
    assert.is_nil(Progress.For(nil, 2900, 2))
  end)
end)

describe("Progress.Text", function()
  it("reads kills over bosses and the difficulty letter", function()
    assert.equals("6/9 H", Progress.Text(entry(ABYSS, 2, 6)))
    assert.equals("1/1 M", Progress.Text(entry(GROTTO, 3, 1)))
    assert.equals("", Progress.Text(nil))
  end)

  it("leaves the difficulty letter out when asked, for tight rows", function()
    assert.equals("6/9", Progress.Text(entry(ABYSS, 2, 6), true))
  end)
end)

describe("Progress.Difficulty", function()
  it("maps a listing's activity to the difficulty numbers Raider.IO uses", function()
    assert.equals(3, Progress.Difficulty({ isMythicActivity = true }))
    assert.equals(2, Progress.Difficulty({ isHeroicActivity = true }))
    assert.equals(1, Progress.Difficulty({ isNormalActivity = true }))
    assert.is_nil(Progress.Difficulty({}))
  end)
end)

describe("Progress.Score", function()
  it("ranks mythic over heroic over normal in the listed raid, then kills", function()
    local mythic2 = Progress.Score({ entry(ABYSS, 3, 2), entry(ABYSS, 2, 9) }, 2900)
    local heroic9 = Progress.Score({ entry(ABYSS, 2, 9) }, 2900)
    local heroic6 = Progress.Score({ entry(ABYSS, 2, 6), entry(ABYSS, 1, 9) }, 2900)
    assert.is_true(mythic2 > heroic9)
    assert.is_true(heroic9 > heroic6)
  end)

  it("ignores other raids", function()
    assert.is_nil(Progress.Score({ entry(GROTTO, 3, 1) }, 2900))
    assert.is_nil(Progress.Score(nil, 2900))
  end)
end)
