-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
describe("Core defaults", function()
  it("give every module switch a saved default, so New in LittleThings shows it once", function()
    _G.StaticPopupDialogs = {}
    _G.CreateFrame = function()
      return { RegisterEvent = function() end, SetScript = function() end }
    end
    local ns = {}
    assert(loadfile("Core.lua"))("LittleThings", ns)

    for _, row in ipairs(ns.MODULES) do
      assert.is_not_nil(ns.defaults[row.key], row.key)
    end
  end)
end)
