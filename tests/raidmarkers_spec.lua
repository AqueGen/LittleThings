-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

local function touched() error("secret value touched", 2) end
local function opaque()
  return setmetatable({}, { __lt = touched, __le = touched, __eq = touched, __add = touched, __sub = touched, __mul = touched,
    __div = touched, __unm = touched, __concat = touched, __tostring = touched, __len = touched })
end
local MANA, MANA_MAX, MANA_PCT, MANA_SHORT = opaque(), opaque(), opaque(), opaque()

local function noop() end

local function set(list)
  local s = {}
  for _, v in ipairs(list) do s[v] = true end
  return s
end

local RESIZING_PROTECTED = {
  "ClearAllPoints", "ClearPoint", "SetAllPoints", "SetPoint", "SetSize", "SetWidth", "SetHeight", "AdjustPointsOffset",
  "SetPointsOffset", "ClearPointsOffset",
}
local SCRIPT_REGION_PROTECTED = {
  "EnableMouse", "EnableMouseMotion", "EnableMouseWheel", "SetParent", "SetMouseClickEnabled", "SetMouseMotionEnabled",
  "SetPassThroughButtons", "SetPropagateMouseClicks", "SetPropagateMouseMotion", "SetCollapsesLayout",
  "SetRoundLayoutToNearestPixel",
}
local FRAME_ONLY_PROTECTED = {
  "Show", "Hide", "SetShown", "Raise", "Lower", "SetScale", "SetFrameStrata", "SetFrameLevel", "SetFixedFrameStrata",
  "SetFixedFrameLevel", "SetUsingParentLevel", "SetClampedToScreen", "SetClampRectInsets", "SetHitRectInsets", "SetToplevel",
  "StartMoving", "StartSizing", "StopMovingOrSizing", "ClearAttribute", "ClearAttributes", "EnableKeyboard",
  "EnableGamePadButton", "EnableGamePadStick", "SetHyperlinksEnabled", "SetID", "SetIgnoreParentScale", "ResizeToBoundsRect",
  "AddRoleset", "RemoveRoleset", "SetRolesets",
}
local BUTTON_ONLY_PROTECTED = { "Enable", "Disable", "SetEnabled", "RegisterForClicks", "RegisterForMouse" }

