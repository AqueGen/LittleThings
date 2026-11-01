-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")

describe("character panel preview", function()
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
            group[kind] = function(_, spec)
                byLabel[#byLabel + 1] = spec
            end
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

    local function buttons()
        local found = {}
        for _, f in ipairs(created) do
            if f.kind == "Button" and within(f, pane.stage) then found[#found + 1] = f end
        end
        return found
    end

    before_each(function()
        created, on = {}, true
        _G.CreateFrame = function(kind, _, parent)
            local f = Frames.new(parent)
            f.kind = kind
            created[#created + 1] = f
            return f
        end
        _G.CharacterFrame = Frames.new()
        _G.CharacterFrame:SetSize(338, 424)
        _G.PaperDollFrame = Frames.new()
        _G.SPECIALIZATION, _G.SELECT_LOOT_SPECIALIZATION = "Specialization", "Loot Specialization"
        _G.LOOT_SPECIALIZATION_DEFAULT = "Current (%s)"
        _G.UnitClass = function() return "Priest", "PRIEST", 5 end
        _G.GetLootSpecialization = function() return 0 end
        _G.C_SpecializationInfo = {
            GetNumSpecializationsForClassID = function() return 3 end,
            GetSpecialization = function() return 1 end,
            GetSpecializationInfo = function(i) return 255 + i, "Spec " .. i, nil, 1000 + i end,
        }
        _G.GameTooltip_Hide = function() end
        ns = {
            db = {},
            Widgets = { FLAT = {}, THEME = { muted = { 0.72, 0.74, 0.78 } } },
            IsOn = function() return on end,
            ApplyDefaults = function(target, defaults)
                for k, v in pairs(defaults) do
                    if target[k] == nil then target[k] = v end
                end
            end,
            RegisterModule = function(_, m) module = m end,
        }
        assert(loadfile("Modules/IconButtons.lua"))("LittleThings", ns)
        assert(loadfile("Modules/CharacterPanel.lua"))("LittleThings", ns)
        pane = fakePane()
        module.Preview.Attach(pane)
    end)

    it("draws both bars as a second instance inside the pane, not on the character panel", function()
        options()
        module.Preview.Refresh()
        local drawn = buttons()
        assert.equals(3 + 4, #drawn)
        for _, b in ipairs(drawn) do assert.is_false(b.mouse) end
        for _, f in ipairs(created) do
            assert.is_false(within(f, _G.PaperDollFrame))
        end
        assert.truthy(pane.caption)
        assert.is_nil(pane.off)
    end)

    it("follows icon size and anchor corner", function()
        local specs = options()
        module.Preview.Refresh()
        local _, h = pane.fit[2], pane.fit[3]
        for _, spec in ipairs(specs) do
            if spec.label == "Icon size" then spec.set(24) end
        end
        module.Preview.Refresh()
        local small = 0
        for _, b in ipairs(buttons()) do
            if b.width == 24 then small = small + 1 end
        end
        assert.is_true(small >= 3)
        for _, spec in ipairs(specs) do
            if spec.label == "Anchor corner" then spec.set("topleft") end
        end
        assert.is_true(h > 424)
        assert.equals(424, pane.fit[3])
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
        assert.equals(0, #buttons())
    end)
end)
