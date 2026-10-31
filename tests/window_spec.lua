-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local function newFrame(parent)
    local f = { parentFrame = parent, points = {}, scripts = {}, shown = true, width = 0, height = 0 }
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:ClearAllPoints() self.points = {} end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetSize() return self.width, self.height end
    function f:Show() self.shown = true end
    function f:Hide()
        local was = self.shown
        self.shown = false
        if was and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:SetShown(on) if on then self:Show() else self:Hide() end end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parentFrame or self.parentFrame:IsVisible()) end
    function f:GetParent() return self.parentFrame end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:GetScript(event) return self.scripts[event] end
    function f:HookScript(event, fn)
        local prev = self.scripts[event]
        self.scripts[event] = function(...)
            if prev then prev(...) end
            fn(...)
        end
    end
    function f:CreateFontString() return newFrame(self) end
    function f:CreateTexture() return newFrame(self) end
    function f:SetParent(p) self.parentFrame = p end
    return setmetatable(f, {
        __index = function(_, k)
            if type(k) ~= "string" or not k:match("^%u") then return nil end
            if k:match("^Create") then return function(self) return newFrame(self) end end
            if k:match("^Get") then return function() return 0 end end
            return function() end
        end,
    })
end

local function point(f, name)
    for _, p in ipairs(f.points) do
        if p[1] == name then return p end
    end
end

describe("settings window preview zone", function()
    local ns, settings, scroll, pane, attached, refreshed

    before_each(function()
        settings, scroll, pane, attached, refreshed = nil, nil, nil, 0, 0
        local root = newFrame()
        _G.UIParent = root
        _G.UISpecialFrames = {}
        _G.tinsert = table.insert
        _G.strmatch = string.match
        _G.GameTooltip_Hide = function() end
        _G.InCombatLockdown = function() return false end
        _G.CreateColor = function(...) return { ... } end
        _G.geterrorhandler = function() return error end
        _G.CreateFrame = function(_, name, parent, template)
            local f = newFrame(parent)
            if name == "LittleThingsSettings" then
                settings = f
                f.scripts.OnSizeChanged = function() f.backdropResized = true end
            end
            if template == "UIPanelScrollFrameTemplate" then scroll = f end
            return f
        end
        local dir = "Libs/LibVelvet-1.0/"
        local file = assert(io.open(dir .. "lib.xml", "rb"))
        local xml = file:read("*a")
        file:close()
        for script in xml:gmatch('<Script file="([^"]+)"/>') do dofile(dir .. script) end

        local preview = {
            columnMin = 430,
            Attach = function(p)
                pane = p
                attached = attached + 1
            end,
            Refresh = function() refreshed = refreshed + 1 end,
        }
        ns = {
            db = { raidMarkers = true, groupChat = true },
            MODULES = {
                { key = "raidMarkers", group = "Party and raid", label = "Raid marker panel", live = true, tooltip = "Panel." },
                { key = "groupChat", group = "Party and raid", label = "Group chat", live = true, tooltip = "Chat." },
            },
            IsOn = function(key) return ns.db[key] == true end,
            IsAvailable = function() return true end,
            ModulesFor = function(key)
                if key == "raidMarkers" then return { { key = key, Preview = preview } } end
                return {}
            end,
        }
        for _, path in ipairs({ "UI/WidgetRules.lua", "UI/MenuModel.lua", "UI/Widgets.lua", "UI/Window.lua" }) do
            assert(loadfile(path))("LittleThings", ns)
        end
    end)

    it("opens wide enough for the zone beside the column", function()
        ns.Window.Show("raidMarkers")
        assert.equals(1000, settings.width)
        assert.is_true(pane.shown)
        assert.is_not_nil(point(pane, "TOPRIGHT"))
        assert.is_not_nil(point(pane, "BOTTOMRIGHT"))
        assert.is_true(refreshed > 0)
    end)

    it("keeps the pane inside the content area height", function()
        ns.Window.Show("raidMarkers")
        assert.same({ "TOPRIGHT", settings, "TOPRIGHT", -8, -36 }, point(pane, "TOPRIGHT"))
        assert.same({ "BOTTOMRIGHT", settings, "BOTTOMRIGHT", -8, 20 }, point(pane, "BOTTOMRIGHT"))
        assert.equals(20, point(scroll, "BOTTOMRIGHT")[5])
    end)

    it("gives the column the full width on a page without a preview", function()
        ns.Window.Show("raidMarkers")
        ns.Window.Show("groupChat")
        assert.is_false(pane.shown)
        assert.same({ "BOTTOMRIGHT", settings, "BOTTOMRIGHT", -30, 20 }, point(scroll, "BOTTOMRIGHT"))
    end)

    it("moves the pane to a band above the column in a narrow window", function()
        ns.Window.Show("raidMarkers")
        settings:SetSize(790, 560)
        settings.scripts.OnSizeChanged(settings, 790, 560)
        assert.is_true(pane.shown)
        assert.is_not_nil(point(pane, "TOPLEFT"))
        assert.is_nil(point(pane, "BOTTOMRIGHT"))
        assert.equals(150, pane.height)
        assert.is_true(settings.backdropResized)
    end)

    it("builds one pane per preview and refreshes it when a switch changes", function()
        ns.Window.Show("raidMarkers")
        ns.Window.Show("groupChat")
        ns.Window.Show("raidMarkers")
        assert.equals(1, attached)
        local before = refreshed
        ns.Window.Refresh()
        assert.equals(before + 1, refreshed)
    end)

    it("does not refresh a preview while its page is not open", function()
        ns.Window.Show("raidMarkers")
        ns.Window.Show("groupChat")
        local before = refreshed
        ns.Window.Refresh()
        assert.equals(before, refreshed)
    end)
end)
