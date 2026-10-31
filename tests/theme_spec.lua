-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
describe("settings theme from LibVelvet", function()
  local ns, UI

  setup(function()
    _G.strmatch = string.match
    local dir = "Libs/LibVelvet-1.0/"
    local f = assert(io.open(dir .. "lib.xml", "rb"))
    local xml = f:read("*a")
    f:close()
    for name in xml:gmatch('<Script file="([^"]+)"/>') do dofile(dir .. name) end
    UI = LibStub("LibVelvet-1.0")
    ns = { WidgetRules = {} }
    assert(loadfile("UI/Widgets.lua"))("LittleThings", ns)
  end)

  it("takes the soft tokens and keeps the old key names", function()
    local T = ns.Widgets.THEME
    assert.same({ 0.18, 0.20, 0.235, 1 }, T.border)
    assert.same({ 0.275, 0.295, 0.337, 1 }, T.control)
    assert.same({ 0.72, 0.74, 0.78 }, T.muted)
    for _, key in ipairs({ "bg", "panel", "border", "control", "gold", "text", "muted", "selected" }) do
      assert.is_table(T[key], key)
    end
  end)

  it("shares the library's flat backdrop with the raid marker panel", function()
    assert.equal(UI.FLAT, ns.Widgets.FLAT)
  end)
end)
