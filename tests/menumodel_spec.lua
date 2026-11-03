-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
package.path = "./UI/?.lua;" .. package.path

local MenuModel = require("MenuModel")

local MODULES = {
  { key = "groupFinder", group = "Group content", label = "Group finder" },
  { key = "applicantSort", parent = "groupFinder", label = "Keys" },
  { key = "groupLeader", group = "Group content", label = "Group leader icons" },
  { key = "damageMeter", group = "Combat", label = "Damage meter" },
  { key = "journalLoot", group = "Character and loot", label = "Journal loot" },
}

local EXTRAS = { { key = "damageMeterWindows", label = "Meter windows", after = "damageMeter" } }

local function flatten(groups)
  local list = {}
  for _, group in ipairs(groups) do
    for _, entry in ipairs(group.entries) do
      list[#list + 1] = group.title .. ":" .. entry.key
    end
  end
  return list
end

describe("MenuModel.Build", function()
  it("keeps the group and module order and leaves child rows off the menu", function()
    local groups = MenuModel.Build(MODULES, EXTRAS, function() return false end)
    assert.same({
      "Group content:groupFinder",
      "Group content:groupLeader",
      "Combat:damageMeter",
      "Combat:damageMeterWindows",
      "Character and loot:journalLoot",
    }, flatten(groups))
  end)

  it("carries the labels", function()
    local groups = MenuModel.Build(MODULES, EXTRAS, function() return false end)
    assert.equals("Meter windows", groups[2].entries[2].label)
  end)

  it("moves modules without a page of their own onto the group page", function()
    local hasPage = function(key) return key ~= "groupLeader" and key ~= "journalLoot" end
    local groups = MenuModel.Build(MODULES, EXTRAS, function() return false end, hasPage)
    assert.same({
      "Group content:groupFinder",
      "Combat:damageMeter",
      "Combat:damageMeterWindows",
    }, flatten(groups))
    assert.same({ "groupLeader" }, groups[1].switches)
    assert.equals("group:Group content", groups[1].page)
    assert.same({ "journalLoot" }, groups[3].switches)
  end)

  it("keeps a group page-less when every module has settings", function()
    local groups = MenuModel.Build(MODULES, EXTRAS, function() return false end, function() return true end)
    for _, group in ipairs(groups) do
      assert.same({}, group.switches)
      assert.is_nil(group.page)
    end
  end)

  it("keeps a module with child switches on the menu", function()
    local groups = MenuModel.Build(MODULES, EXTRAS, function() return false end, function() return false end)
    assert.equals("groupFinder", groups[1].entries[1].key)
  end)

  it("marks each entry on or off from the switch lookup", function()
    local groups = MenuModel.Build(MODULES, EXTRAS, function(key) return key == "groupFinder" or key == "damageMeterWindows" end)
    assert.is_true(groups[1].entries[1].on)
    assert.is_false(groups[1].entries[2].on)
    assert.is_false(groups[2].entries[1].on)
    assert.is_true(groups[2].entries[2].on)
  end)
end)
