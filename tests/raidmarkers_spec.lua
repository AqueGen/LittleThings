local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

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

local ALLOWED = {
  Frame = { "SetScript", "RegisterEvent", "Show", "Hide", "IsShown", "SetPoint", "ClearAllPoints", "SetSize", "SetScale",
    "SetFrameStrata", "SetClampedToScreen", "SetDontSavePosition", "SetMovable", "EnableMouse", "RegisterForDrag",
    "CreateTexture", "StartMoving", "StopMovingOrSizing", "GetLeft", "GetBottom", "GetWidth", "GetHeight",
    "GetEffectiveScale", "WrapScript", "SetAllPoints", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" },
  Button = { "SetScript", "SetSize", "SetPoint", "ClearAllPoints", "CreateTexture", "CreateFontString", "SetHighlightTexture",
    "RegisterForClicks", "SetAttribute", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" },
  Texture = { "SetAllPoints", "SetPoint", "SetSize", "SetColorTexture", "SetTexture", "SetAtlas", "SetMask", "SetBlendMode",
    "Hide", "SetShown" },
  FontString = { "SetPoint", "SetText", "SetTextColor", "GetStringWidth" },
}

local MOVER = "LittleThingsRaidMarkersMover"

local IMPL = {}
function IMPL:SetAttribute(k, v) self.attrs[k] = v end
function IMPL:SetScript(script, fn) self.scripts[script] = fn end
function IMPL:RegisterEvent(event) self.events[event] = true end
function IMPL:Show() self.shown = true self.showCalls = self.showCalls + 1 end
function IMPL:Hide() self.shown = false end
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
function IMPL:SetText(t) self.text = t end
function IMPL:SetTextColor(r, g, b) self.color = { r, g, b } end
function IMPL:RegisterForClicks(...) self.clicks = { ... } end
function IMPL:SetBackdrop(backdrop) self.backdrop = backdrop end
function IMPL:SetBackdropColor(...) self.bg = { ... } end
function IMPL:SetBackdropBorderColor(...) self.border = { ... } end
function IMPL:SetColorTexture(...) self.colorTexture = { ... } end
function IMPL:SetTexture(texture) self.texture = texture end
function IMPL:SetAtlas(atlas) self.atlas = atlas end
function IMPL:SetMask(mask) self.mask = mask end
function IMPL:GetStringWidth() return self.frames.state.textWidth or 0 end
function IMPL:WrapScript(frame, script, preBody) frame.wraps = rawget(frame, "wraps") or {} frame.wraps[script] = preBody end

local new_object

function IMPL:CreateTexture() return new_object(self.frames, "Texture", nil, nil, self) end
function IMPL:CreateFontString() return new_object(self.frames, "FontString", nil, nil, self) end

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
    RegisterModule = function(_, m) module = m end,
    ApplyDefaults = function(target, defaults)
      for k, v in pairs(defaults) do
        if target[k] == nil then target[k] = v end
      end
    end,
  }
  _G.UIParent = { GetEffectiveScale = function() return 0.8 end }
  _G.CreateFrame = function(kind, name, parent, template) return new_object(frames, kind, name, template, parent) end
  _G.InCombatLockdown = function() return state.combat end
  _G.IsInGroup = function() return state.group end
  _G.IsInRaid = function() return state.raid end
  _G.UnitIsGroupLeader = function() return state.leader end
  _G.UnitIsGroupAssistant = function() return state.assistant end
  _G.issecretvalue = function(v) return v == SECRET end
  _G.GetRaidTargetIndex = function() return state.targetIndex end
  _G.IsRaidMarkerActive = function(i) return state.placed and state.placed[i] or false end
  _G.SetRaidTargetIconTexture = noop
  _G.SecureHandlerSetFrameRef = function(frame, label, ref) frame.attrs["frameref-" .. label] = ref end
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
  _G.C_AddOns = { IsAddOnLoaded = function() return state.mrt end }
  _G.GameTooltip = setmetatable({}, { __index = function() return noop end })
  _G.ExRT = state.exrt
  _G.GMRT = state.gmrt
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

  return { module = module, ns = ns, fire = fire, secure = secure, named = named, panel = panel, button = button, advance = advance,
    groupButtons = groupButtons, blocked = frames.blocked, tick = tick, eventFrame = eventFrame, children = children,
    mover = function() return named("LittleThingsRaidMarkersMover") end }
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
    assert.same({ "Visibility", "Raid marker panel" }, titles)
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
      if rawget(child, "mask") then return child end
    end
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
      assert.equals("Interface\\CharacterFrame\\TempPortraitAlphaMask", d.mask)
      assert.same({ 16, 16 }, { d.width, d.height })
      assert.same({ color[1] / 255, color[2] / 255, color[3] / 255, 1 }, d.colorTexture)
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
    assert.equals(21, #buttons)
    for _, button in ipairs(buttons) do
      assert.equals(flat, button.backdrop)
      assert.same({ 0, 0, 0, 0.5 }, button.bg)
      assert.same(BORDER, button.border)
      assert.truthy(button.template == "BackdropTemplate" or button.template == "SecureActionButtonTemplate,BackdropTemplate")
    end
    assert.equals(18, #addon.secure(function(_, f) return f.template == "SecureActionButtonTemplate,BackdropTemplate" end))
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
    return a.button("Ready check"), a.button("Pull countdown"), a.button("Role check"), a.button("MRT Raid Check")
  end

  local function offsets(button)
    return { button.lastPoint[4], button.lastPoint[5] }
  end

  it("lays the group buttons out as a 2x2 block right of both rows", function()
    local panel = addon.panel()
    local ready, pull, role, rc = cells(addon)
    assert.is_nil(rc)
    local block = ready.parent
    local row1 = target(1).parent
    local row2 = world(1).parent
    assert.same({ "TOPLEFT", row1, "TOPRIGHT", 2, 0 }, block.lastPoint)
    assert.same({ "TOPLEFT", row1, "BOTTOMLEFT", 0, -2 }, row2.lastPoint)
    assert.same({ 284, 26 }, { row1.width, row1.height })
    assert.same({ 284, 26 }, { row2.width, row2.height })
    for _, button in ipairs({ ready, pull, role }) do
      assert.same({ 64, 26 }, { button.width, button.height })
      assert.equals(block, button.lastPoint[2])
    end
    assert.same({ 0, 0 }, offsets(ready))
    assert.same({ 66, 0 }, offsets(pull))
    assert.same({ 0, -28 }, offsets(role))
    assert.same({ 130, 54 }, { block.width, block.height })
    assert.same({ 284 + 2 + 130 + 8, 54 + 8 }, { panel.width, panel.height })
  end)

  it("puts the 2x2 block under the columns in the vertical layout", function()
    local _, specs = pages(addon)
    specs["Vertical"].set(true)
    local panel = addon.panel()
    local ready, pull, role = cells(addon)
    local block = ready.parent
    local row1 = target(1).parent
    assert.same({ "TOPLEFT", row1, "BOTTOMLEFT", 0, -2 }, block.lastPoint)
    assert.same({ 60, 250 }, { row1.width, row1.height })
    assert.same({ 0, 0 }, offsets(ready))
    assert.same({ 66, 0 }, offsets(pull))
    assert.same({ 0, -28 }, offsets(role))
    assert.same({ math.max(60 + 2 + 60, 130) + 8, 250 + 2 + 54 + 8 }, { panel.width, panel.height })
  end)

  it("fills the fourth cell with RC when MRT is loaded", function()
    state.mrt, state.gmrt = true, { A = { RaidCheck = { ReadyCheckWindow = noop } } }
    local mrt = load(state)
    mrt.module.Enable()
    local ready, _, _, rc = cells(mrt)
    assert.equals(ready.parent, rc.lastPoint[2])
    assert.same({ 66, -28 }, offsets(rc))
    assert.same({ 64, 26 }, { rc.width, rc.height })
    assert.same({ 284 + 2 + 130 + 8, 54 + 8 }, { mrt.panel().width, mrt.panel().height })
  end)

  it("widens the block cells when the ready label needs more than 64 px", function()
    state.textWidth = 70.2
    local wide = load(state)
    wide.module.Enable()
    local ready, pull = cells(wide)
    assert.same({ 79, 26 }, { ready.width, ready.height })
    assert.same({ 81, 0 }, offsets(pull))
    assert.equals("Ready", ready.label.text)
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
    local rcCalls = 0
    state.mrt = true
    state.gmrt = { A = { RaidCheck = { ReadyCheckWindow = function() rcCalls = rcCalls + 1 end } } }
    addon = load(state)
    addon.module.Enable()
    state.group, state.leader = true, true
    addon.fire("GROUP_ROSTER_UPDATE")
    local specs, _, page = pages(addon)
    local panel = addon.panel()
    assert.truthy(addon.button("MRT Raid Check"))

    local events = {
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
    panel.scripts.OnDragStart(panel)
    panel.scripts.OnDragStop(panel)
    panel.scripts.OnShow(panel)
    addon.tick()
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
    assert.equals(0, rcCalls)
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

    it("hides RC without MRT and calls Raid Check with it", function()
      assert.is_nil(addon.button("MRT Raid Check"))
      local args
      local raidCheck = { ReadyCheckWindow = function(...) args = { ... } end }
      state.mrt, state.exrt = true, { A = { RaidCheck = raidCheck } }
      local stray = load(state)
      stray.module.Enable()
      assert.is_nil(stray.button("MRT Raid Check"))
      state.exrt, state.gmrt = nil, { A = { RaidCheck = raidCheck } }
      local mrt = load(state)
      mrt.module.Enable()
      local rc = mrt.button("MRT Raid Check")
      rc.scripts.OnClick(rc, "LeftButton")
      assert.same({ raidCheck, nil, nil, true }, args)
    end)

    it("greys RC in combat and in chat lockdown, never by rank, and does not call MRT", function()
      local calls = 0
      state.mrt, state.gmrt = true, { A = { RaidCheck = { ReadyCheckWindow = function() calls = calls + 1 end } } }
      local mrt = load(state)
      mrt.module.Enable()
      local rc = mrt.button("MRT Raid Check")
      state.group, state.raid = true, true
      rc.scripts.OnEnter(rc)
      assert.is_nil(rawget(rc, "reason"))
      assert.same({ 1, 1, 1 }, rc.label.color)
      for _, blocked in ipairs({ { combat = true, reason = "Not in combat" },
        { lockdown = true, reason = "Blocked while the game restricts chat (combat, encounter or active key)" } }) do
        state.combat, state.lockdown = blocked.combat, blocked.lockdown
        rc.scripts.OnEnter(rc)
        assert.equals(blocked.reason, rc.reason)
        assert.same({ 0.5, 0.5, 0.5 }, rc.label.color)
        rc.scripts.OnClick(rc, "LeftButton")
      end
      assert.equals(0, calls)
    end)
  end)
end)
