package.path = "./Modules/Applicants/?.lua;" .. package.path

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

local function install(fakes)
  _G.issecretvalue = function(value) return value == SECRET end
  _G.C_LFGList = fakes.lfg
  _G.UnitExists = function(unit) return fakes.units[unit] ~= nil end
  _G.UnitClassBase = function(unit) return fakes.units[unit].class end
  _G.UnitName = function(unit) return fakes.units[unit].name, fakes.units[unit].realm end
  _G.GetNormalizedRealmName = function() return "TarrenMill" end
  _G.UnitGroupRolesAssigned = function(unit) return fakes.units[unit].role end
end

local function lfg(members, status, best)
  return {
    GetApplicantInfo = function() return { numMembers = #members, applicationStatus = status or "applied" } end,
    GetApplicantMemberInfo = function(_, i)
      local m = members[i]
      return "Name", m.class, "Class", 90, m.itemLevel, 0, m.tank, m.healer, m.damage, "NONE", nil, m.rating
    end,
    GetApplicantDungeonScoreForListing = function(_, i) return best and best[i] end,
    GetApplicantBestDungeonScore = function() return nil end,
    GetActiveEntryInfo = function() return { activityIDs = { 42 } } end,
    GetActivityInfoTable = function() return { isMythicPlusActivity = true, maxNumPlayers = 5 } end,
  }
end

local function load()
  package.loaded["FilterRules"] = nil
  package.loaded["ApplicantData"] = nil
  package.loaded["RaidProgress"] = nil
  return require("ApplicantData")
end

describe("Data.Application", function()
  it("reads every member into the plain table the rules use", function()
    install({ units = {}, lfg = lfg(
      { { class = "MAGE", itemLevel = 291.4, tank = false, healer = false, damage = true, rating = 2700 } },
      "applied", { { bestRunLevel = 12, finishedSuccess = true, mapScore = 310 } }) })
    local Data = load()
    local application = Data.Application(7, { activityID = 42, isMythicPlus = true })
    local m = application.members[1]
    assert.equals("MAGE", m.class)
    assert.equals(2700, m.rating)
    assert.equals(291.4, m.itemLevel)
    assert.is_true(m.roles.DAMAGER)
    assert.equals(12, m.dungeonLevel)
    assert.is_true(m.dungeonTimed)
    assert.equals(310, m.dungeonScore)
    assert.is_false(application.pinned)
  end)

  it("marks an invited application as pinned", function()
    install({ units = {}, lfg = lfg({ { class = "MAGE", itemLevel = 290, tank = false, healer = false, damage = true, rating = 1 } }, "invited") })
    assert.is_true(load().Application(7, { activityID = 42, isMythicPlus = true }).pinned)
  end)

  it("returns nothing when any member value is Secret", function()
    install({ units = {}, lfg = lfg({
      { class = "MAGE", itemLevel = 290, tank = false, healer = false, damage = true, rating = 2000 },
      { class = "PRIEST", itemLevel = 290, tank = false, healer = true, damage = false, rating = SECRET },
    }) })
    assert.is_nil(load().Application(7, { activityID = 42, isMythicPlus = true }))
  end)

  it("returns nothing when the dungeon score is Secret", function()
    install({ units = {}, lfg = lfg(
      { { class = "MAGE", itemLevel = 290, tank = false, healer = false, damage = true, rating = 2000 } },
      "applied", { { bestRunLevel = SECRET, finishedSuccess = true, mapScore = 1 } }) })
    assert.is_nil(load().Application(7, { activityID = 42, isMythicPlus = true }))
  end)

  it("leaves the dungeon fields empty outside Mythic+ listings", function()
    install({ units = {}, lfg = lfg(
      { { class = "MAGE", itemLevel = 290, tank = false, healer = false, damage = true, rating = 2000 } },
      "applied", { { bestRunLevel = 12, finishedSuccess = true, mapScore = 1 } }) })
    local m = load().Application(7, { activityID = 42, isMythicPlus = false }).members[1]
    assert.is_nil(m.dungeonLevel)
  end)
end)

describe("Data.Group", function()
  it("counts assigned roles against one tank, one healer, three damage", function()
    install({ lfg = lfg({}), units = {
      player = { class = "PALADIN", role = "TANK" },
      party1 = { class = "SHAMAN", role = "HEALER" },
      party2 = { class = "ROGUE", role = "DAMAGER" },
    } })
    local group = load().Group({ fiveMan = true })
    assert.same({ TANK = 0, HEALER = 0, DAMAGER = 2 }, group.open)
    assert.is_true(group.hasBloodlust)
    assert.is_true(group.hasBattleRes)
  end)

  it("has no role slots for a listing that is not five players", function()
    install({ lfg = lfg({}), units = { player = { class = "ROGUE", role = "DAMAGER" } } })
    local group = load().Group({ fiveMan = false })
    assert.is_nil(group.open)
    assert.is_false(group.hasBloodlust)
  end)
end)

describe("Data.Listing", function()
  it("reads nothing during chat messaging lockdown", function()
    install({ units = {}, lfg = lfg({}) })
    _G.C_ChatInfo = { InChatMessagingLockdown = function() return true end }
    assert.is_nil(load().Listing())
    _G.C_ChatInfo = nil
  end)

  it("reads nothing when the activity id is Secret", function()
    local fake = lfg({})
    fake.GetActiveEntryInfo = function() return { activityIDs = { SECRET } } end
    install({ units = {}, lfg = fake })
    assert.is_nil(load().Listing())
  end)
end)

describe("Data.Application, members still loading", function()
  it("keeps an application whose member class has not arrived yet", function()
    install({ units = {}, lfg = lfg({ { class = nil, itemLevel = 0, tank = false, healer = false, damage = true, rating = 0 } }) })
    local application = load().Application(7, { activityID = 42, isMythicPlus = false })
    assert.is_true(application.pinned)
  end)
end)

describe("Data.Group, unassigned roles", function()
  it("counts an unassigned party member as damage and the player by their spec role", function()
    install({ lfg = lfg({}), units = {
      player = { class = "PALADIN", role = "NONE" },
      party1 = { class = "ROGUE", role = "NONE" },
    } })
    _G.GetSpecialization = function() return 2 end
    _G.GetSpecializationRole = function(index) return index == 2 and "TANK" or nil end
    local group = load().Group({ fiveMan = true })
    assert.same({ TANK = 0, HEALER = 1, DAMAGER = 2 }, group.open)
  end)
end)

describe("Data.Group members", function()
  it("lists each member with realm, class and role, an unassigned party member as damage", function()
    install({ lfg = lfg({}), units = {
      player = { name = "Borshbringer", class = "PALADIN", role = "NONE" },
      party1 = { name = "Ктулху", realm = "Gordunni", class = "MAGE", role = "NONE" },
      party2 = { name = "Medvedyk", realm = "", class = "DRUID", role = "HEALER" },
    } })
    _G.GetSpecialization = function() return 2 end
    _G.GetSpecializationRole = function(index) return index == 2 and "TANK" or nil end
    assert.same({
      { name = "Borshbringer", realm = "TarrenMill", class = "PALADIN", role = "TANK" },
      { name = "Ктулху", realm = "Gordunni", class = "MAGE", role = "DAMAGER" },
      { name = "Medvedyk", realm = "TarrenMill", class = "DRUID", role = "HEALER" },
    }, load().Group({}).members)
  end)

  it("leaves out a member whose name is Secret", function()
    install({ lfg = lfg({}), units = {
      player = { name = "Borshbringer", class = "PALADIN", role = "TANK" },
      party1 = { name = SECRET, class = "MAGE", role = "DAMAGER" },
    } })
    assert.same({ { name = "Borshbringer", realm = "TarrenMill", class = "PALADIN", role = "TANK" } }, load().Group({}).members)
  end)
end)

describe("Data.Listing, raids", function()
  it("marks a raid listing and leaves PvP and dungeons out", function()
    local fake = lfg({})
    install({ units = {}, lfg = fake })
    fake.GetActivityInfoTable = function() return { isMythicPlusActivity = false, isHeroicActivity = true, maxNumPlayers = 30, mapID = 2900 } end
    local listing = load().Listing()
    assert.is_true(listing.isRaid)
    assert.equals(2900, listing.mapID)
    assert.equals(2, listing.raidDifficulty)
    fake.GetActivityInfoTable = function() return { isMythicPlusActivity = false, isPvpActivity = true, maxNumPlayers = 10 } end
    assert.is_false(load().Listing().isRaid)
    fake.GetActivityInfoTable = function() return { isMythicPlusActivity = true, maxNumPlayers = 5 } end
    assert.is_false(load().Listing().isRaid)
  end)
end)
