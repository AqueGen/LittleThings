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

  it("uses the frame mouse-over for an unregistered id", function()
    local f = frame(true)
    ns.PanelDock.Fade("unknown", f, { fade = true, fadeAlpha = 0 })
    assert.equals(1, f.alpha)
    assert.equals(0, hoveredCalls)
  end)
end)
