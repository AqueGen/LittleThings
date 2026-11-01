-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")

local CLASSES = {
    { classID = 1, classFile = "WARRIOR", specs = { { 71, "DAMAGER" }, { 72, "DAMAGER" }, { 73, "TANK" } } },
    { classID = 5, classFile = "PRIEST", specs = { { 256, "HEALER" }, { 257, "HEALER" }, { 258, "DAMAGER" } } },
}

describe("journal loot preview", function()
    local ns, module, pane, created, on

    local function fakePane()
        local p = { visible = true, stage = Frames.new() }
        function p:IsVisible() return self.visible end
        function p:SetCaption(text) self.caption = text end
        function p:SetOff(text) self.off = text end
        function p:Fit(content, w, h) self.fit = { content, w, h } end
        return p
    end

    local function options()
        local byLabel = {}
        local group = {}
        for _, kind in ipairs({ "Check", "Slider", "Dropdown" }) do
            group[kind] = function(_, spec) byLabel[spec.label] = spec end
        end
        module.Pages({ Group = function() return group end })
        return byLabel
    end

    local function within(f, ancestor)
        while f do
            if f == ancestor then return true end
            f = f.parentFrame
        end
        return false
    end

    local function shownIcons()
        local found = {}
        for _, f in ipairs(created) do
            if f.lootIcon and f.shown and within(f, pane.stage) then found[#found + 1] = f end
        end
        return found
    end

    local function lootButtons()
        local found = {}
        for _, f in ipairs(created) do
            if f.kind == "Button" and within(f, pane.stage) then found[#found + 1] = f end
        end
        return found
    end

    before_each(function()
        created, on = {}, true
        local function new(kind, parent)
            local f = Frames.new(parent)
            f.kind = kind
            created[#created + 1] = f
            function f:CreateTexture(_, layer, _, sub)
                local t = new("Texture", self)
                t.lootIcon = layer == "OVERLAY" and sub == 7
                return t
            end
            function f:CreateFontString() return new("FontString", self) end
            return f
        end
        _G.CreateFrame = function(kind, _, parent) return new(kind, parent) end
        _G.GetNumClasses = function() return #CLASSES end
        _G.C_CreatureInfo = { GetClassInfo = function(i) return CLASSES[i] end }
        _G.GetSpecializationInfoForClassID = function(classID, j)
            for _, class in ipairs(CLASSES) do
                if class.classID == classID and class.specs[j] then return class.specs[j][1], nil, nil, 1000 + class.specs[j][1], class.specs[j][2] end
            end
        end
        _G.C_SpecializationInfo = {
            GetNumSpecializationsForClassID = function() return 3 end,
            GetSpecialization = function() return 1 end,
            GetSpecializationInfo = function(i) return 70 + i, "Spec " .. i, nil, 1000 + i end,
        }
        _G.UnitClass = function() return "Warrior", "WARRIOR", 1 end
        _G.GetLootSpecialization = function() return 0 end
        _G.CLASS_ICON_TCOORDS = { WARRIOR = { 0, 1, 0, 1 }, PRIEST = { 0, 1, 0, 1 } }
        _G.GameTooltip_Hide = function() end
        ns = {
            db = { journalLoot = true },
            Widgets = { FLAT = {} },
            IsOn = function() return on end,
            ApplyDefaults = function(target, defaults)
                for k, v in pairs(defaults) do
                    if target[k] == nil then target[k] = v end
                end
            end,
            RegisterModule = function(_, m) module = m end,
        }
        assert(loadfile("Modules/IconButtons.lua"))("LittleThings", ns)
        assert(loadfile("Modules/JournalLoot/JournalLootIcons.lua"))("LittleThings", ns)
        assert(loadfile("Modules/JournalLoot/JournalLoot.lua"))("LittleThings", ns)
        pane = fakePane()
        module.Preview.Attach(pane)
    end)

    it("paints the spec icons on a sample loot row inside the pane", function()
        options()
        module.Preview.Refresh()
        assert.equals(2, #shownIcons())
        for _, b in ipairs(lootButtons()) do assert.is_false(b.mouse) end
        assert.equals(3, #lootButtons())
        assert.truthy(pane.caption)
        assert.is_nil(pane.off)
    end)

    it("folds icons for all classes and follows icon size", function()
        local byLabel = options()
        byLabel["All classes"].set(true)
        assert.equals(3, #shownIcons())
        byLabel["Icon size"].set(20)
        for _, icon in ipairs(shownIcons()) do assert.equals(20, icon.width) end
    end)

    it("hides the loot specialization buttons with their switch and sizes them", function()
        local byLabel = options()
        byLabel["Button size"].set(30)
        module.Preview.Refresh()
        assert.equals(30, lootButtons()[1].width)
        local _, before = pane.fit[2], pane.fit[3]
        byLabel["Loot specialization buttons"].set(false)
        assert.is_true(pane.fit[3] < before)
    end)

    it("greys out with a visible line while the module is off", function()
        options()
        on = false
        module.Preview.Refresh()
        assert.truthy(pane.off)
    end)

    it("draws nothing while the pane is hidden", function()
        options()
        pane.visible = false
        module.Preview.Refresh()
        assert.equals(0, #shownIcons())
    end)
end)
