package.path = "./Modules/Performance/?.lua;" .. package.path

local Preset = require("GraphicsPreset")

local targets = {
  { cvar = "shadow", value = "1" },
  { cvar = "ssao", value = "0" },
  { cvar = "clutter", value = "0" },
}

local function Reader(values)
  return function(cvar) return values[cvar] end
end

describe("Preset.Changes", function()
  it("lists only the settings that differ from the target, in list order", function()
    local changes = Preset.Changes(targets, Reader({ shadow = "3", ssao = "0", clutter = "7" }))
    assert.same({
      { cvar = "shadow", from = "3", to = "1" },
      { cvar = "clutter", from = "7", to = "0" },
    }, changes)
  end)

  it("is empty when everything is already at the target", function()
    assert.same({}, Preset.Changes(targets, Reader({ shadow = "1", ssao = "0", clutter = "0" })))
  end)

  it("skips a setting the client does not know", function()
    local changes = Preset.Changes(targets, Reader({ shadow = "1", ssao = "0" }))
    assert.same({}, changes)
  end)
end)

describe("Preset.Remember", function()
  it("takes the current values when there is no backup yet", function()
    local backup = Preset.Remember(nil, targets, Reader({ shadow = "3", ssao = "2", clutter = "7" }))
    assert.same({ shadow = "3", ssao = "2", clutter = "7" }, backup)
  end)

  it("keeps what an earlier optimize saved and only adds settings it did not have", function()
    local backup = Preset.Remember({ shadow = "4" }, targets, Reader({ shadow = "1", ssao = "0", clutter = "0" }))
    assert.same({ shadow = "4", ssao = "0", clutter = "0" }, backup)
  end)
end)

describe("Preset.Restores", function()
  it("brings back the saved values that differ from the current ones", function()
    local changes = Preset.Restores({ shadow = "3", ssao = "0", clutter = "7" }, targets,
      Reader({ shadow = "1", ssao = "0", clutter = "0" }))
    assert.same({
      { cvar = "shadow", from = "1", to = "3" },
      { cvar = "clutter", from = "0", to = "7" },
    }, changes)
  end)

  it("is empty without a backup", function()
    assert.same({}, Preset.Restores(nil, targets, Reader({ shadow = "1" })))
  end)
end)
