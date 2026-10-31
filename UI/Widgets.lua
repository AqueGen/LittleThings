-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local addonName, ns = ...

local Rules = ns.WidgetRules
local UI = LibStub("LibVelvet-1.0")

local Widgets = {}

Widgets.THEME = {
    bg = UI.T.bg,
    panel = UI.T.panel,
    border = UI.T.border,
    control = UI.T.control,
    gold = UI.T.gold,
    text = UI.T.text,
    muted = UI.T.muted,
    selected = UI.T.selected,
}
Widgets.FLAT = UI.FLAT

local T = Widgets.THEME
local PAD, GAP, TITLE_H = UI.PAD, UI.GAP, 32
local LABEL_W, CONTROL_W, NOTE_W = 170, 220, 540

local function Locked(spec)
    return spec.combatLocked and InCombatLockdown()
end

local function ShowTooltip(owner, spec)
    local text = type(spec.tooltip) == "function" and spec.tooltip() or spec.tooltip
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(spec.label or spec.text, 1, 1, 1)
    if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
    if spec.combatLocked then GameTooltip:AddLine("Not in combat.", 0.5, 0.5, 0.5, true) end
    if spec.reload then GameTooltip:AddLine("Takes effect after /reload.", 0.5, 0.5, 0.5, true) end
    GameTooltip:Show()
end

local function Hover(region, spec)
    if region.SetMotionScriptsWhileDisabled then region:SetMotionScriptsWhileDisabled(true) end
    region:SetScript("OnEnter", function(self) ShowTooltip(self, spec) end)
    region:SetScript("OnLeave", GameTooltip_Hide)
end

local function HookHover(region, spec)
    region:HookScript("OnEnter", function(self) ShowTooltip(self, spec) end)
    region:HookScript("OnLeave", GameTooltip_Hide)
end

local function AskReload(spec, valueText)
    if spec.reload then
        StaticPopup_Show("LITTLETHINGS_MODULE_RELOAD", spec.name or spec.label, valueText)
    end
end

function Widgets.Button(parent, text, width)
    return UI.Button(parent, text, width)
end

local Group = {}
Group.__index = Group

