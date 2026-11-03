-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = dofile("tests/frames.lua")
local newFrame, point = Frames.new, Frames.point

describe("settings window preview zone", function()
    local ns, settings, scroll, pane, attached, refreshed, created, combat, tip

    before_each(function()
        settings, scroll, pane, attached, refreshed, created, combat, tip = nil, nil, nil, 0, 0, {}, false, {}
        local root = newFrame()
        _G.UIParent = root
        _G.UISpecialFrames = {}
        _G.tinsert = table.insert
        _G.strmatch = string.match
        _G.GameTooltip_Hide = function() end
        _G.InCombatLockdown = function() return combat end
        _G.C_Timer = { NewTicker = function() return {} end, After = function() end }
        _G.GameTooltip = setmetatable({}, { __index = function(_, method)
            return function(_, ...) tip[#tip + 1] = { method, ... } end
        end })
        _G.geterrorhandler = function() return error end
        _G.CreateFrame = function(_, name, parent, template)
            local f = newFrame(parent)
            created[#created + 1] = f
            if name == "LittleThingsSettings" then
                settings = f
                f.scripts.OnSizeChanged = function() f.backdropResized = true end
            end
            if template == "UIPanelScrollFrameTemplate" then scroll = f end
            return f
        end
        Frames.loadVelvet()

        local preview = {
            columnMin = 476,
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
                { key = "groupLeader", group = "Party and raid", label = "Group leader icons", live = true, hint = "Mark the leader", tooltip = "Crown." },
            },
            IsOn = function(key) return ns.db[key] == true end,
            IsAvailable = function() return true end,
            ModulesFor = function(key)
                if key == "raidMarkers" then return { { key = key, Preview = preview } } end
                if key == "groupChat" then return { { key = key, Pages = function() end } } end
                return {}
            end,
        }
        ns.Print = function() end
        for _, path in ipairs({ "UI/WidgetRules.lua", "UI/MenuModel.lua", "UI/Widgets.lua", "UI/Window.lua", "Modules/PanelMove.lua" }) do
            assert(loadfile(path))("LittleThings", ns)
        end
    end)

    local function button(text)
        for _, f in ipairs(created) do
            if f.text == text and f.label then return f end
        end
    end

    it("puts a primary Move the panels button, 110 wide, left of the close button in the title bar", function()
        ns.Window.Show("raidMarkers")
        local move, close = button("Move the panels"), button("X")
        assert.equals(close.parentFrame, move.parentFrame)
        assert.same({ "RIGHT", close, "LEFT", -4, 0 }, point(move, "RIGHT"))
        assert.same({ 110, close.height }, { move.width, move.height })
        assert.same(ns.Widgets.THEME.gold, move.label.color)
        assert.same(ns.Widgets.THEME.gold, move.border)
    end)

    it("starts the mode with the window kept open, reads Done, ends the mode, and follows a mode ended elsewhere", function()
        ns.Window.Show("raidMarkers")
        local move = button("Move the panels")
        move.scripts.OnClick(move)
        assert.is_true(ns.PanelMove.Moving())
        assert.equals("Done", move.text)
        assert.is_true(settings.shown)
        move.scripts.OnClick(move)
        assert.is_false(ns.PanelMove.Moving())
        assert.equals("Move the panels", move.text)
        ns.PanelMove.Toggle()
        assert.equals("Done", move.text)
        ns.PanelMove.Stop()
        assert.equals("Move the panels", move.text)
    end)

    it("looks disabled with an out-of-combat line in combat and does not toggle", function()
        ns.Window.Show("raidMarkers")
        local move = button("Move the panels")
        combat = true
        ns.Window.Refresh()
        assert.is_false(move.enabled)
        assert.same(ns.Widgets.THEME.muted, move.label.color)
        move.scripts.OnClick(move)
        assert.is_false(ns.PanelMove.Moving())
        move.scripts.OnEnter(move)
        local lines = {}
        for _, call in ipairs(tip) do
            if call[1] == "AddLine" or call[1] == "SetText" then lines[#lines + 1] = call[2] end
        end
        assert.is_truthy(table.concat(lines, "|"):find("Out of combat only.", 1, true))
    end)

    it("hides the button while no movable panel module is on", function()
        ns.db.raidMarkers = false
        ns.Window.Show("groupChat")
        assert.is_false(button("Move the panels").shown)
        ns.db.raidMarkers = true
        ns.Window.Refresh()
        assert.is_true(button("Move the panels").shown)
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

    it("reflows a check grid to the group width instead of overflowing it", function()
        local page = ns.Widgets.NewPage(newFrame())
        local group = page:Group("Tracked saves")
        local specs = {}
        for i = 1, 6 do
            specs[i] = { label = "Save " .. i, get = function() return true end, set = function() end }
        end
        group:CheckGrid(specs, 3, 220)
        local holder = group.items[1].frame
        group.frame.width = 464
        page:Refresh()
        assert.equals(440, holder.width)
        assert.equals(54, holder.height)
        group.frame.width = 684
        page:Refresh()
        assert.equals(660, holder.width)
        assert.equals(36, holder.height)
    end)

    it("opens a switch-only module on its group page, which lists the switch with its hint", function()
        ns.Window.Show("groupLeader")
        local header = button("Party and raid")
        assert.is_not_nil(header)
        assert.is_nil(button("Group leader icons"))
        local selected = header.label.color
        ns.Window.Show("raidMarkers")
        assert.same(LibStub("LibVelvet-1.0").HEADER, header.label.color)
        header.scripts.OnClick(header)
        assert.same(selected, header.label.color)
        assert.not_same(LibStub("LibVelvet-1.0").HEADER, selected)
    end)

    it("does not refresh a preview while its page is not open", function()
        ns.Window.Show("raidMarkers")
        ns.Window.Show("groupChat")
        local before = refreshed
        ns.Window.Refresh()
        assert.equals(before, refreshed)
    end)
end)
