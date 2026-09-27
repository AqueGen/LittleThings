package.path = "./Modules/Applicants/?.lua;" .. package.path

local Keys = require("KeystoneRules")

describe("Keys.MythicPlusActivity", function()
  local activities = {
    { id = 10, mapID = 2805, isMythicPlusActivity = false, groupFinderActivityGroupID = 300 },
    { id = 11, mapID = 2805, isMythicPlusActivity = true, groupFinderActivityGroupID = 300 },
    { id = 20, mapID = 2811, isMythicPlusActivity = true, groupFinderActivityGroupID = 301 },
  }

  it("finds the keystone activity of a dungeon and its group", function()
    local activityID, groupID = Keys.MythicPlusActivity(activities, 2805)
    assert.equals(11, activityID)
    assert.equals(300, groupID)
  end)

  it("finds nothing for a dungeon without a keystone activity", function()
    assert.is_nil(Keys.MythicPlusActivity(activities, 9999))
    assert.is_nil(Keys.MythicPlusActivity({ activities[1] }, 2805))
  end)
end)

describe("Keys.Rows", function()
  local keys = {
    ["Me"] = { level = 11, challengeMapID = 1 },
    ["Tank-Kazzak"] = { level = 14, challengeMapID = 2 },
    ["Healer"] = { level = 9, challengeMapID = 3 },
    ["Gone"] = { level = 20, challengeMapID = 4 },
    ["NoKey"] = { level = 0, challengeMapID = 0 },
  }

  it("keeps the group's members with a key, yours first, then highest first", function()
    local rows = Keys.Rows(keys, "Me", { "Me", "Tank-Kazzak", "Healer", "NoKey" })
    assert.equals(3, #rows)
    assert.equals("Me", rows[1].name)
    assert.equals("Tank-Kazzak", rows[2].name)
    assert.equals("Healer", rows[3].name)
    assert.equals(14, rows[2].level)
  end)

  it("shows your own key when you are alone", function()
    local rows = Keys.Rows(keys, "Me", { "Me" })
    assert.equals(1, #rows)
    assert.equals("Me", rows[1].name)
  end)
end)