function Group:Add(frame, height, refresh, visible)
    self.items[#self.items + 1] = { frame = frame, height = height, refresh = refresh, visible = visible }
end

function Group:Check(spec)
    local group = self
    local check = UI.Checkbox(self.frame, 22)
    check.text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    check.text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.text:SetText(spec.label)
    check:SetHitRectInsets(0, -(check.text:GetStringWidth() + 6), 0, 0)
    local function Refresh()
        check:SetChecked(spec.get() and true or false)
        local enabled = not Locked(spec) and (not spec.enabled or spec.enabled())
        check:SetEnabled(enabled)
        check.text:SetTextColor(unpack(enabled and T.text or T.muted))
    end
    check:SetScript("OnClick", function(self)
        if Locked(spec) then
            Refresh()
            return
        end
        local on = self:GetChecked() and true or false
        spec.set(on)
        AskReload(spec, on and "on" or "off")
        group.page:Refresh()
    end)
    Hover(check, spec)
    self:Add(check, 24, Refresh, spec.visible)
end

function Group:CheckGrid(specs, columns, cellWidth)
    local group = self
    local ROW_H = 18
    local box = self.frame
    local holder = CreateFrame("Frame", nil, box)
    local checks, refreshers = {}, {}
    local function Place()
        local fit = Rules.Columns(columns, cellWidth, (box:GetWidth() or 0) - 2 * PAD)
        local cells, height = Rules.Grid(#specs, fit, cellWidth, ROW_H)
        for i, check in ipairs(checks) do
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", holder, "TOPLEFT", cells[i].x, -cells[i].y)
        end
        holder:SetSize(fit * cellWidth, math.max(height, 1))
        return math.max(height, 1)
    end
    for i, spec in ipairs(specs) do
        local check = UI.Checkbox(holder, 16)
        checks[i] = check
        check.text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        check.text:SetPoint("LEFT", check, "RIGHT", 3, 0)
        check.text:SetWidth(cellWidth - 24)
        check.text:SetJustifyH("LEFT")
        check.text:SetWordWrap(false)
        check.text:SetText(spec.label)
        check:SetHitRectInsets(0, -(cellWidth - 20), 0, 0)
        refreshers[i] = function()
            check:SetChecked(spec.get() and true or false)
            local enabled = not Locked(spec)
            check:SetEnabled(enabled)
            check.text:SetTextColor(unpack(enabled and T.text or T.muted))
        end
        check:SetScript("OnClick", function(self)
            if Locked(spec) then
                refreshers[i]()
                return
            end
            local on = self:GetChecked() and true or false
            spec.set(on)
            AskReload(spec, on and "on" or "off")
            group.page:Refresh()
        end)
        Hover(check, spec)
    end
    Place()
    self:Add(holder, Place, function()
        for _, refresh in ipairs(refreshers) do refresh() end
    end)
end

function Group:Slider(spec)
    local holder = CreateFrame("Frame", nil, self.frame)
    holder:SetSize(LABEL_W + CONTROL_W, 22)
    holder:EnableMouse(true)
    Hover(holder, spec)
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT")
    label:SetWidth(LABEL_W - 8)
    label:SetJustifyH("LEFT")
    local slider = UI.Slider(holder, CONTROL_W)
    slider:SetPoint("LEFT", holder, "LEFT", LABEL_W, 0)
    local format = spec.format or "%d"
    local function Caption(value)
        label:SetText(spec.label .. ": " .. format:format(value))
    end
    HookHover(slider.widget, spec)
    slider:Setup(spec.min, spec.max, spec.step or 1)
    local function SetShown(value)
        slider:SetValue(value, true)
        Caption(slider:GetValue())
    end
    slider.onChange = function(value)
        if Locked(spec) then
            SetShown(spec.get())
            return
        end
        spec.set(value)
        Caption(value)
    end
    self:Add(holder, 24, function()
        SetShown(spec.get())
        local locked = Locked(spec)
        slider:SetEnabled(not locked)
        label:SetTextColor(unpack(locked and T.muted or T.text))
    end, spec.visible)
end

function Group:Dropdown(spec)
    local group = self
    local holder = CreateFrame("Frame", nil, self.frame)
    holder:SetSize(LABEL_W + CONTROL_W, 26)
    holder:EnableMouse(true)
    Hover(holder, spec)
    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT")
    label:SetWidth(LABEL_W - 8)
    label:SetJustifyH("LEFT")
    label:SetText(spec.label)
    local dropdown = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", holder, "LEFT", LABEL_W, 0)
    dropdown:SetWidth(CONTROL_W)
    local function Options()
        return type(spec.options) == "function" and spec.options() or spec.options
    end
    dropdown:SetupMenu(function(_, root)
        for _, option in ipairs(Options()) do
            root:CreateRadio(option.text,
                function(value) return spec.get() == value end,
                function(value)
                    if Locked(spec) then return end
                    spec.set(value)
                    AskReload(spec, "to " .. option.text)
                    group.page:Refresh()
                end,
                option.value)
        end
    end)
    HookHover(dropdown, spec)
    self:Add(holder, 26, function()
        local current = spec.get()
        local options = Options()
        if spec.default ~= nil and #options > 0 and Rules.Known(options, current, spec.default) ~= current then
            spec.set(spec.default)
        end
        dropdown:GenerateMenu()
        local enabled = not Locked(spec) and (not spec.enabled or spec.enabled())
        dropdown:SetEnabled(enabled)
        label:SetTextColor(unpack(enabled and T.text or T.muted))
    end, spec.visible)
end

function Group:Button(spec)
    local group = self
    local button = Widgets.Button(self.frame, spec.text or spec.label, spec.width or 180)
    button:SetScript("OnClick", function()
        if Locked(spec) then return end
        spec.onClick()
        group.page:Refresh()
    end)
    Hover(button, spec)
    self:Add(button, 22, function()
        local enabled = not Locked(spec)
        button:SetEnabled(enabled)
        button.label:SetTextColor(unpack(enabled and T.text or T.muted))
    end, spec.visible)
end

function Group:Note(spec)
    if type(spec) == "string" then spec = { text = spec } end
    local box = self.frame
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetWidth(NOTE_W)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(T.muted))
    text:SetText(spec.text)
    -- Wraps to the box on a narrow window, never wider than a comfortable line
    self:Add(text, function()
        local room = (box:GetWidth() or 0) - 2 * PAD
        text:SetWidth(room > 100 and math.min(NOTE_W, room) or NOTE_W)
        return text:GetStringHeight()
    end, nil, spec.visible)
end

function Group:Scoped(predicate)
    local group, proxy = self, {}
    for _, name in ipairs({ "Check", "Slider", "Dropdown", "Button", "Note" }) do
        proxy[name] = function(_, spec)
            if type(spec) == "string" then spec = { text = spec } end
            local own = spec.visible
            spec.visible = own and function() return predicate() and own() end or predicate
            return group[name](group, spec)
        end
    end
    return proxy
end

local Page = {}
Page.__index = Page

function Widgets.NewPage(host)
    local frame = CreateFrame("Frame", nil, host)
    frame:SetPoint("TOPLEFT")
    frame:SetPoint("TOPRIGHT")
    frame:SetHeight(1)
    frame:Hide()
    return setmetatable({ frame = frame, groups = {} }, Page)
end

function Page:Group(title)
    local box = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    -- Anchored from the start so notes measure the box's width on the page's first layout
    box:SetPoint("TOPLEFT")
    box:SetPoint("RIGHT", self.frame, "RIGHT", -PAD, 0)
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.title:SetPoint("TOPLEFT", PAD, -8)
    box.title:SetText(title or "")
    UI.PaintGroup(box, title and title ~= "" and box.title or nil)
    local group = setmetatable({ page = self, frame = box, items = {}, visible = self.visible }, Group)
    self.groups[#self.groups + 1] = group
    return group
end

local function Height(item)
    return type(item.height) == "function" and item.height() or item.height
end

local function LayoutGroup(group)
    local heights = {}
    for index, item in ipairs(group.items) do
        local shown = not item.visible or item.visible()
        item.frame:SetShown(shown)
        if shown and item.refresh then item.refresh() end
        heights[index] = { height = Height(item), shown = shown }
    end
    local offsets, total = Rules.Stack(heights, GAP)
    for index, item in ipairs(group.items) do
        if offsets[index] then
            item.frame:ClearAllPoints()
            item.frame:SetPoint("TOPLEFT", group.frame, "TOPLEFT", PAD, -(TITLE_H + offsets[index]))
        end
    end
    return TITLE_H + total + PAD
end

function Page:Refresh()
    local blocks = {}
    for index, group in ipairs(self.groups) do
        local shown = not group.visible or group.visible()
        group.frame:SetShown(shown)
        local height = shown and LayoutGroup(group) or nil
        group.frame:SetHeight(height or 1)
        blocks[index] = { height = height or 0, shown = shown }
    end
    local offsets, total = Rules.Stack(blocks, PAD)
    for index, group in ipairs(self.groups) do
        if offsets[index] then
            group.frame:ClearAllPoints()
            group.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -offsets[index])
            group.frame:SetPoint("RIGHT", self.frame, "RIGHT", -PAD, 0)
        end
    end
    self.frame:SetHeight(math.max(total, 1))
    self.frame:GetParent():SetHeight(math.max(total, 1))
end

function Page:Fail()
    for _, group in ipairs(self.groups) do
        group.frame:Hide()
    end
    self.groups = {}
    self.visible = nil
    self:Group("This page failed to build"):Note("The error is in the error log (BugSack). Every other page still works.")
end

ns.Widgets = Widgets
