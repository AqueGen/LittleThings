local SECRET = "Secret-Name"

local function load(state)
  local module
  local ns = { RegisterModule = function(_, m) module = m end }
  _G.issecretvalue = function(v) return v == SECRET end
  _G.GetNormalizedRealmName = function() return "TarrenMill" end
  _G.C_LFGList = {
    GetApplicants = function() return state.ids end,
    GetApplicantInfo = function(id) return state.applications[id] end,
    GetApplicantMemberInfo = function(id, i)
      local m = state.applications[id].members[i]
      return m.name, m.class, nil, nil, nil, nil, m.tank, m.healer, m.damage, m.role, nil, m.rating, nil, nil, nil, m.spec
    end,
  }
  loadfile("Modules/Applicants/Compare.lua")("LittleThings", ns)
  return module
end

local function application(status, members)
  return { applicationStatus = status, numMembers = #members, members = members }
end

local function dps(name, class, rating)
  return { name = name, class = class, role = "DAMAGER", damage = true, rating = rating }
end

describe("Compare.applications", function()
  it("reads only live applications, skips secret names and splits the realm", function()
    local compare = load({
      ids = { 1, 2, 3, 4 },
      applications = {
        application("applied", { dps("Cutlers-Silvermoon", "ROGUE", 2900) }),
        application("invited", { { name = "Medvedyk", class = "DRUID", role = "HEALER", healer = true, damage = true, rating = 2500 }, dps(SECRET, "MAGE", 3000) }),
        application("declined", { dps("Gone", "MAGE", 3000) }),
        application("cancelled", { dps("Left", "MAGE", 3000) }),
      },
    })
    assert.same({
      { members = { { name = "Cutlers", realm = "Silvermoon", class = "ROGUE", role = "DAMAGER", rating = 2900, roles = { TANK = false, HEALER = false, DAMAGER = true } } } },
      { members = { { name = "Medvedyk", realm = "TarrenMill", class = "DRUID", role = "HEALER", rating = 2500, roles = { TANK = false, HEALER = true, DAMAGER = true } } } },
    }, compare.applications())
  end)

  it("keeps an application whose members are all unreadable as an empty one", function()
    local compare = load({ ids = { 1 }, applications = { application("applied", { dps(SECRET, "MAGE", 3000) }) } })
    assert.same({ { members = {} } }, compare.applications())
  end)

  it("skips a member whose rating is secret", function()
    local compare = load({ ids = { 1 }, applications = { application("applied", { dps("Cutlers", "ROGUE", SECRET) }) } })
    assert.same({ { members = {} } }, compare.applications())
  end)

  it("reads the specID and drops it when it is secret or missing", function()
    local compare = load({ ids = { 1 }, applications = { application("applied", {
      { name = "Flex", class = "DEMONHUNTER", role = "DAMAGER", tank = true, damage = true, rating = 2900, spec = 1480 },
      { name = "Hidden", class = "MAGE", role = "DAMAGER", damage = true, rating = 2500, spec = SECRET },
      dps("Plain", "ROGUE", 2400),
    }) } })
    local members = compare.applications()[1].members
    assert.equals(1480, members[1].spec)
    assert.is_nil(members[2].spec)
    assert.equals("Hidden", members[2].name)
    assert.is_nil(members[3].spec)
  end)
end)
