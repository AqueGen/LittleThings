local addonName, ns = ...

local Rules = ns.SaveRules

local SaveIndicator = {}
ns.SaveIndicator = SaveIndicator

local DEFAULTS = { x = 0, y = -140, scale = 1, locked = false,
    showTime = true, showDR = true, off = {} }

local events

local function InitializeDb()
    local db = ns.db.saveIndicatorRow or {}
    ns.db.saveIndicatorRow = db
    if db.point and db.point ~= "CENTER" then
        db.x, db.y = DEFAULTS.x, DEFAULTS.y
    end
    db.point, db.relativePoint = nil, nil
    ns.ApplyDefaults(db, DEFAULTS)
end

function SaveIndicator.Refresh()
    local center = ns.IsOn("saveIndicator") and Rules.Where({ instanceType = select(2, IsInInstance()) })
    if ns.SaveCenter then ns.SaveCenter.Apply(center) end
end

function SaveIndicator.Enable()
    InitializeDb()
    if not events then
        events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        events:SetScript("OnEvent", SaveIndicator.Refresh)
    end
    SaveIndicator.Refresh()
end

local pageFrame

local function SyncPreview()
    if ns.SaveCenter then
        ns.SaveCenter.SetPreview(pageFrame ~= nil and pageFrame:IsShown() and ns.IsOn("saveIndicator"))
    end
end

function SaveIndicator.OnSwitch(enabled)
    if enabled then
        SaveIndicator.Enable()
    elseif events then
        SaveIndicator.Refresh()
    end
    SyncPreview()
end

local function Option(key, spec, apply)
    spec.default = DEFAULTS[key]
    spec.combatLocked = true
    spec.get = function() return ns.db.saveIndicatorRow[key] end
    spec.set = function(value)
        ns.db.saveIndicatorRow[key] = value
        if apply then apply() end
    end
    return spec
end

local function Place()
    if ns.SaveCenter then ns.SaveCenter.Place() end
end

function SaveIndicator.Pages(page)
    InitializeDb()
    if page.frame then
        pageFrame = page.frame
        page.frame:HookScript("OnShow", SyncPreview)
        page.frame:HookScript("OnHide", SyncPreview)
    end

    local row = page:Group("Centre row")
    row:Check(Option("showTime", { label = "Time left", reload = true,
        tooltip = "Seconds left inside each icon." }))
    row:Check(Option("showDR", { label = "Damage reduction", reload = true,
        tooltip = "The reduction under each icon, orange under 20%." }))
    row:Check(Option("locked", { label = "Lock position",
        tooltip = "Drag the row while this page is open to place it, then lock it." }))
    row:Slider(Option("scale", { label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f",
        tooltip = "Size of the whole row." }, Place))
    row:Slider(Option("x", { label = "X", min = -1000, max = 1000,
        tooltip = "Pixels right of the screen centre; 0 is centred. Dragging the row sets it for you." }, Place))
    row:Slider(Option("y", { label = "Y", min = -600, max = 600,
        tooltip = "Pixels above the screen centre. Dragging the row sets it for you." }, Place))
    row:Button({ label = "Test",
        tooltip = "Shows a sample row (Sentinel -24%, Pain Suppression -40%) that stays after this window closes, so you can see it over the game. Press again to hide it.",
        onClick = function()
            if ns.SaveCenter then ns.SaveCenter.ToggleDemo() end
        end })
    row:Button({ label = "Center horizontally", combatLocked = true,
        tooltip = "Puts the row in the middle of the screen, keeping its height.",
        onClick = function()
            ns.db.saveIndicatorRow.x = 0
            Place()
            ns.Window.Refresh()
        end })
    row:Button({ label = "Reset position", combatLocked = true,
        tooltip = "Moves the row back below the centre of the screen.",
        onClick = function()
            local db = ns.db.saveIndicatorRow
            db.x, db.y = DEFAULTS.x, DEFAULTS.y
            Place()
            ns.Window.Refresh()
        end })

    local tracked = Rules.Groups(ns.SaveData, select(2, UnitClass("player")))
    local group = page:Group("Tracked saves")
    for _, part in ipairs({
        { key = "yours", title = "Your class" },
        { key = "external", title = "Externals from other classes" },
    }) do
        group:Note(part.title)
        local specs = {}
        for _, id in ipairs(tracked[part.key]) do
            local entry = ns.SaveData[id]
            specs[#specs + 1] = { label = ("|T%s:14|t %s |cff999999%s|r"):format(C_Spell.GetSpellTexture(id) or 134400, entry.name, Rules.Text(entry)),
                name = entry.name, reload = true, combatLocked = true,
                tooltip = "Shows this save in the row.",
                get = function() return not ns.db.saveIndicatorRow.off[id] end,
                set = function(value) ns.db.saveIndicatorRow.off[id] = (not value) or nil end }
        end
        group:CheckGrid(specs, 3, 220)
    end
end

SaveIndicator.key = "saveIndicator"
ns.RegisterModule("SaveIndicator", SaveIndicator)
