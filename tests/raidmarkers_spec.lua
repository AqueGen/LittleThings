local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

local function noop() end

local function new_object(frames, name, template)
  local f = { name = name, template = template, attrs = {}, scripts = {}, events = {}, shown = true, showCalls = 0 }
  function f:SetAttribute(k, v) self.attrs[k] = v end
  function f:SetScript(script, fn) self.scripts[script] = fn end
  function f:RegisterEvent(event) self.events[event] = true end
  function f:Show() self.shown = true self.showCalls = self.showCalls + 1 end
  function f:Hide() self.shown = false end
  function f:IsShown() return self.shown end
  function f:CreateTexture() return new_object(frames) end
  function f:CreateFontString() return new_object(frames) end
  frames[#frames + 1] = f
  return setmetatable(f, { __index = function() return noop end })
end

local function load(state, db)
  local module
  local frames = {}
  local ns = {
    db = db or {},
    RegisterModule = function(_, m) module = m end,
    ApplyDefaults = function(target, defaults)
      for k, v in pairs(defaults) do
        if target[k] == nil then target[k] = v end
      end
    end,
  }
  _G.UIParent = {}
  _G.CreateFrame = function(_, name, _, template) return new_object(frames, name, template) end
  _G.InCombatLockdown = function() return state.combat end
  _G.IsInGroup = function() return state.group end
  _G.IsInRaid = function() return state.raid end
  _G.UnitIsGroupLeader = function() return state.leader end
  _G.UnitIsGroupAssistant = function() return state.assistant end
  _G.issecretvalue = function(v) return v == SECRET end
  _G.GetRaidTargetIndex = function() return state.targetIndex end
  _G.IsRaidMarkerActive = function() return false end
  _G.SetRaidTargetIconTexture = noop
  _G.C_Timer = { NewTicker = function() return { Cancel = noop } end }
  assert(loadfile("Modules/RaidMarkers/MarkerRules.lua"))("LittleThings", ns)
  assert(loadfile("Modules/RaidMarkers/RaidMarkers.lua"))("LittleThings", ns)

  local function fire(event, ...)
    for _, f in ipairs(frames) do
      if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
  end

  local function secure(match)
    local found = {}
    for _, f in ipairs(frames) do
      if f.template == "SecureActionButtonTemplate" and match(f.attrs) then found[#found + 1] = f end
    end
    return found
  end

  local function panel()
    for _, f in ipairs(frames) do
      if f.name == "LittleThingsRaidMarkers" then return f end
    end
  end

  return { module = module, ns = ns, fire = fire, secure = secure, panel = panel }
end

describe("RaidMarkers", function()
  local state, addon

  before_each(function()
    state = { combat = false, group = false, raid = false, leader = false, assistant = false }
    addon = load(state)
    addon.module.Enable()
  end)

  it("sets raidtarget set/clear on the 8 target buttons", function()
    for i = 1, 8 do
      local found = addon.secure(function(a)
        return a.type == "raidtarget" and a.marker == i and a.action1 == "set" and a.action2 == "clear" and a.unit == "target"
      end)
      assert.equals(1, #found)
    end
  end)

  it("clear all uses clear-all", function()
    local found = addon.secure(function(a) return a.type == "raidtarget" and a.action == "clear-all" end)
    assert.equals(1, #found)
  end)

  it("sets worldmarker set/clear on the 8 world buttons and a clear-all without marker", function()
    for i = 1, 8 do
      local found = addon.secure(function(a)
        return a.type == "worldmarker" and a.marker == i and a.action1 == "set" and a.action2 == "clear"
      end)
      assert.equals(1, #found)
    end
    local clear = addon.secure(function(a) return a.type == "worldmarker" and a.action == "clear" and a.marker == nil end)
    assert.equals(1, #clear)
  end)

  it("fills defaults before any page exists", function()
    local db = addon.ns.db.raidMarkerPanel
    assert.equals(10, db.pullLeft)
    assert.equals(5, db.pullRight)
    assert.equals(1, db.scale)
    assert.is_false(db.locked)
  end)

  it("shows in a party and hides solo", function()
    state.group = true
    addon.fire("GROUP_ROSTER_UPDATE")
    assert.is_true(addon.panel():IsShown())
    state.group = false
    addon.fire("GROUP_ROSTER_UPDATE")
    assert.is_false(addon.panel():IsShown())
  end)

  it("hides in a raid while the rank is secret", function()
    state.group, state.raid, state.leader = true, true, SECRET
    addon.fire("GROUP_ROSTER_UPDATE")
    assert.is_false(addon.panel():IsShown())
  end)

  it("applies a visibility change requested in combat after combat ends", function()
    state.combat = true
    state.group, state.raid = true, true
    addon.fire("GROUP_ROSTER_UPDATE")
    local panel = addon.panel()
    local shows = panel.showCalls
    state.assistant = true
    addon.fire("GROUP_ROSTER_UPDATE")
    assert.is_false(panel:IsShown())
    assert.equals(shows, panel.showCalls)
    state.combat = false
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.is_true(panel:IsShown())
  end)

  it("keeps the module switch when enabled with the switch saved on", function()
    local on = load(state, { raidMarkers = true })
    assert.has_no.errors(function() on.module.Enable() end)
    assert.equals(10, on.ns.db.raidMarkerPanel.pullLeft)
    assert.is_true(on.ns.db.raidMarkers)
  end)

  it("keeps the module switch off when the page is built", function()
    local off = load(state, { raidMarkers = false })
    local group = setmetatable({}, { __index = function() return noop end })
    off.module.Pages({ Group = function() return group end })
    assert.is_false(off.ns.db.raidMarkers)
  end)

  it("hides when switched off", function()
    state.group = true
    addon.fire("GROUP_ROSTER_UPDATE")
    addon.module.OnSwitch(false)
    assert.is_false(addon.panel():IsShown())
  end)
end)
