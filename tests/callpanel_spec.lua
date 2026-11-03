-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")

describe("PartyCallPanel docking", function()
  local ns, Panel, state, db, rootFrame, rootChanges

  local function newFrame(parent)
    local f = Frames.new(parent)
    f.clears = 0
    function f:ClearAllPoints() self.points = {} self.clears = self.clears + 1 end
    function f:GetNumPoints() return #self.points end
    function f:GetScale() return self.scale or 1 end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetRight() return self.left and self.left + 100 end
    function f:GetBottom() return self.top and self.top - 50 end
    function f:SetBackdrop(b) self.backdrop = b end
    function f:GetEffectiveScale() return self.scale or 1 end
    return f
  end

  before_each(function()
    state = { combat = false, applied = {}, rootDb = {}, dockCalls = {}, snapTo = { 0, 0 }, canDrag = true }
    rootChanges = 0
    rootFrame = newFrame()
    rootFrame.scale = 2
    db = { scale = 1, posX = 300, posY = 400, calls = {}, bgAlpha = 0.6, border = true, iconSize = 32, labels = true, gap = 4, pad = 4 }
    _G.UIParent = newFrame()
    _G.InCombatLockdown = function() return state.combat end
    _G.GetCursorPosition = function() return 0, 0 end _G.IsMouseButtonDown = function() return true end
    _G.CreateFrame = function(_, name, parent)
      local f = newFrame(parent)
      f.name = name
      return f
    end
    local lib
    lib = { dock = { panels = {
      raidMarkers = { spec = { root = true, frame = rootFrame, get = function() return state.rootDb end,
        onChange = function() rootChanges = rootChanges + 1 end } },
    } }, Dock = {
      Register = function(id, spec) lib.dock.panels[id] = { spec = spec } end,
      Snap = function(id) state.dockCalls[#state.dockCalls + 1] = { "Snap", id } return state.snapTo[1], state.snapTo[2] end,
      Drop = function(id) state.dockCalls[#state.dockCalls + 1] = { "Drop", id, posX = db.posX } end,
      Merged = function() return state.merged == true end,
      MergeFrame = function() return state.mergeFrame end,
      Apply = function(id)
        state.applied[#state.applied + 1] = { id, combat = state.combat }
        if state.combat or not db.dockTo then return end
        local panel = lib.dock.panels[id].spec.frame
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", rootFrame, "BOTTOMLEFT", 0, -6)
        panel.left, panel.top = state.dockedAt[1], state.dockedAt[2]
      end,
    }, T = { muted = { 0.7, 0.7, 0.7 }, gold = { 1, 0.82, 0 }, divider = { 0.2, 0.2, 0.2, 1 } } }
    _G.LibStub = function() return lib end
    ns = {
      db = { partyCallOptions = db },
      Widgets = { FLAT = { bgFile = "flat" } },
      CallRules = { Grid = function(_, o) state.grid = o return {}, 0, state.gridH or 0, "TOPLEFT" end },
    }
    assert(loadfile("./Modules/PanelDock.lua"))("LittleThings", ns)
    ns.PanelMove = { Moving = function() return state.moving == true end, CanDrag = function() return state.canDrag and not state.combat end }
    assert(loadfile("./Modules/PartyCalls/CallPanel.lua"))("LittleThings", ns)
    Panel = ns.PartyCallPanel
  end)

  local function build()
    state.changes = 0
    Panel.Build(function() end, function() state.changes = state.changes + 1 end)
    return Panel.panel
  end

  it("drags a gold ghost, not the panel, and on release places, snaps, saves the corner before Drop, then docks", function()
    local panel = build()
    UIParent.left, UIParent.top = 0, 1080
    panel.left, panel.top = 300, 400
    local before = #panel.points
    panel.scripts.OnDragStart(panel)
    local mover = Panel.drag.mover
    assert.equals("LittleThingsPartyCallsMover", mover.name)
    assert.is_true(mover.shown)
    assert.equals(before, #panel.points)
    function mover:GetLeft() return 120 end
    function mover:GetTop() return 900 end
    state.snapTo = { 126, 186 }
    panel.scripts.OnDragStop(panel)
    assert.is_false(mover.shown)
    assert.same({ "Snap", "partyCalls" }, state.dockCalls[1])
    assert.equals("Drop", state.dockCalls[2][1])
    assert.is_number(state.dockCalls[2].posX)
    assert.is_false(Panel.drag.active)
  end)

  it("keeps a docked member on its dock spot when the drag ends in combat", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.dockedAt = { 500, 700 }
    local panel = build()
    panel.scripts.OnDragStart(panel)
    local mover = Panel.drag.mover
    function mover:GetLeft() return 120 end
    function mover:GetTop() return 900 end
    state.combat = true
    panel.scripts.OnDragStop(panel)
    assert.same({ { "TOPLEFT", rootFrame, "BOTTOMLEFT", 0, -6 } }, panel.points)
    assert.equals("raidMarkers", db.dockTo)
    assert.same({ 500, 700 }, { db.posX, db.posY })
    assert.is_false(mover.shown)
  end)

  it("does not start a ghost drag while locked", function()
    local panel = build()
    panel.left, panel.top = 300, 400
    state.canDrag = false
    panel.scripts.OnDragStart(panel)
    assert.is_false(Panel.drag.mover.shown)
  end)

  it("builds a plain fold handle as a strip inside the left edge, as tall as the panel", function()
    local panel = build()
    local handle = Panel.handle
    assert.equals(panel, handle.parentFrame)
    assert.equals(handle, panel.foldHandle)
    assert.same({ { "TOPLEFT", panel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", panel, "BOTTOMLEFT", 18, 0 } }, handle.points)
    assert.same({ { "CENTER", handle, "CENTER", 0, -8 } }, Panel.glyph.points)
    assert.equals("-", Panel.glyph.text)
    Panel.Layout({})
    assert.equals(18, state.grid.strip)
  end)

  it("folds its labels away on a click of its own handle and shows + while folded", function()
    build()
    Panel.Update()
    Panel.Layout({})
    assert.equals(32 + 2 + 12, state.grid.cellH)
    Panel.handle.scripts.OnClick(Panel.handle)
    assert.is_true(db.collapsed)
    assert.equals(1, state.changes)
    Panel.Update()
    Panel.Layout({})
    assert.equals(32, state.grid.cellH)
    assert.is_true(Panel.handle:IsShown())
    assert.equals("+", Panel.glyph.text)
  end)

  it("drops its handle and strip while merged with a shown root and folds with the root's handle", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.dockedAt = { 500, 700 }
    build()
    state.merged = true
    state.rootDb.collapsed = true
    Panel.Update()
    Panel.Layout({})
    assert.is_false(Panel.handle:IsShown())
    assert.equals(0, state.grid.strip)
    assert.equals(32, state.grid.cellH)
    state.rootDb.collapsed = false
    db.collapsed = true
    Panel.Layout({})
    assert.equals(32 + 2 + 12, state.grid.cellH)
    rootFrame:Hide()
    Panel.Update()
    Panel.Layout({})
    assert.is_true(Panel.handle:IsShown())
    assert.equals(18, state.grid.strip)
    assert.equals(32, state.grid.cellH)
  end)

  it("hands its lock to the root while merged with a shown root", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.dockedAt = { 500, 700 }
    build()
    assert.is_nil(Panel.MergedOwner())
    state.merged = true
    assert.equals("raidMarkers", Panel.MergedOwner())
    rootFrame:Hide()
    assert.is_nil(Panel.MergedOwner())
  end)

  it("keeps its merged layout in combat when the merged background hides", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.dockedAt = { 500, 700 }
    build()
    state.merged, state.mergeFrame = true, {}
    Panel.Update()
    Panel.Layout({})
    state.combat, state.mergeFrame = true, nil
    Panel.Update()
    Panel.Layout({})
    assert.is_false(Panel.handle:IsShown())
    assert.equals(0, state.grid.strip)
    assert.equals(ns.Widgets.FLAT, Panel.panel.backdrop)
  end)

  it("places a fresh docked panel at its saved corner when built in combat", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.combat = true
    local panel = build()
    assert.same({ { "TOPLEFT", UIParent, "BOTTOMLEFT", 300, 400 } }, panel.points)
    assert.same({ 300, 400 }, { db.posX, db.posY })
  end)

  it("leaves a docked panel's points alone in combat once it has them", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.dockedAt = { 500, 700 }
    local panel = build()
    local clears = panel.clears
    state.combat = true
    Panel.Place()
    assert.equals(clears, panel.clears)
    assert.same({ { "TOPLEFT", rootFrame, "BOTTOMLEFT", 0, -6 } }, panel.points)
  end)

  it("drops its own border in Move panels mode, where the gold outline takes over", function()
    local panel = build()
    function panel:SetBackdropBorderColor(...) self.borderColor = { ... } end
    Panel.Update()
    assert.equals(1, panel.borderColor[4])
    state.moving = true
    Panel.Update()
    assert.equals(0, panel.borderColor[4])
  end)

  it("keeps the fold glyph inside a short panel's strip", function()
    build()
    state.gridH = 20
    Panel.Layout({})
    assert.same({ { "CENTER", Panel.handle, "CENTER", 0, -5 } }, Panel.glyph.points)
    state.gridH = 80
    Panel.Layout({})
    assert.same({ { "CENTER", Panel.handle, "CENTER", 0, -8 } }, Panel.glyph.points)
  end)

  it("wires mouse-down on the panel, the handle and the call buttons so pre-drag movement counts", function()
    local panel = build()
    assert.is_function(panel.scripts.OnMouseDown)
    assert.is_function(Panel.handle.scripts.OnMouseDown)
  end)

  it("keeps its own background while the merged background is not shown", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.merged, state.dockedAt = true, { 500, 700 }
    local panel = build()
    Panel.Update()
    assert.equals(ns.Widgets.FLAT, panel.backdrop)
    state.mergeFrame = {}
    Panel.Update()
    assert.is_nil(panel.backdrop)
  end)

  it("takes the root's scale only while merged with a shown root", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.merged, state.dockedAt = true, { 500, 700 }
    rootFrame:Hide()
    local panel = build()
    assert.equals(1, panel.scale)
    rootFrame:Show()
    Panel.Place()
    assert.equals(2, panel.scale)
    state.merged = false
    Panel.Place()
    assert.equals(1, panel.scale)
  end)

  it("saves the docked corner out of combat as its own-scale fallback", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.dockedAt = { 500, 700 }
    build()
    assert.same({ 500, 700 }, { db.posX, db.posY })
    state.dockedAt = { 520, 650 }
    Panel.Place()
    assert.same({ 520, 650 }, { db.posX, db.posY })
    state.merged = true
    state.dockedAt = { 260, 325 }
    Panel.Place()
    assert.same({ 520, 650 }, { db.posX, db.posY })
    state.combat = true
    state.dockedAt = { 1, 1 }
    Panel.Place()
    assert.same({ 520, 650 }, { db.posX, db.posY })
  end)

  it("tells the root when it docks, changes side or undocks so the root can repaint", function()
    state.dockedAt = { 500, 700 }
    build()
    assert.equals(0, rootChanges)
    db.dockTo, db.side = "raidMarkers", "Below"
    Panel.Place()
    assert.equals(1, rootChanges)
    Panel.Place()
    assert.equals(1, rootChanges)
    db.side = "Above"
    Panel.Place()
    assert.equals(2, rootChanges)
    db.dockTo, db.side = nil, nil
    Panel.Place()
    assert.equals(3, rootChanges)
  end)
end)
