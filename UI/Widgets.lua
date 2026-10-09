local addonName, ns = ...

local Rules = ns.WidgetRules

local Widgets = {}

Widgets.THEME = {
    bg = { 0.063, 0.075, 0.09, 0.97 },
    panel = { 0.082, 0.098, 0.125, 1 },
    border = { 0.235, 0.251, 0.282, 1 },
    gold = { 1, 0.82, 0 },
    text = { 0.9, 0.9, 0.9 },
    muted = { 0.545, 0.576, 0.627 },
    selected = { 0.165, 0.192, 0.251, 1 },
}
Widgets.FLAT = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

local T = Widgets.THEME
local PAD, GAP, TITLE_H = 10, 6, 26
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
    region:SetScript("OnEnter", function(self) ShowTooltip(self, spec) end)
    region:SetScript("OnLeave", GameTooltip_Hide)
end

local function AskReload(spec, valueText)
    if spec.reload then
        StaticPopup_Show("LITTLETHINGS_MODULE_RELOAD", spec.label, valueText)
    end
end

function Widgets.Button(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 22)
    button:SetBackdrop(Widgets.FLAT)
    button:SetBackdropColor(unpack(T.panel))
    button:SetBackdropBorderColor(unpack(T.border))
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetTextColor(unpack(T.text))
    button:SetFontString(button.label)
    button:SetText(text)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.06)
    return button
end

local Group = {}
Group.__index = Group

function Group:Add(frame, height, refresh, visible)
    self.items[#self.items + 1] = { frame = frame, height = height, refresh = refresh, visible = visible }
end

function Group:Check(spec)
    local group = self
    local check = CreateFrame("CheckButton", nil, self.frame, "MinimalCheckboxTemplate")
    check:SetSize(22, 22)
    check.text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    check.text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.text:SetText(spec.label)
    check:SetHitRectInsets(0, -(check.text:GetStringWidth() + 6), 0, 0)
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        spec.set(on)
        AskReload(spec, on and "on" or "off")
        group.page:Refresh()
    end)
    Hover(check, spec)
    self:Add(check, 24, function()
        check:SetChecked(spec.get() and true or false)
        local enabled = not Locked(spec) and (not spec.enabled or spec.enabled())
        check:SetEnabled(enabled)
        check.text:SetTextColor(unpack(enabled and T.text or T.muted))
    end, spec.visible)
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
    local slider = CreateFrame("Frame", nil, holder, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("LEFT", holder, "LEFT", LABEL_W, 0)
    slider:SetSize(CONTROL_W, 19)
    local step, format = spec.step or 1, spec.format or "%d"
    local suppress = false
    local function Caption(value)
        label:SetText(spec.label .. ": " .. format:format(value))
    end
    slider:Init(spec.get(), spec.min, spec.max, (spec.max - spec.min) / step, {})
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if suppress then return end
        value = math.floor(value / step + 0.5) * step
        spec.set(value)
        Caption(value)
    end, holder)
    self:Add(holder, 24, function()
        local value = spec.get()
        suppress = true
        slider:SetValue(value)
        suppress = false
        Caption(value)
        slider:SetEnabled(not Locked(spec))
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
                    spec.set(value)
                    AskReload(spec, "to " .. option.text)
                    group.page:Refresh()
                end,
                option.value)
        end
    end)
    self:Add(holder, 26, function()
        local current = spec.get()
        if spec.default ~= nil and Rules.Known(Options(), current, spec.default) ~= current then
            spec.set(spec.default)
        end
        dropdown:GenerateMenu()
        dropdown:SetEnabled(not Locked(spec))
    end, spec.visible)
end

function Group:Button(spec)
    local group = self
    local button = Widgets.Button(self.frame, spec.text or spec.label, spec.width or 180)
    button:SetScript("OnClick", function()
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
    local text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetWidth(NOTE_W)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(T.muted))
    text:SetText(spec.text)
    self:Add(text, function() return text:GetStringHeight() end, nil, spec.visible)
end

function Group:Scoped(predicate)
    local group, proxy = self, {}
    for _, name in ipairs({ "Check", "Slider", "Dropdown", "Button", "Note" }) do
        proxy[name] = function(_, spec)
            if type(spec) == "string" then spec = { text = spec } end
            spec.visible = predicate
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
    box:SetBackdrop(Widgets.FLAT)
    box:SetBackdropColor(unpack(T.panel))
    box:SetBackdropBorderColor(unpack(T.border))
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.title:SetPoint("TOPLEFT", PAD, -8)
    box.title:SetTextColor(unpack(T.gold))
    box.title:SetText(title or "")
    local group = setmetatable({ page = self, frame = box, items = {}, visible = self.visible }, Group)
    self.groups[#self.groups + 1] = group
    return group
end

function Page:Embed(frame, height)
    frame:SetParent(self.frame)
    frame:Show()
    self.groups[#self.groups + 1] = { frame = frame, height = height, embedded = true, visible = self.visible }
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
        local height = group.height
        if shown and not group.embedded then
            height = LayoutGroup(group)
        end
        group.frame:SetHeight(height or 1)
        blocks[index] = { height = height or 0, shown = shown }
    end
    local offsets, total = Rules.Stack(blocks, PAD)
    for index, group in ipairs(self.groups) do
        if offsets[index] then
            group.frame:ClearAllPoints()
            group.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -offsets[index])
            if not group.embedded then
                group.frame:SetPoint("RIGHT", self.frame, "RIGHT", -PAD, 0)
            end
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
