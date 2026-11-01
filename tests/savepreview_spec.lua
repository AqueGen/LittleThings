-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local created

local function newFrame(kind, name, parent, template)
    local f = { kind = kind, name = name, parentFrame = parent, template = template, shown = true, width = 0, height = 0, scale = 1, scripts = {} }
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetScale(s) self.scale = s end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(on) self.shown = on and true or false end
    function f:SetText(t) self.text = t end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:CreateTexture() return newFrame("Texture", nil, self) end
    function f:CreateFontString() return newFrame("FontString", nil, self) end
    created[#created + 1] = f
    return setmetatable(f, {
        __index = function(_, k)
            if type(k) == "string" and k:match("^%u") then return function() end end
        end,
    })
end

local function fakePane()
    local p = { visible = true, stage = {} }
    function p:IsVisible() return self.visible end
    function p:SetCaption(text) self.caption = text end
    function p:SetOff(text) self.off = text end
    function p:Fit(content, w, h) self.fit = { content, w, h } end
    return p
end

describe("save indicator preview", function()
    local ns, pane, on

    local function options()
        local byLabel = {}
        local group = { Note = function() end, CheckGrid = function() end }
        for _, kind in ipairs({ "Check", "Slider", "Button" }) do
            group[kind] = function(_, spec) byLabel[spec.label] = spec end
        end
        ns.SaveIndicator.Pages({ Group = function() return group end })
        return byLabel
    end

    local function strings(parent, text)
        local found = {}
        for _, f in ipairs(created) do
            if f.kind == "FontString" and f.parentFrame == parent and (text == nil or f.text == text) then found[#found + 1] = f end
        end
        return found
    end

    local function inner()
        for _, f in ipairs(created) do
            if f.parentFrame and f.parentFrame.parentFrame == pane.stage then return f end
        end
    end

    before_each(function()
        created, on = {}, true
        _G.CreateFrame = function(kind, name, parent, template) return newFrame(kind, name, parent, template) end
        _G.InCombatLockdown = function() return false end
        _G.UIParent = newFrame("Frame")
        _G.C_Spell = { GetSpellTexture = function(id) return id end }
        _G.UnitClass = function() return "Priest", "PRIEST" end
        _G.IsInInstance = function() return false, "none" end
        ns = {
            db = {},
            IsOn = function() return on end,
            RegisterModule = function() end,
            ApplyDefaults = function(target, defaults)
                for k, v in pairs(defaults) do
                    if target[k] == nil then target[k] = v end
                end
            end,
        }
        for _, path in ipairs({ "SaveRules", "SaveData", "Center", "RowPreview", "SaveIndicator" }) do
            assert(loadfile("Modules/SaveIndicator/" .. path .. ".lua"))("LittleThings", ns)
        end
        pane = fakePane()
        ns.SaveIndicator.Preview.Attach(pane)
    end)

    it("draws the sample row as a second instance inside the pane, nothing on screen", function()
        options()
        ns.SaveIndicator.Preview.Refresh()
        local row = inner()
        assert.is_truthy(row)
        assert.is_nil(row.name)
        assert.equals(2, #strings(row, "|cff7dff6a-24%|r") + #strings(row, "|cff7dff6a-40%|r"))
        assert.is_truthy(pane.caption)
        assert.is_nil(pane.off)
        for _, f in ipairs(created) do
            assert.is_nil(f.name)
        end
    end)

    it("follows the time, reduction and scale settings", function()
        local byLabel = options()
        ns.SaveIndicator.Preview.Refresh()
        local row = inner()
        local times = strings(row, "12")
        assert.equals(1, #times)
        assert.is_true(times[1].shown)
        byLabel["Time left"].set(false)
        assert.is_false(times[1].shown)
        local dr = strings(row, "|cff7dff6a-24%|r")[1]
        byLabel["Damage reduction"].set(false)
        assert.is_false(dr.shown)
        byLabel["Scale"].set(1.5)
        assert.equals(1.5, row.scale)
        assert.same({ row.width * 1.5, row.height * 1.5 }, { pane.fit[2], pane.fit[3] })
    end)

    it("greys out with a visible line while the module is off", function()
        options()
        on = false
        ns.SaveIndicator.Preview.Refresh()
        assert.is_truthy(pane.off)
        on = true
        ns.SaveIndicator.Preview.Refresh()
        assert.is_nil(pane.off)
    end)

    it("asks for the same column as the raid marker page, two grid columns wide", function()
        assert.equals(476, ns.SaveIndicator.Preview.columnMin)
    end)

    it("draws nothing while the pane is hidden", function()
        options()
        pane.visible = false
        ns.SaveIndicator.Preview.Refresh()
        assert.is_nil(inner())
    end)
end)
