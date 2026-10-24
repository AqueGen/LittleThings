local addonName, ns = ...

local Rules = ns.MarkerRules
local Shared = ns.RaidMarkerPanel

local SIZE, GAP, CELL_PAD = Shared.SIZE, Shared.GAP, Shared.CELL_PAD
local CLEAR_WIDTH = 60
local MODE_WIDTH = CLEAR_WIDTH - GAP - SIZE
local DOT = 16
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CLEAR_ICON = "common-icon-redx"
local TARGET_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local WORLD_COLORS = {
    { 4, 149, 255 }, { 15, 155, 12 }, { 168, 14, 192 }, { 167, 20, 13 },
    { 222, 218, 50 }, { 208, 84, 0 }, { 116, 155, 179 }, { 243, 241, 235 },
}
local GOLD, GREY, IDLE = Shared.GOLD, Shared.GREY, { 0.8, 0.8, 0.8 }

local NEXT_BODY = [[
if not down then return false end
local n = self:GetAttribute("lt-count") or 0
if n == 0 then return false end
local i = self:GetAttribute("lt-index") or 1
if i > n then i = 1 end
self:SetAttribute("macrotext", "/wm [@cursor]" .. self:GetAttribute("lt-order" .. i))
self:SetAttribute("lt-index", i % n + 1)
]]
local CLEAR_BODY = [[self:GetFrameRef("next"):SetAttribute("lt-index", 1)]]
local MODE_BODY = [[
if not down then return false end
if button == "RightButton" or self:GetAttribute("lt-active") then
    self:ClearBindings()
    self:SetAttribute("lt-active", nil)
elseif self:GetAttribute("lt-allowed") and (self:GetFrameRef("next"):GetAttribute("lt-count") or 0) > 0 then
    self:SetBindingClick(true, "BUTTON1", "LittleThingsWorldMarkerNext", "LeftButton")
    self:SetBindingClick(true, "ESCAPE", self:GetName(), "RightButton")
    self:SetAttribute("lt-active", true)
end
return false
]]
local HIDE_BODY = [[self:ClearBindings() self:SetAttribute("lt-active", nil)]]

Shared.targetButtons, Shared.worldButtons = {}, {}

local bindNext, bindClear

local function MarkerTitle(name)
    return name .. ": left click set, right click clear"
end

function Shared.RefreshTarget()
    local index = GetRaidTargetIndex("target")
    local secret = issecretvalue(index)
    for i, button in ipairs(Shared.targetButtons) do
        Shared.Ring(button, not secret and index == i)
    end
end

function Shared.PaintMode()
    local modeButton = Shared.modeButton
    local count = bindNext:GetAttribute("lt-count") or 0
    local on = modeButton:GetAttribute("lt-active")
    local index = bindNext:GetAttribute("lt-index") or 1
    if index > count then
        index = 1
    end
    local upcoming = on and bindNext:GetAttribute("lt-order" .. index)
    local allowed = modeButton:GetAttribute("lt-allowed")
    local color = (count == 0 or not allowed) and GREY or on and GOLD or IDLE
    modeButton.reason = not allowed and "Needs lead or assist" or count == 0 and "Placement order is empty" or nil
    modeButton.label:SetText(on and (index .. "/" .. count) or "Place")
    modeButton.label:SetTextColor(color[1], color[2], color[3])
    Shared.Ring(modeButton, on)
    for i, button in ipairs(Shared.worldButtons) do
        button.nextRing:SetShown(i == upcoming)
        button.nextGap:SetShown(i == upcoming)
    end
end

function Shared.StopMode()
    local modeButton = Shared.modeButton
    if modeButton and modeButton:GetAttribute("lt-active") then
        ClearOverrideBindings(modeButton)
        modeButton:SetAttribute("lt-active", nil)
        Shared.PaintMode()
    end
end

