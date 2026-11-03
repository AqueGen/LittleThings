-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")

describe("option hints", function()
    local ns, frames, page

    before_each(function()
        frames = Frames.tracker()
        _G.CreateFrame = frames.CreateFrame
        _G.InCombatLockdown = function() return false end
        _G.GameTooltip_Hide = function() end
        Frames.loadVelvet()
        ns = {}
        for _, path in ipairs({ "UI/WidgetRules.lua", "UI/Widgets.lua" }) do
            assert(loadfile(path))("LittleThings", ns)
        end
        page = ns.Widgets.NewPage(Frames.new())
    end)

    local function check(spec)
        spec.get = function() return true end
        spec.set = function() end
        page:Group("Group"):Check(spec)
    end

    it("creates the hint text in the row of a check", function()
        check({ label = "Option", hint = "What it does" })
        assert.is_not_nil(frames.text("What it does"))
    end)

    it("creates no hint text without a hint", function()
        check({ label = "Option" })
        local texts = {}
        for _, f in ipairs(frames.find("FontString")) do texts[#texts + 1] = f.text end
        assert.same({ "Group", "Option" }, texts)
    end)

    it("dims the hint while the option is disabled", function()
        local on = true
        check({ label = "Option", hint = "What it does", enabled = function() return on end })
        page:Refresh()
        assert.equals(1, frames.text("What it does").alpha)
        on = false
        page:Refresh()
        assert.equals(0.5, frames.text("What it does").alpha)
    end)

    it("shows only the label in a slider caption and the formatted value beside the slider", function()
        local value = 10
        page:Group("Group"):Slider({ label = "Pull timer, left click", min = 3, max = 60, format = "%d s",
            get = function() return value end, set = function() end })
        page:Refresh()
        assert.is_not_nil(frames.text("Pull timer, left click"))
        assert.is_not_nil(frames.text("10 s"))
    end)

    it("puts the hint under the control on a page with a preview", function()
        page.hintsBelow = true
        check({ label = "Option", hint = "What it does" })
        page:Refresh()
        assert.equals("TOPLEFT", frames.text("What it does").points[1][1])
    end)

    it("puts the hint right of the control otherwise", function()
        check({ label = "Option", hint = "What it does" })
        page:Refresh()
        assert.equals("LEFT", frames.text("What it does").points[1][1])
    end)
end)

describe("module rows", function()
    it("carry a hint each", function()
        local f = assert(io.open("Core.lua", "r"))
        local text = f:read("*a")
        f:close()
        local count = 0
        for line in text:gmatch("[^\n]+") do
            local key = line:match('^%s*{ key = "(%w+)"')
            if key then
                count = count + 1
                local hint = line:match('hint = "([^"]+)"')
                assert.is_truthy(hint, key)
            end
        end
        assert.is_true(count > 20)
    end)
end)
