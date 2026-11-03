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
  local ALL = { above = true, below = true, right = true, left = true }

  it("prefers above, then below, right and left", function()
    assert.equals("above", ns.PanelDock.ArrowSide({}, ALL))
    assert.equals("below", ns.PanelDock.ArrowSide({ above = true }, ALL))
    assert.equals("right", ns.PanelDock.ArrowSide({ above = true, below = true }, ALL))
    assert.equals("left", ns.PanelDock.ArrowSide({ above = true, below = true, right = true }, ALL))
  end)

  it("skips a side with no room on screen", function()
    assert.equals("below", ns.PanelDock.ArrowSide({}, { below = true, right = true }))
    assert.equals("right", ns.PanelDock.ArrowSide({ below = true }, { below = true, right = true }))
  end)

  it("returns nil when every side is blocked or off screen", function()
    assert.is_nil(ns.PanelDock.ArrowSide({ above = true, below = true }, { above = true, below = true }))
  end)
end)

local function frame(over)
  local f = { alpha = 1 }
  function f:IsShown() return true end
  function f:IsMouseOver() return over end
  function f:SetAlpha(a) self.alpha = a end
  return f
end

local function dockLib(panels, members)
  return { dock = { panels = panels }, Dock = {
    Hovered = function() return false end,
    Members = function(id) return members and members[id] or {} end,
  } }
end

describe("PanelDock.Blocked", function()
  local function blocked(side, id)
    local panels = {
      root = { spec = { root = true, get = function() return {} end } },
      member = { spec = { get = function() return { dockTo = side and "root", side = side } end } },
    }
    _G.LibStub = function() return dockLib(panels) end
    return ns.PanelDock.Blocked(id)
  end

  it("blocks the member's near edge and the root's far edge for each dock side", function()
    assert.same({ above = true }, blocked("Below", "member"))
    assert.same({ below = true }, blocked("Below", "root"))
    assert.same({ below = true }, blocked("Above", "member"))
    assert.same({ above = true }, blocked("Above", "root"))
    assert.same({ left = true }, blocked("Right", "member"))
    assert.same({ right = true }, blocked("Right", "root"))
    assert.same({ right = true }, blocked("Left", "member"))
    assert.same({ left = true }, blocked("Left", "root"))
  end)

  it("blocks nothing for an undocked or unregistered panel", function()
    assert.same({}, blocked(nil, "member"))
    assert.same({}, blocked(nil, "root"))
    assert.same({}, blocked("Below", "unknown"))
  end)
end)

