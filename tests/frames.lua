-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local Frames = {}

function Frames.new(parent)
    local f = { parentFrame = parent, points = {}, scripts = {}, shown = true, width = 0, height = 0, enabled = true, checked = false }
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
    function f:CreateFontString() return Frames.new(self) end
    function f:CreateTexture() return Frames.new(self) end
    function f:SetParent(p) self.parentFrame = p end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetTextColor(...) self.color = { ... } end
    function f:SetEnabled(on) self.enabled = on and true or false end
    function f:IsEnabled() return self.enabled end
    function f:SetChecked(on) self.checked = on and true or false end
    function f:GetChecked() return self.checked end
    function f:HasFocus() return self.focused == true end
    function f:ClearFocus() self.focused = false end
    function f:SetAlpha(a) self.alpha = a end
    function f:EnableMouse(on) self.mouse = on and true or false end
    function f:SetScale(s) self.scale = s end
    return setmetatable(f, {
        __index = function(_, k)
            if type(k) ~= "string" or not k:match("^%u") then return nil end
            if k:match("^Create") then return function(self) return Frames.new(self) end end
            if k:match("^Get") then return function() return 0 end end
            return function() end
        end,
    })
end

function Frames.loadVelvet()
    _G.strmatch = string.match
    _G.CreateColor = function(...) return { ... } end
    local dir = "Libs/LibVelvet-1.0/"
    local file = assert(io.open(dir .. "lib.xml", "rb"))
    local xml = file:read("*a")
    file:close()
    for script in xml:gmatch('<Script file="([^"]+)"/>') do dofile(dir .. script) end
end

function Frames.point(f, name)
    for _, p in ipairs(f.points) do
        if p[1] == name then return p end
    end
end

return Frames
