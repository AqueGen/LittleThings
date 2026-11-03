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
  local ns = { Widgets = { FLAT = { bgFile = "flat" } }, Print = function(text) state.printed[#state.printed + 1] = text end }
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
  local s = { name = name, frame = function() return frame end, calls = {} }
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

describe("PanelMove.LockSide", function()
  local Move = load({ printed = {} })

  it("puts the lock above the panel's top-left corner, below it at the screen top", function()
    assert.equals("above", Move.LockSide(1000, 1080))
    assert.equals("above", Move.LockSide(1066, 1080))
    assert.equals("below", Move.LockSide(1070, 1080))
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
    assert.same({ { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 434 } }, icon.points)
    icon.scripts.OnClick(icon)
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

  it("puts the lock below the panel at the screen top", function()
    local top = panel({ 10, 1078, 200, 1000 })
    Move.Register("saveIndicator", spec(state, "Save indicator", top))
    top.over = true
    tick()
    assert.same({ { "TOPLEFT", UIParent, "BOTTOMLEFT", 10, 1000 } }, lock().points)
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

  it("hides a hidden panel's outline in the mode", function()
    calls:Hide()
    Move.Toggle()
    assert.is_nil(tracker.text("Party calls"))
    assert.is_true(tracker.text("Raid marker panel").parentFrame:IsShown())
  end)
end)
