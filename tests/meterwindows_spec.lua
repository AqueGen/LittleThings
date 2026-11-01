-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")

local BLIZZARD = { InputBoxTemplate = true, UICheckButtonTemplate = true, UIPanelButtonTemplate = true }

describe("Meter windows page", function()
    local ns, build, page, templates, calls, combat, windows

    local function window(w, h, locked)
        return {
            GetWidth = function() return w end,
            GetHeight = function() return h end,
            IsShown = function() return true end,
            CanMoveOrResize = function() return not locked end,
            IsLocked = function() return locked end,
        }
    end

    local function strings(parent)
        local found = {}
        local function walk(f)
            for _, child in ipairs(f.children or {}) do
                if child.text then found[child.text] = child end
                walk(child)
            end
        end
        walk(parent)
        return found
    end

    local function group(title)
        for _, g in ipairs(page.groups) do
            if g.frame.title and g.frame.title.text == title then return g end
        end
    end

    local function find(parent, kind)
        local found = {}
        local function walk(f)
            for _, child in ipairs(f.children or {}) do
                if child.kind == kind then found[#found + 1] = child end
                walk(child)
            end
        end
        walk(parent)
        return found
    end

    before_each(function()
        templates, calls, combat = {}, {}, false
        local function new(kind, parent, template)
            local f = Frames.new(parent)
            f.kind = kind
            f.children = {}
            if parent and parent.children then parent.children[#parent.children + 1] = f end
            function f:CreateFontString()
                local s = new("FontString", self)
                return s
            end
            function f:CreateTexture() return new("Texture", self) end
            if template then templates[#templates + 1] = template end
            return f
        end
        _G.CreateFrame = function(kind, _, parent, template) return new(kind, parent, template) end
        _G.InCombatLockdown = function() return combat end
        _G.GameTooltip_Hide = function() end
        Frames.loadVelvet()
        windows = { window(300, 200), window(250, 180), nil }
        ns = {
            db = { damageMeter = true },
            charDb = { links = { [2] = { to = 1, point = "TOPLEFT", relPoint = "BOTTOMLEFT", gap = 2, matchWidth = true } } },
            IsAvailable = function() return true end,
            RequestReload = function(what) calls[#calls + 1] = { "reload", what } end,
            RegisterModule = function() end,
            Window = { Register = function(_, fn) build = fn end },
            Windows = {
                BLIZZARD_WINDOW_COUNT = 3,
                SortedIndices = function(set)
                    local list = {}
                    for k in pairs(set) do list[#list + 1] = k end
                    table.sort(list)
                    return list
                end,
                Get = function(i) return windows[i] end,
                SetSize = function(i, w, h)
                    calls[#calls + 1] = { "size", i, w, h }
                    return true
                end,
                Hide = function(i) calls[#calls + 1] = { "hide", i } end,
            },
            Snap = {
                ApplyLink = function(i) calls[#calls + 1] = { "apply", i } end,
                ClearLink = function(i) calls[#calls + 1] = { "clear", i } end,
                CopyCrossSize = function() return false end,
            },
        }
        for _, path in ipairs({ "UI/WidgetRules.lua", "UI/Widgets.lua", "Modules/DamageMeter/Config.lua" }) do
            assert(loadfile(path))("LittleThings", ns)
        end
        page = ns.Widgets.NewPage(new("Frame"))
        build(page)
        page.frame:Show()
        page.frame.scripts.OnShow(page.frame)
    end)

    it("puts each window in its own group box under a visible note", function()
        assert.truthy(group("Window 1 (primary)"))
        assert.truthy(group("Window 2"))
        assert.truthy(group("Window 3"))
        local texts = strings(page.groups[1].frame)
        local note
        for text in pairs(texts) do
            if text:find("need a /reload afterwards", 1, true) then note = text end
        end
        assert.truthy(note)
        assert.truthy(strings(group("Window 1 (primary)").frame)["Size comes from Edit Mode."])
    end)

    it("draws no Blizzard input, checkbox or button templates", function()
        for _, template in ipairs(templates) do
            assert.is_nil(BLIZZARD[template], template)
        end
    end)

    it("resizes a window from its size box and offers the reload", function()
        local box = find(group("Window 2").frame, "EditBox")[1]
        box:SetText("320")
        box.scripts.OnEnterPressed(box)
        assert.same({ { "size", 2, 320, 180 }, { "reload", "size" } }, calls)
    end)

    it("refuses a size typed in combat", function()
        local box = find(group("Window 2").frame, "EditBox")[1]
        combat = true
        box:SetText("320")
        box.scripts.OnEnterPressed(box)
        assert.same({}, calls)
    end)

    it("keeps the link controls: gap, match, detach and hide", function()
        local g = group("Window 2").frame
        local gap = find(g, "EditBox")[3]
        gap:SetText("6")
        gap.scripts.OnEnterPressed(gap)
        assert.equals(6, ns.charDb.links[2].gap)
        local checks = find(g, "CheckButton")
        assert.is_true(checks[1]:GetChecked())
        checks[2]:SetChecked(true)
        checks[2].scripts.OnClick(checks[2])
        assert.is_true(ns.charDb.links[2].matchHeight)
        local buttons = find(g, "Button")
        buttons[1].scripts.OnClick(buttons[1])
        buttons[2].scripts.OnClick(buttons[2])
        assert.same({ "clear", 2 }, calls[#calls - 1])
        assert.same({ "hide", 2 }, calls[#calls])
    end)

    it("greys out what the primary window cannot do", function()
        local g = group("Window 1 (primary)").frame
        assert.is_false(find(g, "EditBox")[3]:IsEnabled())
        for _, check in ipairs(find(g, "CheckButton")) do assert.is_false(check:IsEnabled()) end
        for _, button in ipairs(find(g, "Button")) do assert.is_false(button:IsEnabled()) end
    end)
end)
