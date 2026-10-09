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
  it("DefaultPlaystyle fills its defaults on first read", function()
    local ns = newNs()
    load("Modules/Applicants/DefaultPlaystyle.lua", ns)
    local options = ns.DefaultPlaystyle.Options()
    assert.equals("FunSerious", options.style)
    assert.is_true(options.partyKeys)
    assert.equals(options, ns.db.defaultPlaystyleOptions)
  end)

  it("DefaultPlaystyle keeps what the player saved", function()
    local ns = newNs()
    ns.db.defaultPlaystyleOptions = { style = "Expert" }
    load("Modules/Applicants/DefaultPlaystyle.lua", ns)
    assert.equals("Expert", ns.DefaultPlaystyle.Options().style)
    assert.is_true(ns.DefaultPlaystyle.Options().preferMythicPlus)
  end)

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
