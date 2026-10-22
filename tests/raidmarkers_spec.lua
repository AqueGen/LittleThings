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
  function f:SetEnabled(v) self.enabled = v end
  function f:IsEnabled() return self.enabled ~= false end
  function f:SetText(t) self.text = t end
  function f:SetTextColor(r, g, b) self.color = { r, g, b } end
  function f:CreateTexture() return new_object(frames) end
  function f:CreateFontString() return new_object(frames) end
  function f:RegisterForClicks(...) self.clicks = { ... } end
  function f:WrapScript(frame, script, preBody) frame.wraps = rawget(frame, "wraps") or {} frame.wraps[script] = preBody end
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
  _G.SecureHandlerSetFrameRef = function(frame, label, ref) frame.attrs["frameref-" .. label] = ref end
  local timers = {}
  _G.C_Timer = {
    NewTicker = function() return { Cancel = noop } end,
    After = function(delay, fn)
      if delay == 0 then fn() else timers[#timers + 1] = fn end
    end,
  }
  _G.C_PartyInfo = {
    DoReadyCheck = function() state.calls[#state.calls + 1] = { "ready" } end,
    DoCountdown = function(n) state.calls[#state.calls + 1] = { "pull", n } end,
  }
  _G.InitiateRolePoll = function() state.calls[#state.calls + 1] = { "role" } end
  _G.C_ChatInfo = { InChatMessagingLockdown = function() return state.lockdown end }
  _G.HasLFGRestrictions = function() return state.lfg end
  _G.GetReadyCheckStatus = function(unit) return state.status and state.status[unit] end
  _G.GetNumGroupMembers = function() return state.members or 1 end
  _G.C_AddOns = { IsAddOnLoaded = function() return state.mrt end }
  _G.ExRT = state.exrt
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

  local function named(name)
    for _, f in ipairs(frames) do
      if f.name == name then return f end
    end
  end

  local function panel()
    return named("LittleThingsRaidMarkers")
  end

  local function button(title)
    for _, f in ipairs(frames) do
      if f.label and f.title == title then return f end
    end
  end

  local function advance()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
  end

  return { module = module, ns = ns, fire = fire, secure = secure, named = named, panel = panel, button = button, advance = advance }
end

describe("RaidMarkers", function()
  local state, addon

  before_each(function()
    state = { combat = false, group = false, raid = false, leader = false, assistant = false, calls = {} }
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

  describe("binding buttons", function()
    local function bindings(a)
      return a.named("LittleThingsWorldMarkerNext"), a.named("LittleThingsWorldMarkerClear")
    end

    it("creates both binding buttons with macro type", function()
      local nextButton, clear = bindings(addon)
      assert.equals("SecureActionButtonTemplate", nextButton.template)
      assert.equals("SecureActionButtonTemplate", clear.template)
      assert.equals("macro", nextButton.attrs.type)
      assert.equals("macro", clear.attrs.type)
      assert.equals("/cwm all", clear.attrs.macrotext)
    end)

    it("next button starts at marker 1", function()
      local nextButton, clear = bindings(addon)
      assert.equals(1, nextButton.attrs["lt-next"])
      assert.is_nil(nextButton.attrs.macrotext)
      assert.matches("lt%-next", nextButton.wraps.OnClick)
      assert.matches("lt%-next", clear.wraps.OnClick)
      assert.equals(nextButton, clear.attrs["frameref-next"])
    end)

    it("acts on key down only, so the wrapped cycle advances once per press", function()
      local nextButton, clear = bindings(addon)
      for _, button in ipairs({ assert(nextButton), assert(clear) }) do
        assert.same({ "AnyDown" }, button.clicks)
        assert.is_true(button.attrs.useOnKeyDown)
      end
    end)

    it("binding buttons go dead when switched off", function()
      local nextButton, clear = bindings(addon)
      addon.module.OnSwitch(false)
      assert.is_nil(nextButton.attrs.type)
      assert.is_nil(clear.attrs.type)
      addon.module.OnSwitch(true)
      assert.equals("macro", nextButton.attrs.type)
      assert.equals("macro", clear.attrs.type)
    end)

    it("defers switching off in combat until combat ends", function()
      local nextButton = bindings(addon)
      state.combat = true
      addon.module.OnSwitch(false)
      assert.equals("macro", nextButton.attrs.type)
      state.combat = false
      addon.fire("PLAYER_REGEN_ENABLED")
      assert.is_nil(nextButton.attrs.type)
    end)
  end)

  describe("group buttons", function()
    local function leading()
      state.group, state.leader = true, true
      addon.fire("GROUP_ROSTER_UPDATE")
    end

    it("pull left starts 10 and right starts 5", function()
      leading()
      local pull = addon.button("Pull countdown")
      pull.scripts.OnClick(pull, "LeftButton")
      pull.scripts.OnClick(pull, "RightButton")
      assert.same({ { "pull", 10 }, { "pull", 5 } }, state.calls)
    end)

    it("pull cancels a running countdown", function()
      leading()
      local pull = addon.button("Pull countdown")
      addon.fire("START_PLAYER_COUNTDOWN", "Someone", 10, 10)
      pull.scripts.OnClick(pull, "LeftButton")
      addon.fire("CANCEL_PLAYER_COUNTDOWN")
      pull.scripts.OnClick(pull, "LeftButton")
      assert.same({ { "pull", 0 }, { "pull", 10 } }, state.calls)
    end)

    it("secret countdown payload does not error", function()
      leading()
      local pull = addon.button("Pull countdown")
      assert.has_no.errors(function() addon.fire("START_PLAYER_COUNTDOWN", SECRET, SECRET, SECRET) end)
      pull.scripts.OnClick(pull, "LeftButton")
      assert.same({ { "pull", 0 } }, state.calls)
    end)

    it("buttons disable in chat lockdown and clicking records no call", function()
      state.lockdown = true
      leading()
      local ready, pull, role = addon.button("Ready check"), addon.button("Pull countdown"), addon.button("Role check")
      assert.is_false(ready:IsEnabled())
      assert.is_false(pull:IsEnabled())
      assert.is_false(role:IsEnabled())
      ready.scripts.OnClick(ready, "LeftButton")
      pull.scripts.OnClick(pull, "LeftButton")
      role.scripts.OnClick(role, "LeftButton")
      assert.same({}, state.calls)
    end)

    it("clicks the ready check and role poll when allowed", function()
      leading()
      local ready, role = addon.button("Ready check"), addon.button("Role check")
      ready.scripts.OnClick(ready, "LeftButton")
      role.scripts.OnClick(role, "LeftButton")
      assert.same({ { "ready" }, { "role" } }, state.calls)
    end)

    it("disables on combat start after the timer tick", function()
      leading()
      state.combat = true
      addon.fire("PLAYER_REGEN_DISABLED")
      assert.is_false(addon.button("Ready check"):IsEnabled())
    end)

    it("ready shows count then green", function()
      leading()
      state.members = 2
      state.status = { player = "waiting", party1 = "ready" }
      addon.fire("READY_CHECK")
      local ready = addon.button("Ready check")
      assert.equals("Ready 1/2", ready.label.text)
      assert.same({ 1, 0.82, 0 }, ready.label.color)
      state.status = { player = "ready", party1 = "ready" }
      addon.fire("READY_CHECK_CONFIRM")
      addon.fire("READY_CHECK_FINISHED")
      assert.equals("Ready 2/2", ready.label.text)
      assert.same({ 0.2, 1, 0.2 }, ready.label.color)
      addon.advance()
      assert.equals("Ready", ready.label.text)
      assert.same({ 1, 1, 1 }, ready.label.color)
    end)

    it("passes a secret ready status to the tally as unknown", function()
      leading()
      state.members = 2
      state.status = { player = "ready", party1 = SECRET }
      addon.fire("READY_CHECK")
      assert.equals("Ready 1/1", addon.button("Ready check").label.text)
    end)

    it("counts raid units without adding the player twice", function()
      state.raid = true
      leading()
      state.members = 2
      state.status = { raid1 = "ready", raid2 = "notready", player = "ready" }
      addon.fire("READY_CHECK")
      assert.equals("Ready 1/2", addon.button("Ready check").label.text)
    end)

    it("hides RC without MRT and calls Raid Check with it", function()
      assert.is_nil(addon.button("MRT Raid Check"))
      local args
      local raidCheck = { ReadyCheckWindow = function(...) args = { ... } end }
      state.mrt, state.exrt = true, { A = { RaidCheck = raidCheck } }
      local mrt = load(state)
      mrt.module.Enable()
      local rc = mrt.button("MRT Raid Check")
      rc.scripts.OnClick(rc, "LeftButton")
      assert.same({ raidCheck, nil, nil, true }, args)
    end)
  end)
end)
