local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

local function new_texture()
  local t = { shown = false }
  function t:SetSize() end
  function t:SetPoint() end
  function t:SetAtlas(atlas) self.image = atlas end
  function t:SetTexture(path) self.image = path end
  function t:Show() self.shown = true end
  function t:Hide() self.shown = false end
  return t
end

local function new_frame(name, unit)
  local f = { unit = unit }
  function f:GetName() return name end
  function f:CreateTexture() return new_texture() end
  return f
end

local function load(state)
  local module, hook, handler
  local ns = {
    IsOn = function() return state.on end,
    RegisterModule = function(_, m) module = m end,
  }
  _G.MEMBERS_PER_RAID_GROUP, _G.MAX_RAID_MEMBERS, _G.NUM_RAID_GROUPS = 5, 40, 8
  _G.hooksecurefunc = function(_, fn) hook = fn end
  _G.CreateFrame = function()
    return {
      RegisterEvent = function() end,
      SetScript = function(_, _, fn) handler = fn end,
    }
  end
  _G.issecretvalue = function(v) return v == SECRET end
  _G.IsInRaid = function() return state.raid end
  _G.UnitExists = function(unit) return state.ranks[unit] ~= nil end
  _G.UnitIsGroupLeader = function(unit) return state.ranks[unit] == "leader" or state.ranks[unit] == SECRET and SECRET end
  _G.UnitIsGroupAssistant = function(unit) return state.ranks[unit] == "assistant" end
  loadfile("Modules/GroupLeader.lua")("LittleThings", ns)
  module.Enable()
  return { hook = hook, event = function() handler() end, module = module }
end

describe("GroupLeader", function()
  local state, addon

  before_each(function()
    state = { on = true, raid = false, ranks = { player = "none", party1 = "leader" } }
    addon = load(state)
  end)

  it("puts the crown on the leader and nothing on the others", function()
    local leader = new_frame("CompactPartyFrameMember2", "party1")
    local me = new_frame("CompactPartyFrameMember1", "player")
    addon.hook(leader)
    addon.hook(me)
    assert.equals("UI-HUD-UnitFrame-Player-Group-LeaderIcon", leader.ltLeaderIcon.image)
    assert.is_true(leader.ltLeaderIcon.shown)
    assert.is_nil(me.ltLeaderIcon)
  end)

  it("shows assistants only in a raid", function()
    state.ranks.raid3 = "assistant"
    local frame = new_frame("CompactRaidGroup1Member3", "raid3")
    addon.hook(frame)
    assert.is_nil(frame.ltLeaderIcon)
    state.raid = true
    addon.event()
    assert.equals("Interface\\GroupFrame\\UI-Group-AssistantIcon", frame.ltLeaderIcon.image)
  end)

  it("moves the crown when the leader changes", function()
    local old = new_frame("CompactPartyFrameMember2", "party1")
    local new = new_frame("CompactPartyFrameMember1", "player")
    addon.hook(old)
    addon.hook(new)
    state.ranks.party1, state.ranks.player = "none", "leader"
    addon.event()
    assert.is_false(old.ltLeaderIcon.shown)
    assert.is_true(new.ltLeaderIcon.shown)
  end)

  it("keeps the last icon while the rank is secret", function()
    local frame = new_frame("CompactRaidFrame1", "party1")
    addon.hook(frame)
    state.ranks.party1 = SECRET
    addon.event()
    assert.is_true(frame.ltLeaderIcon.shown)
  end)

  it("leaves nameplates and arena frames alone", function()
    state.ranks.nameplate1 = "leader"
    local plate = new_frame("NamePlate1UnitFrame", "nameplate1")
    local arena = new_frame("CompactArenaFrameMember1", "party1")
    addon.hook(plate)
    addon.hook(arena)
    assert.is_nil(plate.ltLeaderIcon)
    assert.is_nil(arena.ltLeaderIcon)
  end)

  it("hides every icon when switched off", function()
    local frame = new_frame("CompactPartyFrameMember2", "party1")
    addon.hook(frame)
    state.on = false
    addon.module.OnSwitch(false)
    assert.is_false(frame.ltLeaderIcon.shown)
  end)
end)
