-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")

local BLIZZARD = { TooltipBackdropTemplate = true, UICheckButtonTemplate = true, InputBoxTemplate = true, UIPanelButtonTemplate = true }

describe("applicant filter panel", function()
    local ns, frames, settings, changed, panel

    local function checkFor(label)
        local text = frames.text(label)
        return text and text.parentFrame
    end

    before_each(function()
        frames = Frames.tracker()
        _G.CreateFrame = frames.CreateFrame
        Frames.loadVelvet()
        _G.LFGListFrame = { ApplicationViewer = Frames.new() }
        _G.PVEFrame = Frames.new()
        _G.GetNumClasses = function() return 1 end
        _G.C_CreatureInfo = { GetClassInfo = function() return { classFile = "MAGE", className = "Mage" } end }
        _G.CLASS_ICON_TCOORDS = { MAGE = { 0, 1, 0, 1 } }
        _G.RAID_CLASS_COLORS = {}
        _G.NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
        _G.RESET = "Reset"
        _G.GameTooltip_Hide = function() end
        _G.EditBox_ClearFocus = function(self) self:ClearFocus() end
        _G.Round = function(v) return math.floor(v + 0.5) end
        _G.InCombatLockdown = function() return false end
        changed = 0
        ns = { db = {}, IsOn = function() return true end, SetSwitch = function() end,
            ApplyDefaults = function(target, defaults)
                for k, v in pairs(defaults) do
                    if target[k] == nil then target[k] = v end
                end
            end }
        assert(loadfile("Modules/Applicants/FilterRules.lua"))("LittleThings", ns)
        settings = ns.FilterRules.Defaults()
        local options = { removeFinished = false }
        ns.ApplicantData = { Listing = function() return nil end }
        ns.ApplicantFilter = {
            state = { count = 0, paused = false },
            Settings = function() return settings end,
            Options = function() return options end,
            Changed = function() changed = changed + 1 end,
            OnChange = function() end,
        }
        assert(loadfile("UI/WidgetRules.lua"))("LittleThings", ns)
        assert(loadfile("UI/Widgets.lua"))("LittleThings", ns)
        assert(loadfile("Modules/Applicants/FilterPanel.lua"))("LittleThings", ns)
        ns.ApplicantFilter.BuildPanel()
        panel = ns.ApplicantFilter.panel
    end)

    it("draws no Blizzard backdrop, checkbox, input or button templates", function()
        for _, template in ipairs(frames.templates) do
            assert.is_nil(BLIZZARD[template], template)
        end
        assert.equals("BackdropTemplate", panel.template)
    end)

    it("keeps every label", function()
        for _, label in ipairs({ "Applicant filter", "Classes", "Roles", "Only missing roles", "Minimum item level", "Group utility",
            "Brings Bloodlust", "Brings battle res", "List", "Show keys and progress", "Remove closed applications" }) do
            assert.truthy(frames.text(label), label)
        end
    end)

    it("filters from its checkboxes", function()
        local check = checkFor("Brings Bloodlust")
        assert.equals("CheckButton", check.kind)
        check:SetChecked(true)
        check.scripts.OnClick(check)
        assert.is_true(settings.needBloodlust)
        assert.equals(1, changed)
    end)

    it("reads the minimum item level from its input", function()
        local box = frames.find("EditBox")[1]
        box:SetText("620")
        box.scripts.OnTextChanged(box, true)
        assert.equals(620, settings.minItemLevel)
    end)

    it("resets from its button, greyed while nothing differs", function()
        local reset
        for _, button in ipairs(frames.find("Button")) do
            if button.text == "Reset" then reset = button end
        end
        assert.is_false(reset:IsEnabled())
        settings.needBloodlust = true
        panel:Sync()
        assert.is_true(reset:IsEnabled())
        reset.scripts.OnClick(reset)
        assert.is_nil(settings.needBloodlust == true or nil)
    end)

    it("docks beside the group finder with its offsets", function()
        ns.db.applicantPanel = { side = "left", x = 5, y = -7 }
        panel.scripts.OnShow(panel)
        assert.same({ "TOPRIGHT", _G.PVEFrame, "TOPLEFT", 3, -7 }, panel.points[#panel.points])
    end)
end)
