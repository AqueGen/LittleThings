local addonName, ns = ...

local Widgets = ns.Widgets
local Rules = ns.WhatsNewRules
local T = Widgets.THEME

local WhatsNew = {}

local W, MAX_H, TITLE_H, FOOTER_H, PAD = 620, 520, 28, 38, 8
local DELAY = 2

local frame, page

local function EnableSpec(row)
    return {
        label = "Enable",
        name = row.label,
        reload = not row.live,
        combatLocked = true,
        get = function() return ns.IsOn(row.key) end,
        set = function(value)
            if value and row.parent and not ns.db[row.parent] then
                ns.SetSwitch(row.parent, true)
            end
            ns.SetSwitch(row.key, value)
        end,
    }
end

local function Build(rows)
    frame = CreateFrame("Frame", "LittleThingsWhatsNew", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "LittleThingsWhatsNew")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop(Widgets.FLAT)
    frame:SetBackdropColor(unpack(T.bg))
    frame:SetBackdropBorderColor(unpack(T.border))
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetPoint("CENTER")

    local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", PAD, -PAD)
    name:SetTextColor(unpack(T.gold))
    name:SetText("New in LittleThings")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -TITLE_H)
    scroll:SetPoint("BOTTOMRIGHT", -30, FOOTER_H)
    local host = CreateFrame("Frame", nil, scroll)
    host:SetSize(W - PAD - 30, 1)
    scroll:SetScrollChild(host)

    page = Widgets.NewPage(host)
    for _, row in ipairs(rows) do
        local group = page:Group(Rules.Title(row, ns.MODULES))
        group:Note(row.tooltip)
        group:Check(EnableSpec(row))
    end
    page.frame:Show()
    page:Refresh()
    frame:SetSize(W, math.min(TITLE_H + host:GetHeight() + FOOTER_H, MAX_H))

    local close = Widgets.Button(frame, "Close", 120)
    close:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    close:SetScript("OnClick", function() frame:Hide() end)

    local first = rows[1].parent or rows[1].key
    local open = Widgets.Button(frame, "Open settings", 120)
    open:SetPoint("RIGHT", close, "LEFT", -PAD, 0)
    open:SetScript("OnClick", function()
        frame:Hide()
        ns.OpenSettings(first)
    end)

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function() C_Timer.After(0, function() page:Refresh() end) end)
end

local function Show()
    Build(ns.newModules)
    frame:Show()
end

local function ShowOutOfCombat()
    if not InCombatLockdown() then
        Show()
        return
    end
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    waiter:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Show()
    end)
end

function WhatsNew.Enable()
    if #ns.newModules > 0 then
        C_Timer.After(DELAY, ShowOutOfCombat)
    end
end

ns.RegisterModule("WhatsNew", WhatsNew)
