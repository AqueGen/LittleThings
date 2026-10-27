package.path = "./Modules/SaveIndicator/?.lua;" .. package.path
local Data = require("SaveData")

describe("SaveData", function()
  it("only holds saves of 20 or more with a name", function()
    for id, e in pairs(Data) do
      assert.is_number(id)
      assert.is_true(e.dr >= 20 and e.dr <= 100, tostring(id))
      assert.is_string(e.name)
    end
  end)
  it("has Sentinel with its stack rule", function()
    assert.same({ dr = 30, name = "Sentinel", perStack = 2, maxStacks = 15 }, Data[389539])
  end)
  it("has Pain Suppression at 40", function()
    assert.equals(40, Data[33206].dr)
  end)
  it("keys Blur by its aura, not its cast", function()
    assert.equals(25, Data[212800].dr)
    assert.is_nil(Data[198589])
  end)
end)
