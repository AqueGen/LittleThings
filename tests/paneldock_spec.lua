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