local function concat(...)
  local out = {}
  for _, list in ipairs({ ... }) do
    for _, v in ipairs(list) do out[#out + 1] = v end
  end
  return out
end

local PROTECTED = {
  Frame = set(concat(RESIZING_PROTECTED, SCRIPT_REGION_PROTECTED, FRAME_ONLY_PROTECTED)),
  Button = set(concat(RESIZING_PROTECTED, SCRIPT_REGION_PROTECTED, FRAME_ONLY_PROTECTED, BUTTON_ONLY_PROTECTED)),
  Texture = set(concat(RESIZING_PROTECTED, SCRIPT_REGION_PROTECTED, { "SetScale", "SetIgnoreParentScale" })),
}
PROTECTED.FontString = PROTECTED.Texture
PROTECTED.MaskTexture = PROTECTED.Texture
PROTECTED.StatusBar = PROTECTED.Frame

local ALLOWED = {
  Frame = { "SetScript", "RegisterEvent", "Show", "Hide", "IsShown", "SetPoint", "ClearAllPoints", "SetSize", "SetScale",
    "SetFrameStrata", "SetClampedToScreen", "SetDontSavePosition", "SetMovable", "EnableMouse", "RegisterForDrag",
    "CreateTexture", "CreateMaskTexture", "CreateFontString", "StartMoving", "StopMovingOrSizing", "GetLeft", "GetBottom", "GetRight", "GetTop", "GetWidth", "GetHeight",
    "GetEffectiveScale", "WrapScript", "SetAllPoints", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" },
  Button = { "SetScript", "SetSize", "SetPoint", "ClearAllPoints", "CreateTexture", "CreateMaskTexture", "CreateFontString", "SetHighlightTexture",
    "RegisterForClicks", "SetAttribute", "GetAttribute", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" },
  Texture = { "SetAllPoints", "SetPoint", "SetSize", "SetColorTexture", "SetTexture", "SetVertexColor", "SetAtlas", "AddMaskTexture",
    "SetBlendMode", "Hide", "SetShown" },
  MaskTexture = { "SetTexture", "SetAllPoints" },
  FontString = { "SetPoint", "ClearAllPoints", "SetText", "SetFormattedText", "SetTextColor", "GetStringWidth", "SetAlpha", "SetShown" },
  StatusBar = { "SetScript", "SetPoint", "ClearAllPoints", "SetSize", "SetShown", "SetAlpha", "EnableMouse", "SetMouseClickEnabled", "CreateTexture",
    "CreateFontString",
    "SetStatusBarTexture", "SetStatusBarColor", "SetMinMaxValues", "SetValue" },
}

local MOVER = "LittleThingsRaidMarkersMover"

local FILES = {}
for line in io.lines("LittleThings.toc") do
  local path = line:match("^(Modules/RaidMarkers/%S+%.lua)")
  if path then FILES[#FILES + 1] = path end
end

describe("RaidMarkers files", function()
  it("each file in the TOC compiles under Lua 5.1, so none passes the 60-upvalue limit", function()
    assert.equals("Modules/RaidMarkers/RaidMarkers.lua", FILES[#FILES])
    for _, path in ipairs(FILES) do
      local chunk, err = loadfile(path)
      assert(chunk, path .. ": " .. tostring(err))
    end
  end)
end)

local function handle(f, bindings)
  local h = {}
  function h:GetAttribute(k) return f.attrs[k] end
  function h:SetAttribute(k, v)
    f.attrs[k] = v
    if f.scripts.OnAttributeChanged then f.scripts.OnAttributeChanged(f, k, v) end
  end
  function h:GetFrameRef(label) return handle(assert(f.attrs["frameref-" .. label]), bindings) end
  function h:SetBindingClick(priority, key, name, button) bindings[key] = { priority, name, button } end
  function h:ClearBindings() for key in pairs(bindings) do bindings[key] = nil end end
  function h:GetName() return f.name end
  return h
end

local SIGNATURES = { OnClick = "self, button, down", OnHide = "self" }

local function wrapped(f, script, bindings, ...)
  local body = assert(f.wraps and f.wraps[script], "no " .. script .. " wrap")
  local fn = assert(loadstring("local " .. SIGNATURES[script] .. " = ...\n" .. body))
  setfenv(fn, {})
  return fn(handle(f, bindings), ...)
end

local function snippet(f, bindings, button, down)
  return wrapped(f, "OnClick", bindings, button, down)
end

local function within(f, ancestor)
  while f do
    if f == ancestor then return true end
    f = rawget(f, "parent")
  end
  return false
end

local IMPL = {}
function IMPL:SetAttribute(k, v)
  self.attrs[k] = v
  if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, k, v) end
end
function IMPL:GetAttribute(k) return self.attrs[k] end
function IMPL:SetScript(script, fn) self.scripts[script] = fn end
function IMPL:RegisterEvent(event) self.events[event] = true end
function IMPL:Show() self.shown = true self.showCalls = self.showCalls + 1 end
function IMPL:Hide()
  if not self.shown then return end
  self.shown = false
  for _, f in ipairs(self.frames) do
    if rawget(f, "wraps") and f.wraps.OnHide and within(f, self) then
      wrapped(f, "OnHide", self.frames.state.bindings or {})
    end
  end
end
function IMPL:IsShown() return self.shown end
function IMPL:SetShown(v) self.shown = v and true or false end
function IMPL:SetPoint(...)
  self.setPoints = (rawget(self, "setPoints") or 0) + 1
  self.lastPoint = { ... }
  self.points[#self.points + 1] = { ... }
end
function IMPL:SetSize(w, h) self.width, self.height = w, h end
function IMPL:SetScale(s) self.scale = s end
function IMPL:SetFrameStrata(strata) self.strata = strata end
function IMPL:SetAllPoints(relativeTo) self.allPoints = relativeTo end
function IMPL:GetLeft() return self.left or 0 end
function IMPL:GetBottom() return self.bottom or 0 end
function IMPL:GetWidth() return self.width or 0 end
function IMPL:GetHeight() return self.height or 0 end
function IMPL:GetEffectiveScale() return (self.scale or 1) * _G.UIParent:GetEffectiveScale() end
function IMPL:SetText(t) self.text, self.formatted = t, nil end
function IMPL:SetTextColor(r, g, b) self.color = { r, g, b } end
function IMPL:RegisterForClicks(...) self.clicks = { ... } end
function IMPL:SetBackdrop(backdrop) self.backdrop = backdrop end
function IMPL:SetBackdropColor(...) self.bg = { ... } end
function IMPL:SetBackdropBorderColor(...) self.border = { ... } end
function IMPL:SetColorTexture(...) self.colorTexture = { ... } end
function IMPL:SetTexture(texture, horizontal, vertical) self.texture, self.wrap = texture, { horizontal, vertical } end
function IMPL:SetVertexColor(...) self.vertexColor = { ... } end
function IMPL:SetAtlas(atlas) self.atlas = atlas end
function IMPL:AddMaskTexture(mask) self.masks = rawget(self, "masks") or {} self.masks[#self.masks + 1] = mask end
function IMPL:SetAlpha(alpha) self.alpha = alpha end
function IMPL:SetStatusBarTexture(texture) self.barTexture = texture end
function IMPL:SetStatusBarColor(...) self.barColor = { ... } end
function IMPL:SetMinMaxValues(low, high) self.minMax = { low, high } end
function IMPL:SetValue(value) self.value = value end
function IMPL:SetFormattedText(...) self.text, self.formatted = nil, { ... } end
function IMPL:GetRight() return self.right or 0 end
function IMPL:GetTop() return self.top or 0 end
function IMPL:GetStringWidth()
  local state = self.frames.state
  return state.textWidths and state.textWidths[self.text] or state.textWidth or 0
end
function IMPL:WrapScript(frame, script, preBody) frame.wraps = rawget(frame, "wraps") or {} frame.wraps[script] = preBody end

local new_object

function IMPL:CreateTexture() return new_object(self.frames, "Texture", nil, nil, self) end
function IMPL:CreateFontString() return new_object(self.frames, "FontString", nil, nil, self) end
function IMPL:CreateMaskTexture() return new_object(self.frames, "MaskTexture", nil, nil, self) end

new_object = function(frames, kind, name, template, parent)
  local f = { frames = frames, kind = kind, name = name, template = template, parent = parent, attrs = {}, scripts = {},
    events = {}, points = {}, shown = true, showCalls = 0, calls = {} }
  local protected = PROTECTED[kind]
  local secure = template and template:find("Secure")
  local exempt = name == MOVER
  for _, method in ipairs(assert(ALLOWED[kind], kind)) do
    local impl = IMPL[method] or noop
    local recorded = protected[method] or (secure and method == "SetAttribute")
    f[method] = function(self, ...)
      self.calls[method] = (self.calls[method] or 0) + 1
      if recorded and not exempt and frames.state.combat then frames.blocked[#frames.blocked + 1] = method end
      return impl(self, ...)
    end
  end
  frames[#frames + 1] = f
  return setmetatable(f, { __index = function(_, k)
    if type(k) == "string" and k:match("^%u") then error(kind .. ":" .. k .. " is not on the fake allowlist", 2) end
  end })
end

local function load(state, db)
  local module
  local frames = { state = state, blocked = {} }
  local ns = {
    db = db or {},
    Widgets = { FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 } },
    IconButtons = { ROLE_ATLAS = { HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder" } },
    RegisterModule = function(_, m) module = m end,
    IsOn = function() return not state.off end,
    ApplyDefaults = function(target, defaults)
      for k, v in pairs(defaults) do
        if target[k] == nil then target[k] = v end
      end
    end,
  }
  _G.UIParent = { GetEffectiveScale = function() return 0.8 end, GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
  _G.CreateFrame = function(kind, name, parent, template) return new_object(frames, kind, name, template, parent) end
  _G.InCombatLockdown = function() return state.combat end
  _G.IsInGroup = function() return state.group end
  _G.IsInRaid = function() return state.raid end
  _G.UnitIsGroupLeader = function() return state.leader end
  _G.UnitIsGroupAssistant = function() return state.assistant end
  _G.issecretvalue = function(v)
    for _, secret in ipairs({ SECRET, MANA, MANA_MAX, MANA_PCT, MANA_SHORT }) do
      if rawequal(v, secret) then return true end
    end
    return false
  end
  _G.GetRaidTargetIndex = function() return state.targetIndex end
  _G.IsRaidMarkerActive = function(i) return state.placed and state.placed[i] or false end
  _G.SetRaidTargetIconTexture = noop
  _G.SecureHandlerSetFrameRef = function(frame, label, ref) frame.attrs["frameref-" .. label] = ref end
  state.clearedBindings = {}
  _G.ClearOverrideBindings = function(owner)
    if state.combat then frames.blocked[#frames.blocked + 1] = "ClearOverrideBindings" end
    state.clearedBindings[#state.clearedBindings + 1] = owner
  end
  state.drivers = {}
  local function driver(...)
    if state.combat then frames.blocked[#frames.blocked + 1] = (...) end
    state.drivers[#state.drivers + 1] = { ... }
  end
  _G.RegisterStateDriver = function(...) driver("register", ...) end
  _G.UnregisterStateDriver = function(...) driver("unregister", ...) end
  local timers, tickers = {}, {}
  _G.C_Timer = {
    NewTicker = function(_, fn)
      local t = { Cancel = noop, fn = fn }
      tickers[#tickers + 1] = t
      return t
    end,
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
  _G.Enum = { PowerType = { Mana = 0 }, LuaCurveType = { Linear = 0, Step = 1 } }
  local function party(field, unit, default)
    local values = state[field]
    if values and values[unit] ~= nil then return values[unit] end
    return default
  end
  _G.UnitGroupRolesAssigned = function(unit) return party("roles", unit, "NONE") end
  _G.UnitExists = function(unit) return party("present", unit, false) end
  _G.UnitIsDeadOrGhost = function(unit) return party("dead", unit, false) end
  _G.UnitIsConnected = function(unit) return party("connected", unit, true) end
  _G.UnitName = function(unit) return party("names", unit, nil) end
  _G.UnitClass = function(unit) return "Class", party("classes", unit, nil), 1 end
  _G.C_ClassColor = { GetClassColor = function(classFile)
    if classFile ~= "PRIEST" and classFile ~= "DRUID" then return nil end
    return { WrapTextInColorCode = function(_, text) return "|c" .. classFile .. text .. "|r" end }
  end }
  _G.UnitPower = function(unit, kind)
    assert(kind == 0, "mana only")
    return party("power", unit, 0)
  end
  _G.UnitPowerMax = function(unit, kind)
    assert(kind == 0, "mana only")
    return party("powerMax", unit, 0)
  end
  state.curves = {}
  _G.C_CurveUtil = {
    CreateCurve = function()
      local curve = { points = {} }
      function curve:SetType(kind) self.kind = kind end
      function curve:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
      state.curves[#state.curves + 1] = curve
      return curve
    end,
  }
  _G.UnitPowerPercent = function(unit, kind, unmodified, curve)
    assert(kind == 0 and unmodified == false, "mana, modified")
    assert(curve == state.curves[1], "the module's curve")
    return party("percent", unit, 0)
  end
  _G.AbbreviateNumbers = function(value)
    if rawequal(value, MANA) then return MANA_SHORT end
    return "short " .. value
  end
  state.tip = {}
  _G.GameTooltip = setmetatable({}, { __index = function(_, method)
    return function(_, ...) state.tip[#state.tip + 1] = { method, ... } end
  end })
  for _, path in ipairs(FILES) do
    assert(loadfile(path))("LittleThings", ns)
  end

  local function fire(event, ...)
    for _, f in ipairs(frames) do
      if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
  end

  local function secure(match)
    local found = {}
    for _, f in ipairs(frames) do
      if f.template and f.template:find("SecureActionButtonTemplate", 1, true) and match(f.attrs, f) then found[#found + 1] = f end
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

  local function tick()
    tickers[#tickers].fn()
  end

  local function eventFrame()
    for _, f in ipairs(frames) do
      if next(f.events) then return f end
    end
  end

  local function children(parent)
    local found = {}
    for _, f in ipairs(frames) do
      if f.parent == parent then found[#found + 1] = f end
    end
    return found
  end

  local function groupButtons()
    local found = {}
    for _, f in ipairs(frames) do
      if rawget(f, "action") then found[#found + 1] = f end
    end
    return found
  end

  local function all()
    local copy = {}
    for i, f in ipairs(frames) do copy[i] = f end
    return copy
  end

  return { module = module, ns = ns, fire = fire, secure = secure, named = named, panel = panel, button = button, advance = advance, all = all,
    groupButtons = groupButtons, blocked = frames.blocked, tick = tick, eventFrame = eventFrame, children = children,
    mover = function() return named("LittleThingsRaidMarkersMover") end,
    manaBar = function()
      for _, f in ipairs(frames) do
        if f.kind == "StatusBar" then return f end
      end
    end,
    manaIcon = function()
      for _, f in ipairs(frames) do
        if f.kind == "Texture" and f.parent and f.parent.kind == "StatusBar" and rawget(f, "atlas") then return f end
      end
    end,
    manaText = function()
      for _, f in ipairs(frames) do
        if f.kind == "FontString" and f.parent and f.parent.kind == "StatusBar" then return f end
      end
    end,
    downText = function()
      for _, f in ipairs(frames) do
        if f.kind == "FontString" and f.parent == panel() then return f end
      end
    end }
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
    local clear = addon.secure(function(a, f) return rawget(f, "name") == nil and a.type == "worldmarker" and a.action == "clear" and a.marker == nil end)
    assert.equals(1, #clear)
  end)

  local function target(i)
    return addon.secure(function(a) return a.type == "raidtarget" and a.marker == i end)[1]
  end

  it("moves the target highlight to the new target", function()
    state.targetIndex = 2
    addon.fire("PLAYER_TARGET_CHANGED")
    assert.same({ 1, 0.82, 0, 1 }, target(2).border)
    state.targetIndex = 5
    addon.fire("PLAYER_TARGET_CHANGED")
    assert.same({ 0.4, 0.4, 0.4, 1 }, target(2).border)
    assert.same({ 1, 0.82, 0, 1 }, target(5).border)
  end)

  it("hides every target highlight when the target index is secret", function()
    state.targetIndex = 3
    addon.fire("PLAYER_TARGET_CHANGED")
    state.targetIndex = SECRET
    addon.fire("PLAYER_TARGET_CHANGED")
    for i = 1, 8 do
      assert.same({ 0.4, 0.4, 0.4, 1 }, target(i).border)
    end
  end)

  local function pages(a)
    local specs, titles = {}, {}
    local group = {
      Check = function(_, spec) specs[#specs + 1] = spec end,
      Slider = function(_, spec) specs[#specs + 1] = spec end,
      Button = function(_, spec) specs[#specs + 1] = spec end,
      Dropdown = function(_, spec) specs[#specs + 1] = spec end,
    }
    local frame = { scripts = {} }
    function frame:HookScript(script, fn) self.scripts[script] = fn end
    a.module.Pages({ Group = function(_, title) titles[#titles + 1] = title return group end, frame = frame })
    local byLabel = {}
    for _, spec in ipairs(specs) do byLabel[spec.label] = spec end
    return specs, byLabel, frame, titles
  end

  local VISIBILITY = {
    { "showSolo", "Show when solo", "Shows the panel outside a group too. Markers and group buttons do nothing there." },
    { "partyLeaderOnly", "In a party, only as leader", "In a party the panel shows only while you lead the group." },
    { "raidWithoutRank", "In a raid, also without lead or assist", "In a raid the panel shows to everyone; markers and group buttons work only with lead or assist." },
    { "hideInCombat", "Hide in combat", "Hides the panel while you are in combat. The game hides it, so this is safe in combat." },
  }

  it("puts the visibility options in their own group first, all off by default", function()
    local specs, byLabel, _, titles = pages(addon)
    assert.same({ "Visibility", "Raid marker panel", "Tank helpers", "Placement order" }, titles)
    for i, option in ipairs(VISIBILITY) do
      local spec = byLabel[option[2]]
      assert.equals(specs[i], spec)
      assert.equals(option[3], spec.tooltip)
      assert.is_false(spec.default)
      assert.is_false(addon.ns.db.raidMarkerPanel[option[1]])
      assert.is_false(spec.get())
    end
    assert.is_true(byLabel["Hide in combat"].combatLocked)
  end)

  it("applies the visibility options live", function()
    local _, specs = pages(addon)
    local panel = addon.panel()
    specs["Show when solo"].set(true)
    assert.is_true(panel:IsShown())
    specs["Show when solo"].set(false)
    assert.is_false(panel:IsShown())

    state.group = true
    addon.fire("GROUP_ROSTER_UPDATE")
    assert.is_true(panel:IsShown())
    specs["In a party, only as leader"].set(true)
    assert.is_false(panel:IsShown())
    state.leader = true
    addon.fire("PARTY_LEADER_CHANGED")
    assert.is_true(panel:IsShown())

    state.raid, state.leader = true, false
    addon.fire("GROUP_ROSTER_UPDATE")
    assert.is_false(panel:IsShown())
    state.combat = true
    specs["In a raid, also without lead or assist"].set(true)
    assert.is_false(panel:IsShown())
    state.combat = false
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.is_true(panel:IsShown())
  end)

  it("puts the panel in a container filling UIParent and keeps the mover outside it", function()
    local panel, mover = addon.panel(), addon.mover()
    local container = panel.parent
    assert.equals("Frame", container.kind)
    assert.equals(_G.UIParent, container.parent)
    assert.is_nil(container.template)
    assert.equals(1, container.calls.SetAllPoints)
    assert.equals(_G.UIParent, container.allPoints)
    assert.equals(_G.UIParent, mover.parent)
    assert.equals(_G.UIParent, panel.lastPoint[2])
  end)

  it("hides in combat through a state driver on the container", function()
    local _, specs = pages(addon)
    local container = addon.panel().parent
    local shows = container.showCalls
    specs["Hide in combat"].set(true)
    assert.same({ "register", container, "visibility", "[combat] hide; show" }, state.drivers[#state.drivers])
    specs["Hide in combat"].set(false)
    assert.same({ "unregister", container, "visibility" }, state.drivers[#state.drivers])
    assert.equals(shows + 1, container.showCalls)
    assert.is_true(container:IsShown())
  end)

  it("applies hide in combat toggled in combat after combat", function()
    local _, specs = pages(addon)
    local container = addon.panel().parent
    local count = #state.drivers
    state.combat = true
    specs["Hide in combat"].set(true)
    assert.equals(count, #state.drivers)
    assert.same({}, addon.blocked)
    state.combat = false
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.same({ "register", container, "visibility", "[combat] hide; show" }, state.drivers[#state.drivers])
  end)

  it("registers the saved hide in combat option when the panel is built", function()
    local on = load(state, { raidMarkerPanel = { hideInCombat = true } })
    on.module.Enable()
    assert.same({ "register", on.panel().parent, "visibility", "[combat] hide; show" }, state.drivers[#state.drivers])
  end)

  it("creates the container only out of combat", function()
    state.combat = true
    local late = load(state)
    late.module.Enable()
    assert.same({}, late.children(_G.UIParent))
    assert.same({}, state.drivers)
    state.combat = false
    late.fire("PLAYER_REGEN_ENABLED")
    assert.equals(_G.UIParent, late.panel().parent.parent)
  end)

  it("shows the panel solo while its settings page is open", function()
    local _, _, page = pages(addon)
    local panel = addon.panel()
    assert.is_false(panel:IsShown())
    page.scripts.OnShow(page)
    assert.is_true(panel:IsShown())
    page.scripts.OnHide(page)
    assert.is_false(panel:IsShown())
  end)

  it("raises the panel and the mover above the settings window while previewing", function()
    local _, _, page = pages(addon)
    local panel, mover = addon.panel(), addon.mover()
    assert.same({ "MEDIUM", "DIALOG" }, { panel.strata, mover.strata })
    page.scripts.OnShow(page)
    assert.same({ "FULLSCREEN_DIALOG", "TOOLTIP" }, { panel.strata, mover.strata })
    page.scripts.OnHide(page)
    assert.same({ "MEDIUM", "DIALOG" }, { panel.strata, mover.strata })
  end)

  it("restores the strata after combat when the preview ends in combat", function()
    local _, _, page = pages(addon)
    local panel, mover = addon.panel(), addon.mover()
    page.scripts.OnShow(page)
    state.combat = true
    page.scripts.OnHide(page)
    assert.same({}, addon.blocked)
    assert.same({ "FULLSCREEN_DIALOG", "TOOLTIP" }, { panel.strata, mover.strata })
    state.combat = false
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.same({ "MEDIUM", "DIALOG" }, { panel.strata, mover.strata })
  end)

  it("applies a preview change made in combat after combat", function()
    local _, _, page = pages(addon)
    local panel = addon.panel()
    state.combat = true
    page.scripts.OnShow(page)
    assert.is_false(panel:IsShown())
    state.combat = false
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.is_true(panel:IsShown())
    state.combat = true
    page.scripts.OnHide(page)
    assert.is_true(panel:IsShown())
    state.combat = false
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.is_false(panel:IsShown())
  end)

  local function startDrag(panel)
    panel.scale, panel.left, panel.bottom, panel.width, panel.height = 2, 100, 50, 300, 60
    addon.ns.db.raidMarkerPanel.scale = 2
    panel.scripts.OnDragStart(panel)
  end

  local GOLD, BORDER = { 1, 0.82, 0, 1 }, { 0.4, 0.4, 0.4, 1 }
  local WORLD = {
    { 4, 149, 255 }, { 15, 155, 12 }, { 168, 14, 192 }, { 167, 20, 13 },
    { 222, 218, 50 }, { 208, 84, 0 }, { 116, 155, 179 }, { 243, 241, 235 },
  }

  local function world(i)
    return addon.secure(function(a) return a.type == "worldmarker" and a.marker == i end)[1]
  end

  local function dot(button)
    for _, child in ipairs(addon.children(button)) do
      if rawget(child, "masks") then return child end
    end
  end

  local function round(texture)
    assert.equals(1, #texture.masks)
    local mask = texture.masks[1]
    assert.equals("MaskTexture", mask.kind)
    assert.equals(texture.parent, mask.parent)
    assert.equals("Interface\\CharacterFrame\\TempPortraitAlphaMask", mask.texture)
    assert.same({ "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE" }, mask.wrap)
    assert.equals(texture, mask.allPoints)
  end

  local function panelButtons(a)
    local found = {}
    for _, holder in ipairs(a.children(a.panel())) do
      for _, child in ipairs(a.children(holder)) do
        if child.kind == "Button" then found[#found + 1] = child end
      end
    end
    return found
  end

  it("draws world markers as round full-colour 16 px dots", function()
    for i, color in ipairs(WORLD) do
      local d = assert(dot(world(i)))
      round(d)
      assert.same({ 16, 16 }, { d.width, d.height })
      assert.equals("Interface\\Buttons\\WHITE8x8", d.texture)
      assert.same({ color[1] / 255, color[2] / 255, color[3] / 255, 1 }, d.vertexColor)
    end
  end)

  it("rings placed world markers in gold and never dims them", function()
    state.placed = { [2] = true, [5] = SECRET }
    local panel = addon.panel()
    panel.scripts.OnShow(panel)
    assert.same(GOLD, world(2).border)
    assert.same(BORDER, world(1).border)
    state.placed = { [1] = true }
    addon.tick()
    assert.same(GOLD, world(1).border)
    assert.same(BORDER, world(2).border)
  end)

  it("gives the panel and every button a thin border", function()
    local panel = addon.panel()
    local flat = addon.ns.Widgets.FLAT
    assert.equals("BackdropTemplate", panel.template)
    assert.equals(flat, panel.backdrop)
    assert.same({ 0, 0, 0, 0.6 }, panel.bg)
    assert.same({ 0.3, 0.3, 0.3, 1 }, panel.border)
    local buttons = panelButtons(addon)
    assert.equals(22, #buttons)
    for _, button in ipairs(buttons) do
      assert.equals(flat, button.backdrop)
      assert.same({ 0, 0, 0, 0.5 }, button.bg)
      assert.same(BORDER, button.border)
      assert.truthy(button.template == "BackdropTemplate" or button.template == "SecureActionButtonTemplate,BackdropTemplate")
    end
    assert.equals(19, #addon.secure(function(_, f) return f.template == "SecureActionButtonTemplate,BackdropTemplate" end))
  end)

  it("shows the world clear as an icon and names every marker in its tooltip", function()
    local clearWorld = addon.secure(function(a, f) return rawget(f, "name") == nil and a.type == "worldmarker" and a.action == "clear" end)[1]
    local clearTarget = addon.secure(function(a) return a.type == "raidtarget" and a.action == "clear-all" end)[1]
    local icon
    for _, child in ipairs(addon.children(clearWorld)) do
      if rawget(child, "atlas") then icon = child end
      assert.is_nil(rawget(child, "text"))
    end
    assert.equals("common-icon-redx", icon.atlas)
    assert.equals("Clear all world markers", clearWorld.title)
    assert.equals("Clear all", clearTarget.label.text)
    assert.equals("Clear all target markers", clearTarget.title)
    assert.equals("Target marker 2: left click set, right click clear", target(2).title)
    assert.equals("World marker 3: left click set, right click clear", world(3).title)
    clearWorld.scripts.OnEnter(clearWorld)
    target(1).scripts.OnEnter(target(1))
  end)

  it("uses the game's marker names when they exist", function()
    _G.RAID_TARGET_1, _G.WORLD_MARKER1 = "Star", "Blue Square"
    local named = load(state)
    named.module.Enable()
    _G.RAID_TARGET_1, _G.WORLD_MARKER1 = nil, nil
    local star = named.secure(function(a) return a.type == "raidtarget" and a.marker == 1 end)[1]
    local blue = named.secure(function(a) return a.type == "worldmarker" and a.marker == 1 end)[1]
    assert.equals("Star: left click set, right click clear", star.title)
    assert.equals("Blue Square: left click set, right click clear", blue.title)
  end)

  local function cells(a)
    return a.button("Ready check"), a.button("Pull countdown"), a.button("Role check")
  end

  local function offsets(button)
    return { button.lastPoint[4], button.lastPoint[5] }
  end

  it("lays the group buttons out as a block right of both rows, Role spanning the bottom", function()
    local panel = addon.panel()
    local ready, pull, role = cells(addon)
    local block = ready.parent
    local row1 = target(1).parent
    local row2 = world(1).parent
    assert.same({ "TOPLEFT", row1, "TOPRIGHT", 2, 0 }, block.lastPoint)
    assert.same({ "TOPLEFT", row1, "BOTTOMLEFT", 0, -2 }, row2.lastPoint)
    assert.same({ 284, 26 }, { row1.width, row1.height })
    assert.same({ 284, 26 }, { row2.width, row2.height })
    for _, button in ipairs({ ready, pull, role }) do
      assert.equals(block, button.lastPoint[2])
    end
    assert.same({ 64, 26 }, { ready.width, ready.height })
    assert.same({ 64, 26 }, { pull.width, pull.height })
    assert.same({ 130, 26 }, { role.width, role.height })
    assert.same({ 0, 0 }, offsets(ready))
    assert.same({ 66, 0 }, offsets(pull))
    assert.same({ 0, -28 }, offsets(role))
    assert.same({ 130, 54 }, { block.width, block.height })
    assert.same({ 284 + 2 + 130 + 8, 54 + 8 }, { panel.width, panel.height })
  end)

  local function clears(a)
    return a.secure(function(attrs) return attrs.type == "raidtarget" and attrs.action == "clear-all" end)[1],
      a.secure(function(attrs, f) return rawget(f, "name") == nil and attrs.type == "worldmarker" and attrs.action == "clear" end)[1]
  end

  local function placed(button, parent, x, y, width)
    assert.same({ "TOPLEFT", parent, "TOPLEFT", x, y }, button.lastPoint)
    assert.same({ width, 26 }, { button.width, button.height })
  end

  it("puts the mode button between the world dots and the world clear, both rows the same width", function()
    local clearTarget, clearWorld = clears(addon)
    local mode = addon.named("LittleThingsWorldMarkerMode")
    local row1, row2 = target(1).parent, world(1).parent
    assert.equals(row2, mode.parent)
    for i = 1, 8 do
      placed(target(i), row1, (i - 1) * 28, 0, 26)
      placed(world(i), row2, (i - 1) * 28, 0, 26)
    end
    placed(clearTarget, row1, 224, 0, 60)
    placed(mode, row2, 224, 0, 32)
    placed(clearWorld, row2, 258, 0, 26)
  end)

  local ORDER = { 8, 4, 1, 7, 2, 3, 6, 5 }

  local function column(a, width, inset)
    local clearTarget, clearWorld = clears(a)
    local mode = a.named("LittleThingsWorldMarkerMode")
    local function find(kind, i)
      return a.secure(function(attrs) return attrs.type == kind and attrs.marker == i end)[1]
    end
    local row1, row2 = find("raidtarget", 1).parent, find("worldmarker", 1).parent
    for t = 1, 8 do
      placed(find("raidtarget", t), row1, inset, -(t - 1) * 28, 26)
      placed(find("worldmarker", ORDER[9 - t]), row2, inset + 28, -(t - 1) * 28, 26)
    end
    placed(clearTarget, row1, 0, -224, width - 28)
    placed(clearWorld, row2, width - 26, -224, 26)
    placed(mode, row2, 0, -252, width)
    assert.same({ width, 278 }, { row1.width, row1.height })
    assert.same({ width, 278 }, { row2.width, row2.height })
    assert.same({ "TOPLEFT", row1, "TOPLEFT", 0, 0 }, row2.lastPoint)
    local ready, pull, role = cells(a)
    local block = ready.parent
    placed(ready, block, 0, 0, width)
    placed(pull, block, 0, -28, width)
    placed(role, block, 0, -56, width)
    assert.same({ width, 82 }, { block.width, block.height })
    assert.same({ "TOPLEFT", row1, "BOTTOMLEFT", 0, -2 }, block.lastPoint)
    local panel = a.panel()
    assert.same({ width + 8, 278 + 2 + 82 + 8 }, { panel.width, panel.height })
  end

  it("pairs each target marker with the world marker of the same symbol in one centred column", function()
    local _, specs = pages(addon)
    specs["Vertical"].set(true)
    column(addon, 64, 5)
    specs["Vertical"].set(false)
    local clearTarget = clears(addon)
    placed(clearTarget, target(1).parent, 224, 0, 60)
    assert.same({ 284, 26 }, { target(1).parent.width, target(1).parent.height })
  end)

  it("widens the column to the measured ready cell", function()
    state.textWidths = { ["Ready 20/20"] = 70.2 }
    local wide = load(state, { raidMarkerPanel = { vertical = true } })
    wide.module.Enable()
    column(wide, 79, 12)
  end)

  it("widens the column so the measured Clear all text fits next to the world clear icon", function()
    state.textWidths = { ["Clear all"] = 50 }
    local wide = load(state, { raidMarkerPanel = { vertical = true } })
    wide.module.Enable()
    column(wide, 86, 16)
    local _, specs = pages(wide)
    specs["Vertical"].set(false)
    local clearTarget = clears(wide)
    assert.same({ 60, 26 }, { clearTarget.width, clearTarget.height })
  end)

  it("widens the block cells when the ready label needs more than 64 px", function()
    state.textWidth = 70.2
    local wide = load(state)
    wide.module.Enable()
    local ready, pull, role = cells(wide)
    assert.same({ 79, 26 }, { ready.width, ready.height })
    assert.same({ 81, 0 }, offsets(pull))
    assert.same({ 160, 26 }, { role.width, role.height })
    assert.equals("Ready", ready.label.text)
    assert.same({ 284 + 2 + 160 + 8, 54 + 8 }, { wide.panel().width, wide.panel().height })
  end)

  it("anchors every tooltip beside the panel on the side with more room", function()
    local panel = addon.panel()
    local ready = cells(addon)
    local clearTarget, clearWorld = clears(addon)
    local buttons = { target(1), world(2), clearTarget, clearWorld, addon.named("LittleThingsWorldMarkerMode"), ready }
    local function tipAt(edges, scale)
      panel.left, panel.bottom, panel.right, panel.top = unpack(edges)
      panel.scale = scale
      local points = {}
      for _, button in ipairs(buttons) do
        for i = #state.tip, 1, -1 do state.tip[i] = nil end
        button.scripts.OnEnter(button)
        assert.same({ "SetOwner", panel, "ANCHOR_NONE" }, state.tip[1])
        assert.same({ "ClearAllPoints" }, state.tip[2])
        points[#points + 1] = state.tip[3]
      end
      for _, point in ipairs(points) do assert.same(points[1], point) end
      return points[1]
    end
    assert.same({ "SetPoint", "TOPLEFT", panel, "BOTTOMLEFT", 0, -4 }, tipAt({ 100, 900, 500, 960 }, 1))
    assert.same({ "SetPoint", "BOTTOMLEFT", panel, "TOPLEFT", 0, 4 }, tipAt({ 100, 50, 500, 110 }, 1))
    local _, specs = pages(addon)
    specs["Vertical"].set(true)
    assert.same({ "SetPoint", "TOPRIGHT", panel, "TOPLEFT", -4, 0 }, tipAt({ 1700, 100, 1760, 500 }, 1))
    assert.same({ "SetPoint", "TOPLEFT", panel, "TOPRIGHT", 4, 0 }, tipAt({ 1700, 100, 1760, 500 }, 0.5))
  end)

  it("drags only the mover and places the panel where the outline was released", function()
    local panel, mover = addon.panel(), addon.mover()
    startDrag(panel)
    assert.is_true(mover:IsShown())
    assert.equals(1, mover.calls.StartMoving)
    assert.same({ "BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 200, 100 }, mover.lastPoint)
    assert.same({ 600, 120 }, { mover.width, mover.height })
    mover.left, mover.bottom = 401, 301
    panel.scripts.OnDragStop(panel)
    assert.equals(1, mover.calls.StopMovingOrSizing)
    assert.is_false(mover:IsShown())
    assert.is_nil(panel.calls.StartMoving)
    assert.is_nil(panel.calls.StopMovingOrSizing)
    local db = addon.ns.db.raidMarkerPanel
    assert.same({ "BOTTOMLEFT", "BOTTOMLEFT", 201, 151 }, { db.point, db.relativePoint, db.x, db.y })
    assert.same({ "BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 201, 151 }, panel.lastPoint)
  end)

  it("finishes an active drag when the panel hides", function()
    local panel, mover = addon.panel(), addon.mover()
    startDrag(panel)
    mover.left, mover.bottom = 401, 301
    panel.scripts.OnHide(panel)
    assert.equals(1, mover.calls.StopMovingOrSizing)
    assert.is_false(mover:IsShown())
    local db = addon.ns.db.raidMarkerPanel
    assert.same({ "BOTTOMLEFT", "BOTTOMLEFT", 201, 151 }, { db.point, db.relativePoint, db.x, db.y })
    panel.scripts.OnDragStop(panel)
    assert.equals(1, mover.calls.StopMovingOrSizing)
  end)

  it("keeps the mover a separate childless frame never anchored to the panel", function()
    local panel, mover = addon.panel(), addon.mover()
    startDrag(panel)
    panel.scripts.OnDragStop(panel)
    assert.equals(_G.UIParent, mover.parent)
    assert.is_nil(mover.template)
    for _, child in ipairs(addon.children(mover)) do
      assert.equals("Texture", child.kind)
    end
    for _, point in ipairs(mover.points) do
      assert.are_not.equal(panel, point[2])
    end
    for _, point in ipairs(panel.points) do
      assert.are_not.equal(mover, point[2])
    end
  end)

  it("saves a drag released in combat and places the panel after combat", function()
    local panel, mover = addon.panel(), addon.mover()
    startDrag(panel)
    addon.fire("PLAYER_REGEN_DISABLED")
    state.combat = true
    addon.fire("PLAYER_REGEN_DISABLED")
    assert.is_nil(mover.calls.StopMovingOrSizing)
    local placed = panel.setPoints
    mover.left, mover.bottom = 401, 301
    panel.scripts.OnDragStop(panel)
    assert.same({}, addon.blocked)
    assert.equals(1, mover.calls.StopMovingOrSizing)
    assert.is_false(mover:IsShown())
    assert.equals(placed, panel.setPoints)
    local db = addon.ns.db.raidMarkerPanel
    assert.same({ "BOTTOMLEFT", "BOTTOMLEFT", 201, 151 }, { db.point, db.relativePoint, db.x, db.y })
    state.combat = false
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.same({ "BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 201, 151 }, panel.lastPoint)
  end)

  it("applies settings changed in combat when combat ends, and nothing else", function()
    local panel = addon.panel()
    local _, specs = pages(addon)
    state.combat = true
    specs["Scale"].set(1.5)
    specs["Vertical"].set(true)
    assert.same({}, addon.blocked)
    assert.equals(1, panel.scale)
    local sized = panel.calls.SetSize
    state.combat = false
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.equals(1.5, panel.scale)
    assert.equals(sized + 1, panel.calls.SetSize)
    local counts = { panel.calls.SetPoint, panel.calls.SetScale, panel.calls.SetSize, panel.calls.ClearAllPoints }
    addon.fire("PLAYER_REGEN_ENABLED")
    assert.same(counts, { panel.calls.SetPoint, panel.calls.SetScale, panel.calls.SetSize, panel.calls.ClearAllPoints })
  end)

  it("calls no protected function in combat", function()
    state.group, state.leader = true, true
    addon.fire("GROUP_ROSTER_UPDATE")
    local specs, byLabel, page = pages(addon)
    local panel = addon.panel()
    byLabel["Healer mana"].set(true)
    byLabel["Dead or offline count"].set(true)
    state.roles, state.present = { party1 = "HEALER" }, { player = true, party1 = true, party2 = true }
    state.power, state.powerMax = { party1 = MANA, party2 = MANA }, { party1 = MANA_MAX, party2 = MANA_MAX }
    state.dead, state.names = { party2 = true }, { party2 = SECRET }
    byLabel["Mana text"].set("both")
    state.percent = { party1 = MANA_PCT, party2 = MANA_PCT }

    local events = {
      { "PLAYER_ROLES_ASSIGNED", before = function() state.roles = { party2 = "HEALER", party1 = SECRET } end },
      { "READY_CHECK", "Leader", 30 },
      { "READY_CHECK_CONFIRM", "party1", true },
      { "READY_CHECK_FINISHED", false },
      { "START_PLAYER_COUNTDOWN", SECRET, SECRET, SECRET },
      { "CANCEL_PLAYER_COUNTDOWN", SECRET },
      { "START_PLAYER_COUNTDOWN", "Someone", 10, 10 },
      { "CANCEL_PLAYER_COUNTDOWN", "Someone" },
      { "RAID_TARGET_UPDATE" },
      { "PLAYER_TARGET_CHANGED" },
      { "GROUP_ROSTER_UPDATE", before = function() state.leader, state.assistant = false, true end },
      { "PARTY_LEADER_CHANGED" },
      { "PLAYER_ENTERING_WORLD", false, false },
      { "ADDON_RESTRICTION_STATE_CHANGED", 0, 1 },
      { "PLAYER_REGEN_DISABLED" },
      { "PLAYER_REGEN_ENABLED" },
    }
    local listed = {}
    for _, entry in ipairs(events) do listed[entry[1]] = true end
    for event in pairs(addon.eventFrame().events) do
      assert(listed[event], "no payload for " .. event)
    end

    state.combat = true
    for _, entry in ipairs(events) do
      if entry.before then entry.before() end
      addon.fire(entry[1], unpack(entry, 2))
      if entry[1] == "READY_CHECK_FINISHED" then addon.advance() end
    end
    state.targetIndex = 4
    addon.fire("RAID_TARGET_UPDATE")
    state.leader, state.assistant = true, false
    for _, button in ipairs(addon.groupButtons()) do
      button.scripts.OnEnter(button)
      assert.equals("Not in combat", button.reason)
      button.scripts.OnClick(button, "LeftButton")
      button.scripts.OnClick(button, "RightButton")
      button.scripts.OnLeave(button)
    end
    local mode = addon.named("LittleThingsWorldMarkerMode")
    local nextButton, clear = addon.named("LittleThingsWorldMarkerNext"), addon.named("LittleThingsWorldMarkerClear")
    local bound = {}
    mode.scripts.OnEnter(mode)
    mode.scripts.OnLeave(mode)
    snippet(mode, bound, "LeftButton", true)
    assert.is_truthy(bound.BUTTON1)
    snippet(nextButton, bound, "LeftButton", true)
    snippet(nextButton, bound, "LeftButton", false)
    snippet(clear, bound, "LeftButton", true)
    mode.scripts.OnAttributeChanged(mode, "lt-active", true)
    nextButton.scripts.OnAttributeChanged(nextButton, "lt-index", 2)
    snippet(mode, bound, "RightButton", true)
    assert.same({}, bound)
    snippet(mode, bound, "LeftButton", true)
    assert.is_truthy(bound.BUTTON1)
    wrapped(mode, "OnHide", bound)
    assert.same({}, bound)
    assert.is_nil(mode.attrs["lt-active"])
    snippet(mode, bound, "LeftButton", true)
    panel.scripts.OnDragStart(panel)
    panel.scripts.OnDragStop(panel)
    panel.scripts.OnShow(panel)
    addon.tick()
    local bar = addon.manaBar()
    assert.is_true(rawequal(MANA, bar.value))
    local formatted = addon.manaText().formatted
    assert.equals("%s  %d%%", formatted[1])
    assert.is_true(rawequal(MANA_SHORT, formatted[2]) and rawequal(MANA_PCT, formatted[3]))
    assert.equals("1 down", addon.downText().text)
    bar.scripts.OnEnter(bar)
    bar.scripts.OnLeave(bar)
    panel.scripts.OnHide(panel)
    page.scripts.OnShow(page)
    page.scripts.OnHide(page)
    addon.module.OnSwitch(false)
    addon.module.OnSwitch(true)
    for _, spec in ipairs(specs) do
      if spec.set then spec.set(spec.default) else spec.onClick() end
    end

    assert.same({}, addon.blocked)
    assert.same({}, state.calls)
    assert.same({}, state.clearedBindings)
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

    it("creates the next button as a macro and the clear button as a world marker clear-all", function()
      local nextButton, clear = bindings(addon)
      assert.equals("SecureActionButtonTemplate", nextButton.template)
      assert.equals("SecureActionButtonTemplate", clear.template)
      assert.equals("macro", nextButton.attrs.type)
      assert.equals("worldmarker", clear.attrs.type)
      assert.equals("clear", clear.attrs.action)
      assert.is_nil(clear.attrs.marker)
      assert.is_nil(clear.attrs.macrotext)
    end)

    it("next button starts at the first slot of the default order 1..8", function()
      local nextButton, clear = bindings(addon)
      assert.same({ 1, 2, 3, 4, 5, 6, 7, 8 }, addon.ns.db.raidMarkerPanel.order)
      assert.equals(8, nextButton.attrs["lt-count"])
      for i = 1, 8 do assert.equals(i, nextButton.attrs["lt-order" .. i]) end
      assert.equals(1, nextButton.attrs["lt-index"])
      assert.is_nil(nextButton.attrs.macrotext)
      assert.equals(nextButton, clear.attrs["frameref-next"])
      local seen = {}
      for _ = 1, 9 do
        snippet(nextButton, {}, "LeftButton", true)
        seen[#seen + 1] = nextButton.attrs.macrotext
      end
      assert.equals("/wm [@cursor]1", seen[1])
      assert.equals("/wm [@cursor]8", seen[8])
      assert.equals("/wm [@cursor]1", seen[9])
    end)

    it("acts on key down only, so the wrapped cycle advances once per press", function()
      local nextButton, clear = bindings(addon)
      for _, button in ipairs({ assert(nextButton), assert(clear) }) do
        assert.same({ "AnyDown" }, button.clicks)
        assert.is_true(button.attrs.useOnKeyDown)
      end
      assert.is_nil(snippet(nextButton, {}, "LeftButton", true))
      assert.equals("/wm [@cursor]1", nextButton.attrs.macrotext)
      assert.equals(2, nextButton.attrs["lt-index"])
      assert.is_false(snippet(nextButton, {}, "LeftButton", false))
      assert.equals("/wm [@cursor]1", nextButton.attrs.macrotext)
      assert.equals(2, nextButton.attrs["lt-index"])
    end)

    it("binding buttons go dead when switched off", function()
      local nextButton, clear = bindings(addon)
      addon.module.OnSwitch(false)
      assert.is_nil(nextButton.attrs.type)
      assert.is_nil(clear.attrs.type)
      addon.module.OnSwitch(true)
      assert.equals("macro", nextButton.attrs.type)
      assert.equals("worldmarker", clear.attrs.type)
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

  describe("placement mode and order", function()
    local ORDINALS = { "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th" }
    local IDLE = { 0.8, 0.8, 0.8 }

    local function mode(a) return (a or addon).named("LittleThingsWorldMarkerMode") end
    local function nextButton(a) return (a or addon).named("LittleThingsWorldMarkerNext") end
    local function clearButton(a) return (a or addon).named("LittleThingsWorldMarkerClear") end

    before_each(function()
      state.group, state.leader = true, true
      addon.fire("GROUP_ROSTER_UPDATE")
    end)

    local function setOrder(a, order)
      local _, byLabel = pages(a)
      for i = 1, 8 do byLabel[ORDINALS[i]].set(order[i] or 0) end
    end

    local function ringed()
      local found = {}
      for i = 1, 8 do
        local button = world(i)
        assert.equals(button.nextRing.shown, button.nextGap.shown)
        if button.nextRing.shown then found[#found + 1] = i end
      end
      return found
    end

    it("offers a Placement order group of 8 combat-locked dropdowns", function()
      _G.WORLD_MARKER1 = "Blue Square"
      local named = load(state)
      named.module.Enable()
      local specs, byLabel = pages(named)
      _G.WORLD_MARKER1 = nil
      for i, label in ipairs(ORDINALS) do
        local spec = assert(byLabel[label], label)
        assert.is_true(spec.combatLocked)
        assert.equals(i, spec.default)
        assert.equals(i, spec.get())
        assert.equals(9, #spec.options)
        assert.same({ text = "None", value = 0 }, spec.options[1])
        assert.same({ text = "Blue Square", value = 1 }, spec.options[2])
        assert.same({ text = "World marker 8", value = 8 }, spec.options[9])
        assert.is_string(spec.tooltip)
      end
      assert.equals(byLabel["8th"], specs[#specs])
    end)

    it("cycles the non-empty slots in order and wraps", function()
      setOrder(addon, { 5, 0, 1 })
      local nb = nextButton()
      assert.equals(2, nb.attrs["lt-count"])
      assert.same({ 5, 1 }, { nb.attrs["lt-order1"], nb.attrs["lt-order2"] })
      assert.same({ 5, 0, 1, 0, 0, 0, 0, 0 }, addon.ns.db.raidMarkerPanel.order)
      local seen = {}
      for _ = 1, 4 do
        assert.is_nil(snippet(nb, {}, "LeftButton", true))
        seen[#seen + 1] = nb.attrs.macrotext
      end
      assert.same({ "/wm [@cursor]5", "/wm [@cursor]1", "/wm [@cursor]5", "/wm [@cursor]1" }, seen)
    end)

    it("allows duplicates", function()
      setOrder(addon, { 3, 3, 0, 0, 0, 0, 0, 2 })
      local nb = nextButton()
      local seen = {}
      for _ = 1, 3 do
        snippet(nb, {}, "LeftButton", true)
        seen[#seen + 1] = nb.attrs.macrotext
      end
      assert.same({ "/wm [@cursor]3", "/wm [@cursor]3", "/wm [@cursor]2" }, seen)
    end)

    it("clear sends the cycle back to the first slot", function()
      setOrder(addon, { 5, 0, 1 })
      local nb = nextButton()
      snippet(nb, {}, "LeftButton", true)
      snippet(clearButton(), {}, "LeftButton", true)
      assert.equals(1, nb.attrs["lt-index"])
      snippet(nb, {}, "LeftButton", true)
      assert.equals("/wm [@cursor]5", nb.attrs.macrotext)
    end)

    it("cancels the next click when the order is empty", function()
      setOrder(addon, {})
      local nb = nextButton()
      assert.equals(0, nb.attrs["lt-count"])
      assert.is_false(snippet(nb, {}, "LeftButton", true))
      assert.is_nil(nb.attrs.macrotext)
    end)

    it("resets the cycle when the order changes", function()
      local nb = nextButton()
      snippet(nb, {}, "LeftButton", true)
      snippet(nb, {}, "LeftButton", true)
      setOrder(addon, { 7, 6 })
      assert.equals(1, nb.attrs["lt-index"])
      snippet(nb, {}, "LeftButton", true)
      assert.equals("/wm [@cursor]7", nb.attrs.macrotext)
    end)

    it("applies an order changed in combat after combat", function()
      local nb = nextButton()
      state.combat = true
      setOrder(addon, { 4 })
      assert.same({}, addon.blocked)
      assert.equals(8, nb.attrs["lt-count"])
      state.combat = false
      addon.fire("PLAYER_REGEN_ENABLED")
      assert.equals(1, nb.attrs["lt-count"])
      assert.equals(4, nb.attrs["lt-order1"])
    end)

    it("left click enters the mode with both bindings, right click and a second left click leave it", function()
      local m, b = mode(), {}
      assert.is_false(snippet(m, b, "LeftButton", true))
      assert.same({ true, "LittleThingsWorldMarkerNext", "LeftButton" }, b.BUTTON1)
      assert.same({ true, "LittleThingsWorldMarkerMode", "RightButton" }, b.ESCAPE)
      assert.is_true(m.attrs["lt-active"])
      snippet(m, b, "RightButton", true)
      assert.same({}, b)
      assert.is_nil(m.attrs["lt-active"])
      snippet(m, b, "LeftButton", true)
      assert.is_truthy(b.BUTTON1)
      snippet(m, b, "LeftButton", true)
      assert.same({}, b)
      assert.is_nil(m.attrs["lt-active"])
    end)

    it("toggles once per press: the mode button is clicked on down only and ignores an up", function()
      local m, b = mode(), {}
      assert.same({ "AnyDown" }, m.clicks)
      snippet(m, b, "LeftButton", true)
      snippet(m, b, "LeftButton", false)
      assert.is_truthy(b.BUTTON1)
      snippet(m, b, "RightButton", false)
      assert.is_truthy(b.BUTTON1)
      snippet(m, b, "RightButton", true)
      assert.same({}, b)
      assert.same({ "AnyDown" }, nextButton().clicks)
    end)

    it("stays on after the last marker and wraps", function()
      local m, b = mode(), {}
      setOrder(addon, { 2, 6 })
      snippet(m, b, "LeftButton", true)
      for _ = 1, 3 do snippet(nextButton(), b, "LeftButton", true) end
      assert.equals("/wm [@cursor]2", nextButton().attrs.macrotext)
      assert.is_true(m.attrs["lt-active"])
      assert.is_truthy(b.BUTTON1)
    end)

    it("refuses the mode and greys the button when the order is empty", function()
      setOrder(addon, {})
      local m, b = mode(), {}
      assert.same({ 0.5, 0.5, 0.5 }, m.label.color)
      assert.equals("Placement order is empty", m.reason)
      snippet(m, b, "LeftButton", true)
      assert.same({}, b)
      assert.is_nil(m.attrs["lt-active"])
      setOrder(addon, { 1 })
      assert.is_nil(rawget(m, "reason"))
      assert.same(IDLE, m.label.color)
    end)

    it("ends an active mode when the order becomes empty", function()
      local m, b = mode(), {}
      snippet(m, b, "LeftButton", true)
      setOrder(addon, {})
      assert.same({ m }, state.clearedBindings)
      assert.is_nil(m.attrs["lt-active"])
    end)

    it("shows the next position in gold and rings the next marker while on", function()
      local m, b = mode(), {}
      assert.equals("Place", m.label.text)
      assert.same(IDLE, m.label.color)
      assert.same(BORDER, m.border)
      assert.same({}, ringed())
      setOrder(addon, { 5, 0, 1 })
      snippet(m, b, "LeftButton", true)
      assert.equals("1/2", m.label.text)
      assert.same({ 1, 0.82, 0 }, m.label.color)
      assert.same(GOLD, m.border)
      assert.same({ 5 }, ringed())
      snippet(nextButton(), b, "LeftButton", true)
      assert.equals("2/2", m.label.text)
      assert.same({ 1 }, ringed())
      snippet(nextButton(), b, "LeftButton", true)
      assert.equals("1/2", m.label.text)
      snippet(m, b, "RightButton", true)
      assert.equals("Place", m.label.text)
      assert.same(BORDER, m.border)
      assert.same({}, ringed())
    end)

    it("draws the next ring as a white circle with a dark gap around the dot", function()
      local button = world(3)
      local d = dot(button)
      assert.same({ 22, 22 }, { button.nextRing.width, button.nextRing.height })
      assert.same({ 1, 1, 1, 1 }, button.nextRing.vertexColor)
      assert.same({ 18, 18 }, { button.nextGap.width, button.nextGap.height })
      assert.same({ 0, 0, 0, 1 }, button.nextGap.vertexColor)
      for _, t in ipairs({ button.nextRing, button.nextGap }) do
        round(t)
        assert.are_not.equal(d, t)
        assert.are_not.equal(d.masks[1], t.masks[1])
      end
    end)

    it("explains the mode in its tooltip", function()
      local m = mode()
      assert.equals("Placement mode: left click on the ground places the next world marker. Right click or Esc to stop.", m.title)
      assert.same({ "Left-clicks on the world do not target or turn the camera while it is on." }, m.lines())
      m.scripts.OnEnter(m)
      m.scripts.OnLeave(m)
    end)

    it("starts off on login", function()
      local fresh = load(state)
      fresh.module.Enable()
      assert.is_nil(mode(fresh).attrs["lt-active"])
      assert.equals("Place", mode(fresh).label.text)
    end)

    it("clears the bindings from the restricted environment when the mode button hides", function()
      local m, b = mode(), {}
      snippet(m, b, "LeftButton", true)
      assert.is_truthy(b.BUTTON1)
      wrapped(m, "OnHide", b)
      assert.same({}, b)
      assert.is_nil(m.attrs["lt-active"])
      assert.equals("Place", m.label.text)
      assert.same({}, state.clearedBindings)
    end)

    it("ends the mode when switched off, out of combat only", function()
      local m = mode()
      state.bindings = {}
      snippet(m, state.bindings, "LeftButton", true)
      state.combat = true
      addon.module.OnSwitch(false)
      assert.is_truthy(state.bindings.BUTTON1)
      assert.is_true(m.attrs["lt-active"])
      state.combat = false
      addon.fire("PLAYER_REGEN_ENABLED")
      assert.is_false(addon.panel():IsShown())
      assert.same({}, state.bindings)
      assert.is_nil(m.attrs["lt-active"])
      assert.equals("Place", m.label.text)
    end)

    it("ends the mode when the visibility rule hides the panel", function()
      local m = mode()
      state.bindings = {}
      snippet(m, state.bindings, "LeftButton", true)
      addon.fire("PARTY_LEADER_CHANGED")
      assert.is_truthy(state.bindings.BUTTON1)
      state.group = false
      addon.fire("GROUP_ROSTER_UPDATE")
      assert.is_false(addon.panel():IsShown())
      assert.same({}, state.bindings)
      assert.is_nil(m.attrs["lt-active"])
    end)

    it("resets the cycle from the panel's world clear icon", function()
      local _, clearWorld = clears(addon)
      local nb = nextButton()
      assert.equals(nb, clearWorld.attrs["frameref-next"])
      snippet(nb, {}, "LeftButton", true)
      snippet(nb, {}, "LeftButton", true)
      snippet(clearWorld, {}, "LeftButton", true)
      assert.equals(1, nb.attrs["lt-index"])
      snippet(nb, {}, "LeftButton", true)
      assert.equals("/wm [@cursor]1", nb.attrs.macrotext)
    end)

    it("refuses the mode without lead or assist and greys the button", function()
      local m, b = mode(), {}
      state.leader = false
      addon.fire("GROUP_ROSTER_UPDATE")
      assert.is_nil(m.attrs["lt-allowed"])
      assert.same({ 0.5, 0.5, 0.5 }, m.label.color)
      assert.equals("Needs lead or assist", m.reason)
      assert.is_false(snippet(m, b, "LeftButton", true))
      assert.same({}, b)
      assert.is_nil(m.attrs["lt-active"])
      state.raid, state.assistant = true, true
      addon.fire("GROUP_ROSTER_UPDATE")
      assert.is_true(m.attrs["lt-allowed"])
      assert.same(IDLE, m.label.color)
      assert.is_nil(rawget(m, "reason"))
      snippet(m, b, "LeftButton", true)
      assert.is_truthy(b.BUTTON1)
    end)

    it("is not allowed solo", function()
      local fresh = load(state)
      state.group, state.leader = false, false
      fresh.module.Enable()
      assert.is_nil(mode(fresh).attrs["lt-allowed"])
      assert.equals("Needs lead or assist", mode(fresh).reason)
    end)

    it("ends an active mode when the rank is lost, after combat if in combat", function()
      local m, b = mode(), {}
      snippet(m, b, "LeftButton", true)
      state.combat = true
      state.leader = false
      addon.fire("PARTY_LEADER_CHANGED")
      assert.same({}, addon.blocked)
      assert.is_true(m.attrs["lt-allowed"])
      assert.is_true(m.attrs["lt-active"])
      state.combat = false
      addon.fire("PLAYER_REGEN_ENABLED")
      assert.is_nil(m.attrs["lt-allowed"])
      assert.same({ m }, state.clearedBindings)
      assert.is_nil(m.attrs["lt-active"])
    end)
  end)

  describe("tank helpers", function()
    local function helpers(a, mana, down, text)
      local _, byLabel = pages(a)
      byLabel["Healer mana"].set(mana)
      byLabel["Dead or offline count"].set(down)
      if text then byLabel["Mana text"].set(text) end
    end

    local function inParty(a)
      state.group = true
      state.present = { player = true, party1 = true, party2 = true, party3 = true }
      state.roles = { player = "TANK", party1 = "DAMAGER", party2 = "HEALER", party3 = "DAMAGER" }
      a.fire("GROUP_ROSTER_UPDATE")
      a.panel().scripts.OnShow(a.panel())
    end

    it("offers two combat-locked checkboxes, both off", function()
      local _, byLabel = pages(addon)
      local mana, down = byLabel["Healer mana"], byLabel["Dead or offline count"]
      assert.equals("A bar under the group buttons with your party healer's mana. Party only.", mana.tooltip)
      assert.equals("A red count next to the group buttons when party members are dead or offline. Party only.", down.tooltip)
      for _, spec in ipairs({ mana, down }) do
        assert.is_true(spec.combatLocked)
        assert.is_false(spec.default)
        assert.is_false(spec.get())
      end
    end)

    it("passes the healer's mana to the bar untouched", function()
      helpers(addon, true, false)
      state.power, state.powerMax = { party2 = MANA }, { party2 = MANA_MAX }
      inParty(addon)
      addon.tick()
      local bar = addon.manaBar()
      assert.is_true(rawequal(MANA, bar.value))
      assert.equals(0, bar.minMax[1])
      assert.is_true(rawequal(MANA_MAX, bar.minMax[2]))
      assert.equals(1, bar.alpha)
      assert.equals("Interface\\Buttons\\WHITE8x8", bar.barTexture)
    end)

    it("moves the bar to the new healer on a role change and skips a secret role", function()
      helpers(addon, true, false)
      state.power = { party2 = 40, party3 = 70 }
      inParty(addon)
      local bar = addon.manaBar()
      assert.equals(40, bar.value)
      state.roles = { party2 = SECRET, party3 = "HEALER" }
      addon.fire("PLAYER_ROLES_ASSIGNED")
      assert.equals(70, bar.value)
      assert.equals(1, bar.alpha)
    end)

    it("hides the bar without a healer, in a raid and solo", function()
      helpers(addon, true, false)
      inParty(addon)
      local bar = addon.manaBar()
      assert.equals(1, bar.alpha)
      state.roles = { party2 = "DAMAGER" }
      addon.tick()
      assert.equals(0, bar.alpha)
      state.roles = { party2 = "HEALER" }
      state.raid = true
      addon.fire("GROUP_ROSTER_UPDATE")
      assert.equals(0, bar.alpha)
      state.raid, state.group = false, false
      addon.tick()
      assert.equals(0, bar.alpha)
    end)

    it("names the healer in the bar tooltip only when the name is readable", function()
      helpers(addon, true, false)
      inParty(addon)
      local bar = addon.manaBar()
      assert.equals("Healer mana", bar.title)
      state.names = { party2 = "Mender" }
      assert.same({ "Mender" }, bar.lines())
      state.names = { party2 = SECRET }
      assert.same({}, bar.lines())
      bar.scripts.OnEnter(bar)
      bar.scripts.OnLeave(bar)
    end)

    it("counts dead and offline party members, never a secret state", function()
      helpers(addon, false, true)
      inParty(addon)
      local text = addon.downText()
      assert.equals("", text.text)
      assert.equals(0, text.alpha)
      state.dead, state.connected = { party1 = true, party9 = true }, { party3 = false }
      addon.tick()
      assert.equals("2 down", text.text)
      assert.equals(1, text.alpha)
      assert.same({ 1, 0.2, 0.2 }, text.color)
      state.dead, state.connected = { party1 = SECRET }, { party3 = SECRET }
      addon.tick()
      assert.equals("", text.text)
      assert.equals(0, text.alpha)
      state.dead = { party1 = true }
      state.raid = true
      addon.fire("GROUP_ROSTER_UPDATE")
      assert.equals(0, text.alpha)
    end)

    it("reserves no space while both are off", function()
      inParty(addon)
      assert.is_false(addon.manaBar().shown)
      assert.is_false(addon.downText().shown)
      assert.same({ 284 + 2 + 130 + 8, 54 + 8 }, { addon.panel().width, addon.panel().height })
    end)

    it("puts the bar under the group block and the count right of it in the horizontal layout", function()
      state.textWidths = { ["5 down"] = 30.5 }
      local a = load(state)
      a.module.Enable()
      local block = a.button("Ready check").parent
      helpers(a, true, false, "none")
      assert.is_true(a.manaBar().shown)
      assert.is_false(a.downText().shown)
      assert.same({ "TOPLEFT", block, "BOTTOMLEFT", 14, -2 }, a.manaBar().lastPoint)
      assert.same({ 116, 4 }, { a.manaBar().width, a.manaBar().height })
      assert.same({ 284 + 2 + 130 + 8, 60 + 8 }, { a.panel().width, a.panel().height })
      helpers(a, true, true)
      assert.is_true(a.downText().shown)
      assert.same({ "LEFT", block, "RIGHT", 2, 0 }, a.downText().lastPoint)
      assert.same({ 284 + 2 + 130 + 2 + 31 + 8, 60 + 8 }, { a.panel().width, a.panel().height })
      helpers(a, false, true)
      assert.is_false(a.manaBar().shown)
      assert.same({ 284 + 2 + 130 + 2 + 31 + 8, 54 + 8 }, { a.panel().width, a.panel().height })
    end)

    it("stacks the bar and the count under the group block in the vertical layout", function()
      local a = load(state, { raidMarkerPanel = { vertical = true } })
      a.module.Enable()
      local block = a.button("Ready check").parent
      helpers(a, true, true, "none")
      local bar, text = a.manaBar(), a.downText()
      assert.same({ "TOPLEFT", block, "BOTTOMLEFT", 14, -2 }, bar.lastPoint)
      assert.same({ 50, 4 }, { bar.width, bar.height })
      assert.same({ "TOP", bar, "BOTTOM", 0, -2 }, text.lastPoint)
      assert.same({ 64 + 8, 278 + 2 + 82 + 6 + 16 + 8 }, { a.panel().width, a.panel().height })
      helpers(a, false, true)
      assert.same({ "TOP", block, "BOTTOM", 0, -2 }, text.lastPoint)
      assert.same({ 64 + 8, 278 + 2 + 82 + 16 + 8 }, { a.panel().width, a.panel().height })
    end)

    it("offers a Mana text dropdown under Healer mana, Percent by default, greyed while the bar is off", function()
      local specs, byLabel = pages(addon)
      local spec = byLabel["Mana text"]
      local index
      for i, entry in ipairs(specs) do
        if entry == spec then index = i end
      end
      assert.equals(byLabel["Healer mana"], specs[index - 1])
      assert.equals("percent", spec.default)
      assert.equals("percent", spec.get())
      assert.is_true(spec.combatLocked)
      assert.same({ { text = "None", value = "none" }, { text = "Percent", value = "percent" },
        { text = "Value", value = "value" }, { text = "Both", value = "both" } }, spec.options)
      assert.is_false(spec.enabled())
      byLabel["Healer mana"].set(true)
      assert.is_true(spec.enabled())
    end)

    it("shows the percent through a 0..100 curve, passing the secret straight through", function()
      helpers(addon, true, false)
      state.percent = { party2 = MANA_PCT }
      inParty(addon)
      addon.tick()
      local text = addon.manaText()
      assert.equals("%d%%", text.formatted[1])
      assert.is_true(rawequal(MANA_PCT, text.formatted[2]))
      assert.equals(1, #state.curves)
      assert.equals(0, state.curves[1].kind)
      assert.same({ { 0, 0 }, { 1, 100 } }, state.curves[1].points)
      assert.is_true(text.shown)
    end)

    it("shows the abbreviated value, passing the secret straight through", function()
      helpers(addon, true, false, "value")
      state.power = { party2 = MANA }
      inParty(addon)
      addon.tick()
      local text = addon.manaText()
      assert.is_true(rawequal(MANA_SHORT, text.text))
      assert.is_nil(text.formatted)
    end)

    it("shows both, value first", function()
      helpers(addon, true, false, "both")
      state.power, state.percent = { party2 = MANA }, { party2 = MANA_PCT }
      inParty(addon)
      addon.tick()
      local formatted = addon.manaText().formatted
      assert.equals("%s  %d%%", formatted[1])
      assert.is_true(rawequal(MANA_SHORT, formatted[2]))
      assert.is_true(rawequal(MANA_PCT, formatted[3]))
    end)

    it("shows no text and a thin bar for None", function()
      helpers(addon, true, false, "none")
      state.power, state.percent = { party2 = MANA }, { party2 = MANA_PCT }
      inParty(addon)
      addon.tick()
      local text = addon.manaText()
      assert.equals("", text.text)
      assert.is_false(text.shown)
      assert.same({ 116, 4 }, { addon.manaBar().width, addon.manaBar().height })
    end)

    it("makes the bar 12 px tall with the text centred on it", function()
      local block = addon.button("Ready check").parent
      helpers(addon, true, false, "percent")
      local bar, text = addon.manaBar(), addon.manaText()
      assert.same({ "CENTER" }, text.lastPoint)
      assert.same({ 116, 12 }, { bar.width, bar.height })
      assert.same({ "TOPLEFT", block, "BOTTOMLEFT", 14, -2 }, bar.lastPoint)
      assert.same({ 284 + 2 + 130 + 8, 54 + 2 + 12 + 8 }, { addon.panel().width, addon.panel().height })
      local _, specs = pages(addon)
      specs["Vertical"].set(true)
      assert.same({ 50, 12 }, { bar.width, bar.height })
      assert.same({ 64 + 8, 278 + 2 + 82 + 14 + 8 }, { addon.panel().width, addon.panel().height })
      helpers(addon, false, false, "both")
      assert.is_false(bar.shown)
      assert.same({ 64 + 8, 278 + 2 + 82 + 8 }, { addon.panel().width, addon.panel().height })
    end)

    it("puts a 12 px healer role icon left of the bar, its alpha following the bar", function()
      helpers(addon, true, false)
      inParty(addon)
      local icon, bar = addon.manaIcon(), addon.manaBar()
      assert.equals("UI-LFG-RoleIcon-Healer-Micro-GroupFinder", icon.atlas)
      assert.same({ 12, 12 }, { icon.width, icon.height })
      assert.equals(bar, icon.parent)
      assert.same({ "RIGHT", bar, "LEFT", -2, 0 }, icon.lastPoint)
      assert.equals(1, bar.alpha)
      state.roles = { party2 = "DAMAGER" }
      addon.tick()
      assert.equals(0, bar.alpha)
    end)

    it("prefixes the class-coloured healer name for each text mode", function()
      state.names, state.classes = { party2 = "Mender" }, { party2 = "PRIEST" }
      state.power, state.percent = { party2 = 40 }, { party2 = 55 }
      helpers(addon, true, false, "percent")
      inParty(addon)
      local text = addon.manaText()
      assert.same({ "%s %d%%", "|cPRIESTMender|r", 55 }, text.formatted)
      helpers(addon, true, false, "value")
      addon.tick()
      assert.same({ "%s %s", "|cPRIESTMender|r", "short 40" }, text.formatted)
      helpers(addon, true, false, "both")
      addon.tick()
      assert.same({ "%s %s  %d%%", "|cPRIESTMender|r", "short 40", 55 }, text.formatted)
      helpers(addon, true, false, "none")
      addon.tick()
      assert.equals("", text.text)
    end)

    it("leaves the name out when it is secret or missing, uncoloured when only the class is unusable", function()
      state.power, state.percent = { party2 = 40 }, { party2 = 55 }
      helpers(addon, true, false, "percent")
      inParty(addon)
      local text = addon.manaText()
      state.names, state.classes = { party2 = SECRET }, { party2 = "PRIEST" }
      addon.tick()
      assert.same({ "%d%%", 55 }, text.formatted)
      state.names = nil
      addon.tick()
      assert.same({ "%d%%", 55 }, text.formatted)
      state.names, state.classes = { party2 = "Mender" }, { party2 = SECRET }
      addon.tick()
      assert.same({ "%s %d%%", "Mender", 55 }, text.formatted)
      state.classes = { party2 = "WARLOCK" }
      addon.tick()
      assert.same({ "%s %d%%", "Mender", 55 }, text.formatted)
    end)

    it("still passes secret value and percent untouched alongside the name", function()
      state.names, state.classes = { party2 = "Mender" }, { party2 = "DRUID" }
      state.power, state.percent = { party2 = MANA }, { party2 = MANA_PCT }
      helpers(addon, true, false, "both")
      inParty(addon)
      local formatted = addon.manaText().formatted
      assert.is_true(rawequal(MANA_SHORT, formatted[3]))
      assert.is_true(rawequal(MANA_PCT, formatted[4]))
    end)

    it("records no protected call in combat with the icon and name text on", function()
      state.names, state.classes = { party2 = "Mender" }, { party2 = "PRIEST" }
      state.power, state.percent = { party2 = MANA }, { party2 = MANA_PCT }
      helpers(addon, true, false, "both")
      inParty(addon)
      state.combat = true
      state.names = { party2 = SECRET }
      addon.tick()
      state.names = { party2 = "Mender" }
      addon.tick()
      assert.same({}, addon.blocked)
    end)

    it("applies a toggle made in combat after combat", function()
      inParty(addon)
      state.combat = true
      helpers(addon, true, true)
      assert.same({}, addon.blocked)
      assert.is_false(addon.manaBar().shown)
      state.combat = false
      addon.fire("PLAYER_REGEN_ENABLED")
      assert.is_true(addon.manaBar().shown)
      assert.is_true(addon.downText().shown)
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

    it("buttons grey out in chat lockdown and clicking records no call", function()
      state.lockdown = true
      leading()
      local ready, pull, role = addon.button("Ready check"), addon.button("Pull countdown"), addon.button("Role check")
      for _, button in ipairs({ ready, pull, role }) do
        assert.same({ 0.5, 0.5, 0.5 }, button.label.color)
        assert.is_string(button.reason)
      end
      ready.scripts.OnClick(ready, "LeftButton")
      pull.scripts.OnClick(pull, "LeftButton")
      role.scripts.OnClick(role, "LeftButton")
      assert.same({}, state.calls)
    end)

    it("never disables group buttons", function()
      state.lockdown = true
      leading()
      for _, title in ipairs({ "Ready check", "Pull countdown", "Role check" }) do
        local button = addon.button(title)
        assert.is_nil(button.calls.SetEnabled)
        assert.is_nil(button.calls.Enable)
        assert.is_nil(button.calls.Disable)
      end
    end)

    it("repaints when the chat restriction lifts", function()
      state.lockdown = true
      leading()
      local ready = addon.button("Ready check")
      assert.same({ 0.5, 0.5, 0.5 }, ready.label.color)
      state.lockdown = false
      addon.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
      assert.same({ 1, 1, 1 }, ready.label.color)
      assert.is_nil(rawget(ready, "reason"))
    end)

    it("starts a pull after a secret countdown once the restriction lifts", function()
      leading()
      local pull = addon.button("Pull countdown")
      state.lockdown = true
      addon.fire("START_PLAYER_COUNTDOWN", SECRET, SECRET, SECRET)
      addon.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 1)
      state.lockdown = false
      addon.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
      pull.scripts.OnClick(pull, "LeftButton")
      assert.same({ { "pull", 10 } }, state.calls)
    end)

    it("keeps a readable countdown running when the restriction lifts", function()
      leading()
      local pull = addon.button("Pull countdown")
      addon.fire("START_PLAYER_COUNTDOWN", "Someone", 10, 10)
      addon.fire("ADDON_RESTRICTION_STATE_CHANGED", 0, 0)
      pull.scripts.OnClick(pull, "LeftButton")
      assert.same({ { "pull", 0 } }, state.calls)
    end)

    it("clicks the ready check and role poll when allowed", function()
      leading()
      local ready, role = addon.button("Ready check"), addon.button("Role check")
      ready.scripts.OnClick(ready, "LeftButton")
      role.scripts.OnClick(role, "LeftButton")
      assert.same({ { "ready" }, { "role" } }, state.calls)
    end)

    it("greys out on combat start after the timer tick", function()
      leading()
      state.combat = true
      addon.fire("PLAYER_REGEN_DISABLED")
      local ready = addon.button("Ready check")
      assert.same({ 0.5, 0.5, 0.5 }, ready.label.color)
      assert.is_string(ready.reason)
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

    it("keeps the last statuses when the finished tally reads none", function()
      leading()
      state.members = 2
      state.status = { player = "ready", party1 = "waiting" }
      addon.fire("READY_CHECK")
      state.status = nil
      addon.fire("READY_CHECK_FINISHED")
      local ready = addon.button("Ready check")
      assert.equals("Ready 1/2", ready.label.text)
      assert.same({ 1, 0.2, 0.2 }, ready.label.color)
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
  end)
end)

describe("RaidMarkers preview", function()
  local state, addon, pane

  local function fakePane()
    local p = { visible = true, stage = {} }
    function p:IsVisible() return self.visible end
    function p:SetCaption(text) self.caption = text end
    function p:SetOff(text) self.off = text end
    function p:Fit(content, w, h) self.fit = { content, w, h } end
    return p
  end

  local function options()
    local byLabel = {}
    local group = {}
    for _, kind in ipairs({ "Check", "Slider", "Button", "Dropdown" }) do
      group[kind] = function(_, spec) byLabel[spec.label] = spec end
    end
    local frame = { HookScript = noop }
    addon.module.Pages({ Group = function() return group end, frame = frame })
    return byLabel
  end

  local function previewPanel()
    return addon.children(addon.children(pane.stage)[1])[1]
  end

  before_each(function()
    state = { combat = false, group = false, raid = false, leader = false, assistant = false, calls = {} }
    addon = load(state)
    addon.module.Enable()
    pane = fakePane()
  end)

  it("draws a second panel from non-secure, unnamed frames without touching the live one", function()
    local live = addon.panel()
    local liveCalls = {}
    for _, f in ipairs(addon.all()) do
      local copy = {}
      for k, v in pairs(f.calls) do copy[k] = v end
      liveCalls[f] = copy
    end
    addon.module.Preview.Attach(pane)
    addon.module.Preview.Refresh()
    for f, copy in pairs(liveCalls) do assert.same(copy, f.calls) end
    local panel = previewPanel()
    assert.is_truthy(panel)
    assert.are_not.equal(live, panel)
    local function walk(f, seen)
      for _, child in ipairs(addon.children(f)) do
        assert.is_nil(child.name)
        assert.is_falsy(child.template and child.template:find("Secure"))
        assert.are_not.equal("Button", child.kind)
        seen[#seen + 1] = child
        walk(child, seen)
      end
      return seen
    end
    assert.is_true(#walk(addon.children(pane.stage)[1], {}) > 20)
    assert.is_truthy(pane.caption)
    assert.is_nil(pane.off)
    assert.equals(addon.children(pane.stage)[1], pane.fit[1])
  end)

  it("follows the layout, scale and helper settings", function()
    local byLabel = options()
    addon.module.Preview.Attach(pane)
    addon.module.Preview.Refresh()
    local panel = previewPanel()
    assert.is_true(panel.width > panel.height)
    byLabel["Vertical"].set(true)
    assert.is_true(panel.height > panel.width)
    byLabel["Scale"].set(1.5)
    assert.equals(1.5, panel.scale)
    assert.same({ panel.width * 1.5, panel.height * 1.5 }, { pane.fit[2], pane.fit[3] })
    byLabel["Healer mana"].set(true)
    byLabel["Mana text"].set("value")
    local bar
    for _, f in ipairs(addon.children(panel)) do
      if f.kind == "StatusBar" then bar = f end
    end
    assert.is_true(bar.shown)
    local text = addon.children(bar)
    local formatted
    for _, f in ipairs(text) do
      if f.kind == "FontString" then formatted = f.formatted end
    end
    assert.same({ "%s %s", "|cPRIESTHealer|r", "short 180000" }, formatted)
  end)

  it("follows a setting changed in combat without touching the live panel", function()
    local byLabel = options()
    addon.module.Preview.Attach(pane)
    addon.module.Preview.Refresh()
    local live = addon.panel()
    local sized = live.calls.SetSize
    state.combat = true
    byLabel["Vertical"].set(true)
    local panel = previewPanel()
    assert.is_true(panel.height > panel.width)
    assert.equals(sized, live.calls.SetSize)
  end)

  it("greys out with a visible line while the module is off", function()
    addon.module.Preview.Attach(pane)
    state.off = true
    addon.module.Preview.Refresh()
    assert.is_truthy(pane.off)
    state.off = false
    addon.module.Preview.Refresh()
    assert.is_nil(pane.off)
  end)

  it("asks for the column every preview page shares", function()
    assert.equals(476, addon.module.Preview.columnMin)
  end)

  it("draws nothing while the pane is hidden", function()
    addon.module.Preview.Attach(pane)
    pane.visible = false
    addon.module.Preview.Refresh()
    assert.equals(0, #addon.children(addon.children(pane.stage)[1]))
  end)
end)
