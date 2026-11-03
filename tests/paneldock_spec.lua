-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local ns = {}
local chunk = assert(loadfile("./Modules/PanelDock.lua"))
chunk("LittleThings", ns)

describe("PanelDock.FadeAlpha", function()
  it("uses the faded alpha when idle and fade is on", function()
    assert.equals(0, ns.PanelDock.FadeAlpha(false, { fade = true, fadeAlpha = 0 }))
  end)

  it("is opaque while hovered", function()
    assert.equals(1, ns.PanelDock.FadeAlpha(true, { fade = true, fadeAlpha = 0 }))
  end)

  it("is opaque when fade is off", function()
    assert.equals(1, ns.PanelDock.FadeAlpha(false, { fade = false, fadeAlpha = 0 }))
  end)

  it("is opaque while Move panels mode is on", function()
    assert.equals(1, ns.PanelDock.FadeAlpha(false, { fade = true, fadeAlpha = 0 }, true))
  end)
end)

describe("PanelDock.HandleAlpha", function()
  it("follows the panel's alpha but never drops below 0.35", function()
    assert.equals(1, ns.PanelDock.HandleAlpha(1))
    assert.equals(0.5, ns.PanelDock.HandleAlpha(0.5))
    assert.equals(0.35, ns.PanelDock.HandleAlpha(0.2))
    assert.equals(0.35, ns.PanelDock.HandleAlpha(0))
  end)
end)

describe("PanelDock.HandleShown", function()
  it("keeps the handle on the root and on every panel that is not merged", function()
    assert.is_true(ns.PanelDock.HandleShown(true, true))
    assert.is_true(ns.PanelDock.HandleShown(true, false))
    assert.is_true(ns.PanelDock.HandleShown(false, false))
    assert.is_false(ns.PanelDock.HandleShown(false, true))
  end)
end)

local function frame(over)
  local f = { alpha = 1 }
  function f:IsShown() return true end
  function f:IsMouseOver() return over end
  function f:SetAlpha(a) self.alpha = a end
  return f
end

describe("PanelDock.Hovered", function()
  local panels, lib
  local function panel(spec)
    spec.frame = spec.frame or frame(false)
    spec.get = spec.get or function() return spec.pos or {} end
    return { spec = spec }
  end

  before_each(function()
    panels = {
      root = panel({ root = true }),
      member = panel({ pos = { dockTo = "root" } }),
      other = panel({}),
    }
    lib = { dock = { panels = panels }, Dock = {
      Hovered = function() return false end,
      Members = function(id) return id == "root" and { "member" } or {} end,
    } }
    _G.LibStub = function() return lib end
  end)

  it("asks the dock for a registered panel, so any group member counts", function()
    lib.Dock.Hovered = function(id) return id == "member" end
    assert.is_true(ns.PanelDock.Hovered("member", panels.member.spec.frame))
    assert.is_false(ns.PanelDock.Hovered("root", panels.root.spec.frame))
  end)
end)

