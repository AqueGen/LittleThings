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
      return m.name, m.class, nil, nil, nil, nil, nil, nil, nil, m.role
    end,
  }
  loadfile("Modules/Applicants/Compare.lua")("LittleThings", ns)
  return module
end

local function application(status, members)
  return { applicationStatus = status, numMembers = #members, members = members }
end

describe("Compare.applicants", function()
  it("reads only live applications, skips secret names and splits the realm", function()
    local compare = load({
      ids = { 1, 2, 3, 4 },
      applications = {
        application("applied", { { name = "Cutlers-Silvermoon", class = "ROGUE", role = "DAMAGER" } }),
        application("invited", { { name = "Medvedyk", class = "DRUID", role = "HEALER" }, { name = SECRET, class = "MAGE", role = "DAMAGER" } }),
        application("declined", { { name = "Gone", class = "MAGE", role = "DAMAGER" } }),
        application("cancelled", { { name = "Left", class = "MAGE", role = "DAMAGER" } }),
      },
    })
    assert.same({
      { name = "Cutlers", realm = "Silvermoon", class = "ROGUE", role = "DAMAGER", app = 1 },
      { name = "Medvedyk", realm = "TarrenMill", class = "DRUID", role = "HEALER", app = 2 },
    }, compare.applicants())
  end)

  it("gives a duo one number and numbers only applications that add a member", function()
    local compare = load({
      ids = { 1, 2, 3 },
      applications = {
        application("applied", { { name = SECRET, class = "MAGE", role = "DAMAGER" } }),
        application("applied", { { name = "Cutlers", class = "ROGUE", role = "DAMAGER" }, { name = "Medvedyk", class = "DRUID", role = "HEALER" } }),
        application("applied", { { name = "Ктулху-Gordunni", class = "MAGE", role = "DAMAGER" } }),
      },
    })
    assert.same({
      { name = "Cutlers", realm = "TarrenMill", class = "ROGUE", role = "DAMAGER", app = 1 },
      { name = "Medvedyk", realm = "TarrenMill", class = "DRUID", role = "HEALER", app = 1 },
      { name = "Ктулху", realm = "Gordunni", class = "MAGE", role = "DAMAGER", app = 2 },
    }, compare.applicants())
  end)
end)
