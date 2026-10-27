local function read(path)
  local f = assert(io.open(path, "r"))
  local text = f:read("*a")
  f:close()
  return text
end

local switches = {}
for key in read("Core.lua"):gmatch('{ key = "(%w+)"') do
  switches[key] = true
end

describe("module settings tables", function()
  it("never reuse a module switch key", function()
    local files = io.popen('find Modules -name "*.lua"')
    for path in files:lines() do
      for key in read(path):gmatch("ns%.db%.(%w+)%s*=%s*ns%.db%.%w+%s*or%s*{}") do
        assert.is_nil(switches[key], path .. " keeps a settings table in the switch ns.db." .. key)
      end
    end
    files:close()
  end)
end)