function Shared.ApplyOrder()
    local cycle = Rules.Cycle(ns.db.raidMarkerPanel.order)
    bindNext:SetAttribute("lt-count", #cycle)
    for i, marker in ipairs(cycle) do
        bindNext:SetAttribute("lt-order" .. i, marker)
    end
    bindNext:SetAttribute("lt-index", 1)
    if #cycle == 0 then
        Shared.StopMode()
    end
    Shared.PaintMode()
end

function Shared.RefreshWorld()
    for i, button in ipairs(Shared.worldButtons) do
        local placed = IsRaidMarkerActive(i)
        if not issecretvalue(placed) then
            Shared.Ring(button, placed)
        end
    end
end

local function Circle(button, layer, size, r, g, b)
    local texture = button:CreateTexture(nil, layer)
    texture:SetSize(size, size)
    texture:SetPoint("CENTER")
    texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    texture:SetVertexColor(r, g, b, 1)
    local mask = button:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return texture
end

local function BindingButton(name, attributes)
    local button = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyDown")
    button:SetAttribute("useOnKeyDown", true)
    for key, value in pairs(attributes) do
        button:SetAttribute(key, value)
    end
    return button
end

function Shared.BuildBindings()
    bindNext = BindingButton("LittleThingsWorldMarkerNext", {})
    bindClear = BindingButton("LittleThingsWorldMarkerClear", { action = "clear" })
    local header = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
    header:WrapScript(bindNext, "OnClick", NEXT_BODY)
    SecureHandlerSetFrameRef(bindClear, "next", bindNext)
    header:WrapScript(bindClear, "OnClick", CLEAR_BODY)
    return header
end

function Shared.BuildTargetButtons()
    local row1 = Shared.row1
    for i = 1, 8 do
        local button = Shared.SecureButton(row1, SIZE, MarkerTitle(_G["RAID_TARGET_" .. i] or ("Target marker " .. i)),
            { type = "raidtarget", marker = i, action1 = "set", action2 = "clear", unit = "target" })
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexture(TARGET_ICONS)
        SetRaidTargetIconTexture(icon, i)
        Shared.targetButtons[i] = button
    end
    local clearTarget = Shared.SecureButton(row1, CLEAR_WIDTH, "Clear all target markers", { type = "raidtarget", action = "clear-all" })
    Shared.clearTarget = clearTarget
    clearTarget.label = Shared.Label(clearTarget, "Clear all")
    clearTarget.cell = math.ceil(clearTarget.label:GetStringWidth()) + CELL_PAD
end

function Shared.BuildWorldButtons(header)
    local row2 = Shared.row2
    for i, color in ipairs(WORLD_COLORS) do
        local button = Shared.SecureButton(row2, SIZE, MarkerTitle(_G["WORLD_MARKER" .. i] or ("World marker " .. i)),
            { type = "worldmarker", marker = i, action1 = "set", action2 = "clear" })
        Circle(button, "ARTWORK", DOT, color[1] / 255, color[2] / 255, color[3] / 255)
        button.nextRing = Circle(button, "BACKGROUND", DOT + 6, 1, 1, 1)
        button.nextGap = Circle(button, "BORDER", DOT + 2, 0, 0, 0)
        Shared.worldButtons[i] = button
    end
    local modeButton = Shared.SecureButton(row2, MODE_WIDTH, "Placement mode: left click on the ground places the next world marker. Right click or Esc to stop.",
        {}, "LittleThingsWorldMarkerMode")
    Shared.modeButton = modeButton
    modeButton:RegisterForClicks("AnyDown")
    modeButton.label = Shared.Label(modeButton, "Place")
    modeButton.lines = function()
        return { "Left-clicks on the world do not target or turn the camera while it is on." }
    end
    SecureHandlerSetFrameRef(modeButton, "next", bindNext)
    header:WrapScript(modeButton, "OnClick", MODE_BODY)
    header:WrapScript(modeButton, "OnHide", HIDE_BODY)

    local clearWorld = Shared.SecureButton(row2, SIZE, "Clear all world markers", { type = "worldmarker", action = "clear" })
    Shared.clearWorld = clearWorld
    SecureHandlerSetFrameRef(clearWorld, "next", bindNext)
    header:WrapScript(clearWorld, "OnClick", CLEAR_BODY)
    local clearIcon = clearWorld:CreateTexture(nil, "ARTWORK")
    clearIcon:SetSize(DOT, DOT)
    clearIcon:SetPoint("CENTER")
    clearIcon:SetAtlas(CLEAR_ICON)

    modeButton:SetScript("OnAttributeChanged", Shared.PaintMode)
    bindNext:SetScript("OnAttributeChanged", Shared.PaintMode)
end

function Shared.SyncBindings()
    if not bindNext or InCombatLockdown() then
        return
    end
    bindNext:SetAttribute("type", Shared.active and "macro" or nil)
    bindClear:SetAttribute("type", Shared.active and "worldmarker" or nil)
end
