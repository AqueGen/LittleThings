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

describe("PanelDock.Fade", function()
  local merged, tick, hoveredCalls
  local function frame(over)
    local f = { alpha = 1 }
    function f:IsShown() return true end
    function f:IsMouseOver() return over end
    function f:SetAlpha(a) self.alpha = a end
    return f
  end

  before_each(function()
    merged = frame(false)
    hoveredCalls = 0
    local lib = { dock = { panels = { known = {} } }, Dock = {
      MergeFrame = function() return merged end,
      Hovered = function() hoveredCalls = hoveredCalls + 1 return false end,
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
