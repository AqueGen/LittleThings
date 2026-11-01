-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")

local BLIZZARD = { ButtonFrameTemplate = true, UIPanelButtonTemplate = true }
local NOTE = "Times are the game's own measurements since login. Red rows took over 50 ms in a frame."

describe("addon performance window", function()
    local ns, frames, module, UI, measured, window

    local function button(text)
        for _, b in ipairs(frames.find("Button")) do
            if b.text == text then return b end
        end
    end

    before_each(function()
        frames = Frames.tracker()
        _G.CreateFrame = frames.CreateFrame
        Frames.loadVelvet()
        UI = LibStub("LibVelvet-1.0")
        measured = 0
        _G.UIParent = Frames.new()
        _G.UISpecialFrames = {}
        _G.Enum = { AddOnProfilerMetric = { RecentAverageTime = 1, SessionAverageTime = 2, PeakTime = 3, EncounterAverageTime = 4, CountTimeOver50Ms = 5 } }
        _G.C_AddOns = { GetNumAddOns = function() return 1 end, IsAddOnLoaded = function() return true end, GetAddOnInfo = function() return "Foo" end }
        _G.C_AddOnProfiler = { IsEnabled = function() return true end, GetAddOnMetric = function() return 0 end }
        _G.UpdateAddOnMemoryUsage = function() measured = measured + 1 end
        _G.GetAddOnMemoryUsage = function() return 1024 end
        _G.CreateDataProvider = function() return { Sort = function() end } end
        _G.ScrollBoxConstants = { RetainScrollPosition = true }
        _G.CreateScrollBoxListLinearView = function() return { SetElementExtent = function() end, SetElementInitializer = function() end } end
        _G.ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
        _G.InCombatLockdown = function() return false end
        _G.GameTooltip_Hide = function() end
        ns = { RegisterModule = function(_, m) module = m end, Print = function() end }
        assert(loadfile("Modules/Performance/ProfilerRows.lua"))("LittleThings", ns)
        assert(loadfile("UI/WidgetRules.lua"))("LittleThings", ns)
        assert(loadfile("UI/Widgets.lua"))("LittleThings", ns)
        assert(loadfile("Modules/Performance/Profiler.lua"))("LittleThings", ns)
        module.Toggle()
        for _, f in ipairs(frames.all) do
            if f.name == "LittleThingsAddonPerformance" then window = f end
        end
    end)

    it("uses the flat window chrome, same name, size and close-on-Escape", function()
        for _, template in ipairs(frames.templates) do
            assert.is_nil(BLIZZARD[template], template)
        end
        assert.equals("BackdropTemplate", window.template)
        assert.same({ "LittleThingsAddonPerformance" }, _G.UISpecialFrames)
        assert.same({ 688, 480 }, { window.width, window.height })
        assert.is_true(window.shown)
        local title = frames.text("Addon performance")
        assert.same(UI.T.gold, title.color)
    end)

    it("closes from its X button", function()
        local close = button("X")
        close.scripts.OnClick(close)
        assert.is_false(window.shown)
    end)

    it("measures memory again from its button", function()
        local before = measured
        local refresh = button("Refresh memory")
        refresh.scripts.OnClick(refresh)
        assert.equals(before + 1, measured)
    end)

    it("keeps the note as visible text at the muted token", function()
        local note = frames.text(NOTE)
        assert.truthy(note)
        assert.same(UI.T.muted, note.color)
    end)

    it("marks the sorted column", function()
        local header = frames.text("Peak").parentFrame
        header.scripts.OnClick(header)
        assert.same(UI.T.selLabel, frames.text("Peak").color)
        assert.same(UI.T.text, frames.text("Average").color)
    end)
end)