describe("PanelDock.PlaceArrow", function()
  local function rect(left, top, w, h, scale)
    local f = { scale = scale or 1 }
    function f:GetLeft() return left end
    function f:GetTop() return top end
    function f:GetBottom() return top and top - h end
    function f:GetWidth() return w end
    function f:GetHeight() return h end
    function f:GetEffectiveScale() return 0.8 * self.scale end
    function f:IsShown() return true end
    return f
  end

  local function setup(side, rootFrame, memberFrame)
    _G.UIParent = { GetEffectiveScale = function() return 0.8 end, GetTop = function() return 1080 end,
      GetBottom = function() return 0 end, GetLeft = function() return 0 end, GetRight = function() return 1920 end }
    local panels = {
      root = { spec = { root = true, frame = rootFrame, get = function() return {} end } },
      member = { spec = { frame = memberFrame, get = function() return { dockTo = side and "root", side = side } end } },
    }
    _G.LibStub = function() return dockLib(panels, { root = { "member" } }) end
  end

  local function placed(id, panel, w, h)
    local arrow = { GetHeight = function() return 14 end, GetWidth = function() return 14 end,
      ClearAllPoints = function(self) self.points = {} end,
      SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end }
    ns.PanelDock.PlaceArrow(arrow, panel, id, w, h)
    return arrow.points
  end

  it("anchors above the top-right corner with a 2 px gap when nothing is docked", function()
    local panel = rect(100, 500, 200, 40)
    setup(nil, panel, rect(0, 0, 10, 10))
    assert.same({ { "BOTTOMRIGHT", panel, "TOPLEFT", 200, 2 } }, placed("root", panel))
  end)

  it("keeps a member docked below off the root's buttons and the root's arrow off the member", function()
    local root, member = rect(100, 500, 200, 40), rect(100, 454, 120, 40)
    setup("Below", root, member)
    assert.same({ { "TOPRIGHT", member, "TOPLEFT", 120, -42 } }, placed("member", member))
    assert.same({ { "BOTTOMRIGHT", root, "TOPLEFT", 200, 2 } }, placed("root", root))
  end)

  it("moves the root's arrow to the right at the screen top when a member is docked below", function()
    local root, member = rect(100, 1075, 200, 40), rect(100, 1029, 120, 40)
    setup("Below", root, member)
    assert.same({ { "TOPLEFT", root, "TOPLEFT", 202, 0 } }, placed("root", root))
  end)

  it("puts the root's arrow below when a member is docked above", function()
    local root, member = rect(100, 500, 200, 40), rect(100, 546, 120, 40)
    setup("Above", root, member)
    assert.same({ { "BOTTOMRIGHT", member, "TOPLEFT", 120, 2 } }, placed("member", member))
    assert.same({ { "TOPRIGHT", root, "TOPLEFT", 200, -42 } }, placed("root", root))
  end)

  it("keeps the arrows above for side docks, and below at the screen top", function()
    local root, member = rect(100, 500, 200, 40), rect(306, 500, 120, 40)
    setup("Right", root, member)
    assert.same({ { "BOTTOMRIGHT", member, "TOPLEFT", 120, 2 } }, placed("member", member))
    assert.same({ { "BOTTOMRIGHT", root, "TOPLEFT", 200, 2 } }, placed("root", root))
    root, member = rect(100, 1080, 200, 40), rect(0, 1080, 94, 40)
    setup("Left", root, member)
    assert.same({ { "TOPRIGHT", root, "TOPLEFT", 200, -42 } }, placed("root", root))
    assert.same({ { "TOPRIGHT", member, "TOPLEFT", 94, -42 } }, placed("member", member))
  end)

  it("anchors at the full size so a collapse does not move the arrow", function()
    local panel = rect(100, 500, 120, 34)
    setup(nil, panel, rect(0, 0, 10, 10))
    assert.same({ { "BOTTOMRIGHT", panel, "TOPLEFT", 292, 2 } }, placed("root", panel, 292, 60))
    setup("Above", panel, rect(100, 546, 120, 40))
    assert.same({ { "TOPRIGHT", panel, "TOPLEFT", 292, -62 } }, placed("root", panel, 292, 60))
  end)

  it("falls back to the group's outer edge when no side is free", function()
    local root, member = rect(0, 1080, 1920, 40), rect(0, 1040, 300, 40)
    setup("Below", root, member)
    assert.same({ { "TOPRIGHT", root, "TOPLEFT", 1920, -82 } }, placed("root", root))
    root, member = rect(0, 40, 1920, 40), rect(0, 80, 300, 40)
    setup("Above", root, member)
    assert.same({ { "BOTTOMRIGHT", root, "TOPLEFT", 1920, 42 } }, placed("root", root))
  end)

  it("works in screen units at a panel scale", function()
    local panel = rect(100, 520, 100, 20, 2)
    setup(nil, panel, rect(0, 0, 10, 10))
    assert.same({ { "BOTTOMRIGHT", panel, "TOPLEFT", 100, 2 } }, placed("root", panel))
    panel = rect(100, 530, 100, 20, 2)
    setup(nil, panel, rect(0, 0, 10, 10))
    assert.same({ { "TOPRIGHT", panel, "TOPLEFT", 100, -22 } }, placed("root", panel))
  end)

  it("falls back to above while the panel has no position", function()
    local panel = rect(nil, nil, 100, 20)
    setup(nil, panel, rect(0, 0, 10, 10))
    assert.same({ { "BOTTOMRIGHT", panel, "TOPLEFT", 100, 2 } }, placed("root", panel))
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
