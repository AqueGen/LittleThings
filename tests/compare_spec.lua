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
  _G.GetNumSubgroupMembers = function() return #state.party end
  _G.UnitName = function(unit) local u = state.units[unit] return u.name, u.realm end
  _G.UnitClass = function(unit) return nil, state.units[unit].class end
  _G.UnitGroupRolesAssigned = function(unit) return state.units[unit].role end
  _G.GetSpecialization = function() return 2 end
  _G.GetSpecializationRole = function(spec) return spec == 2 and "HEALER" or nil end
  loadfile("Modules/Applicants/Compare.lua")("LittleThings", ns)
  return module
end

local function application(status, members)
  return { applicationStatus = status, numMembers = #members, members = members }
end

describe("Compare data readers", function()
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
      { name = "Cutlers", realm = "Silvermoon", class = "ROGUE", role = "DAMAGER" },
      { name = "Medvedyk", realm = "TarrenMill", class = "DRUID", role = "HEALER" },
    }, compare.applicants())
  end)

  it("uses the player's spec role when no role is assigned", function()
    local compare = load({
      party = { "party1" },
      units = {
        player = { name = "Borshbringer", class = "PALADIN", role = "NONE" },
        party1 = { name = "Ктулху", realm = "Gordunni", class = "MAGE", role = "DAMAGER" },
      },
    })
    assert.same({
      { name = "Borshbringer", realm = "TarrenMill", class = "PALADIN", role = "HEALER" },
      { name = "Ктулху", realm = "Gordunni", class = "MAGE", role = "DAMAGER" },
    }, compare.group())
  end)
end)
