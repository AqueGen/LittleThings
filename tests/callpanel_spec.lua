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
    return f
  end

  before_each(function()
    state = { combat = false, applied = {}, arrows = 0 }
    rootChanges = 0
    rootFrame = newFrame()
    rootFrame.scale = 2
    db = { scale = 1, posX = 300, posY = 400, calls = {}, bgAlpha = 0.6, border = true }
    _G.UIParent = newFrame()
    _G.InCombatLockdown = function() return state.combat end
    _G.CreateFrame = function(_, _, parent) return newFrame(parent) end
    local lib
    lib = { dock = { panels = {
      raidMarkers = { spec = { root = true, frame = rootFrame, get = function() return {} end,
        onChange = function() rootChanges = rootChanges + 1 end } },
    } }, Dock = {
      Register = function(id, spec) lib.dock.panels[id] = { spec = spec } end,
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
      Arrow = function(parent)
        local arrow = newFrame(parent)
        function arrow:SetCollapsed() end
        return arrow
      end,
    } }
    _G.LibStub = function() return lib end
    ns = {
      db = { partyCallOptions = db },
      Widgets = { FLAT = { bgFile = "flat" } },
      CallRules = { Grid = function() return {}, 0, 0, "TOPLEFT" end },
      PanelDock = { PlaceArrow = function(_, _, id) state.arrows = state.arrows + 1 state.arrowId = id end },
    }
    assert(loadfile("./Modules/PartyCalls/CallPanel.lua"))("LittleThings", ns)
    Panel = ns.PartyCallPanel
  end)

  local function build()
    Panel.Build(function() end, function() end)
    return Panel.panel
  end

  it("places a fresh docked panel at its saved corner when built in combat", function()
    db.dockTo, db.side = "raidMarkers", "Below"
    state.combat = true
    local panel = build()
    assert.same({ { "TOPLEFT", UIParent, "BOTTOMLEFT", 300, 400 } }, panel.points)
    assert.same({ 300, 400 }, { db.posX, db.posY })
    assert.equals(1, state.arrows)
    assert.equals("partyCalls", state.arrowId)
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
    assert.equals(2, state.arrows)
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

  it("tells the root when it docks, changes side or undocks so the root's arrow can move", function()
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
