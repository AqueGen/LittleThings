-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")

local function load(state)
  local tracker = Frames.tracker()
  local tickers = {}
  _G.CreateFrame = tracker.CreateFrame
  _G.UIParent = Frames.new()
  function UIParent:GetEffectiveScale() return 1 end
  function UIParent:GetTop() return 1080 end
  _G.InCombatLockdown = function() return state.combat end
  _G.UISpecialFrames = {}
  _G.tinsert = table.insert
  _G.C_Timer = { NewTicker = function(_, fn) tickers[#tickers + 1] = fn return { Cancel = function() end } end }
  _G.LibStub = function() return { dock = { panels = state.dockPanels or {} } } end
  local ns = { Widgets = { FLAT = { bgFile = "flat" }, THEME = { bg = { 0.063, 0.075, 0.09, 0.99 } } }, Print = function(text) state.printed[#state.printed + 1] = text end }
  assert(loadfile("./Modules/PanelMove.lua"))("LittleThings", ns)
  return ns.PanelMove, tracker, function() tickers[1]() end, ns
end

local function panel(rect)
  local f = Frames.new()
  f.over = false
  function f:IsMouseOver() return self.over end
  function f:GetLeft() return rect[1] end
  function f:GetTop() return rect[2] end
  function f:GetRight() return rect[3] end
  function f:GetBottom() return rect[4] end
  function f:GetEffectiveScale() return 1 end
  return f
end

local function spec(state, name, frame)
  local s = { name = name, frame = function() return frame end, calls = {}, strip = 18 }
  for _, key in ipairs({ "setMoving", "reset", "stopDrag" }) do
    s[key] = function(...) s.calls[#s.calls + 1] = { key, ... } state.log[#state.log + 1] = name .. ":" .. key end
  end
  return s
end

describe("PanelMove.Draggable", function()
  local Move = load({ printed = {} })

  it("drags only out of combat, in Move panels mode or on an unlocked panel", function()
    assert.is_true(Move.Draggable(false, true, false))
    assert.is_true(Move.Draggable(false, false, true))
    assert.is_false(Move.Draggable(false, false, false))
    assert.is_false(Move.Draggable(true, true, true))
  end)
end)

describe("PanelMove.SeamRect", function()
  local Move = load({ printed = {} })
  local target = { l = 100, t = 500, r = 400, b = 440 }

  it("draws a 1 unit line on whole units in the middle of the gap, spanning only the shared part of the two edges", function()
    assert.same({ 100, 438, 300, 437 }, { Move.SeamRect("Below", { l = 100, t = 434, r = 300, b = 380 }, target) })
    assert.same({ 150, 504, 400, 503 }, { Move.SeamRect("Above", { l = 150, t = 560, r = 450, b = 506 }, target) })
    assert.same({ 403, 500, 404, 470 }, { Move.SeamRect("Right", { l = 406, t = 520, r = 500, b = 470 }, target) })
    assert.same({ 97, 490, 98, 440 }, { Move.SeamRect("Left", { l = 0, t = 490, r = 94, b = 400 }, target) })
  end)

  it("sits on the shared edge when there is no gap", function()
    assert.same({ 100, 441, 300, 440 }, { Move.SeamRect("Below", { l = 100, t = 440, r = 300, b = 380 }, target) })
  end)
end)

describe("PanelMove.SharedSides", function()
  local Move = load({ printed = {} })

  it("names the sides of a docked pair that touch, for the member and the target", function()
    for side, pair in pairs({ Below = { "top", "bottom" }, Above = { "bottom", "top" }, Right = { "left", "right" }, Left = { "right", "left" } }) do
      local docks = { calls = { dockTo = "raid", side = side } }
      assert.same({ [pair[1]] = true }, Move.SharedSides("calls", docks))
      assert.same({ [pair[2]] = true }, Move.SharedSides("raid", docks))
    end
    assert.same({}, Move.SharedSides("raid", {}))
  end)
end)

describe("PanelMove.Available", function()
  local Move = load({ printed = {} })

  it("is available while any movable panel module is on", function()
    local on = {}
    local function isOn(key) return on[key] == true end
    assert.is_false(Move.Available(isOn))
    for _, key in ipairs({ "raidMarkers", "partyCalls", "saveIndicator" }) do
      on = { [key] = true }
      assert.is_true(Move.Available(isOn))
    end
    on = { groupChat = true }
    assert.is_false(Move.Available(isOn))
  end)
end)

describe("PanelMove.LockSpot", function()
  local Move = load({ printed = {} })

  it("centres a 20 unit padlock on the top of the fold strip, scaled with the panel, sticking out past the corner", function()
    assert.same({ "CENTER", 109, 491, 20 }, { Move.LockSpot(100, 500, 400, 440, 1080, 18, 1, false) })
    assert.same({ "CENTER", 118, 982, 40 }, { Move.LockSpot(100, 1000, 400, 880, 1080, 36, 2, false) })
  end)

  it("shrinks the badge inside the strip when a neighbour sits on the left or above", function()
    assert.same({ "CENTER", 109, 491, 16 }, { Move.LockSpot(100, 500, 400, 440, 1080, 18, 1, true) })
    assert.same({ "CENTER", 118, 982, 32 }, { Move.LockSpot(100, 1000, 400, 880, 1080, 36, 2, true) })
  end)

  it("puts the badge outside the top-right corner of a panel without a strip, below it at the screen top", function()
    assert.same({ "BOTTOMRIGHT", 400, 500, 20 }, { Move.LockSpot(100, 500, 400, 440, 1080) })
    assert.same({ "BOTTOMRIGHT", 400, 1060, 20 }, { Move.LockSpot(100, 1060, 400, 1000, 1080) })
    assert.same({ "TOPRIGHT", 400, 1000, 20 }, { Move.LockSpot(100, 1062, 400, 1000, 1080) })
  end)
end)

describe("PanelMove", function()
  local state, Move, tracker, tick, raid, calls

  local function button(text)
    for _, f in ipairs(tracker.find("Button")) do
      if f.text == text then return f end
    end
  end

  local function lock()
    for _, f in ipairs(tracker.all) do
      if f.name == "LittleThingsMoveLock" then return f end
    end
  end

  before_each(function()
    state = { combat = false, printed = {}, log = {} }
    Move, tracker, tick = load(state)
    raid = panel({ 100, 500, 400, 440 })
    calls = panel({ 100, 434, 300, 380 })
    Move.Register("raidMarkers", spec(state, "Raid marker panel", raid))
    Move.Register("partyCalls", spec(state, "Party calls", calls))
  end)

  it("refuses the mode in combat with a chat line", function()
    state.combat = true
    Move.Toggle()
    assert.is_false(Move.Moving())
    assert.same({ "Move panels is available out of combat only." }, state.printed)
    assert.same({}, state.log)
  end)

  it("shows every panel, a bar with visible text and buttons, gold outlines with names, and lets every panel drag", function()
    Move.Toggle()
    assert.is_true(Move.Moving())
    assert.same({ "Raid marker panel:setMoving", "Party calls:setMoving" }, state.log)
    local bar = tracker.text("Moving LittleThings panels").parentFrame
    assert.is_true(bar:IsShown())
    assert.equals("LittleThingsMovePanels", bar.name)
    assert.is_truthy(button("Reset positions"))
    assert.is_truthy(button("Done"))
    assert.is_true(tracker.text("Raid marker panel").parentFrame:IsShown())
    assert.is_true(tracker.text("Party calls").parentFrame:IsShown())
    assert.is_true(Move.CanDrag("raidMarkers"))
    assert.is_true(Move.CanDrag("partyCalls"))
    assert.same({ "LittleThingsMovePanels", "LittleThingsPanelUnlock" }, UISpecialFrames)
  end)

  it("resets every panel from the bar and ends on Done, stopping drags first", function()
    Move.Toggle()
    state.log = {}
    button("Reset positions").scripts.OnClick()
    assert.same({ "Raid marker panel:reset", "Party calls:reset" }, state.log)
    state.log = {}
    button("Done").scripts.OnClick()
    assert.is_false(Move.Moving())
    assert.same({ "Raid marker panel:stopDrag", "Raid marker panel:setMoving", "Party calls:stopDrag", "Party calls:setMoving" }, state.log)
    assert.is_false(tracker.text("Moving LittleThings panels").parentFrame:IsShown())
    assert.is_false(tracker.text("Raid marker panel").parentFrame:IsShown())
    assert.is_false(Move.CanDrag("raidMarkers"))
  end)

  it("ends on Esc (the bar hides) and when combat starts", function()
    Move.Toggle()
    tracker.text("Moving LittleThings panels").parentFrame:Hide()
    assert.is_false(Move.Moving())
    Move.Toggle()
    for _, f in ipairs(tracker.all) do
      if f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_REGEN_DISABLED") end
    end
    assert.is_false(Move.Moving())
  end)

  it("shows a lock above the hovered panel out of combat, never in combat, and unlocks only that panel on click", function()
    tick()
    assert.is_nil(lock())
    calls.over = true
    tick()
    local icon = lock()
    assert.is_true(icon:IsShown())
    assert.same({ { "CENTER", UIParent, "BOTTOMLEFT", 109, 425 } }, icon.points)
    assert.same({ 20, 20 }, { icon.width, icon.height })
    assert.is_nil(icon.bg)
    assert.is_nil(icon.border)
    assert.equals("QuestSharing-Padlock", icon.icon.atlas)
    assert.same({ 0.85, 0.85, 0.85 }, icon.icon.vertex)
    assert.equals("QuestSharing-Padlock", icon.shadow.atlas)
    assert.same({ 0, 0, 0, 0.8 }, icon.shadow.vertex)
    assert.same({ { "TOPLEFT", icon, "TOPLEFT", 1, -1 }, { "BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1 } }, icon.shadow.points)
    icon.scripts.OnEnter(icon)
    assert.same({ 1, 0.82, 0 }, icon.icon.vertex)
    tick()
    assert.same({ 1, 0.82, 0 }, icon.icon.vertex)
    icon.scripts.OnLeave(icon)
    assert.same({ 0.85, 0.85, 0.85 }, icon.icon.vertex)
    icon.scripts.OnClick(icon)
    assert.same({ 1, 0.82, 0 }, icon.icon.vertex)
    assert.is_true(Move.CanDrag("partyCalls"))
    assert.is_false(Move.CanDrag("raidMarkers"))
    assert.is_true(tracker.text("Party calls").parentFrame:IsShown())
    calls.over = false
    function icon:IsMouseOver() return true end
    tick()
    assert.is_true(icon:IsShown())
    icon.scripts.OnClick(icon)
    assert.is_false(Move.CanDrag("partyCalls"))
    assert.is_false(tracker.text("Party calls").parentFrame:IsShown())
    state.combat = true
    calls.over = true
    tick()
    assert.is_false(icon:IsShown())
  end)

  it("puts the lock below a strip-less panel at the screen top", function()
    local top = panel({ 10, 1078, 200, 1000 })
    local s = spec(state, "Save indicator", top)
    s.strip = nil
    Move.Register("saveIndicator", s)
    top.over = true
    tick()
    assert.same({ { "TOPRIGHT", UIParent, "BOTTOMLEFT", 200, 1000 } }, lock().points)
  end)

  it("shows a merged member's lock on the root's strip and unlocks the root", function()
    local member = spec(state, "Members", panel({ 500, 300, 600, 200 }))
    member.owner = function() return "raidMarkers" end
    Move.Register("member", member)
    member.frame().over = true
    tick()
    assert.same({ { "CENTER", UIParent, "BOTTOMLEFT", 109, 491 } }, lock().points)
    lock().scripts.OnClick(lock())
    assert.is_true(Move.CanDrag("raidMarkers"))
    assert.is_false(Move.CanDrag("member"))
  end)

  it("sizes the lock to the strip at the panel's scale", function()
    function raid:GetEffectiveScale() return 2 end
    raid.over = true
    tick()
    assert.same({ 40, 40 }, { lock().width, lock().height })
  end)

  it("keeps the badge inside the strip when a neighbour is docked above or to the left, never over its buttons", function()
    for _, side in ipairs({ "Above", "Left" }) do
      state.dockPanels = {
        raidMarkers = { spec = { root = true, frame = raid, get = function() return {} end } },
        partyCalls = { spec = { frame = calls, get = function() return { dockTo = "raidMarkers", side = side } end } },
      }
      raid.over = true
      tick()
      assert.same({ 16, 16 }, { lock().width, lock().height })
      raid.over = false
      tick()
    end
    state.dockPanels.partyCalls.spec.get = function() return { dockTo = "raidMarkers", side = "Below" } end
    raid.over = true
    tick()
    assert.same({ 20, 20 }, { lock().width, lock().height })
    raid.over, calls.over = false, true
    tick()
    assert.same({ 16, 16 }, { lock().width, lock().height })
  end)

  it("locks every unlocked panel again on Esc and when combat starts", function()
    calls.over = true
    tick()
    lock().scripts.OnClick(lock())
    local catcher
    for _, f in ipairs(tracker.all) do
      if f.name == "LittleThingsPanelUnlock" then catcher = f end
    end
    assert.is_true(catcher:IsShown())
    catcher:Hide()
    assert.is_false(Move.CanDrag("partyCalls"))
    lock().scripts.OnClick(lock())
    for _, f in ipairs(tracker.all) do
      if f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_REGEN_DISABLED") end
    end
    state.combat = false
    assert.is_false(Move.CanDrag("partyCalls"))
  end)

  it("marks every dock seam in the mode and keeps the name labels out of the seam", function()
    state.dockPanels = {
      raidMarkers = { spec = { root = true, frame = raid, get = function() return {} end } },
      partyCalls = { spec = { frame = calls, get = function() return { dockTo = "raidMarkers", side = "Below" } end } },
    }
    Move.Toggle()
    local seam
    for _, f in ipairs(tracker.all) do
      if f.name == "LittleThingsMoveSeampartyCalls" then seam = f end
    end
    assert.is_true(seam:IsShown())
    assert.same({ { "TOPLEFT", UIParent, "BOTTOMLEFT", 100, 438 } }, seam.points)
    assert.same({ 200, 1 }, { seam.width, seam.height })
    local function outline(id)
      for _, f in ipairs(tracker.all) do
        if f.name == "LittleThingsMoveOutline" .. id then return f end
      end
    end
    local calls, raid = outline("partyCalls"), outline("raidMarkers")
    assert.same({ false, true, true, true }, { calls.edges.top.shown, calls.edges.bottom.shown, calls.edges.left.shown, calls.edges.right.shown })
    assert.same({ true, false, true, true }, { raid.edges.top.shown, raid.edges.bottom.shown, raid.edges.left.shown, raid.edges.right.shown })
    assert.equals("TOPLEFT", tracker.text("Party calls").points[1][1])
    assert.equals("BOTTOMLEFT", tracker.text("Raid marker panel").points[1][1])
    Move.Toggle()
    assert.is_false(seam:IsShown())
  end)

  it("hides a hidden panel's outline in the mode", function()
    calls:Hide()
    Move.Toggle()
    assert.is_nil(tracker.text("Party calls"))
    assert.is_true(tracker.text("Raid marker panel").parentFrame:IsShown())
  end)
end)

describe("PanelMove with the Velvet dock", function()
  local function rectFrame(parent)
    local f = Frames.new(parent)
    function f:GetEffectiveScale() return 1 end
    function f:GetLeft() local p = self.points[1] return p and p[2]:GetLeft() + p[4] end
    function f:GetTop() local p = self.points[1] return p and p[2]:GetTop() + p[5] end
    function f:GetRight() return self:GetLeft() and self:GetLeft() + self.width end
    function f:GetBottom() return self:GetTop() and self:GetTop() - self.height end
    return f
  end

  it("draws one seam and hides the touching outline sides of a docked pair", function()
    local state = { printed = {}, log = {} }
    local Move, tracker, tick = load(state)
    _G.LibStub = nil
    UIParent.width, UIParent.height = 1920, 1080
    function UIParent:GetLeft() return 0 end
    Frames.loadVelvet()
    local lib = LibStub("LibVelvet-1.0")
    local raid, calls = rectFrame(UIParent), rectFrame(UIParent)
    raid.width, raid.height, calls.width, calls.height = 200, 60, 120, 40
    raid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
    calls:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -166)
    local callsDb = { dockTo = "raidMarkers", side = "Below", offset = 0 }
    lib.Dock.Register("raidMarkers", { frame = raid, root = true, get = function() return {} end, set = function() end,
      locked = function() return false end, merged = function() return false end })
    lib.Dock.Register("partyCalls", { frame = calls, get = function() return callsDb end, set = function() end,
      locked = function() return false end })
    Move.Register("raidMarkers", spec(state, "Raid marker panel", raid))
    Move.Register("partyCalls", spec(state, "Party calls", calls))
    Move.Toggle()
    tick()
    local function named(name)
      for _, f in ipairs(tracker.all) do
        if f.name == name then return f end
      end
    end
    assert.is_true(named("LittleThingsMoveSeampartyCalls"):IsShown())
    assert.is_false(named("LittleThingsMoveOutlinepartyCalls").edges.top.shown)
    assert.is_false(named("LittleThingsMoveOutlineraidMarkers").edges.bottom.shown)
  end)
end)
