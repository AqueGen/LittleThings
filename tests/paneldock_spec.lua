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
end)

describe("PanelDock.ArrowSide", function()
  it("puts the arrow above when there is room under the screen top", function()
    assert.equals("above", ns.PanelDock.ArrowSide(1000, 1080, 16))
    assert.equals("above", ns.PanelDock.ArrowSide(1064, 1080, 16))
  end)
  it("puts the arrow below when the panel top is within the arrow height and gap of the screen top", function()
    assert.equals("below", ns.PanelDock.ArrowSide(1065, 1080, 16))
    assert.equals("below", ns.PanelDock.ArrowSide(1080, 1080, 16))
  end)
  it("falls back to above while the panel has no position", function()
    assert.equals("above", ns.PanelDock.ArrowSide(nil, 1080, 16))
  end)
end)

local function frame(over)
  local f = { alpha = 1 }
  function f:IsShown() return true end
  function f:IsMouseOver() return over end
  function f:SetAlpha(a) self.alpha = a end
  return f
end

describe("PanelDock.PlaceArrow", function()
  local function placed(top, scale)
    _G.UIParent = { GetEffectiveScale = function() return 0.8 end, GetTop = function() return 1080 end }
    local panel = { GetTop = function() return top end, GetEffectiveScale = function() return 0.8 * scale end }
    local arrow = { GetHeight = function() return 14 end, ClearAllPoints = function(self) self.points = {} end,
      SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end }
    ns.PanelDock.PlaceArrow(arrow, panel)
    return arrow.points, panel
  end

  it("anchors the arrow above the top-right corner with a 2 px gap", function()
    local points, panel = placed(500, 1)
    assert.same({ { "BOTTOMRIGHT", panel, "TOPRIGHT", 0, 2 } }, points)
  end)

  it("anchors the arrow below the bottom-right corner at the top of the screen, in screen units", function()
    local points, panel = placed(1070, 1)
    assert.same({ { "TOPRIGHT", panel, "BOTTOMRIGHT", 0, -2 } }, points)
    points, panel = placed(520, 2)
    assert.same({ { "BOTTOMRIGHT", panel, "TOPRIGHT", 0, 2 } }, points)
    points, panel = placed(530, 2)
    assert.same({ { "TOPRIGHT", panel, "BOTTOMRIGHT", 0, -2 } }, points)
  end)
end)

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

  it("counts a member's arrow as hovering the whole group", function()
    panels.member.spec.frame.dockArrow = frame(true)
    assert.is_true(ns.PanelDock.Hovered("root", panels.root.spec.frame))
    assert.is_true(ns.PanelDock.Hovered("member", panels.member.spec.frame))
    assert.is_false(ns.PanelDock.Hovered("other", panels.other.spec.frame))
  end)

  it("counts the root's arrow for a member", function()
    panels.root.spec.frame.dockArrow = frame(true)
    assert.is_true(ns.PanelDock.Hovered("member", panels.member.spec.frame))
  end)

  it("stops at a cycle in saved dock state", function()
    panels.member.spec.pos = { dockTo = "other" }
    panels.other.spec.pos = { dockTo = "member" }
    assert.is_false(ns.PanelDock.Hovered("member", panels.member.spec.frame))
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

  it("stays opaque while the mouse is on the panel's collapse arrow outside it", function()
    local f = frame(false)
    f.dockArrow = frame(true)
    LibStub().dock.panels.known.spec.frame = f
    ns.PanelDock.Fade("known", f, { fade = true, fadeAlpha = 0 })
    assert.equals(1, f.alpha)
  end)

  it("uses the frame mouse-over for an unregistered id", function()
    local f = frame(true)
    ns.PanelDock.Fade("unknown", f, { fade = true, fadeAlpha = 0 })
    assert.equals(1, f.alpha)
    assert.equals(0, hoveredCalls)
  end)
end)
