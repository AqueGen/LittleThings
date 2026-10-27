package.path = "./Modules/SaveIndicator/?.lua;" .. package.path
local Rules = require("SaveRules")

local DATA = {
  [389539] = { dr = 30, name = "Sentinel", perStack = 2, maxStacks = 15 },
  [33206] = { dr = 40, name = "Pain Suppression" },
  [102342] = { dr = 20, name = "Ironbark" },
  [6940] = { dr = 30, name = "Blessing of Sacrifice" },
  [642] = { dr = 100, name = "Divine Shield" },
  [1] = { dr = 15, name = "Too weak" },
}

describe("Rules.Buckets", function()
  it("groups fixed saves by reduction, strongest first, without stacked or weak ones", function()
    local b = Rules.Buckets(DATA)
    assert.same({ 100, 40, 30, 20 }, { b[1].dr, b[2].dr, b[3].dr, b[4].dr })
    assert.same({ [6940] = true }, b[3].ids)
    assert.is_nil(b[5])
  end)
end)

describe("Rules.Stacked", function()
  it("lists Sentinel with its stack rule", function()
    assert.same({ { id = 389539, dr = 30, perStack = 2, maxStacks = 15 } }, Rules.Stacked(DATA))
  end)
end)

describe("Rules.AllIDs", function()
  it("has every save at 20 or more, stacked included", function()
    local ids = Rules.AllIDs(DATA)
    assert.is_true(ids[389539] and ids[102342] and ids[642])
    assert.is_nil(ids[1])
  end)
end)

describe("Rules.Row", function()
  it("orders the centre row by strength, Sentinel before the fixed 30 bucket", function()
    local row = Rules.Row(DATA)
    assert.same({ 100, 40, 30, 30, 20 }, { row[1].dr, row[2].dr, row[3].dr, row[4].dr, row[5].dr })
    assert.same({ [389539] = true }, row[3].ids)
    assert.equals(2, row[3].perStack)
    assert.same({ [6940] = true }, row[4].ids)
    assert.is_nil(row[4].perStack)
    assert.is_nil(row[6])
  end)
end)

describe("Rules.CornerIDs", function()
  it("drops saves Blizzard already flags as big defensive", function()
    local big = { [642] = true, [33206] = true }
    local ids = Rules.CornerIDs(DATA, function(id) return big[id] == true end)
    assert.is_true(ids[389539] and ids[6940] and ids[102342])
    assert.is_nil(ids[642])
    assert.is_nil(ids[33206])
  end)
end)

describe("Rules.StackBreakpoints", function()
  local bp = Rules.StackBreakpoints(2, 15)
  it("has one breakpoint per stack", function()
    assert.equals(15, #bp)
    assert.equals(12, bp[12].threshold)
  end)
  it("keeps the normal colour at 10 stacks and turns low at 9", function()
    assert.equals("|c" .. Rules.COLORS.normal .. "-20%%|r", bp[10].format)
    assert.equals("|c" .. Rules.COLORS.low .. "-18%%|r", bp[9].format)
  end)
end)

describe("Rules.CenterOffset", function()
  it("turns a dropped frame centre into an offset from the screen centre", function()
    assert.same({ 0, -140 }, { Rules.CenterOffset(960, 400, 960, 540, 1) })
  end)
  it("works in the row's own scale", function()
    assert.same({ 100, 0 }, { Rules.CenterOffset(580, 270, 960, 540, 2) })
  end)
  it("rounds to whole pixels", function()
    assert.same({ 1, -1 }, { Rules.CenterOffset(960.6, 539.4, 960, 540, 1) })
  end)
end)

describe("Rules.ChainStart", function()
  local SECRET = {}
  local function isSecret(v) return v == SECRET end
  it("starts the chain half its width left of the centre", function()
    assert.equals(-19, Rules.ChainStart({ 1, 36, 1 }, isSecret))
  end)
  it("centres two icons on the anchor", function()
    assert.equals(-36, Rules.ChainStart({ 36, 36 }, isSecret))
  end)
  it("gives up when a width is secret", function()
    assert.is_nil(Rules.ChainStart({ 36, SECRET }, isSecret))
  end)
end)

describe("Rules.Label", function()
  it("prints a fixed reduction", function()
    assert.equals("-40%", Rules.Label(40))
    assert.equals("-100%", Rules.Label(100))
  end)
end)

describe("Rules.Where", function()
  local function where(s) return { Rules.Where(s) } end
  it("shows centre and corners solo", function()
    assert.same({ true, true }, where({ inGroup = false, inRaid = false, instanceType = "none", raidOn = false }))
  end)
  it("is fully on in a party", function()
    assert.same({ true, true }, where({ inGroup = true, inRaid = false, instanceType = "party", raidOn = false }))
  end)
  it("is off in a raid by default", function()
    assert.same({ false, false }, where({ inGroup = true, inRaid = true, instanceType = "raid", raidOn = false }))
  end)
  it("shows only the centre in a raid when the raid switch is on", function()
    assert.same({ true, false }, where({ inGroup = true, inRaid = true, instanceType = "raid", raidOn = true }))
  end)
  it("is off in battlegrounds and arenas", function()
    assert.same({ false, false }, where({ inGroup = true, inRaid = true, instanceType = "pvp", raidOn = true }))
    assert.same({ false, false }, where({ inGroup = true, inRaid = false, instanceType = "arena", raidOn = true }))
  end)
end)