describe("PanelDock.GhostDrag", function()
  local Frames = dofile("tests/frames.lua")
  local state, panel, drag, calls

  before_each(function()
    state = { combat = false, can = true }
    calls = {}
    _G.UIParent = Frames.new()
    function UIParent:GetEffectiveScale() return 0.8 end
    state.created = {}
    _G.CreateFrame = function(_, name, parent)
      local f = Frames.new(parent)
      f.name = name
      state.created[#state.created + 1] = f
      return f
    end
    _G.InCombatLockdown = function() return state.combat end
    _G.GetCursorPosition = function() return 0, 0 end _G.IsMouseButtonDown = function() return true end
    state.target = Frames.new()
    function state.target:IsVisible() return true end
    function state.target:GetEffectiveScale() return 0.8 end
    function state.target:GetLeft() return 10 end
    function state.target:GetTop() return 20 end
    function state.target:GetRight() return 30 end
    function state.target:GetBottom() return 5 end
    _G.LibStub = function() return { dock = { panels = { raidMarkers = { spec = { frame = state.target } } } }, Dock = {
      Snap = function(id, rect)
        calls[#calls + 1] = { "Snap", id, rect and { rect.x, rect.y, rect.w, rect.h } }
        if rect then return state.snapTo[1], state.snapTo[2], state.tid, state.side end
        return 40, 60
      end,
      Drop = function(id) calls[#calls + 1] = { "Drop", id } end,
    } } end
    state.snapTo = { 40, 60 }
    function UIParent:GetLeft() return 0 end
    function UIParent:GetTop() return 1080 end
    state.cursor, state.down = { 0, 0 }, true
    _G.GetCursorPosition = function() return state.cursor[1], state.cursor[2] end
    _G.IsMouseButtonDown = function() return state.down end
    ns.PanelMove = { Moving = function() return false end,
      CanDrag = function(id) assert(id == "panelId") return state.can and not state.combat end,
      SeamRect = function(side, ghost, target)
        state.seamArgs = { side, ghost.l, ghost.t, ghost.r, ghost.b, target.l, target.t, target.r, target.b }
        return 8, 4, 24, 2
      end }
    panel = Frames.new()
    function panel:GetEffectiveScale() return 1.6 end
    function panel:GetLeft() return 100 end
    function panel:GetBottom() return 50 end
    function panel:GetTop() return 70 end
    panel.width, panel.height = 30, 20
  end)

  local function make(withSnap)
    drag = ns.PanelDock.GhostDrag("panelId", panel, { name = "TestMover",
      release = function(mover, deferred) calls[#calls + 1] = { "release", mover, deferred } end,
      snapped = withSnap and function(x, y) calls[#calls + 1] = { "snapped", x, y } end or nil,
      after = function() calls[#calls + 1] = { "after" } end })
    function drag.mover:StartMoving() self.moving = true end
    function drag.mover:StopMovingOrSizing() self.moving = false end
    return drag
  end

  it("builds one hidden gold mover on UIParent per panel", function()
    make(true)
    assert.equals("TestMover", drag.mover.name)
    assert.equals("TOOLTIP", drag.mover.strata)
    assert.equals(UIParent, drag.mover.parentFrame)
    assert.is_false(drag.mover.shown)
  end)

  it("refuses to start while locked or in combat", function()
    make(true)
    state.can = false
    drag.Start()
    assert.is_false(drag.mover.shown)
    state.can, state.combat = true, true
    drag.Start()
    assert.is_false(drag.mover.shown)
    assert.is_false(drag.active)
  end)

  it("moves only the mover over the panel's screen rect", function()
    make(true)
    drag.Start()
    assert.is_true(drag.mover.shown)
    assert.equals(drag.Follow, drag.mover.scripts.OnUpdate)
    assert.same({ 60, 40 }, { drag.mover.width, drag.mover.height })
    assert.same({ { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 100 } }, drag.mover.points)
    assert.same({}, panel.points)
  end)

  local function seamFrame()
    for _, f in ipairs(state.created) do
      if f.name == "LittleThingsDockSeam" then return f end
    end
  end

  it("moves the ghost with the cursor and snaps it live, never the panel", function()
    make(true)
    drag.Start()
    state.cursor = { 80, 80 }
    drag.mover.scripts.OnUpdate(drag.mover)
    assert.same({ "Snap", "panelId", { 300, 840, 60, 40 } }, calls[1])
    assert.same({ { "TOPLEFT", UIParent, "BOTTOMLEFT", 40, 1020 } }, drag.mover.points)
    assert.same({}, panel.points)
    drag.mover.scripts.OnUpdate(drag.mover)
    assert.equals(1, #calls)
  end)

  it("draws the gold seam only while the ghost would dock, and hides it on release", function()
    make(true)
    drag.Start()
    state.cursor, state.tid, state.side = { 80, 80 }, "raidMarkers", "Below"
    drag.mover.scripts.OnUpdate(drag.mover)
    local seam = seamFrame()
    assert.is_true(seam.shown)
    assert.same({ "Below", 40, 1020, 100, 980, 10, 20, 30, 5 }, state.seamArgs)
    assert.same({ { "TOPLEFT", UIParent, "BOTTOMLEFT", 8, 4 } }, seam.points)
    assert.same({ 16, 2 }, { seam.width, seam.height })
    state.cursor, state.tid, state.side = { 90, 90 }, nil, nil
    drag.mover.scripts.OnUpdate(drag.mover)
    assert.is_false(seam.shown)
    state.cursor, state.tid, state.side = { 80, 80 }, "raidMarkers", "Below"
    drag.mover.scripts.OnUpdate(drag.mover)
    assert.is_true(seam.shown)
    drag.Stop()
    assert.is_false(seam.shown)
  end)

  it("ends the drag when the mouse button is up", function()
    make(true)
    drag.Start()
    state.down = false
    drag.mover.scripts.OnUpdate(drag.mover)
    assert.is_false(drag.active)
    assert.is_nil(drag.mover.scripts.OnUpdate)
  end)

  it("places at the mover on release, then snaps and drops, and hides the mover", function()
    make(true)
    drag.Start()
    drag.Stop()
    assert.same({ { "release", drag.mover, false }, { "Snap", "panelId" }, { "snapped", 40, 60 }, { "Drop", "panelId" }, { "after" } }, calls)
    assert.is_false(drag.mover.shown)
    assert.is_false(drag.active)
    drag.Stop()
    assert.equals(5, #calls)
  end)

  it("only places, without snap or drop, when the drag ends by hiding or in combat, or has no dock", function()
    make(true)
    drag.Start()
    drag.Stop(true)
    assert.same({ { "release", drag.mover, true }, { "after" } }, calls)
    calls = {}
    drag.Start()
    state.combat = true
    drag.Stop()
    assert.same({ { "release", drag.mover, true }, { "after" } }, calls)
    state.combat, calls = false, {}
    make(false)
    drag.Start()
    drag.Stop()
    assert.same({ { "release", drag.mover, false }, { "after" } }, calls)
  end)
end)

describe("PanelDock.Fade", function()
  local merged, tick, hoveredCalls

  before_each(function()
    merged = frame(false)
    hoveredCalls = 0
    local lib = { dock = { panels = { known = { spec = { root = true, frame = frame(false), get = function() return {} end } } } }, Dock = {
      MergeFrame = function() return merged end,
      Hovered = function() hoveredCalls = hoveredCalls + 1 return false end,
      Members = function() return {} end,
    } }
    _G.LibStub = function() return lib end
    _G.InCombatLockdown = function() return false end
    _G.C_Timer = { NewTicker = function(_, fn) tick = fn return { Cancel = function() end } end }
  end)

  it("fades the panel and the merged background at once", function()
    local f = frame(false)
    ns.PanelDock.Fade("known", f, { fade = true, fadeAlpha = 0.25 })
    assert.equals(0.25, f.alpha)
    assert.equals(0.25, merged.alpha)
  end)

  it("restores both to 1 when fade is turned off", function()
    local f = frame(false)
    ns.PanelDock.Fade("known", f, { fade = true, fadeAlpha = 0 })
    ns.PanelDock.Fade("known", f, { fade = false })
    assert.equals(1, f.alpha)
    assert.equals(1, merged.alpha)
  end)

  it("fades the fold handle with the panel down to its floor", function()
    local f = frame(false)
    f.foldHandle = frame(false)
    ns.PanelDock.Fade("known", f, { fade = true, fadeAlpha = 0 })
    assert.equals(0, f.alpha)
    assert.equals(0.35, f.foldHandle.alpha)
    ns.PanelDock.Fade("known", f, { fade = true, fadeAlpha = 0.6 })
    assert.equals(0.6, f.foldHandle.alpha)
    ns.PanelDock.Fade("known", f, { fade = false })
    assert.equals(1, f.foldHandle.alpha)
  end)

  it("counts the hover part of an unregistered frame, so icons past the frame keep it shown", function()
    local f = frame(false)
    f.hoverPart = frame(true)
    ns.PanelDock.Fade("unknown", f, { fade = true, fadeAlpha = 0 })
    assert.equals(1, f.alpha)
  end)

  it("uses the frame mouse-over for an unregistered id", function()
    local f = frame(true)
    ns.PanelDock.Fade("unknown", f, { fade = true, fadeAlpha = 0 })
    assert.equals(1, f.alpha)
    assert.equals(0, hoveredCalls)
  end)
end)

describe("PanelDock.GhostDrag with the Velvet dock", function()
  local Frames = dofile("tests/frames.lua")

  local function rectFrame(parent)
    local f = Frames.new(parent)
    function f:GetEffectiveScale() return 1 end
    function f:GetNumPoints() return #self.points end
    function f:GetLeft()
      local p = self.points[1]
      if not p then return nil end
      local rel = p[2]
      local x = rel:GetLeft() + (p[3]:find("RIGHT") and rel:GetWidth() or 0) + p[4]
      return x - (p[1]:find("RIGHT") and self.width or 0)
    end
    function f:GetTop()
      local p = self.points[1]
      if not p then return nil end
      local rel = p[2]
      local y = rel:GetTop() - (p[3]:find("BOTTOM") and rel:GetHeight() or 0) + p[5]
      return y + (p[1]:find("BOTTOM") and self.height or 0)
    end
    function f:GetBottom() return self:GetTop() and self:GetTop() - self.height end
    function f:GetRight() return self:GetLeft() and self:GetLeft() + self.width end
    return f
  end

  it("docks a member released 10 px below the root's bottom edge", function()
    _G.LibStub = nil
    _G.UIParent = Frames.new()
    UIParent.width, UIParent.height = 1920, 1080
    function UIParent:GetEffectiveScale() return 1 end
    function UIParent:GetLeft() return 0 end
    function UIParent:GetTop() return 1080 end
    _G.CreateFrame = function(_, _, parent) return rectFrame(parent) end
    _G.InCombatLockdown = function() return false end
    _G.GetCursorPosition = function() return 0, 0 end _G.IsMouseButtonDown = function() return true end
    Frames.loadVelvet()
    local lib = LibStub("LibVelvet-1.0")
    local root, member = rectFrame(UIParent), rectFrame(UIParent)
    root.width, root.height, member.width, member.height = 200, 60, 120, 40
    root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
    member:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -600)
    local rootDb, memberDb = {}, {}
    lib.Dock.Register("raidMarkers", { frame = root, root = true, get = function() return rootDb end, set = function() end,
      locked = function() return false end, merged = function() return false end })
    lib.Dock.Register("partyCalls", { frame = member, get = function() return memberDb end, set = function() end,
      locked = function() return false end })
    ns.PanelMove = { Moving = function() return false end, CanDrag = function() return true end }
    local function placeAt(x, y)
      member:ClearAllPoints()
      member:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -y)
    end
    local drag = ns.PanelDock.GhostDrag("partyCalls", member, {
      release = function(m) placeAt(m:GetLeft() - UIParent:GetLeft(), UIParent:GetTop() - m:GetTop()) end, snapped = placeAt })
    drag.Start()
    drag.mover:ClearAllPoints()
    drag.mover:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 110, -170)
    drag.Stop()
    assert.same({ "raidMarkers", "Below" }, { memberDb.dockTo, memberDb.side })
    assert.equals(root, member.points[1][2])
    assert.same({ 100, 1080 - 166 }, { member:GetLeft(), member:GetTop() })
  end)

  it("docks a member released on top of the root to the root's nearest edge", function()
    _G.LibStub = nil
    _G.UIParent = Frames.new()
    UIParent.width, UIParent.height = 1920, 1080
    function UIParent:GetEffectiveScale() return 1 end
    function UIParent:GetLeft() return 0 end
    function UIParent:GetTop() return 1080 end
    _G.CreateFrame = function(_, _, parent) return rectFrame(parent) end
    _G.InCombatLockdown = function() return false end
    _G.GetCursorPosition = function() return 0, 0 end _G.IsMouseButtonDown = function() return true end
    Frames.loadVelvet()
    local lib = LibStub("LibVelvet-1.0")
    local root, member = rectFrame(UIParent), rectFrame(UIParent)
    root.width, root.height, member.width, member.height = 200, 60, 120, 40
    root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
    member:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -600)
    local memberDb = {}
    lib.Dock.Register("raidMarkers", { frame = root, root = true, get = function() return {} end, set = function() end,
      locked = function() return false end, merged = function() return false end })
    lib.Dock.Register("partyCalls", { frame = member, get = function() return memberDb end, set = function() end,
      locked = function() return false end })
    ns.PanelMove = { Moving = function() return false end, CanDrag = function() return true end }
    local function placeAt(x, y)
      member:ClearAllPoints()
      member:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -y)
    end
    local drag = ns.PanelDock.GhostDrag("partyCalls", member, {
      release = function(m) placeAt(m:GetLeft() - UIParent:GetLeft(), UIParent:GetTop() - m:GetTop()) end, snapped = placeAt })
    drag.Start()
    drag.mover:ClearAllPoints()
    drag.mover:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -120)
    drag.Stop()
    assert.same({ "raidMarkers", "Below", 20 }, { memberDb.dockTo, memberDb.side, memberDb.offset })
    assert.equals(1080 - 166, member:GetTop())
  end)
end)

describe("PanelDock.Options merge", function()
  local panels, members, checks

  local function options(db, id)
    checks = {}
    local group = {}
    function group:Check(spec) checks[spec.label] = spec end
    function group:Button() end
    ns.PanelDock.Options({ Group = function() return group end }, db, function() checks.applied = true end, id)
    return checks["Merge with docked panels"]
  end

  before_each(function()
    local rootDb = { merge = false }
    panels = {
      raidMarkers = { spec = { root = true, get = function() return rootDb end } },
      partyCalls = { spec = { get = function() return panels.partyCallsDb end } },
    }
    members = {}
    _G.InCombatLockdown = function() return false end
    _G.LibStub = function() return { dock = { panels = panels }, Dock = {
      Members = function(id) return members[id] or {} end,
      Undock = function() end,
    } } end
  end)

  it("reads and writes the group root's merge from a docked member's page", function()
    panels.partyCallsDb = { dockTo = "raidMarkers", side = "Below", merge = false }
    local merge = options(panels.partyCallsDb, "partyCalls")
    assert.is_true(merge.enabled())
    assert.is_false(merge.get())
    merge.set(true)
    assert.is_true(panels.raidMarkers.spec.get().merge)
    assert.is_false(panels.partyCallsDb.merge)
    assert.is_true(merge.get())
    assert.is_true(checks.applied)
  end)

  it("is enabled on a root page with members and works on its own db", function()
    members.raidMarkers = { "partyCalls" }
    local db = panels.raidMarkers.spec.get()
    local merge = options(db, "raidMarkers")
    assert.is_true(merge.enabled())
    merge.set(true)
    assert.is_true(db.merge)
  end)

  it("is disabled with a dock-first line only for a panel neither docked nor with members", function()
    panels.partyCallsDb = {}
    local merge = options(panels.partyCallsDb, "partyCalls")
    assert.is_false(merge.enabled())
    assert.is_truthy(merge.tooltip():find("Dock this panel to another one first.", 1, true))
    panels.partyCallsDb.dockTo = "raidMarkers"
    assert.is_nil(merge.tooltip():find("Dock this panel", 1, true))
    panels.raidMarkers = nil
    assert.is_false(merge.enabled())
  end)
end)
