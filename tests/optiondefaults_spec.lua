local function newNs()
  local ns = { db = {}, modules = {} }
  function ns.RegisterModule(name, module) ns.modules[name] = module end
  function ns.ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
      if target[key] == nil then target[key] = value end
    end
  end
  return ns
end

local function load(path, ns)
  assert(loadfile(path))("LittleThings", ns)
end

describe("option tables read before any settings page exists", function()
  it("JournalLoot fills its defaults and resets an unknown position", function()
    local ns = newNs()
    ns.IconButtons = { ROLE_ATLAS = {}, SIZE = 24 }
    ns.db.journalLootOptions = { corner = "gone" }
    load("Modules/JournalLoot/JournalLoot.lua", ns)
    local options = ns.modules.JournalLoot.Options()
    assert.equals("bottomright", options.corner)
    assert.equals(16, options.size)
    assert.equals(24, options.lootSpecSize)
  end)
end)
